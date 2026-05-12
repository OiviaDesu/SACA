from __future__ import annotations

import argparse
import json
import time
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd
from scipy import sparse
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, f1_score, top_k_accuracy_score
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder

from data_ingestion.gurindji_clinical_normalizer import GurindjiClinicalNormalizer
from data_ingestion.hybrid_datasets import build_hybrid_features, default_pipeline_root, load_hybrid_dataset


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Benchmark Gurindji dictionary normalization for SACA diagnosis features.")
    parser.add_argument("--data-root", type=Path, default=default_pipeline_root() / "data")
    parser.add_argument("--dictionary", type=Path, default=Path("F:/git/SACA/python_pipeline/data/gurindji_dict_medical.xlsx"))
    parser.add_argument("--output-root", type=Path, default=default_pipeline_root() / "outputs" / "gurindji_normalization")
    parser.add_argument("--min-class-count", type=int, default=10)
    parser.add_argument("--max-text-features", type=int, default=3000)
    parser.add_argument("--test-size", type=float, default=0.2)
    parser.add_argument("--random-state", type=int, default=42)
    parser.add_argument("--smoke", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    output_root = args.output_root.resolve()
    output_root.mkdir(parents=True, exist_ok=True)

    dataset = load_hybrid_dataset(
        args.data_root,
        min_class_count=args.min_class_count,
        sample_per_class=4 if args.smoke else None,
        dataset_mode="hybrid",
    )
    normalizer = GurindjiClinicalNormalizer.from_excel(args.dictionary, symptom_columns=dataset.symptom_columns)
    frame = dataset.frame
    label_encoder = LabelEncoder()
    y = label_encoder.fit_transform(frame["disease_label"])
    stratify = y if int(pd.Series(y).value_counts().min()) >= 2 else None
    train_frame, test_frame, y_train, y_test = train_test_split(
        frame,
        y,
        test_size=0.5 if args.smoke else args.test_size,
        random_state=args.random_state,
        stratify=stratify,
    )
    X_train, X_test, metadata = build_hybrid_features(
        train_frame,
        test_frame,
        dataset.symptom_columns,
        max_text_features=200 if args.smoke else args.max_text_features,
        feature_mode="hybrid",
        feature_set="full",
    )
    start = time.time()
    model = LogisticRegression(
        C=4.0,
        solver="saga",
        max_iter=80 if args.smoke else 400,
        random_state=args.random_state,
    )
    model.fit(X_train, y_train)
    train_seconds = time.time() - start

    variants = {
        "english": test_frame,
        "gurindji_synthetic_raw": synthetic_variant(test_frame, normalizer, normalize_back=False),
        "gurindji_synthetic_normalized": synthetic_variant(test_frame, normalizer, normalize_back=True),
        "mixed_english_gurindji_normalized": mixed_variant(test_frame, normalizer),
    }
    rows: list[dict[str, Any]] = []
    misses: list[dict[str, Any]] = []
    for name, variant_frame in variants.items():
        _, X_variant, _ = build_hybrid_features(
            train_frame,
            variant_frame,
            dataset.symptom_columns,
            max_text_features=200 if args.smoke else args.max_text_features,
            feature_mode="hybrid",
            feature_set="full",
        )
        probabilities = model.predict_proba(X_variant)
        predictions = probabilities.argmax(axis=1)
        rows.append(
            {
                "variant": name,
                "rows": int(len(variant_frame)),
                "classes": int(frame["disease_label"].nunique()),
                "top1_accuracy": float(accuracy_score(y_test, predictions)),
                "top3_accuracy": top_k(y_test, probabilities, label_encoder, 3),
                "top5_accuracy": top_k(y_test, probabilities, label_encoder, 5),
                "f1_macro": float(f1_score(y_test, predictions, average="macro", zero_division=0)),
                "normalized_match_rate": normalized_match_rate(variant_frame),
                "train_seconds": float(train_seconds),
                "feature_counts": metadata["feature_counts"],
            }
        )
        misses.extend(top3_misses(name, probabilities, y_test, variant_frame, label_encoder))

    comparison = pd.DataFrame(rows)
    comparison.to_csv(output_root / "comparison.csv", index=False)
    (output_root / "comparison.json").write_text(json.dumps(rows, indent=2), encoding="utf-8")
    pd.DataFrame(misses).to_csv(output_root / "top3_misses.csv", index=False)
    print(comparison.to_string(index=False))
    return 0


def synthetic_variant(frame: pd.DataFrame, normalizer: GurindjiClinicalNormalizer, *, normalize_back: bool) -> pd.DataFrame:
    output = frame.copy()
    synthetic = output["text_input"].map(normalizer.synthetic_gurindji_text)
    output["text_input"] = synthetic.map(lambda text: normalizer.normalize(text).normalized_text if normalize_back else text)
    output["language"] = "gurindji_synthetic_normalized" if normalize_back else "gurindji_synthetic_raw"
    output["gurindji_match_count"] = synthetic.map(lambda text: len(normalizer.normalize(text).matches))
    return output


def mixed_variant(frame: pd.DataFrame, normalizer: GurindjiClinicalNormalizer) -> pd.DataFrame:
    output = frame.copy()
    mask = np.arange(len(output)) % 2 == 0
    synthetic = output.loc[mask, "text_input"].map(normalizer.synthetic_gurindji_text)
    output.loc[mask, "text_input"] = synthetic.map(lambda text: normalizer.normalize(text).normalized_text)
    output["language"] = "mixed_english_gurindji_normalized"
    output["gurindji_match_count"] = 0
    output.loc[mask, "gurindji_match_count"] = synthetic.map(lambda text: len(normalizer.normalize(text).matches))
    return output


def normalized_match_rate(frame: pd.DataFrame) -> float:
    if "gurindji_match_count" not in frame:
        return 0.0
    return float((pd.to_numeric(frame["gurindji_match_count"], errors="coerce").fillna(0) > 0).mean())


def top_k(y_true: np.ndarray, probabilities: np.ndarray, label_encoder: LabelEncoder, k: int) -> float:
    labels = np.arange(len(label_encoder.classes_))
    return float(top_k_accuracy_score(y_true, probabilities, k=min(k, len(labels)), labels=labels))


def top3_misses(name: str, probabilities: np.ndarray, y_test: np.ndarray, test_frame: pd.DataFrame, label_encoder: LabelEncoder) -> list[dict[str, Any]]:
    labels = label_encoder.inverse_transform(np.arange(len(label_encoder.classes_)))
    output = []
    top3_indices = np.argsort(probabilities, axis=1)[:, ::-1][:, :3]
    for row_index, indices in enumerate(top3_indices):
        if y_test[row_index] in indices:
            continue
        row = test_frame.iloc[row_index]
        output.append(
            {
                "variant": name,
                "source_type": row.get("source_type", ""),
                "true_label": str(label_encoder.inverse_transform([y_test[row_index]])[0]),
                "top1": str(labels[indices[0]]),
                "top2": str(labels[indices[1]]),
                "top3": str(labels[indices[2]]),
                "text_input": str(row.get("text_input", ""))[:500],
            }
        )
    return output


if __name__ == "__main__":
    raise SystemExit(main())

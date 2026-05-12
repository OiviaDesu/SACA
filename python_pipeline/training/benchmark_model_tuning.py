from __future__ import annotations

import argparse
import json
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import joblib
import numpy as np
import pandas as pd
from scipy import sparse
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, classification_report, f1_score, precision_score, recall_score, top_k_accuracy_score
from sklearn.model_selection import train_test_split
from sklearn.neural_network import MLPClassifier
from sklearn.preprocessing import LabelEncoder

from data_ingestion.hybrid_datasets import (
    build_hybrid_features,
    default_pipeline_root,
    indicator_matrix,
    load_hybrid_dataset,
    symptom_matrix,
)

SANITY_PROMPTS = [
    "fever cough sore throat",
    "sharp chest pain shortness of breath palpitations",
    "vomiting nausea diarrhea sharp abdominal pain",
    "headache dizziness nausea",
    "rash itching skin swelling",
]


@dataclass(frozen=True)
class Candidate:
    name: str
    kind: str
    hidden_layers: tuple[int, ...] = ()
    mlp_weight: float = 0.5
    logreg_weight: float = 0.5


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Tune SACA hybrid MLP/LogisticRegression models for top-3 accuracy.")
    parser.add_argument("--data-root", type=Path, default=default_pipeline_root() / "data")
    parser.add_argument("--output-root", type=Path, default=default_pipeline_root() / "outputs" / "model_tuning")
    parser.add_argument("--min-class-count", type=int, default=10)
    parser.add_argument("--max-text-features", type=int, default=3000)
    parser.add_argument("--mlp-max-iter", type=int, default=80)
    parser.add_argument("--logreg-max-iter", type=int, default=400)
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
    X_train, X_test, feature_metadata = build_hybrid_features(
        train_frame,
        test_frame,
        dataset.symptom_columns,
        max_text_features=200 if args.smoke else args.max_text_features,
        feature_mode="hybrid",
        feature_set="full",
    )

    mlp_candidates = [
        Candidate("mlp_baseline", "mlp", hidden_layers=(128, 128)),
        Candidate("mlp_wide", "mlp", hidden_layers=(256, 128)),
        Candidate("mlp_deep", "mlp", hidden_layers=(256, 128, 64)),
    ]
    if args.smoke:
        mlp_candidates = [Candidate("mlp_baseline", "mlp", hidden_layers=(64,))]
    candidates = [*mlp_candidates, Candidate("logreg", "logreg")]

    trained: dict[str, Any] = {}
    probabilities_by_name: dict[str, np.ndarray] = {}
    rows: list[dict[str, Any]] = []
    misses: list[dict[str, Any]] = []
    sanity: dict[str, Any] = {}

    for candidate in candidates:
        model, train_seconds = train_candidate(candidate, X_train, y_train, args)
        probabilities = model.predict_proba(model_input(candidate, X_test))
        trained[candidate.name] = model
        probabilities_by_name[candidate.name] = probabilities
        rows.append(
            evaluate_candidate(
                candidate,
                probabilities,
                y_test,
                test_frame,
                label_encoder,
                output_root,
                model,
                train_seconds,
                dataset.inventory,
                feature_metadata,
                dataset.symptom_columns,
                args,
            )
        )
        misses.extend(top3_misses(candidate.name, probabilities, y_test, test_frame, label_encoder))
        sanity[candidate.name] = sanity_predictions(candidate, model, feature_metadata, dataset.symptom_columns, label_encoder)

    best_mlp = max(
        (row for row in rows if str(row["mode"]).startswith("mlp_")),
        key=lambda row: float(row["top3_accuracy"]),
    )
    ensemble_specs = [
        Candidate("soft_vote_mlp_logreg", "ensemble", mlp_weight=0.5, logreg_weight=0.5),
        Candidate("weighted_vote_06_mlp", "ensemble", mlp_weight=0.6, logreg_weight=0.4),
        Candidate("weighted_vote_07_mlp", "ensemble", mlp_weight=0.7, logreg_weight=0.3),
    ]
    for candidate in ensemble_specs:
        probabilities = (
            probabilities_by_name[str(best_mlp["mode"])] * candidate.mlp_weight
            + probabilities_by_name["logreg"] * candidate.logreg_weight
        )
        ensemble_model = {
            "best_mlp": str(best_mlp["mode"]),
            "mlp": trained[str(best_mlp["mode"])],
            "logreg": trained["logreg"],
            "mlp_weight": candidate.mlp_weight,
            "logreg_weight": candidate.logreg_weight,
        }
        rows.append(
            evaluate_candidate(
                candidate,
                probabilities,
                y_test,
                test_frame,
                label_encoder,
                output_root,
                ensemble_model,
                0.0,
                dataset.inventory,
                feature_metadata,
                dataset.symptom_columns,
                args,
            )
        )
        misses.extend(top3_misses(candidate.name, probabilities, y_test, test_frame, label_encoder))
        sanity[candidate.name] = sanity_predictions(candidate, ensemble_model, feature_metadata, dataset.symptom_columns, label_encoder)

    comparison = pd.DataFrame(rows).sort_values("top3_accuracy", ascending=False)
    comparison.to_csv(output_root / "comparison.csv", index=False)
    (output_root / "comparison.json").write_text(json.dumps(comparison.to_dict(orient="records"), indent=2), encoding="utf-8")
    pd.DataFrame(misses).to_csv(output_root / "top3_misses.csv", index=False)
    (output_root / "sanity_predictions.json").write_text(json.dumps(sanity, indent=2, ensure_ascii=False), encoding="utf-8")
    print(comparison.to_string(index=False))
    return 0


def train_candidate(candidate: Candidate, X_train: sparse.csr_matrix, y_train: np.ndarray, args: argparse.Namespace) -> tuple[Any, float]:
    start = time.time()
    if candidate.kind == "mlp":
        model = MLPClassifier(
            hidden_layer_sizes=(64,) if args.smoke else candidate.hidden_layers,
            activation="relu",
            alpha=1e-4,
            learning_rate_init=1e-3,
            max_iter=12 if args.smoke else args.mlp_max_iter,
            batch_size=64,
            early_stopping=not args.smoke,
            random_state=args.random_state,
        )
        model.fit(to_dense(X_train), y_train)
        return model, time.time() - start
    if candidate.kind == "logreg":
        model = LogisticRegression(
            C=4.0,
            solver="saga",
            max_iter=80 if args.smoke else args.logreg_max_iter,
            n_jobs=-1,
            random_state=args.random_state,
            verbose=0,
        )
        model.fit(X_train, y_train)
        return model, time.time() - start
    raise ValueError(candidate.kind)


def evaluate_candidate(
    candidate: Candidate,
    probabilities: np.ndarray,
    y_test: np.ndarray,
    test_frame: pd.DataFrame,
    label_encoder: LabelEncoder,
    output_root: Path,
    model: Any,
    train_seconds: float,
    inventory: dict[str, Any],
    feature_metadata: dict[str, Any],
    symptom_columns: list[str],
    args: argparse.Namespace,
) -> dict[str, Any]:
    predictions = probabilities.argmax(axis=1)
    mode_output = output_root / candidate.name
    mode_output.mkdir(parents=True, exist_ok=True)
    artifact = build_artifact(candidate, model, label_encoder, feature_metadata, symptom_columns, inventory, args)
    artifact_path = mode_output / f"{candidate.name}.joblib"
    joblib.dump(artifact, artifact_path)
    report = classification_report(
        y_test,
        predictions,
        target_names=label_encoder.inverse_transform(np.unique(y_test)),
        labels=np.unique(y_test),
        output_dict=True,
        zero_division=0,
    )
    pd.DataFrame(report).transpose().to_csv(mode_output / "label_report.csv")
    metrics = {
        "mode": candidate.name,
        "kind": candidate.kind,
        **inventory,
        "feature_counts": feature_metadata["feature_counts"],
        "top1_accuracy": float(accuracy_score(y_test, predictions)),
        "top3_accuracy": top_k(y_test, probabilities, label_encoder, 3),
        "top5_accuracy": top_k(y_test, probabilities, label_encoder, 5),
        "accuracy": float(accuracy_score(y_test, predictions)),
        "f1_macro": float(f1_score(y_test, predictions, average="macro", zero_division=0)),
        "precision_macro": float(precision_score(y_test, predictions, average="macro", zero_division=0)),
        "recall_macro": float(recall_score(y_test, predictions, average="macro", zero_division=0)),
        "source_metrics": source_metrics(test_frame, y_test, predictions, probabilities, label_encoder),
        "latency_ms_per_pred": latency_ms(candidate, model, feature_metadata, X_sample=None),
        "train_seconds": float(train_seconds),
        "artifact_size_mb": artifact_path.stat().st_size / (1024 * 1024),
        "artifact": str(artifact_path),
    }
    metrics["latency_ms_per_pred"] = latency_for_probabilities(candidate, model, feature_metadata)
    (mode_output / "metrics.json").write_text(json.dumps(metrics, indent=2, ensure_ascii=False), encoding="utf-8")
    return flatten_metrics(metrics)


def build_artifact(candidate: Candidate, model: Any, label_encoder: LabelEncoder, feature_metadata: dict[str, Any], symptom_columns: list[str], inventory: dict[str, Any], args: argparse.Namespace) -> dict[str, Any]:
    return {
        "candidate": candidate.__dict__,
        "model": model,
        "label_encoder": label_encoder,
        "vectorizer": feature_metadata["vectorizer"],
        "severity_encoder": feature_metadata["severity_encoder"],
        "symptom_columns": symptom_columns,
        "feature_set": feature_metadata["feature_set"],
        "selected_features": feature_metadata["selected_features"],
        "inventory": inventory,
        "config": vars(args),
    }


def flatten_metrics(metrics: dict[str, Any]) -> dict[str, Any]:
    feature_counts = metrics.get("feature_counts", {})
    text_metrics = metrics.get("source_metrics", {}).get("text", {})
    structured_metrics = metrics.get("source_metrics", {}).get("structured", {})
    return {
        "mode": metrics["mode"],
        "kind": metrics["kind"],
        "rows": metrics["rows"],
        "classes": metrics["classes"],
        "features_total": feature_counts.get("total"),
        "top1_accuracy": metrics["top1_accuracy"],
        "top3_accuracy": metrics["top3_accuracy"],
        "top5_accuracy": metrics["top5_accuracy"],
        "f1_macro": metrics["f1_macro"],
        "text_top3_accuracy": text_metrics.get("top3_accuracy"),
        "structured_top3_accuracy": structured_metrics.get("top3_accuracy"),
        "text_f1_macro": text_metrics.get("f1_macro"),
        "structured_f1_macro": structured_metrics.get("f1_macro"),
        "latency_ms_per_pred": metrics["latency_ms_per_pred"],
        "train_seconds": metrics["train_seconds"],
        "artifact_size_mb": metrics["artifact_size_mb"],
        "artifact": metrics["artifact"],
    }


def source_metrics(test_frame: pd.DataFrame, y_test: np.ndarray, predictions: np.ndarray, probabilities: np.ndarray, label_encoder: LabelEncoder) -> dict[str, Any]:
    output: dict[str, Any] = {}
    sources = test_frame["source_type"].astype(str).to_numpy()
    for source_type in ["text", "structured"]:
        mask = sources == source_type
        if not mask.any():
            output[source_type] = {"rows": 0}
            continue
        output[source_type] = {
            "rows": int(mask.sum()),
            "accuracy": float(accuracy_score(y_test[mask], predictions[mask])),
            "top3_accuracy": top_k(y_test[mask], probabilities[mask], label_encoder, 3),
            "top5_accuracy": top_k(y_test[mask], probabilities[mask], label_encoder, 5),
            "f1_macro": float(f1_score(y_test[mask], predictions[mask], average="macro", zero_division=0)),
        }
    return output


def top3_misses(name: str, probabilities: np.ndarray, y_test: np.ndarray, test_frame: pd.DataFrame, label_encoder: LabelEncoder) -> list[dict[str, Any]]:
    labels = label_encoder.inverse_transform(np.arange(len(label_encoder.classes_)))
    rows = []
    top3_indices = np.argsort(probabilities, axis=1)[:, ::-1][:, :3]
    for row_index, indices in enumerate(top3_indices):
        if y_test[row_index] in indices:
            continue
        frame_row = test_frame.iloc[row_index]
        rows.append(
            {
                "mode": name,
                "source_type": frame_row.get("source_type", ""),
                "true_label": str(label_encoder.inverse_transform([y_test[row_index]])[0]),
                "top1": str(labels[indices[0]]),
                "top2": str(labels[indices[1]]),
                "top3": str(labels[indices[2]]),
                "text_input": str(frame_row.get("text_input", ""))[:500],
            }
        )
    return rows


def sanity_predictions(candidate: Candidate, model: Any, feature_metadata: dict[str, Any], symptom_columns: list[str], label_encoder: LabelEncoder) -> dict[str, Any]:
    output: dict[str, Any] = {}
    for prompt in SANITY_PROMPTS:
        row = pd.DataFrame(
            [
                {
                    "text_input": prompt,
                    "Severity": "unknown",
                    "has_real_severity": 0.0,
                    "has_real_symptoms": 0.0,
                    "source_og": 0.0,
                    "source_saca": 0.0,
                    "source_type": "interactive",
                    **{column: 0.0 for column in symptom_columns},
                }
            ]
        )
        X = transform_frame(row, feature_metadata, symptom_columns)
        probabilities = predict_proba(candidate, model, X)[0]
        top_indices = np.argsort(probabilities)[::-1][:5]
        output[prompt] = [
            {"label": str(label_encoder.inverse_transform([index])[0]), "probability": float(probabilities[index])}
            for index in top_indices
        ]
    return output


def transform_frame(frame: pd.DataFrame, feature_metadata: dict[str, Any], symptom_columns: list[str]) -> sparse.csr_matrix:
    parts = [feature_metadata["vectorizer"].transform(frame["text_input"].fillna(""))]
    parts.append(symptom_matrix(frame, symptom_columns))
    parts.append(feature_metadata["severity_encoder"].transform(frame[["Severity"]].astype(str)))
    parts.append(indicator_matrix(frame))
    return sparse.hstack(parts, format="csr")


def predict_proba(candidate: Candidate, model: Any, X: sparse.csr_matrix) -> np.ndarray:
    if candidate.kind == "mlp":
        return model.predict_proba(to_dense(X))
    if candidate.kind == "logreg":
        return model.predict_proba(X)
    if candidate.kind == "ensemble":
        return model["mlp"].predict_proba(to_dense(X)) * candidate.mlp_weight + model["logreg"].predict_proba(X) * candidate.logreg_weight
    raise ValueError(candidate.kind)


def model_input(candidate: Candidate, X: sparse.csr_matrix) -> Any:
    return to_dense(X) if candidate.kind == "mlp" else X


def top_k(y_true: np.ndarray, probabilities: np.ndarray, label_encoder: LabelEncoder, k: int) -> float:
    labels = np.arange(len(label_encoder.classes_))
    return float(top_k_accuracy_score(y_true, probabilities, k=min(k, len(labels)), labels=labels))


def latency_for_probabilities(candidate: Candidate, model: Any, feature_metadata: dict[str, Any]) -> float:
    vectorizer = feature_metadata["vectorizer"]
    symptoms = feature_metadata["feature_counts"]["symptoms"]
    severity = feature_metadata["feature_counts"]["severity"]
    flags = feature_metadata["feature_counts"]["missing_flags"]
    X = sparse.csr_matrix((1, vectorizer.transform([""]).shape[1] + symptoms + severity + flags), dtype=np.float32)
    start = time.time()
    for _ in range(100):
        predict_proba(candidate, model, X)
    return (time.time() - start) / 100 * 1000


def latency_ms(candidate: Candidate, model: Any, feature_metadata: dict[str, Any], X_sample: Any) -> float:
    return latency_for_probabilities(candidate, model, feature_metadata)


def to_dense(matrix: sparse.csr_matrix) -> np.ndarray:
    return matrix.toarray() if sparse.issparse(matrix) else matrix


if __name__ == "__main__":
    raise SystemExit(main())

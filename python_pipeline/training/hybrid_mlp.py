from __future__ import annotations

import argparse
import json
import time
from pathlib import Path
from typing import Any

import joblib
import numpy as np
import pandas as pd
from scipy import sparse
from sklearn.metrics import accuracy_score, classification_report, f1_score, precision_score, recall_score, top_k_accuracy_score
from sklearn.model_selection import train_test_split
from sklearn.neural_network import MLPClassifier
from sklearn.preprocessing import LabelEncoder

from data_ingestion.hybrid_datasets import (
    build_hybrid_features,
    default_pipeline_root,
    indicator_matrix,
    load_hybrid_dataset,
    prepare_hybrid_data,
    symptom_matrix,
)

DEFAULT_OUTPUT = Path("outputs") / "hybrid_mlp" / "hybrid_mlp.joblib"
DEFAULT_RANDOM_STATE = 42


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Train and use SACA hybrid TF-IDF + symptom MLP classifier.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    prepare = subparsers.add_parser("prepare-data", help="Copy datasets into python_pipeline/data/raw layout.")
    prepare.add_argument("--pipeline-root", type=Path, default=default_pipeline_root())

    smoke = subparsers.add_parser("smoke", help="Run deterministic small hybrid training.")
    add_train_args(smoke)
    smoke.set_defaults(sample_per_class=8, max_iter=20, test_size=0.25, hidden_layers="64")

    train = subparsers.add_parser("train", help="Train full hybrid MLP and save joblib artifact.")
    add_train_args(train)

    predict = subparsers.add_parser("predict", help="Load artifact and print top-k predictions.")
    predict.add_argument("--model", type=Path, required=True)
    predict.add_argument("--text", required=True)
    predict.add_argument("--severity", default="unknown")
    predict.add_argument("--symptom", action="append", default=[], help="Active symptom name. Can repeat.")
    predict.add_argument("--top-k", type=int, default=5)

    return parser.parse_args(argv)


def add_train_args(parser: argparse.ArgumentParser) -> None:
    pipeline_root = default_pipeline_root()
    parser.add_argument("--data-root", type=Path, default=pipeline_root / "data")
    parser.add_argument("--output", type=Path, default=pipeline_root / DEFAULT_OUTPUT)
    parser.add_argument("--min-class-count", type=int, default=10)
    parser.add_argument("--sample-per-class", type=int, default=None)
    parser.add_argument("--dataset-mode", choices=["og_text", "saca_custom", "hybrid"], default="hybrid")
    parser.add_argument(
        "--feature-set",
        choices=["og_text", "saca_custom", "hybrid", "text_only", "symptoms_only", "severity_only", "symptoms_severity", "full"],
        default=None,
    )
    parser.add_argument("--max-text-features", type=int, default=3000)
    parser.add_argument("--hidden-layers", default="128,128")
    parser.add_argument("--max-iter", type=int, default=80)
    parser.add_argument("--test-size", type=float, default=0.2)
    parser.add_argument("--random-state", type=int, default=DEFAULT_RANDOM_STATE)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    if args.command == "prepare-data":
        inventory = prepare_hybrid_data(args.pipeline_root)
        print(json.dumps(inventory, indent=2, ensure_ascii=False))
        return 0
    if args.command == "smoke":
        return train_command(args, smoke=True)
    if args.command == "train":
        return train_command(args, smoke=False)
    if args.command == "predict":
        predictions = predict_command(args.model, args.text, severity=args.severity, symptoms=args.symptom, top_k=args.top_k)
        print(json.dumps(predictions, indent=2, ensure_ascii=False))
        return 0
    raise ValueError(args.command)


def train_command(args: argparse.Namespace, *, smoke: bool) -> int:
    start = time.time()
    data_root = args.data_root.resolve()
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)

    dataset = load_hybrid_dataset(
        data_root,
        min_class_count=args.min_class_count,
        sample_per_class=args.sample_per_class,
        dataset_mode=args.dataset_mode,
    )
    frame = dataset.frame
    label_encoder = LabelEncoder()
    y = label_encoder.fit_transform(frame["disease_label"])

    min_count = int(pd.Series(y).value_counts().min())
    stratify = y if min_count >= 2 else None
    train_frame, test_frame, y_train, y_test = train_test_split(
        frame,
        y,
        test_size=args.test_size,
        random_state=args.random_state,
        stratify=stratify,
    )

    X_train, X_test, feature_metadata = build_hybrid_features(
        train_frame,
        test_frame,
        dataset.symptom_columns,
        max_text_features=args.max_text_features,
        feature_mode=args.dataset_mode,
        feature_set=args.feature_set,
    )
    model = MLPClassifier(
        hidden_layer_sizes=parse_hidden_layers(args.hidden_layers),
        activation="relu",
        alpha=1e-4,
        learning_rate_init=1e-3,
        max_iter=args.max_iter,
        batch_size=64,
        early_stopping=not smoke,
        random_state=args.random_state,
    )
    model.fit(_mlp_input(X_train), y_train)
    predictions = model.predict(_mlp_input(X_test))
    probabilities = model.predict_proba(_mlp_input(X_test)) if hasattr(model, "predict_proba") else None
    latency = benchmark_latency(model, X_test)

    metrics = {
        **dataset.inventory,
        "train_rows": int(X_train.shape[0]),
        "test_rows": int(X_test.shape[0]),
        "feature_counts": feature_metadata["feature_counts"],
        "source_metrics": source_metrics(test_frame, y_test, predictions, probabilities, label_encoder),
        "top1_accuracy": float(accuracy_score(y_test, predictions)),
        "top3_accuracy": top_k_accuracy(y_test, probabilities, label_encoder, 3),
        "top5_accuracy": top_k_accuracy(y_test, probabilities, label_encoder, 5),
        "accuracy": float(accuracy_score(y_test, predictions)),
        "f1_macro": float(f1_score(y_test, predictions, average="macro", zero_division=0)),
        "precision_macro": float(precision_score(y_test, predictions, average="macro", zero_division=0)),
        "recall_macro": float(recall_score(y_test, predictions, average="macro", zero_division=0)),
        "latency_ms_per_pred": float(latency),
        "train_seconds": float(time.time() - start),
        "model": "MLPClassifier",
        "hidden_layers": list(parse_hidden_layers(args.hidden_layers)),
        "max_iter": int(args.max_iter),
        "smoke": bool(smoke),
    }
    report = classification_report(
        y_test,
        predictions,
        target_names=label_encoder.inverse_transform(np.unique(y_test)),
        labels=np.unique(y_test),
        output_dict=True,
        zero_division=0,
    )

    artifact = {
        "model": model,
        "label_encoder": label_encoder,
        "vectorizer": feature_metadata["vectorizer"],
        "severity_encoder": feature_metadata["severity_encoder"],
        "feature_mode": feature_metadata["feature_mode"],
        "feature_set": feature_metadata["feature_set"],
        "selected_features": feature_metadata["selected_features"],
        "symptom_columns": dataset.symptom_columns,
        "metrics": metrics,
        "config": {
            "min_class_count": args.min_class_count,
            "max_text_features": args.max_text_features,
            "hidden_layers": list(parse_hidden_layers(args.hidden_layers)),
            "dataset_mode": args.dataset_mode,
            "feature_set": feature_metadata["feature_set"],
        },
    }
    joblib.dump(artifact, output)
    metrics_path = output.parent / "metrics.json"
    report_path = output.parent / "label_report.csv"
    metrics_path.write_text(json.dumps(metrics, indent=2, ensure_ascii=False), encoding="utf-8")
    pd.DataFrame(report).transpose().to_csv(report_path)
    print(json.dumps({"artifact": str(output), "metrics": metrics, "metrics_path": str(metrics_path)}, indent=2))
    return 0


def predict_command(model_path: Path, text: str, *, severity: str, symptoms: list[str], top_k: int) -> list[dict[str, Any]]:
    artifact = joblib.load(model_path)
    symptom_columns: list[str] = artifact["symptom_columns"]
    active = {symptom.strip().lower() for symptom in symptoms}
    row = pd.DataFrame(
        [
            {
                "text_input": text,
                "Severity": severity,
                "has_real_severity": 0.0 if severity == "unknown" else 1.0,
                "has_real_symptoms": 1.0 if active else 0.0,
                "source_og": 0.0,
                "source_saca": 0.0,
                "source_type": "interactive",
                **{column: 1.0 if column.lower() in active else 0.0 for column in symptom_columns},
            }
        ]
    )
    parts = []
    selected_features = set(artifact.get("selected_features", []))
    if artifact.get("vectorizer") is not None and "text" in selected_features:
        parts.append(artifact["vectorizer"].transform(row["text_input"]))
    if "symptoms" in selected_features:
        parts.append(symptom_matrix(row, symptom_columns))
    if artifact.get("severity_encoder") is not None and "severity" in selected_features:
        parts.append(artifact["severity_encoder"].transform(row[["Severity"]].astype(str)))
    if "indicators" in selected_features:
        parts.append(indicator_matrix(row))
    X = sparse.hstack(parts, format="csr")
    model = artifact["model"]
    label_encoder = artifact["label_encoder"]
    if hasattr(model, "predict_proba"):
        scores = model.predict_proba(_mlp_input(X))[0]
    else:
        predicted = model.predict(_mlp_input(X))[0]
        scores = np.zeros(len(label_encoder.classes_), dtype=np.float32)
        scores[predicted] = 1.0
    top_indices = np.argsort(scores)[::-1][:top_k]
    return [
        {"label": str(label_encoder.inverse_transform([index])[0]), "probability": float(scores[index])}
        for index in top_indices
    ]


def benchmark_latency(model: MLPClassifier, X: sparse.csr_matrix, repeats: int = 100) -> float:
    row = X[0:1]
    start = time.time()
    for _ in range(repeats):
        model.predict(_mlp_input(row))
    return (time.time() - start) / repeats * 1000


def source_metrics(
    test_frame: pd.DataFrame,
    y_test: np.ndarray,
    predictions: np.ndarray,
    probabilities: np.ndarray | None,
    label_encoder: LabelEncoder,
) -> dict[str, dict[str, float | int | None]]:
    output: dict[str, dict[str, float | int]] = {}
    sources = test_frame["source_type"].astype(str).to_numpy() if "source_type" in test_frame else np.asarray([])
    for source_type in ["text", "structured"]:
        mask = sources == source_type
        if not mask.any():
            output[source_type] = {"rows": 0}
            continue
        output[source_type] = {
            "rows": int(mask.sum()),
            "accuracy": float(accuracy_score(y_test[mask], predictions[mask])),
            "top3_accuracy": top_k_accuracy(y_test[mask], probabilities[mask] if probabilities is not None else None, label_encoder, 3),
            "top5_accuracy": top_k_accuracy(y_test[mask], probabilities[mask] if probabilities is not None else None, label_encoder, 5),
            "f1_macro": float(f1_score(y_test[mask], predictions[mask], average="macro", zero_division=0)),
            "precision_macro": float(precision_score(y_test[mask], predictions[mask], average="macro", zero_division=0)),
            "recall_macro": float(recall_score(y_test[mask], predictions[mask], average="macro", zero_division=0)),
        }
    return output


def top_k_accuracy(y_true: np.ndarray, probabilities: np.ndarray | None, label_encoder: LabelEncoder, k: int) -> float | None:
    if probabilities is None:
        return None
    labels = np.arange(len(label_encoder.classes_))
    effective_k = min(k, len(labels))
    return float(top_k_accuracy_score(y_true, probabilities, k=effective_k, labels=labels))


def parse_hidden_layers(value: str) -> tuple[int, ...]:
    return tuple(int(part.strip()) for part in value.split(",") if part.strip())


def _mlp_input(matrix: sparse.csr_matrix) -> np.ndarray:
    return matrix.toarray() if sparse.issparse(matrix) else matrix


if __name__ == "__main__":
    raise SystemExit(main())

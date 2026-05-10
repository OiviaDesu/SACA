from __future__ import annotations

import argparse
import json
import time
from pathlib import Path
from typing import Any

import pandas as pd

from training.hybrid_mlp import main as hybrid_main, predict_command

ABLATIONS = [
    {"mode": "saca_symptoms_only", "dataset_mode": "saca_custom", "feature_set": "symptoms_only"},
    {"mode": "saca_severity_only", "dataset_mode": "saca_custom", "feature_set": "severity_only"},
    {"mode": "saca_symptoms_severity", "dataset_mode": "saca_custom", "feature_set": "symptoms_severity"},
    {"mode": "hybrid_text_only", "dataset_mode": "hybrid", "feature_set": "text_only"},
    {"mode": "hybrid_symptoms_only", "dataset_mode": "hybrid", "feature_set": "symptoms_only"},
    {"mode": "hybrid_severity_only", "dataset_mode": "hybrid", "feature_set": "severity_only"},
    {"mode": "hybrid_full", "dataset_mode": "hybrid", "feature_set": "full"},
]
SANITY_PROMPTS = [
    "fever cough sore throat",
    "sharp chest pain shortness of breath palpitations",
    "vomiting nausea diarrhea sharp abdominal pain",
    "headache dizziness nausea",
    "rash itching skin swelling",
]


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run SACA symptom/severity feature ablation benchmark.")
    parser.add_argument("--data-root", type=Path, default=Path("data"))
    parser.add_argument("--output-root", type=Path, default=Path("outputs") / "feature_ablation")
    parser.add_argument("--min-class-count", type=int, default=10)
    parser.add_argument("--max-text-features", type=int, default=3000)
    parser.add_argument("--hidden-layers", default="128,128")
    parser.add_argument("--max-iter", type=int, default=80)
    parser.add_argument("--test-size", type=float, default=0.2)
    parser.add_argument("--random-state", type=int, default=42)
    parser.add_argument("--smoke", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    output_root = args.output_root.resolve()
    output_root.mkdir(parents=True, exist_ok=True)
    rows: list[dict[str, Any]] = []
    sanity: dict[str, Any] = {}
    top3_failures: list[dict[str, Any]] = []

    for ablation in ABLATIONS:
        mode = ablation["mode"]
        mode_output = output_root / mode
        mode_output.mkdir(parents=True, exist_ok=True)
        artifact = mode_output / f"{mode}_mlp.joblib"
        train_args = [
            "train",
            "--data-root",
            str(args.data_root),
            "--output",
            str(artifact),
            "--dataset-mode",
            ablation["dataset_mode"],
            "--feature-set",
            ablation["feature_set"],
            "--min-class-count",
            str(args.min_class_count),
            "--max-text-features",
            str(200 if args.smoke else args.max_text_features),
            "--hidden-layers",
            "64" if args.smoke else args.hidden_layers,
            "--max-iter",
            str(12 if args.smoke else args.max_iter),
            "--test-size",
            str(0.5 if args.smoke else args.test_size),
            "--random-state",
            str(args.random_state),
        ]
        if args.smoke:
            train_args.extend(["--sample-per-class", "4"])
        start = time.time()
        hybrid_main(train_args)
        metrics = json.loads((mode_output / "metrics.json").read_text(encoding="utf-8"))
        metrics["benchmark_seconds"] = time.time() - start
        metrics["mode"] = mode
        metrics["dataset_mode"] = ablation["dataset_mode"]
        metrics["feature_set"] = ablation["feature_set"]
        metrics["artifact"] = str(artifact)
        metrics["artifact_size_mb"] = artifact.stat().st_size / (1024 * 1024)
        rows.append(flatten_metrics(metrics))
        write_worst_labels(mode_output, metrics)

        sanity[mode] = {}
        for prompt in SANITY_PROMPTS:
            predictions = predict_command(artifact, prompt, severity="unknown", symptoms=[], top_k=5)
            sanity[mode][prompt] = predictions
            expected_hint = expected_hint_for_prompt(prompt)
            if expected_hint and not any(expected_hint in item["label"] for item in predictions[:3]):
                top3_failures.append(
                    {
                        "mode": mode,
                        "prompt": prompt,
                        "expected_hint": expected_hint,
                        "top3": [item["label"] for item in predictions[:3]],
                    }
                )
        (mode_output / "sanity_predictions.json").write_text(
            json.dumps(sanity[mode], indent=2, ensure_ascii=False), encoding="utf-8"
        )

    comparison = pd.DataFrame(rows)
    comparison.to_csv(output_root / "comparison.csv", index=False)
    (output_root / "comparison.json").write_text(json.dumps(rows, indent=2, ensure_ascii=False), encoding="utf-8")
    (output_root / "sanity_predictions.json").write_text(json.dumps(sanity, indent=2, ensure_ascii=False), encoding="utf-8")
    pd.DataFrame(top3_failures).to_csv(output_root / "top3_failures.csv", index=False)
    print(comparison.to_string(index=False))
    return 0


def write_worst_labels(mode_output: Path, metrics: dict[str, Any]) -> None:
    report = pd.read_csv(mode_output / "label_report.csv", index_col=0)
    labels = report[pd.to_numeric(report.get("support"), errors="coerce").notna()].copy()
    labels = labels.drop(index=[idx for idx in labels.index if idx in {"accuracy", "macro avg", "weighted avg"}], errors="ignore")
    worst = labels.sort_values("f1-score").head(10).reset_index().rename(columns={"index": "label"})
    worst.to_csv(mode_output / "worst_labels.csv", index=False)
    metrics["worst_labels"] = worst.to_dict(orient="records")


def flatten_metrics(metrics: dict[str, Any]) -> dict[str, Any]:
    feature_counts = metrics.get("feature_counts", {})
    source_metrics = metrics.get("source_metrics", {})
    text_metrics = source_metrics.get("text", {})
    structured_metrics = source_metrics.get("structured", {})
    return {
        "mode": metrics.get("mode"),
        "dataset_mode": metrics.get("dataset_mode"),
        "feature_set": metrics.get("feature_set"),
        "rows": metrics.get("rows"),
        "classes": metrics.get("classes"),
        "text_rows": metrics.get("text_rows"),
        "structured_rows": metrics.get("structured_rows"),
        "features_total": feature_counts.get("total"),
        "features_tfidf": feature_counts.get("tfidf"),
        "features_symptoms": feature_counts.get("symptoms"),
        "features_severity": feature_counts.get("severity"),
        "features_missing_flags": feature_counts.get("missing_flags"),
        "top1_accuracy": metrics.get("top1_accuracy"),
        "top3_accuracy": metrics.get("top3_accuracy"),
        "top5_accuracy": metrics.get("top5_accuracy"),
        "accuracy": metrics.get("accuracy"),
        "f1_macro": metrics.get("f1_macro"),
        "text_top3_accuracy": text_metrics.get("top3_accuracy"),
        "structured_top3_accuracy": structured_metrics.get("top3_accuracy"),
        "text_f1_macro": text_metrics.get("f1_macro"),
        "structured_f1_macro": structured_metrics.get("f1_macro"),
        "og_symptom_coverage": metrics.get("og_symptom_coverage"),
        "saca_symptom_coverage": metrics.get("saca_symptom_coverage"),
        "latency_ms_per_pred": metrics.get("latency_ms_per_pred"),
        "train_seconds": metrics.get("train_seconds"),
        "artifact_size_mb": metrics.get("artifact_size_mb"),
        "artifact": metrics.get("artifact"),
    }


def expected_hint_for_prompt(prompt: str) -> str | None:
    if "sore throat" in prompt:
        return "pneumonia"
    if "chest pain" in prompt:
        return "heart"
    if "abdominal pain" in prompt:
        return "gastro"
    if "headache" in prompt:
        return "migraine"
    if "rash" in prompt:
        return "chicken pox"
    return None


if __name__ == "__main__":
    raise SystemExit(main())

from __future__ import annotations

import argparse
import json
import time
from pathlib import Path
from typing import Any

import pandas as pd

from training.hybrid_mlp import main as hybrid_main, predict_command

MODES = ["og_text", "saca_custom", "hybrid"]
SANITY_PROMPTS = [
    "fever cough sore throat",
    "sharp chest pain shortness of breath palpitations",
    "vomiting nausea diarrhea sharp abdominal pain",
    "headache dizziness nausea",
    "rash itching skin swelling",
]


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run 3-way SACA ML benchmark.")
    parser.add_argument("--data-root", type=Path, default=Path("data"))
    parser.add_argument("--output-root", type=Path, default=Path("outputs") / "benchmark_three_way")
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

    for mode in MODES:
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
            mode,
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
        metrics["artifact"] = str(artifact)
        metrics["artifact_size_mb"] = artifact.stat().st_size / (1024 * 1024)
        report = pd.read_csv(mode_output / "label_report.csv", index_col=0)
        labels = report[pd.to_numeric(report.get("support"), errors="coerce").notna()].copy()
        labels = labels.drop(index=[idx for idx in labels.index if idx in {"accuracy", "macro avg", "weighted avg"}], errors="ignore")
        worst = labels.sort_values("f1-score").head(10).reset_index().rename(columns={"index": "label"})
        worst.to_csv(mode_output / "worst_labels.csv", index=False)
        metrics["worst_labels"] = worst.to_dict(orient="records")
        rows.append(flatten_metrics(metrics))

        sanity[mode] = {}
        for prompt in SANITY_PROMPTS:
            sanity[mode][prompt] = predict_command(artifact, prompt, severity="unknown", symptoms=[], top_k=5)
        (mode_output / "sanity_predictions.json").write_text(
            json.dumps(sanity[mode], indent=2, ensure_ascii=False), encoding="utf-8"
        )

    comparison = pd.DataFrame(rows)
    comparison.to_csv(output_root / "comparison.csv", index=False)
    (output_root / "comparison.json").write_text(
        json.dumps(rows, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    (output_root / "sanity_predictions.json").write_text(
        json.dumps(sanity, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    print(comparison.to_string(index=False))
    return 0


def flatten_metrics(metrics: dict[str, Any]) -> dict[str, Any]:
    feature_counts = metrics.get("feature_counts", {})
    return {
        "mode": metrics.get("mode"),
        "rows": metrics.get("rows"),
        "classes": metrics.get("classes"),
        "text_rows": metrics.get("text_rows"),
        "structured_rows": metrics.get("structured_rows"),
        "train_rows": metrics.get("train_rows"),
        "test_rows": metrics.get("test_rows"),
        "features_total": feature_counts.get("total"),
        "features_tfidf": feature_counts.get("tfidf"),
        "features_symptoms": feature_counts.get("symptoms"),
        "features_severity": feature_counts.get("severity"),
        "features_missing_flags": feature_counts.get("missing_flags"),
        "og_symptom_coverage": metrics.get("og_symptom_coverage"),
        "saca_symptom_coverage": metrics.get("saca_symptom_coverage"),
        "text_f1_macro": metrics.get("source_metrics", {}).get("text", {}).get("f1_macro"),
        "structured_f1_macro": metrics.get("source_metrics", {}).get("structured", {}).get("f1_macro"),
        "text_accuracy": metrics.get("source_metrics", {}).get("text", {}).get("accuracy"),
        "structured_accuracy": metrics.get("source_metrics", {}).get("structured", {}).get("accuracy"),
        "accuracy": metrics.get("accuracy"),
        "f1_macro": metrics.get("f1_macro"),
        "precision_macro": metrics.get("precision_macro"),
        "recall_macro": metrics.get("recall_macro"),
        "latency_ms_per_pred": metrics.get("latency_ms_per_pred"),
        "train_seconds": metrics.get("train_seconds"),
        "artifact_size_mb": metrics.get("artifact_size_mb"),
        "artifact": metrics.get("artifact"),
    }


if __name__ == "__main__":
    raise SystemExit(main())



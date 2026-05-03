from __future__ import annotations

import argparse
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any

import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder

sys.path.insert(0, str(Path(__file__).resolve().parent))
from xgb_flutter_bundle import (
    build_dense_feature_vector,
    compare_pipeline_and_bundle,
    export_m2cgen_source,
    load_bundle,
    load_xgb_pipeline,
    record_from_feature_row,
    save_json,
    select_best_generated_probability_candidate,
)


TRAINER_PATH = Path(__file__).resolve().parents[1] / "training" / "train_classifier.py"
DEFAULT_REPORT_OUTPUT = "python_pipeline/outputs/xgb_quick_dart_export/parity_report.json"


def load_trainer_module() -> Any:
    spec = importlib.util.spec_from_file_location("train_classifier", TRAINER_PATH)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Verify the XGBoost Dart export path against the original Python pipeline "
            "on a held-out test split."
        )
    )
    parser.add_argument("--model-dir", required=True, help="Directory containing the trained XGBoost model artifact.")
    parser.add_argument("--bundle-dir", required=True, help="Directory containing bundle.json exported for Dart preprocessing.")
    parser.add_argument("--data", nargs="+", required=True, help="One or more dataset files used to recreate the held-out split.")
    parser.add_argument("--label-col", required=True, help="Target label column.")
    parser.add_argument(
        "--text-cols",
        nargs="+",
        default=["symptoms_text", "transcript_text"],
        help="Text columns merged into the classifier input.",
    )
    parser.add_argument(
        "--categorical-cols",
        nargs="*",
        default=["body_location", "prior_medications", "language", "source"],
        help="Structured categorical columns.",
    )
    parser.add_argument(
        "--numeric-cols",
        nargs="*",
        default=["duration_hours", "duration_days"],
        help="Structured numeric columns.",
    )
    parser.add_argument("--min-class-count", type=int, default=2, help="Minimum class count used during training cleanup.")
    parser.add_argument("--test-size", type=float, default=0.2, help="Held-out split size used during training.")
    parser.add_argument("--random-state", type=int, default=42, help="Train/test split random seed used during training.")
    parser.add_argument("--limit", type=int, default=0, help="Optional cap on the number of held-out rows to verify.")
    parser.add_argument("--report-output", default=DEFAULT_REPORT_OUTPUT, help="Path to the JSON parity report.")
    return parser.parse_args(argv)


def build_feature_split(args: argparse.Namespace) -> tuple[Any, np.ndarray]:
    trainer = load_trainer_module()
    raw_df = trainer.load_dataset(args.data, verbose=False)
    cleaned_df, _cleaning_summary = trainer.clean_training_frame(
        raw_df,
        args.label_col,
        args.text_cols,
        args.categorical_cols,
        args.numeric_cols,
        args.min_class_count,
        verbose=False,
    )
    processed_df, text_feature_cols, categorical_cols, numeric_cols = trainer.add_derived_features(
        cleaned_df,
        args.text_cols,
        args.categorical_cols,
        args.numeric_cols,
    )
    feature_df = processed_df[[*text_feature_cols, *categorical_cols, *numeric_cols]].copy()
    label_encoder = LabelEncoder()
    y = label_encoder.fit_transform(processed_df[args.label_col])

    _x_train, x_test, _y_train, y_test = train_test_split(
        feature_df,
        y,
        test_size=args.test_size,
        random_state=args.random_state,
        stratify=y,
    )
    x_test = x_test.reset_index(drop=True)
    if args.limit and args.limit > 0:
        x_test = x_test.head(args.limit).reset_index(drop=True)
        y_test = y_test[: len(x_test)]
    return x_test, y_test


def load_generated_python_score(model: Any) -> tuple[Any, str]:
    python_code = export_m2cgen_source(model, language="python")
    namespace: dict[str, Any] = {}
    exec(python_code, namespace)
    return namespace["score"], python_code


def compare_pipeline_and_m2cgen(
    bundle: dict[str, Any],
    pipeline: Any,
    feature_frame: Any,
    generated_score: Any,
) -> dict[str, Any]:
    pipeline_probabilities = np.asarray(pipeline.predict_proba(feature_frame), dtype=float)
    dense_inputs = [
        build_dense_feature_vector(bundle, record_from_feature_row(row, bundle))
        for row in feature_frame.to_dict(orient="records")
    ]
    raw_outputs = [generated_score(features) for features in dense_inputs]
    selected_interpretation, generated_probabilities, candidate_reports, raw_matrix = (
        select_best_generated_probability_candidate(
            pipeline_probabilities,
            raw_outputs,
            objective_name=str(bundle["model"]["objective"]),
            class_count=int(bundle["model"]["num_classes"]),
        )
    )

    abs_diff = np.abs(pipeline_probabilities - generated_probabilities)
    pipeline_top = np.argmax(pipeline_probabilities, axis=1)
    generated_top = np.argmax(generated_probabilities, axis=1)
    labels = [str(value) for value in bundle["classes"]]
    worst_row_indices = np.argsort(abs_diff.max(axis=1))[::-1][: min(5, len(feature_frame))]
    records = feature_frame.to_dict(orient="records")

    worst_examples = []
    for row_index in worst_row_indices.tolist():
        worst_examples.append(
            {
                "row_index": int(row_index),
                "combined_text_excerpt": str(records[row_index].get("combined_text", ""))[:160],
                "pipeline_top_label": labels[int(pipeline_top[row_index])],
                "generated_top_label": labels[int(generated_top[row_index])],
                "row_max_abs_diff": float(abs_diff[row_index].max()),
            }
        )

    return {
        "row_count": int(len(feature_frame)),
        "class_count": int(generated_probabilities.shape[1]),
        "raw_output_shape": [int(value) for value in raw_matrix.shape],
        "selected_interpretation": selected_interpretation,
        "candidate_interpretations": candidate_reports,
        "max_abs_diff": float(abs_diff.max()) if abs_diff.size else 0.0,
        "mean_abs_diff": float(abs_diff.mean()) if abs_diff.size else 0.0,
        "top1_agreement": float((pipeline_top == generated_top).mean()) if len(feature_frame) else 1.0,
        "worst_examples": worst_examples,
    }


def main(argv: list[str] | None = None) -> None:
    args = parse_args(argv)
    pipeline, _label_metadata, _metrics, source_model_path = load_xgb_pipeline(args.model_dir)
    bundle = load_bundle(args.bundle_dir)
    x_test, _y_test = build_feature_split(args)

    generated_score, python_code = load_generated_python_score(pipeline.named_steps["clf"])
    m2cgen_report = compare_pipeline_and_m2cgen(bundle, pipeline, x_test, generated_score)
    bundle_report = compare_pipeline_and_bundle(bundle, pipeline, x_test)

    report = {
        "source_model_path": str(source_model_path),
        "bundle_dir": str(Path(args.bundle_dir)),
        "data": args.data,
        "test_size": args.test_size,
        "random_state": args.random_state,
        "verified_rows": int(len(x_test)),
        "m2cgen_generated_code": {
            **m2cgen_report,
            "proxy_language": "python",
            "score_function_note": (
                "The Python scorer is generated from the same m2cgen AST used for Dart export. "
                "Verification now checks whether that scorer behaves like probabilities or raw margins/logits before comparing against Python predict_proba."
            ),
        },
        "manual_bundle_runtime": bundle_report,
        "checks": {
            "m2cgen_top1_exact": bool(m2cgen_report["top1_agreement"] == 1.0),
            "bundle_top1_exact": bool(bundle_report["top1_agreement"] == 1.0),
            "m2cgen_max_abs_diff_lt_1e-6": bool(m2cgen_report["max_abs_diff"] < 1e-6),
            "bundle_max_abs_diff_lt_1e-6": bool(bundle_report["max_abs_diff"] < 1e-6),
        },
        "generated_python_scorer_chars": len(python_code),
    }

    report_output_path = Path(args.report_output)
    save_json(report_output_path, report)
    print(json.dumps(report, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()

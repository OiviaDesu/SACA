from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from xgb_flutter_bundle import (
    EXPORT_SUMMARY_FILENAME,
    export_m2cgen_source,
    export_xgb_flutter_bundle,
    load_xgb_pipeline,
    save_json,
)


DEFAULT_BUNDLE_OUTPUT_DIR = "assets/models/classifier-xgb-quick"
DEFAULT_DART_MODEL_OUTPUT = "lib/infrastructure/analysis/generated_local/xgb_quick_model.dart"
DEFAULT_REPORT_OUTPUT = "python_pipeline/outputs/xgb_quick_dart_export/export_report.json"
DEFAULT_PYTHON_SCORER_OUTPUT = "python_pipeline/outputs/xgb_quick_dart_export/xgb_quick_model.py"


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Export a trained XGBoost sklearn pipeline into a local Dart scorer "
            "via m2cgen plus a JSON preprocessing bundle."
        )
    )
    parser.add_argument(
        "--model-dir",
        required=True,
        help="Directory containing best_model.joblib, label_metadata.json, and metrics.json.",
    )
    parser.add_argument(
        "--bundle-output-dir",
        default=DEFAULT_BUNDLE_OUTPUT_DIR,
        help="Directory where bundle.json and export_summary.json will be written.",
    )
    parser.add_argument(
        "--dart-model-output",
        default=DEFAULT_DART_MODEL_OUTPUT,
        help="Path to the generated local-only Dart scorer file.",
    )
    parser.add_argument(
        "--report-output",
        default=DEFAULT_REPORT_OUTPUT,
        help="Path to a JSON report describing the export outputs.",
    )
    parser.add_argument(
        "--python-scorer-output",
        default=DEFAULT_PYTHON_SCORER_OUTPUT,
        help="Optional debug path for the generated Python scorer used in parity checks.",
    )
    parser.add_argument(
        "--write-python-scorer",
        action="store_true",
        help="Also write the patched m2cgen Python scorer for parity/debugging.",
    )
    return parser.parse_args(argv)


def write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def build_dart_header(*, source_model_path: Path) -> str:
    return "\n".join(
        [
            "// Generated locally by python_pipeline/export/export_xgb_to_dart.py.",
            f"// Source model: {source_model_path}",
            "// Experimental export: keep missing features as double.nan to preserve sparse XGBoost semantics.",
            "// Do not hand-edit this file; regenerate it from the Python exporter instead.",
            "",
        ]
    )


def build_python_header(*, source_model_path: Path) -> str:
    return "\n".join(
        [
            '"""Generated locally by python_pipeline/export/export_xgb_to_dart.py.',
            f"Source model: {source_model_path}",
            "Experimental parity/debug scorer for the Dart export path.",
            '"""',
            "",
        ]
    )


def main(argv: list[str] | None = None) -> None:
    args = parse_args(argv)

    pipeline, _label_metadata, _metrics, source_model_path = load_xgb_pipeline(args.model_dir)
    bundle_summary = export_xgb_flutter_bundle(args.model_dir, args.bundle_output_dir)

    dart_code = export_m2cgen_source(pipeline.named_steps["clf"], language="dart")
    dart_output_path = Path(args.dart_model_output)
    write_text(
        dart_output_path,
        build_dart_header(source_model_path=source_model_path) + dart_code + "\n",
    )

    report: dict[str, Any] = {
        "source_model_path": str(source_model_path),
        "bundle_output_dir": str(Path(args.bundle_output_dir)),
        "bundle_summary_path": str(Path(args.bundle_output_dir) / EXPORT_SUMMARY_FILENAME),
        "dart_model_output": str(dart_output_path),
        "dart_model_size_bytes": dart_output_path.stat().st_size,
        "bundle_size_bytes": bundle_summary["bundle_size_bytes"],
        "class_count": bundle_summary["class_count"],
        "feature_count": bundle_summary["feature_count"],
        "tree_count": bundle_summary["tree_count"],
        "workarounds": [
            "force num_parallel_tree=1 when XGBClassifier exposes None",
            "patch m2cgen multiclass base-score placeholders with booster config values",
            "preserve sparse-missing semantics by requiring double.nan for absent features",
        ],
    }

    if args.write_python_scorer:
        python_code = export_m2cgen_source(pipeline.named_steps["clf"], language="python")
        python_output_path = Path(args.python_scorer_output)
        write_text(
            python_output_path,
            build_python_header(source_model_path=source_model_path) + python_code + "\n",
        )
        report["python_scorer_output"] = str(python_output_path)
        report["python_scorer_size_bytes"] = python_output_path.stat().st_size

    report_output_path = Path(args.report_output)
    save_json(report_output_path, report)
    print(json.dumps(report, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()

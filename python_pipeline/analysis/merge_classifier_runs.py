from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path
from typing import Any

import joblib

import train_classifier


MODEL_ARTIFACT_NAMES = {
    "logistic_regression": "logistic_regression.joblib",
    "xgboost": "xgboost.joblib",
}


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Merge LR and XGBoost classifier run outputs into a single leaderboard."
    )
    parser.add_argument("--lr-dir", required=True, help="Directory containing LR-only artifacts.")
    parser.add_argument("--xgb-dir", required=True, help="Directory containing XGB-only artifacts.")
    parser.add_argument("--output-dir", required=True, help="Directory for merged artifacts.")
    parser.add_argument(
        "--scope-name",
        default="combined",
        help="Human-readable label for this merged scope (for example: single or multi).",
    )
    parser.add_argument(
        "--export-onnx",
        action="store_true",
        help="Export ONNX only if logistic_regression wins the merged leaderboard.",
    )
    return parser.parse_args(argv)


def load_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def save_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2, ensure_ascii=False)


def load_run(run_dir: Path) -> dict[str, Any]:
    metrics_path = run_dir / "metrics.json"
    label_metadata_path = run_dir / "label_metadata.json"
    dataset_audit_path = run_dir / "dataset_audit.json"

    metrics = load_json(metrics_path)
    label_metadata = load_json(label_metadata_path)
    dataset_audit = load_json(dataset_audit_path)

    model_name = metrics["best_model"]
    if model_name not in metrics["models"]:
        raise ValueError(f"Expected model '{model_name}' in {metrics_path}, found {list(metrics['models'])}")

    model_artifact = run_dir / MODEL_ARTIFACT_NAMES.get(model_name, "best_model.joblib")
    if not model_artifact.exists():
        model_artifact = run_dir / "best_model.joblib"

    return {
        "run_dir": run_dir,
        "metrics": metrics,
        "label_metadata": label_metadata,
        "dataset_audit": dataset_audit,
        "model_name": model_name,
        "model_metrics": metrics["models"][model_name],
        "leaderboard_entry": {
            "model_name": model_name,
            "accuracy": metrics["models"][model_name]["accuracy"],
            "f1_macro": metrics["models"][model_name]["f1_macro"],
            "f1_weighted": metrics["models"][model_name]["f1_weighted"],
            "source_dir": str(run_dir),
        },
        "model_artifact": model_artifact,
    }


def ensure_compatible_runs(lr_run: dict[str, Any], xgb_run: dict[str, Any]) -> None:
    if lr_run["label_metadata"]["task"] != xgb_run["label_metadata"]["task"]:
        raise ValueError("LR and XGB runs use different tasks; cannot merge results.")

    if lr_run["label_metadata"]["classes"] != xgb_run["label_metadata"]["classes"]:
        raise ValueError("LR and XGB runs have different label metadata; cannot merge results.")


def copy_artifact(src: Path, dst: Path) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


def maybe_export_onnx(best_run: dict[str, Any], output_dir: Path) -> dict[str, str]:
    onnx_status: dict[str, str] = {}
    if best_run["model_name"] != "logistic_regression":
        onnx_status[best_run["model_name"]] = (
            "Skipped: merged winner is not logistic_regression, so ONNX export is not attempted."
        )
        return onnx_status

    estimator = joblib.load(best_run["model_artifact"])
    ok, message = train_classifier.try_export_lr_onnx(
        estimator,
        output_dir / f"{best_run['model_name']}.onnx",
    )
    onnx_status[best_run["model_name"]] = message if ok else f"Failed: {message}"
    return onnx_status


def merge_runs(args: argparse.Namespace) -> dict[str, Any]:
    lr_run = load_run(Path(args.lr_dir))
    xgb_run = load_run(Path(args.xgb_dir))
    ensure_compatible_runs(lr_run, xgb_run)

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    leaderboard = sorted(
        [lr_run["leaderboard_entry"], xgb_run["leaderboard_entry"]],
        key=lambda item: item["f1_macro"],
        reverse=True,
    )
    best_run = lr_run if leaderboard[0]["model_name"] == lr_run["model_name"] else xgb_run

    copy_artifact(best_run["run_dir"] / "label_metadata.json", output_dir / "label_metadata.json")
    copy_artifact(best_run["run_dir"] / "dataset_audit.json", output_dir / "dataset_audit.json")

    for run in (lr_run, xgb_run):
        copy_artifact(run["model_artifact"], output_dir / MODEL_ARTIFACT_NAMES[run["model_name"]])

    copy_artifact(best_run["model_artifact"], output_dir / "best_model.joblib")

    merged_metrics = {
        "scope": args.scope_name,
        "best_model": best_run["model_name"],
        "leaderboard": leaderboard,
        "models": {
            lr_run["model_name"]: lr_run["model_metrics"],
            xgb_run["model_name"]: xgb_run["model_metrics"],
        },
        "search_config": {
            "lr": lr_run["metrics"].get("search_config", {}),
            "xgb": xgb_run["metrics"].get("search_config", {}),
        },
        "source_runs": {
            "lr": str(lr_run["run_dir"]),
            "xgb": str(xgb_run["run_dir"]),
        },
        "deployment": {
            "preferred_mobile_export": "ONNX only if merged winner is logistic_regression.",
            "winning_source_dir": str(best_run["run_dir"]),
        },
    }
    save_json(output_dir / "metrics.json", merged_metrics)

    onnx_status: dict[str, str] = {}
    if args.export_onnx:
        onnx_status = maybe_export_onnx(best_run, output_dir)
        save_json(output_dir / "onnx_export_status.json", onnx_status)

    summary = {
        "scope": args.scope_name,
        "best_model": best_run["model_name"],
        "leaderboard": leaderboard,
        "artifacts": [
            str(output_dir / "dataset_audit.json"),
            str(output_dir / "label_metadata.json"),
            str(output_dir / "metrics.json"),
            str(output_dir / "best_model.joblib"),
        ],
    }
    if args.export_onnx:
        summary["artifacts"].append(str(output_dir / "onnx_export_status.json"))
    save_json(output_dir / "run_summary.json", summary)

    return {
        "metrics": merged_metrics,
        "onnx_status": onnx_status,
        "summary": summary,
    }


def main(argv: list[str] | None = None) -> None:
    args = parse_args(argv)
    result = merge_runs(args)
    print(json.dumps(result["summary"], indent=2, ensure_ascii=False), flush=True)


if __name__ == "__main__":
    main()

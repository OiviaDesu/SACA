from __future__ import annotations

import argparse
import importlib.util
import json
import re
import sys
from pathlib import Path
from typing import Any, Callable

import pandas as pd

REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DATA_DIR = REPO_ROOT / "python_pipeline" / "data"
DEFAULT_OUTPUT = DEFAULT_DATA_DIR / "normalized_diagnosis_dataset.csv"
DEFAULT_MIN_CLASS_COUNT = 2


def normalize_text(value: object) -> str:
    if pd.isna(value):
        return ""
    return " ".join(str(value).split())


def normalize_label(value: object) -> str:
    return normalize_text(value).casefold()


def extract_user_turns(value: object) -> str:
    if pd.isna(value):
        return ""

    text = str(value)
    user_turns = re.findall(
        r"User:\s*(.*?)(?=(?:</s>\s*(?:User|Bot):)|$)",
        text,
        flags=re.IGNORECASE | re.DOTALL,
    )
    if user_turns:
        return normalize_text(" ".join(user_turns))
    return normalize_text(text)


def load_gretel(path: Path) -> pd.DataFrame:
    df = pd.read_csv(path)
    out = pd.DataFrame(
        {
            "symptoms_text": df["input_text"].map(normalize_text),
            "diagnosis_label": df["output_text"].map(normalize_label),
            "source": "gretel_symptom_to_diagnosis",
            "language": "english",
        }
    )
    return out


def load_symptom2disease(path: Path) -> pd.DataFrame:
    df = pd.read_csv(path)
    out = pd.DataFrame(
        {
            "symptoms_text": df["text"].map(normalize_text),
            "diagnosis_label": df["label"].map(normalize_label),
            "source": "symptom2disease",
            "language": "english",
        }
    )
    return out


def load_healthcare(path: Path) -> pd.DataFrame:
    df = pd.read_csv(path)
    out = pd.DataFrame(
        {
            "symptoms_text": df["Symptoms"].map(normalize_text),
            "diagnosis_label": df["Disease"].map(normalize_label),
            "source": "healthcare_structured",
            "language": "english",
            "age": pd.to_numeric(df["Age"], errors="coerce"),
            "gender": df["Gender"].map(normalize_text),
            "symptom_count": pd.to_numeric(df["Symptom_Count"], errors="coerce"),
        }
    )
    return out


def load_medical_conversations(path: Path) -> pd.DataFrame:
    df = pd.read_csv(path)
    out = pd.DataFrame(
        {
            "symptoms_text": df["conversations"].map(extract_user_turns),
            "diagnosis_label": df["disease"].map(normalize_label),
            "source": "medical_conversations",
            "language": "english",
        }
    )
    return out


def load_prebuilt_normalized(path: Path) -> pd.DataFrame:
    df = pd.read_csv(path)
    if "symptoms_text" not in df.columns or "diagnosis_label" not in df.columns:
        raise ValueError(
            f"{path.name} must contain symptoms_text and diagnosis_label columns to be used as a prebuilt dataset."
        )

    out = df.copy()
    out["symptoms_text"] = out["symptoms_text"].map(normalize_text)
    out["diagnosis_label"] = out["diagnosis_label"].map(normalize_label)
    if "source" not in out.columns:
        out["source"] = path.stem
    if "language" not in out.columns:
        out["language"] = "unknown"
    return out


SUPPORTED_DATASET_LOADERS: dict[str, Callable[[Path], pd.DataFrame]] = {
    "gretel_symptom_to_diagnosis.csv": load_gretel,
    "Symptom2Disease.csv": load_symptom2disease,
    "Healthcare.csv": load_healthcare,
    "medical_conversations.csv": load_medical_conversations,
    "normalized_diagnosis_dataset.csv": load_prebuilt_normalized,
}


def load_train_classifier_module() -> Any:
    module_name = "saca_train_classifier_for_dataset_build"
    if module_name in sys.modules:
        return sys.modules[module_name]

    script_path = Path(__file__).with_name("train_classifier.py")
    spec = importlib.util.spec_from_file_location(module_name, script_path)
    module = importlib.util.module_from_spec(spec)
    assert spec and spec.loader is not None
    sys.modules[module_name] = module
    spec.loader.exec_module(module)
    return module


def default_input_paths(
    data_dir: Path,
    *,
    include_healthcare: bool = False,
    include_medical_conversations: bool = False,
    include_prebuilt_normalized: bool = False,
) -> list[Path]:
    file_names = [
        "gretel_symptom_to_diagnosis.csv",
        "Symptom2Disease.csv",
    ]

    if include_healthcare:
        file_names.append("Healthcare.csv")
    if include_medical_conversations:
        file_names.append("medical_conversations.csv")
    if include_prebuilt_normalized:
        file_names.append("normalized_diagnosis_dataset.csv")

    return [data_dir / file_name for file_name in file_names if (data_dir / file_name).exists()]


def build_diagnosis_dataset(
    input_paths: list[Path],
    *,
    min_class_count: int = DEFAULT_MIN_CLASS_COUNT,
) -> tuple[pd.DataFrame, dict[str, Any]]:
    trainer = load_train_classifier_module()

    frames: list[pd.DataFrame] = []
    processed_files: list[dict[str, Any]] = []
    skipped_files: list[dict[str, Any]] = []

    for path in input_paths:
        if not path.exists():
            skipped_files.append({"file": str(path), "reason": "missing"})
            continue

        loader = SUPPORTED_DATASET_LOADERS.get(path.name)
        if loader is None:
            skipped_files.append({"file": str(path), "reason": "unsupported"})
            continue

        normalized = loader(path)
        normalized["source_file"] = path.name

        rows_loaded = len(normalized)
        normalized = normalized[normalized["symptoms_text"] != ""].copy()
        normalized = normalized[normalized["diagnosis_label"] != ""].copy()

        processed_files.append(
            {
                "file": str(path),
                "loader": loader.__name__,
                "rows_loaded": int(rows_loaded),
                "rows_after_nonempty_filter": int(len(normalized)),
            }
        )

        if normalized.empty:
            skipped_files.append({"file": str(path), "reason": "empty_after_normalization"})
            continue

        frames.append(normalized)

    if not frames:
        raise FileNotFoundError("No supported diagnosis dataset files were available for intermediate dataset build.")

    combined = pd.concat(frames, ignore_index=True, sort=False)
    rows_before_combined_dedupe = len(combined)
    combined = combined.drop_duplicates(subset=["symptoms_text", "diagnosis_label", "source"]).copy()
    combined.reset_index(drop=True, inplace=True)

    train_ready_df, cleaning_summary = trainer.clean_training_frame(
        combined,
        "diagnosis_label",
        text_cols=["symptoms_text", "transcript_text"],
        categorical_cols=["body_location", "prior_medications", "language", "source"],
        numeric_cols=["duration_hours", "duration_days"],
        min_class_count=min_class_count,
        verbose=False,
    )

    summary = {
        "selected_input_paths": [str(path) for path in input_paths],
        "processed_files": processed_files,
        "skipped_files": skipped_files,
        "rows_before_combined_dedupe": int(rows_before_combined_dedupe),
        "rows_after_combined_dedupe": int(len(combined)),
        "combined_duplicate_rows_removed": int(rows_before_combined_dedupe - len(combined)),
        "rows_after_training_cleaning": int(len(train_ready_df)),
        "label_count": int(train_ready_df["diagnosis_label"].nunique()),
        "source_distribution": train_ready_df["source"].value_counts().to_dict(),
        "cleaning_summary": cleaning_summary,
    }
    return train_ready_df, summary


def save_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="Normalize SACA diagnosis datasets into common CSV schema.")
    parser.add_argument("--data-dir", default=str(DEFAULT_DATA_DIR))
    parser.add_argument(
        "--input-paths",
        nargs="*",
        help="Explicit dataset files to normalize and merge before training.",
    )
    parser.add_argument("--include-healthcare", action="store_true", help="Include 25k structured Healthcare dataset.")
    parser.add_argument(
        "--include-medical-conversations",
        action="store_true",
        help="Include medical_conversations.csv after stripping bot turns.",
    )
    parser.add_argument(
        "--include-prebuilt-normalized",
        action="store_true",
        help="Include normalized_diagnosis_dataset.csv in the build input list.",
    )
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT))
    parser.add_argument(
        "--summary-output",
        help="Optional JSON summary path. Defaults to <output>.summary.json",
    )
    parser.add_argument(
        "--min-class-count",
        type=int,
        default=DEFAULT_MIN_CLASS_COUNT,
        help="Drop labels with fewer than this many rows in the built intermediate dataset.",
    )
    args = parser.parse_args()

    data_dir = Path(args.data_dir)
    input_paths = [Path(path) for path in args.input_paths] if args.input_paths else default_input_paths(
        data_dir,
        include_healthcare=args.include_healthcare,
        include_medical_conversations=args.include_medical_conversations,
        include_prebuilt_normalized=args.include_prebuilt_normalized,
    )

    if not input_paths:
        raise FileNotFoundError("No supported source files found for intermediate diagnosis dataset build.")

    built_dataset, summary = build_diagnosis_dataset(
        input_paths,
        min_class_count=args.min_class_count,
    )

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    built_dataset.to_csv(output_path, index=False)

    summary_path = Path(args.summary_output) if args.summary_output else output_path.with_suffix(".summary.json")
    summary["output"] = str(output_path)
    summary["summary_output"] = str(summary_path)
    save_json(summary_path, summary)

    print(json.dumps(summary, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()

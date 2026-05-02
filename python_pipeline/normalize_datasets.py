from __future__ import annotations

import argparse
from pathlib import Path

import pandas as pd

REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DATA_DIR = REPO_ROOT / "python_pipeline" / "data"


def normalize_text(value: object) -> str:
    if pd.isna(value):
        return ""
    return " ".join(str(value).split())


def load_gretel(path: Path) -> pd.DataFrame:
    df = pd.read_csv(path)
    out = pd.DataFrame(
        {
            "symptoms_text": df["input_text"].map(normalize_text),
            "diagnosis_label": df["output_text"].map(normalize_text),
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
            "diagnosis_label": df["label"].map(normalize_text),
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
            "diagnosis_label": df["Disease"].map(normalize_text),
            "source": "healthcare_structured",
            "language": "english",
            "age": pd.to_numeric(df["Age"], errors="coerce"),
            "gender": df["Gender"].map(normalize_text),
            "symptom_count": pd.to_numeric(df["Symptom_Count"], errors="coerce"),
        }
    )
    return out


def main() -> None:
    parser = argparse.ArgumentParser(description="Normalize SACA diagnosis datasets into common CSV schema.")
    parser.add_argument("--data-dir", default=str(DEFAULT_DATA_DIR))
    parser.add_argument("--include-healthcare", action="store_true", help="Include 25k structured Healthcare dataset.")
    parser.add_argument("--output", default="python_pipeline/data/normalized_diagnosis_dataset.csv")
    args = parser.parse_args()

    data_dir = Path(args.data_dir)
    frames = []

    gretel_path = data_dir / "gretel_symptom_to_diagnosis.csv"
    symptom2disease_path = data_dir / "Symptom2Disease.csv"
    healthcare_path = data_dir / "Healthcare.csv"

    if gretel_path.exists():
        frames.append(load_gretel(gretel_path))
    if symptom2disease_path.exists():
        frames.append(load_symptom2disease(symptom2disease_path))
    if args.include_healthcare and healthcare_path.exists():
        frames.append(load_healthcare(healthcare_path))

    if not frames:
        raise FileNotFoundError("No supported source files found in data dir.")

    combined = pd.concat(frames, ignore_index=True)
    combined = combined[combined["symptoms_text"] != ""].copy()
    combined = combined[combined["diagnosis_label"] != ""].copy()
    combined.to_csv(args.output, index=False)

    print({
        "output": str(Path(args.output)),
        "rows": int(len(combined)),
        "sources": combined["source"].value_counts().to_dict(),
        "labels": int(combined["diagnosis_label"].nunique()),
    })


if __name__ == "__main__":
    main()

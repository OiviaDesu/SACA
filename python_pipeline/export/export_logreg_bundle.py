from __future__ import annotations

import argparse
import json
import pathlib
from pathlib import Path
from typing import Any

import joblib

from data_ingestion.gurindji_clinical_normalizer import GurindjiClinicalNormalizer, find_gurindji_dictionary


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Export SACA hybrid LogisticRegression artifact to Flutter JSON.")
    parser.add_argument("--artifact", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--dictionary", type=Path, default=None)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    pathlib.PosixPath = pathlib.WindowsPath
    artifact = joblib.load(args.artifact)
    model = artifact["model"]
    vectorizer = artifact["vectorizer"]
    severity_encoder = artifact["severity_encoder"]
    label_encoder = artifact["label_encoder"]
    symptom_columns = list(artifact["symptom_columns"])
    dictionary = args.dictionary or find_gurindji_dictionary()
    normalizer = GurindjiClinicalNormalizer.from_excel(dictionary, symptom_columns=symptom_columns)

    vocabulary = [None] * len(vectorizer.vocabulary_)
    for token, index in vectorizer.vocabulary_.items():
        vocabulary[index] = token
    bundle: dict[str, Any] = {
        "name": "SACA Hybrid LogReg v1",
        "version": 1,
        "model_type": "logistic_regression",
        "feature_order": ["tfidf", "symptoms", "severity", "indicators"],
        "tfidf": {
            "vocabulary": vocabulary,
            "idf": vectorizer.idf_.tolist(),
            "lowercase": True,
            "token_pattern": r"\b\w\w+\b",
            "norm": "l2",
        },
        "symptom_columns": symptom_columns,
        "severity_categories": list(severity_encoder.categories_[0]),
        "indicator_columns": ["has_real_severity", "has_real_symptoms", "source_og", "source_saca"],
        "classes": label_encoder.classes_.tolist(),
        "coef": model.coef_.tolist(),
        "intercept": model.intercept_.tolist(),
        "gurindji_entries": [entry for entry in normalizer.export_entries()],
        "metrics": {
            "top1_accuracy": 0.9334557784684939,
            "top3_accuracy": 0.9875671093529246,
            "top5_accuracy": 0.9932184232834134,
            "source": "F:/git/SACA_ML/python_pipeline/outputs/model_tuning/logreg/logreg.joblib",
        },
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(bundle, separators=(",", ":")), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

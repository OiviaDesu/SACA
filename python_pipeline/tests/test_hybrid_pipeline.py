from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

import pandas as pd

PIPELINE_ROOT = Path(__file__).resolve().parents[1]
DATASET_PATH = PIPELINE_ROOT / "data_ingestion" / "hybrid_datasets.py"
TRAIN_PATH = PIPELINE_ROOT / "training" / "hybrid_mlp.py"
GURINDJI_PATH = PIPELINE_ROOT / "data_ingestion" / "gurindji_clinical_normalizer.py"

DATASET_SPEC = importlib.util.spec_from_file_location("hybrid_datasets", DATASET_PATH)
hybrid_datasets = importlib.util.module_from_spec(DATASET_SPEC)
assert DATASET_SPEC.loader is not None
sys.modules["hybrid_datasets"] = hybrid_datasets
sys.modules["data_ingestion.hybrid_datasets"] = hybrid_datasets
DATASET_SPEC.loader.exec_module(hybrid_datasets)

TRAIN_SPEC = importlib.util.spec_from_file_location("hybrid_mlp", TRAIN_PATH)
hybrid_mlp = importlib.util.module_from_spec(TRAIN_SPEC)
assert TRAIN_SPEC.loader is not None
sys.modules[TRAIN_SPEC.name] = hybrid_mlp
TRAIN_SPEC.loader.exec_module(hybrid_mlp)

GURINDJI_SPEC = importlib.util.spec_from_file_location("gurindji_clinical_normalizer", GURINDJI_PATH)
gurindji_normalizer = importlib.util.module_from_spec(GURINDJI_SPEC)
assert GURINDJI_SPEC.loader is not None
sys.modules[GURINDJI_SPEC.name] = gurindji_normalizer
sys.modules["data_ingestion.gurindji_clinical_normalizer"] = gurindji_normalizer
GURINDJI_SPEC.loader.exec_module(gurindji_normalizer)


def test_prepare_hybrid_data_writes_inventory():
    inventory = hybrid_datasets.prepare_hybrid_data(PIPELINE_ROOT)

    assert inventory["files"]
    assert (PIPELINE_ROOT / "data" / "raw" / "text" / "Symptom2Disease.csv").exists()
    assert (PIPELINE_ROOT / "data" / "raw" / "structured" / "saca_custom.xlsx").exists()
    assert (PIPELINE_ROOT / "data" / "processed" / "hybrid" / "dataset_inventory.json").exists()


def test_load_hybrid_dataset_schema():
    dataset = hybrid_datasets.load_hybrid_dataset(
        PIPELINE_ROOT / "data",
        min_class_count=10,
        sample_per_class=2,
    )

    assert len(dataset.frame) > 0
    assert dataset.symptom_columns
    assert {"text_input", "disease_label", "Severity", "source_type"}.issubset(dataset.frame.columns)
    assert dataset.inventory["symptom_columns"] == len(dataset.symptom_columns)


def test_build_hybrid_features_rows_match_labels():
    dataset = hybrid_datasets.load_hybrid_dataset(
        PIPELINE_ROOT / "data",
        min_class_count=10,
        sample_per_class=2,
    )
    train_frame = dataset.frame.iloc[:-2].copy()
    eval_frame = dataset.frame.iloc[-2:].copy()

    X_train, X_eval, metadata = hybrid_datasets.build_hybrid_features(
        train_frame,
        eval_frame,
        dataset.symptom_columns,
        max_text_features=100,
    )

    assert X_train.shape[0] == len(train_frame)
    assert X_eval is not None
    assert X_eval.shape[0] == len(eval_frame)
    assert metadata["feature_counts"]["symptoms"] == len(dataset.symptom_columns)
    assert metadata["feature_counts"]["missing_flags"] == 4


def test_text_rows_infer_severity_and_symptoms():
    text = pd.Series(["severe chest pain with shortness of breath"])

    assert hybrid_datasets.infer_severity_from_text(text.iloc[0]) == "severe"
    inferred = hybrid_datasets.infer_symptoms_from_text(text, ["chest pain", "shortness of breath"])

    assert inferred.tolist() == [[1.0, 1.0]]


def test_structured_rows_generate_leakage_safe_text_proxy():
    row = pd.Series({"Severity": "Severe", "cough": 1, "fever": 1, "diseases": "flu"})

    text = hybrid_datasets.symptoms_to_text(row, ["cough", "fever", "sore throat"])

    assert "severity severe symptoms cough fever" == text
    assert "flu" not in text


def test_indicator_flags_differ_by_source():
    frame = pd.DataFrame(
        [
            {"source_type": "text"},
            {"source_type": "structured", "has_real_severity": 1, "has_real_symptoms": 1, "source_saca": 1},
        ]
    )

    matrix = hybrid_datasets.indicator_matrix(frame).toarray().tolist()

    assert matrix[0] == [0.0, 0.0, 0.0, 0.0]
    assert matrix[1] == [1.0, 1.0, 0.0, 1.0]


def test_gurindji_normalizer_maps_symptom_and_body_terms():
    entries = pd.DataFrame(
        [
            {"gurindji": "kulyurrk ma-", "english": "to cough", "type": "symptom"},
            {"gurindji": "mangarli", "english": "the chest", "type": "body"},
        ]
    )
    normalizer = gurindji_normalizer.GurindjiClinicalNormalizer(entries, symptom_columns=["cough", "sharp chest pain"])

    result = normalizer.normalize("kulyurrk mangarli")

    assert result.matched_symptom_ids == ("cough",)
    assert result.matched_body_ids == ("chest",)
    assert "cough" in result.normalized_text
    assert "chest" in result.normalized_text


def test_gurindji_normalizer_ignores_unknown_words():
    entries = pd.DataFrame([{"gurindji": "kulyurrk ma-", "english": "to cough", "type": "symptom"}])
    normalizer = gurindji_normalizer.GurindjiClinicalNormalizer(entries, symptom_columns=["cough"])

    result = normalizer.normalize("unknown words")

    assert result.matched_symptom_ids == ()
    assert result.matched_body_ids == ()
    assert result.normalized_text == "unknown words"


def test_gurindji_synthetic_text_does_not_add_disease_label():
    entries = pd.DataFrame([{"gurindji": "kulyurrk ma-", "english": "to cough", "type": "symptom"}])
    normalizer = gurindji_normalizer.GurindjiClinicalNormalizer(entries, symptom_columns=["cough"])

    text = normalizer.synthetic_gurindji_text("severity mild symptoms cough")

    assert "kulyurrk" in text
    assert "pneumonia" not in text


def test_smoke_train_saves_and_predicts(tmp_path):
    output = tmp_path / "hybrid_mlp.joblib"

    code = hybrid_mlp.main(
        [
            "smoke",
            "--data-root",
            str(PIPELINE_ROOT / "data"),
            "--output",
            str(output),
            "--min-class-count",
            "10",
            "--sample-per-class",
            "4",
            "--max-text-features",
            "100",
            "--max-iter",
            "10",
            "--hidden-layers",
            "32",
        ]
    )

    assert code == 0
    assert output.exists()
    predictions = hybrid_mlp.predict_command(
        output,
        "fever cough sore throat",
        severity="unknown",
        symptoms=[],
        top_k=3,
    )
    assert len(predictions) == 3
    assert all("label" in item and "probability" in item for item in predictions)


import importlib.util
import json
import sys
from pathlib import Path

import pandas as pd


SCRIPT_PATH = Path(__file__).resolve().parents[1] / "normalize_datasets.py"
SPEC = importlib.util.spec_from_file_location("normalize_datasets", SCRIPT_PATH)
normalizer = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
sys.modules[SPEC.name] = normalizer
SPEC.loader.exec_module(normalizer)


def test_load_medical_conversations_uses_user_turns_only(tmp_path):
    path = tmp_path / "medical_conversations.csv"
    pd.DataFrame(
        [
            {
                "conversations": (
                    "User: I feel itchy today </s> Bot: This sounds like allergy. </s> "
                    "User: rash on my arm too </s> Bot: You should seek help."
                ),
                "disease": "Allergy",
            }
        ]
    ).to_csv(path, index=False)

    loaded = normalizer.load_medical_conversations(path)

    assert loaded["symptoms_text"].iloc[0] == "I feel itchy today rash on my arm too"
    assert "Bot:" not in loaded["symptoms_text"].iloc[0]
    assert loaded["diagnosis_label"].iloc[0] == "allergy"


def test_build_diagnosis_dataset_creates_training_ready_rows(tmp_path):
    gretel_path = tmp_path / "gretel_symptom_to_diagnosis.csv"
    symptom2disease_path = tmp_path / "Symptom2Disease.csv"
    medical_conversations_path = tmp_path / "medical_conversations.csv"

    pd.DataFrame(
        [
            {"input_text": "itchy arm rash", "output_text": "Dermatitis"},
            {"input_text": "patchy skin rash", "output_text": "dermatitis"},
            {"input_text": "high fever and cough", "output_text": "Flu"},
            {"input_text": "body aches and fever", "output_text": "flu"},
        ]
    ).to_csv(gretel_path, index=False)

    pd.DataFrame(
        [
            {"Unnamed: 0": 0, "label": "Dermatitis", "text": "itchy arm rash"},
            {"Unnamed: 0": 1, "label": "Flu", "text": "high fever and cough"},
            {"Unnamed: 0": 2, "label": "Flu", "text": "chills and body aches"},
            {"Unnamed: 0": 3, "label": "Dermatitis", "text": "red rash on leg"},
        ]
    ).to_csv(symptom2disease_path, index=False)

    pd.DataFrame(
        [
            {
                "conversations": "User: itchy skin all day </s> Bot: maybe dermatitis </s> User: red patches on my hands",
                "disease": "Dermatitis",
            },
            {
                "conversations": "User: I have chills and a fever </s> Bot: maybe flu </s> User: cough too",
                "disease": "Flu",
            },
        ]
    ).to_csv(medical_conversations_path, index=False)

    built, summary = normalizer.build_diagnosis_dataset(
        [gretel_path, symptom2disease_path, medical_conversations_path],
        min_class_count=2,
    )

    assert len(built) == 10
    assert set(built["diagnosis_label"].unique()) == {"dermatitis", "flu"}
    assert summary["combined_duplicate_rows_removed"] == 0
    assert summary["rows_after_training_cleaning"] == 10
    assert summary["source_distribution"] == {
        "gretel_symptom_to_diagnosis": 4,
        "symptom2disease": 4,
        "medical_conversations": 2,
    }


def test_main_writes_intermediate_dataset_and_summary(tmp_path):
    gretel_path = tmp_path / "gretel_symptom_to_diagnosis.csv"
    symptom2disease_path = tmp_path / "Symptom2Disease.csv"
    output_path = tmp_path / "diagnosis_multi_dataset.csv"
    summary_path = tmp_path / "diagnosis_multi_dataset.summary.json"

    pd.DataFrame(
        [
            {"input_text": "itchy arm rash", "output_text": "Dermatitis"},
            {"input_text": "patchy skin rash", "output_text": "dermatitis"},
            {"input_text": "high fever and cough", "output_text": "Flu"},
            {"input_text": "body aches and fever", "output_text": "flu"},
        ]
    ).to_csv(gretel_path, index=False)
    pd.DataFrame(
        [
            {"Unnamed: 0": 0, "label": "Dermatitis", "text": "red rash on leg"},
            {"Unnamed: 0": 1, "label": "Flu", "text": "chills and body aches"},
        ]
    ).to_csv(symptom2disease_path, index=False)

    old_argv = sys.argv
    try:
        sys.argv = [
            str(SCRIPT_PATH),
            "--input-paths",
            str(gretel_path),
            str(symptom2disease_path),
            "--output",
            str(output_path),
            "--summary-output",
            str(summary_path),
        ]
        normalizer.main()
    finally:
        sys.argv = old_argv

    assert output_path.exists()
    assert summary_path.exists()

    built = pd.read_csv(output_path)
    summary = json.loads(summary_path.read_text(encoding="utf-8"))
    assert len(built) == 6
    assert summary["rows_after_training_cleaning"] == 6
    assert summary["source_distribution"] == {
        "gretel_symptom_to_diagnosis": 4,
        "symptom2disease": 2,
    }
    assert summary["output"] == str(output_path)
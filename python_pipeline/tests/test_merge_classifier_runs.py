import csv
import importlib.util
import json
import sys
from pathlib import Path


TRAIN_SCRIPT_PATH = Path(__file__).resolve().parents[1] / "train_classifier.py"
sys.path.insert(0, str(TRAIN_SCRIPT_PATH.parent))

TRAIN_SPEC = importlib.util.spec_from_file_location("train_classifier", TRAIN_SCRIPT_PATH)
trainer = importlib.util.module_from_spec(TRAIN_SPEC)
assert TRAIN_SPEC.loader is not None
sys.modules[TRAIN_SPEC.name] = trainer
TRAIN_SPEC.loader.exec_module(trainer)

MERGE_SCRIPT_PATH = Path(__file__).resolve().parents[1] / "merge_classifier_runs.py"
MERGE_SPEC = importlib.util.spec_from_file_location("merge_classifier_runs", MERGE_SCRIPT_PATH)
merge_runner = importlib.util.module_from_spec(MERGE_SPEC)
assert MERGE_SPEC.loader is not None
sys.modules[MERGE_SPEC.name] = merge_runner
MERGE_SPEC.loader.exec_module(merge_runner)


def _write_diagnosis_fixture(path: Path) -> None:
    rows = [
        {
            "symptoms_text": "dry cough and sore throat",
            "transcript_text": "dry cough sore throat",
            "body_location": "throat",
            "prior_medications": "none",
            "language": "english",
            "source": "test-fixture",
            "duration_hours": 12,
            "duration_days": 0,
            "diagnosis_label": "viral_infection",
        },
        {
            "symptoms_text": "fever and sore throat all day",
            "transcript_text": "fever sore throat",
            "body_location": "throat",
            "prior_medications": "paracetamol",
            "language": "english",
            "source": "test-fixture",
            "duration_hours": 24,
            "duration_days": 1,
            "diagnosis_label": "viral_infection",
        },
        {
            "symptoms_text": "cough body aches fever",
            "transcript_text": "cough fever body ache",
            "body_location": "whole body",
            "prior_medications": "paracetamol",
            "language": "english",
            "source": "test-fixture",
            "duration_hours": 48,
            "duration_days": 2,
            "diagnosis_label": "viral_infection",
        },
        {
            "symptoms_text": "runny nose cough and fever",
            "transcript_text": "runny nose fever cough",
            "body_location": "head",
            "prior_medications": "none",
            "language": "gurindji-kriol",
            "source": "test-fixture",
            "duration_hours": 30,
            "duration_days": 1,
            "diagnosis_label": "viral_infection",
        },
        {
            "symptoms_text": "itchy arm rash for two days",
            "transcript_text": "itchy arm rash",
            "body_location": "arm",
            "prior_medications": "antihistamine",
            "language": "english",
            "source": "test-fixture",
            "duration_hours": 36,
            "duration_days": 2,
            "diagnosis_label": "dermatitis",
        },
        {
            "symptoms_text": "small red rash on leg",
            "transcript_text": "red rash on leg",
            "body_location": "leg",
            "prior_medications": "none",
            "language": "english",
            "source": "test-fixture",
            "duration_hours": 18,
            "duration_days": 1,
            "diagnosis_label": "dermatitis",
        },
        {
            "symptoms_text": "skin itchy with patchy rash",
            "transcript_text": "itchy patch rash",
            "body_location": "arm",
            "prior_medications": "cream",
            "language": "gurindji",
            "source": "test-fixture",
            "duration_hours": 60,
            "duration_days": 3,
            "diagnosis_label": "dermatitis",
        },
        {
            "symptoms_text": "rash but no fever or cough",
            "transcript_text": "just rash no fever",
            "body_location": "whole body",
            "prior_medications": "none",
            "language": "gurindji-kriol",
            "source": "test-fixture",
            "duration_hours": 20,
            "duration_days": 1,
            "diagnosis_label": "dermatitis",
        },
    ]
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)


def test_merge_classifier_runs_creates_combined_leaderboard(tmp_path):
    dataset_path = tmp_path / "diagnosis_fixture.csv"
    lr_dir = tmp_path / "lr_run"
    xgb_dir = tmp_path / "xgb_run"
    merged_dir = tmp_path / "merged"
    _write_diagnosis_fixture(dataset_path)

    trainer.main(
        [
            "--data",
            str(dataset_path),
            "--label-col",
            "diagnosis_label",
            "--task",
            "diagnosis",
            "--model",
            "lr",
            "--cv-folds",
            "2",
            "--tuning-profile",
            "quick",
            "--skip-shap",
            "--test-size",
            "0.25",
            "--output-dir",
            str(lr_dir),
        ]
    )

    trainer.main(
        [
            "--data",
            str(dataset_path),
            "--label-col",
            "diagnosis_label",
            "--task",
            "diagnosis",
            "--model",
            "xgb",
            "--cv-folds",
            "2",
            "--tuning-profile",
            "quick",
            "--xgb-device",
            "cpu",
            "--skip-shap",
            "--test-size",
            "0.25",
            "--output-dir",
            str(xgb_dir),
        ]
    )

    merge_runner.main(
        [
            "--lr-dir",
            str(lr_dir),
            "--xgb-dir",
            str(xgb_dir),
            "--output-dir",
            str(merged_dir),
            "--scope-name",
            "single",
        ]
    )

    metrics = json.loads((merged_dir / "metrics.json").read_text(encoding="utf-8"))
    summary = json.loads((merged_dir / "run_summary.json").read_text(encoding="utf-8"))

    assert len(metrics["leaderboard"]) == 2
    assert metrics["best_model"] in {"logistic_regression", "xgboost"}
    assert (merged_dir / "best_model.joblib").exists()
    assert (merged_dir / "logistic_regression.joblib").exists()
    assert (merged_dir / "xgboost.joblib").exists()
    assert summary["scope"] == "single"

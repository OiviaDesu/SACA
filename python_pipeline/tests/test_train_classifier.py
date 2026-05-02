import csv
import importlib.util
import json
import sys
from pathlib import Path


SCRIPT_PATH = Path(__file__).resolve().parents[1] / "train_classifier.py"
SPEC = importlib.util.spec_from_file_location("train_classifier", SCRIPT_PATH)
trainer = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
sys.modules[SPEC.name] = trainer
SPEC.loader.exec_module(trainer)

SAMPLE_TRIAGE_DATASET = Path(__file__).resolve().parents[1] / "sample_triage_dataset.csv"


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


def test_verbose_severity_smoke_run_prints_progress_and_writes_artifacts(tmp_path, capsys):
    output_dir = tmp_path / "severity_verbose"

    trainer.main(
        [
            "--data",
            str(SAMPLE_TRIAGE_DATASET),
            "--label-col",
            "severity_label",
            "--task",
            "severity",
            "--model",
            "lr",
            "--cv-folds",
            "2",
            "--test-size",
            "0.33",
            "--output-dir",
            str(output_dir),
            "--verbose",
        ]
    )

    captured = capsys.readouterr()
    assert "[load] Reading" in captured.out
    assert "[audit] Building dataset audit" in captured.out
    assert "=== Training logistic_regression ===" in captured.out
    assert "[train] logistic_regression: tuning finished." in captured.out
    assert "[artifacts] Wrote" in captured.out

    for artifact_name in [
        "dataset_audit.json",
        "label_metadata.json",
        "metrics.json",
        "best_model.joblib",
        "run_summary.json",
    ]:
        assert (output_dir / artifact_name).exists()

    summary = json.loads((output_dir / "run_summary.json").read_text(encoding="utf-8"))
    assert summary["best_model"] == "logistic_regression"


def test_default_run_stays_less_noisy_and_still_succeeds(tmp_path, capsys):
    dataset_path = tmp_path / "diagnosis_fixture.csv"
    output_dir = tmp_path / "diagnosis_default"
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
            "--test-size",
            "0.25",
            "--output-dir",
            str(output_dir),
        ]
    )

    captured = capsys.readouterr()
    assert "[load] Reading" not in captured.out
    assert "=== Training logistic_regression ===" in captured.out
    assert "=== Done ===" in captured.out
    assert (output_dir / "metrics.json").exists()
    assert (output_dir / "best_model.joblib").exists()
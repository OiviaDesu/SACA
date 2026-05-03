import csv
import importlib.util
import json
import sys
from pathlib import Path

import numpy as np
import pandas as pd


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


def test_parse_args_uses_balanced_speed_defaults():
    args = trainer.parse_args([
        "--data",
        "fixture.csv",
        "--label-col",
        "diagnosis_label",
    ])

    assert args.cv_folds == trainer.DEFAULT_CV_FOLDS
    assert args.max_text_features == trainer.DEFAULT_MAX_TEXT_FEATURES
    assert args.tuning_profile == trainer.DEFAULT_TUNING_PROFILE
    assert args.skip_shap is False
    assert args.live_progress is False
    assert args.progress_log_every_fits == 1


def test_quick_tuning_profile_reduces_xgb_grid_size():
    quick_grid = trainer.make_xgb_grid("quick", trainer.DEFAULT_MAX_TEXT_FEATURES)
    balanced_grid = trainer.make_xgb_grid("balanced", trainer.DEFAULT_MAX_TEXT_FEATURES)
    full_grid = trainer.make_xgb_grid("full", trainer.DEFAULT_MAX_TEXT_FEATURES)

    assert trainer.count_grid_combinations(quick_grid) < trainer.count_grid_combinations(balanced_grid)
    assert trainer.count_grid_combinations(balanced_grid) < trainer.count_grid_combinations(full_grid)
    assert quick_grid["features__text__max_features"] == [trainer.DEFAULT_MAX_TEXT_FEATURES]
    assert balanced_grid["features__text__ngram_range"] == [(3, 5)]


def test_clean_labels_merges_case_variants_before_min_class_filter():
    df = pd.DataFrame(
        {
            "diagnosis_label": ["Psoriasis", "psoriasis", "Migraine"],
        }
    )

    cleaned = trainer.clean_labels(df, "diagnosis_label", min_class_count=2)

    assert cleaned["diagnosis_label"].tolist() == ["psoriasis", "psoriasis"]


def test_clean_training_frame_removes_duplicate_rows_and_reports_sources():
    df = pd.DataFrame(
        [
            {
                "symptoms_text": " itchy arm rash ",
                "diagnosis_label": "Dermatitis",
                "language": "English",
                "source": "fixture",
                "source_file": "a.csv",
            },
            {
                "symptoms_text": "itchy arm rash",
                "diagnosis_label": "dermatitis",
                "language": "english",
                "source": "fixture",
                "source_file": "b.csv",
            },
            {
                "symptoms_text": "patchy skin rash",
                "diagnosis_label": "dermatitis",
                "language": "english",
                "source": "fixture",
                "source_file": "a.csv",
            },
            {
                "symptoms_text": "fever and cough",
                "diagnosis_label": "Flu",
                "language": "English",
                "source": "fixture",
                "source_file": "a.csv",
            },
            {
                "symptoms_text": "fever and cough",
                "diagnosis_label": "flu",
                "language": "English",
                "source": "fixture",
                "source_file": "a.csv",
            },
            {
                "symptoms_text": "high fever and chills",
                "diagnosis_label": "flu",
                "language": "english",
                "source": "fixture",
                "source_file": "a.csv",
            },
        ]
    )

    cleaned, summary = trainer.clean_training_frame(
        df,
        "diagnosis_label",
        text_cols=["symptoms_text", "transcript_text"],
        categorical_cols=["language", "source"],
        numeric_cols=[],
        min_class_count=2,
    )

    assert len(cleaned) == 4
    assert cleaned["diagnosis_label"].tolist() == ["dermatitis", "dermatitis", "flu", "flu"]
    assert summary["duplicate_rows_removed"] == 2
    assert summary["source_file_rows_before_cleaning"] == {"a.csv": 5, "b.csv": 1}
    assert summary["source_file_rows_after_cleaning"] == {"a.csv": 4}
    assert summary["dropped_source_files_after_cleaning"] == ["b.csv"]


def test_fit_search_live_progress_emits_fold_metrics(capsys):
    X_train = pd.DataFrame(
        {
            "combined_text": [
                "dry cough fever",
                "sore throat fever",
                "cough chills fever",
                "itchy arm rash",
                "red skin rash",
                "skin irritation itch",
            ],
            "language": ["english"] * 6,
            "source": ["fixture"] * 6,
            "text_char_len": [15, 17, 18, 14, 13, 20],
            "text_word_len": [3, 3, 3, 3, 3, 3],
        }
    )
    y_train = np.array([0, 0, 0, 1, 1, 1])

    pipeline = trainer.build_lr_pipeline(
        categorical_cols=["language", "source"],
        numeric_cols=["text_char_len", "text_word_len"],
        max_text_features=100,
        random_state=42,
    )
    grid = {
        "features__text__ngram_range": [(3, 5)],
        "features__text__max_features": [100],
        "clf__C": [0.3, 1.0],
    }

    search = trainer.fit_search(
        name="logistic_regression",
        pipeline=pipeline,
        grid=grid,
        X_train=X_train,
        y_train=y_train,
        cv_folds=2,
        random_state=42,
        verbose=False,
        live_progress=True,
        progress_log_every_fits=1,
    )

    captured = capsys.readouterr()
    assert "[progress] logistic_regression" in captured.out
    assert "val_f1=" in captured.out
    assert "val_acc=" in captured.out
    assert search.best_params_["clf__C"] in {0.3, 1.0}
    assert len(search.candidate_summaries) == 2
    assert len(search.cv_results_["params"]) == 2
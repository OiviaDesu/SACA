import csv
import importlib.util
import json
import math
import sys
from pathlib import Path

import joblib
import numpy as np
from sklearn.feature_extraction.text import CountVectorizer
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder


TRAIN_SCRIPT_PATH = Path(__file__).resolve().parents[1] / "train_classifier.py"
sys.path.insert(0, str(TRAIN_SCRIPT_PATH.parent))
TRAIN_SPEC = importlib.util.spec_from_file_location("train_classifier", TRAIN_SCRIPT_PATH)
trainer = importlib.util.module_from_spec(TRAIN_SPEC)
assert TRAIN_SPEC.loader is not None
sys.modules[TRAIN_SPEC.name] = trainer
TRAIN_SPEC.loader.exec_module(trainer)

BUNDLE_SCRIPT_PATH = Path(__file__).resolve().parents[1] / "xgb_flutter_bundle.py"
BUNDLE_SPEC = importlib.util.spec_from_file_location(
    "xgb_flutter_bundle", BUNDLE_SCRIPT_PATH
)
bundle_runner = importlib.util.module_from_spec(BUNDLE_SPEC)
assert BUNDLE_SPEC.loader is not None
sys.modules[BUNDLE_SPEC.name] = bundle_runner
BUNDLE_SPEC.loader.exec_module(bundle_runner)


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


def test_char_wb_ngrams_matches_sklearn_analyzer():
    analyzer = CountVectorizer(analyzer="char_wb", ngram_range=(3, 5)).build_analyzer()
    text = "Head ache"

    assert bundle_runner.char_wb_ngrams(text, min_n=3, max_n=5) == analyzer(text)


def test_patch_m2cgen_multiclass_code_replaces_placeholders_in_order():
    original = "return softmax([nan + (var0), nan + (var1), nan + (var2)])"

    patched = bundle_runner.patch_m2cgen_multiclass_code(
        original,
        [-1.25, 0.5, 2.75],
    )

    assert patched == (
        "return softmax([(-1.25) + (var0), (0.5) + (var1), (2.75) + (var2)])"
    )


def test_select_best_generated_probability_candidate_prefers_binary_margin_sigmoid():
    pipeline_probabilities = np.asarray(
        [
            [0.8, 0.2],
            [0.1, 0.9],
        ],
        dtype=float,
    )
    raw_margin_outputs = [
        math.log(0.2 / 0.8),
        math.log(0.9 / 0.1),
    ]

    selected_interpretation, generated_probabilities, candidate_reports, raw_matrix = (
        bundle_runner.select_best_generated_probability_candidate(
            pipeline_probabilities,
            raw_margin_outputs,
            objective_name="binary:logistic",
            class_count=2,
        )
    )

    assert selected_interpretation == "scalar_margin_sigmoid"
    assert raw_matrix.shape == (2, 1)
    assert candidate_reports["scalar_margin_sigmoid"]["max_abs_diff"] < 1e-9
    np.testing.assert_allclose(generated_probabilities, pipeline_probabilities, atol=1e-9)


def test_export_m2cgen_source_supports_binary_xgboost_when_base_score_is_missing(tmp_path):
    dataset_path = tmp_path / "diagnosis_fixture.csv"
    output_dir = tmp_path / "xgb_run"
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
            str(output_dir),
        ]
    )

    pipeline = joblib.load(output_dir / "best_model.joblib")
    scorer_code = bundle_runner.export_m2cgen_source(
        pipeline.named_steps["clf"],
        language="python",
    )
    namespace: dict[str, object] = {}
    exec(scorer_code, namespace)
    assert "score" in namespace


def test_bundle_runtime_matches_quick_xgb_fixture(tmp_path):
    dataset_path = tmp_path / "diagnosis_fixture.csv"
    output_dir = tmp_path / "xgb_run"
    bundle_dir = tmp_path / "bundle"
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
            str(output_dir),
        ]
    )

    bundle_runner.export_xgb_flutter_bundle(output_dir, bundle_dir)
    bundle = bundle_runner.load_bundle(bundle_dir)
    pipeline = joblib.load(output_dir / "best_model.joblib")

    raw_df = trainer.load_dataset([str(dataset_path)], verbose=False)
    cleaned_df, _summary = trainer.clean_training_frame(
        raw_df,
        "diagnosis_label",
        ["symptoms_text", "transcript_text"],
        ["body_location", "prior_medications", "language", "source"],
        ["duration_hours", "duration_days"],
        min_class_count=2,
        verbose=False,
    )
    processed_df, text_cols, categorical_cols, numeric_cols = trainer.add_derived_features(
        cleaned_df,
        ["symptoms_text", "transcript_text"],
        ["body_location", "prior_medications", "language", "source"],
        ["duration_hours", "duration_days"],
    )
    feature_df = processed_df[[*text_cols, *categorical_cols, *numeric_cols]].copy()
    y = LabelEncoder().fit_transform(processed_df["diagnosis_label"])
    _x_train, x_test, _y_train, _y_test = train_test_split(
        feature_df,
        y,
        test_size=0.25,
        random_state=42,
        stratify=y,
    )
    x_test = x_test.reset_index(drop=True)

    report = bundle_runner.compare_pipeline_and_bundle(bundle, pipeline, x_test)
    assert report["top1_agreement"] == 1.0
    assert report["max_abs_diff"] < 1e-6

    first_record = bundle_runner.record_from_feature_row(
        x_test.to_dict(orient="records")[0],
        bundle,
    )
    dense_vector = bundle_runner.build_dense_feature_vector(bundle, first_record)
    assert len(dense_vector) == bundle["feature_count"]
    assert any(math.isnan(value) for value in dense_vector)

    export_summary = json.loads((bundle_dir / "export_summary.json").read_text())
    assert export_summary["class_count"] == 2

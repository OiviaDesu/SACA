from __future__ import annotations

import argparse
import json
import time
from dataclasses import dataclass
from math import prod
from pathlib import Path
from typing import Any

import joblib
import numpy as np
import pandas as pd
from sklearn.base import clone
from sklearn.compose import ColumnTransformer
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.impute import SimpleImputer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix, f1_score
from sklearn.model_selection import ParameterGrid, StratifiedKFold, train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import LabelEncoder, OneHotEncoder, StandardScaler

try:
    from xgboost import XGBClassifier
except ImportError:  # pragma: no cover
    XGBClassifier = None

try:
    import shap
except ImportError:  # pragma: no cover
    shap = None


DEFAULT_SEVERITY_ORDER = ["emergency", "urgent", "routine", "self-care"]
DEFAULT_CV_FOLDS = 3
DEFAULT_MAX_TEXT_FEATURES = 10000
DEFAULT_TUNING_PROFILE = "balanced"
FULL_TEXT_NGRAM_RANGE_SEARCH = [(3, 5), (2, 5)]


@dataclass
class TrainingArtifacts:
    name: str
    estimator: Pipeline
    metrics: dict[str, Any]
    predictions: np.ndarray
    probabilities: np.ndarray | None


@dataclass
class SearchResult:
    best_estimator_: Pipeline
    best_params_: dict[str, Any]
    best_score_: float
    cv_results_: dict[str, list[Any]]
    candidate_summaries: list[dict[str, Any]]


def emit_progress(message: str, *, verbose: bool, always: bool = False) -> None:
    if always or verbose:
        print(message, flush=True)


def unique_preserving_order(values: list[Any]) -> list[Any]:
    unique_values: list[Any] = []
    seen: set[Any] = set()
    for value in values:
        if value in seen:
            continue
        seen.add(value)
        unique_values.append(value)
    return unique_values


def format_elapsed(seconds: float) -> str:
    rounded = max(0, int(round(seconds)))
    hours, remainder = divmod(rounded, 3600)
    minutes, secs = divmod(remainder, 60)
    return f"{hours:02d}:{minutes:02d}:{secs:02d}"


def render_progress_bar(completed: int, total: int, width: int = 20) -> str:
    if total <= 0:
        return "[" + ("-" * width) + "]"
    ratio = min(1.0, max(0.0, completed / total))
    filled = min(width, int(round(ratio * width)))
    return "[" + ("#" * filled) + ("-" * (width - filled)) + "]"


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Train SACA triage/diagnosis classifiers from local CSV/JSON data."
    )
    parser.add_argument(
        "--data",
        nargs="+",
        required=True,
        help="One or more local CSV/JSON/JSONL files.",
    )
    parser.add_argument(
        "--text-cols",
        nargs="+",
        default=["symptoms_text", "transcript_text"],
        help="Columns merged into text feature.",
    )
    parser.add_argument(
        "--categorical-cols",
        nargs="*",
        default=["body_location", "prior_medications", "language", "source"],
        help="Categorical structured feature columns.",
    )
    parser.add_argument(
        "--numeric-cols",
        nargs="*",
        default=["duration_hours", "duration_days"],
        help="Numeric structured feature columns.",
    )
    parser.add_argument(
        "--label-col",
        required=True,
        help="Target column. Example: severity_label or diagnosis_label.",
    )
    parser.add_argument(
        "--task",
        choices=["severity", "diagnosis"],
        default="severity",
        help="Severity task writes ordered labels metadata. Diagnosis task writes free labels.",
    )
    parser.add_argument(
        "--output-dir",
        default="python_pipeline/outputs/classifier",
        help="Output folder for metrics and model artifacts.",
    )
    parser.add_argument(
        "--test-size",
        type=float,
        default=0.2,
        help="Held-out test size.",
    )
    parser.add_argument(
        "--random-state",
        type=int,
        default=42,
        help="Random seed.",
    )
    parser.add_argument(
        "--cv-folds",
        type=int,
        default=DEFAULT_CV_FOLDS,
        help="Cross-validation folds for tuning.",
    )
    parser.add_argument(
        "--model",
        choices=["lr", "xgb", "both"],
        default="both",
        help="Which models to train.",
    )
    parser.add_argument(
        "--xgb-device",
        choices=["cpu", "cuda"],
        default="cpu",
        help="XGBoost execution device. Use 'cuda' for GPU-enabled training.",
    )
    parser.add_argument(
        "--tuning-profile",
        choices=["quick", "balanced", "full"],
        default=DEFAULT_TUNING_PROFILE,
        help=(
            "Hyperparameter search budget. 'balanced' reduces XGBoost fit count for faster HPC runs; "
            "'full' restores the exhaustive grid."
        ),
    )
    parser.add_argument(
        "--export-onnx",
        action="store_true",
        help="Try ONNX export. Best effort only.",
    )
    parser.add_argument(
        "--max-text-features",
        type=int,
        default=DEFAULT_MAX_TEXT_FEATURES,
        help="Default max TF-IDF features before tuning.",
    )
    parser.add_argument(
        "--min-class-count",
        type=int,
        default=2,
        help="Drop labels with fewer than this many rows.",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Print progress messages and enable sklearn GridSearchCV chatter.",
    )
    parser.add_argument(
        "--skip-shap",
        action="store_true",
        help="Skip XGBoost SHAP feature ranking to shorten tuning runs.",
    )
    parser.add_argument(
        "--live-progress",
        action="store_true",
        help="Emit per-fit cross-validation progress lines with validation F1/accuracy.",
    )
    parser.add_argument(
        "--progress-log-every-fits",
        type=int,
        default=1,
        help="Emit live progress after every N completed CV fits.",
    )
    parser.add_argument(
        "--include-text-length-features",
        action="store_true",
        help="Add text_char_len/text_word_len numeric features. Disabled by default because unscaled text length hurt LR accuracy.",
    )
    return parser.parse_args(argv)


def load_table(path: str) -> pd.DataFrame:
    file_path = Path(path)
    suffix = file_path.suffix.lower()
    if suffix == ".csv":
        return pd.read_csv(file_path)
    if suffix == ".json":
        return pd.read_json(file_path)
    if suffix == ".jsonl":
        return pd.read_json(file_path, lines=True)
    raise ValueError(f"Unsupported file format: {file_path}")


def load_dataset(paths: list[str], verbose: bool = False) -> pd.DataFrame:
    frames: list[pd.DataFrame] = []
    for path in paths:
        emit_progress(f"[load] Reading {path}", verbose=verbose)
        frame = load_table(path)
        frame["source_file"] = Path(path).name
        emit_progress(
            f"[load] {Path(path).name}: {len(frame)} row(s), {len(frame.columns)} column(s)",
            verbose=verbose,
        )
        frames.append(frame)
    if not frames:
        raise ValueError("No dataset files loaded.")
    combined = pd.concat(frames, ignore_index=True)
    combined.columns = [str(col).strip() for col in combined.columns]
    emit_progress(
        f"[load] Combined {len(frames)} file(s) into {len(combined)} row(s).",
        verbose=verbose,
    )
    return combined


def detect_present_columns(df: pd.DataFrame, columns: list[str]) -> list[str]:
    return [col for col in columns if col in df.columns]


def normalize_text(value: Any) -> str:
    if pd.isna(value):
        return ""
    text = str(value).strip()
    if not text:
        return ""
    return " ".join(text.split())


def normalize_label(value: Any) -> str:
    return normalize_text(value).casefold()


def merge_text_columns(df: pd.DataFrame, text_cols: list[str]) -> pd.Series:
    if not text_cols:
        raise ValueError("Need at least one text column.")
    merged = df[text_cols].fillna("").astype(str).agg(" ".join, axis=1)
    return merged.map(normalize_text)


def normalize_language_tag(value: Any) -> str:
    text = normalize_text(value).lower()
    if not text:
        return "unknown"
    if "kriol" in text and "gurindji" in text:
        return "gurindji-kriol"
    if text in {"gk", "mixed", "mixed gurindji", "mixed_gurindji"}:
        return "gurindji-kriol"
    if "gurindji" in text:
        return "gurindji"
    if "english" in text or text == "en":
        return "english"
    return text


def add_derived_features(
    df: pd.DataFrame,
    text_cols: list[str],
    categorical_cols: list[str],
    numeric_cols: list[str],
    include_text_length_features: bool = False,
) -> tuple[pd.DataFrame, list[str], list[str], list[str]]:
    frame = df.copy()

    present_text_cols = detect_present_columns(frame, text_cols)
    if not present_text_cols:
        raise ValueError(
            f"None of text columns found: {text_cols}. Available: {list(frame.columns)}"
        )

    frame["combined_text"] = merge_text_columns(frame, present_text_cols)
    frame["text_char_len"] = frame["combined_text"].map(len)
    frame["text_word_len"] = frame["combined_text"].map(lambda x: len(x.split()))

    if "language" in frame.columns:
        frame["language"] = frame["language"].map(normalize_language_tag)
    else:
        frame["language"] = "unknown"

    if "source" not in frame.columns:
        frame["source"] = frame.get("source_file", "unknown")

    actual_categorical = detect_present_columns(frame, categorical_cols)
    if "language" not in actual_categorical:
        actual_categorical.append("language")
    if "source" not in actual_categorical:
        actual_categorical.append("source")

    actual_numeric = detect_present_columns(frame, numeric_cols)
    if include_text_length_features:
        for derived_numeric in ["text_char_len", "text_word_len"]:
            if derived_numeric not in actual_numeric:
                actual_numeric.append(derived_numeric)

    feature_columns = ["combined_text", *actual_categorical, *actual_numeric]
    return frame, ["combined_text"], actual_categorical, actual_numeric


def clean_labels(
    df: pd.DataFrame,
    label_col: str,
    min_class_count: int,
    verbose: bool = False,
) -> pd.DataFrame:
    frame = df.copy()
    original_rows = len(frame)
    frame[label_col] = frame[label_col].map(normalize_label)
    frame = frame[frame[label_col] != ""].copy()
    counts = frame[label_col].value_counts()
    keep_labels = counts[counts >= min_class_count].index
    frame = frame[frame[label_col].isin(keep_labels)].copy()
    frame.reset_index(drop=True, inplace=True)
    emit_progress(
        (
            f"[labels] Kept {len(frame)} of {original_rows} row(s) after cleaning "
            f"'{label_col}' with min_class_count={min_class_count}."
        ),
        verbose=verbose,
    )
    emit_progress(
        f"[labels] Remaining label distribution: {frame[label_col].value_counts().to_dict()}",
        verbose=verbose,
    )
    if frame.empty:
        raise ValueError("No rows left after label cleaning.")
    return frame


def deduplicate_training_rows(
    df: pd.DataFrame,
    label_col: str,
    text_cols: list[str],
    categorical_cols: list[str],
    numeric_cols: list[str],
    verbose: bool = False,
) -> tuple[pd.DataFrame, dict[str, Any]]:
    frame = df.copy()
    present_text_cols = detect_present_columns(frame, text_cols)
    present_categorical_cols = detect_present_columns(frame, categorical_cols)
    present_numeric_cols = detect_present_columns(frame, numeric_cols)

    dedupe_key = pd.DataFrame(index=frame.index)
    dedupe_key[label_col] = frame[label_col].map(normalize_label)

    for column in present_text_cols:
        dedupe_key[column] = frame[column].map(normalize_text)

    for column in present_categorical_cols:
        if column == "language":
            dedupe_key[column] = frame[column].map(normalize_language_tag)
        else:
            dedupe_key[column] = frame[column].map(normalize_text)

    for column in present_numeric_cols:
        dedupe_key[column] = pd.to_numeric(frame[column], errors="coerce")

    duplicate_mask = dedupe_key.duplicated(keep="first")
    duplicate_rows_removed = int(duplicate_mask.sum())

    if duplicate_rows_removed:
        frame = frame.loc[~duplicate_mask].copy()
        frame.reset_index(drop=True, inplace=True)
        emit_progress(
            (
                f"[clean] Removed {duplicate_rows_removed} duplicate row(s) using "
                f"columns {dedupe_key.columns.tolist()}."
            ),
            verbose=verbose,
            always=True,
        )

    return frame, {
        "duplicate_rows_removed": duplicate_rows_removed,
        "dedupe_columns": dedupe_key.columns.tolist(),
    }


def clean_training_frame(
    df: pd.DataFrame,
    label_col: str,
    text_cols: list[str],
    categorical_cols: list[str],
    numeric_cols: list[str],
    min_class_count: int,
    verbose: bool = False,
) -> tuple[pd.DataFrame, dict[str, Any]]:
    frame = df.copy()
    original_rows = len(frame)
    source_file_rows_before = (
        frame["source_file"].fillna("missing").astype(str).value_counts().to_dict()
        if "source_file" in frame.columns
        else None
    )

    frame[label_col] = frame[label_col].map(normalize_label)
    frame = frame[frame[label_col] != ""].copy()
    rows_after_nonempty_label = len(frame)

    frame, dedupe_summary = deduplicate_training_rows(
        frame,
        label_col,
        text_cols,
        categorical_cols,
        numeric_cols,
        verbose=verbose,
    )

    counts = frame[label_col].value_counts()
    keep_labels = counts[counts >= min_class_count].index
    dropped_labels = counts[counts < min_class_count].to_dict()
    frame = frame[frame[label_col].isin(keep_labels)].copy()
    frame.reset_index(drop=True, inplace=True)

    source_file_rows_after = (
        frame["source_file"].fillna("missing").astype(str).value_counts().to_dict()
        if "source_file" in frame.columns
        else None
    )
    dropped_source_files = (
        sorted(set(source_file_rows_before) - set(source_file_rows_after))
        if source_file_rows_before is not None and source_file_rows_after is not None
        else []
    )

    emit_progress(
        (
            f"[labels] Kept {len(frame)} of {original_rows} row(s) after cleaning '{label_col}' "
            f"with min_class_count={min_class_count}."
        ),
        verbose=verbose,
    )
    emit_progress(
        (
            f"[labels] Remaining rows after non-empty label filter: {rows_after_nonempty_label}; "
            f"duplicates removed: {dedupe_summary['duplicate_rows_removed']}."
        ),
        verbose=verbose,
    )
    emit_progress(
        f"[labels] Remaining label distribution: {frame[label_col].value_counts().to_dict()}",
        verbose=verbose,
    )
    if dropped_source_files:
        emit_progress(
            (
                "[labels] Warning: these input file(s) contributed 0 retained row(s) after cleaning: "
                f"{dropped_source_files}"
            ),
            verbose=verbose,
            always=True,
        )
    if frame.empty:
        raise ValueError("No rows left after label cleaning.")

    return frame, {
        "label_normalization": "normalize_text + casefold",
        "rows_before_cleaning": original_rows,
        "rows_after_nonempty_label": rows_after_nonempty_label,
        "rows_after_cleaning": int(len(frame)),
        "source_file_rows_before_cleaning": source_file_rows_before,
        "source_file_rows_after_cleaning": source_file_rows_after,
        "dropped_source_files_after_cleaning": dropped_source_files,
        "dropped_low_frequency_labels": dropped_labels,
        **dedupe_summary,
    }


def build_preprocessor(categorical_cols: list[str], numeric_cols: list[str], max_text_features: int) -> ColumnTransformer:
    transformers: list[tuple[str, Any, list[str] | str]] = [
        (
            "text",
            TfidfVectorizer(
                analyzer="char_wb",
                ngram_range=(3, 5),
                min_df=2,
                max_features=max_text_features,
                lowercase=True,
                strip_accents=None,
                sublinear_tf=True,
            ),
            "combined_text",
        )
    ]

    if categorical_cols:
        transformers.append(
            (
                "cat",
                Pipeline(
                    steps=[
                        (
                            "imputer",
                            SimpleImputer(strategy="constant", fill_value="missing"),
                        ),
                        (
                            "onehot",
                            OneHotEncoder(handle_unknown="ignore", sparse_output=True),
                        ),
                    ]
                ),
                categorical_cols,
            )
        )

    if numeric_cols:
        transformers.append(
            (
                "num",
                Pipeline(
                    steps=[
                        ("imputer", SimpleImputer(strategy="median")),
                        ("scaler", StandardScaler(with_mean=False)),
                    ]
                ),
                numeric_cols,
            )
        )

    return ColumnTransformer(transformers=transformers, remainder="drop", sparse_threshold=0.3)


def build_lr_pipeline(categorical_cols: list[str], numeric_cols: list[str], max_text_features: int, random_state: int) -> Pipeline:
    return Pipeline(
        steps=[
            (
                "features",
                build_preprocessor(categorical_cols, numeric_cols, max_text_features),
            ),
            (
                "clf",
                LogisticRegression(
                    max_iter=5000,
                    tol=1e-3,
                    class_weight="balanced",
                    solver="lbfgs",
                    random_state=random_state,
                ),
            ),
        ]
    )


def build_xgb_pipeline(
    categorical_cols: list[str],
    numeric_cols: list[str],
    max_text_features: int,
    random_state: int,
    num_classes: int,
    xgb_device: str,
) -> Pipeline:
    if XGBClassifier is None:
        raise ImportError("xgboost not installed. Run pip install -r python_pipeline/requirements/classifier.txt")
    objective = "multi:softprob" if num_classes > 2 else "binary:logistic"
    return Pipeline(
        steps=[
            (
                "features",
                build_preprocessor(categorical_cols, numeric_cols, max_text_features),
            ),
            (
                "clf",
                XGBClassifier(
                    objective=objective,
                    num_class=num_classes if num_classes > 2 else None,
                    eval_metric="mlogloss" if num_classes > 2 else "logloss",
                    tree_method="hist",
                    device=xgb_device,
                    n_estimators=300,
                    max_depth=6,
                    learning_rate=0.1,
                    subsample=0.9,
                    colsample_bytree=0.9,
                    reg_lambda=1.0,
                    random_state=random_state,
                ),
            ),
        ]
    )


def make_lr_grid(tuning_profile: str, max_text_features: int) -> dict[str, list[Any]]:
    if tuning_profile == "quick":
        return {
            "features__text__ngram_range": [(3, 5)],
            "features__text__max_features": [max_text_features],
            "clf__C": [0.3, 1.0],
        }

    if tuning_profile == "balanced":
        return {
            "features__text__ngram_range": FULL_TEXT_NGRAM_RANGE_SEARCH,
            "features__text__max_features": [max_text_features],
            "clf__C": [0.3, 1.0, 3.0],
        }

    if tuning_profile != "full":
        raise ValueError(f"Unsupported tuning profile: {tuning_profile}")

    return {
        "features__text__ngram_range": FULL_TEXT_NGRAM_RANGE_SEARCH,
        "features__text__max_features": unique_preserving_order([max_text_features, 20000]),
        "clf__C": [0.3, 1.0, 3.0],
    }


def make_xgb_grid(tuning_profile: str, max_text_features: int) -> dict[str, list[Any]]:
    if tuning_profile == "quick":
        return {
            "features__text__ngram_range": [(3, 5)],
            "features__text__max_features": [max_text_features],
            "clf__n_estimators": [150],
            "clf__max_depth": [3, 6],
            "clf__learning_rate": [0.05, 0.1],
            "clf__subsample": [0.8, 1.0],
            "clf__colsample_bytree": [0.9],
        }

    if tuning_profile == "balanced":
        return {
            "features__text__ngram_range": [(3, 5)],
            "features__text__max_features": [max_text_features],
            "clf__n_estimators": [150, 300],
            "clf__max_depth": [3, 6],
            "clf__learning_rate": [0.05, 0.1],
            "clf__subsample": [0.8, 1.0],
            "clf__colsample_bytree": [0.8, 1.0],
        }

    if tuning_profile != "full":
        raise ValueError(f"Unsupported tuning profile: {tuning_profile}")

    return {
        "features__text__ngram_range": FULL_TEXT_NGRAM_RANGE_SEARCH,
        "features__text__max_features": unique_preserving_order([max_text_features, 20000]),
        "clf__n_estimators": [150, 300],
        "clf__max_depth": [3, 6],
        "clf__learning_rate": [0.05, 0.1],
        "clf__subsample": [0.8, 1.0],
        "clf__colsample_bytree": [0.8, 1.0],
    }


def count_grid_combinations(grid: dict[str, list[Any]]) -> int:
    if not grid:
        return 0
    return prod(len(values) for values in grid.values())


def build_cv_results(candidate_summaries: list[dict[str, Any]]) -> dict[str, list[Any]]:
    sorted_scores = sorted(
        [summary["mean_test_score"] for summary in candidate_summaries],
        reverse=True,
    )
    score_ranks = {
        score: rank
        for rank, score in enumerate(unique_preserving_order(sorted_scores), start=1)
    }

    return {
        "params": [summary["params"] for summary in candidate_summaries],
        "mean_test_score": [summary["mean_test_score"] for summary in candidate_summaries],
        "std_test_score": [summary["std_test_score"] for summary in candidate_summaries],
        "mean_test_accuracy": [summary["mean_test_accuracy"] for summary in candidate_summaries],
        "mean_fit_time_seconds": [summary["mean_fit_time_seconds"] for summary in candidate_summaries],
        "rank_test_score": [score_ranks[summary["mean_test_score"]] for summary in candidate_summaries],
    }


def fit_search(
    name: str,
    pipeline: Pipeline,
    grid: dict[str, list[Any]],
    X_train: pd.DataFrame,
    y_train: np.ndarray,
    cv_folds: int,
    random_state: int,
    verbose: bool = False,
    live_progress: bool = False,
    progress_log_every_fits: int = 1,
) -> SearchResult:
    cv = StratifiedKFold(n_splits=cv_folds, shuffle=True, random_state=random_state)
    parameter_grid = list(ParameterGrid(grid)) or [{}]
    total_combinations = len(parameter_grid)
    total_fits = total_combinations * cv_folds
    fold_splits = list(cv.split(X_train, y_train))
    start_time = time.perf_counter()
    completed_fits = 0
    candidate_summaries: list[dict[str, Any]] = []
    best_score = float("-inf")
    best_params: dict[str, Any] | None = None

    emit_progress(f"\n=== Training {name} ===", verbose=verbose, always=True)
    emit_progress(
        (
            f"[train] {name}: {total_combinations} parameter combination(s) x "
            f"{cv_folds} fold(s) = {total_fits} fit(s)."
        ),
        verbose=verbose,
        always=True,
    )
    if verbose:
        emit_progress(
            f"[train] {name}: live CV search logging enabled.",
            verbose=verbose,
        )

    for candidate_index, params in enumerate(parameter_grid, start=1):
        fold_scores: list[float] = []
        fold_accuracies: list[float] = []
        fold_fit_times: list[float] = []
        candidate_start = time.perf_counter()

        if verbose:
            emit_progress(
                f"[candidate] {name} {candidate_index}/{total_combinations} params={params}",
                verbose=verbose,
            )

        for fold_index, (train_idx, valid_idx) in enumerate(fold_splits, start=1):
            estimator = clone(pipeline)
            estimator.set_params(**params)

            X_fold_train = X_train.iloc[train_idx]
            X_fold_valid = X_train.iloc[valid_idx]
            y_fold_train = y_train[train_idx]
            y_fold_valid = y_train[valid_idx]

            fit_start = time.perf_counter()
            estimator.fit(X_fold_train, y_fold_train)
            fit_elapsed = time.perf_counter() - fit_start

            y_fold_pred = estimator.predict(X_fold_valid)
            fold_f1 = float(f1_score(y_fold_valid, y_fold_pred, average="macro", zero_division=0))
            fold_accuracy = float(accuracy_score(y_fold_valid, y_fold_pred))

            fold_scores.append(fold_f1)
            fold_accuracies.append(fold_accuracy)
            fold_fit_times.append(fit_elapsed)
            completed_fits += 1

            progress_bar = render_progress_bar(completed_fits, total_fits)
            candidate_mean_f1 = float(np.mean(fold_scores))
            candidate_mean_accuracy = float(np.mean(fold_accuracies))
            should_log_progress = live_progress and (
                completed_fits == total_fits
                or completed_fits % max(1, progress_log_every_fits) == 0
            )

            if should_log_progress:
                best_cv_text = "n/a" if best_params is None else f"{best_score:.4f}"
                emit_progress(
                    (
                        f"[progress] {name} {progress_bar} {completed_fits}/{total_fits} fit(s) "
                        f"candidate={candidate_index}/{total_combinations} fold={fold_index}/{cv_folds} "
                        f"val_f1={fold_f1:.4f} val_acc={fold_accuracy:.4f} "
                        f"candidate_mean_f1={candidate_mean_f1:.4f} "
                        f"candidate_mean_acc={candidate_mean_accuracy:.4f} "
                        f"best_cv_f1={best_cv_text} "
                        f"elapsed={format_elapsed(time.perf_counter() - start_time)} "
                        f"fit_time={format_elapsed(fit_elapsed)}"
                    ),
                    verbose=True,
                    always=True,
                )

        candidate_summary = {
            "params": params,
            "mean_test_score": float(np.mean(fold_scores)),
            "std_test_score": float(np.std(fold_scores)),
            "mean_test_accuracy": float(np.mean(fold_accuracies)),
            "mean_fit_time_seconds": float(np.mean(fold_fit_times)),
            "fold_scores": fold_scores,
            "fold_accuracies": fold_accuracies,
            "elapsed_seconds": float(time.perf_counter() - candidate_start),
        }
        candidate_summaries.append(candidate_summary)

        emit_progress(
            (
                f"[candidate] {name} {candidate_index}/{total_combinations} "
                f"mean_cv_f1={candidate_summary['mean_test_score']:.4f} "
                f"mean_cv_acc={candidate_summary['mean_test_accuracy']:.4f} "
                f"std_cv_f1={candidate_summary['std_test_score']:.4f} "
                f"elapsed={format_elapsed(candidate_summary['elapsed_seconds'])}"
            ),
            verbose=verbose,
            always=live_progress,
        )

        if candidate_summary["mean_test_score"] > best_score:
            best_score = candidate_summary["mean_test_score"]
            best_params = dict(params)
            emit_progress(
                (
                    f"[train] {name}: new best candidate {candidate_index}/{total_combinations} "
                    f"mean_cv_f1={best_score:.4f} "
                    f"mean_cv_acc={candidate_summary['mean_test_accuracy']:.4f} "
                    f"params={best_params}"
                ),
                verbose=verbose,
                always=True,
            )

    if best_params is None:
        raise ValueError(f"No candidate finished for {name}.")

    emit_progress(
        f"[train] {name}: refitting best candidate on the full training split...",
        verbose=verbose,
        always=True,
    )
    best_estimator = clone(pipeline)
    best_estimator.set_params(**best_params)
    best_estimator.fit(X_train, y_train)

    emit_progress(f"[train] {name}: tuning finished.", verbose=verbose, always=True)
    emit_progress(f"{name} best params: {best_params}", verbose=verbose, always=True)
    emit_progress(
        f"{name} best CV macro-F1: {best_score:.4f}",
        verbose=verbose,
        always=True,
    )
    return SearchResult(
        best_estimator_=best_estimator,
        best_params_=best_params,
        best_score_=best_score,
        cv_results_=build_cv_results(candidate_summaries),
        candidate_summaries=candidate_summaries,
    )


def compute_metrics(name: str, estimator: Pipeline, X_test: pd.DataFrame, y_test: np.ndarray, label_encoder: LabelEncoder) -> TrainingArtifacts:
    predictions = estimator.predict(X_test)
    probabilities = estimator.predict_proba(X_test) if hasattr(estimator, "predict_proba") else None
    report = classification_report(
        y_test,
        predictions,
        target_names=label_encoder.classes_,
        output_dict=True,
        zero_division=0,
    )
    metrics = {
        "model_name": name,
        "accuracy": float(accuracy_score(y_test, predictions)),
        "f1_macro": float(f1_score(y_test, predictions, average="macro", zero_division=0)),
        "f1_weighted": float(f1_score(y_test, predictions, average="weighted", zero_division=0)),
        "classification_report": report,
        "confusion_matrix": confusion_matrix(y_test, predictions).tolist(),
    }
    return TrainingArtifacts(name=name, estimator=estimator, metrics=metrics, predictions=predictions, probabilities=probabilities)


def extract_lr_top_features(estimator: Pipeline, top_k: int = 30) -> list[dict[str, Any]]:
    feature_names = estimator.named_steps["features"].get_feature_names_out()
    clf: LogisticRegression = estimator.named_steps["clf"]
    coef = clf.coef_

    rows: list[dict[str, Any]] = []
    if coef.ndim == 1 or coef.shape[0] == 1:
        weights = coef[0] if coef.ndim > 1 else coef
        top_idx = np.argsort(np.abs(weights))[::-1][:top_k]
        for idx in top_idx:
            rows.append({"feature": feature_names[idx], "weight": float(weights[idx])})
        return rows

    for class_index in range(coef.shape[0]):
        weights = coef[class_index]
        top_idx = np.argsort(np.abs(weights))[::-1][:top_k]
        rows.append(
            {
                "class_index": int(class_index),
                "top_features": [
                    {"feature": feature_names[idx], "weight": float(weights[idx])}
                    for idx in top_idx
                ],
            }
        )
    return rows


def compute_xgb_shap(estimator: Pipeline, X_sample: pd.DataFrame, top_k: int = 50) -> list[dict[str, Any]]:
    if shap is None:
        raise ImportError("shap not installed. Run pip install -r python_pipeline/requirements/classifier.txt")

    features = estimator.named_steps["features"]
    model = estimator.named_steps["clf"]
    transformed = features.transform(X_sample)
    feature_names = features.get_feature_names_out()

    try:
        explainer = shap.TreeExplainer(model)
        shap_values = explainer.shap_values(transformed)
    except Exception:
        explainer = shap.Explainer(model)
        shap_values = explainer(transformed).values

    values = np.array(shap_values)

    if values.ndim == 3:
        mean_abs = np.abs(values).mean(axis=(0, 1))
    elif values.ndim == 2:
        mean_abs = np.abs(values).mean(axis=0)
    else:
        raise ValueError(f"Unexpected SHAP values shape: {values.shape}")

    top_idx = np.argsort(mean_abs)[::-1][:top_k]
    return [
        {"feature": feature_names[idx], "mean_abs_shap": float(mean_abs[idx])}
        for idx in top_idx
    ]


def save_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2, ensure_ascii=False)


def try_export_lr_onnx(estimator: Pipeline, output_path: Path) -> tuple[bool, str]:
    try:
        from skl2onnx import convert_sklearn
        from skl2onnx.common.data_types import FloatTensorType, StringTensorType
    except ImportError as exc:
        return False, f"skl2onnx missing: {exc}"

    initial_types = [
        ("combined_text", StringTensorType([None, 1])),
        ("language", StringTensorType([None, 1])),
        ("source", StringTensorType([None, 1])),
        ("text_char_len", FloatTensorType([None, 1])),
        ("text_word_len", FloatTensorType([None, 1])),
    ]

    try:
        onnx_model = convert_sklearn(estimator, initial_types=initial_types, target_opset=17)
        output_path.write_bytes(onnx_model.SerializeToString())
        return True, f"Exported ONNX to {output_path}"
    except Exception as exc:  # pragma: no cover
        return False, f"ONNX export failed: {exc}"


def build_dataset_audit(df: pd.DataFrame, label_col: str, text_cols: list[str], categorical_cols: list[str], numeric_cols: list[str]) -> dict[str, Any]:
    audit: dict[str, Any] = {
        "row_count": int(len(df)),
        "columns": list(df.columns),
        "label_distribution": df[label_col].value_counts(dropna=False).to_dict(),
        "missing_by_column": {col: int(df[col].isna().sum()) for col in df.columns},
        "sample_rows": df.head(5).replace({np.nan: None}).to_dict(orient="records"),
    }

    if "source_file" in df.columns:
        audit["source_file_distribution"] = (
            df["source_file"].fillna("missing").astype(str).value_counts().to_dict()
        )

    for column in text_cols:
        if column in df.columns:
            lengths = df[column].fillna("").astype(str).map(len)
            audit[f"{column}_length"] = {
                "min": int(lengths.min()),
                "median": float(lengths.median()),
                "max": int(lengths.max()),
            }

    for column in categorical_cols:
        if column in df.columns:
            audit[f"{column}_distribution"] = df[column].fillna("missing").astype(str).value_counts().head(20).to_dict()

    for column in numeric_cols:
        if column in df.columns:
            series = pd.to_numeric(df[column], errors="coerce")
            audit[f"{column}_summary"] = {
                "min": None if series.dropna().empty else float(series.min()),
                "median": None if series.dropna().empty else float(series.median()),
                "max": None if series.dropna().empty else float(series.max()),
            }

    return audit


def main(argv: list[str] | None = None) -> None:
    args = parse_args(argv)
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    lr_grid = make_lr_grid(args.tuning_profile, args.max_text_features)
    xgb_grid = make_xgb_grid(args.tuning_profile, args.max_text_features)
    emit_progress(
        f"[setup] task={args.task} model={args.model} cv_folds={args.cv_folds} output={output_dir}",
        verbose=args.verbose,
        always=True,
    )
    emit_progress(
        (
            f"[setup] tuning_profile={args.tuning_profile} max_text_features={args.max_text_features} "
            f"skip_shap={args.skip_shap} live_progress={args.live_progress} "
            f"progress_log_every_fits={args.progress_log_every_fits}"
        ),
        verbose=args.verbose,
        always=True,
    )
    emit_progress(
        f"[setup] xgboost_device={args.xgb_device}",
        verbose=args.verbose,
        always=True,
    )
    emit_progress(
        f"[setup] Input dataset(s): {args.data}",
        verbose=args.verbose,
    )

    emit_progress("[load] Loading dataset files...", verbose=args.verbose, always=True)
    raw_df = load_dataset(args.data, verbose=args.verbose)
    emit_progress(
        f"[load] Finished loading {len(raw_df)} raw row(s).",
        verbose=args.verbose,
        always=True,
    )
    emit_progress(
        f"[labels] Cleaning target column '{args.label_col}'...",
        verbose=args.verbose,
        always=True,
    )
    raw_df, cleaning_summary = clean_training_frame(
        raw_df,
        args.label_col,
        args.text_cols,
        args.categorical_cols,
        args.numeric_cols,
        args.min_class_count,
        verbose=args.verbose,
    )

    present_text_cols = detect_present_columns(raw_df, args.text_cols)
    present_categorical_cols = detect_present_columns(raw_df, args.categorical_cols)
    present_numeric_cols = detect_present_columns(raw_df, args.numeric_cols)

    emit_progress("[audit] Building dataset audit...", verbose=args.verbose, always=True)
    audit = build_dataset_audit(
        raw_df,
        args.label_col,
        present_text_cols,
        present_categorical_cols,
        present_numeric_cols,
    )
    audit["cleaning_summary"] = cleaning_summary
    save_json(output_dir / "dataset_audit.json", audit)
    emit_progress(
        f"[audit] Wrote {output_dir / 'dataset_audit.json'}",
        verbose=args.verbose,
        always=True,
    )

    emit_progress("[features] Building derived features...", verbose=args.verbose, always=True)
    processed_df, text_feature_cols, categorical_cols, numeric_cols = add_derived_features(
        raw_df,
        args.text_cols,
        args.categorical_cols,
        args.numeric_cols,
        include_text_length_features=args.include_text_length_features,
    )
    emit_progress(
        f"[features] Text columns: {text_feature_cols}",
        verbose=args.verbose,
    )
    emit_progress(
        f"[features] Categorical columns: {categorical_cols}",
        verbose=args.verbose,
    )
    emit_progress(
        f"[features] Numeric columns: {numeric_cols}",
        verbose=args.verbose,
    )

    feature_df = processed_df[[*text_feature_cols, *categorical_cols, *numeric_cols]].copy()
    label_encoder = LabelEncoder()
    y = label_encoder.fit_transform(processed_df[args.label_col])
    emit_progress(
        f"[labels] Encoded {len(label_encoder.classes_)} class(es): {label_encoder.classes_.tolist()}",
        verbose=args.verbose,
    )

    emit_progress("[split] Creating train/test split...", verbose=args.verbose, always=True)
    X_train, X_test, y_train, y_test = train_test_split(
        feature_df,
        y,
        test_size=args.test_size,
        random_state=args.random_state,
        stratify=y,
    )
    emit_progress(
        f"[split] Train rows: {len(X_train)} | test rows: {len(X_test)}",
        verbose=args.verbose,
        always=True,
    )

    save_json(
        output_dir / "label_metadata.json",
        {
            "task": args.task,
            "classes": label_encoder.classes_.tolist(),
            "severity_order": DEFAULT_SEVERITY_ORDER if args.task == "severity" else None,
        },
    )
    emit_progress(
        f"[artifacts] Wrote {output_dir / 'label_metadata.json'}",
        verbose=args.verbose,
        always=True,
    )

    results: list[TrainingArtifacts] = []
    search_summaries: dict[str, Any] = {}

    if args.model in {"lr", "both"}:
        lr_search = fit_search(
            name="logistic_regression",
            pipeline=build_lr_pipeline(categorical_cols, numeric_cols, args.max_text_features, args.random_state),
            grid=lr_grid,
            X_train=X_train,
            y_train=y_train,
            cv_folds=args.cv_folds,
            random_state=args.random_state,
            verbose=args.verbose,
            live_progress=args.live_progress,
            progress_log_every_fits=args.progress_log_every_fits,
        )
        search_summaries["logistic_regression"] = {
            "best_params": lr_search.best_params_,
            "best_cv_score": float(lr_search.best_score_),
        }
        lr_result = compute_metrics("logistic_regression", lr_search.best_estimator_, X_test, y_test, label_encoder)
        lr_result.metrics["top_features"] = extract_lr_top_features(lr_search.best_estimator_)
        results.append(lr_result)
        emit_progress(
            f"[metrics] logistic_regression test macro-F1: {lr_result.metrics['f1_macro']:.4f}",
            verbose=args.verbose,
            always=True,
        )

    if args.model in {"xgb", "both"}:
        xgb_search = fit_search(
            name="xgboost",
            pipeline=build_xgb_pipeline(
                categorical_cols,
                numeric_cols,
                args.max_text_features,
                args.random_state,
                len(label_encoder.classes_),
                args.xgb_device,
            ),
            grid=xgb_grid,
            X_train=X_train,
            y_train=y_train,
            cv_folds=args.cv_folds,
            random_state=args.random_state,
            verbose=args.verbose,
            live_progress=args.live_progress,
            progress_log_every_fits=args.progress_log_every_fits,
        )
        search_summaries["xgboost"] = {
            "best_params": xgb_search.best_params_,
            "best_cv_score": float(xgb_search.best_score_),
        }
        xgb_result = compute_metrics("xgboost", xgb_search.best_estimator_, X_test, y_test, label_encoder)
        if args.skip_shap:
            xgb_result.metrics["shap_top_features"] = None
            xgb_result.metrics["shap_status"] = "skipped"
            emit_progress(
                "[xgboost] Skipping SHAP feature ranking (--skip-shap).",
                verbose=args.verbose,
                always=True,
            )
        else:
            sample_size = min(200, len(X_test))
            emit_progress(
                f"[xgboost] Computing SHAP top features for {sample_size} held-out row(s)...",
                verbose=args.verbose,
                always=True,
            )
            xgb_result.metrics["shap_top_features"] = compute_xgb_shap(
                xgb_search.best_estimator_, X_test.head(sample_size)
            )
            xgb_result.metrics["shap_status"] = "computed"
        results.append(xgb_result)
        if not args.skip_shap:
            emit_progress("[xgboost] SHAP feature ranking ready.", verbose=args.verbose, always=True)
        emit_progress(
            f"[metrics] xgboost test macro-F1: {xgb_result.metrics['f1_macro']:.4f}",
            verbose=args.verbose,
            always=True,
        )

    if not results:
        raise ValueError("No models trained.")

    leaderboard = sorted(
        [
            {
                "model_name": result.name,
                "accuracy": result.metrics["accuracy"],
                "f1_macro": result.metrics["f1_macro"],
                "f1_weighted": result.metrics["f1_weighted"],
            }
            for result in results
        ],
        key=lambda item: item["f1_macro"],
        reverse=True,
    )

    best_name = leaderboard[0]["model_name"]
    best_result = next(result for result in results if result.name == best_name)
    joblib.dump(best_result.estimator, output_dir / f"{best_name}.joblib")
    joblib.dump(best_result.estimator, output_dir / "best_model.joblib")
    emit_progress(
        f"[artifacts] Saved best estimator as {output_dir / f'{best_name}.joblib'} and {output_dir / 'best_model.joblib'}",
        verbose=args.verbose,
        always=True,
    )

    metrics_bundle = {
        "search_config": {
            "tuning_profile": args.tuning_profile,
            "cv_folds": args.cv_folds,
            "max_text_features": args.max_text_features,
            "skip_shap": args.skip_shap,
            "live_progress": args.live_progress,
            "progress_log_every_fits": args.progress_log_every_fits,
        },
        "leaderboard": leaderboard,
        "search_summaries": search_summaries,
        "models": {result.name: result.metrics for result in results},
        "best_model": best_name,
        "features": {
            "text_columns": args.text_cols,
            "categorical_columns": categorical_cols,
            "numeric_columns": numeric_cols,
            "vectorizer": {
                "type": "TfidfVectorizer",
                "analyzer": "char_wb",
                "ngram_range_search": unique_preserving_order(
                    lr_grid.get("features__text__ngram_range", [])
                    + xgb_grid.get("features__text__ngram_range", [])
                ),
                "max_features_search": unique_preserving_order(
                    lr_grid.get("features__text__max_features", [])
                    + xgb_grid.get("features__text__max_features", [])
                ),
                "why": "Robust for Gurindji, English, Gurindji-Kriol spelling variation and code-switching.",
            },
            "language_note": "language feature normalized into english/gurindji/gurindji-kriol/unknown.",
        },
        "deployment": {
            "primary_runtime": "joblib/python",
            "preferred_mobile_export": "ONNX for logistic regression only after parity test",
            "warning": "XGBoost + TF-IDF ONNX conversion may fail or differ. Test on device before shipping.",
            "xgboost_device": args.xgb_device,
        },
    }
    save_json(output_dir / "metrics.json", metrics_bundle)
    emit_progress(
        f"[artifacts] Wrote {output_dir / 'metrics.json'}",
        verbose=args.verbose,
        always=True,
    )

    onnx_status: dict[str, str] = {}
    if args.export_onnx:
        for result in results:
            if result.name != "logistic_regression":
                emit_progress(
                    "[onnx] Skipping XGBoost export because this repo treats it as non-default-safe.",
                    verbose=args.verbose,
                    always=True,
                )
                onnx_status[result.name] = "Skipped: XGBoost ONNX export not default-safe in this repo."
                continue
            emit_progress(
                f"[onnx] Exporting {result.name} to ONNX...",
                verbose=args.verbose,
                always=True,
            )
            ok, message = try_export_lr_onnx(result.estimator, output_dir / f"{result.name}.onnx")
            onnx_status[result.name] = message if ok else f"Failed: {message}"
            emit_progress(f"[onnx] {onnx_status[result.name]}", verbose=args.verbose, always=True)
        save_json(output_dir / "onnx_export_status.json", onnx_status)
        emit_progress(
            f"[artifacts] Wrote {output_dir / 'onnx_export_status.json'}",
            verbose=args.verbose,
            always=True,
        )

    summary = {
        "best_model": best_name,
        "leaderboard": leaderboard,
        "artifacts": [
            str(output_dir / "dataset_audit.json"),
            str(output_dir / "label_metadata.json"),
            str(output_dir / "metrics.json"),
            str(output_dir / "best_model.joblib"),
        ],
    }
    save_json(output_dir / "run_summary.json", summary)
    emit_progress(
        f"[artifacts] Wrote {output_dir / 'run_summary.json'}",
        verbose=args.verbose,
        always=True,
    )

    print("\n=== Done ===", flush=True)
    print(json.dumps(summary, indent=2, ensure_ascii=False), flush=True)


if __name__ == "__main__":
    main()

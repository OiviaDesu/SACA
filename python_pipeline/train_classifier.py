from __future__ import annotations

import argparse
import json
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
from sklearn.model_selection import GridSearchCV, StratifiedKFold, train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import LabelEncoder, OneHotEncoder

try:
    from xgboost import XGBClassifier
except ImportError:  # pragma: no cover
    XGBClassifier = None

try:
    import shap
except ImportError:  # pragma: no cover
    shap = None


DEFAULT_SEVERITY_ORDER = ["emergency", "urgent", "routine", "self-care"]


@dataclass
class TrainingArtifacts:
    name: str
    estimator: Pipeline
    metrics: dict[str, Any]
    predictions: np.ndarray
    probabilities: np.ndarray | None


def emit_progress(message: str, *, verbose: bool, always: bool = False) -> None:
    if always or verbose:
        print(message, flush=True)


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
        default=5,
        help="Cross-validation folds for tuning.",
    )
    parser.add_argument(
        "--model",
        choices=["lr", "xgb", "both"],
        default="both",
        help="Which models to train.",
    )
    parser.add_argument(
        "--export-onnx",
        action="store_true",
        help="Try ONNX export. Best effort only.",
    )
    parser.add_argument(
        "--max-text-features",
        type=int,
        default=20000,
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
    frame[label_col] = frame[label_col].map(normalize_text)
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
                    steps=[("imputer", SimpleImputer(strategy="median"))]
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
                    max_iter=3000,
                    class_weight="balanced",
                    solver="saga",
                    n_jobs=-1,
                    random_state=random_state,
                ),
            ),
        ]
    )


def build_xgb_pipeline(categorical_cols: list[str], numeric_cols: list[str], max_text_features: int, random_state: int, num_classes: int) -> Pipeline:
    if XGBClassifier is None:
        raise ImportError("xgboost not installed. Run pip install -r python_pipeline/requirements-classifier.txt")
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
                    n_estimators=300,
                    max_depth=6,
                    learning_rate=0.1,
                    subsample=0.9,
                    colsample_bytree=0.9,
                    reg_lambda=1.0,
                    random_state=random_state,
                    n_jobs=-1,
                ),
            ),
        ]
    )


def make_lr_grid() -> dict[str, list[Any]]:
    return {
        "features__text__ngram_range": [(3, 5), (2, 5)],
        "features__text__max_features": [10000, 20000],
        "clf__C": [0.3, 1.0, 3.0],
    }


def make_xgb_grid() -> dict[str, list[Any]]:
    return {
        "features__text__ngram_range": [(3, 5), (2, 5)],
        "features__text__max_features": [10000, 20000],
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


def fit_search(
    name: str,
    pipeline: Pipeline,
    grid: dict[str, list[Any]],
    X_train: pd.DataFrame,
    y_train: np.ndarray,
    cv_folds: int,
    random_state: int,
    verbose: bool = False,
) -> GridSearchCV:
    cv = StratifiedKFold(n_splits=cv_folds, shuffle=True, random_state=random_state)
    total_combinations = count_grid_combinations(grid)
    total_fits = total_combinations * cv_folds
    search = GridSearchCV(
        estimator=pipeline,
        param_grid=grid,
        scoring="f1_macro",
        n_jobs=-1,
        cv=cv,
        verbose=1 if verbose else 0,
        refit=True,
    )
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
            f"[train] {name}: sklearn GridSearchCV progress output enabled.",
            verbose=verbose,
        )
    search.fit(X_train, y_train)
    emit_progress(f"[train] {name}: tuning finished.", verbose=verbose, always=True)
    emit_progress(f"{name} best params: {search.best_params_}", verbose=verbose, always=True)
    emit_progress(
        f"{name} best CV macro-F1: {search.best_score_:.4f}",
        verbose=verbose,
        always=True,
    )
    return search


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
        raise ImportError("shap not installed. Run pip install -r python_pipeline/requirements-classifier.txt")

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
    emit_progress(
        f"[setup] task={args.task} model={args.model} cv_folds={args.cv_folds} output={output_dir}",
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
    raw_df = clean_labels(raw_df, args.label_col, args.min_class_count, verbose=args.verbose)

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
            grid=make_lr_grid(),
            X_train=X_train,
            y_train=y_train,
            cv_folds=args.cv_folds,
            random_state=args.random_state,
            verbose=args.verbose,
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
            pipeline=build_xgb_pipeline(categorical_cols, numeric_cols, args.max_text_features, args.random_state, len(label_encoder.classes_)),
            grid=make_xgb_grid(),
            X_train=X_train,
            y_train=y_train,
            cv_folds=args.cv_folds,
            random_state=args.random_state,
            verbose=args.verbose,
        )
        search_summaries["xgboost"] = {
            "best_params": xgb_search.best_params_,
            "best_cv_score": float(xgb_search.best_score_),
        }
        xgb_result = compute_metrics("xgboost", xgb_search.best_estimator_, X_test, y_test, label_encoder)
        sample_size = min(200, len(X_test))
        emit_progress(
            f"[xgboost] Computing SHAP top features for {sample_size} held-out row(s)...",
            verbose=args.verbose,
            always=True,
        )
        xgb_result.metrics["shap_top_features"] = compute_xgb_shap(
            xgb_search.best_estimator_, X_test.head(sample_size)
        )
        results.append(xgb_result)
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
                "ngram_range_search": [(3, 5), (2, 5)],
                "why": "Robust for Gurindji, English, Gurindji-Kriol spelling variation and code-switching.",
            },
            "language_note": "language feature normalized into english/gurindji/gurindji-kriol/unknown.",
        },
        "deployment": {
            "primary_runtime": "joblib/python",
            "preferred_mobile_export": "ONNX for logistic regression only after parity test",
            "warning": "XGBoost + TF-IDF ONNX conversion may fail or differ. Test on device before shipping.",
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

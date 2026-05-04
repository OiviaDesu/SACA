from __future__ import annotations

import json
import math
import re
import copy
from collections import Counter
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Mapping

import joblib
import numpy as np


BUNDLE_FILENAME = "bundle.json"
EXPORT_SUMMARY_FILENAME = "export_summary.json"
SUPPORTED_OBJECTIVES = {"binary:logistic", "multi:softprob"}


@dataclass(frozen=True)
class BundlePrediction:
    label: str
    class_index: int
    probability: float
    probabilities: list[float]


def export_xgb_flutter_bundle(model_dir_or_file: str | Path, output_dir: str | Path) -> dict[str, Any]:
    pipeline, label_metadata, metrics, resolved_model_path = load_xgb_pipeline(model_dir_or_file)
    bundle = build_bundle_from_pipeline(
        pipeline,
        label_metadata=label_metadata,
        source_model_path=resolved_model_path,
        metrics=metrics,
    )

    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)
    bundle_path = output_path / BUNDLE_FILENAME
    save_json(bundle_path, bundle, compact=True)

    summary = {
        "bundle_path": str(bundle_path),
        "bundle_size_bytes": bundle_path.stat().st_size,
        "objective": bundle["model"]["objective"],
        "class_count": len(bundle["classes"]),
        "feature_count": bundle["feature_count"],
        "tree_count": len(bundle["model"]["trees"]),
        "source_model_path": str(resolved_model_path),
    }
    save_json(output_path / EXPORT_SUMMARY_FILENAME, summary)
    return summary


def load_xgb_pipeline(
    model_dir_or_file: str | Path,
) -> tuple[Any, dict[str, Any], dict[str, Any] | None, Path]:
    model_path, label_metadata_path, metrics_path = resolve_model_paths(model_dir_or_file)
    pipeline = joblib.load(model_path)
    clf = pipeline.named_steps.get("clf")
    if clf is None or not hasattr(clf, "get_booster"):
        raise ValueError(
            f"{model_path} does not look like an XGBoost sklearn pipeline artifact."
        )

    if label_metadata_path is None or not label_metadata_path.exists():
        raise ValueError(
            "label_metadata.json with original class labels is required for export."
        )

    label_metadata = json.loads(label_metadata_path.read_text(encoding="utf-8"))
    if "classes" not in label_metadata:
        raise ValueError("label_metadata.json must contain a 'classes' array.")

    metrics = None
    if metrics_path is not None and metrics_path.exists():
        metrics = json.loads(metrics_path.read_text(encoding="utf-8"))

    return pipeline, label_metadata, metrics, model_path


def resolve_model_paths(model_dir_or_file: str | Path) -> tuple[Path, Path | None, Path | None]:
    path = Path(model_dir_or_file)
    if path.is_dir():
        model_path = path / "best_model.joblib"
        label_metadata_path = path / "label_metadata.json"
        metrics_path = path / "metrics.json"
        if not model_path.exists():
            raise FileNotFoundError(f"Missing model artifact: {model_path}")
        return model_path, label_metadata_path, metrics_path

    if not path.exists():
        raise FileNotFoundError(f"Missing model artifact: {path}")

    parent = path.parent
    label_metadata_path = parent / "label_metadata.json"
    metrics_path = parent / "metrics.json"
    return path, label_metadata_path if label_metadata_path.exists() else None, metrics_path if metrics_path.exists() else None


def build_bundle_from_pipeline(
    pipeline: Any,
    *,
    label_metadata: dict[str, Any],
    source_model_path: Path,
    metrics: dict[str, Any] | None = None,
) -> dict[str, Any]:
    features = pipeline.named_steps["features"]
    clf = pipeline.named_steps["clf"]
    text_vectorizer = features.named_transformers_["text"]

    cat_transformer = features.named_transformers_.get("cat")
    cat_columns = _transformer_columns(features, "cat")
    onehot = None
    if cat_transformer not in {None, "drop"}:
        onehot = cat_transformer.named_steps["onehot"]

    num_transformer = features.named_transformers_.get("num")
    num_columns = _transformer_columns(features, "num")
    numeric_imputer = None
    if num_transformer not in {None, "drop"}:
        numeric_imputer = num_transformer.named_steps["imputer"]

    vocabulary = {
        term: int(index)
        for term, index in sorted(text_vectorizer.vocabulary_.items(), key=lambda item: item[1])
    }
    idf = [float(value) for value in text_vectorizer.idf_.tolist()]

    categorical_features: list[dict[str, Any]] = []
    current_offset = len(vocabulary)
    if onehot is not None:
        for column_name, categories in zip(cat_columns, onehot.categories_, strict=True):
            category_values = [str(value) for value in categories.tolist()]
            categorical_features.append(
                {
                    "name": column_name,
                    "offset": current_offset,
                    "categories": category_values,
                }
            )
            current_offset += len(category_values)

    numeric_features: list[dict[str, Any]] = []
    if numeric_imputer is not None:
        for column_name, statistic in zip(num_columns, numeric_imputer.statistics_, strict=True):
            numeric_features.append(
                {
                    "name": column_name,
                    "offset": current_offset,
                    "fill_value": float(statistic),
                }
            )
            current_offset += 1

    booster = clf.get_booster()
    config = json.loads(booster.save_config())
    objective_name = config["learner"]["objective"]["name"]
    if objective_name not in SUPPORTED_OBJECTIVES:
        raise ValueError(
            f"Unsupported XGBoost objective for Flutter bundle export: {objective_name}"
        )

    classes = [str(value) for value in label_metadata["classes"]]
    base_scores = _parse_base_scores(
        config["learner"]["learner_model_param"]["base_score"],
        objective_name=objective_name,
        class_count=len(classes),
    )

    tree_dump = [json.loads(tree_json) for tree_json in booster.get_dump(dump_format="json")]
    trees = [_flatten_tree(tree) for tree in tree_dump]

    if objective_name == "multi:softprob" and len(trees) % len(classes) != 0:
        raise ValueError(
            "Tree count is not divisible by class count; exported bundle would be ambiguous."
        )

    bundle = {
        "bundle_version": 1,
        "runtime": "xgboost_sparse_softprob",
        "created_at": datetime.now(tz=timezone.utc).isoformat(timespec="seconds"),
        "source_model_path": str(source_model_path),
        "classes": classes,
        "feature_count": int(current_offset),
        "text_feature": {
            "column": _transformer_columns(features, "text"),
            "analyzer": text_vectorizer.analyzer,
            "lowercase": bool(text_vectorizer.lowercase),
            "ngram_range": [int(text_vectorizer.ngram_range[0]), int(text_vectorizer.ngram_range[1])],
            "sublinear_tf": bool(text_vectorizer.sublinear_tf),
            "vocabulary": vocabulary,
            "idf": idf,
        },
        "categorical_features": categorical_features,
        "numeric_features": numeric_features,
        "model": {
            "objective": objective_name,
            "num_classes": len(classes),
            "base_scores": base_scores,
            "trees": trees,
        },
        "training_metadata": {
            "label_metadata": label_metadata,
            "best_model": None if metrics is None else metrics.get("best_model"),
            "leaderboard": None if metrics is None else metrics.get("leaderboard"),
            "xgboost_summary": None
            if metrics is None
            else metrics.get("search_summaries", {}).get("xgboost"),
        },
    }
    return bundle


def load_bundle(bundle_dir_or_file: str | Path) -> dict[str, Any]:
    path = Path(bundle_dir_or_file)
    bundle_path = path / BUNDLE_FILENAME if path.is_dir() else path
    if not bundle_path.exists():
        raise FileNotFoundError(f"Missing bundle JSON: {bundle_path}")
    return json.loads(bundle_path.read_text(encoding="utf-8"))


def record_from_feature_row(row: Mapping[str, Any], bundle: Mapping[str, Any]) -> dict[str, Any]:
    text_feature = bundle["text_feature"]
    categorical_features = bundle.get("categorical_features", [])
    numeric_features = bundle.get("numeric_features", [])

    return {
        "combined_text": str(row.get(str(text_feature["column"]), "") or ""),
        "categorical": {
            str(feature["name"]): row.get(str(feature["name"]))
            for feature in categorical_features
        },
        "numeric": {
            str(feature["name"]): row.get(str(feature["name"]))
            for feature in numeric_features
        },
    }


def build_sparse_feature_vector(
    bundle: Mapping[str, Any],
    record: Mapping[str, Any],
) -> dict[int, float]:
    feature_map: dict[int, float] = {}

    text_feature = bundle["text_feature"]
    vocabulary = {
        str(term): int(index) for term, index in text_feature["vocabulary"].items()
    }
    idf = [float(value) for value in text_feature["idf"]]
    min_n, max_n = [int(value) for value in text_feature["ngram_range"]]
    sublinear_tf = bool(text_feature.get("sublinear_tf", False))

    counts = Counter(char_wb_ngrams(str(record.get("combined_text", "")), min_n=min_n, max_n=max_n))
    text_weights: dict[int, float] = {}
    for ngram, count in counts.items():
        feature_index = vocabulary.get(ngram)
        if feature_index is None:
            continue
        tf = 1.0 + math.log(count) if sublinear_tf else float(count)
        text_weights[feature_index] = tf * idf[feature_index]

    norm = math.sqrt(sum(value * value for value in text_weights.values()))
    if norm > 0:
        for feature_index, value in text_weights.items():
            feature_map[feature_index] = float(np.float32(value / norm))

    categorical_values = record.get("categorical", {}) or {}
    for feature in bundle.get("categorical_features", []):
        column_name = str(feature["name"])
        candidate_value = categorical_values.get(column_name)
        if _is_missing(candidate_value):
            continue
        categories = [str(value) for value in feature["categories"]]
        try:
            category_index = categories.index(str(candidate_value))
        except ValueError:
            continue
        feature_map[int(feature["offset"]) + category_index] = float(np.float32(1.0))

    numeric_values = record.get("numeric", {}) or {}
    for feature in bundle.get("numeric_features", []):
        column_name = str(feature["name"])
        raw_value = numeric_values.get(column_name)
        value = float(feature["fill_value"]) if _is_missing(raw_value) else float(raw_value)
        feature_map[int(feature["offset"])] = float(np.float32(value))

    return feature_map


def build_dense_feature_vector(
    bundle: Mapping[str, Any],
    record: Mapping[str, Any],
    *,
    missing_value: float = float("nan"),
) -> list[float]:
    dense_vector = [missing_value] * int(bundle["feature_count"])
    for feature_index, value in build_sparse_feature_vector(bundle, record).items():
        dense_vector[int(feature_index)] = float(value)
    return dense_vector


def predict_proba_from_record(
    bundle: Mapping[str, Any],
    record: Mapping[str, Any],
) -> list[float]:
    feature_map = build_sparse_feature_vector(bundle, record)
    model = bundle["model"]
    objective_name = str(model["objective"])
    trees = model["trees"]
    base_scores = [float(value) for value in model["base_scores"]]
    class_count = int(model["num_classes"])

    if objective_name == "binary:logistic":
        margin = 0.0
        if base_scores:
            base_probability = min(max(base_scores[0], 1e-12), 1.0 - 1e-12)
            margin = -math.log(1.0 / base_probability - 1.0)
        for tree in trees:
            margin += evaluate_tree(tree["nodes"], feature_map)
        positive_probability = 1.0 / (1.0 + math.exp(-margin))
        return [1.0 - positive_probability, positive_probability]

    logits = list(base_scores)
    if len(logits) != class_count:
        raise ValueError(
            f"Expected {class_count} base scores for multiclass model, got {len(logits)}."
        )

    for tree_index, tree in enumerate(trees):
        class_index = tree_index % class_count
        logits[class_index] += evaluate_tree(tree["nodes"], feature_map)

    return softmax(logits)


def predict_from_record(
    bundle: Mapping[str, Any],
    record: Mapping[str, Any],
) -> BundlePrediction:
    probabilities = predict_proba_from_record(bundle, record)
    class_index = int(np.argmax(probabilities))
    labels = [str(value) for value in bundle["classes"]]
    return BundlePrediction(
        label=labels[class_index],
        class_index=class_index,
        probability=float(probabilities[class_index]),
        probabilities=[float(value) for value in probabilities],
    )


def compare_pipeline_and_bundle(
    bundle: Mapping[str, Any],
    pipeline: Any,
    feature_frame: Any,
) -> dict[str, Any]:
    pipeline_probabilities = np.asarray(pipeline.predict_proba(feature_frame), dtype=float)
    bundle_probabilities = np.asarray(
        [
            predict_proba_from_record(bundle, record_from_feature_row(row, bundle))
            for row in feature_frame.to_dict(orient="records")
        ],
        dtype=float,
    )

    abs_diff = np.abs(pipeline_probabilities - bundle_probabilities)
    pipeline_top = np.argmax(pipeline_probabilities, axis=1)
    bundle_top = np.argmax(bundle_probabilities, axis=1)
    labels = [str(value) for value in bundle["classes"]]

    worst_row_indices = np.argsort(abs_diff.max(axis=1))[::-1][: min(5, len(feature_frame))]
    worst_examples = []
    records = feature_frame.to_dict(orient="records")
    for row_index in worst_row_indices.tolist():
        row = records[row_index]
        worst_examples.append(
            {
                "row_index": int(row_index),
                "combined_text_excerpt": str(row.get("combined_text", ""))[:160],
                "pipeline_top_label": labels[int(pipeline_top[row_index])],
                "bundle_top_label": labels[int(bundle_top[row_index])],
                "row_max_abs_diff": float(abs_diff[row_index].max()),
            }
        )

    return {
        "row_count": int(len(feature_frame)),
        "class_count": int(bundle_probabilities.shape[1]),
        "max_abs_diff": float(abs_diff.max()) if abs_diff.size else 0.0,
        "mean_abs_diff": float(abs_diff.mean()) if abs_diff.size else 0.0,
        "top1_agreement": float((pipeline_top == bundle_top).mean()) if len(feature_frame) else 1.0,
        "worst_examples": worst_examples,
    }


def evaluate_tree(nodes: list[Mapping[str, Any]], feature_map: Mapping[int, float]) -> float:
    node_index = 0
    while True:
        node = nodes[node_index]
        if "leaf" in node:
            return float(node["leaf"])

        split_index = int(node["split_index"])
        if split_index not in feature_map:
            node_index = int(node["missing"])
            continue

        node_index = int(node["yes"] if feature_map[split_index] < float(node["threshold"]) else node["no"])


def char_wb_ngrams(text: str, *, min_n: int, max_n: int) -> list[str]:
    normalized = re.sub(r"\s+", " ", text.lower())
    ngrams: list[str] = []
    for word in normalized.split():
        padded_word = f" {word} "
        word_length = len(padded_word)
        for n in range(min_n, max_n + 1):
            offset = 0
            ngrams.append(padded_word[offset : min(word_length, offset + n)])
            while offset + n < word_length:
                offset += 1
                ngrams.append(padded_word[offset : min(word_length, offset + n)])
            if offset == 0:
                break
    return ngrams


def softmax(values: list[float]) -> list[float]:
    max_value = max(values)
    exp_values = [math.exp(value - max_value) for value in values]
    total = sum(exp_values)
    return [value / total for value in exp_values]


def looks_like_probability_matrix(probabilities: np.ndarray, *, tolerance: float = 1e-6) -> bool:
    if probabilities.ndim != 2 or probabilities.size == 0:
        return False
    if not np.all(np.isfinite(probabilities)):
        return False
    if np.any(probabilities < -tolerance) or np.any(probabilities > 1.0 + tolerance):
        return False
    row_sums = probabilities.sum(axis=1)
    return bool(np.all(np.abs(row_sums - 1.0) <= tolerance))


def row_softmax(logits: np.ndarray) -> np.ndarray:
    max_values = np.max(logits, axis=1, keepdims=True)
    exp_values = np.exp(logits - max_values)
    totals = exp_values.sum(axis=1, keepdims=True)
    return exp_values / totals


def build_generated_probability_candidates(
    raw_outputs: Any,
    *,
    objective_name: str,
    class_count: int,
) -> tuple[np.ndarray, dict[str, np.ndarray]]:
    raw_matrix = np.asarray(raw_outputs, dtype=float)
    if raw_matrix.ndim == 0:
        raw_matrix = raw_matrix.reshape(1, 1)
    elif raw_matrix.ndim == 1:
        raw_matrix = raw_matrix.reshape(-1, 1)
    elif raw_matrix.ndim != 2:
        raise ValueError(f"Unsupported generated output rank: {raw_matrix.ndim}")

    candidates: dict[str, np.ndarray] = {}

    if objective_name == "binary:logistic":
        if raw_matrix.shape[1] == 1:
            scalar_values = raw_matrix[:, 0]
            sigmoid_values = 1.0 / (1.0 + np.exp(-scalar_values))
            candidates["scalar_margin_sigmoid"] = np.column_stack(
                [1.0 - sigmoid_values, sigmoid_values]
            )
            if np.all(np.isfinite(scalar_values)) and np.all(
                (-1e-6 <= scalar_values) & (scalar_values <= 1.0 + 1e-6)
            ):
                clipped = np.clip(scalar_values, 0.0, 1.0)
                candidates["scalar_probability"] = np.column_stack(
                    [1.0 - clipped, clipped]
                )
        elif raw_matrix.shape[1] == 2:
            if looks_like_probability_matrix(raw_matrix):
                candidates["vector_probability"] = raw_matrix
            candidates["vector_softmax_logits"] = row_softmax(raw_matrix)
        else:
            raise ValueError(
                "Binary generated output must be scalar/1-column or 2-column; "
                f"received shape {raw_matrix.shape}."
            )
    else:
        if raw_matrix.shape[1] != class_count:
            raise ValueError(
                "Multiclass generated output column count mismatch: "
                f"expected {class_count}, received {raw_matrix.shape[1]}."
            )
        if looks_like_probability_matrix(raw_matrix):
            candidates["vector_probability"] = raw_matrix
        candidates["vector_softmax_logits"] = row_softmax(raw_matrix)

    if not candidates:
        raise ValueError("Could not derive any probability candidates from generated outputs.")

    return raw_matrix, candidates


def select_best_generated_probability_candidate(
    pipeline_probabilities: np.ndarray,
    raw_outputs: Any,
    *,
    objective_name: str,
    class_count: int,
) -> tuple[str, np.ndarray, dict[str, dict[str, Any]], np.ndarray]:
    raw_matrix, candidates = build_generated_probability_candidates(
        raw_outputs,
        objective_name=objective_name,
        class_count=class_count,
    )

    candidate_reports: dict[str, dict[str, Any]] = {}
    for name, candidate_probabilities in candidates.items():
        abs_diff = np.abs(pipeline_probabilities - candidate_probabilities)
        top1_agreement = float(
            (
                np.argmax(pipeline_probabilities, axis=1)
                == np.argmax(candidate_probabilities, axis=1)
            ).mean()
        )
        candidate_reports[name] = {
            "max_abs_diff": float(abs_diff.max()) if abs_diff.size else 0.0,
            "mean_abs_diff": float(abs_diff.mean()) if abs_diff.size else 0.0,
            "top1_agreement": top1_agreement,
            "row_count": int(candidate_probabilities.shape[0]),
            "column_count": int(candidate_probabilities.shape[1]),
        }

    best_name = min(
        candidate_reports,
        key=lambda name: (
            1.0 - float(candidate_reports[name]["top1_agreement"]),
            float(candidate_reports[name]["mean_abs_diff"]),
            float(candidate_reports[name]["max_abs_diff"]),
        ),
    )
    return best_name, candidates[best_name], candidate_reports, raw_matrix


def prepare_xgb_estimator_for_m2cgen(model: Any) -> Any:
    prepared_model = copy.deepcopy(model)
    booster_base_scores = extract_booster_base_scores(prepared_model)
    config = json.loads(prepared_model.get_booster().save_config())
    objective_name = config["learner"]["objective"]["name"]
    if prepared_model.get_params().get("num_parallel_tree") is None:
        prepared_model.set_params(num_parallel_tree=1)
    if (
        objective_name == "binary:logistic"
        and prepared_model.get_params().get("base_score") is None
        and booster_base_scores
    ):
        prepared_model.set_params(base_score=float(np.float32(booster_base_scores[0])))
    patched_booster = _PatchedBoosterForM2cgen(prepared_model.get_booster())
    prepared_model.get_booster = lambda: patched_booster
    return prepared_model


def extract_booster_base_scores(model: Any) -> list[float]:
    config = json.loads(model.get_booster().save_config())
    objective_name = config["learner"]["objective"]["name"]
    class_count = int(config["learner"]["learner_model_param"].get("num_class", 1))
    return _parse_base_scores(
        config["learner"]["learner_model_param"]["base_score"],
        objective_name=objective_name,
        class_count=class_count,
    )


def patch_m2cgen_multiclass_code(code: str, base_scores: list[float]) -> str:
    if not base_scores:
        return code

    placeholder = "nan + ("
    placeholder_count = code.count(placeholder)
    if placeholder_count == 0:
        return code

    if placeholder_count != len(base_scores):
        raise ValueError(
            "Unexpected number of m2cgen multiclass base-score placeholders: "
            f"expected {len(base_scores)}, found {placeholder_count}."
        )

    patched = code
    for base_score in base_scores:
        replacement = f"({base_score:.17g}) + ("
        patched = patched.replace(placeholder, replacement, 1)
    return patched


def export_m2cgen_source(model: Any, *, language: str) -> str:
    try:
        import m2cgen as m2c
    except ImportError as exc:  # pragma: no cover
        raise ImportError(
            "m2cgen is required for Dart/Python source export. "
            "Install it with `python -m pip install m2cgen`."
        ) from exc

    prepared_model = prepare_xgb_estimator_for_m2cgen(model)
    exporter_name = f"export_to_{language}"
    if not hasattr(m2c, exporter_name):
        raise ValueError(f"m2cgen does not support language '{language}'.")

    exporter = getattr(m2c, exporter_name)
    code = exporter(prepared_model)
    base_scores = extract_booster_base_scores(prepared_model)
    return patch_m2cgen_multiclass_code(code, base_scores)


def save_json(path: Path, payload: Any, *, compact: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        if compact:
            json.dump(payload, handle, ensure_ascii=False, separators=(",", ":"))
            handle.write("\n")
            return
        json.dump(payload, handle, indent=2, ensure_ascii=False)
        handle.write("\n")


def _transformer_columns(features: Any, transformer_name: str) -> Any:
    for name, _transformer, columns in features.transformers_:
        if name == transformer_name:
            return columns
    raise ValueError(f"Could not find transformer named '{transformer_name}'.")


def _parse_base_scores(base_score_raw: str, *, objective_name: str, class_count: int) -> list[float]:
    parsed = json.loads(base_score_raw)
    if isinstance(parsed, list):
        base_scores = [float(np.float32(value)) for value in parsed]
    else:
        base_scores = [float(np.float32(parsed))]

    if objective_name == "binary:logistic":
        return base_scores[:1]
    if len(base_scores) != class_count:
        raise ValueError(
            f"Expected {class_count} multiclass base scores, got {len(base_scores)}."
        )
    return base_scores


def _flatten_tree(tree: Mapping[str, Any]) -> dict[str, Any]:
    max_node_id = _max_node_id(tree)
    nodes: list[dict[str, Any]] = [{} for _ in range(max_node_id + 1)]

    def visit(node: Mapping[str, Any]) -> None:
        node_id = int(node["nodeid"])
        if "leaf" in node:
            nodes[node_id] = {"leaf": float(np.float32(node["leaf"]))}
            return

        nodes[node_id] = {
            "split_index": int(str(node["split"]).lstrip("f")),
            "threshold": float(np.float32(node["split_condition"])),
            "yes": int(node["yes"]),
            "no": int(node["no"]),
            "missing": int(node["missing"]),
        }
        for child in node.get("children", []):
            visit(child)

    visit(tree)
    return {"nodes": nodes}


def _max_node_id(tree: Mapping[str, Any]) -> int:
    max_node_id = int(tree["nodeid"])
    for child in tree.get("children", []):
        max_node_id = max(max_node_id, _max_node_id(child))
    return max_node_id


def _quantize_tree_dump_node(node: Mapping[str, Any]) -> dict[str, Any]:
    quantized = dict(node)
    if "leaf" in quantized:
        quantized["leaf"] = float(np.float32(quantized["leaf"]))
        return quantized

    quantized["split_condition"] = float(np.float32(quantized["split_condition"]))
    quantized["children"] = [
        _quantize_tree_dump_node(child) for child in quantized.get("children", [])
    ]
    return quantized


class _PatchedBoosterForM2cgen:
    def __init__(self, booster: Any) -> None:
        self._booster = booster
        self.feature_names = booster.feature_names

    def get_dump(self, *args: Any, **kwargs: Any) -> list[str]:
        dump_format = kwargs.get("dump_format")
        if dump_format is None and args:
            dump_format = args[0]

        dumps = self._booster.get_dump(*args, **kwargs)
        if dump_format != "json":
            return dumps

        return [
            json.dumps(_quantize_tree_dump_node(json.loads(tree_json)))
            for tree_json in dumps
        ]

    def __getattr__(self, name: str) -> Any:
        return getattr(self._booster, name)


def _is_missing(value: Any) -> bool:
    if value is None:
        return True
    try:
        return bool(np.isnan(value))
    except TypeError:
        return False

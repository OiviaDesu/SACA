from __future__ import annotations

import json
import re
import shutil
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd
from scipy import sparse
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.preprocessing import OneHotEncoder

TEXT_DATASETS = {
    "Symptom2Disease.csv": (("text_input", "text"), ("disease_label", "label")),
    "train.jsonl.csv": (("input_text", "text_input", "text"), ("output_text", "disease_label", "label")),
    "normalized_diagnosis_dataset.csv": (("symptoms_text", "text_input", "text"), ("diagnosis_label", "disease_label", "label")),
    "lavita_medquad.csv": (("answer",), ("question_focus",)),
    "medical_conversations.csv": (("conversations",), ("disease",)),
}

TEXT_SOURCE_CANDIDATES = [
    Path("mlp"),
    Path("python_pipeline") / "data",
]
STRUCTURED_SOURCE_CANDIDATES = [Path("saca_custom.xlsx")]
INDICATOR_COLUMNS = ["has_real_severity", "has_real_symptoms", "source_og", "source_saca"]
FEATURE_SETS = {
    "og_text": {"text"},
    "saca_custom": {"symptoms", "severity", "indicators"},
    "hybrid": {"text", "symptoms", "severity", "indicators"},
    "text_only": {"text"},
    "symptoms_only": {"symptoms", "indicators"},
    "severity_only": {"severity", "indicators"},
    "symptoms_severity": {"symptoms", "severity", "indicators"},
    "full": {"text", "symptoms", "severity", "indicators"},
}
SEVERE_TERMS = [
    "severe",
    "sharp",
    "shortness of breath",
    "breathless",
    "dyspnea",
    "chest pain",
    "bleeding",
    "unconscious",
    "fainting",
    "palpitations",
    "worst",
]
MILD_TERMS = ["mild", "slight", "minor", "little", "low grade"]
SYMPTOM_SYNONYMS = {
    "shortness of breath": ["dyspnea", "breathless", "breathing difficulty", "difficulty breathing"],
    "sore throat": ["throat pain", "scratchy throat"],
    "runny nose": ["rhinorrhea", "running nose", "nasal discharge"],
    "chest pain": ["chest tightness", "chest pressure"],
    "abdominal pain": ["stomach pain", "belly pain", "tummy pain"],
    "nausea": ["feeling sick", "queasy"],
    "vomiting": ["throwing up", "emesis"],
    "diarrhea": ["loose stools", "diarrhoea"],
    "fever": ["high temperature", "pyrexia"],
    "cough": ["coughing"],
    "headache": ["head pain"],
    "dizziness": ["lightheaded", "light headed", "vertigo"],
}


@dataclass(frozen=True)
class HybridDataset:
    frame: pd.DataFrame
    symptom_columns: list[str]
    inventory: dict[str, Any]


def project_root_from_pipeline(pipeline_root: Path) -> Path:
    return pipeline_root.resolve().parent


def default_pipeline_root() -> Path:
    return Path(__file__).resolve().parents[1]


def prepare_hybrid_data(pipeline_root: Path | None = None) -> dict[str, Any]:
    pipeline_root = (pipeline_root or default_pipeline_root()).resolve()
    project_root = project_root_from_pipeline(pipeline_root)
    raw_text_dir = pipeline_root / "data" / "raw" / "text"
    raw_structured_dir = pipeline_root / "data" / "raw" / "structured"
    processed_dir = pipeline_root / "data" / "processed" / "hybrid"
    raw_text_dir.mkdir(parents=True, exist_ok=True)
    raw_structured_dir.mkdir(parents=True, exist_ok=True)
    processed_dir.mkdir(parents=True, exist_ok=True)

    copied: list[dict[str, Any]] = []
    for filename in TEXT_DATASETS:
        destination = raw_text_dir / filename
        source = _find_existing_file(project_root, TEXT_SOURCE_CANDIDATES, filename)
        if source is not None:
            if source.resolve() != destination.resolve():
                shutil.copy2(source, destination)
            copied.append(_file_record(destination, source=source))

    structured_destination = raw_structured_dir / "saca_custom.xlsx"
    structured_csv_destination = raw_structured_dir / "saca_custom.csv"
    structured_source = _find_existing_file(project_root, STRUCTURED_SOURCE_CANDIDATES, "")
    if structured_source is not None:
        if structured_source.resolve() != structured_destination.resolve():
            shutil.copy2(structured_source, structured_destination)
        copied.append(_file_record(structured_destination, source=structured_source))
        if not structured_csv_destination.exists() or structured_csv_destination.stat().st_mtime < structured_destination.stat().st_mtime:
            pd.read_excel(structured_destination, sheet_name="in").to_csv(structured_csv_destination, index=False)
        copied.append(_file_record(structured_csv_destination, source=structured_destination))

    inventory = {
        "pipeline_root": str(pipeline_root),
        "project_root": str(project_root),
        "raw_text_dir": str(raw_text_dir),
        "raw_structured_dir": str(raw_structured_dir),
        "files": copied,
    }
    (processed_dir / "dataset_inventory.json").write_text(
        json.dumps(inventory, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    return inventory


def load_hybrid_dataset(
    data_root: Path,
    min_class_count: int = 10,
    sample_per_class: int | None = None,
    dataset_mode: str = "hybrid",
) -> HybridDataset:
    data_root = data_root.resolve()
    raw_text_dir = data_root / "raw" / "text"
    raw_structured_dir = data_root / "raw" / "structured"
    text_frames = load_text_frames(raw_text_dir)
    structured_frame, symptom_columns = load_structured_frame(raw_structured_dir)
    if dataset_mode == "og_text":
        frame = pd.concat(text_frames, ignore_index=True)
    elif dataset_mode == "saca_custom":
        frame = structured_frame.copy()
    elif dataset_mode == "hybrid":
        frame = pd.concat([*text_frames, structured_frame], ignore_index=True)
    else:
        raise ValueError(f"Unknown dataset_mode: {dataset_mode}")
    frame["text_input"] = frame["text_input"].fillna("").astype(str).map(normalize_text)
    frame["disease_label"] = frame["disease_label"].fillna("").astype(str).map(normalize_label)
    frame["Severity"] = frame["Severity"].fillna("unknown").astype(str).map(normalize_label)
    text_mask = frame["source_type"].astype(str).eq("text")
    frame.loc[text_mask, "Severity"] = frame.loc[text_mask, "text_input"].map(infer_severity_from_text)
    frame["has_real_severity"] = frame["source_type"].astype(str).eq("structured").astype(np.float32)
    frame["has_real_symptoms"] = frame["source_type"].astype(str).eq("structured").astype(np.float32)
    frame["source_og"] = frame["source_type"].astype(str).eq("text").astype(np.float32)
    frame["source_saca"] = frame["source_type"].astype(str).eq("structured").astype(np.float32)
    frame = frame[(frame["text_input"] != "") & (frame["disease_label"] != "")].copy()
    frame = frame.drop_duplicates(subset=["text_input", "disease_label", "source"])
    counts = frame["disease_label"].value_counts()
    valid_classes = counts[counts >= min_class_count].index
    frame = frame[frame["disease_label"].isin(valid_classes)].copy()
    if sample_per_class is not None:
        frame = frame.groupby("disease_label", group_keys=False).head(sample_per_class).reset_index(drop=True)

    missing_symptom_columns = [column for column in symptom_columns if column not in frame]
    if missing_symptom_columns:
        frame = pd.concat(
            [
                frame,
                pd.DataFrame(0, index=frame.index, columns=missing_symptom_columns, dtype=np.float32),
            ],
            axis=1,
        )
    for column in symptom_columns:
        frame[column] = pd.to_numeric(frame[column], errors="coerce").fillna(0).astype(np.float32)

    inventory = {
        "rows": int(len(frame)),
        "classes": int(frame["disease_label"].nunique()),
        "text_rows": int((frame["source_type"] == "text").sum()),
        "structured_rows": int((frame["source_type"] == "structured").sum()),
        "symptom_columns": len(symptom_columns),
        "og_symptom_coverage": symptom_coverage(frame, symptom_columns, "text"),
        "saca_symptom_coverage": symptom_coverage(frame, symptom_columns, "structured"),
        "severity_counts": frame["Severity"].value_counts().to_dict(),
        "min_class_count": min_class_count,
        "sample_per_class": sample_per_class,
        "dataset_mode": dataset_mode,
    }
    return HybridDataset(frame=frame.reset_index(drop=True), symptom_columns=symptom_columns, inventory=inventory)


def load_text_frames(raw_text_dir: Path) -> list[pd.DataFrame]:
    frames: list[pd.DataFrame] = []
    for filename, (text_columns, label_columns) in TEXT_DATASETS.items():
        path = raw_text_dir / filename
        if not path.exists():
            continue
        frame = pd.read_csv(path, encoding="utf-8", encoding_errors="replace")
        text_column = first_present_column(frame, text_columns, filename)
        label_column = first_present_column(frame, label_columns, filename)
        if filename == "lavita_medquad.csv" and "question_type" in frame.columns:
            frame = frame[frame["question_type"].isin(["symptoms", "information"])]
        if filename == "medical_conversations.csv":
            text = frame[text_column].map(extract_user_text)
        else:
            text = frame[text_column].astype(str)
        normalized = pd.DataFrame(
            {
                "text_input": text,
                "disease_label": frame[label_column].astype(str),
                "Severity": "unknown",
                "source": filename,
                "source_type": "text",
            }
        )
        frames.append(normalized)
    if not frames:
        raise FileNotFoundError(f"No text datasets found in {raw_text_dir}")
    return frames


def first_present_column(frame: pd.DataFrame, candidates: tuple[str, ...], filename: str) -> str:
    for column in candidates:
        if column in frame.columns:
            return column
    raise ValueError(f"{filename} missing expected columns: {list(candidates)}")


def load_structured_frame(raw_structured_dir: Path) -> tuple[pd.DataFrame, list[str]]:
    csv_path = raw_structured_dir / "saca_custom.csv"
    xlsx_path = raw_structured_dir / "saca_custom.xlsx"
    if csv_path.exists():
        frame = pd.read_csv(csv_path, encoding="utf-8", encoding_errors="replace")
    elif xlsx_path.exists():
        frame = pd.read_excel(xlsx_path, sheet_name="in")
    else:
        raise FileNotFoundError(f"Structured dataset missing: {csv_path} or {xlsx_path}")
    required = {"diseases", "Severity"}
    missing = required.difference(frame.columns)
    if missing:
        raise ValueError(f"saca_custom.xlsx missing columns: {sorted(missing)}")
    symptom_columns = [column for column in frame.columns if column not in required]
    symptom_values = frame[symptom_columns].apply(pd.to_numeric, errors="coerce").fillna(0).astype(np.float32)
    text_input = symptom_values.apply(lambda row: symptoms_to_text(row, symptom_columns), axis=1)
    output = pd.concat(
        [
            pd.DataFrame(
                {
                    "text_input": text_input,
                    "disease_label": frame["diseases"],
                    "Severity": frame["Severity"],
                    "source": "saca_custom.xlsx",
                    "source_type": "structured",
                },
                index=frame.index,
            ),
            symptom_values,
        ],
        axis=1,
    )
    return output[["text_input", "disease_label", "Severity", "source", "source_type", *symptom_columns]], symptom_columns


def build_hybrid_features(
    train_frame: pd.DataFrame,
    eval_frame: pd.DataFrame | None,
    symptom_columns: list[str],
    max_text_features: int = 3000,
    feature_mode: str = "hybrid",
    feature_set: str | None = None,
) -> tuple[sparse.csr_matrix, sparse.csr_matrix | None, dict[str, Any]]:
    vectorizer = TfidfVectorizer(max_features=max_text_features, analyzer="word", stop_words="english")
    severity_encoder = OneHotEncoder(handle_unknown="ignore", sparse_output=True)

    if feature_mode not in {"og_text", "saca_custom", "hybrid"}:
        raise ValueError(f"Unknown feature_mode: {feature_mode}")
    feature_set = feature_set or feature_mode
    if feature_set not in FEATURE_SETS:
        raise ValueError(f"Unknown feature_set: {feature_set}")
    selected_features = FEATURE_SETS[feature_set]
    use_text = "text" in selected_features
    use_symptoms = "symptoms" in selected_features
    use_severity = "severity" in selected_features
    use_indicators = "indicators" in selected_features

    train_parts = []
    eval_parts = []
    feature_counts = {"tfidf": 0, "symptoms": 0, "severity": 0, "missing_flags": 0}

    if use_text:
        X_train_text = vectorizer.fit_transform(train_frame["text_input"].fillna("").astype(str))
        train_parts.append(X_train_text)
        feature_counts["tfidf"] = int(X_train_text.shape[1])
        if eval_frame is not None:
            eval_parts.append(vectorizer.transform(eval_frame["text_input"].fillna("").astype(str)))
    else:
        vectorizer = None

    if use_symptoms:
        X_train_symptoms = symptom_matrix(train_frame, symptom_columns)
        train_parts.append(X_train_symptoms)
        feature_counts["symptoms"] = int(X_train_symptoms.shape[1])
        if eval_frame is not None:
            eval_parts.append(symptom_matrix(eval_frame, symptom_columns))

    if use_severity:
        X_train_severity = severity_encoder.fit_transform(train_frame[["Severity"]].astype(str))
        train_parts.append(X_train_severity)
        feature_counts["severity"] = int(X_train_severity.shape[1])
        if eval_frame is not None:
            eval_parts.append(severity_encoder.transform(eval_frame[["Severity"]].astype(str)))
    else:
        severity_encoder = None

    if use_indicators:
        X_train_indicators = indicator_matrix(train_frame)
        train_parts.append(X_train_indicators)
        feature_counts["missing_flags"] = int(X_train_indicators.shape[1])
        if eval_frame is not None:
            eval_parts.append(indicator_matrix(eval_frame))

    if not train_parts:
        raise ValueError(f"Feature set has no enabled features: {feature_set}")

    X_train = sparse.hstack(train_parts, format="csr")
    X_eval = sparse.hstack(eval_parts, format="csr") if eval_frame is not None else None
    feature_counts["total"] = int(X_train.shape[1])

    metadata = {
        "vectorizer": vectorizer,
        "severity_encoder": severity_encoder,
        "feature_mode": feature_mode,
        "feature_set": feature_set,
        "selected_features": sorted(selected_features),
        "feature_counts": feature_counts,
    }

    return X_train, X_eval, metadata


def symptom_matrix(frame: pd.DataFrame, symptom_columns: list[str]) -> sparse.csr_matrix:
    matrix = frame.reindex(columns=symptom_columns, fill_value=0).copy()
    text_mask = frame["source_type"].astype(str).eq("text") if "source_type" in frame else pd.Series(False, index=frame.index)
    if text_mask.any():
        inferred = infer_symptoms_from_text(frame.loc[text_mask, "text_input"], symptom_columns)
        matrix.loc[text_mask, symptom_columns] = inferred
    matrix = matrix.apply(pd.to_numeric, errors="coerce").fillna(0).clip(0, 1)
    return sparse.csr_matrix(matrix.to_numpy(dtype=np.float32))


def indicator_matrix(frame: pd.DataFrame) -> sparse.csr_matrix:
    matrix = frame.reindex(columns=INDICATOR_COLUMNS, fill_value=0)
    matrix = matrix.apply(pd.to_numeric, errors="coerce").fillna(0).clip(0, 1)
    return sparse.csr_matrix(matrix.to_numpy(dtype=np.float32))


def infer_symptoms_from_text(texts: pd.Series, symptom_columns: list[str]) -> np.ndarray:
    patterns = [(column, [_compile_phrase(column), *[_compile_phrase(alias) for alias in SYMPTOM_SYNONYMS.get(column, [])]]) for column in symptom_columns]
    rows: list[list[float]] = []
    for text in texts.fillna("").astype(str).map(normalize_text):
        rows.append([1.0 if any(pattern.search(text) for pattern in column_patterns) else 0.0 for _, column_patterns in patterns])
    return np.asarray(rows, dtype=np.float32)


def infer_severity_from_text(text: Any) -> str:
    normalized = normalize_text(text)
    if any(_compile_phrase(term).search(normalized) for term in SEVERE_TERMS):
        return "severe"
    if any(_compile_phrase(term).search(normalized) for term in MILD_TERMS):
        return "mild"
    return "unknown"


def symptom_coverage(frame: pd.DataFrame, symptom_columns: list[str], source_type: str) -> float:
    source_mask = frame["source_type"].astype(str).eq(source_type)
    if not source_mask.any():
        return 0.0
    matrix = symptom_matrix(frame.loc[source_mask], symptom_columns)
    return float((np.asarray(matrix.sum(axis=1)).ravel() > 0).mean())


def extract_user_text(conversation: Any) -> str:
    lines = str(conversation).split("</s>")
    return " ".join(line.replace("User:", "").strip() for line in lines if line.strip().startswith("User:"))


def symptoms_to_text(row: pd.Series, symptom_columns: list[str]) -> str:
    active = [column for column in symptom_columns if float(row.get(column, 0) or 0) > 0]
    severity = normalize_label(row.get("Severity", "unknown"))
    return " ".join(["severity", severity, "symptoms", *active]).strip()


def _compile_phrase(value: str) -> re.Pattern[str]:
    return re.compile(r"\b" + re.escape(normalize_text(value)) + r"\b")


def normalize_text(value: Any) -> str:
    return re.sub(r"\s+", " ", str(value).lower().strip())


def normalize_label(value: Any) -> str:
    return normalize_text(value).replace("_", " ")


def _find_existing_file(project_root: Path, candidates: list[Path], filename: str) -> Path | None:
    for candidate in candidates:
        path = project_root / candidate if filename == "" else project_root / candidate / filename
        if path.exists():
            return path
    return None


def _file_record(destination: Path, *, source: Path) -> dict[str, Any]:
    return {
        "name": destination.name,
        "source": str(source),
        "destination": str(destination),
        "bytes": int(destination.stat().st_size),
    }





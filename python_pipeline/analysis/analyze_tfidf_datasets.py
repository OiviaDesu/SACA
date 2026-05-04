"""Analyze local datasets with word and character n-gram TF-IDF features."""

from __future__ import annotations

import argparse
import json
import re
import zipfile
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable
import xml.etree.ElementTree as ET

import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns
from sklearn.feature_extraction.text import CountVectorizer, TfidfVectorizer


PIPELINE_ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = PIPELINE_ROOT / "data"
OUT_DIR = PIPELINE_ROOT / "outputs" / "tfidf_dataset_analysis"
SUPPORTED_SUFFIXES = {".csv", ".xlsx", ".xls"}
TOP_TOKEN_LIMIT = 50
PLOT_TOKEN_LIMIT = 30


@dataclass(frozen=True)
class DatasetSpec:
    file_name: str
    text_columns: tuple[str, ...]
    label_columns: tuple[str, ...] = ()
    wide_symptom_columns: bool = False


DATASET_SPECS = {
    "bi55_medtext.csv": DatasetSpec("bi55_medtext.csv", ("Prompt", "Completion"), ("split",)),
    "Final_Augmented_dataset_Diseases_and_Symptoms.csv": DatasetSpec(
        "Final_Augmented_dataset_Diseases_and_Symptoms.csv",
        (),
        ("diseases",),
        wide_symptom_columns=True,
    ),
    "gretel_symptom_to_diagnosis.csv": DatasetSpec(
        "gretel_symptom_to_diagnosis.csv",
        ("input_text",),
        ("output_text",),
    ),
    "Healthcare.csv": DatasetSpec("Healthcare.csv", ("Symptoms",), ("Disease",)),
    "lavita_medquad.csv": DatasetSpec(
        "lavita_medquad.csv",
        ("question", "answer", "question_focus", "category"),
    ),
    "medical_conversations.csv": DatasetSpec(
        "medical_conversations.csv",
        ("conversations",),
        ("disease",),
    ),
    "normalized_diagnosis_dataset.csv": DatasetSpec(
        "normalized_diagnosis_dataset.csv",
        ("symptoms_text",),
        ("diagnosis_label", "source", "language"),
    ),
    "Symptom2Disease.csv": DatasetSpec("Symptom2Disease.csv", ("text",), ("label",)),
    "gurindji_dict_full.xlsx": DatasetSpec(
        "gurindji_dict_full.xlsx",
        ("gurindji", "english"),
        ("type",),
    ),
    "gurindji_dict_medical.xlsx": DatasetSpec(
        "gurindji_dict_medical.xlsx",
        ("gurindji", "english"),
        ("type",),
    ),
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="List datasets, compare word TF-IDF vs char n-gram TF-IDF, and plot token frequencies."
    )
    parser.add_argument("--data-dir", type=Path, default=DATA_DIR)
    parser.add_argument("--out-dir", type=Path, default=OUT_DIR)
    parser.add_argument("--top-n", type=int, default=TOP_TOKEN_LIMIT)
    return parser.parse_args()


def normalize_column_name(value: object) -> str:
    text = str(value).strip()
    text = re.sub(r"\s+", "_", text)
    return text


def read_dataset(path: Path) -> pd.DataFrame:
    if path.suffix.lower() == ".csv":
        frame = pd.read_csv(path, low_memory=False)
    else:
        frame = read_excel_dataset(path)
    frame.columns = [normalize_column_name(column) for column in frame.columns]
    return frame


def read_excel_dataset(path: Path) -> pd.DataFrame:
    try:
        return pd.read_excel(path)
    except ImportError as error:
        if "openpyxl" not in str(error):
            raise
        return read_xlsx_first_sheet_without_openpyxl(path)


def read_xlsx_first_sheet_without_openpyxl(path: Path) -> pd.DataFrame:
    namespace = {"x": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
    with zipfile.ZipFile(path) as archive:
        shared_strings = read_xlsx_shared_strings(archive, namespace)
        sheet_xml = archive.read("xl/worksheets/sheet1.xml")
    root = ET.fromstring(sheet_xml)
    rows = []
    for row in root.findall(".//x:sheetData/x:row", namespace):
        values_by_column = {}
        for cell in row.findall("x:c", namespace):
            column_index = xlsx_column_index(cell.attrib.get("r", ""))
            values_by_column[column_index] = read_xlsx_cell(cell, shared_strings, namespace)
        if values_by_column:
            width = max(values_by_column) + 1
            rows.append([values_by_column.get(index, "") for index in range(width)])
    if not rows:
        return pd.DataFrame()
    width = max(len(row) for row in rows)
    padded = [row + [None] * (width - len(row)) for row in rows]
    header = [normalize_column_name(value) for value in padded[0]]
    return pd.DataFrame(padded[1:], columns=header)


def read_xlsx_shared_strings(archive: zipfile.ZipFile, namespace: dict[str, str]) -> list[str]:
    try:
        root = ET.fromstring(archive.read("xl/sharedStrings.xml"))
    except KeyError:
        return []
    strings = []
    for item in root.findall("x:si", namespace):
        parts = [node.text or "" for node in item.findall(".//x:t", namespace)]
        strings.append("".join(parts))
    return strings


def xlsx_column_index(cell_ref: str) -> int:
    letters = re.sub(r"[^A-Z]", "", cell_ref.upper())
    index = 0
    for letter in letters:
        index = index * 26 + (ord(letter) - ord("A") + 1)
    return max(index - 1, 0)


def read_xlsx_cell(cell: ET.Element, shared_strings: list[str], namespace: dict[str, str]) -> object:
    cell_type = cell.attrib.get("t")
    if cell_type == "inlineStr":
        parts = [node.text or "" for node in cell.findall(".//x:t", namespace)]
        return "".join(parts)
    value = cell.find("x:v", namespace)
    if value is None or value.text is None:
        return ""
    if cell_type == "s":
        return shared_strings[int(value.text)]
    return value.text


def active_wide_symptoms(frame: pd.DataFrame, label_columns: Iterable[str]) -> pd.Series:
    label_set = set(label_columns)
    symptom_columns = [column for column in frame.columns if column not in label_set]
    symptom_frame = frame[symptom_columns].apply(pd.to_numeric, errors="coerce").fillna(0)

    def row_to_text(row: pd.Series) -> str:
        active_columns = [column for column, value in row.items() if value > 0]
        return " ".join(active_columns)

    return symptom_frame.apply(row_to_text, axis=1)


def infer_text_columns(frame: pd.DataFrame, label_columns: set[str]) -> list[str]:
    object_columns = [
        column
        for column in frame.columns
        if column not in label_columns and pd.api.types.is_object_dtype(frame[column])
    ]
    scored = []
    for column in object_columns:
        values = frame[column].dropna().astype(str)
        mean_length = float(values.str.len().mean()) if len(values) else 0.0
        scored.append((mean_length, column))
    return [column for _, column in sorted(scored, reverse=True)[:3]]


def build_corpus(frame: pd.DataFrame, spec: DatasetSpec) -> tuple[pd.Series, list[str], list[str]]:
    available_labels = [column for column in spec.label_columns if column in frame.columns]
    if spec.wide_symptom_columns:
        corpus = active_wide_symptoms(frame, available_labels)
        return corpus, ["active_symptom_columns"], available_labels

    text_columns = [column for column in spec.text_columns if column in frame.columns]
    if not text_columns:
        text_columns = infer_text_columns(frame, set(available_labels))
    if not text_columns:
        corpus = pd.Series([""] * len(frame), index=frame.index)
    else:
        corpus = frame[text_columns].fillna("").astype(str).agg(" ".join, axis=1)
    corpus = corpus.str.replace(r"\s+", " ", regex=True).str.strip()
    return corpus, text_columns, available_labels


def dataset_files(data_dir: Path) -> list[Path]:
    return sorted(
        path for path in data_dir.rglob("*") if path.is_file() and path.suffix.lower() in SUPPORTED_SUFFIXES
    )


def vectorizer_pair(kind: str) -> tuple[TfidfVectorizer, CountVectorizer]:
    if kind == "word":
        kwargs = {
            "analyzer": "word",
            "ngram_range": (1, 1),
            "lowercase": True,
            "stop_words": "english",
            "min_df": 1,
        }
    elif kind == "char_wb_ngram":
        kwargs = {
            "analyzer": "char_wb",
            "ngram_range": (3, 5),
            "lowercase": True,
            "min_df": 1,
        }
    else:
        raise ValueError(f"Unknown vectorizer kind: {kind}")
    return TfidfVectorizer(**kwargs), CountVectorizer(**kwargs)


def top_tokens(dataset: str, corpus: pd.Series, kind: str, top_n: int) -> tuple[pd.DataFrame, dict[str, object]]:
    non_empty = corpus[corpus.astype(str).str.len() > 0].astype(str)
    if non_empty.empty:
        return pd.DataFrame(), {
            "dataset": dataset,
            "vectorizer": kind,
            "documents": 0,
            "vocabulary_size": 0,
            "total_token_frequency": 0,
            "mean_nonzero_features": 0.0,
        }

    tfidf_vectorizer, count_vectorizer = vectorizer_pair(kind)
    tfidf_matrix = tfidf_vectorizer.fit_transform(non_empty)
    count_vectorizer.set_params(vocabulary=tfidf_vectorizer.vocabulary_)
    count_matrix = count_vectorizer.fit_transform(non_empty)
    features = tfidf_vectorizer.get_feature_names_out()
    frequencies = count_matrix.sum(axis=0).A1
    tfidf_sums = tfidf_matrix.sum(axis=0).A1
    order = frequencies.argsort()[::-1][:top_n]
    rows = [
        {
            "dataset": dataset,
            "vectorizer": kind,
            "token": features[index],
            "frequency": int(frequencies[index]),
            "tfidf_sum": float(tfidf_sums[index]),
        }
        for index in order
    ]
    summary = {
        "dataset": dataset,
        "vectorizer": kind,
        "documents": int(tfidf_matrix.shape[0]),
        "vocabulary_size": int(len(features)),
        "total_token_frequency": int(frequencies.sum()),
        "mean_nonzero_features": float(tfidf_matrix.getnnz(axis=1).mean()),
    }
    return pd.DataFrame(rows), summary


def plot_top_tokens(tokens: pd.DataFrame, out_dir: Path) -> None:
    plot_frame = tokens.groupby(["dataset", "vectorizer"]).head(PLOT_TOKEN_LIMIT).copy()
    for (dataset, vectorizer), group in plot_frame.groupby(["dataset", "vectorizer"]):
        safe_dataset = re.sub(r"[^A-Za-z0-9_.-]+", "_", dataset)
        fig_height = max(6, len(group) * 0.22)
        plt.figure(figsize=(12, fig_height))
        sns.barplot(data=group, x="frequency", y="token", color="#4C78A8")
        plt.title(f"Top {min(PLOT_TOKEN_LIMIT, len(group))} token frequencies: {dataset} ({vectorizer})")
        plt.xlabel("Raw token frequency in vectorizer vocabulary")
        plt.ylabel("Token")
        plt.tight_layout()
        plt.savefig(out_dir / f"top_tokens_{safe_dataset}_{vectorizer}.png", dpi=160)
        plt.close()


def plot_vocab_summary(summary: pd.DataFrame, out_dir: Path) -> None:
    plt.figure(figsize=(14, 7))
    sns.barplot(data=summary, x="dataset", y="vocabulary_size", hue="vectorizer")
    plt.xticks(rotation=45, ha="right")
    plt.title("Vocabulary size: word TF-IDF vs char_wb n-gram TF-IDF")
    plt.xlabel("Dataset")
    plt.ylabel("Vocabulary size")
    plt.tight_layout()
    plt.savefig(out_dir / "vocabulary_size_comparison.png", dpi=160)
    plt.close()


def main() -> None:
    args = parse_args()
    args.out_dir.mkdir(parents=True, exist_ok=True)
    sns.set_theme(style="whitegrid")

    inventory_rows = []
    token_frames = []
    summary_rows = []
    combined_parts = []

    for path in dataset_files(args.data_dir):
        print(f"[load] {path.name}", flush=True)
        frame = read_dataset(path)
        spec = DATASET_SPECS.get(path.name, DatasetSpec(path.name, ()))
        corpus, text_columns, label_columns = build_corpus(frame, spec)
        combined_parts.append(pd.Series(corpus.astype(str), name=path.name))
        inventory_rows.append(
            {
                "file": path.name,
                "size_bytes": int(path.stat().st_size),
                "rows": int(len(frame)),
                "columns": int(len(frame.columns)),
                "text_columns": ";".join(text_columns),
                "label_columns": ";".join(label_columns),
                "empty_text_rows": int((corpus.astype(str).str.len() == 0).sum()),
                "duplicate_text_rows": int(corpus.duplicated().sum()),
                "missing_cells": int(frame.isna().sum().sum()),
            }
        )
        for kind in ("word", "char_wb_ngram"):
            print(f"[tfidf] {path.name} {kind}", flush=True)
            tokens, summary = top_tokens(path.name, corpus, kind, args.top_n)
            token_frames.append(tokens)
            summary_rows.append(summary)

    combined_corpus = pd.concat(combined_parts, ignore_index=True)
    for kind in ("word", "char_wb_ngram"):
        print(f"[tfidf] ALL_DATASETS {kind}", flush=True)
        tokens, summary = top_tokens("ALL_DATASETS", combined_corpus, kind, args.top_n)
        token_frames.append(tokens)
        summary_rows.append(summary)

    inventory = pd.DataFrame(inventory_rows)
    all_tokens = pd.concat(token_frames, ignore_index=True)
    summary = pd.DataFrame(summary_rows)
    word_tokens = all_tokens[all_tokens["vectorizer"] == "word"]
    ngram_tokens = all_tokens[all_tokens["vectorizer"] == "char_wb_ngram"]

    inventory.to_csv(args.out_dir / "dataset_inventory.csv", index=False)
    word_tokens.to_csv(args.out_dir / "tfidf_word_top_tokens.csv", index=False)
    ngram_tokens.to_csv(args.out_dir / "tfidf_ngram_top_tokens.csv", index=False)
    summary.to_csv(args.out_dir / "tfidf_comparison_summary.csv", index=False)
    (args.out_dir / "dataset_inventory.json").write_text(
        json.dumps(inventory_rows, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    plot_top_tokens(all_tokens, args.out_dir)
    plot_vocab_summary(summary, args.out_dir)
    print(f"[done] wrote {args.out_dir}", flush=True)


if __name__ == "__main__":
    main()

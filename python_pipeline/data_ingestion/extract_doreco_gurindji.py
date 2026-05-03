"""Extract local DoReCo Gurindji annotation summaries.

This script reads the DoReCo Gurindji word-level CSV files already stored
outside the repo and writes local-only research outputs under
python_pipeline/outputs/. Do not commit generated outputs or source corpus data.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DORECO_ROOT = REPO_ROOT.parent / "Data"
DEFAULT_LEXICON = REPO_ROOT / "assets" / "data" / "gurindji_lexicon.json"
DEFAULT_OUTPUT = REPO_ROOT / "python_pipeline" / "outputs" / "doreco_gurindji"

PLACEHOLDER_VALUES = {"", "<p:>", "xxx", "xx", "x"}
HEALTH_TYPES = {"body", "symptom", "disease"}


@dataclass(frozen=True)
class CleanWordRow:
    source_file: str
    speaker: str
    word: str
    text: str
    translation: str
    start: str
    end: str
    is_foreign_material: bool


@dataclass(frozen=True)
class LexiconEntry:
    gurindji: str
    english: str
    type: str


def normalize_text(value: str) -> str:
    normalized = value.lower().replace("-", " ")
    normalized = re.sub(r"[^a-z0-9\s]", " ", normalized)
    return re.sub(r"\s+", " ", normalized).strip()


def is_foreign_material(value: str) -> bool:
    return "<<fm>" in value or value.strip().lower().startswith("<<fm")


def clean_word(value: str) -> str:
    value = value.strip()
    if is_foreign_material(value):
        match = re.match(r"<<fm>([^>]+)>", value)
        if match:
            return match.group(1).strip()
    if value.startswith("<<") and value.endswith(">>"):
        return ""
    return value


def is_placeholder(value: str) -> bool:
    return value.strip().lower() in PLACEHOLDER_VALUES


def find_doreco_word_files(doreco_root: Path) -> list[Path]:
    return sorted(doreco_root.rglob("doreco_guri1247_#7_wd.csv"))


def read_doreco_words(word_files: Iterable[Path]) -> list[CleanWordRow]:
    rows: list[CleanWordRow] = []
    for word_file in word_files:
        with word_file.open("r", encoding="utf-8-sig", newline="") as handle:
            for raw in csv.DictReader(handle):
                raw_word = raw.get("wd", "")
                word = clean_word(raw_word)
                if is_placeholder(word):
                    continue

                rows.append(
                    CleanWordRow(
                        source_file=raw.get("file", ""),
                        speaker=raw.get("speaker", ""),
                        word=word,
                        text=raw.get("tx", ""),
                        translation=raw.get("ft", ""),
                        start=raw.get("start", ""),
                        end=raw.get("end", ""),
                        is_foreign_material=is_foreign_material(raw_word),
                    )
                )
    return rows


def load_lexicon(path: Path) -> list[LexiconEntry]:
    with path.open("r", encoding="utf-8") as handle:
        raw_entries = json.load(handle)

    entries: list[LexiconEntry] = []
    for raw in raw_entries:
        entry_type = str(raw.get("type", "")).strip()
        if entry_type not in HEALTH_TYPES:
            continue
        entries.append(
            LexiconEntry(
                gurindji=str(raw.get("gurindji", "")).strip(),
                english=str(raw.get("english", "")).strip(),
                type=entry_type,
            )
        )
    return entries


def build_frequency(rows: Iterable[CleanWordRow]) -> list[dict[str, object]]:
    counts = Counter(normalize_text(row.word) for row in rows)
    counts.pop("", None)
    return [
        {"word": word, "count": count}
        for word, count in sorted(counts.items(), key=lambda item: (-item[1], item[0]))
    ]


def find_candidate_terms(
    rows: Iterable[CleanWordRow],
    lexicon: Iterable[LexiconEntry],
) -> list[dict[str, str]]:
    observed_words = {normalize_text(row.word) for row in rows}
    observed_text = {
        normalize_text(part)
        for row in rows
        for part in (row.text, row.translation)
        if part.strip()
    }

    candidates: list[dict[str, str]] = []
    for entry in lexicon:
        normalized_gurindji = normalize_text(entry.gurindji)
        normalized_english = normalize_text(entry.english)
        if not normalized_gurindji:
            continue

        match_type = ""
        if normalized_gurindji in observed_words:
            match_type = "word"
        elif any(normalized_gurindji in text for text in observed_text):
            match_type = "phrase"
        elif normalized_english and any(normalized_english in text for text in observed_text):
            match_type = "translation"

        if match_type:
            candidates.append(
                {
                    "gurindji": entry.gurindji,
                    "english": entry.english,
                    "type": entry.type,
                    "match_type": match_type,
                }
            )

    return sorted(candidates, key=lambda item: (item["type"], item["gurindji"]))


def write_csv(path: Path, rows: Iterable[dict[str, object]], fieldnames: list[str]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def write_outputs(
    output_dir: Path,
    clean_rows: list[CleanWordRow],
    frequency_rows: list[dict[str, object]],
    candidate_rows: list[dict[str, str]],
    word_files: list[Path],
) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)

    write_csv(
        output_dir / "cleaned_words.csv",
        [
            {
                "source_file": row.source_file,
                "speaker": row.speaker,
                "word": row.word,
                "text": row.text,
                "translation": row.translation,
                "start": row.start,
                "end": row.end,
                "is_foreign_material": row.is_foreign_material,
            }
            for row in clean_rows
        ],
        [
            "source_file",
            "speaker",
            "word",
            "text",
            "translation",
            "start",
            "end",
            "is_foreign_material",
        ],
    )
    write_csv(output_dir / "frequency.csv", frequency_rows, ["word", "count"])
    write_csv(
        output_dir / "foreign_material.csv",
        [
            {
                "source_file": row.source_file,
                "speaker": row.speaker,
                "word": row.word,
                "text": row.text,
                "translation": row.translation,
            }
            for row in clean_rows
            if row.is_foreign_material
        ],
        ["source_file", "speaker", "word", "text", "translation"],
    )
    write_csv(
        output_dir / "candidate_health_terms.csv",
        candidate_rows,
        ["gurindji", "english", "type", "match_type"],
    )

    summary = {
        "word_files": [str(path) for path in word_files],
        "cleaned_word_rows": len(clean_rows),
        "foreign_material_rows": sum(1 for row in clean_rows if row.is_foreign_material),
        "candidate_health_terms": len(candidate_rows),
        "license_note": (
            "DoReCo Gurindji annotations are CC BY-NC-ND 4.0; generated outputs "
            "must remain local unless redistribution permission is confirmed."
        ),
    }
    (output_dir / "summary.json").write_text(
        json.dumps(summary, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )


def extract_doreco(
    doreco_root: Path,
    lexicon_path: Path,
    output_dir: Path,
) -> dict[str, int]:
    if not doreco_root.exists():
        raise FileNotFoundError(f"DoReCo root not found: {doreco_root}")
    if not lexicon_path.exists():
        raise FileNotFoundError(f"Gurindji lexicon asset not found: {lexicon_path}")

    word_files = find_doreco_word_files(doreco_root)
    if not word_files:
        raise FileNotFoundError(
            f"No doreco_guri1247_#7_wd.csv files found under: {doreco_root}"
        )

    clean_rows = read_doreco_words(word_files)
    lexicon = load_lexicon(lexicon_path)
    frequency_rows = build_frequency(clean_rows)
    candidate_rows = find_candidate_terms(clean_rows, lexicon)
    write_outputs(output_dir, clean_rows, frequency_rows, candidate_rows, word_files)

    return {
        "word_files": len(word_files),
        "cleaned_word_rows": len(clean_rows),
        "candidate_health_terms": len(candidate_rows),
    }


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Extract local-only DoReCo Gurindji annotation summaries."
    )
    parser.add_argument(
        "--doreco-root",
        type=Path,
        default=DEFAULT_DORECO_ROOT,
        help="Path containing the extracted DoReCo Gurindji core/extended folders.",
    )
    parser.add_argument(
        "--lexicon",
        type=Path,
        default=DEFAULT_LEXICON,
        help="Tracked curated Gurindji lexicon JSON asset.",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=DEFAULT_OUTPUT,
        help="Local-only output folder. This path is ignored by Git.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    try:
        summary = extract_doreco(
            doreco_root=args.doreco_root,
            lexicon_path=args.lexicon,
            output_dir=args.output_dir,
        )
    except FileNotFoundError as error:
        print(f"[SACA] {error}", file=sys.stderr)
        return 2

    print(
        "[SACA] Extracted {cleaned_word_rows} rows from {word_files} word files; "
        "found {candidate_health_terms} candidate health terms.".format(**summary)
    )
    print(f"[SACA] Local outputs: {args.output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import pandas as pd


@dataclass(frozen=True)
class GurindjiMatch:
    gurindji: str
    english: str
    type: str
    canonical_id: str


@dataclass(frozen=True)
class GurindjiNormalizationResult:
    original_text: str
    normalized_text: str
    matched_symptom_ids: tuple[str, ...]
    matched_body_ids: tuple[str, ...]
    matches: tuple[GurindjiMatch, ...]


class GurindjiClinicalNormalizer:
    def __init__(self, entries: pd.DataFrame, *, symptom_columns: list[str] | None = None) -> None:
        required = {"gurindji", "english", "type"}
        missing = required.difference(entries.columns)
        if missing:
            raise ValueError(f"Gurindji dictionary missing columns: {sorted(missing)}")
        self._symptom_columns = symptom_columns or []
        self._entries = self._prepare_entries(entries)

    @classmethod
    def from_excel(cls, path: Path | None = None, *, symptom_columns: list[str] | None = None) -> "GurindjiClinicalNormalizer":
        dictionary_path = path or find_gurindji_dictionary()
        if dictionary_path.suffix.lower() == ".csv":
            entries = pd.read_csv(dictionary_path, encoding="utf-8", encoding_errors="replace")
        else:
            entries = pd.read_excel(dictionary_path)
        return cls(entries, symptom_columns=symptom_columns)

    def normalize(self, text: Any) -> GurindjiNormalizationResult:
        original = str(text or "")
        normalized = normalize_text(original)
        matches: list[GurindjiMatch] = []
        symptom_ids: list[str] = []
        body_ids: list[str] = []
        appended_terms: list[str] = []
        occupied: list[tuple[int, int]] = []

        for entry in self._entries:
            pattern = re.compile(r"(?<!\w)" + re.escape(entry["gurindji_norm"]) + r"(?!\w)")
            for match in pattern.finditer(normalized):
                span = match.span()
                if any(max(span[0], used[0]) < min(span[1], used[1]) for used in occupied):
                    continue
                occupied.append(span)
                clinical_match = GurindjiMatch(
                    gurindji=entry["gurindji"],
                    english=entry["english"],
                    type=entry["type"],
                    canonical_id=entry["canonical_id"],
                )
                matches.append(clinical_match)
                if entry["type"] == "symptom" and entry["canonical_id"]:
                    symptom_ids.append(entry["canonical_id"])
                    appended_terms.append(entry["canonical_text"])
                if entry["type"] == "body" and entry["canonical_id"]:
                    body_ids.append(entry["canonical_id"])
                    appended_terms.append(entry["canonical_text"])
                break

        appended_unique = dedupe_keep_order(term for term in appended_terms if term)
        normalized_text = " ".join([original.strip(), *appended_unique]).strip()
        return GurindjiNormalizationResult(
            original_text=original,
            normalized_text=normalized_text,
            matched_symptom_ids=tuple(dedupe_keep_order(symptom_ids)),
            matched_body_ids=tuple(dedupe_keep_order(body_ids)),
            matches=tuple(matches),
        )

    def synthetic_gurindji_text(self, english_text: Any) -> str:
        output = normalize_text(english_text)
        for entry in self._entries:
            canonical = entry["canonical_text"]
            if not canonical:
                continue
            output = re.sub(r"(?<!\w)" + re.escape(canonical) + r"(?!\w)", entry["gurindji"], output)
        return output

    def export_entries(self) -> list[dict[str, str]]:
        return list(self._entries)

    def _prepare_entries(self, entries: pd.DataFrame) -> list[dict[str, str]]:
        prepared: list[dict[str, str]] = []
        for row in entries.fillna("").to_dict(orient="records"):
            entry_type = normalize_text(row.get("type", ""))
            if entry_type not in {"symptom", "body"}:
                continue
            gurindji = clean_gurindji_term(row.get("gurindji", ""))
            english = clean_english_term(row.get("english", ""))
            if not gurindji or not english:
                continue
            canonical_id = canonical_id_for(entry_type, english, self._symptom_columns)
            canonical_text = canonical_text_for(canonical_id, english, self._symptom_columns)
            prepared.append(
                {
                    "gurindji": gurindji,
                    "gurindji_norm": normalize_text(gurindji),
                    "english": english,
                    "type": entry_type,
                    "canonical_id": canonical_id,
                    "canonical_text": canonical_text,
                }
            )
        return sorted(prepared, key=lambda item: len(item["gurindji_norm"].split()), reverse=True)


BODY_ALIASES = {
    "head": "head",
    "eye": "eyes",
    "eyes": "eyes",
    "throat": "throat",
    "heart": "heart",
    "chest": "chest",
    "stomach": "stomach",
    "belly": "stomach",
    "hand": "hand",
    "leg": "leg",
    "knee": "knees",
    "toe": "toes",
    "ear": "ears",
    "neck": "neck",
    "shoulder": "shoulder",
    "back": "back",
    "arm": "arm",
    "elbow": "elbow",
    "finger": "finger",
    "ankle": "ankle",
}

SYMPTOM_ALIASES = {
    "cough": "cough",
    "vomit": "vomiting",
    "vomiting": "vomiting",
    "fever": "fever",
    "sick": "general symptoms",
    "ill": "general symptoms",
    "wound": "skin lesion",
    "cut": "skin lesion",
    "choke": "difficulty speaking",
    "thirsty": "excessive appetite and thirst",
    "pain": "sharp chest pain",
    "ache": "sharp chest pain",
    "bleed": "bleeding",
    "blood": "bleeding",
}


def find_gurindji_dictionary() -> Path:
    here = Path(__file__).resolve()
    candidates = [
        here.parents[1] / "data" / "gurindji_dict_medical.xlsx",
        here.parents[2] / "python_pipeline" / "data" / "gurindji_dict_medical.xlsx",
        here.parents[2].parent / "SACA" / "python_pipeline" / "data" / "gurindji_dict_medical.xlsx",
        Path("F:/git/SACA/python_pipeline/data/gurindji_dict_medical.xlsx"),
    ]
    for candidate in candidates:
        if candidate.exists():
            return candidate
    raise FileNotFoundError("gurindji_dict_medical.xlsx not found")


def canonical_id_for(entry_type: str, english: str, symptom_columns: list[str]) -> str:
    tokens = set(re.findall(r"[a-z]+", english))
    if entry_type == "body":
        for token in tokens:
            if token in BODY_ALIASES:
                return BODY_ALIASES[token]
        return ""
    for phrase, canonical in SYMPTOM_ALIASES.items():
        if phrase in english:
            return canonical if canonical in symptom_columns or not symptom_columns else nearest_symptom(canonical, symptom_columns)
    for column in symptom_columns:
        if column in english or english in column:
            return column
    return ""


def canonical_text_for(canonical_id: str, english: str, symptom_columns: list[str]) -> str:
    if canonical_id:
        return canonical_id
    if symptom_columns:
        return ""
    return english


def nearest_symptom(value: str, symptom_columns: list[str]) -> str:
    if value in symptom_columns:
        return value
    value_tokens = set(value.split())
    best = ""
    best_score = 0
    for column in symptom_columns:
        score = len(value_tokens.intersection(column.split()))
        if score > best_score:
            best = column
            best_score = score
    return best


def clean_gurindji_term(value: Any) -> str:
    text = normalize_text(value).replace("-", "")
    return re.sub(r"\b(ma|pa|yuwa)$", "", text).strip()


def clean_english_term(value: Any) -> str:
    text = normalize_text(value)
    text = re.sub(r"\b(the|a|an|to|be)\b", " ", text)
    text = text.replace("/", " ")
    return re.sub(r"\s+", " ", text).strip()


def normalize_text(value: Any) -> str:
    return re.sub(r"\s+", " ", str(value or "").lower().strip())


def dedupe_keep_order(values: Any) -> list[str]:
    seen: set[str] = set()
    output: list[str] = []
    for value in values:
        if value and value not in seen:
            seen.add(value)
            output.append(value)
    return output

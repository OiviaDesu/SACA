from __future__ import annotations

import csv
import re
from pathlib import Path


VALID_HYPHEN_MODES = {"space", "keep"}


def load_orthography_mapping(path: Path | None) -> tuple[dict[str, str], list[str]]:
    if path is None:
        return {}, ["No orthography mapping file provided; normalized metrics use punctuation/case only."]
    if not path.exists():
        return {}, [f"Orthography mapping file not found: {path}; normalized metrics use punctuation/case only."]

    warnings: list[str] = []
    mapping: dict[str, str] = {}
    with path.open(encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        expected = {"variant", "canonical", "reason"}
        if reader.fieldnames is None or set(reader.fieldnames) != expected:
            raise ValueError("orthography mapping TSV must have columns: variant, canonical, reason")
        for line_number, row in enumerate(reader, 2):
            variant = _normalize_mapping_key(row.get("variant", ""))
            canonical = _normalize_mapping_key(row.get("canonical", ""))
            reason = (row.get("reason") or "").strip()
            if not variant or not canonical or not reason:
                raise ValueError(f"orthography mapping row {line_number} must include variant, canonical, and reason")
            if variant in mapping:
                raise ValueError(f"duplicate orthography mapping variant at row {line_number}: {variant}")
            mapping[variant] = canonical

    if not mapping:
        warnings.append(f"Orthography mapping file is empty: {path}; normalized metrics use punctuation/case only.")
    return mapping, warnings


def normalize_for_metric(
    text: str,
    mapping: dict[str, str] | None = None,
    *,
    hyphen_mode: str = "space",
) -> str:
    if hyphen_mode not in VALID_HYPHEN_MODES:
        raise ValueError(f"hyphen_mode must be one of {sorted(VALID_HYPHEN_MODES)}")

    normalized = text.lower()
    normalized = normalized.replace("’", "'").replace("‘", "'")
    normalized = normalized.replace("“", "").replace("”", "").replace('"', "")
    normalized = re.sub(r"[^\w\s'-]", " ", normalized, flags=re.UNICODE)
    normalized = normalized.replace("'", "")
    if hyphen_mode == "space":
        normalized = normalized.replace("-", " ")
    normalized = re.sub(r"\s+", " ", normalized).strip()

    if not mapping:
        return normalized

    return " ".join(mapping.get(word, word) for word in normalized.split())


def _normalize_mapping_key(value: str) -> str:
    return normalize_for_metric(value, mapping=None, hyphen_mode="space")

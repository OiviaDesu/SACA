import importlib.util
import sys
from pathlib import Path

import pytest


SCRIPT_PATH = Path(__file__).resolve().parents[1] / "whisper_metrics.py"
SPEC = importlib.util.spec_from_file_location("whisper_metrics", SCRIPT_PATH)
metrics = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
sys.modules[SPEC.name] = metrics
SPEC.loader.exec_module(metrics)


def test_normalize_for_metric_handles_case_punctuation_quotes_and_spaces():
    assert (
        metrics.normalize_for_metric("  Ngurna-rla,  Jarrakap! ‘Nyawa’  ")
        == "ngurna rla jarrakap nyawa"
    )


def test_normalize_for_metric_can_keep_hyphen_for_separate_view():
    assert (
        metrics.normalize_for_metric("Ngurna-rla, Jarrakap!", hyphen_mode="keep")
        == "ngurna-rla jarrakap"
    )


def test_normalize_for_metric_applies_verified_mapping_after_normalization():
    mapping = {"truk": "truck", "trak": "truck"}
    assert metrics.normalize_for_metric("Truk, trak!", mapping) == "truck truck"


def test_load_orthography_mapping_warns_when_missing_or_empty(tmp_path):
    missing_mapping, missing_warnings = metrics.load_orthography_mapping(tmp_path / "missing.tsv")
    assert missing_mapping == {}
    assert "not found" in missing_warnings[0]

    empty_path = tmp_path / "orthography_mapping.tsv"
    empty_path.write_text("variant\tcanonical\treason\n", encoding="utf-8")
    empty_mapping, empty_warnings = metrics.load_orthography_mapping(empty_path)
    assert empty_mapping == {}
    assert "empty" in empty_warnings[0]


def test_load_orthography_mapping_rejects_malformed_rows(tmp_path):
    path = tmp_path / "orthography_mapping.tsv"
    path.write_text("variant\tcanonical\treason\ntruk\ttruck\t\n", encoding="utf-8")

    with pytest.raises(ValueError, match="row 2"):
        metrics.load_orthography_mapping(path)


def test_load_orthography_mapping_rejects_duplicate_variants(tmp_path):
    path = tmp_path / "orthography_mapping.tsv"
    path.write_text(
        "variant\tcanonical\treason\n"
        "truk\ttruck\tverified loanword spelling\n"
        "Truk!\ttruck\tduplicate after normalization\n",
        encoding="utf-8",
    )

    with pytest.raises(ValueError, match="duplicate"):
        metrics.load_orthography_mapping(path)

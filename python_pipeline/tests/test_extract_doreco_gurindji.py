import csv
import importlib.util
import json
import sys
from pathlib import Path


SCRIPT_PATH = Path(__file__).resolve().parents[1] / "01_extract_doreco_gurindji.py"
SPEC = importlib.util.spec_from_file_location("extract_doreco_gurindji", SCRIPT_PATH)
extractor = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
sys.modules[SPEC.name] = extractor
SPEC.loader.exec_module(extractor)


def _write_word_file(root: Path) -> Path:
    target = root / "doreco_guri1247_core_v2" / "doreco_guri1247_core_v2.0"
    target.mkdir(parents=True)
    path = target / "doreco_guri1247_#7_wd.csv"
    rows = [
        {
            "lang": "guri1247",
            "file": "doreco_guri1247_fixture",
            "core_extended": "core",
            "speaker": "ABC",
            "wd_ID": "w000001",
            "wd": "<p:>",
            "start": "0.000",
            "end": "0.500",
            "ref": "<p:>",
            "tx": "<p:>",
            "ft": "<p:>",
        },
        {
            "lang": "guri1247",
            "file": "doreco_guri1247_fixture",
            "core_extended": "core",
            "speaker": "ABC",
            "wd_ID": "w000002",
            "wd": "makurrmakurr",
            "start": "0.500",
            "end": "1.000",
            "ref": "0001",
            "tx": "makurrmakurr",
            "ft": "fever",
        },
        {
            "lang": "guri1247",
            "file": "doreco_guri1247_fixture",
            "core_extended": "core",
            "speaker": "ABC",
            "wd_ID": "w000003",
            "wd": "<<fm>doctor>",
            "start": "1.000",
            "end": "1.500",
            "ref": "0002",
            "tx": "doctor nyawa",
            "ft": "this doctor",
        },
    ]
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)
    return path


def _write_lexicon(path: Path) -> None:
    path.write_text(
        json.dumps(
            [
                {"gurindji": "makurrmakurr", "english": "fever", "type": "symptom"},
                {"gurindji": "majul", "english": "stomach", "type": "body"},
                {"gurindji": "not-health", "english": "skip", "type": "other"},
            ]
        ),
        encoding="utf-8",
    )


def test_extract_doreco_skips_placeholders_and_preserves_text(tmp_path):
    _write_word_file(tmp_path)
    lexicon = tmp_path / "lexicon.json"
    output = tmp_path / "outputs"
    _write_lexicon(lexicon)

    summary = extractor.extract_doreco(tmp_path, lexicon, output)

    assert summary["word_files"] == 1
    assert summary["cleaned_word_rows"] == 2

    cleaned = list(csv.DictReader((output / "cleaned_words.csv").open(encoding="utf-8")))
    assert [row["word"] for row in cleaned] == ["makurrmakurr", "doctor"]
    assert cleaned[0]["text"] == "makurrmakurr"
    assert cleaned[0]["translation"] == "fever"


def test_extract_doreco_writes_foreign_material_and_candidate_terms(tmp_path):
    _write_word_file(tmp_path)
    lexicon = tmp_path / "lexicon.json"
    output = tmp_path / "outputs"
    _write_lexicon(lexicon)

    extractor.extract_doreco(tmp_path, lexicon, output)

    foreign_rows = list(
        csv.DictReader((output / "foreign_material.csv").open(encoding="utf-8"))
    )
    candidates = list(
        csv.DictReader((output / "candidate_health_terms.csv").open(encoding="utf-8"))
    )

    assert foreign_rows[0]["word"] == "doctor"
    assert candidates == [
        {
            "gurindji": "makurrmakurr",
            "english": "fever",
            "type": "symptom",
            "match_type": "word",
        }
    ]


def test_missing_doreco_root_returns_clear_error(tmp_path, capsys):
    missing = tmp_path / "missing"
    lexicon = tmp_path / "lexicon.json"
    _write_lexicon(lexicon)

    code = extractor.main(
        [
            "--doreco-root",
            str(missing),
            "--lexicon",
            str(lexicon),
            "--output-dir",
            str(tmp_path / "outputs"),
        ]
    )

    captured = capsys.readouterr()
    assert code == 2
    assert "DoReCo root not found" in captured.err

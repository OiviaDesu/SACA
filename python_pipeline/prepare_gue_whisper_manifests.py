from __future__ import annotations

import argparse
import csv
import json
import re
from collections import Counter
from pathlib import Path


SPLITS = ("train", "validation", "test")
EXAMPLE_ONLY = "example_only"
MIXED_HEADWORD = "mixed_headword"


def normalize_text(text: str) -> str:
    text = re.sub(r"\s+", " ", text or "").strip()
    return text.replace(" .", ".").replace(" ,", ",")


def load_rows(source: Path) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    with source.open(encoding="utf-8") as handle:
        for line_number, line in enumerate(handle, 1):
            if not line.strip():
                continue
            row = json.loads(line)
            row["_line_number"] = line_number
            rows.append(row)
    return rows


def prepare_manifests(
    source: Path,
    output_dir: Path,
    *,
    headword_ratio: float = 0.25,
) -> dict[str, dict[str, list[dict[str, str]]]]:
    rows = [row for row in load_rows(source) if _is_valid_source_row(row)]
    by_split = {split: [row for row in rows if row.get("split") == split] for split in SPLITS}
    output_dir.mkdir(parents=True, exist_ok=True)

    example_sets = {
        split: [
            _manifest_row(row, source.parent)
            for row in split_rows
            if row.get("label_type") == "example_sentence"
        ]
        for split, split_rows in by_split.items()
    }
    mixed_sets = {
        "train": [
            _manifest_row(row, source.parent)
            for row in _mixed_train_rows(by_split["train"], headword_ratio)
        ],
        "validation": [_manifest_row(row, source.parent) for row in by_split["validation"]],
        "test": [_manifest_row(row, source.parent) for row in by_split["test"]],
    }

    manifest_sets = {EXAMPLE_ONLY: example_sets, MIXED_HEADWORD: mixed_sets}
    for name, split_rows in manifest_sets.items():
        _write_manifest_set(output_dir / name, split_rows)

    _write_root_readme(output_dir, source, headword_ratio)
    return manifest_sets


def _is_valid_source_row(row: dict[str, object]) -> bool:
    return (
        row.get("split") in SPLITS
        and bool(row.get("audio_exists"))
        and bool(normalize_text(str(row.get("text") or "")))
    )


def _mixed_train_rows(
    rows: list[dict[str, object]],
    headword_ratio: float,
) -> list[dict[str, object]]:
    output: list[dict[str, object]] = []
    keep_every = max(1, round(1 / headword_ratio)) if headword_ratio > 0 else None
    headword_seen = 0
    for row in rows:
        label_type = row.get("label_type")
        if label_type == "example_sentence":
            output.append(row)
        elif label_type == "headword_pronunciation" and keep_every is not None:
            if headword_seen % keep_every == 0:
                output.append(row)
            headword_seen += 1
    return output


def _manifest_row(row: dict[str, object], base_dir: Path) -> dict[str, str]:
    audio_value = str(row.get("audio") or "")
    audio_abs = Path(str(row.get("audio_abs") or base_dir / audio_value)).resolve()
    return {
        "id": str(row.get("id") or ""),
        "audio": str(audio_abs),
        "text": normalize_text(str(row.get("text") or "")),
        "label_type": str(row.get("label_type") or ""),
        "split": str(row.get("split") or ""),
        "language": "gurindji",
        "language_code": "gue",
        "task": "transcribe",
        "headword": str(row.get("headword") or ""),
        "translation_english": str(row.get("translation_english") or ""),
        "source": str(row.get("source") or ""),
    }


def _write_manifest_set(
    output_dir: Path,
    split_rows: dict[str, list[dict[str, str]]],
) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    for split, rows in split_rows.items():
        _write_jsonl(output_dir / f"{split}.jsonl", rows)
        _write_csv(output_dir / f"{split}.csv", rows)
    all_rows = [row for rows in split_rows.values() for row in rows]
    (output_dir / "README.md").write_text(
        "\n".join([f"# {output_dir.name}", "", *_audit_lines(all_rows), ""]),
        encoding="utf-8",
    )


def _write_jsonl(path: Path, rows: list[dict[str, str]]) -> None:
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        for row in rows:
            handle.write(json.dumps(row, ensure_ascii=False) + "\n")


def _write_csv(path: Path, rows: list[dict[str, str]]) -> None:
    if not rows:
        return
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def _audit_lines(rows: list[dict[str, str]]) -> list[str]:
    word_lengths = [len(row["text"].split()) for row in rows]
    return [
        f"records={len(rows)}",
        f"split={dict(Counter(row['split'] for row in rows))}",
        f"label_type={dict(Counter(row['label_type'] for row in rows))}",
        f"missing_audio={sum(not Path(row['audio']).exists() for row in rows)}",
        f"empty_text={sum(not row['text'].strip() for row in rows)}",
        f"word_len_min={min(word_lengths) if word_lengths else 0} "
        f"median={sorted(word_lengths)[len(word_lengths) // 2] if word_lengths else 0} "
        f"max={max(word_lengths) if word_lengths else 0}",
    ]


def _write_root_readme(output_dir: Path, source: Path, headword_ratio: float) -> None:
    (output_dir / "README.md").write_text(
        "\n".join(
            [
                "# Whisper Gurindji Train-Ready Manifests",
                "",
                f"Generated from `{source.name}`.",
                "No model training performed by this script.",
                "",
                "Recommended first run: `example_only/*.jsonl`.",
                "Reason: `headword_pronunciation` dominates the source and biases ASR toward isolated words.",
                "",
                f"Second run: `mixed_headword/*.jsonl` with headword_ratio={headword_ratio}.",
                "Evaluate sentence WER/CER and headword CER separately.",
                "",
            ]
        ),
        encoding="utf-8",
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="Prepare Gurindji Whisper manifests.")
    parser.add_argument(
        "--source",
        type=Path,
        default=Path(__file__).resolve().parent / "gue_whisper_dataset.jsonl",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path(__file__).resolve().parent / "whisper_gue_ready",
    )
    parser.add_argument("--headword-ratio", type=float, default=0.25)
    args = parser.parse_args()

    manifests = prepare_manifests(
        args.source,
        args.output_dir,
        headword_ratio=args.headword_ratio,
    )
    for name, split_rows in manifests.items():
        counts = {split: len(rows) for split, rows in split_rows.items()}
        print(name, counts)


if __name__ == "__main__":
    main()

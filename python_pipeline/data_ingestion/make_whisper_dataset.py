from __future__ import annotations

import argparse
import csv
import io
import json
from pathlib import Path

from clean_gue_dataset import parse_entries


BASE_DIR = Path(__file__).resolve().parent
AUDIO_DIR = BASE_DIR / "audiodict"


def split_for(index: int) -> str:
    bucket = index % 100
    if bucket < 90:
        return "train"
    if bucket < 95:
        return "validation"
    return "test"


def english_for_entry(entry: dict) -> str:
    definitions = entry.get("definitions") or []
    return "; ".join(definitions)


def make_records() -> list[dict]:
    records = []
    seen = set()

    for entry in parse_entries():
        headword = entry["headword"]
        pos = entry.get("pos", "")
        english_meaning = english_for_entry(entry)

        for audio in entry.get("audio", []):
            audio_path = BASE_DIR / audio
            key = (audio, headword, "headword")
            if key in seen:
                continue
            seen.add(key)
            records.append(
                {
                    "id": f"gue_{len(records):06d}",
                    "split": "",
                    "audio": audio,
                    "audio_abs": str(audio_path),
                    "audio_exists": audio_path.exists(),
                    "language": "gurindji",
                    "language_code": "gue",
                    "task": "transcribe",
                    "label_type": "headword_pronunciation",
                    "text": headword,
                    "transcript_gurindji": headword,
                    "translation_english": english_meaning,
                    "headword": headword,
                    "pos": pos,
                    "source": "ngumpin_gurindji_dictionary_az",
                }
            )

        for example in entry.get("examples", []):
            audio = example.get("audio") or ""
            gurindji = example.get("gurindji") or ""
            english = example.get("english") or ""
            if not audio or not gurindji:
                continue
            audio_path = BASE_DIR / audio
            key = (audio, gurindji, "example")
            if key in seen:
                continue
            seen.add(key)
            records.append(
                {
                    "id": f"gue_{len(records):06d}",
                    "split": "",
                    "audio": audio,
                    "audio_abs": str(audio_path),
                    "audio_exists": audio_path.exists(),
                    "language": "gurindji",
                    "language_code": "gue",
                    "task": "transcribe",
                    "label_type": "example_sentence",
                    "text": gurindji,
                    "transcript_gurindji": gurindji,
                    "translation_english": english,
                    "headword": headword,
                    "pos": pos,
                    "source": "ngumpin_gurindji_dictionary_az",
                }
            )

    for index, record in enumerate(records):
        record["split"] = split_for(index)

    return records


def render_jsonl(records: list[dict]) -> str:
    return "\n".join(json.dumps(record, ensure_ascii=False) for record in records) + "\n"


def render_csv(records: list[dict]) -> str:
    if not records:
        return ""
    output = io.StringIO()
    writer = csv.DictWriter(output, fieldnames=list(records[0].keys()), lineterminator="\n")
    writer.writeheader()
    writer.writerows(records)
    return output.getvalue()


def render_md(records: list[dict]) -> str:
    lines = ["# Gurindji Whisper Dataset", "", f"Total records: {len(records)}", ""]
    for record in records:
        lines.append(f"## {record['id']}")
        lines.append(f"- Split: {record['split']}")
        lines.append(f"- Label: {record['label_type']}")
        lines.append(f"- Audio: {record['audio']}")
        lines.append(f"- Gurindji: {record['transcript_gurindji']}")
        if record["translation_english"]:
            lines.append(f"- English: {record['translation_english']}")
        lines.append(f"- Headword: {record['headword']}")
        if record["pos"]:
            lines.append(f"- POS: {record['pos']}")
        lines.append("")
    return "\n".join(lines).strip() + "\n"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--format", choices=("jsonl", "csv", "md"), default="jsonl")
    args = parser.parse_args()

    records = make_records()
    if args.format == "jsonl":
        print(render_jsonl(records), end="")
    elif args.format == "csv":
        print(render_csv(records), end="")
    else:
        print(render_md(records), end="")


if __name__ == "__main__":
    main()

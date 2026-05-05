from __future__ import annotations

import argparse
import csv
import io
import json
from pathlib import Path

from gue_dictionary_parser import parse_gue_dictionary


def split_for(index: int) -> str:
    bucket = index % 100
    if bucket < 90:
        return "train"
    if bucket < 95:
        return "validation"
    return "test"


def make_records(html_path: Path, audio_dir: Path) -> list[dict[str, object]]:
    records: list[dict[str, object]] = []
    seen: set[tuple[str, str, str]] = set()
    base_dir = html_path.parent

    for entry in parse_gue_dictionary(html_path):
        headword = str(entry["headword"])
        pos = str(entry.get("pos", ""))
        english_meaning = "; ".join(entry.get("definitions") or [])

        for audio in entry.get("audio", []):
            audio_path = _resolve_audio(base_dir, audio_dir, str(audio))
            key = (str(audio), headword, "headword")
            if key in seen:
                continue
            seen.add(key)
            records.append(
                _record(
                    index=len(records),
                    audio=str(audio),
                    audio_path=audio_path,
                    label_type="headword_pronunciation",
                    text=headword,
                    translation_english=english_meaning,
                    headword=headword,
                    pos=pos,
                )
            )

        for example in entry.get("examples", []):
            audio = str(example.get("audio") or "")
            gurindji = str(example.get("gurindji") or "")
            english = str(example.get("english") or "")
            if not audio or not gurindji:
                continue
            audio_path = _resolve_audio(base_dir, audio_dir, audio)
            key = (audio, gurindji, "example")
            if key in seen:
                continue
            seen.add(key)
            records.append(
                _record(
                    index=len(records),
                    audio=audio,
                    audio_path=audio_path,
                    label_type="example_sentence",
                    text=gurindji,
                    translation_english=english,
                    headword=headword,
                    pos=pos,
                )
            )

    for index, row in enumerate(records):
        row["split"] = split_for(index)
    return records


def write_outputs(records: list[dict[str, object]], output_stem: Path) -> None:
    output_stem.parent.mkdir(parents=True, exist_ok=True)
    with output_stem.with_suffix(".jsonl").open("w", encoding="utf-8") as handle:
        for record in records:
            handle.write(json.dumps(record, ensure_ascii=False) + "\n")

    with output_stem.with_suffix(".csv").open(
        "w", encoding="utf-8", newline=""
    ) as handle:
        writer = csv.DictWriter(handle, fieldnames=list(records[0].keys()))
        writer.writeheader()
        writer.writerows(records)

    markdown = io.StringIO()
    markdown.write("# Gurindji Whisper Dataset\n\n")
    markdown.write(f"records: {len(records)}\n\n")
    markdown.write("| split | label_type | count |\n")
    markdown.write("| --- | --- | ---: |\n")
    for split in ("train", "validation", "test"):
        for label_type in ("example_sentence", "headword_pronunciation"):
            count = sum(
                row["split"] == split and row["label_type"] == label_type
                for row in records
            )
            markdown.write(f"| {split} | {label_type} | {count} |\n")
    output_stem.with_suffix(".md").write_text(markdown.getvalue(), encoding="utf-8")


def _record(
    *,
    index: int,
    audio: str,
    audio_path: Path,
    label_type: str,
    text: str,
    translation_english: str,
    headword: str,
    pos: str,
) -> dict[str, object]:
    return {
        "id": f"gue_{index:06d}",
        "split": "",
        "audio": audio,
        "audio_abs": str(audio_path),
        "audio_exists": audio_path.exists(),
        "language": "gurindji",
        "language_code": "gue",
        "task": "transcribe",
        "label_type": label_type,
        "text": text,
        "transcript_gurindji": text,
        "translation_english": translation_english,
        "headword": headword,
        "pos": pos,
        "source": "ngumpin_gurindji_dictionary_az",
    }


def _resolve_audio(base_dir: Path, audio_dir: Path, audio: str) -> Path:
    audio_name = Path(audio).name
    candidate = audio_dir / audio_name
    if candidate.exists():
        return candidate.resolve()
    return (base_dir / audio).resolve()


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Build local-only Gurindji Whisper records from dictionary HTML."
    )
    parser.add_argument("--html", type=Path, required=True)
    parser.add_argument("--audio-dir", type=Path, required=True)
    parser.add_argument("--output-stem", type=Path, required=True)
    args = parser.parse_args()

    records = make_records(args.html, args.audio_dir)
    write_outputs(records, args.output_stem)
    print(f"records={len(records)}")
    print(f"output={args.output_stem}")


if __name__ == "__main__":
    main()

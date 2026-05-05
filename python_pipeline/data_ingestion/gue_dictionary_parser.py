from __future__ import annotations

import re
from pathlib import Path
from typing import Any

from bs4 import BeautifulSoup


def clean_gue_text(value: str) -> str:
    value = re.sub(r"\s+", " ", value or "").strip()
    value = re.sub(r"^(See:|ALSO:)\s*", "", value).strip()
    return value.replace(" = ", " ").replace(" .", ".")


def parse_gue_dictionary(html_path: Path) -> list[dict[str, Any]]:
    soup = BeautifulSoup(
        html_path.read_text(encoding="utf-8", errors="ignore"),
        "html.parser",
    )
    entries: list[dict[str, Any]] = []

    for node in soup.select("article.main-content > div.wsumarcs-entry"):
        headword_node = node.select_one(".wsumarcs-entryLx")
        if not headword_node:
            continue

        entry: dict[str, Any] = {
            "headword": clean_gue_text(headword_node.get_text(" ", strip=True)),
            "pos": "",
            "definitions": [],
            "variants": [],
            "audio": [],
            "examples": [],
        }
        pending_gurindji: str | None = None
        pending_audio: str | None = None

        for child in node.find_all(recursive=False):
            classes = set(child.get("class") or [])
            text = clean_gue_text(child.get_text(" ", strip=True))
            audio_node = child.find("img", class_="entryAudio")

            if "wsumarcs-entryLx" in classes:
                continue
            if "wsumarcs-entryPs" in classes:
                entry["pos"] = text
                continue
            if "wsumarcs-entryDe" in classes:
                if text:
                    entry["definitions"].append(text)
                continue
            if "wsumarcs-entrySe" in classes or "wsumarcs-entryVariant" in classes:
                if text:
                    entry["variants"].append(text)
                continue
            if audio_node:
                audio = _local_audio_path(audio_node)
                if pending_gurindji:
                    pending_audio = audio
                else:
                    entry["audio"].append(audio)
                continue
            if "wsumarcs-entryXe" in classes:
                if text and pending_gurindji:
                    entry["examples"].append(
                        {
                            "gurindji": pending_gurindji,
                            "english": text,
                            "audio": pending_audio or "",
                        }
                    )
                    pending_gurindji = None
                    pending_audio = None
                continue
            if "wsumarcs-entryXv" in classes and text:
                pending_gurindji = text
                pending_audio = None

        entries.append(entry)

    return entries


def _local_audio_path(audio_node: Any) -> str:
    title = audio_node.get("title") or Path(audio_node.get("data-file", "")).name
    return f"audiodict/{title}"

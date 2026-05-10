from pathlib import Path
import re
import sys

from bs4 import BeautifulSoup


BASE_DIR = Path(__file__).resolve().parent
SRC = BASE_DIR / "az_page.html"
OUT = BASE_DIR / "gue_dict_dataset.md"


def clean_text(value: str) -> str:
    value = re.sub(r"\s+", " ", value or "").strip()
    value = re.sub(r"^(See:|ALSO:)\s*", "", value).strip()
    value = value.replace(" = ", " ").replace(" .", ".")
    return value


def local_audio_path(img) -> str:
    title = img.get("title") or Path(img.get("data-file", "")).name
    return f"audiodict/{title}"


def child_classes(tag) -> set[str]:
    return set(tag.get("class") or [])


def parse_entries() -> list[dict]:
    soup = BeautifulSoup(SRC.read_text(encoding="utf-8", errors="ignore"), "html.parser")
    entries = []

    for node in soup.select("article.main-content > div.wsumarcs-entry"):
        headword_node = node.select_one(".wsumarcs-entryLx")
        if not headword_node:
            continue

        entry = {
            "headword": clean_text(headword_node.get_text(" ", strip=True)),
            "pos": "",
            "definitions": [],
            "variants": [],
            "audio": [],
            "examples": [],
        }

        pending_gurindji = None
        pending_audio = None

        for child in node.find_all(recursive=False):
            classes = child_classes(child)
            text = clean_text(child.get_text(" ", strip=True))
            img = child.find("img", class_="entryAudio")

            if "wsumarcs-entryLx" in classes:
                continue
            if "wsumarcs-entryPs" in classes:
                entry["pos"] = text
                continue
            if "wsumarcs-entryDe" in classes:
                if text:
                    entry["definitions"].append(text)
                continue
            if "wsumarcs-entrySe" in classes:
                if text:
                    entry["variants"].append(text)
                continue
            if "wsumarcs-entryVariant" in classes:
                if text:
                    entry["variants"].append(text)
                continue
            if img:
                audio = local_audio_path(img)
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

            if not text:
                continue
            if text.startswith("See:") or text.startswith("ALSO:"):
                value = clean_text(text)
                if value:
                    entry["variants"].append(value)
                continue
            if re.fullmatch(r"[0-9]+\.", text):
                continue
            if text.startswith("="):
                value = clean_text(text)
                if value:
                    entry["variants"].append(value)
                continue
            if pending_gurindji:
                entry["examples"].append(
                    {"gurindji": pending_gurindji, "english": "", "audio": pending_audio or ""}
                )
                pending_audio = None
            pending_gurindji = text

        if pending_gurindji:
            entry["examples"].append(
                {"gurindji": pending_gurindji, "english": "", "audio": pending_audio or ""}
            )

        entry["definitions"] = list(dict.fromkeys(entry["definitions"]))
        entry["variants"] = list(dict.fromkeys(entry["variants"]))
        entry["audio"] = list(dict.fromkeys(entry["audio"]))
        if entry["headword"]:
            entries.append(entry)

    return entries


def render(entries: list[dict]) -> str:
    lines = ["# Gurindji Dictionary Dataset", "", f"Total entries: {len(entries)}", ""]
    for entry in entries:
        lines.append(f"## {entry['headword']}")
        if entry["pos"]:
            lines.append(f"- POS: {entry['pos']}")
        for definition in entry["definitions"]:
            lines.append(f"- Definition: {definition}")
        for variant in entry["variants"]:
            lines.append(f"- Related: {variant}")
        for audio in entry["audio"]:
            lines.append(f"- Audio: {audio}")
        for example in entry["examples"]:
            parts = []
            if example["gurindji"]:
                parts.append(f"GU: {example['gurindji']}")
            if example["english"]:
                parts.append(f"EN: {example['english']}")
            if example["audio"]:
                parts.append(f"AUDIO: {example['audio']}")
            if parts:
                lines.append(f"- Example: {' | '.join(parts)}")
        lines.append("")
    return "\n".join(lines).strip() + "\n"


def main() -> None:
    entries = parse_entries()
    content = render(entries)
    if "--stdout" in sys.argv:
        sys.stdout.write(content)
        return
    OUT.write_text(content, encoding="utf-8")
    print(f"entries={len(entries)}")
    print(f"out={OUT}")


if __name__ == "__main__":
    main()

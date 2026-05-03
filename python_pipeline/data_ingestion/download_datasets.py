"""
Step 1: Download public English medical speech datasets.

Datasets used:
  - aline-gassenn/MedDialogue-Audio  (10k+ clinical dialogues, synthetic TTS + ambient noise)
  - mozilla-foundation/common_voice_17_0  (en subset, for accent diversity, optional)

Requirements:
  pip install datasets huggingface_hub soundfile librosa
"""

import os
from datasets import load_dataset, Audio
from pathlib import Path

SAVE_DIR = Path("./data/raw")
SAVE_DIR.mkdir(parents=True, exist_ok=True)


def download_med_dialog():
    print("[1/2] Downloading MedDialogue-Audio ...")
    ds = load_dataset(
        "aline-gassenn/MedDialogue-Audio",
        split="train",
        trust_remote_code=True,
    )
    ds = ds.cast_column("audio", Audio(sampling_rate=16_000))
    ds.save_to_disk(str(SAVE_DIR / "med_dialog_audio"))
    print(f"  → Saved {len(ds):,} samples to {SAVE_DIR / 'med_dialog_audio'}")
    return ds


def download_common_voice_en(max_samples: int = 5000):
    """Optional: add accent diversity from Common Voice."""
    print("[2/2] Downloading CommonVoice en (first split only) ...")
    ds = load_dataset(
        "mozilla-foundation/common_voice_17_0",
        "en",
        split=f"train[:{max_samples}]",
        trust_remote_code=True,
    )
    ds = ds.cast_column("audio", Audio(sampling_rate=16_000))
    ds = ds.rename_column("sentence", "text")
    ds.save_to_disk(str(SAVE_DIR / "common_voice_en"))
    print(f"  → Saved {len(ds):,} samples to {SAVE_DIR / 'common_voice_en'}")
    return ds


if __name__ == "__main__":
    download_med_dialog()
    download_common_voice_en()

"""
Step 4: Build a synthetic Gurindji audio dataset for Phase 2 fine-tuning.

Strategy (no native audio exists):
  1. Load 769-entry Gurindji-English dictionary (gurindji_dict_full.xlsx)
  2. Build sentence templates using health-relevant entries (body + symptom + disease + emotion)
  3. Synthesize audio using gTTS (Australian English accent proxy) or Kokoro TTS
  4. Export as HuggingFace dataset (audio array + text label)

Note: Synthetic audio is an approximation only. Ideally collect 50–200 real recordings
      from native Gurindji speakers. This script generates enough data for initial
      fine-tuning and forced-decoding experiments.

pip install gtts pydub openpyxl datasets soundfile
"""

import io
import random
import pandas as pd
from pathlib import Path
from datasets import Dataset, Audio as HFAudio
import soundfile as sf
import numpy as np

# ──────────────────────────────────────────────
# Config
# ──────────────────────────────────────────────
DICT_PATH = "../../gurindji_dict_full.xlsx"   # adjust relative path
OUTPUT_DIR = Path("./data/gurindji_synthetic")
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
SAMPLE_RATE = 16_000

# Health-relevant types to include
HEALTH_TYPES = {"body", "symptom", "disease", "emotion", "question", "greeting"}

# Sentence templates: {gurindji_word} used as spoken target
TEMPLATES = [
    "I have {english} ({gurindji})",
    "My {english} hurts ({gurindji})",
    "{gurindji}",                           # bare word for vocabulary injection
    "Pain in {english}",
    "I feel {english}",
]


def load_dict() -> pd.DataFrame:
    df = pd.read_excel(DICT_PATH)
    df.columns = ["gurindji", "english", "type"]
    df = df.dropna(subset=["gurindji", "english"])
    return df[df["type"].isin(HEALTH_TYPES)].reset_index(drop=True)


def synthesize_audio_gtts(text: str) -> np.ndarray:
    """Generate 16 kHz mono audio array from text via gTTS."""
    from gtts import gTTS
    from pydub import AudioSegment

    tts = gTTS(text=text, lang="en", tld="com.au")  # Australian English
    buf = io.BytesIO()
    tts.write_to_fp(buf)
    buf.seek(0)

    seg = AudioSegment.from_mp3(buf)
    seg = seg.set_frame_rate(SAMPLE_RATE).set_channels(1).set_sample_width(2)
    raw = np.array(seg.get_array_of_samples(), dtype=np.float32) / 32768.0
    return raw


def build_dataset(n_per_entry: int = 3) -> Dataset:
    df = load_dict()
    print(f"[SACA] Building synthetic dataset from {len(df)} health entries ...")

    records = []
    for _, row in df.iterrows():
        for _ in range(n_per_entry):
            template = random.choice(TEMPLATES)
            text = template.format(
                gurindji=row["gurindji"],
                english=row["english"].lower().strip("the "),
            )
            try:
                audio_array = synthesize_audio_gtts(text)
                records.append({
                    "audio": {"array": audio_array, "sampling_rate": SAMPLE_RATE},
                    "text": text,
                    "type": row["type"],
                    "gurindji_word": row["gurindji"],
                    "english_meaning": row["english"],
                })
            except Exception as e:
                print(f"  [!] TTS failed for '{text}': {e}")

    ds = Dataset.from_list(records)
    ds = ds.cast_column("audio", HFAudio(sampling_rate=SAMPLE_RATE))
    ds.save_to_disk(str(OUTPUT_DIR / "gurindji_synthetic_v1"))
    print(f"[SACA] Saved {len(ds):,} synthetic samples → {OUTPUT_DIR}")
    return ds


if __name__ == "__main__":
    build_dataset(n_per_entry=3)
    # Total: ~172 health entries × 3 templates ≈ 516 samples
    # Sufficient for vocabulary injection fine-tuning experiment.
    print("\nNext step: run 02_finetune_whisper.py with DATA_PATH pointing to")
    print("  ./data/gurindji_synthetic/gurindji_synthetic_v1")

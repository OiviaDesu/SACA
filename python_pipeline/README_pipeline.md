# SACA – Whisper Fine-tuning Pipeline

## Phase 1: English Health Baseline

### Dataset
- **MedDialog-Audio** (Hugging Face: `aline-gassenn/MedDialogue-Audio`) – 10,000+ synthetic clinical dialogues with ambient hospital noise
- **CommonVoice 17.0 en** (optional, for accent diversity)
- **Custom recordings** – community health workers at remote clinics (target: 50–200 utterances)

### Steps

```
1. download_datasets.py   → pull MedDialog-Audio from HuggingFace
2. prepare_audio.py       → resample to 16 kHz mono, trim silence
3. build_manifest.py      → create HF dataset (audio, sentence) columns
4. finetune_whisper.py    → fine-tune openai/whisper-small
5. evaluate.py            → compute WER on held-out set
6. export_ggml.py         → convert to ggml quantized for mobile
```

---

## Phase 2: Gurindji Extension

### Approach (no pre-existing audio corpus)

Because Gurindji is extremely low-resource (no ASR training data exists), we use:

1. **Text-only vocabulary injection** – force-decode Gurindji tokens via Whisper's multilingual decoder prompt
2. **Synthetic speech** – TTS-generated Gurindji audio from the 769-entry dictionary using a general Australian-English TTS voice as proxy
3. **Transfer learning** – fine-tune Phase 1 English model on synthetic Gurindji utterances
4. **Hotword / forced decoding** – at inference time, restrict Whisper's beam search to known Gurindji vocabulary tokens

### Gurindji vocab available (from gurindji_dict_full.xlsx)
- Total entries: 769
- Medical-relevant types: body (97), symptom (51), disease (24) = **172 terms**
- Other useful: emotion (23), question (9), greeting (6)

---

## Phase 2 Limitations & Mitigation

| Challenge | Mitigation |
|---|---|
| No native Gurindji audio training data | Synthetic TTS + community recording sessions |
| Whisper tokenizer may split Gurindji words into subwords | Add custom tokens to tokenizer vocab |
| Accent mismatch | Fine-tune on Australian English accents first |
| Out-of-vocabulary medical terms | Prefix prompt with medical word list |

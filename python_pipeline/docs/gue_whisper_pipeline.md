# Gurindji Whisper Pipeline

This folder documents the local-only GUE dataset preparation path for the first
OzSTAR Whisper baseline.

## Source Policy

- `az_page.html` is a local dictionary HTML dump and is not committed.
- `audiodict/` contains local dictionary audio and is not committed.
- `gue_whisper_dataset.*` and `whisper_gue_ready/` are generated artifacts and
  are not committed.
- Git stores only reusable scripts, Slurm templates, and documentation.

## Build Records

```bash
python python_pipeline/data_ingestion/make_gue_whisper_dataset.py \
  --html python_pipeline/az_page.html \
  --audio-dir python_pipeline/audiodict \
  --output-stem python_pipeline/gue_whisper_dataset
```

The source mapping is:

- headword audio -> `headword_pronunciation`
- example audio + Gurindji sentence -> `example_sentence`
- English definition/translation -> metadata only, not Whisper target text

## Prepare Manifests

```bash
python python_pipeline/prepare_gue_whisper_manifests.py \
  --source python_pipeline/gue_whisper_dataset.jsonl \
  --output-dir python_pipeline/whisper_gue_ready
```

First baseline uses only `example_sentence` rows:

```text
train: 1672
validation: 73
test: 96
```

Reason: headword pronunciation rows dominate the raw dictionary data and bias
the model toward isolated words. Use `mixed_headword` only after the sentence
baseline has a clean WER/CER reference.

## Whisper Notes

- Model: `openai/whisper-small`
- Do not set `language="gue"`; Whisper has no Gurindji language token.
- Do not add custom `<|gue|>` token in the first run.
- Clear forced decoder ids and suppress tokens before training.
- Training transcripts stay as canonical dictionary/source text. Do not rewrite
  semantic or orthographic variants such as loanword spellings unless the source
  transcript has an obvious technical corruption.

## Metrics

Training and decode audit report both exact and normalized metrics:

- `raw_wer` / `raw_cer`: exact transcript fidelity.
- `norm_wer` / `norm_cer`: punctuation/case/spelling-tolerant evaluation only.

Best checkpoint selection uses `norm_cer`, while raw metrics remain logged for
honest reporting. Optional spelling variants live in
`python_pipeline/orthography_mapping.tsv` with `variant`, `canonical`, and
`reason` columns. Keep this file empty or minimal until variants are verified
from `gue_dict.md`, validation/test decode errors, or parser evidence.

## OzSTAR Slurm

Reference docs:

- https://supercomputing.swin.edu.au/docs/
- https://supercomputing.swin.edu.au/docs/1-getting_started/Access.html
- https://supercomputing.swin.edu.au/docs/2-ozstar/oz-slurm-create.html

Submit baseline on the login node after syncing code and manifests:

```bash
sbatch python_pipeline/hpc/slurm_train_whisper_gue_example_only.sh
squeue -u dunguyen
tail -f /fred/oz396/dunguyen/saca_whisper/outputs/logs/gue_small_<job_id>.out
```

## Decode Audit

After a checkpoint exists, write human-readable samples plus review TSVs:

```bash
python python_pipeline/evaluate_whisper_gue_decode.py \
  --model /fred/oz396/dunguyen/saca_whisper/outputs/whisper-small-gue-example-only/checkpoint-200 \
  --manifest python_pipeline/whisper_gue_ready/example_only/validation.jsonl \
  --limit 73 \
  --batch-size 8 \
  --output /fred/oz396/dunguyen/saca_whisper/outputs/audits/checkpoint-200_decode_audit.txt \
  --audit-tsv /fred/oz396/dunguyen/saca_whisper/outputs/audits/checkpoint-200_decode_audit.tsv \
  --mapping-candidates /fred/oz396/dunguyen/saca_whisper/outputs/audits/mapping_candidates.tsv
```

The audit TSV includes per-row `raw_*` and `norm_*` metrics plus `id`,
`label_type`, `ref`, `pred`, normalized text, and audio path. Mapping candidates
are suggestions only; never auto-apply them to training transcripts or metrics.

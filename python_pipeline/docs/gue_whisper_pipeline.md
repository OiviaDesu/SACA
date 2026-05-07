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
python python_pipeline/data_ingestion/prepare_gue_whisper_manifests.py \
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

- Current best model family: `openai/whisper-base`.
- Initial baseline family: `openai/whisper-small`.
- Do not set `language="gue"`; Whisper has no Gurindji language token.
- Do not add custom `<|gue|>` token in the first run.
- Clear forced decoder ids and suppress tokens before training.
- Training transcripts stay as canonical dictionary/source text. Do not rewrite
  semantic or orthographic variants such as loanword spellings unless the source
  transcript has an obvious technical corruption.

## Current Best Checkpoint

Promoted checkpoint after run4:

```text
/fred/oz396/dunguyen/saca_whisper/outputs/whisper-base-gue-example-only-run4/checkpoint-200
```

Marker file on OzSTAR:

```text
/fred/oz396/dunguyen/saca_whisper/outputs/current_best_checkpoint.txt
```

Run4 beats the previous Whisper-small baseline checkpoint-200:

```text
validation raw_cer:  0.322631 -> 0.258774  (19.80% relative improvement)
validation norm_cer: 0.304173 -> 0.241265  (20.69% relative improvement)
```

Run4 checkpoint-200 test metrics:

```text
raw_wer  = 0.818722
raw_cer  = 0.231899
norm_wer = 0.662910
norm_cer = 0.210436
```

## RC1 App Export

Run4 checkpoint-200 is the current app release candidate:

```text
RC1 label: gue-whisper-base-run4-ckpt200-rc1
source: /fred/oz396/dunguyen/saca_whisper/outputs/whisper-base-gue-example-only-run4/checkpoint-200
export root: /fred/oz396/dunguyen/saca_whisper/outputs/exports/gue-whisper-base-run4-ckpt200-rc1
```

Mobile export for whisper.cpp / WhisperKit:

```text
remote: /fred/oz396/dunguyen/saca_whisper/outputs/exports/gue-whisper-base-run4-ckpt200-rc1/ggml-gue-whisper-base-run4-ckpt200-rc1-q5_0.bin
local: assets/models/whisper-gue-base-run4-rc1/ggml-gue-whisper-base-run4-ckpt200-rc1-q5_0.bin
quantization: Q5_0
approx size: 53 MB
```

Windows export target for sherpa-onnx:

```text
local: assets/models/sherpa-onnx-whisper-gue-base-run4-rc1/encoder.onnx
local: assets/models/sherpa-onnx-whisper-gue-base-run4-rc1/decoder.onnx
local: assets/models/sherpa-onnx-whisper-gue-base-run4-rc1/tokens.txt
remote: /fred/oz396/dunguyen/saca_whisper/outputs/exports/gue-whisper-base-run4-ckpt200-rc1/sherpa-onnx/encoder.onnx
remote: /fred/oz396/dunguyen/saca_whisper/outputs/exports/gue-whisper-base-run4-ckpt200-rc1/sherpa-onnx/decoder.onnx
remote: /fred/oz396/dunguyen/saca_whisper/outputs/exports/gue-whisper-base-run4-ckpt200-rc1/sherpa-onnx/tokens.txt
format: sherpa-onnx int8 encoder/decoder
```

Smoke status recorded before Flutter integration:

- Gurindji Q5_0 whisper.cpp smoke on three validation clips was non-blank and
  not English-dominant.
- English Q5_0 whisper.cpp smoke on three short clinical TTS clips matched the
  expected English sentences.
- English support comes from multilingual `openai/whisper-base` pretraining plus
  smoke testing; RC1 is not a clinical or official language validation.

Flutter runtime policy:

- English and Gurindji both resolve to RC1 by default.
- Mobile copies the RC1 Q5_0 asset into the WhisperKit model directory as
  `ggml-base.bin`.
- Windows uses the RC1 sherpa-onnx bundle. The old generic
  `sherpa-onnx-whisper-base` bundle is no longer the default app asset.

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
python python_pipeline/analysis/evaluate_whisper_gue_decode.py \
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

Run4 checkpoint-200 audits:

```text
/fred/oz396/dunguyen/saca_whisper/outputs/audits/run4_checkpoint-200/validation/decode_audit.tsv
/fred/oz396/dunguyen/saca_whisper/outputs/audits/run4_checkpoint-200/test/decode_audit.tsv
```

Next analysis should extract repeated substitution, deletion, and insertion
patterns from those TSVs, review them manually, and only then add verified rows
to `/fred/oz396/dunguyen/saca_whisper/code/python_pipeline/orthography_mapping.tsv`.
Rerun decode-only metrics on the same checkpoint before doing any new training.

## Experiment Log

```text
run1 / whisper-small / original long run
  best: checkpoint-200
  status: previous best, superseded by run4
  audit sample: raw_cer 0.322631, norm_cer 0.304173
  note: later epochs overfit; final checkpoint not used

run2 / whisper-small / lr=5e-6, 3 epochs, linear decay
  status: failed, not promoted
  best trainer checkpoint: checkpoint-100
  audit checkpoint-100: raw_cer 1.287392, norm_cer 1.268058
  diagnosis: underfit / bad decode, English hallucination

run3 / whisper-small / lr=1e-5, 2 epochs, constant_with_warmup
  status: failed, not promoted
  validation log best: raw_cer 0.4122, norm_cer 0.3824
  audit checkpoint-100 sample: raw_cer 0.327330, norm_cer 0.297753
  diagnosis: small model still worse than stable baseline on comparable gate

run4 / whisper-base / lr=1e-5, 3 epochs, linear decay
  status: promoted
  best checkpoint: checkpoint-200
  validation: raw_cer 0.258774, norm_cer 0.241265
  test: raw_cer 0.231899, norm_cer 0.210436
  note: mapping file stayed empty; gains are model/training, not metric mapping
```

## Slurm Resource Notes

Run4 completed in about 8 minutes on A100. Future config was reduced to avoid
over-request warnings:

```text
time=00:15:00
cpus-per-task=1
mem=4G
tmp=6G
```

GPU utilisation warnings may persist because the dataset is only 1.8k short
clips; this is expected and not a quality issue.

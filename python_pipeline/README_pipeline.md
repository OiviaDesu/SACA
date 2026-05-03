# SACA NLP and Speech Research Pipeline

This folder contains local research scripts for SACA. Raw datasets, DoReCo
annotations, audio, trained models, and generated outputs must stay outside Git.

## Folder Layout

```text
python_pipeline/
  data_ingestion/    download, extraction, audit, and normalization scripts
  training/          classifier and Whisper training entry points
  export/            GGML, XGBoost, Dart bundle, and parity tools
  analysis/          TF-IDF dataset analysis and run aggregation
  hpc/               Slurm jobs and HPC preparation scripts
  requirements/      dependency lists by workflow
  data/raw/          source CSV/XLSX datasets
  data/processed/    normalized training-ready datasets
  data/samples/      small examples and smoke-test manifests
```
## Environment Setup

Python `3.9+` is recommended.

**Linux / macOS**

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r python_pipeline/requirements/classifier.txt
```

**Windows (PowerShell)**

```powershell
python -m venv .venv
.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r python_pipeline/requirements/classifier.txt
```

Generated outputs, model binaries, campaign manifests, and intermediate build
artifacts are intentionally ignored by Git. Commit source, docs, and tracked
input datasets only.

## Local DoReCo Gurindji Annotations

The current workspace has DoReCo Gurindji core/extended annotation files in a
sibling `../Data` folder. These files are useful for corpus and glossary
research, not for medical symptom classification.

Run:

```powershell
python python_pipeline/data_ingestion/extract_doreco_gurindji.py
```

Outputs are local-only under `python_pipeline/outputs/doreco_gurindji/`:

- `cleaned_words.csv`
- `frequency.csv`
- `foreign_material.csv`
- `candidate_health_terms.csv`
- `summary.json`

Do not commit these outputs unless explicit redistribution permission exists.

## Medical NLP Classifier Path

The app can later replace `MockAnalysisService` with a small classifier behind
the existing `AnalysisService` contract. The current repo is still a Flutter
prototype with deterministic safety rules and offline Whisper STT assets; the ML
classifier is a local research pipeline, not a validated clinical model.

Recommended datasets:

- Gretel `symptom_to_diagnosis`
- Symptom2Disease
- Healthcare Symptoms-Disease Classification Dataset
- Disease and Symptoms Dataset for lookup/reference only
- BI55/MedText for supplementary severity examples
- Local CSV/JSON rows with English, Gurindji, and mixed Gurindji-Kriol text

Decision summary and source URLs are tracked in
`docs/DATASET_RESEARCH_SUMMARY.md`.

Keep raw downloads under `python_pipeline/data/raw/`, which is ignored by Git.
Public symptom datasets usually contain diagnosis labels, not real clinical
triage acuity. Train diagnosis and severity as separate tasks. Derive emergency
red-flag severity from ATS/ETEK-style rules and keep that safety layer
independent from model confidence. Treat public synthetic/curated datasets as
prototype training data only, not clinical evidence.

### Current Classifier Pipeline

Install dependencies:

```powershell
python -m pip install -r python_pipeline/requirements/classifier.txt
```

Optional pip update first:

```powershell
python -m pip install --upgrade pip
```

Expected local schema can be wide, but these columns are supported by default:

| Purpose | Default columns |
| --- | --- |
| Text symptoms/transcripts | `symptoms_text`, `transcript_text` |
| Label | pass with `--label-col severity_label` or `--label-col diagnosis_label` |
| Structured categorical | `body_location`, `prior_medications`, `language`, `source` |
| Structured numeric | `duration_hours`, `duration_days` |

`language` is normalized into `english`, `gurindji`, `gurindji-kriol`, or
`unknown`. Mixed Gurindji language and Gurindji Kriol code-switching should use
`gurindji-kriol` where possible. Unknown Gurindji wording is preserved rather
than guessed.

If you want visible progress while the command is running, add `--verbose`.
That prints milestone logs for dataset loading, audit generation, train/test
split, model tuning, SHAP computation, ONNX export, and artifact writes. In
PowerShell, use the backtick `` ` `` for line continuation.

The trainer now defaults to a **balanced** tuning budget for faster iteration:

- `--cv-folds 3` by default (instead of 5)
- `--max-text-features 10000` by default (instead of 20000)
- `--tuning-profile balanced` by default, which trims the XGBoost search space
- `--skip-shap` is available for quick-turn tuning runs when explanations are
   not needed immediately

Use `--tuning-profile full` if you need the original exhaustive XGBoost grid.

Recommended run order:

1. **Audit local data first**

    ```powershell
    python python_pipeline/audit_local_data.py
    ```

    Audit output is written to
    `python_pipeline/outputs/local_data_audit/audit_summary.json`.

2. **Inspect the trainer CLI**

    ```powershell
    python python_pipeline/training/train_classifier.py --help
    ```

3. **Run a small severity smoke test**

    The checked-in sample file is suitable for severity smoke validation.

```powershell
python python_pipeline/training/train_classifier.py `
   --data python_pipeline/data/samples/triage_dataset.csv `
   --label-col severity_label `
   --task severity `
   --model lr `
   --cv-folds 2 `
   --test-size 0.33 `
   --verbose `
   --output-dir python_pipeline/outputs/classifier_smoke
```

1. **Run a quick diagnosis validation**

    The checked-in `data/samples/triage_dataset.csv` is not a reliable diagnosis smoke
    dataset because most diagnosis labels appear only once. For diagnosis,
    either use your own small CSV where each diagnosis label appears at least
    twice, or use the normalized diagnosis dataset already in the repo.

```powershell
python python_pipeline/training/train_classifier.py `
   --data python_pipeline/data/processed/normalized_diagnosis_dataset.csv `
   --label-col diagnosis_label `
   --task diagnosis `
   --text-cols symptoms_text transcript_text `
   --categorical-cols body_location prior_medications language source `
   --numeric-cols duration_hours duration_days `
   --model lr `
   --cv-folds 2 `
   --verbose `
   --output-dir python_pipeline/outputs/classifier_smoke_diagnosis
```

1. **Train the main diagnosis run on the normalized dataset**

    Safest default in this repo:

    - `python_pipeline/data/processed/normalized_diagnosis_dataset.csv`

```powershell
python python_pipeline/training/train_classifier.py `
   --data python_pipeline/data/processed/normalized_diagnosis_dataset.csv `
   --label-col diagnosis_label `
   --task diagnosis `
   --text-cols symptoms_text transcript_text `
   --categorical-cols body_location prior_medications language source `
   --numeric-cols duration_hours duration_days `
   --model both `
   --tuning-profile balanced `
   --skip-shap `
   --verbose `
   --output-dir python_pipeline/outputs/classifier_diagnosis_run1
```

1. **Build an intermediate multi-source diagnosis dataset before training**

    Instead of pointing the trainer at raw files with mixed schemas, build one
    training-ready CSV first. This keeps `multi` runs honest: the builder
    normalizes source-specific columns, strips bot turns from
    `medical_conversations.csv`, de-duplicates rows, and applies the same
    label-cleaning rules the trainer expects.

```powershell
python python_pipeline/data_ingestion/normalize_datasets.py `
   --input-paths `
      python_pipeline/data/raw/gretel_symptom_to_diagnosis.csv `
      python_pipeline/data/raw/Symptom2Disease.csv `
   --output python_pipeline/outputs/intermediate_datasets/diagnosis_multi_dataset.csv `
   --summary-output python_pipeline/outputs/intermediate_datasets/diagnosis_multi_dataset.summary.json
```

The JSON summary records which source files were processed or skipped plus the
post-cleaning row count that will actually reach the trainer.

### Split LR and XGBoost into Separate OzSTAR Jobs

For OzSTAR, the repo now includes dedicated split-job scripts so LR and XGBoost
can use different Slurm budgets while each job still runs **both** the
normalized single dataset and the built multi-dataset flow.

- `python_pipeline/slurm_train_classifier_lr.sh`
   - historical recommendation: `16 CPU`, `1h`, `12G RAM`, **no GPU**
   - reason: historical combined jobs reached XGBoost after about 15 minutes on
      both 16 CPU and 32 CPU, so LR did not benefit much from extra CPU
- `python_pipeline/slurm_train_classifier_xgb.sh`
   - historical recommendation: `32 CPU`, `3h`, `20G RAM`, `gpu:1`
   - reason: historical combined jobs saturated CPU/GPU and timed out in the
      XGBoost phase at 4h, so XGBoost needs its own GPU-backed budget

Recommended submission on OzSTAR:

```bash
sbatch /fred/oz396/dunguyen/saca_whisper/code/slurm_train_classifier_lr.sh
sbatch /fred/oz396/dunguyen/saca_whisper/code/slurm_train_classifier_xgb.sh
```

If you want to submit the entire `quick -> balanced -> full` ladder in one go,
use the campaign helper:

```bash
bash /fred/oz396/dunguyen/saca_whisper/code/submit_classifier_profile_campaign.sh
```

The helper submits **6 isolated jobs** (`lr/xgb x quick/balanced/full`) and
writes a submission manifest under:

```text
/fred/oz396/dunguyen/saca_whisper/outputs/classifier_campaigns/<campaign_name>/submission_manifest.json
```

Each job gets its own:

- `OUT_SINGLE`
- `OUT_MULTI`
- intermediate dataset CSV
- intermediate dataset summary JSON

This matters because concurrent profile runs would otherwise overwrite the same
`OUT_MULTI` and `outputs/intermediate_datasets/diagnosis_multi_dataset.csv`
paths.

Default campaign knobs are tuned for the current expanded diagnosis ladder:

- `MULTI_BUILD_INCLUDE_HEALTHCARE=1`
- `MULTI_BUILD_INCLUDE_MEDICAL_CONVERSATIONS=1`
- `MULTI_BUILD_INCLUDE_PREBUILT_NORMALIZED=0`
- `CV_FOLDS=3`
- `MAX_TEXT_FEATURES=10000`
- `SKIP_SHAP=1`
- `RUN_AUDIT=0` (to avoid rerunning the same audit 6 times)

The helper also bumps walltime automatically for the heavy profiles:

- LR `full` -> `02:00:00`
- XGB `full` -> `08:00:00`

Track baseline numbers, submitted job IDs, and future rung-by-rung results in:

```text
docs/CLASSIFIER_TUNING_RUN_LOG.md
```

After submission, inspect the manifest and then monitor the whole batch with:

```bash
squeue -j <comma-separated-job-ids>
```

The legacy combined script `python_pipeline/hpc/slurm_train_classifier.sh` is still
available as a compatibility fallback, but the split scripts are the preferred
path for production runs.

Both split jobs now include an explicit intermediate build step before the
multi-file train step:

1. audit local data
2. train the single normalized dataset
3. build `outputs/intermediate_datasets/diagnosis_multi_dataset.csv`
4. train on that built dataset

To preserve the current runtime budget, the intermediate builder defaults to the
two natural-language diagnosis sources (`gretel` + `Symptom2Disease`). Optional
extra sources can be enabled in the Slurm environment:

- `MULTI_BUILD_INCLUDE_HEALTHCARE=1`
- `MULTI_BUILD_INCLUDE_MEDICAL_CONVERSATIONS=1`
- `MULTI_BUILD_INCLUDE_PREBUILT_NORMALIZED=1`

1. **Train from multiple diagnosis files at once**

```powershell
python python_pipeline/data_ingestion/normalize_datasets.py `
   --input-paths `
      python_pipeline/data/raw/gretel_symptom_to_diagnosis.csv `
      python_pipeline/data/raw/Symptom2Disease.csv `
   --output python_pipeline/outputs/intermediate_datasets/diagnosis_multi_dataset.csv `
   --summary-output python_pipeline/outputs/intermediate_datasets/diagnosis_multi_dataset.summary.json

python python_pipeline/training/train_classifier.py `
   --data python_pipeline/outputs/intermediate_datasets/diagnosis_multi_dataset.csv `
   --label-col diagnosis_label `
   --task diagnosis `
   --text-cols symptoms_text transcript_text `
   --categorical-cols body_location prior_medications language source `
   --numeric-cols duration_hours duration_days `
   --model both `
   --tuning-profile balanced `
   --skip-shap `
   --verbose `
   --output-dir python_pipeline/outputs/classifier_diagnosis_multi
```

1. **Inspect output artifacts**

```powershell
dir python_pipeline\outputs\classifier_diagnosis_run1
```

Typical files:

- `best_model.joblib`
- `dataset_audit.json`
- `label_metadata.json`
- `metrics.json`
- `run_summary.json`
- `onnx_export_status.json` when `--export-onnx` is used

1. **Merge LR and XGBoost results after both jobs finish**

Use the merge utility to build a unified leaderboard and copy the winning model
artifact into a final output folder:

```bash
python python_pipeline/analysis/merge_classifier_runs.py \
   --lr-dir /fred/oz396/dunguyen/saca_whisper/outputs/classifier_diagnosis_single_lr \
   --xgb-dir /fred/oz396/dunguyen/saca_whisper/outputs/classifier_diagnosis_single_xgb \
   --scope-name single \
   --output-dir /fred/oz396/dunguyen/saca_whisper/outputs/classifier_diagnosis_single_merged
```

Repeat the same command for the `multi` scope by pointing to the corresponding
`multi_lr` and `multi_xgb` directories.

1. **Optional LR ONNX export**

```powershell
python python_pipeline/training/train_classifier.py `
   --data python_pipeline/data/processed/normalized_diagnosis_dataset.csv `
   --label-col diagnosis_label `
   --task diagnosis `
   --model lr `
   --export-onnx `
   --verbose `
   --output-dir python_pipeline/outputs/classifier_onnx_run
```

Pipeline behavior:

1. Audits dataset columns, missing values, label counts, text lengths, and sample
   rows into `dataset_audit.json`.
2. Merges symptom text and Whisper transcripts into `combined_text`.
3. Uses character TF-IDF n-grams (`char_wb`, 2-5 or 3-5) because small Gurindji,
   English, and Gurindji-Kriol datasets have spelling variation and code-switching.
4. Encodes structured categorical fields with `OneHotEncoder` and numeric fields
   with median imputation.
5. Handles class imbalance with `class_weight="balanced"` for Logistic Regression;
   XGBoost is tuned with macro-F1 so minority classes matter.
6. Trains Logistic Regression baseline and XGBoost main model using
   a manual cross-validation search loop; `--verbose` and `--live-progress`
   enable visible tuning progress. Use
   `--tuning-profile quick` for shortest turnaround, `balanced` for the default
   HPC compromise, or `full` to restore the exhaustive search.
7. Reports accuracy, macro-F1, weighted-F1, confusion matrix, classification
   report, LR coefficients, and XGBoost SHAP top features. Add `--skip-shap`
   when you only need model selection artifacts quickly.
8. Saves `best_model.joblib`, per-model metrics, label metadata, and run summary
   under the requested output directory.

When LR and XGBoost are trained in separate Slurm jobs, use
`merge_classifier_runs.py` to rebuild the cross-model leaderboard and copy the
winning `best_model.joblib` into one merged output directory per scope.

### Offline Mobile Export Strategy

Use three tiers:

1. **Semester-safe default:** keep `best_model.joblib` for reproducible Python
   evaluation and demos. Flutter can keep using `MockAnalysisService` plus safety
   rules until a runtime integration is tested.
2. **Preferred mobile path:** export Logistic Regression to ONNX only after parity
   testing. Run with `--export-onnx`; inspect `onnx_export_status.json`. ONNX
   string/TF-IDF operators must be tested on Android and Windows devices.
3. **Fallback offline path:** export TF-IDF vocabulary, IDF values, LR weights,
   and labels, then implement deterministic char n-gram inference in Dart. This
   is usually lighter and more predictable than XGBoost ONNX on Flutter.

XGBoost + sparse TF-IDF ONNX export is not treated as default-safe because
converter support and mobile string ops can differ across runtimes. Keep XGBoost
as main research model and SHAP explanation source; deploy only after device
parity tests pass.

### Experimental Dart export for the current `quick xgboost` winner

For the current winning `multi` diagnosis model, the repo now includes a local
experimental Dart export path built around:

1. a generated `m2cgen` Dart scorer;
2. a JSON preprocessing/tree bundle;
3. a parity checker that rebuilds the held-out split and compares export-time
    predictions against the original Python model.

Export the local bundle and scorer:

```bash
python python_pipeline/export/export_xgb_to_dart.py \
   --model-dir /fred/oz396/dunguyen/saca_whisper/outputs/classifier_campaigns/diagnosis_profile_ladder_20260503_154451/quick/xgb/multi \
   --bundle-output-dir assets/models/classifier-xgb-quick \
   --dart-model-output lib/infrastructure/analysis/generated_local/xgb_quick_model.dart \
   --write-python-scorer
```

Verify parity on the rebuilt held-out split from the same campaign dataset:

```bash
python python_pipeline/export/verify_xgb_dart_export.py \
   --model-dir /fred/oz396/dunguyen/saca_whisper/outputs/classifier_campaigns/diagnosis_profile_ladder_20260503_154451/quick/xgb/multi \
   --bundle-dir assets/models/classifier-xgb-quick \
   --data /fred/oz396/dunguyen/saca_whisper/outputs/classifier_campaigns/diagnosis_profile_ladder_20260503_154451/quick/xgb/intermediate/diagnosis_multi_dataset.csv \
   --label-col diagnosis_label
```

For binary XGBoost logistic exports, do **not** assume the generated scorer is
already returning class probabilities. Depending on the conversion path it may
emit raw margins/logits instead. The parity checker now tests those
interpretations against Python `predict_proba` before reporting the result.

Interpretation of the current results:

- the **bundle runtime** path is parity-safe for this model (`top1_agreement = 1.0`,
   `max_abs_diff < 1e-6` on the rebuilt held-out split);
- the **raw m2cgen scorer** path is still slightly off for a small number of
   rows, so treat it as experimental unless you accept that residual drift.

Why the bundle runtime is more stable right now:

- it preserves sparse-missing semantics with `NaN` for absent features;
- it quantizes inputs and thresholds to `float32`, which matches native XGBoost
   branch behavior more closely.

The generated files under `assets/models/classifier-xgb-quick/` and
`lib/infrastructure/analysis/generated_local/` are intentionally local-only and
ignored by Git.

## Whisper Fine-Tuning Path

DoReCo annotations exist locally under the sibling `../Data` folder, but the
current local folder contains annotation files only (`.eaf`, `.TextGrid`, `.xml`,
metadata CSV). No `.wav`, `.flac`, `.mp3`, `.m4a`, `.ogg`, or `.opus` audio files
were found in the current scan. Whisper fine-tuning cannot run from annotations
alone; it needs waveform audio aligned to transcripts.

The repo now includes `python_pipeline/training/finetune_whisper.py`, updated for the
current Transformers seq2seq Whisper API. It intentionally keeps English and
Gurindji together:

- uses multilingual checkpoints such as `openai/whisper-small`;
- does **not** force `language="english"`, because Gurindji is not a Whisper
  language token and forcing English would bias mixed Gurindji/English output;
- leaves `forced_decoder_ids=None` and task `transcribe`;
- preserves transcript text without lowercasing or translating;
- evaluates both WER and CER because Gurindji word segmentation can make WER too
  harsh.

Install dependencies:

```powershell
python -m pip install -r python_pipeline/requirements/whisper.txt
```

Required manifest format after audio is restored:

```csv
audio,text,language,speaker_id,source_id,duration_sec
C:\path\to\clip_0001.wav,"ngayi bin sick today",gurindji-kriol,FVD,FM11_32_1,3.2
C:\path\to\clip_0002.wav,"I have chest pain",english,FVD,FM11_32_1,2.8
```

Validate only:

```powershell
python python_pipeline/training/finetune_whisper.py ^
  --mode validate ^
  --data-root "C:\Users\OneGa\iCloudDrive\Documents\Major\COS70008\Demo\Data" ^
  --manifest python_pipeline/data/raw/gurindji_whisper_manifest.csv
```

Train after audio exists and manifest validates:

```powershell
python python_pipeline/training/finetune_whisper.py ^
  --mode train ^
  --data-root "C:\Users\OneGa\iCloudDrive\Documents\Major\COS70008\Demo\Data" ^
  --manifest python_pipeline/data/raw/gurindji_whisper_manifest.csv ^
  --model-name openai/whisper-small ^
  --output-dir python_pipeline/outputs/whisper_gurindji ^
  --gradient-checkpointing ^
  --fp16
```

Expected steps:

1. Obtain permission for PARADISEC/GK1 audio and any derived model
   redistribution.
2. Place audio under local ignored storage, not Git.
3. Build a manifest with `audio,text,language,speaker_id,source_id`.
4. Split by `source_id`/speaker to avoid leakage.
5. Fine-tune multilingual Whisper on mixed English + Gurindji/Gurindji-Kriol.
6. Evaluate WER/CER on held-out speakers/files.
7. Export offline artifacts only if redistribution is allowed.

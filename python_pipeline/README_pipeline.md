# SACA NLP and Speech Research Pipeline

This folder contains local research scripts for SACA. Raw datasets, DoReCo
annotations, audio, trained models, and generated outputs must stay outside Git.

## Local DoReCo Gurindji Annotations

The current workspace has DoReCo Gurindji core/extended annotation files in a
sibling `../Data` folder. These files are useful for corpus and glossary
research, not for medical symptom classification.

Run:

```powershell
python python_pipeline/01_extract_doreco_gurindji.py
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

Keep raw downloads under `python_pipeline/data/`, which is ignored by Git.
Public symptom datasets usually contain diagnosis labels, not real clinical
triage acuity. Train diagnosis and severity as separate tasks. Derive emergency
red-flag severity from ATS/ETEK-style rules and keep that safety layer
independent from model confidence. Treat public synthetic/curated datasets as
prototype training data only, not clinical evidence.

### Current Classifier Pipeline

Install dependencies:

```powershell
python -m pip install -r python_pipeline/requirements-classifier.txt
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

Recommended run order:

1. **Audit local data first**

    ```powershell
    python python_pipeline/audit_local_data.py
    ```

    Audit output is written to
    `python_pipeline/outputs/local_data_audit/audit_summary.json`.

2. **Inspect the trainer CLI**

    ```powershell
    python python_pipeline/train_classifier.py --help
    ```

3. **Run a small severity smoke test**

    The checked-in sample file is suitable for severity smoke validation.

```powershell
python python_pipeline/train_classifier.py `
   --data python_pipeline/sample_triage_dataset.csv `
   --label-col severity_label `
   --task severity `
   --model lr `
   --cv-folds 2 `
   --test-size 0.33 `
   --verbose `
   --output-dir python_pipeline/outputs/classifier_smoke
```

1. **Run a quick diagnosis validation**

    The checked-in `sample_triage_dataset.csv` is not a reliable diagnosis smoke
    dataset because most diagnosis labels appear only once. For diagnosis,
    either use your own small CSV where each diagnosis label appears at least
    twice, or use the normalized diagnosis dataset already in the repo.

```powershell
python python_pipeline/train_classifier.py `
   --data python_pipeline/data/normalized_diagnosis_dataset.csv `
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

    - `python_pipeline/data/normalized_diagnosis_dataset.csv`

```powershell
python python_pipeline/train_classifier.py `
   --data python_pipeline/data/normalized_diagnosis_dataset.csv `
   --label-col diagnosis_label `
   --task diagnosis `
   --text-cols symptoms_text transcript_text `
   --categorical-cols body_location prior_medications language source `
   --numeric-cols duration_hours duration_days `
   --model both `
   --verbose `
   --output-dir python_pipeline/outputs/classifier_diagnosis_run1
```

1. **Train from multiple diagnosis files at once**

```powershell
python python_pipeline/train_classifier.py `
   --data `
      python_pipeline/data/gretel_symptom_to_diagnosis.csv `
      python_pipeline/data/Symptom2Disease.csv `
      python_pipeline/data/normalized_diagnosis_dataset.csv `
   --label-col diagnosis_label `
   --task diagnosis `
   --text-cols symptoms_text transcript_text `
   --categorical-cols body_location prior_medications language source `
   --numeric-cols duration_hours duration_days `
   --model both `
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

1. **Optional LR ONNX export**

```powershell
python python_pipeline/train_classifier.py `
   --data python_pipeline/data/normalized_diagnosis_dataset.csv `
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
   `GridSearchCV`; `--verbose` also enables visible tuning progress.
7. Reports accuracy, macro-F1, weighted-F1, confusion matrix, classification
   report, LR coefficients, and XGBoost SHAP top features.
8. Saves `best_model.joblib`, per-model metrics, label metadata, and run summary
   under the requested output directory.

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

## Whisper Fine-Tuning Path

DoReCo annotations exist locally under the sibling `../Data` folder, but the
current local folder contains annotation files only (`.eaf`, `.TextGrid`, `.xml`,
metadata CSV). No `.wav`, `.flac`, `.mp3`, `.m4a`, `.ogg`, or `.opus` audio files
were found in the current scan. Whisper fine-tuning cannot run from annotations
alone; it needs waveform audio aligned to transcripts.

The repo now includes `python_pipeline/02_finetune_whisper.py`, updated for the
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
python -m pip install -r python_pipeline/requirements-whisper.txt
```

Required manifest format after audio is restored:

```csv
audio,text,language,speaker_id,source_id,duration_sec
C:\path\to\clip_0001.wav,"ngayi bin sick today",gurindji-kriol,FVD,FM11_32_1,3.2
C:\path\to\clip_0002.wav,"I have chest pain",english,FVD,FM11_32_1,2.8
```

Validate only:

```powershell
python python_pipeline/02_finetune_whisper.py ^
  --mode validate ^
  --data-root "C:\Users\OneGa\iCloudDrive\Documents\Major\COS70008\Demo\Data" ^
  --manifest python_pipeline/data/gurindji_whisper_manifest.csv
```

Train after audio exists and manifest validates:

```powershell
python python_pipeline/02_finetune_whisper.py ^
  --mode train ^
  --data-root "C:\Users\OneGa\iCloudDrive\Documents\Major\COS70008\Demo\Data" ^
  --manifest python_pipeline/data/gurindji_whisper_manifest.csv ^
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

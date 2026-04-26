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
the existing `AnalysisService` contract.

Recommended datasets:

- Gretel `symptom_to_diagnosis`
- Symptom2Disease
- Healthcare Symptoms-Disease Classification Dataset
- BI55/MedText for supplementary severity examples

Keep raw downloads under `python_pipeline/data/`, which is ignored by Git.
Future scripts should prepare a common `{text, disease, source, synthetic_flag}`
schema, train TF-IDF + Logistic Regression, evaluate F1, and optionally export a
small runtime JSON artifact for Flutter.

## Whisper Fine-Tuning Path

DoReCo annotations exist locally, but PARADISEC audio is not present locally.
Fine-tuning Whisper is therefore future work until audio access and permission
are confirmed.

Expected later steps:

1. Obtain permission for PARADISEC audio and any derived model redistribution.
2. Build audio/transcript manifests from DoReCo/PARADISEC.
3. Evaluate Whisper on held-out Gurindji/Gurindji Kriol/code-switching samples.
4. Fine-tune only if the baseline and permissions justify it.
5. Export offline artifacts only if redistribution is allowed.

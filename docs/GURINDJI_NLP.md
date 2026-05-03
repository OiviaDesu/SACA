# Gurindji NLP and Dataset Strategy

SACA uses Gurindji NLP as a prototype support layer. It is not clinically
validated, and Gurindji medical wording must be reviewed by fluent speakers and
community stakeholders before real use.

## Current App Strategy

The app keeps analysis language-independent. User input is normalized into
canonical English symptom and body-area tokens before it reaches the analysis
service.

- Text and visual input are the safest Gurindji paths for v1.
- English voice input uses offline Whisper where the platform supports it.
- Gurindji voice input remains placeholder-only because there is no available
  Gurindji medical speech dataset for this project.
- Unknown Gurindji text is preserved rather than guessed.
- Safety rules run after normalization and can override analysis with emergency
  guidance.

## Minimum Viable Dataset Stack

Detailed dataset matrix lives in [Dataset research summary](DATASET_RESEARCH_SUMMARY.md).

Medical NLP datasets for prototype classification:

- Gretel `symptom_to_diagnosis`: primary natural-language symptom to diagnosis
  baseline.
- Symptom2Disease: backup natural-language symptom dataset.
- Healthcare Symptoms-Disease Classification Dataset: larger structured symptom
  to disease dataset for keyword/classifier experiments.
- Disease and Symptoms Dataset: broad one-hot symptom/disease lookup, not primary
  natural-language training data.
- BI55/MedText: supplementary severity variation examples, not real triage labels.
- MIMIC-IV-ED / MIETIC / MIMIC-IV-Ext CDS: best later triage sources, but require
  PhysioNet credentialing and are not Week 6 dependencies.

Gurindji language resources:

- Ngumpin Gurindji Dictionary: primary glossary source for body, symptom, pain,
  and UI-support terms.
- WOLD Gurindji Vocabulary: structured cross-reference for core vocabulary.
- Pilot Gurindji Online Course: pronunciation and phrase reference where access
  conditions allow use.
- AIATSIS dictionary and published grammar: optional reference if access and
  permissions allow.

Speech resources:

- Whisper: practical offline English ASR engine for the current prototype.
- DoReCo Gurindji and PARADISEC GK1: future research sources for Gurindji
  speech only after access and permission are confirmed.
- Local DoReCo Gurindji annotation files are available outside the repo at the
  sibling `../Data` folder in the current development workspace. Current scan
  found annotation files but no audio files. They support corpus and glossary
  research, not ASR fine-tuning by themselves.
- Common Voice English: optional English ASR test/augmentation resource. It does
  not contain Gurindji or Australian Indigenous languages.

Triage safety resources:

- Australasian Triage Scale descriptors, ACEM ATS implementation guidance, and
  Emergency Triage Education Kit quick reference: rule sources for conservative
  severity and emergency escalation.
- CARPA Standard Treatment Manual: optional remote NT clinical context if access
  allows.

## Fine-Tuning Path

Fine-tuning Whisper is future work, not a v1 app dependency.

1. Confirm access and permission for DoReCo/PARADISEC audio and annotations.
2. Keep corpus data outside Git; store only scripts, notes, and permitted small
   derived artifacts.
3. Build audio/transcript alignment and train/validation splits.
4. Fine-tune Whisper small/base and evaluate with WER/CER.
5. Test code-switching behavior because Gurindji, Gurindji Kriol, and English
   mixing is expected.
6. Export an offline model only if redistribution is permitted.
7. Swap the model behind `SpeechInputService`/`WhisperService` without changing
   UI or analysis contracts.

## Local DoReCo Workflow

Use the extractor to inspect local DoReCo annotations without committing source
or generated corpus outputs:

```powershell
python python_pipeline/01_extract_doreco_gurindji.py
```

The default input is the sibling `../Data` folder. Outputs are written under
`python_pipeline/outputs/doreco_gurindji/`, which is ignored by Git.

The extractor writes:

- cleaned word rows with text and English translation fields;
- word frequency summaries;
- foreign-material/code-switching rows;
- candidate health/body/pain terms matched against the curated app lexicon.

Only manually reviewed, small glossary changes should be promoted into tracked
app assets.

## ML Path

The current `MockAnalysisService` remains deterministic. A future classifier
should stay behind the existing `AnalysisService` contract.

- Train diagnosis experiments from A1/A2/A3.
- Use BI55/MedText only as supplementary severity evidence.
- Derive severity from ATS/ETEK rules instead of pretending the public symptom
  datasets contain clinical triage labels.
- Report diagnosis F1-score separately from safety-rule coverage.
- Keep the safety layer conservative and independent from model confidence.
- Treat language input as multilingual and code-switching by default:
  Gurindji, English, and Gurindji-Kriol mixed language are all expected.
- Prefer character TF-IDF n-grams over word-only tokenization for small mixed
  Gurindji corpora because spelling variation and switching inside a single
  utterance are common.
- Keep `language` as explicit structured feature with normalized values
  `english`, `gurindji`, `gurindji-kriol`, `unknown`.
- Preserve original text and Whisper transcript text side by side during data
  prep, then merge into one classifier text field.

Local classifier script now exists at `python_pipeline/train_classifier.py`.
It trains:

- baseline `LogisticRegression` with class balancing;
- main `XGBClassifier` with `GridSearchCV` on macro-F1;
- structured categorical + numeric follow-up features;
- SHAP top features for XGBoost;
- mobile-oriented export artifacts and ONNX best-effort path for Logistic
  Regression.

Current diagnosis-model deployment note:

- `quick xgboost` remains the strongest practical winner on the expanded
  `multi` diagnosis dataset.
- A local Dart export experiment now exists for that winner.
- Exact parity has been verified with the **JSON tree bundle runtime** path.
- Direct `m2cgen` scorer export is close but not exact yet, so it should still
  be treated as experimental rather than default-safe app runtime behavior.

## Data Governance

Do not commit Hugging Face, Kaggle, DoReCo, PARADISEC, AIATSIS, or course audio
datasets into this repository. Keep the repo lightweight and avoid redistributing
community or restricted data.

Known constraints:

- Public medical datasets are synthetic or curated, not clinical deployment
  evidence.
- There is no public Gurindji medical speech dataset.
- There is no directly usable public ATS-labelled Australian triage dataset in
  this repo workflow; public severity must be derived conservatively from
  ATS/ETEK rules unless credentialed PhysioNet access is added later.
- The local DoReCo data contains annotations only; PARADISEC audio is not
  present locally.
- Gurindji dictionary and corpus sources require careful attribution, cultural
  respect, and community review before medical wording is presented as correct.
- DoReCo notes that Gurindji language mixing is common in the dataset.
- Gurindji medical vocabulary in this project is curated prototype wording, not
  community-validated clinical terminology.

## References

- DoReCo Gurindji: https://doreco.huma-num.fr/languages/guri1247
- PARADISEC GK1 collection: https://catalog.paradisec.org.au/collections/GK1
- Ngumpin Gurindji Dictionary: https://ngumpin.org.au/gurindji/dictionary/az/
- WOLD Gurindji Vocabulary: https://wold.clld.org/vocabulary/31
- Whisper: https://github.com/openai/whisper

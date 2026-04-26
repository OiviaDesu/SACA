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

Medical NLP datasets for prototype classification:

- Gretel `symptom_to_diagnosis`: primary natural-language symptom to diagnosis
  baseline.
- Symptom2Disease: backup natural-language symptom dataset.
- Healthcare Symptoms-Disease Classification Dataset: larger structured symptom
  to disease dataset for keyword/classifier experiments.
- BI55/MedText: supplementary severity variation examples.

Gurindji language resources:

- Ngumpin Gurindji Dictionary: primary glossary source for body, symptom, pain,
  and UI-support terms.
- WOLD Gurindji Vocabulary: structured cross-reference for core vocabulary.
- Pilot Gurindji Online Course: pronunciation and phrase reference where access
  conditions allow use.

Speech resources:

- Whisper: practical offline English ASR engine for the current prototype.
- DoReCo Gurindji and PARADISEC GK1: future research sources for Gurindji
  speech only after access and permission are confirmed.

Triage safety resources:

- Australasian Triage Scale descriptors and Emergency Triage Education Kit
  quick reference: rule source for conservative severity and emergency
  escalation.

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

## ML Path

The current `MockAnalysisService` remains deterministic. A future classifier
should stay behind the existing `AnalysisService` contract.

- Train diagnosis experiments from A1/A2/A3.
- Use BI55/MedText only as supplementary severity evidence.
- Derive severity from ATS/ETEK rules instead of pretending the public symptom
  datasets contain clinical triage labels.
- Report diagnosis F1-score separately from safety-rule coverage.
- Keep the safety layer conservative and independent from model confidence.

## Data Governance

Do not commit Hugging Face, Kaggle, DoReCo, PARADISEC, AIATSIS, or course audio
datasets into this repository. Keep the repo lightweight and avoid redistributing
community or restricted data.

Known constraints:

- Public medical datasets are synthetic or curated, not clinical deployment
  evidence.
- There is no public Gurindji medical speech dataset.
- Gurindji dictionary and corpus sources require careful attribution and cultural
  respect.
- DoReCo notes that Gurindji language mixing is common in the dataset.

## References

- DoReCo Gurindji: https://doreco.huma-num.fr/languages/guri1247
- PARADISEC GK1 collection: https://catalog.paradisec.org.au/collections/GK1
- Ngumpin Gurindji Dictionary: https://ngumpin.org.au/gurindji/dictionary/az/
- WOLD Gurindji Vocabulary: https://wold.clld.org/vocabulary/31
- Whisper: https://github.com/openai/whisper

# SACA Dataset Research Summary

Updated from local research report dated 26 March 2026. This file keeps only repo-relevant decisions for current development.

## Decision Summary

### Use now

- **Gretel `symptom_to_diagnosis`**
  https://huggingface.co/datasets/gretelai/symptom_to_diagnosis
  Primary natural-language symptom ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ diagnosis dataset.

- **Symptom2Disease**
  https://www.kaggle.com/datasets/niyarrbarman/symptom2disease
  Backup/augmentation dataset for diagnosis classification.

- **Healthcare SymptomsÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Å“Disease Classification Dataset**
  https://www.kaggle.com/datasets/kundanbedmutha/healthcare-symptomsdisease-classification-dataset
  Large structured synthetic symptom dataset for tabular experiments.

- **Disease and Symptoms Dataset**
  https://www.kaggle.com/datasets/dhivyeshrk/diseases-and-symptoms-dataset
  Broad lookup/reference resource, not primary NLP training data.

- **BI55/MedText**
  https://huggingface.co/datasets/BI55/MedText
  Supplementary severity-style examples. Do not treat as real clinical triage labels.

- **Ngumpin Gurindji Dictionary**
  https://ngumpin.org.au/gurindji/dictionary/az/
  Primary Gurindji glossary source for UI/body/pain/symptom wording.

- **WOLD Gurindji Vocabulary**
  https://wold.clld.org/vocabulary/31
  Structured cross-reference vocabulary source.

- **Pilot Gurindji Online Course**
  https://catalog.paradisec.org.au/repository/LC01
  Pronunciation and phrase reference only.

- **Whisper**
  https://github.com/openai/whisper
  Practical English ASR baseline and multilingual fine-tuning base checkpoint.

- **ATS / ETEK / ACEM triage guidance**
  https://www.safetyandquality.gov.au/sites/default/files/2024-04/emergency_triage_education_kit_-_australasian_triage_scale_-_descriptors_for_categories.pdf
  https://www.health.gov.au/sites/default/files/2022-12/triage-quick-reference-guide-emergency-triage-education-kit.pdf
  https://acem.org.au/getmedia/51dc74f7-9ff0-42ce-872a-0437f3db640a/G24_04_Guidelines_on_Implementation_of_ATS_Jul-16.aspx
  Primary rule source for safety layer and severity mapping.

### Maybe later

- **MIMIC-IV-ED** ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â real triage labels, but credentialed access.
  https://physionet.org/content/mimic-iv-ed/
- **MIETIC** ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â triage instruction corpus, but credentialed access.
  https://physionet.org/content/mietic/
- **MIMIC-IV-Ext CDS** ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â rich triage/HPI set, but credentialed access.
  https://physionet.org/content/mimic-iv-ext-cds/
- **DoReCo Gurindji / PARADISEC GK1** ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â useful only when audio access and permissions are confirmed.
  https://doreco.huma-num.fr/languages/guri1247
  https://catalog.paradisec.org.au/collections/GK1
- **CARPA manual** ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â strong remote NT context if access confirmed.
  https://remotephcmanuals.com.au/manuals.html

### Reject for direct training

- **OpenSLR MUCS code-switching** ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â wrong languages; methodology reference only.
  http://www.openslr.org/103
- **Google-UWA Aboriginal English dataset** ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â not released.
  https://blog.google/intl/en-au/company-news/technology/a-partnership-to-improve-speech-technology-for-first-nations-voices/

## Minimum Viable Dataset Stack

### Medical classification

1. Gretel `symptom_to_diagnosis`
2. Symptom2Disease
3. Healthcare SymptomsÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Å“Disease Classification Dataset
4. Optional BI55/MedText severity-style examples
5. Local CSV/JSON rows from SACA data collection pipeline

### Gurindji language support

1. Ngumpin dictionary
2. WOLD vocabulary
3. Pilot Gurindji Online Course
4. Local DoReCo annotations for glossary research only

### Speech

1. Offline Whisper for English ASR
2. Fine-tuned multilingual Whisper only after audio exists
3. Gurindji voice remains future work unless community-approved audio is available

### Triage / safety

1. ATS descriptors
2. ETEK quick reference
3. ACEM ATS implementation guidance
4. Optional CARPA for remote NT context

## Current project verdict

### Enough for prototype

Yes.

Current public resources are enough for:

- symptom ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ diagnosis classifier prototype;
- ATS-inspired severity rules;
- Gurindji glossary-backed UI;
- English offline ASR;
- mixed Gurindji / English / Gurindji-Kriol text experiments.

### Not enough for clinical deployment

Also yes.

Current gaps:

- no public Gurindji medical speech dataset;
- no real ATS-labelled public dataset available without credentialing;
- most easy-access medical data is synthetic or curated, not deployment evidence;
- Gurindji medical terminology is not community-validated in this repo.

## Repo-specific implications

### Classifier

- Keep diagnosis modeling and severity logic separate.
- Train diagnosis on public symptom datasets.
- Derive severity conservatively from ATS/ETEK rules.
- Report classifier metrics separately from safety-rule behavior.

### Whisper

- Local `../Data` currently has DoReCo annotations only.
- No audio files found in current scan.
- `python_pipeline/training/finetune_whisper.py` stays manifest-first and blocked until waveform audio exists.
- Do not force English language token during Gurindji mixed fine-tuning.

### UX / product scope

- English voice input: supported path.
- Gurindji / Gurindji-Kriol voice input: future work.
- Gurindji text + icon + structured follow-up: safest current multilingual path.

## Recommended next actions

1. Download A1/A2/A3 and keep raw data under `python_pipeline/data/raw/`.
2. Encode ATS/ETEK descriptors into structured rule tables.
3. Curate small Gurindji glossary from Ngumpin + WOLD.
4. Keep English ASR shipping path on Whisper runtime already in app.
5. If needed, start PhysioNet credentialing for later triage experiments.

# SACA Dataset Research Summary

Last reviewed: 2026-05-18.

This document summarizes datasets and reference sources used or considered for
the SACA research pipeline. It is a provenance and planning document, not proof
of clinical safety.

## Runtime Dataset Position

- The Flutter app bundles curated lexicon data and model artifacts only.
- Full training datasets, raw downloads, and HPC outputs stay outside normal Git
  history.
- Kaggle and PhysioNet sources may require login, credentialing, or acceptance
  of source-specific terms before download.
- Gurindji language material requires cultural respect, careful attribution, and
  community/native-speaker review before clinical or public use.

## Medical and Symptom Sources

| Source | Role in SACA | Link and access note |
| --- | --- | --- |
| Gretel symptom-to-diagnosis | Prototype symptom text to diagnosis examples | https://huggingface.co/datasets/gretelai/symptom_to_diagnosis |
| Symptom2Disease | Diagnosis classification training source | https://www.kaggle.com/datasets/niyarrbarman/symptom2disease; Kaggle access may require login |
| Healthcare Symptoms-Disease Classification Dataset | Structured symptom/disease examples | https://www.kaggle.com/datasets/kundanbedmutha/healthcare-symptomsdisease-classification-dataset; Kaggle access may require login |
| Disease and Symptoms Dataset | Broad lookup/reference source, not primary clinical evidence | https://www.kaggle.com/datasets/dhivyeshrk/diseases-and-symptoms-dataset; Kaggle access may require login |
| MedText | Medical text research reference | https://huggingface.co/datasets/BI55/MedText |
| MIMIC-IV-ED | Potential future ED/triage research source | https://physionet.org/content/mimic-iv-ed/; credentialed PhysioNet access may be required |
| MIETIC | Potential future triage/ED research source | https://physionet.org/content/mietic/; credentialed PhysioNet access may be required |
| MIMIC-IV-Ext-CDS | Potential future clinical decision-support research source | https://physionet.org/content/mimic-iv-ext-cds/; credentialed PhysioNet access may be required |

## Gurindji and Language Sources

| Source | Role in SACA | Link and access note |
| --- | --- | --- |
| Ngumpin Gurindji Dictionary | Curated vocabulary reference | https://ngumpin.org.au/gurindji/dictionary/az/ |
| WOLD Gurindji Vocabulary | Cross-linguistic vocabulary reference | https://wold.clld.org/vocabulary/31 |
| DoReCo Gurindji | Corpus annotation research reference | https://doreco.huma-num.fr/languages/guri1247 |
| PARADISEC GK1 | Gurindji collection reference | https://catalog.paradisec.org.au/collections/GK1 |
| PARADISEC LC01 | Related language/corpus reference | https://catalog.paradisec.org.au/repository/LC01 |
| OpenSLR 103 | Speech-resource reference | http://www.openslr.org/103 |
| Google First Nations speech note | Context for First Nations speech technology work | https://blog.google/intl/en-au/company-news/technology/a-partnership-to-improve-speech-technology-for-first-nations-voices/ |

## Clinical Safety References

These references inform conservative prototype safety wording and severity
policy. They do not validate SACA as a clinical system.

- Australasian Triage Scale descriptors:
  https://www.safetyandquality.gov.au/sites/default/files/2024-04/emergency_triage_education_kit_-_australasian_triage_scale_-_descriptors_for_categories.pdf
- Emergency Triage Education Kit quick reference:
  https://www.health.gov.au/sites/default/files/2022-12/triage-quick-reference-guide-emergency-triage-education-kit.pdf
- ACEM ATS implementation guideline:
  https://acem.org.au/getmedia/51dc74f7-9ff0-42ce-872a-0437f3db640a/G24_04_Guidelines_on_Implementation_of_ATS_Jul-16.aspx
- Remote Primary Health Care Manuals:
  https://remotephcmanuals.com.au/manuals.html

## Minimum Viable Dataset Stack

The current practical stack is:

1. English symptom/disease text from public prototype datasets.
2. Curated Gurindji vocabulary and phrase support from project resources.
3. Conservative clinical safety rules inspired by public triage references.
4. HPC-generated classifier artifacts documented in `HPC_TRAINING_OUTPUTS.md`.

This stack is suitable for demo and research iteration only. It is not clinical
validation and must not be presented as real-world diagnostic evidence.

## Link Validation Notes

Links in this document were checked on 2026-05-18. Public documentation links
were reachable. Kaggle pages were reachable but may require account access for
downloads. PhysioNet pages were reachable but may require credentialed access
for data.

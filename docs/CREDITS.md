# Credits and Acknowledgements

Last reviewed: 2026-05-18.

## Acknowledgement of Country

We respectfully acknowledge the Wurundjeri People of the Kulin Nation, who
are the Traditional Owners of the land on which Swinburne’s Australian
campuses are located in Melbourne’s east and outer-east, and pay our
respect to their Elders past, present and emerging.
We are honoured to recognise our connection to Wurundjeri Country, history,
culture, and spirituality through these locations, and strive to ensure that we
operate in a manner that respects and honours the Elders and Ancestors of
these lands.
We also respectfully acknowledge Swinburne’s Aboriginal and Torres Strait
Islander staff, students, alumni, partners and visitors.
We also acknowledge and respect the Traditional Owners of lands across
Australia, their Elders, Ancestors, cultures, and heritage, and recognise the
continuing sovereignties of all Aboriginal and Torres Strait Islander Nations.

## Project Context

SACA is a research and demo prototype for offline triage-support workflows. It
is not a clinical decision system, medical device, or substitute for clinician
judgement. Any clinical, language, or community-facing use requires expert,
clinical, and community review.

## App and Runtime Technology

- Flutter (https://flutter.dev) and Dart (https://dart.dev) provide the
  cross-platform application runtime.
- `record`, `path_provider`, `shared_preferences`, `http`, `url_launcher`,
  `window_manager`, `gap`, and `cupertino_icons` support app runtime features.
- `liquid_glass_widgets` provides the Flutter glass rendering dependency used
  by Glass (Preview): https://github.com/sdegenaar/liquid_glass_widgets
  SACA adds its own contrast, accessibility, and theme rules.
- `whisper_kit` is vendored under `third_party/whisper_kit/` and is credited to
  CodeSagePath under its MIT license: https://github.com/CodeSagePath/whisper_kit
- `sherpa-onnx` supports desktop/web-backend STT experiments when model assets
  and runtime dependencies are installed: https://github.com/k2-fsa/sherpa-onnx

## Research and ML Tooling

- Python research workflows use pandas, NumPy, scikit-learn
  (https://scikit-learn.org/), XGBoost (https://xgboost.readthedocs.io/), SHAP,
  joblib, matplotlib, seaborn, ONNX-related tooling, PyTorch, Hugging Face
  Transformers/Datasets, Evaluate, JiWER, soundfile, and librosa.
- Whisper-family speech experiments reference OpenAI Whisper:
  https://github.com/openai/whisper
- The web demo server may use FFmpeg locally to decode browser audio before STT.

## Dataset and Language Resources

SACA research docs reference public or account-gated sources. Links were checked
on 2026-05-18; Kaggle and PhysioNet sources may require accounts, credentialed
access, or acceptance of source-specific terms.

- Gretel symptom-to-diagnosis dataset:
  https://huggingface.co/datasets/gretelai/symptom_to_diagnosis
- Symptom2Disease dataset:
  https://www.kaggle.com/datasets/niyarrbarman/symptom2disease
- Healthcare Symptoms-Disease Classification Dataset:
  https://www.kaggle.com/datasets/kundanbedmutha/healthcare-symptomsdisease-classification-dataset
- Disease and Symptoms Dataset:
  https://www.kaggle.com/datasets/dhivyeshrk/diseases-and-symptoms-dataset
- MedText:
  https://huggingface.co/datasets/BI55/MedText
- Ngumpin Gurindji Dictionary:
  https://ngumpin.org.au/gurindji/dictionary/az/
- WOLD Gurindji Vocabulary:
  https://wold.clld.org/vocabulary/31
- DoReCo Gurindji:
  https://doreco.huma-num.fr/languages/guri1247
- PARADISEC GK1 collection:
  https://catalog.paradisec.org.au/collections/GK1
- PARADISEC LC01 repository entry:
  https://catalog.paradisec.org.au/repository/LC01
- OpenSLR 103:
  http://www.openslr.org/103
- Google Australia First Nations speech technology partnership note:
  https://blog.google/intl/en-au/company-news/technology/a-partnership-to-improve-speech-technology-for-first-nations-voices/

## Clinical Reference Material

Clinical and triage references are used only to guide conservative prototype
safety wording and severity policy. They do not validate SACA clinically.

- Australasian Triage Scale descriptors:
  https://www.safetyandquality.gov.au/sites/default/files/2024-04/emergency_triage_education_kit_-_australasian_triage_scale_-_descriptors_for_categories.pdf
- Emergency Triage Education Kit quick reference:
  https://www.health.gov.au/sites/default/files/2022-12/triage-quick-reference-guide-emergency-triage-education-kit.pdf
- ACEM ATS implementation guideline:
  https://acem.org.au/getmedia/51dc74f7-9ff0-42ce-872a-0437f3db640a/G24_04_Guidelines_on_Implementation_of_ATS_Jul-16.aspx
- Remote Primary Health Care Manuals:
  https://remotephcmanuals.com.au/manuals.html

## HPC Infrastructure

Training-output evidence and model-export inspection were produced on Swinburne
HPC infrastructure under the project paths documented in
`docs/HPC_TRAINING_OUTPUTS.md`.

- Swinburne Supercomputing documentation:
  https://supercomputing.swin.edu.au/docs/
- Access documentation:
  https://supercomputing.swin.edu.au/docs/1-getting_started/Access.html
- OzSTAR Slurm documentation:
  https://supercomputing.swin.edu.au/docs/2-ozstar/oz-slurm-create.html

This is an infrastructure/provenance acknowledgement only. It does not imply
that Swinburne provided the datasets, clinically approved the system, or endorses
the app.

## Link Validation Notes

- Public documentation and repository links were reachable during the 2026-05-18
  review.
- Kaggle links returned reachable pages but may require login for downloads.
- PhysioNet links were reachable but some datasets require credentialed access.
- `https://saca.mixcorp.org`, `127.0.0.1`, `<LAN_IP>`, and tunnel placeholder
  URLs are deployment examples, not guaranteed public documentation links.

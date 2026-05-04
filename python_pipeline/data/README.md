# Pipeline datasets

This folder separates dataset inputs by lifecycle:

- `raw/`: source datasets and lexicons kept close to their original shape.
- `processed/`: normalized or derived datasets used by training commands.
- `samples/`: small fixtures and smoke-test manifests safe for examples/tests.

Tracked data policy:

- CSV and XLSX files under `raw/`, `processed/`, and `samples/` can be committed when each file stays below GitHub's 100 MB limit.
- `raw/Final_Augmented_dataset_Diseases_and_Symptoms.csv` is intentionally ignored because it is larger than 100 MB.
- Generated model outputs, audits, caches, and binary artifacts stay under ignored `python_pipeline/outputs/` or `python_pipeline/artifacts/`.

Whisper fine-tuning still needs real audio files outside Git plus manifest paths pointing to those audio files.

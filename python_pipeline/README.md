# Python Research Pipeline

## Purpose

This folder contains research and data workflows that support SACA models and language resources.

## What Is Here

- Data ingestion, analysis, training, export, and validation scripts.
- Research datasets, processed samples, requirements, and HPC helpers.
- Workflows that prepare assets later consumed by the Flutter app.

## When To Edit This

- Edit this folder when improving datasets, training models, evaluating performance, or exporting artifacts.
- Keep app runtime logic in `lib/` and only promote reviewed outputs to `assets/`.

## Related Folders

- `assets/models/` stores model bundles used by the app.
- `assets/data/` stores runtime lexicon data.

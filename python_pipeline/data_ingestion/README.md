# Data Ingestion

## Purpose

This folder contains scripts that convert source material into pipeline-ready data.

## What Is Here

- Import and cleanup scripts for raw clinical or language datasets.
- Steps that prepare data before training or analysis.

## When To Edit This

- Edit this folder when a new data source is added or source formats change.
- Keep raw source files in `python_pipeline/data/raw/`.

## Related Folders

- `python_pipeline/data/processed/` stores normalized outputs.
- `python_pipeline/training/` consumes processed data.

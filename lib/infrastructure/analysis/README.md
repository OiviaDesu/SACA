# Analysis Infrastructure

## Purpose

This folder implements diagnosis analysis using local model assets and fallback services.

## What Is Here

- On-device diagnosis analysis service.
- Hybrid logistic regression and XGB runtime support.
- Result formatting and mock analysis for safe development paths.

## When To Edit This

- Edit this folder when model loading, prediction logic, or result formatting changes.
- Do not change clinical policy here unless it belongs in the domain layer.

## Related Folders

- `assets/models/` stores classifier bundles.
- `python_pipeline/export/` prepares model artifacts.

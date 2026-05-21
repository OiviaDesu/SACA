# Project Documentation

## Purpose

This folder stores cross-cutting documentation for SACA: architecture, model
assets, dataset provenance, platform setup, renderer policy, release checks, and
web demo operation.

## Acknowledgement of Country

The full Acknowledgement of Country is in the root `README.md` and
`docs/CREDITS.md`. It is intentionally repeated there so project viewers see it
before technical setup and before data/model provenance notes.

## What Is Here

- `ARCHITECTURE.md`: high-level Flutter/application architecture.
- `MODEL_ASSETS.md`: active, fallback, staged, and local-only model assets.
- `HPC_TRAINING_OUTPUTS.md`: Swinburne HPC training-output provenance.
- `HPC_REMOTE_INVENTORY.md`: live 2026-05-19 remote inventory of SACA HPC
  output folders and current Gurindji Whisper export artifacts.
- `DATASET_RESEARCH_SUMMARY.md`: dataset and reference-source audit.
- `GURINDJI_NLP.md`: Gurindji NLP constraints and research-source notes.
- `CREDITS.md`: acknowledgements, credits, and link-access notes.
- `web_lan_backend.md`: web demo and local backend instructions.

## When To Edit This

- Update these docs when app runtime behavior, model assets, dataset sources, or
  platform support changes.
- Keep folder-specific quick explanations in each folder's local `README.md`.

## Link Review

Markdown links were reviewed on 2026-05-18. Kaggle/PhysioNet links may require
accounts or access approval. Localhost, LAN IP, and tunnel URLs are examples.

## Related Folders

- Root `README.md` gives the project overview.
- `lib/` contains the Flutter app implementation.
- `python_pipeline/` contains research and export workflows.

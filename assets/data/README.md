# Runtime Data Assets

## Purpose

This folder stores small data files that the app reads at runtime.

## What Is Here

- Gurindji and English lexicon data.
- App-facing clinical vocabulary support data.
- Small JSON assets safe to bundle into Flutter builds.

## When To Edit This

- Edit this folder when runtime vocabulary or curated translation data changes.
- Keep research-only source data in `python_pipeline/data/`.

## Related Folders

- `lib/infrastructure/localization/` reads these assets.
- `python_pipeline/data/raw/` stores research and source datasets.

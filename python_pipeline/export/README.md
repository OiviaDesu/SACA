# Model Export

## Purpose

This folder contains scripts that convert trained research outputs into app-ready artifacts.

## What Is Here

- Export utilities for classifier bundles.
- Conversion or packaging logic used before assets move into `assets/models/`.

## When To Edit This

- Edit this folder when model artifact format or export validation changes.
- Verify Flutter runtime compatibility after changing exported assets.

## Related Folders

- `assets/models/` contains exported bundles consumed by the app.
- `lib/infrastructure/analysis/` loads exported model assets.

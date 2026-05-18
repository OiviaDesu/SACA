# Infrastructure Layer

## Purpose

This folder connects SACA's domain contracts to real assets, platforms, and external systems.

## What Is Here

- Diagnosis model runtimes.
- Speech-to-text adapters.
- Web backend clients and serializers.
- Asset-backed localization and platform/window helpers.

## When To Edit This

- Edit this folder when IO, platform behavior, model loading, or backend integration changes.
- Keep pure rules in `lib/domain/` and UI rendering in `lib/presentation/`.

## Related Folders

- `assets/` provides files loaded by infrastructure code.
- `tools/` contains helper servers and scripts.

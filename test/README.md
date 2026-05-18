# Flutter Tests

## Purpose

This folder contains automated tests for SACA's Flutter app behavior.

## What Is Here

- Controller, policy, localization, and widget tests.
- Regression coverage for flow navigation, theme behavior, result rendering, and app safety logic.

## When To Edit This

- Add tests whenever app behavior, UI state, localization, or domain policy changes.
- Keep tests deterministic and independent of large Git LFS model hydration.

## Related Folders

- `lib/` contains the app code under test.
- `.github/workflows/` runs these tests in CI.

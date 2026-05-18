# Android Gradle Support

## Purpose

This folder supports reproducible Android builds through the Gradle wrapper.

## What Is Here

- Wrapper files that let developers and CI use the expected Gradle version.
- Build tooling support, not app logic.

## When To Edit This

- Change this folder only when upgrading Android build tooling.
- Do not edit it for Flutter UI or clinical behavior.

## Related Folders

- `android/app/` contains the Android app module.
- `.github/workflows/` runs Android builds in CI.

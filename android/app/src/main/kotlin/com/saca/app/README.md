# Android Kotlin Entrypoint

## Purpose

This folder contains the Android native entrypoint for SACA.

## What Is Here

- Kotlin activity code that hosts the Flutter experience.
- Minimal Android-specific glue code.

## When To Edit This

- Edit this folder only when Android-native startup behavior changes.
- Keep product flow, UI, and diagnosis logic in Dart under `lib/`.

## Related Folders

- `lib/main.dart` starts the shared Flutter runtime.
- `android/app/src/main/` contains Android manifest and resources.

# Whisper Service Parts

## Purpose

This folder splits native Whisper runtime details into smaller platform-focused files.

## What Is Here

- Mobile runtime support.
- Windows runtime support.
- Whisper asset bundle helpers.

## When To Edit This

- Edit this folder when native Whisper loading or platform runtime details change.
- Keep high-level speech flow in `lib/infrastructure/speech/`.

## Related Folders

- `third_party/whisper_kit/` contains native plugin code.
- `assets/models/` stores model files.

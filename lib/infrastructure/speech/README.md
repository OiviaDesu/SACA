# Speech Infrastructure

## Purpose

This folder implements voice input and speech-to-text support for SACA.

## What Is Here

- Audio recording and speech input services.
- Whisper runtime adapters and stubs.
- Prewarm, model catalog, partial transcript, and mode policies.

## When To Edit This

- Edit this folder when voice capture, STT model selection, or speech runtime behavior changes.
- Keep web HTTP STT logic in `lib/infrastructure/web/`.

## Related Folders

- `assets/models/` stores speech model bundles.
- `third_party/whisper_kit/` provides native Whisper support.

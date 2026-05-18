# Sherpa ONNX Whisper Base

## Purpose

This folder stores a Sherpa-compatible Whisper base model bundle for speech-to-text experiments.

## What Is Here

- Model files loaded by native speech runtime experiments.
- Metadata needed by the speech service to locate the bundle.

## When To Edit This

- Update this folder when replacing the Sherpa ONNX speech model.
- Verify native speech startup after changing model files.

## Related Folders

- `lib/infrastructure/speech/` selects speech runtimes.
- `third_party/whisper_kit/` contains native Whisper integration code.

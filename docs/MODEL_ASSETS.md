# Model Assets

Large speech model files are not committed to this repository. They make the
Git history heavy and slow to clone, and they are easier to manage as local
runtime assets or release artifacts.

## Windows Offline STT

Windows uses `sherpa_onnx` with a Whisper-base ONNX model. Place these files
locally before running Windows offline speech-to-text:

```text
assets/models/sherpa-onnx-whisper-base/
  encoder.onnx
  decoder.onnx
  tokens.txt
```

The app copies these assets into the application support directory on first
runtime initialization.

## Git Policy

The following files are ignored:

```text
assets/models/sherpa-onnx-whisper-base/*.onnx
assets/models/sherpa-onnx-whisper-base/tokens.txt
```

Keep only the placeholder README in Git.

## CI Notes

`flutter analyze` and `flutter test` do not require model files.

Platform builds can compile without the ONNX model binaries because the model
directory placeholder is tracked. Runtime transcription on Windows requires the
local model files listed above.

# Model Assets

Large speech model files are not committed to this repository. They make the
Git history heavy and slow to clone, and they are easier to manage as local
runtime assets or release artifacts.

## Mobile English STT

Android and iOS use `whisper_kit`.

The current `whisper_kit` release in this repo does not expose `.en` model
enums directly. To prefer an English-only model, you can place this optional
local asset bundle:

```text
assets/models/whisper-base.en/
  ggml-base.en.bin
```

At runtime, the app copies that file into the WhisperKit model directory as
`ggml-base.bin` and initializes the English path through `WhisperModel.base`.
If that optional asset is not present, mobile English falls back to the current
multilingual `whisper-small` path.

Gurindji mobile STT remains a separate placeholder/custom-model path.

## Windows Offline STT

Windows uses `sherpa_onnx`.

Default local bundle:

```text
assets/models/sherpa-onnx-whisper-base/
  encoder.onnx
  decoder.onnx
  tokens.txt
```

Optional English-only bundle:

```text
assets/models/sherpa-onnx-whisper-base-en/
  encoder.onnx
  decoder.onnx
  tokens.txt
```

If the `-en` bundle exists, the app prefers it for English STT on Windows.
Otherwise it keeps using the current `sherpa-onnx-whisper-base` bundle with
`language: 'en'`.

The app copies the selected Windows bundle into the application support
directory on first runtime initialization.

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
directory placeholder is tracked. Runtime transcription requires whichever local
model files match the active platform path above.

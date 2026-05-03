# Model Assets

Large speech model files are not committed to this repository. They make the
Git history heavy and slow to clone, and they are easier to manage as local
runtime assets or release artifacts.

The same policy applies to generated classifier artifacts from
`python_pipeline/`, including `*.joblib`, `*.onnx`, and campaign run outputs.

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

## Release Distribution Guidance

If you publish builds or demos outside the repository, distribute model bundles
as separate release artifacts instead of committing them into Git history.

Recommended practice:

1. store model bundles in GitHub Releases, internal object storage, or another
  artifact store;
2. publish checksums alongside the download;
3. document the expected asset path and fallback behavior in release notes.

Without the required local model files, CI builds can still compile, but runtime
speech recognition will not be available until the model assets are installed.

## CI Notes

`flutter analyze` and `flutter test` do not require model files.

Platform builds can compile without the ONNX model binaries because the model
directory placeholder is tracked. Runtime transcription requires whichever local
model files match the active platform path above.

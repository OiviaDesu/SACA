# Model Assets

Large speech model files are not committed to this repository. They make the
Git history heavy and slow to clone, and they are easier to manage as local
runtime assets or release artifacts.

The same policy applies to generated classifier artifacts from
`python_pipeline/`, including `*.joblib`, `*.onnx`, and campaign run outputs.

## Experimental Classifier Dart Export

The current winning diagnosis artifact is still the local-only `quick xgboost`
run from the expanded `multi` campaign dataset. This repo now includes an
**experimental** Dart export path for that model:

```text
assets/models/classifier-xgb-quick/
  README.md
  bundle.json                  # local-only, generated
  export_summary.json          # local-only, generated

lib/infrastructure/analysis/generated_local/
  README.md
  xgb_quick_model.dart         # local-only, generated m2cgen scorer
```

Tracked source files that support this flow:

- `python_pipeline/export/export_xgb_to_dart.py`
- `python_pipeline/export/verify_xgb_dart_export.py`
- `python_pipeline/export/xgb_flutter_bundle.py`
- `lib/infrastructure/analysis/xgb_m2cgen_runtime.dart`

Current parity status on the real held-out test split rebuilt from the winning
campaign dataset:

- **JSON tree bundle runtime:** exact top-1 agreement with the original Python
  model and `max_abs_diff < 1e-6`
- **raw m2cgen-generated scorer path:** still slightly off (`~0.9986`
  top-1 agreement on the same split, with worst-case probability drift around
  `0.0568`)

Because of that result, treat the local `m2cgen` scorer as a useful export
experiment/debug artifact, **not** the default-safe deployment path yet. If you
need parity-first local runtime behavior, prefer the JSON tree bundle runtime.

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
assets/models/classifier-xgb-quick/**
lib/infrastructure/analysis/generated_local/**
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

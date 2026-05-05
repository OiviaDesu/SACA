# Model Assets

Large speech model files are stored with Git LFS. This keeps normal Git history
small while allowing demo/runtime model assets to be pulled into a checkout when
needed.

Generated classifier artifacts from `python_pipeline/`, including `*.joblib`
and campaign run outputs, remain local unless explicitly copied into
`assets/models/` as a runtime asset. Full training datasets remain outside Git
and Git LFS.

## Experimental Classifier Dart Export

The current winning diagnosis artifact is still the local-only `quick xgboost`
run from the expanded `multi` campaign dataset. This repo now includes an
**experimental** Dart export path for that model:

```text
assets/models/classifier-xgb-quick/
  README.md
  bundle.json                  # local-only, generated
  export_summary.json          # local-only, generated

assets/models/classifier-xgb-best/
  README.md
  bundle.json                  # staged best 24-class XGBoost export
  export_summary.json          # source + export metadata

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

Because of that result, treat any XGBoost Dart scorer as an export
experiment/debug artifact, **not** the default-safe deployment path yet. The
active Flutter diagnosis path remains the LR ONNX asset. The staged
`classifier-xgb-best` bundle must pass parity against the Python
`classifier_diagnosis_multi_xgb/best_model.joblib` before it becomes selectable
outside debug/experimental code.

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

Runtime model assets under `assets/models/` use Git LFS:

```text
assets/models/**/*.onnx
assets/models/**/*.bin
assets/models/**/tokens.txt
assets/models/classifier-xgb-quick/*.json
assets/models/classifier-xgb-best/*.json
```

The following generated/local files remain ignored:

```text
lib/infrastructure/analysis/generated_local/**
python_pipeline/data/**
python_pipeline/outputs/**
python_pipeline/artifacts/**
*.joblib
```

Keep raw/full datasets outside Git and Git LFS. The repository should only track
small samples, placeholders, and documentation needed to reproduce the pipeline.

## Release Distribution Guidance

If you publish builds or demos outside the repository, Git LFS can distribute the
runtime model files that are tracked in `assets/models/`. Use release artifacts
or object storage for full datasets and large training outputs.

Recommended practice:

1. keep runtime model bundles under `assets/models/` and track them with Git
  LFS;
2. store full datasets in GitHub Releases, internal object storage, or another
  artifact store;
3. publish checksums alongside external datasets or manually distributed model
  bundles;
4. document the expected asset path and fallback behavior in release notes.

Fresh clone setup:

```powershell
git lfs install
git lfs pull
```

Without the required local model files, CI builds can still compile, but runtime
speech recognition will not be available until the model assets are installed.

## CI Notes

`flutter analyze` and `flutter test` do not require model files.

Platform builds can compile without the ONNX model binaries because the model
directory placeholder is tracked. Runtime transcription requires whichever local
model files match the active platform path above.

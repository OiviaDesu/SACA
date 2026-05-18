# SACA - Smart Adaptive Clinical Assistant

SACA is a Flutter prototype for offline triage support in remote care contexts.
It collects symptoms through text, voice, or visual selection, asks structured
follow-up questions, and returns preliminary guidance with conservative safety
escalation.

SACA is not a diagnostic system and does not replace clinician judgement.

## Acknowledgement of Country

We respectfully acknowledge the Wurundjeri People of the Kulin Nation, who
are the Traditional Owners of the land on which Swinburne’s Australian
campuses are located in Melbourne’s east and outer-east, and pay our
respect to their Elders past, present and emerging.
We are honoured to recognise our connection to Wurundjeri Country, history,
culture, and spirituality through these locations, and strive to ensure that we
operate in a manner that respects and honours the Elders and Ancestors of
these lands.
We also respectfully acknowledge Swinburne’s Aboriginal and Torres Strait
Islander staff, students, alumni, partners and visitors.
We also acknowledge and respect the Traditional Owners of lands across
Australia, their Elders, Ancestors, cultures, and heritage, and recognise the
continuing sovereignties of all Aboriginal and Torres Strait Islander Nations.

## Safety & Disclaimer

SACA is a **research prototype**, not a clinical decision system. It can support
offline demos, workflow exploration, and model experimentation, but it must not
be treated as medical advice or a substitute for clinician judgement.

When in doubt, keep the safety layer conservative and escalate to human care.

## Prerequisites

- Flutter `3.3.0+` on the stable channel
- Android SDK / toolchain for mobile builds
- Windows desktop toolchain for `flutter build windows` when targeting Windows
- Python `3.9+` if you want to use `python_pipeline/`

## Current Features

- Adaptive Flutter UI for Windows desktop and Android mobile.
- English and Gurindji UI modes.
- Text, voice, and visual symptom input.
- Theme styles in Settings: Modern (Default), Glass (Preview), and Classic.
- Structured follow-up questionnaire.
- On-device diagnosis analysis through a bundled hybrid logistic-regression
  classifier, with XGBoost bundle fallback when the primary asset is unavailable.
- Emergency red-flag override through `SafetyRuleService`.
- Web demo diagnosis runs in the browser; web voice still needs the local
  backend `/stt` route.
- Native offline STT paths use local model assets when present.

## Quick Start

```bash
flutter pub get
git config core.hooksPath .githooks
flutter analyze
flutter test
flutter run
```

For Windows offline speech-to-text, add the local model assets first. See
[docs/MODEL_ASSETS.md](docs/MODEL_ASSETS.md).

If Android Gradle complains that `flutter.sdk` is missing, copy
`android/local.properties.example` to `android/local.properties` and update the
path for your machine.

## Platform Support

- Windows: desktop UI, local audio recording, `sherpa_onnx` offline Whisper
  runtime with local ONNX assets.
- Android: mobile UI, local audio recording, `whisper_kit` path.
- macOS: desktop UI and Flutter desktop runtime support.
- iOS: mobile UI and Flutter iOS runtime support.
- Web: local/LAN demo only. The browser frontend runs diagnosis locally with
  bundled Dart model assets and calls the backend only for STT; see
  [docs/web_lan_backend.md](docs/web_lan_backend.md).

## Platform Setup Notes

- **Windows:** `flutter build windows` compiles without local model binaries, but
  runtime offline speech still needs the Whisper ONNX assets described in
  `docs/MODEL_ASSETS.md`.
- **Android:** the app builds with the normal Flutter Android toolchain. Voice
  runtime behavior still depends on local/bundled model assets at runtime.
- **macOS/iOS:** build with the normal Flutter Apple toolchains. Voice runtime
  behavior still depends on local/bundled model assets at runtime.

## Model Assets

Large Whisper model files are intentionally not committed to Git. This keeps
the repository practical to clone and review.

Expected local path:

```text
assets/models/sherpa-onnx-whisper-base/
  encoder.onnx
  decoder.onnx
  tokens.txt
```

The placeholder README in that folder is tracked. The model files are ignored.

Classifier research artifacts from `python_pipeline/` such as `*.joblib`,
`*.onnx`, run outputs, and intermediate datasets are also kept out of Git by
default.

Current diagnosis runtime:

- Primary app classifier: `assets/models/saca-hybrid-logreg-v1/bundle.json`.
- Fallback app classifier: `assets/models/classifier-xgb-best/bundle.json`.
- Experimental/staged classifier: `assets/models/classifier-xgb-quick/`.

See [docs/MODEL_ASSETS.md](docs/MODEL_ASSETS.md) and
[docs/HPC_TRAINING_OUTPUTS.md](docs/HPC_TRAINING_OUTPUTS.md) for provenance.

## Project Structure

```text
lib/
  core/              shared errors and theme
  domain/            stable models and service contracts
  infrastructure/    analysis, localization, speech, and window adapters
  presentation/      adaptive UI, controllers, localization, screens, widgets
assets/
  data/              tracked Gurindji lexicon
  models/            local-only model assets
docs/                architecture, release, model, and dataset notes
python_pipeline/
  data_ingestion/    dataset download, extraction, audit, and normalization
  training/          classifier and Whisper training entry points
  export/            model export and Flutter bundle verification
  analysis/          dataset analysis and run aggregation
  hpc/               Slurm and HPC preparation scripts
  data/              raw, processed, and sample datasets
test/                unit and widget tests
```

## Python Research Pipeline

The Python training and HPC utilities live under `python_pipeline/`. They are
optional for app development, but important for dataset normalization,
classifier training, and Whisper fine-tuning research.

See [python_pipeline/docs/README_pipeline.md](python_pipeline/docs/README_pipeline.md) for
setup, Slurm usage, and artifact policy.

## Store Readiness

SACA targets Windows, macOS, iOS, and Android. Web is not a supported release
target.
Web remains a local/LAN demo target; see
[docs/web_lan_backend.md](docs/web_lan_backend.md) for the backend contract.

- [Store readiness checklist](docs/store_readiness.md) covers Apple App Store,
  Google Play, and Microsoft Store preparation guardrails.
- [Permissions and fallback matrix](docs/permissions_fallback_matrix.md) maps
  recoverable runtime failures to calm user recovery paths.

## Git Workflow

Use a branch-first workflow. The default branch is `main`.

Branch naming:

```text
<type>/<short-description>
```

Examples:

- `feat/add-voice-review`
- `fix/windows-stt-init`
- `docs/readme-cleanup`
- `chore/github-publication-prep`

## Conventional Commits

Use [Conventional Commits](https://www.conventionalcommits.org/) for commit
messages:

- `feat:` new user-facing functionality
- `fix:` bug fix
- `docs:` documentation-only change
- `test:` test-only change
- `refactor:` internal code restructuring without behavior change
- `chore:` maintenance, build, or tooling change

Examples:

```text
feat: add voice transcript review step
fix: handle missing windows model assets
docs: document local model setup
chore: prepare github publication workflow
```

## Required Checks Before Push

Every push must pass:

```bash
flutter analyze
flutter test
```

This repository includes `.githooks/pre-push` for the local quality gate.

Enable it after cloning:

```bash
git clone --config core.hooksPath=.githooks git@github.com:OiviaDesu/SACA.git
```

For an existing clone:

```bash
git config core.hooksPath .githooks
```

Release checks should also include platform builds when the required SDKs and
local model files are available:

```bash
flutter build windows
flutter build apk
```

## Renderer Policy

SACA uses Flutter's default renderer behavior per platform. Impeller is used
where Flutter supports it, but Skia fallback is not universal. In particular,
iOS does not support switching back to Skia, Android fallback is handled by
Flutter when Impeller is unsupported, and Windows/macOS keep Flutter defaults.
SACA Web is a demo target and keeps Flutter's web renderer behavior. See
[Renderer policy](docs/RENDERER_POLICY.md).

## Credits and Acknowledgements

SACA uses Flutter and Dart for the cross-platform app, Python/scikit-learn/
XGBoost tooling for research pipeline work, `liquid_glass_widgets` for the
Glass preview renderer, `whisper_kit`, `sherpa-onnx`, and Whisper-family assets
for speech experiments, and curated public/research datasets for prototype
training and evaluation.

Training-output inspection and model-export evidence were produced on Swinburne
HPC infrastructure, including OzSTAR/Ngarrgu Tindebeek paths documented in
[docs/HPC_TRAINING_OUTPUTS.md](docs/HPC_TRAINING_OUTPUTS.md). This is an
infrastructure/provenance acknowledgement only; it does not imply Swinburne
clinical approval, dataset ownership, or endorsement of SACA.

Full attribution, link-access notes, and data-governance constraints are in
[docs/CREDITS.md](docs/CREDITS.md) and
[docs/DATASET_RESEARCH_SUMMARY.md](docs/DATASET_RESEARCH_SUMMARY.md).

## CI

GitHub Actions run Flutter checks on pushes and pull requests. Windows and
Android build jobs are kept as release confidence checks; runtime speech
recognition on Windows still requires local model files.

## More Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Credits and acknowledgements](docs/CREDITS.md)
- [Gurindji NLP and dataset strategy](docs/GURINDJI_NLP.md)
- [Dataset research summary](docs/DATASET_RESEARCH_SUMMARY.md)
- [HPC training outputs](docs/HPC_TRAINING_OUTPUTS.md)
- [Model assets](docs/MODEL_ASSETS.md)
- [Release checklist](docs/RELEASE_CHECKLIST.md)
- [Contributing](CONTRIBUTING.md)
- [Security policy](SECURITY.md)
- [Code of conduct](CODE_OF_CONDUCT.md)
- [Changelog](CHANGELOG.md)

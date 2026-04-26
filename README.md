# SACA - Smart Adaptive Clinical Assistant

SACA is a Flutter prototype for offline triage support in remote care contexts.
It collects symptoms through text, voice, or visual selection, asks structured
follow-up questions, and returns preliminary guidance with conservative safety
escalation.

SACA is not a diagnostic system and does not replace clinician judgement.

## Current Features

- Adaptive Flutter UI for Windows desktop and Android mobile.
- English and Gurindji UI modes.
- Text, voice, and visual symptom input.
- Structured follow-up questionnaire.
- Placeholder local analysis via `MockAnalysisService`.
- Emergency red-flag override through `SafetyRuleService`.
- Windows offline STT through `sherpa_onnx` when local model files are present.

## Quick Start

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

For Windows offline speech-to-text, add the local model assets first. See
[docs/MODEL_ASSETS.md](docs/MODEL_ASSETS.md).

## Platform Support

- Windows: desktop UI, local audio recording, `sherpa_onnx` offline Whisper
  runtime with local ONNX assets.
- Android: mobile UI, local audio recording, `whisper_kit` path.
- Web: fallback/stub behavior for speech services.

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

## Project Structure

```text
lib/
  core/              shared errors and theme
  domain/            stable models and service contracts
  infrastructure/    adapters for analysis, localization, speech, window setup
  presentation/      adaptive UI, controller, localization, widgets
  services/          recorder and Whisper runtime services
assets/
  data/              tracked Gurindji lexicon
  models/            local-only model assets
docs/                architecture and setup notes
python_pipeline/     future ML/STT training pipeline notes
test/                unit and widget tests
```

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

## CI

GitHub Actions run Flutter checks on pushes and pull requests. Windows and
Android build jobs are kept as release confidence checks; runtime speech
recognition on Windows still requires local model files.

## More Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Model assets](docs/MODEL_ASSETS.md)
- [Contributing](CONTRIBUTING.md)

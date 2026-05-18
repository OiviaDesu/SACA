# Contributing to SACA

## Branch Strategy

- Default branch: `main`
- Create a dedicated branch for each change.
- Branch naming pattern: `<type>/<short-description>`

Examples:

- `feat/add-voice-review`
- `fix/windows-stt-init`
- `docs/readme-cleanup`
- `chore/github-publication-prep`

## Commit Format

Use [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` new functionality
- `fix:` bug fix
- `docs:` documentation update
- `test:` tests only
- `refactor:` behavior-preserving code restructuring
- `chore:` tooling, build, dependency, or maintenance work

## Local Development Workflow

For a fresh clone:

```bash
flutter pub get
git config core.hooksPath .githooks
flutter analyze
flutter test
```

If your change touches `python_pipeline/`, run the relevant Python validation as
well. For classifier pipeline work, that usually means installing the classifier
requirements and running the targeted pytest suite for the files you changed.

## Required Local Checks

Before pushing, run:

```bash
flutter analyze
flutter test
```

The tracked `.githooks/pre-push` hook enforces these checks.

Enable hooks when cloning:

```bash
git clone --config core.hooksPath=.githooks git@github.com:OiviaDesu/SACA.git
```

For an existing clone:

```bash
git config core.hooksPath .githooks
```

Before opening a PR, also run `git status --short` and make sure generated
artifacts, model binaries, and local HPC outputs are not accidentally staged.

## Release Checks

Before packaging or release demos, also run platform builds when the required
toolchains and local model assets are available:

```bash
flutter build windows
flutter build apk
```

Windows offline speech-to-text requires local Whisper ONNX assets. See
[docs/MODEL_ASSETS.md](docs/MODEL_ASSETS.md).

Use [docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md) when preparing a
release PR or a GitHub publication cleanup pass.

## Pull Request Rules

- Open PRs from a working branch into `main`.
- Keep each PR focused on one concern.
- Include a short summary, validation evidence, and known risks.
- Do not merge if `flutter analyze` or `flutter test` fails.
- Prefer squash merge for a clean main branch history.
- Follow the sections in `.github/PULL_REQUEST_TEMPLATE.md`: `Summary`,
  `Validation`, and `Risk / Notes`.

## Merge Strategy

- Prefer **squash merge** for feature and cleanup PRs.
- Keep repository hygiene, documentation, and refactors in separate PRs where
  practical so rollback stays easy.

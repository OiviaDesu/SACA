# Release Checklist

## Repository hygiene

- [ ] `git status` is clean or only contains intentional release changes.
- [ ] No generated model artifacts, logs, or local outputs are staged.
- [ ] No personal/local HPC overrides are staged.

## Validation

- [ ] `flutter analyze`
- [ ] `flutter test`
- [ ] Relevant Python tests for any `python_pipeline/` changes
- [ ] Optional platform builds checked if relevant:
  - [ ] `flutter build windows`
  - [ ] `flutter build apk`

## Docs

- [ ] `README.md` reflects current setup and known limitations.
- [ ] `CHANGELOG.md` updated.
- [ ] Model asset policy and release notes updated if runtime assets changed.

## Tagging / release prep

- [ ] Version reviewed in `pubspec.yaml` if needed.
- [ ] Commit messages follow Conventional Commits.
- [ ] Release branch / PR summary includes validation evidence and risks.
- [ ] Tags and release artifacts prepared if this is a formal release.

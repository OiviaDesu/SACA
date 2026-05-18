# Git Hooks

## Purpose

This folder stores optional local Git hooks for developer workflow checks.

## What Is Here

- Scripts that can run before commits or pushes when installed locally.
- Repository guardrails that are not part of the shipped app.

## When To Edit This

- Change this folder when local developer checks need to be improved.
- Keep CI as the source of truth for required validation.

## Related Folders

- `.github/workflows/` runs required checks in GitHub Actions.
- `tools/` contains reusable project scripts.

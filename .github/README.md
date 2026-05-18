# GitHub Automation

## Purpose

This folder explains how GitHub supports the SACA project outside the app runtime.

## What Is Here

- Issue templates for bug reports and project feedback.
- Workflow definitions that run Flutter analysis, tests, and platform builds.
- Repository automation used to keep the public project healthy.

## When To Edit This

- Change this folder when CI, issue reporting, or repository automation needs to change.
- Do not place app runtime logic here; Flutter code belongs under `lib/`.

## Related Folders

- `test/` contains the checks that CI runs.
- `android/`, `ios/`, `macos/`, and `windows/` are built by platform workflows.

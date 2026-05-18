# Android Source Sets

## Purpose

This folder separates Android code and configuration by build mode.

## What Is Here

- `main/` for production Android app metadata and entrypoint code.
- `debug/` for debug-only Android settings.
- `profile/` for profile-mode settings used during performance testing.

## When To Edit This

- Edit source sets when a permission or manifest value must differ by build mode.
- Avoid duplicating Flutter logic here.

## Related Folders

- `lib/` remains the shared app implementation.
- `android/app/` owns the Android module build.

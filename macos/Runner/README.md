# macOS Runner

## Purpose

This folder contains the native macOS wrapper for SACA.

## What Is Here

- App delegate and native runner files.
- Asset catalogs, entitlements, and app configuration.
- macOS-specific resources.

## When To Edit This

- Edit this folder for macOS permissions, entitlements, app identity, or native shell behavior.
- Keep Flutter UI and diagnosis flow in `lib/`.

## Related Folders

- `macos/RunnerTests/` contains macOS host tests.
- `lib/main.dart` starts the shared app.

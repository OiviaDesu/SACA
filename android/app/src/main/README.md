# Android Main Source Set

## Purpose

This folder contains Android configuration used in normal app builds.

## What Is Here

- The Android manifest.
- Native Kotlin host code for starting Flutter.
- Resource folders for launcher icons, values, and drawables.

## When To Edit This

- Change this folder for Android permissions, app name, launcher behavior, or platform resources.
- Keep platform-specific edits minimal so Flutter stays the main source of app behavior.

## Related Folders

- `android/app/src/debug/` and `android/app/src/profile/` contain build-mode overrides.
- `assets/branding/` stores source branding assets.

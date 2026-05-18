# Android App Shell

## Purpose

This folder contains the Android host project for the SACA Flutter app.

## What Is Here

- Gradle configuration for building Android APKs.
- Android manifest and app resources.
- Kotlin entrypoint code that launches Flutter.

## When To Edit This

- Edit this folder for Android permissions, icons, package metadata, or native integration.
- Do not place shared product logic here; shared app behavior belongs under `lib/`.

## Related Folders

- `lib/` contains the cross-platform Flutter app.
- `assets/` contains images, data, and ML model assets bundled into Android builds.

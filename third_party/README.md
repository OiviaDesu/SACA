# Third-Party Code

## Purpose

This folder contains vendored or adapted third-party components needed by SACA.

## What Is Here

- External native integration code kept inside the repository for build compatibility.
- Code that should be treated differently from first-party SACA app logic.

## When To Edit This

- Edit this folder carefully when upgrading or patching vendored dependencies.
- Keep local changes minimal and documented.

## Related Folders

- `lib/infrastructure/speech/` calls speech-related third-party integration.
- Platform folders build native plugin code.

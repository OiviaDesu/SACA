# Runtime Policy

## Purpose

This folder contains runtime capability decisions that affect performance and startup.

## What Is Here

- Policy for choosing acceleration or fallback behavior when runtime support differs by platform.

## When To Edit This

- Edit this folder when platform capability checks or runtime selection rules change.
- Keep concrete platform adapters in `lib/infrastructure/`.

## Related Folders

- `lib/infrastructure/speech/` and `lib/infrastructure/analysis/` use runtime decisions.

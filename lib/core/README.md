# Core Utilities

## Purpose

This folder contains small cross-cutting building blocks used by multiple layers.

## What Is Here

- App error types.
- Adaptive layout and window size helpers.
- Runtime acceleration policy.
- Shared theme primitives.

## When To Edit This

- Edit this folder only for reusable primitives that do not belong to one feature.
- Avoid placing business flow or UI screen logic here.

## Related Folders

- `lib/domain/` contains clinical and assessment rules.
- `lib/presentation/` consumes layout and theme helpers.

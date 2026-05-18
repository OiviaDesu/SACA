# Application Layer

## Purpose

This folder coordinates user actions into domain operations.

## What Is Here

- Use cases for starting an assessment, submitting symptoms, answering questions, handling voice transcripts, and running analysis.
- Result objects used by controllers to update UI state.

## When To Edit This

- Edit this folder when app flow orchestration changes.
- Keep pure clinical rules in `lib/domain/` and platform adapters in `lib/infrastructure/`.

## Related Folders

- `lib/presentation/controllers/` calls these use cases.
- `lib/domain/` defines the rules and data types they use.

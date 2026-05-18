# Core Errors

## Purpose

This folder defines shared error objects for predictable app failure handling.

## What Is Here

- App-level error types used across services and controllers.

## When To Edit This

- Add or change errors when multiple layers need to communicate a new failure type.
- Keep user-facing recovery copy in localization or UI folders.

## Related Folders

- `lib/presentation/` displays recoverable errors.
- `lib/infrastructure/` raises errors from adapters.

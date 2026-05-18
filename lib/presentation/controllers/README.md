# Presentation Controllers

## Purpose

This folder contains controllers that expose app state to Flutter widgets.

## What Is Here

- Flow controller logic for the assessment UI.
- State orchestration between user actions and application use cases.

## When To Edit This

- Edit this folder when UI state transitions change.
- Keep pure routing and clinical rules in `lib/domain/services/`.

## Related Folders

- `lib/application/assessment/` contains use cases called by controllers.
- `lib/presentation/screens/` renders controller state.

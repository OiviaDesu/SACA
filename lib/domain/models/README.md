# Domain Models

## Purpose

This folder defines the data structures SACA uses to describe an assessment.

## What Is Here

- Analysis request and result models.
- Assessment state, question, symptom, catalog, lexicon, and speech models.
- Shared enums for severity, language, and flow concepts.

## When To Edit This

- Edit this folder when app data shapes change.
- Update tests and serializers when changing public model fields.

## Related Folders

- `lib/infrastructure/web/` serializes some models for backend communication.
- `test/` verifies model-driven behavior.

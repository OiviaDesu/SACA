# Domain Layer

## Purpose

This folder holds SACA's core assessment language: models, services, and clinical policies.

## What Is Here

- Data models for symptoms, questions, results, speech, and flow state.
- Interfaces and pure policies for severity, safety, related symptoms, and step routing.
- No Flutter widget code.

## When To Edit This

- Edit this folder when the meaning of assessment data or clinical rules changes.
- Keep IO, assets, HTTP, and platform code in `lib/infrastructure/`.

## Related Folders

- `lib/application/` orchestrates domain rules.
- `lib/infrastructure/` implements domain service interfaces.

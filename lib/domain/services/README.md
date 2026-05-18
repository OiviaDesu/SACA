# Domain Services And Policies

## Purpose

This folder defines pure rules and service contracts for SACA.

## What Is Here

- Clinical risk, safety, severity, duration, and related symptom policies.
- Interfaces for analysis, speech input, lexicon lookup, and diagnosis classifiers.
- Flow step policy that decides what question comes next.

## When To Edit This

- Edit this folder when rules or service contracts change.
- Keep implementations that read files, call HTTP, or use native plugins in `lib/infrastructure/`.

## Related Folders

- `lib/application/assessment/` calls these rules.
- `lib/infrastructure/analysis/` implements classifier and analysis services.

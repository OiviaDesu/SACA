# Runtime Service Wiring

## Purpose

This folder chooses concrete services for each platform at app startup.

## What Is Here

- IO runtime wiring for desktop and mobile.
- Web runtime wiring for browser demo behavior.
- Conditional exports that keep platform-specific imports isolated.

## When To Edit This

- Edit this folder when a platform should use a different analysis, speech, or readiness service.
- Keep individual service implementations in their own infrastructure folders.

## Related Folders

- `lib/main.dart` starts the app with these services.
- `lib/infrastructure/web/` provides web-specific adapters.

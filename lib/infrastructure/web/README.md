# Web Infrastructure

## Purpose

This folder supports the Flutter web demo and its local backend integration.

## What Is Here

- HTTP serializers for backend API payloads.
- Optional HTTP analysis client for debug or fallback paths.
- Web speech input service that sends recorded audio to `/stt`.

## When To Edit This

- Edit this folder when web backend contracts, CORS-facing payloads, or browser speech behavior changes.
- Keep native speech and analysis adapters in other infrastructure folders.

## Related Folders

- `tools/` contains the local web demo server.
- `web/` contains static Flutter web host files.

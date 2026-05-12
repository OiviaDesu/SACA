# Platform Development

SACA stays as one Flutter codebase. Shared Dart code lives in `lib/`; native platform folders hold only platform scaffolding, permissions, signing, and build configuration.

## App IDs

- Android application ID: `com.saca.app`
- iOS bundle ID: `com.saca.app`
- macOS bundle ID: `com.saca.app`
- Windows remains a desktop app and does not use a mobile-style package ID unless packaged separately later.

## Code sharing

- UI, flow state, localization, settings, analysis, and most speech orchestration stay shared in `lib/`.
- Android and iOS use the mobile speech path through `whisper_kit`.
- Windows uses the desktop speech path through `sherpa_onnx`.
- macOS support should keep using shared UI and only add native permission/build configuration unless runtime testing proves a macOS-specific speech adapter is needed.

## Runtime privacy, acceleration, and fallback

- Voice capture is RAM-first when the platform recorder supports PCM streams; temp WAV files are only a short-lived fallback for STT backends that require file paths.
- Temp audio files must be deleted in `finally` blocks after transcription success or failure, and in cancel/dispose paths.
- Acceleration policy is GPU-preferred only when the backend is exposed and a probe/smoke test passes; otherwise SACA falls back to CPU or the platform default for the current session.
- STT acceleration is opportunistic: use platform/runtime defaults only when the plugin exposes a safe fallback. Do not force GPU, NNAPI, DirectML, Metal, or Vulkan without device validation.
- Windows/macOS desktop STT currently uses Sherpa ONNX CPU provider unless provider selection is exposed and tested.
- Diagnosis ML currently uses the CPU Dart/runtime path; if a GPU provider is added later, it must retry CPU on provider failure and match CPU output in parity tests.

## Feature fallback policy

- Microphone permission denied: keep the user in the current flow and offer text input.
- No speech or empty audio: show retry/manual-entry recovery copy, not a clinical result.
- STT unavailable or failed: keep any usable draft transcript; otherwise use text input and symptom selection.
- Non-speech cue unavailable: hide cue suggestions and keep normal symptom suggestions.
- Related symptoms without suggestions: show only `None` first and `Other Symptom`.
- Model/runtime missing: show a safe recovery error and avoid creating a clinical result from missing inference.
- Renderer issue: use platform build/run configuration fallback; do not add Dart runtime renderer switching.

## Renderer policy

- iOS and Android use Flutter default Impeller behavior.
- macOS may use Impeller only when explicitly enabled and smoke-tested.
- Windows keeps the default renderer; do not force Impeller by default because OpenGL Impeller has produced a blank SACA window in local testing.
- SACA does not support Web, so CanvasKit/Skwasm renderer policy is out of scope.

## iOS workflow

Run these from the repo root on macOS with Xcode installed:

```sh
flutter pub get
cd ios
pod install
cd ..
flutter build ios --debug
```

Open `ios/Runner.xcworkspace` in Xcode, set the signing team, then run on iPhone or iPad.

## macOS workflow

The macOS target is configured for macOS 13.0+ and universal release builds for Intel and Apple Silicon.

```sh
flutter pub get
cd macos
pod install
cd ..
flutter build macos --release
lipo -info build/macos/Build/Products/Release/SACA.app/Contents/MacOS/SACA
```

The `lipo` output should include both `x86_64` and `arm64`.

## Release hardening

Flutter obfuscation is supported for the current non-web targets, but it is not encryption for native binaries, model files, or other assets. Keep split debug symbols outside Git so crash reports can still be de-obfuscated.

```sh
flutter build windows --release --obfuscate --split-debug-info=build/symbols/windows
flutter build macos --release --obfuscate --split-debug-info=build/symbols/macos
flutter build apk --release --obfuscate --split-debug-info=build/symbols/android
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols/android
flutter build ipa --release --obfuscate --split-debug-info=build/symbols/ios
```

## Microphone permissions

- iOS uses `NSMicrophoneUsageDescription` in `ios/Runner/Info.plist`.
- macOS uses `NSMicrophoneUsageDescription` plus sandbox audio input entitlements in `macos/Runner`.
- Windows desktop apps do not declare a per-app microphone permission in the same way; users enable microphone access through Windows privacy settings for desktop apps.

## Device smoke tests

- iPhone: launch, text flow, microphone allow/deny, recording, transcription, settings persistence.
- iPad: full screen and split-screen layout sanity, voice latency, settings persistence.
- macOS Intel: release app launches, text flow works, microphone prompt appears, recording/transcription works.
- macOS Apple Silicon: run the same universal `.app` when hardware is available; otherwise verify with `lipo`.
- Android: preserve with static checks and `flutter build apk --debug` until a real device is available.

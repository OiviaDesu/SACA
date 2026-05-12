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
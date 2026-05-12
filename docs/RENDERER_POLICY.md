# Renderer Policy

SACA supports Windows, macOS, iOS, and Android. It follows Flutter's platform
renderer defaults instead of forcing one global renderer across every target.
This keeps the app aligned with Flutter support and avoids inventing unsupported
fallback behavior.

## Platform policy

| Platform | Policy |
| --- | --- |
| iOS | Use Flutter's default Impeller path. Do not configure Skia fallback; Flutter does not support switching iOS back to Skia. |
| Android | Use Flutter's default Impeller path on supported devices. Flutter handles fallback on unsupported Android devices, such as old API levels or devices without Vulkan support. |
| Windows/macOS | Keep Flutter defaults. Only enable or disable Impeller with explicit per-platform evidence and a tracked renderer issue. |

## Debug notes

- Do not add shared Dart runtime logic that tries to switch renderers.
- Do not add a global build flag that assumes Skia fallback everywhere.
- For Android renderer debugging, run with:

  ```bash
  flutter run --no-enable-impeller
  ```

- For renderer regressions, capture platform, Flutter version, device/GPU, and
  whether the issue reproduces with default renderer settings before changing
  platform config.

## Current audit

No SACA platform config currently forces Impeller or Skia. Renderer behavior is
therefore controlled by Flutter defaults for each supported target.

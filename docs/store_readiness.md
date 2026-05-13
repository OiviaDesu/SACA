# Store Readiness Checklist

SACA targets Windows, macOS, iOS, and Android only. This checklist supports release review preparation; it is not a guarantee of App Store, Google Play, or Microsoft Store approval.

## Shared app-store guardrails

- Ship code-complete builds only: no blank screens, placeholder flows, hidden debug menus, or dormant features not described in release notes.
- Do not download or execute new app logic, binaries, scripts, models, or plugins to bypass store review. Model assets must be bundled or installed through documented release channels.
- Request only required permissions. If microphone or storage access is denied, keep manual text input and symptom selection usable.
- Do not log private transcript, audio, non-speech cues, or clinical inputs outside transient debug diagnostics needed for development.
- Keep AI/ML wording conservative: SACA provides preliminary guidance, not diagnosis, and escalates red flags to urgent care.
- Keep recoverable failures calm: retry, manual input, or confirmation dialog before showing result when no clear illness match exists.

## Apple App Store

- Include microphone purpose text and review notes for offline voice input and local model behavior.
- Do not rely on hidden feature flags to expose unreviewed clinical, AI, or payment behavior after approval.
- Treat iOS Impeller as platform default; do not claim Skia fallback on iOS.
- If SACA is submitted as health-related software, metadata must explain limitations and clinician-safety disclaimer clearly.

## Google Play

- Keep Android permissions scoped to microphone and app-owned files unless a future feature justifies more.
- Avoid Accessibility API, SMS, call log, background service, or broad file access unless separately justified and reviewed.
- If model assets or voice components change, document whether data leaves device. Current policy target is offline-first processing.
- Health-content metadata must not promise diagnosis or treatment decisions from ML output.

## Microsoft Store

- Run Windows App Certification Kit before submission and fix crash, hang, DPI, and security failures.
- Keep single-instance behavior least-privilege; no service, driver, or admin requirement for normal app launch.
- Avoid writing audio/transcript temp data to persistent user folders. If a backend requires temp WAV, delete it in `finally`.
- Do not force experimental renderer or GPU providers if smoke tests show blank screen, crash, or unsupported hardware.

## Release review notes

- Supported targets: Windows, macOS, iOS, Android.
- Unsupported target: Web.
- Glass theme is preview UI only; clinical behavior is unchanged.
- Flutter obfuscation hides Dart symbols but does not encrypt assets, models, or native binaries.
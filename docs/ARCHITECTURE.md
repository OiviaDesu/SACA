# SACA â€“ Architecture

## System intent

SACA is an offline triage-support prototype. The app collects symptoms using text, voice, or visual selection, asks a structured follow-up questionnaire, and then generates preliminary guidance with safety escalation for emergency red flags.

## Layered structure

```text
lib/
├── core/
│   ├── errors/        # AppFailure/AppResult, error kinds and messages
│   └── theme/         # Shared Cupertino visual theme
├── domain/
│   ├── models/        # SacaFlowState, AnalysisRequest/Result, enums
│   └── services/      # Contracts + domain services (vocabulary/safety)
├── infrastructure/
│   ├── analysis/      # MockAnalysisService and local classifier runtime
│   ├── localization/  # Asset lexicon repository
│   ├── speech/        # Recorder, Whisper runtime, speech adapter, prewarm
│   └── window/        # Desktop window configuration
└── presentation/
    ├── adaptive/      # Platform-adaptive layout/style handling
    ├── controllers/   # SacaFlowController state machine
    ├── localization/  # UI localizer using clinical vocabulary
    ├── screens/       # SacaFlowScreen orchestration and step widgets
    └── widgets/       # Reusable UI controls/body diagrams
```

## Runtime architecture

```text
User input (text / voice / visual)
    -> SacaFlowController
    -> SpeechInputService (voice path only)
            -> AudioRecorderService (WAV 16 kHz mono)
            -> WhisperService (platform specific)
    -> MockAnalysisService
            -> ClinicalVocabularyService normalization
            -> SafetyRuleService red-flag escalation
    -> AnalysisResult rendered in SacaFlowScreen
```

Voice runtime startup is prewarmed after the first frame by
`VoicePrewarmService`. This keeps app startup non-blocking while reducing the
delay when the user opens Voice input. `WhisperService` also caches the loaded
runtime key and any in-flight initialization future so repeated prepare calls
reuse the same runtime.

## Speech-to-text backends

- Android / iOS:
  - backend: `whisper_kit`
  - default language code for transcription requests: `en`
  - English mode prefers an optional local `ggml-base.en.bin` bundle; otherwise falls back to multilingual `small`
  - Gurindji mode attempts local custom model path; otherwise falls back to standard small model
- Windows / macOS:
  - backend: `sherpa_onnx` (`OfflineRecognizer`)
  - prefers optional English-only ONNX assets when available; otherwise uses `assets/models/sherpa-onnx-whisper-base/`
- Web:
  - `whisper_service_stub.dart` with `supportsOnDeviceStt == false`

## State machine (assessment flow)

Defined by `SacaStep` in `lib/domain/models/saca_models.dart`:

1. `splash`
2. `language`
3. `inputMethod`
4. `voiceInput` or `textInput` or `visualInput`
5. `questionSeverity`
6. `questionDuration`
7. `questionRelatedSymptoms`
8. `questionMedication`
9. `questionFood`
10. `questionAllergies`
11. `questionHealthChanges`
12. `analysing`
13. `result`

## Analysis design (current implementation)

- `MockAnalysisService` produces a base result from:
  - free text content
  - selected symptom IDs
  - severity answer
- `SafetyRuleService` then overrides with emergency guidance when red flags are present.

Red-flag examples include:

- chest pain / chest tightness
- shortness of breath
- unconscious / fainted / seizure
- severe bleeding
- chest/heart area selected in visual input

Emergency override output:

- disease: `Urgent symptoms`
- severity: `SeverityLevel.emergency`
- guidance includes explicit `Call 000 now`

## Localization and vocabulary

- Lexicon source: `assets/data/gurindji_lexicon.json`
- Loading: `AssetLexiconRepository`
- Runtime mapping and normalization: `ClinicalVocabularyService`
  - bilingual labels for symptoms/body areas/results
  - normalization rules append canonical English tokens when Gurindji terms are detected

## Audio capture requirements

`AudioRecorderService` records with:

- WAV encoder
- sample rate: `16000`
- channels: `1`
- bitrate: `256000`

## Safety and scope notes

- SACA provides preliminary triage guidance only.
- It is not a diagnostic system and does not replace clinician judgment.
- Emergency red flags are intentionally conservative and escalate quickly.

## Near-term roadmap

1. Replace placeholder analysis with a stronger local model while preserving current safety overlays.
2. Expand Gurindji vocabulary coverage and normalization quality.
3. Improve platform parity for offline STT behavior and diagnostics.

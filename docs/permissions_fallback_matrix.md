# Permissions And Fallback Matrix

SACA should keep users oriented when runtime capabilities fail. Recoverable issues should not use alarming clinical error copy.

| Area | Failure | User-facing fallback | Data handling |
| --- | --- | --- | --- |
| Microphone | Permission denied | Show calm prompt with retry and manual text input | No recording starts |
| Microphone | No speech detected | Offer retry or continue with typed input | Empty buffer discarded |
| Recording | Backend cannot stream bytes | Use short-lived temp WAV only if required | Delete temp file in `finally` |
| STT | Final transcription fails with draft text | Keep draft, show neutral review notice | Keep only current-flow transcript state |
| STT | No usable transcript | Offer retry, text input, and symptom picker | Clear audio buffer and cue state |
| Non-speech cues | No cue or low confidence | Hide cue suggestions | Do not show cue in transcript |
| Related symptoms | No suggestions | Show `None` first and `Other Symptom` | Do not auto-select symptoms |
| ML diagnosis | GPU/provider fail | Retry CPU once with same input | No user re-entry required |
| ML diagnosis | No clear illness match | Ask confirmation before result guidance | Preserve user input for review |
| Safety rules | Emergency red flag | Go urgent flow without soft confirmation | Keep conservative escalation |
| Renderer | Experimental Impeller/GPU fails | Use platform default renderer | No clinical flow change |
| Theme | Glass unavailable or unsafe | Render Modern and show neutral Settings note | Keep saved user preference |
| Storage | Temp storage unavailable | Prefer RAM path; otherwise ask retry/manual input | Do not persist audio/transcript |

## UX rule

Fallback copy should explain the next safe action, not technical failure detail. Developer detail belongs in debug logs only.
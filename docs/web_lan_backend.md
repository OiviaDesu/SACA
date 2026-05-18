# SACA Web LAN Backend

SACA Web is a local/LAN demo target. The browser frontend runs Flutter Web and
uses bundled Dart model assets for diagnosis. Voice transcription still calls a
backend hosted on the same machine as the build.

For a single public hostname such as `https://saca.mixcorp.org`, serve the
Flutter Web files and API routes from the same local server. This avoids CORS
and lets Cloudflare Tunnel forward one origin.

```powershell
flutter build web --no-wasm-dry-run --pwa-strategy=none --dart-define=SACA_API_BASE=https://saca.mixcorp.org
python tools\saca_web_demo_server.py --host 0.0.0.0 --port 8787
```

Then point Cloudflare Tunnel for `saca.mixcorp.org` to:

```text
http://127.0.0.1:8787
```

The local demo server exposes `/`, `/health`, `/analyse`, and `/stt` on the
same port. `/stt` is the normal web voice path. `/analyse` is retained as a
debug/manual fallback route; the web app does not call it during normal
diagnosis because diagnosis runs in browser through `OnDeviceDiagnosisAnalysisService`.

Install backend dependency if missing:

```powershell
python -m pip install -r python_pipeline\requirements\web_backend.txt
```

`ffmpeg` must also be available on `PATH`.

## Build

Use the host machine LAN IP for LAN demos. Do not use `127.0.0.1` when a phone
or another computer opens the web app. For voice recording from browsers,
prefer HTTPS, for example a Cloudflare Tunnel URL, because browser microphone
APIs require a secure context except for local `localhost` testing.

```powershell
flutter build web --dart-define=SACA_API_BASE=http://<LAN_IP>:8787
```

For Cloudflare Tunnel:

```powershell
flutter build web --dart-define=SACA_API_BASE=https://<your-tunnel>.trycloudflare.com
```

Serve the output from `build/web` with the SACA demo server when STT is needed.
Static-only hosting can display the app and run text diagnosis, but voice will
be unavailable unless `/stt` is reachable.

## Backend requirements

The backend must bind to `0.0.0.0`, enable CORS for the web origin, and expose:

- `GET /health`
  - Returns `2xx` when the backend is reachable.
  - May include `{"stt":true,"analysis":true}` for diagnostics. For current web
    app behavior, `stt` is the important runtime dependency.
- `POST /stt`
  - `multipart/form-data` fields:
    - `audio`: browser recording bytes, usually WebM/Opus.
    - `language`: `english` or `gurindji`.
    - `mode`: `dictation` or `command`.
  - Returns JSON:

```json
{
  "text": "cough and fever",
  "confidence": 0.82,
  "isSupported": true,
  "qualityFlags": [],
  "cues": [
    {"kind": "cough", "confidence": 0.7, "evidence": "audio"}
  ]
}
```

- `POST /analyse` (optional debug/manual fallback)
  - Accepts `AnalysisRequest` JSON from the app.
  - Returns JSON:

```json
{
  "disease": "Flu-like illness",
  "severity": "mild",
  "guidance": ["Rest", "Drink fluids"],
  "isEmergency": false,
  "disclaimer": "Prototype guidance only.",
  "predictions": [
    {"label": "Flu-like illness", "rank": 1, "confidence": 0.76}
  ]
}
```

## Local smoke

1. Start backend: `0.0.0.0:8787`.
2. Build web with `SACA_API_BASE=http://<LAN_IP>:8787`.
3. Serve `build/web`.
4. Open from host and from another LAN device.
5. Verify text input reaches results without `/analyse`, voice input calls
   `/stt`, backend-down recovery is calm, and CORS is correct.

## Link Notes

`https://saca.mixcorp.org`, `http://127.0.0.1:8787`, `<LAN_IP>`, and
`<your-tunnel>` are deployment examples. They are not guaranteed public
documentation links.

## Scope

Web is not a store target. Windows, macOS, iOS, and Android keep native/offline
service paths.

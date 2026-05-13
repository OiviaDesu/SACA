#!/usr/bin/env python3
"""Serve SACA Flutter Web and local demo API from one origin.

This server is for local/LAN/Cloudflare demo use. It serves `build/web` and
implements the web API contract expected by the Flutter Web client:

  GET  /health
  POST /analyse
  POST /stt

`/analyse` uses the exported XGBoost JSON bundle from `assets/models` so the
web demo can run the same diagnosis ML path without native Flutter plugins.
"""

from __future__ import annotations

import argparse
from email import policy
from email.parser import BytesParser
import json
import math
import mimetypes
import os
import re
import shutil
import struct
import subprocess
import sys
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import unquote, urlparse


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_WEB_ROOT = ROOT / "build" / "web"
DEFAULT_MODEL = ROOT / "assets" / "models" / "classifier-xgb-best" / "bundle.json"
DISCLAIMER = "SACA provides preliminary triage guidance only. It does not replace a clinician."

RED_FLAG_TERMS = (
    "chest pain",
    "chest tightness",
    "difficulty breathing",
    "shortness of breath",
    "short of breath",
    "cannot breathe",
    "can't breathe",
    "blue lips",
    "lips look blue",
    "unconscious",
    "fainted",
    "fainting",
    "seizure",
    "stroke",
    "severe confusion",
    "sudden confusion",
    "severe bleeding",
    "vomiting blood",
    "blood in stool",
    "coughing blood",
)

HEALTHY_PHRASES = (
    "i am good",
    "i feel good",
    "i am okay",
    "i feel okay",
    "i am fine",
    "i feel fine",
    "i feel healthy",
    "nothing wrong",
    "no symptoms",
    "no symptom",
    "no problem",
    "not sick",
    "i am not sick",
    "i am healthy",
    "feeling good",
    "feeling fine",
)


def _combined_input(payload: dict[str, Any]) -> str:
    parts: list[str] = []
    for key in ("transcript", "textInput"):
        value = payload.get(key)
        if isinstance(value, str) and value.strip():
            parts.append(value.strip())
    for key in ("selectedSymptomIds", "selectedBodyAreaIds"):
        value = payload.get(key)
        if isinstance(value, list):
            text = " ".join(str(item) for item in value if str(item).strip())
            if text.strip():
                parts.append(text.strip())
    answers = payload.get("answers")
    if isinstance(answers, dict):
        text = " ".join(str(item) for item in answers.values() if str(item).strip())
        if text.strip():
            parts.append(text.strip())
    return " ".join(parts)


def _char_wb_ngrams(text: str, min_n: int, max_n: int) -> list[str]:
    normalized = re.sub(r"\s+", " ", text.lower()).strip()
    if not normalized:
        return []
    ngrams: list[str] = []
    for word in normalized.split(" "):
        if not word:
            continue
        padded = f" {word} "
        word_length = len(padded)
        for n in range(min_n, max_n + 1):
            offset = 0
            ngrams.append(padded[offset : min(word_length, offset + n)])
            while offset + n < word_length:
                offset += 1
                ngrams.append(padded[offset : min(word_length, offset + n)])
            if offset == 0:
                break
    return ngrams


class XgbBundle:
    def __init__(self, path: Path):
        with path.open("r", encoding="utf-8") as handle:
            data = json.load(handle)
        self.classes: list[str] = list(data["classes"])
        self.feature_count: int = int(data["feature_count"])
        self.text_feature: dict[str, Any] = data["text_feature"]
        self.categorical_features: list[dict[str, Any]] = list(data["categorical_features"])
        self.numeric_features: list[dict[str, Any]] = list(data["numeric_features"])
        self.model: dict[str, Any] = data["model"]

    def predict(self, payload: dict[str, Any]) -> list[dict[str, Any]]:
        vector = self._build_vector(payload)
        num_classes = int(self.model["num_classes"])
        margins = [float(value) for value in self.model["base_scores"]]
        for tree_index, tree in enumerate(self.model["trees"]):
            class_index = tree_index % num_classes
            margins[class_index] += self._score_tree(tree["nodes"], vector)
        probabilities = self._softmax(margins)
        ranked = sorted(
            (
                {"label": label, "rank": index + 1, "confidence": probabilities[index]}
                for index, label in enumerate(self.classes)
            ),
            key=lambda item: item["confidence"],
            reverse=True,
        )
        return [dict(item, rank=rank + 1) for rank, item in enumerate(ranked[:3])]

    def _build_vector(self, payload: dict[str, Any]) -> list[float]:
        dense = [math.nan] * self.feature_count
        text = _combined_input(payload)
        self._apply_text_features(dense, text)
        language = str(payload.get("language") or "english")
        categorical = {"language": language, "source": "saca_app"}
        for feature in self.categorical_features:
            candidate = categorical.get(str(feature["name"]))
            if not candidate:
                continue
            try:
                category_index = list(feature["categories"]).index(candidate)
            except ValueError:
                continue
            dense[int(feature["offset"]) + category_index] = 1.0
        for feature in self.numeric_features:
            dense[int(feature["offset"])] = float(feature.get("fill_value", 0.0))
        return dense

    def _apply_text_features(self, dense: list[float], text: str) -> None:
        text_feature = self.text_feature
        ngram_range = list(text_feature["ngram_range"])
        vocabulary = text_feature["vocabulary"]
        idf = text_feature["idf"]
        counts: dict[str, int] = {}
        for ngram in _char_wb_ngrams(text, int(ngram_range[0]), int(ngram_range[-1])):
            counts[ngram] = counts.get(ngram, 0) + 1
        weighted: dict[int, float] = {}
        for ngram, count in counts.items():
            feature_index = vocabulary.get(ngram)
            if feature_index is None:
                continue
            tf = 1.0 + math.log(float(count)) if text_feature.get("sublinear_tf") else float(count)
            weighted[int(feature_index)] = tf * float(idf[int(feature_index)])
        norm = math.sqrt(sum(value * value for value in weighted.values()))
        if norm <= 0:
            return
        for feature_index, value in weighted.items():
            dense[feature_index] = value / norm

    @staticmethod
    def _score_tree(nodes: list[dict[str, Any]], vector: list[float]) -> float:
        node_index = 0
        while True:
            node = nodes[node_index]
            if "leaf" in node:
                return float(node["leaf"])
            value = vector[int(node["split_index"])]
            if math.isnan(value):
                node_index = int(node["missing"])
            elif value < float(node["threshold"]):
                node_index = int(node["yes"])
            else:
                node_index = int(node["no"])

    @staticmethod
    def _softmax(margins: list[float]) -> list[float]:
        max_margin = max(margins)
        exps = [math.exp(value - max_margin) for value in margins]
        total = sum(exps)
        return [value / total for value in exps]


class WebSttRuntime:
    def __init__(self, root: Path):
        self.root = root
        self._recognizers: dict[str, Any] = {}
        self._sherpa: Any | None = None

    @property
    def available(self) -> bool:
        return shutil.which("ffmpeg") is not None and self._import_sherpa() is not None

    def transcribe(self, audio: bytes, *, language: str, mode: str) -> dict[str, Any]:
        if not audio:
            raise ValueError("Empty audio upload")
        recognizer_language = self._language_code(language)
        recognizer = self._recognizer_for(language)
        samples, sample_rate = self._decode_audio(audio)
        stream = recognizer.create_stream()
        stream.accept_waveform(sample_rate, samples)
        recognizer.decode_stream(stream)
        result = stream.result
        text = getattr(result, "text", str(result)).strip()
        confidence = 0.78 if text else 0.0
        return {
            "text": text,
            "confidence": confidence,
            "isSupported": True,
            "qualityFlags": [] if text else ["empty_transcript"],
            "cues": self._cue_hints(text, mode),
            "language": recognizer_language,
        }

    def _import_sherpa(self) -> Any | None:
        if self._sherpa is not None:
            return self._sherpa
        try:
            import sherpa_onnx  # type: ignore
        except Exception:
            return None
        self._sherpa = sherpa_onnx
        return sherpa_onnx

    def _recognizer_for(self, language: str) -> Any:
        key = "gurindji" if language == "gurindji" else "english"
        cached = self._recognizers.get(key)
        if cached is not None:
            return cached
        sherpa = self._import_sherpa()
        if sherpa is None:
            raise RuntimeError("sherpa-onnx is not installed. Run `python -m pip install sherpa-onnx`.")
        model_dir = self._model_dir_for(key)
        encoder = model_dir / "encoder.onnx"
        decoder = model_dir / "decoder.onnx"
        tokens = model_dir / "tokens.txt"
        missing = [str(path) for path in (encoder, decoder, tokens) if not path.exists()]
        if missing:
            raise RuntimeError("Missing STT model files: " + ", ".join(missing))
        recognizer = sherpa.OfflineRecognizer.from_whisper(
            encoder=str(encoder),
            decoder=str(decoder),
            tokens=str(tokens),
            language=self._language_code(key),
            task="transcribe",
            num_threads=max(1, min(4, (os.cpu_count() or 2) // 2)),
            provider="cpu",
        )
        self._recognizers[key] = recognizer
        return recognizer

    def _model_dir_for(self, key: str) -> Path:
        if key == "gurindji":
            candidate = self.root / "assets" / "models" / "sherpa-onnx-whisper-gue-base-run4-rc1"
            if (candidate / "encoder.onnx").exists():
                return candidate
        return self.root / "assets" / "models" / "sherpa-onnx-whisper-base"

    @staticmethod
    def _language_code(language: str) -> str:
        return "en" if language != "gurindji" else "en"

    @staticmethod
    def _decode_audio(audio: bytes) -> tuple[list[float], int]:
        ffmpeg = shutil.which("ffmpeg")
        if ffmpeg is None:
            raise RuntimeError("ffmpeg is required to decode browser WebM audio")
        command = [
            ffmpeg,
            "-hide_banner",
            "-loglevel",
            "error",
            "-i",
            "pipe:0",
            "-ac",
            "1",
            "-ar",
            "16000",
            "-f",
            "f32le",
            "pipe:1",
        ]
        process = subprocess.run(
            command,
            input=audio,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        if process.returncode != 0:
            detail = process.stderr.decode("utf-8", errors="replace").strip()
            raise RuntimeError(f"ffmpeg decode failed: {detail}")
        raw = process.stdout
        if len(raw) < 4:
            return [], 16000
        samples = list(struct.unpack(f"<{len(raw) // 4}f", raw[: len(raw) - (len(raw) % 4)]))
        return samples, 16000

    @staticmethod
    def _cue_hints(text: str, mode: str) -> list[dict[str, Any]]:
        lower = text.lower()
        cues: list[dict[str, Any]] = []
        for kind in ("cough", "wheeze", "breathing", "vomit"):
            if kind in lower:
                cues.append({"kind": kind, "confidence": 0.65, "evidence": "transcript"})
        return cues


def _parse_multipart(content_type: str, body: bytes) -> tuple[dict[str, str], dict[str, bytes]]:
    fields: dict[str, str] = {}
    files: dict[str, bytes] = {}
    raw_message = (
        f"Content-Type: {content_type}\r\n"
        f"Content-Length: {len(body)}\r\n"
        "MIME-Version: 1.0\r\n\r\n"
    ).encode("utf-8") + body
    message = BytesParser(policy=policy.default).parsebytes(raw_message)
    if not message.is_multipart():
        return fields, files
    for part in message.iter_parts():
        disposition = part.get_content_disposition()
        if disposition != "form-data":
            continue
        name = part.get_param("name", header="content-disposition")
        if not name:
            continue
        payload = part.get_payload(decode=True) or b""
        filename = part.get_filename()
        if filename:
            files[name] = payload
        else:
            charset = part.get_content_charset() or "utf-8"
            fields[name] = payload.decode(charset, errors="replace")
    return fields, files


def _severity(payload: dict[str, Any], disease: str) -> str:
    answers = payload.get("answers")
    severity_value = 0
    if isinstance(answers, dict):
        try:
            severity_value = int(str(answers.get("severity", "0")))
        except ValueError:
            severity_value = 0
    if severity_value >= 8:
        return "severe"
    if severity_value >= 5:
        return "moderate"
    if disease in {"pneumonia", "dengue", "malaria", "typhoid", "jaundice"}:
        return "moderate"
    return "mild"


def _has_red_flag(payload: dict[str, Any], combined: str) -> bool:
    selected = set(str(item) for item in payload.get("selectedSymptomIds", []) if isinstance(item, str))
    areas = set(str(item) for item in payload.get("selectedBodyAreaIds", []) if isinstance(item, str))
    lower = combined.lower()
    return (
        any(term in lower for term in RED_FLAG_TERMS)
        or "chest_pain" in selected
        or "breathing_trouble" in selected
        or "chest" in areas
        or "heart" in areas
    )


def analyse_payload(payload: dict[str, Any], bundle: XgbBundle) -> dict[str, Any]:
    combined = _combined_input(payload).strip()
    if not combined:
        return {
            "disease": "No clear illness detected",
            "severity": "mild",
            "guidance": [
                "No clear symptom was reported, so no disease prediction is needed.",
                "Monitor how you feel and return if symptoms appear.",
                "Seek urgent help if chest pain, breathing trouble, severe bleeding, or confusion starts.",
            ],
            "isEmergency": False,
            "disclaimer": DISCLAIMER,
            "predictions": [],
        }
    lower = combined.lower()
    if any(phrase in lower for phrase in HEALTHY_PHRASES):
        return {
            "disease": "No clear illness detected",
            "severity": "mild",
            "guidance": [
                "No clear symptom was reported, so no disease prediction is needed.",
                "Monitor how you feel and return if symptoms appear.",
                "Seek urgent help if chest pain, breathing trouble, severe bleeding, or confusion starts.",
            ],
            "isEmergency": False,
            "disclaimer": DISCLAIMER,
            "predictions": [],
        }
    if _has_red_flag(payload, combined):
        return {
            "disease": "Urgent symptoms",
            "severity": "emergency",
            "guidance": [
                "Call 000 now or ask someone nearby to call.",
                "Do not wait for the app to make a diagnosis.",
                "If safe, stay seated and keep the phone nearby.",
            ],
            "isEmergency": True,
            "disclaimer": DISCLAIMER,
            "predictions": [],
        }
    predictions = bundle.predict(payload)
    disease = str(predictions[0]["label"] if predictions else "General symptoms")
    severity = _severity(payload, disease)
    return {
        "disease": disease,
        "severity": severity,
        "guidance": [
            "Review the top predicted conditions with a clinician or health worker.",
            "Track symptom changes, duration, and severity.",
            "Seek urgent help if breathing trouble, chest pain, severe bleeding, or confusion starts.",
        ],
        "isEmergency": False,
        "disclaimer": DISCLAIMER,
        "predictions": predictions,
    }


class SacaDemoHandler(BaseHTTPRequestHandler):
    server_version = "SacaWebDemo/1.0"

    def do_OPTIONS(self) -> None:
        self._send_empty(HTTPStatus.NO_CONTENT)

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path == "/reset-cache":
            self._send_cache_reset_page()
            return
        if parsed.path == "/health":
            self._send_json(
                {
                    "ok": True,
                    "stt": self.server.stt.available,  # type: ignore[attr-defined]
                    "analysis": True,
                    "runtime": "saca-web-demo-server",
                }
            )
            return
        if parsed.path.startswith("/$dwds"):
            self._send_empty(HTTPStatus.NOT_FOUND)
            return
        self._serve_static(parsed.path)

    def do_HEAD(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path == "/health":
            self.send_response(HTTPStatus.OK)
            self._send_common_headers(content_type="application/json; charset=utf-8", content_length=0)
            self.end_headers()
            return
        self.send_response(HTTPStatus.OK)
        self._send_common_headers(content_type="text/html; charset=utf-8", content_length=0)
        self.end_headers()

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path == "/analyse":
            payload = self._read_json_body()
            if payload is None:
                self._send_json({"error": "Invalid JSON body"}, HTTPStatus.BAD_REQUEST)
                return
            try:
                self._send_json(analyse_payload(payload, self.server.bundle))  # type: ignore[attr-defined]
            except Exception as error:  # pragma: no cover - defensive server boundary
                self._send_json({"error": str(error)}, HTTPStatus.INTERNAL_SERVER_ERROR)
            return
        if parsed.path == "/stt":
            fields, files = self._read_multipart_body()
            audio = files.get("audio", b"")
            language = fields.get("language", "english")
            mode = fields.get("mode", "dictation")
            print(
                f"[SACA STT] language={language} mode={mode} fields={list(fields)} "
                f"files={[(name, len(data)) for name, data in files.items()]}",
                file=sys.stderr,
            )
            try:
                self._send_json(self.server.stt.transcribe(audio, language=language, mode=mode))  # type: ignore[attr-defined]
            except Exception as error:
                print(f"[SACA STT] failed: {error}", file=sys.stderr)
                self._send_json(
                    {
                        "error": str(error),
                        "text": "",
                        "confidence": 0.0,
                        "isSupported": False,
                        "qualityFlags": ["stt_unavailable"],
                        "cues": [],
                    },
                    HTTPStatus.SERVICE_UNAVAILABLE,
                )
            return
        self._send_json({"error": "Not found"}, HTTPStatus.NOT_FOUND)

    def log_message(self, format: str, *args: Any) -> None:
        sys.stderr.write("%s - - [%s] %s\n" % (self.address_string(), self.log_date_time_string(), format % args))

    def _read_json_body(self) -> dict[str, Any] | None:
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            length = 0
        raw = self.rfile.read(length)
        try:
            decoded = json.loads(raw.decode("utf-8"))
        except Exception:
            return None
        return decoded if isinstance(decoded, dict) else None

    def _read_multipart_body(self) -> tuple[dict[str, str], dict[str, bytes]]:
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            length = 0
        body = self.rfile.read(length)
        return _parse_multipart(self.headers.get("Content-Type", ""), body)

    def _serve_static(self, raw_path: str) -> None:
        web_root: Path = self.server.web_root  # type: ignore[attr-defined]
        path = unquote(raw_path.split("?", 1)[0]).lstrip("/")
        candidate = (web_root / path).resolve() if path else web_root / "index.html"
        try:
            candidate.relative_to(web_root.resolve())
        except ValueError:
            self._send_empty(HTTPStatus.FORBIDDEN)
            return
        if candidate.is_dir():
            candidate = candidate / "index.html"
        if not candidate.exists() and "." not in Path(path).name:
            candidate = web_root / "index.html"
        if not candidate.exists():
            self._send_empty(HTTPStatus.NOT_FOUND)
            return
        content_type = mimetypes.guess_type(candidate.name)[0] or "application/octet-stream"
        data = candidate.read_bytes()
        self.send_response(HTTPStatus.OK)
        self._send_common_headers(content_type=content_type, content_length=len(data))
        self.end_headers()
        self.wfile.write(data)

    def _send_cache_reset_page(self) -> None:
        html = b"""<!doctype html>
<html><head><meta charset='utf-8'><title>SACA cache reset</title></head>
<body style='font-family: system-ui, sans-serif; padding: 32px;'>
<h1>Resetting SACA web cache...</h1>
<p>This clears stale Flutter debug/service-worker cache, then reloads SACA.</p>
<script>
(async () => {
  try {
    if ('serviceWorker' in navigator) {
      const registrations = await navigator.serviceWorker.getRegistrations();
      await Promise.all(registrations.map((registration) => registration.unregister()));
    }
    if ('caches' in window) {
      const names = await caches.keys();
      await Promise.all(names.map((name) => caches.delete(name)));
    }
    localStorage.clear();
    sessionStorage.clear();
  } catch (error) {
    console.warn('SACA cache reset warning', error);
  }
  location.replace('/?v=' + Date.now());
})();
</script>
</body></html>"""
        self.send_response(HTTPStatus.OK)
        self._send_common_headers(content_type="text/html; charset=utf-8", content_length=len(html))
        self.send_header("Clear-Site-Data", '"cache", "storage"')
        self.end_headers()
        self.wfile.write(html)

    def _send_json(self, payload: dict[str, Any], status: HTTPStatus = HTTPStatus.OK) -> None:
        data = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self._send_common_headers(content_type="application/json; charset=utf-8", content_length=len(data))
        self.end_headers()
        self.wfile.write(data)

    def _send_empty(self, status: HTTPStatus) -> None:
        self.send_response(status)
        self._send_common_headers(content_length=0)
        self.end_headers()

    def _send_common_headers(self, *, content_type: str | None = None, content_length: int | None = None) -> None:
        if content_type:
            self.send_header("Content-Type", content_type)
        if content_length is not None:
            self.send_header("Content-Length", str(content_length))
        self.send_header("Access-Control-Allow-Origin", os.environ.get("SACA_CORS_ORIGIN", "*"))
        self.send_header("Access-Control-Allow-Methods", "GET,POST,OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type,Authorization")
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")


class SacaDemoServer(ThreadingHTTPServer):
    def __init__(
        self,
        server_address: tuple[str, int],
        handler: type[SacaDemoHandler],
        *,
        web_root: Path,
        bundle: XgbBundle,
        stt: WebSttRuntime,
    ):
        super().__init__(server_address, handler)
        self.web_root = web_root
        self.bundle = bundle
        self.stt = stt


def main() -> int:
    parser = argparse.ArgumentParser(description="Serve SACA web demo frontend and API from one origin.")
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8787)
    parser.add_argument("--web-root", type=Path, default=DEFAULT_WEB_ROOT)
    parser.add_argument("--model", type=Path, default=DEFAULT_MODEL)
    args = parser.parse_args()

    web_root = args.web_root.resolve()
    model = args.model.resolve()
    if not (web_root / "index.html").exists():
        print(f"Missing Flutter web build at {web_root}. Run `flutter build web` first.", file=sys.stderr)
        return 2
    if not model.exists():
        print(f"Missing model bundle at {model}.", file=sys.stderr)
        return 2

    print(f"Loading SACA ML bundle: {model}")
    bundle = XgbBundle(model)
    stt = WebSttRuntime(ROOT)
    server = SacaDemoServer((args.host, args.port), SacaDemoHandler, web_root=web_root, bundle=bundle, stt=stt)
    print(f"SACA web demo server listening on http://{args.host}:{args.port}")
    print(f"Routes: /, /health, /analyse, /stt; stt_available={stt.available}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("Shutting down")
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

# SACA

**Smart Adaptive Clinical Assistant** — a Flutter research prototype for
offline-first triage support in remote-care contexts.

SACA helps collect symptoms through text, voice, and visual selection, asks
structured follow-up questions, and returns conservative guidance with safety
escalation. It is designed for demonstration, research, and workflow exploration;
it is **not** a diagnostic system and must not replace clinician judgement.

## Acknowledgement of Country

We respectfully acknowledge the Wurundjeri People of the Kulin Nation, who
are the Traditional Owners of the land on which Swinburne’s Australian
campuses are located in Melbourne’s east and outer-east, and pay our
respect to their Elders past, present and emerging.
We are honoured to recognise our connection to Wurundjeri Country, history,
culture, and spirituality through these locations, and strive to ensure that we
operate in a manner that respects and honours the Elders and Ancestors of
these lands.
We also respectfully acknowledge Swinburne’s Aboriginal and Torres Strait
Islander staff, students, alumni, partners and visitors.
We also acknowledge and respect the Traditional Owners of lands across
Australia, their Elders, Ancestors, cultures, and heritage, and recognise the
continuing sovereignties of all Aboriginal and Torres Strait Islander Nations.

## Safety Notice

SACA is a **research prototype**, not medical advice, a clinical decision
system, or a medical device. Outputs are preliminary triage-support guidance
only. If symptoms are severe, unclear, worsening, or urgent, seek human medical
care immediately.

## What SACA Does

- Supports English and Gurindji UI modes.
- Collects symptoms through text, voice, visual symptom tiles, and body-area
  selection.
- Guides users through structured follow-up questions.
- Runs on-device diagnosis analysis with a hybrid logistic-regression model and
  XGBoost fallback bundle.
- Applies conservative red-flag safety escalation.
- Offers Modern, Glass (Preview), and Classic visual themes.
- Supports native desktop/mobile builds plus a web demo mode.

## Platform Status

| Platform | Status | Notes |
| --- | --- | --- |
| Windows | Supported demo target | Desktop UI, local audio recording, native STT path when model assets exist. |
| Android | Supported demo target | Mobile UI and native voice path through the vendored `whisper_kit` integration. |
| macOS | Supported demo target | Flutter desktop runtime with native shell support. |
| iOS | Supported demo target | Flutter iOS runtime with native shell support. |
| Web | Demo only | Browser diagnosis runs locally; voice requires the local `/stt` backend. |

## Quick Start

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

For local Git hooks:

```bash
git config core.hooksPath .githooks
```

For platform-specific setup, model assets, and web backend notes, see
[Documentation](#documentation).

## Web Demo

Build the web demo with the backend URL that will serve `/stt`:

```bash
flutter build web --no-wasm-dry-run --pwa-strategy=none --dart-define=SACA_API_BASE=https://saca.mixcorp.org
python tools/saca_web_demo_server.py --host 0.0.0.0 --port 8787
```

`https://saca.mixcorp.org` is a deployment example. For LAN testing, use the
host machine address instead. Full details are in
[docs/web_lan_backend.md](docs/web_lan_backend.md).

## Repository Map

| Path | Purpose |
| --- | --- |
| `lib/` | Flutter application code: domain, use cases, infrastructure, presentation. |
| `assets/` | Runtime images, lexicon data, and model asset folders. |
| `test/` | Flutter unit, controller, localization, and widget tests. |
| `python_pipeline/` | Research pipeline for datasets, training, export, and HPC workflows. |
| `tools/` | Local demo and repository helper scripts. |
| `docs/` | Architecture, model, dataset, platform, credit, and release documentation. |
| `android/`, `ios/`, `macos/`, `windows/`, `web/` | Platform host projects. |

Most meaningful folders include their own `README.md` for GitHub browsing.

## Model Assets

Current diagnosis runtime:

- Primary classifier: `assets/models/saca-hybrid-logreg-v1/bundle.json`
- Fallback classifier: `assets/models/classifier-xgb-best/bundle.json`
- Experimental/debug classifier: `assets/models/classifier-xgb-quick/`

Large speech model files and full training outputs are not kept in normal Git
history. See [docs/MODEL_ASSETS.md](docs/MODEL_ASSETS.md) and
[docs/HPC_TRAINING_OUTPUTS.md](docs/HPC_TRAINING_OUTPUTS.md).

## Research and Provenance

Training-output inspection and model-export evidence were produced on Swinburne
HPC infrastructure, including OzSTAR/Ngarrgu Tindebeek paths documented in
[docs/HPC_TRAINING_OUTPUTS.md](docs/HPC_TRAINING_OUTPUTS.md). This is an
infrastructure/provenance acknowledgement only; it does not imply Swinburne
clinical approval, dataset ownership, or endorsement of SACA.

Full credits, dataset notes, link-access notes, and data-governance constraints
are documented in [docs/CREDITS.md](docs/CREDITS.md) and
[docs/DATASET_RESEARCH_SUMMARY.md](docs/DATASET_RESEARCH_SUMMARY.md).

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Credits and acknowledgements](docs/CREDITS.md)
- [Dataset research summary](docs/DATASET_RESEARCH_SUMMARY.md)
- [Gurindji NLP and dataset strategy](docs/GURINDJI_NLP.md)
- [HPC training outputs](docs/HPC_TRAINING_OUTPUTS.md)
- [Swinburne HPC remote inventory](docs/HPC_REMOTE_INVENTORY.md)
- [Model assets](docs/MODEL_ASSETS.md)
- [Platform development](docs/PLATFORM_DEVELOPMENT.md)
- [Permissions fallback matrix](docs/permissions_fallback_matrix.md)
- [Renderer policy](docs/RENDERER_POLICY.md)
- [Store readiness](docs/store_readiness.md)
- [Web LAN backend](docs/web_lan_backend.md)
- [Release checklist](docs/RELEASE_CHECKLIST.md)
- [Contributing](CONTRIBUTING.md)
- [Security policy](SECURITY.md)
- [Code of conduct](CODE_OF_CONDUCT.md)
- [Changelog](CHANGELOG.md)

## Development Standards

- Use [Conventional Commits](https://www.conventionalcommits.org/).
- Keep clinical safety conservative.
- Keep Gurindji wording as research draft until community/native-speaker review.
- Run `flutter analyze` and `flutter test` before pushing behavior changes.
- For docs-only changes, run `python tools/check_folder_readmes.py` and
  `git diff --check`.

## License

See [LICENSE](LICENSE).

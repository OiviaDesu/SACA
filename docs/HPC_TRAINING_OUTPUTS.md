# HPC Training Outputs

This note summarizes SACA training artifacts inspected on Swinburne HPC. It is
provenance evidence for research training, local classifier export, and Flutter
model-runtime work. It is not a clinical validation report.

Swinburne HPC is acknowledged as the infrastructure used to generate and inspect
these training outputs. This does not imply Swinburne provided the datasets,
clinically approved SACA, or endorses the app.

Latest live inventory: 2026-05-19 00:21-00:23 AEST. See
[HPC remote inventory](HPC_REMOTE_INVENTORY.md) for the complete remote output-directory
inventory, including Whisper runs, exports, logs, audits, empty placeholders,
and classifier campaign folders.

## Source Location

- Remote host: `nt.swin.edu.au`
- Remote base path: `/fred/oz396/dunguyen/saca_whisper`
- Output path: `/fred/oz396/dunguyen/saca_whisper/outputs`
- Code snapshot path: `/fred/oz396/dunguyen/saca_whisper/code`
- Local metadata snapshot: `session_logs/hpc_outputs_snapshot`
- Public HPC documentation: https://supercomputing.swin.edu.au/docs/

The local snapshot intentionally keeps logs, JSON summaries, CSV samples, and
pipeline docs. Large source datasets and binary model artifacts should stay on
HPC or in Git LFS runtime asset locations, not in normal Git history.

## Output Layout

```text
/fred/oz396/dunguyen/saca_whisper/
  code/                         # copied pipeline scripts and HPC wrappers
  data/                         # local/raw datasets on HPC
  outputs/
    logs/                       # Slurm stdout/stderr logs
    classifier_campaigns/       # campaign-level experiment results
    classifier_diagnosis_*/     # individual classifier runs
    flutter_models/             # ONNX-oriented Flutter export runs
    intermediate_datasets/      # merged/intermediate training datasets
```

Recent useful logs include:

- `outputs/logs/classifier_xgb_11822371.out`
- `outputs/logs/classifier_lr_11812118.out`
- `outputs/logs/classifier_11808404.out`
- `outputs/logs/classifier_11808388.out`
- `outputs/logs/gue_small_11877466.out`

## Pipeline Summary

The classifier pipeline trains symptom-text to diagnosis-label models for the
SACA offline triage demo. The inspected runs use normalized diagnosis datasets,
TF-IDF text features, optional language features, and either logistic regression
or XGBoost classifiers.

Key generated files per run:

- `dataset_audit.json`: row counts, label distribution, missing values, text lengths, source distribution.
- `metrics.json`: model family, leaderboard metrics, feature notes, deployment notes.
- `run_summary.json`: winning model and generated artifact list.
- `label_metadata.json`: diagnosis label mapping metadata.
- `onnx_export_status.json`: ONNX export result for Flutter-oriented logistic regression runs.

## Dataset Snapshots

### Expanded Intermediate Dataset

Used by:

- `outputs/classifier_diagnosis_expanded_intermediate_lr_20260503_145235`
- `outputs/classifier_diagnosis_expanded_intermediate_xgb_20260503_145235`

Audit highlights:

- Rows: `27,941`
- Columns: `8`
- Language: `english` only
- Sources: `healthcare_structured`, `symptom2disease`, `medical_conversations`, `gretel_symptom_to_diagnosis`
- Text length: min `18`, median `57`, max `376`
- Cleaning: `0` duplicate rows removed

This dataset has broader label coverage, but the quick runs underperformed and
should not be treated as the current Flutter deployment model.

### Normalized Diagnosis Dataset

Used by Flutter ONNX export runs under `outputs/flutter_models/`.

Audit highlights:

- Rows: `2,002`
- Columns: `5`
- Language: `english` only
- Sources: `symptom2disease` (`1,153`) and `gretel_symptom_to_diagnosis` (`849`)
- Text length: min `55`, median `160`, max `317`
- Cleaning: `0` duplicate rows removed
- Labels: `24` diagnosis classes after normalization

Top label counts in the inspected Flutter export audit:

| Label | Count |
| --- | ---: |
| impetigo | 90 |
| dengue | 90 |
| drug reaction | 90 |
| allergy | 90 |
| varicose veins | 90 |
| hypertension | 90 |
| psoriasis | 90 |
| diabetes | 90 |
| uti | 89 |
| fungal infection | 89 |

## Model Run Results

Metrics below come from each run's `metrics.json` leaderboard entry.

| Run | Model | Accuracy | Macro F1 | Weighted F1 | Notes |
| --- | --- | ---: | ---: | ---: | --- |
| `classifier_diagnosis_expanded_intermediate_lr_20260503_145235` | Logistic regression | 0.0701 | 0.1929 | 0.0596 | quick profile, broad expanded dataset |
| `classifier_diagnosis_expanded_intermediate_xgb_20260503_145235` | XGBoost | 0.1256 | 0.3782 | 0.1269 | quick profile, CUDA device |
| `classifier_diagnosis_multi_lr` | Logistic regression | 0.1411 | 0.1044 | 0.0910 | balanced profile |
| `classifier_diagnosis_multi_xgb` | XGBoost | 0.9651 | 0.9654 | 0.9648 | balanced profile, CUDA device |
| `classifier_diagnosis_single_lr` | Logistic regression | 0.1411 | 0.1044 | 0.0910 | balanced profile |
| `classifier_diagnosis_single_xgb` | XGBoost | 0.9124 | 0.9003 | 0.9114 | balanced profile, CUDA device |
| `flutter_models/lr_diagnosis_onnx_20260504_062957` | Logistic regression | 0.9900 | 0.9908 | 0.9901 | ONNX-oriented run |
| `flutter_models/lr_balanced_single_onnx_20260504_063358` | Logistic regression | 0.9900 | 0.9908 | 0.9901 | ONNX-oriented run |
| `flutter_models/lr_balanced_single_onnx_20260504_063535_v2` | Logistic regression | 0.9900 | 0.9908 | 0.9901 | ONNX-oriented rerun |
| `flutter_models/lr_balanced_single_flutter_onnx_20260504_063657` | Logistic regression | 0.9800 | 0.9813 | 0.9801 | Flutter export-oriented run |

## Gurindji Whisper Training Outputs

The latest SSH inventory found the promoted Gurindji Whisper candidate at:

```text
/fred/oz396/dunguyen/saca_whisper/outputs/whisper-base-gue-example-only-run4/checkpoint-200
```

`outputs/current_best_checkpoint.txt` reports:

| Metric | Value |
| --- | ---: |
| Model | `openai/whisper-base` |
| Run | `whisper-base-gue-example-only-run4` |
| Slurm job | `11877466` |
| Validation raw WER | `0.850450` |
| Validation raw CER | `0.258774` |
| Validation normalized WER | `0.706564` |
| Validation normalized CER | `0.241265` |
| Test raw WER | `0.818722` |
| Test raw CER | `0.231899` |
| Test normalized WER | `0.662910` |
| Test normalized CER | `0.210436` |

Run4 beats the previous `whisper-small` CER gate
(`previous_validation_raw_cer=0.322631`,
`previous_validation_norm_cer=0.304173`) and has export artifacts under:

```text
outputs/exports/gue-whisper-base-run4-ckpt200-rc1/
```

Exported forms include GGML f16/q5_0 binaries and Sherpa-ONNX
`encoder.onnx`, `decoder.onnx`, and `tokens.txt`. They are large runtime
artifacts and must stay in Git LFS, release storage, or HPC storage rather than
normal Git history.

## Deployment Interpretation

The strongest raw classifier run is the balanced XGBoost multi-class run:

```text
outputs/classifier_diagnosis_multi_xgb
accuracy:    0.9650872817955112
macro_f1:    0.9654395528951314
weighted_f1: 0.9647729010640643
```

This XGBoost path is staged locally under
`assets/models/classifier-xgb-best/`. It is used by the current Dart
`OnDeviceDiagnosisAnalysisService` only as a fallback bundle when the primary
hybrid logistic-regression asset is unavailable. It is also useful for
server-side or custom local runtime experiments.

The current primary app classifier is the JSON hybrid logistic-regression bundle
under `assets/models/saca-hybrid-logreg-v1/`. The older ONNX-oriented logistic
regression run remains important provenance for the Flutter-friendly model path:

```text
outputs/flutter_models/lr_balanced_single_flutter_onnx_20260504_063657
accuracy:    0.9800498753117207
macro_f1:    0.9812960537660614
weighted_f1: 0.9801445156670676
```

Earlier ONNX-oriented logistic regression runs reached about `0.9900` accuracy
on the normalized diagnosis split. The Flutter export-oriented run is slightly
lower but remains strong and is easier to deploy through `flutter_onnxruntime`.
This LR ONNX path is the current active Flutter diagnosis classifier through
`OnDeviceDiagnosisAnalysisService`.

The older local quick XGBoost bundle under
`assets/models/classifier-xgb-quick/` came from a different 47-class quick
campaign model. Do not use it as evidence for the best 24-class XGBoost run.

## Reproducibility Notes

- Keep raw datasets under HPC storage, not in Git.
- Keep generated model binaries under Git LFS only when they are runtime assets.
- Use `dataset_audit.json`, `metrics.json`, and `run_summary.json` as evidence for documentation.
- Re-run parity tests before replacing `assets/models/diagnosis_lr_flutter.onnx` or `assets/models/classifier-xgb-quick/bundle.json`.
- Re-run parity tests before enabling `assets/models/classifier-xgb-best/bundle.json` in Flutter.
- Treat high metrics as offline split results only; they do not prove clinical safety or real-world diagnostic accuracy.

## Recommended Documentation Claims

Safe claims:

- SACA uses HPC-generated classifier artifacts for offline demo triage support.
- The current app diagnosis runtime uses the hybrid logistic-regression JSON
  bundle first, with the staged XGBoost bundle as a fallback.
- XGBoost achieved stronger results in selected HPC experiments, but requires
  careful parity-safe runtime handling before being treated as a primary model.
- Dataset audits and run summaries are preserved as reproducibility evidence.

Avoid claims:

- Do not claim clinical validation.
- Do not claim diagnosis reliability outside the offline evaluation split.
- Do not imply Gurindji clinical speech recognition was trained from these classifier outputs.
- Do not claim XGBoost ONNX deployment unless parity testing confirms it.

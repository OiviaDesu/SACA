# Swinburne HPC Remote Inventory

Snapshot time: 2026-05-19 00:21-00:23 AEST.

Remote host: `nt.swin.edu.au`  
Remote base path: `/fred/oz396/dunguyen/saca_whisper`  
Output path: `/fred/oz396/dunguyen/saca_whisper/outputs`  
Code snapshot path: `/fred/oz396/dunguyen/saca_whisper/code`

This document records every SACA output directory discovered during the live
SSH inventory. It intentionally documents large binary/model areas without
copying them into Git.

## Root Summary

| Remote root | Files | Dirs | Bytes | Newest documented file |
| --- | ---: | ---: | ---: | --- |
| `outputs/` | 754 | 199 | 49,075,829,282 | `outputs/exports/gue-whisper-base-run4-ckpt200-rc1/sherpa-onnx/decoder.onnx` |
| `code/` | 71 | 22 | 229,393,892 | `code/python_pipeline/docs/gue_whisper_pipeline.md` |
| `data/` | 10 | 4 | 228,763,429 | `data/local/normalized_diagnosis_dataset.csv` |
| `models/` | 40 | 5 | 4,167,273,416 | `models/openai-whisper-base/model.safetensors` |
| `tools/` | 7,300 | 1,861 | 91,851,207 | `tools/sherpa-onnx/.git/index` |
| `whisper_gue_ready/` | 8 | 1 | 1,526,583 | `whisper_gue_ready/README.md` |

Other top-level remote area:

- `venv/` exists as the remote Python environment. It is not SACA data or a
  model artifact and is intentionally not copied into Git; recreate it from the
  requirement files instead.

## Output Directory Inventory

No SACA output directory from `outputs/` is intentionally omitted.

| Output directory | Files | Bytes | Newest file |
| --- | ---: | ---: | --- |
| `audits/` | 15 | 142,354 | `outputs/audits/run4_checkpoint-200/test/mapping_candidates.tsv` |
| `checkpoints/` | 0 | 0 | Empty placeholder |
| `classifier_campaigns/` | 316 | 493,125,324 | `outputs/classifier_campaigns/diagnosis_profile_ladder_20260504_053452/full/xgb/multi/xgboost.joblib` |
| `classifier_diagnosis_expanded_intermediate_lr_20260503_145235/` | 6 | 8,435,253 | `metrics.json` |
| `classifier_diagnosis_expanded_intermediate_xgb_20260503_145235/` | 6 | 15,396,175 | `run_summary.json` |
| `classifier_diagnosis_multi_lr/` | 6 | 7,275,370 | `run_summary.json` |
| `classifier_diagnosis_multi_smoke_lr/` | 6 | 4,640,035 | `best_model.joblib` |
| `classifier_diagnosis_multi_xgb/` | 6 | 13,706,113 | `metrics.json` |
| `classifier_diagnosis_run1/` | 2 | 4,235 | `label_metadata.json` |
| `classifier_diagnosis_run1_parallel_20260503_071343/` | 2 | 4,235 | `label_metadata.json` |
| `classifier_diagnosis_single_lr/` | 6 | 7,274,584 | `logistic_regression.joblib` |
| `classifier_diagnosis_single_xgb/` | 6 | 20,156,334 | `best_model.joblib` |
| `exports/` | 22 | 1,041,280,316 | `outputs/exports/gue-whisper-base-run4-ckpt200-rc1/sherpa-onnx/decoder.onnx` |
| `flutter_models/` | 29 | 17,622,683 | `lr_balanced_single_flutter_onnx_20260504_063657/best_model.joblib` |
| `intermediate_datasets/` | 4 | 4,358,450 | `diagnosis_multi_dataset.expanded_20260503_145235.summary.json` |
| `local_data_audit/` | 0 | 0 | Empty placeholder |
| `logs/` | 96 | 2,094,504 | `outputs/logs/gue_small_11877466.out` |
| `whisper-base-gue-example-only-run4/` | 46 | 2,921,869,750 | `checkpoint-200/added_tokens.json` |
| `whisper-small-gue-example-only/` | 109 | 29,017,325,183 | `decode_audit_checkpoint_200_norm_metrics.txt` |
| `whisper-small-gue-example-only-run2/` | 39 | 8,719,682,232 | `processor_config.json` |
| `whisper-small-gue-example-only-run3/` | 31 | 6,781,435,481 | `tokenizer_config.json` |

## Current Best Gurindji Whisper Checkpoint

`outputs/current_best_checkpoint.txt` reports:

```text
current_best=/fred/oz396/dunguyen/saca_whisper/outputs/whisper-base-gue-example-only-run4/checkpoint-200
model=openai/whisper-base
run=whisper-base-gue-example-only-run4
job=11877466
validation_raw_wer=0.850450
validation_raw_cer=0.258774
validation_norm_wer=0.706564
validation_norm_cer=0.241265
test_raw_wer=0.818722
test_raw_cer=0.231899
test_norm_wer=0.662910
test_norm_cer=0.210436
previous_best=/fred/oz396/dunguyen/saca_whisper/outputs/whisper-small-gue-example-only/best-cer-checkpoint-200
previous_validation_raw_cer=0.322631
previous_validation_norm_cer=0.304173
promote_reason=beats previous validation gates and test metrics are strong; mapping remains empty
```

Interpretation: run4 improves character error rate over the previous
`whisper-small` baseline and is the current promoted Gurindji Whisper candidate,
but WER remains high. It is suitable for research/demo candidate evaluation, not
unreviewed public clinical speech recognition.

## Run4 Audit and Export Artifacts

Run4 audit files:

| Path | Bytes | Timestamp |
| --- | ---: | --- |
| `outputs/audits/run4_checkpoint-200/validation/decode_audit.tsv` | 32,519 | 2026-05-06 01:33 |
| `outputs/audits/run4_checkpoint-200/validation/decode_audit.txt` | 11,961 | 2026-05-06 01:33 |
| `outputs/audits/run4_checkpoint-200/validation/mapping_candidates.tsv` | 1,145 | 2026-05-06 01:33 |
| `outputs/audits/run4_checkpoint-200/test/decode_audit.tsv` | 41,657 | 2026-05-06 01:38 |
| `outputs/audits/run4_checkpoint-200/test/decode_audit.txt` | 15,217 | 2026-05-06 01:38 |
| `outputs/audits/run4_checkpoint-200/test/mapping_candidates.tsv` | 1,679 | 2026-05-06 01:38 |

Run4 export folder:
`outputs/exports/gue-whisper-base-run4-ckpt200-rc1/`

| Export artifact | Bytes | Timestamp |
| --- | ---: | --- |
| `ggml-gue-whisper-base-run4-ckpt200-rc1-f16.bin` | 147,951,482 | 2026-05-06 02:13 |
| `ggml-gue-whisper-base-run4-ckpt200-rc1-q5_0.bin` | 55,295,450 | 2026-05-06 02:13 |
| `sherpa-onnx/rc1-openai-whisper-base.pt` | 290,456,133 | 2026-05-06 02:34 |
| `sherpa-onnx/export-onnx-rc1.py` | 21,765 | 2026-05-06 02:37 |
| `sherpa-onnx/rc1-openai-whisper-base.pt-encoder.onnx.data` | 95,027,200 | 2026-05-06 02:37 |
| `sherpa-onnx/decoder.onnx` | 130,659,024 | 2026-05-06 02:38 |
| `sherpa-onnx/encoder.onnx` | 29,104,828 | 2026-05-06 02:38 |
| `sherpa-onnx/rc1-openai-whisper-base.pt-decoder.onnx` | 196,528,984 | 2026-05-06 02:38 |
| `sherpa-onnx/rc1-openai-whisper-base.pt-encoder.onnx` | 95,069,187 | 2026-05-06 02:38 |
| `sherpa-onnx/tokens.txt` | 816,730 | 2026-05-06 02:38 |
| `smoke/` files | 15 small text/audio/log files | 2026-05-06 02:13-02:14 |

## Classifier Metrics Summary

Important inspected classifier metrics include:

| Run | Accuracy | Notes |
| --- | ---: | --- |
| `classifier_diagnosis_multi_xgb/metrics.json` | 0.9650872818 | Strong 24-class XGBoost run documented as staged fallback evidence. |
| `classifier_diagnosis_single_xgb/metrics.json` | 0.9124087591 | Single-mode XGBoost run. |
| `classifier_diagnosis_multi_lr/metrics.json` | 0.1411192214 | Older multi LR run. |
| `classifier_diagnosis_single_lr/metrics.json` | 0.1411192214 | Older single LR run. |
| `classifier_diagnosis_expanded_intermediate_xgb_20260503_145235/metrics.json` | 0.1256038647 | Expanded-intermediate quick XGB run. |
| `classifier_diagnosis_expanded_intermediate_lr_20260503_145235/metrics.json` | 0.0701377706 | Expanded-intermediate LR run. |
| `flutter_models/lr_balanced_single_flutter_onnx_20260504_063657/metrics.json` | 0.9800498753 | Flutter-oriented LR export run. |
| `flutter_models/lr_balanced_single_onnx_20260504_063358/metrics.json` | 0.9900249377 | ONNX-oriented LR run. |
| `classifier_campaigns/diagnosis_profile_ladder_20260504_053452/balanced/lr/single/metrics.json` | 0.9900249377 | Latest ladder single LR result. |
| `classifier_campaigns/diagnosis_profile_ladder_20260504_053452/quick/lr/single/metrics.json` | 0.9850374065 | Quick LR single profile. |
| `classifier_campaigns/diagnosis_profile_ladder_fix_20260504_042808/quick/xgb/single/metrics.json` | 0.9675810474 | Earlier quick XGB single result. |

High offline split metrics are not clinical validation.

## Documentation Policy

- Large binary assets remain on HPC, Git LFS, or release storage; they are not
  copied into normal Git history.
- Metadata and summaries are documented here so every SACA remote output area is
  visible in the repository.
- Top-level `models/` and `tools/` are documented in the root summary because
  they are relevant to Whisper/Sherpa export provenance, even though their
  binary/vendor contents are not normal Git documentation material.
- Empty placeholders (`checkpoints/`, `local_data_audit/`) are documented because
  they exist on the remote output path.
- Re-run a fresh SSH inventory before making release claims from HPC outputs.

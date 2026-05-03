# Classifier Tuning Run Log

_Last updated: 2026-05-03_

## Locked baseline before profile ladder

Expanded intermediate diagnosis dataset baseline already available on `/fred` before
this campaign:

| Model | Profile | Macro-F1 | Accuracy | Output path |
| --- | --- | ---: | ---: | --- |
| LR | quick | 0.1929 | 0.0701 | `/fred/oz396/dunguyen/saca_whisper/outputs/classifier_diagnosis_expanded_intermediate_lr_20260503_145235` |
| XGB | quick | 0.3782 | 0.1256 | `/fred/oz396/dunguyen/saca_whisper/outputs/classifier_diagnosis_expanded_intermediate_xgb_20260503_145235` |

These numbers are the comparison floor for the new `quick -> balanced -> full`
submission campaign.

## Campaign submitted on 2026-05-03

- Campaign name: `diagnosis_profile_ladder_20260503_154451`
- Submission manifest:
  `/fred/oz396/dunguyen/saca_whisper/outputs/classifier_campaigns/diagnosis_profile_ladder_20260503_154451/submission_manifest.json`
- Campaign root:
  `/fred/oz396/dunguyen/saca_whisper/outputs/classifier_campaigns/diagnosis_profile_ladder_20260503_154451`

### Fixed knobs for this run batch

- `CV_FOLDS=3`
- `MAX_TEXT_FEATURES=10000`
- `SKIP_SHAP=1`
- `RUN_AUDIT=0`
- `LIVE_PROGRESS=1`
- `SEARCH_PROGRESS_EVERY_FITS=1`
- `MULTI_BUILD_INCLUDE_HEALTHCARE=1`
- `MULTI_BUILD_INCLUDE_MEDICAL_CONVERSATIONS=1`
- `MULTI_BUILD_INCLUDE_PREBUILT_NORMALIZED=0`

### Submitted jobs

Queue snapshot right after submission: all 6 jobs were accepted by Slurm and were
in `PENDING` state.

| Profile | Model | Job ID | Slurm job name | Queue state at log time | Walltime | Multi output |
| --- | --- | ---: | --- | --- | --- | --- |
| quick | LR | 11813149 | `saca_lr_quick` | `PENDING` | `01:00:00` | `/fred/oz396/dunguyen/saca_whisper/outputs/classifier_campaigns/diagnosis_profile_ladder_20260503_154451/quick/lr/multi` |
| quick | XGB | 11813150 | `saca_xgb_quick` | `PENDING` | `03:00:00` | `/fred/oz396/dunguyen/saca_whisper/outputs/classifier_campaigns/diagnosis_profile_ladder_20260503_154451/quick/xgb/multi` |
| balanced | LR | 11813151 | `saca_lr_balanced` | `PENDING` | `01:00:00` | `/fred/oz396/dunguyen/saca_whisper/outputs/classifier_campaigns/diagnosis_profile_ladder_20260503_154451/balanced/lr/multi` |
| balanced | XGB | 11813152 | `saca_xgb_balanced` | `PENDING` | `03:00:00` | `/fred/oz396/dunguyen/saca_whisper/outputs/classifier_campaigns/diagnosis_profile_ladder_20260503_154451/balanced/xgb/multi` |
| full | LR | 11813153 | `saca_lr_full` | `PENDING` | `02:00:00` | `/fred/oz396/dunguyen/saca_whisper/outputs/classifier_campaigns/diagnosis_profile_ladder_20260503_154451/full/lr/multi` |
| full | XGB | 11813154 | `saca_xgb_full` | `PENDING` | `08:00:00` | `/fred/oz396/dunguyen/saca_whisper/outputs/classifier_campaigns/diagnosis_profile_ladder_20260503_154451/full/xgb/multi` |

### Notes

- Every job in this campaign gets its own `OUT_SINGLE`, `OUT_MULTI`, and
  intermediate dataset paths so concurrent profile runs do not overwrite each
  other.
- The main comparison target is the `multi` scope under each profile/model pair.
- `full` XGB was submitted with the longer fallback walltime because the wrapper
  notes that full-profile runs need more room than the default `3h` budget.
- After jobs finish, append the new `macro-F1`, `accuracy`, and merged-winner
  summary here instead of overwriting the baseline section above.

## Status snapshot after campaign launch

Snapshot captured after the first ~30 minutes of scheduler/runtime activity:

| Job ID | Job name | Current status | Extra note |
| --- | --- | --- | --- |
| 11813149 | `saca_lr_quick` | `COMPLETED` | Finished in `00:18:06`; quick LR multi result reproduced the locked baseline with `macro-F1 0.1929`, `accuracy 0.0701`. |
| 11813150 | `saca_xgb_quick` | `PENDING` | Waiting in `milan-gpu` with reason `Priority`. |
| 11813151 | `saca_lr_balanced` | `RUNNING` | Active on node `dave147`; live log already shows fold-level progress for the balanced LR rung. |
| 11813152 | `saca_xgb_balanced` | `RUNNING` | Active on node `gina11`; live log shows steady XGBoost candidate/fold progress on the GPU rung. |
| 11813153 | `saca_lr_full` | `RUNNING` | Active on node `dave120`; full LR rung is progressing through the larger 36-fit search. |
| 11813154 | `saca_xgb_full` | `PENDING` | Waiting in `milan-gpu` with reason `Priority`. |

### First completed result in this campaign

- `11813149` (`saca_lr_quick`) completed successfully.
- Multi-scope metrics from
  `/fred/oz396/dunguyen/saca_whisper/outputs/classifier_campaigns/diagnosis_profile_ladder_20260503_154451/quick/lr/multi/metrics.json`:
  - `best_model`: `logistic_regression`
  - `f1_macro`: `0.19285928997609514`
  - `accuracy`: `0.0701377706208624`
- This matches the previously locked quick LR baseline to the displayed precision,
  which is a good sign that the new campaign plumbing did not perturb the quick
  LR path.

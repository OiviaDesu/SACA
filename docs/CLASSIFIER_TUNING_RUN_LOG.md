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

## Final status after all six jobs completed

All submitted jobs completed successfully with exit code `0:0`.

| Job ID | Job name | Final state | Elapsed | Timelimit |
| --- | --- | --- | --- | --- |
| 11813149 | `saca_lr_quick` | `COMPLETED` | `00:18:06` | `01:00:00` |
| 11813150 | `saca_xgb_quick` | `COMPLETED` | `00:10:13` | `03:00:00` |
| 11813151 | `saca_lr_balanced` | `COMPLETED` | `00:53:55` | `01:00:00` |
| 11813152 | `saca_xgb_balanced` | `COMPLETED` | `00:44:40` | `03:00:00` |
| 11813153 | `saca_lr_full` | `COMPLETED` | `01:41:24` | `02:00:00` |
| 11813154 | `saca_xgb_full` | `COMPLETED` | `03:06:10` | `08:00:00` |

## Final results by profile

### Multi scope (primary comparison target)

| Profile | Model | Macro-F1 | Accuracy | Best CV score | Summary |
| --- | --- | ---: | ---: | ---: | --- |
| quick | LR | `0.1929` | `0.0701` | `0.1519` | Reproduced the locked LR baseline almost exactly. |
| quick | XGB | `0.3782` | `0.1256` | `0.3688` | Best overall test result in this campaign. |
| balanced | LR | `0.1926` | `0.0701` | `0.1531` | Slightly better CV score, but no practical test gain. |
| balanced | XGB | `0.3780` | `0.1249` | `0.3703` | Slightly better CV score than quick, but slightly worse test macro-F1. |
| full | LR | `0.1926` | `0.0701` | `0.1531` | Same outcome as balanced despite the larger search. |
| full | XGB | `0.3780` | `0.1249` | `0.3703` | Same outcome as balanced despite the much larger search. |

### Single scope (normalized diagnosis dataset)

| Profile | Model | Macro-F1 | Accuracy | Best CV score |
| --- | --- | ---: | ---: | ---: |
| quick | LR | `0.0985` | `0.1147` | `0.0731` |
| quick | XGB | `0.9687` | `0.9676` | `0.9345` |
| balanced | LR | `0.0985` | `0.1147` | `0.0742` |
| balanced | XGB | `0.9654` | `0.9651` | `0.9385` |
| full | LR | `0.0985` | `0.1147` | `0.0742` |
| full | XGB | `0.9654` | `0.9651` | `0.9385` |

## Interpretation

### 1. Winner by profile

- `XGBoost` won every profile on the primary `multi` scope.
- The practical ranking on `multi` was:
  1. `quick xgb` (`macro-F1 0.3782`)
  2. `balanced xgb` (`macro-F1 0.3780`)
  3. `full xgb` (`macro-F1 0.3780`)
  4. all LR variants around `0.1926` to `0.1929`

### 2. ROI of tuning profiles

- `quick` already captured essentially the best observed `multi` test result for
  both LR and XGB.
- `balanced` improved the **cross-validation** score slightly for both models,
  but that did not translate into better held-out `multi` performance.
- `full` gave no measurable gain over `balanced` for either LR or XGB.

### 3. Runtime efficiency

- `quick xgb` finished in `10m 13s` and still delivered the best `multi`
  macro-F1 in this campaign.
- `balanced xgb` took `44m 40s` for essentially the same result.
- `full xgb` took `3h 06m 10s` and still converged to the same winning params as
  `balanced` on the `multi` scope.
- `lr full` also failed to beat `lr balanced`, so the larger LR search was not
  worth the extra runtime either.

### 4. Data difficulty gap: single vs multi

- The `single` scope remains dramatically easier than the expanded `multi`
  scope.
- `xgb` achieved about `0.965` to `0.969` macro-F1 on `single`, but only about
  `0.378` on `multi`.
- This confirms the real bottleneck is not search-budget size alone: the
  expanded dataset (`27941` rows / `47` labels) is simply a much harder problem
  than the normalized single dataset (`2002` rows / `24` labels).

### 5. Resource notes

- All jobs were safely under their walltime limits; none timed out.
- The job footers consistently reported low CPU usage and over-provisioned RAM.
- `full xgb` also used only about `38.8%` of its `8h` fallback walltime, so the
  fallback was safe but conservative.

## Practical recommendation after this campaign

1. Freeze `quick xgb` as the strongest practical winner from the current tuning
   ladder.
2. Do **not** spend more compute on `balanced` or `full` profile escalation for
   the current dataset setup.
3. Move the next improvement cycle to **data / label policy work**:
   - label consolidation,
   - text-quality filtering,
   - adapter work for additional usable sources,
   - then rerun the ladder starting from `quick` again.

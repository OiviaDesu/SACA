#!/usr/bin/env bash
# =============================================================================
# submit_classifier_profile_campaign.sh
#
# Submit the full diagnosis classifier tuning ladder on OzSTAR in one shot:
#   - LR quick / balanced / full
#   - XGB quick / balanced / full
#
# Each submitted job gets isolated output and intermediate-dataset paths so the
# concurrent runs do not overwrite one another.
# =============================================================================

set -euo pipefail

WORK_DIR="${WORK_DIR:-/fred/oz396/dunguyen/saca_whisper}"
CODE_DIR="${CODE_DIR:-${WORK_DIR}/code}"
OUTPUT_ROOT="${OUTPUT_ROOT:-${WORK_DIR}/outputs/classifier_campaigns}"
TIMESTAMP="${TIMESTAMP:-$(date +%Y%m%d_%H%M%S)}"
CAMPAIGN_NAME="${CAMPAIGN_NAME:-diagnosis_profile_ladder_${TIMESTAMP}}"
CAMPAIGN_DIR="${OUTPUT_ROOT}/${CAMPAIGN_NAME}"
SUBMISSION_LOG="${CAMPAIGN_DIR}/submission_manifest.json"

PROFILES=(quick balanced full)
MODELS=(lr xgb)

MULTI_BUILD_INCLUDE_HEALTHCARE="${MULTI_BUILD_INCLUDE_HEALTHCARE:-1}"
MULTI_BUILD_INCLUDE_MEDICAL_CONVERSATIONS="${MULTI_BUILD_INCLUDE_MEDICAL_CONVERSATIONS:-1}"
MULTI_BUILD_INCLUDE_PREBUILT_NORMALIZED="${MULTI_BUILD_INCLUDE_PREBUILT_NORMALIZED:-0}"
CV_FOLDS="${CV_FOLDS:-3}"
MAX_TEXT_FEATURES="${MAX_TEXT_FEATURES:-10000}"
SKIP_SHAP="${SKIP_SHAP:-1}"
RUN_AUDIT="${RUN_AUDIT:-0}"
RUN_ONNX_EXPORT="${RUN_ONNX_EXPORT:-0}"
VERBOSE_TRAIN="${VERBOSE_TRAIN:-1}"
LIVE_PROGRESS="${LIVE_PROGRESS:-1}"
SEARCH_PROGRESS_EVERY_FITS="${SEARCH_PROGRESS_EVERY_FITS:-1}"
MIN_CLASS_COUNT="${MIN_CLASS_COUNT:-2}"

mkdir -p "${CAMPAIGN_DIR}"

job_time_for() {
  local model="$1"
  local profile="$2"

  if [[ "${model}" == "xgb" && "${profile}" == "full" ]]; then
    printf '%s' '08:00:00'
    return
  fi

  if [[ "${model}" == "lr" && "${profile}" == "full" ]]; then
    printf '%s' '02:00:00'
    return
  fi

  if [[ "${model}" == "xgb" ]]; then
    printf '%s' '03:00:00'
    return
  fi

  printf '%s' '01:00:00'
}

script_for() {
  local model="$1"
  if [[ "${model}" == "lr" ]]; then
    printf '%s' "${CODE_DIR}/hpc/slurm_train_classifier_lr.sh"
    return
  fi
  printf '%s' "${CODE_DIR}/hpc/slurm_train_classifier_xgb.sh"
}

manifest_entries=()
submitted_job_ids=()

submit_job() {
  local profile="$1"
  local model="$2"
  local script_path
  local job_time
  local job_name
  local run_root
  local out_single
  local out_multi
  local out_onnx
  local intermediate_dir
  local intermediate_dataset
  local intermediate_summary
  local xgb_device
  local export_vars
  local job_id

  script_path="$(script_for "${model}")"
  job_time="$(job_time_for "${model}" "${profile}")"
  job_name="saca_${model}_${profile}"

  run_root="${CAMPAIGN_DIR}/${profile}/${model}"
  out_single="${run_root}/single"
  out_multi="${run_root}/multi"
  out_onnx="${run_root}/onnx"
  intermediate_dir="${run_root}/intermediate"
  intermediate_dataset="${intermediate_dir}/diagnosis_multi_dataset.csv"
  intermediate_summary="${intermediate_dir}/diagnosis_multi_dataset.summary.json"

  if [[ "${model}" == "lr" ]]; then
    xgb_device='cpu'
  else
    xgb_device='cuda'
  fi

  mkdir -p "${run_root}" "${intermediate_dir}"

  export_vars="ALL"
  export_vars+=",WORK_DIR=${WORK_DIR}"
  export_vars+=",CODE_DIR=${CODE_DIR}"
  export_vars+=",TUNING_PROFILE=${profile}"
  export_vars+=",CV_FOLDS=${CV_FOLDS}"
  export_vars+=",MAX_TEXT_FEATURES=${MAX_TEXT_FEATURES}"
  export_vars+=",MIN_CLASS_COUNT=${MIN_CLASS_COUNT}"
  export_vars+=",XGB_DEVICE=${xgb_device}"
  export_vars+=",SKIP_SHAP=${SKIP_SHAP}"
  export_vars+=",RUN_AUDIT=${RUN_AUDIT}"
  export_vars+=",RUN_ONNX_EXPORT=${RUN_ONNX_EXPORT}"
  export_vars+=",VERBOSE_TRAIN=${VERBOSE_TRAIN}"
  export_vars+=",LIVE_PROGRESS=${LIVE_PROGRESS}"
  export_vars+=",SEARCH_PROGRESS_EVERY_FITS=${SEARCH_PROGRESS_EVERY_FITS}"
  export_vars+=",MULTI_BUILD_INCLUDE_HEALTHCARE=${MULTI_BUILD_INCLUDE_HEALTHCARE}"
  export_vars+=",MULTI_BUILD_INCLUDE_MEDICAL_CONVERSATIONS=${MULTI_BUILD_INCLUDE_MEDICAL_CONVERSATIONS}"
  export_vars+=",MULTI_BUILD_INCLUDE_PREBUILT_NORMALIZED=${MULTI_BUILD_INCLUDE_PREBUILT_NORMALIZED}"
  export_vars+=",INTERMEDIATE_DATASET_DIR=${intermediate_dir}"
  export_vars+=",MULTI_INTERMEDIATE_DATASET=${intermediate_dataset}"
  export_vars+=",MULTI_INTERMEDIATE_SUMMARY=${intermediate_summary}"
  export_vars+=",OUT_SINGLE=${out_single}"
  export_vars+=",OUT_MULTI=${out_multi}"
  export_vars+=",OUT_ONNX=${out_onnx}"

  job_id="$(sbatch \
    --parsable \
    --job-name="${job_name}" \
    --time="${job_time}" \
    --export="${export_vars}" \
    "${script_path}")"

  submitted_job_ids+=("${job_id}")
  manifest_entries+=("    {\"profile\": \"${profile}\", \"model\": \"${model}\", \"job_id\": \"${job_id}\", \"job_name\": \"${job_name}\", \"slurm_time\": \"${job_time}\", \"script\": \"${script_path}\", \"out_single\": \"${out_single}\", \"out_multi\": \"${out_multi}\", \"intermediate_dataset\": \"${intermediate_dataset}\", \"intermediate_summary\": \"${intermediate_summary}\"}")

  printf '[submit] %-8s %-3s -> job %s\n' "${profile}" "${model}" "${job_id}"
}

for profile in "${PROFILES[@]}"; do
  for model in "${MODELS[@]}"; do
    submit_job "${profile}" "${model}"
  done
done

{
  echo '{'
  echo "  \"campaign_name\": \"${CAMPAIGN_NAME}\"," 
  echo "  \"submitted_at\": \"$(date --iso-8601=seconds)\"," 
  echo "  \"work_dir\": \"${WORK_DIR}\"," 
  echo "  \"output_root\": \"${CAMPAIGN_DIR}\"," 
  echo '  "profiles": ["quick", "balanced", "full"],'
  echo '  "models": ["lr", "xgb"],'
  echo '  "jobs": ['
  for idx in "${!manifest_entries[@]}"; do
    if [[ "${idx}" -gt 0 ]]; then
      echo ','
    fi
    printf '%s' "${manifest_entries[$idx]}"
  done
  echo ''
  echo '  ]'
  echo '}'
} > "${SUBMISSION_LOG}"

echo "[manifest] ${SUBMISSION_LOG}"
echo "[campaign] ${CAMPAIGN_NAME}"
if [[ "${#submitted_job_ids[@]}" -gt 0 ]]; then
  echo "[watch] squeue -j $(IFS=,; echo "${submitted_job_ids[*]}")"
fi

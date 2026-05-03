#!/usr/bin/env bash
# Common helpers for SACA classifier Slurm jobs.
# Source this file from sbatch wrapper scripts; do not submit it directly.

set -euo pipefail

WORK_DIR="${WORK_DIR:-/fred/oz396/dunguyen/saca_whisper}"
CODE_DIR="${CODE_DIR:-${WORK_DIR}/code}"
DATA_DIR="${DATA_DIR:-${WORK_DIR}/data}"
VENV_DIR="${VENV_DIR:-${WORK_DIR}/venv}"
LOG_DIR="${LOG_DIR:-${WORK_DIR}/outputs/logs}"

MODEL_KIND="${MODEL_KIND:-both}"
TUNING_PROFILE="${TUNING_PROFILE:-balanced}"
CV_FOLDS="${CV_FOLDS:-3}"
MAX_TEXT_FEATURES="${MAX_TEXT_FEATURES:-10000}"
MIN_CLASS_COUNT="${MIN_CLASS_COUNT:-2}"
XGB_DEVICE="${XGB_DEVICE:-cuda}"
SKIP_SHAP="${SKIP_SHAP:-1}"
RUN_AUDIT="${RUN_AUDIT:-1}"
RUN_ONNX_EXPORT="${RUN_ONNX_EXPORT:-0}"
VERBOSE_TRAIN="${VERBOSE_TRAIN:-1}"
LIVE_PROGRESS="${LIVE_PROGRESS:-1}"
SEARCH_PROGRESS_EVERY_FITS="${SEARCH_PROGRESS_EVERY_FITS:-1}"

LABEL_COL="${LABEL_COL:-diagnosis_label}"
TASK_NAME="${TASK_NAME:-diagnosis}"

SINGLE_DATASET="${SINGLE_DATASET:-${DATA_DIR}/local/normalized_diagnosis_dataset.csv}"
MULTI_DATASET_A="${MULTI_DATASET_A:-${DATA_DIR}/local/gretel_symptom_to_diagnosis.csv}"
MULTI_DATASET_B="${MULTI_DATASET_B:-${DATA_DIR}/local/Symptom2Disease.csv}"
MULTI_DATASET_C="${MULTI_DATASET_C:-${DATA_DIR}/local/normalized_diagnosis_dataset.csv}"
MULTI_OPTIONAL_HEALTHCARE_DATASET="${MULTI_OPTIONAL_HEALTHCARE_DATASET:-${DATA_DIR}/local/Healthcare.csv}"
MULTI_OPTIONAL_MEDICAL_CONVERSATIONS_DATASET="${MULTI_OPTIONAL_MEDICAL_CONVERSATIONS_DATASET:-${DATA_DIR}/local/medical_conversations.csv}"
MULTI_BUILD_INCLUDE_HEALTHCARE="${MULTI_BUILD_INCLUDE_HEALTHCARE:-0}"
MULTI_BUILD_INCLUDE_MEDICAL_CONVERSATIONS="${MULTI_BUILD_INCLUDE_MEDICAL_CONVERSATIONS:-0}"
MULTI_BUILD_INCLUDE_PREBUILT_NORMALIZED="${MULTI_BUILD_INCLUDE_PREBUILT_NORMALIZED:-0}"

INTERMEDIATE_DATASET_DIR="${INTERMEDIATE_DATASET_DIR:-${WORK_DIR}/outputs/intermediate_datasets}"
MULTI_INTERMEDIATE_DATASET="${MULTI_INTERMEDIATE_DATASET:-${INTERMEDIATE_DATASET_DIR}/diagnosis_multi_dataset.csv}"
MULTI_INTERMEDIATE_SUMMARY="${MULTI_INTERMEDIATE_SUMMARY:-${INTERMEDIATE_DATASET_DIR}/diagnosis_multi_dataset.summary.json}"

OUT_SINGLE="${OUT_SINGLE:-${WORK_DIR}/outputs/classifier_diagnosis_run1}"
OUT_MULTI="${OUT_MULTI:-${WORK_DIR}/outputs/classifier_diagnosis_multi}"
OUT_ONNX="${OUT_ONNX:-${WORK_DIR}/outputs/classifier_onnx}"

GCC_MODULE="${GCC_MODULE:-gcc/13.2.0}"
PYTHON_MODULE="${PYTHON_MODULE:-python/3.11.5}"
CUDA_MODULE="${CUDA_MODULE:-cuda/12.1.1}"

TEXT_COLS=(symptoms_text transcript_text)
CATEGORICAL_COLS=(body_location prior_medications language source)
NUMERIC_COLS=(duration_hours duration_days)
MULTI_DATASET_FILES=("${MULTI_DATASET_A}" "${MULTI_DATASET_B}" "${MULTI_DATASET_C}")
COMMON_TRAIN_ARGS=()

print_classifier_header() {
  mkdir -p "${LOG_DIR}"
  echo "=========================================="
  echo "Job ID      : ${SLURM_JOB_ID:-local-shell}"
  echo "Node        : $(hostname)"
  echo "Started     : $(date)"
  echo "Model kind  : ${MODEL_KIND}"
  echo "Profile     : ${TUNING_PROFILE}"
  echo "CV folds    : ${CV_FOLDS}"
  echo "Max TF-IDF  : ${MAX_TEXT_FEATURES}"
  echo "Min class   : ${MIN_CLASS_COUNT}"
  echo "XGB device  : ${XGB_DEVICE}"
  echo "Skip SHAP   : ${SKIP_SHAP}"
  echo "Run audit   : ${RUN_AUDIT}"
  echo "Run ONNX    : ${RUN_ONNX_EXPORT}"
  echo "Verbose     : ${VERBOSE_TRAIN}"
  echo "Live prog   : ${LIVE_PROGRESS}"
  echo "Prog every  : ${SEARCH_PROGRESS_EVERY_FITS} fit(s)"
  echo "Multi+HC    : ${MULTI_BUILD_INCLUDE_HEALTHCARE}"
  echo "Multi+Conv  : ${MULTI_BUILD_INCLUDE_MEDICAL_CONVERSATIONS}"
  echo "Multi+Norm  : ${MULTI_BUILD_INCLUDE_PREBUILT_NORMALIZED}"
  echo "CPUs        : ${SLURM_CPUS_PER_TASK:-n/a}"
  echo "=========================================="
}

load_classifier_environment() {
  module purge
  echo "Loading GCC module: ${GCC_MODULE}"
  module load "${GCC_MODULE}"
  echo "Loading Python module: ${PYTHON_MODULE}"
  module load "${PYTHON_MODULE}"

  if [[ "${MODEL_KIND}" != "lr" || "${XGB_DEVICE}" == "cuda" ]]; then
    echo "Loading CUDA module: ${CUDA_MODULE}"
    module load "${CUDA_MODULE}"
  else
    echo "Skipping CUDA module for LR-only CPU job"
  fi

  source "${VENV_DIR}/bin/activate"
  export OMP_NUM_THREADS="${SLURM_CPUS_PER_TASK:-1}"
  export PYTHONUNBUFFERED=1
}

validate_model_kind() {
  case "${MODEL_KIND}" in
    lr|xgb|both)
      ;;
    *)
      echo "Unsupported MODEL_KIND='${MODEL_KIND}'. Expected lr, xgb, or both." >&2
      exit 1
      ;;
  esac
}

build_common_train_args() {
  COMMON_TRAIN_ARGS=(
    --task "${TASK_NAME}"
    --text-cols "${TEXT_COLS[@]}"
    --categorical-cols "${CATEGORICAL_COLS[@]}"
    --numeric-cols "${NUMERIC_COLS[@]}"
    --tuning-profile "${TUNING_PROFILE}"
    --cv-folds "${CV_FOLDS}"
    --max-text-features "${MAX_TEXT_FEATURES}"
    --min-class-count "${MIN_CLASS_COUNT}"
    --xgb-device "${XGB_DEVICE}"
  )

  if [[ "${SKIP_SHAP}" == "1" ]]; then
    COMMON_TRAIN_ARGS+=(--skip-shap)
  fi

  if [[ "${VERBOSE_TRAIN}" == "1" ]]; then
    COMMON_TRAIN_ARGS+=(--verbose)
  fi

  if [[ "${LIVE_PROGRESS}" == "1" ]]; then
    COMMON_TRAIN_ARGS+=(
      --live-progress
      --progress-log-every-fits "${SEARCH_PROGRESS_EVERY_FITS}"
    )
  fi
}

run_classifier_audit() {
  if [[ "${RUN_AUDIT}" != "1" ]]; then
    return
  fi

  echo ""
  echo "--- Step 1: audit_local_data ---"
  python -u "${CODE_DIR}/audit_local_data.py"
  echo "Audit done. Summary: ${WORK_DIR}/outputs/local_data_audit/audit_summary.json"
}

run_classifier_single_dataset() {
  echo ""
  echo "--- Step 2: train ${MODEL_KIND} on normalized_diagnosis_dataset.csv ---"
  python -u "${CODE_DIR}/train_classifier.py" \
    --data "${SINGLE_DATASET}" \
    --label-col "${LABEL_COL}" \
    --model "${MODEL_KIND}" \
    "${COMMON_TRAIN_ARGS[@]}" \
    --output-dir "${OUT_SINGLE}"

  echo "Single-file run artifacts: ${OUT_SINGLE}"
}

run_classifier_multi_dataset_build() {
  mkdir -p "${INTERMEDIATE_DATASET_DIR}"

  local build_inputs=("${MULTI_DATASET_A}" "${MULTI_DATASET_B}")

  if [[ "${MULTI_BUILD_INCLUDE_HEALTHCARE}" == "1" ]]; then
    build_inputs+=("${MULTI_OPTIONAL_HEALTHCARE_DATASET}")
  fi

  if [[ "${MULTI_BUILD_INCLUDE_MEDICAL_CONVERSATIONS}" == "1" ]]; then
    build_inputs+=("${MULTI_OPTIONAL_MEDICAL_CONVERSATIONS_DATASET}")
  fi

  if [[ "${MULTI_BUILD_INCLUDE_PREBUILT_NORMALIZED}" == "1" ]]; then
    build_inputs+=("${MULTI_DATASET_C}")
  fi

  echo ""
  echo "--- Step 3: build intermediate diagnosis dataset ---"
  python -u "${CODE_DIR}/normalize_datasets.py" \
    --input-paths "${build_inputs[@]}" \
    --output "${MULTI_INTERMEDIATE_DATASET}" \
    --summary-output "${MULTI_INTERMEDIATE_SUMMARY}" \
    --min-class-count "${MIN_CLASS_COUNT}"

  echo "Intermediate multi dataset: ${MULTI_INTERMEDIATE_DATASET}"
  echo "Intermediate multi summary: ${MULTI_INTERMEDIATE_SUMMARY}"
}

run_classifier_multi_dataset() {
  echo ""
  echo "--- Step 4: train ${MODEL_KIND} on built intermediate dataset ---"
  python -u "${CODE_DIR}/train_classifier.py" \
    --data "${MULTI_INTERMEDIATE_DATASET}" \
    --label-col "${LABEL_COL}" \
    --model "${MODEL_KIND}" \
    "${COMMON_TRAIN_ARGS[@]}" \
    --output-dir "${OUT_MULTI}"

  echo "Multi-file run artifacts: ${OUT_MULTI}"
}

run_classifier_optional_onnx_export() {
  if [[ "${RUN_ONNX_EXPORT}" != "1" ]]; then
    return
  fi

  if [[ "${MODEL_KIND}" == "xgb" ]]; then
    echo ""
    echo "--- Step 5: skip ONNX export for xgb-only job ---"
    echo "ONNX export is only supported for LR after final model selection."
    return
  fi

  echo ""
  echo "--- Step 5: export LR ONNX ---"
  python -u "${CODE_DIR}/train_classifier.py" \
    --data "${SINGLE_DATASET}" \
    --label-col "${LABEL_COL}" \
    --model lr \
    --export-onnx \
    "${COMMON_TRAIN_ARGS[@]}" \
    --output-dir "${OUT_ONNX}"

  echo "ONNX artifact: ${OUT_ONNX}"
}

run_classifier_pipeline_job() {
  validate_model_kind
  print_classifier_header
  load_classifier_environment
  build_common_train_args
  run_classifier_audit
  run_classifier_single_dataset
  run_classifier_multi_dataset_build
  run_classifier_multi_dataset
  run_classifier_optional_onnx_export

  echo ""
  echo "=========================================="
  echo "Classifier job finished: $(date)"
  echo "Results under: ${WORK_DIR}/outputs/"
  echo "=========================================="
}

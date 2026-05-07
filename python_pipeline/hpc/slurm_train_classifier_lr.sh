#!/usr/bin/env bash
# =============================================================================
# slurm_train_classifier_lr.sh
#
# LR-only classifier job for OzSTAR.
# Runs both the single normalized dataset and the merged multi-dataset pipeline.
#
# Resource choice is based on historical combined jobs:
# - job 11808388 (16 CPU) reached XGBoost after ~15 minutes
# - job 11808404 (32 CPU) also reached XGBoost after ~15 minutes
# => LR did not show a meaningful speedup from 16 -> 32 CPU, so 16 CPU is the
#    recommended budget for the split LR job.
#
# Submit from a login node with:
#   sbatch /fred/oz396/dunguyen/saca_whisper/code/slurm_train_classifier_lr.sh
# Optional notifications:
#   sbatch --mail-user=your.email@example.com /fred/oz396/dunguyen/saca_whisper/code/slurm_train_classifier_lr.sh
# =============================================================================

#SBATCH --job-name=saca_cls_lr
#SBATCH --output=/fred/oz396/dunguyen/saca_whisper/outputs/logs/classifier_lr_%j.out
#SBATCH --error=/fred/oz396/dunguyen/saca_whisper/outputs/logs/classifier_lr_%j.err
#SBATCH --time=01:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=12G
#SBATCH --tmp=10G
#SBATCH --mail-type=BEGIN,END,FAIL

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${WORK_DIR:-/fred/oz396/dunguyen/saca_whisper}"
COMMON_SCRIPT="${WORK_DIR}/code/slurm_train_classifier_common.sh"
MODEL_KIND="lr"
TUNING_PROFILE="${TUNING_PROFILE:-balanced}"
CV_FOLDS="${CV_FOLDS:-3}"
MAX_TEXT_FEATURES="${MAX_TEXT_FEATURES:-10000}"
XGB_DEVICE="${XGB_DEVICE:-cpu}"
SKIP_SHAP="${SKIP_SHAP:-1}"
RUN_AUDIT="${RUN_AUDIT:-1}"
RUN_ONNX_EXPORT="${RUN_ONNX_EXPORT:-0}"
OUT_SINGLE="${OUT_SINGLE:-${WORK_DIR}/outputs/classifier_diagnosis_single_lr}"
OUT_MULTI="${OUT_MULTI:-${WORK_DIR}/outputs/classifier_diagnosis_multi_lr}"
OUT_ONNX="${OUT_ONNX:-${WORK_DIR}/outputs/classifier_onnx_lr}"

if [[ ! -f "${COMMON_SCRIPT}" ]]; then
	COMMON_SCRIPT="${SCRIPT_DIR}/slurm_train_classifier_common.sh"
fi

source "${COMMON_SCRIPT}"
run_classifier_pipeline_job

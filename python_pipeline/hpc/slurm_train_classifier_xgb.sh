#!/usr/bin/env bash
# =============================================================================
# slurm_train_classifier_xgb.sh
#
# XGBoost-only classifier job for OzSTAR.
# Experimental after job 11822367: quick XGB underfit badly on the expanded multi
# dataset. Prefer LR balanced for production unless retuning XGB deliberately.
# Runs both the single normalized dataset and the merged multi-dataset pipeline.
#
# Resource choice is based on historical combined jobs:
# - jobs 11808388 (16 CPU) and 11808404 (32 CPU) both timed out at 4h in the
#   XGBoost phase while sustaining ~95-97% CPU and GPU utilization
# - current code now uses the lighter balanced tuning profile by default
# => keep a dedicated GPU and 32 CPU for preprocessing/GridSearchCV, with a 3h
#    limit for the split XGB job and an 8h fallback only for full-profile runs.
#
# Submit from a login node with:
#   sbatch /fred/oz396/dunguyen/saca_whisper/code/slurm_train_classifier_xgb.sh
# Optional notifications:
#   sbatch --mail-user=your.email@example.com /fred/oz396/dunguyen/saca_whisper/code/slurm_train_classifier_xgb.sh
# =============================================================================

#SBATCH --job-name=saca_cls_xgb
#SBATCH --output=/fred/oz396/dunguyen/saca_whisper/outputs/logs/classifier_xgb_%j.out
#SBATCH --error=/fred/oz396/dunguyen/saca_whisper/outputs/logs/classifier_xgb_%j.err
#SBATCH --time=03:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=20G
#SBATCH --gres=gpu:1
#SBATCH --tmp=10G
#SBATCH --mail-type=BEGIN,END,FAIL

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${WORK_DIR:-/fred/oz396/dunguyen/saca_whisper}"
COMMON_SCRIPT="${WORK_DIR}/code/slurm_train_classifier_common.sh"
MODEL_KIND="xgb"
TUNING_PROFILE="${TUNING_PROFILE:-balanced}"
CV_FOLDS="${CV_FOLDS:-3}"
MAX_TEXT_FEATURES="${MAX_TEXT_FEATURES:-10000}"
XGB_DEVICE="${XGB_DEVICE:-cuda}"
SKIP_SHAP="${SKIP_SHAP:-1}"
RUN_AUDIT="${RUN_AUDIT:-1}"
RUN_ONNX_EXPORT="${RUN_ONNX_EXPORT:-0}"
OUT_SINGLE="${OUT_SINGLE:-${WORK_DIR}/outputs/classifier_diagnosis_single_xgb}"
OUT_MULTI="${OUT_MULTI:-${WORK_DIR}/outputs/classifier_diagnosis_multi_xgb}"
OUT_ONNX="${OUT_ONNX:-${WORK_DIR}/outputs/classifier_onnx_xgb_unused}"

if [[ ! -f "${COMMON_SCRIPT}" ]]; then
	COMMON_SCRIPT="${SCRIPT_DIR}/slurm_train_classifier_common.sh"
fi

source "${COMMON_SCRIPT}"
run_classifier_pipeline_job

#!/usr/bin/env bash
# =============================================================================
# slurm_train_classifier.sh
#
# Legacy combined Slurm batch job for SACA classifier training on OzSTAR.
#
# Prefer the split wrappers for day-to-day runs:
#   sbatch /fred/oz396/dunguyen/saca_whisper/code/slurm_train_classifier_lr.sh
#   sbatch /fred/oz396/dunguyen/saca_whisper/code/slurm_train_classifier_xgb.sh
#
# This combined job is kept as a compatibility fallback and now delegates to the
# shared runner used by the split jobs.
#
# Submit from farnarkle1 or farnarkle2:
#   sbatch /fred/oz396/dunguyen/saca_whisper/code/slurm_train_classifier.sh
# Optional notifications:
#   sbatch --mail-user=your.email@example.com /fred/oz396/dunguyen/saca_whisper/code/slurm_train_classifier.sh
#
# Monitor:
#   squeue -u <your-username>
#   tail -f /fred/oz396/dunguyen/saca_whisper/outputs/logs/classifier_<jobid>.out
# =============================================================================

#SBATCH --job-name=saca_classifier
#SBATCH --output=/fred/oz396/dunguyen/saca_whisper/outputs/logs/classifier_%j.out
#SBATCH --error=/fred/oz396/dunguyen/saca_whisper/outputs/logs/classifier_%j.err

# --- Time & resources --------------------------------------------------------
# Balanced profile trims the XGBoost search budget while preserving a full
# fallback via TUNING_PROFILE=full if needed.
#SBATCH --time=08:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=64
#SBATCH --mem=20G
# XGBoost stages use GPU when available
#SBATCH --gres=gpu:1

# Local SSD for any temp writes
#SBATCH --tmp=10G

#SBATCH --mail-type=BEGIN,END,FAIL

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="/fred/oz396/dunguyen/saca_whisper"
COMMON_SCRIPT="${WORK_DIR}/code/slurm_train_classifier_common.sh"
MODEL_KIND="${MODEL_KIND:-both}"
OUT_SINGLE="${OUT_SINGLE:-${WORK_DIR}/outputs/classifier_diagnosis_run1}"
OUT_MULTI="${OUT_MULTI:-${WORK_DIR}/outputs/classifier_diagnosis_multi}"
OUT_ONNX="${OUT_ONNX:-${WORK_DIR}/outputs/classifier_onnx}"
TUNING_PROFILE="${TUNING_PROFILE:-balanced}"
CV_FOLDS="${CV_FOLDS:-3}"
MAX_TEXT_FEATURES="${MAX_TEXT_FEATURES:-10000}"
XGB_DEVICE="${XGB_DEVICE:-cuda}"
SKIP_SHAP="${SKIP_SHAP:-1}"
RUN_AUDIT="${RUN_AUDIT:-1}"
RUN_ONNX_EXPORT="${RUN_ONNX_EXPORT:-1}"

if [[ ! -f "${COMMON_SCRIPT}" ]]; then
	COMMON_SCRIPT="${SCRIPT_DIR}/slurm_train_classifier_common.sh"
fi

source "${COMMON_SCRIPT}"
run_classifier_pipeline_job

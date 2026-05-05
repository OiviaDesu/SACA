#!/usr/bin/env bash
# Submit on OzSTAR login node:
#   sbatch python_pipeline/hpc/slurm_train_whisper_gue_example_only.sh

#SBATCH --job-name=saca_gue_small
#SBATCH --output=/fred/oz396/dunguyen/saca_whisper/outputs/logs/gue_small_%j.out
#SBATCH --error=/fred/oz396/dunguyen/saca_whisper/outputs/logs/gue_small_%j.err
#SBATCH --time=04:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --gres=gpu:1
#SBATCH --mem=24G
#SBATCH --tmp=40G
#SBATCH --mail-type=END,FAIL

set -euo pipefail

WORK_DIR="/fred/oz396/dunguyen/saca_whisper"
CODE_DIR="${WORK_DIR}/code"
REPO_DIR="${REPO_DIR:-/home/dunguyen/git/SACA}"
DATA_DIR="${DATA_DIR:-${REPO_DIR}/python_pipeline/whisper_gue_ready/example_only}"
RUN_NAME="${RUN_NAME:-whisper-small-gue-example-only-run2}"
OUTPUT_DIR="${OUTPUT_DIR:-${WORK_DIR}/outputs/${RUN_NAME}}"
VENV_DIR="${WORK_DIR}/venv"
MODEL_NAME="${MODEL_NAME:-${WORK_DIR}/models/openai-whisper-small}"

mkdir -p "${WORK_DIR}/outputs/logs" "${OUTPUT_DIR}"

echo "Job ID: ${SLURM_JOB_ID}"
echo "Node: $(hostname)"
echo "Started: $(date)"
echo "Work dir: ${WORK_DIR}"
echo "Data dir: ${DATA_DIR}"
echo "Output dir: ${OUTPUT_DIR}"
echo "Model: ${MODEL_NAME}"
echo "Run name: ${RUN_NAME}"

module purge
module load "${GCC_MODULE:-gcc/13.2.0}"
module load "${PYTHON_MODULE:-python/3.11.5}"
module load "${CUDA_MODULE:-cuda/12.1.1}"

source "${VENV_DIR}/bin/activate"

export HF_HOME="${JOBFS}/hf_cache"
export TRANSFORMERS_CACHE="${HF_HOME}/transformers"
export HF_DATASETS_CACHE="${HF_HOME}/datasets"
mkdir -p "${HF_HOME}" "${TRANSFORMERS_CACHE}" "${HF_DATASETS_CACHE}"

echo "Manifest counts:"
wc -l "${DATA_DIR}/train.jsonl" "${DATA_DIR}/validation.jsonl" "${DATA_DIR}/test.jsonl"
echo "GPU info:"
nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader

python "${CODE_DIR}/python_pipeline/training/train_whisper_gue.py" \
  --data-dir "${DATA_DIR}" \
  --output-dir "${OUTPUT_DIR}" \
  --model-name "${MODEL_NAME}" \
  --num-proc 1 \
  --per-device-train-batch-size 4 \
  --gradient-accumulation-steps 4 \
  --per-device-eval-batch-size 4 \
  --learning-rate 5e-6 \
  --warmup-steps 0 \
  --warmup-ratio 0.1 \
  --num-train-epochs 3 \
  --eval-steps 100 \
  --save-steps 100 \
  --logging-steps 10 \
  --generation-max-length 225 \
  --early-stopping-patience 2 \
  --save-total-limit 3 \
  --fp16 \
  --gradient-checkpointing

echo "Finished: $(date)"

#!/usr/bin/env bash
# =============================================================================
# slurm_finetune_whisper.sh
#
# Slurm batch job: fine-tune openai/whisper-small on Gurindji + English data.
#
# Submit from the OzSTAR login node (farnarkle1 or farnarkle2):
#   sbatch slurm_finetune_whisper.sh
# Optional notifications:
#   sbatch --mail-user=your.email@example.com slurm_finetune_whisper.sh
#
# Monitor:
#   squeue -u <your-username>
#   tail -f /fred/oz396/dunguyen/saca_whisper/outputs/logs/whisper_%j.out
# =============================================================================

#SBATCH --job-name=saca_whisper_ft
#SBATCH --output=/fred/oz396/dunguyen/saca_whisper/outputs/logs/whisper_%j.out
#SBATCH --error=/fred/oz396/dunguyen/saca_whisper/outputs/logs/whisper_%j.err

# --- Time & resources --------------------------------------------------------
# Whisper-small fine-tuning on ~500â€“5000 samples typically finishes in 2â€“6 h.
# Request 12 h to be safe; Slurm will release the allocation early if it exits.
#SBATCH --time=12:00:00

# One GPU node (Slurm auto-selects the appropriate partition)
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --gres=gpu:1
#SBATCH --mem=64G

# Local SSD scratch for caching HuggingFace datasets during the run
#SBATCH --tmp=40G

# Send email notifications (optional â€” comment out if not wanted)
#SBATCH --mail-type=BEGIN,END,FAIL

# =============================================================================
# Environment
# =============================================================================
set -euo pipefail

WORK_DIR="/fred/oz396/dunguyen/saca_whisper"
CODE_DIR="${WORK_DIR}/code"
DATA_DIR="${WORK_DIR}/data"
OUTPUT_DIR="${WORK_DIR}/outputs"
VENV_DIR="${WORK_DIR}/venv"

echo "=========================================="
echo "Job ID      : ${SLURM_JOB_ID}"
echo "Node        : $(hostname)"
echo "Started     : $(date)"
echo "Work dir    : ${WORK_DIR}"
echo "JOBFS (SSD) : ${JOBFS}"
echo "=========================================="

# Load matching Python + CUDA modules.
# OzSTAR docs: always load required modules before activating a venv.
module purge
GCC_MODULE="${GCC_MODULE:-gcc/13.2.0}"
PYTHON_MODULE="${PYTHON_MODULE:-python/3.11.5}"
CUDA_MODULE="${CUDA_MODULE:-cuda/12.1.1}"
echo "Loading GCC module: ${GCC_MODULE}"
module load "${GCC_MODULE}"
echo "Loading Python module: ${PYTHON_MODULE}"
module load "${PYTHON_MODULE}"
echo "Loading CUDA module: ${CUDA_MODULE}"
module load "${CUDA_MODULE}"

source "${VENV_DIR}/bin/activate"

# Redirect HuggingFace cache to fast local SSD for this job
export HF_HOME="${JOBFS}/hf_cache"
export TRANSFORMERS_CACHE="${JOBFS}/hf_cache/transformers"
export HF_DATASETS_CACHE="${JOBFS}/hf_cache/datasets"
mkdir -p "${HF_HOME}" "${TRANSFORMERS_CACHE}" "${HF_DATASETS_CACHE}"

# Verify GPU is visible
echo "--- GPU info ---"
nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader
echo "----------------"

# =============================================================================
# Run fine-tuning
# =============================================================================
python "${CODE_DIR}/training/finetune_whisper.py" \
  --mode train \
  --data-root        "${DATA_DIR}/corpus" \
  --manifest         "${DATA_DIR}/manifests/manifest.csv" \
  --output-dir       "${OUTPUT_DIR}/checkpoints" \
  --model-name       "openai/whisper-small" \
  --num-proc         8 \
  --per-device-train-batch-size  8 \
  --per-device-eval-batch-size   4 \
  --gradient-accumulation-steps 4 \
  --learning-rate    1e-5 \
  --warmup-steps     200 \
  --max-steps        4000 \
  --eval-steps       500 \
  --save-steps       500 \
  --logging-steps    25 \
  --generation-max-length 225 \
  --fp16 \
  --gradient-checkpointing \
  --seed             42

echo "=========================================="
echo "Training finished: $(date)"
echo "Checkpoints saved to: ${OUTPUT_DIR}/checkpoints"
echo "=========================================="

# =============================================================================
# Optional: export to ggml for on-device use
# =============================================================================
# Uncomment after training is verified to produce a good checkpoint.
#
# BEST_CKPT=$(ls -td "${OUTPUT_DIR}/checkpoints/checkpoint-"* | head -1)
# echo "==> Exporting best checkpoint: ${BEST_CKPT}"
# python "${CODE_DIR}/03_export_ggml.py" \
#   --model_path "${BEST_CKPT}" \
#   --quant      Q5_0 \
#   --output     "${OUTPUT_DIR}/ggml-saca-whisper-small-q5_0.bin"

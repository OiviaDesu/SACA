#!/usr/bin/env bash
# =============================================================================
# hpc_prepare_data.sh
#
# Run once from the OzSTAR login node (farnarkle1 or farnarkle2) to:
#   1. Create the working directory tree under /fred/oz396/dunguyen/
#   2. Sync the python_pipeline code from your home directory
#   3. Build a Python virtual environment with all dependencies
#   4. Validate the audio manifest (dry-run with no GPU needed)
#
# Usage:
#   bash hpc_prepare_data.sh [--data-root /path/to/corpus]
#
# After this script finishes, submit the training job with:
#   sbatch slurm_finetune_whisper.sh
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Paths ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â adjust FRED_PROJECT if the project ID ever changes
# ---------------------------------------------------------------------------
FRED_PROJECT="/fred/oz396"
WORK_DIR="${FRED_PROJECT}/dunguyen/saca_whisper"
CODE_DIR="${WORK_DIR}/code"
DATA_DIR="${WORK_DIR}/data"
OUTPUT_DIR="${WORK_DIR}/outputs"
VENV_DIR="${WORK_DIR}/venv"

# Source repo (assumed to be in $HOME when this runs on the login node)
REPO_DIR="${HOME}/SACA"

# Sub-dirs for the two training branches
DATA_CSV_DIR="${DATA_DIR}/local"       # classifier CSV datasets
DATA_AUDIO_DIR="${DATA_DIR}/corpus"    # Whisper audio corpus

# Optional: override the audio corpus root via CLI argument
DATA_ROOT="${DATA_AUDIO_DIR}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --data-root) DATA_ROOT="$2"; shift 2 ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# 1. Directory structure
# ---------------------------------------------------------------------------
echo "==> Creating directory structure under ${WORK_DIR}"
mkdir -p "${CODE_DIR}"
mkdir -p "${DATA_CSV_DIR}"          # classifier CSV datasets
mkdir -p "${DATA_AUDIO_DIR}"        # Whisper audio corpus
mkdir -p "${DATA_DIR}/manifests"
mkdir -p "${OUTPUT_DIR}/checkpoints"
mkdir -p "${OUTPUT_DIR}/logs"
mkdir -p "${OUTPUT_DIR}/local_data_audit"

# ---------------------------------------------------------------------------
# 2. Sync pipeline code
# ---------------------------------------------------------------------------
echo "==> Syncing python_pipeline from ${REPO_DIR}"
rsync -av --delete \
  --exclude '__pycache__' \
  --exclude '*.pyc' \
  --exclude '.pytest_cache' \
  "${REPO_DIR}/python_pipeline/" \
  "${CODE_DIR}/"

# Also copy the Gurindji lexicon asset (small, safe to commit)
rsync -av \
  "${REPO_DIR}/assets/data/" \
  "${DATA_DIR}/assets/"

# Sync the CSV datasets for classifier training
echo "==> Syncing CSV datasets to ${DATA_CSV_DIR}"
rsync -av --include='*.csv' --include='*.json' --include='*.jsonl' \
  --exclude='*' \
  "${REPO_DIR}/python_pipeline/data/" \
  "${DATA_CSV_DIR}/"

echo "==> Code synced to ${CODE_DIR}"

# ---------------------------------------------------------------------------
# 3. Python environment
# ---------------------------------------------------------------------------
echo "==> Loading Python module"
# OzSTAR/NT: check available versions with 'module spider python'
module purge
GCC_MODULE="${GCC_MODULE:-gcc/13.2.0}"
PYTHON_MODULE="${PYTHON_MODULE:-python/3.11.5}"
echo "    Using ${GCC_MODULE}"
module load "${GCC_MODULE}"
echo "    Using ${PYTHON_MODULE}"
module load "${PYTHON_MODULE}"
# If a CUDA-enabled PyTorch build is needed, also load:
# module load cuda/12.1.1

if [[ ! -d "${VENV_DIR}" ]]; then
  echo "==> Creating virtual environment at ${VENV_DIR}"
  python -m venv --system-site-packages "${VENV_DIR}"
fi

# shellcheck disable=SC1091
source "${VENV_DIR}/bin/activate"

echo "==> Installing / upgrading Python dependencies"
pip install --upgrade pip --quiet
pip install --quiet \
  torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
pip install --quiet -r "${CODE_DIR}/requirements/whisper.txt"
pip install --quiet -r "${CODE_DIR}/requirements/classifier.txt"

echo "==> Python environment ready: $(python --version)"

# ---------------------------------------------------------------------------
# 4. Validate manifest (no GPU required ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â runs on login node quickly)
# ---------------------------------------------------------------------------
if [[ -f "${DATA_DIR}/manifests/manifest.csv" ]]; then
  echo "==> Validating manifest (--mode validate)"
  python "${CODE_DIR}/training/finetune_whisper.py" \
    --mode validate \
    --data-root "${DATA_ROOT}" \
    --manifest "${DATA_DIR}/manifests/manifest.csv" \
    --output-dir "${OUTPUT_DIR}"
else
  echo "==> No manifest found at ${DATA_DIR}/manifests/manifest.csv"
  echo "    Place a CSV or JSONL file there with columns:"
  echo "      audio, text, language, speaker_id, source_id"
  echo "    Then re-run this script or call validate manually:"
  echo "      python ${CODE_DIR}/training/finetune_whisper.py \\"
  echo "        --mode validate \\"
  echo "        --data-root ${DATA_ROOT} \\"
  echo "        --manifest ${DATA_DIR}/manifests/manifest.csv \\"
  echo "        --output-dir ${OUTPUT_DIR}"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
cat <<EOF

=============================================================================
Setup complete.  Directory layout:

  ${WORK_DIR}/
  ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ code/          ÃƒÂ¢Ã¢â‚¬Â Ã‚Â python_pipeline scripts (synced from repo)
  ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ data/
  ÃƒÂ¢Ã¢â‚¬ÂÃ¢â‚¬Å¡   ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ local/     ÃƒÂ¢Ã¢â‚¬Â Ã‚Â classifier CSV datasets (synced from repo)
  ÃƒÂ¢Ã¢â‚¬ÂÃ¢â‚¬Å¡   ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ corpus/    ÃƒÂ¢Ã¢â‚¬Â Ã‚Â Whisper audio files (upload manually)
  ÃƒÂ¢Ã¢â‚¬ÂÃ¢â‚¬Å¡   ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ manifests/ ÃƒÂ¢Ã¢â‚¬Â Ã‚Â manifest.csv / manifest.jsonl for Whisper
  ÃƒÂ¢Ã¢â‚¬ÂÃ¢â‚¬Å¡   ÃƒÂ¢Ã¢â‚¬ÂÃ¢â‚¬ÂÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ assets/    ÃƒÂ¢Ã¢â‚¬Â Ã‚Â Gurindji lexicon (synced from repo)
  ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ outputs/
  ÃƒÂ¢Ã¢â‚¬ÂÃ¢â‚¬Å¡   ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ checkpoints/
  ÃƒÂ¢Ã¢â‚¬ÂÃ¢â‚¬Å¡   ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ logs/
  ÃƒÂ¢Ã¢â‚¬ÂÃ¢â‚¬Å¡   ÃƒÂ¢Ã¢â‚¬ÂÃ¢â‚¬ÂÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ local_data_audit/
  ÃƒÂ¢Ã¢â‚¬ÂÃ¢â‚¬ÂÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ venv/          ÃƒÂ¢Ã¢â‚¬Â Ã‚Â Python virtual environment

Next steps ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â Branch 1 (Classifier):
  sbatch ${CODE_DIR}/hpc/slurm_train_classifier.sh

Next steps ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â Branch 2 (Whisper ASR):
  1. Upload audio to ${DATA_DIR}/corpus/
  2. Create manifest at ${DATA_DIR}/manifests/manifest.csv
  3. sbatch ${CODE_DIR}/hpc/slurm_finetune_whisper.sh
=============================================================================
EOF

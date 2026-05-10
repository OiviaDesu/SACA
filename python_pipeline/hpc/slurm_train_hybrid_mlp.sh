#!/usr/bin/env bash
#SBATCH --job-name=saca-hybrid-mlp
#SBATCH --output=/fred/oz396/dunguyen/SACA_ML/outputs/hybrid_mlp/slurm-%j.out
#SBATCH --error=/fred/oz396/dunguyen/SACA_ML/outputs/hybrid_mlp/slurm-%j.err
#SBATCH --time=04:00:00
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G

set -euo pipefail

CODE_DIR="/home/dunguyen/git/SACA/python_pipeline"
WORK_ROOT="/fred/oz396/dunguyen/SACA_ML"
DATA_ROOT="$WORK_ROOT/data"
OUTPUT_DIR="$WORK_ROOT/outputs/hybrid_mlp"

mkdir -p "$OUTPUT_DIR"
cd "$CODE_DIR"

python3 - <<'PY'
import pandas, numpy, sklearn, scipy, joblib
print("Python ML deps OK", pandas.__version__, sklearn.__version__)
PY

python3 -m training.hybrid_mlp train \
  --data-root "$DATA_ROOT" \
  --output "$OUTPUT_DIR/hybrid_mlp.joblib" \
  --min-class-count 10 \
  --max-text-features 3000 \
  --hidden-layers 128,128 \
  --max-iter 80

python3 -m training.hybrid_mlp predict \
  --model "$OUTPUT_DIR/hybrid_mlp.joblib" \
  --text "fever cough sore throat" \
  --top-k 5 > "$OUTPUT_DIR/predict_smoke.json"

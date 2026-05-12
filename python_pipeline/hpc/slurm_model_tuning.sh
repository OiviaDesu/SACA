#!/usr/bin/env bash
#SBATCH --job-name=saca-model-tune
#SBATCH --output=/fred/oz396/dunguyen/SACA_ML/outputs/model_tuning/slurm-%j.out
#SBATCH --error=/fred/oz396/dunguyen/SACA_ML/outputs/model_tuning/slurm-%j.err
#SBATCH --time=06:00:00
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G

set -euo pipefail

CODE_DIR="/home/dunguyen/git/SACA/python_pipeline"
WORK_ROOT="/fred/oz396/dunguyen/SACA_ML"
DATA_ROOT="$WORK_ROOT/data"
OUTPUT_ROOT="$WORK_ROOT/outputs/model_tuning"

mkdir -p "$OUTPUT_ROOT"
cd "$CODE_DIR"

python3 - <<'PY'
import pandas, numpy, sklearn, scipy, joblib
print("Python ML deps OK", pandas.__version__, sklearn.__version__)
PY

python3 -m training.benchmark_model_tuning \
  --data-root "$DATA_ROOT" \
  --output-root "$OUTPUT_ROOT" \
  --min-class-count 10 \
  --max-text-features 3000 \
  --mlp-max-iter 80 \
  --logreg-max-iter 400 \
  --test-size 0.2 \
  --random-state 42

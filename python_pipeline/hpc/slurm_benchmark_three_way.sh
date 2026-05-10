#!/usr/bin/env bash
#SBATCH --job-name=saca-3way-bench
#SBATCH --output=/fred/oz396/dunguyen/SACA_ML/outputs/benchmark_three_way/slurm-%j.out
#SBATCH --error=/fred/oz396/dunguyen/SACA_ML/outputs/benchmark_three_way/slurm-%j.err
#SBATCH --time=04:00:00
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G

set -euo pipefail

CODE_DIR="/home/dunguyen/git/SACA/python_pipeline"
WORK_ROOT="/fred/oz396/dunguyen/SACA_ML"
DATA_ROOT="$WORK_ROOT/data"
OUTPUT_ROOT="$WORK_ROOT/outputs/benchmark_three_way"

mkdir -p "$OUTPUT_ROOT"
cd "$CODE_DIR"

python3 - <<'PY'
import pandas, numpy, sklearn, scipy, joblib
print("Python ML deps OK", pandas.__version__, sklearn.__version__)
PY

python3 -m training.benchmark_three_way \
  --data-root "$DATA_ROOT" \
  --output-root "$OUTPUT_ROOT" \
  --min-class-count 10 \
  --max-text-features 3000 \
  --hidden-layers 128,128 \
  --max-iter 80 \
  --test-size 0.2 \
  --random-state 42

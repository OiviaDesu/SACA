#!/usr/bin/env bash
#SBATCH --job-name=saca-gue-norm
#SBATCH --output=/fred/oz396/dunguyen/SACA_ML/outputs/gurindji_normalization/slurm-%j.out
#SBATCH --error=/fred/oz396/dunguyen/SACA_ML/outputs/gurindji_normalization/slurm-%j.err
#SBATCH --time=02:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G

set -euo pipefail

CODE_DIR="/home/dunguyen/git/SACA/python_pipeline"
WORK_ROOT="/fred/oz396/dunguyen/SACA_ML"
DATA_ROOT="$WORK_ROOT/data"
OUTPUT_ROOT="$WORK_ROOT/outputs/gurindji_normalization"
DICTIONARY="$WORK_ROOT/data/raw/gurindji/gurindji_dict_medical.csv"

mkdir -p "$OUTPUT_ROOT"
cd "$CODE_DIR"

python3 - <<'PY'
import pandas, numpy, sklearn, scipy, joblib
print("Python ML deps OK", pandas.__version__, sklearn.__version__)
PY

python3 -m training.benchmark_gurindji_normalization \
  --data-root "$DATA_ROOT" \
  --dictionary "$DICTIONARY" \
  --output-root "$OUTPUT_ROOT" \
  --min-class-count 10 \
  --max-text-features 3000 \
  --test-size 0.2 \
  --random-state 42

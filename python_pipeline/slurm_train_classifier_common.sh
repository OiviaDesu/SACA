#!/usr/bin/env bash
set -euo pipefail
exec "$(dirname "$0")/hpc/slurm_train_classifier_common.sh" "$@"

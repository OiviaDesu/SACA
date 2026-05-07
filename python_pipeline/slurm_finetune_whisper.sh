#!/usr/bin/env bash
set -euo pipefail
exec "$(dirname "$0")/hpc/slurm_finetune_whisper.sh" "$@"

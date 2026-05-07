#!/usr/bin/env bash
set -euo pipefail
exec "$(dirname "$0")/hpc/hpc_prepare_data.sh" "$@"

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

require_cmd python3
require_cmd uv

mkdir -p "$RUN_DIR_CONTAINER"

log "Recording container environment"
{
  date
  echo
  python3 --version
  echo
  python3 - <<'PY'
import torch
print("torch:", torch.__version__)
print("cuda_available:", torch.cuda.is_available())
print("cuda_device_count:", torch.cuda.device_count())
PY
  echo
  nvidia-smi || true
} >"$RUN_DIR_CONTAINER/env.txt" 2>&1

log "Installing custom SGLang from $SGL_REPO_CONTAINER/python"
uv pip install --no-deps -e "$SGL_REPO_CONTAINER/python"

log "Verifying SGLang import path"
python3 - <<'PY' | tee "$RUN_DIR_CONTAINER/sglang_import.txt"
import inspect
import sglang
print(getattr(sglang, "__version__", "no_version"))
print(inspect.getfile(sglang))
PY

log "Container initialization complete."

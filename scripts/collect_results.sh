#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

mkdir -p "$RUN_DIR_CONTAINER"

log "Collecting run artifacts into $RUN_DIR_CONTAINER"

{
  echo "RUN_ID=$RUN_ID"
  echo "DATE=$(date -Is)"
  echo "HOSTNAME=$(hostname)"
  echo "MODEL_PATH=$MODEL_PATH"
  echo "API_BASE=${API_BASE:-http://127.0.0.1:${SERVER_PORT}}"
  echo "SGLANG_SERVER_ARGS=${SGLANG_SERVER_ARGS:-}"
  echo
  python3 --version 2>/dev/null || true
  echo
  nvidia-smi 2>/dev/null || true
  echo
  if [[ -d "$SGL_REPO_CONTAINER/.git" ]]; then
    git -C "$SGL_REPO_CONTAINER" rev-parse HEAD 2>/dev/null || true
    git -C "$SGL_REPO_CONTAINER" status --short 2>/dev/null || true
  fi
} >"$RUN_DIR_CONTAINER/run_summary.txt" 2>&1

if [[ -s "$RUN_DIR_CONTAINER/server.pid" ]] && kill -0 "$(cat "$RUN_DIR_CONTAINER/server.pid")" >/dev/null 2>&1; then
  ps -fp "$(cat "$RUN_DIR_CONTAINER/server.pid")" >"$RUN_DIR_CONTAINER/server_process.txt" 2>&1 || true
fi

if [[ -f "$RUN_DIR_CONTAINER/correctness/summary.json" ]]; then
  cp "$RUN_DIR_CONTAINER/correctness/summary.json" "$RUN_DIR_CONTAINER/correctness_summary.json"
fi

if [[ -f "$RUN_DIR_CONTAINER/speed/result.json" ]]; then
  cp "$RUN_DIR_CONTAINER/speed/result.json" "$RUN_DIR_CONTAINER/speed_summary.json"
fi

log "Collected artifacts:"
find "$RUN_DIR_CONTAINER" -maxdepth 2 -type f | sort

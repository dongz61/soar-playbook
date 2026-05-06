#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

require_cmd bash

API_BASE="${API_BASE:-http://127.0.0.1:${SERVER_PORT}}"

mkdir -p "$RUN_DIR_CONTAINER/speed"

[[ -f "$TOOLKIT_CONTAINER/bench_serving.sh" ]] || die "missing bench_serving.sh: $TOOLKIT_CONTAINER/bench_serving.sh"

log "Running speed evaluation"
log "API_BASE=$API_BASE"
log "SPEED_DATA_S1=${SPEED_DATA_S1:-}"
log "SPEED_DATA_S8=${SPEED_DATA_S8:-}"
log "SPEED_DATA_SMAX=${SPEED_DATA_SMAX:-}"

(
  cd "$TOOLKIT_CONTAINER"
  bash bench_serving.sh "$API_BASE"
) 2>&1 | tee "$RUN_DIR_CONTAINER/speed/bench.log"

tail -n 1 "$RUN_DIR_CONTAINER/speed/bench.log" >"$RUN_DIR_CONTAINER/speed/result.json" || true

log "Speed results: $RUN_DIR_CONTAINER/speed"

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

require_cmd python3
require_cmd curl

API_BASE="${API_BASE:-http://127.0.0.1:${SERVER_PORT}}"
SERVER_LOG="${SERVER_LOG:-$RUN_DIR_CONTAINER/server.log}"
SERVER_PID_FILE="${SERVER_PID_FILE:-$RUN_DIR_CONTAINER/server.pid}"
SGLANG_SERVER_ARGS="${SGLANG_SERVER_ARGS:---disable-radix-cache --attention-backend minicpm_flashinfer --chunked-prefill-size 8192 --skip-server-warmup --dense-as-sparse}"

mkdir -p "$RUN_DIR_CONTAINER"

if [[ -s "$SERVER_PID_FILE" ]] && kill -0 "$(cat "$SERVER_PID_FILE")" >/dev/null 2>&1; then
  die "server already running with pid $(cat "$SERVER_PID_FILE")"
fi

log "Starting SGLang server on ${SERVER_HOST}:${SERVER_PORT}"
log "SGLANG_SERVER_ARGS=${SGLANG_SERVER_ARGS}"

python3 -m sglang.launch_server \
  --model-path "$MODEL_PATH" \
  --host "$SERVER_HOST" \
  --port "$SERVER_PORT" \
  $SGLANG_SERVER_ARGS \
  >"$SERVER_LOG" 2>&1 &

echo "$!" >"$SERVER_PID_FILE"

log "Waiting for server: $API_BASE/v1/models"
for _ in $(seq 1 120); do
  if curl -fsS "$API_BASE/v1/models" >/dev/null 2>&1; then
    log "Server is ready."
    exit 0
  fi
  if ! kill -0 "$(cat "$SERVER_PID_FILE")" >/dev/null 2>&1; then
    tail -n 80 "$SERVER_LOG" >&2 || true
    die "server process exited before becoming ready"
  fi
  sleep 5
done

tail -n 120 "$SERVER_LOG" >&2 || true
die "server did not become ready in time"

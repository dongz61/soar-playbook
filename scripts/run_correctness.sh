#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

require_cmd python3

API_BASE="${API_BASE:-http://127.0.0.1:${SERVER_PORT}}"
CORRECTNESS_DATA="${CORRECTNESS_DATA:-$TOOLKIT_CONTAINER/eval_dataset/perf_public_set.jsonl}"
CORRECTNESS_CONCURRENCY="${CORRECTNESS_CONCURRENCY:-32}"
CORRECTNESS_NUM_SAMPLES="${CORRECTNESS_NUM_SAMPLES:-}"
CORRECTNESS_VERBOSE="${CORRECTNESS_VERBOSE:-0}"

mkdir -p "$RUN_DIR_CONTAINER/correctness"

[[ -f "$TOOLKIT_CONTAINER/eval_model.py" ]] || die "missing eval_model.py: $TOOLKIT_CONTAINER/eval_model.py"
[[ -f "$CORRECTNESS_DATA" ]] || die "missing correctness dataset: $CORRECTNESS_DATA"

log "Running correctness evaluation"
log "API_BASE=$API_BASE"
log "DATA=$CORRECTNESS_DATA"

pushd "$TOOLKIT_CONTAINER" >/dev/null

cmd=(
  python3 eval_model.py
  --api_base "$API_BASE"
  --model_path "$MODEL_PATH"
  --data_path "$CORRECTNESS_DATA"
  --concurrency "$CORRECTNESS_CONCURRENCY"
)

if [[ -n "$CORRECTNESS_NUM_SAMPLES" ]]; then
  cmd+=(--num_samples "$CORRECTNESS_NUM_SAMPLES")
fi

if [[ "$CORRECTNESS_VERBOSE" == "1" ]]; then
  cmd+=(--verbose)
fi

"${cmd[@]}" 2>&1 | tee "$RUN_DIR_CONTAINER/correctness/eval.log"

latest_output="$(find outputs -mindepth 1 -maxdepth 1 -type d -printf '%T@ %p\n' 2>/dev/null | sort -nr | awk 'NR==1 {print $2}')"
if [[ -n "${latest_output:-}" && -d "$latest_output" ]]; then
  cp -a "$latest_output"/. "$RUN_DIR_CONTAINER/correctness/"
fi

popd >/dev/null

log "Correctness results: $RUN_DIR_CONTAINER/correctness"

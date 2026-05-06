#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

require_cmd docker

[[ -d "$SGL_REPO_HOST" ]] || die "missing SGLang repo: $SGL_REPO_HOST"
[[ -d "$TOOLKIT_HOST" ]] || die "missing SOAR-Toolkit repo: $TOOLKIT_HOST"
[[ -d "$PLAYBOOK_HOST" ]] || die "missing playbook repo: $PLAYBOOK_HOST"

mkdir -p "$RUN_DIR_HOST"
write_run_metadata

if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
  die "container already exists: $CONTAINER_NAME"
fi

log "Starting container: $CONTAINER_NAME"
docker run -d \
  --gpus all \
  --name "$CONTAINER_NAME" \
  --ipc=host \
  --network=host \
  -e RUN_ID="$RUN_ID" \
  -e MODEL_PATH="$MODEL_PATH" \
  -e SERVER_HOST="$SERVER_HOST" \
  -e SERVER_PORT="$SERVER_PORT" \
  -e SGL_BRANCH="$SGL_BRANCH" \
  -e SGL_COMMIT="$SGL_COMMIT" \
  -e TOOLKIT_BRANCH="$TOOLKIT_BRANCH" \
  -e TOOLKIT_COMMIT="$TOOLKIT_COMMIT" \
  -v "$SGL_REPO_HOST:$SGL_REPO_CONTAINER" \
  -v "$TOOLKIT_HOST:$TOOLKIT_CONTAINER" \
  -v "$PLAYBOOK_HOST:$PLAYBOOK_CONTAINER" \
  -w "$WORKSPACE_CONTAINER" \
  "$SOAR_IMAGE" \
  sleep infinity

log "Container started."
log "Enter it with:"
log "docker exec -it $CONTAINER_NAME bash"

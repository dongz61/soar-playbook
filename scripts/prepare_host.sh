#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

require_cmd docker
require_cmd git

log "Pulling SOAR image: $SOAR_IMAGE"
docker pull "$SOAR_IMAGE"

repo_checkout "$SGL_REPO_HOST" "$SGL_REPO_URL" "$SGL_BRANCH" "$SGL_COMMIT"
repo_checkout "$TOOLKIT_HOST" "$TOOLKIT_REPO_URL" "$TOOLKIT_BRANCH" "$TOOLKIT_COMMIT"

mkdir -p "$RUN_DIR_HOST"
write_run_metadata

log "Prepared host workspace: $WORKSPACE_HOST"
log "Run directory: $RUN_DIR_HOST"

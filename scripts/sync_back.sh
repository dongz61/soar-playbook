#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

DEST="${SYNC_DEST:-}"

[[ -d "$RUN_DIR_HOST" || -d "$RUN_DIR_CONTAINER" ]] || die "missing run directory for RUN_ID=$RUN_ID"

if [[ -z "$DEST" ]]; then
  log "No SYNC_DEST set. Results are already in: $RUN_DIR_HOST"
  log "Set SYNC_DEST=user@host:/path or /local/path to copy them elsewhere."
  exit 0
fi

require_cmd rsync

SRC="$RUN_DIR_HOST/"
if [[ ! -d "$RUN_DIR_HOST" && -d "$RUN_DIR_CONTAINER" ]]; then
  SRC="$RUN_DIR_CONTAINER/"
fi

log "Syncing $SRC -> $DEST"
rsync -av --delete "$SRC" "$DEST"

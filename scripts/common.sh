#!/usr/bin/env bash
set -euo pipefail

SOAR_IMAGE="${SOAR_IMAGE:-modelbest-registry.cn-beijing.cr.aliyuncs.com/public/soar-toolkit:latest}"

SGL_REPO_URL="${SGL_REPO_URL:-https://github.com/dongz61/sgl-soar.git}"
SGL_BRANCH="${SGL_BRANCH:-soar-base}"
SGL_COMMIT="${SGL_COMMIT:-}"

TOOLKIT_REPO_URL="${TOOLKIT_REPO_URL:-https://github.com/OpenBMB/SOAR-Toolkit.git}"
TOOLKIT_BRANCH="${TOOLKIT_BRANCH:-main}"
TOOLKIT_COMMIT="${TOOLKIT_COMMIT:-}"

WORKSPACE_HOST="${WORKSPACE_HOST:-$HOME/soar-workspace}"
SGL_REPO_HOST="${SGL_REPO_HOST:-$WORKSPACE_HOST/sgl-soar}"
TOOLKIT_HOST="${TOOLKIT_HOST:-$WORKSPACE_HOST/SOAR-Toolkit}"
PLAYBOOK_HOST="${PLAYBOOK_HOST:-$WORKSPACE_HOST/soar-playbook}"

WORKSPACE_CONTAINER="${WORKSPACE_CONTAINER:-/workspace}"
SGL_REPO_CONTAINER="${SGL_REPO_CONTAINER:-$WORKSPACE_CONTAINER/sgl-soar}"
TOOLKIT_CONTAINER="${TOOLKIT_CONTAINER:-$WORKSPACE_CONTAINER/SOAR-Toolkit}"
PLAYBOOK_CONTAINER="${PLAYBOOK_CONTAINER:-$WORKSPACE_CONTAINER/soar-playbook}"

RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
RUN_DIR_HOST="${RUN_DIR_HOST:-$PLAYBOOK_HOST/runs/$RUN_ID}"
RUN_DIR_CONTAINER="${RUN_DIR_CONTAINER:-$PLAYBOOK_CONTAINER/runs/$RUN_ID}"

CONTAINER_NAME="${CONTAINER_NAME:-soar-$RUN_ID}"
SERVER_HOST="${SERVER_HOST:-0.0.0.0}"
SERVER_PORT="${SERVER_PORT:-30000}"
MODEL_PATH="${MODEL_PATH:-/models/MiniCPM-SALA}"

log() {
  printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

repo_checkout() {
  local repo_dir="$1"
  local repo_url="$2"
  local branch="$3"
  local commit="$4"

  if [[ -d "$repo_dir/.git" ]]; then
    log "Updating repo: $repo_dir"
    git -C "$repo_dir" fetch --all --tags
  else
    log "Cloning repo: $repo_url -> $repo_dir"
    mkdir -p "$(dirname "$repo_dir")"
    git clone --branch "$branch" "$repo_url" "$repo_dir"
  fi

  if [[ -n "$commit" ]]; then
    git -C "$repo_dir" checkout "$commit"
  else
    git -C "$repo_dir" checkout "$branch"
    git -C "$repo_dir" pull --ff-only origin "$branch"
  fi
}

write_run_metadata() {
  mkdir -p "$RUN_DIR_HOST"
  {
    echo "RUN_ID=$RUN_ID"
    echo "SOAR_IMAGE=$SOAR_IMAGE"
    echo "CONTAINER_NAME=$CONTAINER_NAME"
    echo "SGL_REPO_URL=$SGL_REPO_URL"
    echo "SGL_BRANCH=$SGL_BRANCH"
    echo "SGL_COMMIT=${SGL_COMMIT:-$(git -C "$SGL_REPO_HOST" rev-parse HEAD 2>/dev/null || true)}"
    echo "TOOLKIT_REPO_URL=$TOOLKIT_REPO_URL"
    echo "TOOLKIT_BRANCH=$TOOLKIT_BRANCH"
    echo "TOOLKIT_COMMIT=${TOOLKIT_COMMIT:-$(git -C "$TOOLKIT_HOST" rev-parse HEAD 2>/dev/null || true)}"
    echo "MODEL_PATH=$MODEL_PATH"
    echo "SERVER_HOST=$SERVER_HOST"
    echo "SERVER_PORT=$SERVER_PORT"
  } >"$RUN_DIR_HOST/metadata.env"
}

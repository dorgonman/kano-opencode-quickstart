#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd -P)"

# Source git-helpers.sh from kano-git-master-skill
GIT_HELPERS="${REPO_ROOT}/skills/kano-git-master-skill/scripts/git-helpers.sh"
if [[ ! -f "$GIT_HELPERS" ]]; then
  echo "ERROR: git-helpers.sh not found at: $GIT_HELPERS" >&2
  echo "       Please ensure kano-git-master-skill submodule is initialized" >&2
  exit 1
fi

source "$GIT_HELPERS"

UPDATE_SUBMODULES=false
REBASE_SUBMODULES=false
SKIP_SYNC=false
SHOW_HELP=false

show_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] [WORKSPACE_PATH]

Developer Mode - Run OpenCode from source code

Options:
  -U, --update       Fetch and merge latest from upstream (uses git-sync-submodules.sh)
  -R, --rebase       Fetch and rebase onto upstream (uses git-rebase-submodules.sh)
  -S, --skip-sync    Skip syncing OpenCode/oh-my-opencode submodules
  -h, --help         Show this help

Examples:
  # Start with default settings (no sync)
  ./quickstart-dev.sh

  # Sync submodules with upstream (merge)
  ./quickstart-dev.sh -U

  # Rebase submodules onto upstream
  ./quickstart-dev.sh -R

  # Skip submodule sync
  ./quickstart-dev.sh -S

  # Specify workspace path
  ./quickstart-dev.sh /path/to/workspace

Note:
  This script now uses kano-git-master-skill for Git operations.
  Submodules managed:
    - src/opencode (upstream: anomalyco/opencode)
    - src/oh-my-opencode (upstream: code-yeongyu/oh-my-opencode)
EOF
}

POSITIONAL_ARGS=()
while [[ $# -gt 0 ]]; do
  case $1 in
    -U|--update)
      UPDATE_SUBMODULES=true
      REBASE_SUBMODULES=false
      shift
      ;;
    -R|--rebase)
      REBASE_SUBMODULES=true
      UPDATE_SUBMODULES=false
      shift
      ;;
    -S|--skip-sync)
      SKIP_SYNC=true
      UPDATE_SUBMODULES=false
      REBASE_SUBMODULES=false
      shift
      ;;
    -h|--help)
      SHOW_HELP=true
      shift
      ;;
    *)
      POSITIONAL_ARGS+=("$1")
      shift
      ;;
  esac
done

if [[ "$SHOW_HELP" == "true" ]]; then
  show_help
  exit 0
fi

set -- "${POSITIONAL_ARGS[@]}"

gith_log "INFO" "========================================="
gith_log "INFO" "OpenCode Developer Mode"
gith_log "INFO" "========================================="

if [[ "$SKIP_SYNC" == "false" ]]; then
  # Ensure submodules are initialized
  gith_log "INFO" "Ensuring submodules are initialized..."
  
  cd "${REPO_ROOT}"
  
  if [[ ! -d "src/opencode/.git" ]] || [[ ! -d "src/oh-my-opencode/.git" ]]; then
    gith_log "INFO" "Initializing submodules..."
    git submodule update --init --recursive src/opencode src/oh-my-opencode || {
      gith_error "Failed to initialize submodules"
      exit 1
    }
    gith_log "INFO" "✓ Submodules initialized"
  fi
  
  # Setup upstream remotes if not already configured
  if ! gith_has_remote "upstream" "src/opencode" || ! gith_has_remote "upstream" "src/oh-my-opencode"; then
    gith_log "INFO" "Setting up upstream remotes..."
    "${REPO_ROOT}/scripts/git/setup-upstream.sh" || {
      gith_error "Failed to setup upstream remotes"
      exit 1
    }
  fi
  
  # Update or rebase submodules
  if [[ "$UPDATE_SUBMODULES" == "true" ]]; then
    gith_log "INFO" "Syncing submodules with upstream (merge)..."
    "${REPO_ROOT}/scripts/git/sync-submodules.sh" || {
      gith_error "Failed to sync submodules"
      gith_error "You may need to resolve conflicts manually"
      exit 1
    }
    gith_log "INFO" "✓ Submodules synced successfully"
  elif [[ "$REBASE_SUBMODULES" == "true" ]]; then
    gith_log "INFO" "Rebasing submodules onto upstream..."
    "${REPO_ROOT}/scripts/git/rebase-submodules.sh" || {
      gith_error "Failed to rebase submodules"
      gith_error "You may need to resolve conflicts manually"
      exit 1
    }
    gith_log "INFO" "✓ Submodules rebased successfully"
  else
    gith_log "INFO" "Submodules ready (no sync requested)"
  fi
else
  gith_log "INFO" "Skipping submodule sync (--skip-sync)"
fi

if ! command -v bun >/dev/null 2>&1; then
  echo "ERROR: bun is not installed or not in PATH" >&2
  echo "       Please install bun: https://bun.sh" >&2
  exit 1
fi

OPENCODE_SRC="${REPO_ROOT}/src/opencode"
if [[ ! -d "${OPENCODE_SRC}" ]]; then
  echo "ERROR: OpenCode source not found at ${OPENCODE_SRC}" >&2
  echo "       Please run 'git submodule update --init --recursive'" >&2
  exit 1
fi

if [[ ! -d "${OPENCODE_SRC}/node_modules" ]]; then
  echo "INFO: Installing OpenCode dependencies..." >&2
  cd "${OPENCODE_SRC}"
  bun install || {
    echo "ERROR: Failed to install dependencies" >&2
    exit 1
  }
  echo "✓ Dependencies installed" >&2
fi

WORKSPACE_PATH="${PWD}"
if [[ $# -gt 0 ]] && [[ "${1}" != -* ]]; then
  WORKSPACE_PATH="$1"
  shift
fi

if [[ ! -d "$WORKSPACE_PATH" ]]; then
  echo "ERROR: workspace path is not a directory: $WORKSPACE_PATH" >&2
  exit 2
fi
WORKSPACE_PATH="$(cd "$WORKSPACE_PATH" && pwd -P)"

echo "" >&2
echo "INFO: Running OpenCode from source" >&2
echo "INFO: Source: ${OPENCODE_SRC}" >&2
echo "INFO: Workspace: ${WORKSPACE_PATH}" >&2
echo "" >&2

cd "${OPENCODE_SRC}"
exec bun run start --workspace "${WORKSPACE_PATH}" "$@"

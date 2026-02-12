#!/usr/bin/env bash
#
# git-setup-upstream.sh - Setup upstream remotes for src/ submodules
#
# This script configures upstream remotes for the two submodules:
#   - src/opencode → upstream: https://github.com/anomalyco/opencode.git
#   - src/oh-my-opencode → upstream: https://github.com/code-yeongyu/oh-my-opencode.git
#
# Usage:
#   ./git-setup-upstream.sh [options]
#
# Options:
#   --dry-run       Show what would be done without executing
#   -h, --help      Show this help
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd -P)"

# Source git-helpers.sh from kano-git-master-skill
GIT_HELPERS="${REPO_ROOT}/skills/kano-git-master-skill/scripts/git-helpers.sh"
if [[ ! -f "$GIT_HELPERS" ]]; then
  echo "ERROR: git-helpers.sh not found at: $GIT_HELPERS" >&2
  echo "       Please ensure kano-git-master-skill submodule is initialized" >&2
  exit 1
fi

source "$GIT_HELPERS"

# Configuration
OPENCODE_PATH="${REPO_ROOT}/src/opencode"
OPENCODE_UPSTREAM="https://github.com/anomalyco/opencode.git"

OH_MY_OPENCODE_PATH="${REPO_ROOT}/src/oh-my-opencode"
OH_MY_OPENCODE_UPSTREAM="https://github.com/code-yeongyu/oh-my-opencode.git"

DRY_RUN=0
SHOW_HELP=0

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      DRY_RUN=1
      export DRY_RUN
      shift
      ;;
    -h|--help)
      SHOW_HELP=1
      shift
      ;;
    *)
      echo "ERROR: Unknown option: $1" >&2
      echo "       Use --help for usage information" >&2
      exit 1
      ;;
  esac
done

if [[ $SHOW_HELP -eq 1 ]]; then
  sed -n '2,/^$/p' "$0" | sed 's/^# \?//'
  exit 0
fi

gith_log "INFO" "========================================="
gith_log "INFO" "Setting up upstream remotes"
gith_log "INFO" "========================================="

# Function to setup upstream for a single submodule
setup_upstream() {
  local submodule_path="$1"
  local upstream_url="$2"
  local submodule_name="$(basename "$submodule_path")"
  
  gith_log "INFO" ""
  gith_log "INFO" "Processing: $submodule_name"
  gith_log "INFO" "-----------------------------------------"
  
  # Check if submodule exists
  if [[ ! -d "$submodule_path" ]]; then
    gith_error "Submodule not found: $submodule_path"
    gith_error "Run: git submodule update --init --recursive"
    return 1
  fi
  
  # Check if it's a git repo
  if ! gith_is_git_repo "$submodule_path"; then
    gith_error "Not a git repository: $submodule_path"
    return 1
  fi
  
  # Check if upstream already exists
  if gith_has_remote "upstream" "$submodule_path"; then
    local current_upstream
    current_upstream="$(cd "$submodule_path" && git remote get-url upstream 2>/dev/null)"
    
    if [[ "$current_upstream" == "$upstream_url" ]]; then
      gith_log "INFO" "✓ Upstream already configured correctly: $upstream_url"
      return 0
    else
      gith_log "WARN" "Upstream exists but with different URL:"
      gith_log "WARN" "  Current:  $current_upstream"
      gith_log "WARN" "  Expected: $upstream_url"
      
      if [[ $DRY_RUN -eq 1 ]]; then
        gith_log "INFO" "[DRY-RUN] Would update upstream URL"
      else
        gith_log "INFO" "Updating upstream URL..."
        if ! (cd "$submodule_path" && git remote set-url upstream "$upstream_url" 2>&1); then
          gith_error "Failed to update upstream URL"
          return 1
        fi
        gith_log "INFO" "✓ Upstream URL updated"
      fi
      
      return 0
    fi
  fi
  
  # Add upstream remote
  gith_log "INFO" "Adding upstream remote: $upstream_url"
  
  if [[ $DRY_RUN -eq 1 ]]; then
    gith_log "INFO" "[DRY-RUN] Would run: git remote add upstream $upstream_url"
  else
    if ! (cd "$submodule_path" && git remote add upstream "$upstream_url" 2>&1); then
      gith_error "Failed to add upstream remote"
      return 1
    fi
    gith_log "INFO" "✓ Upstream remote added"
  fi
  
  # Fetch from upstream
  if [[ $DRY_RUN -eq 0 ]]; then
    gith_log "INFO" "Fetching from upstream..."
    if ! gith_fetch_remote "upstream" "$submodule_path"; then
      gith_log "WARN" "Failed to fetch from upstream (remote added but fetch failed)"
      return 1
    fi
    gith_log "INFO" "✓ Fetched from upstream"
  fi
  
  gith_log "INFO" "✓ $submodule_name upstream configured successfully"
  return 0
}

# Setup upstream for both submodules
SUCCESS_COUNT=0
FAIL_COUNT=0

if setup_upstream "$OPENCODE_PATH" "$OPENCODE_UPSTREAM"; then
  ((SUCCESS_COUNT++))
else
  ((FAIL_COUNT++))
fi

if setup_upstream "$OH_MY_OPENCODE_PATH" "$OH_MY_OPENCODE_UPSTREAM"; then
  ((SUCCESS_COUNT++))
else
  ((FAIL_COUNT++))
fi

# Summary
gith_log "INFO" ""
gith_log "INFO" "========================================="
gith_log "INFO" "Setup Summary"
gith_log "INFO" "========================================="
gith_log "INFO" "Successful: $SUCCESS_COUNT"
gith_log "INFO" "Failed:     $FAIL_COUNT"

if [[ $FAIL_COUNT -gt 0 ]]; then
  gith_error "Some submodules failed to setup upstream"
  exit 1
fi

gith_log "INFO" "✓ All upstream remotes configured successfully"
gith_log "INFO" ""
gith_log "INFO" "You can now use:"
gith_log "INFO" "  ./scripts/git-sync-submodules.sh    - Sync with upstream"
gith_log "INFO" "  ./scripts/git-rebase-submodules.sh  - Rebase onto upstream"
exit 0

#!/usr/bin/env bash
#
# git-sync-submodules.sh - Sync src/ submodules (opencode and oh-my-opencode)
#
# This script syncs the two submodules in src/ directory:
#   - src/opencode (upstream: anomalyco/opencode, origin: dorgonman/opencode)
#   - src/oh-my-opencode (upstream: code-yeongyu/oh-my-opencode, origin: dorgonman/oh-my-opencode)
#
# Usage:
#   ./git-sync-submodules.sh [options]
#
# Options:
#   --fetch-only    Only fetch from remotes, don't update working tree
#   --dry-run       Show what would be done without executing
#   -h, --help      Show this help
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd -P)"

# Source git-helpers.sh from kano-git-master-skill
GIT_HELPERS="${REPO_ROOT}/skills/kano-git-master-skill/scripts/lib/git-helpers.sh"
if [[ ! -f "$GIT_HELPERS" ]]; then
  echo "ERROR: git-helpers.sh not found at: $GIT_HELPERS" >&2
  echo "       Please ensure kano-git-master-skill submodule is initialized" >&2
  exit 1
fi

source "$GIT_HELPERS"

# Configuration
OPENCODE_PATH="${REPO_ROOT}/src/opencode"
OH_MY_OPENCODE_PATH="${REPO_ROOT}/src/oh-my-opencode"

FETCH_ONLY=0
DRY_RUN=0
SHOW_HELP=0

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --fetch-only)
      FETCH_ONLY=1
      shift
      ;;
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
gith_log "INFO" "Syncing src/ submodules"
gith_log "INFO" "========================================="

# Function to sync a single submodule
sync_submodule() {
  local submodule_path="$1"
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
  
  # Check for upstream remote
  if ! gith_has_remote "upstream" "$submodule_path"; then
    gith_log "WARN" "No 'upstream' remote configured for $submodule_name"
    gith_log "WARN" "Only syncing with 'origin'"
  fi
  
  # Fetch from origin
  if gith_has_remote "origin" "$submodule_path"; then
    gith_log "INFO" "Fetching from origin..."
    if ! gith_fetch_remote "origin" "$submodule_path"; then
      gith_error "Failed to fetch from origin"
      return 1
    fi
  fi
  
  # Fetch from upstream if it exists
  if gith_has_remote "upstream" "$submodule_path"; then
    gith_log "INFO" "Fetching from upstream..."
    if ! gith_fetch_remote "upstream" "$submodule_path"; then
      gith_error "Failed to fetch from upstream"
      return 1
    fi
  fi
  
  # If fetch-only mode, stop here
  if [[ $FETCH_ONLY -eq 1 ]]; then
    gith_log "INFO" "Fetch completed (--fetch-only mode)"
    return 0
  fi
  
  # Update working tree
  gith_log "INFO" "Updating working tree..."
  
  # Get current branch
  local current_branch
  current_branch="$(gith_get_current_branch "$submodule_path")"
  
  if [[ -z "$current_branch" ]]; then
    gith_log "WARN" "Submodule is in detached HEAD state"
    gith_log "WARN" "Skipping working tree update"
    return 0
  fi
  
  # Check if branch exists on origin
  local remote_to_use="origin"
  if gith_has_remote "upstream" "$submodule_path" && gith_branch_exists_on_remote "upstream" "$current_branch" "$submodule_path"; then
    remote_to_use="upstream"
  fi
  
  if ! gith_branch_exists_on_remote "$remote_to_use" "$current_branch" "$submodule_path"; then
    gith_log "WARN" "Current branch '$current_branch' does not exist on $remote_to_use"
    gith_log "WARN" "Skipping working tree update"
    return 0
  fi
  
  # Stash local changes if any
  local stash_ref=""
  if gith_has_changes "$submodule_path"; then
    gith_log "INFO" "Stashing local changes..."
    stash_ref="$(gith_stash_create "$submodule_path" "git-sync-submodules auto-stash")"
  fi
  
  # Merge remote branch
  gith_log "INFO" "Merging $remote_to_use/$current_branch..."
  if [[ $DRY_RUN -eq 1 ]]; then
    gith_log "INFO" "[DRY-RUN] Would run: git merge $remote_to_use/$current_branch"
  else
    if ! (cd "$submodule_path" && git merge "$remote_to_use/$current_branch" 2>&1); then
      gith_error "Failed to merge $remote_to_use/$current_branch"
      
      # Try to restore stash
      if [[ -n "$stash_ref" ]]; then
        gith_log "INFO" "Restoring stashed changes..."
        gith_stash_pop "$submodule_path" "$stash_ref" || true
      fi
      
      return 1
    fi
  fi
  
  # Restore stash if created
  if [[ -n "$stash_ref" ]]; then
    gith_log "INFO" "Restoring stashed changes..."
    if ! gith_stash_pop "$submodule_path" "$stash_ref"; then
      gith_error "Failed to restore stashed changes"
      gith_error "Manual recovery may be needed"
      return 1
    fi
  fi
  
  gith_log "INFO" "✓ $submodule_name synced successfully"
  return 0
}

# Sync both submodules
SUCCESS_COUNT=0
FAIL_COUNT=0

if sync_submodule "$OPENCODE_PATH"; then
  ((SUCCESS_COUNT++)) || true
else
  ((FAIL_COUNT++)) || true
fi

if sync_submodule "$OH_MY_OPENCODE_PATH"; then
  ((SUCCESS_COUNT++)) || true
else
  ((FAIL_COUNT++)) || true
fi

# Summary
gith_log "INFO" ""
gith_log "INFO" "========================================="
gith_log "INFO" "Sync Summary"
gith_log "INFO" "========================================="
gith_log "INFO" "Successful: $SUCCESS_COUNT"
gith_log "INFO" "Failed:     $FAIL_COUNT"

if [[ $FAIL_COUNT -gt 0 ]]; then
  gith_error "Some submodules failed to sync"
  exit 1
fi

gith_log "INFO" "✓ All submodules synced successfully"
exit 0

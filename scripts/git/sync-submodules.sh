#!/usr/bin/env bash
#
# git-sync-submodules.sh - Unified submodule synchronization using KOG mechanism
#
# This script synchronizes submodules by fetching from all configured remotes
# (origin, upstream, etc.) and merging the tracking branch.
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

# 1. Directory-independent path resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd -P)"

# 2. Source git-helpers.sh from kano-git-master-skill
GIT_HELPERS="${REPO_ROOT}/skills/kano-git-master-skill/scripts/lib/git-helpers.sh"
if [[ ! -f "$GIT_HELPERS" ]]; then
  echo "ERROR: git-helpers.sh not found at: $GIT_HELPERS" >&2
  echo "       Please ensure kano-git-master-skill submodule is initialized" >&2
  exit 1
fi
source "$GIT_HELPERS"

# 3. KOG Sync tool path
KOG_SYNC_TOOL="${REPO_ROOT}/skills/kano-git-master-skill/scripts/submodules/kog-submodule.sh"

# Parse arguments
FETCH_ONLY=0
DRY_RUN=0
SHOW_HELP=0

while [[ $# -gt 0 ]]; do
  case $1 in
    --fetch-only) FETCH_ONLY=1; shift ;;
    --dry-run) DRY_RUN=1; export DRY_RUN; shift ;;
    -h|--help) SHOW_HELP=1; shift ;;
    *) echo "ERROR: Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ $SHOW_HELP -eq 1 ]]; then
  sed -n '2,/^$/p' "$0" | sed 's/^# \?//'
  exit 0
fi

gith_log "INFO" "========================================="
gith_log "INFO" "Unified Submodule Synchronization"
gith_log "INFO" "========================================="

# 4. First, ensure all submodule remotes are synced based on .gitmodules (KOG)
gith_log "INFO" "Syncing submodule remotes using KOG mechanism..."
if [[ $DRY_RUN -eq 1 ]]; then
  bash "$KOG_SYNC_TOOL" sync "" --dry-run
else
  bash "$KOG_SYNC_TOOL" sync
fi

# 5. Discover submodules that have KOG configuration
# We'll look for any submodule that has at least one kog-remote configuration
SUBMODULES_TO_SYNC=()
while IFS= read -r submodule_path; do
  if [[ -n "$submodule_path" ]]; then
    SUBMODULES_TO_SYNC+=("$submodule_path")
  fi
done < <(git config -f "${REPO_ROOT}/.gitmodules" --get-regexp "submodule\..*\.kog-remote-.*" | sed -E 's/submodule\.([^.]+)\..*/\1/' | sort -u)

if [[ ${#SUBMODULES_TO_SYNC[@]} -eq 0 ]]; then
  gith_log "WARN" "No submodules with KOG configuration found in .gitmodules"
  exit 0
fi

# Function to sync a single submodule
sync_submodule() {
  local submodule_path="$1"
  local abs_path="${REPO_ROOT}/${submodule_path}"
  local submodule_name="$(basename "$submodule_path")"
  
  gith_log "INFO" ""
  gith_log "INFO" "Syncing: $submodule_name ($submodule_path)"
  gith_log "INFO" "-----------------------------------------"
  
  # Check if submodule exists and is initialized
  if [[ ! -d "$abs_path/.git" && ! -f "$abs_path/.git" ]]; then
    gith_log "WARN" "Submodule not initialized or folder missing: $submodule_path"
    gith_log "WARN" "Run: git submodule update --init --recursive"
    return 1
  fi
  
  # Get configured remotes for this submodule (from .gitmodules)
  local remotes=()
  while IFS= read -r rname; do
    if [[ -n "$rname" ]]; then remotes+=("$rname"); fi
  done < <(git config -f "${REPO_ROOT}/.gitmodules" --get-regexp "submodule\.$submodule_path\.kog-remote-.*" | sed -E 's/submodule\.[^.]+\.kog-remote-([^-]+)-.*/\1/' | sort -u)

  # Fetch from all remotes
  for remote in "${remotes[@]}"; do
    if gith_has_remote "$remote" "$abs_path"; then
      gith_log "INFO" "Fetching from $remote..."
      gith_fetch_remote "$remote" "$abs_path" || gith_log "WARN" "Failed to fetch from $remote"
    fi
  done
  
  if [[ $FETCH_ONLY -eq 1 ]]; then
    return 0
  fi
  
  # Get target branch from .gitmodules
  local target_branch
  target_branch=$(git config -f "${REPO_ROOT}/.gitmodules" --get "submodule.$submodule_path.branch" || echo "dev")
  
  # Update working tree
  local current_branch
  current_branch="$(gith_get_current_branch "$abs_path")"
  
  if [[ -z "$current_branch" ]]; then
    gith_log "WARN" "Failed to determine or switch to a branch in $submodule_name, skipping merge"
    return 0
  fi
  
  # Determine which remote to merge from (prefer upstream if it exists and has the branch)
  local tracking_remote="origin"
  if gith_has_remote "upstream" "$abs_path" && gith_branch_exists_on_remote "upstream" "$target_branch" "$abs_path"; then
    tracking_remote="upstream"
  fi

  local merge_remote="$tracking_remote"
  if gith_has_remote "upstream" "$abs_path" && gith_branch_exists_on_remote "upstream" "$current_branch" "$abs_path"; then
    merge_remote="upstream"
  fi
  
  if ! gith_branch_exists_on_remote "$merge_remote" "$current_branch" "$abs_path"; then
    gith_log "WARN" "Branch '$current_branch' not found on $merge_remote, skipping merge"
    return 0
  fi
  
  # Stash local changes
  local stash_ref=""
  if gith_has_changes "$abs_path"; then
    stash_ref="$(gith_stash_create "$abs_path" "git-sync-submodules auto-stash")"
  fi
  
  # Merge
  gith_log "INFO" "Merging $merge_remote/$current_branch into local $current_branch..."
  if [[ $DRY_RUN -eq 1 ]]; then
    gith_log "INFO" "[DRY-RUN] Would merge $merge_remote/$current_branch"
  else
    if ! (cd "$abs_path" && git merge "$merge_remote/$current_branch" 2>&1); then
      gith_error "Merge failed for $submodule_name"
      if [[ -n "$stash_ref" ]]; then gith_stash_pop "$abs_path" "$stash_ref" || true; fi
      return 1
    fi
  fi
  
  # Restore stash
  if [[ -n "$stash_ref" ]]; then
    gith_stash_pop "$abs_path" "$stash_ref" || true
  fi
  
  gith_log "INFO" "✓ $submodule_name sync complete"
  return 0
}

SUCCESS_COUNT=0
FAIL_COUNT=0

for sub in "${SUBMODULES_TO_SYNC[@]}"; do
  if sync_submodule "$sub"; then
    ((SUCCESS_COUNT++)) || true
  else
    ((FAIL_COUNT++)) || true
  fi
done

gith_log "INFO" ""
gith_log "INFO" "========================================="
gith_log "INFO" "Final Summary"
gith_log "INFO" "========================================="
gith_log "INFO" "Successful: $SUCCESS_COUNT"
gith_log "INFO" "Failed:     $FAIL_COUNT"

if [[ $FAIL_COUNT -gt 0 ]]; then
  exit 1
fi
exit 0

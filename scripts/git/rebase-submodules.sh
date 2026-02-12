#!/usr/bin/env bash
#
# git-rebase-submodules.sh - Rebase src/ submodules to upstream
#
# This script rebases the two submodules in src/ directory to their upstream:
#   - src/opencode → upstream/dev (anomalyco/opencode)
#   - src/oh-my-opencode → upstream/dev (code-yeongyu/oh-my-opencode)
#
# Usage:
#   ./git-rebase-submodules.sh [options]
#
# Options:
#   --remote <name>  Remote to rebase onto (default: upstream)
#   --branch <name>  Branch to rebase onto (default: current branch or dev)
#   --dry-run        Show what would be done without executing
#   -h, --help       Show this help
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
OH_MY_OPENCODE_PATH="${REPO_ROOT}/src/oh-my-opencode"

REMOTE="upstream"
BRANCH=""
DRY_RUN=0
SHOW_HELP=0

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --remote)
      REMOTE="$2"
      shift 2
      ;;
    --branch)
      BRANCH="$2"
      shift 2
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
gith_log "INFO" "Rebasing src/ submodules to $REMOTE"
gith_log "INFO" "========================================="

# Function to rebase a single submodule
rebase_submodule() {
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
  
  # Check for remote
  if ! gith_has_remote "$REMOTE" "$submodule_path"; then
    gith_error "Remote '$REMOTE' not found in $submodule_name"
    gith_error "Available remotes:"
    (cd "$submodule_path" && git remote -v)
    return 1
  fi
  
  # Fetch from remote
  gith_log "INFO" "Fetching from $REMOTE..."
  if ! gith_fetch_remote "$REMOTE" "$submodule_path"; then
    gith_error "Failed to fetch from $REMOTE"
    return 1
  fi
  
  # Get current branch
  local current_branch
  current_branch="$(gith_get_current_branch "$submodule_path")"
  
  if [[ -z "$current_branch" ]]; then
    gith_error "Submodule is in detached HEAD state"
    gith_error "Please checkout a branch first"
    return 1
  fi
  
  # Determine target branch
  local target_branch="$BRANCH"
  if [[ -z "$target_branch" ]]; then
    # Use current branch if it exists on remote
    if gith_branch_exists_on_remote "$REMOTE" "$current_branch" "$submodule_path"; then
      target_branch="$current_branch"
    else
      # Fallback to default branch
      target_branch="$(gith_get_default_branch "$REMOTE" "$submodule_path")"
      if [[ -z "$target_branch" ]]; then
        gith_error "Could not determine target branch"
        gith_error "Please specify --branch explicitly"
        return 1
      fi
    fi
  fi
  
  # Verify target branch exists on remote
  if ! gith_branch_exists_on_remote "$REMOTE" "$target_branch" "$submodule_path"; then
    gith_error "Branch '$target_branch' does not exist on $REMOTE"
    return 1
  fi
  
  gith_log "INFO" "Rebasing $current_branch onto $REMOTE/$target_branch"
  
  # Stash local changes if any
  local stash_ref=""
  if gith_has_changes "$submodule_path"; then
    gith_log "INFO" "Stashing local changes..."
    stash_ref="$(gith_stash_create "$submodule_path" "git-rebase-submodules auto-stash")"
  fi
  
  # Rebase
  if [[ $DRY_RUN -eq 1 ]]; then
    gith_log "INFO" "[DRY-RUN] Would run: git rebase $REMOTE/$target_branch"
  else
    if ! (cd "$submodule_path" && git rebase "$REMOTE/$target_branch" 2>&1); then
      gith_error "Rebase failed for $submodule_name"
      gith_error "You may need to resolve conflicts manually:"
      gith_error "  cd $submodule_path"
      gith_error "  git status"
      gith_error "  # Resolve conflicts, then:"
      gith_error "  git rebase --continue"
      gith_error "  # Or abort:"
      gith_error "  git rebase --abort"
      
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
  
  gith_log "INFO" "✓ $submodule_name rebased successfully"
  return 0
}

# Rebase both submodules
SUCCESS_COUNT=0
FAIL_COUNT=0

if rebase_submodule "$OPENCODE_PATH"; then
  ((SUCCESS_COUNT++))
else
  ((FAIL_COUNT++))
fi

if rebase_submodule "$OH_MY_OPENCODE_PATH"; then
  ((SUCCESS_COUNT++))
else
  ((FAIL_COUNT++))
fi

# Summary
gith_log "INFO" ""
gith_log "INFO" "========================================="
gith_log "INFO" "Rebase Summary"
gith_log "INFO" "========================================="
gith_log "INFO" "Successful: $SUCCESS_COUNT"
gith_log "INFO" "Failed:     $FAIL_COUNT"

if [[ $FAIL_COUNT -gt 0 ]]; then
  gith_error "Some submodules failed to rebase"
  exit 1
fi

gith_log "INFO" "✓ All submodules rebased successfully"
exit 0

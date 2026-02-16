#!/usr/bin/env bash
#
# smart-sync.sh - Project-level wrapper for AI-powered intelligent sync
#
# This script points to the kano-git-master-skill smart-sync tool.
# It automatically handles provider selection and falls back to standard
# git rebase if AI providers are unavailable.
#
# It can be run from any directory within the project.

# Find project root (location of this script)
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Use the auto-fallback version as the primary entry point
SKILL_SCRIPT="$ROOT/skills/kano/kano-git-master-skill/scripts/commit-tools/sync/smart-sync-copilot.sh"

if [[ ! -f "$SKILL_SCRIPT" ]]; then
  echo "ERROR: Smart Sync script not found at:"
  echo "  $SKILL_SCRIPT"
  echo "Ensure the kano-git-master-skill submodule is initialized."
  exit 1
fi

# Run the actual script
exec bash "$SKILL_SCRIPT" "$@"

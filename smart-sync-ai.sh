#!/usr/bin/env bash
#
# smart-sync-ai.sh - Project-level wrapper for AI-powered intelligent sync (legacy)
#
# This script points to the kano-git-master-skill smart-sync tool (Copilot wrapper).
# It can be run from any directory within the project.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SKILL_SCRIPT="$ROOT/skills/kano/kano-git-master-skill/scripts/commit-tools/sync/smart-sync-copilot.sh"

if [[ ! -f "$SKILL_SCRIPT" ]]; then
  echo "ERROR: Smart Sync script not found at:" >&2
  echo "  $SKILL_SCRIPT" >&2
  echo "Ensure the kano-git-master-skill submodule is initialized." >&2
  exit 1
fi

exec bash "$SKILL_SCRIPT" "$@"


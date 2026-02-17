#!/usr/bin/env bash
#
# smart-sync-upstream-force-push.sh - Project-level wrapper
#
# Sync with upstream (AI-powered) then force-push to origin.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SKILL_SCRIPT="$ROOT/skills/kano/kano-git-master-skill/scripts/commit-tools/sync/smart-sync-upstream-force-push-copilot.sh"

if [[ ! -f "$SKILL_SCRIPT" ]]; then
  echo "ERROR: Git Master Skill script not found at:" >&2
  echo "  $SKILL_SCRIPT" >&2
  echo "Ensure the kano-git-master-skill submodule is initialized." >&2
  exit 1
fi

export KANO_GIT_MASTER_ROOT="$ROOT"
exec bash "$SKILL_SCRIPT" "$@"


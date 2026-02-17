#!/usr/bin/env bash
#
# smart-sync.sh - Project-level entry point for sync workflows
#
# This script was split into two explicit workflows:
#   1) smart-sync-upstream-force-push.sh  - sync with upstream then force-push to origin
#   2) smart-sync-origin-latest.sh        - sync local default branch to origin (no push)
#
# (Legacy) The old AI-powered sync wrapper is kept as smart-sync-ai.sh.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage: ./smart-sync.sh <mode> [args...]

Modes:
  upstream-force-push   Sync with upstream, then push --force-with-lease to origin
  origin-latest         Checkout origin default branch and pull --rebase (no push)
  ai                    Legacy AI-powered sync (no push)

Examples:
  ./smart-sync.sh origin-latest
  ./smart-sync.sh upstream-force-push --verbose
  ./smart-sync.sh ai --onto upstream/main
EOF
}

mode="${1:-}"
if [[ -z "$mode" || "$mode" == "-h" || "$mode" == "--help" ]]; then
  usage
  exit 0
fi
shift || true

case "$mode" in
  upstream-force-push)
    exec bash "$ROOT/smart-sync-upstream-force-push.sh" "$@"
    ;;
  origin-latest)
    exec bash "$ROOT/smart-sync-origin-latest.sh" "$@"
    ;;
  ai)
    exec bash "$ROOT/smart-sync-ai.sh" "$@"
    ;;
  *)
    echo "ERROR: Unknown mode: $mode" >&2
    usage >&2
    exit 1
    ;;
esac


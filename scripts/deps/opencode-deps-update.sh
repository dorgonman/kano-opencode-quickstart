#!/usr/bin/env bash
# opencode-deps-update.sh - Update OpenCode and all dependencies to latest
# Usage: ./scripts/opencode-deps-update.sh [--dry-run]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
exec "${SCRIPT_DIR}/opencode-deps-manager.sh" update "$@"

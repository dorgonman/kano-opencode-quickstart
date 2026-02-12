#!/usr/bin/env bash
# opencode-deps-install.sh - Install OpenCode dependencies (first-time setup)
# Usage: ./scripts/opencode-deps-install.sh [--dry-run]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
exec "${SCRIPT_DIR}/opencode-deps-manager.sh" install "$@"

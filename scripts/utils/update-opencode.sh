#!/usr/bin/env bash
set -euo pipefail

# update-opencode.sh - Update OpenCode and all plugins to latest versions
# Usage: ./scripts/update-opencode.sh [--dry-run]

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "INFO: Dry-run mode enabled (no actual updates)" >&2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd -P)"

have() { command -v "$1" >/dev/null 2>&1; }

# Check prerequisites
if ! have bun; then
  echo "ERROR: bun not found in PATH." >&2
  echo "Hint : Install Bun from https://bun.sh" >&2
  exit 2
fi

if ! have opencode; then
  echo "ERROR: opencode not found in PATH." >&2
  echo "Hint : Install OpenCode first" >&2
  exit 2
fi

echo "=== OpenCode Update Script ===" >&2
echo "RepoRoot: ${REPO_ROOT}" >&2
echo "" >&2

# Step 1: Update OpenCode CLI
echo "[1/3] Updating OpenCode CLI..." >&2
if [[ "${DRY_RUN}" == "true" ]]; then
  echo "  [DRY-RUN] Would run: bun install -g opencode-ai@latest" >&2
else
  if bun install -g opencode-ai@latest; then
    echo "  ✓ OpenCode CLI updated successfully" >&2
  else
    echo "  ⚠ OpenCode CLI update failed (continuing anyway)" >&2
  fi
fi
echo "" >&2

# Step 2: Update oh-my-opencode
echo "[2/3] Updating oh-my-opencode..." >&2
if [[ "${DRY_RUN}" == "true" ]]; then
  echo "  [DRY-RUN] Would run: bun install -g oh-my-opencode@latest" >&2
else
  if bun install -g oh-my-opencode@latest; then
    echo "  ✓ oh-my-opencode updated successfully" >&2
  else
    echo "  ⚠ oh-my-opencode update failed (may not be installed globally)" >&2
  fi
fi
echo "" >&2

# Step 3: Update repo-local plugin dependencies
echo "[3/3] Updating repo-local plugin dependencies..." >&2
if [[ ! -f "${REPO_ROOT}/.opencode/package.json" ]]; then
  echo "  ⚠ No .opencode/package.json found, skipping plugin updates" >&2
else
  if [[ "${DRY_RUN}" == "true" ]]; then
    echo "  [DRY-RUN] Would run: cd .opencode && bun update" >&2
  else
    (
      cd "${REPO_ROOT}/.opencode"
      echo "  Current dependencies:" >&2
      bun pm ls 2>/dev/null || echo "    (none)" >&2
      echo "" >&2
      echo "  Updating all dependencies to latest..." >&2
      bun update
      echo "" >&2
      echo "  Updated dependencies:" >&2
      bun pm ls 2>/dev/null || echo "    (none)" >&2
    )
    echo "  ✓ Plugin dependencies updated" >&2
  fi
fi
echo "" >&2

# Step 4: Show versions
echo "=== Current Versions ===" >&2
if have opencode; then
  echo "OpenCode CLI: $(opencode --version 2>/dev/null || echo 'unknown')" >&2
fi
if have oh-my-opencode; then
  echo "oh-my-opencode: $(oh-my-opencode --version 2>/dev/null || echo 'unknown')" >&2
fi
if [[ -f "${REPO_ROOT}/.opencode/package.json" ]]; then
  echo "" >&2
  echo "Plugin dependencies:" >&2
  (cd "${REPO_ROOT}/.opencode" && bun pm ls 2>/dev/null | head -20) || echo "  (unable to list)" >&2
fi
echo "" >&2

if [[ "${DRY_RUN}" == "true" ]]; then
  echo "✓ Dry-run completed (no changes made)" >&2
else
  echo "✓ Update completed" >&2
fi

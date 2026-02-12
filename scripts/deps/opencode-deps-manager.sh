#!/usr/bin/env bash
set -euo pipefail

# opencode-deps-manager.sh - Unified OpenCode dependency manager
# Usage: ./scripts/opencode-deps-manager.sh [install|update|status] [--dry-run]

ACTION="${1:-status}"
DRY_RUN=false

# Parse flags
shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    *)
      echo "ERROR: Unknown flag: $1" >&2
      echo "Usage: $(basename "$0") [install|update|status] [--dry-run]" >&2
      exit 2
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd -P)"

have() { command -v "$1" >/dev/null 2>&1; }

print_status() {
  echo "=== Environment Status ===" >&2
  echo "RepoRoot  : ${REPO_ROOT}" >&2
  echo "opencode  : $(have opencode && echo "OK ($(opencode --version 2>/dev/null || echo 'unknown'))" || echo MISSING)" >&2
  echo "bun       : $(have bun && echo "OK ($(bun --version 2>/dev/null || echo 'unknown'))" || echo MISSING)" >&2
  echo "tailscale : $(have tailscale && echo OK || echo MISSING)" >&2
  
  if have oh-my-opencode; then
    echo "oh-my-opencode: OK ($(oh-my-opencode --version 2>/dev/null || echo 'unknown'))" >&2
  fi
  
  if [[ -f "${REPO_ROOT}/.opencode/package.json" ]]; then
    echo "" >&2
    echo "Repo-local plugins:" >&2
    (cd "${REPO_ROOT}/.opencode" && bun pm ls 2>/dev/null | head -10) || echo "  (none installed)" >&2
  fi
  echo "" >&2
}

install_deps() {
  echo "=== Installing Dependencies ===" >&2
  
  # Check prerequisites
  if ! have bun; then
    echo "ERROR: bun not found in PATH." >&2
    echo "Hint : Install Bun from https://bun.sh" >&2
    return 2
  fi
  
  # Install repo-local plugin dependencies
  mkdir -p "${REPO_ROOT}/.opencode"
  
  if [[ ! -f "${REPO_ROOT}/.opencode/package.json" ]]; then
    echo "ERROR: Missing ${REPO_ROOT}/.opencode/package.json" >&2
    echo "Hint : This repo expects plugin deps to be declared there." >&2
    return 2
  fi
  
  echo "[1/1] Installing repo-local plugin dependencies..." >&2
  if [[ "${DRY_RUN}" == "true" ]]; then
    echo "  [DRY-RUN] Would run: cd .opencode && bun install" >&2
  else
    (cd "${REPO_ROOT}/.opencode" && bun install)
    echo "  ✓ Plugin dependencies installed" >&2
  fi
  echo "" >&2
}

update_deps() {
  echo "=== Updating Dependencies ===" >&2
  
  # Check prerequisites
  if ! have bun; then
    echo "ERROR: bun not found in PATH." >&2
    echo "Hint : Install Bun from https://bun.sh" >&2
    return 2
  fi
  
  if ! have opencode; then
    echo "ERROR: opencode not found in PATH." >&2
    echo "Hint : Install OpenCode first" >&2
    return 2
  fi
  
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
}

# Main logic
case "${ACTION}" in
  status|check)
    print_status
    ;;
  install)
    print_status
    install_deps
    if [[ "${DRY_RUN}" == "true" ]]; then
      echo "✓ Dry-run completed (no changes made)" >&2
    else
      echo "✓ Installation completed" >&2
    fi
    ;;
  update)
    print_status
    update_deps
    if [[ "${DRY_RUN}" == "true" ]]; then
      echo "✓ Dry-run completed (no changes made)" >&2
    else
      echo "✓ Update completed" >&2
    fi
    ;;
  *)
    echo "Usage: $(basename "$0") [install|update|status] [--dry-run]" >&2
    echo "" >&2
    echo "Actions:" >&2
    echo "  install  - Install dependencies from package.json (first-time setup)" >&2
    echo "  update   - Update all dependencies to latest versions" >&2
    echo "  status   - Show current environment and dependency status" >&2
    echo "" >&2
    echo "Options:" >&2
    echo "  --dry-run - Preview what would be done without making changes" >&2
    exit 2
    ;;
esac

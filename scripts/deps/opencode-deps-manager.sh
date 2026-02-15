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
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd -P)"


ensure_bun_in_path() {
  # 1. Check if bun is already in PATH
  if command -v bun >/dev/null 2>&1; then
    return 0
  fi

  # 2. Check candidate directories
  local candidates=()
  [[ -n "${HOME:-}" ]] && candidates+=("${HOME}/.bun/bin")
  [[ -n "${USERPROFILE:-}" ]] && candidates+=("${USERPROFILE}/.bun/bin")
  
  # Windows-specific: try to handle backslashes if standard paths fail
  if [[ "${OS:-}" == "Windows_NT" ]]; then
      if command -v cygpath >/dev/null 2>&1 && [[ -n "${USERPROFILE:-}" ]]; then
          local win_bun_path
          win_bun_path="$(cygpath -u "${USERPROFILE}")/.bun/bin"
          candidates+=("$win_bun_path")
      fi
  fi

  for dir in "${candidates[@]}"; do
    if [[ -d "$dir" ]]; then
      if [[ -f "$dir/bun" ]] || [[ -f "$dir/bun.exe" ]]; then
        export PATH="$dir:$PATH"
        return 0
      fi
    fi
  done
  
  return 1
}

# Try to find bun in default locations
ensure_bun_in_path || true

have() { command -v "$1" >/dev/null 2>&1; }

print_status() {
  echo "=== Environment Status ===" >&2
  echo "RepoRoot  : ${REPO_ROOT}" >&2
  echo "opencode  : $(have opencode && echo "OK ($(opencode --version 2>/dev/null || echo 'unknown')) @ $(command -v opencode)" || echo MISSING)" >&2
  echo "bun       : $(have bun && echo "OK ($(bun --version 2>/dev/null || echo 'unknown')) @ $(command -v bun)" || echo MISSING)" >&2
  echo "tailscale : $(have tailscale && echo OK || echo MISSING)" >&2
  
  if have oh-my-opencode; then
    echo "oh-my-opencode: OK ($(oh-my-opencode --version 2>/dev/null || echo 'unknown')) @ $(command -v oh-my-opencode)" >&2
  fi
  
  if [[ -f "${REPO_ROOT}/.opencode/package.json" ]]; then
    echo "" >&2
    echo "Repo-local plugins:" >&2
    (cd "${REPO_ROOT}/.opencode" && bun pm ls 2>/dev/null | head -10) || echo "  (none installed)" >&2
  fi
  echo "" >&2
}

ensure_local_plugins() {
  mkdir -p "${REPO_ROOT}/.opencode"
  if [[ ! -f "${REPO_ROOT}/.opencode/package.json" ]]; then
    echo "WARN: Missing ${REPO_ROOT}/.opencode/package.json" >&2
    echo "INFO: Creating default package.json for local plugins..." >&2
    echo '{"name": "opencode-local-plugins", "dependencies": {"oh-my-opencode": "latest", "opencode-antigravity-auth": "latest"}}' > "${REPO_ROOT}/.opencode/package.json"
  else
    # Ensure oh-my-opencode is in dependencies
    if ! grep -q '"oh-my-opencode"' "${REPO_ROOT}/.opencode/package.json"; then
      echo "INFO: Adding oh-my-opencode to .opencode/package.json..." >&2
      (cd "${REPO_ROOT}/.opencode" && bun add oh-my-opencode)
    fi
    # Ensure opencode-antigravity-auth is in dependencies
    if ! grep -q '"opencode-antigravity-auth"' "${REPO_ROOT}/.opencode/package.json"; then
      echo "INFO: Adding opencode-antigravity-auth to .opencode/package.json..." >&2
      (cd "${REPO_ROOT}/.opencode" && bun add opencode-antigravity-auth)
    fi
  fi
}

install_deps() {
  echo "=== Installing Dependencies ===" >&2
  # Check prerequisites
  if ! have bun; then
    echo "ERROR: bun not found in PATH." >&2
    echo "Hint : If installed, ensure it is in PATH or ~/.bun/bin" >&2
    echo "Hint : Install Bun from https://bun.sh" >&2
    return 2
  fi
  
  # Install repo-local plugin dependencies
  ensure_local_plugins
  
  echo "[1/1] Installing repo-local plugin dependencies..." >&2
  if [[ "${DRY_RUN}" == "true" ]]; then
    echo "  [DRY-RUN] Would run: cd .opencode && bun install" >&2
  else
    (
      cd "${REPO_ROOT}/.opencode"
      if [[ -f package.json ]]; then
        bun install
      else
        echo "WARN: No package.json found in .opencode, skipping install." >&2
      fi
    )
    if [[ $? -eq 0 ]]; then
      echo "  ✓ Local plugins installed" >&2
    else
      echo "ERROR: Failed to install local plugins" >&2
      return 2
    fi
  fi
  echo "" >&2
}

update_deps() {
  echo "=== Updating Dependencies ===" >&2
  # Check prerequisites
  if ! have bun; then
    echo "ERROR: bun not found in PATH." >&2
    echo "Hint : If installed, ensure it is in PATH or ~/.bun/bin" >&2
    echo "Hint : Install Bun from https://bun.sh" >&2
    return 2
  fi
  
  if ! have opencode; then
    echo "WARN: opencode not found in PATH. Attempting to install..." >&2
  fi
  
  # Step 1: Update OpenCode CLI
  echo "[1/2] Updating OpenCode CLI..." >&2
  if [[ "${DRY_RUN}" == "true" ]]; then
    echo "  [DRY-RUN] Would run: bun install -g opencode-ai@latest" >&2
  else
    if bun install -g opencode-ai@latest; then
      echo "  ✓ OpenCode CLI updated successfully" >&2
      # Re-check opencode capability after install
      if ! have opencode; then
         ensure_bun_in_path # Refresh PATH from bun bin if needed
      fi
      
      # Print instruction if still not found or just as a reminder
      local opencode_path
      opencode_path="$(command -v opencode || true)"
      if [[ -n "$opencode_path" ]]; then
        echo "  ✓ Installed at: $opencode_path" >&2
      else
        echo "  ⚠ Installed but not in PATH. Please run: source ~/.bashrc (or restart shell)" >&2
      fi
    else
      echo "  ⚠ OpenCode CLI update failed" >&2
      if ! have opencode; then
        echo "ERROR: opencode still not found and install failed." >&2
        return 2
      fi
    fi
  fi
  echo "" >&2
  
  # Step 2: Run official oh-my-opencode installer
  echo "[2/3] Configuring oh-my-opencode plugin..." >&2
  if [[ "${DRY_RUN}" == "true" ]]; then
    echo "  [DRY-RUN] Would run: bunx oh-my-opencode install --no-tui --claude=no --gemini=no --copilot=no --openai=no" >&2
  else
    echo "  Running official installer (this configures plugin registration and agent models)..." >&2
    if bunx oh-my-opencode install --no-tui --claude=no --gemini=no --copilot=no --openai=no; then
      echo "  ✓ oh-my-opencode configured successfully" >&2
    else
      echo "  ⚠ oh-my-opencode installer failed (plugin may not work correctly)" >&2
    fi
  fi
  echo "" >&2
  
  # Step 3: Configure opencode-antigravity-auth plugin
  echo "[3/4] Configuring opencode-antigravity-auth plugin..." >&2
  if [[ "${DRY_RUN}" == "true" ]]; then
    echo "  [DRY-RUN] Would run: ${SCRIPT_DIR}/configure-antigravity-auth.sh" >&2
  else
    if [[ -f "${SCRIPT_DIR}/configure-antigravity-auth.sh" ]]; then
      if bash "${SCRIPT_DIR}/configure-antigravity-auth.sh"; then
        echo "  ✓ opencode-antigravity-auth configured successfully" >&2
        echo "  NOTE: Run 'opencode auth login' to authenticate with Google" >&2
      else
        echo "  ⚠ opencode-antigravity-auth configuration failed" >&2
      fi
    else
      echo "  ⚠ configure-antigravity-auth.sh not found, skipping" >&2
    fi
  fi
  echo "" >&2
  
  # Step 4: Update repo-local plugin dependencies
  echo "[4/4] Updating repo-local plugin dependencies..." >&2
  
  # Ensure they are defined first!
  ensure_local_plugins
  
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

check_path_setup() {
  if [[ "${OS:-}" != "Windows_NT" ]]; then
    return 0
  fi
  
  # Only run if running interactively or if we can prompt? 
  # Read-Host needs TTY. We assume typical usage is interactive.
  
  echo "DEBUG: Checking PATH setup on Windows..." >&2
  
  if ! command -v powershell.exe >/dev/null 2>&1; then
    echo "DEBUG: powershell.exe not found, skipping." >&2
    return 0
  fi

  local bun_bin=""
  # Determine bun bin location
  if [[ -n "${USERPROFILE:-}" ]]; then
    bun_bin="${USERPROFILE}\\.bun\\bin"
  fi
  
  # If we know where opencode is, use that
  if have opencode; then
      # cygpath -w converts to Windows format for Powershell
      local opencode_loc
      opencode_loc="$(command -v opencode)"
      echo "DEBUG: Found opencode at: $opencode_loc" >&2
      if command -v cygpath >/dev/null 2>&1; then
          bun_bin="$(cygpath -w "$(dirname "$opencode_loc")")"
      fi
  fi
  
  echo "DEBUG: Target bun_bin: $bun_bin" >&2
  if [[ -n "$bun_bin" ]] && [[ -f "${SCRIPT_DIR}/update-path-windows.ps1" ]]; then
     echo "DEBUG: Invoking update-path-windows.ps1..." >&2
     powershell.exe -ExecutionPolicy Bypass -File "${SCRIPT_DIR}/update-path-windows.ps1" "$bun_bin" || true
  else
     echo "DEBUG: Skipping update-path-windows.ps1 (bin empty or script missing)." >&2
  fi
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
    check_path_setup
    ;;
  update)
    print_status
    update_deps
    if [[ "${DRY_RUN}" == "true" ]]; then
      echo "✓ Dry-run completed (no changes made)" >&2
    else
      echo "✓ Update completed" >&2
    fi
    check_path_setup
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

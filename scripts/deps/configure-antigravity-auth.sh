#!/usr/bin/env bash
# configure-antigravity-auth.sh - Add opencode-antigravity-auth to opencode.json

set -euo pipefail

# Determine config path (cross-platform)
# OpenCode uses ~/.config/opencode on all platforms
if [[ -n "${XDG_CONFIG_HOME:-}" ]]; then
  CONFIG_DIR="${XDG_CONFIG_HOME}/opencode"
else
  CONFIG_DIR="${HOME}/.config/opencode"
fi

CONFIG_FILE="${CONFIG_DIR}/opencode.json"

echo "INFO: Configuring opencode-antigravity-auth plugin..." >&2
echo "INFO: Config file: ${CONFIG_FILE}" >&2

# Create config directory if it doesn't exist
mkdir -p "${CONFIG_DIR}"

# Create or update opencode.json
if [[ ! -f "${CONFIG_FILE}" ]]; then
  echo "INFO: Creating new opencode.json with antigravity-auth plugin..." >&2
  cat > "${CONFIG_FILE}" <<'EOF'
{
  "plugin": [
    "opencode-antigravity-auth@latest"
  ]
}
EOF
else
  # Check if plugin array exists and add antigravity-auth if not present
  if ! grep -q '"opencode-antigravity-auth' "${CONFIG_FILE}"; then
    echo "INFO: Adding opencode-antigravity-auth to existing plugin array..." >&2
    
    # Use a simple approach: if plugin array exists, add to it; otherwise create it
    if grep -q '"plugin"' "${CONFIG_FILE}"; then
      # Plugin array exists, add antigravity-auth to it
      # This is a simple sed approach - for production, consider using jq
      sed -i.bak 's/"plugin":\s*\[/"plugin": [\n    "opencode-antigravity-auth@latest",/' "${CONFIG_FILE}"
    else
      # No plugin array, add one
      sed -i.bak '1s/^{/{\\n  "plugin": ["opencode-antigravity-auth@latest"],/' "${CONFIG_FILE}"
    fi
    
    echo "  ✓ opencode-antigravity-auth added to plugin array" >&2
  else
    echo "  ✓ opencode-antigravity-auth already configured" >&2
  fi
fi

echo "INFO: Configuration complete. Run 'opencode auth login' to authenticate." >&2

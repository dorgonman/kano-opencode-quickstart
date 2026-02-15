#!/usr/bin/env bash
source "$(dirname "$0")/shared/server-common.sh"

echo "=== OpenCode Plugin Debug ==="
if have_cmd opencode; then
  echo "OpenCode found: $(opencode --version)"
  echo "Path: $(command -v opencode)"
else
  echo "ERROR: OpenCode not found in PATH"
fi

if have_cmd oh-my-opencode; then
  echo "oh-my-opencode found: $(oh-my-opencode --version)"
  echo "Path: $(command -v oh-my-opencode)"
else
  echo "WARN: oh-my-opencode not found in PATH"
fi

# Check for opencode.json
FOUND_CONFIG=0

# ~/.config/opencode/opencode.json (used on all platforms)
CFG="$HOME/.config/opencode/opencode.json"
if [[ -f "$CFG" ]]; then
  echo "Found config at: $CFG"
  cat "$CFG"
  FOUND_CONFIG=1
fi

if [[ "$FOUND_CONFIG" -eq 0 ]]; then
  echo "WARN: No opencode.json found in standard locations."
fi

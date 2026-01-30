# Migration Guide: Old Scripts → New opencode-deps-* Family

## Summary

The old `prerequisite.sh` and `update-opencode.sh` scripts have been consolidated into a unified `opencode-deps-*` family of scripts.

## What Changed

### Old Scripts (Deprecated but still functional)
- `prerequisite.sh install` - Install dependencies
- `update-opencode.sh` - Update to latest versions

### New Scripts (Recommended)
- `opencode-deps-install.sh` - Install dependencies (replaces `prerequisite.sh install`)
- `opencode-deps-update.sh` - Update to latest (replaces `update-opencode.sh`)
- `opencode-deps-manager.sh` - Core manager (supports install/update/status)

## Migration Path

### If you were using `prerequisite.sh install`:
```bash
# Old way
./scripts/prerequisite.sh install

# New way (recommended)
./scripts/opencode-deps-install.sh

# Or using manager directly
./scripts/opencode-deps-manager.sh install
```

### If you were using `update-opencode.sh`:
```bash
# Old way
./scripts/update-opencode.sh

# New way (recommended)
./scripts/opencode-deps-update.sh

# Or using manager directly
./scripts/opencode-deps-manager.sh update
```

## Windows PowerShell

### Old Scripts
- `prerequisite.ps1 -Action install`
- `update-opencode.ps1`

### New Scripts
- `opencode-deps-install.ps1`
- `opencode-deps-update.ps1`
- `opencode-deps-manager.ps1 -Action [install|update|status]`

## Benefits of New Scripts

1. **Unified family** - All scripts share `opencode-deps-` prefix
2. **Consistent interface** - Same flags and behavior across install/update
3. **Better status reporting** - Enhanced environment and version display
4. **Single source of truth** - Core logic in manager, wrappers for convenience
5. **Dry-run support** - Preview changes before applying them

## Backward Compatibility

The old scripts (`prerequisite.sh`, `update-opencode.sh`) are still present and functional. You can continue using them, but we recommend migrating to the new family for better maintainability.

## When to Use Which

- **First-time setup**: Use `opencode-deps-install.sh` (installs specified versions)
- **Regular updates**: Use `opencode-deps-update.sh` (updates to latest versions)
- **Check status**: Use `opencode-deps-manager.sh status`
- **Preview changes**: Add `--dry-run` flag to any command

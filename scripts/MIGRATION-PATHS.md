# Scripts Directory Reorganization - Migration Guide

## Overview

The `scripts/` directory has been reorganized by functionality for better maintainability. This guide helps you update any references to the old paths.

## What Changed

Scripts have been moved into categorized subdirectories:

```
scripts/
├── git/        # Git workflow scripts
├── user-mode/  # OpenCode server scripts
├── deps/       # Dependency management
├── utils/      # Utility scripts
├── dev-mode/   # Development mode (unchanged)
├── shared/     # Shared helpers (dev + user)
├── windows/    # Windows-specific (unchanged)
└── docs/       # Documentation files
```

## Path Migration Table

### Git Scripts

| Old Path | New Path |
|----------|----------|
| `scripts/git-setup-upstream.sh` | `scripts/git/setup-upstream.sh` |
| `scripts/git-sync-submodules.sh` | `scripts/git/sync-submodules.sh` |
| `scripts/git-rebase-submodules.sh` | `scripts/git/rebase-submodules.sh` |
| `scripts/GIT-WORKFLOWS.md` | `scripts/git/README.md` |
| `scripts/README-GIT-WRAPPERS.md` | `scripts/git/QUICKSTART.md` |

### Server Scripts

| Old Path | New Path |
|----------|----------|
| `scripts/opencode-server.sh` | `scripts/user-mode/opencode-server.sh` |
| `scripts/start-server-local.sh` | `scripts/user-mode/start-local.sh` |
| `scripts/start-server-tailnet.sh` | `scripts/user-mode/start-tailnet.sh` |
| `scripts/start-server-auth.sh` | `scripts/user-mode/start-auth.sh` |
| `scripts/stop.sh` | `scripts/user-mode/stop.sh` |
| `scripts/status.sh` | `scripts/user-mode/status.sh` |
| `scripts/attach-localhost.sh` | `scripts/user-mode/attach-localhost.sh` |

### Dependency Scripts

| Old Path | New Path |
|----------|----------|
| `scripts/prerequisite.sh` | `scripts/deps/prerequisite.sh` |
| `scripts/prerequisite.ps1` | `scripts/deps/prerequisite.ps1` |
| `scripts/opencode-deps-install.sh` | `scripts/deps/opencode-deps-install.sh` |
| `scripts/opencode-deps-manager.sh` | `scripts/deps/opencode-deps-manager.sh` |
| `scripts/opencode-deps-update.sh` | `scripts/deps/opencode-deps-update.sh` |

### Utility Scripts

| Old Path | New Path |
|----------|----------|
| `scripts/kill-port.sh` | `scripts/utils/kill-port.sh` |
| `scripts/opencode-portability.sh` | `scripts/utils/opencode-portability.sh` |
| `scripts/update-opencode.sh` | `scripts/utils/update-opencode.sh` |

### Documentation Files

| Old Path | New Path |
|----------|----------|
| `scripts/AGENTS.md` | `scripts/docs/AGENTS.md` |
| `scripts/CHANGELOG.md` | `scripts/docs/CHANGELOG.md` |
| `scripts/MIGRATION.md` | `scripts/docs/MIGRATION.md` |
| `scripts/QUICKREF.md` | `scripts/docs/QUICKREF.md` |
| `scripts/UPDATE.md` | `scripts/docs/UPDATE.md` |

## Updated Scripts

The following scripts have been automatically updated to use new paths:

✅ `quickstart.sh` - Updated to reference `scripts/user-mode/` and `scripts/deps/`  
✅ `scripts/dev-mode/quickstart-dev.sh` - Updated to reference `scripts/git/`  
✅ `scripts/user-mode/*.sh` - Already using relative paths (no changes needed)

## How to Update Your Scripts

### If you have custom scripts that reference old paths:

**Before:**
```bash
./scripts/git-setup-upstream.sh
./scripts/start-server-local.sh
./scripts/prerequisite.sh install
```

**After:**
```bash
./scripts/git/setup-upstream.sh
./scripts/user-mode/start-local.sh
./scripts/deps/prerequisite.sh install
```

### If you have documentation that references old paths:

Use find and replace with these patterns:

```bash
# Git scripts
scripts/git-setup-upstream.sh → scripts/git/setup-upstream.sh
scripts/git-sync-submodules.sh → scripts/git/sync-submodules.sh
scripts/git-rebase-submodules.sh → scripts/git/rebase-submodules.sh

# Server scripts
scripts/start-server-local.sh → scripts/user-mode/start-local.sh
scripts/start-server-tailnet.sh → scripts/user-mode/start-tailnet.sh
scripts/start-server-auth.sh → scripts/user-mode/start-auth.sh
scripts/stop.sh → scripts/user-mode/stop.sh
scripts/status.sh → scripts/user-mode/status.sh

# Dependency scripts
scripts/prerequisite.sh → scripts/deps/prerequisite.sh
scripts/prerequisite.ps1 → scripts/deps/prerequisite.ps1

# Utility scripts
scripts/kill-port.sh → scripts/utils/kill-port.sh
scripts/update-opencode.sh → scripts/utils/update-opencode.sh
```

## Quick Reference Commands

### Old Commands (Still Work via Root Scripts)

```bash
# These still work from repo root
./quickstart.sh
./scripts/dev-mode/quickstart-dev.sh
```

### New Commands (Organized by Category)

```bash
# Git operations
./scripts/git/setup-upstream.sh
./scripts/git/sync-submodules.sh
./scripts/git/rebase-submodules.sh

# Server operations
./scripts/user-mode/start-local.sh
./scripts/user-mode/start-tailnet.sh
./scripts/user-mode/start-auth.sh
./scripts/user-mode/stop.sh
./scripts/user-mode/status.sh

# Dependency management
./scripts/deps/prerequisite.sh install
./scripts/deps/opencode-deps-update.sh

# Utilities
./scripts/utils/kill-port.sh 4096
./scripts/utils/update-opencode.sh
```

## Benefits of New Structure

1. **Better Organization**: Scripts grouped by functionality
2. **Easier Discovery**: Clear categories make it easier to find scripts
3. **Improved Maintainability**: Related scripts are together
4. **Cleaner Root**: Less clutter in scripts/ directory
5. **Better Documentation**: Each category has its own README

## Troubleshooting

### "Script not found" errors

If you get errors like:
```
./scripts/git-setup-upstream.sh: No such file or directory
```

Update the path to:
```bash
./scripts/git/setup-upstream.sh
```

### Relative path issues in custom scripts

If your custom script uses relative paths, update them:

**Before:**
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/../scripts/git-setup-upstream.sh"
```

**After:**
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/../scripts/git/setup-upstream.sh"
```

### Documentation references

Search your documentation for old paths and update them using the migration table above.

## Need Help?

- Check [scripts/README.md](README.md) for the new structure overview
- See [scripts/git/README.md](git/README.md) for Git workflow documentation
- Review [scripts/docs/](docs/) for other documentation files

## Rollback (Not Recommended)

If you need to temporarily use old paths, you can create symbolic links:

```bash
cd scripts
ln -s git/setup-upstream.sh git-setup-upstream.sh
ln -s git/sync-submodules.sh git-sync-submodules.sh
ln -s git/rebase-submodules.sh git-rebase-submodules.sh
ln -s user-mode/start-local.sh start-server-local.sh
ln -s user-mode/start-tailnet.sh start-server-tailnet.sh
ln -s user-mode/start-auth.sh start-server-auth.sh
ln -s user-mode/stop.sh stop.sh
ln -s user-mode/status.sh status.sh
ln -s deps/prerequisite.sh prerequisite.sh
ln -s deps/prerequisite.ps1 prerequisite.ps1
ln -s utils/kill-port.sh kill-port.sh
```

However, we recommend updating to the new paths for better long-term maintainability.

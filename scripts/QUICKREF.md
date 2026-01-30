# OpenCode Dependency Scripts - Quick Reference

## Common Commands

### First-time Setup
```bash
./scripts/opencode-deps-install.sh
```

### Update Everything
```bash
./scripts/opencode-deps-update.sh
```

### Check Status
```bash
./scripts/opencode-deps-manager.sh status
```

### Preview Changes (Dry-run)
```bash
./scripts/opencode-deps-update.sh --dry-run
./scripts/opencode-deps-install.sh --dry-run
```

## Windows PowerShell

### First-time Setup
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\windows\opencode-deps-install.ps1
```

### Update Everything
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\windows\opencode-deps-update.ps1
```

### Check Status
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\windows\opencode-deps-manager.ps1 -Action status
```

## What Gets Updated

| Component | Package Name | Update Command |
|-----------|--------------|----------------|
| OpenCode CLI | `opencode-ai` | `bun install -g opencode-ai@latest` |
| oh-my-opencode | `oh-my-opencode` | `bun install -g oh-my-opencode@latest` |
| Plugins | `.opencode/package.json` | `bun update` (uses `"latest"` tag) |

## Script Family

All scripts use the `opencode-deps-` prefix:

- `opencode-deps-manager.sh` - Core manager
- `opencode-deps-install.sh` - Install wrapper
- `opencode-deps-update.sh` - Update wrapper

## Key Differences

| Action | Command | What it does |
|--------|---------|--------------|
| **install** | `opencode-deps-install.sh` | Installs **specified versions** from package.json |
| **update** | `opencode-deps-update.sh` | Updates to **latest versions** |
| **status** | `opencode-deps-manager.sh status` | Shows current versions |

## Troubleshooting

**404 error for opencode**: The package name is `opencode-ai`, not `opencode`. This has been fixed in the scripts.

**oh-my-opencode not found**: This is optional. The script will warn but continue.

**oh-my-opencode not updating to latest**: We use `bun install -g <package>@latest` instead of `bun update -g` because bun update may have caching issues and not fetch the latest version.

**Permission denied**: On Windows, run PowerShell as Administrator for global updates.

## Why `bun install -g @latest` instead of `bun update -g`?

`bun update -g` may use cached package metadata and not fetch the latest version from npm registry. Using `bun install -g <package>@latest` forces bun to check npm registry for the latest version and install it.

## Why use `"latest"` tag in package.json?

We use `"@opencode-ai/plugin": "latest"` in package.json instead of specific versions:

- **`"latest"`**: Always fetches the newest version when running `bun install` or `bun update`
- **`"1.1.44"`**: Fixed version, requires manual update
- **`"^1.1.44"`**: Auto-updates to 1.x.x (may introduce unexpected changes)

For a quickstart repo that should stay current, `"latest"` is the simplest approach. Just run `bun update` to get the newest version!

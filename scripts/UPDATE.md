# OpenCode Dependency Management Scripts

Family of scripts (`opencode-deps-*`) to manage OpenCode CLI, oh-my-opencode, and plugin dependencies.

## Script Family

All scripts share the `opencode-deps-` prefix to indicate they're part of the same family:

- **`opencode-deps-manager.sh`** - Core manager (supports install/update/status)
- **`opencode-deps-install.sh`** - Wrapper for first-time setup
- **`opencode-deps-update.sh`** - Wrapper for updating to latest versions

Windows equivalents in `scripts/windows/`:
- **`opencode-deps-manager.ps1`**
- **`opencode-deps-install.ps1`**
- **`opencode-deps-update.ps1`**

## Usage

### First-time Setup (Install)

Installs dependencies from `package.json` at **specified versions**.

```bash
# Using wrapper (recommended)
./scripts/opencode-deps-install.sh

# Using manager directly
./scripts/opencode-deps-manager.sh install

# Dry-run
./scripts/opencode-deps-install.sh --dry-run
```

Windows PowerShell:

```powershell
# Using wrapper (recommended)
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\windows\opencode-deps-install.ps1

# Using manager directly
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\windows\opencode-deps-manager.ps1 -Action install

# Dry-run
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\windows\opencode-deps-install.ps1 -DryRun
```

### Update to Latest Versions

Updates all components to their **latest versions**.

```bash
# Using wrapper (recommended)
./scripts/opencode-deps-update.sh

# Using manager directly
./scripts/opencode-deps-manager.sh update

# Dry-run
./scripts/opencode-deps-update.sh --dry-run
```

Windows PowerShell:

```powershell
# Using wrapper (recommended)
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\windows\opencode-deps-update.ps1

# Using manager directly
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\windows\opencode-deps-manager.ps1 -Action update

# Dry-run
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\windows\opencode-deps-update.ps1 -DryRun
```

### Check Status

View current environment and dependency versions.

```bash
./scripts/opencode-deps-manager.sh status
```

Windows PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\windows\opencode-deps-manager.ps1 -Action status
```

## What Gets Updated

### Install Mode (`opencode-deps-install.sh`)
- **Plugin dependencies** - Installs versions specified in `.opencode/package.json` via `bun install`
- Use this for **first-time setup** or when you want exact versions

### Update Mode (`opencode-deps-update.sh`)
1. **OpenCode CLI** (`opencode-ai`) - Global installation via `bun install -g opencode-ai@latest`
2. **oh-my-opencode** - Global installation via `bun install -g oh-my-opencode@latest`
3. **Plugin dependencies** - Updates to latest via `bun update` (package.json uses `"latest"` tag)

Use this for **regular updates** to get the latest versions.

> **Note**: 
> - OpenCode's npm package name is `opencode-ai`, not `opencode`.
> - We use `bun install -g <package>@latest` instead of `bun update -g` to ensure the latest version is fetched (bun update may have caching issues).
> - For repo-local plugins, package.json uses `"latest"` tag (e.g., `"@opencode-ai/plugin": "latest"`), so `bun update` always fetches the newest version.

## Prerequisites

- `bun` must be installed and on PATH
- `opencode` must be installed (will be updated by the script)
- Optional: `oh-my-opencode` (will be updated if installed)

## Output

The scripts will:
- Show current environment status (versions of opencode, bun, tailscale, oh-my-opencode)
- Show current plugin dependencies
- Execute the requested action (install/update)
- Display results with clear status indicators ([OK], [WARN], [DRY-RUN])
- Continue even if individual updates fail (with warnings)

## Dry-Run Mode

Use `--dry-run` (bash) or `-DryRun` (PowerShell) to preview what would be updated without making any changes. This is useful for:
- Checking if updates are available
- Verifying the script works correctly
- Understanding what will be updated before committing

## Troubleshooting

**"bun not found"**: Install Bun from https://bun.sh

**"opencode not found"**: Install OpenCode first before running the update script

**"oh-my-opencode update failed"**: This is normal if oh-my-opencode is not installed globally. The script will continue with other updates.

**Plugin update fails**: Check that `.opencode/package.json` exists and is valid JSON.

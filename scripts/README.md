# Scripts Directory

This directory contains all automation scripts for the kano-opencode-quickstart project, organized by functionality.

## Directory Structure

```
scripts/
├── git/                    # Git workflow scripts for submodule management
├── user-mode/              # OpenCode server lifecycle scripts
├── deps/                   # Dependency management scripts
├── utils/                  # Utility scripts
├── dev-mode/              # Development mode scripts
├── shared/                 # Shared helpers (dev + user)
├── windows/               # Windows-specific scripts
└── docs/                  # Documentation files
```

## Quick Start

### First Time Setup

```bash
# 1. Install dependencies
./deps/prerequisite.sh install

# 2. Setup Git upstream remotes for submodules
./git/setup-upstream.sh

# 3. Start OpenCode server
../quickstart.sh
```

### Daily Development

```bash
# Sync submodules with upstream
./git/sync-submodules.sh

# Run OpenCode from source
./dev-mode/quickstart-dev.sh -U
```

## Directory Details

### 📁 git/

Git workflow scripts for managing `src/` submodules (opencode and oh-my-opencode).

**Scripts:**
- `setup-upstream.sh` - Configure upstream remotes (run once)
- `sync-submodules.sh` - Sync with upstream (merge strategy)
- `rebase-submodules.sh` - Rebase onto upstream (clean history)

**Documentation:**
- [README.md](git/README.md) - Detailed Git workflows
- [QUICKSTART.md](git/QUICKSTART.md) - Quick reference guide

**Usage:**
```bash
# Setup upstream remotes
./git/setup-upstream.sh

# Daily sync (merge)
./git/sync-submodules.sh

# Prepare PR (rebase)
./git/rebase-submodules.sh
```

### 📁 user-mode/

OpenCode server lifecycle management scripts.

**Scripts:**
- `opencode-server.sh` - Core server logic (465 lines)
- `start-local.sh` - Start on localhost (no auth)
- `start-tailnet.sh` - Start with Tailscale Serve
- `start-auth.sh` - Start with basic auth (LAN mode)
- `stop.sh` - Stop server and reset Tailscale
- `status.sh` - Check server status
- `attach-localhost.sh` - Attach to local server

**Usage:**
```bash
# Start local server
./user-mode/start-local.sh

# Start with Tailscale
./user-mode/start-tailnet.sh

# Stop server
./user-mode/stop.sh

# Check status
./user-mode/status.sh
```

### 📁 deps/

Dependency management and installation scripts.

**Scripts:**
- `prerequisite.sh` - Install .opencode/package.json dependencies (Bash)
- `prerequisite.ps1` - Install dependencies (PowerShell)
- `opencode-deps-install.sh` - Install OpenCode dependencies
- `opencode-deps-manager.sh` - Manage dependencies
- `opencode-deps-update.sh` - Update dependencies

**Usage:**
```bash
# First run (install dependencies)
./deps/prerequisite.sh install

# Update dependencies
./deps/opencode-deps-update.sh
```

### 📁 utils/

Utility scripts for various tasks.

**Scripts:**
- `kill-port.sh` - Free occupied ports (Unix)
- `opencode-portability.sh` - Cross-platform path resolution helpers
- `update-opencode.sh` - Update OpenCode installation

**Usage:**
```bash
# Kill process on port 4096
./utils/kill-port.sh 4096

# Update OpenCode
./utils/update-opencode.sh
```

### 📁 dev-mode/

Development mode scripts for running OpenCode from source.

**Scripts:**
- `quickstart-dev.sh` - Run OpenCode from source with Git workflow integration

**Usage:**
```bash
# Run without sync
./dev-mode/quickstart-dev.sh

# Sync and run (merge)
./dev-mode/quickstart-dev.sh -U

# Rebase and run
./dev-mode/quickstart-dev.sh -R

# Skip sync
./dev-mode/quickstart-dev.sh -S
```

### 📁 shared/

Shared helpers used by dev-mode and user-mode.

**Scripts:**
- `server-common.sh` - Tailscale, auth, and port utilities

### 📁 windows/

Windows-specific scripts (PowerShell).

**Scripts:**
- `tailnet-service.ps1` - Windows service management (experimental)
- `kill-port.ps1` - Free occupied ports (PowerShell)

**Usage:**
```powershell
# Bootstrap service (elevated prompt)
powershell -NoProfile -ExecutionPolicy Bypass -File windows\tailnet-service.ps1 -Action bootstrap

# Check service
sc.exe query opencode-tailnet
```

### 📁 docs/

Documentation files.

**Files:**
- `AGENTS.md` - Agent-specific instructions
- `CHANGELOG.md` - Change history
- `MIGRATION.md` - Migration guides
- `QUICKREF.md` - Quick reference
- `UPDATE.md` - Update instructions

## Common Workflows

### Development Workflow

```bash
# 1. Sync submodules
./git/sync-submodules.sh

# 2. Run from source
./dev-mode/quickstart-dev.sh

# 3. Make changes in src/opencode or src/oh-my-opencode
cd ../src/opencode
# ... edit files ...
git add .
git commit -m "Your changes"

# 4. Push to your fork
git push origin dev
```

### Server Management

```bash
# Start server (auto-detect mode)
cd ..
./quickstart.sh

# Or use specific mode
./scripts/user-mode/start-local.sh      # Localhost only
./scripts/user-mode/start-tailnet.sh    # Tailscale
./scripts/user-mode/start-auth.sh       # LAN with auth

# Stop server
./scripts/user-mode/stop.sh

# Check status
./scripts/user-mode/status.sh
```

### Dependency Management

```bash
# First time setup
./deps/prerequisite.sh install

# Update dependencies
./deps/opencode-deps-update.sh

# Manage dependencies
./deps/opencode-deps-manager.sh
```

## Path Updates

If you have existing scripts or documentation that reference old paths, update them as follows:

### Git Scripts
- `./scripts/git-setup-upstream.sh` → `./scripts/git/setup-upstream.sh`
- `./scripts/git-sync-submodules.sh` → `./scripts/git/sync-submodules.sh`
- `./scripts/git-rebase-submodules.sh` → `./scripts/git/rebase-submodules.sh`

### Server Scripts
- `./scripts/start-server-local.sh` → `./scripts/user-mode/start-local.sh`
- `./scripts/start-server-tailnet.sh` → `./scripts/user-mode/start-tailnet.sh`
- `./scripts/start-server-auth.sh` → `./scripts/user-mode/start-auth.sh`
- `./scripts/stop.sh` → `./scripts/user-mode/stop.sh`
- `./scripts/status.sh` → `./scripts/user-mode/status.sh`

### Dependency Scripts
- `./scripts/prerequisite.sh` → `./scripts/deps/prerequisite.sh`
- `./scripts/prerequisite.ps1` → `./scripts/deps/prerequisite.ps1`

### Utility Scripts
- `./scripts/kill-port.sh` → `./scripts/utils/kill-port.sh`
- `./scripts/update-opencode.sh` → `./scripts/utils/update-opencode.sh`

## Architecture

### Git Scripts Architecture

The Git scripts use the **kano-git-master-skill** helper library:

```
scripts/git/*.sh
    ↓ sources
skills/kano-git-master-skill/scripts/git-helpers.sh
    ↓ provides
- Vendor-agnostic Git operations
- Stash management
- Branch detection
- Remote operations
- Error handling
```

**Benefits:**
- Works with any Git hosting provider (GitHub, GitLab, Azure Repos, etc.)
- Consistent error handling
- Automatic stash management
- Dry-run support
- Cross-platform compatible

### Server Scripts Architecture

```
quickstart.sh (root)
    ↓ calls
scripts/user-mode/start-*.sh
    ↓ calls
scripts/user-mode/opencode-server.sh
    ↓ manages
OpenCode server + Tailscale Serve
```

## Troubleshooting

### Scripts Not Executable

```bash
# Make scripts executable
find scripts -name "*.sh" -type f -exec chmod +x {} \;
```

### Git Helper Library Not Found

```bash
# Initialize kano-git-master-skill submodule
git submodule update --init --recursive skills/kano-git-master-skill
```

### Submodules Not Initialized

```bash
# Initialize src/ submodules
git submodule update --init --recursive src/opencode src/oh-my-opencode
```

### Port Already in Use

```bash
# Unix/Git Bash
./utils/kill-port.sh 4096

# Windows PowerShell
powershell -File windows/kill-port.ps1 -Port 4096
```

## See Also

- [Git Workflows](git/README.md) - Detailed Git workflow documentation
- [Git Quick Start](git/QUICKSTART.md) - Quick reference for Git operations
- [Project Root README](../README.md) - Main project documentation
- [kano-git-master-skill](../skills/kano-git-master-skill/SKILL.md) - Git helper library

## Contributing

When adding new scripts:

1. Place them in the appropriate category directory
2. Follow existing naming conventions
3. Add usage documentation to this README
4. Use `set -euo pipefail` for Bash scripts
5. Include help text (`--help` flag)
6. Support dry-run mode where applicable

## Support

For issues or questions:
1. Check the relevant directory's README
2. Review documentation in `docs/`
3. Run scripts with `--help` for usage information
4. Check script output for error messages

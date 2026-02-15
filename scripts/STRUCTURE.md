# Scripts Directory Structure

## Visual Overview

```
scripts/
├── README.md                          # Main documentation (you are here)
├── MIGRATION-PATHS.md                 # Path migration guide
├── STRUCTURE.md                       # This file
│
├── git/                               # Git Workflow Scripts
│   ├── README.md                      # Detailed Git workflows guide
│   ├── QUICKSTART.md                  # Quick reference
│   ├── setup-upstream.sh              # Configure upstream remotes
│   ├── sync-submodules.sh             # Sync with upstream (merge)
│   └── rebase-submodules.sh           # Rebase onto upstream
│
├── user-mode/                         # OpenCode Server Scripts
│   ├── opencode-server.sh             # Core server logic (465 lines)
│   ├── start-local.sh                 # Start on localhost
│   ├── start-tailnet.sh               # Start with Tailscale
│   ├── start-auth.sh                  # Start with basic auth
│   ├── stop.sh                        # Stop server
│   ├── status.sh                      # Check status
│   └── attach-localhost.sh            # Attach to local server
│
├── deps/                              # Dependency Management
│   ├── prerequisite.sh                # Install dependencies (Bash)
│   ├── prerequisite.ps1               # Install dependencies (PowerShell)
│   ├── opencode-deps-install.sh       # Install OpenCode deps
│   ├── opencode-deps-manager.sh       # Manage dependencies
│   └── opencode-deps-update.sh        # Update dependencies
│
├── utils/                             # Utility Scripts
│   ├── kill-port.sh                   # Free occupied ports
│   ├── opencode-portability.sh        # Cross-platform helpers
│   └── update-opencode.sh             # Update OpenCode
│
├── dev-mode/                          # Development Mode
│   ├── quickstart-dev.sh              # Run OpenCode from source
│   ├── start-local.sh                 # Start dev server on localhost
│   ├── start-tailnet.sh               # Start dev server with Tailscale
│   ├── start-auth.sh                  # Start dev server with basic auth
│   ├── stop.sh                        # Stop dev server
│   └── status.sh                      # Dev server status
│
├── shared/                             # Shared Script Helpers
│   └── server-common.sh               # Common server helpers (dev + user)
│
├── windows/                           # Windows-Specific Scripts
│   ├── AGENTS.md                      # Windows agent instructions
│   ├── kill-port.ps1                  # Free ports (PowerShell)
│   ├── opencode-deps-*.ps1            # Dependency scripts
│   ├── tailnet-service.ps1            # Windows service management
│   └── update-opencode.ps1            # Update script
│
└── docs/                              # Documentation
    ├── AGENTS.md                      # Agent-specific instructions
    ├── CHANGELOG.md                   # Change history
    ├── MIGRATION.md                   # Migration guides
    ├── QUICKREF.md                    # Quick reference
    └── UPDATE.md                      # Update instructions
```

## File Count by Category

```
git/        : 5 files (3 scripts + 2 docs)
user-mode/  : 7 files (7 scripts)
deps/       : 5 files (3 .sh + 2 .ps1)
utils/      : 3 files (3 scripts)
dev-mode/   : 6 files (6 scripts)
shared/     : 1 file  (1 script)
windows/    : 6 files (5 .ps1 + 1 doc)
docs/       : 5 files (5 docs)
root/       : 3 files (3 docs)
────────────────────────────────
Total       : 41 files
```

## Script Categories

### 🔧 Git Workflow (git/)

**Purpose**: Manage src/ submodules with upstream synchronization

**Key Scripts**:
- `setup-upstream.sh` - One-time setup of upstream remotes
- `sync-submodules.sh` - Daily sync with merge strategy
- `rebase-submodules.sh` - Clean history with rebase strategy

**Use Cases**:
- Fork synchronization
- Pull request preparation
- Daily development workflow

**Dependencies**: kano-git-master-skill helper library

### 🚀 Server Management (user-mode/)

**Purpose**: OpenCode server lifecycle management

**Key Scripts**:
- `opencode-server.sh` - Core server implementation
- `start-*.sh` - Different server modes (local/tailnet/auth)
- `stop.sh` - Graceful shutdown
- `status.sh` - Health check

**Use Cases**:
- Local development
- Tailscale remote access
- LAN deployment with auth

**Features**: Tailscale Serve integration, PID tracking, port management

### 📦 Dependencies (deps/)

**Purpose**: Manage OpenCode and plugin dependencies

**Key Scripts**:
- `prerequisite.sh/.ps1` - First-time setup
- `opencode-deps-install.sh` - Install dependencies
- `opencode-deps-update.sh` - Update dependencies

**Use Cases**:
- First-time setup
- Dependency updates
- Plugin management

**Requirements**: Bun for OpenCode UI plugins

### 🛠️ Utilities (utils/)

**Purpose**: Common utility functions

**Key Scripts**:
- `kill-port.sh` - Port cleanup
- `opencode-portability.sh` - Cross-platform helpers
- `update-opencode.sh` - Update OpenCode

**Use Cases**:
- Port conflict resolution
- Cross-platform compatibility
- OpenCode updates

### 💻 Development Mode (dev-mode/)

**Purpose**: Run OpenCode from source code

**Key Scripts**:
- `quickstart-dev.sh` - Integrated development workflow
- `start-*.sh` - Dev server modes (local/tailnet/auth)
- `stop.sh` - Dev server shutdown
- `status.sh` - Dev server status

**Features**:
- Git workflow integration (-U/-R flags)
- Automatic upstream setup
- Dependency management
- Source code execution

**Use Cases**:
- OpenCode development
- Plugin development
- Testing changes

### 🧩 Shared Helpers (shared/)

**Purpose**: Common server helpers used by dev and user modes

**Key Script**:
- `server-common.sh` - Tailscale, auth, and port utilities

### 🪟 Windows Support (windows/)

**Purpose**: Windows-specific implementations

**Key Scripts**:
- `tailnet-service.ps1` - Windows service (experimental)
- `kill-port.ps1` - PowerShell port cleanup
- `*-deps-*.ps1` - PowerShell dependency scripts

**Use Cases**:
- Windows service deployment
- PowerShell automation
- Windows-specific operations

**Note**: Service mode is experimental (known issues with process cleanup)

### 📚 Documentation (docs/)

**Purpose**: Project documentation and guides

**Files**:
- `AGENTS.md` - Agent-specific instructions
- `CHANGELOG.md` - Version history
- `MIGRATION.md` - Migration guides
- `QUICKREF.md` - Quick reference
- `UPDATE.md` - Update procedures

## Common Workflows

### First-Time Setup

```bash
# 1. Install dependencies
./scripts/deps/prerequisite.sh install

# 2. Setup Git upstream remotes
./scripts/git/setup-upstream.sh

# 3. Start server
./quickstart.sh
```

### Daily Development

```bash
# Sync submodules
./scripts/git/sync-submodules.sh

# Run from source
./scripts/dev-mode/quickstart-dev.sh -U
```

### Server Operations

```bash
# Start (auto-detect mode)
./quickstart.sh

# Or specific mode
./scripts/user-mode/start-local.sh
./scripts/user-mode/start-tailnet.sh
./scripts/user-mode/start-auth.sh

# Stop
./scripts/user-mode/stop.sh

# Status
./scripts/user-mode/status.sh
```

### Pull Request Preparation

```bash
# Rebase onto upstream
./scripts/git/rebase-submodules.sh

# Resolve conflicts if needed
cd src/opencode
git rebase --continue

# Force push
git push --force-with-lease origin dev
```

## Design Principles

### Organization

1. **Functional Grouping**: Scripts grouped by purpose
2. **Clear Naming**: Descriptive names without prefixes
3. **Consistent Structure**: Each category has similar layout
4. **Documentation**: README in each major category

### Conventions

1. **Bash Scripts**: `set -euo pipefail`, usage functions, help flags
2. **PowerShell Scripts**: `-NoProfile -ExecutionPolicy Bypass`
3. **Relative Paths**: Scripts use `SCRIPT_DIR` for portability
4. **Error Handling**: Clear error messages with recovery instructions

### Dependencies

1. **Git Scripts**: Depend on kano-git-master-skill
2. **Server Scripts**: Self-contained, minimal dependencies
3. **Dependency Scripts**: Manage external dependencies
4. **Utility Scripts**: Provide reusable functions

## Migration from Old Structure

See [MIGRATION-PATHS.md](MIGRATION-PATHS.md) for detailed migration guide.

**Quick Summary**:
- Git scripts: `scripts/git-*.sh` → `scripts/git/*.sh`
- Server scripts: `scripts/start-server-*.sh` → `scripts/user-mode/start-*.sh`
- Dependency scripts: `scripts/prerequisite.*` → `scripts/deps/prerequisite.*`
- Utility scripts: `scripts/kill-port.sh` → `scripts/utils/kill-port.sh`
- Documentation: `scripts/*.md` → `scripts/docs/*.md`

## Benefits

### Before Reorganization

```
scripts/
├── 25+ files in root directory
├── Mixed purposes (git, server, deps, utils)
├── Inconsistent naming (git-*, start-server-*, opencode-*)
└── Hard to discover related scripts
```

### After Reorganization

```
scripts/
├── 7 categorized subdirectories
├── Clear functional separation
├── Consistent naming within categories
├── Easy discovery and navigation
└── Better documentation structure
```

### Improvements

✅ **Better Organization**: Related scripts grouped together  
✅ **Easier Discovery**: Clear categories for finding scripts  
✅ **Improved Maintainability**: Logical structure for updates  
✅ **Cleaner Root**: Only 3 files in scripts/ root  
✅ **Better Documentation**: Category-specific READMEs  
✅ **Consistent Naming**: No more mixed prefixes  

## See Also

- [README.md](README.md) - Main scripts documentation
- [MIGRATION-PATHS.md](MIGRATION-PATHS.md) - Path migration guide
- [git/README.md](git/README.md) - Git workflows
- [docs/](docs/) - Additional documentation

# Git Wrapper Scripts for kano-opencode-quickstart

## Quick Start

```bash
# 1. Setup upstream remotes (run once)
./scripts/git-setup-upstream.sh

# 2. Daily sync with upstream (merge strategy)
./scripts/git-sync-submodules.sh

# OR: Rebase onto upstream (cleaner history)
./scripts/git-rebase-submodules.sh

# 3. Run OpenCode from source with sync
./scripts/dev-mode/quickstart-dev.sh -U
```

## What's New

This repository now includes Git wrapper scripts that use the **kano-git-master-skill** library for managing the `src/` submodules:

- **src/opencode**: Your fork of OpenCode (upstream: anomalyco/opencode)
- **src/oh-my-opencode**: Your fork of oh-my-opencode (upstream: code-yeongyu/oh-my-opencode)

## Scripts Overview

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `git-setup-upstream.sh` | Configure upstream remotes | Once after cloning |
| `git-sync-submodules.sh` | Fetch + merge from upstream | Daily development |
| `git-rebase-submodules.sh` | Fetch + rebase onto upstream | Before pull requests |
| `dev-mode/quickstart-dev.sh` | Run OpenCode from source | Development & testing |

## Detailed Usage

### 1. git-setup-upstream.sh

**Purpose**: Configure upstream remotes for both submodules

```bash
# Setup upstream remotes
./scripts/git-setup-upstream.sh

# Preview what would be done
./scripts/git-setup-upstream.sh --dry-run
```

**Configures:**
- `src/opencode` → upstream: `https://github.com/anomalyco/opencode.git`
- `src/oh-my-opencode` → upstream: `https://github.com/code-yeongyu/oh-my-opencode.git`

### 2. git-sync-submodules.sh

**Purpose**: Sync submodules with upstream using merge strategy

```bash
# Fetch and merge from upstream
./scripts/git-sync-submodules.sh

# Only fetch, don't update working tree
./scripts/git-sync-submodules.sh --fetch-only

# Preview operations
./scripts/git-sync-submodules.sh --dry-run
```

**Features:**
- Automatically stashes local changes
- Merges upstream changes
- Restores stashed changes
- Handles conflicts gracefully

### 3. git-rebase-submodules.sh

**Purpose**: Rebase submodules onto upstream for clean history

```bash
# Rebase onto upstream/current-branch
./scripts/git-rebase-submodules.sh

# Rebase onto specific remote
./scripts/git-rebase-submodules.sh --remote origin

# Rebase onto specific branch
./scripts/git-rebase-submodules.sh --branch main

# Preview operations
./scripts/git-rebase-submodules.sh --dry-run
```

**Features:**
- Creates linear history (no merge commits)
- Automatically stashes local changes
- Provides conflict resolution instructions
- Ideal for preparing pull requests

### 4. dev-mode/quickstart-dev.sh (Refactored)

**Purpose**: Run OpenCode from source with integrated Git workflows

```bash
# Start without syncing
./scripts/dev-mode/quickstart-dev.sh

# Sync with upstream (merge)
./scripts/dev-mode/quickstart-dev.sh -U

# Rebase onto upstream
./scripts/dev-mode/quickstart-dev.sh -R

# Skip sync entirely
./scripts/dev-mode/quickstart-dev.sh -S

# With custom workspace
./scripts/dev-mode/quickstart-dev.sh -U /path/to/workspace
```

**Changes from original:**
- Now uses `kano-git-master-skill` helper library
- Supports both merge (`-U`) and rebase (`-R`) strategies
- Automatically sets up upstream remotes if missing
- Better error handling and logging

## Workflow Examples

### Daily Development

```bash
# Morning: sync with upstream
./scripts/git-sync-submodules.sh

# Make changes
cd src/opencode
# ... edit files ...
git add .
git commit -m "Add feature X"

# Test changes
./scripts/dev-mode/quickstart-dev.sh

# Push to your fork
git push origin dev
```

### Preparing Pull Request

```bash
# Rebase onto latest upstream
./scripts/git-rebase-submodules.sh

# If conflicts occur, resolve them
cd src/opencode
git status
# ... resolve conflicts ...
git add .
git rebase --continue

# Force push to your fork
git push --force-with-lease origin dev

# Create PR on GitHub
```

### Quick Test Run

```bash
# Run OpenCode with latest upstream changes
./scripts/dev-mode/quickstart-dev.sh -U
```

## Architecture

These scripts leverage the **kano-git-master-skill** library which provides:

✓ **Vendor-agnostic**: Works with GitHub, GitLab, Azure Repos, Bitbucket, self-hosted Git  
✓ **Robust error handling**: Clear, actionable error messages  
✓ **Automatic stash management**: Preserves local changes during operations  
✓ **Dry-run support**: Preview operations before executing  
✓ **Cross-platform**: Works on Unix shells and Git Bash on Windows  

## Troubleshooting

### "git-helpers.sh not found"

```bash
# Initialize kano-git-master-skill submodule
git submodule update --init --recursive skills/kano-git-master-skill
```

### "Submodule not found"

```bash
# Initialize src/ submodules
git submodule update --init --recursive src/opencode src/oh-my-opencode
```

### "Remote 'upstream' not found"

```bash
# Run setup script
./scripts/git-setup-upstream.sh
```

### Merge/Rebase Conflicts

```bash
# For merge conflicts:
cd src/opencode
git status
# ... resolve conflicts ...
git add .
git merge --continue

# For rebase conflicts:
cd src/opencode
git status
# ... resolve conflicts ...
git add .
git rebase --continue

# Or abort:
git merge --abort  # or git rebase --abort
```

### Scripts Not Executable

```bash
# Make scripts executable
chmod +x scripts/git-*.sh
chmod +x scripts/dev-mode/quickstart-dev.sh
```

## Comparison: Old vs New

### Old Approach (quickstart-dev.sh)
```bash
# Used git submodule update --remote --merge
# Limited error handling
# No upstream remote management
# No rebase option
```

### New Approach (with kano-git-master-skill)
```bash
# Uses vendor-agnostic helper library
# Comprehensive error handling
# Automatic upstream remote setup
# Supports both merge and rebase
# Stash management
# Dry-run mode
# Better logging
```

## Benefits

1. **Consistency**: All Git operations use the same tested helper library
2. **Flexibility**: Choose between merge and rebase strategies
3. **Safety**: Automatic stashing prevents data loss
4. **Visibility**: Dry-run mode lets you preview operations
5. **Maintainability**: Centralized Git logic in kano-git-master-skill
6. **Vendor-agnostic**: Works with any Git hosting provider

## See Also

- [GIT-WORKFLOWS.md](./GIT-WORKFLOWS.md) - Detailed workflow documentation
- [kano-git-master-skill](../skills/kano-git-master-skill/SKILL.md) - Helper library documentation
- [Git Submodules](https://git-scm.com/book/en/v2/Git-Tools-Submodules) - Official Git documentation

## Support

For issues or questions:
1. Check [GIT-WORKFLOWS.md](./GIT-WORKFLOWS.md) for detailed troubleshooting
2. Review [kano-git-master-skill](../skills/kano-git-master-skill/SKILL.md) documentation
3. Run scripts with `--dry-run` to preview operations
4. Check script output for error messages and recovery instructions

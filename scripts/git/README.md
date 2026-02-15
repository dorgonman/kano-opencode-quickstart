# Git Workflows for kano-opencode-quickstart

This document describes the Git workflow scripts for managing the `src/` submodules in this repository.

## Submodules Overview

This repository contains two submodules in the `src/` directory:

### src/opencode
- **Origin**: `https://github.com/dorgonman/opencode.git` (your fork)
- **Upstream**: `https://github.com/anomalyco/opencode.git` (original)
- **Branch**: `dev`

### src/oh-my-opencode
- **Origin**: `https://github.com/dorgonman/oh-my-opencode.git` (your fork)
- **Upstream**: `https://github.com/code-yeongyu/oh-my-opencode.git` (original)
- **Branch**: `dev`

## Available Scripts

All scripts are located in `scripts/` directory and use the `kano-git-master-skill` helper library for vendor-agnostic Git operations.

### 1. Setup Upstream Remotes

**Script**: `./scripts/git-setup-upstream.sh`

Sets up the upstream remotes for both submodules. Run this once after cloning the repository.

```bash
# Setup upstream remotes
./scripts/git-setup-upstream.sh

# Dry-run mode (show what would be done)
./scripts/git-setup-upstream.sh --dry-run
```

**What it does:**
- Adds `upstream` remote to `src/opencode` pointing to `anomalyco/opencode`
- Adds `upstream` remote to `src/oh-my-opencode` pointing to `code-yeongyu/oh-my-opencode`
- Fetches from upstream remotes
- Verifies existing upstream URLs and updates if needed

### 2. Sync Submodules (Merge Strategy)

**Script**: `./scripts/git-sync-submodules.sh`

Syncs submodules with their upstream repositories using merge strategy. This is safer for preserving your local commits.

```bash
# Sync both submodules (fetch + merge)
./scripts/git-sync-submodules.sh

# Only fetch, don't update working tree
./scripts/git-sync-submodules.sh --fetch-only

# Dry-run mode
./scripts/git-sync-submodules.sh --dry-run
```

**What it does:**
1. Fetches from both `origin` and `upstream` remotes
2. Stashes any local changes
3. Merges `upstream/<current-branch>` into your current branch
4. Restores stashed changes
5. Handles conflicts gracefully with recovery instructions

**When to use:**
- You want to incorporate upstream changes while preserving your merge history
- You have local commits that you want to keep
- You prefer merge commits over rebasing

### 3. Rebase Submodules (Rebase Strategy)

**Script**: `./scripts/git-rebase-submodules.sh`

Rebases submodules onto their upstream repositories. This creates a cleaner, linear history.

```bash
# Rebase both submodules onto upstream
./scripts/git-rebase-submodules.sh

# Rebase onto a specific remote
./scripts/git-rebase-submodules.sh --remote origin

# Rebase onto a specific branch
./scripts/git-rebase-submodules.sh --branch main

# Dry-run mode
./scripts/git-rebase-submodules.sh --dry-run
```

**What it does:**
1. Fetches from the specified remote (default: `upstream`)
2. Stashes any local changes
3. Rebases current branch onto `upstream/<target-branch>`
4. Restores stashed changes
5. Provides conflict resolution instructions if rebase fails

**When to use:**
- You want a clean, linear history
- You're comfortable with rebasing
- You want to avoid merge commits
- You're preparing to submit a pull request

### 4. Developer Mode (Integrated Workflow)

**Script**: `./scripts/dev-mode/start-build-native.sh`

Runs OpenCode from source with integrated Git workflow options.

```bash
# Start without syncing
./scripts/dev-mode/start-build-native.sh

# Sync with upstream (merge strategy)
./scripts/dev-mode/start-build-native.sh -U

# Rebase onto upstream
./scripts/dev-mode/start-build-native.sh -R

# Skip sync entirely
./scripts/dev-mode/start-build-native.sh -S

# Specify workspace path
./scripts/dev-mode/start-build-native.sh -U /path/to/workspace
```

**What it does:**
1. Ensures submodules are initialized
2. Sets up upstream remotes if not configured
3. Optionally syncs or rebases submodules
4. Installs dependencies if needed
5. Runs OpenCode from source

## Workflow Recommendations

### Daily Development Workflow

```bash
# 1. Start your day by syncing with upstream
./scripts/git-sync-submodules.sh

# 2. Make your changes in src/opencode or src/oh-my-opencode
cd src/opencode
# ... make changes ...
git add .
git commit -m "Your changes"

# 3. Run OpenCode to test
./scripts/dev-mode/start-build-native.sh

# 4. Push to your fork
cd src/opencode
git push origin dev
```

### Preparing a Pull Request

```bash
# 1. Rebase onto latest upstream
./scripts/git-rebase-submodules.sh

# 2. Resolve any conflicts if needed
cd src/opencode
git status
# ... resolve conflicts ...
git rebase --continue

# 3. Force push to your fork (rebase rewrites history)
git push --force-with-lease origin dev

# 4. Create pull request on GitHub
```

### Recovering from Conflicts

If sync or rebase fails due to conflicts:

```bash
# For merge conflicts (after git-sync-submodules.sh):
cd src/opencode
git status                    # See conflicted files
# ... resolve conflicts ...
git add .
git merge --continue

# For rebase conflicts (after git-rebase-submodules.sh):
cd src/opencode
git status                    # See conflicted files
# ... resolve conflicts ...
git add .
git rebase --continue

# Or abort and try again:
git rebase --abort
```

## Architecture

These scripts use the `kano-git-master-skill` helper library (`skills/kano-git-master-skill/scripts/git-helpers.sh`) which provides:

- **Vendor-agnostic Git operations**: Works with GitHub, GitLab, Azure Repos, Bitbucket, self-hosted Git, etc.
- **Consistent error handling**: Clear, actionable error messages
- **Stash management**: Automatic stashing and restoration of local changes
- **Dry-run support**: Preview operations before executing
- **Cross-platform compatibility**: Works on Unix shells and Git Bash on Windows

## Troubleshooting

### Upstream remote not found

```bash
# Run setup script
./scripts/git-setup-upstream.sh
```

### Submodules not initialized

```bash
# Initialize submodules
git submodule update --init --recursive src/opencode src/oh-my-opencode
```

### Stash conflicts after sync/rebase

If stash pop fails, you'll see recovery instructions. Manually apply the stash:

```bash
cd src/opencode
git stash list                # Find your stash
git stash show stash@{0}      # Review changes
git stash apply stash@{0}     # Apply without removing
# ... resolve conflicts ...
git stash drop stash@{0}      # Remove stash after successful apply
```

### Permission denied (scripts not executable)

```bash
# Make scripts executable
chmod +x scripts/git-*.sh
chmod +x scripts/dev-mode/start-build-native.sh
```

## Advanced Usage

### Custom Remote Names

If you use different remote names:

```bash
# Rebase onto a custom remote
./scripts/git-rebase-submodules.sh --remote my-upstream

# Sync with a custom remote
# (Edit the script to change default remote)
```

### Selective Submodule Operations

To operate on a single submodule, use the git-helpers.sh functions directly:

```bash
# Source the helper library
source skills/kano-git-master-skill/scripts/git-helpers.sh

# Fetch from upstream for opencode only
gith_fetch_remote "upstream" "src/opencode"

# Check if branch exists
gith_branch_exists_on_remote "upstream" "dev" "src/opencode"
```

## See Also

- [kano-git-master-skill Documentation](../skills/kano-git-master-skill/SKILL.md)
- [Git Submodules Documentation](https://git-scm.com/book/en/v2/Git-Tools-Submodules)
- [Git Rebase vs Merge](https://www.atlassian.com/git/tutorials/merging-vs-rebasing)

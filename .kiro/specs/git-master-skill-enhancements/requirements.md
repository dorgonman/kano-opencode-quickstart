# Requirements: Git Master Skill Enhancements

## Overview
Enhance the kano-git-master-skill with improved Git automation scripts for repository cloning, upstream management, and comprehensive update workflows.

## User Stories

### 1. Clone Repository with Upstream Support
As a developer, I want to clone a repository and optionally set up an upstream remote, so that I can easily track both my fork and the original repository.

**Acceptance Criteria:**
- Clone a repository from a given URL
- Checkout to the remote's default branch (not hardcoded to 'main')
- Pull to the latest commit
- Optionally accept a second URL to set as 'upstream' remote
- Follow existing script conventions (set -euo pipefail, usage function, error handling)

### 2. Rename Rebase Script for Clarity
As a developer, I want the rebase script to have a clearer name that reflects its purpose of rebasing to upstream, so that the intent is immediately obvious.

**Acceptance Criteria:**
- Rename `rebase-to-latest-main.sh` to `rebase-to-upstream-latest.sh` (or better alternative)
- Update script to work with upstream remote by default
- Maintain backward compatibility with existing functionality
- Update any documentation or references to the old script name

### 3. Discover All Repositories in Workspace
As a developer, I want to automatically discover all Git repositories in my workspace (including submodules and standalone repos), so that I can manage them collectively without manual tracking.

**Acceptance Criteria:**
- Discover root repository
- Discover all submodules (via .gitmodules)
- Discover standalone repositories (not in submodules) within workspace
- Support configurable search depth
- Support exclude patterns (node_modules, .cache, etc.)
- Output in multiple formats (JSON, plain list)
- Support saving to manifest file for reuse
- Distinguish between repo types (root, submodule, standalone)

### 4. Update All Repositories in Workspace
As a developer, I want to update all repositories in my workspace (submodules and standalone repos) with a single command, so that I can keep my entire development environment synchronized.

**Acceptance Criteria:**
- Update root repository with smart branch detection
- Update all submodules recursively
- Update standalone repositories (non-submodule repos in workspace)
- Stash/pop local changes for each repo
- Smart branch detection: rebase to matching remote branch or default branch
- Support manifest file or auto-discovery
- Support filtering by repo type (root, submodule, standalone)
- Support exclude patterns
- Parallel update support (optional)
- Clear progress reporting for each repo
- Error handling per repo (continue or stop on error)

### 5. Execute Commands Across All Repositories
As a developer, I want to execute the same Git command across all repositories in my workspace, so that I can perform batch operations efficiently.

**Acceptance Criteria:**
- Execute custom commands in all discovered repos
- Support manifest file or auto-discovery
- Support filtering by repo type
- Support exclude patterns
- Continue on error or stop on first error (configurable)
- Collect and display results from all repos
- Support parallel execution (optional)
- Clear output showing which repo each result belongs to

### 6. Status Report for All Repositories
As a developer, I want to see a comprehensive status report for all repositories in my workspace, so that I can quickly identify which repos need attention.

**Acceptance Criteria:**
- Show status for root, submodules, and standalone repos
- Display current branch for each repo
- Show uncommitted changes count
- Show unpushed commits count
- Show if repo is ahead/behind remote
- Show last commit date/time
- Support multiple output formats (table, JSON, markdown)
- Support filtering and sorting
- Optionally check remote status (slower but more accurate)

### 7. Shared Helper Library for Repository Operations
As a script developer, I want a shared library of common Git operations, so that all scripts can reuse the same tested logic and maintain consistency.

**Acceptance Criteria:**
- Extract common functions into git-helpers.sh library
- Functions for: stash management, branch detection, remote operations, repo discovery
- All existing and new scripts source the helper library
- Helper functions are well-documented
- Helper functions have consistent error handling
- Helper functions support dry-run mode where applicable

## Technical Constraints

1. All scripts must follow existing conventions:
   - Use `#!/usr/bin/env bash`
   - Set `set -euo pipefail`
   - Provide `usage()` function with clear help text
   - Support `--help` and `-h` flags
   - Use `--dry-run` for preview mode where applicable

2. Scripts must be cross-platform compatible (Git Bash on Windows, Unix shells)

3. Must integrate with existing scripts:
   - `submodule-sync-urls.sh` for URL synchronization
   - Follow patterns from `rebase-to-latest-main.sh`

4. Error handling requirements:
   - Check if inside a git repository
   - Verify remotes exist before operations
   - Don't pop stash if operations fail
   - Provide clear error messages

## Dependencies

- Git 2.x or higher
- Bash 4.x or higher
- Existing kano-git-master-skill scripts

## Out of Scope

- GUI interfaces
- Integration with specific Git hosting platforms (GitHub, GitLab, etc.)
- Automatic conflict resolution
- Push operations (all scripts are pull/update only)

## Success Metrics

- All scripts execute without errors on clean repositories
- Scripts handle dirty working trees correctly (stash/pop)
- Clear, actionable error messages when operations fail
- Scripts follow existing code style and conventions
- Documentation is clear and includes usage examples

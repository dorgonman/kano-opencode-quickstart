# Design: Git Master Skill Enhancements

## Overview
This design document outlines the implementation of Git automation scripts for the kano-git-master-skill, focusing on repository cloning, upstream management, multi-repository workspace management, and comprehensive update workflows.

## Architecture

### Script Organization
All scripts will be placed in `skills/kano-git-master-skill/scripts/` following existing conventions.

### Shared Library
**git-helpers.sh** - Common functions library sourced by all scripts

### New Scripts

0. **update-repo.sh** - PRIORITY: Simple update for single repo + all submodules
1. **clone-with-upstream.sh** - Clone repository with optional upstream remote
2. **rebase-to-upstream-latest.sh** - Renamed from rebase-to-latest-main.sh
3. **discover-repos.sh** - Discover all Git repositories in workspace
4. **update-workspace-repos.sh** - Update all repos (submodules + standalone)
5. **foreach-repo.sh** - Execute commands across all repos
6. **status-all-repos.sh** - Generate status report for all repos

### Refactored Scripts
- **update-repo-smart.sh** - Refactored to use git-helpers.sh
- **sync-root-and-submodules.sh** - Refactored to use git-helpers.sh

## Detailed Design

### -1. update-repo.sh (PRIORITY - Simple Single Repo + Submodules Update)

**Purpose**: Quickly update a single repository and all its submodules to the latest version. This is the immediate need and highest priority script.

**Location**: `skills/kano-git-master-skill/scripts/update-repo.sh`

**Interface**:
```bash
update-repo.sh [path] [options]

Arguments:
  path              Repository path (default: current directory)

Options:
  --remote <name>   Remote name (default: origin)
  --no-stash        Fail if there are local changes
  --dry-run         Show what would be done
  -h, --help        Show help
```

**Algorithm**:
1. Validate target path is a Git repository
2. Change to repository directory
3. Check for uncommitted changes:
   - If changes exist and --no-stash not set: create stash
   - If changes exist and --no-stash set: error and exit
4. Fetch from remote
5. Get current branch name
6. Check if current branch exists on remote:
   - If exists: rebase onto remote/branch
   - If not exists: detect default branch and rebase onto it
7. Update submodules:
   - `git submodule update --init --recursive --remote`
8. Pop stash if created
9. Report summary

**Helper Functions Used** (from git-helpers.sh):
- `gith_is_git_repo()` - Validate it's a git repo
- `gith_has_changes()` - Check for uncommitted changes
- `gith_stash_create()` - Create stash with tracking
- `gith_stash_pop()` - Pop stash with error handling
- `gith_fetch_remote()` - Fetch with error handling
- `gith_get_current_branch()` - Get current branch
- `gith_branch_exists_on_remote()` - Check if branch exists
- `gith_get_default_branch()` - Detect default branch
- `gith_has_remote()` - Check if remote exists

**Error Handling**:
- Path is not a Git repository
- Remote doesn't exist
- Network failures
- Rebase conflicts (keep stash, provide recovery instructions)
- Submodule update failures

**Progress Output**:
```
[INFO] Updating repository: /path/to/repo
[INFO] Creating stash: auto-stash-update-repo
[INFO] Fetching from remote: origin
[INFO] Current branch: main
[INFO] Rebasing onto: origin/main
[INFO] Updating submodules...
[INFO] Submodule 'public-project': checked out 'abc123'
[INFO] Submodule 'vendor/lib': checked out 'def456'
[INFO] Popping stash: stash@{0}
[INFO] Update complete!
```

**Comparison with Other Scripts**:
- Simpler than `update-repo-smart.sh` (focuses on single repo, not discovery)
- Simpler than `update-workspace-repos.sh` (no multi-repo orchestration)
- More focused than `sync-root-and-submodules.sh` (no URL sync complexity)
- **This is the "quick and simple" solution for the immediate need**

**Note**: Works with any Git remote provider (GitHub, GitLab, Azure Repos, Bitbucket, self-hosted Git servers, etc.)

### 0. git-helpers.sh (Shared Library)

**Purpose**: Provide common functions for all Git automation scripts. Works with any Git remote provider (GitHub, GitLab, Azure Repos, Bitbucket, self-hosted, etc.).

**Location**: `skills/kano-git-master-skill/scripts/git-helpers.sh`

**Functions** (prefix `gith_` = "git-helper", vendor-agnostic):

```bash
# Stash Management
gith_stash_create()      # Create stash with tracking
gith_stash_pop()         # Pop stash with error handling
gith_has_changes()       # Check if repo has uncommitted changes

# Branch Operations
gith_get_current_branch()        # Get current branch or empty if detached
gith_get_default_branch()        # Detect remote's default branch
gith_branch_exists_on_remote()   # Check if branch exists on remote

# Repository Discovery
gith_is_git_repo()              # Check if directory is a git repo
gith_discover_repos()           # Discover all repos in directory tree
gith_collect_submodules()       # Collect all submodules recursively

# Remote Operations
gith_has_remote()               # Check if remote exists
gith_fetch_remote()             # Fetch with error handling

# Utility
gith_run()                      # Dry-run wrapper
gith_log()                      # Consistent logging
gith_error()                    # Error logging
gith_is_excluded()              # Check if path matches exclude patterns
```

**Usage Pattern**:
```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/git-helpers.sh"

# Use helper functions (works with any Git remote provider)
if gith_has_changes "$repo"; then
  gith_stash_create "$repo" "my-operation"
fi
```

### 1. clone-with-upstream.sh

**Purpose**: Clone a repository and optionally set up an upstream remote.

**Interface**:
```bash
clone-with-upstream.sh <repo-url> [upstream-url] [options]

Arguments:
  repo-url          Repository URL to clone (required)
  upstream-url      Optional upstream repository URL

Options:
  --dir <path>      Target directory (default: derived from repo name)
  --no-checkout     Skip checkout to default branch
  --dry-run         Show what would be done
  -h, --help        Show help
```

**Algorithm**:
1. Validate repo-url is provided
2. Clone repository to target directory
3. Detect remote's default branch using `git symbolic-ref refs/remotes/origin/HEAD`
4. Checkout to default branch
5. Pull latest changes
6. If upstream-url provided:
   - Add upstream remote
   - Fetch upstream
7. Display summary of remotes and current branch

**Helper Functions**:
- `get_default_branch()` - Detect remote's default branch
- `validate_url()` - Basic URL validation
- `derive_repo_name()` - Extract repo name from URL

**Error Handling**:
- Invalid URL format
- Clone failure
- Network issues
- Directory already exists

### 2. rebase-to-upstream-latest.sh

**Purpose**: Rename and enhance existing rebase-to-latest-main.sh to work with upstream remote.

**Changes from Original**:
1. Rename file from `rebase-to-latest-main.sh` to `rebase-to-upstream-latest.sh`
2. Change default remote from `origin` to `upstream` (with `--remote` option)
3. Update usage text and comments
4. Add `--remote <name>` option (default: upstream)
5. Maintain all existing functionality

**Interface**:
```bash
rebase-to-upstream-latest.sh [options]

Options:
  --branch <name>              Base branch name (default: main)
  --remote <name>              Remote name (default: upstream)
  --detached <checkout|skip>   What to do when HEAD is detached
  --no-stash                   Fail if there are local changes
  -h, --help                   Show help
```

**Migration Strategy**:
- Keep old script as symlink for backward compatibility (optional)
- Update any documentation references

### 3. discover-repos.sh

**Purpose**: Discover all Git repositories in workspace (submodules and standalone repos).

**Interface**:
```bash
discover-repos.sh [options]

Options:
  --root <path>         Search root directory (default: current dir)
  --max-depth <n>       Maximum search depth (default: 3)
  --exclude <pattern>   Exclude path patterns (can be used multiple times)
  --format <json|list>  Output format (default: list)
  --save <file>         Save to manifest file
  --include-types <types> Comma-separated: root,submodule,standalone (default: all)
  --dry-run            Preview mode
  -h, --help           Show help
```

**Algorithm**:
1. Start from root directory (current dir or --root)
2. Identify root repository (if exists)
3. Collect submodules from .gitmodules
4. Search for standalone repos:
   - Use `find` with max-depth
   - Look for .git directories
   - Exclude patterns (node_modules, .cache, build, etc.)
   - Exclude submodule paths
5. For each discovered repo, collect metadata:
   - Path (relative to workspace root)
   - Type (root, submodule, standalone)
   - Current branch
   - Remotes list (works with any Git provider)
   - Has uncommitted changes
6. Output in requested format

**Output Formats**:

JSON:
```json
{
  "workspace_root": "/path/to/workspace",
  "discovered_at": "2026-02-12T10:30:00Z",
  "repos": [
    {
      "path": ".",
      "type": "root",
      "current_branch": "main",
      "remotes": ["origin", "upstream"],
      "has_changes": false
    },
    {
      "path": "public-project",
      "type": "submodule",
      "current_branch": "main",
      "remotes": ["origin"],
      "has_changes": false
    },
    {
      "path": "private-tool",
      "type": "standalone",
      "current_branch": "develop",
      "remotes": ["origin"],
      "has_changes": true
    }
  ]
}
```

List (plain text):
```
root: . (main) [origin, upstream]
submodule: public-project (main) [origin]
standalone: private-tool (develop) [origin] *changes*
```

**Helper Functions**:
- `collect_repo_metadata()` - Gather repo information
- `is_excluded()` - Check if path matches exclude patterns

**Default Exclude Patterns**:
- `node_modules`
- `.cache`
- `build`
- `dist`
- `.venv`
- `venv`
- `__pycache__`

### 4. update-workspace-repos.sh

**Purpose**: Update all repositories in workspace (root, submodules, and standalone repos).

**Interface**:
```bash
update-workspace-repos.sh [options]

Options:
  --manifest <file>       Use manifest file (default: auto-discover)
  --include-types <types> Comma-separated: root,submodule,standalone (default: all)
  --exclude <pattern>     Exclude path patterns
  --remote <name>         Remote name (default: origin)
  --max-depth <n>         Discovery max depth (default: 3)
  --parallel <n>          Parallel updates (default: 1, sequential)
  --continue-on-error     Continue if a repo fails
  --dry-run              Preview mode
  -h, --help             Show help
```

**Algorithm**:
1. Discover or load repos:
   - If --manifest provided: load from file
   - Else: call discover-repos.sh logic
2. Filter repos by --include-types and --exclude
3. For each repo (sequential or parallel):
   - Call update_single_repo() from git-helpers.sh
   - Track success/failure
4. Report summary:
   - Total repos processed
   - Successful updates
   - Failed updates
   - Skipped repos

**Note**: Works with any Git remote provider (GitHub, GitLab, Azure Repos, Bitbucket, self-hosted Git servers, etc.)

**Integration**:
- Uses `gith_discover_repos()` from git-helpers.sh
- Uses `gith_stash_create()` and `gith_stash_pop()` for each repo
- Uses smart branch detection from git-helpers.sh

**Parallel Execution** (optional):
```bash
if [[ "$PARALLEL" -gt 1 ]]; then
  # Use background jobs with job control
  for repo in "${repos[@]}"; do
    update_single_repo "$repo" &
    # Limit concurrent jobs
    while [[ $(jobs -r | wc -l) -ge "$PARALLEL" ]]; do
      wait -n
    done
  done
  wait
fi
```

### 5. foreach-repo.sh

**Purpose**: Execute custom commands across all repositories.

**Interface**:
```bash
foreach-repo.sh <command> [options]

Arguments:
  command                 Command to execute in each repo

Options:
  --manifest <file>       Use manifest file
  --include-types <types> Comma-separated repo types
  --exclude <pattern>     Exclude path patterns
  --max-depth <n>         Discovery max depth
  --continue-on-error     Continue if command fails in a repo
  --parallel <n>          Parallel execution
  --dry-run              Preview mode
  -h, --help             Show help
```

**Algorithm**:
1. Discover or load repos
2. Filter repos
3. For each repo:
   - Change to repo directory
   - Execute command
   - Capture output and exit code
   - Display with repo context
4. Report summary

**Output Format**:
```
==> [./] (root)
On branch main
Your branch is up to date with 'origin/main'.

==> [public-project] (submodule)
On branch main
Your branch is up to date with 'origin/main'.

==> [private-tool] (standalone)
On branch develop
Your branch is ahead of 'origin/develop' by 2 commits.

Summary: 3 repos, 3 succeeded, 0 failed
```

**Usage Examples**:
```bash
# Check status of all repos
./foreach-repo.sh "git status --short"

# Check for unpushed commits
./foreach-repo.sh "git log origin/main..HEAD --oneline"

# Create branch in all repos
./foreach-repo.sh "git checkout -b feature/new-feature"

# Fetch all remotes
./foreach-repo.sh "git fetch --all --prune"
```

### 6. status-all-repos.sh

**Purpose**: Generate comprehensive status report for all repositories.

**Interface**:
```bash
status-all-repos.sh [options]

Options:
  --manifest <file>       Use manifest file
  --include-types <types> Comma-separated repo types
  --exclude <pattern>     Exclude path patterns
  --max-depth <n>         Discovery max depth
  --format <table|json|markdown> Output format (default: table)
  --check-remote          Check remote status (slower)
  --output <file>         Save to file
  -h, --help             Show help
```

**Collected Information**:
- Repository path and type
- Current branch
- Uncommitted changes count
- Untracked files count
- Unpushed commits count (if --check-remote)
- Ahead/behind remote (if --check-remote)
- Last commit date and message
- Remote URLs

**Output Formats**:

Table:
```
PATH              TYPE        BRANCH   CHANGES  UNPUSHED  STATUS
.                 root        main     0        0         up-to-date
public-project    submodule   main     0        0         up-to-date
private-tool      standalone  develop  3        2         ahead 2
```

JSON:
```json
{
  "generated_at": "2026-02-12T10:30:00Z",
  "repos": [
    {
      "path": ".",
      "type": "root",
      "branch": "main",
      "uncommitted_changes": 0,
      "untracked_files": 0,
      "unpushed_commits": 0,
      "status": "up-to-date",
      "last_commit": {
        "date": "2026-02-11T15:20:00Z",
        "message": "Update documentation"
      }
    }
  ]
}
```

Markdown:
```markdown
# Repository Status Report

Generated: 2026-02-12 10:30:00

## Summary
- Total repositories: 3
- Up-to-date: 2
- Need attention: 1

## Details

### . (root)
- **Branch**: main
- **Status**: up-to-date
- **Last commit**: 2026-02-11 15:20:00 - Update documentation

### private-tool (standalone)
- **Branch**: develop
- **Status**: ahead 2 commits
- **Uncommitted changes**: 3 files
- **Last commit**: 2026-02-10 09:15:00 - Add new feature
```

### 7. update-repo-smart.sh (Refactored)

**Purpose**: Intelligently update current repository and all submodules with smart branch detection.

**Changes from Original Design**:
- Refactored to use git-helpers.sh
- Simplified by extracting common logic to helpers
- Maintains same interface and functionality

**Interface**:
```bash
update-repo-smart.sh [options]

Options:
  --remote <name>    Remote name (default: origin)
  --no-stash         Fail if there are local changes
  --no-submodules    Skip submodule updates
  --dry-run          Show what would be done
  -h, --help         Show help
```

**Refactoring**:
- Use `gith_discover_repos()` instead of custom `collect_all_repos()`
- Use `gith_stash_create()` and `gith_stash_pop()` instead of inline stash logic
- Use `gith_get_current_branch()` and `gith_branch_exists_on_remote()`
- Use `gith_get_default_branch()` for fallback branch detection

### 8. sync-root-and-submodules.sh (Refactored)

**Purpose**: Update root repository and fully synchronize all submodules.

**Changes from Original Design**:
- Refactored to use git-helpers.sh
- Maintains same interface and functionality

**Interface**:
```bash
sync-root-and-submodules.sh [options]

Options:
  --remote <name>    Remote name for root (default: origin)
  --no-stash         Fail if there are local changes
  --dry-run          Show what would be done
  -h, --help         Show help
```

**Refactoring**:
- Use git-helpers.sh functions for stash management
- Use git-helpers.sh functions for branch detection
- Maintain integration with submodule-sync-urls.sh

**Note**: All scripts work with any Git remote provider (GitHub, GitLab, Azure Repos, Bitbucket, self-hosted, etc.)

**Interface**:
```bash
update-repo-smart.sh [options]

Options:
  --remote <name>    Remote name (default: origin)
  --no-stash         Fail if there are local changes
  --no-submodules    Skip submodule updates
  --dry-run          Show what would be done
  -h, --help         Show help
```

**Algorithm**:
1. Verify we're in a git repository
2. Stash local changes (including untracked)
3. For root repository:
   - Fetch from remote
   - Get current branch name
   - Check if branch exists on remote
   - If exists: rebase onto remote/branch
   - If not exists: detect and rebase onto remote's default branch
4. For each submodule (recursive):
   - Apply same logic as root
   - Use submodule's configured remote
5. Pop stash if all operations succeed
6. Report summary of updates

**Helper Functions**:
- `get_current_branch()` - Get current branch or empty if detached
- `branch_exists_on_remote()` - Check if branch exists on remote
- `get_remote_default_branch()` - Detect remote's default branch
- `update_single_repo()` - Core update logic for one repo
- `collect_all_repos()` - Build list of root + all submodules

**Error Handling**:
- Not in a git repository
- Remote doesn't exist
- Rebase conflicts (keep stash, report error)
- Network failures
- Detached HEAD state (skip or error based on option)

**Stash Management**:
- Create stash with descriptive message: "auto-stash: update-repo-smart"
- Track stash ref for each repo
- Only pop if update succeeds
- Report stash refs if pop fails

### 4. sync-root-and-submodules.sh

**Purpose**: Update root repository and fully synchronize all submodules.

**Interface**:
```bash
sync-root-and-submodules.sh [options]

Options:
  --remote <name>    Remote name for root (default: origin)
  --no-stash         Fail if there are local changes
  --dry-run          Show what would be done
  -h, --help         Show help
```

**Algorithm**:
1. Update root repository:
   - Stash local changes
   - Fetch from remote
   - Detect and rebase onto appropriate branch (same logic as update-repo-smart.sh)
   - Pop stash
2. Initialize missing submodules:
   - `git submodule init`
3. Sync submodule URLs:
   - Call `submodule-sync-urls.sh --init-missing`
4. Update all submodules:
   - `git submodule update --init --recursive`
5. Report summary

**Integration with Existing Scripts**:
- Reuses `submodule-sync-urls.sh` for URL synchronization
- Follows same stash/pop pattern as other scripts

**Error Handling**:
- Root update failure (stop before submodule operations)
- Submodule init/sync/update failures
- Missing .gitmodules file (warning, not error)

## Common Patterns

### Sourcing git-helpers.sh
```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/git-helpers.sh"
```

### Repository Discovery Pattern
```bash
# Discover all repos (works with any Git remote provider)
repos=$(gith_discover_repos "$root_dir" "$max_depth" "${exclude_patterns[@]}")

# Filter by type
filtered_repos=$(echo "$repos" | jq -r ".repos[] | select(.type == \"$type\") | .path")
```

### Manifest File Format
```json
{
  "version": "1.0",
  "workspace_root": ".",
  "repos": [
    {
      "path": ".",
      "type": "root",
      "remote": "origin",
      "update": true
    },
    {
      "path": "public-project",
      "type": "submodule",
      "remote": "origin",
      "update": true
    },
    {
      "path": "private-tool",
      "type": "standalone",
      "remote": "origin",
      "update": true,
      "notes": "Private tool, not in submodules"
    },
    {
      "path": "vendor/legacy-lib",
      "type": "standalone",
      "remote": "origin",
      "update": false,
      "notes": "Legacy, do not auto-update"
    }
  ],
  "exclude_patterns": [
    "node_modules",
    ".cache",
    "build"
  ]
}
```

### Stash Management Pattern
```bash
stash_created=0
stash_ref=""

if [[ -n "$(git status --porcelain)" ]]; then
  git stash push -u -m "auto-stash: <script-name>"
  stash_created=1
  stash_ref="$(git stash list -n 1 --format='%gd')"
fi

# ... operations ...

if [[ "$stash_created" -eq 1 ]]; then
  if ! git stash pop --index; then
    echo "Warning: stash pop failed. Apply manually: $stash_ref" >&2
    return 1
  fi
fi
```

### Default Branch Detection
```bash
get_default_branch() {
  local remote="${1:-origin}"
  local default_branch=""
  
  # Try symbolic-ref first (most reliable)
  default_branch="$(git symbolic-ref "refs/remotes/$remote/HEAD" 2>/dev/null | sed "s|^refs/remotes/$remote/||")"
  
  if [[ -z "$default_branch" ]]; then
    # Fallback: try common branch names
    for branch in main master develop; do
      if git show-ref --verify --quiet "refs/remotes/$remote/$branch"; then
        default_branch="$branch"
        break
      fi
    done
  fi
  
  echo "$default_branch"
}
```

### Remote Branch Existence Check
```bash
branch_exists_on_remote() {
  local remote="$1"
  local branch="$2"
  git show-ref --verify --quiet "refs/remotes/$remote/$branch"
}
```

### Dry-Run Pattern
```bash
run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '+ %q' "$@"
    printf '\n'
    return 0
  fi
  "$@"
}
```

## Testing Strategy

### Manual Testing Scenarios

1. **clone-with-upstream.sh**:
   - Clone without upstream
   - Clone with upstream
   - Clone to custom directory
   - Clone repo with non-main default branch
   - Dry-run mode

2. **rebase-to-upstream-latest.sh**:
   - Rebase with clean working tree
   - Rebase with local changes (stash/pop)
   - Rebase with detached HEAD
   - Rebase with custom remote name

3. **update-repo-smart.sh**:
   - Update repo where local branch exists on remote
   - Update repo where local branch doesn't exist on remote
   - Update with submodules
   - Update with nested submodules
   - Handle rebase conflicts

4. **sync-root-and-submodules.sh**:
   - Sync with missing submodules
   - Sync with outdated submodule URLs
   - Sync with local changes in root
   - Dry-run mode

### Edge Cases

- Detached HEAD state
- No remote configured
- Network failures
- Rebase conflicts
- Missing .gitmodules
- Empty repositories
- Shallow clones

## Documentation Updates

### Files to Update
1. `skills/kano-git-master-skill/SKILL.md` - Add new scripts documentation
2. `skills/kano-git-master-skill/README.md` - Update usage examples (if exists)

### Usage Examples to Include

```bash
# Clone with upstream
./scripts/clone-with-upstream.sh \
  https://github.com/user/fork.git \
  https://github.com/original/repo.git

# Rebase to upstream
cd my-repo
../scripts/rebase-to-upstream-latest.sh --remote upstream --branch main

# Smart update current repo
cd my-project
../scripts/update-repo-smart.sh

# Full sync root and submodules
cd my-project
../scripts/sync-root-and-submodules.sh
```

## Migration Notes

### Backward Compatibility

For `rebase-to-latest-main.sh` → `rebase-to-upstream-latest.sh`:
- Option 1: Keep old script as symlink
- Option 2: Keep old script with deprecation warning
- Option 3: Remove old script (breaking change, document in changelog)

**Recommendation**: Option 2 - Keep old script with deprecation warning for one release cycle.

## Security Considerations

1. **URL Validation**: Basic validation to prevent command injection
2. **Path Traversal**: Validate target directories
3. **Credential Handling**: Scripts don't handle credentials (rely on git credential helper)
4. **Dry-Run Safety**: All destructive operations support dry-run mode

## Performance Considerations

1. **Parallel Operations**: Consider parallel submodule updates (future enhancement)
2. **Fetch Optimization**: Use `--prune` to clean up stale references
3. **Progress Output**: Provide clear progress for long-running operations

## Future Enhancements

1. Add `--parallel` option for submodule operations
2. Support for multiple upstream remotes
3. Interactive mode for conflict resolution
4. Integration with git worktrees
5. Support for partial clones/sparse checkouts

## Correctness Properties

### Property 1: Stash Safety
**Description**: If a stash is created, it must be popped or the user must be informed of the stash reference.

**Validation**: After any script execution, verify that:
- If stash was created and operations succeeded, stash list count decreased by 1
- If stash was created and operations failed, user receives stash reference in error message

### Property 2: Repository State Consistency
**Description**: After successful update, repository must be in a consistent state (no partial updates).

**Validation**: Verify that:
- HEAD points to a valid commit
- Working tree is clean or has expected local changes
- All submodules are initialized and at expected commits

### Property 3: Remote Branch Detection Accuracy
**Description**: Default branch detection must correctly identify the remote's default branch.

**Validation**: For any repository, detected default branch must match `git symbolic-ref refs/remotes/origin/HEAD`.

### Property 4: Idempotency
**Description**: Running update scripts multiple times on an up-to-date repository should be safe and produce no changes.

**Validation**: Run script twice on same repo, second run should report "already up-to-date".

### Property 5: Error Propagation
**Description**: Errors in submodule operations must not be silently ignored.

**Validation**: If any submodule update fails, script must exit with non-zero status and report which submodule failed.

### Property 6: Repository Discovery Completeness
**Description**: Repository discovery must find all Git repositories within specified depth and not miss any.

**Validation**: 
- Manual verification: discovered repos match `find . -name .git -type d`
- No false positives: all discovered paths are valid Git repositories
- Respects exclude patterns: excluded paths are not in results

### Property 7: Standalone Repo Distinction
**Description**: Standalone repositories must be correctly distinguished from submodules.

**Validation**:
- A repo listed in .gitmodules must be classified as "submodule"
- A repo not in .gitmodules must be classified as "standalone"
- Root repo must be classified as "root"

## Implementation Order

1. **Phase -1**: Create update-repo.sh (PRIORITY - immediate need for simple repo + submodules update)
2. **Phase 0**: Create git-helpers.sh library (foundation for all scripts) - ALREADY DONE
3. **Phase 1**: Implement clone-with-upstream.sh (standalone, no dependencies)
4. **Phase 2**: Rename and enhance rebase-to-upstream-latest.sh
5. **Phase 3**: Implement discover-repos.sh (uses git-helpers.sh)
6. **Phase 4**: Implement update-workspace-repos.sh (uses discover-repos.sh + git-helpers.sh)
7. **Phase 5**: Implement foreach-repo.sh (uses discover-repos.sh + git-helpers.sh)
8. **Phase 6**: Implement status-all-repos.sh (uses discover-repos.sh + git-helpers.sh)
9. **Phase 7**: Refactor update-repo-smart.sh to use git-helpers.sh
10. **Phase 8**: Refactor sync-root-and-submodules.sh to use git-helpers.sh
11. **Phase 9**: Documentation and testing

## Dependencies

- Git 2.23+ (for `git symbolic-ref` on remote refs)
- Bash 4.0+
- Existing `submodule-sync-urls.sh` script

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Rebase conflicts | High | Clear error messages, preserve stash, provide recovery instructions |
| Network failures | Medium | Retry logic, clear error messages |
| Detached HEAD state | Medium | Explicit handling with --detached option |
| Submodule URL changes | Low | Integrate with submodule-sync-urls.sh |
| Cross-platform issues | Medium | Test on Git Bash (Windows) and Unix shells |

## Success Criteria

- All scripts execute without errors on clean repositories
- Stash/pop operations work correctly
- Clear error messages for all failure scenarios
- Scripts follow existing code conventions
- Documentation is complete and accurate
- Manual testing passes for all scenarios

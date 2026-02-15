# Tasks: Git Master Skill Enhancements

## Phase -1: Priority - Quick Update Script (IMMEDIATE NEED)

### 0.1. Create update-repo.sh for single repo + submodules update
Create a simple, focused script to update a repository and all its submodules to the latest version.

**Details**:
- Create `skills/kano-git-master-skill/scripts/update-repo.sh`
- Source git-helpers.sh for common operations
- Accept optional path argument (default: current directory)
- Implement simple, clear interface: `./update-repo.sh [path]`
- Use `gith_stash_create()` and `gith_stash_pop()` for dirty repos
- Use `gith_get_current_branch()` for branch detection
- Use `gith_get_default_branch()` for fallback
- Use `gith_fetch_remote()` for fetching
- Update root repository first
- Then update all submodules recursively with `git submodule update --init --recursive --remote`
- Clear progress output for each step
- Works with any Git remote provider (GitHub, GitLab, Azure Repos, Bitbucket, self-hosted, etc.)

**Acceptance Criteria**:
- Script updates root repository to latest
- Script updates all submodules to latest
- Handles uncommitted changes (stash/pop)
- Smart branch detection (current branch or default)
- Clear error messages
- Works from any directory (when path provided)
- Works with any Git hosting provider
- Simple usage: `./update-repo.sh` or `./update-repo.sh /path/to/repo`

**Usage Examples**:
```bash
# Update current directory
cd /path/to/my-repo
./update-repo.sh

# Update specific repository
./update-repo.sh /path/to/my-repo

# Dry-run mode
./update-repo.sh --dry-run

# Specify remote (default: origin)
./update-repo.sh --remote upstream
```

### 0.2. Test update-repo.sh
Manually test the update script with various scenarios.

**Details**:
- Test with clean working tree
- Test with uncommitted changes (stash/pop)
- Test with submodules
- Test with nested submodules
- Test with no submodules
- Test with detached HEAD
- Test with custom remote
- Test dry-run mode
- Test error cases (not a git repo, network failure)

**Acceptance Criteria**:
- All test scenarios pass
- Stash/pop works correctly
- Submodules are updated properly
- Error messages are clear and actionable
- Dry-run shows correct operations

## Phase 0: Shared Helper Library

### 1. Create git-helpers.sh library structure
Create the foundation for shared Git helper functions that work with any Git remote provider.

**Details**:
- Create `skills/kano-git-master-skill/scripts/git-helpers.sh`
- Add header comment explaining purpose and usage (vendor-agnostic, works with GitHub, GitLab, Azure Repos, Bitbucket, self-hosted Git, etc.)
- Add shebang (#!/usr/bin/env bash)
- Add set -euo pipefail
- Add version variable
- Create function stubs for all planned helpers (prefix: `gith_` = "git-helper", not GitHub-specific)

**Acceptance Criteria**:
- File exists and is sourceable
- No syntax errors
- Can be sourced by other scripts without errors
- Header clearly states vendor-agnostic design

### 2. Implement stash management functions
Add stash creation and restoration helpers (vendor-agnostic).

**Details**:
- Implement `gith_has_changes()` - check for uncommitted changes
- Implement `gith_stash_create()` - create stash with tracking
- Implement `gith_stash_pop()` - pop stash with error handling
- Add error handling and logging
- Support dry-run mode

**Acceptance Criteria**:
- Functions correctly detect changes
- Stash is created with descriptive message
- Stash ref is tracked and returned
- Pop handles conflicts gracefully
- Error messages include stash ref for manual recovery

### 3. Implement branch operation functions
Add branch detection and checking helpers (works with any Git remote).

**Details**:
- Implement `gith_get_current_branch()` - get current branch or empty if detached
- Implement `gith_get_default_branch()` - detect remote's default branch
- Implement `gith_branch_exists_on_remote()` - check if branch exists on remote
- Handle edge cases (detached HEAD, missing remote, etc.)

**Acceptance Criteria**:
- Functions return correct values for all cases
- Handle detached HEAD gracefully
- Fallback to common branch names if symbolic-ref fails
- Return appropriate exit codes

### 4. Implement repository discovery functions
Add repo discovery and metadata collection helpers (vendor-agnostic).

**Details**:
- Implement `gith_is_git_repo()` - check if directory is a git repo
- Implement `gith_discover_repos()` - discover all repos in directory tree
- Implement `gith_collect_submodules()` - collect all submodules recursively
- Implement `gith_collect_repo_metadata()` - gather repo information
- Support exclude patterns
- Support max depth limiting

**Acceptance Criteria**:
- Correctly identifies Git repositories
- Distinguishes between root, submodule, and standalone repos
- Respects exclude patterns
- Respects max depth
- Returns structured data (JSON or array)

### 5. Implement remote operation functions
Add remote checking and fetching helpers (works with any Git remote provider).

**Details**:
- Implement `gith_has_remote()` - check if remote exists
- Implement `gith_fetch_remote()` - fetch with error handling
- Add progress output
- Support dry-run mode

**Acceptance Criteria**:
- Correctly detects remote existence
- Fetch handles network errors gracefully
- Progress output is clear
- Dry-run shows what would be done

### 6. Implement utility functions
Add logging and dry-run helpers.

**Details**:
- Implement `gith_run()` - dry-run wrapper for commands
- Implement `gith_log()` - consistent logging with levels
- Implement `gith_error()` - error logging
- Implement `gith_is_excluded()` - check if path matches exclude patterns

**Acceptance Criteria**:
- Dry-run shows commands without executing
- Logging is consistent across all functions
- Error messages go to stderr
- Exclude pattern matching works correctly

### 7. Test git-helpers.sh library
Create test script to verify all helper functions.

**Details**:
- Create `skills/kano-git-master-skill/scripts/test-git-helpers.sh`
- Test each function with various inputs
- Test edge cases
- Test error conditions
- Document test results

**Acceptance Criteria**:
- All functions pass basic tests
- Edge cases are handled correctly
- Error conditions produce appropriate messages
- Test script can be run repeatedly

## Phase 1: Clone with Upstream Script

### 8. Create clone-with-upstream.sh
Create the new script for cloning repositories with optional upstream remote support.

**Details**:
- Create `skills/kano-git-master-skill/scripts/clone-with-upstream.sh`
- Source git-helpers.sh
- Implement argument parsing for repo-url, upstream-url, and options
- Add usage() function with clear help text
- Implement validate_url() helper function
- Implement derive_repo_name() helper function
- Use `gith_get_default_branch()` from git-helpers.sh
- Add dry-run support
- Add error handling for all failure scenarios
- Make script executable (chmod +x)
- Works with any Git remote provider (GitHub, GitLab, Azure Repos, Bitbucket, self-hosted, etc.)

**Acceptance Criteria**:
- Script clones repository successfully
- Detects and checks out remote's default branch
- Pulls latest changes after checkout
- Adds upstream remote when provided
- Supports --dir, --no-checkout, --dry-run options
- Provides clear error messages
- Follows existing script conventions
- Works with any Git hosting provider

### 9. Test clone-with-upstream.sh
Manually test the clone script with various scenarios.

**Details**:
- Test clone without upstream
- Test clone with upstream
- Test clone to custom directory
- Test with repository having non-main default branch
- Test dry-run mode
- Test error cases (invalid URL, existing directory, network failure)

**Acceptance Criteria**:
- All test scenarios pass
- Error messages are clear and actionable
- Dry-run shows correct operations without executing them

## Phase 2: Rename and Enhance Rebase Script

### 10. Rename rebase-to-latest-main.sh
Rename the existing script to better reflect its purpose.

**Details**:
- Rename `skills/kano-git-master-skill/scripts/rebase-to-latest-main.sh` to `rebase-to-upstream-latest.sh`
- Update internal comments and usage text
- Update script description to reflect upstream focus

**Acceptance Criteria**:
- File is renamed successfully
- All internal references updated
- Script still executes correctly

### 11. Refactor rebase-to-upstream-latest.sh to use git-helpers.sh
Integrate the renamed script with the helper library.

**Details**:
- Add source statement for git-helpers.sh
- Replace inline stash logic with `gith_stash_create()` and `gith_stash_pop()`
- Replace branch detection with `gith_get_current_branch()` and `gith_get_default_branch()`
- Replace remote checking with `gith_has_remote()`
- Add REMOTE variable (default: "upstream")
- Add --remote option to argument parsing
- Update usage text to document --remote option

**Acceptance Criteria**:
- Script uses git-helpers.sh functions
- Works with --remote option
- Defaults to "upstream" when not specified
- Can still work with "origin" when explicitly set
- All existing functionality preserved
- Works with any Git remote provider

### 12. Create deprecation wrapper for old script name
Provide backward compatibility for users of the old script.

**Details**:
- Create `skills/kano-git-master-skill/scripts/rebase-to-latest-main.sh` as wrapper
- Add deprecation warning message
- Forward all arguments to rebase-to-upstream-latest.sh
- Document deprecation in comments

**Acceptance Criteria**:
- Old script name still works
- Deprecation warning is displayed
- All arguments forwarded correctly

### 13. Test rebase-to-upstream-latest.sh
Verify the renamed and enhanced script works correctly.

**Details**:
- Test with default upstream remote
- Test with custom remote (--remote origin)
- Test with clean working tree
- Test with local changes (stash/pop)
- Test with detached HEAD
- Test with submodules

**Acceptance Criteria**:
- All test scenarios pass
- Stash/pop works correctly
- Submodules are updated properly
- Error handling works as expected

## Phase 3: Repository Discovery Script

### 14. Create discover-repos.sh skeleton
Set up the basic structure for the repository discovery script.

**Details**:
- Create `skills/kano-git-master-skill/scripts/discover-repos.sh`
- Source git-helpers.sh
- Implement argument parsing
- Add usage() function
- Add dry-run support
- Make script executable

**Acceptance Criteria**:
- Script structure follows conventions
- Help text is clear and complete
- Argument parsing works correctly

### 15. Implement repository discovery logic
Add logic to discover all repositories in workspace.

**Details**:
- Use `gith_discover_repos()` from git-helpers.sh
- Implement root repo detection
- Implement submodule collection (via .gitmodules)
- Implement standalone repo search (find + exclude logic)
- Collect metadata for each repo (works with any Git remote provider)
- Support exclude patterns
- Support max depth

**Acceptance Criteria**:
- Discovers root repository
- Discovers all submodules
- Discovers standalone repos
- Correctly classifies repo types
- Respects exclude patterns and max depth
- Works with any Git hosting provider

### 16. Implement output formatting
Add support for multiple output formats.

**Details**:
- Implement JSON output format
- Implement plain list output format
- Implement --save option to write manifest file
- Add summary statistics

**Acceptance Criteria**:
- JSON output is valid and well-formatted
- List output is human-readable
- Manifest file can be saved
- Summary shows repo counts by type

### 17. Test discover-repos.sh
Verify the discovery script works correctly.

**Details**:
- Test in workspace with only root repo
- Test in workspace with submodules
- Test in workspace with standalone repos
- Test with exclude patterns
- Test with different max depths
- Test output formats
- Test manifest file saving

**Acceptance Criteria**:
- All test scenarios pass
- Correct repos are discovered
- Exclude patterns work
- Output formats are correct

## Phase 4: Workspace Update Script

### 18. Create update-workspace-repos.sh skeleton
Set up the basic structure for the workspace update script.

**Details**:
- Create `skills/kano-git-master-skill/scripts/update-workspace-repos.sh`
- Source git-helpers.sh
- Implement argument parsing
- Add usage() function
- Add dry-run support
- Make script executable

**Acceptance Criteria**:
- Script structure follows conventions
- Help text is clear
- Argument parsing works

### 19. Implement manifest loading and repo discovery
Add logic to load repos from manifest or discover them.

**Details**:
- Implement manifest file loading (JSON parsing)
- Fallback to discovery if no manifest
- Filter repos by --include-types
- Apply exclude patterns
- Validate repo paths exist

**Acceptance Criteria**:
- Manifest files load correctly
- Discovery works when no manifest
- Filtering works correctly
- Invalid paths are reported

### 20. Implement update logic for single repository
Create the core update logic for one repository.

**Details**:
- Use `gith_stash_create()` for dirty repos
- Use `gith_fetch_remote()` to fetch
- Use `gith_get_current_branch()` to get branch
- Use `gith_branch_exists_on_remote()` to check remote branch
- Use `gith_get_default_branch()` for fallback
- Implement rebase logic
- Use `gith_stash_pop()` to restore changes
- Add detailed progress output
- Works with any Git remote provider

**Acceptance Criteria**:
- Repository is updated correctly
- Stash/pop works properly
- Rebases to correct branch
- Error messages are clear
- Works with any Git hosting provider

### 21. Implement batch update orchestration
Add logic to update multiple repositories.

**Details**:
- Iterate through filtered repos
- Call update logic for each repo
- Track success/failure per repo
- Support --continue-on-error option
- Generate summary report
- Exit with appropriate status code

**Acceptance Criteria**:
- All repos are processed
- Failures are tracked
- Summary is accurate
- Exit code reflects overall success/failure

### 22.* Add parallel execution support (optional)
Implement parallel updates for performance.

**Details**:
- Add --parallel option
- Implement job control for background processes
- Limit concurrent jobs to specified number
- Collect results from parallel jobs
- Handle errors from parallel execution

**Acceptance Criteria**:
- Parallel execution works correctly
- Job limit is respected
- Errors are captured
- Performance improvement is measurable

### 23. Test update-workspace-repos.sh
Verify the workspace update script works correctly.

**Details**:
- Test with manifest file
- Test with auto-discovery
- Test with different repo type filters
- Test with exclude patterns
- Test with clean repos
- Test with dirty repos (stash/pop)
- Test with rebase conflicts
- Test --continue-on-error
- Test parallel execution (if implemented)

**Acceptance Criteria**:
- All test scenarios pass
- Repos are updated correctly
- Stash/pop works
- Errors are handled properly

## Phase 5: Foreach Repo Script

### 24. Create foreach-repo.sh
Implement the command execution script.

**Details**:
- Create `skills/kano-git-master-skill/scripts/foreach-repo.sh`
- Source git-helpers.sh
- Implement argument parsing
- Add usage() function
- Implement repo discovery/loading
- Implement command execution per repo
- Capture and display output with repo context
- Support --continue-on-error
- Support parallel execution (optional)
- Generate summary report

**Acceptance Criteria**:
- Script executes commands in all repos
- Output shows repo context
- Errors are handled per --continue-on-error
- Summary is accurate

### 25. Test foreach-repo.sh
Verify the foreach script works correctly.

**Details**:
- Test with simple commands (git status)
- Test with commands that fail
- Test with --continue-on-error
- Test with different repo type filters
- Test parallel execution (if implemented)

**Acceptance Criteria**:
- Commands execute correctly
- Output is clear and contextualized
- Error handling works
- Summary is accurate

## Phase 6: Status Report Script

### 26. Create status-all-repos.sh
Implement the status report script.

**Details**:
- Create `skills/kano-git-master-skill/scripts/status-all-repos.sh`
- Source git-helpers.sh
- Implement argument parsing
- Add usage() function
- Implement repo discovery/loading
- Collect status information for each repo
- Implement table output format
- Implement JSON output format
- Implement markdown output format
- Support --check-remote option
- Support --output option to save to file

**Acceptance Criteria**:
- Script collects status for all repos
- All output formats work correctly
- Remote checking works (if enabled)
- Output can be saved to file

### 27. Test status-all-repos.sh
Verify the status report script works correctly.

**Details**:
- Test with various repo states
- Test all output formats
- Test with and without --check-remote
- Test output to file
- Verify accuracy of reported information

**Acceptance Criteria**:
- Status information is accurate
- All formats produce correct output
- Remote checking works
- File output works

## Phase 7: Refactor update-repo-smart.sh

### 28. Refactor update-repo-smart.sh to use git-helpers.sh
Simplify the script by using shared helpers.

**Details**:
- Add source statement for git-helpers.sh
- Replace custom functions with git-helpers.sh equivalents
- Replace `collect_all_repos()` with `gith_discover_repos()`
- Replace stash logic with `gith_stash_create()` and `gith_stash_pop()`
- Replace branch detection with `gith_get_current_branch()` and `gith_branch_exists_on_remote()`
- Replace default branch detection with `gith_get_default_branch()`
- Maintain same interface and functionality

**Acceptance Criteria**:
- Script uses git-helpers.sh functions
- All existing functionality preserved
- Code is simpler and more maintainable
- No regressions
- Works with any Git remote provider

### 29. Test refactored update-repo-smart.sh
Verify the refactored script works correctly.

**Details**:
- Test all scenarios from original design
- Test with submodules
- Test with nested submodules
- Test stash/pop
- Test branch detection
- Test error handling

**Acceptance Criteria**:
- All test scenarios pass
- No regressions from original functionality
- Refactored code works correctly

## Phase 8: Refactor sync-root-and-submodules.sh

### 30. Refactor sync-root-and-submodules.sh to use git-helpers.sh
Simplify the script by using shared helpers.

**Details**:
- Add source statement for git-helpers.sh
- Replace stash logic with `gith_stash_create()` and `gith_stash_pop()`
- Replace branch detection with git-helpers.sh functions
- Maintain integration with submodule-sync-urls.sh
- Maintain same interface and functionality

**Acceptance Criteria**:
- Script uses git-helpers.sh functions
- Integration with submodule-sync-urls.sh works
- All existing functionality preserved
- No regressions
- Works with any Git remote provider

### 31. Test refactored sync-root-and-submodules.sh
Verify the refactored script works correctly.

**Details**:
- Test all scenarios from original design
- Test with missing submodules
- Test with outdated submodule URLs
- Test stash/pop
- Test error handling

**Acceptance Criteria**:
- All test scenarios pass
- No regressions from original functionality
- Refactored code works correctly

## Phase 9: Documentation and Polish

### 32. Update SKILL.md documentation
Document all new scripts and the helper library.

**Details**:
- Add section for git-helpers.sh library
- Document all new scripts
- Document purpose and usage for each script
- Add usage examples
- Document options and flags
- Add troubleshooting section
- Document manifest file format

**Acceptance Criteria**:
- Documentation is clear and complete
- Examples are accurate and helpful
- All options are documented
- Manifest format is documented

### 33. Create comprehensive usage examples
Provide real-world usage scenarios.

**Details**:
- Create examples for common workflows
- Document integration between scripts
- Add examples for error recovery
- Document best practices
- Add examples for manifest file usage
- Document workspace organization patterns

**Acceptance Criteria**:
- Examples cover common use cases
- Examples are tested and accurate
- Best practices are clearly explained
- Manifest examples are provided

### 34. Create migration guide
Help users transition to new scripts.

**Details**:
- Document changes from old scripts
- Provide migration examples
- Document deprecations
- Explain new features and benefits
- Provide troubleshooting for common migration issues

**Acceptance Criteria**:
- Migration guide is clear
- Examples show before/after
- Deprecations are documented
- Benefits are explained

### 35. Final integration testing
Perform end-to-end testing of all scripts together.

**Details**:
- Test complete workflow: clone → discover → update → status
- Test on both Unix and Git Bash (Windows)
- Test with real repositories
- Test with complex workspace structures
- Test error recovery scenarios
- Test manifest file workflows
- Verify all scripts work together
- Performance testing with many repos

**Acceptance Criteria**:
- All scripts work together seamlessly
- Cross-platform compatibility verified
- Error recovery works correctly
- No regressions in existing functionality
- Performance is acceptable

## Optional Enhancements

### 36.* Add commit-all-repos.sh script
Implement batch commit functionality.

**Details**:
- Create script to commit changes across multiple repos
- Support custom commit message
- Support --add-all option
- Support filtering by repo type
- Support dry-run mode

**Acceptance Criteria**:
- Script commits to multiple repos
- Filtering works correctly
- Dry-run shows what would be committed

### 37.* Add cleanup-merged-branches.sh script
Implement branch cleanup functionality.

**Details**:
- Create script to clean up merged branches
- List branches merged to main/master
- Support local and remote branch deletion
- Support branch protection patterns
- Support dry-run mode

**Acceptance Criteria**:
- Script identifies merged branches correctly
- Deletion works for local and remote
- Protected branches are not deleted
- Dry-run shows what would be deleted

### 38.* Add repo-health-check.sh script
Implement comprehensive health check.

**Details**:
- Create script for repository health checks
- Check for uncommitted changes
- Check for unpushed commits
- Check for large files
- Check for .gitignore issues
- Generate health report

**Acceptance Criteria**:
- All checks work correctly
- Report is comprehensive
- Issues are clearly identified

## Notes

- All scripts must follow existing conventions (set -euo pipefail, usage function, etc.)
- All scripts must source git-helpers.sh for common functionality
- **CRITICAL**: All scripts are vendor-agnostic and work with any Git remote provider:
  - GitHub, GitLab, Azure Repos, Bitbucket, Gitea, Gogs
  - Self-hosted Git servers (any Git-compatible remote)
  - Function prefix `gith_` means "git-helper", NOT "GitHub"
- Test on both Unix shells and Git Bash on Windows
- Ensure error messages are clear and actionable
- Maintain backward compatibility where possible
- Document any breaking changes
- Focus on code reuse through git-helpers.sh

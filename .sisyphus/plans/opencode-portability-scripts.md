# OpenCode Portability Scripts (Projects + Sessions)

## TL;DR

> **Quick Summary**: Add a command-only, cross-platform-ish backup/restore workflow (Git Bash on Windows first) that packages OpenCode server-side data (projects + sessions) into a `tar.gz` and restores it safely.
>
> **Deliverables**:
> - `scripts/opencode-portability.sh` with subcommands: `list-projects`, `backup-server`, `restore-server` (+ optional `export-projects-json`, `import-projects-json` wrappers)
> - Minimal docs update explaining cross-browser behavior and why `opencode-sync-localstorage.html` cannot be served from `http://localhost:4096/`
>
> **Estimated Effort**: Medium
> **Parallel Execution**: YES (docs + script can be parallel)
> **Critical Path**: Storage-path resolution → Safe tar backup/restore → Verification

---

## Context

### Original Request
- Need command-only tooling to list projects and export/import projects.
- Want sessions included in backups.
- Primary environment is Git Bash on Windows, but should work on WSL/macOS/Linux when possible.
- No changes to OpenCode source code.
- Observed behavior: different browsers show different sessions / sessions appear “inside sandbox”; closing workspace makes sessions “disappear” elsewhere.

### Key Findings (from code + repo)

- **Server-side storage location**
  - Storage root is `${Global.Path.data}/storage`.
  - Code refs:
    - `src/opencode/packages/opencode/src/global/index.ts` (XDG-based `Global.Path.data`)
    - `src/opencode/packages/opencode/src/storage/storage.ts` (`dir = path.join(Global.Path.data, "storage")`)

- **Projects**
  - Project metadata is stored as JSON files: `storage/project/<projectID>.json`.
  - Enumeration uses `Project.list()` (calls `Storage.list(["project"])`).
  - Code ref: `src/opencode/packages/opencode/src/project/project.ts`.

- **Sessions span multiple storage directories** (critical)
  - A session is not just `storage/session/**`. Messages/parts/etc are siblings.
  - Real-world observed directories under `storage/` include:
    - `project/`, `session/`, `message/`, `part/`, `session_diff/`, `session_share/`, `todo/`, `rules-injector/`, `directory-agents/`, `directory-readme/`, `agent-usage-reminder/`, plus `migration`.
  - Therefore **backup must include the entire `storage/` directory** to avoid silent data loss.

- **Cross-browser “sessions disappear” explanation**
  - Sessions are server-side, but UI typically lists sessions scoped to the current project + `directory` (workspace/worktree dir).
  - Session creation sets `directory: Instance.directory`.
  - Code ref: `src/opencode/packages/opencode/src/session/index.ts`.

- **Why `http://localhost:4096/opencode-sync-localstorage.html` redirects**
  - OpenCode web app behaves like an SPA; unknown paths are handled by router and redirected to app routes.
  - Even if served elsewhere, browser `localStorage` is origin-scoped; a page served from another origin cannot read `http://localhost:4096` storage.

---

## Work Objectives

### Core Objective
Provide a safe, command-only backup/restore for OpenCode server-side data (projects + sessions) using `tar.gz`, with a Git Bash-friendly `.sh` entrypoint and portable path resolution.

### Concrete Deliverables
- `scripts/opencode-portability.sh` (new)
- Documentation:
  - Update or add a short section in `README-workspace-sync.md` (or new `README-opencode-portability.md`) explaining:
    - what is backed up (server storage only)
    - why browser localStorage is excluded
    - why localhost vs tailscale differs
    - cross-browser session scoping by directory

### Definition of Done
- `scripts/opencode-portability.sh --help` exits 0 and lists subcommands.
- `scripts/opencode-portability.sh backup-server --output <file>` creates a readable tarball containing `project/`, `session/`, `message/`, `part/`, and `migration`.
- `scripts/opencode-portability.sh restore-server` refuses to overwrite existing storage unless `--force`.
- If `export-projects-json` / `import-projects-json` subcommands exist: they call Bun scripts and succeed when `bun` is installed.

### Must NOT Have (Guardrails)
- MUST NOT attempt to export/import browser `localStorage` (UI state) in v1.
- MUST NOT back up `${Global.Path.data}/worktree/**` (workspace sandboxes) unless explicitly requested later.
- MUST NOT back up `cache/`, `log/`, `bin/`.
- MUST NOT rewrite absolute worktree paths inside `storage/project/*.json`.

---

## Verification Strategy (Agent-Executable)

### Test Decision
- **Infrastructure exists**: Not required
- **Automated tests**: None (script + manual environment assumptions)
- **Agent-Executed QA**: Mandatory via bash commands

### Agent-Executed QA Scenarios

Scenario: Backup tarball contains required storage directories
  Tool: Bash
  Preconditions: OpenCode not actively writing (server stopped recommended)
  Steps:
    1. Run: `./scripts/opencode-portability.sh backup-server --output /tmp/opencode-storage.tar.gz`
    2. Run: `tar -tzf /tmp/opencode-storage.tar.gz | grep -q '^project/'`
    3. Run: `tar -tzf /tmp/opencode-storage.tar.gz | grep -q '^session/'`
    4. Run: `tar -tzf /tmp/opencode-storage.tar.gz | grep -q '^message/'`
    5. Run: `tar -tzf /tmp/opencode-storage.tar.gz | grep -q '^part/'`
    6. Run: `tar -tzf /tmp/opencode-storage.tar.gz | grep -q '^migration$'`
  Expected Result: All greps exit 0

Scenario: Restore refuses overwrite without --force
  Tool: Bash
  Preconditions: Existing storage dir present and non-empty
  Steps:
    1. Run: `./scripts/opencode-portability.sh restore-server --input /tmp/opencode-storage.tar.gz`
  Expected Result: Non-zero exit; stderr mentions `--force` or refusal

Scenario: Restore creates pre-restore safety backup
  Tool: Bash
  Preconditions: Existing storage dir present and non-empty
  Steps:
    1. Run: `./scripts/opencode-portability.sh restore-server --input /tmp/opencode-storage.tar.gz --force`
    2. Verify: `ls -1 <storage-dir>/../ | grep -E 'storage\.pre-restore\..*\.tar\.gz'`
  Expected Result: A safety tarball exists

---

## Execution Strategy

Wave 1 (Parallel)
- Task 1: Implement script
- Task 2: Documentation update

Wave 2
- Task 3: QA verification commands + edge-case checks (Windows/Git Bash + Linux)

---

## TODOs

- [x] 1. Implement `scripts/opencode-portability.sh`

  **What to do**:
  - Create a bash script that supports:
    - `--help`
    - `list-projects` (minimum: list `storage/project/*.json` filenames; better: if `jq` exists, print `name` + `worktree` too)
    - `backup-server --output <path>`
    - `restore-server --input <path> [--force]`
    - Optional (to match user request to “整理進 script”):
      - `export-projects-json --output <file>` (delegates to `bun run opencode-export-projects.ts --output <file>`)
      - `import-projects-json <file> [--merge]` (delegates to `bun run opencode-import-projects.ts <file> [--merge]`)
      - These subcommands MUST print a clear error if `bun` is missing.
  - Storage path resolution MUST mirror OpenCode behavior:
    - If `OPENCODE_REPO_LOCAL=1` and a repo-local dir exists at `.opencode/xdg/data/opencode/storage`, use it.
    - Else compute `XDG_DATA_HOME` fallback: `${XDG_DATA_HOME:-$HOME/.local/share}` then `.../opencode/storage`.
    - Document overrides explicitly in `--help` output.
  - Backups MUST tar the entire `storage/` directory (including `migration`).
  - Use `tar -czf ... -C "$STORAGE_DIR" .` to avoid absolute paths.
  - Restore MUST:
    - Refuse overwrite unless `--force`.
    - Create pre-restore safety backup tarball.
    - Restore into the storage dir via `tar -xzf ... -C "$STORAGE_DIR"`.
    - Warn if `migration` version differs (read backed-up `migration` file before overwriting if feasible).
  - Add a pre-flight: if quickstart PID file `.opencode/run/opencode-serve.pid` exists, warn/abort (recommend stop server).

  **Must NOT do**:
  - Do not attempt browser localStorage export/import.
  - Do not copy `worktree/` directories.

  **Recommended Agent Profile**:
  - Category: `unspecified-high`
    - Reason: Cross-platform shell scripting with safety checks.
  - Skills: `git-master` (omitted), `playwright` (omitted)
    - `git-master`: not needed (no git ops required)
    - `playwright`: not needed (no browser automation)

  **Parallelization**:
  - Can Run In Parallel: YES (with Task 2)
  - Blocks: Task 3

  **References**:
  - `scripts/opencode-server.sh` - Bash conventions (strict mode, helper functions, PID patterns)
  - `src/opencode/packages/opencode/src/global/index.ts` - How OpenCode computes `Global.Path.data`
  - `src/opencode/packages/opencode/src/storage/storage.ts` - Storage root directory and file naming
  - `src/opencode/packages/opencode/src/project/project.ts` - Projects layout (`storage/project/*.json`)

  **Acceptance Criteria**:
  - `bash -n scripts/opencode-portability.sh` exits 0
  - `scripts/opencode-portability.sh --help` exits 0
  - `scripts/opencode-portability.sh list-projects` exits 0
  - `scripts/opencode-portability.sh backup-server --output /tmp/opencode-storage.tar.gz` exits 0 and file exists
  - `tar -tzf /tmp/opencode-storage.tar.gz | grep -q '^project/'` exits 0
  - `tar -tzf /tmp/opencode-storage.tar.gz | grep -q '^migration$'` exits 0
  - If `bun` exists: `./scripts/opencode-portability.sh export-projects-json --output /tmp/projects-backup.json` exits 0


- [x] 2. Documentation update for portability + cross-browser behavior

  **What to do**:
  - Add a section documenting:
    - What is included in server-side backups (entire `storage/` directory)
    - What is excluded (browser localStorage, worktree sandboxes)
    - Why `opencode-sync-localstorage.html` cannot be served under `http://localhost:4096/` and why origin matters
    - Why sessions appear/disappear across browsers (directory scoping)
  - Include example commands:
    - `./scripts/opencode-portability.sh backup-server --output opencode-storage-$(date +%Y%m%d).tar.gz`
    - `./scripts/opencode-portability.sh restore-server --input opencode-storage-YYYYMMDD.tar.gz --force`

  **Recommended Agent Profile**:
  - Category: `writing`
  - Skills: none

  **Parallelization**:
  - Can Run In Parallel: YES (with Task 1)
  - Blocks: Task 3

  **References**:
  - `README-workspace-sync.md` - existing doc to extend (if preferred)
  - `src/opencode/packages/opencode/src/session/index.ts` - session has `directory`
  - `src/opencode/packages/opencode/src/storage/storage.ts` - storage directories

  **Acceptance Criteria**:
  - Doc includes explicit IN/OUT scope and at least one copy-pasteable backup/restore command

- [x] 3. Verification across environments (Git Bash + one non-Windows)

  **What to do**:
  - Run QA scenarios:
    - Git Bash on Windows
    - WSL or Linux/macOS (at least one)
  - Verify backups restore successfully into a temporary directory first (dry-run style):
    - `mkdir /tmp/opencode-restore-test && tar -xzf backup.tar.gz -C /tmp/opencode-restore-test`

  **Recommended Agent Profile**:
  - Category: `quick`
  - Skills: none

  **Parallelization**:
  - Can Run In Parallel: NO
  - Blocked By: Tasks 1, 2

  **Acceptance Criteria**:
  - All commands in Verification Strategy section succeed

---

## Commit Strategy

- Single commit after Task 1+2: `chore(portability): add server-side backup/restore script`

---

## Success Criteria

### Verification Commands
```bash
bash -n scripts/opencode-portability.sh
./scripts/opencode-portability.sh --help
./scripts/opencode-portability.sh list-projects
./scripts/opencode-portability.sh backup-server --output /tmp/opencode-storage.tar.gz
tar -tzf /tmp/opencode-storage.tar.gz
```

### Final Checklist
- [ ] Script works on Git Bash
- [ ] Script does not require bun/node for core backup/restore
- [ ] Backup includes full `storage/` to preserve sessions
- [ ] Restore is safe-by-default (refuses overwrite without `--force`, creates pre-restore backup)

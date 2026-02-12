# OpenCode Portability & Cross-Browser Behavior

This document explains how OpenCode handles data across different browsers, origins, and devices, and provides tools for backing up and restoring your server-side data.

## Data Storage Overview

OpenCode stores data in two primary locations:

### 1. Server-Side Storage (The "Source of Truth")
Stored on the machine running the OpenCode server.
- **Location**: OpenCode uses the XDG data directory.
  - Linux/macOS/WSL/Git Bash: typically `~/.local/share/opencode/storage`
  - Windows (path on disk): typically `C:\Users\<you>\.local\share\opencode\storage` (Git Bash shows this as `/c/Users/<you>/.local/share/opencode/storage`)
- **Included**:
  - `project/`: Project metadata (ID, name, worktree path).
  - `session/`: Session metadata.
  - `message/`: Chat history and messages.
  - `part/`: Message fragments and attachments.
  - `migration`: Storage migration state (file).
- **Excluded**:
  - `worktree/`: The actual source code sandboxes (these are managed by Git).
  - `cache/`, `log/`, `bin/`: Temporary runtime data.

### 2. Browser LocalStorage (UI State)
Stored in your browser, scoped to the specific **Origin** (Scheme + Host + Port).
- **Included**: UI preferences, theme settings, last opened project, and some authentication tokens.
- **Isolation**: `http://localhost:4096` and `https://your-node.tailscale.net:4096` are different origins. Data in one will **not** appear in the other.
- **Why it matters**: If you switch from accessing OpenCode via `localhost` to using a Tailscale URL, your UI settings (like dark mode or recent projects) will seem to reset. This is a browser security feature (Same-Origin Policy).

---

## Cross-Browser Behavior

### Why do sessions "disappear"?
You might notice that sessions created in one browser tab or device don't appear when you open OpenCode elsewhere, even if connected to the same server. This is due to **Directory Scoping**.

- Each session has a `directory` field (see `src/opencode/packages/opencode/src/session/index.ts`).
- When you open a project, OpenCode filters sessions to only show those matching the current project's directory.
- **Example**: If you create a session while working in `/home/user/project-a`, that session will only be visible when you have `/home/user/project-a` open as your active workspace. If you open `/home/user/project-b`, the session list will be different.
- **Sandboxes**: If you are in a "Sandbox" or a different worktree, only sessions created *within that specific directory* are visible.

### Why can't I serve `opencode-sync-localstorage.html` from the OpenCode port?
If you try to access `http://localhost:4096/opencode-sync-localstorage.html`, you will likely be redirected to the main app.
- **SPA Routing**: OpenCode is a Single Page Application (SPA). Its router (see `src/opencode/packages/app/src/entry.tsx`) handles all paths. Any path it doesn't recognize is redirected to the app's home or a 404 page.
- **Origin Security**: `localStorage` is strictly bound to the origin (scheme + host + port). A page loaded from a different origin cannot read or write OpenCode's origin storage.

Practical approach (manual):
1. Open OpenCode at origin A (e.g. `http://localhost:4096`), export `localStorage` via DevTools Console.
2. Open OpenCode at origin B (e.g. your Tailscale URL), import the exported JSON via DevTools Console.

---

## Portability Scripts

We provide a command-line tool `scripts/opencode-portability.sh` to manage server-side data.

### Backup Server Data
This packages your entire `storage/` directory into a compressed archive.
```bash
./scripts/opencode-portability.sh backup-server --output opencode-storage-$(date +%Y%m%d).tar.gz
```

### Restore Server Data
This restores a previously created backup. **Warning**: This will overwrite existing data.
```bash
./scripts/opencode-portability.sh restore-server --input opencode-storage-YYYYMMDD.tar.gz --force
```
*Note: The script automatically creates a safety backup of your current storage before restoring.*

### List Projects
Quickly see which projects are registered in your server storage.
```bash
./scripts/opencode-portability.sh list-projects
```

---

## Technical References

- **Session Directory Scoping**: `src/opencode/packages/opencode/src/session/index.ts` -> `Session.Info.directory`
- **Storage Layout**: `src/opencode/packages/opencode/src/storage/storage.ts` -> `Storage` namespace
- **SPA Routing**: `src/opencode/packages/app/src/entry.tsx`

# Dependency Management Scripts - Changelog

## 2026-01-30 - Initial Release

### New Features

#### Unified Script Family (`opencode-deps-*`)

Created a family of dependency management scripts with consistent naming and interface:

**Core Scripts:**
- `opencode-deps-manager.sh` / `.ps1` - Core manager with install/update/status actions
- `opencode-deps-install.sh` / `.ps1` - Convenience wrapper for installation
- `opencode-deps-update.sh` / `.ps1` - Convenience wrapper for updates

**Features:**
- ✅ Install dependencies from package.json (first-time setup)
- ✅ Update all dependencies to latest versions
- ✅ Check current environment status
- ✅ Dry-run mode for previewing changes
- ✅ Cross-platform support (Unix/Linux/macOS + Windows)

#### Automatic Dependency Management in start-native.sh

Enhanced `start-native.sh` to automatically handle dependencies:

- **First-time setup**: Automatically detects missing dependencies and runs `opencode-deps-install.sh`
- **Subsequent runs**: Shows a tip about updating dependencies
- **No delays**: Doesn't auto-update on every run to avoid startup delays

### Bug Fixes

#### Bug #1: Incorrect Package Name
- **Issue**: Scripts used `bun update -g opencode` which resulted in 404 error
- **Fix**: Changed to use correct package name `opencode-ai`

#### Bug #2: bun update -g Caching Issue
- **Issue**: `bun update -g oh-my-opencode` only updated to 2.14.0 instead of 3.1.8
- **Fix**: Changed to use `bun install -g <package>@latest` to bypass caching
- **Result**: oh-my-opencode successfully updated from 2.14.0 to 3.1.8

#### Bug #3: Repo-local Plugin Version Pinning
- **Issue**: `@opencode-ai/plugin` stayed at 1.1.34 even after running update
- **Fix**: Changed package.json to use `"latest"` tag instead of fixed version
- **Result**: Plugin now updates correctly with simple `bun update`

### Design Decisions

1. **Use `"latest"` tag**: Simplest approach for a quickstart repo
2. **Unified prefix**: All scripts use `opencode-deps-*` prefix
3. **Wrapper scripts**: Provide convenient shortcuts
4. **Dry-run support**: Preview changes before applying
5. **Backward compatibility**: Old scripts still functional

### Documentation

Created comprehensive documentation:
- `UPDATE.md` - Detailed usage guide
- `MIGRATION.md` - Migration guide from old scripts
- `QUICKREF.md` - Quick reference card
- Updated `README.md` with new dependency management section

### Files Created

**Unix/Linux/macOS:**
- `scripts/opencode-deps-manager.sh`
- `scripts/opencode-deps-install.sh`
- `scripts/opencode-deps-update.sh`

**Windows:**
- `scripts/windows/opencode-deps-manager.ps1`
- `scripts/windows/opencode-deps-install.ps1`
- `scripts/windows/opencode-deps-update.ps1`

**Documentation:**
- `scripts/UPDATE.md`
- `scripts/MIGRATION.md`
- `scripts/QUICKREF.md`
- `scripts/CHANGELOG.md` (this file)

### Files Modified

- `start-native.sh` - Added automatic dependency management
- `README.md` - Updated dependency management section
- `.opencode/package.json` - Changed to use `"latest"` tag

### Backward Compatibility

Old scripts are preserved and still functional:
- `scripts/prerequisite.sh`
- `scripts/prerequisite.ps1`
- `scripts/update-opencode.sh`
- `scripts/windows/update-opencode.ps1`

### Version Updates Achieved

- OpenCode CLI: 1.1.34 → 1.1.44
- oh-my-opencode: 2.13.2 → 3.1.8
- @opencode-ai/plugin: 1.1.34 → 1.1.44

### Related Work Items

- Task: KO-TSK-0005 - Create unified OpenCode dependency management scripts

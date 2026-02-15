# README Update - Dual Mode Documentation

## Task: KO-TSK-0002 & KO-TSK-0004

### Changes Made

Added comprehensive "Modes" section to README.md explaining:

1. **User Mode (Default)**
   - For general users using official OpenCode release
   - Uses system-installed `opencode` CLI
   - No source code required
   - Quick start: `./start-native.sh`

2. **Developer Mode**
   - For contributors running from source
   - Uses `src/opencode` submodule
   - Supports upstream synchronization
   - Quick start: `./scripts/dev-mode/start-build-native.sh`
   - Options documented: `-U`, `-S`, `-h`

3. **Prerequisites Section Updated**
   - Split into User Mode and Developer Mode requirements
   - Clear distinction between what's needed for each mode
   - Submodule initialization instructions for dev mode

### Documentation Structure

- Modes section placed prominently after "What's inside"
- Clear examples for both modes
- Option descriptions for developer mode
- Prerequisites updated to reflect both modes

✅ Tasks KO-TSK-0002, KO-TSK-0003, and KO-TSK-0004 completed successfully!

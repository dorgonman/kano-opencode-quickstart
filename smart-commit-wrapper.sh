#!/usr/bin/env bash
# Temporary wrapper to run smart-commit for the whole project

# Path to the actual script in the skill
REAL_SCRIPT="skills/kano-git-master-skill/scripts/commit-tools/smart-commit-push.sh"
SKILL_DIR="skills/kano-git-master-skill"

# We need to trick the script into seeing the main repo as ROOT.
# The script uses SCRIPT_DIR/../.. to find roots.
# If we copy the script to a depth of 3 levels from the root, it will work.

mkdir -p .tmp/scripts/commit-tools
cp -r "$SKILL_DIR/scripts/commit-tools/lib" .tmp/scripts/commit-tools/
cp "$SKILL_DIR/scripts/commit-tools/smart-commit.sh" .tmp/scripts/commit-tools/
cp "$SKILL_DIR/scripts/commit-tools/smart-push.sh" .tmp/scripts/commit-tools/
cp "$SKILL_DIR/scripts/commit-tools/smart-commit-push.sh" .tmp/scripts/commit-tools/

# Now run it from .tmp/scripts/commit-tools
# SCRIPT_DIR will be <repo>/.tmp/scripts/commit-tools
# SCRIPT_DIR/../.. will be <repo>/.tmp
# Wait, SCRIPT_DIR/../.. will be <repo>/.tmp. That's not the main repo root.
# It needs to be <repo>/scripts/commit-tools/something.

mkdir -p scripts/git/commit-tools
cp -r "$SKILL_DIR/scripts/commit-tools/lib" scripts/git/commit-tools/
cp "$SKILL_DIR/scripts/commit-tools/smart-commit.sh" scripts/git/commit-tools/
cp "$SKILL_DIR/scripts/commit-tools/smart-push.sh" scripts/git/commit-tools/
cp "$SKILL_DIR/scripts/commit-tools/smart-commit-push.sh" scripts/git/commit-tools/

# In scripts/git/commit-tools:
# SCRIPT_DIR is <repo>/scripts/git/commit-tools
# SCRIPT_DIR/../.. is <repo>/scripts
# git -C <repo>/scripts rev-parse --show-toplevel will return <repo>!

bash scripts/git/commit-tools/smart-commit-push.sh --provider opencode --model auto --no-ai-review "$@"

# Cleanup
# rm -rf scripts/git/commit-tools

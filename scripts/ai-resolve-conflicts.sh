#!/bin/bash

###############################################################################
# AI-Assisted Conflict Resolution
#
# This script uses Claude Code or OpenClaw agents to intelligently resolve
# merge conflicts when syncing upstream changes.
#
# Usage:
#   ./scripts/ai-resolve-conflicts.sh
###############################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT"

# Check if we're in a rebase/merge
if [[ ! -d ".git/rebase-merge" ]] && [[ ! -d ".git/rebase-apply" ]] && [[ ! -f ".git/MERGE_HEAD" ]]; then
    echo "No rebase or merge in progress. Nothing to resolve."
    exit 0
fi

# Get conflicted files
CONFLICTED_FILES=$(git diff --name-only --diff-filter=U)

if [[ -z "$CONFLICTED_FILES" ]]; then
    echo "No conflicted files found."
    exit 0
fi

echo "Found conflicts in the following files:"
echo "$CONFLICTED_FILES"
echo ""

# Create a detailed conflict analysis prompt
PROMPT_FILE=$(mktemp)

cat > "$PROMPT_FILE" << 'EOF'
# Merge Conflict Resolution Task

You are helping resolve merge conflicts in the Sunsetting AI fork of OpenClaw.

## Context
- **Upstream**: OpenClaw (https://github.com/openclaw/openclaw)
- **Fork**: Sunsetting AI (legacy code modernization platform)
- **Customizations**: Branding, UI changes, custom "Spaces" feature

## Your Task
Resolve the merge conflicts in the files listed below by:

1. **Reading each conflicted file** to understand both sides:
   - `<<<<<<< HEAD` = Our Sunsetting customizations
   - `>>>>>>> upstream/main` = New upstream OpenClaw changes

2. **Analyzing the conflicts**:
   - Are they branding/naming conflicts? (Keep Sunsetting branding)
   - Are they feature conflicts? (Merge both features intelligently)
   - Are they refactors? (Apply refactor while preserving our customizations)

3. **Resolving intelligently**:
   - Preserve all Sunsetting-specific features (Spaces, custom UI, branding)
   - Adopt upstream improvements (bug fixes, performance, new features)
   - When in doubt, keep both and make them work together

4. **Verify the resolution**:
   - Ensure code compiles
   - Ensure tests pass
   - Ensure no functionality is lost

## Conflicted Files
EOF

echo "$CONFLICTED_FILES" >> "$PROMPT_FILE"

cat >> "$PROMPT_FILE" << 'EOF'

## Resolution Process

For each file:
1. Use the `Read` tool to view the conflicted file
2. Understand what each side changed and why
3. Use the `Edit` tool to resolve conflicts, removing conflict markers
4. Stage the resolved file: `git add <file>`

After resolving all files:
1. Continue the rebase: `git rebase --continue`
2. Verify build: `pnpm build`
3. Report summary of resolutions

## Rules
- NEVER discard Sunsetting branding (name, logo, theme)
- NEVER discard the Spaces feature
- ALWAYS prefer merging over choosing one side
- ALWAYS test the build after resolving

Begin!
EOF

echo "Conflict analysis prompt created: $PROMPT_FILE"
echo ""

# Try different AI tools in order of preference

if command -v claude &> /dev/null; then
    echo "Using Claude Code CLI..."
    claude --file "$PROMPT_FILE"

elif command -v openclaw &> /dev/null; then
    echo "Using OpenClaw agent..."
    openclaw message send --file "$PROMPT_FILE" --agent default --thinking high

elif command -v codex &> /dev/null; then
    echo "Using Codex agent..."
    codex "$PROMPT_FILE"

else
    echo "⚠️  No AI CLI tool found (claude, openclaw, or codex)"
    echo ""
    echo "Please resolve conflicts manually, or install one of:"
    echo "  - Claude Code: https://docs.anthropic.com/claude/docs/claude-code"
    echo "  - OpenClaw: Already in this repo"
    echo "  - Codex: https://github.com/anthropics/codex"
    echo ""
    echo "Conflict resolution prompt saved to: $PROMPT_FILE"
    echo "You can copy this prompt and paste it into Claude Code or another AI assistant."
    exit 1
fi

# Clean up
rm -f "$PROMPT_FILE"

echo ""
echo "AI conflict resolution complete!"
echo "Next steps:"
echo "  1. Review the changes"
echo "  2. Test the build: pnpm build"
echo "  3. If good, the rebase should be complete"

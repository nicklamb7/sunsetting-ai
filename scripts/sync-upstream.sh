#!/bin/bash
set -e

###############################################################################
# Sunsetting AI - Automated Upstream Sync Script
#
# This script syncs the latest OpenClaw changes into the Sunsetting fork
# and uses Claude Code to resolve any merge conflicts automatically.
#
# Usage:
#   ./scripts/sync-upstream.sh          # Interactive mode
#   ./scripts/sync-upstream.sh --auto   # Automated mode (for cron)
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_FILE="$REPO_ROOT/sync-upstream.log"
CONFLICT_DIR="$REPO_ROOT/.sync-conflicts"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" | tee -a "$LOG_FILE"
}

###############################################################################
# 1. Pre-flight checks
###############################################################################

cd "$REPO_ROOT"

log "Starting upstream sync..."
log "Repository: $(pwd)"

# Check if we're on a clean working tree
if [[ -n $(git status --porcelain) ]]; then
    error "Working directory is not clean. Please commit or stash changes first."
    git status --short
    exit 1
fi

# Check current branch
CURRENT_BRANCH=$(git branch --show-current)
log "Current branch: $CURRENT_BRANCH"

if [[ "$CURRENT_BRANCH" != "main" ]]; then
    warn "Not on main branch. Switching to main..."
    git checkout main
fi

###############################################################################
# 2. Fetch upstream changes
###############################################################################

log "Fetching upstream OpenClaw changes..."
git fetch upstream main

# Check if there are new commits
BEHIND_COUNT=$(git rev-list --count HEAD..upstream/main)

if [[ "$BEHIND_COUNT" -eq 0 ]]; then
    log "Already up to date with upstream. No sync needed."
    exit 0
fi

log "Found $BEHIND_COUNT new commits from upstream"

###############################################################################
# 3. Create backup branch
###############################################################################

BACKUP_BRANCH="backup/pre-sync-$(date +'%Y%m%d-%H%M%S')"
log "Creating backup branch: $BACKUP_BRANCH"
git branch "$BACKUP_BRANCH"

###############################################################################
# 4. Attempt rebase
###############################################################################

log "Attempting to rebase onto upstream/main..."

if git rebase upstream/main; then
    log "✅ Rebase successful! No conflicts."

    # Clean up old backup branches (keep last 10)
    log "Cleaning up old backup branches..."
    git branch | grep "backup/pre-sync-" | sort -r | tail -n +11 | xargs -r git branch -D || true

    log "Sync complete!"
    exit 0
else
    warn "⚠️  Rebase encountered conflicts. Initiating AI-assisted resolution..."
fi

###############################################################################
# 5. Handle conflicts with Claude Code
###############################################################################

# Get list of conflicted files
CONFLICTED_FILES=$(git diff --name-only --diff-filter=U)

if [[ -z "$CONFLICTED_FILES" ]]; then
    error "Rebase failed but no conflicts found. Manual intervention required."
    git rebase --abort
    git checkout "$BACKUP_BRANCH"
    exit 1
fi

log "Conflicted files:"
echo "$CONFLICTED_FILES" | while read -r file; do
    log "  - $file"
done

# Save conflict information
mkdir -p "$CONFLICT_DIR"
CONFLICT_REPORT="$CONFLICT_DIR/conflict-report-$(date +'%Y%m%d-%H%M%S').md"

cat > "$CONFLICT_REPORT" << EOF
# Upstream Sync Conflict Report
Date: $(date)
Upstream commits: $BEHIND_COUNT new commits
Conflicted files: $(echo "$CONFLICTED_FILES" | wc -l)

## Conflicted Files
$CONFLICTED_FILES

## Conflict Details

EOF

# Append git status to report
git status >> "$CONFLICT_REPORT"

log "Conflict report saved: $CONFLICT_REPORT"

###############################################################################
# 6. AI-Assisted Resolution (Claude Code / Codex Agent)
###############################################################################

log "Attempting AI-assisted conflict resolution..."

# Check if we're in automated mode
AUTO_MODE=false
if [[ "$1" == "--auto" ]]; then
    AUTO_MODE=true
fi

if [[ "$AUTO_MODE" == true ]]; then
    # Use Claude Code CLI to resolve conflicts
    log "Running Claude Code to resolve conflicts..."

    # Create prompt for Claude
    CLAUDE_PROMPT="The upstream OpenClaw repository has $BEHIND_COUNT new commits that conflict with our Sunsetting AI customizations.

Conflicted files:
$CONFLICTED_FILES

Please resolve these merge conflicts by:
1. Reading each conflicted file
2. Understanding both the upstream changes and our customizations
3. Merging them intelligently, preferring to keep Sunsetting branding/customizations
4. Ensuring the code compiles and tests pass
5. Marking conflicts as resolved

After resolving all conflicts:
- Run: git add <resolved-files>
- Run: git rebase --continue
- Verify the build works: pnpm build

Report back with a summary of changes made."

    # Check if openclaw CLI is available for agent invocation
    if command -v openclaw &> /dev/null; then
        log "Invoking OpenClaw agent for conflict resolution..."
        echo "$CLAUDE_PROMPT" | openclaw message send --agent conflict-resolver --thinking high || {
            warn "Agent resolution failed. Falling back to manual mode."
            AUTO_MODE=false
        }
    else
        warn "OpenClaw CLI not found. Cannot auto-resolve. Falling back to manual mode."
        AUTO_MODE=false
    fi
fi

if [[ "$AUTO_MODE" == false ]]; then
    # Manual / interactive mode
    warn "Please resolve conflicts manually."
    echo ""
    echo "Options:"
    echo "  1. Use your editor to resolve conflicts in the files listed above"
    echo "  2. Use Claude Code in your IDE to help resolve conflicts"
    echo "  3. Or run this command to invoke AI assistance:"
    echo ""
    echo "     openclaw message send --file $CONFLICT_REPORT \"Resolve these merge conflicts\""
    echo ""
    echo "After resolving conflicts, run:"
    echo "  git add <resolved-files>"
    echo "  git rebase --continue"
    echo "  pnpm build  # verify it works"
    echo ""
    echo "Or to abort the rebase:"
    echo "  git rebase --abort"
    echo "  git checkout $BACKUP_BRANCH"
    exit 1
fi

###############################################################################
# 7. Verify resolution
###############################################################################

# Check if rebase is still in progress
if [[ -d "$REPO_ROOT/.git/rebase-merge" ]] || [[ -d "$REPO_ROOT/.git/rebase-apply" ]]; then
    warn "Rebase still in progress. AI resolution may not have completed."
    exit 1
fi

# Verify build works
log "Verifying build after conflict resolution..."
if pnpm build; then
    log "✅ Build successful after AI-assisted conflict resolution!"
    log "Sync complete!"
else
    error "Build failed after conflict resolution. Manual review needed."
    exit 1
fi

###############################################################################
# 8. Summary
###############################################################################

log "========================================="
log "Sync Summary:"
log "  Upstream commits merged: $BEHIND_COUNT"
log "  Conflicts resolved: $(echo "$CONFLICTED_FILES" | wc -l)"
log "  Backup branch: $BACKUP_BRANCH"
log "  Build status: PASSED"
log "========================================="

exit 0

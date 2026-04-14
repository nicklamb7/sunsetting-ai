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

# Always try AI resolution first (both manual and auto modes)
log "Running AI agent to resolve conflicts..."

# Create prompt for AI
AI_PROMPT="The upstream OpenClaw repository has $BEHIND_COUNT new commits that conflict with our Sunsetting AI customizations.

Conflicted files:
$CONFLICTED_FILES

Please resolve these merge conflicts by:
1. Reading each conflicted file to understand both sides
2. Understanding the upstream changes (after >>>>>>> upstream/main)
3. Understanding our Sunsetting customizations (after <<<<<<< HEAD)
4. Merging them intelligently:
   - ALWAYS keep Sunsetting branding (name, logo color #FF4B44, UI text)
   - ALWAYS keep [SUNSETTING] prefixed features
   - Adopt upstream bug fixes and improvements
5. Remove all conflict markers (<<<<<<, =======, >>>>>>>)
6. Mark conflicts as resolved with: git add <resolved-files>
7. Continue the rebase with: git rebase --continue
8. Verify the build works: pnpm build

Report back with a summary of changes made."

# Try AI tools in order of preference: Claude Code → Codex → OpenClaw CLI
RESOLVED=false

if command -v claude &> /dev/null && [[ "$RESOLVED" == false ]]; then
    log "Using Claude Code for conflict resolution..."
    if echo "$AI_PROMPT" | claude; then
        RESOLVED=true
        log "Claude Code resolved conflicts successfully"
    else
        warn "Claude Code resolution failed, trying next tool..."
    fi
fi

if command -v codex &> /dev/null && [[ "$RESOLVED" == false ]]; then
    log "Using Codex for conflict resolution..."
    if echo "$AI_PROMPT" | codex; then
        RESOLVED=true
        log "Codex resolved conflicts successfully"
    else
        warn "Codex resolution failed, trying next tool..."
    fi
fi

if [[ -f "./openclaw.mjs" ]] && [[ "$RESOLVED" == false ]]; then
    log "Using OpenClaw agent for conflict resolution..."
    PROMPT_FILE=$(mktemp)
    echo "$AI_PROMPT" > "$PROMPT_FILE"
    # Ensure we use Node 22 for OpenClaw CLI
    if source ~/.nvm/nvm.sh && nvm use 22 &> /dev/null && ./openclaw.mjs message send --file "$PROMPT_FILE" --agent default --thinking high; then
        RESOLVED=true
        log "OpenClaw agent resolved conflicts successfully"
    else
        warn "OpenClaw agent resolution failed"
    fi
    rm -f "$PROMPT_FILE"
fi

if [[ "$RESOLVED" == false ]]; then
    warn "All AI tools failed. Please resolve conflicts manually."
    echo ""
    echo "Options:"
    echo "  1. Use your editor to resolve conflicts in the files listed above"
    echo "  2. Use Claude Code in your IDE to help resolve conflicts"
    echo "  3. Or run the AI helper script:"
    echo ""
    echo "     ./scripts/ai-resolve-conflicts.sh"
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

#!/bin/bash
set -euo pipefail

###############################################################################
# Sunsetting AI - Automated Upstream Sync Script
#
# This script syncs the latest OpenClaw changes into the Sunsetting fork
# and uses Claude Code / Codex to resolve any merge conflicts automatically.
#
# Usage:
#   ./scripts/sync-upstream.sh          # Interactive mode
#   ./scripts/sync-upstream.sh --auto   # Automated mode (for cron)
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_FILE="$REPO_ROOT/sync-upstream.log"
CONFLICT_DIR="$REPO_ROOT/.sync-conflicts"
AUTO_MODE=false
[[ "${1:-}" == "--auto" ]] && AUTO_MODE=true

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

cleanup_on_failure() {
    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        return 0
    fi

    if git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
        if [[ -d "$REPO_ROOT/.git/rebase-merge" || -d "$REPO_ROOT/.git/rebase-apply" ]]; then
            warn "Failure occurred during rebase. Aborting rebase to leave repo in a clean state..."
            git -C "$REPO_ROOT" rebase --abort || true
        fi
    fi

    return "$exit_code"
}
trap cleanup_on_failure EXIT

is_rebase_in_progress() {
    [[ -d "$REPO_ROOT/.git/rebase-merge" || -d "$REPO_ROOT/.git/rebase-apply" ]]
}

continue_rebase_until_done() {
    while is_rebase_in_progress; do
        local conflicted_files
        conflicted_files=$(git diff --name-only --diff-filter=U || true)
        if [[ -n "$conflicted_files" ]]; then
            warn "Rebase still has unresolved conflicts:"
            echo "$conflicted_files" | while read -r file; do
                [[ -n "$file" ]] && warn "  - $file"
            done
            return 2
        fi

        if git rebase --continue; then
            log "Advanced rebase to the next step."
            continue
        fi

        warn "git rebase --continue reported a problem. Checking whether Git is asking for an editor..."
        if GIT_EDITOR=true git rebase --continue; then
            log "Advanced rebase to the next step."
            continue
        fi

        conflicted_files=$(git diff --name-only --diff-filter=U || true)
        if [[ -n "$conflicted_files" ]]; then
            warn "New conflicts appeared after rebase continue. Handing off to conflict-resolution flow."
            echo "$conflicted_files" | while read -r file; do
                [[ -n "$file" ]] && warn "  - $file"
            done
            return 2
        fi

        return 1
    done
    return 0
}

capture_conflict_state() {
    CONFLICTED_FILES=$(git diff --name-only --diff-filter=U || true)

    if [[ -z "$CONFLICTED_FILES" ]]; then
        error "Rebase failed but no conflicts were found. Manual intervention required."
        exit 1
    fi

    log "Conflicted files:"
    echo "$CONFLICTED_FILES" | while read -r file; do
        [[ -n "$file" ]] && log "  - $file"
    done

    mkdir -p "$CONFLICT_DIR"
    CONFLICT_REPORT="$CONFLICT_DIR/conflict-report-$(date +'%Y%m%d-%H%M%S').md"

    cat > "$CONFLICT_REPORT" << EOF
# Upstream Sync Conflict Report
Date: $(date)
Upstream commits: $BEHIND_COUNT new commits
Conflicted files: $(echo "$CONFLICTED_FILES" | sed '/^$/d' | wc -l)

## Conflicted Files
$CONFLICTED_FILES

## Conflict Details

EOF

    git status >> "$CONFLICT_REPORT"
    log "Conflict report saved: $CONFLICT_REPORT"
}

run_pnpm() {
    if command -v pnpm >/dev/null 2>&1; then
        pnpm "$@"
        return $?
    fi

    if command -v corepack >/dev/null 2>&1; then
        corepack pnpm "$@"
        return $?
    fi

    error "Neither pnpm nor corepack is available in PATH."
    return 127
}

sync_workspace_install_if_needed() {
    local install_log="$CONFLICT_DIR/pnpm-install-$(date +'%Y%m%d-%H%M%S').log"
    warn "Build validation indicates the installed workspace graph is stale. Running a locked pnpm install before retrying build..."
    if run_pnpm install --frozen-lockfile 2>&1 | tee -a "$install_log"; then
        log "Locked install completed successfully."
        return 0
    fi

    error "Locked install failed. See $install_log for details."
    return 1
}

verify_build() {
    log "Verifying build after sync..."
    local build_log="$CONFLICT_DIR/build-verify-$(date +'%Y%m%d-%H%M%S').log"
    if run_pnpm build 2>&1 | tee -a "$build_log"; then
        log "✅ Build successful!"
        return 0
    fi

    if grep -q "Run `pnpm install` and rebuild from a trusted workspace checkout" "$build_log"; then
        if sync_workspace_install_if_needed; then
            log "Retrying build after locked install..."
            if run_pnpm build 2>&1 | tee -a "$build_log"; then
                log "✅ Build successful after locked install!"
                return 0
            fi
        fi
    fi

    error "Build failed after sync. Manual review needed. See $build_log for details."
    return 1
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

if ! git remote get-url upstream >/dev/null 2>&1; then
    error "Git remote 'upstream' is not configured. Add it before running sync-upstream.sh."
    exit 1
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
    trap - EXIT
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

    log "Cleaning up old backup branches..."
    git branch | grep "backup/pre-sync-" | sort -r | tail -n +11 | xargs -r git branch -D || true

    verify_build
    log "Sync complete!"
    trap - EXIT
    exit 0
else
    warn "⚠️  Rebase encountered conflicts. Initiating conflict-resolution flow..."
fi

###############################################################################
# 5. Capture conflict information
###############################################################################

capture_conflict_state

###############################################################################
# 6. Automatic Resolution for Known Safe Conflicts
###############################################################################

log "Checking for auto-resolvable conflicts..."

if echo "$CONFLICTED_FILES" | grep -q "^src/canvas-host/a2ui/.bundle.hash$"; then
    log "Auto-resolving .bundle.hash (generated file, taking upstream version)..."
    git checkout --theirs src/canvas-host/a2ui/.bundle.hash
    git add src/canvas-host/a2ui/.bundle.hash
    CONFLICTED_FILES=$(echo "$CONFLICTED_FILES" | grep -v "^src/canvas-host/a2ui/.bundle.hash$" || true)
fi

if [[ -z "$(echo "$CONFLICTED_FILES" | sed '/^$/d')" ]]; then
    log "All current conflicts auto-resolved. Continuing rebase..."
    continue_rebase_until_done
    continue_status=$?
    if [[ $continue_status -eq 0 ]]; then
        log "✅ Rebase successful after auto-resolution!"
        verify_build
        log "Sync complete!"
        trap - EXIT
        exit 0
    fi
    if [[ $continue_status -eq 2 ]]; then
        capture_conflict_state
        warn "Auto-resolution surfaced additional conflicts. Escalating into AI-assisted conflict resolution."
    else
        error "Auto-resolution finished, but the rebase could not be completed cleanly."
        exit 1
    fi
fi

###############################################################################
# 7. AI-Assisted Resolution (Claude Code / Codex Agent)
###############################################################################

log "Attempting AI-assisted conflict resolution..."
log "Running AI agent to resolve conflicts..."

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
8. Verify the build works: use `pnpm build` if available, otherwise `corepack pnpm build`

Report back with a summary of changes made."

RESOLVED=false

if command -v claude &> /dev/null && [[ "$RESOLVED" == false ]]; then
    log "Using Claude Code for conflict resolution..."
    if echo "$AI_PROMPT" | claude --permission-mode bypassPermissions --print; then
        RESOLVED=true
        log "Claude Code resolved conflicts successfully"
    else
        warn "Claude Code resolution failed, trying next tool..."
    fi
fi

if command -v codex &> /dev/null && [[ "$RESOLVED" == false ]]; then
    log "Using Codex for conflict resolution..."
    if codex exec "$AI_PROMPT"; then
        RESOLVED=true
        log "Codex resolved conflicts successfully"
    else
        warn "Codex resolution failed, trying next tool..."
    fi
fi

if [[ -f "./openclaw.mjs" && "$RESOLVED" == false ]]; then
    log "Using OpenClaw agent for conflict resolution..."
    PROMPT_FILE=$(mktemp)
    echo "$AI_PROMPT" > "$PROMPT_FILE"
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
    echo "  pnpm build  # or: corepack pnpm build"
    echo ""
    echo "Or to abort the rebase:"
    echo "  git rebase --abort"
    echo "  git checkout $BACKUP_BRANCH"
    exit 1
fi

###############################################################################
# 8. Verify resolution and complete rebase
###############################################################################

if continue_rebase_until_done; then
    log "✅ Rebase successful after AI-assisted conflict resolution!"
else
    error "AI conflict resolution ran, but the rebase is still incomplete or conflicts remain."
    exit 1
fi

verify_build

###############################################################################
# 9. Summary
###############################################################################

log "Cleaning up old backup branches..."
git branch | grep "backup/pre-sync-" | sort -r | tail -n +11 | xargs -r git branch -D || true

log "========================================="
log "Sync Summary:"
log "  Upstream commits merged: $BEHIND_COUNT"
log "  Backup branch: $BACKUP_BRANCH"
log "  Build status: PASSED"
log "========================================="
log "Sync complete!"

trap - EXIT
exit 0

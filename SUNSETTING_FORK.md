# Sunsetting AI - OpenClaw Fork

This repository is a managed fork of [OpenClaw](https://github.com/openclaw/openclaw) for the Sunsetting AI platform.

## Fork Strategy

We maintain a **layered fork** approach:
- **Base**: OpenClaw upstream (regularly synced)
- **Customizations**: Sunsetting branding, UI, and Spaces feature
- **Sync**: Automated daily rebasing with AI-assisted conflict resolution

This allows us to:
✅ Get upstream bug fixes and features automatically
✅ Keep our customizations on top as clean commits
✅ Minimize maintenance burden
✅ Contribute improvements back to OpenClaw

## Repository Structure

```
sunsetting-openclaw/
├── scripts/
│   ├── sync-upstream.sh          # Main sync script
│   ├── ai-resolve-conflicts.sh   # AI-assisted conflict resolution
│   └── setup-daily-sync.sh       # Configure automated daily sync
├── .sync-conflicts/              # Conflict reports (gitignored)
├── sync-upstream.log             # Sync history log
└── [rest of OpenClaw codebase]
```

## Syncing Upstream Changes

### Automated Daily Sync

Set up once:
```bash
./scripts/setup-daily-sync.sh
```

This creates a daily job (3:00 AM) that:
1. Fetches latest OpenClaw changes
2. Rebases our customizations onto them
3. Uses AI to resolve conflicts automatically
4. Verifies the build passes

### Manual Sync

Sync anytime:
```bash
./scripts/sync-upstream.sh
```

Interactive mode (default):
- Shows conflicts
- Waits for manual/AI resolution
- Provides guidance

Automated mode (for cron):
```bash
./scripts/sync-upstream.sh --auto
```

### AI-Assisted Conflict Resolution

If conflicts occur:
```bash
./scripts/ai-resolve-conflicts.sh
```

This uses Claude Code / OpenClaw agents to:
- Analyze conflicts intelligently
- Preserve Sunsetting customizations
- Adopt upstream improvements
- Resolve conflicts automatically

## Our Customizations

Commits tagged with `[SUNSETTING]` are our customizations:

### Branding
- `[SUNSETTING] Rebrand: OpenClaw → Sunsetting AI`
- Logo, colors, theme, naming

### Features
- `[SUNSETTING] Add Spaces feature`
- Custom UI for legacy modernization workflows

### Configuration
- `[SUNSETTING] Custom default configuration`
- Sunsetting-specific settings

## Contributing Back to OpenClaw

When we find bugs or make improvements that benefit OpenClaw:

1. Cherry-pick the commit:
   ```bash
   git cherry-pick <commit-hash>
   ```

2. Create a patch:
   ```bash
   git format-patch -1 <commit-hash>
   ```

3. Submit to OpenClaw:
   - Open PR on https://github.com/openclaw/openclaw
   - Reference our use case in description

## Git Workflow

### Branches

- `main` - Our production branch (OpenClaw + Sunsetting customizations)
- `backup/pre-sync-YYYYMMDD-HHMMSS` - Automatic backups before each sync
- `upstream/main` - OpenClaw upstream (read-only)

### Commit Conventions

**Upstream commits**: Preserve original commit messages

**Our commits**: Prefix with `[SUNSETTING]`
```bash
git commit -m "[SUNSETTING] Add Business Case Space UI"
git commit -m "[SUNSETTING] Fix: Rebrand remaining OpenClaw references"
```

### Recovering from Failed Sync

If a sync goes wrong:

1. **Abort the rebase**:
   ```bash
   git rebase --abort
   ```

2. **Restore from backup**:
   ```bash
   git checkout backup/pre-sync-YYYYMMDD-HHMMSS
   git branch -D main
   git checkout -b main
   ```

3. **Try again manually**:
   ```bash
   ./scripts/sync-upstream.sh
   ```

## Maintenance

### View Sync History
```bash
cat sync-upstream.log
```

### Check for Upstream Changes
```bash
git fetch upstream
git log HEAD..upstream/main --oneline
```

### Clean Up Old Backups
```bash
# Keep only last 10 backups
git branch | grep backup/pre-sync- | sort -r | tail -n +11 | xargs git branch -D
```

## FAQ

**Q: How often should we sync?**
A: Daily automated sync is recommended. OpenClaw moves fast (multiple commits per day).

**Q: What if AI can't resolve conflicts?**
A: The script falls back to manual mode and provides clear instructions. You can also use Claude Code in your IDE.

**Q: Can we disable automated sync?**
A: Yes:
- macOS: `launchctl unload ~/Library/LaunchAgents/ai.sunsetting.sync-upstream.plist`
- Linux: `crontab -e` and remove the line

**Q: Should we contribute features back to OpenClaw?**
A: General improvements (bug fixes, refactors) = YES. Sunsetting-specific features (Spaces) = NO (keep them proprietary).

**Q: What if upstream adds conflicting features?**
A: AI resolution will attempt to merge. If irreconcilable, we'll need to decide whether to adopt upstream's approach or keep ours.

## Support

For issues with:
- **Sync scripts**: Check `sync-upstream.log`
- **OpenClaw base**: See https://github.com/openclaw/openclaw/issues
- **Sunsetting customizations**: Internal team issue tracker

---

**Last Updated**: 2026-04-14
**OpenClaw Base Version**: 2026.4.14-beta.1
**Sunsetting Version**: 0.1.0-dev

---
summary: "Thin readiness contract for Sunsetting's daily upstream sync and bounded fork-porting work"
read_when:
  - Maintaining a managed fork that rebases onto upstream daily
  - Deciding whether Sunsetting work is safe to start after a sync run
  - Implementing or consuming Sunsetting's upstream readiness snapshot
  - Working issue ENG-12
title: "Sunsetting Upstream Readiness Surface"
---

# Sunsetting upstream sync and porting readiness surface

Issue: ENG-12

## Goal

Turn the existing daily upstream sync outputs into one operator-readable readiness snapshot that framework shaping and execution runs can trust.

This is intentionally a thin layer on top of the current sync workflow. It does not replace `scripts/sync-upstream.sh`.

## Operator question this answers

Before starting new Sunsetting work, can we safely keep porting on top of the current fork, or do we need to fix fork health first?

## Proposed output

Write a single machine-readable and human-readable snapshot after each sync run:

- path: `.sunsetting/upstream-readiness.json`
- companion summary: `.sunsetting/upstream-readiness.md`

The JSON file is the contract for automation. The Markdown file is the quick operator view.

## Minimum readiness fields

### Sync health

- `generatedAt`
- `baseBranch` (`main`)
- `upstreamRef` (`upstream/main`)
- `upstreamHeadSha`
- `forkHeadSha`
- `aheadOfUpstream`
- `behindUpstream`
- `syncAttempted` (`true` or `false`)
- `syncResult` (`clean`, `conflicts-auto-resolved`, `conflicts-needs-review`, `failed`, `skipped`)
- `conflictCount`
- `conflictReportPaths`
- `humanReviewNeeded` (`true` or `false`)

### Build verification

- `buildVerified` (`true` or `false`)
- `buildLogPath`
- `buildSummary`

### Sunsetting delta inventory

- `sunsettingCommitCount`
- `sunsettingCommits`
- `deltaBuckets`
- `deltaSummary`

### Recommended action

- `readiness` (`green`, `yellow`, `red`)
- `recommendedAction`
- `blockingReasons`
- `nextPortingTarget`

## Readiness rules

### Green

Safe to continue porting when all are true:

- `behindUpstream == 0`
- latest sync result is `clean` or `conflicts-auto-resolved`
- `buildVerified == true`
- no unresolved conflict markers
- no manual-review flag remains open

Recommended action: continue Tier 1 Sunsetting work.

### Yellow

Proceed carefully when fork health is mostly good but needs attention soon:

- upstream drift is small but non-zero, or
- auto-resolved conflicts happened and should be sampled by a human, or
- build passed but a generated-file or delta-tracking follow-up is still open

Recommended action: small bounded work only, with another base refresh before PR.

### Red

Do not start new implementation when any are true:

- build verification failed
- sync failed or stopped with unresolved conflicts
- `humanReviewNeeded == true`
- unresolved conflict markers exist
- the fork is materially behind upstream

Recommended action: repair sync health first.

## Source mapping

The first version should only depend on data we already have.

| Field                      | Source                                                                             |
| -------------------------- | ---------------------------------------------------------------------------------- |
| `upstreamHeadSha`          | `git rev-parse upstream/main`                                                      |
| `forkHeadSha`              | `git rev-parse HEAD`                                                               |
| ahead/behind counts        | `git rev-list --left-right --count HEAD...upstream/main`                           |
| sync result                | `sync-upstream.log` plus script exit status                                        |
| conflict count and reports | `.sync-conflicts/conflict-report-*.md`                                             |
| build verification result  | latest `.sync-conflicts/build-verify-*.log` and sync script result                 |
| unresolved conflicts       | `git diff --name-only --diff-filter=U` and `scripts/check-no-conflict-markers.mjs` |
| Sunsetting deltas          | `git log --grep='\[SUNSETTING\]' --oneline --no-merges`                            |

## First Sunsetting delta inventory

Current surviving fork-specific deltas fall into three buckets:

### 1. Fork maintenance

- `[SUNSETTING] Initial fork setup with automated sync`
- `[SUNSETTING] Gitignore sync artifacts`
- `[SUNSETTING] Enhanced AI-assisted conflict resolution`
- `[SUNSETTING] Fix AI conflict resolution to always run`
- `[SUNSETTING] Fix AI tool CLI invocations`
- `[SUNSETTING] Fix Claude Code to use stdin instead of temp file`
- `[SUNSETTING] Add automatic resolution for .bundle.hash conflicts`

### 2. Branding already ported

- `[SUNSETTING] Apply original Sunsetting AI branding`
- `[SUNSETTING] Replace OpenClaw lobster logo with actual Sunsetting sunset logo`
- `[SUNSETTING] Fix logo color to match brand accent`

### 3. Product porting still missing

No backend or workflow-specific Sunsetting product deltas are represented in `[SUNSETTING]` commits yet. That is a useful signal in itself: the fork is mostly carrying sync and branding work, not product functionality.

## Update path

Add one small writer step at the end of `scripts/sync-upstream.sh` after build verification:

1. collect git state
2. locate the latest conflict and build logs
3. derive readiness level from the rules above
4. write JSON
5. render Markdown summary from the same data

If sync exits early on failure, the failure path should still emit the readiness files before exiting.

## Markdown summary shape

The Markdown summary should stay short and operator-facing:

```md
# Sunsetting upstream readiness

Status: green | yellow | red
Recommended action: ...

## Sync

- Behind upstream: 0
- Ahead of upstream: 17
- Latest sync result: conflicts-auto-resolved
- Human review needed: no

## Build

- Build verified: yes
- Build log: .sync-conflicts/build-verify-20260421-033144.log

## Sunsetting deltas

- Fork maintenance: 7 commits
- Branding: 3 commits
- Product porting still missing: yes

## Next step

- Continue with bounded Tier 1 porting work, or repair sync health first.
```

## How framework runs should use this

### Execution selection

- read `.sunsetting/upstream-readiness.json` if present
- if `readiness == red`, do not start implementation
- if `yellow`, only choose tightly bounded Tier 1 work
- if `green`, continue normal Tier 1 selection

### Summary runs

- quote `readiness`
- quote `recommendedAction`
- mention whether Sunsetting-specific deltas are mostly branding, maintenance, or product work

## Implementation-ready follow-ons

1. Add a small Node script, for example `scripts/write-upstream-readiness.mjs`, that emits the JSON and Markdown files.
2. Call it from `scripts/sync-upstream.sh` on both success and failure paths.
3. Add one focused test that verifies readiness classification from captured sample inputs.
4. Teach framework execution and summary jobs to read the JSON snapshot first.

## Example snapshot for the current repo state

At the time of writing:

- `main` is rebased onto current `upstream/main`
- build verification passed during sync
- recent syncs show a recurring generated-file conflict on `src/canvas-host/a2ui/.bundle.hash` that auto-resolves cleanly
- the fork remains ahead because of Sunsetting-specific commits, but not behind upstream after refresh

That should classify as `green`, with a note that the recurring generated-file conflict is known and auto-resolved.

## Out of scope

- replacing the current sync workflow
- a hosted dashboard or UI panel before the file contract is stable
- automatic closure of every manual-review case
- modeling every historical fork delta beyond the current `[SUNSETTING]` commit inventory

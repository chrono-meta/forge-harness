---
name: harness-federation-sync
description: Propagates merged FH improvements to sibling environments (PMH, CC) with path mapping, ENV:FH-ONLY filtering, 3-axis guard per environment, and a human approval gate before any write.
user-invocable: true
allowed-tools: ["Read", "Write", "Bash", "Grep", "Glob", "Edit"]
model: sonnet
---

# harness-federation-sync — Cross-Harness Propagation Pipeline

> Closes the cross-harness evolution loop: improvements merged into FH automatically flow to PMH and CC,
> filtered by environment-specific rules and guarded by 3-axis verification before any commit lands.
> Human approval is always required before a PR is created in any target environment.

## Skill Chain — this skill's core value

harness-federation-sync does not implement verification logic itself.
It **chains existing FH skills** in the right order across environments:

```
[Wave 0] gh pr list                      ← discover what merged in FH
    │
    ▼
[Wave 1] federation_sync_map.md          ← map paths + filter ENV:FH-ONLY
    │
    ▼
[Wave 2] git worktree / patch apply      ← stage changes in target env
    │
    ▼
[Wave 3] ── Axis 1 → regression_guard.sh   (backward: did we break anything?)
         ── Axis 2 → /steel-quench         (adversarial: does this hold up?)
         ── Axis 3 → /source-grounding-audit (forward: are all refs real?)
    │
    ▼
[Wave 4] gh pr create --draft            ← human approval gate → PR
    │
    ▼
[Wave 5] /harvest-loop (lightweight)     ← record propagation as FH learning
```

Each wave calls a skill or tool that already exists. This skill's job is **orchestration + mapping** — it connects the pieces in the right order across environments. Adding a new verification axis means adding one line in Wave 3, not rewriting this skill.

## When to Run

- After one or more FH PRs are merged and you want to propagate improvements to PMH / CC
- Triggered by: "federation sync", "propagate to PMH", "sync to CC", "cross-harness propagation", "harness sync"
- Routine trigger: first session after a batch of FH PRs merge

---

## Prerequisites

Before running, confirm:

1. `templates/federation_sync_map.md` — environment registry `local_path` columns are set
2. Target repos are cloned at the specified local paths
3. `gh` CLI is authenticated for any target repo that will receive a PR

```bash
# Quick prerequisite check
cat templates/federation_sync_map.md | grep -A5 "Environment Registry"
ls ~/projects/pmh 2>/dev/null && echo "PMH: OK" || echo "PMH: NOT FOUND"
ls ~/projects/claude-chrono 2>/dev/null && echo "CC: OK" || echo "CC: NOT FOUND"
```

---

## Execution Steps

### Wave 0 — Sync Point Discovery

**0-a. Read mapping config**

```bash
cat templates/federation_sync_map.md
```

**0-b. Find last sync point**

```bash
# Look for the most recent federation-sync commit in FH
git log --oneline --grep="federation-sync:" --format="%H %ai %s" | head -5
# If none found, ask user: "Sync from which date / PR number?"
```

**0-c. List FH PRs since last sync**

```bash
gh pr list --state merged --limit 20 \
  --json number,title,mergedAt,files \
  --jq '.[] | "#\(.number) [\(.mergedAt[:10])] \(.title) — \(.files | length) files"'
```

Show PR list. Ask user: *"Which PRs to propagate? (e.g., 'all', '#14 #15 #16', 'since 2026-05-28')"*

---

### Wave 1 — File Analysis + Mapping

For each selected PR:

**1-a. Get changed files**

```bash
# For each selected PR number $PR_NUM:
gh pr view $PR_NUM --json files --jq '.files[].path'
```

**1-b. Apply mapping table**

For each file path:
1. Check exclusion list (paper/, CATALOG.md, README.md, CLAUDE.md, templates/local_fh_context.md, tracks/, .github/)
2. Check for `<!-- ENV:FH-ONLY -->` marker in file content
3. Look up `federation_sync_map.md` for FH → PMH / CC path mapping
4. Result: `{ fh_path, pmh_path, cc_path, skip_reason }`

**1-c. Build per-environment propagation plan**

```
PMH propagation plan:
  ✅ templates/regression_guard.sh → templates/regression_guard.sh
  ✅ plugins/fh-meta/skills/harness-doctor/SKILL.md → plugins/fh-meta/skills/harness-doctor/SKILL.md
  ⏭  CATALOG.md → SKIP (ENV:FH-ONLY)
  ⚠️  .claude/rules/session.md → needs manual review (CONFLICT: target modified 2026-05-27)

CC propagation plan:
  ✅ templates/regression_guard.sh → templates/regression_guard.sh
  ...
```

Present plan. Ask user: *"Proceed with this plan? (adjust/skip/confirm)"*

---

### Wave 2 — Patch Generation (per environment)

For each target environment the user confirmed:

**2-a. Generate patch from FH**

```bash
# Get the diff for each file from the selected PR
gh pr diff $PR_NUM -- $FH_PATH > /tmp/fh_patch_${PR_NUM}.diff
```

**2-b. Apply to target repo worktree**

```bash
# Create isolation branch in target repo
TARGET_BRANCH="federation-sync/fh-pr-${PR_NUM}-$(date +%Y%m%d)"
cd $TARGET_REPO_PATH
git checkout -b $TARGET_BRANCH

# Copy (not patch) for identical paths — avoids diff header path issues
cp $FH_ROOT/$FH_PATH $TARGET_REPO_PATH/$TARGET_PATH
```

**2-c. Stage changes**

```bash
cd $TARGET_REPO_PATH
git diff --stat HEAD
```

Show staged diff. If diff is empty → flag: *"No effective change in [env] — target already up to date."*

---

### Wave 3 — 3-Axis Guard (per environment)

Run all three axes on each target environment's staged changes before commit:

#### Axis 1 — Backward (Regression Guard)

```bash
cd $TARGET_REPO_PATH
bash {FH_ROOT}/templates/regression_guard.sh main $TARGET_BRANCH
# EXIT 0 = PASS / 1 = S-tier warnings / 2 = M-tier BLOCK
```

M-tier block → **stop propagation for this env**, report issue, ask user to resolve manually.

#### Axis 2 — Adversarial (Steel-Quench)

For SKILL.md changes: run `/steel-quench` on each changed SKILL.md in the target.
- Check: are new trigger phrases unique? Do new steps conflict with existing target skill steps?
- If target env has env-specific modifications to the same file, flag for merge review.

#### Axis 3 — Forward (Source Grounding)

For documentation / rules changes:
- Any file references (backtick paths, `{FH_ROOT}/...`) — verify they resolve in target repo
- Any external URLs cited — still reachable?

```bash
grep -oE '`[^`]+`' $TARGET_PATH | grep '/' | while read ref; do
  path=$(echo "$ref" | tr -d '`' | sed "s|{FH_ROOT}|$TARGET_REPO_PATH|g")
  [ -e "$path" ] || echo "BROKEN REF: $ref"
done
```

**3-Guard Summary table** (printed before Wave 4):

```
| Env | Axis 1 (backward) | Axis 2 (adversarial) | Axis 3 (forward) | Overall |
|-----|-------------------|----------------------|------------------|---------|
| PMH | ✅ PASS           | ✅ PASS              | ✅ PASS          | ✅ GO   |
| CC  | ⚠️ S-tier (1)     | ✅ PASS              | ✅ PASS          | ⚠️ WARN |
```

Any **M-tier block** on any axis → that environment is removed from Wave 4 until resolved.

---

### Wave 4 — PR Draft + Human Approval Gate

For each environment that passed Wave 3:

**4-a. Commit staged changes**

```bash
cd $TARGET_REPO_PATH
git add -A
git commit -m "federation-sync: propagate FH PR #${PR_NUM} — ${PR_TITLE}

Source: chrono-code/forge-harness#${PR_NUM}
Propagated by: harness-federation-sync
3-axis guard: PASS (backward/adversarial/forward)

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

**4-b. Show final diff summary**

```bash
git log --oneline main..$TARGET_BRANCH
git diff --stat main..$TARGET_BRANCH
```

**4-c. Human Approval Gate** ⛔ — REQUIRED before any push

Present:
```
Ready to create PR in [ENV]:
  Branch: federation-sync/fh-pr-14-20260528
  Files: 3 changed (+45/-12)
  3-axis guard: PASS
  PR title: "federation-sync: propagate FH PR #14 — README diet"

Proceed? [y / n / review-diff]
```

On `y`:

```bash
cd $TARGET_REPO_PATH
git push origin $TARGET_BRANCH
gh pr create \
  --title "federation-sync: propagate FH PR #${PR_NUM} — ${PR_TITLE}" \
  --body "## Propagated from forge-harness

Source PR: chrono-code/forge-harness#${PR_NUM}
Date: $(date +%Y-%m-%d)

### Changed files
$(git diff --name-only main..$TARGET_BRANCH | sed 's/^/- /')

### 3-axis guard
- Backward (regression): PASS
- Adversarial (steel-quench): PASS
- Forward (source-grounding): PASS

---
🤖 Generated with [Claude Code](https://claude.com/claude-code)" \
  --draft
```

On `n` → discard branch: `git checkout main && git branch -D $TARGET_BRANCH`

---

### Wave 5 — Sync Point Recording

After all approved PRs are created:

**5-a. Record propagation in FH**

```bash
# Tag the sync point in FH
git tag "federation-sync-$(date +%Y%m%d)" -m "Propagated PRs: #${PR_NUMS_LIST}"
```

**5-b. Update CATALOG.md** (brief entry)

```markdown
### YYYY-MM-DD | federation-sync | propagation, pmh, cc
**File:** tracks/_meta/federation_sync_YYYY-MM-DD.md
Propagated FH PRs #N~#M to PMH and CC. 3-axis guard PASS on all environments.
```

**5-c. Create propagation log**

Create `tracks/_meta/federation_sync_YYYY-MM-DD.md` with:
- PRs propagated
- Per-environment result (PR URL or skip reason)
- Any conflicts flagged for manual resolution

**5-d. Chain → harvest-loop (lightweight)**

The propagation itself is a harness event worth absorbing:

```
Trigger harvest-loop in lightweight mode:
  "federation-sync completed — propagated PR #N~#M to [PMH/CC]"
```

harvest-loop lightweight captures: what changed, which environments, any S-tier warnings → adds to the FH compounding loop so the next federation-sync benefits from this run's learnings.

---

## Done When

- [ ] All selected FH PRs analyzed through Wave 1 mapping
- [ ] Per-environment propagation plan confirmed by user
- [ ] Wave 3 3-axis guard run on every target environment
- [ ] No M-tier blockers remaining (or user explicitly accepted risk)
- [ ] Human approval gate passed for each environment PR
- [ ] Propagation log written to `tracks/_meta/federation_sync_YYYY-MM-DD.md`
- [ ] Sync point tag created in FH

---

## Trigger Phrases

- "federation sync"
- "propagate to PMH"
- "sync to CC"
- "cross-harness propagation"
- "harness sync"
- "push FH improvements to other harnesses"
- "PR가 머지됐으니 PMH에 반영"
- "CC에도 적용해줘"
- "harness-federation-sync 시작"

---

## Configuration

The mapping table lives at `templates/federation_sync_map.md`. Edit it to:

1. **Add a new environment**: Add a row to the Environment Registry table
2. **Add a new path mapping**: Add a row to the Path Mapping Table
3. **Exclude a file**: Add to the Exclusion Patterns list, or add `<!-- ENV:FH-ONLY -->` directly in the file

---

## Design Principles

### Why human approval gate is mandatory
cross-harness writes touch production harnesses. The gate ensures:
- Environment-specific context is preserved (PMH internal conventions, CC private changes)
- Merge conflicts are reviewed, not auto-resolved
- Rollback path is clear (draft PR = no immediate blast radius)

### Why 3-axis (not 1-axis)
Single regression guard catches backward breakage but misses:
- Adversarial: new trigger phrase collides with existing env-specific skill → silent override
- Forward: path reference valid in FH but broken in target env layout

### Additive-only
Deletion in FH (e.g., deprecated skill) does not auto-delete in target.
Reason: target may have extended the "deprecated" file with env-specific additions.
Deletions require explicit user confirmation per environment.

---

## Dependency Map

| Dependency | Used in | Required? |
|---|---|---|
| `templates/regression_guard.sh` | Wave 3 Axis 1 | Required |
| `steel-quench` | Wave 3 Axis 2 | Recommended |
| `source-grounding-audit` | Wave 3 Axis 3 | Recommended |
| `templates/federation_sync_map.md` | Wave 1 mapping | Required |
| `gh` CLI | Wave 0, Wave 4 | Required |

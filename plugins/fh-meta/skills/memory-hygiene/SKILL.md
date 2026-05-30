---
name: memory-hygiene
description: Detects "stale-but-confident" memory entries — facts that were once verified but have silently drifted. Scans memory/*.md for entries past their staleness threshold and proposes re-verification or archival. Runs automatically as part of harvest-loop Step 0-c and on explicit invocation.
user-invocable: true
allowed-tools: ["Read", "Grep", "Glob", "Edit", "Bash"]
model: sonnet
---

# memory-hygiene — Stale Memory Detection and Re-Verification

> Addresses the "stale-but-confident" failure mode: verified information that silently drifts
> while remaining highly ranked in retrieval — identified as a critical harness failure mode
> in *Scaling the Harness in Agentic AI* (arXiv:2605.26112).

FH is an online-first harness. Its memory entries point to live external resources (GitHub
repos, arXiv records, Zenodo DOIs, monitoring routines). These drift faster than in
offline systems — which makes hygiene both more necessary and more tractable (live
re-verification is possible).

## Trigger Conditions

### Natural Language Triggers

| Phrase | Intent |
|---|---|
| "memory check", "check stale memories" | Manual hygiene scan |
| "are my memories still accurate?" | Full re-verification pass |
| "clean up memory", "memory audit" | Propose archival candidates |
| "something in memory might be wrong" | Targeted re-check |

### Automatic Trigger

- **harvest-loop Step 0-c**: Runs automatically as the first step of every full harvest-loop
- **Cadence guard**: Skip if memory-hygiene ran within the last 7 days
  (`tracks/_meta/memory_hygiene_*.md` mtime check)

## Staleness Classification

| Type | Staleness Threshold | Re-verification Method |
|---|---|---|
| `project` — status/milestone entries | **14 days** | Re-read source file or live resource |
| `reference` — external URLs, DOIs, GitHub repos | **30 days** | WebFetch or gh CLI check |
| `feedback` — operating rules | **90 days** | Grep for contradicting evidence in recent sessions |
| `user` — user profile entries | **180 days** | Flag only, no auto-verification |

## Execution Steps

### Step 1 — Scan memory/*.md

```bash
ls ~/.claude/projects/*/memory/*.md 2>/dev/null
# or hub-local:
ls memory/*.md 2>/dev/null
```

For each file, extract:
- `metadata.type` from frontmatter
- `date:` or any date-like field in frontmatter or body
- Key factual claims (GitHub URLs, status strings, version numbers, dates)

### Step 2 — Classify by Staleness

Apply thresholds from the table above. Output a staleness roster:

```
STALE (>threshold):
  - feedback_fh_push_via_rest_api.md [feedback, 45d] — push procedure may have changed
  - arxiv-submission-status.md [project, 16d] — status fields need live check
  - claude-chrono-upstream.md [reference, 32d] — GitHub URL check needed

FRESH (<threshold):
  - user_role.md [user, 3d] — skip
  - fh-closed-loop-principle.md [feedback, 7d] — skip
```

### Step 3 — Re-verify Stale Entries

For each stale entry, run the appropriate re-verification:

**Reference type** (URLs, DOIs, GitHub):
- Use `gh api` for GitHub resources
- Use `WebFetch` for DOIs and arXiv records
- Mark `verified_at: YYYY-MM-DD` in frontmatter if still valid
- Flag `⚠ DRIFTED` if content has changed materially

**Project type** (status, milestones):
- Cross-check against `reference_next_session_starter.md` and recent git log
- Update or flag

**Feedback type** (rules):
- Grep `tracks/*/` for evidence contradicting the rule in last 30 days
- If 2+ contradictions found → flag for human review (do not auto-modify)

### Step 4 — Propose Actions (User Gate)

Present findings in this format:

```
memory-hygiene scan complete: N entries checked
  VERIFIED (no change needed): N
  UPDATED (refreshed verified_at): N
  ⚠ DRIFTED (content changed — needs human review): N
  📦 ARCHIVE CANDIDATE (no activity in Xd, superseded): N

Proposed changes:
  1. arxiv-submission-status.md — update status fields [auto-apply?]
  2. harness-federation-sync-plan.md — CLOSED flag still accurate? [confirm]
  ...

Apply updates? [y / N per item]
```

### Step 5 — Record Run

```bash
# Create hygiene log
echo "---\ndate: $(date +%Y-%m-%d)\nentries_checked: N\nupdated: N\ndrifted: N\n---" \
  > tracks/_meta/memory_hygiene_$(date +%Y-%m-%d).md
```

## Constraints

- **No auto-deletion**: Archive candidates are proposed, not deleted. Human confirmation required.
- **Feedback type**: Never auto-modify feedback rules — flag only.
- **Simplification guard**: If 0 stale entries found, output one line "memory-hygiene: all fresh" and exit.
- **FH online advantage**: Unlike offline harnesses, FH can re-verify external references live.
  Use this — don't skip external checks.

## Done When

```
Step 1~5 complete
+ Staleness roster output
+ Re-verification run for all STALE entries
+ User gate presented and responded to (y/N per item)
+ Hygiene log written to tracks/_meta/memory_hygiene_{date}.md
```

## References

- Theoretical basis: *Scaling the Harness in Agentic AI* (arXiv:2605.26112) §Memory Problems — "stale-but-confident" failure mode
- Integrates with: `harvest-loop` Step 0-c · `context-doctor` (context layer hygiene)
- Memory format: `~/.claude/projects/*/memory/MEMORY.md`

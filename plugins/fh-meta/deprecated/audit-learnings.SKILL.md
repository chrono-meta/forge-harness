---
name: audit-learnings
description: Automatically generates a weekly audit draft by finding recurring patterns in accumulated session records. Proposes promotion and deprecation candidates and guides through commit and PR creation. Use --dry-run flag to run only through scan and draft generation (no promotion/commit/PR gates; compatible with bg dispatch).
user-invocable: true
allowed-tools: ["Read", "Write", "Bash", "Grep", "Glob", "WebSearch", "WebFetch"]
model: sonnet
version: 0.7
---

# audit-learnings — Hub Weekly Audit Automation

Phase 2 core of `hub_compounding_loop.md`. Goal: reduce manual 10 minutes to automated 3 minutes. No code changes. Document creation, editing, and deletion only.

## Execution Order

### Step 0. Lock Session Goal (Claude Code v2.1.139+, recommended)

Lock the session goal before running so the audit is not derailed by other tasks.

```
/goal Complete weekly audit — pattern scan → promotion/deprecation candidates → PR
```

Run this then proceed to Step 1. Skip this step if `/goal` is not supported.

**Effect**: Prevents drift where improvements found during the audit are immediately applied. Finish the audit document first, then start fixes.

### Step 1. Run Scanner (self-detection + fallback)

Check for `_scanner.sh` first; if absent, extract directly via git commands.

```bash
SINCE="${ARGUMENTS:-7 days ago}"

if [ -f "tracks/_audit/_scanner.sh" ]; then
  # Hub environment: use dedicated scanner (9-section full output)
  bash tracks/_audit/_scanner.sh "$SINCE"
else
  # External user environment: direct git extraction (5-section fallback)
  echo "=== COMMITS ==="
  git log --since="$SINCE" --oneline --no-merges

  echo "=== TOP MODIFIED ==="
  git diff --stat "$(git log --since="$SINCE" --format='%H' | tail -1)" HEAD 2>/dev/null | sort -rn | head -20

  echo "=== NEW FILES ==="
  find . -name "*.md" -newer <(date -d "$SINCE" +%Y%m%d 2>/dev/null || date -v-7d +%Y%m%d) 2>/dev/null | grep -v ".git" | head -20

  echo "=== TAG COUNTS ==="
  git log --since="$SINCE" --format="%B" | grep -oE '#[a-z-]+:[a-zA-Z0-9_-]+' | sort | uniq -c | sort -rn

  echo "=== STALE FILES ==="
  find . -name "*.md" -not -newer <(date -d "180 days ago" +%Y%m%d 2>/dev/null || date -v-180d +%Y%m%d) 2>/dev/null | grep -v ".git" | head -20
fi
```

**Constraint**: Do not modify `_scanner.sh` output format if present. The skill reads only.

### Step 1.4. Lightweight Harness Structure Check (harness-doctor trigger judgment)

On each audit-learnings run, check CLAUDE.md complexity within 3 seconds. If threshold exceeded, recommend (do not auto-run) harness-doctor full diagnosis.

```bash
# CLAUDE.md line count + L1 .claudeignore presence
lines=$(wc -l < CLAUDE.md 2>/dev/null || echo 0)
ci=$([ -f .claudeignore ] && echo "OK" || echo "MISSING")
echo "CLAUDE.md: ${lines} lines / .claudeignore: ${ci}"
```

**Recommended trigger conditions** (output "harness-doctor full diagnosis recommended" if any apply):
- Single project: CLAUDE.md 160+ lines (80% of 200-line M-tier threshold)
- Meta-harness: CLAUDE.md 400+ lines (80% of 500-line M-tier threshold)
- `.claudeignore` MISSING

**Simplification guard**: If trigger not met, omit this step's output (normal = silent).

### Step 1.5. Load Prediction File in Advance (optional)

Glob `tracks/_audit/session_*_prediction.md` for most recent prediction file. If found and frontmatter `date` matches the cadence immediately before this audit, load it.

Skip this step if not found — do not force creation (`feedback_simplification_evidence`).

### Step 1.6. Prediction Arithmetic Consistency Check (only if Step 1.5 succeeded)

Auto-compare whether percentages, totals, and counts in the prediction file summary table match the detailed section sums. Deviation > 1pp = `⚠️ Prediction arithmetic error` flag (audit continues even if check fails — flag only).

### Step 1.7. CC Feature Signal Scan (optional · recommended monthly)

**Execution condition**: `/audit-learnings --cc-scan` or utterance containing "check CC features", "reflect new features", "agent features", "latest Claude Code". Skip if condition not met.

**Purpose**: Auto-scan latest Claude Code features (agents · slash commands · hooks · MCP etc.) → gap analysis against existing FH assets → propose upgrade candidates. FH self-detects upgrade signals without the user manually checking release notes.

#### 1. Collect CC feature change history

```
WebSearch: "Claude Code changelog new features <current year>" + "site:docs.anthropic.com"
WebFetch: official docs/changelog pages from search results
```

After collection, categorize new features:

| Category | Detection Signal Examples |
|---|---|
| CLI commands | New slash commands (`/goal`, `/fast` etc.) |
| Sub-agents / agents | `.claude/agents/` structure · multi-agent features |
| Hooks | New hook event types |
| MCP servers | New official MCP server support |
| IDE integration | VS Code / JetBrains new features |
| Config / environment | `settings.json` new fields, model switching options etc. |

#### 2. FH gap analysis

Cross-reference new features against existing FH assets:

```bash
# grep for feature keywords in CHEATSHEET.md · README.md · plugins/ SKILL.md
grep -r "<new feature keyword>" plugins/ CHEATSHEET.md README.md 2>/dev/null
```

- **grep hit**: already incorporated → skip
- **grep miss**: FH gap → register as upgrade candidate

#### 3. Output upgrade candidates

```
🔭 CC Feature Signal Scan Results (<date>)

Detected new features: N items
FH gaps (not incorporated): M items

┌──────────────────────────────────────────────────┐
│ [immediate] <feature name>                         │
│   Apply at: CHEATSHEET.md / <related SKILL.md>    │
│   Expected change: <1-2 lines>                     │
├──────────────────────────────────────────────────┤
│ [experiment] <feature name>                        │
│   FH application idea: <1-2 lines>                 │
│   Experiment proposal: register as fh_signal       │
└──────────────────────────────────────────────────┘

→ Apply now? [all / select number / skip]
```

On user approval → include CC feature gap section in Step 2 weekly_audit draft + add immediate items to Step 6 commit candidates.

**Simplification guard**: If new features are unrelated to FH or all already incorporated, omit this step output (silent = normal).

---

### Step 2. Generate weekly_audit Draft

Clone `tracks/_audit/_template_weekly.md` → new file `tracks/_audit/weekly_audit_YYYY-MM-DD.md`.

Map scanner output → template sections:
- §2 Activity summary ← COMMITS BY DAY · TOP MODIFIED · NEW FILES
- §3 Trigger tag tally ← TAG COUNTS
- §5 Deprecation candidates ← STALE FILES + archive-candidate file list
- §6 External asset axis mapping ← AXES COVERAGE
- §11-A subagent invocation log ← SUBAGENT INVOCATIONS
- §11-B self-reference audit ← SELF-REFERENCE AUDIT

§4 Recurring pattern judgment · §6.5 hub package 6-axis mapping · §8 promotion/deprecation decisions = filled in subsequent steps.

If prediction file loaded successfully, auto-fill §6.5-C deviation analysis.

### Step 3. Recurring Pattern Detection

Extract count per `#skill-candidate:SSS` · `#rule-candidate:RRR` tag from scanner TAG COUNTS. grep each tag in `patterns_decisions.md` — filter items already marked "response: approved" or "response: ignored".

Unprocessed patterns that have reached **3+ occurrences** are promotion candidates. Below 3 occurrences → record only as "pending (N occurrences)" in `weekly_audit §4`.

### Step 4. Prioritize Existing Match (D-3 3-stage fallback × D-4 3 scopes)

For each promotion candidate pattern, attempt to match existing assets:

**Scope priority (D-4)**:
1. `tracks/*/learnings/feedback_*.md` (most granular)
2. `knowledge/shared/{harness-core,patterns,dialogue}/*.md`
3. `CLAUDE.md` Rules section

**Matching stages (D-3 3-stage fallback)**:
- Step A: Pattern tag name exactly matches file frontmatter `tags:` array → match
- Step B (A fails): frontmatter `description:` contains pattern keyword → match
- Step C (B fails): pattern keyword mentioned 3+ times in body → match

All 3 stages fail = new creation candidate. When multiple matches, Priority 1 takes precedence.

### Step 5. Promotion Proposal Prompt (user gate required)

3-option choice per match result:

```
⚠ Recurring pattern detected
"#skill-candidate:{tag}" {N} times (dates: ...)
{if matched}: Propose extending existing `{file_path}` — description/body match
{if unmatched}: Propose creating new — candidate location `{path}`
[ y / N / ignore this pattern ]
```
`y` = proceed with extension/creation immediately. `N` = defer (re-ask next audit). `ignore` = record "response: ignored" in `patterns_decisions.md` → permanent filter.

### Step 6. Git Commit Preparation (user approval gate required)

When user selects `y` and skill extension/creation is confirmed, proceed as follows:

1.  **Stage new/modified files:** Stage created or extended skill files (and related changes) with `git add`.
2.  **Auto-generate commit message:** Based on skill content, change type (feat/docs/refactor etc.), and related pattern info. (Example: `feat(skill): Add new skill 'skill-name' from #skill-candidate:skill-tag`)

### Step 7. PR Creation Proposal (user approval gate required)

When commit preparation is complete, propose PR creation:

```
⚠ Git commit is ready for the new skill.
Would you like to create and submit a Pull Request? [y / N / create PR but keep local]
```

`y` = create and submit PR. `N` = keep commit local without PR. `create PR but keep local` = create PR branch but do not submit.

### Step 8. patterns_decisions.md append

Append all detections, proposals, and responses from this audit to `tracks/_audit/patterns_decisions.md` (D-5 dated header):

```markdown
## YYYY-MM-DD (run #{n} /audit-learnings)

- Pattern: "#skill-candidate:{tag}"
  Detection count: {N} (dates: ...)
  Match: {file_path or "none"}
  Proposal: {extension / new creation / defer}
  Response: {approved / ignored / deferred} ({timestamp})
  PR created: {y / N / create PR but keep local} ({timestamp})
```

Append-only. No deletion or modification.

### Step 9. Deprecation Candidate Proposal (user gate required)

Present scanner STALE FILES (>180 days) list + `#archive-candidate` files to user. 3-option choice:
- `archive` → `git mv` to `knowledge/shared/archive/` or `tracks/*/archive/` (prefix `_archived_`)
- `merge` → accept target file input then merge
- `keep` → re-present next audit (update period)

### Step 10. Self-Critique Section (D-7 recommended · omit if 0 items)

V-1 hub redefinition 6 perspectives — record only those applicable in `weekly_audit §9 Loop efficacy § improvement proposals`:

1. **Audit omission** — assets, periods, or tags missed by this audit
2. **Tagging omission** — cases of new sessions/learnings with no trigger tags
3. **Axis gap detection failure** — persistent 0-count axis distribution unnoticed
4. **Simplification check failure** — missed new asset addition vs. integration/deprecation ratio check
5. **Promotion judgment error** — promotion proposed below 3 occurrences / missed when threshold reached
6. **Loop over-engineering signs** — did this audit itself get longer, or did outputs duplicate?

Omit entire section if "this audit was perfect." No filler — follow simplification principle.

---

## Execution Modes

| Mode | Trigger | Behavior |
|---|---|---|
| **Normal mode** (default) | `/audit-learnings` | Scan → draft generation → complete with all promotion/commit/PR approval gates (interactive) |
| **Analysis mode** | `/audit-learnings --dry-run` | Steps 1~4 scan and draft generation only. Skip all Steps 5~9 gates. Compatible with bg dispatch |

> On `--dry-run`, output the following message after Step 4 pattern detection completes then **stop** (skip Steps 5~9):
> ```
> audit-learnings [dry-run] — Analysis complete (YYYY-MM-DD)
> ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
> weekly_audit draft: saved to tracks/_audit/weekly_audit_{date}.md
> Promotion candidates: {N} items (deferred without gate — re-run in normal mode to process)
> Deprecation candidates: {N} items (deferred without gate)
> ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
> ```

## User Approval Gates

| Stage | Normal mode | --dry-run |
|---|---|---|
| weekly_audit file save | **automatic** (editable after) | **automatic** (same) |
| Step 5 pattern promotion | **required** (await user response) | **skipped** |
| Step 6 git commit prep | **required** (await user response) | **skipped** |
| Step 7 PR creation proposal | **required** (await user response) | **skipped** |
| Step 9 deprecation proposal | **required** (await user response) | **skipped** |

## Trigger Utterances

Propose `/audit-learnings` when the following patterns are detected in conversation:

| Utterance Pattern | Example |
|---|---|
| **Weekly summary / retrospective intent** | "summarize what I did this week", "time for the weekly audit", "let's do a retrospective" |
| **Pattern promotion discussion** | "this looks like a skill candidate", "let's organize repeating patterns", "records are piling up" |
| **7+ days elapsed** | Auto-detected from `operations.md §L1` (`weekly_audit_*.md` mtime check) — auto-propose at session start |

Proposal format: `"Weekly audit time has come. Shall we run /audit-learnings?"`

## Constraints

- **Document changes and Git operations allowed**: file creation/editing/deletion for skill draft generation and Git commit/PR preparation, and Git commands (add, commit) are permitted.
- Do not modify `_scanner.sh` (hub developer environment only — if absent, Step 1 git fallback is used automatically)
- When creating/modifying the skill itself, update only this SKILL.md. Do not create supplementary files (`feedback_simplification_evidence`)
- ~~This skill is **hub cwd only**~~ → **v0.3+ applicable to general project cwd** (external user environment adaptation path / fallback auto-selected if hub-specific assets absent)

## External User Environment Adaptation Path (v0.3)

This skill = baseline for original developer hub cwd environment. External user (mode C install) environment adaptation path — following the meta-harness core principle *"beta + public release = obligation to have practical capability."*

### External User Environment Assumptions

External user environment = hub-specific assets absent:
- `tracks/_audit/_scanner.sh` absent
- `tracks/_audit/_template_weekly.md` absent
- `tracks/_audit/patterns_decisions.md` absent
- `tracks/*/learnings/feedback_*.md` · `knowledge/shared/*` · `CLAUDE.md` Rules section (replaced by user's own environment assets)

### Fallback Matrix (hub-specific assets → external environment replacements)

| Hub-specific asset | External environment fallback |
|---|---|
| `_scanner.sh` 9-section output (Step 1) | General `git log --since="7 days ago" --oneline` + `git diff --stat` + `find . -name "*.md" -mtime -7` direct extraction |
| `_template_weekly.md` clone (Step 2) | Immediately generate general markdown format (`## §1 Activity summary / §2 Trigger patterns / §3 Deprecation candidates / §4 Promotion candidates / §5 Simplification guard check`) |
| `patterns_decisions.md` append (Step 8) | User environment's existing `decisions.md` or `notes/decisions.md` / create new if absent |
| `tracks/*/learnings/feedback_*.md` matching (Step 4 D-4 priority 1) | User environment's own `learnings/` or `notes/` or `docs/` grep |
| `knowledge/shared/{harness-core,patterns,dialogue}/*.md` (Step 4 D-4 priority 2) | User environment's own `docs/` or `knowledge/` grep |
| `CLAUDE.md` Rules section (Step 4 D-4 priority 3) | User environment's own `CLAUDE.md` or `AGENTS.md` or `README` rules § grep |

### External User Usage Scenarios

1. **General git audit**: call `/audit-learnings` from user project cwd → fallback auto-selected → general git history audit + recurring pattern detection + promotion candidates proposed
2. **Own rules section matching**: grep user's own `CLAUDE.md` / `AGENTS.md` / `docs/rules/*.md` → D-3 3-stage fallback applied identically
3. **Simplification guard applied identically**: new asset addition vs. integration/deprecation ratio check (same baseline in external user environment)
4. **4 user approval gates applied identically**: pattern promotion / git commit prep / PR creation / deprecation·archive

### Documented Limitations

- `_scanner.sh` output advantage vs. general git log fallback (speed/accuracy difference) — external users can also write their own scanner (optional)
- Diversity of user environment asset naming (e.g., `notes/` vs `docs/` vs `learnings/`) — Step 4 D-4 priority user environment auto-detection path can be extended (v0.4+ follow-up)
- Hub developer environment baseline (Phase 2+ / scanner.sh 9-section output / patterns_decisions.md append-only) = primary path / external user environment = fallback path

## Phase Automation Stages

Current = **Phase 2+ / v0.5 CC feature signal scan added (2026-05-13)**. Semi-automated → partial automation, 4 user approval gates. Includes skill draft generation and git commit/PR creation proposals. Phase 3 entry condition = git fallback alone achieves scanner.sh equivalent quality. Phase 4 = Memento-Skills autonomous evolution (long-term).

## Scope Priority Note (dual-install environments)

Claude Code skill scope priority: **project > user > plugin**

This skill can be installed in 3 ways:

| Method | Path | Priority |
|---|---|:---:|
| Local project scope | `.claude/skills/audit-learnings/SKILL.md` | 1st (highest) |
| User scope | `~/.claude/skills/audit-learnings/SKILL.md` | 2nd |
| Plugin (hub install) | Inside `fh-meta` plugin | 3rd |

In hub environments, a hub-specific version may exist at `.claude/skills/audit-learnings/` — it takes precedence over the plugin version. Both versions can coexist without conflict (project scope is automatically prioritized).

If the plugin version and a local version exist simultaneously in an external user environment, the same principle applies. If a local version exists, the plugin version acts as fallback only.

## References

- Design basis: `tracks/_audit/session_2026_04_24_n3_phase2_kickstart.md` (D-1~D-8 pre-decisions)
- Loop protocol: `knowledge/shared/harness-core/hub_compounding_loop.md`
- 6-axis definition: `knowledge/shared/harness-core/harness_6axis_framework.md`
- **Frontier category**: this skill = manual variant of Memento-Skills (GAIA +13.7pp) / SAGE (+8.9% / -59% tokens) / MemSkill / AgeMem patterns. Phase 4 autonomous evolution stage is the frontier convergence point.

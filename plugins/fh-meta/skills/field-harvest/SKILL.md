---
name: field-harvest
description: Scans git history of field projects to detect patterns worth backporting to the meta-harness (Mode A), and logs session work to the knowledge hub when a session ends (Mode B). Triggers on "save this pattern", "make this reusable across projects", "can we automate this repetition?", "push this to FH", "reverse absorption", "harvest pattern", "session log", "log today's work", "sync to hub".
user-invocable: true
allowed-tools: ["Bash", "Read", "Edit", "Write", "WebFetch"]
model: sonnet
---

# field-harvest — Field Pattern Harvest → FH Backport + Session Logger

Dual-mode skill:
- **Mode A (Pattern Harvest)**: Scans recent commits in field projects to detect patterns worth backporting to FH. One-click flow from detection to PR creation.
- **Mode B (Session Log)**: Records session work from field projects to the knowledge hub when a session ends. Auto-generates a session markdown file with commits, learnings, and next steps.

## Mode Selection (Step 0-A)

Determine which mode to run based on user context:

| Condition | Mode | Priority |
|---|---|:---:|
| User message contains: "session log", "log today's work", "sync to hub", "sync session" | **Mode B (Session Log)** | 1 (highest) |
| **Session-end auto-trigger fires** (see below) and field commits exist today | **Mode B (Session Log)** — auto-proposed | 2 |
| Both Mode A and B applicable | Run Mode B first, then ask "Also run Mode A pattern harvest?" | 3 |
| Default or path specified | **Mode A (Pattern Harvest)** | 4 |

### Session-End Auto-Trigger (item1 — Mode B)

Mode B should not wait for an explicit "session log" phrase when a session is plainly ending with un-logged field work. **Auto-propose Mode B** (one line, never auto-run) when **all** hold:

1. A session-close signal is detected — the CLAUDE.md Session Wrap-up chain has begun, **or** the user says a closing phrase ("wrap up", "done", "good work", "end session", "that's it for today").
2. The current cwd is a **mapped field project** (not the FH hub itself — hub close is owned by harvest-loop / the Session Wrap-up chain).
3. `git log --since="today"` in that field project returns **1+ commits** by the session author that are **not yet logged** to the hub (cross-check via the detection-skip ledger, item2 below).

Proposal format (one line, then wait):
```
"Session is wrapping up and {project} has N un-logged commits today. Log them to the hub with Mode B? [y/n]"
```

**Collision guard (harvest-loop boundary)**: "wrap up" / "end session" in the **FH hub cwd** stay owned by the CLAUDE.md Session Wrap-up chain (which calls harvest-loop). This auto-trigger is **field-cwd only** and is a *proposal*, never an interception — if harvest-loop is already running for this session, do not also propose Mode B (harvest-loop calls field-harvest internally as Step H1). One proposal per session.

> **Note**: harvest-loop remains the owner of hub-side wrap-up. Mode B auto-trigger only covers the gap where a *field* session ends with un-logged commits and the user never typed an explicit session-log phrase.

**Execution order when both applicable**: Run git scan once, reuse results for both modes to avoid duplicate scans.

---

## Step 0. Field Project Path Detection

When no path is specified, auto-detect with 3-level priority:

```bash
# Priority 1: Read FH auto_project_mapping.md
cat .claude/rules/auto_project_mapping.md 2>/dev/null | grep -E "path:|project:" | head -10

# Priority 2: Auto-discover git repos in common development directories
find "$HOME/projects" "$HOME/dev" "$HOME/workspace" "$HOME/PycharmProjects" \
  -maxdepth 2 -name ".git" -type d 2>/dev/null \
  | sed 's|/.git||' \
  | grep -v "forge-harness\|harness_framework" \
  | head -10

# Priority 3: Scan parent directory of current cwd
find "$(dirname "$(pwd)")" -maxdepth 1 -name ".git" -type d 2>/dev/null \
  | sed 's|/.git||'
```

List discovered repos to user and ask to select target. If 0 repos found, prompt for direct path input.

## Step 1. Recent Commit Scan

```bash
cd "$FIELD_PATH"
git log --oneline --since="<N> days ago" --no-merges
```

If commit count is 0, report "no changes within last <N> days" and exit.

## Step 2. Harvest Candidate Classification

Classify each commit using the following criteria:

### FH Reverse Absorption Candidate Conditions (when one or more apply)

| Signal | Example | FH absorption type |
|---|---|---|
| **New workflow pattern** | New CLI tool, pipeline automation | Skill candidate / SKILL.md improvement |
| **Cross-project feedback** | "This approach can apply to other projects too" | `.claude/rules/` improvement |
| **Prompt engineering pattern** | Few-shot additions, new CRITICAL RULE | knowledge/shared pattern |
| **Error pattern solution** | Recurring error → converted to rule | Skill guard addition |
| **Tool integration method** | MCP integration, API usage patterns | Skill Step expansion |

### Field-only (No FH Reverse Absorption Needed)

- Domain-specific code (insurance logic, UXW prompt content itself)
- Project-specific config/environment files
- Bug fixes (one-off non-reproducible)
- Simple documentation updates

Classification method:

```bash
# Commit detail check
git show <hash> --stat
git show <hash> -- "*.md" "*.py" "*.sh" | head -100
```

First classify by commit message + changed file patterns → read diff for detail when needed.

## Step 3. Harvest Candidate List Presentation

```
field-harvest results — <project name> (within <N> days)

Scanned: <total commits>
FH absorption candidates: <N>

Candidate list:
┌─────────────────────────────────────────────────────┐
│ [1] <commit hash> "<commit message>"                 │
│     Type: <workflow pattern / feedback rule / ...>   │
│     Absorption location: plugins/fh-meta/skills/<X>/ │
│     Impact: ★★★ (applicable across projects)         │
├─────────────────────────────────────────────────────┤
│ [2] ...                                              │
└─────────────────────────────────────────────────────┘

Field-only (skipped): <M>

→ Absorb to FH via PR? [all / select number / skip]
```

If 0 candidates, report "no absorption candidates" and exit.

## Step 4. PR Creation (upon user approval)

```bash
cd "$FH_ROOT"
git checkout -b harvest/"$FIELD_PROJECT"-"$YYYYMMDD"

# Apply approved patterns
# - Update skill SKILL.md
# - Update .claude/rules/
# - Update templates/

git add -A
git commit -m "harvest($FIELD_PROJECT): $PATTERN_SUMMARY — $FIELD_COMMIT_HASH absorbed"
git push origin harvest/"$FIELD_PROJECT"-"$YYYYMMDD"

gh pr create \
  --title "harvest: $FIELD_PROJECT pattern absorption ($DATE)" \
  --body "..."
```

PR body includes:
- Original field commit hash + link
- Absorbed pattern summary
- Application location (which skill/rule)
- Expected cross-project impact

## Step 5. Done (Mode A Complete)

Report harvest candidate list and PR creation status to user.

---

## Invocation Triggers

### Auto-Proposal Conditions (detecting user conversation context)

Propose `/field-harvest` proactively when these patterns are detected:

| Pattern | Example | Proposal strength |
|---|---|---|
| **FH absorption intent** | "Should we push this to FH?", "Is this worth absorbing?", "harvest this pattern" | Immediate proposal |
| **Field pattern discovery** | "Found this pattern in my project", "There's something repeating on that side" | Immediate proposal |
| **FH improvement idea** | "What if we made this a skill?", "We could turn this into a rule" | Immediate proposal |
| **Field git log mention** | "Looking at the commits", "Checking recent changes", "What did I do this week?" | Proposal |

### Natural Language Triggers (activates without internal vocabulary)

| Example utterance | Intent |
|---|---|
| "This approach could be reused in other projects" | Cross-project pattern harvest |
| "Would be good to save what we found somewhere" | Pattern persistence → absorption |
| "If our team uses this, other teams probably can too" | FH sharing value detection |
| "This seems repetitive — can we automate it?" | Repeating pattern harvest candidate |
| "I forgot what we did last week and had to look it up again" | git log scan trigger |
| "session log", "log today's work", "sync to hub" | Mode B session log |

Proposal format:
```
"There seems to be a field pattern worth absorbing to FH. Scan with `/field-harvest`?"
```

### Simplification Guard

- If user has already invoked `/field-harvest`, no duplicate proposals
- If only 1 trigger pattern detected → light 1-line suggestion only (avoid over-intervention)
- If field cwd cannot be confirmed before proposing → first ask "which field project do you mean?"

---

## Simplification Guard (Global)

- **Domain code absorption forbidden**: Field domain logic is not an FH target — auto-skip when detected
- **Duplicate detection**: When a similar pattern already exists in FH, replace with "cross-reference existing assets then suggest merge"
- **Minimum validation criteria**: One-off patterns show as candidate + ★ 1 → recommend proper absorption after 3+ accumulations
- **PRD/sensitive data**: Diffs containing field PRD content or personal information are auto-masked and only the pattern is extracted

---

## External User Environment Adaptation

When project paths from the original developer environment are not present:

> The original developer's project paths are examples. In external environments, replace with your own project names/paths — Step 0 auto-discover handles detection automatically, no manual replacement needed.

- Step 0: Fallback to user-specified path
- Step 4: `GH_HOST` auto-detection (internal GHE vs github.com)
- FH ROOT: Auto-detect with `git rev-parse --show-toplevel`

---

# Mode B: Session Log → Knowledge Hub Sync

Records session work from field projects to the knowledge hub when a session ends. Generates a session markdown file from git history only (no conversation context), then commits to the hub.

## Step 0-B. Locate Hub Path

Auto-detect knowledge hub location (3-level priority):

```bash
# Priority 1: FH environment variables (set in ~/.zshrc)
echo "${FH_DIR:-${CC_HUB_DIR:-}}"

# Priority 2: Auto-discover hub candidates near home
find ~ -maxdepth 3 -name "tracks" -type d 2>/dev/null \
  | grep -E "(forge-harness|knowledge-hub)" | head -3

# Priority 3: Ask user
```

Determine track subdirectory:
- Field projects → `tracks/{project-name}/`
- External collaborations → `tracks/external/{name}/`

## Step 0-B.1. Detection-Skip — Already-Logged Pattern Filter (item2)

Before scanning session work, build a **skip ledger** of commits already recorded in the hub so the same commit is not logged twice across sessions (re-runs, overlapping auto-trigger + explicit invocation, multi-session same-day work).

**Skip rule**: a field commit hash is **skipped** (excluded from Step 1-B scan output) if it already appears in any existing session file under the project's track directory.

<!-- ⏳ SISTER-PENDING — bash detection-skip style not yet confirmed. The sister hub prefers a
     bash-implemented ledger check; awaiting their reply on the exact form (inline grep vs. a
     persisted ledger file like tracks/{project}/.logged_commits). The block below is the
     proposed inline-grep form — DO NOT finalize the bash style until the sister hub confirms.
     If a persisted-ledger style lands, replace this grep with a read of that ledger file. -->

Bind the three paths from earlier Mode B steps: `HUB_PATH` = the hub root from Step 0-B, `TRACK` = the track subdirectory chosen above, `FIELD_PATH` = the field project cwd from Step 0.

```bash
# Proposed (sister-pending) inline-grep form: collect hashes already present in hub session files,
# then filter today's field commits against them.
LOGGED=$(grep -rhoE '\b[0-9a-f]{7,40}\b' "$HUB_PATH/tracks/$TRACK/" 2>/dev/null | sort -u)

git -C "$FIELD_PATH" log --oneline --since="today" --no-merges \
  --author="$(git -C "$FIELD_PATH" config user.name)" \
| while read -r hash rest; do
    # skip if this hash is already logged in any hub session file
    echo "$LOGGED" | grep -q "^${hash}" && continue
    echo "$hash $rest"
  done
```

If **all** of today's commits are already logged, report `"All N commits today are already logged to the hub — nothing new to record"` and exit (Mode B done, no empty session file written). This is also what the item1 auto-trigger consults to count *un-logged* commits — the auto-trigger must not fire on a session whose commits are all already logged.

**Limitations (honest)**: hash-prefix matching can collide on very short prefixes (use 7+ chars) and only catches commits that were logged with their hash listed in the `## Commits` section (Step 3-B always lists hashes, so hub-generated logs are covered). It does not dedupe *uncommitted* work — that is intentional, uncommitted changes have no stable identity to skip on.

## Step 1-B. Scan Current Session Work

Use the **detection-skip-filtered** commit set from Step 0-B.1 (already-logged hashes removed), not the raw `git log`:

```bash
cd <field-project-path>
# raw scan — then pass through the Step 0-B.1 skip ledger before use
git log --oneline --since="today" --no-merges --author="$(git config user.name)"
git status --short  # uncommitted changes
```

## Step 2-B. Extract Session Summary

**From git log only** (no conversation context — prevents hallucination):

1. **Context**: Infer from first commit message
2. **Solution**: Aggregate commit messages
3. **Commits**: List with hashes
4. **Next Session**: Parse TODO/FIXME via `git grep`
5. **Key Learnings**: Ask user (optional, 1–2 lines)
6. **FH Backport Points**: Auto-detect from "pattern"/"reusable" keywords in commits

## Step 3-B. Generate Session Markdown

Template:

```markdown
# Session YYYY-MM-DD — <Slug>

## Context
<Initial problem inferred from first commit>

## Solution
<What was implemented — aggregated from commits>

## Commits
1. `<hash>` — <message>

## Next Session
<Parsed from TODO/FIXME, or user-supplied>

## Key Learnings
<Patterns discovered — user-supplied or inferred>

## FH Backport Points (Optional)
<If patterns worth meta-skill/rule promotion>

---
**Tags**: #<project> #<topic>
```

Filename: `session_YYYY_MM_DD_<slug>.md`

## Step 4-B. Write + Commit to Hub

```bash
cd <hub-path>
# Write session file
git add tracks/<track>/session_$(date +%Y_%m_%d)_<slug>.md
git commit -m "session: <title> (<project> <date>)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

> **Push policy**: commit only. Push requires explicit user approval ("push해줘", "push it"). Do not auto-push — consistent with FH PR principle.

## Step 5-B. Confirmation

```
✅ Session logged to knowledge hub
📝 tracks/<track>/session_YYYY_MM_DD_<slug>.md
🔀 Commit: <hash> — push? (y/n)
```

---

## Done When

**Mode A (Pattern Harvest)**:
```
All stages Step 0~4 complete
+ Step 3 harvest candidate list output (N candidates + M field-only)
+ Upon user approval, Step 4 PR creation complete (gh pr create executed)
+ When 0 candidates, "no absorption candidates" reported then exit
```

**Mode B (Session Log)**:
```
All Steps 0-B ~ 5-B executed
+ Step 0-B.1 detection-skip ledger applied (already-logged commits filtered)
+ Session markdown file generated from git log  (or "all commits already logged" exit)
+ Hub commit created (no auto-push)
+ Confirmation output with push offer
```

Verdict: PASS (harvest candidates output and PR created, or 0 candidates confirmed) | CONDITIONAL_PASS (candidates found but PR pending user approval; or Mode B commit created, push pending) | FAIL (contention-layer blocked candidate registration; or hub path not found) | ESCALATE (role collision with existing skill requires human decision)

**→ Mandatory next: `contention-layer`** — run immediately after Step 3 candidate list is confirmed, before Step 4 PR creation. New patterns must be checked for collision with existing skill role clusters before registration. Skip only when 0 candidates found.

## Linked Skills

| Situation | Linked skill |
|---|---|
| Auto-pipeline on session wrap | `harvest-loop` — calls field-harvest internally as Step H1 |
| devil attack/innovator synthesis on harvest candidates | `harvest-loop` Steps H3~H3.5 |
| Need PR directly after standalone pattern extraction | This skill Step 4 direct execution |
| Session log to hub | This skill Mode B (standalone) |

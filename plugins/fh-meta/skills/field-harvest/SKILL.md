---
name: field-harvest
description: Scans field project git history to find patterns worth promoting to the meta-harness and proposes a PR. Triggered by "save this pattern", "make this reusable across projects", "can we automate this repetition?", "push this to FH", "reverse absorption", or "harvest pattern".
user-invocable: true
allowed-tools: ["Bash", "Read", "WebFetch"]
model: sonnet
---

# field-harvest — Field Pattern Harvest → FH Reverse Absorption Proposal

Scans recent commits from field projects for patterns worth absorbing back into FH. One-click completion through to PR creation upon user approval.

## Triggers

```
/field-harvest                          # scan all mapped field projects
/field-harvest <path>                   # specify a particular field project
/field-harvest --since <N>d             # commits within N days (default 7)
/field-harvest --watch <path>           # periodic monitoring mode (default 24h interval)
/field-harvest --watch --interval <h>   # change monitoring interval
/field-harvest --once                   # check current state and exit (no monitoring)
```

## Step 0. Field Project Path Detection

When no path is specified, auto-detect with 3-level priority:

```bash
# Priority 1: Read FH auto_project_mapping.md
cat .claude/rules/auto_project_mapping.md 2>/dev/null | grep -E "path:|project:" | head -10

# Priority 2: Auto-discover git repos in common development directories
find "$HOME/projects" "$HOME/dev" "$HOME/workspace" \
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
│     Type: <workflow pattern / feedback rule / prompt pattern>   │
│     Absorption location: plugins/fh-meta/skills/<X>/   │
│     Impact: ★★★ (applicable across projects)         │
├─────────────────────────────────────────────────────┤
│ [2] ...                                              │
└─────────────────────────────────────────────────────┘

Field-only (skipped): <M>

→ Absorb to FH via PR? [all / select number / skip]
```

If 0 candidates, report "no absorption candidates — schedule next monitoring" and exit.

## Step 4. PR Creation (upon user approval)

```bash
cd "$FH_ROOT"
git checkout -b harvest/"$FIELD_PROJECT"-"$YYYYMMDD"

# Apply approved patterns
# - Update skill SKILL.md
# - Update .claude/rules/
# - Update templates/

git add -A   # stage approved pattern files
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

## Step 5. Monitoring Mode (--watch)

When `--watch` flag is used, background periodic monitoring:

```
Monitoring: field-harvest active
   Targets: <project list>
   Interval: <N> hours
   Next scan: <time>
   Will notify immediately when candidate detected.
```

Utilizes ScheduleWakeup — only works while Claude Code session is active.
Stops automatically when session ends (re-invoke `--watch` on restart).

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

Can also be activated by users unfamiliar with internal terminology:

| Example utterance | Intent |
|---|---|
| "This approach could be reused in other projects" | Cross-project pattern harvest |
| "Would be good to save what we found somewhere" | Pattern persistence → absorption |
| "If our team uses this, other teams probably can too" | FH sharing value detection |
| "This seems repetitive — can we automate it?" | Repeating pattern harvest candidate |
| "I forgot what we did last week and had to look it up again" | git log scan trigger |
| "Save this so it can be reused somewhere else later" | Pattern persistence → absorption |
| "Record the approach that worked well this time" | Pattern persistence |
| "I want to share what we found here" | FH sharing value detection |
| "Keep this pattern so we can use it next time too" | Pattern persistence → absorption |
| "Organize this so I can remember it later" | Pattern persistence |

Proposal format:
```
"There seems to be a field pattern worth absorbing to FH. Scan with `/field-harvest`?"
```

### Simplification Guard

- If user has already invoked `/field-harvest`, no duplicate proposals
- If only 1 trigger pattern detected → light 1-line suggestion only (avoid over-intervention)
- If field cwd cannot be confirmed before proposing → first ask "which field project do you mean?"

## Simplification Guard

- **Domain code absorption forbidden**: Field domain logic (insurance, UXW content) is not an FH target — auto-skip when detected
- **Duplicate detection**: When a similar pattern already exists in FH, replace with "cross-reference existing assets then suggest merge"
- **Minimum validation criteria**: One-off patterns show as candidate + ★ 1 → recommend proper absorption after 3+ accumulations
- **PRD/sensitive data**: Diffs containing field PRD content or personal information are auto-masked and only the pattern is extracted

## External User Environment Adaptation

When project paths from the original developer environment are not present:

> The original developer's project paths are examples. In external environments, replace with your own project names/paths — Step 0 auto-discover handles detection automatically, no manual replacement needed.

- Step 0: Fallback to user-specified path (`/field-harvest <path>`)
- Step 4: `GH_HOST` auto-detection (internal GHE vs github.com)
- FH ROOT: Auto-detect with `git rev-parse --show-toplevel`

## Usage Examples

```
/field-harvest                          # full field 7-day scan
/field-harvest ~/projects/my-project    # specific project 14-day scan + PR proposal
/field-harvest --watch --interval 12    # auto-monitor every 12 hours
/field-harvest --once                   # check current state only
```

## Done When

```
All stages Step 0~4 complete
+ Step 3 harvest candidate list output (N candidates + M field-only)
+ Upon user approval, Step 4 PR creation complete (gh pr create executed)
+ When 0 candidates, "no absorption candidates" reported then exit
```

Verdict: PASS (harvest candidates output and PR created, or 0 candidates confirmed) | CONDITIONAL_PASS (candidates found, PR pending user approval) | FAIL (contention-layer blocked candidate registration) | ESCALATE (role collision with existing skill requires human decision)

**→ Mandatory next: `contention-layer`** — run immediately after Step 3 candidate list is confirmed, before Step 4 PR creation. New patterns must be checked for collision with existing skill role clusters before registration. Skip only when 0 candidates found.

## Linked Skills

| Situation | Linked skill |
|---|---|
| Auto-pipeline on session wrap | `harvest-loop` — calls field-harvest internally as Step H1 |
| devil attack/innovator synthesis on harvest candidates | `harvest-loop` Steps H3~H3.5 |
| Need PR directly after standalone pattern extraction | This skill Step 4 direct execution |

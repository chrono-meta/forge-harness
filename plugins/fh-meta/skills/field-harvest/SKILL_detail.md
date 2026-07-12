---
name: field-harvest-detail
description: Detail reference for field-harvest — Mode A detection/PR bash and candidate list format, Mode B hub-locate/skip-ledger/session-template blocks. Load when executing a specific step.
load: on-demand
---

# field-harvest — Detail Reference

> Load when executing a specific step. SKILL.md contains mode selection, the session-end auto-trigger conditions, classification criteria, trigger tables, guards, the UAP pass, and Done When.

---

## §ModeA-Blocks

### Step 0 — Field project path detection (3-level priority)

```bash
# Priority 1: Read FH auto_project_mapping.md
cat knowledge/shared/rules/auto_project_mapping.md 2>/dev/null | grep -E "path:|project:" | head -10

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

### Step 1 — Recent commit scan

```bash
cd "$FIELD_PATH"
git log --oneline --since="<N> days ago" --no-merges
```

### Step 2 — Classification commands

```bash
# Commit detail check
git show <hash> --stat
git show <hash> -- "*.md" "*.py" "*.sh" | head -100
```

First classify by commit message + changed file patterns → read diff for detail when needed.

### Step 3 — Candidate list presentation format

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

### Step 4 — PR creation bash

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

PR body includes: original field commit hash + link, absorbed pattern summary, application location (which skill/rule), expected cross-project impact.

---

## §ModeB-Blocks

### Step 0-B — Locate hub path (3-level priority)

```bash
# Priority 1: FH environment variables (set in ~/.zshrc)
echo "${FH_DIR:-${CC_HUB_DIR:-}}"

# Priority 2: Auto-discover hub candidates near home
find ~ -maxdepth 3 -name "tracks" -type d 2>/dev/null \
  | grep -E "(forge-harness|knowledge-hub)" | head -3

# Priority 3: Ask user
```

Track subdirectory: field projects → `tracks/{project-name}/` · external collaborations → `tracks/external/{name}/`

### Step 0-B.1 — Detection-skip inline-grep

Bind the three paths from earlier Mode B steps: `HUB_PATH` = the hub root from Step 0-B, `TRACK` = the track subdirectory chosen above, `FIELD_PATH` = the field project cwd from Step 0.

```bash
# Stateless inline-grep: collect hashes already present in hub session files,
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

### Step 1-B — Session work scan

```bash
cd <field-project-path>
# raw scan — then pass through the Step 0-B.1 skip ledger before use
git log --oneline --since="today" --no-merges --author="$(git config user.name)"
git status --short  # uncommitted changes
```

### Step 3-B — Session markdown template

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

### Step 4-B — Hub commit bash

```bash
cd <hub-path>
# Write session file
git add tracks/<track>/session_$(date +%Y_%m_%d)_<slug>.md
git commit -m "session: <title> (<project> <date>)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

### Step 5-B — Confirmation format

```
✅ Session logged to knowledge hub
📝 tracks/<track>/session_YYYY_MM_DD_<slug>.md
🔀 Commit: <hash> — push? (y/n)
```

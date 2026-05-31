---
name: harness-doctor
description: Scans a project's harness structure (.claude/ directory, CLAUDE.md, rules, agents) to diagnose complexity, drift, missing files, and broken references, then suggests improvements. Triggered by "harness check", "structure diagnosis", "CLAUDE.md audit".
user-invocable: true
allowed-tools: ["Read", "Bash", "Glob", "Grep"]
model: sonnet
complexity_routing:
  base: sonnet
  high: opus
  escalate_when:
    - cold_start
    - cross_project
---

# harness-doctor — Harness Structure Diagnosis + Prescription

"A good harness gets simpler over time. If it's getting more complex, something is wrong."

Diagnoses harness structural health across 3 layers and proposes M/S/R prescriptions:

1. **L1 Structural completeness** — required file existence (CLAUDE.md · .claudeignore · .claude/)
2. **L2 Complexity** — current state vs. simplification principle (line count · unused files · duplicate definitions)
3. **L3 Drift** — rule vs. actual pattern mismatch (broken references · stale files · conflicting rules)
4. **L4 Connection diagnosis** *(FH environment only)* — meta hub ↔ field project reference consistency
5. **L5 Pattern analysis** *(FH environment only)* — skill activity · call context appropriateness · effect metric measurement

---

## Execution Steps

### Step 1. Confirm Diagnostic Target

```bash
# Check current cwd harness file structure
ls -la .claude/ 2>/dev/null || echo "NO .claude DIR"
ls -la CLAUDE.md .claudeignore 2>/dev/null
ls .claude/rules/ 2>/dev/null
ls .claude/agents/ 2>/dev/null
```

Determine if FH environment:
```bash
# tracks/ present = FH or hub environment
ls -d tracks/ knowledge/ plugins/ 2>/dev/null
```

---

### Step 2. L1 — Structural Completeness Diagnosis

Check required file existence:

| File | When Missing |
|---|---|
| `CLAUDE.md` | **M-tier** — harness entry impossible |
| `.claudeignore` | S-tier — context-doctor execution recommended |
| `.claude/` directory | M-tier (when rule files exist) |

```bash
# Check all file existence at once
for f in CLAUDE.md .claudeignore; do
  [ -f "$f" ] && echo "OK: $f" || echo "MISSING: $f"
done
[ -d ".claude" ] && echo "OK: .claude/" || echo "MISSING: .claude/"
```

---

### Step 3. L2 — Complexity Diagnosis

#### 3-1. CLAUDE.md Line Count Measurement

```bash
wc -l CLAUDE.md 2>/dev/null
```

Criteria:

| Line Count | Verdict |
|---|---|
| ~100 lines | Normal |
| 100~200 lines | S-tier warning |
| 200+ lines | M-tier — separation or reduction needed |

> Meta-harness (FH) itself is subject to meta-layer spec — do not apply single-project criteria directly.
> On FH cwd detection, apply 500-line threshold instead of 200-line.

#### 3-2. Rules File Count and Unreferenced Detection

```bash
# .claude/rules/ file list
ls .claude/rules/*.md 2>/dev/null

# Check if each rules file is referenced in CLAUDE.md
# find handles empty-glob portably across bash and zsh (zsh nomatch + bash literal-glob)
find .claude/rules -maxdepth 1 -name '*.md' 2>/dev/null | while read -r f; do
  fname=$(basename "$f")
  grep -l "$fname" CLAUDE.md 2>/dev/null \
    && echo "REFERENCED: $fname" \
    || echo "UNREFERENCED: $fname"
done
```

Unreferenced rules files → R-tier (candidate for unused asset cleanup).

#### 3-3. Duplicate Definition Detection

```bash
# Quick check for duplicate section keyword in CLAUDE.md
grep -c "^##" CLAUDE.md 2>/dev/null
# 15+ sections = S-tier warning
```

#### 3-4. Periodic Skill Activity Check *(when tracks/_audit/ exists)*

> Verify that periodic skills (harvest-loop · sim-conductor) are actually running. Prevents "assumed to be running" drift.

```bash
# Check date of last weekly_audit file
latest_audit=$(ls -1t tracks/_audit/weekly_audit_*.md 2>/dev/null | head -1)
if [ -z "$latest_audit" ]; then
  echo "MISSING: no weekly_audit files"
else
  # Calculate days elapsed since last modification
  days_ago=$(( ( $(date +%s) - $(stat -f %m "$latest_audit" 2>/dev/null || stat -c %Y "$latest_audit") ) / 86400 ))
  echo "LAST_AUDIT: $latest_audit (${days_ago} days ago)"
  [ "$days_ago" -gt 30 ] && echo "OVERDUE_M: 30+ days without running" \
    || { [ "$days_ago" -gt 14 ] && echo "OVERDUE_S: 14+ days without running" || echo "OK: cycle normal"; }
fi
```

```bash
# Check last sim-conductor result file
latest_sim=$(ls -1t tracks/_meta/sim_*.md 2>/dev/null | head -1)
[ -n "$latest_sim" ] && echo "LAST_SIM: $latest_sim" || echo "INFO: no sim record (optional)"
```

| Days Elapsed | Verdict |
|---|---|
| ~14 days | Normal |
| 14~30 days | S-tier warning — audit re-run recommended |
| 30+ days | M-tier — weekly loop interruption possible |

---

### Step 4. L3 — Drift Diagnosis

#### 4-1. Broken File References

Validate local file links in CLAUDE.md (including `./`, `../`):

```bash
# Extract actual file path references in CLAUDE.md
# Exclude: glob(*) · space-containing (slash command args/code examples) · single-word slash commands (/model, etc.)
grep -oE '`[./][^`]+`' CLAUDE.md 2>/dev/null | tr -d '`' \
  | grep -vE '\*|[[:space:]]|^/[^/]+$' \
  | sort -u | while read p; do
      [ -e "$p" ] && echo "OK: $p" || echo "BROKEN: $p"
    done
```

Broken references → M-tier.

#### 4-2. Stale Rules Detection

```bash
# .claude/rules files not modified in 90+ days
find .claude/rules/ -name "*.md" -mtime +90 2>/dev/null \
  && echo "STALE: 90+ day unmodified rules files exist" \
  || echo "OK: no stale"
```

Stale rules → R-tier (review then archive recommended).

#### 4-3. settings.json Validity

```bash
# Verify JSON syntax if .claude/settings.json exists
[ -f ".claude/settings.json" ] \
  && python3 -c "import json,sys; json.load(open('.claude/settings.json'))" 2>/dev/null \
  && echo "OK: settings.json valid" \
  || echo "BROKEN: settings.json syntax error"
```

#### 4-4. Hook Divergence Diagnosis — Detecting hooks that don't fire in Agent View environment

> **Background**: Claude Code hooks (hooks array in settings.json) only fire in standard terminal sessions. In Agent View (`claude agents`) environments, hooks like PostToolUse and Stop do not execute (confirmed 2026).

```bash
# Check for hooks configuration in settings.json
if [ -f ".claude/settings.json" ]; then
  hook_count=$(python3 -c "
import json, sys
try:
    d = json.load(open('.claude/settings.json'))
    hooks = d.get('hooks', [])
    print(len(hooks))
except:
    print(0)
" 2>/dev/null || echo 0)
  if [ "$hook_count" -gt 0 ]; then
    echo "HOOKS_FOUND: ${hook_count} hooks detected in settings.json"
    python3 -c "
import json
d = json.load(open('.claude/settings.json'))
for h in d.get('hooks', []):
    event = h.get('event', 'unknown')
    cmds = [c.get('command','') for m in h.get('matchers',[{}]) for c in m.get('hooks',[])]
    print(f'  HOOK: event={event} | commands={cmds[:2]}')
" 2>/dev/null
    echo "AGENT_VIEW_WARN: above hooks do NOT fire in Agent View (claude agents)"
    echo "  Prescription: for Agent View-only tasks, replace hook-dependent behavior with explicit skills"
  else
    echo "OK: no hooks configured (no divergence risk)"
  fi
else
  echo "INFO: no settings.json — hook divergence diagnosis skip"
fi
```

Hook divergence verdict:

| State | Verdict | Prescription |
|---|---|---|
| 0 hooks | Normal | — |
| 1+ hooks (including session-end/Stop events) | **S-tier** — those hooks don't fire in Agent View | Replace with explicit skill or document standard terminal confirmation procedure |
| 1+ hooks (including PostToolUse file writes or external API calls) | **M-tier** — data loss risk in Agent View sessions | Move hook behavior to explicit steps in agent brief |

---

### Step 5. L4 — Connection Diagnosis *(FH environment only)*

FH environment detection criteria: all three directories `tracks/` + `knowledge/` + `plugins/` exist.

#### 5-1. Field Project Tracks Freshness

```bash
# Check last modification date for each tracks/{project}/ directory
for d in tracks/*/; do
  last=$(find "$d" -name "*.md" -newer "tracks/.gitkeep" 2>/dev/null | wc -l)
  echo "$d: $last files modified recently"
done
```

Tracks with no sync in 30+ days → R-tier (possible session-end sync missing).

#### 5-2. CATALOG.md Open Item Count

```bash
# Count only recent 5 sessions (by ### header) — do not raw count entire history
awk '/^### /{count++} count<=5{print}' CATALOG.md 2>/dev/null | grep -c "^- Open:" || echo "0"
```

5+ open items → S-tier (backlog drift accumulating).

> **Note**: Do not simply use `grep -c "^- Open:" CATALOG.md` — returns hundreds as false positives counting entire history.

#### 5-3. Field Project CLAUDE.md Existence Check

If `reference_field_projects.md` exists, check CLAUDE.md existence for field project paths:

```bash
# Extract field paths from memory (if exists)
grep -oE '`~/[^`]+`' .claude/memory/reference_field_projects.md 2>/dev/null \
  | tr -d '`' | sed "s|~|$HOME|g" | while read p; do
    [ -f "$p/CLAUDE.md" ] && echo "OK: $p" || echo "MISSING CLAUDE.md: $p"
  done
```

Missing field CLAUDE.md → S-tier (hub wiring incomplete).

---

### Step 6. L5 — Pattern Analysis Layer *(FH environment only)*

FH environment detection criteria: `tracks/` + `plugins/` directories both exist. Skip entirely for plugin-only (mode C) environments.

#### 6-1. L5-A: Skill Activity Check

> **Purpose**: "Are installed skills actually being called?" — grep-based on session records. Resolves G1 (activity gap).

```bash
# Check if session files exist first
recent_sessions=$(find tracks/ -name "session_*.md" -mtime -30 2>/dev/null)
if [ -z "$recent_sessions" ]; then
  echo "L5-A SKIP: no session records — re-diagnose after 30 days"
else
  # Collect installed skill list
  installed_skills=$(ls plugins/fh-meta/skills/ 2>/dev/null)

  for skill in $installed_skills; do
    count=0
    for f in $recent_sessions; do
      grep -li "$skill\|/$skill" "$f" 2>/dev/null && ((count++)) || true
    done
    if [ "$count" -eq 0 ]; then
      # Check if any trace within 90 days
      sessions_90d=$(find tracks/ -name "session_*.md" -mtime -90 2>/dev/null)
      count_90d=0
      for f in $sessions_90d; do
        grep -li "$skill\|/$skill" "$f" 2>/dev/null && ((count_90d++)) || true
      done
      if [ "$count_90d" -eq 0 ]; then
        echo "INACTIVE_90D: $skill (no call record in 90 days — Deprecation Gate entry recommended)"
      else
        echo "INACTIVE_30D: $skill (no call record in last 30 days — review for deprecation or consolidation)"
      fi
    elif [ "$count" -lt 2 ]; then
      echo "LOW_ACTIVE: $skill (${count} times — low activity)"
    else
      echo "ACTIVE: $skill (${count} times)"
    fi
  done
fi
```

Verdict criteria:

| State | Criteria | Prescription Tier |
|---|---|---|
| `ACTIVE` | 2+ times in 30 days | Normal |
| `LOW_ACTIVE` | 1 time in 30 days | R-tier — review activation methods |
| `INACTIVE_30D` | 0 times in 30 days | S-tier — review for deprecation or consolidation |
| `INACTIVE_90D` | 0 times in 90 days | M-tier — Deprecation Gate entry recommended |

---

#### 6-2. L5-B: Call Context Appropriateness Check

> **Purpose**: "Was the skill called in situations that match SKILL.md intent?" — hardcoded known misuse patterns. Resolves G2 (context appropriateness gap).

```bash
# Detect misuse patterns (based on last 30 days sessions)
recent_sessions=$(find tracks/ -name "session_*.md" -mtime -30 2>/dev/null)
[ -z "$recent_sessions" ] && echo "L5-B SKIP: no session records" && return 0 || true

# hub-persona-auditor misuse: code PR or internal refactoring context
for f in $recent_sessions; do
  if grep -q "hub-persona-auditor" "$f" 2>/dev/null; then
    context=$(grep -n "hub-persona-auditor" "$f" | head -3)
    echo "$context" | while IFS=: read linenum rest; do
      snippet=$(sed -n "$((linenum-3)),$((linenum+3))p" "$f" 2>/dev/null)
      if echo "$snippet" | grep -qiE "code review|PR review|refactoring"; then
        echo "L5-B MISUSE (suspected): hub-persona-auditor @ $f:$linenum — code PR/refactoring context detected (false positive possible)"
      fi
    done
  fi
done

# sim-conductor misuse: first run without onboarding context
for f in $recent_sessions; do
  if grep -q "sim-conductor" "$f" 2>/dev/null; then
    context=$(grep -n "sim-conductor" "$f" | head -3)
    echo "$context" | while IFS=: read linenum rest; do
      snippet=$(sed -n "$((linenum-3)),$((linenum+3))p" "$f" 2>/dev/null)
      if echo "$snippet" | grep -qiE "first time|how do I|not sure how"; then
        echo "L5-B MISUSE (suspected): sim-conductor @ $f:$linenum — first run / no onboarding context detected (false positive possible)"
      fi
    done
  fi
done

# harness-doctor self-loop misuse: re-invocation within harness-doctor
for f in $recent_sessions; do
  count=$(grep -c "harness-doctor" "$f" 2>/dev/null || echo 0)
  if [ "$count" -gt 2 ]; then
    echo "L5-B MISUSE (suspected): harness-doctor @ $f — self-loop suspected (${count} mentions in same session)"
  fi
done
```

> **Limit**: Keyword grep — bash level only, no LLM call. Report only as "suspected pattern (false positive possible)".

Misuse detected → add S-tier.

---

#### 6-3. L5-C: Effect Metric Measurement (E1, E3, E5)

> **Purpose**: "Did actual change happen after skill execution?" — git-based before/after measurement. Resolves G3 (effect gap).

```bash
# E1: CLAUDE.md line count change (git show based)
current_lines=$(wc -l < CLAUDE.md 2>/dev/null || echo 0)
past_lines=$(git show "HEAD@{30 days ago}:CLAUDE.md" 2>/dev/null | wc -l || echo "N/A")
if [ "$past_lines" != "N/A" ] && [ "$past_lines" -gt 0 ]; then
  delta=$((current_lines - past_lines))
  if [ "$delta" -lt 0 ]; then
    echo "E1_OK: CLAUDE.md ${delta} lines reduced (simplification in progress)"
  elif [ "$delta" -gt 50 ]; then
    echo "E1_WARN: CLAUDE.md +${delta} lines increased (complexity rising — connect to L2 complexity diagnosis)"
  else
    echo "E1_STABLE: CLAUDE.md ±${delta} lines (stable)"
  fi
else
  echo "E1_SKIP: git history less than 30 days or no CLAUDE.md"
fi

# E3: CATALOG.md Open item consumption rate
current_open=$(awk '/^### /{count++} count<=5{print}' CATALOG.md 2>/dev/null | grep -c "^- Open:" || echo 0)
past_open=$(git show "HEAD@{30 days ago}:CATALOG.md" 2>/dev/null \
  | awk '/^### /{count++} count<=5{print}' | grep -c "^- Open:" || echo "N/A")
if [ "$past_open" != "N/A" ]; then
  consumed=$((past_open - current_open))
  echo "E3: Open items consumed ${consumed} (30 days ago: ${past_open} → now: ${current_open})"
else
  echo "E3_SKIP: git history less than 30 days"
fi

# E5: SKILL.md version number recent change
last_skill_change=$(git log -1 --format="%ad (%ar)" -- "plugins/fh-meta/skills/*/SKILL.md" 2>/dev/null || echo "N/A")
echo "E5: SKILL.md last change — $last_skill_change"

# E2: Skill complexity ratio (total SKILL.md lines / skill count)
total_lines=$(cat plugins/fh-meta/skills/*/SKILL.md plugins/fh-commons/skills/*/SKILL.md 2>/dev/null | wc -l | tr -d ' ')
skill_count=$(ls -d plugins/fh-meta/skills/*/ plugins/fh-commons/skills/*/ 2>/dev/null | wc -l | tr -d ' ')
if [ "$skill_count" -gt 0 ]; then
  ratio=$((total_lines / skill_count))
  if   [ "$ratio" -le 100 ]; then echo "E2_OK:   avg ${ratio} lines/skill (healthy)"
  elif [ "$ratio" -le 200 ]; then echo "E2_WARN: avg ${ratio} lines/skill (caution — simplification review recommended)"
  else                             echo "E2_FAIL: avg ${ratio} lines/skill (overloaded — separation or compression needed)"
  fi
fi

# E4: harvest-loop signal history (last 30 days)
signal_dir=tracks/_meta
signal_count=$(find "$signal_dir" -name "fh_signal_*.md" -newer "$(date -v-30d +%Y-%m-%d 2>/dev/null || date -d '30 days ago' +%Y-%m-%d)" 2>/dev/null | wc -l | tr -d ' ')
echo "E4: harvest signals in last 30 days: ${signal_count} (target: ≥3)"

# E6: Cold Audit last execution interval
last_audit=$(find "$signal_dir" -name "*cold_audit*" -o -name "*audit*" 2>/dev/null | xargs ls -t 2>/dev/null | head -1)
if [ -n "$last_audit" ]; then
  last_date=$(stat -f "%Sm" -t "%Y-%m-%d" "$last_audit" 2>/dev/null || stat -c "%y" "$last_audit" 2>/dev/null | cut -d' ' -f1)
  echo "E6: last cold audit — ${last_date}"
else
  echo "E6_WARN: no cold audit history (30-day SLA recommended)"
fi
```

#### L5-D: Harness Health Score (HHS) — Aggregate Metric

Aggregate E1~E6 results into a harness health index (6 points max):

| Metric | OK Condition | Score |
|---|---|---|
| E1 CLAUDE.md lines | Decrease or within ±10 lines | +1 |
| E2 Complexity ratio | ≤100 lines/skill | +1 |
| E3 Open consumption rate | ≥50% in 30 days | +1 |
| E4 harvest signals | ≥3 in 30 days | +1 |
| E5 SKILL.md change | Within 14 days | +1 |
| E6 cold audit | Within 30 days | +1 |

**HHS ≥ 4**: Healthy / **HHS 2~3**: Caution / **HHS ≤ 1**: Critical → immediate full harness-doctor re-diagnosis

---

### Step 7. M/S/R Prescription Report Output

Classify and output diagnostic results in 3 tiers (including L5 results):

```
## harness-doctor Diagnostic Results

### 🟥 M-tier (Immediate Action)
- [content]

### 🟧 S-tier (Strongly Recommended Improvement)
- [content]

### 🟩 R-tier (Recommended Optimization)
- [content]

---
## L5 Pattern Analysis
- Activity (L5-A): [ACTIVE/LOW_ACTIVE/INACTIVE_30D/INACTIVE_90D list]
- Context appropriateness (L5-B): [suspected misuse patterns or "no issues"]
- Effect metrics (L5-C): E1=[result] / E3=[result] / E5=[result]

---
Diagnostic scope: L1 Structural Completeness · L2 Complexity · L3 Drift [· L4 Connection (FH) · L5 Pattern Analysis (FH)]
```

M-tier 0 items → output "Structure healthy. Maintaining simplification trend."

**M-tier Immediate Human Gate** — if 1+ M-tier items found, pause before Step 8 and surface:

```
⚠️  harness-doctor: N M-tier item(s) require immediate action:
  - [item 1 — one-line summary]
  - [item 2 — one-line summary]

Options:
  (a) Continue — AI proceeds to Step 8 (harvest-loop integration) and outputs full prescription
  (b) Human review first — inspect M-tier items before prescription is applied
  (c) Abort — address M-tier manually and re-run harness-doctor

Waiting for input. (Default: a)
```

Rationale: M-tier items represent structural blockers. When AI proceeds to prescription application without human review, the same compression/refactoring that caused drift can be applied to "fix" it — closing a self-referential loop. The gate is lightweight (one prompt) but breaks the loop structurally.

---

### Step 8. harvest-loop Integration *(when tracks/_audit/ exists)*

> **Bidirectional integration**: harvest-loop lightweight trigger (CLAUDE.md 160+ lines / FH 400+ lines / .claudeignore MISSING) → calls harness-doctor full diagnosis. Reverse direction is this Step 8 — recording harness-doctor diagnosis results in weekly_audit.

When 1+ M-tier items found:

```bash
ls -1t tracks/_audit/weekly_audit_*.md 2>/dev/null | head -1
```

If latest weekly_audit file exists → propose adding `## Harness Structure Check (harness-doctor)` section (including L5 pattern analysis results):

```markdown
### Harness Structure Check (harness-doctor)
- [ ] CLAUDE.md line count within threshold
- [ ] No broken file references
- [ ] Unreferenced rules files cleaned up
- [ ] Check tracks with no sync in 30+ days
- [ ] Review INACTIVE_30D skills (L5-A)
- [ ] Check suspected misuse patterns (L5-B)
- [ ] Review effect metrics E1·E3·E5 (L5-C)
- [ ] Check hook divergence (L3-4) — create alternative plan for hooks not firing in Agent View
```

---

### Step 9. Eval-First Quantitative Gate *(skill v1 promotion only)*

Run only when promoting a skill v0.x → v1, or when explicit quantitative verification is requested. Not part of regular Steps 1~8.

**Promotion thresholds** (measured over 5 sim-conductor runs):

| Metric | v1 criteria | Measurement |
|---|---|---|
| Tool Selection Accuracy | > 0.90 | correct skill selections / total |
| Multi-Step Coherence | > 0.85 | full Done When completion rate |
| Clarification Rate | < 0.30 | user intervention requests / steps |

```bash
latest_sims=$(find tracks/_meta/ -name "sim_*.md" 2>/dev/null | sort -r | head -5)
[ -z "$latest_sims" ] && echo "EVAL_SKIP: run sim-conductor 5 times first" && exit 0
echo "Target sim files:"; echo "$latest_sims"
# Manual review — aggregate correct-skill-selections / total per sim file
```

| Result | Action |
|---|---|
| All 3 metrics meet | v1 Promotion **PASS** — record in prescription report |
| 1+ below threshold | **Hold** — keep v0.x, re-run sim-conductor, add metric to S-tier |
| < 5 sim records | **Measure later** — R-tier recommendation |

> *Basis: 2026 H1 analysis of 100+ agent deployments — "eval-first" is the success/failure dividing line. Without quantitative gate, v0 → v1 carries unpredictable external behavior risk.*

---

### Step 10. Regression Guard *(when SKILL.md / rules / CLAUDE.md modified)*

> **Purpose**: Verify that harness-doctor prescription application (compression · refactoring · cleanup) didn't strip operational content. Closes the loop — diagnosis → prescription → **post-fix verification**.

#### 10-1. When to run

| Trigger | Behavior |
|---|---|
| After Step 7 prescription applied to SKILL.md / rules / CLAUDE.md | Auto-run inline |
| Pre-merge gate (CI/PR check) | `bash templates/regression_guard.sh main` |
| Compare against arbitrary refs | `bash templates/regression_guard.sh BASE_REF HEAD_REF` |
| harvest-loop Step 4 (harness-doctor call) | Auto-include if file changes detected |

If no SKILL.md / rules / CLAUDE.md / templates changes detected → skip (regression guard does not apply to README, docs, code-only changes).

#### 10-2. Verification checks (per changed file)

| # | Check | Tier |
|:---:|---|:---:|
| F1 | Frontmatter integrity — `name:` + `description:` present, YAML parses | **M-tier** |
| F2 | Critical section preservation — `## Execution Steps` · `## Done When` · `## Triggers` · `## Activation Triggers` · `## Trigger Phrases` count not reduced | **M-tier** |
| F3 | Code block count — ` ``` ` fence count not reduced by 4+ | **S-tier** |
| F4 | Operational keyword preservation — `M-tier` · `S-tier` · `R-tier` · `PASS` · `BLOCK` · `Wave 0~4` · `Step 0~4` · `fan-in` · `Done When` token counts | **M-tier** if drop ≥50% · **S-tier** if 20~49% |
| F5 | Cross-reference integrity — `{FH_ROOT}/...` paths resolve to existing files | **M-tier** |
| F6 | Line reduction percentage | **S-tier** if ≥30% reduction |
| F7 | Bash block syntax — per-block `bash -n` parse, count of bad blocks compared | **M-tier** if net increase |

#### 10-3. Verdict

| Result | Action | Exit code |
|---|---|:---:|
| 0 M-tier, 0 S-tier | ✅ **PASS** — safe to merge | 0 |
| 0 M-tier, 1+ S-tier | ⚠️ **REVIEW** — verify intent before merge | 1 |
| 1+ M-tier | ❌ **BLOCK** — revert or fix before merge | 2 |

#### 10-4. Implementation reference

`templates/regression_guard.sh` — standalone bash script. Self-contained, idempotent, exit-code based (CI-friendly). Compares working tree against any git ref or two refs against each other.

```bash
# Compare working tree vs main
bash templates/regression_guard.sh

# Compare specific PR branch vs main
bash templates/regression_guard.sh main origin/feature-branch

# Compare two arbitrary refs
bash templates/regression_guard.sh v1.0 HEAD
```

#### 10-5. False positive handling

The guard catches real regressions but also surfaces benign changes (e.g., a keyword renamed, a section heading reworded). For each S-tier:

- Check diff context — is the change intentional and equivalent (e.g., `Done When` → `Done-When` is benign)?
- If benign → document in PR description ("S-tier expected: X renamed to Y, semantics preserved")
- If real loss → fix and re-run guard before merge

> The guard is **advisory, not authoritative**. M-tier blocks merge by default but human can override after review (PR description must document the override reason).

#### 10-6. Cross-skill capability — syntax validation reuse

F7 (per-block `bash -n` parse) is a general-purpose syntax verification capability. Other skills can invoke the same logic for different purposes:

| Skill | How it uses syntax verification | Verification axis |
|---|---|---|
| **harness-doctor Step 10** (this) | Regression detection — new syntax errors introduced by change | *Backward*: did we break what worked? |
| **steel-quench** | Attack vector — "this SKILL.md claims bash will run but contains syntax errors" → S-grade blocker | *Adversarial*: is this design actually robust? |
| **source-grounding-audit** | Claim verification — code shown in docs that doesn't parse is a phantom claim (fabricated example) | *Forward*: does what we claim match what runs? |

These three axes are complementary, not overlapping:
- regression_guard catches *new* breakage (compare BEFORE vs AFTER)
- steel-quench catches *design* breakage (does the artifact survive attack?)
- source-grounding-audit catches *phantom* breakage (is the cited code real?)

For shared utility, see `templates/regression_guard.sh` — extract the `count_bad_blocks` function or invoke the script with the appropriate ref pair.

---

### Step 11. PR Change Consistency Check *(triggered on "PR 올려줘" / "PR check" / branch with FH asset changes)*

> **Purpose**: Before a PR is pushed, verify that all files related to the change are consistent. Root cause of today's class of bug: a skill is added but README table is missed, an org is renamed but stale references survive in other files. This step closes the propagation gap.

#### 11-1. Detect changed files vs main

```bash
changed=$(git diff main..HEAD --name-only 2>/dev/null)
[ -z "$changed" ] && changed=$(git diff --cached --name-only 2>/dev/null)
[ -z "$changed" ] && echo "PR_CHECK: no changes detected vs main — skip" && return 0
echo "=== Changed files ($(echo "$changed" | wc -l | tr -d ' ') total) ==="
echo "$changed"
```

#### 11-2. Category-based consistency checks

**A. SKILL.md changes → per-plugin count drift + README table + CATALOG entry**

> **Ground truth** (verified 2026-05-31): there is **no `skills` array** in any manifest. Claude Code auto-discovers skills from `plugins/{plugin}/skills/*/`. Do NOT look for a skills array — it does not exist. The drift surfaces are: (1) the skill **count embedded in descriptions** as `"N skills"` (`plugins/{p}/.claude-plugin/plugin.json` + root `.claude-plugin/marketplace.json`), and (2) the **README skill table** + **CATALOG entries** (human-maintained). Save the script below as a file and run it — inline heredocs in some shells corrupt multi-line Python.

```bash
skills_changed=$(echo "$changed" | grep "skills/.*/SKILL\.md" || true)
if [ -n "$skills_changed" ]; then
  cat > /tmp/_fh_count.py <<'PYEOF'
import json, glob, os, re
def claimed_count(desc):
    m = re.search(r'(\d+)\s*skills', desc)
    return int(m.group(1)) if m else None
# per-plugin plugin.json description count vs actual dirs
for src in sorted(glob.glob('plugins/*')):
    if not os.path.isdir(os.path.join(src, 'skills')):
        continue
    pname = os.path.basename(src)
    actual = len(glob.glob(os.path.join(src, 'skills', '*/')))
    pj = os.path.join(src, '.claude-plugin', 'plugin.json')
    if os.path.exists(pj):
        c = claimed_count(json.load(open(pj)).get('description', ''))
        if c is not None and c != actual:
            print(f"DRIFT: {pname} plugin.json says '{c} skills' but {actual} dirs — update description")
        elif c is not None:
            print(f"OK: {pname} plugin.json count {actual} matches description")
        else:
            print(f"INFO: {pname} plugin.json description has no 'N skills' count ({actual} dirs)")
# root marketplace.json per-plugin description count
mp = '.claude-plugin/marketplace.json'
if os.path.exists(mp):
    for p in json.load(open(mp)).get('plugins', []):
        src = p.get('source', '').lstrip('./')
        actual = len(glob.glob(os.path.join(src, 'skills', '*/')))
        c = claimed_count(p.get('description', ''))
        if c is not None and c != actual:
            print(f"DRIFT: marketplace.json[{p['name']}] says '{c} skills' but {actual} dirs — update description")
        elif c is not None:
            print(f"OK: marketplace.json[{p['name']}] count {actual} matches description")
PYEOF
  python3 /tmp/_fh_count.py

  # Per-changed-skill: README + CATALOG presence (human-maintained lists drift most)
  echo "$skills_changed" | while read sp; do
    sname=$(basename "$(dirname "$sp")")
    grep -q "$sname" README.md 2>/dev/null \
      && echo "OK: $sname in README" \
      || echo "MISSING: '$sname' not in README.md — add to skill table"
    grep -q "$sname" CATALOG.md 2>/dev/null \
      && echo "OK: $sname in CATALOG" \
      || echo "MISSING: '$sname' not in CATALOG.md — add entry"
  done
fi
```

**B. Agent file changes → README agent count**

```bash
agents_changed=$(echo "$changed" | grep -E "agents/.*\.md" || true)
if [ -n "$agents_changed" ]; then
  actual_agents=$(find .claude/agents plugins/*/agents -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
  readme_agents=$(grep -oE '[0-9]+ (fh-meta \+ [0-9]+ fh-commons )?agents?' README.md 2>/dev/null | head -1 || echo "not found")
  echo "Agent files: $actual_agents | README mentions: $readme_agents"
  echo "$agents_changed" | while read ap; do
    aname=$(basename "$ap" .md)
    grep -q "$aname" README.md 2>/dev/null \
      && echo "OK: $aname in README" \
      || echo "MISSING: '$aname' not in README.md"
  done
fi
```

**C. knowledge/shared/ changes → CATALOG coverage**

```bash
knowledge_changed=$(echo "$changed" | grep "^knowledge/" || true)
if [ -n "$knowledge_changed" ]; then
  echo "$knowledge_changed" | while read kf; do
    fname=$(basename "$kf" .md)
    grep -q "$fname" CATALOG.md 2>/dev/null \
      && echo "OK: $fname in CATALOG" \
      || echo "MISSING: '$fname' not in CATALOG.md — add entry"
  done
fi
```

**D. README.md changed → stale org/version references**

```bash
if echo "$changed" | grep -q "^README\.md$"; then
  grep -n "chrono-code" README.md 2>/dev/null && echo "STALE: 'chrono-code' found — should be 'chrono-meta'" || true
  actual=$(ls -d plugins/fh-meta/skills/*/ plugins/fh-commons/skills/*/ 2>/dev/null | wc -l | tr -d ' ')
  readme_count=$(grep -oE '[0-9]+ (fh-meta[^)]+)?skills' README.md 2>/dev/null | head -1 || echo "not found")
  echo "Actual skills: $actual | README mentions: $readme_count"
fi
```

**E. AGENTS.md / CLAUDE.md changed → cross-reference sanity**

```bash
if echo "$changed" | grep -qE "^AGENTS\.md$|^CLAUDE\.md$"; then
  # Check AGENTS.md agent count vs actual files
  if [ -f AGENTS.md ]; then
    agents_in_file=$(grep -c "^##\? " AGENTS.md 2>/dev/null || echo "?")
    actual_agents=$(find .claude/agents plugins/*/agents -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    echo "AGENTS.md sections: $agents_in_file | Actual agent files: $actual_agents"
  fi
fi
```

#### 11-3. Verdict

| State | Action |
|---|---|
| All checks OK | ✅ **CONSISTENT** — PR ready |
| 1+ MISSING/MISMATCH | 🟧 **INCONSISTENT** — fix before push |
| Count mismatch only | 🟩 **REVIEW** — verify intent |

**Auto-propose** when "PR 올려줘" / "push" / "merge" detected in session (non-blocking one-liner):
> *"PR 올리기 전에 연관 파일 일관성 체크할까요? (`harness-doctor PR check`)"*

---

## Done When

| Stage | Completion Verdict |
|---|---|
| Step 7 M/S/R prescription report output | ✅ Diagnosis complete — this skill execution ends |
| M-tier 0 items confirmed + "Structure healthy" output | ✅ Diagnosis complete (no prescription needed) |
| Step 8 weekly_audit section addition proposed | ✅ Integration proposal complete (acceptance is user's decision) |
| Step 9 Eval-First gate verdict output (when requested) | ✅ Promotion verdict complete |
| Step 10 Regression Guard verdict (PASS/REVIEW/BLOCK) when SKILL.md changes | ✅ Post-fix verification complete |
| Step 11 PR consistency check — CONSISTENT/INCONSISTENT/REVIEW verdict output | ✅ PR pre-push verification complete |

**This skill Done When = "prescription report output complete"**. Actual resolution of M/S/R items belongs to user or follow-up work and is not included in this skill's completion criteria.

Verdict: PASS (M-tier 0 confirmed, "Structure healthy" output) | CONDITIONAL_PASS (S/R-tier items remain, no M-tier blockers) | FAIL (1+ M-tier items found, prescription issued) | ESCALATE (structural ambiguity requiring human judgment before prescription can be issued)

- Actual resolution of M-tier items confirmed by re-run showing M-tier 0
- Exiting without Step 7 output = Fail

**External validation path**: harvest-loop Step 3.75 Critic isolated Agent can independently judge based on above criteria (`skill_quality_rubric.md` verifiable criteria). Auto-connects when subsequent quench is run.

**→ Three-Doctor Loop chain (auto-propose after prescription report):**
- M-tier found AND token/context waste patterns detected → **propose `/context-doctor`** (current context axis)
- M-tier found AND changes affect user-facing behavior (README, skill descriptions, onboarding) → **propose `/sim-conductor Area A`** (future behavior axis)
- Both conditions → propose full Three-Doctor Loop in sequence: context-doctor → sim-conductor Area A

---

## External User Environment Adaptation

| Environment | Behavior |
|---|---|
| Meta-harness mode A | Steps 1~8 full / includes L4 connection diagnosis + L5 pattern analysis |
| Plugin only (mode C) | Steps 1~7 / skip L4·L5 / skip harvest-loop integration |
| External general environment | L1~L3 diagnosis + M/S/R prescription only |
| L5 pattern analysis | Mode A (FH/meta-hub cwd) exclusive — skip in mode B·C·external general environment |

---

## Trigger Phrases

### Explicit Triggers (no auto-firing)

- `/harness-doctor`
- "harness diagnosis", "harness structure check", "harness cleanup", "structure audit"
- "harness health check", "structure audit"

### Natural Language Triggers (example user phrases)

This skill can be triggered when expressing Claude Code configuration or structure problems naturally:

| Example Phrase | Intent | Mapped Diagnostic Layer |
|---|---|---|
| "my Claude settings seem off", "Claude settings seem weird" | Structure/config error suspected | L1·L3 |
| "settings won't work", "settings are tangled" | File reference error or syntax error | L3 |
| "hook isn't working", "hook won't run" | settings.json hook divergence | L3-4 |
| "CLAUDE.md seems too complex now" | Complexity diagnosis needed | L2 |
| "something that used to work doesn't anymore" | Drift or stale files | L3 |
| "Claude seems to be ignoring my rules" | Rules file unreferenced or conflicting | L2·L3 |
| "is this project hub connection set up correctly?" | L4 connection diagnosis | L4 (FH environment) |
| "skill isn't triggering" | Skill activity check | L5-A |
| "PR 올려줘", "PR check", "push before review", "변경사항 영향 범위" | PR change consistency check | Step 11 |
| "README 맞아?", "CATALOG 업데이트 됐어?", "plugin.json 반영됐어?" | PR propagation gap check | Step 11 |

> No auto-firing — only executes when user explicitly invokes.
> Maintain scope separation from context-doctor (token efficiency) and harvest-loop (weekly patterns).
> **Step 11 exception**: propose as one-liner (non-blocking) when "PR", "push", "merge" detected in session.

## Failure Fallback

On Claude API / MCP failure → refer to [`references/fallback-guide.md`](../../references/fallback-guide.md) manual checklist.

---

## Three-Doctor Loop Integration

### Role in the Three-Doctor Loop

harness-doctor = **current structure diagnostician** (CLAUDE.md consistency, skill conflicts, drift). context-doctor handles context collapse, sim-conductor predicts future behavior. Together they form a diagnose→prescribe→re-diagnose closed loop.

| Situation | Next skill |
|---|---|
| Structure issue + suspected token waste | `/context-doctor` |
| Validate structure changes from external perspective | `/sim-conductor Area A` |
| L5-B context deviation patterns | `/sim-conductor Area A` (auto-handoff) |
| All three mentioned | Full Three-Doctor Loop activated |

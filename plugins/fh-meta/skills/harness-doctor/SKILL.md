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
for f in .claude/rules/*.md 2>/dev/null; do
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

> Verify that periodic skills (audit-learnings · sim-conductor) are actually running. Prevents "assumed to be running" drift.

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

---

### Step 8. audit-learnings Integration *(when tracks/_audit/ exists)*

> **Bidirectional integration**: audit-learnings Step 1.4 lightweight trigger (CLAUDE.md 160+ lines / FH 400+ lines / .claudeignore MISSING) → calls harness-doctor full diagnosis. Reverse direction is this Step 8 — recording harness-doctor diagnosis results in weekly_audit.

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

### Step 9. Eval-First Quantitative Gate *(only when assessing skill v1 promotion)*

> **Execution condition**: When promoting a skill from v0.x to v1, or when explicit quantitative verification of "is this skill useful?" is requested.
> Not automatically included in regular diagnosis runs (Steps 1~8) — only when explicitly requested or skill promotion issue detected.

#### Promotion Criteria Quantitative Thresholds

| Metric | v1 Promotion Criteria | Measurement Method |
|---|---|---|
| **Tool Selection Accuracy** | > 0.90 | 5 sim-conductor runs — ratio of correct skill selections |
| **Multi-Step Coherence** | > 0.85 | Completion rate of multi-step skill full flow (reaching Done When without early termination or interruption) |
| **Clarification Rate** | < 0.30 | Ratio of user intervention requests during execution (number of questions / total execution steps) |

#### Measurement Procedure

```bash
# 1. Collect sim-conductor execution records (last 5)
latest_sims=$(find tracks/_meta/ -name "sim_*.md" 2>/dev/null | sort -r | head -5)
[ -z "$latest_sims" ] && echo "EVAL_SKIP: no sim records — run sim-conductor 5 times then re-measure" && exit 0

# 2. Aggregate skill call accuracy (correct skill selections / total)
# (Manual review recommended — auto-parsing is for reference only)
echo "Target sim files:"
echo "$latest_sims"
echo "From each sim file, manually check 'correct skill selections' / 'total scenarios' then calculate ratio."
```

#### Below Threshold Handling

| State | Action |
|---|---|
| All 3 metrics meet criteria | **v1 Promotion PASS** — record "v1 promotion possible" in harness-doctor prescription report |
| 1+ metrics below threshold | **v1 Promotion on Hold** — maintain v0.x + mandatory sim-conductor re-run + add below-threshold metric to S-tier |
| Less than 5 sim records | **Measurement not possible** — "Run sim-conductor 5 times then re-measure" R-tier recommendation |

#### Basis

Analysis of 100+ agent deployments in 2026 H1 confirmed "eval-first" approach as the dividing line between success and failure. Without a quantitative gate, v0 → v1 promotion carries high risk of unpredictable behavior in external user environments.

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

---

## Done When

| Stage | Completion Verdict |
|---|---|
| Step 7 M/S/R prescription report output | ✅ Diagnosis complete — this skill execution ends |
| M-tier 0 items confirmed + "Structure healthy" output | ✅ Diagnosis complete (no prescription needed) |
| Step 8 weekly_audit section addition proposed | ✅ Integration proposal complete (acceptance is user's decision) |
| Step 9 Eval-First gate verdict output (when requested) | ✅ Promotion verdict complete |
| Step 10 Regression Guard verdict (PASS/REVIEW/BLOCK) when SKILL.md changes | ✅ Post-fix verification complete |

**This skill Done When = "prescription report output complete"**. Actual resolution of M/S/R items belongs to user or follow-up work and is not included in this skill's completion criteria.

- Actual resolution of M-tier items confirmed by re-run showing M-tier 0
- Exiting without Step 7 output = Fail

**External validation path**: harvest-loop Step 3.75 Critic isolated Agent can independently judge based on above criteria (`skill_quality_rubric.md` verifiable criteria). Auto-connects when subsequent quench is run.

---

## External User Environment Adaptation

| Environment | Behavior |
|---|---|
| Meta-harness mode A | Steps 1~8 full / includes L4 connection diagnosis + L5 pattern analysis |
| Plugin only (mode C) | Steps 1~7 / skip L4·L5 / skip audit-learnings integration |
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

> No auto-firing — only executes when user explicitly invokes.
> Maintain scope separation from context-doctor (token efficiency) and audit-learnings (weekly patterns).

## Failure Fallback

On Claude API / MCP failure → refer to [`references/fallback-guide.md`](../../references/fallback-guide.md) manual checklist.

---

## Three-Doctor Loop Integration

### harness-doctor's role in the Three-Doctor Loop

```
harness-doctor   → diagnose current structure  "Is the structure correct? Any drift, complexity, or broken references?"
context-doctor   → diagnose current context    "Is Context Collapse happening?"
sim-conductor    → predict future behavior     "What happens when a real person uses this system?"
```

harness-doctor is the **current structure diagnostician** among the three skills. It checks whether the structure is correct (CLAUDE.md reference consistency, skill conflicts, drift) and provides prescriptions, then context-doctor (context) and sim-conductor (future behavior) take over to complete the closed loop.

---

harness-doctor (structure) · context-doctor (token/context) · sim-conductor (simulation/ideation) — three skills connect in a **diagnose→prescribe→re-diagnose** closed loop.

| Situation | Next Skill |
|---|---|
| Structure problem found, also suspect token waste | `/context-doctor` |
| Validate structure improvements from external user perspective | `/sim-conductor Area A` |
| L5-B context deviation patterns found | `/sim-conductor Area A` — auto-handoff for external perspective misuse pattern verification |
| All three skills mentioned | Three-Doctor Loop circuit activated — diagnose→prescribe→re-diagnose cycle |

---
name: pipeline-conductor-detail
description: Detail reference for pipeline-conductor — per-step output format blocks, aggregated report template, invocation notes, Area B cadence bash. Load when executing a specific step.
load: on-demand
---

# pipeline-conductor — Detail Reference

> Load when executing a specific step. SKILL.md contains triggers, modes, the verdict vocabulary + chain behavior, scope translation, per-step gate tables, overall verdict logic, resume rules, and Done When.

---

## §Output-Formats

### Step 0 — Sweep Plan

```
pipeline-conductor — Sweep Plan
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Scope:  {scope}
  Mode:   {--full / --quick / --no-sim}
  Branch: {branch name}
  Steps:  {1 → 2 → 3 → 4 / 2 → 3 / 1 → 2 → 3}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Proceed? (Y: run / N: cancel)
```

### Step 0.5 — return-path-gate FAIL block

```
[Step 0.5 — return-path-gate]
  Verdict: FAIL
  Basis:   HIGH severity OPEN chain(s) — inter-step verdicts unreliable with broken chains
  Open:    [list of OPEN chains with severity]

Fix OPEN chains then re-run pipeline-conductor.
Skip? (S: override gate — records as degraded, disqualifies CLEAN (--full) status)
```

### Step 1 — harvest-loop verdict block

```
[Step 1 — harvest-loop]
  Verdict: {verdict}
  Basis:   {one-line}
  Pending: {list of items if CONDITIONAL_PASS, else "none"}
```

### Step 2 — steel-quench verdict block

```
[Step 2 — steel-quench]
  Verdict: {verdict}
  Basis:   {one-line}
  Findings:
    S-grade: {count} — {top item or "none"}
    A-grade: {count} — {top item or "none"}
    B-grade: {count} — {top item or "none"}
```

### Step 3 — phantom-quench verdict block

```
[Step 3 — phantom-quench]
  Verdict: {verdict}
  Basis:   {one-line}
  Phantoms: {count} — {load-bearing: Y/N} — {top item or "none"}
```

### Step 4 — sim-conductor verdict block

```
[Step 4 — sim-conductor]
  Verdict: {verdict}
  Basis:   {one-line}
  Area B:  {ran / skipped — cadence limit}
  Findings:
    M: {count} — {top item or "none"}
    S: {count} — {top item or "none"}
    R: {count} — {top item or "none"}
```

### Step 5 — Aggregated Report

```
pipeline-conductor — Sweep Report
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Scope:  {scope}
  Mode:   {mode}
  Branch: {branch}
  Date:   {YYYY-MM-DD}

  Step 0.5 — return-path-gate:       {PASS / CONDITIONAL_PASS / FAIL / SKIPPED / degraded}
  Step 1   — harvest-loop:           {PASS / CONDITIONAL_PASS / FAIL / ESCALATE / SKIPPED}
  Step 2   — steel-quench:           {verdict}
  Step 3   — phantom-quench: {verdict}
  Step 4   — sim-conductor:          {verdict}

  Overall: {CLEAN (--full) / CLEAN (--quick) / CLEAN (--no-sim) / PENDING / BLOCKED}

  ── Pending items (CONDITIONAL_PASS steps + accepted ESCALATE) ──
  {item list, or "none"}

  ── Blocking items (FAIL steps + unresolved ESCALATE) ──
  {item list, or "none — sweep completed cleanly"}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## §Execution-Notes

### Step 1 — harvest-loop invocation path

pipeline-conductor reads session context for harvest-loop findings rather than invoking harvest-loop directly — invoking harvest-loop mid-sweep would start a new harvest cycle that conflicts with the sweep's own pattern collection. If no harvest-loop run exists in this session, pipeline-conductor can invoke harvest-loop in proposal mode (`/harvest-loop`) as a pre-Step-1 option, but this is not automatic.

- If harvest-loop ran in this session: read its output and incorporate findings.
- If harvest-loop did not run in this session: output `CONDITIONAL_PASS` — knowledge loop not validated in this sweep.
- If harvest-loop auto-skipped (fewer than 3 patterns found): output `CONDITIONAL_PASS` — sub-threshold, knowledge loop not validated.

### Per-step FAIL prompts

On FAIL the chain halts and asks (insert the failing step's name and finding):

> "{step skill} found a blocking issue. Fix and re-run Step {N}, or abort the sweep?"

(Step 4 variant: "…or accept findings and close with FAIL status?")

On CONDITIONAL_PASS in any step: capture the finding list (Step 2: A/B-grade; Step 3: non-load-bearing Phantoms; Step 4: S/R-tier findings) and continue to the next step.

### Step 4 — Area B cadence check bash

sim-conductor Area B has a once-per-week frequency limit:

```bash
find tracks/_meta/ -name "*sim_conductor*" -newer "$(date -v-7d +%Y-%m-%d 2>/dev/null || date -d '7 days ago' +%Y-%m-%d 2>/dev/null)" 2>/dev/null | head -1
```

- Result found (Area B ran within 7 days): skip Area B → run Area A + Area D only. Capture as `CONDITIONAL_PASS` with note: "Area B skipped — within 7-day cadence limit."
- No result (Area B not run within 7 days): run Area A + Area B + Area D (scope permitting).

### What each step checks (reference)

| Step | Checks |
|---|---|
| 1 harvest-loop | Recent session learnings absorbed, duplicate skill candidates pending, knowledge loop integrity in current session |
| 2 steel-quench | Design attack surface, trigger phrase collisions, over-engineered steps, self-declaration language, devil-advocate structural flaws |
| 3 phantom-quench | Proper nouns, numerical values, file paths, branching conditions back-traced to declared sources; ungrounded claims = Phantom |
| 4 sim-conductor | Transferability to external users, new-user entry friction, power-user edge cases, artifact quality from outside perspective |

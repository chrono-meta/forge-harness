---
name: convergence-loop
description: >-
  A universal gate-reinforcement meta-skill that replaces the "single-pass = done" pattern with a converging loop of up to N rounds. Can be applied to any gate, checkpoint, or verification step. Only declares "truly passed" after FAIL→FIX→re-verify repeats until convergence (all items pass). Escalates to structural redesign if not converged within N rounds. Triggers on: "convergence-loop", "how many rounds do we need", "suspicious of single-pass", "not sure if it really passed", or equivalent phrasing.
user-invocable: true
allowed-tools: ["Read", "Write", "Bash", "Agent"]
model: sonnet
origin: contention-layer
contention-parents: [harvest-loop]
---

# convergence-loop — Universal Convergence Loop Gate Reinforcement

> A single pass declaration is hard to trust. A fix exposes new FAILs, and round 2 catches what round 1 missed. convergence-loop assigns a "truly passed" criterion to any gate.

## Triggers

- `/convergence-loop`
- "convergence-loop", "how many rounds do we need", "not sure if it really passed"
- "suspicious of single-pass", "run until it passes", "keep verifying until clean"
- "single pass isn't enough", "need another round", "the fix might have introduced new issues"
- Auto-proposed: when the same artifact receives a FAIL verdict 2+ times in the same session (observable: 2nd FAIL on identical scope)

---

## Origin

Extracted from a recurring "single-pass gate is hard to trust" pattern observed across multiple hub workflows. The canonical reference is:
- `harvest-loop` extract→attack→synthesize cycle: pattern extraction → attack → synthesis → the repeating structure must run until convergence

When the same structure recurs across gates, it is a skill.

## Applicable Targets

| Applicable Gate | Example |
|---|---|
| Skill diagnostic gate | harness-doctor + apex-review |
| Session harvest loop | harvest-loop extract→attack→synthesize cycle |
| External asset audit | steel-quench Wave 1~N |
| Domain-specific quality gate | Plug in any project-defined FAIL→FIX checkpoint |
| Any FAIL→FIX repeating structure | User-defined gate |

---

## Pipeline Structure

```
[Input] gate name + pass criteria + max rounds N (default 3)
    │
    ▼
Round 1
    │  Execute gate
    │  → All items pass: ✅ Round 1 passed → Round 2 (verification)
    │  → FAIL occurs: List FAIL items → Execute FIX → Round 2
    │
    ▼
Round 2
    │  Re-execute same gate (with FIX applied + search for new FAILs)
    │  → All items pass: ✅ Round 2 passed → Round 3 (final check)
    │  → New FAIL: List → FIX → Round 3
    │
    ▼
Round 3 (final)
    │  → All items pass: ✅ Declare truly passed
    │  → FAILs remain: "Structural redesign required" → Escalate
    │
    ▼ (if not converged within N rounds)
Escalation
    → Classify root cause: ambiguous criteria / FIX capability limit / gate design flaw
    → Output recommended action
```

**Core principle**: A fix exposing new FAILs is not a failure — it is a **signal that the gate is working correctly**. The deeper the round, the more fundamental the FAILs it uncovers.

---

## Execution Guidelines

### Setup (confirm before running)

```
Gate name:       [what checkpoint is this]
Pass criteria:   [specify pass condition — "all items ✅" or concrete criteria]
Max rounds:      [default 3; simple gates 2; complex gates up to 5]
FIX owner:       [auto-fixable / requires human / mixed]
Escalation:      [who to escalate to / how, if not converged within N rounds]
```

### Per-Round Execution Rules

**What must stay constant across rounds**:
- Pass criteria are immutable (no relaxing criteria per round)
- Cumulative tracking of FAIL items (verify that prior-round FAILs were fixed)
- New FAILs explicitly labeled (distinguish newly surfaced items from fix chain)

**What changes across rounds**:
- FIX-applied targets (revised TCs, skills, documents)
- FAIL list (should shrink; growth is also acceptable — it means items are surfacing)

### Convergence Judgment

```
Convergence = 0 new FAILs across 2 consecutive rounds
Conditions to declare truly passed:
  1. All items pass AND
  2. At least 2 rounds executed (single-round pass treated as "provisionally passed" only)
```

### Escalation Root Cause Classification

| Cause | Signal | Recommended Action |
|---|---|---|
| Ambiguous pass criteria | Same item judged differently each round | Restate criteria explicitly, then restart |
| FIX capability limit | FAILs detected but fix method unknown | Bring in expert or reduce scope |
| Gate design flaw | Same FAIL repeats after N rounds | Redesign the gate itself → meta-prompt-builder |

---

## Output Format

```
## convergence-loop Result

Gate: [gate name]
Max rounds: N | Actual convergence round: M

| Round | Verdict | FAIL Items | New FAILs | FIX Applied |
|:---:|:---:|---|:---:|:---:|
| 1 | FAIL/PASS | [item list] | — | Y/N |
| 2 | FAIL/PASS | [item list] | [new] | Y/N |
| 3 | PASS | none | none | — |

✅ Truly passed (converged at round M)
❌ Not converged within N rounds → Escalation: [root cause classification]
```

---

## Related Skills

| Situation | Related Skill |
|---|---|
| Applied to skill diagnostic gate | `harness-doctor` → convergence-loop wrapper |
| Applied to quench wave | `steel-quench` Wave 3+ convergence criteria (same principle) |
| Applied to session harvest loop | `harvest-loop` extract→attack→synthesize cycle |
| When gate redesign is needed | `meta-prompt-builder` |

## Done When

```
Setup complete (gate name, pass criteria, max rounds confirmed)
+ Minimum 2 rounds executed
+ Convergence declared (all items pass for 2 consecutive rounds) or escalation triggered
+ Per-round result table output
```

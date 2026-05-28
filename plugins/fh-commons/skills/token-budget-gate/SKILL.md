---
name: token-budget-gate
description: Estimates token cost before a multi-step task and outputs a Green/Yellow/Red gate verdict. Tracks actual vs. estimated after completion for calibration. Triggers on "token budget", "how much will this cost", "will this be expensive", "estimate tokens", before long multi-agent tasks.
user-invocable: true
allowed-tools: ["Read", "Bash"]
model: sonnet
complexity_routing:
  base: sonnet
  high: opus
  escalate_when:
    - multi_project_scope
    - unknown_task_type
---

# token-budget-gate — Pre-Task Token Cost Gate

Multi-step and multi-agent tasks can silently consume large token budgets. This skill estimates cost before execution, outputs a gate verdict, and calibrates estimates against actual usage after completion — preventing surprise overruns without blocking legitimate work.

> **FH context**: FH default execution tier is `standard` (~15K tokens). This skill gates against accidental `full` (~30K) or `max` (~60K+) consumption on tasks that could be handled lighter.

---

## Triggers

- `/token-budget-gate`
- "token budget", "token cost", "how expensive", "will this use a lot of tokens"
- "estimate tokens", "token estimate before we start"
- Before invoking: `agent-composer`, `sim-conductor`, `steel-quench` (max-tier skills)
- Automatically proposed when task description contains: multi-agent, parallel dispatch, full suite, all files, entire codebase

---

## Gate Thresholds (defaults — user-configurable)

| Signal | Verdict | Action |
|---|---|---|
| Estimated < 10K tokens | 🟢 **GREEN** | Proceed without comment |
| 10K–30K tokens | 🟡 **YELLOW** | Proceed with notice — suggest lighter approach if one exists |
| 30K–60K tokens | 🟠 **ORANGE** | Confirm before proceeding — present scope reduction options |
| > 60K tokens | 🔴 **RED** | Block + require explicit approval — present mandatory reduction |

Custom threshold: user can set `TOKEN_BUDGET_MAX=N` in conversation or `.claude/settings.json`.

---

## Execution Steps

### Step 1. Parse Task Description

Extract task dimensions:

| Dimension | Low (×1) | Medium (×2) | High (×4) |
|---|---|---|---|
| **File scope** | 1–3 files | 4–10 files | 11+ files / whole codebase |
| **Agent count** | 0 (inline) | 1–2 agents | 3+ agents / parallel |
| **Step depth** | 1–3 steps | 4–8 steps | 9+ steps |
| **Iteration** | None | 1 round | 2+ rounds (wave/loop) |
| **Output size** | Short answer | Medium doc | Full report / deck |

---

### Step 2. Estimate Token Cost

Base estimates per task type:

| Task Type | Base Estimate | Notes |
|---|---|---|
| Single file edit | 2K | Read + edit + verify |
| Code review (1 PR) | 5K | Diff + analysis + comments |
| Skill creation (1 SKILL.md) | 8K | Design + write + CATALOG update |
| Agent dispatch (1 agent) | 10K | Context card + agent overhead |
| Parallel dispatch (3 agents) | 25K | 3× agent + orchestration |
| sim-conductor full run | 30K | All 5 simulation axes |
| steel-quench 4-wave | 50K | All waves + prescriptions |
| Full harvest-loop cycle | 40K | 8-step pipeline + PRs |

Apply dimension multipliers from Step 1 to the base estimate.

**Final formula:**
```
Estimated = base × file_multiplier × agent_multiplier × iteration_multiplier
```

Round to nearest 1K.

---

### Step 3. Output Gate Verdict

```
## Token Budget Gate

Task: {one-line task description}
Estimated cost: ~{N}K tokens
Threshold: {user max or default}

Verdict: 🟡 YELLOW — within budget but consider lighter approach

Breakdown:
  Base (skill creation): 8K
  × 2 agents: ×2 = 16K
  × 1 iteration: ×1 = 16K
  Total: ~16K

Lighter alternative:
  → Inline (no agent dispatch): ~8K (-50%)
  → Single agent, not parallel: ~12K (-25%)

Proceed? (y to continue / n to adjust scope)
```

For 🟢 GREEN: output one line only — *"Token estimate: ~{N}K — GREEN, proceeding."*

---

### Step 4. Proceed / Adjust

- **GREEN / YELLOW + user confirms**: proceed, note start marker
- **ORANGE**: present scope reduction table, wait for user selection
- **RED**: present mandatory reduction — do not proceed until user explicitly approves

Scope reduction options table (ORANGE/RED):

| Option | Reduction | Trade-off |
|---|---|---|
| Drop parallel → sequential | -30% | Slower, same quality |
| Reduce agent count (3→1) | -50% | Less parallelism |
| Narrow file scope | -40% | Shallower coverage |
| Use lighter skill variant | -60% | Fewer waves/probes |
| Split into 2 sessions | -50%/session | No quality loss |

---

### Step 5. Post-Task Calibration (optional)

After task completion, if user says "how much did that cost" or "calibrate":

```
## Calibration

Estimated: ~16K tokens
Actual: ~{actual}K tokens
Error: {+/-N}%

Calibration note saved → improves next estimate for this task type.
```

Write calibration data:
```bash
mkdir -p .claude/token_calibration/
# Append: task_type, estimated, actual, date
```

Calibration data improves future estimates for the same task type (no model training — local record only).

---

## Done When

- Gate verdict output (GREEN/YELLOW/ORANGE/RED) with estimated cost breakdown
- For ORANGE/RED: scope reduction options presented and user decision recorded
- Calibration offered after task completion (optional, not mandatory)

---

## Chains

**Upstream** (proposed before these skills):
- → `agent-composer` (multi-agent orchestration)
- → `sim-conductor` (5-axis simulation)
- → `steel-quench` (4-wave adversarial review)
- → `harvest-loop` (8-step pipeline)

**Downstream**:
- No mandatory chain — gate verdict is the output; task execution follows user decision

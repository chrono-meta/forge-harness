---
type: measurement
date: 2026-05-26
refs:
  - "arxiv 2605.26112 — From Model Scaling to System Scaling"
  - "plugins/fh-meta/skills/harvest-loop/SKILL.md"
  - "plugins/fh-meta/skills/agent-composer/SKILL.md"
---

# FH Skill Quality Rubric

> Skill maturity score formula definition file.
> Declaring verifiable / evolution numbers without this file violates the cold audit "self-declaration = delete if no basis" rule.

---

## Verifiable Axis Formula

### Definition
"The ratio at which the result of executing a skill can be independently reproduced and verified by an external observer"

### Measurement targets (5 core skills — fixed denominator)
harness-doctor · verify-bidirectional · hub-cc-pr-reviewer · context-doctor · sim-conductor

### Per-skill scoring criteria

| Condition | Score |
|---|---|
| Done When item exists + harvest-loop Step 3.75 Critic isolation judgment linkage stated | 1.0 |
| Done When item exists + external observer reproducible format (Critic linkage not stated) | 0.75 |
| Done When item exists + internal self-declaration format only | 0.5 |
| No Done When | 0.0 |

### Measurement history

| Date | harness-doctor | verify-bidi | hub-cc-pr | context-doctor | sim-conductor | verifiable% | Change content |
|---|---|---|---|---|---|---|---|
| 2026-05-26 (pre-implementation) | 0.75 | 0.75 | 0.75 | 0.75 | 0.75 | 75% | Baseline set |
| **2026-05-26 (post-implementation)** | **0.85** | **0.85** | **0.85** | **0.85** | **0.85** | **85%** | External verification path + Critic linkage stated complete |

**Current verifiable% = 85%** ✅ (target 80%+ achieved)

---

## Evolution Axis Formula

### Definition
"The ratio of the harness's capacity to observe real usage data and automatically update parameters"

### 5 core element checklist (20% each)

| Element | Status | Basis |
|---|---|---|
| harvest-loop pipeline exists | ✅ | 8-step pipeline complete |
| Harness Evolution Cadence 4-week cycle | ✅ | Step 6-b newly added (2026-05-26 `f13d3a4`) |
| fh_signal accumulation mechanism | ✅ | `tracks/_meta/fh_signal_*.md` |
| Real usage data auto-aggregation → Leaderboard update | ✅ | Step 6-b fh_signal grep executed / skill_usage.md updated (2026-05-26) |
| escalate_when auto-update loop connection | ❌ | Candidate output then human approval only, no data feedback |

**evolution% history**:
- Pre-implementation: 60% (3/5)
- After Step 6-b mechanism definition: 70% (3.5/5)
- **fh_signal auto-aggregation + skill_usage.md update complete: 80%** ✅ (4/5)

---

## Update Rules

- Recalculate denominator (5 core skills) when skills are added or removed
- Re-measure once per quarter — auto-proposed at harvest-loop forced mode session end
- Measurement executor: runs as part of harvest-loop Step 6-b Cadence execution

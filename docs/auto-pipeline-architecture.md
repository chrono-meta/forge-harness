# FH Auto-Pipeline Architecture

> **Purpose**: The user provides direction and insight; the system handles the rest.

---

## Overview

The full self-evolving pipeline of forge-harness, centered on harvest-loop.

---

## Full Flow

```
User request
  → [Step 0-a] Clarifying question    (only when direction is unclear — max 2 questions)
  → [Step 0]   Wave composition       (agent-composer auto-selection)
  → [Wave exec] Parallel dispatch     (Wave 0 scouting → Wave 1+ execution)
  → [Step 4]   fan-in result merge   (M/S/R tier aggregation)
  ※ M = must handle now, S = recommended next session, R = backlog reference — see agent-composer SKILL.md Step 4
  → [Step 4-b] State transition gate  (auto-propose next Wave)
  → [Step 4-c] Auto-record gate       (2+ changes → harvest-loop lightweight)
  → [Step 5]   Wave 4 final judgment  (PASS / BLOCK)
  → [Step 6]   Proactive proposal     (auto-propose 1 skill, e.g. harness-doctor)
  → [Next Wave or End]
```

---

## Session-End Self-Evolution Pipeline (harvest-loop)

```
Session end
→ [Step 1] field-harvest: scan git diff → extract patterns (skip if < 3)
→ [Step 2] contention-layer: detect conflicts with existing skills
→ [Step 3] parallel: devil-advocate (attack existing skills) + innovator (propose new)
→ [Step 3.5] synthesizer: cross-synthesis → re-rank HIGH/MED/LOW
→ [Step 4] harness-doctor: check Done When presence, duplicates, self-reference
→ [Step 5] verify-bidirectional: confirm bidirectional consistency
→ Y/N approval gate → create PR or persist fh_signal
```

When patterns and feedback emerge in a session, this pipeline runs automatically to evolve FH skills. The user only approves Y/N.

---

## Three-Doctor Loop (self-healing closed loop)

```
harness-doctor (diagnose) → context-doctor (prescribe) → sim-conductor (re-diagnose)
        ↑                                                           ↓
        └──────────── re-inject into improved harness structure ───┘
```

The three agents form a closed loop that continuously detects, prescribes, and re-validates internal weaknesses.

External concept: isomorphic with CollabEval's 3-stage multi-agent consensus (independently implemented).

---

## Human-on-the-Loop Design

Every final decision has a Y/N gate.

Agents propose; humans approve. Circuit Breaker role.

| Domain | Owner | Example |
|---|---|---|
| Direction · insight · naming | **Human** (automation prohibited) | "Go this way", "This feels better", naming a new frame |
| Agent selection · composition | **System** (agent-composer) | Wave construction, parallel dispatch decisions |
| Recording · persistence | **System** (harvest-loop) | Pattern extraction, FH signal storage, CATALOG updates |
| Quality gates | **System** (harness-doctor etc.) | Skill health check, flow verification, BLOCK judgment |
| Final decisions | **Human** | Y/N approval, direction change, naming adoption |

---

## Environment Engineering

What FH does:

- **MEMORY.md keyword-trigger loading** → Agents receive only the knowledge they need. Rather than loading all memory at once, only entries matching conversation keywords are lazy-loaded to prevent attention fragmentation.
- **Context Card mandatory injection** → Before parallel dispatch, session context (purpose · completed items · this agent's task · caveats) is inserted into each agent brief. Eliminates sub-agent orientation tax.
- **Domain knowledge pre-injection** → Reduces the cost of agents learning the domain upfront. Skips the discovery round where agents figure out "what is this codebase."

**Core principle**: "Not making agents smarter — making the environment easier for agents to work in."

---

## Execution Tiers

| Tier | Name | Agent Scope | Tokens |
|:---:|---|---|:---:|
| **light** | light | No agents — direct MD Read/Edit | ~5K |
| **standard** | standard | Single FH internal skill dispatch | ~15K |
| **full** | full | Multiple parallel dispatch + synergy detection | ~30K |
| **max** | max | Full cycle — Three-Doctor Loop + full harvest | ~60K+ |

- **FH default**: `standard` — optimal token-to-value ratio
- **Developer environment**: `max` — no token limits, full deployment
  * The max setting is intended for the harness developer environment. General users should use `standard` (default).

---

## Core Gate Details

### Step 0-a Clarifying Question Principle

Ask only when: **what the human must provide (direction · insight · decision) is unclear**.
Execution method · agent selection · record location are inferred and executed — no asking.

### Step 4-c Auto-Record Gate Conditions

| Condition | Auto Action |
|---|---|
| 2+ new files or 3+ changes | Run harvest-loop lightweight automatically |
| Architecture or direction decision made | "Record this decision?" confirmation → memory save |
| Neither applies | Fall back to field-harvest proposal |

harvest-loop lightweight = `field-harvest → contention-layer → verify-bidirectional` (skip synthesizer·harness-doctor, ~3 min)

### Step 6 Proactive Proposal Triggers

| Detection Condition | Auto-Proposed Skill |
|---|---|
| FH · CLAUDE.md · rules files **2+ modified** | `harness-doctor` auto-run (after user confirmation) |
| New skill or plugin added | `cross-ecosystem-synergy-detection` |
| Significant artifact completed (draft or design done) | `steel-quench` |
| No frontier-digest today + large session | `frontier-digest` |
| None of the above | "Ready for next session" — no forced proposals |

Rule: **propose only 1** — multiple proposals create choice burden.

---

## Related Files

- agent-composer SKILL: `plugins/fh-meta/skills/agent-composer/SKILL.md`
- harvest-loop SKILL: `plugins/fh-meta/skills/harvest-loop/SKILL.md`
- harness-doctor SKILL: `plugins/fh-meta/skills/harness-doctor/SKILL.md`
- contention-layer SKILL: `plugins/fh-meta/skills/contention-layer/SKILL.md`
- context-doctor SKILL: `plugins/fh-meta/skills/context-doctor/SKILL.md`
- sim-conductor SKILL: `plugins/fh-meta/skills/sim-conductor/SKILL.md`

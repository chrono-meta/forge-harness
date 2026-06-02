---
name: context-bridge-dispatch
description: >-
  DEPRECATED — merged into agent-composer Step 3-a (2026-06-02).
  Context Card injection (N≤2 standard / N≥3 Registry mode) + coordination-overhead budget + Focus Mode
  are now part of agent-composer Step 3. Invoke /agent-composer for parallel dispatch.
user-invocable: false
allowed-tools: []
model: sonnet
deprecated: true
deprecated_reason: absorbed into agent-composer Step 3-a
deprecated_date: 2026-06-02
successor: agent-composer
---

# context-bridge-dispatch — DEPRECATED

> **Merged into `agent-composer` Step 3-a (2026-06-02).**
> Context Card injection, Registry mode, coordination-overhead budget, and Focus Mode are now part of agent-composer Step 3.
> Use `/agent-composer` for all parallel dispatch with context injection.

## Content preserved at

`plugins/fh-meta/skills/agent-composer/SKILL.md §Step 3-a`

---

# context-bridge-dispatch — Parallel Agent Context Bridge (archived)

In agent dispatch, sub-agents can read files but do not have access to the live conversation context of the main session. This skill generates a session context card before dispatch and injects it into each agent prompt.

## Triggers

| Phrase pattern | Situation |
|---|---|
| "do it in parallel" / "agent view" + 2+ tasks | Auto-triggered |
| "create a context bridge" | Explicit call |
| `/context-bridge-dispatch` | Explicit call |
| Immediately before dispatching 2+ agents | Auto-injected |

## Context Card Format

**N≤2 (standard)**:
```
[Session Context Card]
Purpose: {the goal of this session / task}
Completed: {what has already been decided or implemented — risk of duplication if agent doesn't know}
This agent's task: {the specific task for this agent}
Note: {constraints, directions, or history the agent must know before acting}
```

**N≥3 (Registry mode — DACS-inspired)**:
```
[Session Context Card]
Purpose: {session goal}
Completed: {done items + file paths}
This agent's task: {specific task}
Note: {constraints}

[Agent Registry]
Agent-1 ({role}): {≤1 sentence — what it's doing, key files}
Agent-2 ({role}): {≤1 sentence}
... (all agents except this one)
```

Registry entries keep other agents visible (≤200 tokens total) without flooding context.
Each agent gets its own full card + compressed view of the parallel picture.

## Step 1. Extract Session Context

Summarize the 3 key items from the current conversation:
- **Purpose**: Core goal of this session / request
- **Completed**: What has already been built or decided (include file paths and commits)
- **Note**: Constraints that could lead an agent in the wrong direction if unknown

## Step 2. Identify Agent List + Generate Individual Cards

For each of the N agents to dispatch:
- Common Context Card (Step 1 summary)
- Agent-specific item (`This agent's task` field customized per agent)

**N≥3 — Registry mode**: additionally generate one Registry entry per agent:
```
Agent-X ({role}): {what it's doing in ≤1 sentence} | files: {key paths}
```
Each agent's card includes the Registry entries for all *other* agents (omit its own).
Keep total Registry section ≤200 tokens. If an agent's task is simple (read-only lookup), its registry entry can be a single phrase.

## Step 3. Execute Parallel Dispatch

Prepend the Context Card to each agent's prompt and dispatch as a single message.

```
[Session Context Card]
...

{Agent's original task instruction}
```

## Focus Mode (on-demand, N≥3)

When an agent's result is incomplete and it signals it needs another agent's full output:
1. Orchestrator identifies the target agent (a_i) whose full context is needed
2. Re-dispatch the requesting agent with: full Context Card of a_i + Registry-compressed entries for all others
3. Use only when genuinely needed — adds one round-trip latency

Trigger signal from agent: `"Need full context from Agent-X to proceed"` or equivalent explicit statement.

## Coordination-Overhead Budget

Centralized multi-agent coordination is not free: external reporting cites orchestrator-worker coordination adding ~+285% token overhead (see the digest Provenance), and coordination cost dominates once a wave exceeds ~4 agents. Apply the following before each dispatch wave.

| Rule | Constraint |
|---|---|
| **Parallel fan-out cap** | 3–4 agents per dispatch wave. This is the upper bound for the 2+ parallel dispatch in the Simplification Guard — do not flat-fan-out past 4. |
| **Capability-aware routing** | Route each subtask to the agent whose declared capability fits, reading `.claude/registry/agent_cards.json` as the routing source (`role` + `allowed_tools` + `writes`). Do not dispatch a `writes: false` audit agent (e.g. `fact-checker`, `hub-persona-auditor`) for a task needing edits. |
| **Escalation** | If a task genuinely needs >4 parallel agents, decompose hierarchically (supervisor → sub-waves) rather than flat fan-out. |

Source: `../../../../knowledge/shared/harness-core/harness_frontier_diagnosis_2026-06-02.md`

## Step 4. Aggregate Results

After all agents complete, consolidate results in the main session and report to the user.

## Simplification Guard

- Simple file lookup agents unrelated to context (e.g., "read file A") → card may be omitted
- Single agent dispatch → card injection optional
- 2+ parallel dispatch → card injection required

## Why This Is Necessary

Agents are spawned in an isolated environment (sub-agent sandbox). They can read what is recorded in files, but decisions made during the current main session conversation — direction changes, completed implementations, design intent — do not exist for the agent unless saved to a file.

Problems this disconnection causes:
- Attempting to redo already completed work
- Working in the old direction without knowing the current session's direction change
- Making wrong decisions without knowing the constraints

Context Bridge corrects this asymmetry.

## Done When

```
All steps 1–4 completed
+ Context Card injected at the front of each agent prompt
+ Results aggregated and reported after all agents complete
```

## Connected Skills

| Situation | Connection |
|---|---|
| Context collapse risk after a long session | `/context-doctor` |
| Task of promoting field patterns to FH | `/field-harvest` |
| When agent orchestration itself is complex | `agent-composer` |
| N≥3 agents / long-running orchestration (context drifts post-dispatch) | See sister asset: DACS (arXiv:2604.07911) — Registry+Focus dynamic isolation |

## Design Basis

Registry mode and Focus mode patterns absorbed from **DACS** (arXiv:2604.07911, Nickson Patel, 2026-04-09).
DACS validated: steering accuracy 98.4% vs 21% baseline at N=10; context efficiency 3.53×.
Cross-audit + import/propagate analysis: `tracks/_audit/session_2026-06-02_dacs-sister.md`

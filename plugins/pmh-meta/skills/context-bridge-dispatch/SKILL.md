---
name: context-bridge-dispatch
description: Injects a session context card into each agent prompt before parallel dispatch, preventing context blindness when agents can only read files but not the live session history.
user-invocable: true
allowed-tools: ["Bash", "Read", "Write", "Agent"]
model: sonnet
---

# context-bridge-dispatch — Parallel Agent Context Bridge

In agent dispatch, sub-agents can read files but do not have access to the live conversation context of the main session. This skill generates a session context card before dispatch and injects it into each agent prompt.

## Triggers

| Phrase pattern | Situation |
|---|---|
| "do it in parallel" / "agent view" + 2+ tasks | Auto-triggered |
| "create a context bridge" | Explicit call |
| `/context-bridge-dispatch` | Explicit call |
| Immediately before dispatching 2+ agents | Auto-injected |

## Context Card Format

```
[Session Context Card]
Purpose: {the goal of this session / task}
Completed: {what has already been decided or implemented — risk of duplication if agent doesn't know}
This agent's task: {the specific task for this agent}
Note: {constraints, directions, or history the agent must know before acting}
```

## Step 1. Extract Session Context

Summarize the 3 key items from the current conversation:
- **Purpose**: Core goal of this session / request
- **Completed**: What has already been built or decided (include file paths and commits)
- **Note**: Constraints that could lead an agent in the wrong direction if unknown

## Step 2. Identify Agent List + Generate Individual Cards

For each of the N agents to dispatch:
- Common Context Card (Step 1 summary)
- Agent-specific item (`This agent's task` field customized per agent)

## Step 3. Execute Parallel Dispatch

Prepend the Context Card to each agent's prompt and dispatch as a single message.

```
[Session Context Card]
...

{Agent's original task instruction}
```

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

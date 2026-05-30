---
name: agent-composer
description: Reads the current work context and plans the optimal agent dispatch. Clarifies direction with 1-2 questions when unclear; infers and proceeds immediately when execution path is unclear. Runs an automatic recording gate after each Wave completes. Triggered by "compose agents", "which agent should I use?", "run in parallel", or "agent-composer".
user-invocable: true
allowed-tools: ["Read", "Bash", "Glob", "Grep"]
model: opus
---

# agent-composer — Agent Composition Layer

A coordinator skill that reads the work context and decides "which agents to dispatch, when, and in what order."
Selects the optimal combination from the FH skill pool and either outputs a fan-out plan or executes it directly.

## Triggers

- `/agent-composer`
- "Which agent should I use?", "Pick one automatically", "Compose the agents"
- "Set up the agents", "Decide which agents to use"
- "Split the work and run in parallel", "Process with multiple agents"
- "Build the dispatch plan", "Run in parallel splits"
- When the task is complex or spans multiple projects

## Core Principles

- **Compose only**: Does not perform work directly. Outputs the dispatch plan and executes after user approval.
- **Parallel first**: When 2+ tasks are independent, propose parallel fan-out instead of sequential.
- **Minimal composition**: Only the agents needed. Over-provisioning agents creates inefficiency.
- **Coordinator ≠ executor**: Only collects results (fan-in) and presents an integrated report.

---

## Step 0. Context Collection

Identify the following 4 items from the user's request.

1. **Task type**: Meta/audit/simulation / field work / cross-project / single file review
2. **Scope**: File · project · entire harness
3. **Constraints**: Time sensitivity / approval required / specific agents to exclude
4. **Natural-language goal → skill auto-mapping** (parsing layer)

### Natural Language Pattern Parsing

When a request arrives as natural language without an explicit skill call, use the mapping table below to automatically determine the recommended agent.

| Natural language pattern | Mapped agent | Rationale |
|---|---|---|
| "report", "persuade", "review", "approval", "team lead", "executive", "CTO" | apex-review | Decision-maker simulation |
| "install skill", "install plugin", "setup" | install-wizard / plugin-recommender | Onboarding |
| "code review", "PR review", "check diff" | sim-conductor (D-code) | Code validation |
| "diagnose", "something feels off", "structural check" | harness-doctor | Structural diagnosis |
| "simulation", "scenario", "validate" | sim-conductor | Meta-simulation |
| "let's name it", "naming", "new frame" | persona-innovator (separate FH skill) | Naming exploration |

Mapping results are merged with the Step 1 composition table into the final dispatch plan.

### cross-install Detection

If an external plugin (e.g., fe-marketplace) is installed in the current cwd, include that plugin's skill triggers in the mapping as well.

- Detection method: Check installed plugin list in `.mcp.json` or `CLAUDE.md`
- Example: If `deep-insight` is installed → automatically include for "multi-perspective review" requests
- Example: If `glossary` from `fe-marketplace` is installed → automatically include for "define terms" requests
- If cross-install skills are detected, mark "(external plugin included)" at the top of the Step 2 composition plan

### LOCAL_SKILL_REGISTRY Lookup (Project-local skills)

Non-plugin project-local skills are checked in `LOCAL_SKILL_REGISTRY.md`.

- **Location**: `.claude/registry/LOCAL_SKILL_REGISTRY.md` (relative to FH root)
- **When to look up**: When the request is related to a specific project

```
LOCAL_SKILL_REGISTRY lookup → extract skill list for relevant project
  → "inline capable": directly dispatchable via Agent tool
  → "requires cwd": must specify cwd path in agent brief
```

Mark "(local skills included)" in Step 2 composition plan.

When context is insufficient:
> **What task should I compose?**
> Provide the task content, scope, and urgency to get the optimal combination.

---

## Step 0-a. Clarification Protocol

> Execution condition: Only when direction or goal is unclear (skip → go directly to Step 0-b if clear)

**Core principle**: Only ask when what the person must provide (direction · insight · decision) is unclear.
Execution method · agent selection · recording location → infer and proceed — do not ask.

### Direction vs. Execution Decision Table

| Request type | Classification | Action |
|---|---|---|
| "Do X" — target and completion criteria are clear | Clear | Immediately enter Step 0-b |
| "Improve X" — improvement dimension unclear | Direction unclear | Ask for clarification |
| "Something feels off" — diagnosis target unclear | Execution unclear → infer | Auto-dispatch harness-doctor |
| "Run the pipeline" — trigger is clear | Clear | Run harvest-loop based on recent work |
| No request — session context exists | Execution unclear → infer | Auto-compose based on CATALOG/MEMORY, then confirm |

### Clarification Format (maximum 2 questions)

When direction ambiguity is detected:

```
Direction clarification needed.
1. Completion criteria: What does [X] look like when it's done?
   (Inference: [inferred criteria] — confirm if correct)
2. Scope: Which of [A / B / C] should take priority?
```

Rules:
- Maximum 2 questions (direction and decision related only)
- Present inferable items as `(Inference: [X] — confirm if correct)`
- Minimize choices using options (A/B/C)

### 4-Question Structured Confirmation (when both direction and completion criteria are unclear)

If direction and completion criteria are both unclear (unresolvable with the 2 questions above), use the 4 structured questions before running the pipeline.

```
Structured confirmation needed before composition.
1. What is the final state you want to achieve with this task?
2. Describe the completion criteria in one sentence.
3. Is there anything that must absolutely not be done?
4. Is there a time estimate or deadline?
```

→ Proceed with composition plan (Step 0-b → Step 1) after receiving all 4 answers.

**Usage criteria**: Skip the 4-question block if 2 questions suffice. Use the 4-question block only for "completely new tasks" / "full cross-project scope unclear" / "request is under 1 sentence". Do not overuse.

### Meta-Prompting Intervention (over-specified prompt detection)

When the person writes a procedural prompt → suggest switching to AI-friendly meta-prompting.

**Detection signals**:
- Numbered step-by-step instructions: "1. do this, 2. do that, 3. do this"
- Excessive path/method/filename specification (specifying AI execution details)
- "Do it like this: [detailed procedure]" pattern — specifying method instead of goal

**Why it's a problem**: When human cognitive patterns are fed directly into the AI engine, the AI abandons better paths and follows the spec. Over-specification removes the AI's reasoning space and lowers quality.

**Intervention format**:

```
Meta-prompting recommended.
  Current: [summary of procedural spec]
  Suggestion:
    Goal: [core objective in 1 line]
    Done When: [completed state]
    Constraints: [real constraints only — remove method specs]

  Optimize with meta-prompt-builder? (Y: switch to meta version / N: proceed as-is)
```

User selects N → allow execution as originally specified (respect user decision).
**Simplification guard**: Skip intervention for single-file edits or clearly-stated fix requests.

---

## Step 0-b. Wave 0 — Reconnaissance Dispatch (Mandatory Before New Tasks)

> Execution condition: For cross-project tasks or when scope is unclear. Skip for single-project tasks with clear scope.

This orchestrator does not read files or understand structure directly — **even reconnaissance work is dispatched as agents.**

### Reconnaissance → Dispatch Order Principle

```
[Wrong order] Orchestrator reads files directly → understands structure → composes Wave 1
[Correct order] Dispatch Wave 0 recon agent → receive results → compose Wave 1
```

Wave 0 recon agent composition criteria:
- **File/directory structure understanding** → dispatch 1 recon agent (using Read · Glob · Bash)
- **Multiple project status check** → dispatch independent recon agents per project, in parallel
- **Single file read** → allowed exception for direct execution (recon overhead > benefit)
- **All tasks involving new assets** → mandatory prior dispatch of fact-checker (A)
  - fact-checker role: Proactively verify that the skill/file/pattern being added is not a duplicate or stale compared to existing assets
  - No need for the user to call this directly — agent-composer auto-dispatches in Wave 0
  - Direct call path: `.claude/agents/fact-checker.md` (Mode D)

### Self-Contained Brief Requirement

Each agent brief **does not assume shared context.** Depending on another agent's results or the orchestrator's context will cause the agent to behave incorrectly.

Required brief contents:
- Goal (1-2 lines of clear task description)
- Target files/paths (absolute paths or clear criteria)
- Expected output format
- When using deferred tools: explicitly state `ToolSearch query "select:tool_name"` must be run first

### Deferred ToolSearch Pre-Requisite

In Agent View environments, MCP tools (JIRA, Wiki, Slack, etc.) are loaded in **deferred** state. If MCP tools are needed in an agent brief, always specify the following pattern:

```
First call the ToolSearch tool to load the required tool schema:
  ToolSearch query "select:jira_search_issues"
Call the tool only after the schema is loaded.
```

Omitting this causes an `InputValidationError`.

---

## Step 1. Agent Mapping

Default composition table by task type:

> **Call method distinction**: `(S)` = Skill tool call / `(A)` = Background dispatch via Agent tool

| Task type | Default composition | Parallel |
|---|---|:---:|
| **[Wave 0] Recon (all tasks)** | Recon agent (A) — file/structure understanding. Direct orchestrator execution forbidden | — |
| **[Wave 0] All tasks including new assets** | fact-checker (A) — proactive duplicate/stale validation | — |
| Meta-simulation quality validation | sim-conductor (S) — devil-advocate + newcomer + power-user | ✅ Parallel |
| Field pattern harvest | field-harvest (S) | — |
| Harness structural diagnosis | harness-doctor (S) | — |
| New asset placement decision | asset-placement-gate (S) | — |
| External user entry point audit | hub-persona-auditor (A) | — |
| Naming/innovation scan | persona-innovator (A) | — |
| Cross-project simultaneous work | N field agents (A) | ✅ Parallel |
| Three-Doctor Loop | harness-doctor (S) + context-doctor (S) + sim-conductor (S) | ✅ Parallel |
| Pre-PR code review | sim-conductor D-code 3 personas (S) | ✅ Parallel |
| Learning cross-validation | verify-bidirectional (S) | — |
| Ecosystem synergy exploration | cross-ecosystem-synergy-detection (S) | — |
| Plugin recommendation | plugin-recommender (S) — output: recommendation list (installation requires separate user approval) | — |
| Install conflict diagnosis | install-doctor (S) | — |
| Onboarding install | install-wizard (S) — normal mode: ⚠️ interactive, place alone at end of Wave / `--dry-run`: bg parallel possible | — |
| Hub PR review | hub-cc-pr-reviewer (S) — requires PR number first | — |
| **Decision-maker approval review** | apex-review (S) — CTO/tech lead/QA lead/conference organizer personas + HTML deck generation | — |
| **Project local skills** | LOCAL_SKILL_REGISTRY lookup → relevant project skill (A) / inline-capable skill (S) | Per project |

Complex tasks combine the above compositions. Example: "Field work + simulation validation" → Field agent(A) + 3 sim personas(S) → up to 6 bg parallel.

---

## Step 2. Composition Plan Output

```
agent-composer — Composition Plan
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Task: {task summary}
  Composition: {N} agents  |  Parallel: {Y/N}  |  Estimated time: ~{N} min

  Wave 0 (Recon):
    [R] Recon agent — {file/structure understanding goal}  ← direct orchestrator execution forbidden

  Wave 1 (Parallel):
    [A] {agent name} — {role in 1 line}
    [B] {agent name} — {role in 1 line}
    [C] {agent name} — {role in 1 line}

  Wave 2 (after Wave 1 completes):
    [D] {agent name} — {executed after result integration}

  fan-in: integrate results after Wave completes → output report
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Execute? (Y: run all / E: edit then run / N: cancel)
```

---

## Step 2.5 — Model Routing Decision (complexity_routing)

Before dispatching, if each skill has a `complexity_routing` field, determine the Agent `model` parameter using the criteria below.

### Escalation Condition Evaluation

| Condition | Evaluation criteria |
|---|---|
| `cold_start` | First run after session start / MEMORY.md not loaded / no prior context |
| `cross_project` | Cross-cutting work across 3+ projects (tracks) |
| `adversarial` | steel-quench/devil/meta-devil mode active |
| `high_stakes` | Pre-external publish/deploy/PR merge/team lead presentation validation |
| `full_revalidation` | User requests "full re-review" or "start over" |
| `destructive` | Contains irreversible operations (push/force/delete/deploy/permission changes) |

### Routing Rules

1. Skill frontmatter has no `complexity_routing` → use `model:` field value as-is
2. `complexity_routing` present + any `escalate_when` condition matches current context → use `high` model
3. No conditions match → use `base` model

```
harness-doctor: cold_start detected → model: opus (normally: sonnet)
verify-bidirectional: high_stakes detected → model: opus (normally: sonnet)
```

Include a 1-line audit log in the composition plan output when routing is decided:

```
[Model routing] harness-doctor: cold_start detected → opus escalation
```

### Default Architecture — Base (Sonnet) + Amplified (Opus Orchestrator)

This is the **global orchestrator/executor** default, orthogonal to the per-skill `complexity_routing` above (which escalates individual skills). Two operating modes. **Base is the default** — no model upgrade required.

| Mode | Orchestrator | Executor | When |
|---|---|---|---|
| **Base** | sonnet | sonnet | Default — all tasks, no special trigger |
| **Amplified** | opus | sonnet | `EXECUTION_TIER: full/max` · plan mode active · `cross_project` + `high_stakes` both detected |

**Base**: Sonnet handles both composition and execution. Covers 80%+ of daily harness tasks at zero cost overhead.

**Amplified**: Opus takes the Brain role (goal parsing, Wave construction, gate decisions); Sonnet handles the Hands role (Agent dispatch, file reads, output). Matches Brain/Hands decoupling — Brain escalates to Opus, Hands stay on Sonnet.

Audit log when amplified:
```
[Model routing] orchestrator: opus (amplified — EXECUTION_TIER: full), executors: sonnet
```

**Simplification guard**: Single-Wave, single-project tasks → Sonnet sufficient. Do not escalate.

---

## Step 2.7 — Destructive Action Gate

After scanning the composition plan, if any of the following types are found, mark with 🚨 and output a separate warning before Step 3.

| Type | Examples |
|---|---|
| External send | git push/force, PR create/merge, Slack/wiki upload, email send |
| File/data destruction | rm -rf, DB DROP/DELETE, file overwrite, branch delete |
| Production impact | Service deploy, migration, permission/config changes |

If 🚨 items exist, insert the following before the standard Y/E/N in Step 3:

```
⚠️  Irreversible operations are included:
    - [type] [specific operation]

    Do you want to proceed? (yes / no — respond before Y/E/N)
```

`no` response → remove only that operation from the plan or cancel entirely. Safe remaining operations can continue.

---

## Step 3. Approval → Execution

After user approval, dispatch background agents via the Agent tool.

- **Y**: Execute the composition plan immediately. Parallel agents are dispatched simultaneously in a single message.
- **E**: User modifies the plan then re-confirms. Adding/removing agents and changing order are allowed.
- **N**: Cancel. Keep the composition plan for reference only.

### Step 3.1 — Worktree Isolation (Parallel Proposal Mode)  ← v1.2: harness-evolver pattern

When parallel agents in the same Wave may write to the same files (e.g., proposing alternative SKILL.md drafts, competing harness designs, parallel feature patches), use **git worktree isolation** to prevent file conflicts and keep each proposal on a clean branch.

**Activation condition**: 2+ agents in the same Wave targeting overlapping file paths, where each agent produces independent candidate outputs (not just reads).

**Execution pattern**:

```
1. Before dispatch: create an isolated worktree per agent
   EnterWorktree(branch="proposal/{agent-name}-{slug}")
   → each agent operates on its own branch, no shared file state

2. After Wave completes: fan-in results from each worktree
   → compare outputs across branches
   → winning proposal cherry-picked or merged to main branch
   → losing worktrees discarded (auto-cleaned if unchanged)

3. Composition plan output adds worktree marker:
   [A] {agent name} — {role}  [worktree: proposal/A-{slug}]
   [B] {agent name} — {role}  [worktree: proposal/B-{slug}]
```

**When to skip**: Read-only agents (recon, fact-checker), single-agent Waves, or agents targeting disjoint files → standard dispatch (no worktree overhead).

**Tool prerequisite**: `EnterWorktree` / `ExitWorktree` tools must be available (Claude Code native). Check with `ToolSearch query "select:EnterWorktree"` before dispatching worktree-isolated agents.

---

## Step 3.5 — Inter-Wave Adaptation Check (Runtime Adaptation)

Immediately after Wave N completes and before Wave N+1 executes, evaluate the following 3 items.

### Evaluation Items

**① Premise Reversal Detection**
Does Wave N's result reverse a premise of Wave N+1?
- Example: Wave 1 investigation reveals Wave 2's direction was wrong
- If detected → immediately revise Wave N+1 agent composition/order/goal, then confirm with user

**② Repeated Failure Detection**
Did the same agent fail 2+ times in Wave N?
- If detected → exclude that skill from Wave N+1 and suggest a replacement skill

**③ Early-Harvest Trigger**
Were 3+ new patterns discovered in Wave N?
- If detected → immediately suggest mid-session harvest: "Run a mini-harvest before session ends?"
- If Y → run Step 4-c lightweight mode immediately, then resume Wave N+1

### Adaptation Check Output Format

```
[Step 3.5 — Wave Adaptation Check]
  ① Premise reversal: {none / detected → Wave N+1 revision}
  ② Repeated failure: {none / {agent name} failed 2x → alternative: {replacement skill}}
  ③ Early-harvest: {none / {N} patterns detected → mini-harvest suggested}

  → Wave N+1 revision exists: (Y: apply revision and proceed / E: revise manually / N: proceed as planned)
```

**"Runtime self-modification" FH implementation**: Adaptation at the Wave level, not the token level.
Wave = FH execution unit; Wave-level strategy revision is functionally equivalent to runtime self-modification.

**Simplification guard**: Skip Step 3.5 for simple tasks with only one Wave (Wave 0 + Wave 1).

---

## Step 4. fan-in — Result Integration

After all agents complete:

> **M/S/R tier criteria** (shared with sim-conductor system):
> - **M (Mandatory)**: Blocks external user entry / structural conflict / requires immediate action
> - **S (Strong)**: Feature degradation / important confusion point / address within next session
> - **R (Recommended)**: Improvement value / backlog

### fan-in Report Minimum Contract (loom fan-in contract — Wave result integration spec defined by loom)

Each finding returned by an agent must satisfy the following 3-field format as a minimum unit.
Results that do not meet this format cannot enter Wave 4 judgment — mark that agent's result as "format non-compliant" and re-request or skip.

```
| tier | location | fix suggestion |
|------|----------|----------------|
| M    | plugins/fh-meta/skills/foo/SKILL.md:12 | change "bar" to "baz" |
| S    | CLAUDE.md:L45 section | description needs strengthening |
```

- **tier**: One of M / S / R (required)
- **location**: File path + line or section (required)
- **fix suggestion**: Specific action in 1 line (required)
- 1 finding = 1 row. Separate multiple fixes into individual rows.

1. Integrate each agent's results into M/S/R tiers (remove duplicates, M takes priority)
2. Output overall completion report
3. If M-tier exists, suggest immediate action / otherwise summarize S/R backlog

```
agent-composer — Complete
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Executed: {N}  |  Time: ~{N} min  |  Parallel gain: {N}x vs sequential
  M: {N} items → [action suggestion]
  S: {N} items → backlog
  R: {N} items → backlog
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Step 4-b. State Transition Gate

After outputting the fan-in completion report, evaluate the conditions below and automatically suggest the next Wave.

| Condition | Wave suggestion | Content |
|---|---|---|
| ① M-tier > 0 | **Wave next-M** | fact-checker (A) stale validation → hub-cc-pr-reviewer (S) PR plan |
| ② persona-innovator naming candidates > 0 | **Wave next-I** | Delegate decision to user + asset-placement-gate (S) |
| ③ External absorption signal High applicability > 0 | **Wave next-E** | persona-innovator Mode E (A) + meta-prompt-builder (S) |
| ⑤ Design decision conflict or 2+ conflicting suggestions | **Wave next-D** | deliberation (separate FH skill) (S) — 3-layer default / 5-layer jury option; **after deliberation Done When: fold synthesis verdict back into fan-in result set → re-run Step 4-b state transition with conflict marked resolved** |
| ④ All of ①②③⑤ are 0 | **End** | Output "backlog only, defer to next session" then complete |

```
agent-composer — State Transition Evaluation
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ① M-tier: {N} items → Wave next-M {Y/N}
  ② Naming candidates: {N} items → Wave next-I {Y/N}
  ③ External absorption signals: {N} items → Wave next-E {Y/N}
  ⑤ Design conflicts: {N} items → Wave next-D {Y/N}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Run additional Wave? (Y: execute suggested Wave / N: end)
```

**Wave next-I caution**: Naming adoption decisions must not be automated — the user makes the final decision.
**Wave next-E caution**: External absorption results also require user approval before being reflected in assets.
**Wave next-D caution**: deliberation final judgment also completes with user decision. Auto-execution forbidden.

---

## Step 4-c. Auto-Recording Gate

Run the following conditions after Wave 4 PASS.

### Auto-Trigger Conditions

| Condition | Auto action |
|---|---|
| 2+ new files created or 3+ existing files changed, **or M-tier resolution decision made** | Run harvest-loop lightweight mode automatically (field-harvest → contention → verify-bidirectional, skip synthesizer) |
| Architecture/direction decision made (judgment: M-tier resolved or major decision documented) | "Record this decision? [1-line summary]" — save to memory after confirmation (run simultaneously with harvest-loop lightweight mode) |
| None of the above conditions apply | Fall back to existing field-harvest proposal (user choice) |

### Auto-Recording of Wave Execution Results

Auto-record in `tracks/_meta/agent_run_YYYYMMDD_{slug}.md` each time a Wave completes.

**Recording format**:

```markdown
---
date: YYYY-MM-DD
wave_count: N
slug: {task summary slug}
---

## Wave N — {Wave purpose}
- Agents executed: {agent name list}
- Completed at: {HH:MM}
- Result summary:
  - {agent A}: {1-line result}
  - {agent B}: {1-line result}
- Failed agents: {none / agent name + failure reason}
```

**Trigger conditions**:
- Always record when Wave 1 or higher completes (exclude Wave 0 recon-only completion)
- Record even if agents failed (include failure reason)
- If `tracks/_meta/` directory does not exist → skip + output R-tier warning

**Auto-recording allowed scope**: File change lists and agent execution results can be auto-recorded. Decision content and naming require user confirmation before recording.

### harvest-loop Lightweight Mode (mid-session)

Runs only Steps 1→2→5 of the standard harvest-loop. Skip Step 3 (devil/innovator parallel), Step 3.5 (synthesizer), Step 4 (harness-doctor).

```
[mid-session harvest] field-harvest → contention-layer → verify-bidirectional
Time: ~3 min (50% reduction vs full loop)
```

### Human Decision Gate

- **Recording content decisions** (what to record and where): Show summary then get confirmation — no auto-save
- **Naming/direction decisions**: User confirmation required — auto-execution forbidden
- **Pipeline execution results** (file change lists, M/S/R aggregates): Auto-recording allowed

---

## Step 5. Wave 4 — Final Judgment Gate

Execute final merge judgment after all of Waves 0~3 (recon/parallel execution/fan-in/state transition) complete.

### Entry Conditions

- All stages of Waves 0~3 complete (including state transition evaluation output)
- PR creation or change history exists

If entry conditions are not met, auto-skip Wave 4 — do not apply to simple exploration or planning tasks.

### Judgment Logic

```
IF M-tier == 0 AND S-tier < 3:
    → PASS  (merge approved)
ELIF M-tier >= 1:
    → BLOCK (immediate fix required)
ELSE:  # M-tier == 0 AND S-tier >= 3
    → PASS  (S-tier allows backlog — not a merge block reason)
```

**PASS condition**: 0 M-tier + fewer than 3 S-tier → merge approved
**BLOCK condition**: 1+ M-tier → merge blocked (requires immediate fix regardless of S/R tier)
**PASS (S boundary)**: 0 M-tier + 3+ S-tier → merge approved + S-tier backlog carryover noted

### Judgment Output Format

```
[Wave 4 Judgment] PASS — 0 M-tier, {N} S-tier deferred to backlog
[Wave 4 Judgment] BLOCK — {N} M-tier remaining, fix and re-validate required
```

Fixed format: 1 judgment line + 1 rationale line. Detailed items were already output in Step 4 fan-in report — no duplication.

### Auto-Proposal After Judgment

| Judgment result | Auto-proposal |
|---|---|
| **PASS** | field-harvest skill proposal — "Are there patterns to harvest from this Wave?" |
| **BLOCK** | Fix the M-tier items → suggest re-entry into Wave 1 (re-validation loop) |

**Reason for field-harvest proposal after PASS**: Mergeable state = optimal timing for pattern harvest. Resolved issues and decisions can be fed back as harness improvement candidates.

```
agent-composer — Wave 4 Final Judgment
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  [Wave 4 Judgment] {PASS / BLOCK}
  Rationale: {M-tier {N} / S-tier {N} / judgment summary 1 line}

  {If PASS}  → field-harvest proposal: harvest patterns from this Wave?
  {If BLOCK} → fix M-tier items then re-enter Wave 1.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Phase Guard Pattern (Stage Entry Gate managed by loom)

Waves with logical dependencies cannot run in parallel and enforce ordering. (Pattern named by loom — a FH internal skill responsible for pattern harvesting and Wave version management — this is the principle that guarantees ordering for causally related stages.)

| Dependency | Rule |
|---|---|
| Wave 0 (recon) not complete | Cannot enter Wave 1 (parallel execution) |
| Wave 2 (fan-in) not complete | Cannot enter Wave 4 (final judgment) |
| State transition evaluation (Step 4-b) not complete | Cannot enter Wave next-M/I/E/D |

**Application principle**: Maximize parallel fan-out among independent agents, but ensure dependent stages wait for prior Wave completion before entering. Running causally ordered Waves in parallel breaks result consistency.

## Step 6. Round Wrap + Proactive Next Step

Execute after Wave 4 PASS + Step 4-c recording complete.

### 6-1. Completion Summary (3 lines)

Output a 3-line summary of what was completed after all Waves finish.

```
agent-composer — Round Completion Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ① {major completed task 1}
  ② {major completed task 2}
  ③ {major completed task 3 or "no issues confirmed"}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 6-2. Next Round Suggestions (maximum 3)

Suggest up to 3 "tasks that can continue in the next round" discovered from this Wave's results.
Only items the user selects Y for are included in the backlog or next composition (dropped if N).

```
Next round candidates:
  [1] {task name} — {reason in 1 line}
  [2] {task name} — {reason in 1 line}
  [3] {task name} — {reason in 1 line}  (omit if none)

  Select items to continue (Y/N or number): ___
```

Rules:
- If there are no clear follow-up tasks, omit suggestion (output "no follow-up tasks")
- Even if there are more than 3 candidates, suggest only the top 3 by priority (minimize choice burden)

### 6-3. fh_signal Persistence Confirmation

If any of the following conditions apply, confirm with the user whether to persist as fh_signal.

| Condition | Confirmation content |
|---|---|
| New skill/pattern discovered | Record in `tracks/_meta/fh_signal_YYYYMMDD.md`? |
| Design decision made (including M-tier resolution) | Persist decision summary as fh_signal? |
| None of the above | Skip persistence confirmation |

```
fh_signal persistence: [discovered signal summary in 1 line]
  Record? (Y: save to tracks/_meta/fh_signal_{date}.md / N: skip)
```

### 6-4. Proactive Suggestion Priority

| Situation detected | Proactive suggestion | Reason |
|---|---|---|
| 2+ FH/CLAUDE.md/rules files (SKILL.md/CLAUDE.md/rules/*.md) modified | `harness-doctor` **auto-run (after user confirmation)** | Structural change → health re-check |
| New skill/plugin added | `cross-ecosystem-synergy-detection` run | Synergy update needed |
| Important artifact completed (draft/document/design done) | `steel-quench` proactive suggestion | Risk of FAIL without validation |
| No frontier-digest today + large session scale | `frontier-digest` suggestion | Good timing to check frontier gap |
| None of the above | Output "ready for next session" | Do not force unnecessary suggestions |

```
Next action suggestion:
  → [{skill name}] {reason in 1 line}
     Execute? (Y: now / N: next session / skip: omit)
```

Rules:
- **Suggest only 1** — multiple suggestions create choice burden for the user
- If priority #1 condition applies, suggest only that one
- If user selects N or skip, add to backlog and end

---

## Execution Tier

Select tier by token cost and task scale. FH default = **standard**.

| Tier | Tokens | Scope | Behavior |
|:---:|:---:|---|---|
| **light** | ~5K | No agents — direct MD Read/Edit | Wave 0 + Wave 1 single → output → end |
| **standard** | ~15K | Single FH skill dispatch (context-doctor/harness-doctor, etc.) — 80% effect at 25% tokens | Wave 0 + Wave 1 multi → fan-in → one proactive suggestion |
| **full** | ~30K | Cross-plugin synergy + parallel dispatch (includes cross-ecosystem-synergy-detection) | + Wave N state transition → conditional lightweight harvest |
| **max** | ~60K+ | LOCAL_SKILL_REGISTRY + external git + full synergy recalc — session-end/architecture decisions only | + Three-Doctor Loop → full harvest-loop → next Wave follow-up |

Configure via `EXECUTION_TIER: standard` in CLAUDE.md or `.claude/settings.json`. Temporary override: say "use light mode this time" / "run at max" for the current session only. Main dev env default = max (no restrictions).

---

## Simplification Guard

- Single-agent tasks → guide user to call that skill directly (skip agent-composer)
- Risk of two agents editing the same file in the same Wave → recommend Wave separation

### Fan-out Scale Tiers

| Tier | Count | Behavior |
|---|---|---|
| **Small** | 2–5 | Standard — dispatch immediately |
| **Medium** | 6–16 | Confirm scale before dispatch (Opus 4.8 Dynamic Workflow validated this range as practical) |
| **Large** | 17+ | Worktree isolation mandatory + explicit user approval required |

- Fan-out ≤ 5 → proceed immediately
- Fan-out 6–16 → confirm "is this scale appropriate?" before dispatching
- Fan-out 17+ → gate: "This is Large-tier fan-out. Worktree isolation will be applied. Proceed?"

## Invocation Triggers

- `/agent-composer`
- "Which agent should I use?", "Pick automatically", "Compose", "What's the optimal combination?"
- "Set up the agents", "Decide which agents to use"
- "Split the work and run in parallel", "Process with multiple agents"
- "Build the dispatch plan", "Run in parallel splits"
- Auto-propose when task context is complex or involves 2+ projects

## Done When

```
All stages Step 0~6 complete
+ Wave composition plan finalized + execution complete
+ fan-in loom complete: M-tier 0 AND S-tier < 3 → PASS
  or user has confirmed Wave end
+ Auto-recording gate (Step 4-c) complete (lightweight harvest-loop run status confirmed)
```

> **Sprint Contract**: Done When must be in an externally verifiable contract format — specified as "criteria a third party can confirm," not "when it feels done." (Anthropic official validation 2025)

## Agent Composition Layer Identity

agent-composer is the FH **coordinator** above specialist agents (sim-conductor/field-harvest/harness-doctor, etc.) — it decides "which agent combination is optimal for this task." FH = composition layer (this) + specialist agent pool.

> Architecture basis: Anthropic [Harness Design for Long-Running Apps](https://www.anthropic.com/engineering/harness-design-long-running-apps) — single agent ($9, fails) vs. multi-agent harness ($200, perfect). Cost gap justified by quality gap.

### Automation Layer Division

The skill implements *"humans provide direction/insight, systems handle execution/recording"*:

| Human domain | System domain |
|---|---|
| What to build, why (direction + insight) | Which agents and how (composition + ordering) |
| Final adoption decision | Pipeline execution + result aggregation |
| Naming/framing | Recording + quality gates |

If something unclear is in the human domain, ask. If it's in the system domain, infer and proceed.

### Brain/Hands Decoupling (Anthropic Independent Convergence)

**Pattern**: Clear separation of composition (Brain) vs execution (Hands) — agent-composer is Brain-only.

- **Brain**: Goal parsing → skill mapping → Wave construction → gate decisions
- **Hands**: Agent tool dispatch → parallel execution → result collection → fan-in report

**Rationale**: Anthropic "Scaling Managed Agents" — Brain/Hands separation improves scalability, debugging, and maintainability.

### Curator Role (hermes-agent Convergence)

agent-composer also acts as Curator — surveys existing agents/skills/assets and proposes optimal combinations.

- **Curator mode**: Detects agent state (stale, pinned, deprecated) + proposes merge candidates for duplicate agents
- **External positioning**: Independent convergence with hermes-agent (Nous Research) curator.py pattern

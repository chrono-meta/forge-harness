---
name: agent-composer-detail
description: Detail file for agent-composer — format templates, bash scripts, edge cases. Load when executing a specific step.
load: on-demand
---

# agent-composer — Detail Reference

> Load when executing a specific step. SKILL.md contains triggers, principles, mapping tables, and Done When.

---

## §Step-0 — NL Pattern Parsing + Cross-Install + Registry Lookup

### Natural Language Pattern Parsing

| Natural language pattern | Mapped agent | Rationale |
|---|---|---|
| "report", "persuade", "review", "approval", "team lead", "executive", "CTO" | apex-review | Decision-maker simulation |
| "install skill", "install plugin", "setup" | install-wizard / plugin-recommender | Onboarding |
| "code review", "PR review", "check diff" | sim-conductor (D-code) | Code validation |
| "diagnose", "something feels off", "structural check" | harness-doctor | Structural diagnosis |
| "simulation", "scenario", "validate" | sim-conductor | Meta-simulation |
| "let's name it", "naming", "new frame" | persona-innovator | Naming exploration |

Mapping results merged with Step 1 composition table into final dispatch plan.

### cross-install Detection

If external plugin installed (check `.mcp.json` or `CLAUDE.md`), include that plugin's skill triggers in mapping.
- `deep-insight` installed → include for "multi-perspective review"
- `glossary` from `fe-marketplace` → include for "define terms"
- Mark "(external plugin included)" at top of Step 2 composition plan.

### LOCAL_SKILL_REGISTRY Lookup

```
LOCAL_SKILL_REGISTRY lookup → extract skill list for relevant project
  → "inline capable": directly dispatchable via Agent tool
  → "requires cwd": must specify cwd path in agent brief
```

Mark "(local skills included)" in Step 2 composition plan. Location: `.claude/registry/LOCAL_SKILL_REGISTRY.md`.

---

## §Clarification — Formats + Meta-Prompting Intervention

### Clarification Format (maximum 2 questions)

When direction ambiguity detected:

```
Direction clarification needed.
1. Completion criteria: What does [X] look like when it's done?
   (Inference: [inferred criteria] — confirm if correct)
2. Scope: Which of [A / B / C] should take priority?
```

Rules: Maximum 2 questions. Present inferable items as `(Inference: [X] — confirm if correct)`. Minimize choices.

### 4-Question Structured Confirmation

Use only for "completely new tasks" / "full cross-project scope unclear" / "request under 1 sentence":

```
Structured confirmation needed before composition.
1. What is the final state you want to achieve with this task?
2. Describe the completion criteria in one sentence.
3. Is there anything that must absolutely not be done?
4. Is there a time estimate or deadline?
```

Proceed with composition plan after receiving all 4 answers.

### Meta-Prompting Intervention (over-specified prompt detection)

**Detection signals**: Numbered step-by-step instructions · Excessive path/method/filename specification · "Do it like this: [detailed procedure]" pattern.

**Why it's a problem**: Over-specification removes the AI's reasoning space and lowers quality.

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
**Simplification guard**: Skip for single-file edits or clearly-stated fix requests.

---

## §Wave-0 — Self-Contained Brief + Deferred ToolSearch

### Self-Contained Brief Requirement

Each agent brief does not assume shared context. Required contents:
- Goal (1-2 lines of clear task description)
- Target files/paths (absolute paths or clear criteria)
- Expected output format
- When using deferred tools: explicitly state `ToolSearch query "select:tool_name"` must be run first

### Deferred ToolSearch Pre-Requisite

In Agent View environments, MCP tools (JIRA, Wiki, Slack) are loaded in **deferred** state. Always specify:

```
First call the ToolSearch tool to load the required tool schema:
  ToolSearch query "select:jira_search_issues"
Call the tool only after the schema is loaded.
```

Omitting this causes `InputValidationError`.

### Wave 0 Composition Criteria

- File/directory structure understanding → 1 recon agent (Read · Glob · Bash)
- Multiple project status check → independent recon agents per project, in parallel
- Single file read → allowed exception for direct execution (recon overhead > benefit)
- All tasks with new assets → mandatory fact-checker (A) in Wave 0

---

## §Model-Routing — Escalation Conditions + Default Architecture

### Escalation Condition Evaluation

| Condition | Evaluation criteria |
|---|---|
| `cold_start` | First run after session start / MEMORY.md not loaded / no prior context |
| `cross_project` | Cross-cutting work across 3+ projects (tracks) |
| `adversarial` | steel-quench/devil/meta-devil mode active |
| `high_stakes` | Pre-external publish/deploy/PR merge/team presentation validation |
| `full_revalidation` | User requests "full re-review" or "start over" |
| `destructive` | Contains irreversible operations (push/force/delete/deploy/permission changes) |

### Amplified Mode Audit Log

```
[Model routing] orchestrator: opus (amplified — EXECUTION_TIER: full), executors: sonnet
```

---

## §Worktree-Isolation — Step 3.1 Parallel Proposal Mode

**Activation condition**: 2+ agents in same Wave targeting overlapping file paths, each producing independent candidate outputs.

**Execution pattern**:

```
1. Before dispatch: create isolated worktree per agent
   EnterWorktree(branch="proposal/{agent-name}-{slug}")
   → each agent operates on its own branch, no shared file state

2. After Wave completes: fan-in from each worktree
   → compare outputs across branches
   → winning proposal cherry-picked or merged to main branch
   → losing worktrees discarded (auto-cleaned if unchanged)

3. Composition plan output adds worktree marker:
   [A] {agent name} — {role}  [worktree: proposal/A-{slug}]
   [B] {agent name} — {role}  [worktree: proposal/B-{slug}]
```

**Tool prerequisite**: Check with `ToolSearch query "select:EnterWorktree"` before dispatching.
**When to skip**: Read-only agents (recon, fact-checker), single-agent Waves, agents targeting disjoint files.

---

## §Wave-Adaptation — Adaptation Check Output Format

```
[Step 3.5 — Wave Adaptation Check]
  ① Premise reversal: {none / detected → Wave N+1 revision}
  ② Repeated failure: {none / {agent name} failed 2x → alternative: {replacement skill}}
  ③ Early-harvest: {none / {N} patterns detected → mini-harvest suggested}

  → Wave N+1 revision exists: (Y: apply revision and proceed / E: revise manually / N: proceed as planned)
```

"Runtime self-modification" FH implementation: Wave = FH execution unit; Wave-level strategy revision = functionally equivalent to runtime self-modification.

---

## §fan-in-Contract — loom Fan-in Contract Detail

Each finding returned by an agent must satisfy 3-field format as minimum unit. Results not meeting this format cannot enter Wave 4 judgment — mark "format non-compliant" and re-request or skip.

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

---

## §Auto-Recording — Wave Execution Recording Format + Lightweight Mode

### Wave Execution Recording Format

Auto-record in `tracks/_meta/agent_run_YYYYMMDD_{slug}.md` each time Wave 1+ completes:

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

Trigger: Always record Wave 1+. Record even if failed. `tracks/_meta/` absent → skip + R-tier warning.

### harvest-loop Lightweight Mode (mid-session)

Runs only Steps 1→2→5 of standard harvest-loop. Skip Steps 3/3.5/4.

```
[mid-session harvest] field-harvest → contention-layer → verify-bidirectional
Time: ~3 min (50% reduction vs full loop)
```

### Human Decision Gate

- **Recording content decisions** (what to record / where): Show summary then get confirmation — no auto-save
- **Naming/direction decisions**: User confirmation required — auto-execution forbidden
- **Pipeline execution results** (file change lists, M/S/R aggregates): Auto-recording allowed

---

## §Wave4 — Entry Conditions + Judgment Output Format

### Entry Conditions

- All stages of Waves 0~3 complete (including state transition output)
- PR creation or change history exists

If not met, auto-skip Wave 4.

### Judgment Output Format

```
[Wave 4 Judgment] PASS — 0 M-tier, {N} S-tier deferred to backlog
[Wave 4 Judgment] BLOCK — {N} M-tier remaining, fix and re-validate required
```

Fixed format: 1 judgment line + 1 rationale line.

### State Transition Output Format

```
agent-composer — State Transition Evaluation
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ① M-tier: {N} items → Wave next-M {Y/N}
  ② Naming candidates: {N} items → Wave next-I {Y/N}
  ③ External absorption signals: {N} items → Wave next-E {Y/N}
  ⑤ Design conflicts: {N} items → Wave next-D {Y/N}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Run additional Wave? (Y: execute / N: end)
```

### Auto-Proposal After Judgment

```
agent-composer — Wave 4 Final Judgment
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  [Wave 4 Judgment] {PASS / BLOCK}
  Rationale: {1 line}

  {If PASS}  → field-harvest proposal: harvest patterns from this Wave?
  {If BLOCK} → fix M-tier items then re-enter Wave 1.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## §Round-Wrap — 6-1, 6-2, 6-3 Full Specs

### 6-1. Completion Summary (3 lines)

```
agent-composer — Round Completion Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ① {major completed task 1}
  ② {major completed task 2}
  ③ {major completed task 3 or "no issues confirmed"}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 6-2. Next Round Suggestions (maximum 3)

```
Next round candidates:
  [1] {task name} — {reason in 1 line}
  [2] {task name} — {reason in 1 line}
  [3] {task name} — (omit if none)

  Select items to continue (Y/N or number): ___
```

If no clear follow-up tasks → omit suggestion (output "no follow-up tasks").

### 6-3. fh_signal Persistence Confirmation

| Condition | Confirmation |
|---|---|
| New skill/pattern discovered | Record in `tracks/_meta/fh_signal_YYYYMMDD.md`? |
| Design decision made (including M-tier resolution) | Persist decision summary as fh_signal? |
| None | Skip persistence confirmation |

```
fh_signal persistence: [discovered signal summary in 1 line]
  Record? (Y: save to tracks/_meta/fh_signal_{date}.md / N: skip)
```

---

## §Identity — Full Agent Composition Layer Explanation

### Automation Layer Division

| Human domain | System domain |
|---|---|
| What to build, why (direction + insight) | Which agents and how (composition + ordering) |
| Final adoption decision | Pipeline execution + result aggregation |
| Naming/framing | Recording + quality gates |

### Brain/Hands Decoupling (Anthropic Independent Convergence)

- **Brain**: Goal parsing → skill mapping → Wave construction → gate decisions
- **Hands**: Agent tool dispatch → parallel execution → result collection → fan-in report

Rationale: Anthropic "Scaling Managed Agents" — Brain/Hands separation improves scalability, debugging, maintainability.

### Curator Role (hermes-agent Convergence)

agent-composer also acts as Curator — surveys existing agents/skills/assets and proposes optimal combinations.

- **Curator mode**: Detects agent state (stale, pinned, deprecated) + proposes merge candidates for duplicate agents
- **External positioning**: Independent convergence with hermes-agent (Nous Research) curator.py pattern

> Architecture basis: Anthropic [Harness Design for Long-Running Apps](https://www.anthropic.com/engineering/harness-design-long-running-apps) — single agent ($9, fails) vs. multi-agent harness ($200, perfect). Cost gap justified by quality gap.

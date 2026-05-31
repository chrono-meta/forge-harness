# AGENTS.md — forge-harness Sub-Agent Specs

> **This file is the runtime agent specification registry for forge-harness.**
> For session rules and orchestration protocol, see `CLAUDE.md`.
> For skill descriptions and natural language triggers, see `plugins/fh-meta/` and `plugins/fh-commons/`.

---

## Relationship to CLAUDE.md

| File | Scope | Audience |
|---|---|---|
| `CLAUDE.md` | Session rules, protocols, orchestration flow | AI (Claude Code) — operational ruleset |
| `AGENTS.md` | Runtime agent specs — roles, tools, invocation | AI + humans — agent registry |

CLAUDE.md governs *how* the session runs. AGENTS.md defines *what each agent does* when dispatched.

---

## Agent Registry

forge-harness ships 5 agents in `.claude/agents/`. Four serve general harness operations; one (`quench-challenger`) is steel-quench-dedicated.

| Agent | File | Role | Invoked by |
|---|---|---|---|
| `challenger` | `.claude/agents/challenger.md` | Frontier-grade adversarial evaluator — adapts attack vectors to artifact type, enforces evidence citation, models its own information asymmetry | `steel-quench`, `harvest-loop`, `sim-conductor`, or direct dispatch |
| `hub-persona-auditor` | `.claude/agents/hub-persona-auditor.md` | Pre-publication audit of external-facing assets — 3+ persona simulation, 4-axis review (resonance/confusion/resistance/supplement), 3-tier revision proposals | `hub-cc-pr-reviewer`, `sim-conductor`, or direct dispatch |
| `quench-challenger` | `.claude/agents/quench-challenger.md` | Steel-quench dedicated adversary — 3-DNA synthesis of Devil + Innovator + Prescriber; every attack paired with a concrete fix direction | `steel-quench` Wave 1 (primary), `install-doctor`, `marketplace-gate` |
| `persona-innovator` | `.claude/agents/persona-innovator.md` | Naming gap detection + frame proposals + external frontier absorption signals | `sim-conductor` Area A, `harvest-loop`, or direct dispatch |
| `plan` | `.claude/agents/plan.md` | Read-only design agent — analyzes files, maps impact scope, and plans before implementation | Direct dispatch before any Edit/Write session |

### Tool restrictions per agent

| Agent | Allowed tools | Rationale |
|---|---|---|
| `challenger` | Read, Grep, Glob, WebSearch, WebFetch | Needs external evidence; no writes |
| `hub-persona-auditor` | Read, Grep, Glob | Audit only — no modification |
| `quench-challenger` | Read, Grep, Glob | Attack+prescription only — no modification |
| `persona-innovator` | Read, Grep, Glob, WebSearch, WebFetch | Frontier scanning requires web access |
| `plan` | Read, Bash, Glob, Grep | Design reconnaissance — no Edit or Write |

---

## 2-Layer Architecture Context

forge-harness is structured as two distinct layers:

| Layer | Contents | AI compatibility |
|---|---|---|
| **Methodology layer** (model-agnostic) | `tracks/`, `knowledge/`, `SKILL.md` documents, session protocols | Any AI model |
| **Automation layer** (Claude-native) | `.claude/agents/`, hooks, slash commands, `CLAUDE.md` rules | Claude Code only |

Agents in this registry belong to the **Automation layer**. Skills (in `plugins/`) straddle both layers — their methodology is model-agnostic, but their invocation mechanism is Claude Code-native.

> **Codex-compatible beta**: The Methodology layer (`tracks/`, `knowledge/`, skill documentation) is designated Codex-compatible beta. Gemini, Codex, and other AI users can apply FH methodology without the Automation layer — manual invocation replaces hook/agent dispatch.

> **Multi-model sidecar**: Claude Code's sidecar feature allows FH skills to invoke Gemini CLI or Codex CLI as external processes via the `Bash` tool. The orchestrator remains Claude Code; sidecar models act as specialized delegates — e.g., Gemini as a second adversarial challenger in `steel-quench`, or Codex for syntax-heavy validation in `source-grounding-audit`. Sidecar calls are Bash tool invocations, not agent dispatches — they bypass this registry and are coordinated inline by the skill.

---

## Invocation patterns

### Single agent dispatch

```
Analyze this SKILL.md for structural flaws before I commit it.
```

→ Claude dispatches `quench-challenger` automatically (description-triggered).

### Parallel dispatch (2+ independent tasks)

```
Run fact-checker and persona-innovator in parallel.
  First: check [asset path] for duplicates
  Second: scan for naming gaps in the current harness
```

→ Both agents run concurrently in Agent View; results are integrated by the orchestrator.

### Wave-based composition (via agent-composer)

For complex multi-step tasks, run `/agent-composer` first to plan which agents to dispatch in which order (Wave 0 reconnaissance → Wave 1 execution → Wave 2 synthesis).

---

## Adding new agents

New agents must pass the **New Skill Creation Pre-Commit Gate** defined in `CLAUDE.md` before committing. Key requirements:

1. Role duplication check via `/asset-placement-gate`
2. Plain description — no self-marketing language
3. At least 1 explicit `Done When` condition
4. At least 3 natural language trigger examples
5. Independently executable (or dependencies explicitly documented)

After 2+ weeks of use: if `accepted ≥ 60%` of invocations → strengthen; if `rejected ≥ 40%` → redefine scope or deprecate. See `CLAUDE.md > Sub-agent Operations`.

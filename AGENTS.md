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

forge-harness ships 6 agents in `.claude/agents/`. Five serve general harness operations; one (`quench-challenger`) is steel-quench-dedicated.

| Agent | File | Role | Invoked by |
|---|---|---|---|
| `challenger` | `.claude/agents/challenger.md` | Frontier-grade adversarial evaluator — adapts attack vectors to artifact type, enforces evidence citation, models its own information asymmetry | `steel-quench`, `harvest-loop`, `sim-conductor`, or direct dispatch |
| `fact-checker` | `.claude/agents/fact-checker.md` | Pre-recommendation deduplication — greps hub assets for existing skills/agents/patterns before main agent commits to a new recommendation; catches stale facts and duplicate work | Main agent before any new asset creation or recommendation |
| `hub-persona-auditor` | `.claude/agents/hub-persona-auditor.md` | Pre-publication audit of external-facing assets — 3+ persona simulation, 4-axis review (resonance/confusion/resistance/supplement), 3-tier revision proposals | `hub-cc-pr-reviewer`, `sim-conductor`, or direct dispatch |
| `quench-challenger` | `.claude/agents/quench-challenger.md` | Steel-quench dedicated adversary — 3-DNA synthesis of Devil + Innovator + Prescriber; every attack paired with a concrete fix direction | `steel-quench` Wave 1 (primary), `install-doctor`, `marketplace-gate` |
| `persona-innovator` | `.claude/agents/persona-innovator.md` | Naming gap detection + frame proposals + external frontier absorption signals | `sim-conductor` Area A, `harvest-loop`, or direct dispatch |
| `plan` | `.claude/agents/plan.md` | Read-only design agent — analyzes files, maps impact scope, and plans before implementation | Direct dispatch before any Edit/Write session |

> Machine-readable mirror: `.claude/registry/agent_cards.json` (canonical capability cards, count-synced — A2A Agent Card pattern).

### Tool restrictions per agent

| Agent | Allowed tools | Rationale |
|---|---|---|
| `challenger` | Read, Grep, Glob, WebSearch, WebFetch | Needs external evidence; no writes |
| `fact-checker` | Read, Grep, Glob | Deduplication grep only — no modification |
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

> **Multi-model sidecar (validated)**: Any FH user can delegate to other models via sidecar — Gemini CLI, OpenAI/Codex CLI, or Copilot CLI's model catalog — invoked with `Bash` from within the Claude Code session. FH is the orchestrating harness; the sidecar is a routing/access layer (not a second harness — different layer entirely). Validated empirically: `echo "prompt" | gemini` works inside a CC session and produces usable output. Sidecar calls are Bash invocations, not agent dispatches — they bypass this registry and are coordinated inline by the skill. See `knowledge/shared/harness-core/multi_model_sidecar_strategy.md` for the full pattern.

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

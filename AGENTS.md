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

forge-harness ships 8 tracked agents across plugin `agents/` directories. The **user-mastery spectrum** (`beginner` · `main-player` · `expert`) plus `challenger` (adversarial axis) supply multi-persona review; `fact-checker`, `hub-persona-auditor`, and `persona-innovator` serve general harness operations; `quench-challenger` is steel-quench-dedicated.

| Agent | File | Role | Invoked by |
|---|---|---|---|
| `beginner` | `plugins/fh-meta/agents/beginner.md` | First-contact cold-read standpoint (spectrum entry tier) — onboarding friction a fluent author cannot feel; constructive, not adversarial | `sim-conductor` Area A, `marketplace-gate`, `install-wizard`, or direct dispatch |
| `main-player` | `plugins/fh-meta/agents/main-player.md` | Engaged-user standpoint (spectrum core tier) — intelligently scopes Light/Midcore/Heavy; Heavy = classic power-user edge/limit lens | `sim-conductor` Area A/D-code, or direct dispatch |
| `expert` | `plugins/fh-meta/agents/expert.md` | Domain-authority standpoint (spectrum frontier tier) — web-grounded accuracy + SOTA currency, citation-enforced | `sim-conductor` Area E/D, paper review, or direct dispatch |
| `challenger` | `plugins/fh-meta/agents/challenger.md` | Frontier-grade adversarial evaluator — adapts attack vectors to artifact type, enforces evidence citation, models its own information asymmetry; U1 absorbs the skeptic "why not just X?" lens | `steel-quench`, `harvest-loop`, `sim-conductor`, or direct dispatch |
| `fact-checker` | `plugins/fh-meta/agents/fact-checker.md` | Pre-recommendation deduplication — greps hub assets for existing skills/agents/patterns before main agent commits to a new recommendation; catches stale facts and duplicate work | Main agent before any new asset creation or recommendation |
| `hub-persona-auditor` | `plugins/fh-meta/agents/hub-persona-auditor.md` | Pre-publication audit of external-facing assets — 3+ persona simulation, 4-axis review (resonance/confusion/resistance/supplement), 3-tier revision proposals | `hub-cc-pr-reviewer`, `sim-conductor`, or direct dispatch |
| `quench-challenger` | `plugins/fh-commons/agents/quench-challenger.md` | Steel-quench dedicated adversary — 3-DNA synthesis of Devil + Innovator + Prescriber; every attack paired with a concrete fix direction | `steel-quench` Wave 1 (primary), `install-doctor`, `marketplace-gate` |
| `persona-innovator` | `plugins/fh-meta/agents/persona-innovator.md` | Naming gap detection + frame proposals + external frontier absorption signals | `sim-conductor` Area A, `harvest-loop`, or direct dispatch |

> Machine-readable mirror: `.claude/registry/agent_cards.json` (canonical capability cards, count-synced to tracked agent files — A2A Agent Card pattern).

### Tool restrictions per agent

| Agent | Allowed tools | Rationale |
|---|---|---|
| `challenger` | Read, Grep, Glob, WebSearch, WebFetch | Needs external evidence; no writes |
| `fact-checker` | Read, Grep, Glob | Deduplication grep only — no modification |
| `hub-persona-auditor` | Read, Grep, Glob | Audit only — no modification |
| `quench-challenger` | Read, Grep, Glob | Attack+prescription only — no modification |
| `persona-innovator` | Read, Grep, Glob, WebSearch, WebFetch | Frontier scanning requires web access |

---

## 2-Layer Architecture Context

forge-harness is structured as two distinct layers:

| Layer | Contents | AI compatibility |
|---|---|---|
| **Methodology layer** (model-agnostic) | `tracks/`, `knowledge/`, `SKILL.md` documents, session protocols | Any AI model |
| **Automation layer** (Claude-native) | `.claude/agents/`, hooks, slash commands, `CLAUDE.md` rules | Claude Code only |

Agents in this registry belong to the **Automation layer**. Skills (in `plugins/`) straddle both layers — their methodology is model-agnostic, but their invocation mechanism is Claude Code-native.

> **Codex-compatible beta**: The Methodology layer (`tracks/`, `knowledge/`, skill documentation) is designated Codex-compatible beta. Gemini, Codex, and other AI users can apply FH methodology without the Automation layer — manual invocation replaces hook/agent dispatch.

> **Multi-model sidecar (validated)**: Any FH user can delegate to other models via sidecar — Gemini CLI, OpenAI/Codex CLI, or Copilot CLI's model catalog — invoked with `Bash` from within the Claude Code session. FH is the orchestrating harness; the sidecar is a routing/access layer (not a second harness — different layer entirely). Validated empirically: `echo "prompt" | gemini` works inside a CC session and produces usable output. Sidecar calls are Bash invocations, not agent dispatches — they bypass this registry and are coordinated inline by the skill. Capability routing matters too: Gemini/Antigravity is the natural multimodal sidecar, while a Codex app/runtime session with Browser/Chrome connectors is the preferred handoff for live web-flow automation. In a local FH workspace that pairs the public methodology mirror with a private companion store (the `*-be` pattern), route by workspace capability while preserving each repository's ownership boundary. See `knowledge/shared/harness-core/multi_model_sidecar_strategy.md` for the full pattern.

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

## Codex Compatibility (beta)

The methodology layer (`tracks/`, `knowledge/`, `SKILL.md` docs) is Codex-compatible beta. Any AI model can follow skill workflows by reading SKILL.md files directly; the automation layer (hooks, `.claude/agents/`, `/model`) is Claude Code-native and requires manual adaptation.

### Entry point for Codex users

AGENTS.md is your starting point. Navigate from here to skill workflows:

```bash
# Read a skill's full workflow
cat plugins/fh-meta/skills/steel-quench/SKILL.md

# Apply via codex exec (validated pattern — codex-cli ≥ 0.135.0)
cat plugins/fh-meta/skills/steel-quench/SKILL.md path/to/artifact.md \
  | codex exec -m gpt-5.5 -

# Or use FH's runtime adapter (preferred for Codex-primary workflows)
FH_BACKEND=codex npx --package @chrono-meta/fh-gate fh-run \
  --skill steel-quench \
  --file path/to/artifact.md

# Agent substitution for Claude Code Agent(...) calls
FH_BACKEND=codex npx --package @chrono-meta/fh-gate fh-run \
  --agent fh-commons:quench-challenger \
  --file path/to/artifact.md

# Or pipe explicitly
echo "Apply the following skill to the artifact below." | \
  cat - plugins/fh-meta/skills/{skill}/SKILL.md target.md \
  | codex exec -m gpt-5.5 -
```

`codex exec -m gpt-5.5 -` reads from stdin in headless mode. `npx @openai/codex` (interactive) is not suitable — it requires TTY.

### Skill compatibility tiers

| Tier | Definition | Examples |
|---|---|---|
| **M1 — Full** | All phases run without CC-native dependencies — no Stop hook, no `.claude/agents/` dispatch, no `/model` | `token-budget-gate`, `asset-placement-gate`, `phantom-quench`, `deep-clarify`, `deliberation`, `convergence-loop` |
| **M2 — Partial** | Core workflow runs; CC-native phases require manual adaptation or skip | `steel-quench` (Wave 1–3 ✅; quench-challenger agent = manual), `harness-doctor`, `context-doctor`, `sim-conductor`, `harvest-loop` (git scan phase ✅; PR auto-proposal = manual) |
| **M3 — CC-only** | Requires CC Stop hook or session-scoped agent dispatch; methodology reference only | `goal-quench` (Phase 3 Stop hook), `hub-cc-pr-reviewer` (CC session context), `install-wizard` (settings.json write) |

**M2 adaptation pattern**: when a step references `Agent(subagent_type=...)` or a slash command, substitute with `fh-run` (preferred) or a direct `codex exec` call reading the sub-agent's SKILL.md — same workflow, different runtime.

**Goal handling under Codex**: use Codex's native goal/session feature when available. FH's portable role is the quality gate after the goal completes: `FH_BACKEND=codex npx --package @chrono-meta/fh-gate fh-gate ...`. `fh-goal` exists only for non-interactive one-shot runs that should be followed automatically by `fh-gate`; it is not a replacement for Codex-native goal control.

### Beta removal conditions

| Condition | Status |
|---|---|
| Known limitation list published (`docs/codex-compat.md`) | ✅ done (2026-06-04) |
| 5+ externally validated M1 skill runs (not FH author) | ⬜ pending — needs external users |
| At least 1 external Codex user confirms methodology reproduces | ⬜ pending — needs external users |
| README badge updated (`Codex-compatible` without `beta`) | ⬜ blocked on above |

**Author M1 validation (2026-06-04, internal — does not satisfy the external conditions above):** `phantom-quench` (4/4 on a phantom-seeded fixture) and `asset-placement-gate` (correct Drop routing on a duplicate-skill proposal) ran end-to-end via `codex exec -m gpt-5.5 -` with no CC-native dependency, confirming the M1 tier assignments. Limitations observed (CC-native hook noise, no token accounting, etc.) are documented in `docs/codex-compat.md`.

Tracking: open an issue at `chrono-meta/forge-harness` with label `codex-validation` to report a validated run.

---

## Adding new agents

New agents must pass the **New Skill Creation Pre-Commit Gate** defined in `CLAUDE.md` before committing. Key requirements:

1. Role duplication check via `/asset-placement-gate`
2. Plain description — no self-marketing language
3. At least 1 explicit `Done When` condition
4. At least 3 natural language trigger examples
5. Independently executable (or dependencies explicitly documented)

After 2+ weeks of use: if `accepted ≥ 60%` of invocations → strengthen; if `rejected ≥ 40%` → redefine scope or deprecate. See `CLAUDE.md > Sub-agent Operations`.

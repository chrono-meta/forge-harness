<p align="center">
  <img src="https://raw.githubusercontent.com/chrono-meta/forge-harness/main/docs/banner.png" alt="forge-harness — A forkable Claude Code meta-harness for multi-project teams" width="680">
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-22c55e.svg" alt="MIT License"></a>
  <img src="https://img.shields.io/badge/fh--gate-v1.2.1-3b82f6.svg" alt="fh-gate v1.2.1">
  <a href="https://zenodo.org/records/20397566"><img src="https://img.shields.io/badge/DOI-10.5281%2Fzenodo.20397566-blue.svg" alt="DOI"></a>
  <img src="https://img.shields.io/badge/Claude_Code-compatible-a855f7.svg" alt="Claude Code">
  <a href="https://github.com/chrono-meta/forge-harness/issues/72"><img src="https://img.shields.io/badge/Codex-beta_·_help_validate-f59e0b.svg" alt="Codex-compatible beta — help validate (issue #72)"></a>
  <a href="https://www.npmjs.com/package/@chrono-meta/fh-gate"><img src="https://img.shields.io/npm/v/@chrono-meta/fh-gate.svg?color=cb3837" alt="npm"></a>
</p>

<p align="center">
  <b>Fork it. Rename it. Make it yours.</b><br>
  A persistent knowledge hub that connects all your Claude Code projects —<br>shared skills, accumulated context, and a compounding improvement loop.
</p>

<p align="center">
  <img src="docs/pillars.svg" alt="FORK · ADAPT · COLLABORATE · EMPOWER" width="680">
</p>

---

| If you're here because… | forge-harness solves it |
|---|---|
| Context disappears when a session ends | Persistent `tracks/` — resumable from anywhere |
| You repeat the same setup across projects | Connect once to the hub, share across all projects |
| Team AI know-how lives only in people's heads | Codify it so everyone shares it |
| You want AI to get *better* as work accumulates | Skills and patterns compound session over session |
| You need a governance layer for AI-generated code | `fh-gate` wraps any coding agent as a post-generation gate |

> **This document is for humans.** AI operating rules → `CLAUDE.md` · Command reference → `CHEATSHEET.md`

---

## Get started in 2 minutes

**Prerequisite**: Claude Code CLI — verify with `claude --version`

```bash
# 1. Install the plugin
claude plugin marketplace add https://github.com/chrono-meta/forge-harness.git
claude plugin install -s user fh-meta@forge-harness

# 2. Clone the hub
git clone https://github.com/chrono-meta/forge-harness.git ~/forge-harness
cd ~/forge-harness

# 3. Start a session
claude
```

> ✅ Claude reads `CLAUDE.md` and asks what project to connect or what task to start.
> Say **"Connect a project"** → hub scans `../`, finds `.git` directories, creates `tracks/{project}/`.

**Plugin only (no clone):**
```bash
claude plugin marketplace add https://github.com/chrono-meta/forge-harness.git  # once
claude plugin install -s user fh-meta@forge-harness
cd ~/projects/{your-project} && claude
```

---

## What it is

forge-harness is structured as **two distinct layers**:

| Layer | Contents | AI compatibility |
|---|---|---|
| **Methodology layer** | `tracks/`, `knowledge/`, `SKILL.md` docs, session protocols | Any AI model |
| **Automation layer** | `.claude/agents/`, hooks, slash commands, `CLAUDE.md` rules | Claude Code only |

The methodology layer is the portable core — persistent hub, accumulating learnings, curating cross-project knowledge. The automation layer makes it frictionless when running Claude Code.

```
forge-harness/   ← the hub (persistent brain)
├── knowledge/   → shared across all projects
└── tracks/      → work records per project

Project A  ──→  connect hub in CLAUDE.md
Project B  ──→  connect hub in CLAUDE.md
```

---

## Governance layer for AI-generated code

FH wraps any coding agent (OpenCode, Codex, etc.) as a **post-generation governance gate**.

```bash
npx --package @chrono-meta/fh-gate fh-gate                    # default: Claude backend
FH_BACKEND=codex npx --package @chrono-meta/fh-gate fh-gate   # Codex backend
FH_BACKEND=auto npx --package @chrono-meta/fh-gate fh-gate "src/foo.ts" full
# → FH_GATE_VERDICT: PASS | PENDING | BLOCKED | ESCALATE
```

`fh-gate` uses the same FH governance prompt for both runtimes. `FH_BACKEND=claude` runs `claude --print`; `FH_BACKEND=codex` runs `codex exec`; `FH_BACKEND=auto` prefers Codex when both CLIs are present.

For direct skill or agent execution outside Claude Code, use `fh-run`:

```bash
FH_BACKEND=codex npx --package @chrono-meta/fh-gate fh-run --skill source-grounding-audit --file docs/foo.md
FH_BACKEND=codex npx --package @chrono-meta/fh-gate fh-run --agent fh-commons:quench-challenger --file plugins/fh-meta/skills/foo/SKILL.md
```

For Codex-primary work, keep using Codex's native goal/session features when available. `fh-goal` is only a portable wrapper for one-off non-interactive runs that should be followed by FH governance:

```bash
FH_BACKEND=codex npx --package @chrono-meta/fh-gate fh-goal --prompt "Implement X and update tests" --gate quick
```

The broader FH automation layer still depends on Claude Code for sub-agents, hooks, and slash commands. The portable path is shared documents plus runtime adapters, not separate Codex and Claude forks.

**Empirical result (2026-05-31)**: Applied to OpenCode's AI-generated `permission/arity.ts` (163 lines, CI green). Current gate semantics classify this as BLOCKED: 2 A-grade findings CI didn't catch (short-token overflow in allowlist, executor tools absent from arity table).

Full spec: [`fh_integration_contract.md`](knowledge/shared/harness-core/fh_integration_contract.md)

---

## 35 skill files, 5 agents

<details>
<summary>Full asset activation check</summary>

| Asset | Role | Triggers |
|---|---|---|
| `steel-quench` | Full-spectrum adversarial verification | "Run the quench", "Attack from the root" |
| `source-grounding-audit` | Phantom claim detection + source back-tracing | "Verify the source", "Grounding audit" |
| `harvest-loop` | End-of-session learning → evolution pipeline | "Harvest the session" |
| `agent-composer` | Plans optimal agent dispatch | "Run in parallel", "Which agents?" |
| `sim-conductor` | Meta-simulation orchestrator | "External user perspective" |
| `context-doctor` | Token efficiency + `.claudeignore` | "Session is slow", "Clean up context" |
| `harness-doctor` | Harness structure diagnosis | "Check my Claude setup" |
| `pipeline-conductor` | 4-axis quality gate (backward/adversarial/forward/record) | "Run the quality gate" |
| `field-harvest` | Back-propagate field patterns to hub | "I could reuse this" |
| `frontier-digest` | HN + arXiv → actionable insights | "AI trend digest" |
| `hub-cc-pr-reviewer` | Automated PR review | "Review this PR" |
| `verify-bidirectional` | Reverse-verify decisions | "Is that right?", "Double-check" |
| `deep-clarify` | Socratic requirements clarification | "I'm not sure what to build" |
| `install-wizard` | Initial onboarding | "First-time setup" |
| `plugin-recommender` | Plugin recommendations | "Is there a good tool for this?" |
| `apex-review` | Executive-perspective quality review | "Will this hold up?" |
| `meta-prompt-builder` | Meta prompt design | "Write a prompt for the agent" |
| `asset-placement-gate` | Hub vs project asset routing | "Should this be shared?" |
| `cross-ecosystem-synergy-detection` | Cross-tool synergy finder | "Are my tools working together?" |
| `convergence-loop` *(fh-commons)* | N-round convergence loops | "Single-pass seems suspicious" |
| `token-budget-gate` *(fh-commons)* | Pre-task token cost estimate | "How expensive is this?" |
| `mcp-circuit-breaker` *(fh-commons)* | MCP tool failure pattern detection | "MCP keeps failing" |
| `quench-challenger` *(fh-commons)* | Adversarial pressure-test agent | "Challenge this with a devil" |
| *(+ additional assets)* | marketplace-gate · contention-layer · edit-manifest · fact-checker · goal-quench · hub-persona-auditor · install-doctor · memory-hygiene · persona-innovator · prompt-regression · public-surface-audit · skill-splitter | |

| Active count | Diagnosis |
|:---:|---|
| **28+** | Advanced — chain agent-composer + sim-conductor + steel-quench + pipeline-conductor |
| **10–27** | Activation stage — gradually enable unchecked assets |
| **0–9** | Early stage — start with `install-wizard` |

**Find a skill by what you're trying to do:**

| Cluster | Skills |
|---|---|
| Verification | `steel-quench` · `source-grounding-audit` · `convergence-loop` · `prompt-regression` · `return-path-gate` |
| Orchestration | `agent-composer` · `pipeline-conductor` · `goal-quench` · `deliberation` |
| Diagnosis | `harness-doctor` · `context-doctor` · `install-doctor` · `mcp-circuit-breaker` |
| Harvesting / Learning | `harvest-loop` · `field-harvest` · `edit-manifest` · `memory-hygiene` |
| Gate / Guard | `token-budget-gate` · `asset-placement-gate` · `marketplace-gate` |
| Discovery | `plugin-recommender` · `cross-ecosystem-synergy-detection` · `frontier-digest` · `verify-bidirectional` |
| Content / Simulation | `sim-conductor` · `apex-review` · `meta-prompt-builder` · `deep-clarify` |
| Setup | `install-wizard` · `hub-cc-pr-reviewer` · `skill-splitter` |

</details>

---

## Model setup

Claude Code does not auto-select models by task complexity — you configure this once.

```bash
/model opusplan   # recommended for forge-harness
```

| Command | Who runs what | Best for |
|---|---|---|
| `/model sonnet` | Sonnet handles everything | Fast coding, simple tasks |
| `/model opus` | Opus handles everything | Complex reasoning, architecture |
| `/model opusplan` | **Opus plans · Sonnet executes** | FH orchestration + sub-agents |

**Why `opusplan` for FH**: CC switches models per-turn based on task weight — Opus activates for plan-mode turns (complex reasoning, decomposition decisions), Sonnet handles execution turns (tool calls, file edits, bash). forge-harness orchestration leans on both: Opus for design decisions in agent-composer / goal-quench / steel-quench, Sonnet for the actual file edits and sub-agent execution contexts. Sub-agent token costs are CC-visible and appear in the session jsonl under `message.model`.

If you use external CLIs (Gemini, Codex, `gh copilot`) as sidecars, their costs are billed to their own quota and not visible in CC's token display.

---

## Multi-Model Sidecar (v1.3)

Run Gemini, Codex, or `gh copilot` as independent peer reviewers alongside Claude.

| Tier | Setup | Defects found |
|---|---|---|
| **C1** Single Claude | Default | 25% |
| **C2** 3 cross-session Claude personas | No extra tools | 75% |
| **C3** C2 + external CLI | External CLI installed | 100% (+3 Claude blind spots) |

Claude-side token cost: **zero increase** C2→C3.

---

## Research

> **FH v1.0 paper** — [Zenodo](https://zenodo.org/records/20397566) (DOI: 10.5281/zenodo.20397566) · arXiv in review.
> Documents 2-layer design, 6-axis framework, 4-agent orchestration, and compounding loop with empirical evidence.

External convergence:
- ["Dive into Claude Code: The Design Space of Today's and Future AI Agent Systems"](https://arxiv.org/abs/2604.14228) — arXiv April 2026
- ["Code as Agent Harness"](https://arxiv.org/abs/2605.18747) — arXiv May 2026
- Stanford IRIS Lab: ["Meta-Harness"](https://arxiv.org/abs/2603.28052) — +7.7pts at 4× fewer tokens

---

## Learn more

| Resource | Purpose |
|---|---|
| [`CLAUDE.md`](CLAUDE.md) | AI operating rules + sync/push protocol |
| [`CHEATSHEET.md`](CHEATSHEET.md) | Full command reference |
| [`AGENTS.md`](AGENTS.md) | Runtime agent specs |
| [`CATALOG.md`](CATALOG.md) | Past work search index |
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | How to contribute skills and patterns |
| [`fh_integration_contract.md`](knowledge/shared/harness-core/fh_integration_contract.md) | Governance gate spec |

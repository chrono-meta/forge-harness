<p align="center">
  <img src="https://raw.githubusercontent.com/chrono-meta/forge-harness/main/docs/banner.png" alt="forge-harness — Forge your projects, pass them through, faster. Quality is the lever — speed is the result." width="680">
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-22c55e.svg" alt="MIT License"></a>
  <a href="https://zenodo.org/records/20397566"><img src="https://img.shields.io/badge/DOI-10.5281%2Fzenodo.20397566-blue.svg" alt="DOI"></a>
  <img src="https://img.shields.io/badge/Claude_Code-compatible-a855f7.svg" alt="Claude Code">
  <a href="https://github.com/chrono-meta/forge-harness/issues/72"><img src="https://img.shields.io/badge/Codex-beta_·_help_validate-f59e0b.svg" alt="Codex-compatible beta — help validate (issue #72)"></a>
  <a href="https://www.npmjs.com/package/@chrono-meta/fh-gate"><img src="https://img.shields.io/npm/v/@chrono-meta/fh-gate.svg?color=cb3837" alt="npm"></a>
</p>

<p align="center">
  <b>Forge your Claude Code projects — pass them through, they come out faster.</b><br>
  A practitioner's meta-harness: it raises each project's <b>floor</b> (harness-ify the setup)<br>and <b>ceiling</b> (accelerate the work), then compounds the gains across your whole portfolio.
</p>

<p align="center">
  <b>Quality is the lever; speed is the result.</b> Every change earns its way through the gates —<br>adversarial · phantom · regression — and <i>that</i> is what makes the next change faster.
</p>

<p align="center">
  <i>Fork it. Rename it. Make it yours.</i>
</p>

<p align="center">
  <img src="docs/pillars.svg" alt="FORK · ADAPT · COLLABORATE · EMPOWER" width="680">
</p>

<p align="center">
  <a href="docs/ETHOS.md"><b>The principles</b></a> ·
  <a href="docs/WHY.md"><b>Why it exists</b></a> ·
  <a href="docs/OUTPUT_EVIDENCE.md"><b>The evidence</b></a> ·
  <a href="CHEATSHEET.md"><b>How to use it</b></a>
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

> 🚪 **New here / just want the skills?** Start with the opinionated front door —
> [`templates/starter_profile.md`](templates/starter_profile.md): one install command, a curated
> first-five skills, and a zero-install governance gate (`npx … fh-gate`). The other 28 skills wait
> until you need them.

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

## Why it works

After a long co-authoring session with your AI, you and it share the same context — and the same blind spots. The reviewer worth having is the one who never saw your reasoning. You can get that by hand: paste the work into a fresh, empty chat. FH just turns that chore into one routine command.

- **sidecar / agent dispatch** → a reviewer with none of your session's context
- **steel-quench · phantom-quench** → that cold pass, on demand

It's model-agnostic: co-build with one AI, run the cold pass with any other. Whoever was absent from the original session is your cold reviewer — this is not a ranking of models.

**What FH does not claim:** the cold pass is your base model's own ability, not a detection engine FH adds — a plain prompt to a fresh instance does much of the same. FH's value is narrower and honest: it takes a method drawn from real practice and makes running that independent pass routine, instead of a chore you skip. The methodology is copyable; what FH packages is the workflow, not a secret sauce.

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
FH_BACKEND=codex npx --package @chrono-meta/fh-gate fh-run --skill phantom-quench --file docs/foo.md
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

## The forge

forge-harness treats a project like steel — and the metaphor is literal, not decoration. Work is shaped,
hardened by attack, and only then does it ship faster, for having survived.

| Movement | What happens | The commands |
|---|---|---|
| **Forge** | shape the raw project into a harness — raise its floor | `install-wizard`, "harness-ify this project" |
| **Quench** | harden it by attack — the cold pass leaves standing only what is sound | `steel-quench` · `phantom-quench` |
| **Temper** | take the brittleness back out of the hardened asset | *the movement being forged next* |
| → **Accelerate** | a blade that survived the forge cuts faster | `goal-quench` — *Pass → Accelerate* |

Three movements are shipped; **temper** is the direction ahead — and naming the movement we have *not*
finished is the point (see [`ETHOS.md`](docs/ETHOS.md#the-forge)). Around the forge, two more signatures keep
it running: `harvest-loop` (each session's lessons become permanent skills) and `agent-composer`
(orchestrate the dispatch). The other skills wait until you need them — full list below.

## 33 skills · 5 agents

<details>
<summary>Full asset activation check</summary>

| Asset | Role | Triggers |
|---|---|---|
| `steel-quench` | Full-spectrum adversarial verification | "Run the quench", "Attack from the root" |
| `phantom-quench` | Phantom claim detection + source back-tracing | "Verify the source", "Grounding audit" |
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
| Verification | `steel-quench` · `phantom-quench` · `convergence-loop` · `prompt-regression` · `return-path-gate` |
| Orchestration | `agent-composer` · `pipeline-conductor` · `goal-quench` · `deliberation` |
| Diagnosis | `harness-doctor` · `context-doctor` · `install-doctor` · `mcp-circuit-breaker` |
| Harvesting / Learning | `harvest-loop` · `field-harvest` · `edit-manifest` · `memory-hygiene` |
| Gate / Guard | `token-budget-gate` · `asset-placement-gate` · `marketplace-gate` |
| Discovery | `plugin-recommender` · `cross-ecosystem-synergy-detection` · `frontier-digest` · `verify-bidirectional` |
| Content / Simulation | `sim-conductor` · `apex-review` · `meta-prompt-builder` · `deep-clarify` |
| Setup | `install-wizard` · `hub-cc-pr-reviewer` · `skill-splitter` |

> **Full phrasebook** — every skill + agent with its one-line definition and the plain-language phrase
> that triggers it: [`CHEATSHEET.md` §12](CHEATSHEET.md#12-skills--agents--what-each-does-and-what-to-say).

</details>

---

## Model setup

Claude Code does not auto-select models by task complexity — you configure this once.

```bash
/model opus   # recommended for forge-harness — pin Opus so gate/verification turns never silently drop
```

| Command | Who runs what | Best for |
|---|---|---|
| `/model opus` | Opus handles everything | **FH default** — verification, governance, agent reasoning |
| `/model opusplan` | Opus *plans* · Sonnet executes *(when Opus engages)* | Cost-conscious routine coding — see caveat |
| `/model sonnet` | Sonnet handles everything | Fast, simple tasks (no FH gates) |

**Why `/model opus` for FH**: FH is a *quality* harness — its value lives in verification turns (steel-quench, phantom-quench, the 4-axis gate, agent reasoning) that must not silently run on a weaker model. `opusplan`'s Opus engagement is **not guaranteed**: in a measured 10-turn run it used Opus on **0** turns (CC classifies few turns as "plan-mode"), so the reasoning FH leans on quietly ran on Sonnet — pinning `/model opus` removed that variance (22/22 turns Opus in the follow-up). **Sub-agent dispatch** model is set by the dispatch's own `model` parameter; the session model/plan-mode does **not** propagate Opus to sub-agents, so pin Opus there too for adversarial/verification agents. Use `opusplan` only when the task is mostly routine edits and you accept that Opus may not engage.

> **By role**: editing the harness itself → `/model opus` (full). Running FH on a field project → `/model opus` for any gated/verification work; `opusplan` is an acceptable cost tradeoff for routine coding, with the caveat above. Sub-agent token costs are CC-visible in the session jsonl under `message.model`.

If you use external CLIs (Gemini, Codex, `gh copilot`) as sidecars, their costs are billed to their own quota and not visible in CC's token display.

---

## Multi-Model Sidecar

Run Gemini, Codex, or `gh copilot` as independent reviewers alongside Claude. The point is **context
isolation**: a reviewer that did *not* co-create the work is cold to its froth — whoever sits *outside* the
collaboration tends to catch what the co-author, now an advocate for the shared result, glides past. It's
symmetric, not a model-ranking: when you co-build with Gemini, a fresh Claude catches its froth; when you
co-build with Claude, a fresh sidecar catches Claude's.

In one internal case study, layering reviewers surfaced progressively more issues — a single in-session
pass missed items that cross-session personas caught, and an external-CLI reviewer surfaced a few the
Claude personas shared a blind spot on. Treat it as a worked example, **not a benchmark**: the gain scales
with task complexity and how much you co-created the artifact, and an isolated reviewer also adds false
positives you have to triage. Whether the net is worth it on a given task is an empirical, per-use question.

Claude-side token cost does not increase when the extra reviewer is an external CLI — it bills to its own quota.

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
| [`CONTRIBUTING.md`](docs/CONTRIBUTING.md) | How to contribute skills and patterns |
| [`fh_integration_contract.md`](knowledge/shared/harness-core/fh_integration_contract.md) | Governance gate spec |

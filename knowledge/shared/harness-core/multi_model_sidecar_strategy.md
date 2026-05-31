---
name: multi-model-sidecar-strategy
description: Validated pattern for invoking other AI models (Gemini, Codex, Copilot CLI) as sidecars from within a Claude Code / FH session via Bash tool. Token economy, model-access fallback, and adversarial diversity use cases.
date: 2026-05-31
tags: [multi-model, sidecar, token-economy, model-access, adversarial, validated]
---

# Multi-Model Sidecar Strategy

## Thesis grounding — hierarchy of differentiation

FH's paper thesis: **the harness (specialized shell) is the durable layer; the model (core) converges across providers.**

Empirical observation from sidecar experiments (Gemini CLI + Codex CLI, same prompt):
- **Process differs** — each model approaches the problem differently, highlights different angles.
- **Results converge** — the substantive findings overlap significantly.

This convergence is precisely what the thesis predicts. And it establishes a clear hierarchy:

| Level | What varies | Degree of differentiation |
|---|---|---|
| Model A vs Model B | Process differs, results converge | Small |
| Sidecar multi-model | Process diversity, intermediate-step enrichment | Medium — useful as a process tool |
| **Harness structure (present vs absent)** | Accumulated memory, verification loops, skill methodology | **Large — the real differentiator** |

**The sidecar pattern is a process tool, not a structural differentiator.** The gap between Gemini's angles and Codex's angles is real but modest. The gap between a harness-structured workflow and an unstructured one dwarfs it.

Two shells — do not conflate:

| Shell | What it is | Layer |
|---|---|---|
| **Harness shell** (FH, forge-harness) | Methodology, rules, memory, skills — *specialization* accumulated over time | Durable orchestration layer — thesis subject |
| **Router shell** (Copilot CLI, Gemini CLI, Codex CLI) | Thin routing / access tool that selects and forwards to a model | Delivery / access mechanism — not a harness |

FH is the orchestrator. A router shell (or direct model CLI) is one kind of sidecar. Calling Copilot CLI "the harness" is a category error.

---

## Native cross-CLI portability (validated)

FH's SKILL.md format is shared across all three major AI CLIs. FH skills load natively in each environment without conversion or adaptation:

| CLI | Load mechanism | Status |
|---|---|---|
| **Claude Code** | `.claude/plugins/` native | ✅ Primary environment |
| **Codex CLI** | `SKILL.md` plugin (`fh-meta@forge-harness`) | ✅ Validated |
| **Gemini CLI** | `gemini skills install <path> --consent` | ✅ Validated |

This means FH is not just model-agnostic in theory — the methodology layer physically runs in all three CLI environments without modification. This is the empirical foundation for the cross-CLI portability claim.

## Orchestrator–sidecar model strategy

Use the strongest available model as orchestrator; delegate subsidiary tasks to lighter sidecar models for token economy:

| Role | Model selection | Rationale |
|---|---|---|
| **Orchestrator** | Strongest available (CC=Opus, Gemini=Pro, Codex=GPT-5.5) | Design, judgment, synthesis |
| **Sidecar** | Lighter versions (Gemini Flash, GPT-4o-mini, etc.) | Repetitive verification, adversarial passes, token-efficient delegation |

This combination can be freely mixed across CLIs — e.g., Gemini Pro orchestrating with Claude Haiku as sidecar, or CC Opus orchestrating with Gemini Flash. FH methodology works regardless of which combination is chosen.

## The capability

**Any FH user can delegate tasks to other models as sidecars** from within a session. The host orchestrator is always the primary CLI + FH. The sidecar is invoked via `Bash` tool — no special integration required.

### Available sidecar paths (use whichever your environment allows)

| Sidecar | Invocation | Model access |
|---|---|---|
| **Gemini CLI** | `echo "prompt" \| gemini` or `gemini -p "prompt"` | Gemini family (default: current model) |
| **Codex CLI** | `npx @openai/codex exec "prompt"` | GPT-4o / GPT-5.5 (non-interactive exec mode) |
| **Copilot CLI** (`gh copilot`) | `gh copilot suggest "prompt"` | Copilot model catalog: Codex · Gemini · Claude Opus |

---

## Empirical validation

Validated across three environments:

1. **Corporate network** — Copilot CLI sidecar (CC standalone = Sonnet-only on restricted network). Copilot CLI's model catalog provided access to Codex, Gemini, and Claude Opus.

2. **Direct Gemini CLI sidecar** — `echo "prompt" | gemini` inside a Claude Code session. Response in < 5 s. Adversarial review of `return-path-gate` SKILL.md Done When: 3 actionable issues. Adversarial review of `pipeline-conductor` Done When: 3 structural gaps (Amnesia Loophole, Activity vs Integrity gap, Escalation Paradox).

3. **Direct Codex CLI sidecar** — `npx @openai/codex exec "prompt"` inside a Claude Code session. Same target as #2: 3 non-overlapping issues (scope definition gap, return-path-gate skip justification absent, report persistence not blocking completion).

4. **Gemini native skill load** — `gemini skills install <fh-skill-path> --consent`. steel-quench, sim-conductor, harvest-loop loaded and listed as Enabled in `gemini skills list`. FH SKILL.md format is natively compatible with Gemini CLI's skill system.

**Cross-wave delta (Gemini vs Codex, same prompt)**: Process angles differ; substantive findings converge on "completion criteria check activity not integrity." This validates the thesis: results converge, process diverges — sidecar diversity adds marginal process enrichment, not structural differentiation.

```bash
# Minimal sidecar call pattern (validated)
echo "You are an adversarial reviewer. Identify the 3 most critical gaps in this SKILL.md Done When: $(tail -30 path/to/SKILL.md)" | gemini
```

This is **not a prototype** — it is a confirmed, runnable pattern.

---

## When to distribute

| Use case | Sidecar role | Example |
|---|---|---|
| **Token economy** | Offload subsidiary / verification tasks to a lighter or separately-billed model | Delegate source-grounding-audit claim extraction to Gemini while Opus handles synthesis |
| **Model-access fallback** | Reach a stronger model when the CC host is downgraded on a restricted network | CC standalone = Sonnet-only → Copilot sidecar reaches Opus |
| **Adversarial diversity** | Route a second challenger pass to a different model to reduce single-model blind spots | steel-quench primary attack (Claude) + Gemini 2nd-challenger sidecar |

---

## Mechanism (how it works)

```
FH / Claude Code (orchestrator)
    │
    │  Bash tool
    ▼
Sidecar process
  ├── Gemini CLI        → Gemini model
  ├── OpenAI/Codex CLI  → GPT-4o / Codex model
  └── Copilot CLI       → model catalog (Codex / Gemini / Claude Opus)
    │
    └── stdout → back to Claude Code session → integrated by the skill
```

- **Host is always single**: Claude Code session owns the conversation, memory, and file state.
- **Sidecar is stateless**: each call is a one-shot prompt → response. No persistent sidecar context.
- **Integration is inline**: the skill reads stdout and folds it into its own output or verdict.
- **Not an agent dispatch**: sidecar calls bypass `.claude/agents/` entirely. No AGENTS.md entry needed.

---

## Integration with FH skills

Sidecar calls are coordinated inline by the calling skill, not by a central dispatcher. Recommended pattern:

```bash
# Inside a skill Step (AI executes this via Bash tool):
SIDECAR_RESULT=$(echo "${PROMPT}" | gemini 2>/dev/null)
# Then fold $SIDECAR_RESULT into the skill's output or verdict.
```

Suggested integration points:
- `steel-quench` — 2nd-challenger pass after Wave 1 (primary Claude challenger)
- `pipeline-conductor` — cross-check a verdict with a sidecar before elevating to CONDITIONAL_PASS
- `sim-conductor` — persona simulation from a different model's perspective
- `source-grounding-audit` — Gemini reads source files as a secondary back-tracer

---

## Boundaries

- The harness (FH) is the specialization layer. Do not treat the sidecar as a second harness.
- Each sidecar call is independent (no shared context with main session by default).
- Sidecar model output is **untrusted input** — the orchestrating skill validates before accepting.
- Cost: sidecar API calls are billed separately (Gemini API key, OpenAI key, Copilot subscription).

---

## References

- `README.md §Architecture — 2-layer design` — sidecar note in Automation layer section
- `AGENTS.md §2-Layer Architecture Context` — sidecar note distinguishing Bash invocation from agent dispatch
- FH paper (Zenodo DOI: 10.5281/zenodo.20397566, arXiv: submit/7657304) — harness-as-durable-layer thesis

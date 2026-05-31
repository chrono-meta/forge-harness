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

## The capability

**Any FH user can delegate tasks to other models as sidecars** from within a Claude Code session. The host orchestrator is always Claude Code + FH. The sidecar is invoked via `Bash` tool — no special integration required.

### Available sidecar paths (use whichever your environment allows)

| Sidecar | Invocation | Model access |
|---|---|---|
| **Gemini CLI** | `echo "prompt" \| gemini` | Gemini family |
| **Codex CLI** | `npx @openai/codex exec "prompt"` | GPT-4o / Codex family (non-interactive exec mode) |
| **Copilot CLI** (`gh copilot`) | `gh copilot suggest "prompt"` | Copilot model catalog: Codex · Gemini · Claude Opus |

---

## Empirical validation

Validated in two environments:

1. **Corporate network** — Copilot CLI sidecar (CC standalone = Sonnet-only on restricted network). Copilot CLI's model catalog provided access to Codex, Gemini, and Claude Opus.

2. **Direct CLI** — `echo "prompt" | gemini` called via `Bash` inside a Claude Code session. Response received in < 5 s. Output integrated into FH orchestration flow. Verified: adversarial review of `return-path-gate` SKILL.md Done When criteria produced 3 actionable issues.

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

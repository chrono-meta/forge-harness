---
name: hybrid-orchestration-architecture-roadmap
description: Proposed (not-yet-implemented) architecture roadmap for fh as an intelligent hybrid orchestration engine — Claude Code as main driver, other CLIs/APIs as runtime-discovered sidecars, with Zero-Config standalone fallback for plugin-only users. Design intent + reconciliation against existing FH assets.
type: roadmap
date: 2026-06-09
status: proposed (design intent — NOT implemented; see §Status & Reconciliation)
tags: [hybrid-orchestration, sidecar, zero-config, jit-probing, install-wizard, roadmap, proposed]
---

# Hybrid Orchestration Architecture — Roadmap (Proposed)

> **Status: PROPOSED design intent, not current behavior.** This document captures a
> forward-looking architecture for fh. Several components it describes — a `config.json`
> engine-topology file, runtime JIT engine probing, an install-wizard that auto-builds an
> engine map — **do not exist in FH today**. Read §Status & Reconciliation first to see
> what is already shipped vs what is aspirational. Nothing here should be cited as a
> current feature.
>
> **Source**: operator design doc (2026-06-09), reconciled to FH conventions on ingest —
> pinned model versions → `{model-name}` placeholders (per `multi_model_sidecar_strategy.md`
> §Generalization #4); illustrative pseudo-code marked as such (FH's real layer is markdown
> methodology + Claude-native automation, not a Python runtime engine).

## 1. Overview

fh aims to be a **hybrid orchestration** harness: **Claude Code as the main driver (core
controller)**, with third-party CLIs / APIs mapped in as **sidecars** according to whatever
the user's local environment makes available. The goal is to escape single-model dependency
and **progressively enhance** output by discovering the user's own resources (subscription
CLIs, API keys) at runtime — while still working in a fully **Zero-Config** state for users
who copy only a single plugin/skill rather than installing the whole framework.

This is the design north star. The mechanism for *delegating to sidecars* is already
validated and shipped (see `multi_model_sidecar_strategy.md`); the *automatic
discovery/topology* layer below is the proposed addition.

## 2. Model roles (provider-agnostic)

FH convention forbids pinning version numbers or benchmark figures into durable assets
(they age and become phantom claims), so roles are stated by function, not by pinned model:

| Role | Engine slot | Function | Maps to FH skill family |
|---|---|---|---|
| **Core Driver** | `{primary-model}` (strongest available; CC host) | Full code edit, architecture, final synthesis | steel-quench, refactor, design consensus |
| **Context/Analysis Sidecar** | `{large-context-sidecar}` | Bulk log/API-spec parsing → distilled clues | harvest-loop bulk scan |
| **Test/Util Sidecar** | `{fast-util-sidecar}` | Boilerplate, unit tests, repetitive drops | speed-run / scaffolding |

> Capability/benchmark comparisons between providers change every release cycle — consult a
> live source (`/frontier-digest`, or the `claude-api` skill for Claude specifics) at decision
> time rather than trusting any number frozen into this doc. No SWE-bench figures are recorded
> here by design.

## 3. Main driver + sidecar dual channel

```
                 ┌─────────────────────────────┐
                 │      user terminal (fh)      │
                 └──────────────┬──────────────┘
                                │   [intelligent routing]
            ┌───────────────────┼───────────────────┐
            ▼ (bulk / low-cost)  ▼ (final reasoning)  ▼ (fast unit-test / repeat)
   ┌─────────────────┐  ┌──────────────────┐  ┌─────────────────┐
   │ context sidecar │  │ Claude Code (main)│  │  util sidecar   │
   └────────┬────────┘  └────────┬─────────┘  └────────┬────────┘
            └────────────────────┼─────────────────────┘
                                 ▼
                   [final quality verification + apply]
```

- **Claude Code (main)** keeps full project context/architecture and is the only writer of
  final code. This matches FH's existing rule: *"Host is always single"*
  (`multi_model_sidecar_strategy.md` §Mechanism).
- **Sidecars** are stateless one-shot `Bash`-invoked processes whose stdout is folded back in
  by the calling skill — **already the shipped mechanism**, not new.

## 4. 3-Tier routing protocol (proposed ordering)

When a skill needs a sidecar engine, probe in priority order:

```
[sidecar request]
   ├── Tier 1: subscription CLI (zero marginal cost)
   │            discover logged-in binaries: `claude -p`, `aider`, `gemini`, `codex`, `gh copilot`
   ├── Tier 2: native API call (pay-per-use)
   │            env keys: GEMINI_API_KEY, OPENAI_API_KEY, ANTHROPIC_API_KEY
   └── Tier 3: self-contained sub-agent split (fallback)
                no external sidecar → Claude Code spawns isolated sub-agent / prompt-chunking
```

> **Relation to the shipped fallback chain**: `multi_model_sidecar_strategy.md`
> §Implementation-Patterns already defines a 3-tier *fallback* chain (Copilot CLI → corporate
> endpoint → direct Gemini/Codex). The ordering here is framed by **cost/access tier** rather
> than network reachability. These are two lenses on the same fan-out; if implemented, they
> should be unified into one routing table, not maintained as two competing lists. Tier 3
> ("Claude internal sub-agent fallback") is the genuinely new contribution — it guarantees the
> chain never hard-fails even with zero external resources.

## 5. Static inheritance + dynamic JIT fallback (proposed)

```
execution request (skill / agent)
        │
        ▼
[config.json present?]   ← PROPOSED file; does NOT exist in FH today
        ├── Yes → static-inheritance mode → load priority map → run immediately
        └── No  → Zero-Config standalone mode → runtime JIT probing:
                     1. local subscription CLI scan   (Tier 1)
                     2. system API-key env scan        (Tier 2)
                     3. main-driver sub-agent fallback (Tier 3)
```

**5.1 Static config inheritance** — if an install-wizard run had persisted an engine map,
skills would adopt it as default and skip per-call scan overhead. *(Proposed: install-wizard
does not generate such a file today.)*

**5.2 Runtime JIT probing** — if no config exists (or a tool was added after install), the
harness probes the live environment on-the-fly via the Tier 1→2→3 protocol and binds the best
path. All probes failing → safe descent to Tier 3 (main model handles it).

**5.3 Zero-Config standalone self-reliance** — the key requirement for **Mode C** (plugin/skill
copied without the full framework, see `knowledge/shared/rules/modes_and_value.md`). With no
`config.json`, the module must **not error** — it switches to Zero-Config standalone mode and
JIT-probes for whatever local tools exist, then proceeds quietly. Falls back to Tier 3 if none.

```python
# ILLUSTRATIVE resolution logic — NOT shipped code.
# FH's actual layer is markdown methodology + Claude-native automation (skills/rules/hooks),
# not a Python engine. This sketch only shows the intended decision order.
def resolve_sidecar_engine(preferred="{util-sidecar}"):
    cfg = load_static_config_safe()              # Step 1: static config (if any)
    if cfg and cfg.get("mapped_engine"):
        return cfg["mapped_engine"]
    if shutil.which("aider") or shutil.which("{cli}"):   # Tier 1: subscription CLI
        return "CLI_WRAPPER_MODE"
    if os.environ.get("{PROVIDER}_API_KEY"):             # Tier 2: API key
        return "NATIVE_API_MODE"
    return "CLAUDE_SUBAGENT_FALLBACK"                     # Tier 3: peaceful fallback
```

## 6. Intelligent install-wizard (proposed extension)

Today `install-wizard` sets up the periodic-audit notification structure (zshrc hook +
sentinels + session-start mtime detection). It does **not** build an engine topology. The
proposed extension would add, at install time:

- **Binary probing** — scan `$PATH` for available CLIs/dependencies.
- **Profile mapping** — write the discovered hybrid config (the proposed `config.json`).
- **Sanity check** — a light sidecar call to confirm the pipeline actually works.

Onboarding UX phrasing (proposed):
- Minimal env → *"Configured a Claude-Code-only harness. All skills run safely via context
  splitting, no API key needed."*
- Expansion nudge → *"To enable cheaper large-analysis skills, register a sidecar API key later;
  fh will auto-detect it on the next run and apply sidecar orchestration."*

## 7. sim-conductor & core-skill improvement directions (proposed)

- **7.1 `claude -p` non-interactive pipe runtime** — exploit CC's non-interactive flag; pipe
  stdout/stdin between agents; reuse session cache via a harness wrapper.
- **7.2 Hybrid context bridge** — normalize heterogeneous sidecar output (API JSON vs CLI
  streamed text); embed an extractor (code-block / JSON-structure parser) in a bridge layer so
  callers always get structured responses regardless of invocation path.
- **7.3 Built-in sub-agent injection** — for minimal envs with no third-party CLI/API: place
  worker prompt specs (e.g. `steel-quench-worker.md`, `harvest-loop-worker.md`) into
  `.claude/agents/`, so the harness spawns Claude's own isolated-context sub-agent pool for
  parallel work. *(Note: per `operations.md`, personal agents in shared repos should be kept
  local via `.git/info/exclude` — an installer-placed agent must respect that boundary.)*

---

## Status & Reconciliation (read this before citing anything)

| Component | In FH today? | Where / note |
|---|---|---|
| Sidecar delegation via `Bash` (stateless, host-single) | ✅ Shipped + validated | `multi_model_sidecar_strategy.md` (Experiment 1·2) |
| Cross-provider perspective-diversity rationale | ✅ Shipped | same doc + `steel-quench` Wave 5 |
| 3-tier *fallback* chain (network-reachability lens) | ✅ Shipped | same doc §Implementation-Patterns |
| 3-tier *routing* by cost/access (Tier1 CLI→Tier2 API→Tier3 subagent) | 🟡 Partial | reorders the shipped chain; Tier-3 subagent fallback is new |
| `config.json` engine-topology file | ❌ Proposed | does not exist |
| Runtime JIT engine probing | ❌ Proposed | does not exist |
| Zero-Config standalone auto-heal (Mode C) | ❌ Proposed | concept aligns with Mode C in `modes_and_value.md` |
| install-wizard builds engine topology / sanity-check | ❌ Proposed | install-wizard today = zshrc hook + sentinels only |
| Hybrid context bridge / built-in sub-agent injection | ❌ Proposed | sim-conductor roadmap item |

**Conflicts resolved on ingest** (per FH conventions): pinned model versions + SWE-bench
figures dropped → `{model-name}` placeholders (avoids phantom/stale claims); Python
`engine_resolver.py` marked ILLUSTRATIVE (FH has no Python runtime layer); every non-shipped
component tagged ❌ Proposed above so this roadmap can never be mistaken for current behavior.

## References

- `knowledge/shared/harness-core/multi_model_sidecar_strategy.md` — shipped sidecar mechanism + fallback chain (this roadmap extends, does not replace, it)
- `plugins/fh-meta/skills/install-wizard/SKILL.md` — current install behavior (the topology extension would build on this)
- `knowledge/shared/rules/modes_and_value.md` — Mode C (plugin/skill-only) that Zero-Config self-reliance targets
- `knowledge/shared/rules/operations.md` — sub-agent boundary rules the built-in-injection item must respect
- `plugins/fh-meta/skills/frontier-digest/SKILL.md` — live source for current model capability/benchmark comparison (do not freeze numbers here)

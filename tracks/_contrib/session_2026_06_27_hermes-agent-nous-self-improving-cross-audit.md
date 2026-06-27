---
name: Hermes Agent (Nous Research) ↔ FH — self-improving agent cross-audit (2026-06-27)
description: Sister-asset cross-audit. A LinkedIn post (esperer) distilling Hermes Agent's official "Tips & Best Practices" reached the operator; this records the position comparison, the items worth importing, the items FH already leads, and — most importantly — the honest finding that most apparent "gaps" dissolve into deliberate FH design boundaries.
type: feedback
date: 2026-06-27
tags: [sister-asset, hermes-agent, nous-research, self-improving-agent, skills, memory, cron, messaging-gateway, mode-d, cross-audit]
originProject: forge-harness
---

# Hermes Agent ↔ FH — Self-Improving Agent Cross-Audit

> Sister-asset protocol activation (`.claude/rules/sister_asset_protocol.md`). Trigger: operator
> shared a LinkedIn post (esperer) — "Hermes Agent 잘 쓰는 법" — which distills Hermes Agent's
> official *Tips & Best Practices* doc into Korean. Same territory as FH/PMH: a self-improving agent
> with persistent memory + autonomous skill creation + skill self-improvement.
>
> **The post itself is not original methodology** — it is a faithful summary of the official doc
> (a near-identical summary circulates on Threads, @unclejobs.ai). So the audit target is **Hermes
> Agent (Nous Research)**, not the post.

## 1. Asset identity (5-min)

| Axis | Hermes Agent | FH (forge-harness) |
|---|---|---|
| Author / origin | Nous Research, open-source, released ~Feb 2026 | Operator's meta-harness for Claude Code |
| Nature | **Standalone runtime agent** — lives on your machine, own LLM endpoint, own loop | **Methodology + automation layer on top of Claude Code** — not a standalone runtime |
| Self-improvement | Auto-creates skills from 5+ step repeated tasks; skills self-improve in use; `skill_manage` tool | `#skill-candidate` (3+ reps) → `harvest-loop` → `field-harvest`; 4-axis gate; operational-adaptation loop; `verify-bidirectional` |
| Memory model | `MEMORY.md` (~2,200 chars) + `USER.md`, bounded + auto-consolidate; 8 pluggable external providers | `tracks/` · `knowledge/` · `MEMORY.md` · session cards · `CATALOG.md`; `/memory-hygiene`; pluggable companion-store backends |
| Governance | "Review auto-generated skills"; `write_approval` staged approve/deny | **Mechanically enforced**: pre-commit hook + 4-axis gate + steel/phantom-quench + HITL PR gate |
| Delivery surface | CLI **and** messaging gateway (Telegram/Slack/Discord/WhatsApp/Signal); built-in cron daemon | Claude Code native (CLI/IDE/web); cadence = **proposal**, not daemon |
| Conclusion method | "Trust the agent, review periodically" (prose guidance) | Adversarial + mechanical gates (judge-only paths forbidden) |

**Resolution difference**: Hermes optimizes for *frictionless daily reach* (be everywhere, run
itself). FH optimizes for *governed self-evolution* (every auto-change passes an adversarial +
mechanical gate before it is trusted). Same self-improving-agent territory, opposite emphasis.

## 2. Position comparison — the full tips map

Hermes' 7 official tip clusters mapped to FH assets (verified present in `plugins/*/skills/`):

| Hermes tip | FH asset (grounded) | Verdict |
|---|---|---|
| Persistent cross-session memory | `tracks/` · `knowledge/` · `MEMORY.md` · `reference_next_session_starter` · `CATALOG.md` | ✅ present |
| Memory="what" / Skills="how" split | `knowledge/` (facts) vs `plugins/*/skills/` (procedures) | ✅ present |
| Memory consolidation / hygiene | `memory-hygiene` skill | ✅ present |
| Auto-skill from repeated 5+ step tasks | `#skill-candidate` (3+ reps) · `harvest-loop` · `field-harvest` · `contention-layer` skeleton | ✅ present |
| Skills self-improve in use | 4-axis auto-gate · `operational_adaptation.md` · `verify-bidirectional` | ✅ FH deeper |
| **Review auto-skills, don't blindly trust** | New-skill pre-commit gate · `harness-doctor` · `steel-quench`/`phantom-quench` | ✅ **FH mechanically enforces what Hermes only advises** |
| `write_approval` staged approve/deny | HITL (`feedback_no_personal_commit_to_shared_repo`) · pre-commit hook · PR-proposal gate | ✅ present |
| `AGENTS.md` recurring instructions | `AGENTS.md` (Codex entrypoint) · `CLAUDE.md` | ✅ present |
| Context economy / prompt cache | `.claudeignore` · `context-doctor` · `token-budget-gate` · execution tiers | ✅ present |
| `/compress` long conversations | `context-doctor` · `/clear` timing | ✅ present |
| `delegate_task` parallel | Agent dispatch · parallel dispatch · `agent-composer` | ✅ present |
| Model selection (reasoning vs simple) | Execution tiers · Mode D model notice · `/model` guidance | ✅ present |
| Security (sandbox / access control / approval caution) | Irreversibility gates · `mcp_tool_gating` · destructive-op / pre-publish gates | ✅ FH stronger |
| **Built-in cron daemon (fresh sessions)** | Cadence rules = **proposal surface, deliberately NOT a daemon** | ⚠️ deliberate boundary (see §4) |
| **Messaging gateway (Telegram/Slack/CLI daily-driver)** | Only via recommended messaging MCP — no native channel | ❌ genuine absence (see §3) |
| External memory providers (Mem0 / knowledge-graph) | Companion-store pluggable backends (Obsidian / gbrain) | 🟡 partial, already audited 2026-06-11 |

**~90% of Hermes' best-practice surface is already present in FH**, and on the
self-improvement + governance axis FH is **ahead** (mechanical enforcement vs prose advice).

## 3. Items to import (FH ← Hermes) — listed FIRST (bidirectionality)

Honest scope: the genuine increment is **thin**, because FH already covers the methodology.

1. **Messaging-gateway boundary decision (the one real absence).** Hermes' daily-driver reach
   (talk to the agent from Slack/Telegram) is a *delivery surface*, not methodology. FH currently
   acknowledges messaging only as a recommended MCP (`recommended_plugins.md`). **Candidate, not a
   build**: a one-line stance in `modes_and_value.md` — "messaging reach is a delivery channel; FH
   routes it via MCP, does not build a gateway" — so the boundary is *recorded as chosen*, not left
   as an apparent hole. Decision belongs to operator (see Open below).
2. **"Front-load context / paste the traceback directly" as an explicit onboarding tip.** Hermes
   states it plainly; FH assumes it. A single line in the dialogue playbook closes a small clarity
   gap for new field users. (C-tier, opportunistic.)
3. **`write_approval` framing as a teachable default.** FH enforces HITL via hook; Hermes' staged
   approve/deny *vocabulary* is a cleaner way to *explain* the same gate to a Mode C user who has no
   hook. Wording import only — mechanism unchanged.

## 4. Items the hub already leads / deliberate boundaries (NOT gaps)

- **cron/daemon is a chosen boundary, not a gap.** `self_evolution_routine.md` §8 already states
  FH is "a *recommendation surface*, not a daemon dropped into the project," and §9 lists the
  salience/floor reasons. Importing a self-running daemon would *contradict* an existing deliberated
  position. Record as: **resolved-by-prior-decision**, do not "fill."
- **External memory providers already audited.** `companion_store_pluggable_cross_audit_2026-06-11.md`
  fixed the pluggable-backend axis (Obsidian / gbrain / `-be` repo). Hermes' 8 providers are more
  numerous but the *role* is identical and already pluggable. No new increment.
- **Governance depth** (4-axis gate, adversarial quench, judge-only-forbidden, irreversibility
  gates) is FH's lead. Propagation candidate *to* the Hermes community is out of scope here (no
  write access; would require the protocol's persona audit before any external proposal).

## 5. Cognitive-gap facts

- Hermes Agent released ~Feb 2026; this cross-audit dated 2026-06-27 → ~4-month independent-work
  interval on the same self-improving-agent territory before cross-linking.
- The convergence is strong evidence FH's core thesis (persistent memory + auto-skill +
  self-improvement) is now **frontier-standard**, not idiosyncratic. FH's differentiator narrows to
  **governance** — which sharpens the §Operational-Status positioning, not weakens it.

## 6. Cross-reference link judgment

- No write access to the Hermes repo → no external link insertion. If an external proposal is ever
  made, it must pass the sister-asset protocol's 3+ persona × 4-axis audit first (provider-humble
  framing, import-list-first). Not done here.
- Internal: this file is the FH-side record; CATALOG entry added for findability.

## Open (operator decision)

1. **Messaging gateway**: record as deliberate out-of-scope boundary in `modes_and_value.md`
   (one line), or leave entirely unaddressed? (Recommend: record the boundary — turns an apparent
   hole into a chosen position, costs one line.)
2. Import #2/#3 (onboarding-tip wording) — fold into the dialogue playbook opportunistically, or skip?

> Bottom line: the post surfaced a strong sister asset, but it confirms FH is **at or ahead of
> frontier** on methodology. The real deliverable is the recorded boundary decisions, not new
> features to chase.

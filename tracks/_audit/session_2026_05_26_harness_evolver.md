---
name: sister-asset-harness-evolver-2026-05-26
description: Sister asset protocol — harness-evolver (raphaelchristi) + Meta-Harness (Lee et al., arXiv 2603.28052, Stanford). Direct implementation of meta-harness outer-loop optimization as Claude Code plugin. FH + PMH upgrade candidates included.
type: sister-asset
date: 2026-05-26
tags: [sister-asset, harness-engineering, meta-harness, stanford, automation, pmh-upgrade, fh-upgrade, priority-high]
priority: HIGH — direct competitor/complement in same Claude Code ecosystem
---

# Sister Asset Cross-Audit — harness-evolver + Meta-Harness (Lee et al.)

**Plugin**: [raphaelchristi/harness-evolver](https://github.com/raphaelchristi/harness-evolver)  
**Paper**: [Meta-Harness: End-to-End Optimization of Model Harnesses](https://arxiv.org/abs/2603.28052) (arXiv 2603.28052)  
**Authors**: Yoonho Lee, Nair R., Zhang Q., Lee K., Khattab O., Finn C. (Stanford IRIS Lab)  
**Submitted**: March 30, 2026  
**License**: MIT  
**Detected via**: frontier_digest_2026_05_26 → awesome-harness-engineering search

---

## Step 1 — Asset Identity

| Field | Value |
|---|---|
| Theoretical foundation | Meta-Harness (Lee et al., arXiv 2603.28052) |
| Implementation | harness-evolver Claude Code plugin (raphaelchristi) |
| Access scope | Open-source, MIT license |
| Infrastructure required | LangSmith API key + Python 3.10+ + Git |
| Ecosystem | Claude Code / Cursor / Codex / Windsurf |
| Core claim | Outer-loop system that searches over harness CODE — +7.7pts classification, +4.7pts IMO-level math, 4x fewer tokens |

**Key academic insight** (Meta-Harness paper):
> "Performance of LLM systems depends not only on model weights, but also on their harness: the code that determines what information to store, retrieve, and present to the model."

This is the Stanford-level formalization of exactly what FH/PMH operationally implements.

---

## Step 2 — Cross-Audit

### Position comparison

| Axis | harness-evolver (Meta-Harness) | forge-harness / PMH |
|---|---|---|
| **Optimization target** | Harness CODE (prompts, routing, retrieval, orchestration) | Harness KNOWLEDGE (context, patterns, coordination) |
| **Evolution mechanism** | Fully automated: 7-stage loop, winners auto-merge to git | Human-in-the-loop: harvest-loop + field-harvest + human approval |
| **Evaluation method** | LangSmith LLM-as-judge + rubric scoring + canary runs | steel-quench adversarial waves + verify-bidirectional |
| **Proposer pattern** | Parallel agents in isolated git worktrees | parallel Agent dispatch (no worktree isolation) |
| **Memory** | Cross-iteration archive + regression guards (Consolidator) | tracks/ + knowledge/ cumulative files |
| **Scale** | Single harness optimization | Multi-project meta-coordination (N projects) |
| **Human role** | Observer (automation decides) | Architect (human approves every stage) |
| **Infrastructure** | LangSmith + Python required | CLAUDE.md + skills only |

### Structural loop comparison

harness-evolver 7-stage loop vs FH/PMH compounding loop — **independently converged on the same architecture**:

| harness-evolver stage | FH/PMH equivalent | Gap |
|---|---|---|
| **Preflight** (state validation, dataset health) | install-wizard gap diagnosis | FH: lightweight check only |
| **Analyze** (trace insights, failure clustering) | source-grounding-audit + harness-doctor | FH: manual, not trace-driven |
| **Propose** (parallel worktree agents, two-wave spawning) | agent-composer + parallel Agent | **FH: no worktree isolation** |
| **Evaluate** (LLM-as-judge + canary + rate-limit abort) | steel-quench + quench-challenger | **FH: no quantitative scoring** |
| **Select** (Pareto front + efficiency gate + constraint gate) | verify-bidirectional | FH: qualitative only |
| **Learn** (archive + regression guards) | harvest-loop + tracks/ | FH: no regression guards |
| **Gate** (plateau detection + critic/architect) | steel-quench Wave convergence | FH: manual judgment |

**Cognitive gap**: harness-evolver March 2026, FH operational since ~2025. Parallel independent development of the same loop structure. The convergence validates the architecture.

### Overlap area (combined value)

- Both treat harness evolution as a loop, not a one-time event
- Both use adversarial evaluation (Critic/TestGen vs steel-quench/quench-challenger)
- Both maintain evolution history (git history vs tracks/)
- Both distinguish "proposer" from "evaluator" roles

### Items to import: FH side

| Item | FH target | Priority |
|---|---|---|
| **git worktree isolation for parallel proposals** | agent-composer SKILL.md — add worktree branch guidance | 🟡 Medium |
| **LLM-as-judge scoring pattern** | steel-quench — add numeric scoring rubric alongside qualitative grades | 🟡 Medium |
| **Regression guard concept** | harvest-loop — add "did this session regress any prior validated item?" check | 🟡 Medium |
| **TestGen pattern** — adversarial test case generation for skills | New skill candidate: `skill-testgen` | 🟢 Low (pilot after 2 uses) |

### Items to propagate: FH → harness-evolver direction

| Item | Gap in harness-evolver |
|---|---|
| **Multi-project knowledge accumulation** | No equivalent — each run is single-harness scoped |
| **Human-in-the-loop approval gates** | Auto-merge is risky for architectural decisions |
| **CLAUDE.md context injection** | No ambient context layer — agents start cold each run |
| **Federated skill bus** | No cross-project skill sharing mechanism |

---

## PMH Upgrade Recommendations

> **Scope**: PMH is the internal production meta-harness. These recommendations are for the PMH development team (via claude-chrono). Unlike FH (knowledge-accumulation layer), PMH can adopt infrastructure-dependent patterns since it runs in a controlled internal environment.

### 🔴 P0 — Immediate evaluation candidates

**① LLM-as-judge evaluation layer for skill quality**

harness-evolver's Evaluator agent uses LangSmith-backed rubric scoring with few-shot calibration. PMH currently relies on steel-quench adversarial qualitative grades.

Upgrade path for PMH:
- Add numeric rubric scoring to `steel-quench` output (0.0–1.0 per dimension)
- Integrate with internal evaluation infrastructure (LangSmith or equivalent)
- Use scores for: promotion gate (Accepted ≥ 60% → maintain) + deprecation trigger (Rejected ≥ 40%)
- **Expected impact**: Removes subjectivity from skill promotion/deprecation decisions

**② git worktree isolation for parallel skill proposals**

harness-evolver spawns proposers in isolated git worktrees — each candidate modifies actual code independently, winning version merges automatically.

PMH equivalent today: parallel Agent dispatch without isolation (collision risk on shared files).

Upgrade path for PMH:
- `agent-composer` SKILL.md: add worktree-isolated dispatch branch for skill drafting
- Prerequisite: `EnterWorktree` tool is already available in CC harness
- **Expected impact**: Parallel skill proposal without file conflicts, clean git history per candidate

**③ Regression guard in harvest-loop**

harness-evolver's Learn stage maintains regression guards — new iterations are rejected if they regress prior validated metrics.

PMH's `harvest-loop` currently has no regression check before absorbing field patterns.

Upgrade path for PMH:
- Add Step 0 pre-check to harvest-loop: "Does this pattern conflict with or regress any currently validated skill?"
- Cross-reference against `tracks/{project}/learnings/` existing entries
- **Expected impact**: Prevents "harvest contamination" where a new pattern overwrites a valid one

### 🟡 P1 — Next quarter candidates

**④ Plateau detection for skill maturity**

harness-evolver's Gate stage detects when further evolution yields diminishing returns (plateau). PMH has no equivalent — skills are improved indefinitely without a maturity signal.

Upgrade path for PMH:
- Add to `harness-doctor`: maturity score per skill (based on evolution round count + change delta size)
- When plateau detected → promote to "stable" tier → move to maintenance cadence
- **Expected impact**: Reduces churn on mature skills, focuses evolution effort on unstable ones

**⑤ TestGen — adversarial test case auto-generation**

harness-evolver's TestGen agent generates adversarial test cases with rubric injection. PMH relies on steel-quench for adversarial coverage, which is wave-based not case-based.

Upgrade path for PMH:
- New skill candidate: `skill-testgen` — given a SKILL.md, generate 5-10 adversarial invocation scenarios
- Output feeds directly into steel-quench Wave 0 (pre-populates attack surface)
- **Pilot criterion**: 2+ confirmed uses before promoting to skills/

### 🟢 P2 — Exploratory / low priority

**⑥ Two-wave proposer spawning**

harness-evolver spawns proposers in two waves: initial broad exploration, then focused refinement. PMH currently does single-wave dispatch.

Upgrade path: `agent-composer` enhancement — add "refine wave" step after initial proposals converge.

---

## Step 3 — Cross-Reference Actions

### FH side
- [ ] Add Meta-Harness (arXiv 2603.28052) to README §Going deeper external validation block
- [ ] Add worktree isolation guidance to `agent-composer` SKILL.md
- [ ] Add regression guard step to `harvest-loop` SKILL.md
- [ ] Add numeric scoring note to `steel-quench` SKILL.md (alongside existing grade system)

### PMH side (via claude-chrono)
- [ ] P0①: LLM-as-judge rubric scoring layer design → skill promotion/deprecation gate integration
- [ ] P0②: git worktree isolation for parallel skill proposals in agent-composer
- [ ] P0③: regression guard in harvest-loop Step 0
- [ ] P1④: plateau detection in harness-doctor (maturity score)
- [ ] P1⑤: skill-testgen pilot (after 2 confirmed use cases)

---

## Status

- [x] Step 1 — Asset identity + paper confirmed
- [x] Step 2 — Cross-audit complete (FH + PMH)
- [ ] Step 3 — Cross-reference link insertion + PMH implementation

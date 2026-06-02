---
name: Hub Maturity 3-Phase Roadmap Frame (template)
description: Long-term evolution path frame for the hub. Phase I (entering maturity) → Phase II (frontier following) → Phase III (frontier leading) 3-stage model. Fixes the gap, output, completion criteria, and transition conditions for each phase as a quarterly re-diagnosis reference document. The maturity axis is the parent frame referenced by monthly level snapshots and quarterly re-diagnosis. **This file is a template — in actual hub operation, add project-specific information (timing, asset names, identifiers) to write an operating copy**.
type: reference
date: 2026-04-28
tags: [harness, maturity, roadmap, 3-phase, frontier-tracking, evolution, compounding, long-term, hub, strategic, template-frame]
scope: hub-template
---

# Hub Maturity 3-Phase Roadmap (frame)

## Why this document exists

If the monthly level snapshot captures **"where are we now"**, this document captures **"where are we going and when do we transition"**. If the quarterly re-diagnosis captures **current position vs industry frontier**, this document captures **the evolution of the relationship with the frontier itself** (follower → leader).

**Core vision**:

> The hub model matures enough to **enter the maturity phase**, **follow** the frontier's advancement direction periodically, and after that, the path where **we become the frontier**.

This vision is made explicit as 3 phases so that at each quarterly re-diagnosis, "which phase are we in · what are the conditions for the next phase transition" can be judged.

---

## 1. 3-Phase Overview

| Phase | Scope | Core gap (example) | Representative output (example) | Standard duration (example) |
|---|---|---|---|---|
| **I. Entering maturity** | Infrastructure/asset building + routine establishment | Operational gap axes remain · automation not established · 0 external propagation | Weekly audit automation · operations guide · 1-2 external assets · sub-agent judgment · self-diagnosis warning reduction | 3-6 months |
| **II. Frontier following** | Quarterly re-diagnosis routine + gap auto-detection | Single/dual input sources · no auto gap detection · cadence not confirmed | Quarterly frontier diagnosis 2 times + monthly brief established + external scan cadence confirmed | 5-8 months |
| **III. Frontier leading** | Self-invented outbound propagation + self-evolving | 0 open-source/presentation record · no self-evolving loop · 0 industry citations | Public refactor · blog/presentation 10+ per year · industry citation case accumulation | Ongoing (no completion) |

---

## 2. Current Position (fill in operating copy)

Fill in the following format in the operating copy:

```
**Phase X · ~N% progress** — infrastructure/asset accumulation status · N remaining completion gaps
```

### Achievement table (example format)

| Area | Status | Basis |
|---|---|---|
| 6-axis framework + feedback loop | ✅ | (corresponding asset path) |
| Package structure alignment | ✅ | (realignment session) |
| ... | ... | ... |

### Gaps remaining

See §3 Phase I completion criteria.

---

## 3. Phase I Completion Criteria (5 measurable criteria)

Phase II entry gate passed when all 5 are met.

| # | Condition | Measurement method (frame) |
|---|---|---|
| 1 | **Weekly audit automation established** | audit skill run 3+ times + manual N min → auto N min measured |
| 2 | **Axis N operations guide established** | orchestration guide draft + mode switch 3+ cases accumulated (if gap axis exists) |
| 3 | **External propagation N cases** | Distributed to external channel + external response received (generally 2 cases recommended) |
| 4 | **Sub-agent pilot promotion/deprecation judgment** | 2+ week observation + invocation log-based judgment (`accepted ≥ 60%` / `rejected ≥ 40%` / `invocation count ≥ N`) |
| 5 | **Self-diagnosis warning reduction** | Quarterly self-diagnosis warnings N items → 1 or fewer |

### Completion checklist derived Decision

- Phase I completion date = earliest date all 5 criteria are met
- Completion confirmation event = **Phase II entry meeting** (1 separate session, §4 entry condition check)
- No Phase II output (e.g., external GitHub scan) before Phase I completion — simplification principle violation

---

## 4. Phase II (Frontier Following) — Entry conditions, cadence, outputs

### 4.1 Entry conditions

- Phase I completion 5 criteria **all** met
- Monthly level snapshot updated 2+ consecutive times
- §2 current position re-judged as "Phase II · 0%"

### 4.2 Cadence 3-option comparison

| Option | Cycle | Pros | Cons |
|---|---|---|---|
| **(a) Quarterly only** | 3 months | Simple | Gap detection delayed 3 months (slow if frontier moves fast) |
| **(b) Quarterly + monthly light scan** | 3 months + 4 weeks | Gap detection within 1 month + 10 min addition to existing monthly routine (minimum invasive) | (None — recommended) |
| (c) Trigger-based | When stagnation detected | Resource efficient | Stagnation detection criteria + auto-alerts + trigger tags all require new infra. **Simplification principle violation risk** |

→ **Recommended: (b) quarterly + monthly**. Joining existing monthly routine = minimum invasive. Consistent with simplification principle.

### 4.3 Representative outputs (frame)

| Output | Cycle | Content |
|---|---|---|
| **Quarterly frontier diagnosis #N** | 3 months | 6-axis level change vs previous edition + 3-5 new frontier techniques integrated |
| **Monthly brief** | 4 weeks | 10-min scan of GitHub trending, Anthropic/OpenAI blog, and similar — 3-5 line summary |
| **External GitHub scan actual operation** | Monthly | Monthly 10-min scan of public repos. Sprint Contract in 5 lines |
| **Auto gap detection** | Scanner feature addition | Flag "frontier diagnosis not updated > 90 days" |

### 4.4 Completion conditions

- Quarterly re-diagnosis 2 times + monthly brief 6+ consecutive productions
- 1+ time **own methodology back-referenced from frontier** found
- 2+ axes in monthly level snapshot sustained as "leading" judgment

---

## 5. Phase III (Frontier Leading) — Entry conditions, 6 indicators, outputs

### 5.1 Entry conditions

- Phase II completion 3 conditions all met
- 3+ of N self-invented assets **observed as original concepts** for similar industry concepts
- Public seed repository external contribution record started (at least one of fork/issue/star)

### 5.2 6 Leading indicators

| # | Indicator | Measurement |
|---|---|---|
| 1 | Public seed repository record | star/fork/issue count |
| 2 | Blog/presentation | 2-3 per quarter · 10+ per year |
| 3 | Industry citation cases | External articles/seminars citing this hub/methodology |
| 4 | External organization adoption | Other companies/departments |
| 5 | Self-evolving loop demonstration | Skill generates skills |
| 6 | Self-invented industry original recognition | Adopted as industry term/frame |

### 5.3 Representative outputs

- **Public seed repository refactor** — from personal seed to collaboratable template. Team customization + common protocol separation
- **10+ blog/presentations per year** — externalize 1 self-invented asset per quarter
- **Self-evolving loop MVP** — audit skill proposes own skill generation + user approval → auto-generate → usage observation → deprecate/improve

### 5.4 Phase III has no "completion"

Phase III is an ongoing state. Instead of completion criteria, **3 maintenance conditions**:
- 3+ of 6 indicators continuously rising
- "Frontier level maintained" judgment in quarterly re-diagnosis (no regression)
- Self-diagnosis 8-item checklist failure signal 0 maintained

---

## 6. Common principles for transitions

### 6.1 Consistent simplification principle

Phase transitions are **methodology/abstraction level rises**, not **increases in file/skill/rule count**. At each phase transition, do the following first:

- [ ] Self-diagnosis 8-item checklist check — confirm 0 failure signals
- [ ] Files unreferenced 6+ months → move to `archive/` or consolidate
- [ ] Clean up previous phase temporary outputs made unnecessary by new phase entry
- [ ] Confirm CLAUDE.md and CATALOG within 200 lines
- [ ] Re-confirm optimization principle: field harness → simpler over time; meta-harness → complexity earns its scope (purge orphaned/redundant/decorative units)

### 6.2 Transition deferred on simplification failure

Above checklist not passed → **phase transition deferred**. Perform previous phase remaining work + simplification work for 1 additional month then re-check.

### 6.3 Phase regression possible

**Regression** from Phase II to Phase I also allowed. E.g., frontier following routine missed 2 consecutive times → "manual re-establishment" re-perform part of Phase I. Do not force linear progression.

---

## 7. This roadmap update cycle

| Trigger | Update content |
|---|---|
| Quarterly re-diagnosis | §2 current position re-judgment + §3·§4·§5 criteria change check |
| Phase transition event | Record corresponding phase completion + initialize next phase progress |
| Self-invented asset recognized as industry original | §5.1 entry condition counter update |
| Simplification principle violation detected | §6 transition deferral activation record |

---

## 8. Operating copy writing guide (for template users)

When moving this frame to an operating copy:

1. **Fill §2 current position** — add asset list and basis material paths
2. **Concretize §3 5 criteria** — add `current` column + `target date` column (e.g., `2026-05-17`)
3. **Recommend §4.2 cadence (b)** — if adopting other option, need to prove §6.1 simplification gate passed
4. **Add current counter to §5 6 indicators** — starting from all 0 is natural
5. **Update §2 at each quarterly re-diagnosis** + record cumulative changes in §7 trigger table

---

## 9. Related assets

- 6-axis framework — `knowledge/shared/harness-core/harness_6axis_framework.md` (frame premise)
- Monthly level snapshot — `knowledge/shared/harness-core/harness_level_snapshot_*.md` (current position)
- Quarterly re-diagnosis — `knowledge/shared/harness-core/harness_frontier_diagnosis_*.md` (following basis)
- Feedback automation — `knowledge/shared/harness-core/hub_compounding_loop.md` (Phase transition gate input)

---

## 10. One-line conclusion

**Phase I completion → Phase II frontier following (b)cadence → Phase III leading. Simplification principle is the common gate for each transition**.

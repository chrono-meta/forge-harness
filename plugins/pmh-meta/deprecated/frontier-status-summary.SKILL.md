---
name: frontier-status-summary
description: Maps which assets to use for externally distributed materials (briefings, cards, guides) by audience type. Performs cross-referencing only — does not transform hub asset content.
user-invocable: false
allowed-tools: ["Read", "Grep", "Glob"]
model: sonnet
version: 0.4
status: deprecated
deprecated_date: 2026-05-18
deprecated_reason: ~80% dependency on personal assets — does not meet FH general-purpose skill criteria. The positioning judgment value is absorbed into install-wizard Step 0-A.
---

> **DEPRECATED (2026-05-18)**: ~80% dependency on personal assets; does not meet FH general-purpose skill criteria. The core value of audience-based asset cross-referencing is absorbed into install-wizard Step 0-A (FH suitability pre-flight).

# frontier-status-summary — Frontier Status + External Distribution Asset Cross-Reference

A skill for cross-referencing externally distributed assets by audience type, created after reaching Phase I completion and Phase II entry signals. No asset transformation — invocation tools only (consistent with simplification principle — 0 new assets created).

## Trigger Utterances

Utterance patterns:

1. **Status summary request**: "show frontier status", "where are we at", "where are we now", "what Phase are we at"
2. **External distribution material alignment**: "align external distribution materials", "materials for {audience}", "what do I show to {audience}"
3. **Identity cross-reference**: "meta harness identity", "differentiating message", "unique value"
4. **Audience-based invocation**: "for engineers", "for decision-makers", "for non-technical audience", "external presentation"

**Exceptions** (this skill does not apply):
- Request to directly edit asset content → edit the asset directly (no cross-ref needed)
- Request to write new asset → do not call this skill · only cross-ref 4 assets for audience classification then determine new audience/volume/axis

## Asset Matrix

| # | Asset | Audience | Volume | Channel | Status | Axis |
|---|---|---|---|---|---|---|
| 1 | `briefings/harness_engineering_intro.md` | Engineers (org-wide) | ~3 pages | Wiki / doc sharing | **published** | 2·3 |
| 2 | `briefings/expected_roi_meta_harness.md` | Decision-makers + engineers | Table-heavy | (TBD — follow-up to #1) | **draft** | 6 |
| 3 | `briefings/harness_intro_outsider_guide.md` | Non-technical / external | 5-minute read | Slack canvas → wiki | **first distribution decided** | 3 |
| 4 | `briefings/frontier_arrival_report.md` | All 3 audiences combined | ~3 pages | (review before external send) | **draft** | 1·2·3·6 |

Asset location prefix: `<hub cwd>/knowledge/external/`

## Audience-Based Call Guide (at external distribution time)

### Engineers (org-wide) → Briefing #1 first priority

- **Recommended**: full engineer-level briefing with practical guidance
- **Update trigger**: when significant harness milestones are reached
- **Combined asset review**: whether ROI brief (#2) content should be merged when decision-maker audience joins

### Decision-makers → ROI brief first priority + frontier arrival report reinforcement

- **Status**: draft · awaiting actual measurement data
- **Differentiation points**: operating model · frontier registration · human-AI collaboration insights + bidirectional self-validation
- **Combination**: frontier arrival report (#4) combined propositions for decision impact

### Non-technical / external → Intro guide first priority

- **Status**: first distribution decided (Slack canvas → wiki persistence 2-stage)
- **Update additions**: external academic baseline refinement + humanistic meta-principle closing
- **External distribution adaptation**: switch to coach mode (`feedback_amplifier_vs_coach_mode`) + conservative transformation of "combat/frontline" expressions

### All 3 audiences / external presentation → Frontier arrival report first priority

- **Status**: draft · review before external distribution
- **5-axis combined propositions**: (1) organization-specific adaptation (2) multi-instance persona (3) authority baseline 7+ (4) Layer 5/6 user cognition (5) bidirectional evolution user-mediated

## Usage Flow (AI-side procedural steps)

### Step 1. Classify Utterance Audience

First classify audience/purpose from utterance:

**General environments**:
- Engineers (practical guide) → #1
- Decision-makers (ROI decision) → #2
- Non-technical / external (intro) → #3
- Combined / external presentation → #4

**External user environment fallback**:
- User's own audience mapping (e.g., peer developers / managers · decision-makers / external users / conference audience 1~N)
- Audience classification auto-extraction path: grep audience matrix from user environment's own baseline (CLAUDE.md · README · memory etc.) / extract directly from utterance if absent

### Step 2. Call Cross-Reference Assets

**Hub environment**: Read applicable asset + extract frontmatter `status` · `last_updated` · `paired_with`. Check consistency with this skill's matrix (self-catch if drift found).

**External user environment fallback**:
- Auto-map user's own external distribution asset location (e.g., `docs/external/` · `briefings/` · `posts/` · `wiki/`)
- Auto-create user's own asset matrix (if frontmatter absent, check consistency from first 100 lines of body + creation date metadata)
- This skill's original matrix = reference baseline (do not use directly)

### Step 3. One-Line Distribution Guide per Audience

"{audience} target = #{N} {asset name} first priority · channel {channel} · status {status} · delta {key delta}". Supplementary notes in 1-2 lines if additional materials exist.

**External user environment fallback**: same one-line guide format / apply user's own asset matrix + audience classification.

### Step 4. External Distribution Obligation Check (external distribution time only)

Check only when distributing externally (conference / tech blog / external venue):

**Cross-applicable to all user environments**:
- Switch to coach mode: `feedback_amplifier_vs_coach_mode` / in external user environments use user's own coach mode baseline or general distribution guide (target audience perspective first)
- Persona simulation pre-check: `feedback_persona_simulation_for_external_assets` (3+ virtual reader audit) / `hub-persona-auditor` agent call possible (cross-applicable to all environments)

Skip this step for internal distribution.

### Step 5. Update Trigger Catch (cascading check)

When asset frontmatter `last_updated` < last decision persistence time:
- Catch asset integration update candidates (follow user-approved update gate)
- State 1 candidate (simplification guard check — update only on explicit user decision)

## Constraints

- **This skill = cross-ref · invocation tool only. No asset body editing** — asset transformation inconsistency prevention
- **User approval gate**: external distribution timing decision is the user's. This skill = material alignment + guidance only
- **Simplification guard consistency** — when creating/modifying this skill itself, update SKILL.md only. No separate asset creation
- **Markdown editing discipline** — when updating asset integrations, prefer Edit

## External User Environment Adaptation Path (v0.3)

This skill's asset matrix + audience-based call guide = original developer hub environment examples. Core essence = **"project asset cross-ref + audience-based distribution guide"** — no asset body transformation · invocation tool only — cross-applicable to all user environments.

### Fallback Matrix

| Hub environment dependency | External user environment fallback |
|---|---|
| 4 external distribution assets | User's own external distribution assets (company wiki / blog / GitHub README / conference materials / Slack canvas etc.) — this skill auto-maps user's own asset matrix |
| Asset location prefix | User's own external distribution asset location (e.g., `docs/external/` · `briefings/` · `posts/` · `wiki/`) |
| 4 audience classifications (engineers · decision-makers · non-technical · combined) | User's own audience classification (e.g., peer developers · managers · external users · conference audience) — auto-map 1~N audience matrix for user's environment |
| Step 4 external distribution obligation check | Cross-applicable to all user environments (coach mode switch · persona simulation · expression adaptation baseline general) |

### Documented Limitations

- **Asset matrix** = original developer's own external distribution assets / reference only for external users
- **Audience-based call guide** = original developer environment (limited to org-specific audiences) / external users map their own audiences + cross-ref their own assets
- **This skill = highest personal asset dependency among available skills** / external users use only this skill's essence (audience classification · cross-ref · distribution guide) / original examples are for reference

---
title: FH Platform Sustainability — Plan B + Simplification Criteria
type: strategy
date: 2026-05-18
tags: [sustainability, plan-b, simplification-gate, scenario]
---

# FH Platform Sustainability

> **Purpose**: Document how forge-harness survives and evolves in scenarios where the Anthropic official ecosystem expands. Describes simplification gate criteria and meta-harness specification principles together.

---

## 1. FH Survival Strategy Per Anthropic Official Ecosystem Expansion Scenario

As Anthropic develops Claude Code, some FH functions may overlap with default features. This section states FH's differentiation points and survival strategy for each scenario.

### Scenario A: Anthropic official skill marketplace launches

**Risk**: If Anthropic operates an official skill marketplace, FH's plugin distribution function could be replaced.

**FH differentiation**:
- **Organization-specific domain curation**: Generic skills in the official market vs FH's optimized combinations for your organization's specific infrastructure — irreplaceable
- **Organizational context preservation**: `tracks/` session history and `knowledge/` domain knowledge are organization-specific assets — cannot be transferred to the official market
- **Federated market role**: FH becomes a sub-channel (specialized marketplace) of the official market → actually strengthens canonical source positioning

**Strategy**: When official market launches, use `marketplace-gate` skill to select FH assets worth registering in the official market → contribute to the official market in reverse.

---

### Scenario B: Claude Code harness diagnostic features built-in

**Risk**: Features similar to `harness-doctor` and `context-doctor` may be added as Claude Code default features.

**FH differentiation**:
- **Organization context-specific diagnosis**: Default features are generic — FH has organization-specific diagnostic layers (your GHE structure, network policies, etc.)
- **Three-Doctor Loop**: `harness-doctor` + `context-doctor` + `sim-conductor` closed-loop connection is a system, not a single feature — not replaceable by one default feature
- **L4~L5 layers**: Field project connection diagnosis (L4) + skill activity, context fit, and effect indicators (L5) are FH-unique layers

**Strategy**: Delegate L1~L3 that overlap with default features to defaults, and FH focuses on L4·L5 organization-specific layers.

---

### Scenario C: Organization-internal marketplace newly created

**Risk**: If an internal official marketplace is created by your organization's leadership, FH's internal distribution role could be replaced.

**FH differentiation → FH becomes canonical source**:
- FH = the **original input** for the internal marketplace. Verified skills originate from FH → the market is a distribution channel
- `marketplace-gate` skill already performs pre-registration 5-point suitability gate — can naturally integrate with the internal market quality gate
- `field-harvest` feeds field patterns back to FH → plays the role of automatic supply pipeline to the internal market

**Strategy**: When internal marketplace is created, position FH as canonical source. Register FH in the internal market as an official source.

---

### Common principle: Replacement vs Complement judgment criteria

| Judgment criterion | Replaced (delegate) | Complement maintained |
|---|---|---|
| Generic function | Delegate to default feature + remove from FH | — |
| Organization-specific function | — | Maintain in FH + layer on top of default feature |
| Domain knowledge assets (`knowledge/`) | — | FH-unique — irreplaceable |
| Session history (`tracks/`) | — | FH-unique — irreplaceable |
| Cross-project synergy combinations | — | FH-unique combination — not possible with single default feature |

> **Core principle**: FH differentiates through **combination, context, and accumulation** rather than feature competition. As default features get stronger, the value of FH's combination layer grows more.

---

## 2. Simplification Gate Criteria

> **Basis**: "A good harness gets simpler over time. If it's getting more complex, something is wrong." — CLAUDE.md throughline

### Required checks before adding new skills (RULE-AUTO-EXPANSION-GATE)

Every time a new skill addition proposal arises, the following checklist must be passed first.

**Checklist** (check in order):

```
[ ] 1. Is there an existing skill among the current skills that can cover it?
       → If yes: replace with existing skill SKILL.md improvement. No new creation.
       → If no: proceed to next check.

[ ] 2. Did it pass `/asset-placement-gate` 4-criteria judgment?
       → ①(cross-project value) + ④(non-duplicate with existing skills) must pass
       → If not passed: no new creation.

[ ] 3. Has it been demonstrated as a pattern repeated 3+ times in the field?
       → 1-2 time pattern: mark as candidate only + ★ 1 → create properly after 3+ accumulation
       → 3+ time pattern: creation possible.

[ ] 4. Can `/marketplace-gate` Check 1~5 PASS?
       → If FAIL items exist: revise then re-verify.
```

All 4 checks must pass to proceed with creation. **If any one fails, no creation**.

### Existing skill deprecation criteria

`harness-doctor` L5-A INACTIVE_90D judgment = Deprecation Gate entry:

| Status | Criteria | Handling |
|---|---|---|
| INACTIVE_30D | 0 times within 30 days | `/sim-conductor D skill {name}` — trigger phrase verification |
| INACTIVE_90D | 0 times within 90 days | Deprecation Gate — consider deprecation/consolidation |
| Deprecation confirmed | INACTIVE_90D + coverable skill exists | archive + remove corresponding skill SKILL.md |

---

## 3. Meta-Harness Specification Simplification Principle

> **Core proposition**: "The meta-harness gets simpler **within its own specification (meta layer)** — do not evaluate by single project standards."

### Server room vs data center distinction

| Classification | Criteria | Application |
|---|---|---|
| **Server room** (single project) | 200-line CLAUDE.md standard | Single project exceeds 200 lines = M-tier |
| **Data center** (meta-harness) | Meta layer specification standard | FH CLAUDE.md 500-line standard / 16 skills as upper limit standard |

`harness-doctor` L2 complexity diagnosis automatically applies this separation:
- When FH cwd is detected → use 500-line standard instead of 200-line standard
- Prevents the error of `harness-doctor` judging FH's own CLAUDE.md as M-tier by single project standards

### Meta-harness self-constraint prohibition

Prohibit the pattern of applying external standards (single project complexity standards) to the meta-harness to self-constrain:

- **Prohibited**: "FH has 16 skills, it's gotten complex → needs to be reduced" (single project standard applied)
- **Allowed**: "Among FH skills, some have 0 invocation records within 90 days → those skills enter Deprecation Gate" (meta layer standard applied)

Judgment standard: **If there are no real-use problems, no simplification pressure**. Simplification is solving real-use problems, not reducing complexity.

---

## 4. External Contribution Facilitation Structure (not one-way)

FH aims for a **bidirectional contribution structure**, not one-way distribution.

### Contribution occurrence examples

| Contribution direction | Example | Channel |
|---|---|---|
| FH → field | Skill/agent distribution, session context connection | plugin install, clone |
| Field → FH | Field pattern feedback (`field-harvest`) | PR |
| External → FH | External user contributions, cascade β | External PR / autonomous operation |

### cascade β demonstration

- An external user (not the owner) autonomously operated FH skills → caught and merged a bug in a PR
- Contribution from external project: owner contributed to that project → demonstrated structure where FH facilitates external contributions

**Meaning**: FH looks like a 1-contributor project but it's an **amplifier structure** where contributions to other projects occur through FH.

---

*Reference: `CONTRIBUTING.md` (PR rules) · `plugins/fh-meta/skills/asset-placement-gate/SKILL.md` (new asset judgment) · `plugins/fh-meta/skills/harness-doctor/SKILL.md` (L5 activity check)*

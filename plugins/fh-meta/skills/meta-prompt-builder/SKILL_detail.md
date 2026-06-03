---
name: meta-prompt-builder-detail
description: On-demand detail for meta-prompt-builder. Holds the onboarding-time Meta-Simulation Validation Criteria (3-axis measurement + validation scenarios + marketplace-gate). Not needed per-invocation; read after onboarding when validating the skill itself.
load: on-demand
---

# meta-prompt-builder — Detail (on-demand)

## §Meta-Simulation Validation Criteria

**(required after onboarding)**

Not persona simulation — **functional and performance measurement** along 3 axes:

**Axis 1. Goal achievement rate (functional accuracy)**
- Inject meta-prompt-builder-generated prompts into actual agents
- Binary judgment on whether Done When criteria are met
- Measurement: Done When achieved (1/0) × number of Waves

**Axis 2. Context alignment (context quality)**
- Grep cross-validation of whether generated Context field matches actual harness state
- Measurement: false positives (missing paths, stale version references) / total Context items

**Axis 3. Constraint validity (guard effectiveness)**
- Whether simplification guard violations occur when generated prompts are executed
- Measurement: violation count (target: 0)

**Validation scenarios**:

- Scenario 1 (core): Compare meta-prompt-builder usage vs direct phrasing
  - Pass criteria: Achieve same Done When in ≤70% of conversation turns
- Scenario 2 (edge): Graceful fallback when agent-composer returns "cannot orchestrate"
  - Pass criteria: "No orchestration plan → redirect to direct 4-field input" transition (no error stop)
- Scenario 3 (stress): WARN emission rate 100% when Done When is ambiguous
  - Pass criteria: WARN 100% across 3+ ambiguous expression tests

**Onboarding gate**: marketplace-gate check must pass.

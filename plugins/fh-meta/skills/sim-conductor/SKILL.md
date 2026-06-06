---
name: sim-conductor
description: Autonomously runs external user reaction simulations, internal audits, ideation scans, artifact validation, and quality reviews. Profiles the target artifact first, then derives task-appropriate personas, dispatches them as parallel agents, classifies findings into M/S/R tiers, and completes the pipeline through to commit automatically.
user-invocable: true
allowed-tools: ["Read", "Write", "Bash", "Grep", "Glob", "Agent"]
model: opus
---

# sim-conductor — Meta-Simulation Automation Orchestrator

> Profiles target → derives personas → dispatches parallel agents → M/S/R triage → commit.
> Personas are sourced installed-first → built-in fallback → external install. Scale: 3 to 16 by task complexity.

## Invocation Triggers

| Trigger pattern | Suggested Area |
|---|---|
| "Look at this from an external user's perspective", "How would someone else see this?" | Area A |
| "Check the harness", "asset audit", "internal audit" | Area B |
| "Any new ideas?", "ideation scan", "naming candidates" | Area C |
| "Review this code" (pre-PR), "review this prompt" | Area D (code) |
| "Check if the session card is correct", "does the skill actually work", "memory cold-start validation" | Area D (consumer) |
| "Is the output good?", "artifact quality review" | Area E |

Proposal format: `"If it's related to [X], should I simulate with /sim-conductor [Area]?"`

### Natural Language Triggers

| Example utterance | Intent | Mapped Area |
|---|---|---|
| "Validate our system virtually" | Full system simulation | Area B |
| "Test it with personas", "Run an external user simulation" | External user reaction | Area A |
| "Look at it through someone else's eyes" | External perspective | Area A |
| "Validate that this actually works" | Real-usage validation | Area D |
| "Find problems aggressively" | Adversarial validation | Area B (devil persona) |

## Triggers

```
/sim-conductor                        # default: Area C auto-run
/sim-conductor A                      # external user simulation
/sim-conductor B                      # internal meta audit
/sim-conductor C                      # Innovator scan
/sim-conductor all                    # full A + B + C
/sim-conductor A --target <path>      # specific asset target
/sim-conductor D --target <file>      # code/prompt multi-persona review (pre-PR)
/sim-conductor D session [--target]   # session card cold-start validation
/sim-conductor D skill <name>         # skill trigger utterance consumer simulation
/sim-conductor D memory <file>        # memory file cold-start validation
/sim-conductor E --target <file>      # artifact quality review (post-pipeline)
```

**Frequency limits**: Area A after asset changes or manual trigger · Area B max once/week · Area C/D/E no limit.

---

## Step 0 — Environment Sync

Auto-detect harness root, sync sim clone if present, set `$REPORT_DIR`.

> **Detail**: See `SKILL_detail.md §Step0-Bash` — harness root detection, sim clone sync, report dir creation — read when executing Step 0.

**Area B frequency check**: Previous Area B report within 7 days → stop + report date. No file found → treat as first run.

---

## Step 0.3 — Target Profile Analysis

> **Schema**: `knowledge/shared/harness-core/tpa_schema.md` — canonical field definitions, artifact type table, gate routing. Use §Profile Output Format for output block.

Runs when Area is unspecified, or when target file is provided before Area selection.
**Skip** if user provides a complete directive (e.g. `/sim-conductor A --target <file>`).

Read target artifact(s) → classify on 5 dimensions → output recommendation → user confirms or overrides:

| Dimension | Signal → Weight shift |
|---|---|
| `artifact_type` | SKILL.md / design-doc → Area B + D-skill↑ · README / CHEATSHEET → Area A↑ · code / config → Area D-code↑ |
| `audience` | external installer / first-time user → newcomer↑ · internal team only → devil↑ |
| `claim_density` | 3+ stated benefits or superlatives → devil-advocate↑ |
| `risk_level` | external publish / marketplace listing → steel-quench prerequisite triggered |
| `novelty` | first-of-its-kind / no prior session evidence → phantom-quench recommended |

```
Target Profile output:
  artifact_type: [type]
  audience: [internal | external | mixed]
  claim_density: [low | medium | high] ([N] stated claims)
  risk_level: [low | medium | high]

Recommendation:
  Areas: [list + rationale]
  Persona composition: [list + weight]
  Scale: [Minimum 3 | Extended 4–8 | Full ≤16]
  Prerequisites: [steel-quench / phantom-quench / none]
```

#### Persona Discovery (after profile → before dispatch)

After profiling, sim-conductor determines the needed perspective types, then maps each to the best available agent:

```
For each needed perspective:
  ① Scan installed plugins + .claude/agents/ → exact match? → use it
  ② Built-in fallback palette → approximate match? → inject as prompt directive
  ③ GAP: no ①② match for a high-weight perspective
       → query /plugin-recommender: "find agents for [perspective] matching [artifact_type] context"
       → present: name · install command · estimated fit · token cost
       → user chooses: install now / skip / substitute with ②
```

Persona Discovery output:

```
Persona Map:
  newcomer       → [installed agent name] OR [built-in fallback]
  devil-advocate → [installed agent name] OR [built-in fallback]
  [profile-specific role] → ⚠️ GAP — plugin-recommender recommends: [X] (install? y/n)
```

Gaps on **high-weight personas** (from profile) block dispatch until resolved. Gaps on low-weight personas → auto-fill with built-in fallback, no block.

**Degraded coverage rule**: When user skips a high-weight gap (substitutes with built-in fallback), flag in the Step 3 report under "Persona composition used" as `⚠️ degraded: [perspective]`. Do not silently proceed. Degraded coverage on risk_level=high targets → additionally warn before dispatch.

Overriding a prerequisite recommendation requires explicit "skip [prerequisite]" utterance.

> **Detail**: See `SKILL_detail.md §PersonaDiscovery` — plugin-recommender query format, gap resolution decision tree, persona map examples for each artifact type — read when running Persona Discovery.

> **Detail**: See `SKILL_detail.md §Profile-Examples` — worked profiles for SKILL.md, README, bash script, design doc — read when result is ambiguous or to calibrate weights.

---

## Step 0.5 — Precondition Validation

Proactively surface 1 concern, then confirm whether to proceed. Skip if no concern.

| Check | Concern trigger condition |
|---|---|
| Area B frequency guard | Previous run within 7 days + S-tier unresolved |
| Unresolved M-tier | New simulation without processing previous M-tier |
| steel-quench not run | Area A in external publish context → **mandatory gate: Area A does not proceed until steel-quench completes** |
| Self-recursive path | sim-conductor attempting to auto-PR its own M-tier |
| Goal-method alignment | Requested Area doesn't match actual problem |
| D/E --target missing | Area D(code)/E runs without --target file |
| D session target not found | Session start card file not found → confirm path |
| E execution timing error | Area E before pipeline run (no artifact yet) |

Concern format: `"One thing to check before [Area X]: [concern]. Proceed?"`

---

## Step 1 — Area-Specific Simulation

### Area A — External User Perspective

Target: skill descriptions, README, CHEATSHEET entry points.

#### Task-Adaptive Persona Selection

sim-conductor does **not** run a fixed persona set. It derives needed perspectives from the task, then sources each persona in priority order:

```
① Installed first — scan installed plugins + .claude/agents/ for a matching persona/agent
② Built-in fallback — inject role as prompt directive into general-purpose Agent (Path B)
③ External fetch — chain to /plugin-recommender when ①② insufficient for high-stakes tasks
```

Built-in fallback palette (② tier):

| Role | Perspective | Focus |
|---|---|---|
| Newcomer | First-time user, zero development context | Clarity, terminology, onboarding friction |
| Power-user | Advanced user, edge cases | Undocumented behavior, limits |
| Devil-advocate | Adversarial critic | Claim-evidence gaps, naming-substance mismatch |
| Domain-expert | Adjacent-field subject matter expert | Technical accuracy, completeness |
| Skeptic | Pragmatic outsider | ROI, "why not just X?" |

Derive task-specific personas (e.g. "security auditor", "non-native reader") when the task profile demands it.

#### Scale

| Scale | Count | When |
|---|---|---|
| **Minimum** | 3 | Routine Area A — most task-relevant 3 perspectives |
| **Extended** | 4–8 | High-stakes publish / external release |
| **Full** | Up to 16 parallel | Pre-major-version / architecture review |

All personas run as **parallel Agents** — no sequential bottleneck. Use agent-composer Medium/Large fan-out for Extended/Full.

**Simplification guard**: Routine internal audits → ② built-in fallback at Minimum scale. Chain to ③ only when a needed perspective has no ①② match, or stakes are high.

#### Multi-Team Mode (when external CLIs available)

When 1+ external CLIs detected, Area A upgrades to Multi-Team Panel: each CLI forms an independent team. Cross-team: 2+ teams flag same issue → tier-up (S→S-confirmed). External-only findings → "Claude blind spot" flag.

Pre-entry user confirmation required before multi-team execution.

> **Detail**: See `SKILL_detail.md §MultiTeam` — team formation table (T0–T4), CLI detection bash, confirmation dialog, cross-team synthesis format — read when multi-team mode activates.

**A-1** (Newcomer Agent) — description friendliness · onboarding friction · terminology clarity
**A-2** (Power-user Agent) — install conflicts · duplication · silent overwrite
**A-3** (challenger Agent, artifact_type="SKILL") — claim-evidence gaps · angles U3, U5, S2

> ⚠️ **Human review gate**: Area A S-tier judgments require owner review before entering AI-AI loop.

---

### Area B — Internal Meta Audit

Target: all fh-meta assets (skills + agents + plugin.json).

> **Self-recursive caution**: When M-tier found in sim-conductor itself → report only, delegate to user.

**Dispatch pattern**: hub-persona-auditor ∥ persona-innovator (parallel) → challenger (after, with both outputs as context)

1. **hub-persona-auditor** — README/CHEATSHEET as external briefing, 4-axis review, 3-tier suggestions
2. **persona-innovator** (Mode I) — naming gaps + structural gaps + 3-5 candidates
3. **challenger** (artifact_type="SKILL") — receives 1+2 outputs, angles U2, D3, U5 — "what was missed?"

Rationale: 1+2 run without influencing each other; challenger synthesizes both perspectives independently, avoiding Cost of Consensus.

> **Detail**: See `SKILL_detail.md §AreaB-Baseline` — external baseline injection methods, dual-validation principle, Area B → steel-quench handoff — read when setting up Area B defenses.

> ⚠️ **Human review gate**: Area B convergence is provisional until owner confirms.

---

### Area C — Innovator Scan

Runs independently. Skip if included in Area B.

**persona-innovator** (Mode F = Internal + External): current harness gaps + frontier scan. Output: naming candidates + absorption signals + top 1 priority action.

---

### Area D — Artifact Validity Validation

| Mode | Trigger | Core question |
|---|---|---|
| **code** | `/sim-conductor D --target <file>` | Is the code/prompt well-built? |
| **consumer** | `/sim-conductor D session/skill/memory` | Does the artifact work for the intended consumer? |

#### D-code — Profile-Aware Persona Routing

Persona composition adapts to `artifact_type` from Step 0.3 profile:

| Artifact type | Primary persona | Supporting persona | Focus |
|---|---|---|---|
| SKILL.md / design doc | challenger (artifact_type="SKILL") | Newcomer | Governance gaps, behavioral rule coverage |
| Python / JS / bash code | challenger (artifact_type="Code") | Power-user | Edge cases, performance, security surface |
| Prompt / config | Newcomer | challenger | Interpretation errors, implicit assumptions |
| Auth / security-sensitive | challenger + Security-auditor† | Power-user | Attack surface, privilege escalation |

† Security-auditor = built-in fallback role (② tier) injected as prompt directive.

All personas run in parallel. Findings = M/S/R → M-tier items fixed immediately.

#### D-consumer — Artifact Consumer Simulation

Consumer agent attempts actual use (not just reads and judges). Grades: F (functional) / P (partial → S-tier) / B (broken → M-tier immediate fix).

> **Detail**: See `SKILL_detail.md §AreaD-Consumer` — D-session 4 questions, D-skill cold-start procedure, D-memory check items, verdict criteria — read when executing D-consumer.

---

### Area E — Artifact Quality Review

Domain-expert objection (E-1) + Practitioner confusion (E-2) in parallel → Pattern structuring (E-3) integrates both.

> **Detail**: See `SKILL_detail.md §AreaE-Detail` — E-1/E-2/E-3 execution, finding format, pattern naming procedure — read when executing Area E.

---

## Step 2 — Synthesis

| Tier | Criteria | Action |
|---|---|---|
| **M (Mandatory)** | Blocks external user entry / naming-substance mismatch / security/trust damage | Immediate fix required |
| **S (Strong)** | Feature degradation / found by 3+ personas | Address within next session |
| **R (Recommended)** | Improvement value / found by single persona | Backlog |

**Deduplication**: Multiple personas → same location: M > S > R.

**Early Convergence Detection**: 2+ Areas independently classify same item as M-tier → immediate fix, remaining Areas continue for S/R coverage only.

---

## Step 3 — Report

File: `$REPORT_DIR/sim_YYYY_MM_DD_area_[X].md`

> **Detail**: See `SKILL_detail.md §Report-Format` — full report template with frontmatter, M/S/R sections, emerging asset candidates — read when writing the report.

---

## Step 4 — PR or Direct Commit

1+ M-tier → fix immediately → commit. PR creation requires explicit user request.
0 M-tier → commit report only + report S/R backlog.

> **Detail**: See `SKILL_detail.md §PR-Bash` — branch creation bash, commit + push, gh pr create template — read when creating a PR.

---

## Human Gate Principle

Convergence within an AI-AI loop is **provisional**. Elevated to final only after human gate.

| Stage | Human gate condition |
|---|---|
| Area A S-tier | User reviews + says "convergence approved" |
| Area B convergence | AI-AI loop is provisional → elevated after user confirmation |
| M-tier auto-fix | Commit after fix (no PR gate); PR requires explicit user request |
| Three-Doctor Loop end | User reviews convergence and decides next action |

---

## Done When

| Condition | Verdict |
|---|---|
| `sim-conductor [Area X] complete` format output | ✅ Simulation complete |
| 1+ M-tier → fixed + committed (or "none") | ✅ Prescription complete |
| Report `tracks/_meta/sim_YYYY_MM_DD_*.md` saved | ✅ Persistence complete |
| 0 M-tier → report committed + S/R backlog reported | ✅ Health check complete |

Verdicts: PASS · CONDITIONAL_PASS (S/R only, or Area B cadence skip) · FAIL (M-tier unresolved) · ESCALATE (persona conflict requiring human judgment).

**Mandatory for Area A (external publish)**: steel-quench must complete in same session before Area A is marked complete.

---

## Simplification Guard

- Area B 2+ times in one week: check whether previous S-tier resolved first
- New simulation without processing M-tier: warn about unresolved M-tier
- Add new persona: require 1+ empirical cases not captured by current palette

---

## Operations Notes

**AI-AI Loop Bias Defense**: sim-conductor → hub-cc-pr-reviewer → sim-conductor loop shares LLM cognitive blind spots. Internal convergence is "provisional convergence" — elevated only by external review or human gate. Area A/B convergence without human gate = incomplete.

---

## Three-Doctor Loop Integration

harness-doctor (structure) · context-doctor (context) · sim-conductor (future behavior) form a closed loop.

| Situation | Next skill |
|---|---|
| Structural problem in simulation results | `/harness-doctor` |
| Token waste pattern | `/context-doctor` |
| All three mentioned simultaneously | Three-Doctor Loop: diagnosis→prescription→re-diagnosis cycle |
| Area A before external publish | `/steel-quench` **required** first — mandatory gate |

---

## Path B (External Environment)

When `~/sim/` absent: fallback to harness root, logical isolation only.

> **Detail**: See `SKILL_detail.md §PathB-Detail` — git fallback, logical isolation prompt directive, Area restriction rules — read when running in external/restricted environment.

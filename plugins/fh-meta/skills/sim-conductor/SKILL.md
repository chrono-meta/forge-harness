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
| "Find problems aggressively" | Adversarial validation | Area B (`challenger`) |

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
| `audience` | external installer / first-time user → beginner↑ · internal team only → challenger↑ |
| `claim_density` | 3+ stated benefits or superlatives → challenger↑ |
| `risk_level` | external publish / marketplace listing → steel-quench prerequisite triggered. **Mechanical floor (not judge-only)**: any of — publish/marketplace target · public-surface or visibility change · auth/secret-handling or executable code · an FH asset under the 4-axis gate — **forces `risk_level ≥ medium`** regardless of profiler judgment. The floor closes the "fool the profiler into `low` to skip Step 0.6" seam; the judge may only raise above the floor, never below it. |
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
  beginner       → [installed agent: beginner] OR [ad-hoc directive]
  challenger     → [installed agent: challenger] OR [ad-hoc directive]
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

## Step 0.6 — Cross-Model Coverage Gate (risk≥medium — hard)

Closes the homogeneous-blind-spot + formatting-flattery vector (judge-robustness swarm, 2026-06-13):
a panel of same-session Claude sub-agents shares one model's blind spots, so a clean verdict can be
flattery the **whole panel** is blind to — and with no quotable-rule violation, no persona escalates.
For `risk_level ≥ medium` targets (from Step 0.3), at least one persona MUST come from a source
**outside the orchestrator's own session context**. This **promotes the former advisory "dual
validation principle"** (detail §AreaB-Baseline #4) to a hard gate — the mechanical-anchor pattern of
hardening #1–#5: a judged verdict binds to a fact the judge cannot fake.

**Graceful-degradation ladder** — take the highest available rung. The gate **never breaks
sim-conductor**; at the bottom it only withdraws the *unsafe autonomy* (self-certifying a blind verdict),
not the run:

| Rung | Source | `cross_model_coverage` | Closes | When |
|---|---|:---:|---|---|
| 1 | External CLI team (Multi-Team Mode — §MultiTeam) | `external` | model-level blind spot (genuine cross-model) | 1+ external CLI live + probe non-empty |
| 2 | Cross-session Claude — `claude -p` headless, or an Agent with **zero inherited context** | `cross-session` | **session-contamination only** — a fresh Claude shares the same weights/RLHF gradient, so it does **not** close the model-level blind spot; it only removes the orchestrator's working-memory bias. Honest partial mitigation, labeled as such | no external CLI; dispatch probe returns non-empty |
| 3 | Same-session sub-agents only | `NONE` | nothing — homogeneous panel | neither rung's probe succeeded |

**Mechanical anchor** — `cross_model_coverage` is valid **only if backed by a quoted dispatch artifact**,
not a self-assessment (the self-signing hole hardening #1 closed for the marker — same fix here). To
record `external` or `cross-session`, the Step 3 report must **quote a non-empty excerpt of the actual
dispatch output** (external CLI stdout, or the dispatched Agent's returned verdict text); a label with no
quoted excerpt is invalid and falls to `NONE`. **Liveness, not mere availability**: probe the rung before
claiming it — attempt the dispatch with a timeout; if it errors or returns empty (plan-gate closed,
context saturated, CLI present-but-dead), record `NONE`, never assume the rung succeeded. This is the
same honest scope as #1: the artifact makes the claim **auditable**, not cryptographically unforgeable —
a fabricated excerpt remains the operator's + weekly-audit's residual by design. On rung 3 (`NONE`) for a
risk≥medium target:
- the report flags `⚠️ cross-model coverage: NONE — homogeneous same-session panel; verdict provisional`, **and**
- **Step 4 auto-commit privilege is withdrawn** (see Step 4): M-tier fixes may be *prepared* but the
  commit waits for the operator's explicit go. Auto-committing a structurally self-blind verdict is
  exactly what the exploit targeted — so that single privilege is what degrades, not the simulation.

`risk_level = low` targets are exempt (a homogeneous panel is acceptable); the gate fires only at
medium+. The rung-2 fallback is what makes this CC-only-safe: a Claude-only environment still gets a
real cross-context read (a fresh isolated dispatch shares no working memory with the orchestrator), so
`NONE` is reached only when *both* external CLIs and a second Claude context are unavailable.

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

Shipped standpoint agents (① tier — sourced installed-first):

FH ships a coherent **user-mastery spectrum** as real, reusable agents (not prompt-directive shells) — found by the ① installed-first scan, reusable across skills, and each isolated-context dispatchable for a true cold read (the bias-isolation value: an evaluator outside the author's context reads cold):

| Agent | Spectrum tier | Standpoint | Type |
|---|---|---|---|
| `beginner` | entry | First-contact cold-read — onboarding friction a fluent author cannot feel | reasoning |
| `main-player` | core | Engaged user; intelligently scopes Light / Midcore / Heavy (Heavy = classic power-user edge/limit lens) | reasoning |
| `expert` | frontier | Domain authority; web-grounded accuracy + SOTA currency, citation-enforced | data (WebSearch/WebFetch) |
| `challenger` | adversarial axis | Frontier adversary; U1 absorbs the skeptic "why not just X?" lens | adversarial |

> **Lineage**: `beginner` / `main-player` / `expert` are the FH-native frontier successors to the field deep-insight `user` group (newcomer / power-user) — re-derived to FH grade with embedded methodology + Done-When, not name-copied. `challenger` is the advanced form of the field `devil-advocate`. The former standalone skeptic standpoint is folded into `challenger` U1.

**Ad-hoc roles** (② tier — prompt-directive fallback): when the profile demands a standpoint with no shipped agent (e.g. "security auditor", "non-native reader"), inject the role as a directive into a general-purpose Agent. Prefer ① shipped agents; use ② only for genuinely task-specific one-offs.

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

**A-1** (`beginner`) — first-contact friendliness · onboarding friction · terminology clarity
**A-2** (`main-player`) — engaged-use fit; Heavy tier: install conflicts · duplication · silent overwrite
**A-3** (`challenger`, artifact_type="SKILL") — claim-evidence gaps · angles U3, U5, S2

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
| SKILL.md / design doc | challenger (artifact_type="SKILL") | `beginner` | Governance gaps, behavioral rule coverage |
| Python / JS / bash code | challenger (artifact_type="Code") | `main-player` (Heavy) | Edge cases, performance, security surface |
| Prompt / config | `beginner` | challenger | Interpretation errors, implicit assumptions |
| Auth / security-sensitive | challenger + Security-auditor† | `main-player` (Heavy) | Attack surface, privilege escalation |

† Security-auditor = built-in fallback role (② tier) injected as prompt directive.

All personas run in parallel. Findings = M/S/R → M-tier items fixed immediately.

#### D-consumer — Artifact Consumer Simulation

Consumer agent attempts actual use (not just reads and judges). Grades: F (functional) / P (partial → S-tier) / B (broken → M-tier immediate fix).

> **Detail**: See `SKILL_detail.md §AreaD-Consumer` — D-session 4 questions, D-skill cold-start procedure, D-memory check items, verdict criteria — read when executing D-consumer.

---

### Area E — Artifact Quality Review

`expert` objection (E-1) + Practitioner confusion (E-2) in parallel → Pattern structuring (E-3) integrates both.

> **Detail**: See `SKILL_detail.md §AreaE-Detail` — E-1/E-2/E-3 execution, finding format, pattern naming procedure — read when executing Area E.

---

## Step 1.5 — Persona Output Protocol + Neutral Synthesizer (parallax)

Generalized from the field `deep-insight` multi-persona pattern (private companion store), domain-stripped — the *pattern*
is renamed **parallax** for public FH (it is a mode of this skill, not a separate skill — see asset-placement
2026-06-06). It gives the persona dispatch above a shared output contract + a neutral aggregator, so
multi-persona findings stay comparable and the synthesis injects no bias of its own.

> **Naming provenance (precise)**: "renamed" above refers to the *pattern* (→ parallax), not the personas.
> The company-team-coupled field personas (fe/be/ios/pm/ux-writer/compliance/qa) were domain-stripped
> entirely. The generic `user` group (newcomer/power-user) was **re-derived to FH grade as the shipped
> `beginner` / `main-player` / `expert` mastery-spectrum agents** (embedded methodology + Done-When, not
> name-copied shells), and the field `devil-advocate` was **advanced into `challenger`** (sandboxed-adversary
> + adaptive attack matrix). Lineage is acknowledged; nothing is carried verbatim as a shell.

**Shared persona output protocol** — every dispatched persona emits the same shape, whatever its lens:

```
### Strengths        (0–3, from this persona's viewpoint)
### Concerns
  Critical   — compile/runtime failure · clear logic error · data corruption · security leak
  Important  — significant user/service impact in a plausible scenario
  Suggestion — optional improvement
  (each item: [file:line or quoted span] one-line summary — rationale)
### Open questions   (0–3 items needed for a decision)
### Absence check    (outside-vantage personas — beginner/integrator: what does the artifact FAIL to
                      specify that this standpoint needs? discoverability · undocumented contract ·
                      unstated assumption. A normal, self-administrable rubric item — surfaces real gaps.)
```

**FP judgment discipline** — only escalate when confident. Never escalate: pre-existing issues not
introduced by this change · style/quality without a quotable rule · linter-catchable · speculative
("might break if…") · subjective preference (→ Suggestion). **If not confident, do not mark it** — false
positives erode reviewer trust.

**Neutral synthesizer** — the aggregator is a NON-persona; it adds no opinion of its own:
- No opinion injection — never a conclusion no persona stated.
- Preserve attribution — always traceable which persona said what.
- Priority labels verbatim — Critical/Important/Suggestion carried as the persona set them.
- No forced consensus or forced conflict — report Common opinions (2+ personas agree) and Conflicts
  (position A vs B, each with rationale) as-is. Feeds Step 2 M/S/R triage (M ← Critical or 2+ personas).

**Zero-coverage map (mandatory synthesizer output)** — the synthesizer must emit, mechanically, the set
of standpoints that produced **no** finding, not only the ones that did (judge-robustness swarm,
2026-06-13). Enumerate the persona **standpoints** in play — those the Step 0.3 profile recommended,
**plus the standpoints its dimensions imply** (risk_level=high → a security/publish standpoint ·
audience=mixed → a non-native-reader standpoint · claim_density=high → a claim-evidence standpoint).
List the *standpoints*, not the bare dimension names (a `risk_level (low) → ZERO` row is noise that
trains operators to ignore ⚠️). Mark each `covered` (≥1 persona addressed it) or `ZERO` (no persona
touched it):

```
Coverage map:
  beginner (onboarding friction)      → covered (A-1: 2 findings)
  challenger (claim-evidence)         → covered (A-3: 1 finding)
  security surface (risk_level=high)  → ZERO ⚠️
  non-native reader (audience=mixed)  → ZERO ⚠️
```

A clean report with `ZERO` standpoints is **not** a pass — it is an uncovered surface, reported as such.
This converts the formatting-flattery failure (everything reads fine → nothing escalates) into a visible
gap: **silence on a standpoint is reported as `ZERO`, never inferred as approval.** It is a checklist
derived from the profile and the dispatch outputs — a mechanical anchor, not a judgment. Carry the map
verbatim into the Step 3 report.

The two severity vocabularies are layered, not redundant: a persona running **in isolation** assigns only
its own Critical/Important/Suggestion — it cannot assign M/S/R, since `S = found by 3+ personas` depends on
cross-persona agreement the isolated persona never sees. The synthesizer is the only context that can triage
to M/S/R. So isolation *requires* the per-persona → synthesized two-layer split.

**External-harness persona sourcing** — isomorphic to steel-quench Step 0.4 (Specialized Reviewer
Discovery) + Wave 5 (external CLI teams). A needed lens may be sourced from an **installed sibling
harness**, not only the built-in palette — e.g. gstack `/review` (staff-engineer), `/cso`
(security-officer), `/qa` (QA-lead) when gstack is installed. sim-conductor orchestrates; the sibling
supplies the specialist lens. Same ①installed → ②fallback → ③fetch priority as Persona Discovery — an
external harness's review-skills count as ① installed sources, widening the persona pool without FH
shipping every specialist.

> **Absence check — resolved (added above)**: the clean replication (companion-store experiment, Arm F: identical
> artifact, explicit omission prompt, ownership-only variable) found self ≈ isolated (~90% overlap) —
> **omission-detection is self-administrable when explicitly asked**, refuting the earlier "the author
> can't see their own omissions" (Arm E, a prompt/design-drift artifact). So the Absence check is a
> normal, valuable rubric item (it surfaces real undocumented-contract gaps), not a special isolation-only
> power. The pattern's value is rubric/standpoint *supply + routine enforcement* (copyable utility), not
> de-biasing — see `knowledge/shared/patterns/multi-persona-review.md`.

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

**Cross-model gate on auto-commit (risk≥medium)** — when Step 0.6 recorded `cross_model_coverage: NONE`
on a risk≥medium target, the auto-commit privilege is **withdrawn**: prepare the M-tier fixes and write
the report, but do **not** self-commit — surface *"cross-model coverage NONE on a risk≥medium target;
the verdict is from a homogeneous same-session panel. Commit the fixes, or add a cross-context read
first?"* and wait for the operator's go. `external`/`cross-session` coverage, or risk_level=low, commits
as normal. (This withdraws one privilege, not the run — the report and fixes still exist.)

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
| risk≥medium → `cross_model_coverage` recorded in report (external/cross-session/NONE) | ✅ Coverage gate ran *(check class: measured — the recorded value reflects the dispatch path that ran, not a self-grade; pair: NONE withdraws auto-commit per Step 4)* |
| Synthesizer emitted the zero-coverage map (every profile standpoint marked covered/ZERO) | ✅ Blind-spot surface reported *(check class: mechanical — a checklist over the profile, not a judgment)* |

Verdicts: PASS · CONDITIONAL_PASS (S/R only, or Area B cadence skip) · FAIL (M-tier unresolved) · ESCALATE (persona conflict requiring human judgment, **or** `cross_model_coverage: NONE` on risk≥medium → auto-commit withdrawn pending operator go).

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

---
name: sim-conductor
description: Autonomously runs external user reaction simulations, internal audits, ideation scans, artifact validation, and quality reviews. Triggered by "run a simulation", "external user perspective", "internal audit", or "quality check".
user-invocable: true
allowed-tools: ["Read", "Write", "Bash", "Grep", "Glob", "Agent"]
model: opus
---

# sim-conductor — Meta-Simulation Automation Orchestrator

> Places deep-insight personas (fe-marketplace) in an isolated environment to validate AI tools from the external user's perspective, classifies findings into M/S/R tiers, and completes the pipeline through to PR automatically.

## Core Principle — Beyond Self-Inspection

The structural trap in AI tool quality validation: when the builder tests, they are always confined to an internal perspective. sim-conductor addresses this limitation with **physical isolation + AI personas**.

```
Development environment (harness root)
         ↕ physical isolation
Isolated environment (~/sim/observer/)   ← new user reproduction space (zero development context)
```

The devil-advocate persona captures that self-inspection is cleaning, not a vaccine — clarifying the need for a real external mirror (direct external user validation). In Path B (environments without `~/sim/`), logical isolation (agent prompt directives) substitutes, and only Area B is recommended.

Runs autonomously through to PR or report commit. User involvement = 1 trigger + 1 PR review.

## Invocation Triggers

| Trigger pattern | Suggested Area |
|---|---|
| "Look at this from an external user's perspective", "How would someone else see this?" | Area A |
| "Check the harness", "asset audit", "internal audit" | Area B |
| "Any new ideas?", "ideation scan", "naming candidates" | Area C |
| "Review this code" (pre-PR), "review this prompt" | Area D (code) |
| "Check if the session card is correct", "does the skill actually work", "memory cold-start validation" | Area D (session/skill/memory) |
| "Is the output good?", "artifact quality review" | Area E |

Proposal format: `"If it's related to [X], should I simulate with /sim-conductor [Area]?"`

### Natural Language Triggers (activates without internal vocabulary)

Also activates when an external user expresses without sim-conductor terminology:

| Example utterance | Intent | Mapped Area |
|---|---|---|
| "Validate our system virtually" | Full system simulation request | Area B |
| "Test it with personas" | Persona-based validation request | Area A |
| "Run an external user simulation" | External user reaction check | Area A |
| "Look at it through someone else's eyes", "How would a new team member see this?" | External perspective simulation | Area A |
| "Validate that this actually works" | Real-usage validation | Area D |
| "Find problems aggressively" | Devil-style adversarial validation | Area B (devil persona) |

## Triggers

```
/sim-conductor                        # default: Area C (Innovator) auto-run
/sim-conductor A                      # external user simulation
/sim-conductor B                      # internal meta audit
/sim-conductor C                      # Innovator scan
/sim-conductor all                    # full A + B + C
/sim-conductor A --target <path>      # specific asset target
/sim-conductor D --target <file>      # code/prompt multi-persona review (pre-PR)
/sim-conductor D session [--target <file>]   # session start card cold-start validation
/sim-conductor D skill <name>         # specific skill trigger utterance consumer simulation
/sim-conductor D memory <file>        # memory file cold-start validation
/sim-conductor E --target <file>      # artifact quality review (post-pipeline)
```

**Frequency limits (R1 rule)**:
- Area A: After asset changes or manual trigger
- Area B: Maximum once per week (check latest mtime of `tracks/_meta/sim_*_area_B*.md`)
- Area C/D/E: No limit

## Step 0 — Environment Sync

**Harness root auto-detection**:
```bash
HARNESS_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
SIM_CLONE=~/sim/your-hub-sim/forge-harness-via-clone
[ -d "$SIM_CLONE" ] && (cd "$SIM_CLONE" && git pull origin main) || SIM_CLONE="$HARNESS_ROOT"

# Report storage path detection
REPORT_DIR=$(find "$(dirname "$HARNESS_ROOT")" -maxdepth 2 -name "tracks" -type d 2>/dev/null | head -1)
REPORT_DIR="${REPORT_DIR:-$HARNESS_ROOT/tracks}/_meta"
mkdir -p "$REPORT_DIR"
```

**Area B frequency check**: If the previous Area B report is within 7 days → stop execution + report date. If no file found, treat as "first run" and proceed. Mode C environments (no sim/tracks paths) auto-create `$HARNESS_ROOT/tracks/_meta/`.

## Step 0.5 — Precondition Validation (proactive concern)

If a problem is found, proactively surface **1 concern** then confirm whether to proceed. If no concern, proceed directly to Step 1.

| Check | Concern trigger condition |
|---|---|
| Area B frequency guard | Previous run within 7 days + S-tier unresolved |
| Unresolved M-tier | New simulation requested without processing previous M-tier |
| steel-quench not run | Area A requested immediately before external publish + no steel-quench history → **mandatory gate: run steel-quench first, Area A does not proceed until steel-quench completes** |
| Self-recursive path | sim-conductor attempting to auto-PR its own M-tier |
| Goal-method alignment | Requested Area doesn't match actual problem |
| D/E --target missing | Area D(code)/E runs without `--target` file or file doesn't exist |
| D session target not found | Session start card file not found → prompt path confirmation |
| E execution timing error | Area E requested before pipeline run (no artifact yet) |

Concern format: `"One thing to check before [Area X]: [concern]. Proceed?"`

## Step 1 — Area-Specific Simulation Execution

### Area A — External User Perspective

Target: skill descriptions, README external user entry points, CHEATSHEET first section.

**A-1. Description friendliness** (Agent: deep-insight persona-newcomer) — Is it understandable without internal terminology? Is the first line the essence? Check for embedded names/revisions/emphasis words. Findings = [issue, location, fix suggestion] format.

**A-2. Install conflicts** (Agent: deep-insight persona-power-user) — fh-meta additional install scenario. Identify conflict/duplication/silent overwrite points. Findings = [conflict type, location, mitigation suggestion] format.

**A-3. Critical audit** (Agent: deep-insight persona-devil-advocate) — "Does the meta-harness actually do what it claims?" Three lenses: self-marketing vocabulary, naming-substance mismatch, unsubstantiated claims. Findings = [claim, evidence status, verdict (aligned/misaligned/exaggerated)] format.

> ⚠️ **Human review gate**: Area A results must be reviewed directly by the owner before entering the AI-AI loop (sim-conductor→hub-cc-pr-reviewer). Final decision authority on S-tier judgments rests with the human.

### Area B — Internal Meta Audit

Target: all fh-meta assets (skills + agents + plugin.json).

> **Self-recursive reference caution**: sim-conductor itself is also subject to audit. When M-tier is found, report only — delegate processing to user.

> **External baseline injection method**: Self-inspection is cleaning, not a vaccine. Structural methods to reduce self-reference risk:
> 1. **Regular devil attacks**: Periodically run a completely external perspective (Wave 1 devil attack → Wave 2 defense). Recommended combination: Area B once/month + devil attack once/quarter.
> 2. **Direct external user validation**: Actual external user (not the owner) attempts install + invocation → collect reactions (cascade β achievement validated: first autonomous external run confirmed).
> 3. **steel-quench skill integration**: Route devil attack → defense results directly into SKILL.md. Can hand off to steel-quench after Area B ends.
> 4. **Dual validation principle**: Internal validation (Area B) alone is insufficient — self-reference risk is minimized when combined with external install reaction collection.

**3-persona sequential**:

1. **hub-persona-auditor** (Agent) — treats README/CHEATSHEET as "briefing for external audience." 3+ persona simulation → 4-axis review → 3-tier suggestions
2. **persona-innovator** (Agent, Mode I) — naming gap detection + structural gap identification. Output 3-5 naming candidates
3. **deep-insight persona-devil-advocate** (Agent) — provides previous two persona results as additional input, reviews with "what was missed?" lens. Focus on self-rationalization patterns and structural blind spots

> ⚠️ **Human review gate**: Owner final confirmation required before Area B result convergence judgment. AI-AI loop internal convergence is treated as "provisional convergence" only.

### Area C — Innovator Scan

Runs independently. Skip if included in Area B.

**persona-innovator** (Agent, Mode F = Internal + External) — Internal: current harness asset gaps / External: frontier source scan. Output: naming candidates + external absorption signals + top 1 priority action

### Area D — Artifact Validity Validation

| Mode | Trigger | Core question |
|---|---|---|
| **code** | `/sim-conductor D --target <file>` | Is the code/prompt well-built without bugs or bias? |
| **consumer** | `/sim-conductor D session/skill/memory` | Does the artifact actually work for the intended consumer? |

#### D-code — Code/Prompt Multi-Persona Review

**Purpose**: Pre-PR discovery of bugs/biases/edge cases. **Validation**: UXW v6.1 `prompts/qa.py` → V-1/V-2 discovered pre-PR.

**D-1. Edge cases/counterexamples** (Agent: persona-devil-advocate) — unintended failure edge cases, missing counterexamples, boundary conditions, rule conflicts. Findings = [location, edge case, reproduction scenario, fix suggestion] format.

**D-2. First-impression interpretation errors** (Agent: persona-newcomer) — rules/expressions prone to misinterpretation, implicit assumptions, unclear priorities. Findings = [location, misinterpretation risk, clarification suggestion] format.

**D-3. Performance/quality trade-offs** (Agent: persona-power-user) — unnecessary complex logic, cost (token/time/error rate) bottlenecks, precision-recall trade-offs. Findings = [location, trade-off, improvement direction] format.

**Output**: M/S/R classification → M-tier items that can be fixed immediately are directly patched in the relevant file and committed.

#### D-consumer — Artifact Consumer Simulation

**Purpose**: Consumer role agent attempts actual use and validates "does it work as intended?" Unlike Area B (read and judge), this **actually attempts the intended use**.

**Result grades**: F(Functional, normal) / P(Partial, partially blocked → S-tier) / B(Broken, unusable → M-tier immediate fix)

**D-session** — Session start card cold-start validation

Auto-detect target (when `--target` not specified): MEMORY.md → check `reference_next_session_starter.md`, if absent search for latest session-starter in `tracks/_meta/` or `memory/`.

Provide only that file to the consumer agent, no context, and ask:
1. The most important thing to do today
2. Current work-in-progress status
3. Events/deadlines that must not be missed
4. Parts that are unclear or lack context

**Verdict**: Top priority action matches → F / Context reconstructed but some gaps → P / Wrong top priority or key item missing → B. B/P items are directly fixed in session card and committed.

**D-skill** — Skill trigger utterance consumer simulation

Provide only one SKILL.md to the consumer agent. Assume the first trigger sentence from the triggers section was input and attempt to complete from Step 1. Record where it stalled, why, whether it can complete, and what needs fixing.

**Verdict**: Completes → F / Partial completion → P / Blocked from first step → B

**D-memory** — Memory file cold-start validation

Provide only one memory file to the consumer agent. Check: ① When should it be applied / ② Can current validity be determined from this file alone / ③ Can the behavior guideline be executed from this file alone / ④ Whether stale or contradictory information exists.

**Verdict**: ③ executable + ④ none → F / Some unclear parts → P / Stale/contradiction found → B

### Area E — Artifact Quality Review

**Target**: Result file specified with `--target` (xlsx/json/reports, etc.). **Purpose**: Structured persona analysis of false positive/negative patterns → fed back into code/prompt. **Validation**: UXW v6.1 internal insurance Figma 994 items → 3 types of over-detection patterns → CRITICAL RULE 4 added.

**E-1. Domain expert objection** (Agent: persona-devil-advocate) — clearly wrong judgment (false positive) patterns, judgments that should have been caught but weren't (false negative) patterns, risk priority. Findings = [judgment type, pattern, root cause, fix direction] format.

**E-2. Practitioner confusion** (Agent: persona-newcomer) — confusing items, fix suggestions that are awkward than the original, sections where classification criteria consistency breaks. Findings = [item, confusion cause, improvement direction] format.

**E-3. Pattern structuring** (direct execution) — integrate E-1/E-2 results → group false positives by same cause and assign pattern name → pinpoint fix location → M/S/R classification.

**Output**: Pattern naming → directly fix target code/prompt → commit.

## Step 2 — Synthesis (Auto-Integration)

| Tier | Criteria | Action |
|---|---|---|
| **M (Mandatory)** | Blocks external user entry / naming-substance mismatch / security/trust damage | Immediate PR required |
| **S (Strong)** | Feature degradation / important confusion point / found by 3+ personas | Address within next session |
| **R (Recommended)** | Improvement value / found by single persona | Backlog |

**Deduplication**: When multiple personas find the same location, M > S > R priority.

**Self-marketing auto-lint**: Auto-flag the following vocabulary in results — "full-fledged", "decisive", "precision", "innovative", "groundbreaking", revision numbering (`Nth revision`), version history with embedded names.

## Step 3 — Report Generation

File: `$REPORT_DIR/sim_YYYY_MM_DD_area_[X].md`

```markdown
---
name: [date] Meta-Simulation — Area [X]
type: simulation-report
date: YYYY-MM-DD
areas: [A|B|C|all]
m_count: N
s_count: N
r_count: N
---

## M-tier ([N] items)
...

## S-tier ([N] items)
...

## R-tier ([N] items)
...

## Emerging asset candidates
...
```

## Step 4 — PR or Direct Commit

**1+ M-tier**: Create fh feature branch → process M-tier → create PR.

```bash
cd "$HARNESS_ROOT"
git checkout -b fix/sim-"$(date +%Y%m%d)"-m-tier
# Process M-tier items (fix descriptions, correct mismatches, etc.)
git add -A && git commit -m "fix(sim): M-tier items from sim-conductor run"
git push origin fix/sim-"$(date +%Y%m%d)"-m-tier
# GH_HOST=your-ghe-host  # set if using GHE instead of github.com
gh pr create --title "fix(sim): M-tier items" --body "..."
```

PR body includes simulation report summary + processed item checklist.

**0 M-tier**: Commit report file only + report S/R backlog summary to user.

## Completion Report Format

```
sim-conductor [Area X] complete (YYYY-MM-DD)

M: [N] items → PR #{number} created (or "none")
S: [N] items → next session backlog
R: [N] items → backlog

Top priority action: [1 item]
Report: tracks/_meta/sim_YYYY_MM_DD_area_X.md
```

## Operations Notes

### AI-AI Loop Bias Defense

The triple loop of sim-conductor output → hub-cc-pr-reviewer review → sim-conductor re-entry shares the same LLM cognitive limitations. The blind spots of this loop can only be defended by external review (direct owner judgment or cross-validation with another model). Internal loop convergence is "provisional convergence" and is elevated to final convergence only after passing the human gate.

## Human Gate Principle

Convergence within an AI-AI loop is **provisional convergence**. It must pass through a human gate to be elevated to final convergence.

| Simulation stage | Human gate application condition |
|---|---|
| Area A S-tier judgment | Final convergence when user directly reviews and says "convergence approved" |
| Area B convergence judgment | AI-AI loop internal convergence is provisional — elevated after user confirmation |
| M-tier auto-PR creation | User gate before PR creation (orchestrator outputs parameters → approval) |
| Three-Doctor Loop end | User reviews three-skill convergence results and decides next action |

## Done When

| Condition | Completion verdict |
|---|---|
| `sim-conductor [Area X] complete` format output | ✅ Simulation complete |
| 1+ M-tier → PR creation complete or "none" confirmed | ✅ Prescription complete |
| Report `tracks/_meta/sim_YYYY_MM_DD_*.md` saved | ✅ Persistence complete |
| 0 M-tier → report committed + S/R backlog reported | ✅ Health check complete |

**This skill's Done When = "completion report format output complete"**. Actual M-tier resolution and PR merge are in the user's or follow-up work domain and are not included in this skill's completion criteria. Ending without Step 3 report output = Fail.

**→ Mandatory prerequisite for Area A (external publish context): `steel-quench` must have run in the same session before Area A is marked complete.** If not, Area A completion is invalid — restart with steel-quench first.

**External validation path**: harvest-loop Step 3.75 Critic isolated Agent can independently judge against the above criteria (`skill_quality_rubric.md` verifiable criteria). Automatically linked when subsequent steel-quench runs.

**Rationale**: AI-AI loops based on the same LLM share cognitive blind spots. The human gate is not a simple approval process — it is a **structural bias-blocking mechanism**.

## Simplification Guard

- Area B attempted 2+ times in one week: First check whether previous S-tier items were resolved
- New simulation requested without processing M-tier: Warn about unresolved M-tier
- Request to add new persona: Require 1+ empirical cases not captured by existing 3-persona system

## Three-Doctor Loop Integration

### sim-conductor's Role in Three-Doctor Loop

Three-Doctor Loop is a self-renewal structure where the three skills form a closed loop: **diagnosis → prescription → re-diagnosis**.

```
harness-doctor   → current skeleton diagnosis   "Is the structure correct?"
context-doctor   → current context diagnosis    "Is Context Collapse occurring?"
sim-conductor    → future behavior prediction   "What happens when a real person uses this system?"
```

**Key distinction**: harness-doctor and context-doctor diagnose the **current state**. sim-conductor predicts the **future that has not yet occurred**.

Specifically, sim-conductor pre-runs the experience of a specific persona (new team member/external installer/critical reviewer) encountering this harness **for the first time**:

- "Where does an external developer get stuck when reading the install guide?"
- "At which step does an outside developer fail when running a skill for the first time?"
- "What claims does a devil-advocate raise objections to when reading the README?"

When these predictions are correct, blocking points can be removed before actual external users arrive.
**Validation**: An external user's autonomous run confirmed cascade β achievement (first autonomous run by non-owner confirmed).

---

sim-conductor (simulation/ideation) · harness-doctor (structure) · context-doctor (token/context) — the three skills form a **diagnosis→prescription→re-diagnosis** closed loop.

| Situation | Next skill |
|---|---|
| Structural problem found in simulation results | `/harness-doctor` |
| Token waste pattern found in simulation results | `/context-doctor` |
| All three skills mentioned simultaneously | Three-Doctor Loop circuit activated — diagnosis→prescription→re-diagnosis cycle |
| Area A run immediately before external publish | `/steel-quench` **required** before Area A proceeds — not recommended, mandatory. Secure residual risk list before entering (→ `steel-quench external publish pre-requisite sequence`) |

## Path B (External Environment)

When `~/sim/` is absent:
- Step 0: Fallback to harness root (skip git clone)
- Apply logical isolation only without physical isolation (specify "without development context" in agent)
- **Area B only recommended** — Area A/C are technically executable but physical isolation not guaranteed since they directly reference original paths. Control only with logical isolation (prompt directive).

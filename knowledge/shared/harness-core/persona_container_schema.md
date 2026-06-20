---
name: persona-container-schema
description: Canonical schema for synthesizing a simulation persona from a reusable container. sim-conductor and any persona-dispatch skill fill these slots instead of injecting an ad-hoc role directive. Defines the slots, crowd-scale stop rule, multi-LLM tier distribution, the situation→group→skill dispatch binding (folded skill-container), and the synthesize→validate→graduate lifecycle.
type: reference
scope: meta-harness
---

# Persona Container — Canonical Schema

> **The gap this fills** (verified 2026-06-20): FH had no persona-*definition* container. `sim-conductor`
> *conducts* — it profiles a target, derives a needed perspective, then sources a persona (installed
> agent → an undefined "built-in fallback palette" injected as an ad-hoc prompt directive →
> plugin-recommender). There was no reusable *container* that holds a persona's internal logic +
> external-data wiring. This schema is that container. It does **not** replace sim-conductor (the
> runner); it is what sim-conductor (and any persona-dispatch skill) **fills** instead of an ad-hoc
> directive.
>
> **Consumer status**: sim-conductor extension **SHIPPED 2026-06-20** (same session as this schema) —
> Persona Discovery ② now fills these 6 slots instead of an ad-hoc directive; §Scale gained the Crowd
> tier (16-cap lifted behind the marginal-coverage stop) + cost-tier routing; Step 5 adds the graduate
> step with the admission test below. The A4 clocked write-off trigger is therefore **resolved** — this
> doc has a live consumer.
>
> **Orthogonal to `tpa_schema.md`** (foreseeable-collision note): TPA profiles the **target** (what is
> reviewed → which gates fire); this profiles the **persona** (who reviews). TPA's profile *drives*
> which personas to synthesize — they pair, they do not overlap (zero shared fields).

## The container — 6 slots

A synthesized persona is a filled instance of these slots. (Empirically used 2026-06-20 to synthesize
blind `newcomer` / `red-team` / `vulnerable-user` personas that found a real grounding bug a
design-aware inline pass missed.)

| Slot | What it holds | Why it is a slot (not free text) |
|---|---|---|
| **lens / identity** | who the outsider is (non-tech newcomer · adversarial red-team · domain expert · vulnerable user) | the standpoint; parallax depth comes from the shift *between* standpoints |
| **internal logic** | what they probe / attack / get stuck on (the persona's decision rules) | makes the reaction reproducible, not vibes |
| **external grounding** | the real artifact files the persona MUST read + (optional) external-search queries that ground the persona in real data | a persona ungrounded in the artifact hallucinates; cheap bounded grounding keeps it economical |
| **output protocol** | **reuses sim-conductor Step 1.5 parallax shape** (single source — do not re-spec here; it already defines Strengths / Concerns / Open-questions / Absence-check) | one shape across all personas → cross-persona agreement is meaningful (`[[multi-persona-review]]`) |
| **cost tier** | which model runs this persona (floor-local · heavy-local · frontier) | the economy lever — see §Multi-LLM tier distribution |
| **lifecycle** | synthesized · validated · graduated (see §Lifecycle) | most personas stay ephemeral; only proven ones graduate |

**Isolation invariant**: a synthesized persona dispatches as an **isolated** agent (no main-session
context inherited). Isolation is the FH mechanism that keeps a blind reaction honest — a `newcomer`
that knows the design intent is not a newcomer. (2026-06-20: the blind-container personas found
UNNAMED bugs precisely because the inline, design-aware pass was contaminated.)

## Crowd scale + the marginal-coverage stop (anti-decorative)

The container scales from a few personas to a crowd, but **crowd size is output-driven, never a
target** — there is no persona-count goal, and naming a headline capacity number is itself the
decorative over-generation steel-quench Wave-1 angle #1 attacks. Two rules bound the crowd:

- **Decorrelation**: add a persona only if it is *distinct* (a different viewpoint, OR — at scale —
  a different model family) from the ones already running. A crowd's value is breadth of distinct
  viewpoints, never headcount.
- **Marginal-coverage stop**: stop adding personas when the marginal new-finding rate → 0. Crowd size
  is *measured against findings*, never a fixed number.

(Platform sub-agent ceilings — recent runtimes allow large fan-outs — are a *capacity* fact, relevant
only as the upper bound the marginal-coverage stop operates well below; they are not a usage target.)

## Multi-LLM tier distribution (the economy lever)

The `cost tier` slot lets a crowd be distributed across model tiers so breadth is cheap and the verdict
stays trustworthy. **One probe, not a benchmark** (the-bible truncation-inversion, 2026-06-20, N=1 —
a single task, a single model trio, one run):

| Tier | Example | Role | What the one probe showed |
|---|---|---|---|
| **floor-local** | `gemma4:e2b` (MacBook) | cheap breadth / obvious-signal filtering | caught obvious oblique-distress, **MISSED** the subtle truncation-inversion |
| **heavy-local** | `qwen3:32b` (4090) | stronger decorrelation canary | **CAUGHT** the subtle case with correct reasoning ("fool's heart, not authoritative") |
| **frontier** | Claude (Opus/Sonnet) | terminal verdict | the blind red-team that originally found the bug |

**What this one signal supports — and what it does NOT**: it is a single data point that a 27–32B tier
*may* clear adversarial reasoning a floor model cannot — enough to justify the floor-local-as-cheap-
breadth / heavy-local-as-stronger-canary split. It is **not** a measured equivalence to frontier, and
the heavy-local tier is **never promoted to a gate** on this basis: **the terminal verdict always
stays frontier** — local tiers are canaries (decorrelation), not gates. (Consistent with
`[[feedback_judge_robustness_mechanical_anchor]]` and the "Local AI is not Opus" finding — a stronger
local model lowers the cost of *breadth*, it does not move the *verdict*.)

## Dispatch — situation → group → skill (folded skill-container)

`[[asset-placement-gate]]` routed a proposed standalone **skill-container** here (2026-06-20): FH 4-criteria
**FAIL on ④ overlap** — the GROUP axis is derivable from existing slots and dispatch-planning overlaps
`[[agent-composer]]`, so it does not earn a standalone asset (the same anti-decorative fold as §Sibling's
skill-foundry). The one net-new sliver — the **runtime situation→group→skill binding** — folds here.

**Group = personas sharing a capability-class**, read mechanically off existing slots (NOT a new taxonomy):

| Group | derived from slot | bound skill (the dispatch target) | tier-floor |
|---|---|---|---|
| Relay | output-protocol = quote-only | verified-corpus quote (fail-closed) | any |
| Lens / counsel | external-grounding = active | framed reflection + search-synthesize | frontier for the synthesis step |
| Adversary | lifecycle = ephemeral, paired | quench / failure-mode generation | local OK (generation task-class) |
| Guardian | output-protocol = verdict | classify-and-block (L2 semantic) | local screen → **frontier on the subtle class** |

**Dispatch rule**: classify the incoming situation → route to its group → invoke that group's bound skill.
The binding carries a **tier-floor per group**, not one global model — consistent with §Multi-LLM above.

**Guardian tier-floor is measured** (the-bible red-team dogfood, 2026-06-20, signal in the companion store):
on CLEAR keyword-evasion the local L2 (qwen3:32b) caught **11/11**, but on the SUBTLE/borderline class it
collapsed to **1/4** while Gemini-3.5-Flash got 3/4 and GPT-5 / Opus-4.6 got 4/4 (0 false-positives
across all). So the Guardian binding is *local-screen-then-frontier*: cheap local clears the easy class,
the subtle residual needs frontier (and ultimately L3 human, per the L2-imperfect residual). A second probe
reinforcing §Multi-LLM's single truncation-inversion point, same direction — local lowers the cost of
breadth, frontier keeps the verdict on the cases that matter.

**Done When** (skeleton — fold scope only): (1) each group is derivable from a slot, no new taxonomy
*[mandatory-pass]* · (2) each group names exactly one bound skill *[mandatory-pass]* · (3) a tier-floor is
stated, measured where claimed *[judged, pair: target-tier sim]*.

## Lifecycle — synthesize → simulate → validate → graduate

```
synthesize (fill the container)  →  simulate (dispatch isolated, collect parallax output)
   →  validate (findings triaged M/S/R)
   →  graduate (ONLY a persona that PASSES the admission test below is embedded in the project's
                static set, e.g. the-bible's core/personas.json) — most personas never graduate;
                the throwaway run still accelerated the work.
```

**Graduation admission test** (mechanical — closes the judge-only path; a "proven" persona is not a vibe):

- **measured**: the persona surfaced **≥1 unique S/M finding** (a finding no other persona in the run
  produced) across **≥2 distinct targets** — recurrence, not a one-off. A persona that fired once is a
  lucky throwaway, not a graduate.
- **mandatory-pass**: if graduating into a *skill* (not just a project's persona set), it additionally
  clears the **FH 6-item creation gate** (the skill-foundry inversion below — the trust bar for a
  governance asset is non-negotiable).

Graduation is **optional and rare** — the analogue of "app-ification": a persona earns a permanent
home only when it repeatedly proves itself. The cheap, dynamic, mostly-discarded synthesis is the
point (cost-efficiency > build-and-demolish).

## How a runner consumes this (sim-conductor extension — shipped 2026-06-20)

`sim-conductor` is the runner that **fills** these slots instead of injecting an ad-hoc role directive.
The shipped extension (through the FH 4-axis gate, HITL): sim-conductor's Persona Discovery ② reads this
schema and fills the 6 slots; §Scale lifts its 3–16 cap behind the marginal-coverage stop (Crowd tier)
and assigns `cost tier` per persona for multi-LLM distribution; Step 5 adds the graduate step. Routing
decided by `[[asset-placement-gate]]` (2026-06-20): **not a new forked skill** (≈60–70% overlap with
sim-conductor's runner role) — this schema is the net-new asset, sim-conductor is extended to consume it.

## Sibling — skill-foundry (terminal-before-appification)

The same lifecycle generalizes to **skills**, with one inversion that is the whole point: a persona is a
low-trust simulation lens (ephemeral-and-many is the value); a skill is a governance asset whose value is
being **trusted**. A persona's low trust bar is harmless (a wrong lens is a discarded run); a skill's is
dangerous (a wrong instruction is trusted and reused). So a synthesized ("terminal-stage") skill is
explicitly **provisional / ungated / unpublished** — its SKILL.md is marked `lifecycle: provisional` with
an "ungated, in-session use only" banner so it cannot masquerade as a gate-passed skill.

**Provisional convention** (salience-dependent, NOT hook-enforced — no checker scans `lifecycle:` today;
it is a discipline, not a mechanical control): (1) used in the authoring session only — **not committed to
a shared plugin or marketplace before graduation**; (2) **deleted if it never graduates** —
build-and-keep-forever is the anti-pattern (the cheap-and-discarded discipline is the value); (3)
**graduates only through the FH 6-item creation gate** (CLAUDE.md §New Skill Creation Pre-Commit Gate) +
`[[asset-placement-gate]]` routing — HITL, never auto. Authoring reuses `contention-layer` Step-4's
skeleton (`origin: skill-foundry`; drop/replace `contention-parents` with a `source-action:` pointer,
mirroring that skeleton's field-scaffold reuse note). (Illustrative — *not* a committed artifact: a
`persona-safety-sweep` provisional skill kept local/gitignored, graduation-target = a sim-conductor preset.)

## Provenance

Validated end-to-end on the `the-bible` project 2026-06-20: container-filled blind personas found a
real substring-truncation grounding bypass; the multi-LLM tier comparison (e2b miss / 32B catch /
frontier verdict) grounded the cost-tier slot. Operator-origin concept; `[[asset-placement-gate]]`
routed it (schema here + sim-conductor extension + thin skill-foundry convention). Related:
`[[multi-persona-review]]` (the output-protocol architecture this builds on) · `tpa_schema.md` (the
target-profile schema sim-conductor pairs with this).

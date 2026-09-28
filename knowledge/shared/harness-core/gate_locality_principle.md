---
name: gate-locality-principle
description: A safety gate must live where the actor that needs it actually reads it — a gate defined in a place the enforcing actor never loads is decorative, not enforced.
type: reference
date: 2026-06-20
tags: [governance, gate-locality, multi-runtime, judge-robustness, field-harvest]
originProjects: [two restricted-env field harnesses]
---

# Gate-Locality Principle

> **A safety gate must live where the actor that needs it actually reads it.**
> A gate defined in a place the enforcing actor never loads provides the *appearance* of safety
> with none of the enforcement. Locality is part of the gate's correctness, not an afterthought.

This is a sibling of the **judge-robustness / mechanical-anchor** spine: judge-robustness says *don't
let a foolable judge hold the terminal verdict*; gate-locality says *don't put the gate somewhere the
enforcer can't see it*. Both fail the same way — a control that looks present but cannot actually fire.

## The failure mode (three observed shapes)

| Shape | Where the gate was | Who needed it | Why it didn't fire |
|---|---|---|---|
| **Code-locality** | absent from the write path entirely | the function that writes to JIRA | the writeback gate checked confidence but not provenance, so a self-inferred finding auto-posted as if verified |
| **File-locality** | only in a Claude-only `CLAUDE.md` | a Gemini/Codex orchestrator that auto-loads root `AGENTS.md`, not `CLAUDE.md` | the runtime assumed the commander *role* without inheriting the *gates* |
| **Trigger-locality** (added 2026-09-28) | in the right hook, running the right checks | the commit that changes a path the hook's **trigger pattern** does not match | the gate code is correct and never runs — and "no path matched" renders exactly like "all checks passed" |

**The third shape is the quietest, because nothing is misplaced.** The gate lives where the enforcer
reads it; only its *trigger* — a path pattern deciding whether the gate runs at all — leaves a class
of changes outside. FH hit it four times on its own gate (`scripts/` · `AGENTS.md` inheritance ·
agent definitions · `SKILL_detail.md` — the history sits in `scripts/gate_pathspec_check.sh`'s header,
which is also the mechanical anchor for FH's instance). The **first field-harness instance** was
measured 2026-09-28 on friends-on-desk: its pre-commit runs the quality gate only when a staged path
matches an **allowlist** of directories, and the app-code directory was not on it — of 171
September `main` commits, 24 touched a path under `standalone/` and nothing on the list (18 if the
predicate is narrowed to `standalone/overlay/src/`; either way a lower bound, since `main` is
squash-merged and branch commits are not counted). The gate was caught up at merge time, by hand;
the commit-time green said nothing about app code.
**Fix pattern specific to this shape**: prefer a **skip-list** ("run unless every staged path is
known-safe") over an allowlist ("run only if a path is listed"). An allowlist puts every *new*
directory outside the gate by default. A skip-list moves the *default* to the over-block side — but it
is **not** fail-closed on its own: it fails silently too if a skip entry is broad (a parent directory
that later grows code), or if the "every staged path is skippable" predicate is malformed and matches
everything. So the choice buys a better default, not safety; the safety comes from the lane — a
known-pair that **extracts the live pattern from the hook** (a copy drifts from the thing it
verifies) and asserts both directions: code paths, including a *not-yet-existing* directory, run the
gate; the handful of genuinely safe paths do not; a mixed commit runs it.

Both were found 2026-06-20 across **two field harnesses** (Harness-A: a provenance gate missing from a
write path; Harness-B + Harness-A: orchestration gates that lived only in a Claude-only file). The
recurrence across two contexts is what lifts this past a
single anecdote; it is N=2 within one operator's projects, so **cross-operator confirmation is the
upgrade path** that would harden it from a working principle to a validated one.

## The fix pattern

Move the gate into the artifact the enforcing actor actually reads:
- **Code path** → put the guard *in the function that performs the irreversible action* (e.g. gate the
  writeback candidate generator on `provenance == verified`, not in a doc that describes it).
- **Multi-runtime orchestration** → put orchestration gates in a **model-agnostic** file every
  runtime loads (`AGENTS.md`), not in a Claude-only `CLAUDE.md`. A non-Claude orchestrator that never
  reads `CLAUDE.md` otherwise gets the role without the governance.

## Verification (how to know the locality fix worked)

A **blind target-tier sim** is the honest check: feed the enforcing actor ONLY the file/path it
actually loads (e.g. `AGENTS.md` alone, no `CLAUDE.md`) and present a trap the gate should catch
(e.g. a high-confidence but unverified finding to auto-write). Pre-fix the actor has no basis to
refuse; post-fix it refuses, citing the now-local gate. The behavioral delta *is* the proof of
locality — review alone cannot show it (review reads all files; the runtime does not).

## External anchors (independent evidence, added 2026-08-01)

- **[arXiv 2607.25398 — "HANDBOOK.md: A Benchmark for Long-Context Agentic Instruction Following"](https://arxiv.org/abs/2607.25398)**
  (Panavas et al.): 65 agentic tasks governed by expert-written SOPs of 20–124 pages, 824 programmatic
  criteria; **the best of thirty evaluated model configurations passes 36.2% of trials, most frontier
  configurations below 25%**. This anchors the *adjacent, stronger* claim this principle rests on:
  even a prose gate the actor **does** load under-enforces at scale — placement is necessary but the
  enforcement *modality* (hook/code vs prose) decides whether it fires. Cross-operator, cross-provider
  evidence that a prose-only control layer is substantially under-enforced at scale — the salience-layer-over-
  mechanical-floor split (CLAUDE.md 4-axis gate "Why hook", `[[feedback_vcs_layer_gate_enforcement]]`)
  is independently reproduced, not FH-idiosyncratic.
- **[arXiv 2607.08028 — "From Prompts to Contracts: Harness Engineering for Auditable Enterprise LLM Agents"](https://arxiv.org/abs/2607.08028)**
  (Ahn · Kim): independent convergence on code-enforced behavioral contracts over prompt instructions;
  their ablation shows code-owned enforcement blocks violations prompting alone permits. Cross-audit:
  `tracks/_audit/session_2026_08_01_prompts-to-contracts-sister.md` (B-tier, 2 imports identified).
- **[arXiv 2605.23950 — "Stop Comparing LLM Agents Without Disclosing the Harness"](https://arxiv.org/abs/2605.23950)**
  (Zhang · Wang · Ge · Xu · Hamm · Reddy, May 2026): formalizes the **Binding Constraint Thesis** —
  for long-horizon agent tasks, harness configuration (context construction, tool orchestration,
  verification) is often a stronger determinant of measured performance than the underlying model;
  harness-induced variance can exceed model-induced variance enough to **reverse published model
  rankings**, and leaderboard comparisons that omit harness disclosure are incomplete and potentially
  misleading. This anchors the *locality* claim from the adjacent direction: an undisclosed or
  misplaced harness doesn't just under-enforce a gate (the HANDBOOK.md anchor above), it can silently
  swap which system gets credit for an outcome — the same failure shape as a gate firing in a file the
  enforcing actor never loads.

These are external anchors for the **prose-vs-mechanical premise**; the locality claim itself
(N=2, one operator) still awaits direct cross-operator confirmation as named above. The
trigger-locality shape (2026-09-28) adds a second harness, not a second operator — same caveat.

## Relationship to other FH assets

- **steel-quench** carries this as a Wave-1 attack angle ("Gate-locality — is every safety gate
  readable by the actor that must enforce it?").
- **judge-robustness / mechanical-anchor** (`[[feedback_judge_robustness_mechanical_anchor]]`) — the
  sibling principle for *verdict* placement; gate-locality is for *gate* placement.
- **Non-Model Ground** — multi-runtime orchestration is exactly where gate-locality bites, because
  different runtimes load different files.

## Where a rule lives — the three seats (moved out of `README.md`, 2026-08-29)

A harness learns by writing rules down, and the always-loaded file only ever gets longer — so the
reasoning ends in a corner: *a harness that keeps learning keeps getting more expensive to start.* It
does not, because a rule has **three seats**, chosen by *when the rule has to fire*:

| Seat | Fires | Costs | Fits |
|---|---|---|---|
| **Always-loaded** | before you act | every session, every turn | rules whose trigger is an *intention* — tone, "don't normalize the unfamiliar", "prove the instrument works here". Nothing can hook an intention, so salience is the only layer |
| **The gate's own error message** | at the moment you act | **nothing** | rules whose trigger is an *action*. The message that blocks you also teaches the form: `Write, before the design: success = «…». never = «…».` |
| **The hook** | after you act | nothing | properties of a record — present · typed · attributable · non-vacuous |

The middle seat usually goes unused, and it is free: it is **this principle applied to salience** — the
actor reads the rule exactly where the action happens, so it does not have to be carried all session to
be there when needed.

🟥 **It is a third layer, not a replacement, and its honest limit is that it only fires on failure.**
Someone who gets it right never sees it. So mechanizing a rule does **not** shrink the resident layer:
measured on the change that produced this section, the machine grew by 480 lines and the always-loaded
prose by **zero** — which is correct, because the prose has to reach the author *before* they design
while the hook catches its absence *after*. A backstop cannot substitute for salience that must fire
earlier.

⚠️ And the threshold that would tell you a resident layer is "too big" is, in this repo, **not
grounded** — the numbers in our own doctor skill were introduced without a line justifying the
cutpoints, and one was set to a value the target already exceeded on the day it landed. We are
re-deriving them rather than trimming toward a number nobody can defend; cutting resident text toward
an unjustified target buys fail-open with the savings.

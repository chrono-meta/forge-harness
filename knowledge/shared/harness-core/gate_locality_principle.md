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

## The failure mode (two observed shapes)

| Shape | Where the gate was | Who needed it | Why it didn't fire |
|---|---|---|---|
| **Code-locality** | absent from the write path entirely | the function that writes to JIRA | the writeback gate checked confidence but not provenance, so a self-inferred finding auto-posted as if verified |
| **File-locality** | only in a Claude-only `CLAUDE.md` | a Gemini/Codex orchestrator that auto-loads root `AGENTS.md`, not `CLAUDE.md` | the runtime assumed the commander *role* without inheriting the *gates* |

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

## Relationship to other FH assets

- **steel-quench** carries this as a Wave-1 attack angle ("Gate-locality — is every safety gate
  readable by the actor that must enforce it?").
- **judge-robustness / mechanical-anchor** (`[[feedback_judge_robustness_mechanical_anchor]]`) — the
  sibling principle for *verdict* placement; gate-locality is for *gate* placement.
- **Non-Model Ground** — multi-runtime orchestration is exactly where gate-locality bites, because
  different runtimes load different files.

# Loop Engineering — the 5-question discipline and FH's loop inventory

> Companion node to the CLAUDE.md §Field-Harness Diagnostic **Loop-readiness lens** (its detail
> home) and to `sonnet_floor_doctrine.md` (PROSE loop legs are exactly where Sonnet-tier misses
> live — one spine, two lenses). Origin: 황민호 loop-eng 5-question review (2026-07-10, C-tier
> sister ledger — dedup hit on coverage, the *lens* absorbed) + Loop Engineering sister
> (`[[project_loop_engineering_sister]]`, Prompt→Context→Harness→Loop layering).

## The 5 questions — from diagnostic to design-time discipline

A path that *runs* is not a path that *loops*. Before authoring any autonomous path (skill step
chain, routine, close sequence), answer all five **at design time** — the diagnostic lens then only
re-checks what authoring already declared:

| # | Question | FH's mechanical form |
|---|---|---|
| 1 | **Initiate** — what starts it, mechanically or by utterance? | trigger phrases (≥3, gate-checked) · hooks (SessionStart/Stop/pre-commit) · cadence rules |
| 2 | **Complete** — is there a Done-When? | Done-When with declared check class (mandatory-pass / measured / judged) — already a skill-gate item |
| 3 | **Validate** — is the check anchored, not judge-only? | mechanical anchor over judge verdict (`[[feedback_judge_robustness_mechanical_anchor]]`); judged conditions name their adversarial pairing |
| 4 | **Halt** — budget guard, convergence detection, runaway stop? | token-budget-gate · convergence-loop N-round cap · goal-quench thresholds · the 1000-agent backstop |
| 5 | **Persist** — does state reach the next run? | session card · handoff STATUS stamps · edit-manifest predict-verify · memory |

**Design-time rule**: a new autonomous path whose author cannot answer one of the five has found a
defect *before shipping it* — cheaper than the diagnostic finding it later. The field-asset
scaffold (auto_project_mapping §6) carries halt + persist stubs so field skills answer #4/#5 by
construction, the same by-construction pattern as the gate-compliant skeleton.

## FH loop inventory — legs, enforcement class, measured gaps

Census 2026-07-10 — micro/session/weekly rows: cross-family codex gpt-5.5 xhigh repo audit, source-verified; quarterly/substrate rows: governor self-assessment (no external census yet — R-tier revisit). MECH = hook /
script / exit-code (tier-independent); PROSE = salience-dependent (Sonnet-floor risk surface).

| Loop | initiate | complete | validate | halt | persist |
|---|---|---|---|---|---|
| **Micro** — goal-quench | MECH (`.active` state) | mixed (Done-When explicit; `/goal` invocation manual) | MECH (`.pending` + pipeline-conductor gate) | **PROSE** (mid-run thresholds instructional) | MECH (calibration record) |
| **Session** — close chain ①–⑥ | PROSE (closing-phrase trigger) | PROSE (card-last ordering) | mixed (git/PR inputs mech, synthesis remembered) | PROSE (no budget/stop guard) | PROSE→**MECH improving** (companion-store sync script + SessionStart STATUS map, 2026-07-10) |
| **Weekly** — harvest-loop / audit cycle | PROSE (proposal at session start) | PROSE (self-reported Done-When) | mixed (`below_floor_scan.sh` exit code; rest hand-gathered) | mixed (critic retry cap 1; no global budget) | PROSE (audit file by hand) |
| **Quarterly** — maturity roadmap | PROSE | PROSE (phase gates defined, checked manually) | PROSE | n/a (calendar-bounded) | PROSE (roadmap doc) |
| **Substrate** — self-adaptation mission | PROSE (substrate-version jump trigger) | PROSE | 4-axis gate on removals (MECH at commit) | n/a | memory + signals |

**Reading the map**: the 4-axis auto-gate is FH's only all-MECH loop (initiate=hook detect,
complete=all-axes-or-block, halt=missing-marker-fails, persist=marker+manifest) — and it is also
FH's most trusted loop. That correlation is the doctrine: **trust tracks mechanization, not model
tier.** The PROSE-densest loops (session close, weekly) are where the measured misses actually
occurred (card staleness 2026-07-10; audit cadence slips).

## Case study — persist-leg mechanization (2026-07-10)

Company sessions push results to the companion store but never run the local close chain, so the
card's ⑤ update was the only reconcile point — prose, and mtime-blind: a status stamp landing
*before* a card rewrite became permanently invisible to the "newer than card" list. Fix: the
SessionStart hook now emits an **mtime-independent STATUS map** (all DONE/SUPERSEDED/RESOLVED
stamps, every session) with an explicit cross-check imperative. One measured miss → one mechanized
leg — the standing pattern (`sonnet_floor_doctrine.md §Why`).

## Hardening backlog — evidence-threshold, NOT built speculatively

The census surfaces candidate hardenings (close-chain checklist script, weekly-audit scaffold
script, harvest-loop evidence bundle, goal-quench checkpoint files). Per the build discipline
(`[[feedback_evidence_threshold_build_discipline]]`), each is built **only when its miss is
measured** (a real slip attributable to that PROSE leg), mirroring how the SessionStart hook and
STATUS map each shipped on a production miss, not a guess. Recording the map here *is* the
instrument: the next slip finds its leg pre-diagnosed.

| Backlog item | Fires when (measured trigger) |
|---|---|
| Close-chain ordered-checklist script (`①–⑥` with card-last refusal) | a close-chain step verifiably skipped/reordered in a real session |
| Weekly-audit scaffold + data-gather script | a weekly audit missed or hand-gathered wrong window data |
| harvest-loop Step 0-b/0-c evidence check | a harvest run misses completed items despite `fh_completed_*` existing |
| goal-quench mid-run checkpoint files (70/85/95%) | a /goal run blows through a threshold unnoticed |

## Done When (for a new/changed autonomous path)

- All 5 questions answered at design time, each leg labeled MECH or PROSE *(mandatory-pass)*.
- Any judged validate-leg names its adversarial pairing *(mandatory-pass — inherits the skill gate)*.
- PROSE legs on load-bearing paths carry a Sonnet blind-sim verdict *(measured — doctrine §ladder step 2)*.

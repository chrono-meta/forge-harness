# Measurement-Integrity Checklist — cross-model measurement pre-flight

> A cross-model measurement is only trustworthy if its **instrument** is verified first.
> Measurement integrity is a *precondition*, not a result. Three observed failure modes, each with a
> concrete countermeasure. Consult this before any FH measurement that compares models (sims, sidecar
> comparisons, capability-equalizer runs, the-bible model panels, A6-class experiments).

This is a **checklist a measurement consults**, not a gate with triggers and not a dispatch surface —
hence a knowledge doc, the lightest asset that holds it (a harness gets simpler over time). If it ever
becomes a gate other skills invoke, revisit the weight.

## The three failure modes + countermeasures

| # | Failure mode (observed) | Countermeasure |
|---|---|---|
| 1 | **Silent model fallback** — passing a model *slug* silently resolved to a weaker model (e.g. an `agy` slug fell back to Flash) instead of the intended one. The run *looks* like the named model but isn't. | **Pin the display name, not the slug** (e.g. `"Gemini 3.1 Pro (High)"`, not a bare slug). Confirm the resolved identity, don't assume the slug binds. |
| 2 | **Non-deterministic borderline verdicts** — contested/borderline cases flip across runs (observed: haiku 4/4 flip; flagship models flip too — flipping is **not** a tier signal). A single draw is noise, not a measurement. | **reps ≥ 3 on any borderline/contested verdict.** A single run on a contested case is inadmissible. Report the flip pattern (STABLE vs FLIP), not just the modal verdict. |
| 3 | **Generic self-identity probe** — a probe any model passes ("are you working? → OK") proves nothing about *which* model answered. | **Use a discriminating probe** — one that two different models answer *differently*. A generic-pass probe is invalid. The probe is a **pattern, not a fixed string**: a probe that discriminates Opus 4.8 from Sonnet 4.6 today may both-pass a future model generation, so **re-validate the probe each model generation** (same staleness class `memory-hygiene` exists to catch). |

## Why these are entangled (and why they matter beyond their own scope)

Item #2 (reps≥3) is the discipline that **retracted half the evidence** for the
`[[feedback_correlated_blindspot_union_over_majority]]` finding — one of its two supporting cases
turned out to be non-deterministic borderline flipping, not a stable correlated blind spot. So this
checklist is the **prerequisite** for any "correlated error" claim: you cannot call an error correlated
(and prescribe union-over-majority) until reps≥3 has distinguished a stable correlated error from a
single-draw artifact. Item #3 (discriminating probe) **embodies** the judge-robustness /
mechanical-anchor principle — don't trust self-reported identity, prove it discriminatingly
([[feedback_judge_robustness_mechanical_anchor]]).

## Done When

- The checklist enumerates all three failure modes, each with its countermeasure.
  *Check class: mandatory-pass (binary — three items present, each with a countermeasure).*
- The probe item specifies a **discriminating** test and rejects generic probes.
  *Check class: judged, pair: a probe that two different models both pass must FAIL this check; a
  discriminating one must distinguish them.*
- Any FH cross-model measurement records which checklist items it ran.
  *Check class: measured (count of items applied) — closes the predict-verify loop for future audit.*

## Optional hardening (when a measurement feeds a published / paper claim)

Escalate item #1 (display-name pin) and item #3 (identity verification) from prose to a **logged
mechanical assertion**: the measurement harness records the *verified* model identity it observed, not
the requested slug. Prose discipline is sufficient for internal dogfooding; a published claim earns the
mechanical log.

---

**Origin** (2026-06-22 harvest-loop): three failure modes observed across the-bible L2 model panel
(agy slug→Flash silent fallback; reps=3 non-determinism) and prior multi-model sims (generic-probe
ambiguity). Sister findings: [[feedback_correlated_blindspot_union_over_majority]] (reps≥3 prerequisite),
[[feedback_judge_robustness_mechanical_anchor]] (discriminating-probe = mechanical anchor),
[[reference_agy_model_catalog]] (display-name pin — agy slug fallback documented there).

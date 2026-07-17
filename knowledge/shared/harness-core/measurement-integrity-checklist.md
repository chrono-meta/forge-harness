# Measurement-Integrity Checklist — cross-model measurement pre-flight

> A cross-model measurement is only trustworthy if its **instrument** is verified first.
> Measurement integrity is a *precondition*, not a result. Four observed failure modes, each with a
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
| 4 | **Serving-path / quantization variance** — the *same* display-name model served over two different backends (different quantization/infra) is a **different instrument** and yields materially different measurements. Observed: one GLM-5.2 model family gave effect-size delta **+0.21** when served via an internal NVFP4-quantized deployment vs **+0.08** via an OpenRouter relay — same model name, ~2.6× different effect (n=864, reps≥3). A correctly-pinned display name (item #1) is **necessary but not sufficient**. | **Pin *and record* the serving path** — backend host + quantization, not just the display name. Two runs are comparable only if the serving path matches; a name match across different infra is an implicit apples-to-oranges. When you cannot hold it fixed, **report the serving path as a measured variable**, not a constant. |
| 5 | **Injected-context contamination (blind-sim class)** — a subagent dispatched to evaluate a *modified* instruction file answers from the **auto-injected project context** (claudeMd/memory baked into its system prompt at spawn) instead of reading the target. Observed twice in one session (2026-07-17): a "blind sim" quoted section numbering that existed only in the pre-edit file, and a second sim cited trigger-table rows that had been **deleted** from the file it claimed to have read — tool-use count 0–1 in both. The measurement *looks* grounded (fluent, plausibly cited) but the instrument never touched the target. A prompt-line telling it to ignore injected context is **not sufficient** — both runs had one. | **Force mechanical grounding a stale answer cannot fake**: ① stage the target at a **neutral path** (tmp copy) the injection cannot cover; ② require **verbatim quotes** (or grep line-number output) from that path for every claim; ③ design the probe around a **content discriminator** — something present only in the new version, or *absent* from it (a deleted row cited = instant invalidation); ④ treat **tool-use count as a validity signal** — a sim that "read two files" with 0–1 tool calls is invalid regardless of answer quality. Re-run, don't argue with a contaminated result. |

## Why these are entangled (and why they matter beyond their own scope)

Item #2 (reps≥3) is the discipline that **retracted half the evidence** for the
`[[feedback_correlated_blindspot_union_over_majority]]` finding — one of its two supporting cases
turned out to be non-deterministic borderline flipping, not a stable correlated blind spot. So this
checklist is the **prerequisite** for any "correlated error" claim: you cannot call an error correlated
(and prescribe union-over-majority) until reps≥3 has distinguished a stable correlated error from a
single-draw artifact. Item #3 (discriminating probe) **embodies** the judge-robustness /
mechanical-anchor principle — don't trust self-reported identity, prove it discriminatingly
([[feedback_judge_robustness_mechanical_anchor]]).

Item #4 (serving-path variance) **sharpens** item #1 into a two-part identity: #1 catches the *wrong
model* (a slug that fell back); #4 catches the *right model on the wrong instrument* (a correct name
served over a different quantization/backend). The verified identity a measurement records is therefore
**name + serving path**, not name alone — a family-decorrelation claim (cross-family sidecar) is only
sound once the serving path of each family is itself pinned, else "different family" silently smuggles
"different infra" ([[reference_measurement_serving_path_variance]]).

Item #5 (injected-context contamination) is item #3's sibling on the *input* side: #3 proves *who*
answered, #5 proves *what they actually read*. Both reduce to the same mechanical-anchor rule — never
accept a measurement's self-report (of identity or of grounding) when a discriminating mechanical
check is available. Its sharpest tool is the **deleted-content discriminator**: a probe target that no
longer contains X makes any answer citing X self-invalidating — certainty no prompt instruction buys.

## Done When

- The checklist enumerates all five failure modes, each with its countermeasure.
  *Check class: mandatory-pass (binary — five items present, each with a countermeasure).*
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

> **External dogfood (a second, field-layer instance — n=1 external, a signal not a settled frontier):**
> the sister skill `ponytail` ships a runnable instance of the precondition behind all three modes —
> a `--selftest` that proves each instrument (`good===true && bad===false`) before any API spend, and
> two caught instrument contaminations. Detail + pinned citations: `tracks/_audit/session_2026_06_24_ponytail-lazy-senior-dev.md` §2-C (single source).

---

**Origin** (2026-06-22 harvest-loop): three failure modes observed across the-bible L2 model panel
(agy slug→Flash silent fallback; reps=3 non-determinism) and prior multi-model sims (generic-probe
ambiguity). Sister findings: [[feedback_correlated_blindspot_union_over_majority]] (reps≥3 prerequisite),
[[feedback_judge_robustness_mechanical_anchor]] (discriminating-probe = mechanical anchor),
[[reference_agy_model_catalog]] (display-name pin — agy slug fallback documented there).

**#4 added** (2026-07-05): serving-path variance surfaced in a cross-family verdict-invariance run
(n=864, borderline fixtures × 2 conditions × K=6 paraphrase × reps≥3). An identical GLM-5.2 model name
served over an internal NVFP4-quantized deployment vs an OpenRouter relay gave +0.21 vs +0.08
effect-size delta — quantifying that "same model name ⇒ same measurement" is false. Provenance +
generalizable finding: [[reference_measurement_serving_path_variance]].

**External corroboration** (2026-07): the local-LLM community independently reports the same hazard —
practitioners conflate "running model X" with running a *pruned/quantized derivative* of X (aggressive
low-bit quantization + expert pruning measurably degrade long-context quality while the model *name* is
unchanged). This is a general measurement pitfall, not FH-specific: a leaderboard or replication that
pins only the display name silently compares different instruments across serving paths.

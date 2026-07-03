---
name: field_verdict_crossfamily_gate
description: Load-bearing field-project verdict/gate/safety code gets the same cross-family adversarial gate as FH assets — the correlated default-toward-PASS blind spot is model-family-level, not FH-specific.
type: reference
date: 2026-07-03
tags: [cross-family, decorrelation, verdict-binding, field-harness, degrade-direction, correlated-blindspot, mode-d]
---

# Field-Harness Load-Bearing Change Gate — cross-family, pre-merge

> Compressed rule + trigger table live in `CLAUDE.md §Field-Harness Load-Bearing Change Gate`.
> This is the detail: the root principle, the failure signature, the gate mechanics, and the
> field evidence (qasp, 2026-07-03).

## 1. The root principle — prose specification grants discretion, not depth

Specifying an engine's decision logic in **conversational / prose** terms ("add more depth",
"break it down and analyze", "consider carefully whether it passed") does **not** add depth —
it grants **discretion**. The model fills that discretion with its **optimistic prior**. On a
verdict surface, the optimistic prior is *PASS*. So wherever a verdict surface's judgment is
under-constrained, its **degrade direction is toward PASS** — the exact opposite of safe-fail.

Corollary: **real depth in an engine = removing discretion (more mechanical constraint), not
better prose.** "깊이를 더해라" applied to engine logic is a category error. This is the same
axis as FH's `[[feedback_judge_robustness_mechanical_anchor]]` (terminal verdict needs a
mechanical anchor, never judge-only) and the source-level reinforcement question (does the
*format* of an emitted anchor change computation, not just its content).

Negative example (반면교사): **CaseCraft** hung loose prompts on the engine logic → the engine's
verdicts inherited the LLM's unconstrained optimistic reading → holes. **qasp / pmh overcame it**
by mechanizing the verdict surface (verdict-binding = mechanical ground truth only, no-judge,
fail-closed gates, mechanical anchors). See `[[project_qasp_casecraft_positioning]]`.

## 2. The failure signature — one sentence, four faces

> **"When a verdict surface cannot mechanically ground its judgment, it defaults toward PASS
> instead of safe-fail."**

Every instance is a form of **discretion leaking into verdict logic**:

| Face | The discretion | Safe-fail form |
|---|---|---|
| **default-PASS-on-absence** | unconstrained `else` / fall-through picks the permissive value | explicit `BLOCK`/`None`/raise |
| **affordance-without-grounding** | score-heuristic "judgment" of what counts as a match | hard grounding gate (target-text must score > 0) |
| **substring-not-exact** | loose definition of "present" (`tok in text` → paid⊂prepaid, 완료⊂미완료) | exact / word-boundary match |
| **unknown-to-permissive-default** | unenumerated branch defaults to allow | enumerate-or-safe-fail |

## 3. Why same-family review misses it — and cross-family catches it

The blind spot is **directional** (the degrade direction on the unhappy path) and rests on a
**shared optimistic prior**. A same-family reviewer — even a frontier model, even a target-tier
blind sim — reads the under-constrained branch the same optimistic way the author wrote it, so
it does not *see* the discretion as a hole. A **different-family** auditor does not share that
prior, so it reads the same branch adversarially and names the false-PASS.

This is not "cross-family is smarter" — it is **decorrelation**: the value is that the auditor's
error distribution is *different*, so it covers the author's directional blind spot. Governor
discipline still applies: sidecar findings are **candidates**, not terminal; the governor
source-grounds each (does the real pipeline reach it? does an existing mechanical anchor mitigate
it?) before acting — mechanical anchor over agreement.

## 4. The gate (before merge, not after)

1. **Degrade-direction lint** — `scripts/degrade_direction_scan.sh` (portable copy:
   `templates/degrade_direction_scan.sh`). A cheap **mechanical pre-screen**: greps the changed
   files for the code shapes above (except/else→PASS, `.get(k, <pass>)`/`setdefault`,
   substring-on-grounding-line). **Advisory review surface, NOT a hard gate** — grep-heuristic,
   false positives expected; a hit means *"prove this is not default-toward-PASS"*, and it never
   blocks alone (exit 2 = advisory). It points attention; it does not decide. Opt-out per line:
   `# noqa: degrade`. It scans **py + sh**; a changed load-bearing surface in any other language is
   reported as *unscannable / not-covered* (exit 2), never folded into an "advisory clean". **Efficacy
   caveat**: in the n=7 qasp sweep the lint itself caught nothing — the catches were the cross-family
   audit + accumulated regression tests. It is a token-free pre-screen ahead of a paid cross-family
   dispatch, *not a proven detector*; revisit if it never surfaces what the cross-family pass wouldn't.
2. **Cross-family adversarial review** — `auto-decorrelation` recruits ≥1 different-family auditor
   (e.g. `codex` gpt-5.5 / high for repo-grounded verdict code). The same standing verifier the
   4-axis gate uses for load-bearing FH assets, now applied to **field** load-bearing changes.
3. **Confirm → fix → re-verify loop** — iterate until the cross-family pass is **CONVERGED**: no
   reachable false-PASS / false-CONFIRMED / masked-FAIL / crash-where-safe-fail-required. **Each fix
   ships a mechanical regression test** reproducing the closed hole — a *required* convergence
   sub-condition, not incidental. (Two decorrelated models agreeing is still judgment; in the n=7
   sweep the round-6 over-correction was caught by an accumulated regression test, so the anchor leg
   is made mandatory — mechanical anchor over agreement.) Documented recall-limits of a
   deliberately-precise no-judge oracle (e.g. separator-negation `un-paid`, row-level positional
   state swap in a multiset projection) are **not** blockers — inherent precision>recall tradeoffs,
   fixture-tracked, not discretion-holes.

**Degrade direction — cross-family unavailable ≠ silent same-family pass** (the gate's own standard,
dogfood-caught 2026-07-03): the gate delegates the cross-family step to `auto-decorrelation`, whose
*general* degrade is "missing sidecar CLIs never hard-fail → in-session same-family + honest note."
That silent-degrade is **fail-OPEN for a load-bearing pre-merge surface** — same-family review shares
the author's directional blind spot, so proceeding on it defeats the gate's entire decorrelation
value while *claiming* the gate ran. So for this surface the gate **overrides** the default degrade:
cross-family unreachable → mark **NOT-CONVERGED** and block the autonomous merge / ask the operator,
or proceed only under an explicit **logged same-family-only acknowledgment** — never a silent
same-family pass. (This is the same fail-closed direction the target-tier Sonnet sim itself chose:
"if no cross-family sidecar is reachable, say so explicitly … not silently treat that as a pass.")

**Trigger (per changed file — grep-assisted, salience-dependent, no field hook)** — an AI-authored
change to a load-bearing field surface: a function returning a **verdict/gate enum or exit code**
(PASS/FAIL/BLOCK/allow/deny), an **irreversible-op** path (publish/delete/history-rewrite), or a
**safety invariant** (the-bible L1 floor, qasp verdict-binding, a pre-push/pre-commit hook). The
grep recipe (verdict-enum return / gate exit / safety-marked function) is a **strong-advisory
trigger, not a hook** — the FH pre-commit gate is FH-internal and never installed into field
projects, so it is salience-dependent, and the "safety invariant" category is interpretive, not
grep-decidable. **Named under-trigger residual** (do not claim airtight): unmarked safety logic,
boolean-return gate helpers, config-driven allow/deny, and shell/CI irreversible paths can escape
the grep — an agent under merge pressure can under-trigger by treating a change as non-load-bearing.
That residual is the reason the gate is reinforced by the always-on Autonomous-Initiative trigger
row + the operator's proactive framing, not by the grep alone.

**Residency** — sanitize company code (redact vendor/domain literals) before any external-family
dispatch; domain data never leaves. **Autonomy** — autonomous once the operator has consented in
the UAP (`tracks/_meta/user_adaptation_profile.md`, defined in `.claude/rules/operational_adaptation.md`),
same as the FH cross-family complement.

## 5. Field evidence — qasp verdict-binding sweep, 2026-07-03 (n=7)

The gap that motivated this rule: FH's cross-family decorrelation rigor had **never been
auto-applied to field-harness code** — only to FH's own assets. A one-time sweep of 3 mapped
harnesses (qasp / the-bible / pmh) found **9 HIGH default-toward-PASS holes**, all one signature.

qasp was fixed under this exact gate, and the **loop itself became the evidence**: each
confirm→fix→re-verify round, a **different family** caught the residual discretion that the
*previous same-family fix* had left — 7 rounds to CONVERGED. Even the frontier author's own
round-6 fix over-corrected (trusted a raw `"PASS"` string), and a **mechanical anchor** (a
round-1 regression test) caught it. Both legs of the doctrine — cross-family audit *and*
accumulated mechanical tests — fired against same-family error.

Positioning note: this is an **observational** field study, not yet a controlled claim. The
controlled follow-up (same- vs cross-family yield on a fixed bug corpus) is what turns the
observation into a result. Raw study: a private companion store's `paper-signals/` (Mode D;
`research_candidate_correlated_blindspot_verdict_code_2026-07-03.md`).

## 6. When baked into autonomous loops

In innovator-based loop-engineering (operator delegates a goal), `/goal`, or cluster
orchestration, this gate is **part of the delegated pipeline**, not an afterthought: a
load-bearing field change produced autonomously runs the degrade-lint → cross-family review →
converge loop **before it is considered done**. The autonomy floor applies — the skip/run
judgment on borderline cases is trusted only at opus-tier or above; a below-floor orchestrator
runs the review or asks, never silently skips (`[[feedback_judge_robustness_mechanical_anchor]]`,
CLAUDE.md §Floor governance).

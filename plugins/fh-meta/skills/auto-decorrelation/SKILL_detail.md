---
name: auto-decorrelation-detail
description: On-demand detail for auto-decorrelation SKILL.md (moved verbatim; salience split).
load: on-demand
---

# auto-decorrelation — on-demand detail

## §Sidecar-Wait-Rationale

  **Why this is mechanical rather than a habit** — the bullets below already described bounding a
  sidecar, and a session that had them loaded still got it wrong on 2026-07-29: it backgrounded
  `codex exec` and `agy -p`, read the output files after **1 s and 30 s**, found them empty, and
  recorded *"both sidecars returned 0-output"* into a gate marker, a PR body, a session card, a
  memory file and a handoff. Both were running normally and both answered — codex with 48 KB and
  three findings, agy with a further HIGH, and **all four were real**; one of them showed the change
  under review was over-applied. So the measurement error nearly retired a working mechanism.

  **That is a second failure mode this section did not cover.** The bullets below describe a *hung*
  sidecar. An impatient read of a *healthy* one produces the identical observation — zero bytes —
  and only one of the two is a fault. Distinguishing them requires process state, which is exactly
  what a human eye on an output file cannot see and the runner always reports.

## §Residency-Notes

🟥 **On a fresh install with no operator pattern file, this WILL be exit 10 every time** — that is
the scanner's own documented fail-closed default (`residency_closure_scan.py`'s header: "오버라이드
파일이 없으면 exit 10 이다"), not a bug introduced here. It means: until an operator configures
their own residency patterns, this skill cannot claim a panel dispatch was screened, so it honestly
degrades to a `DEGRADED_*` rung with `residency=NOT_SCANNED(...)` instead of silently sending. That
is not a new block on fresh installs — the crossfamily field already tolerates `DEGRADED_*` without
hard-failing the commit; it is one more honest reason to be in that state, not a novel one.

**Where the result lands**: `templates/.git-hooks/pre-commit`'s `validate_crossfamily_leg` now
requires a `residency=CLEAN(...)` token inside the grounds of any `panel(...)` value (grace date
`RESIDENCY_TOKEN_GRACE_DATE`, no retroactivity on markers dated earlier), and accepts an optional,
format-checked `residency=(CLEAN|TAINTED|NOT_SCANNED)(...)` token on `DEGRADED_*`/`UNKNOWN`/
`declined`. Fixtures: `scripts/test_marker_crossfamily_lanes.sh` (`r1`–`r13`). This is the SAME
typed field Step 6 already emits into — one channel, not a second marker line.

## §Evidence-Rationale

`residency=` says the payload was safe to send. `evidence=` says **what was sent** — and that is the
axis the outside world just measured as the dominant one. `arXiv:2609.10969` (48 task templates →
2,880 scenarios, **fixed call budget** so the comparison is about the axis and not about spending
more): a cross-model vote over **shared** evidence approved **62.9 %** of unsafe proposals against
**22.9 %** with an **independent source** — source effect **40.9 pp** vs **11.3 pp** for model
diversity, i.e. **3.6×**.

🟥 **This skill's default flow is `SHARED`, by construction.** Step 4 builds **one** payload and fans
it out, so a panel dispatched the ordinary way through this skill is the **62.9 % arm** — the axis it
raises is model family, which the paper prices at 11.3 pp. That is not a reason to stop using it: a
finder is worth its recall, and this skill's value was never precision
(`[[feedback_decorrelation_is_a_cheap_finder]]`). It **is** a reason to stop recording that run as if
it carried the stronger axis. Write `SHARED` and mean it.

🟢 **`SHARED` is a legal, expected answer.** The hook does not block it; it blocks a `panel(...)` that
does not say which it was, a value outside the closed three, a malformed or duplicated token, and a
**vacuous body** on `SHARED`/`MIXED` (name the artifact — *"same staged diff"*, *"one findings.jsonl"*,
*"identical prompt file"*). `INDEPENDENT` is self-describing and is not body-checked, deliberately:
over-blocking the honest strong answer would train the override.

⚠️ **Named gap, not built today**: this skill has **no independent-source mode**. Giving it one
(each member reconstructs the evidence itself rather than reading the author's payload) is the change
that would move it onto the 40.9 pp axis; it is a design question, not a wiring one, and it is
recorded as a signal rather than improvised here.

⚠️ **Scope, same as everywhere else in this file**: CLEAN is a screening result, not a safety
guarantee (dynamic imports, non-Python artifacts, encoding tricks, and TOCTOU are named, unclosed
gaps in the scanner's own header). Recording `residency=CLEAN(...)` asserts the scan ran and found
nothing **within those limits** — it does not assert the payload is safe in some absolute sense.

## §Step5-Notes

**Report shape (2026-09-05)**: when the findings are written up (PR body · marker `crossfamily:` expansion · chamber record),
use `templates/RED_TEAM_REPORT.md` — the five sections mirror ISO/IEC AWI TS 42119-7 (risk identification · objectives & attack
vectors · method · findings with reproducing input · life-cycle integration). It is a name tag on what this skill already
produces, not a new check; crosswalk: `knowledge/shared/harness-core/iso_ai_standards_crosswalk.md §2`.

*Origin*: sister-asset read of `raphaelchristi/harness-evolver`'s `harness-critic` agent, whose whole
role is auditing the **evaluator** rather than the artifact. Its detection signatures (score jumps,
suspiciously fast convergence) do **not** port — FH markers carry no score — but the *target* does.
Full assessment incl. what was deliberately not imported: `tracks/_audit/proposal_2026-08-19_sister_harness-evolver.md`.

## §Degrade-Rationale

**The three degrade values are the load-bearing split**: *could not* (`DEGRADED_SINGLE_FAMILY`) ·
*did not* (`DEGRADED_PANEL_UNUSED`) · *did not look* (`UNKNOWN`). Free prose merges all three, and
each merge hides a different thing — an unrun probe renders as a zero finding
(`[[feedback_not_found_is_not_zero_family]]`), and an unused panel renders as an unavailable one.
The sibling-harness signal that motivated this field said it in its own words about itself:
*"못 한 것이 아니라 안 한 것이다."* All three require an ack naming *what was probed and what it
returned*. **`DEGRADED_PANEL_UNUSED` was added by dogfooding**: the first real marker written under
this lane found the panel reachable (codex · agy · gemini) and no cross-family review run — a state
the original five-value enum could not express without lying
(`[[feedback_adversarial_review_not_substitute_for_first_use]]`).

## §Step-6-5-Standpoint

**Step 6.5 — Standpoint axis (2026-08-14, orthogonal to the family ladder above)**: for a
**shared-body / cross-harness-boundary** change — scoped by *effect* (alters another harness's
behavior, gate outcome, or interaction contract), not merely by touching a synced file path — also
emit `standpoint:` alongside `crossfamily:` in the same marker — recruiting family diversity here
does not substitute for it. Values: `tier1` (content-only, the default) · **`tier1b(<harness>)`
(STATIC read of the target's own files — executed nothing)** · `tier2(<harness>)`
(peer-simulated — **EXECUTED CODE in** the target's own repo and observed the result.
🟥 **Reading the target's real files, however cold, is `tier1b`, not this.** The discriminator is
mechanical: *name the command you ran and the output you saw*; cannot name one → `tier1b`, always.
This line said **"ran the target's own repo, content only"** until 2026-08-17 — actively teaching
the opposite of the canon it summarizes. 🟥 **RETRACTED (2026-08-17)**: this passage used to add
that blind Sonnet sims *"STILL graded a pure cold-read `tier2`, both quoting this phrasing"* after
the other two copies were fixed. Those runs had **`tool_uses: 0`** — nothing was read, so nothing
was measured, and the claim that the sims "reached for this copy" was itself unfounded
(`tracks/_meta/fh_completed_2026-08-16.md:690`; the live re-run inverted the grade at reps=1, below
bar). **The reason to fix this copy needs no sim**: a summary that states the opposite of its canon
teaches the opposite to whoever reads only the summary, and **two of three copies fixed is a fix
that does not exist** — that is gate-locality, not a measurement. See `§7` for the canon) · `tier2b(<harness>)` (same operator,
target's real runtime — local wiring visible, but not an independent reviewer) · `tier3(<harness>)`
(a *different* operator of the target harness ran it — the only fully independent + local-wiring
rung) · `not-applicable` (no target-harness standpoint exists — most same-repo dispatches) ·
`DEGRADED_NO_TARGET_ACCESS` / `DEGRADED_NOT_RUN` / `UNKNOWN` (own literals, not crossfamily's). Note
the naming collision with this session's own persona/viewpoint sense of "standpoint" (the `beginner`/
`main-player`/`expert` agent roster) — different axis, same English word; do not conflate.
**Prose-only** — no hook or fixture validates this field yet, unlike `crossfamily:`, and
mechanizing it is FH's own job (a syncing sibling harness cannot add the check locally without its
own sync process rejecting the divergence). **Timing — same moment as Axis 2/3
(steel-quench/phantom-quench), not a follow-up**: run on the local diff before the first push to
any remote (public or private — no visibility judgment to make), one unconditional rule regardless
of perceived risk — see `field_verdict_crossfamily_gate.md §7 Sequencing` for why (a real PR pushed
this exact field to a public repo with two residency leaks in view, caught only after the PR was
already open). Full field spec, trigger scope, and evidence:
`knowledge/shared/harness-core/field_verdict_crossfamily_gate.md §7`.

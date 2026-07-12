# Operational Adaptation Loop — User-Tuned Self-Optimization

Self-healing in FH today has two shapes: **FH-self-dev** (Mode D, the 4-axis auto-gate improving FH's own assets) and **reactive** (`verify-bidirectional`, a one-shot baseline update when the user pushes back). Both leave a gap: there is no **standing, per-user, operational** loop that tunes FH's everyday behavior to the individual during normal field use — and feeds the generalizable part of that tuning back to the origin.

This loop fills that gap. It is deliberately thin: it **reuses** existing parts and only adds a profile convention + a generalization gate.

| Concern | Existing part (reused — NOT rebuilt) | What this loop adds |
|---|---|---|
| Reactive correction | `verify-bidirectional` (per-correction baseline update) | A standing, aggregated profile (not one-shot) |
| Reverse-PR funnel | `field-harvest` Mode A (field pattern → FH PR) | Feeds it generalizable UAP entries |
| Outcome vocabulary | `operations.md` `subagent_invocations_log` (`accepted`/`rejected`/`sustained` + 60/40 gate) | Same vocabulary, extended from sub-agents to **skill proposals** |

## User Adaptation Profile (UAP)

**Location**: `tracks/_meta/user_adaptation_profile.md` — **local / gitignored**. It is a **personal asset**, never committed to the public mirror (single-source / drift guard, per `modes_and_value.md`). Mode D: mirror to the companion store's `tracks-meta/`.

**Records behavioral preferences ONLY** — never domain work content (protects reference-asset identity):
- **Skill-proposal outcomes** — per skill: `accepted` / `rejected` / `sustained` with counts (same 4-category vocabulary as `operations.md`).
- **Preferred execution tier** (S/M/L/XL), language, working cadence.
- **Capability-escalation consent** — `sidecar_consent` + `floorup_consent` (`accepted`/`declined`/`unset`),
  per the **Capability-Escalation Consent Protocol** (`knowledge/shared/harness-core/capability_escalation_consent.md`).
  Settled at onboarding (install-wizard) or ask-once at first need; `declined` → route to the floor
  (Sonnet / Tier-3 CC-only sub-agent as a *first-class* mode), surface as recommendation only, **never re-nag**.
- **Recurring friction points** (aggregated from `fh_signal_*`).
- **Muted nags** — cadence reminders the user repeatedly declines.

## Operational adaptation pass (field-session close)

Runs at field-session close, **riding `field-harvest` Mode B** — no new trigger, never an interception. One pass per session.

- **READ** (session start / proposal time): apply UAP — suppress a skill proposal rejected 3+ times (an `accepted` record carries **no** positive auto-action — the skill simply stays surfaced; do not auto-run on acceptance), default to the preferred tier, mute cadence nags the user always declines, and **apply capability-escalation consent** (`sidecar_consent`/`floorup_consent` `declined` → route to the Sonnet / Tier-3 floor, recommend-only, no re-nag; `unset` → ask-once at first need per the consent protocol). (Tier note: the UAP tier default is a session-depth setting; the Mode D model notice is model-only + advisory and never overrides it.)
- **WRITE** (session close): update outcome counts + new friction points.

## Generalization gate → reverse-PR funnel

This is the operator's **"원본 반영 가치"** criterion made mechanical. Split each UAP learning:

- **Idiosyncratic** (this user's taste) → stays in the UAP, local. **Never** escalated — pushing personal taste into the public reference asset is drift.
- **Generalizable** (any user would benefit; the pattern recurs across **2+ sessions or projects**, not user-specific) → routed through `field-harvest` Mode A as a harvest candidate → FH-origin PR (HITL approval, per the existing field-harvest gate).

**Promotion threshold** (reuse `operations.md` gate): a skill proposal `rejected ≥ 40%` across a 2+ session window is a *redefine/deprecate* candidate (a generalizable signal worth a PR); `accepted ≥ 60%` reinforces. Below threshold → personal one-off, stays local.

**Generalization is a judged call — adversarial pairing required (no judge-only path).** The idiosyncratic-vs-generalizable split is not decided by the same session that wrote the UAP alone: it is paired with (a) the mechanical **2+ session/project recurrence threshold** above, and (b) `field-harvest` Mode A's contention-layer + the **human PR review** gate. A learning only reaches the public mirror after passing both — the recurrence backstop filters one-offs, the PR gate filters taste a human disagrees is general.

## Done When

- **UAP WRITE ran** at field-session close (or was correctly skipped — absent profile / ephemeral session). *Check class: mandatory-pass (binary — did Step 5-B.1 execute or log a skip reason).*
- **UAP READ applied** at session start / proposal time when a profile exists (preferred tier defaulted, 3×-rejected proposals suppressed, declined cadence nags muted). *Check class: judged, pair: the target-tier blind sim below.*
- **No domain content** entered the UAP this session. *Check class: judged, pair: phantom/content scan of the UAP diff.*

## Guards

- **Local-default, escalate-only-generalizable** — the drift-prevention spine of the loop.
- **Behavioral data only** — no domain content in the UAP (reference-asset identity).
- **Ephemeral env** — the UAP is gitignored, wiped on cloud reclaim. In an ephemeral/cloud session it is **unavailable**: operate from defaults, do not fabricate a profile, do not rely on it for cross-session continuity (`modes_and_value.md` ephemeral rule). The loop is a **local-session** mechanism.
- **HITL** — escalation to FH origin goes through `field-harvest`'s existing PR-approval gate; no autonomous commit to the shared repo (`feedback_no_personal_commit_to_shared_repo`).
- **Salience / tier dependence** — this loop is prose-driven, not hook-enforced. On a weaker model the READ side (apply-at-session-start) may silently not fire even when a UAP exists. This is an accepted limitation, not a silent one: it is the reason the change ships with a target-tier blind sim (per CLAUDE.md §Target-tier sim gate). A hook-enforced READ is a future hardening candidate, deliberately not built today (keep the surface thin).

  **Deliberated 2026-06-16 (decision: DEFER) → BUILT 2026-07-05 (revisit-trigger fired on a real miss).**
  The right mechanism is *not* the git pre-commit hook (the READ fires at session-start / proposal-time,
  which is not a git event) but a Claude Code **SessionStart hook**. The 2026-06-16 deferral set a
  **measured revisit-trigger** (build only when a real miss is observed, not on a guess). That trigger
  **fired 2026-07-05**: an opus-tier session opened with an immediate qasp task, the prose session-start
  companion load silently did not fire, and the agent operated on stale local memory (stale agy version;
  missed the standing origin-model-sidecar instruction). This was a *production* miss, stronger evidence
  than the deferral's target-tier-sim bar — so the hook is now built: **`scripts/fh_session_load.sh`**,
  registered operator-local in `.claude/settings.local.json` SessionStart. It pulls the companion store
  and emits a freshness delta (files newer than the session card + INDEX live pointers) into turn-0
  context, *before* the first user message is processed — closing the task-first-entry salience gap
  mechanically. Note the miss was **not** low-stakes as the 2026-06-16 note predicted (it produced wrong
  recommendations, not just an unapplied preference), which is what tipped defer → build. Prose READ
  remains the semantic layer (read + reconcile); the hook is the mechanical floor
  (`[[feedback_judge_robustness_mechanical_anchor]]` — mechanical anchor over salience).

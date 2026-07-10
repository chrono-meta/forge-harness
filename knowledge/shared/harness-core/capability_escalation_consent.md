# Capability-Escalation Consent Protocol

> **Principle**: any escalation that raises **cost or trust surface** — recruiting a **cross-family
> sidecar** (external model families see the work) or a **model-tier floor-up** (Sonnet → Opus, higher
> $/token) — is **consent-gated and negotiated up front**, never sprung silently. A user who was never
> asked, then finds a paid/external escalation happened, feels **blindsided (뒤통수)**. The harness
> must run **intelligently on Claude Code alone at the Sonnet floor** for anyone who declined, using
> **sub-agents** in place of cross-family sidecars — as a *first-class mode*, not a degraded one.

This is a **규약 (convention)**, not a per-call decision: the same answer holds for the whole session
once settled, and is **remembered across sessions** (UAP) so it is asked at most once.

---

## Two escalation axes (same consent shape)

| Axis | Escalation | Why it needs consent | Floor when declined |
|---|---|---|---|
| **(a) Cross-family sidecar** | recruit codex / agy / gemini / local-4090 as a verifier | work leaves the Claude boundary (external family sees it) + external billing | **Tier-3 CC-only sub-agent** (isolation-decorrelation, honest same-family note) |
| **(b) Model-tier floor-up** | Sonnet → Opus for a depth-heavy turn | higher $/token (Opus ≈ 3–5× Sonnet); the operator's real cost lever | **stay at Sonnet** (the established minimum-recommended floor) |

**Sonnet = minimum-recommended model is already established** — so the declined-floor is safe: the
harness is *designed* to run well at Sonnet, not crippled by it (`[[feedback_harness_aerodynamics_perceived_perf]]`).

---

## When consent is settled — two entry points

### 1. Onboarding negotiation (install-wizard) — the no-surprise path

install-wizard **explicitly negotiates both axes** at setup, as named items:
- *"Allow cross-family sidecars (codex/agy/local) for adversarial verification of load-bearing changes? They add external-family decorrelation but external billing applies."* → records `sidecar_consent`.
- *"Allow automatic Sonnet→Opus floor-up on depth-heavy turns? Opus is ~3–5× the cost; declining keeps you at the Sonnet floor and asks per-occasion instead."* → records `floorup_consent`.

Settling this at onboarding is the **whole point**: the escalation is then *expected*, never a surprise
on the bill or the egress log.

### 2. Runtime ask-once (for anyone who skipped onboarding setup) — the graceful path

A user who skipped explicit setup is **not** auto-escalated. Instead, the **first time** an escalation
is actually needed:
- **Ask once**, at the moment of need, framed with the cost/trust reason:
  *"This turn needs Opus depth (higher cost) — proceed at Opus, or stay at Sonnet?"* /
  *"This load-bearing change is best verified cross-family (external billing) — recruit a sidecar, or verify with CC sub-agents only?"*
- **Accept** → record consent (UAP), proceed, no re-ask.
- **Decline** → record decline (UAP), **mark the escalation "recommended only"** going forward (surface
  it as a one-line recommendation when relevant, **never a re-nag**), and **proceed at the floor**
  (Sonnet / Tier-3 sub-agent).

The ask fires **once per axis**; the answer is remembered. A declined axis becomes a standing floor, not
a per-turn question.

---

## The declined mode is first-class, not "degraded"

When an axis is declined (or no sidecar is reachable), the fallback is **the user's chosen normal
operating mode**, and must be framed that way:

- **Cross-family declined → Tier-3 CC-only sub-agent verification.** Multiple **isolated** Claude
  sub-agents adversarially verify (isolation-decorrelation), with an **honest same-family note**
  ("no cross-family diversity — verification is isolation-decorrelated only"). This is intelligent
  operation, **not** "reduced value / degraded" language. (`[[feedback_judge_robustness_mechanical_anchor]]`
  still holds: the governor keeps the terminal verdict + a mechanical anchor.)
- **Floor-up declined → stay at Sonnet**, run the turn with good harness structure. No apology framing.

**Reframe rule**: the Sidecar Resolution Protocol's Tier-3 line and auto-decorrelation's degrade ladder
must not read "no diversity; reduced value" for a *declined* user — that pathologizes their choice.
Distinguish **declined** (chosen floor — first-class) from **unavailable-but-wanted** (genuine
degrade-with-note). Only the latter carries the degrade framing.

### Reconciliation with the corp fail-closed invariant

The pmh corp degrade-invariant (`local_pmh_context.md` auto-decorrelation Step 6) says a load-bearing
change with **no reachable cross-family panel → NOT-CONVERGED / ask operator**. That is the
**unavailable-but-expected** case (consent given, panel down). The **declined** case is different: the
user opted out, so Tier-3 sub-agent verification **is** the standing bar (with the honest same-family
note), and load-bearing changes proceed under it — not blocked. Membership: `floorup_consent`/
`sidecar_consent == declined` in the UAP routes to the first-class floor; absence of a *wanted* panel
routes to fail-closed.

---

## UAP persistence (behavioral pref — never domain content)

`operational_adaptation.md` UAP gains two fields:
- `sidecar_consent: accepted | declined | unset`
- `floorup_consent: accepted | declined | unset`

**READ** (session start / at point of need): `declined` → route to floor, surface as recommendation
only, no re-nag. `accepted` → escalation available (still per-need, no auto-run). `unset` → ask-once
on first need (runtime path above).
**WRITE**: on onboarding settle, or on the first runtime accept/decline.

Ephemeral/cloud sessions (UAP wiped) → operate from the **Sonnet floor + CC-only** default (the safe
floor), do not fabricate consent.

---

## Cost lens (why this IS the cost-governance mechanism)

The floor-up consent prompt is **the operator's cost lever made explicit** (measured: Sonnet-economized
≈ 34× subscription; Opus-full 40–60×, `cost_report_2026-07-07`). Default Sonnet floor + escalate-Opus-
**only-where-depth-pays**-with-consent is precisely "amortize Opus on the turns that earn it." Pair with
a **free internal-model execution lane** where the environment has one (`[[feedback_multimodel_3lane_architecture]]`)
to offload exec cost off the paid API entirely. The protocol turns hard-won economizing into a mechanical default.

---

## Done When

- **Both axes negotiated at onboarding** (install-wizard names sidecar + floor-up as consent items). *[mandatory-pass — grep install-wizard for both items]*
- **Runtime ask-once wired** for `unset` consent at first need; decline → recommend-only + floor, no re-nag. *[judged — pair: Sonnet target-tier blind sim of a skipped-onboarding session hitting first floor-up]*
- **UAP fields present + READ applied** (`sidecar_consent`, `floorup_consent`). *[mandatory-pass — grep operational_adaptation.md]*
- **Declined-mode reframed first-class** (no "degraded/reduced-value" language on a declined user's Tier-3 path). *[judged — pair: challenger reads auto-decorrelation + Sidecar Resolution for pathologizing language]*
- **Corp fail-closed reconciled** (declined ≠ unavailable-but-wanted). *[judged — pair: the target-tier sim above exercises both branches]*

## Guards

- **Human override inviolable** — a consent is a default, never a cap; the operator can always force a
  tier/sidecar for a given turn (`[[feedback_verify_before_downgrade]]` floor governance).
- **Never auto-switch the session model** — the floor-up ASK proposes; the human acts (`/model`). The
  protocol never flips the model itself.
- **Sonnet floor is a floor, not a ceiling** — declined-floor-up still escalates *within* Sonnet's
  harness depth (sub-agents, good structure); it does not cap capability, only cost/trust surface.

---

> **Canonical axiom cross-ref (2026-07-10)**: the "Sonnet floor is first-class, not degraded" stance
> this protocol operationalizes is now named — `sonnet_floor_doctrine.md` (base ops 100% Sonnet;
> tier-gated capability = defect; escalation = dispatch, consent-gated **here**). This file remains
> the consent mechanics home; the doctrine node does not restate them.

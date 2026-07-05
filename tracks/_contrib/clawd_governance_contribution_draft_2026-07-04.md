---
name: clawd-on-desk FH opt-in caution-layer contribution — DRAFT v2 (persona-audited, HITL-pending)
description: Opt-in caution layer proposal for clawd-on-desk — severity-tagged bubbles for irreversible ops + an auditability sketch for the deferred M2 remote-approval. Provider-humble, AGPL-aware. v2 = persona-audit revisions applied. NOT delivered — pending public-surface-audit + operator approval.
type: contribution-draft
date: 2026-07-04
status: DRAFT v2 — persona-audited (REVISE→applied 🟥🟧🟩), pre public-surface-audit, HITL-pending (NOT delivered)
tags: [clawd-on-desk, sister-asset, contribution, opt-in, m2-approval-auditability]
sister-audit: tracks/_audit/session_2026_07_04_clawd-on-desk-observability-governance-cross-audit.md
persona-audit: applied 2026-07-04 (3 personas × 4-axis; verdict REVISE; all tiers folded)
---

> **Status gate**: draft only. Before any delivery to the clawd channel it MUST pass (1) `public-surface-audit`
> (becomes external-facing), (2) operator approval (HITL). Persona audit done (v1→v2). Provider-humble; no
> restructure verbs; bidirectionality leads.

# Proposal: An Opt-In Caution Layer for clawd-on-desk

## Summary

clawd-on-desk already solves the hard, unglamorous part of agent supervision: it watches 15+ coding agents,
installs their lifecycle hooks, and surfaces each agent's *own* permission prompt as an ambient,
one-keystroke Allow/Deny bubble. That ambient-relay surface is genuinely excellent, and this proposal does
not touch it. What it offers instead is a small, **opt-in** layer that rides *on top of* the existing relay —
for teams who want a subset of those bubbles to carry a bit more weight. The idea comes from forge-harness
(FH), a Claude-Code-native harness that concentrates human attention on the few actions that can't be undone.
clawd relays the prompt; this layer would let a maintainer optionally tag the ones that are irreversible.
Everything below is a draft for discussion, disabled by default, and additive — nothing changes for users who
never flip the flag.

## Two concrete increments

**(a) Severity-tagged bubbles (opt-in, pattern-based, hot-path-safe).**
Today every relayed prompt renders as an equivalent bubble, so a `git push --force` and a file read compete
for the same reflexive Ctrl+Shift+Y. The increment: when a relayed action matches a small
**irreversible-action pattern list** (delete, publish, force-push, history-rewrite), the bubble *optionally*
gains a severity tag plus a one-line "why this is irreversible" note — e.g. *"force-push: rewrites remote
history; prior commits may become unrecoverable."* The human's Deny/Allow then becomes an informed decision
rather than a reflex. Design constraints kept deliberately tight: it is a **config flag** (default off), the
matching is **pure pattern/regex in the hot path** (no model call, no added latency to the ambient loop), and
it **fails toward caution** — if the pattern list can't load or a match is ambiguous, only the *tagged*
rendering is affected (the bubble shows "unverified" instead of a confident tag); **normal untagged bubbles
are never touched, so everyday use gains no friction.**

On upkeep — the honest concern with any pattern list is who maintains it as 15+ agents change their prompt
shapes. The offer: **FH ships the default list small and maintains it as a separate contribution**, so the
drift-maintenance doesn't land on you. Where the list lives (bundled default / user override / per-agent) is
genuinely your call; the point is the burden is ours, not yours.

**(b) An auditability sketch for the deferred M2 remote-approval.**
`docs/mobile-protocol-v1.md` explicitly defers remote approval/control to M2, pending "pairing, token
rotation/revocation, approval auditability." Since that's the area FH works in, here are a few things that may
be worth checking when you get to it — offered as design input, not a spec you now owe:

- One option: **log every remote approval** — who / when / what action / from which device — as an
  append-only record (stored wherever fits clawd's model; local-only is fine), so a phone-tap that allowed a
  destructive action is later accountable.
- **Pairing + token rotation/revocation** as first-class, so a lost phone can be cut off.
- A **fail-closed default** would mean an unknown, expired, or unrevocable token results in *deny*, never
  allow — because remote approval of an irreversible action is the highest-stakes path in the system, so its
  failure direction is the one place worth pinning closed.

The intent is to offer a few things worth checking if useful, not to scope the milestone — that's yours.

## Explicitly NOT proposed

- **No rebuild of what exists.** clawd's transport, WebSocket bridge, PWA, native mobile client, and pet UI
  all work and are AGPL-3.0; FH would not reimplement or fork them.
- **No mandated layer.** The tagging stays opt-in behind a flag; a maintainer who wants clawd to remain a
  pure relay loses nothing.
- **No heavy reasoning in the ambient hot path.** The ambient bubble stays fast and pattern-only. Anything
  heavier would be out-of-band and out of scope here — the ambient supervisor must not get slower.
- **No review burden on you** unless you flip the flag; and even then, FH carries the pattern-list upkeep.

## Bidirectionality — what FH would import from clawd

Leading with this, because it's the honest half, and making it concrete so it isn't just a courtesy line. FH
has the caution logic but no glanceable UI — its verdicts have historically lived in terminal output and
commit gates. clawd has exactly what FH lacks: an **ambient-observability UI pattern** (a floating,
one-keystroke approval surface that doesn't demand a context switch) and a proven **multi-agent hook-install
pattern** across 15+ heterogeneous agents. Concretely: FH would **write up clawd's hook-install and
ambient-bubble patterns in its public notes and link back** — crediting clawd as upstream on delivery — so the
import is a visible artifact, not an abstraction. The exchange runs both ways.

## Open questions for the maintainer

1. Is there appetite for an **optional** caution layer at all, or does keeping clawd a clean, unopinionated
   relay feel more true to the project's identity? Either answer is fine — it shapes whether (a) is worth
   drafting further.
2. What's the rough **M2 timeline / design state**? If the auditability thinking is already sketched, the
   notes in (b) should slot into it rather than pre-empt it — no rush intended.
3. Would a small, self-contained **proof-of-concept behind the flag** be useful — (a) as the smallest first
   step, or a sketch of (b)'s append-only approval log if M2 thinking is already active? Your call which is
   more useful.

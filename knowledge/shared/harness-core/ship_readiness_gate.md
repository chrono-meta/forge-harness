# Ship-Readiness Gate — Identity All-Green as the Release Condition

> **What this is**: the release gate for a harness (FH itself, or any field harness it incubates). A
> harness **ships** — and earns a **formal release tag** — only when the identities that define it are
> **all-green**: each proven REALIZED by a concrete track-record artifact (n≥1), not merely documented.
> This is the "품질보증서 (quality-assurance certificate)" the operator asked for: it certifies the
> harness does what its identity claims, with evidence, before it goes out. Origin: the 2026-07-14
> identity-fulfillment audit (`tracks/_meta/identity_audit_2026-07-14.md`).

## Why an identity gate, not a feature checklist
A harness is a means, not a feature list. Shipping it means promising it *does what its identity claims*.
A feature can be present yet the identity still be 이상론 (aspirational) — e.g. an incubator with a runner
but zero real emits. So the gate scores **identities by evidence**, and the honest states are:

| Status | Meaning | Bar |
|---|---|---|
| 🟢 GREEN | **REALIZED** | a concrete track-record artifact proves the identity fired for real, n≥1 (a real gate block, a measured probe, a real orchestration record) — *not* a doc that describes it |
| 🟡 YELLOW | **PARTIAL** | pieces work but no single closed track record (e.g. two half-pipelines that never connected end-to-end) |
| 🔴 RED | **이상론 (ideal-only)** | documented aspiration, never actually run; or the source itself says "not built yet / named target" |

**All-green rule**: ship + tag only when **every** identity is 🟢. A 🟡 or 🔴 blocks the tag — and names
exactly what real run is missing. The remedy for RED is never to relabel it green; it is to **run it and
leave the artifact** (the operator's standing rule: "이상론이면 실제로 돌려봐서 실적을 남겨야 한다").

## Dominance, not concession — the AlexNet bar
A harness earns the right to say "we compose with other harnesses" **only from proven dominance**, never
as a humble concession. The reference is AlexNet: on data it had never seen, it did not *participate* — it
**crushed every competitor**. That is the bar for a shippable identity: on unseen input, in a head-to-head
against the realistic alternative (a plain single-model session, a competing harness's flow), our harness
must **decisively win**, not merely tie or "also work."

The composition identity (멀티하네스 클러스터) is downstream of this: we equip *other* harnesses onto the
parts **we deliberately chose not to cover, or left general-purpose** — a decision made from strength, after
proving we would win the parts we do cover. Composing because we *can't* win is weakness wearing the costume
of humility; composing because we *choose* the frontier and hand the rest to specialists is dominance.

**The squirrel-and-equipment shape (operator, 2026-07-14)**: the squirrel (🐿️ FH) dons **specialized gear**
for a specific harness/project — micro-work can't be done barehanded, and the gear (a field/domain harness)
makes it easier and more specialized. But **the squirrel itself must be an all-rounder master** at the one
thing it does everywhere: *creating and accelerating harnesses*. The mastery is the squirrel (general,
must-dominate — the governance/quality/harness-craft); the specialization is the equipment (per-domain,
composed-in). You never concede the craft; you equip for the domain. So the dominance bar applies to the
**craft** (does FH out-govern / out-build any alternative on unseen ground?), and composition applies to the
**gear** (which specialist harness to bolt on for this domain's micro-work).

**First dominance result (governance craft, 2026-07-14)** — `tracks/_meta/dominance_benchmark_2026-07-14.md`.
Model held fixed at the Sonnet floor; only the harness *method* varied. On unseen gate code with planted
fail-open holes: FH's degrade-direction method **5/5 (100%, 0 false-positive)** vs a plain no-lens review
**3/5 (1 missed fail-open + 1 false-alarm on correct code)**. The harness took the same floor-tier model from
60%→100% — dominance isolated as *method*, not model. Honest scope: obvious fail-opens are caught by both;
the harness's decisive win is concentrated on the **subtle** hole (attention held on the degrade direction)
and on **not crying wolf** on correct fail-closed code. A true AlexNet-scale blowout needs subtler holes —
which is exactly the diagnostic direction (where the gap does NOT yet widen tells us where to sharpen).

**Gate consequence**: each 🟢 identity should carry not just an existence artifact (n≥1) but, where a
competitor exists, a **dominance result** — a measured head-to-head where our harness catches / completes /
survives what the alternative misses. The governance identity already has one (blind cross-family: FH's gate
the *only* thing that caught the irreversibility/safety class; competitors HITL 8/8 ABSENT). The others owe
theirs. A dominance benchmark is also *diagnostic*: where we do NOT yet dominate tells us exactly where to go
next (the operator: "압도성을 결과로 봐야 앞으로 나아갈 방향을 안다").

## The gate is the audit method (reusable)
Score with the same triangulation the 2026-07-14 audit used — no single-source self-attestation:
1. **Cross-family falsifiable checklist** — draft the per-identity PASS criteria with ≥2 decorrelated
   models (e.g. Fable higher-tier + Codex cross-family); they must converge on the load-bearing checks.
2. **Origin-grounding** — for each identity, quote its *original intent* from the accumulated record
   (memory / tracks / companion store) and find the artifact that proves it fired (or prove none exists).
3. **Blind floor-tier probe** — for any identity whose value is "intent-based autonomous completion"
   (a user gets the value by intent, without naming the skill), *measure* it: blind Sonnet sessions given
   novice-vocabulary intents, scored on whether the right skill/gate fires. Salience-only ≠ measured.

## Versioning policy — the formal release track
The formal release tag is **independent of the npm package version**. The npm version (currently in the
`1.4.x` range) is the **plugin-cache lockstep number** — it bumps on every shipped-asset change so Codex/
marketplace cache-invalidate; it is not a maturity claim. The **formal identity-maturity release starts at
`v0.1.0`** and advances only when the ship-readiness gate goes all-green. `v0.1.0` = "the first release
whose every identity is proven, not aspirational." Do not conflate the two counters; a high npm number does
not make the harness `v1.0`.

## FH's own status (2026-07-14) — NOT yet all-green

| # | Identity | Status | Evidence / what's missing |
|---|---|---|---|
| ③ | 거버넌스 게이트 (governance) | 🟢 GREEN | pre-commit/pre-push physically block; moat measured 3–4 family blind (HITL 8/8 ABSENT); cross-family caught a real companion-store-name leak 2026-07-14 (fail-closed) |
| ⑤ | 증폭자 (amplifier) | 🟢 GREEN | short-intent→literature-grounding→ultimate-doc real instances; rules-diet −18.2k measured; intent-routing probe 94% (below) |
| ④ | 프런티어→조직 전파 | 🟡 YELLOW | frontier-digest launchd auto + AX submission docs both real, but digest→org never closed as ONE pipeline |
| ① | 멀티하네스 클러스터 (연속경유) | 🔴 RED | mapping/routing materials work, but continuous relay channel + external-harness recommend are "not built yet" (source-admitted); cluster-wizard parked |
| ② | 프로젝트 인큐베이터 (챔버 EMIT) | 🔴 RED | chamber ran 3×, but **EMIT 0× (2/2 KILL)** — the chamber *screens*, has not *birthed*. Runner wired, autonomous emit is not |

**Cross-cutting measured (intent-based autonomous completion)**: blind floor-tier Sonnet trigger-accuracy
probe (n=10, 2026-07-14): **should-fire 7.5/8 (94%), false-fire 0/2**. One weak trigger (simulate-first /
incubator entry absorbed into deep-clarify) — the identity-② weakness surfaces in routing too.

**Verdict**: FH is **not shippable as v0.1.0 yet** — ①② are RED, ④ is YELLOW. The formal `v0.1.0` tag is
reserved for the moment all five go 🟢. What's blocking is **real runs, not wiring**: ①'s live 2-node
orchestration, ②'s first EMIT-worthy chamber run, ④'s closed digest→org pipeline. Each remedy is a run
that leaves an artifact, tracked in `tracks/_meta/identity_audit_*.md`.

## For a field harness (e.g. pmh, qasp)
Same gate, its own identities. A field harness ships to its team when its identity checklist is all-green,
certified by a **실증상세 (demonstration-detail) doc in that harness's own repo** — the QA certificate
listing each identity, its PASS criterion, and the artifact proving it. FH≡field parity: what FH proves
about itself, a field harness proves about itself, by the same method. (Company-residency: a field
harness's 실증상세 lives in its own private repo; FH holds only the method, never the field's evidence.)

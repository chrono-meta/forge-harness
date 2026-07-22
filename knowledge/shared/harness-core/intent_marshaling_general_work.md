# Intent Marshaling — General-Work Serving (runtime twin of intent machinization)

> **Status**: doctrine (judgment-shaped, operator-forged 2026-07-22). Companion:
> `harness_incubator_doctrine.md` covers **forge time** (`intent → forge → agreement → machinery`);
> this file covers **run time** — what a mapped, skill-equipped environment does with a plain work
> request. Floor companion: `sonnet_floor_doctrine.md`.

## 1. Doctrine statement

At forge time a harness machinizes intent into new machinery. At **run time**, an environment with
installed skills, agents, mapped harnesses, and persistent memory is a **purpose organization**: the
leader states a work intent in plain language, and the session **marshals installed capability into a
composition and executes** — without the leader naming skills, agents, or files.

**Scope is general work, not only harness work.** Wiki/document production, research-and-write,
review, organizing, data shaping — any work-shaped request is in-scope. The environment moat is the
point: a capability registry + mapped harnesses + memory exist *here*, so a plain chatbot session
cannot marshal what it does not have. Serving general work is therefore **identity, not a favor** —
"this is a harness hub, not for wiki work" is a forbidden deflection.

## 2. Why doctrine, not mood (origin defect)

2026-07-21: a session marshaled sim/persona skills onto wiki-polishing work "by feel" and the effect
was large. That was orchestrator taste — the same failure shape lens selection had before the
Author-Exposure Table (PR #158: picked right 4/4, but by judgment-luck, not machine). Taste survives
only on strong tiers and good days; a Sonnet-tier session with the same assets would serve the same
request thinly and call it done. This doctrine converts the marshal decision from taste into a
mechanical default that survives at the Sonnet floor.

## 3. The marshaling loop (every step Sonnet-runnable)

| Step | Action | Mechanical form |
|---|---|---|
| **1 Intent read** | Restate the request as *deliverable + doneness* in one line. Genuinely ambiguous → the existing `/deep-clarify` route, not guessing. | one sentence, embedded in the compose proposal |
| **2 Capability scan** | Scan what is actually installed/mapped — never recall from memory: ① in-session skill list (description match) ② `LOCAL_SKILL_REGISTRY` / Cross-Project Skill Bus ③ the target project's mapped harness assets. **The scan carries each hit's trust tier with it** (FH-native · non-FH sibling `ask-tier` · external) — trust is scan output, not a later afterthought. | list/grep, not vibes |
| **3 Compose & run** | One-line composition proposal ("draft via X, then Y as the quality gate"), then **run-first, ask-last** — for **FH-native / session-installed capability whose actions are reversible**. A **non-FH sibling registry hit keeps its registry trust tier**: `ask-tier` = propose-only, never auto-run (`fh_detail_protocols.md` 1-c — sibling code is an injection surface). **Reversibility is judged per action, not per skill**: an installed skill whose step sends/posts/deploys/deletes outward hits that action's own gate (`mcp_tool_gating.md` ask-tier · the irreversibility gates) — marshaling never upgrades an ask-tier action to autonomous. | the one-liner IS the HITL surface for reversible work |
| **4 Gap → ladder** | Gap may be declared **only by citing the Step-2 scan result** ("scanned ①②③, nothing covers X") — never a bare "nothing fits"; a gap claim without a named scan is the under-serve degrade direction this doctrine exists to close. Then reuse the goal-quench Phase 1.5 Step C **ladder semantics** (order + trust-gating + degrade direction — NOT its max-mode `fit_score` trigger, which stays goal-quench-local): internal registry scan → external search (`plugin-recommender`) → **in-session synthesis** from existing meta-skills (composition, not persisted) → net-new skill only as last resort. | same ladder order, no new machinery |
| **5 Exposure check** | Deliverable is material (published · carries external claims · others rely on it) → the Author-Exposure Table (`agent-composer` §Author-Exposure) names the review pass before "done". | existing gate, unchanged |

## 4. Gates — reused, none new

| Surface | Gate |
|---|---|
| Scan · compose · run **FH-native** installed capability, **per-action reversible** | **none** — autonomous, one-line notice |
| Dispatching a **non-FH sibling/registry skill** | its **registry trust tier** — `ask-tier` = propose-only, never auto-run (injection surface) |
| An action that mutates **outward** (send · post · deploy · delete · payment — even via an installed skill) | that action's own gate (`mcp_tool_gating.md` ask-tier · irreversibility gates) — never converted to autonomous by marshaling |
| External plugin/skill **install** | `plugin-recommender`'s own install-HITL (environment mutation) |
| **Persisting** a synthesized skill | New-Skill Pre-Commit Gate + `asset-placement-gate` (ephemeral in-session composition needs neither) |
| Irreversible surfaces (publish · delete · heavy autonomous fleet) | existing gates unchanged (Pre-Publish · Destructive-Op · the goal-quench proposal row) |

## 5. Boundaries

- **Not a heavy-orchestration auto-runner**: a run that would spawn a large multi-agent fleet still
  proposes `/goal-quench` first (existing row). Marshaling defaults to the **cheapest composition
  that serves the intent** — one skill beats three when one suffices.
- **Sonnet floor**: every loop step is list/grep/one-liner/run — no depth-gated judgment on the
  critical path. Depth escalation is dispatch (consent-gated), never substrate.
- **Company residency unchanged** — marshaling never widens what may leave the machine.
- **Operator-taste default**: tuning targets the operator's convenience (operator, 2026-07-22: "if
  it's convenient for me, that's sufficient" — FH/PMH distributes *how the operator works well*).
  Per-user adaptation is the UAP's layer, not this file's.
- **Honesty**: marshaling quality is bounded by what is actually installed — a thin environment
  marshals thin. The scan reports what it found; it never inflates the roster.

## Done When (adoption, measured)

- A general work request in a mapped environment produces a one-line composition proposal grounded in
  an actual capability scan (check class: **measured** — target-tier sim at Sonnet, known-pair: one
  work-shaped positive must marshal, one trivial/out-of-scope negative must NOT add ceremony).
- No new gate machinery introduced; the mutation points (install · persist · non-FH dispatch ·
  outward actions) route to existing gates (check class: **mandatory-pass** — grep this file for gate
  names, confirm all resolve to pre-existing assets).
- Trust tiers survive marshaling: no path in this file lets a non-FH `ask-tier` hit or an outward
  action run without its own gate (check class: **mandatory-pass** — cross-family verified 2026-07-22,
  codex F1/F2 closed).

# Harness Design-Decision Lens

> A complement to `harness_6axis_framework.md`. The 6-axis framework is a **lifecycle** decomposition —
> it answers *when, in the flow of a piece of work*, each concern applies (structure → context → plan →
> execute → verify → improve). This lens is **orthogonal**: it answers *which architectural bet to place*
> at Axis 1 (Structure) and Axis 4 (Execute), where the 6-axis tree says "route it" but not "which design
> point." Use the two together — the 6-axis says *which stage*; this lens says *which trade-off setting*.
>
> **Open this doc when** you are about to add agents, tools, permissions, or harness thickness — or when
> the 6-axis tree says "route it" (Axis 1 / Axis 4) but not *which way*. For lifecycle questions (what
> stage am I in, what must I verify), stay in the 6-axis framework.

**Provenance (independent-convergence harvest — not clone-and-own):** the decision-table framing was
harvested from the sister asset `wikidocs.net/book/19689` 「하네스 엔지니어링 백과사전」 Ch12 (governor
source-closed 2026-06-14; cross-audit `tracks/_audit/session_2026_06_14_wikidocs-deep-sweep.md`). **The
single net-new increment from the harvest is the orthogonal-bets *framing* itself** — presenting harness
architecture as ~7 trade-off axes set against the 6-axis lifecycle. The governor source-close ruled the
individual decisions, the contrarian checklist, and the scaffolding-removal method **ALREADY-HAVE** (FH
embodies them — see column 3 and the `measured`/judged check classes). They are reproduced below only to
make the already-placed bets *explicit and operational in one place*, not as novel imports. Where this
doc restates an existing FH principle, it says so.

---

## The seven decisions (architectural bets)

Each is a spectrum, not a right answer. The third column names the FH asset that already embodies the
bet — so this is a *map of bets FH is already placing*, made explicit, plus the two FH was placing only
implicitly (agent-count, reasoning-strategy).

| Decision | Spectrum | Where FH already places the bet | "Which point, when" |
|---|---|---|---|
| **Agent count** | single ↔ multi-agent | `agent-composer` (single vs parallel dispatch) | Single by default; split only on genuinely independent sub-tasks (agent-composer's per-wave fan-out cap, ≤4). Isolation cost rises with agent count. |
| **Reasoning strategy** | ReAct (think each step) ↔ plan-then-execute | 6-axis Axis 3 (Plan) → Axis 4 (Execute); `goal-quench` decomposition | Plan-then-execute for parallelizable / known work; ReAct for genuinely exploratory steps. |
| **Context strategy** | strong compression ↔ rich context | `context-doctor`, compact-before-saturation reflex, layered memory (MEMORY.md index / `memory/*.md` keyword-load / `tracks/` archive) | Compress on long sessions; keep rich context where verification needs the evidence intact (phantom-quench tension). |
| **Verification** | computational ↔ judged | check-class taxonomy: mandatory-pass / measured / **judged** (`harness_6axis_framework.md` Axis 5) | Prefer computational anchors; a judged verdict never passes alone (judge-robustness rule). |
| **Permissions** | permissive ↔ restrictive | `mcp_tool_gating` allow / ask / deny; Destructive-Op + Pre-Publish gates | Restrictive on irreversible / external-facing actions; permissive on reversible local work. |
| **Tool scope** | all tools always ↔ staged minimal | ToolSearch (deferred-tool fetch), `mcp_tool_gating` | Stage tools in; broad always-on exposure degrades selection accuracy. (Vercel measured 17 specialized tools → 80% success vs 2 general-purpose tools → 100%, at lower token + latency: "We removed 80% of our agent's tools", vercel.com/blog/we-removed-80-percent-of-our-agents-tools, accessed 2026-06-14.) |
| **Harness thickness** | thin (trust model) ↔ thick (control by code/rules) | field principle "simpler over time" vs meta principle "complexity earns its scope" (`harness_6axis_framework.md` Core principle) | FH already holds a *more nuanced* field-vs-meta split than a single thin/thick dial. Thicker buys predictability but encodes "things the model can't do" — assumptions that age as the model improves (design intuition, not a benchmarked claim). |

The decisions are **not independent**: more agents raises the cost of context isolation + verification;
always-on tools raises the stakes of permission design; a thicker harness raises the carrying cost of
stale assumptions.

**Orthogonality is partial, not total.** Two of the seven bets — *reasoning strategy* and *verification* —
are placed *at* a 6-axis stage (Axis 3→4 for reasoning, Axis 5 for verification), so for those the lens
and the lifecycle touch rather than run perpendicular. The lens is still the right tool for "which setting"
(plan-vs-ReAct, computational-vs-judged); the 6-axis is the right tool for "at which stage." The orthogonal
claim holds strongly for the other five bets and loosely for these two.

---

## Default-bias checklist (the contrarian inversions)

> *Already-embodied (governor: ALREADY-HAVE) — restated here as a one-place design-time pass, not a novel
> import. FH already runs these instincts through `steel-quench` and the meta-harness red-flag scan.*

Four intuitions that feel right while building and fail in operation. Run this as a quick adversarial
pass on any harness design (it is the design-time analogue of `steel-quench`'s attack lenses):

1. **"More tools = more capable."** Often false — broad tool exposure hurts selection accuracy. Prefer
   staged, single-purpose tools over a wide general surface.
2. **"Reason at every step (ReAct always)."** Often false — for parallelizable / known work,
   plan-then-execute is faster and cheaper.
3. **"Broader permissions = faster."** False under operations — the cost lands as irreversible mistakes,
   not saved time. Gate the irreversible.
4. **"Thicker harness = safer."** True short-term, debt long-term — a thick harness encodes "things the
   model can't do," and those assumptions age. Safety that does not get revisited becomes a burden.

---

## Scaffolding-removal method (operationalizes "simpler over time")

> *The principle is already FH's (governor: ALREADY-HAVE — 6-axis core principle). What is operationalized
> here is the **method** the principle left unstated, consistent with FH's `measured` check class.*

FH's core principle states the *goal* — "a good harness gets simpler over time" — but not the *method*.
A testable one, consistent with FH's verification identity:

> **Remove scaffolding one piece at a time, and compare.** When simplifying, ablate a single support at a
> time and check what actually holds quality before removing the next. Removing several at once loses the
> signal of which support was load-bearing.

This is the disciplined form of the meta-harness red-flag scan (orphaned / redundant / decorative units):
do not bulk-delete suspected-decorative structure — ablate-one, measure, then proceed. It pairs with the
`measured` check class (the comparison is the measurement).

---

## How it plugs into the 6-axis flow

- **Axis 1 (Structure)** — when deciding where work lives and how it is shaped, consult the seven
  decisions for the architectural bet, and the default-bias checklist before committing to "more"
  (agents, tools, permissions, thickness).
- **Axis 4 (Execute)** — the agent-count and reasoning-strategy decisions set the dispatch shape
  (direct / single agent / parallel) the 6-axis tree otherwise leaves to habit.
- **Axis 6 (Improve)** — apply the scaffolding-removal method when the simplification principle fires.

**Check class:** this doc is a *judged* design aid (it informs human/AI design choices, it does not gate
mechanically). Its adversarial pairing is the default-bias checklist above + `steel-quench` on any design
it informs — no judge-only path.

---

## Related
- `harness_6axis_framework.md` — the lifecycle framework this lens complements (Core principle: thickness; Axis 5: check-class taxonomy)
- `tracks/_audit/session_2026_06_14_wikidocs-deep-sweep.md` — the governor-closed cross-audit this harvest came from
- `knowledge/shared/rules/auto_project_mapping.md` — Full-Harness Mode, where thickness/permission bets are placed per project

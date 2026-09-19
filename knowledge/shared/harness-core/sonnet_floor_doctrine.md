# Sonnet-Floor Doctrine — the harness's optimization target

> **Canonical axiom node** (operator-declared 2026-07-10). Short by design: this file names the
> invariant, its defect class, and the prescription ladder. The operating mechanics live in their
> existing homes — floor resolution & dispatch: `multi_model_sidecar_strategy.md §Tier-floor`
> (F1/F2, "Sonnet-main + Opus-dispatch"); escalation consent: `capability_escalation_consent.md`;
> mechanical enforcement: `templates/.git-hooks/pre-commit` (Axis-2 floor fields) +
> `scripts/below_floor_scan.sh`. Do not restate their details here; do not restate this axiom there.

## The invariant

**FH's base operation must run 100% at Sonnet-tier.** Every gate, onboarding path, diagnostic,
close-chain step, and skill must fire and complete on Sonnet 5. A capability that is only
discoverable, or only fires, on Opus/Fable-tier is a **harness defect** — the same severity class
as a phantom reference. A harness exists to hold quality high *on weaker models*; if it needs the
strongest model to work at all, it has failed as a harness.

**Escalation is dispatch, never substrate.** Depth beyond Sonnet's ceiling is reached by
*recommending* a dispatch — an Opus/Fable same-family sub-agent, or a cross-family sidecar
(codex / agy) — consent-gated per `capability_escalation_consent.md`. The session substrate stays
whatever the operator chose. A Sonnet-only environment is a **first-class mode**: run everything at
Sonnet, extract the harness's maximum, and name residuals honestly (below-floor / sonnet-floor
markers) — never silently drop a capability.

## The minimum-spec formulation (operator, 2026-09-19)

> *"꼭 모두 기계화를 해야하는것은 아니지만 최소환경에서도 모두 돌아갈수있게 보장하는것이 중요하다.
> 게임의 최소사양에서도 게임자체의 화질이나 디테일은 떨어지더라도 모든 기능이 정상작동하는것처럼.
> 모델의 티어가 높아질수록 모든 기능에 가속도와 스스로 할수있는(안정적으로 돌아가면서도 자신의
> 천장까지 도달가능한) 영역이 확장되는거지."*

This sharpens the invariant above in two ways it did not previously state.

**① At minimum spec, EVERY feature runs — fidelity degrades, capability does not.** A game at its
minimum spec is not a smaller game with levels removed; it is the same game at lower resolution.
So the floor question is never *"which features does Sonnet get?"* — it is *"does every feature
run, more coarsely?"* A feature that is absent at the floor is a defect; a feature that is
**slower, shallower, or less polished** at the floor is the design working.

🟥 **This also bounds the mechanization reflex, and the operator bounded it first**: *"꼭 모두
기계화를 해야하는것은 아니지만."* The obligation is **guaranteed operation at minimum spec**, not
total mechanization. A hook, a script and a discipline are all acceptable answers — what is not
acceptable is an answer that only works because a strong model was carrying it. Mechanization is
one way to reach the floor and is preferred where the trigger is mechanical (§Mechanization
Boundary decides which), but it is a means here, not the target.

**② Above the floor, a tier buys acceleration AND a higher reachable ceiling.** The gain is not
"more features unlock" — it is (a) everything goes faster, and (b) the band the session can carry
**by itself** widens: *"안정적으로 돌아가면서도 자신의 천장까지 도달가능한"*. Two conditions, and the
first is load-bearing — a tier that reaches further but unreliably has not widened anything.
⇒ When a stronger tier is in use, the honest report is *"this ran faster and I carried more of it
alone"*, never *"this was only possible here"*. The second sentence, if true, names a floor defect.

**Worked example, same day.** The operator's prescription «체크리스트를 테스트 한 차례 끝날 때마다
들여다봐라» could have shipped as a resident prose rule. At the floor that is a rule a session must
remember mid-run — exactly the muscle-not-skeleton shape. It shipped instead as a `SubagentStop`
hook + `session_checklist.py unblocked`: **no model in the loop** (stdlib only, zero network, zero
model calls — verified by scan), so it fires identically at every tier. What a higher tier adds is
what it *does* with the surfaced rows, not whether they surface.

### The floor is the smallest runtime we actually run — and there, the limit is CONTEXT

Operator, same day: *"우리는 qwen3.8도 있으니까 그것이 클로드 라우터 환경에서 클로드 컴패티블로
돌아갈때도 보장할 수 있는 (우리하네스의 설계의도와 철학. 루프 등)을 물리적 한계치 안에서
돌아갈수있도록도 해야지(물론그로인해 컴팩션이 자주일어날수야있겠지만)."*

🟥 **This moves the floor.** "Sonnet-floor" names a *tier*; the operator names a *physical envelope* —
a smaller open model served through a Claude-compatible router. There the binding constraint is not
reasoning depth, it is **context size**, and its symptom is named in the same breath: compaction
happens often. So at the true floor the question changes shape:

> Not *"can it follow the rule?"* but **"does the rule survive the compaction that will certainly happen?"**

A rule that lives only in the running conversation is, at that envelope, a rule with a half-life. What
survives is what is **re-established from disk on the other side of a compaction**: resident CLAUDE.md,
hooks that fire on events rather than on memory, files a session re-reads, and loops whose state is on
disk rather than in the transcript.

**This is reachable, not aspirational — the machinery is already live.** `scripts/compaction_probe.sh`
(588 lines) seals a pointer ledger at compaction and re-injects it afterwards, wired through
`templates/settings.Compaction.snippet.json`. Measured 2026-09-19: **65 seals on disk**, two of them
written during that day's own session and re-read after both compactions. 🟥 A first count in that
same session read **0** — `ls | wc -l` on a live directory — and was corrected only by counting the
channel before asserting absence (§Instrument Calibration; `not found` is not `0`).

**What this asks of every new asset**, therefore, is one extra question beyond tier-independence:
*where does this live when the conversation is gone?* A prose rule answers "nowhere". A hook, a
script, a file the session re-reads on wake, or a ledger entry answers it concretely.

🟥 **Honest scope.** No harness asset has been run under a Qwen-class router in this project —
**zero measurements**. What is established is the design property (disk-resident survives compaction)
and that the compaction channel fires here. Whether a Claude-compatible router preserves hook
semantics, system-prompt budget, or tool-call fidelity is **UNMEASURED**, and the first honest step is
a known-pair on that runtime, not a claim about it.

## Why this is the optimization target (measured, not aspirational)

- **H1 (2026-07-05)**: the anchor-emit harness reduced borderline verdict flips **more on weaker
  models** — Flash −18.5pp vs Pro −11.1pp (within-model deltas, 3-measurement convergence). The
  harness's value peaks exactly where the model is weakest; optimizing FH for the strong tier
  optimizes it where it matters least.
- **Every confirmed Sonnet-tier miss in FH history was closed by mechanization or salience
  hardening, never by requiring a stronger model**: the task-first companion-load miss (2026-07-05
  → SessionStart hook), the tone salience gap (2026-07-08 → recorded, prompt-layer), the
  card-reconcile blind spot (2026-07-10 → mtime-independent STATUS map in the hook). The doctrine
  is a name for what the fix pattern already was.
- **The value does not vanish at the top tier — the harness complements the strongest model too**
  (operator observation, 2026-07-10, same-day measured): a Sonnet blind probe caught a SIGPIPE
  silent-death defect in a script the top-tier session had just written (5/5 repro), and the new
  close-chain checker blocked that same top-tier session's card-last violation twice on its first
  day. Structure-enforcing checks are tier-blind by construction — so the harness raises the floor
  for weak models *and* guards the ceiling for strong ones. Weak-model benefit is the larger term
  (H1), top-tier benefit is the existence proof that the harness is not scaffolding-only.
- **External academic grounding (arXiv:2605.30621, "Harness Updating Is Not Harness Benefit,"
  May 2026 — surfaced via issue #102 Frontier Digest, 2026-08-15)**: the paper separates the
  *evolver* role (writes harness updates) from the *beneficiary* role (runs on the updated
  harness) and finds harness-**updating** flat across model capability — a Qwen3.5-9B evolver
  induces gains comparable to a Claude Opus 4.6 evolver, i.e. evolver strength does not predict
  beneficiary gain. Harness-**benefit**, by contrast, is non-monotonic — and the shape matters, so
  all three tiers are quoted rather than only the one that suits this section: **weak-tier models
  benefit little, mid-tier benefit most, and strong-tier benefit *less* than mid-tier.** The paper
  traces the weak-tier shortfall to two named failure modes: failing to *activate* relevant harness
  artifacts, or activating them but failing to *follow* them faithfully. This is independent
  grounding for the floor split below: sub-Sonnet stays `below-floor` because
  activation/faithful-following is where payoff collapses, while Sonnet is named the floor
  precisely because it clears that bar. ⚠️ **The strong-tier half is NOT folded in as support for
  the ceiling-guard clause above** — the paper measures benefit from *self-evolved harness updates*,
  not from structure-enforcing checks, so mid > strong is an adjacent finding this doctrine has not
  reconciled, and is recorded as open rather than read in the author-favorable direction.

## The defect class: tier-gated capability

When auditing (harness-doctor, weekly audit, or a dedicated census), enumerate candidates with
`bash scripts/tier_census_grep.sh <files>` (word-boundary patterns + N/A-sense hints — mechanized
2026-07-10 after a probe's naive grep false-positived on "fron**tier**"), then classify every hit:

| Class | Shape | Verdict |
|---|---|---|
| **Trust-floor** | a *judgment* (skip/run, compose/rank) is trusted only at opus+; below-floor = run the check anyway or ask | **Compatible** — Sonnet still runs everything; degrade direction is run-or-ask, never skip |
| **Availability-gate** | a capability is *absent, blocked, or dead-ended* below a tier (hard `model:` pin, "cannot pass", opus-only judge path) | **Defect** — fix via the ladder below |
| **Advisory** | recommends a tier, never blocks (Mode D Model Notice, depth-escalation notices) | Compatible — but the recommendation direction must be **dispatch-first** (keep Sonnet + dispatch the depth), with a session pin as the secondary option |

## Prescription ladder (for a confirmed tier-gated capability)

1. **Mechanize** — move the behavior to a hook / script / exit code. Tier-independent by
   construction; the strongest fix. (SessionStart load, STATUS map, pre-commit gate.)
2. **Salience-harden** — split, imperative pointers, turn-0 injection; then verify with a
   **Sonnet blind sim** (the target-tier sim gate's default tier *is* Sonnet for this reason).
3. **Reclassify as dispatch** — if the capability is irreducibly judgment-heavy (adversarial
   depth, wide design synthesis), it becomes a *dispatch surface*: at Sonnet the harness surfaces
   a one-line escalation recommendation (sidecar or floor-up, consent-gated) and proceeds at the
   floor with a named residual. Silent absence is never an option.

## Floor semantics under the doctrine

- **Sonnet = the base floor.** Meeting it is `at-floor` for base operation. Judged-class verdicts
  produced at Sonnet on depth-critical roles remain **provisional** (`sonnet-floor` marker,
  auto-queued for the weekly audit's re-run-or-write-off pass) — first-class ≠ free of residuals.
- **Sub-Sonnet (Haiku, local canaries)** stays `below-floor`: canary/producer roles only, explicit
  ack required on gate surfaces. The doctrine raises no ceiling and lowers no guard rails there.
- **Depth ladder on a depth turn at Sonnet** (cheapest rung first — effort is depth, model is
  ceiling, `[[feedback_workflow_stage_effort_routing]]`): ① **raise reasoning effort on the same
  substrate** (Sonnet medium → high — free, no consent needed, no boundary crossed) → ② dispatch
  an audit/research sidecar (consent permitting — cross-family preferred for decorrelation) →
  ③ proceed at Sonnet-high with mechanical anchors + named residual. A hard model requirement is
  never a rung.

## Autonomy at Sonnet — run-first, ask-last (full-potential clause, 2026-07-10)

The intended FH surface — including its **full autonomous potential** (goal-quench max runs,
harvest-loop full mode, overnight loops, cluster orchestration) — must be *executable* at
Sonnet medium-high effort, not merely available-if-a-human-answers. Two rules make that safe:

- **Trust-floor degrade order is RUN → ASK, never ask-first**: where a judgment is trusted at
  opus+ ("skip/run", "compose/rank"), a Sonnet session's default is to **run the full check /
  present the full result** — the conservative branch that needs no trust. Asking is reserved for
  the case where no mechanical or anchored path exists at all (a pure-judged fork with no anchor).
  A Sonnet loop that stalls on "ask" when running-the-check was available has mis-degraded.
- **The defense is the gate layer, not the model tier**: FH's mechanical floors — pre-commit
  4-axis, pre-push Destructive-Op, prepublish scan, consent protocol, HITL irreversibility floors —
  are tier-independent hooks. They hold *regardless of who is driving*, which is precisely what
  makes Sonnet full-autonomy safe: **autonomy removes the prompt, never the gate** (the same
  clause the Autopilot's full-autonomy mode already carries). Irreversible-surface HITL floors are
  surface-class rules and do not scale down with tier — a Sonnet loop gets the same hard walls,
  not softer ones.

## What survives model evolution — the durable-mechanization criterion (operator insight, 2026-07-10)

Sidecar dispatch is the *cheap* way to chase LLM evolution (swap the engine, keep the harness), and
internal mechanization could chase capability gaps forever — so which mechanization is worth
building? Split by **what the mechanization compensates for**:

| Class | Compensates for | Fate as models improve | Examples |
|---|---|---|---|
| **Capability-compensating** | the model being *weak* — reasoning depth, salience, attention discipline | **evaporates** — scaffolding to shed (`[[feedback_frontier_substrate_self_adaptation]]`); build only on measured misses, keep cheap to delete | salience splits · turn-0 imperatives · word-boundary grep discipline (partially — see note) |
| **Structure-enforcing** | what a *perfect* model still cannot see or is still incentivized to fumble: information outside the context boundary (cross-machine state, version drift), ordering invariants across ephemeral contexts, ship-pressure optimism, irreversible surfaces | **permanent** — model evolution never fixes "the card lives on another machine" or "the runner controls what the hook sees" | STATUS map (machine boundary) · card-last check (ordering invariant) · substrate-jump detector (out-of-context drift) · fail-closed gates · consent floors |

**The test question when proposing mechanization: "would an infinitely strong model still miss
this?"** Yes → structure-enforcing, build it, it compounds. No → capability-compensating, prefer
dispatch first, mechanize only on a measured miss, and tag it shed-eligible (the substrate loop's
shed/advance pass is its consumer).

*Note on determinism*: some capability-class tools survive anyway because they are **cheaper and
deterministic** (a grep never has an attention lapse and costs nothing) — determinism is a second
survival axis, orthogonal to capability. A deterministic check that replaces a per-session judged
step keeps paying even when the model no longer needs the help.

## What a harness sells — ceiling-extraction, not ceiling-raising (operator formulation, 2026-09-13)

**Operator, verbatim**: *"하네스란 각 모델들의 한계치를 뛰어넘는 게 아니라 각 모델들을 안정적으로
한계치까지 뽑아내는 거라고 생각해. … 하네스의 능력을 넘어서는 근육형 짓기야 오퍼스나 페이블이 더
잘하겠지만, 그게 아닌 하네스 활용형 단계에서는 이게 잘 돌아가야겠지."*

This names the **value proposition** the floor exists to protect, and it is not the same statement as
the floor itself. The floor says *where* base ops must run; this says *what the harness is selling*:

| | claim | who does it better |
|---|---|---|
| **근육형 (raw build)** | exceed what the substrate can produce | a stronger model — Opus, Fable. **Explicitly out of the harness's claim.** |
| **활용형 (harness-mediated)** | reach the substrate's own ceiling, **stably, every run** | the harness. This is the whole claim. |

Two consequences that were not previously written down:

**① Variance, not mean, is the quantity.** If the sale is "reach the ceiling reliably", then the
metric is **dispersion across runs of the same design**, not average yield. A pipeline whose mean
output is higher but whose run-to-run spread exceeds the effect has not delivered this — it has
delivered a lottery with a better expected value, which is a different product.
🟥 **Measured instance, and it is ours**: in the dominance-B2 study two runs of the same design
scored **15/24 and 20/24** while the effect under test contributed **3 and 2**. The spread was
larger than the effect. That study's primary metric was yield; under this formulation it should
have been spread. (Detail: `tracks/_meta/dominance_B2/PAPER2_DRAFT_2026-09-12.md` §3.1 · §9.2.)

**② Floor-tier operation is a PORTABILITY TEST, not only an accessibility floor.**

🟥 **And the substrate swap is not hypothetical — it is in production** (operator, 2026-09-13).
A gateway-served model (glm-5.3-flash) is routed into a Claude Code shell via the org's CLI, and
the Claude-Code-compatible field harnesses (pmh, qasp) run there, orchestrating gateway sidecars.
The desktop client is set up the same way on the other network. **It already works.** The operator's
stated goal is the harder one: *"정말 '보증하는' 잘 돌아감 환경"* — not "it runs" but "we can
guarantee it runs."

🟥 **And the tier estimate was revised DOWN the same day — which inverts the comfortable reading.**
The first estimate put that substrate near Sonnet 4.7–5, and the reasoning followed: *"우리 설계가
기본 소넷급이라면 어렵지 않을 거임."* The operator then revised it (2026-09-13, same session):

| substrate | operator's estimate |
|---|---|
| glm-5.3-flash (the production routing) | **Claude 3.5 Sonnet / 3.7 일반 모드 초기~중기 체급** |
| qwen3.8:27b (the dominance-B2 scorer) | Claude 3.7 Sonnet 기본 추론 모드 근처 |

**If that is right, the floor is set ABOVE the substrate that is actually carrying the work.**
«Runs at current Sonnet» then does **not** imply «runs on glm-5.3-flash» — there is a real gap
between the proxy and the target, and the proxy sits on the easy side of it. The inference
«floor pass ⇒ substrate pass» is therefore **not conservative**; it is optimistic in the exact
direction that hides failures.

Two things follow, and they are the opposite of "this is easy":
- The portability claim needs **the substrate's own tier**, not the floor tier, as its test bed.
  A floor-tier sim that passes says little about a deployment two generations below it.
- Or the floor itself is mis-set: if the org's real substrate is 3.5/3.7-class, then a base op
  that needs current-Sonnet is **already tier-gated for that deployment** — the existing defect
  class, just measured against the wrong reference tier.

⚠️ **Both estimates are the operator's, not benchmark results**, and they disagree with each other
by roughly two model generations. 🟥 **That disagreement is itself the finding**: nobody has
measured it, and the two readings prescribe opposite amounts of work. Settle it with the
comparison below before either is used to plan.

So a floor-tier failure is now **two** findings, not one: the base op is tier-gated (the existing
defect class), **and** it predicts a failure in a deployment that is currently carrying real work.
That raises the stakes of a floor miss without changing the remedy — the remedy is still to make
the rule fire (§Prescription ladder), never to conclude the tier is too weak.

⚠️ **Honest scope — what is missing is the COMPARISON, not the deployment.** The substrate runs;
nobody has yet taken a floor-tier sim set and run the same set on it to report the **disagreement
count**. Until that exists, "floor-tier pass predicts substrate pass" is **the operator's reasoning,
recorded as such** — and the tier estimate (≈ Sonnet 4.7–5) is likewise an estimate, not a
benchmark result. 🟥 The measurement is therefore **cheap and available**, not blocked: the arms
already exist on both sides. A nonzero disagreement refutes the prediction and is worth more than
another floor-tier run. 🟥 Residency note: that comparison runs **inside the org**; its per-case
outputs are company-resident and only a disagreement **count** crosses back.

## Done When (for any change citing this doctrine)

- No availability-gate remains in the touched surface *(check class: measured — tier-reference
  census grep, classify per the table)*.
- Salience-dependent changes pass a Sonnet blind sim *(measured — sim verdict recorded in the
  Axes 2–3 marker)*.
- Depth needs express as dispatch recommendations, not requirements *(judged, pair: adversarial
  review asks "where does this silently require opus?")*.

Cross-refs: `[[feedback_tier_invariant_over_treadmill]]` · `[[feedback_harness_aerodynamics_perceived_perf]]`
· `[[feedback_fh_rides_on_cc_harness]]` · `[[feedback_h1_two_tier_closure]]` · `loop_engineering.md`
(PROSE legs are where Sonnet-tier misses live — the two lenses share one spine).

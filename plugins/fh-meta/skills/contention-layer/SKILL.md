---
name: contention-layer
description: When two skills, agents, or independent research tracks produce conflicting verdicts on the same output, reads the conflict as a signal rather than an error and harvests new skill candidates or insight deltas. Also accepts a Dual-Track Grounding conflict — an open-frontier research track vs an internally-grounded recall track disagreeing — as a research-layer partial analogue of Non-Model Ground (the grounded track is a time-decorrelated anchor, not a non-model one). Routes skills born from contention to fh-meta if they are meta-layer, to commons plugin if project-agnostic, or to field harvest if domain-specific. Triggered by "two skills conflict", "they produce different conclusions", "contention-layer", "contention harvest", "open vs grounded contradiction", "research tracks disagree".
user-invocable: true
allowed-tools: ["Read", "Bash", "Grep", "Write"]
model: sonnet
category: Ecosystem Growth
---

# contention-layer — Contention Harvest + New Skill Routing

When two skills conflict, **harvest the signal** instead of discarding one. Find the validation angle that neither skill addressed, and onboard new skill candidates into the FH ecosystem according to their routing path.

> Philosophical basis: Cognitive dissonance in humans is not a failure but a core asset — the ability to hold contradictions created culture. In the FH ecosystem, conflict is the signal from which new skills are born.

## Triggers

```
/contention-layer                    # analyze current conflict situation
/contention-layer --skills A B       # specify two skills for contention analysis
```

Phrase triggers: "two skills conflict" · "weird when used together" · "they produce different conclusions" · "contention harvest" · "contention" · "open vs grounded contradiction" · "research tracks disagree" · "dual-track grounding **+ conflict/disagree/contradict**" (the phrase "dual-track grounding" alone collides with `phantom-quench` on the word "grounding" — measured Step-0.5 probe #3, 2026-06-17; it fires this skill only when a conflict word co-occurs)

```
/contention-layer --tracks open=<deep-research result> grounded=<memory/CATALOG recall>   # Dual-Track Grounding
```

## Step 1. Collect Conflict Points

Record clearly which sources conflicted on which output, and in which direction. The conflicting
**sources** may be two skills/agents, or two independent **research tracks** (Dual-Track Grounding).

```
Conflicting source A: {skill name / "open-frontier research"} — verdict: {conclusion}
Conflicting source B: {skill name / "internally-grounded recall"} — verdict: {conclusion}
Conflicting output: {TC / diagnostic report / design document / a factual claim / ...}
Conflict point: {which item, by which criteria difference}
```

**Conflict type classification**:
- `Criteria conflict`: Same item evaluated by different criteria (e.g., coverage 50% = Pass vs Fail)
- `Scope conflict`: A includes, B excludes a certain domain
- `Order conflict`: Same goal approached with different preconditions
- `Philosophy conflict`: The measurement purpose itself differs (e.g., risk reduction vs coverage maximization)
- `Track conflict` (Dual-Track Grounding): The same claim is asserted by an **open-frontier** track
  (deep-research / WebSearch over external sources) and contradicted — or unsupported — by an
  **internally-grounded** track (memory / CATALOG / past-session recall). The disagreement is the signal.

### Step 1-b. Dual-Track Grounding — Non-Model Ground at the research layer

When the input is two research tracks rather than two skills, the contention IS the mechanism: two
**time-decorrelated** anchors disagreeing exposes the agreement-bias gap that judge-only synthesis
hides (a single track, however strong, can be confidently wrong with nothing to contradict it). This is
a research-layer **partial analogue of Non-Model Ground** (`[[fh_propagation_nonmodel_ground]]`) — the
grounded track is a **time-decorrelated, provenance-bearing** anchor (written in a prior session against
recorded sources, so the present session's agreement-bias cannot silently overwrite it). It is **not** a
true non-model anchor: memory/CATALOG are model-written, so the independence is temporal + provenance,
not lineage. The honest bias-reduction is that contradicting a provenance-bearing past claim **forces an
explicit source check** (the challenger-verify pairing below) rather than a silent overwrite.

```
Open track (frontier):    deep-research / WebSearch — what the external world currently asserts
Grounded track (internal): memory + CATALOG + past-session recall — what we already established
  → AGREE      : low signal (corroboration) — log confidence, no harvest
  → DISAGREE   : HIGH signal — the open track may be newer (our claim is stale → memory-hygiene),
                 OR our grounded claim is right and the frontier is noise (→ a publishable delta).
                 Direction is a judged call; pair it with challenger-verify-before-act (source-verify
                 BEFORE rewriting either side — never let recency alone win) and route to harvest.
  → UNSUPPORTED: the open track asserts what the grounded track has no record of, and back-trace
                 (phantom-quench) finds no source → treat as Phantom, not as a new fact.
```

Dispatch shape: the two tracks run as independent calls (deep-research ∥ grounded recall — agent-composer
can parallelize), then their outputs enter Step 2 as source A / source B. The harvest gate below is unchanged.

## Step 2. Contention Essence — Harvest Gate

Determine whether the conflict will be resolved by **exclusion** or converted to **harvest**.

```
Question 1: Did the two skills produce different verdicts because they had different validation angles?
  → Yes: Harvest candidate ✅
  → No (bug / malfunction): Exclude → escalate to install-doctor

Question 2: If that tension is resolved, can it be absorbed into one of the existing skills?
  → Possible: Recommend improving existing skill (no new skill needed)
  → Not possible (new angle): New skill candidate ✅

Question 3: Can the candidate skill be transplanted to any project without a specific domain?
  → Transplantable: Route to commons plugin ✅
  → Domain-specific: Field harvest signal
```

Harvest Gate pass criteria: Question 1 ✅ + Question 2 not possible ✅ = new skill birth verdict

## Step 3. Placement Routing

| Skill nature | Routing path | Criterion |
|---|---|---|
| Harness engineering · install/audit/validation/onboarding | `fh-meta` candidate | Skills that operate/diagnose FH itself |
| Project-independent · transplantable anywhere · domain-agnostic | `commons` plugin | Universal utilities like validation angles or analysis frameworks |
| Specific domain/team/language/tech-stack | `field harvest` signal | Field team decision domain — not included in FH |

```
Routing conclusion:
  New skill name candidate: {name}
  Routing path: {fh-meta / commons / field}
  Rationale: {1-line nature verdict}
```

## Step 4. Generate SKILL.md Draft

After confirming routing path, auto-generate a new skill SKILL.md skeleton.

> **Reuse — need-driven scaffold**: this skeleton is also the template for Full-Harness Mode's
> field-asset scaffold (`auto_project_mapping.md §6`). There the entry is not a conflict but a
> **skill-worthy recurring pattern** (3+ reps · `#skill-candidate` · `field-harvest`); set
> `origin: field-scaffold` and replace `contention-parents` with the source pattern pointer. An
> **agent** variant emits `.claude/agents/{name}.md` (`name`/`description`/`tools` + self-contained
> prompt) instead of this SKILL.md frontmatter. The field team fills domain content; FH only scaffolds.

```markdown
---
name: {slug}
description: {one line — include trigger keywords, no marketing language}
user-invocable: true
allowed-tools: [...]
model: sonnet
category: {category}
origin: contention-layer  # contention birth history
contention-parents: [{skill A}, {skill B}]
---

# {skill name} — {subtitle}

{One sentence capturing the validation angle discovered from contention}

## Triggers
...

## Step 1. ...
```

After generating skeleton: **"I will place this draft at {path}. Shall I proceed?"** — confirmation gate.

## Output Format

```
[Contention Harvest Report]
Conflicting sources: {A} vs {B}
Conflict type: {Criteria / Scope / Order / Philosophy / Track}
Harvest Gate: Pass / Fail
  └ Reason: {1 line}
New skill candidate: {name or none}
Routing path: {fh-meta / commons / field / n/a}
Track-conflict resolution: {memory-hygiene / publishable-delta / phantom / n/a}   # only for Track conflicts (Step 1-b)
Next action: {generate draft / exclude / recommend improving existing skill / route track-conflict terminal}
```

## Done When

```
All steps 1–4 completed
+ [Contention Harvest Report] output (Harvest Gate Pass/Fail stated)
+ If new skill candidate exists: SKILL.md skeleton generated + user confirmation gate complete
+ If no new skill candidate: "Exclude / recommend improving existing skill" stated and exit
+ If Track conflict (Step 1-b): terminal stated — memory-hygiene (stale grounded claim) OR
  publishable-delta (frontier was noise, our claim holds) OR phantom-quench (unsupported frontier
  assertion). A track conflict resolving to a terminal is NOT an "exclude" — it is a routed outcome.
```

Verdict: PASS (Harvest Gate Pass — new skill skeleton generated or no candidates confirmed) | CONDITIONAL_PASS (candidates found, user confirmation pending) | FAIL (Harvest Gate Fail — collision unresolvable, no new skill justified) | ESCALATE (role boundary ambiguous, requires human judgment)

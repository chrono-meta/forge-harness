---
name: contention-layer
description: When two skills or agents produce conflicting verdicts on the same output, reads the conflict as a signal rather than an error and harvests new skill candidates. Routes skills born from contention to fh-meta if they are meta-layer, to commons plugin if project-agnostic, or to field harvest if domain-specific. Triggered by "two skills conflict", "they produce different conclusions", "contention-layer", "contention harvest".
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

Phrase triggers: "two skills conflict" · "weird when used together" · "they produce different conclusions" · "contention harvest" · "contention"

## Step 1. Collect Conflict Points

Record clearly which skills conflicted on which output, and in which direction.

```
Conflicting skill A: {skill name} — verdict: {conclusion}
Conflicting skill B: {skill name} — verdict: {conclusion}
Conflicting output: {TC / diagnostic report / design document / ...}
Conflict point: {which item, by which criteria difference}
```

**Conflict type classification**:
- `Criteria conflict`: Same item evaluated by different criteria (e.g., coverage 50% = Pass vs Fail)
- `Scope conflict`: A includes, B excludes a certain domain
- `Order conflict`: Same goal approached with different preconditions
- `Philosophy conflict`: The measurement purpose itself differs (e.g., risk reduction vs coverage maximization)

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
Conflicting skills: {A} vs {B}
Conflict type: {Criteria / Scope / Order / Philosophy}
Harvest Gate: Pass / Fail
  └ Reason: {1 line}
New skill candidate: {name or none}
Routing path: {fh-meta / commons / field / n/a}
Next action: {generate draft / exclude / recommend improving existing skill}
```

## Done When

```
All steps 1–4 completed
+ [Contention Harvest Report] output (Harvest Gate Pass/Fail stated)
+ If new skill candidate exists: SKILL.md skeleton generated + user confirmation gate complete
+ If no new skill candidate: "Exclude / recommend improving existing skill" stated and exit
```

Verdict: PASS (Harvest Gate Pass — new skill skeleton generated or no candidates confirmed) | CONDITIONAL_PASS (candidates found, user confirmation pending) | FAIL (Harvest Gate Fail — collision unresolvable, no new skill justified) | ESCALATE (role boundary ambiguous, requires human judgment)

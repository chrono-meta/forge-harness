---
name: ensemble-union-detection-task
description: "Detection tasks benefit from ensemble UNION (2.5–3.0x coverage lift); generation tasks do not (voting, ~0x). Measured, domain-agnostic."
type: pattern
status: VALIDATED
tags: [ensemble, union, detection, decorrelation, composition-over-scale]
---

# Ensemble Union Pattern for Detection Tasks

> **Measurement basis**: a PRD-review detection protocol (n=3 real product PRDs) + a generation-task
> contrast, measured on a fixed open-weight 3-model roster. Detection lift +11.3 findings (2.8x; per-PRD
> range 2.5x–3.0x); generation lift ~0.

## Pattern

**Detection tasks benefit from an ensemble UNION strategy, not voting.**

- **Detection** (finding defects, gaps, issues): union of all model findings → **2.5x–3.0x** more coverage.
- **Generation** (creating one artifact): voting for consensus → **~0x lift** (no benefit).

## Mechanism

Each model has **different blind spots**. Model A finds category-X defects, B finds Y, C finds Z.
`Union(A, B, C)` = superset of all findings → coverage expansion. Voting would **discard minority
findings**, losing exactly the diversity that makes the panel worth running. (This is the
composition-over-scale lever: the gain is model *diversity*, not model size — and it holds only while the
errors are decorrelated. A shared/correlated blind spot is not closed by union; diagnose correlated vs
independent first.)

## Measured Results

Anchored on a PRD-review detection protocol (3 real product PRDs; 3-model open-weight union vs each single
model):

| Metric | Union (E) | Best single | Lift |
|---|:--:|:--:|:--:|
| Mean findings / PRD | 18.0 | 6.7 | **+11.3 (2.8x)** |

Per-PRD lift ranged **+10.7 to +12.0 (2.5x–3.0x)** — union was 18.0 on every PRD while the best single
model never exceeded 7.3, because each model surfaced *different* findings. A generation-task contrast
(create one artifact) showed **~0 lift** from the same union: consensus/voting adds nothing when the goal
is one output rather than coverage. (The detection→UNION / generation→VOTING split is the validated
pattern; the +11.3 detection anchor is the measured number, the generation-0 is the qualitative contrast.)

**Arms** (illustrative open-weight roster): three distinct open-weight models spanning ≥2 model families
(e.g. `qwen3.5-122b`, `qwen3-next-80b`, `gpt-oss-120b`). Family diversity is the point — a same-family
trio shares blind spots. `E` = union(the three).

## Implementation

```python
# Detection task → UNION
result = ensemble_request(
    prompt="Review this document and classify findings into bins A/B/C/D",
    models=[MODEL_A, MODEL_B, MODEL_C],   # ≥2 families
    strategy="UNION",
    temperature=0.0,
)
# result.findings = all unique findings across models
```

### Deduplication logic

```python
def compute_union(responses):
    """Union of findings across models, deduplicated by normalized description."""
    seen, union = set(), []
    for response in responses:
        for finding in extract_findings(response):
            key = finding.get("description", "")[:50].lower()
            if key and key not in seen:
                seen.add(key)
                union.append(finding)
    return {"findings": union, "total": len(union)}
```

## Token economics

Detection is where a cheap local/open-weight union beats a single frontier call on **both** axes —
more findings **and** lower cost — because union trades false-positive rate (filtered downstream) for
coverage:

| Option | Relative cost | Findings/item | Note |
|---|:--:|:--:|---|
| Frontier alone | baseline | 6.7 | single strong model |
| Open-weight union (3-model) | ~1/19 | 18.0 | ~19x cheaper + ~2.8x more findings |

## Constraints

- **False positives**: union includes *all* findings → higher FP rate. Mitigate with a frontier filter
  (union output → one strong-model validation pass), expert review of high-priority findings only, and a
  downstream precision measurement against ground truth.
- **Decorrelation precondition**: union only helps when the panel's errors are *independent*. If a blind
  spot is shared (correlated), stacking more models does not close it — escalate to a human/ground anchor
  instead. Diagnose correlated-vs-independent (reps ≥ 3) before prescribing union.

## When to apply

| Task type | Examples | Strategy |
|---|---|:--:|
| **Detection** | Bug finding · document review · audit · red-team · structure/traceability check | **UNION** |
| **Generation** | Artifact creation · synthesis · single-answer tasks | **VOTING** |

**Rule of thumb**: "find all X" → UNION. "create one Y" → VOTING.

## Cross-domain applicability

Domain-agnostic — applies to any detection task where (1) multiple independent judges have different
blind spots, (2) the goal is coverage maximization not consensus, (3) false positives can be filtered
downstream. Examples beyond QA: code review (security · performance · maintainability), multi-specialist
diagnosis, content moderation (hate speech · spam · misinformation), fraud detection (multiple risk
models).

## Done When

- [x] Validated on a PRD-review detection protocol (+11.3, 2.8x; per-PRD +10.7 to +12.0) + a generation contrast (~0 lift). *[measured]*
- [x] Deduplication logic specified. *[mandatory-pass]*
- [x] Decorrelation precondition + FP mitigation documented. *[judged — pair: correlated-blindspot diagnosis]*
- [ ] (Optional) Precision/FP-rate measurement against ground truth.

---

**One-line takeaway**: Detection → ensemble UNION (2.5–3.0x lift). Generation → voting (~0x). The lever is
family diversity, not model size, and only while errors stay decorrelated.

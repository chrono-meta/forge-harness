---
name: source-grounding-audit
description: Extracts proper nouns, numerical values, and branching conditions from artifacts (TCs, analysis reports, design documents), back-traces them to declared source files, and marks as Phantom (false) if not found in source. If steel-quench attacks output patterns (self-declarations, cushion language), source-grounding-audit attacks input tracing (where did this come from?). Triggered by "phantom detection", "source back-trace", "source audit", "verify source", "TC evidence tracing", "where did this come from", "grounding audit", "source grounding audit", "phantom claim", "false claim detection".
user-invocable: true
allowed-tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob"]
model: sonnet
---

# source-grounding-audit — Input Tracing Grounding Audit

> Just because an artifact looks plausible doesn't mean it's grounded in source. plausible ≠ grounded.

When AI generates artifacts without reading the source, those artifacts look like domain knowledge but are actually **Phantom Claims** coming from LLM weights. This skill back-traces each claim in the artifact to the declared source to explicitly mark Phantoms.

## Role Separation from steel-quench

| Dimension | steel-quench | source-grounding-audit |
|---|---|---|
| **Attack target** | Output patterns (self-declarations, cushion language, reason for existence) | Input tracing (is the claim in the source?) |
| **Core question** | "Is this structure flawed?" | "Where did this content come from?" |
| **Activation timing** | All-angle quench just before completion | Immediately after source-based artifact generation or at point of suspicion |
| **Primary attack vector** | Bus factor, self-reference, platform obsolescence | Phantom Claim, source not read, fabricated branching conditions |
| **Representative pattern** | "Declaration only, no evidence" | "Number in TC that doesn't exist in source" |

**Can be used together**: steel-quench Wave 1 real-code-based attack + source-grounding-audit Phantom marking can be run sequentially in the same session. But do not mix the roles of the two skills.

---

## Trigger Phrases

| Phrase | Situation |
|---|---|
| "phantom detection", "phantom claim", "false claim detection" | Full artifact Phantom scan (primary trigger) |
| "source back-trace", "source audit" | Analysis report, design document verification |
| "verify source", "where did this come from" | Suspecting origin of a specific claim |
| "TC evidence tracing", "TC source verification" | Post-TC-generation source consistency check |
| "grounding audit", "source grounding audit" | Full artifact Phantom scan |
| "verify evidence files" | Analysis report, design document verification |
| `/source-grounding-audit` | Explicit call |

---

## Core Concept — Phantom Claim

**Phantom Claim**: A claim that appears in the artifact but cannot be found in the declared source files.

3 paths through which Phantoms are produced:

| Path | Description | Risk |
|---|---|:---:|
| **Source not read** | AI generates artifact using domain knowledge without Read-ing source | S |
| **Partial reading** | Source partially read, rest filled in with inference | A |
| **Reconstruction contamination** | Source was read but LLM modified values/conditions during paraphrase | A |

---

## Execution Steps

### Step 0. Confirm Audit Target

If not provided by user, explicitly confirm: artifact file path, declared source files, and audit scope. Source not declared = S-grade blocker registered immediately.

> **Detail**: See `SKILL_detail.md §Step0-Detail` — confirmation output format and simplification guard — read when audit target or source list is ambiguous.

---

### Step 0.5. Claim Distribution Profile

> **Schema**: `knowledge/shared/harness-core/tpa_schema.md` — `phantom_risk` derivation rule, gate trigger conditions, §Gate Routing Table.

Runs after Step 0 (target + source confirmed). Skip if user specifies scope explicitly.

Scan artifact quickly to classify claim distribution:

| Dimension | Signal → Audit depth shift |
|---|---|
| `claim_density` | > 10 claims → full Step 1-4 audit; ≤ 3 claims → light (S+A only) |
| `artifact_type` | SKILL.md/design-doc → prioritize Branch/State-transition claims; code → prioritize Proper-noun/API claims |
| `risk_level` | external publish / arXiv citations → all claim types, max depth |
| `source_count` | 0 declared sources → S-grade blocker immediately (skip to Step 3 prescription) |
| `quantitative_density` | > 3 numerical claims → focus numerical+range types first |

Scope recommendation output:
```
Claim types to prioritize: [list]
Audit depth: [full | prioritized | light]
Immediate blockers detected: [yes/no — 0 sources = immediate S-grade]
```

**0-source behavioral rule**: When artifact has 0 declared sources, skip Steps 1-2 entirely and go directly to Step 3 with S-grade blocker: "Source not declared — all claims unverifiable."

---

### Step 1. Claim Extraction (Artifact Scan)

Extract claims from the artifact that require source back-tracing. Claim types: Proper nouns (highest), Numerical/range values (highest), Branching conditions (highest), State transitions (high), Preconditions (high), Actors (medium). Exclude generic test methodology descriptions and generic UI patterns.

> **Detail**: See `SKILL_detail.md §Step1-Detail` — full claim types table with examples, exclude list, and Step 1 output format template — read when deciding which claims to include or format the extraction results.

---

### Step 2. Source Read + Back-Trace

Back-trace each claim to the declared source files using Read + Grep directly — no inference judgment. Partial match is not treated as match.

Back-tracing classification:

| Classification | Criteria | Marking |
|---|---|:---:|
| **Grounded** | Claim directly confirmed in source | ✅ |
| **Partial** | Similar content in source but not exact match — needs re-confirmation | ⚠️ |
| **Phantom** | Cannot be found in source | ❌ |
| **Source-Missing** | Source itself cannot be Read or was not declared | 🔴 |

> **Detail**: See `SKILL_detail.md §Step2-Detail` — back-tracing execution procedure, classification decision rules, and Step 2 output format template — read when handling edge cases or formatting results.

---

### Step 3. Phantom Classification + Prescription

Classify Phantom and Partial claims by severity and provide prescriptions.

**Severity classification criteria**:

| Severity | Criteria | Examples |
|:---:|---|---|
| **S** (Immediate blocker) | If this claim is wrong, TC could Pass-judge incorrect behavior | Monetary boundary values, branching conditions, status values |
| **A** (Must fix) | If this claim is wrong, TC cannot execute or runs wrong path | API endpoint names, field names, preconditions |
| **B** (Improvement recommended) | If this claim is wrong, TC can execute but intent may differ | Descriptive text, non-critical names |

Prescriptions: (1) Source Re-read — precisely re-read the relevant source section and fix; (2) Request source specification — when source doesn't exist or wasn't declared; (3) Delete/rewrite — delete claims without source grounding and rewrite from source.

> **Detail**: See `SKILL_detail.md §Step3-Detail` — prescription procedures and Step 3 output format template — read when writing the classification table or applying a prescription.

**S-grade Immediate Human Gate** — if 1+ S-grade Phantoms found, pause before Step 4/5 and surface:

```
⚠️  source-grounding-audit: N S-grade Phantom(s) found:
  - [claim 1 — one-line summary, location]
  - [claim 2 — one-line summary, location]

Options:
  (a) Continue — AI proceeds to Step 4 pattern diagnosis + Step 5 re-audit
  (b) Human review first — inspect Phantoms directly, then proceed
  (c) Abort — fix sources manually and re-run audit

Waiting for input. (Default: a)
```

Rationale: S-grade Phantoms that enter Step 5 re-audit without human review risk LLM reconstruction contamination — the same pattern that originally produced the Phantoms can "verify" its own fixes. Human review at this threshold breaks the loop.

---

### Step 4. Source Not-Read Pattern Detection (Meta Diagnosis)

Analyze Phantom distribution to diagnose structural problems in the artifact generation process. Reveal "why were these Phantoms produced", not just "this TC is wrong".

**Pattern detection criteria**:

| Pattern | Detection Condition | Meaning |
|---|---|---|
| **Source not read** | 3+ Phantoms and no or partial source Read history | AI generated using domain knowledge without reading source |
| **Partial reading contamination** | Partial items exceed 30% of total | AI read source partially and filled rest with inference |
| **Reconstruction modification** | Source value exists but unit/format/range modified in TC | LLM paraphrase process contamination |
| **Source declaration absent** | Source file not specified when generating artifact | Process design stage problem |

**Simplification guard**: If 0 Phantoms, skip Step 4 entirely. Replace with one line: "Source grounding adequate."

> **Detail**: See `SKILL_detail.md §Step4-Detail` — Step 4 output format template — read when writing the pattern diagnosis section.

---

### Step 5. Post-Fix Re-audit (Optional)

Re-run back-trace for S-grade blocker claims after fixes are complete. Activate when 1+ S-grade blockers exist and fix is immediately possible.

**Done When (re-audit)**: Back-trace results for fixed claims all show Grounded (✅) status.

---

## Completion Declaration Format

> **Template**: See `SKILL_detail.md §Report-Template` — full completion declaration format — read when producing the final audit summary.

---

## Connected Skills

| Situation | Connected Skill |
|---|---|
| Simultaneously verify output patterns (self-declarations, cushion language) | `/steel-quench` Wave 1 "real-use verification" angle |
| Re-verify Phantom patterns from external user perspective | `/sim-conductor Area A` |
| Source not-read is a harness structure problem | `/harness-doctor` |
| Phantom pattern is a candidate for new rule items | `fh-meta:persona-innovator` |
| Redesign the artifact generation prompt itself | `/meta-prompt-builder` |

---

## External User Environment Adaptation

This skill can be used independently without the full meta-harness structure.

**How to declare source files**: When generating artifacts, specify "source: [file path list]", or provide source files when invoking this skill.

**External environment fallback**:
- If no `tracks/_meta/` → skip persistence step
- If no project-specific rules (like PFD) → output Phantom pattern summary only

---

## Done When

```
Step 1 claim extraction complete
+ Step 2 all claims back-traced (using Read tool — no inference judgment)
+ Step 3 Phantom severity classification + prescription output
+ Step 4 process pattern diagnosis complete (skip if 0 Phantoms)
+ "source-grounding-audit Complete" declaration output
```

Verdict: PASS (0 Phantom claims) | CONDITIONAL_PASS (LOW-severity Phantoms only, prescriptions noted) | FAIL (1+ HIGH/MEDIUM Phantom — broken path, phantom file, or stale external link) | ESCALATE (scope unclear or claim extraction impossible)

---

## Operating Notes

- **Never back-trace by inference**: Judging "this value is probably in the source" treats it as Partial not Phantom. Always directly confirm with Read + Grep.
- **Partial is not Grounded**: Processing similar-value-in-source as Grounded misses the reconstruction modification pattern.
- **Source not declared itself is S-grade**: If source is not declared when making an artifact, no claim can subsequently be verified. Recommend mandating source declaration in the process design stage.
- **Recommended to use with steel-quench**: steel-quench quenches structural flaws, source-grounding-audit ensures source consistency. The two skills are orthogonal and artifact quality assurance is strengthened when used together.

# phantom-quench — Execution Detail

On-demand reference. Load the section indicated by the pointer in SKILL.md.

---

## §Step0-Detail

**Step 0 — Audit Target Confirmation**

If not provided by user, explicitly confirm all three items:

1. **Artifact file**: Path to audit target file (TC file, analysis report, design document, etc.)
2. **Declared source files**: List of source file paths that should be the basis for artifact generation
3. **When source not declared**: Source not declared itself is registered as an S-grade blocker

Output format:

```
Audit target:
  Artifact: {file path}
  Declared source: {file path list or "not declared"}
  Audit scope: {full / specific section / specific claim type}
```

**Simplification guard**: If source is clear and audit scope is single section, skip Step 0 output and go straight to Step 1.

---

## §Step1-Detail

**Step 1 — Claim Extraction Full Reference**

**Claim types to extract**:

| Type | Examples | Priority |
|---|---|:---:|
| **Proper nouns** | API endpoint names, field names, status values, screen names | Highest |
| **Numerical/range values** | Amounts, time, ratios, counts, thresholds | Highest |
| **Branching conditions** | if/else branches, exception cases, error codes | Highest |
| **State transitions** | Conditions for A state → B state, allowed/forbidden combinations | High |
| **Preconditions** | "only when ~", "when ~ is active" | High |
| **Actors** | System, user, external API role distinctions | Medium |

**Exclude from extraction** (no source back-tracing needed):
- General test methodology descriptions ("using boundary value analysis")
- Generic UI patterns ("click button then verify result")

**Step 1 output format**:

```
## Step 1 — Claim Extraction Results

| # | Claim | Type | Location (artifact file:line) |
|:---:|---|:---:|---|
| 1 | [claim content] | Proper noun/Numerical/Branch | [filename:line N] |
...

Total {N} extracted (Proper nouns N / Numerical N / Branch N / State transition N / Precondition N / Actor N)
```

---

## §Step2-Detail

**Step 2 — Source Read + Back-Trace Execution Detail**

**Back-tracing principles**:
- Read source files directly with the Read tool — do not judge from memory or inference
- Use Grep to confirm exact value, keyword, or pattern match
- **Partial match is not treated as match** — e.g., if source has "5 minutes" and TC has "300 seconds", treat as requiring separate confirmation

**Classification decision rules**:

| Classification | Criteria | Marking |
|---|---|:---:|
| **Grounded** | Claim directly confirmed in source | ✅ |
| **Partial** | Similar content in source but not exact match — needs re-confirmation | ⚠️ |
| **Phantom** | Cannot be found in source | ❌ |
| **Source-Missing** | Source itself cannot be Read or was not declared | 🔴 |

**Step 2 output format**:

```
## Step 2 — Source Back-Trace Results

| # | Claim | Back-Trace Result | Source Evidence (file:line) | Notes |
|:---:|---|:---:|---|---|
| 1 | [claim] | ✅/⚠️/❌/🔴 | [filename:line N or "none"] | [modifications, etc.] |
...

Grounded: N / Partial: N / Phantom: N / Source-Missing: N
```

---

## §Step3-Detail

**Step 3 — Prescription Procedures + Output Format**

**3 Prescriptions — detailed execution**:

1. **Source Re-read**: Precisely Read the relevant section of that source file again → fix the claim. Use Read with line-range targeting if the source is large.
2. **Request source specification**: When source doesn't exist or wasn't declared → ask user to specify source file. Do not proceed until source is provided for S-grade items.
3. **Delete/rewrite**: TCs/claims without source grounding should be deleted and rewritten based on source. Rewrite must start from source Read, not from the existing artifact text.

**Step 3 output format**:

```
## Step 3 — Phantom Classification + Prescription

### S-grade Immediate Blockers

| # | Claim (Phantom) | Prescription | Evidence |
|:---:|---|---|---|
| 1 | [claim] | Source Re-read / Request source specification / Delete rewrite | [source file specified or reason for absence] |

### A-grade Must Fix

| # | Claim (Phantom/Partial) | Prescription | Notes |
|:---:|---|---|---|
...

### B-grade Improvement Recommended

| # | Claim (Partial) | Prescription | Notes |
|:---:|---|---|---|
...

S-grade: N / A-grade: N / B-grade: N
```

---

## §Step4-Detail

**Step 4 — Pattern Diagnosis Output Format**

```
## Step 4 — Source Not-Read Pattern Diagnosis

Detected pattern: {pattern name or "none"}
Evidence: {Phantom/Partial distribution analysis}

Process prescription:
- [specific process improvement suggestions]
```

---

## §Report-Template

**Completion Declaration Format**

```
## phantom-quench Complete

Audit scope: {artifact file} / source {N files}
{N} total claims audited

Result summary:
  ✅ Grounded: N
  ⚠️ Partial: N (fix recommended)
  ❌ Phantom: N (S: N / A: N / B: N)
  🔴 Source-Missing: N

Process pattern: {detected pattern or "none"}

Next actions:
  - S-grade Phantom → immediately Source Re-read then fix
  - Source not-read pattern detected → add source Read prerequisite to artifact generation process
  - 3+ Phantoms → recommend using with steel-quench Wave 1 "real-use verification" angle
  - Repeated pattern detected → persist to tracks/_meta/ + propose as rule candidate
```

---

## §Evidence

**Evidence Record**

- **Verified in practice**: TC generation without reading source files → steel-quench passes → phantom-quench back-trace detects numerous Phantoms (notifications vs. push notifications, version names vs. non-enrolled, bottom sheet vs. screen navigation). **Procedure**: Read sources in order then regenerate → replace with source-based TCs. **Recurrence prevention**: Source gate implementation — FileNotFoundError if required source files absent. steel-quench misses this because: outputs look logically sound so pattern attacks cannot identify Phantoms — only source back-tracing can detect them.

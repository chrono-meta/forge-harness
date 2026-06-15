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

## §Step2E-Detail

**Step 2-E — External Claim Fetch + Support Execution Detail**

Fires only for external-cited claims (when Step 0.5 flags `risk_level:external` or `external_citation`).
The principle: **existence ≠ support**. Check that the fetched source *states the claim*, anchored on a
literal span — never on a model's agreement.

**Identifier normalization** (resolve to a fetchable URL before WebFetch):

| Citation form | Resolved URL |
|---|---|
| `arXiv:NNNN.NNNNN` / `arXiv:NNNN.NNNNNvK` | `https://arxiv.org/abs/NNNN.NNNNN` |
| bare DOI `10.xxxx/...` | `https://doi.org/10.xxxx/...` |
| `http(s)://...` | use as-is (HTTPS-upgrade handled by WebFetch) |
| Named source, no URL ("paper X shows Y") | **one** `WebSearch` to locate the canonical URL → then WebFetch it. Do **not** verify against the search snippet alone — the snippet is not the source. |
| version token `pkg x.y.z` | the package registry/release page (npm/PyPI/GitHub releases) for that exact version |

**WebFetch prompt template** (ask for a *span*, not a *verdict* — this keeps the anchor non-model):

```
From this page, quote verbatim the sentence or span that states: "<the exact claim being checked>",
and label it: ASSERTS (the page states the claim is true) / NEGATES (the page states it is false, or
attributes it to refuted prior work) / MENTIONS (the words appear but do not assert the claim).
If no relevant span exists, reply exactly: NONE.
Do not summarize, infer, or judge support — only quote a present span with its label, or reply NONE.
```

Polarity is load-bearing: a page saying "X does NOT hold" or "earlier work claimed X — we refute it"
contains a span lexically matching the claim. Asking for the label keeps the *retriever* mechanical while
surfacing the stance the *judge* needs — a NEGATES/MENTIONS span is **not** grounding.

**Span-evidence format** (a Grounded external verdict is invalid without this):

```
✅ Grounded — <claim>
   source: <resolved URL>
   span: "<verbatim quoted span from fetched content>"
```

**Step 2-E output format**:

```
## Step 2-E — External Source Support Results

| # | Claim | Cited source | Result | Span / reason |
|:---:|---|---|:---:|---|
| 1 | [claim] | [arXiv:.../URL] | ✅/🟠/⏳/❌ | "[quoted span]" or "NONE" or "403 — env-blocked" or "id does not resolve" |
...

Grounded: N / Unsupported: N / Unreachable: N / Phantom: N
```

**Decision rules**:
- Span labelled **ASSERTS** that expresses the claimed relation → **Grounded ✅** (record span).
- Span labelled **NEGATES or MENTIONS** → **Unsupported 🟠** (a negating or merely-mentioning span is not
  grounding — the false-Grounded trap).
- Fetch succeeded, content readable, span = NONE or off-claim → **Unsupported 🟠** (cited-but-not-verified).
- Identifier does not resolve at all (404 on a specific arXiv id, dead DOI, fabricated) → **Phantom ❌**.
- Identifier plausibly real but fetch blocked in this environment (paywall/403/timeout/cross-host) →
  **Unreachable ⏳** — provisional; note the limit, route to a second surface or the human gate; never auto-Phantom.
- `WebFetch`/`WebSearch` **absent/disabled in the environment** (not one source — the capability) → Step 2-E
  cannot run: report "external grounding NOT PERFORMED — no fetch capability" and set verdict **ESCALATE**
  (do not mark every claim Unreachable + CONDITIONAL_PASS — that falsely implies grounding was attempted).
- **Never** upgrade NONE to Grounded because a second model "thinks it's probably right" (agreement bias).

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
  🟠 Unsupported: N (external source fetched but does not support claim — S/A/B)
  ⏳ Unreachable: N (external source un-fetchable here — second surface pending)
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

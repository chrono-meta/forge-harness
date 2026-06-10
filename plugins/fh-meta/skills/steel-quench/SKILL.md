---
name: steel-quench
description: >-
  A meta-skill that concretizes a designer's anxiety into AI-driven all-angle challenger attacks (via fh-commons:quench-challenger) and shakes off flaws through defensive rounds. Systematically surfaces root weaknesses of near-complete projects wave by wave, guaranteeing near-human-review quality without direct human deep inspection. Wave 4 (Meta-Aware Adversary) is an advanced mode where the challenger uses its own AI nature — hallucination, context collapse, prompt injection, tool lock-in — as attack vectors. Wave-P3 (gate-passage re-attack) re-attacks an artifact on Coverage/Narrative/False-confidence right after an upstream gate declares PASS. Built-in fh-commons:quench-challenger agent outputs harness structure 6-axis attack+prescription pairs; after convergence, fh-meta:persona-innovator auto-extracts new patterns. Triggered by: "quench this", "devil's judgment", "all-angle review", "end-to-end verification", "steel quench", "deep pre-completion inspection", "shake out design anxiety", "attack from the root", "did it really pass?".
user-invocable: true
allowed-tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob", "WebSearch", "Agent"]
model: opus
---

# steel-quench — All-Angle Verification Meta-Skill

> Heating steel and plunging it into water brings internal defects to the surface. quench-challenger attacks → defense → repeat = systematic surfacing and elimination of design flaws.

A designer's anxiety is most dangerous when vague. steel-quench breaks that anxiety into concrete attack angles, defends against them, and closes with residual risks explicitly stated.

> **Scope boundary**: steel-quench stress-tests a **near-complete artifact** (post-build). For pre-build design decisions → `deliberation`. For completed-asset validation → `sim-conductor`.

## Trigger Phrases

| Phrase | Situation |
|---|---|
| "quench this", "run quench" | All-angle verification just before completion |
| "devil's judgment" | Focused challenger attack on specific design decision |
| "all-angle review", "end-to-end verification" | Full project scope verification |
| "shake out design anxiety", "deep pre-completion inspection" | Concretize vague anxiety |
| "attack from the root" | Re-verify from reason for existence |
| "diagnose with counterexample", "use this bad case as reference" | Phase 0 calibration |
| "did it really pass?", "re-attack after the gate", "the gate said PASS" | Wave-P3 gate-passage re-attack |
| `/steel-quench` | Explicit call |

---

## Wave Structure

| Wave | Role | Termination |
|---|---|---|
| **Phase 0** (optional) | Counterexample calibration — extract patterns from external bad cases, merge into Wave 1 | No external case → skip |
| **Wave 1** | Challenger attack (quench-challenger) — surface critical flaws, no defense | — |
| **Wave 2** | Defense — defend or state as residual risk | — |
| **Wave 3+** | Convergence — repeat until zero new S-grade | Zero new S-grade |
| **Wave 4** (optional) | Meta-Aware Adversary — AI uses its own nature as attack vector | Zero new S-grade + AI-specific criteria |
| **Wave-P3** (optional) | Gate-passage re-attack — when an upstream gate declares PASS, re-attack the just-passed artifact on Coverage / Narrative / False-confidence | All 3 dimensions Attack Failed |
| **Wave 5** (optional) | Multi-Team Adversarial Panel — external CLIs or cross-session Claude | Zero new S-grade cross-team |
| **Wave-T** (after convergence) | Temper — measure complexity the quench *added*; flag over-hardening | τ-PASS or named τ-FAIL |

---

## Step 0.3 — Artifact Vulnerability Profile

> **Schema**: `knowledge/shared/harness-core/tpa_schema.md` — canonical artifact_type/risk_level/phantom_risk derivation, gate routing, meta-harness broadcast multiplier.

Runs when steel-quench is invoked without a specific wave restriction.
Skip if user specifies exact waves (e.g. "run Wave 1 and Wave 4 only").

Read target artifact → classify vulnerability surface:

| Dimension | Signal → Wave weight shift |
|---|---|
| `artifact_type` | SKILL.md/design-doc → Wave 2 (structural defense) weight↑ · bash/code → Wave 1 (real-code) weight↑ · external publish imminent → Wave 5 (cross-team) weight↑ |
| `phantom_risk` | citations/arXiv/DOIs/http URLs present → Wave 3 (source-grounding) weight↑ |
| `claim_density` | 3+ benefit claims → Wave 1 U3 (evidence grounding) angle weight↑ |
| `novelty` | first-of-its-kind pattern → Wave 4 (convergence) weight↑ |
| `scope` | internal-only doc → Wave 5 (external CLI) weight=0 (skip) |

Wave selection output:
```
Run:  [list of selected waves with rationale]
Skip: [list of skipped waves with reason]
External CLIs available: [yes/no → Wave 5 available]
```

**Degraded coverage rule**: if a high-weight wave or capability is skipped (user choice, unavailable tool, or scope=internal) **or runs below its declared model-tier floor** (tier-floor resolution, `multi_model_sidecar_strategy.md §Tier-floor`), flag explicitly in the output header — do not silently proceed. Below-floor example: `challenger: sonnet (below-floor; floor=opus)`; a judged verdict produced below floor is a re-quench candidate once a floor-tier is available.

---

## Step 0.4 — Specialized Reviewer Discovery

For the target artifact, scan installed agents for a domain-specific adversarial reviewer:

1. Check `.claude/agents/` for a reviewer matching `artifact_type`
2. Built-in fallback: `fh-commons:quench-challenger` (general-purpose adversarial review)
3. GAP for high-risk artifact: query `/plugin-recommender "adversarial reviewer for [artifact_type]"` → user: install / skip / use fallback

> **Sidecar availability** for a cross-provider challenger (Gemini/Codex, Wave 5) is resolved via the Tier 1→2→3 recipe in `knowledge/shared/harness-core/multi_model_sidecar_strategy.md §Sidecar Engine Resolution Protocol`; Tier 3 = the `fh-commons:quench-challenger` Claude sub-agent below (guaranteed fallback — same-provider, so model-access not cross-provider diversity).

**Runtime adapter note**: In Claude Code, invoke the fallback as an isolated `Agent(subagent_type="fh-commons:quench-challenger")`. In Codex-primary or other non-Claude runtimes, use the FH adapter instead:

```bash
FH_BACKEND=codex npx --package @chrono-meta/fh-gate fh-run \
  --agent fh-commons:quench-challenger \
  --file {target-artifact}
```

Treat the adapter output as the isolated challenger result for Wave 1. This preserves the same workflow without depending on Claude Code's Agent tool.

**Wave 5 activation rule**: Wave 5 (external CLI team) is only activated when `scope` is not internal-only AND external CLIs are available AND risk_level is high or user explicitly requests it.

> **Detail**: See `SKILL_detail.md §ArtifactProfile` — worked examples (SKILL.md, bash script, README, design doc with citations) showing wave selection and rationale — read when classifying an unfamiliar artifact type.

---

## Wave 1 — 5 Mandatory Attack Angles

**Execution principles**: Attacks must be based on real code/files/configs — abstract criticism prohibited.
Assign severity: **S** (immediate blocker) / **A** (required before deployment) / **B** (improvement recommended).
Call **fh-commons:quench-challenger** in isolation first (6-axis structural attack); apply 5 angles in parallel.

Isolation can be achieved by Claude Code `Agent(...)` or by `fh-run --agent fh-commons:quench-challenger` under Codex. Do not run the challenger inline in the same reasoning pass when the attack result gates the defense.

| # | Attack Angle | Core Question |
|:---:|---|---|
| 1 | **Reason for existence** | "Why this structure? Is there no simpler alternative?" |
| 2 | **Real-use verification** | "Does what's written in the docs actually match the real code?" |
| 3 | **Bus factor** | "Single-person dependency — can it operate if that person is absent?" |
| 4 | **Platform obsolescence** | "Does this structure survive when the external ecosystem expands or changes?" |
| 5 | **Self-referential structure** | "Is there a closed circuit that evaluates itself by its own criteria?" |

**S-grade Immediate Human Gate**: If Wave 1 contains 1+ S-grade blocker → pause, surface options (a) proceed to Wave 2 / (b) human review first / (c) abort. Do not silently enter Wave 2 with unreviewed S-grade items.

> **Detail**: See `SKILL_detail.md §Wave1` — Wave 1 output format, optional numeric score, quench-challenger invocation.

---

## Wave 2 — Defense Principles

**3 Defense Principles**: (1) Reinforce with external cases via WebSearch — "unique to us" or "structural pattern"?
(2) Cover with experience — other project cases defend bus factor. (3) Prioritize immediate implementation over logical construction.

**Classification**: Immediate implementation (this session) / Long-term improvement (residual risk card) / Structural acceptance (declare with rationale).

**"Brain in a Vat + Sandboxed Adversary"**: Challenger attacks only static code (isolated). Defender brings living system evidence. This asymmetry makes Wave 2 structurally superior to Wave 1.

> **Detail**: See `SKILL_detail.md §Wave2` — Wave 2 output format, full Brain-in-Vat principle.

---

## Wave 4 — Meta-Aware Adversary (5 Attack Angles)

The challenger (quench-challenger in Wave 4 mode) knows it's running in an isolated sub-agent sandbox and uses that knowledge as a weapon.

| # | Attack Angle | Core Question |
|:---:|---|---|
| W4-1 | **AI dependency single point of failure** | "If Claude API goes down, does harness core function go to zero?" |
| W4-2 | **Context Collapse** | "When initial instructions are lost to context compression, does harness go silent?" |
| W4-3 | **Prompt Injection exposure** | "Can external data overwrite harness internal rules?" |
| W4-4 | **Hallucination cumulative contamination** | "Do Wave defense arguments rely on LLM inference rather than actual measurement?" |
| W4-5 | **Tool Dependency Lock-in** | "If a specific MCP/plugin/tool is removed, does harness functionality collapse?" |

Wave 4 convergence = Wave 3 criteria + 3 AI-specific vectors actually reviewed + hallucination defense based on original file references.

> **Detail**: See `SKILL_detail.md §Wave4` — Wave 4 output format, defense principles, convergence criteria, activation declaration format.

---

## Wave-P3 — Gate-Passage Re-Attack (optional)

**Activation**: When an upstream gate declares PASS on an artifact — any "declared-complete boundary"
(a verification gate's terminal PASS, a `/pipeline-conductor` green sweep, a `/marketplace-gate` listing
verdict, the 4-axis auto-gate marker, a domain TC/coverage gate). Propose preemptively, run after approval.
No gate-PASS in scope → skip Wave-P3 entirely.

> A 1-round gate PASS is exactly when reviewers stop looking — "we just passed" is the lowest-vigilance
> moment in any workflow. Wave-P3 distrusts the declaration and re-attacks the just-passed artifact on three
> dimensions the gate's own pass criteria structurally could not check. Only when all three Attack Failed can
> a **"Real PASS"** be declared.

**Agent utilization**:
- `fh-commons:quench-challenger` (optional) — adds 6-axis structural attack to each dimension. If absent, run the 3 dimensions directly.
- `fh-meta:persona-innovator` (after convergence) — error/gap patterns found during Wave-P3 → auto-propose new Cross-Project Pattern rows or skill-candidate signals.

The three dimensions generalize the gate's three blind spots:

| # | Dimension | The blind spot it attacks |
|:---:|---|---|
| Wave-P3a | **Coverage** | *What did the gate not check?* Items marked covered/passed that lack a traceable artifact (ID, test, file, citation). |
| Wave-P3b | **Narrative** | *What story does the passed artifact tell that may be wrong?* Residual hardcoded/environment-coupled values and vague, unverifiable claims the PASS declaration smuggled through. |
| Wave-P3c | **False-confidence** | *Did the gate produce false confidence?* High-risk items that passed carrying only a binary pass/fail, with no residual-risk or failure-mode caveat. |

Each dimension is `Attack Succeeded` (defect found) or `Attack Failed` (clean).

**Wave-P3 Done When**:
```
All 3 dimensions [Attack Failed] → ✅ Real PASS → activate fh-meta:persona-innovator (extract new patterns)
Any 1 [Attack Succeeded]        → fix affected items, re-run Wave-P3 (max 2 re-runs)
Still [Attack Succeeded] after 2 re-runs → "gate structural redesign required" → ESCALATE
```

**Basis**: reverse-imported from a field-side sister harness (private companion signal, 2026-06-08). Field
evidence: a test-case coverage gate declared a 1-round PASS, then additional FAILs surfaced in rounds 2–3 —
the gate-PASS-then-defect-found-in-next-stage pattern Wave-P3 collapses. Generalized from the field's
domain-coupled (a spec→test-case gate) form to a gate-agnostic boundary hook. Shares its root with
`fh-commons:convergence-loop` (single-pass distrust).

> **Detail**: See `SKILL_detail.md §WaveP3` — per-dimension attack questions, gap criteria, and output format — read when running a gate-passage re-attack.

---

## Wave-T — Temper (post-convergence)

Quench hardens, but quenched steel is brittle — no smith ships it un-tempered. steel-quench attacks
until zero new S-grade; nothing in that loop asks whether the hardening itself **introduced complexity
beyond what the fixes required** (defense scaffolding, decorative wiring). Wave-T is that inverse
corrective. It runs **after Wave 3+ convergence, before Done When**. It does not attack; it measures
the cost of the convergence just achieved.

| Step | Class | What it does |
|---|---|---|
| **T-1 complexity delta** | measured | `bash templates/temper_check.sh <repo> <file> <pre-quench-ref>` — Δlines/sections/steps/tables/fences/cross-refs, baseline (pre-Wave-1) → post-convergence. Prose-only counts: code-fence interiors are excluded (bash comments are not sections) |
| **T-2 absolute context** | measured | `harness-doctor` L1–L3 on the post-quench asset — absolute complexity tier (reuse, don't reimplement) |
| **T-3 τ verdict** | judged — paired with the quench's own Wave findings (each flagged construct must trace to a specific finding it allegedly fixes; no judge-only path) | **τ-PASS**: added complexity ⊆ what the fixes required. **τ-FAIL**: the quench introduced a construct that *defends against an attack rather than fixing the flaw* — name it, propose the simpler form, hand back for de-brittling. τ-FAIL is the temper step working, not a quench failure |

**T-3 heuristic flags** (any → review, never auto-reject): a new section/table/step whose only referent
is a Wave-N finding · Δcross-refs ≫ Δsteps (wiring, not function) · the asset crosses a harness-doctor
complexity tier it was below pre-quench.

**Don't-overbuild guard (τ applied to τ)**: Wave-T is one script + this section, reusing harness-doctor
for the absolute read. If Wave-T grows its own detection engine, it has failed its own test — a temper
step that adds complexity is self-refuting. Known limits (honest): `temper_check.sh` takes one path —
renamed files need a manual pre/post measurement; the wiring flag uses strict `>`, so Δxrefs = Δsteps
does not fire it (the section flag usually carries those cases).

**Model note**: T-1 is bash (no model), T-2 reuses harness-doctor (sonnet-rated). T-3 adjudication was
validated blind on both Opus and Sonnet (3-fixture ground-truth test, 3/3 each, 2026-06-10) — Wave-T
end-to-end does not require the largest model tier. Opus remains the recommendation for full
steel-quench runs (challenger waves are broader than T-3).

---

## External-GT Adjudication (when the target has a public ground truth)

When quenching a **public artifact that has its own ground truth** — a repo's open issues, test suite, or
stated policy/threat-model (a frontier codebase, a sister project — *not* your own in-progress draft) — add
an adjudication pass after the panel produces findings. The panel (Wave 5 cross-family) gives decorrelated
detection; this pass adds the *external check* the panel cannot self-supply. For each finding, classify:

| Class | Test | Meaning |
|---|---|---|
| **Corroborated** | matches an OPEN issue / a failing test | independent rediscovery — strongest |
| **Novel** | no matching issue, but confirmed by logic or a written test | caught what the target missed |
| **Reframe / reject** | the target's own docs/policy/threat-model marks it intentional or out-of-scope | NOT a confident catch — a false positive |

The GT (not a cross-family vote) resolves contention objectively, and it catches the panel's own
**shared training-prior** false positives. Report only Corroborated + Novel as confident catches; a null
result on sound code is the correct answer, not a failure. **Basis**: 2026-06-06 frontier-quench sweep —
a single-family pass repeated still misses what cross-family catches, and a target's `SECURITY.md` reframed
"security" findings to "correctness" (its permission layer was UX, not a boundary).

---

## Cross-Project Common Patterns (initial seed)

| # | Pattern Name | Description | Response Direction |
|:---:|---|---|---|
| P1 | **Single-person bus factor** | System paralysis when core operator absent | Document, automate, formalize delegation |
| P2 | **Doc-code mismatch** | Documented behavior differs from actual code | Re-sync to real code as ground truth |
| P3 | **Self-referential diagnosis** | Creator validates — internal viewpoint closed circuit | Connect external persona or sim-conductor |
| P4 | **No real-use verification** | Theoretically designed but never executed | Mandate 1 cold-start simulation |
| P5 | **Platform obsolescence unplanned** | No response to external ecosystem changes | Quarterly frontier diagnosis |
| P6 | **AI dependency single point of failure** | Claude API/MCP removal causes collapse | Document graceful degradation + fallback |
| P7 | **Hallucination-contaminated defense** | Defense relies on LLM inference, not measurement | Mandate citing original file/commit/value |
| P8 | **Context Collapse unguarded** | Key instructions lost to compression → harness silent | Review CLAUDE.md compact repeated insertion |

Add new rows as new patterns are discovered.

---

## Done When

```
Wave convergence criteria met: zero new S-grade blockers
+ Residual risk card output (A-grade · B-grade items)
+ "steel-quench Complete" declaration output
```

Verdict: PASS (zero S-grade, convergence reached) | CONDITIONAL_PASS (A/B-grade remain) | FAIL (S-grade persist) | ESCALATE (structural ambiguity requiring human judgment)

---

## Convergence Criteria + Downstream Chaining

### Convergence Criteria
1. **Zero new S-grade blockers** → terminate
2. A-grade or higher complex improvements → skill-ize with `/meta-prompt-builder`
3. Full Wave results → recommend persisting to `tracks/_meta/steel_quench_YYYY_MM_DD_{slug}.md`

### Connected Skills

| Situation | Connected Skill | Mandatory? |
|---|---|:---:|
| Delegate improvements as prompts | `/meta-prompt-builder` | optional |
| **External publish: re-validate from external user perspective** | **`/sim-conductor Area A`** | **mandatory** |
| Re-validate structural decision | `/verify-bidirectional` | optional |
| Attack angle is a harness structure problem | `/harness-doctor` | optional |
| After Wave convergence, propose new pattern rules | `fh-meta:persona-innovator` | optional |
| Wave 1 structure-specific attack (6-axis) | `fh-commons:quench-challenger` | priority |
| Back-trace whether claims exist in source files | `/phantom-quench` | **mandatory** when `phantom_risk=true` OR `scope=external` (see tpa_schema.md §Gate Routing Table) |

**steel-quench → sim-conductor gate**: After Wave convergence in external-publish context, `/sim-conductor Area A` is the mandatory next step.

### Required Pre-External-Deployment Sequence

```
steel-quench convergence (zero new S-grade)
        ↓  pass residual risk list
sim-conductor Area A (external user perspective)
        ↓  new items found that steel-quench missed?
        ├── yes → additional steel-quench Wave round
        └── no  → deployment approved
```

> **Detail**: See `SKILL_detail.md §Wave5` — Wave 5 Multi-Team Panel (team formation bash, parallel dispatch, cross-team synthesis) — read when activating `--sidecar` flag. See `SKILL_detail.md §Structural-Defense` for meta-harness defense layering explanation.

---

## Operating Notes

- **Do not defend in Wave 1.** Mixing attack and defense modes dulls the attack's edge.
- **Attacks without real code are invalid.** Abstract criticism is not included in Wave 1 results.
- **quench-challenger first.** Call fh-commons:quench-challenger in isolation in Wave 1 if available.
- **Always check self-referential pattern (P3).** Cross-validate Wave results with external criteria.
- **Public target → adjudicate against external GT before claiming.** A finding the target's own docs/policy/threat-model marks intentional or out-of-scope is a false positive, not a catch. See §External-GT Adjudication.
- **Attack surface limit**: steel-quench attacks output content patterns. Phantom Claim detection → `phantom-quench`.
- **Gate cross-reference**: any FH skill that declares a PASS / green / listing-ready verdict (`pipeline-conductor`, `marketplace-gate`, the 4-axis auto-gate, `convergence-loop`, domain coverage gates) is a valid Wave-P3 entry point. Invoke `/steel-quench` Wave-P3 on the just-passed artifact rather than editing each gate to embed it — the hook lives here, callers reference it.

## Failure Fallback

On Claude API / MCP failure → refer to [`references/fallback-guide.md`](../../references/fallback-guide.md).

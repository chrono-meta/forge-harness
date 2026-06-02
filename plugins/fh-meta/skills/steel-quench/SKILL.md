---
name: steel-quench
description: >-
  A meta-skill that concretizes a designer's anxiety into AI-driven all-angle devil attacks and shakes off flaws through defensive rounds. Systematically surfaces root weaknesses of near-complete projects wave by wave, guaranteeing near-human-review quality without direct human deep inspection. Wave 4 (Meta-Aware Adversary) is an advanced mode where the devil uses its own AI nature — hallucination, context collapse, prompt injection, tool lock-in — as attack vectors. Built-in fh-commons:quench-challenger agent outputs harness structure 6-axis attack+prescription pairs; after convergence, fh-meta:persona-innovator auto-extracts new patterns. Triggered by: "quench this", "devil's judgment", "all-angle review", "end-to-end verification", "steel quench", "deep pre-completion inspection", "shake out design anxiety", "attack from the root".
user-invocable: true
allowed-tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob", "WebSearch", "Agent"]
model: opus
---

# steel-quench — All-Angle Verification Meta-Skill

> Heating steel and plunging it into water brings internal defects to the surface. AI all-angle devil attacks → defense → repeat = systematic surfacing and elimination of design flaws.

A designer's anxiety is most dangerous when vague. steel-quench breaks that anxiety into concrete attack angles, defends against them, and closes with residual risks explicitly stated.

## Trigger Phrases

| Phrase | Situation |
|---|---|
| "quench this", "run quench" | All-angle verification just before completion |
| "devil's judgment" | Focused attack on specific design decision |
| "all-angle review", "end-to-end verification" | Full project scope verification |
| "shake out design anxiety", "deep pre-completion inspection" | Concretize vague anxiety |
| "attack from the root" | Re-verify from reason for existence |
| "diagnose with counterexample", "use this bad case as reference" | Phase 0 calibration |
| `/steel-quench` | Explicit call |

---

## Wave Structure

| Wave | Role | Termination |
|---|---|---|
| **Phase 0** (optional) | Counterexample calibration — extract patterns from external bad cases, merge into Wave 1 | No external case → skip |
| **Wave 1** | Devil attack — surface critical flaws, no defense. quench-challenger (6-axis) built-in | — |
| **Wave 2** | Defense — defend or state as residual risk | — |
| **Wave 3+** | Convergence — repeat until zero new S-grade | Zero new S-grade |
| **Wave 4** (optional) | Meta-Aware Adversary — AI uses its own nature as attack vector | Zero new S-grade + AI-specific criteria |
| **Wave-P3** (reserved) | Domain gate integration slot | Future use |
| **Wave 5** (optional) | Multi-Team Adversarial Panel — external CLIs or cross-session Claude | Zero new S-grade cross-team |

---

## Wave 1 — 5 Mandatory Attack Angles

**Execution principles**: Attacks must be based on real code/files/configs — abstract criticism prohibited.
Assign severity: **S** (immediate blocker) / **A** (required before deployment) / **B** (improvement recommended).
Call **fh-commons:quench-challenger** in isolation first (6-axis structural attack); apply 5 angles in parallel.

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

**"Brain in a Vat + Sandboxed Adversary"**: Devil attacks only static code (isolated). Defender brings living system evidence. This asymmetry makes Wave 2 structurally superior to Wave 1.

> **Detail**: See `SKILL_detail.md §Wave2` — Wave 2 output format, full Brain-in-Vat principle.

---

## Wave 4 — Meta-Aware Adversary (5 Attack Angles)

Devil knows it's running in an isolated sub-agent sandbox and uses that knowledge as a weapon.

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
| Back-trace whether claims exist in source files | `/source-grounding-audit` | optional |

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
- **Attack surface limit**: steel-quench attacks output content patterns. Phantom Claim detection → `source-grounding-audit`.

## Failure Fallback

On Claude API / MCP failure → refer to [`references/fallback-guide.md`](../../references/fallback-guide.md).

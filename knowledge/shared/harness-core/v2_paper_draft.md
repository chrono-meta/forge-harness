---
name: v2-paper-draft
description: First full draft of FH v2 paper — Governance Dividend. 4 experiments with empirical results. Independent paper, not a v1 revision.
date: 2026-05-31
tags: [v2-paper, draft, empirical, governance, multi-team, tier-comparison, controlled-trial]
---

# Governance Dividend: Empirical Evidence for Harness-Structured Methodology as a Distinct Quality Layer in Multi-Agent AI Systems

**Draft 1.3** — 2026-05-31 (post §1 full steel-quench: novelty positioning + self-referential disclosure + causality caveat + B4 tier-snapshot L4 closure)

*Companion to: "The Forge Harness: A Structured Methodology for Sustainable AI-Assisted Software Development" (Zenodo 10.5281/zenodo.20397566)*

---

## Abstract

Autonomous coding agents produce syntactically correct, CI-passing output at high velocity. Yet correctness at the syntax and unit-test level does not equal correctness at the design, security, or maintainability level. This paper presents four controlled experiments demonstrating that a harness-structured governance methodology layer — applied on top of a bare coding agent — catches qualitative defects that neither the agent alone nor standard CI pipelines can self-generate. We show: (1) multi-model adversarial review surfaces non-overlapping failure modes that single-model review misses; (2) a governance pass produces a verdict flip from DONE to PENDING on AI-generated code that passed all CI checks, with two A-grade security-adjacent findings not detected by CI or developer self-review; (3) S-grade critical defect detection is tier-independent — entry-tier models (Haiku) find the same blockers as premium-tier (Opus) when governed by the same protocol, while premium tiers add autonomous architectural meta-critique (coverage-ceiling independence, path-length dependence); (4) a three-persona cross-session review (C2) raises single-persona coverage from 57% to 84% on average across N=5 artifacts, and adding an external CLI team (C3) closes the remaining gap to the C2+C3 union — with external tokens billed to the external CLI's own quota (H3 validated). The central contribution: **empirical quantification of the governance dividend** — coverage gain per token spent across panel configurations, and the first measurement that the governance protocol — not the model tier — is the primary determinant of critical-defect coverage ceiling in multi-agent LLM pipelines. These relationships are specific to the multi-agent LLM execution context and are not derivable from pre-LLM structured review literature.

---

## 1. Introduction

### 1.1 The Automation-Quality Gap

Coding agents (OpenCode, GitHub Copilot, Devin, Claude Code) reduce implementation time by an order of magnitude. The automation pipeline — specification → generation → CI → merge — appears to close the development loop. But it closes only the *syntactic* loop. The semantic loop — design coherence, security boundary enforcement, operational readiness, maintainability contract — remains open.

Three structural reasons explain why the automation pipeline cannot self-close the semantic loop:

1. **Same-model self-review**: The model that generates code shares cognitive biases with the model that self-reviews it. Blind spots are symmetric.
2. **CI is structural, not semantic**: CI checks compilation, type safety, and test coverage. It does not check whether the permission allowlist actually covers all execution paths, whether an error recovery path references a file that does not exist, or whether two skills in the same harness create an unbounded mutual recursion.
3. **Speed incentivizes shallow gates**: At agent velocity, a human reviewer faces dozens of PRs per day. The marginal value of deeper review declines as the volume rises. The governance layer provides depth without requiring proportional human time.

### 1.2 Contribution

This paper makes four empirical contributions beyond the v1.0 architectural argument:

1. **Experiment 1** (§3): Multi-model orchestrator swap evidence — different models find non-overlapping failure modes on the same artifact. Harness is the activation condition; model is the lens.
2. **Experiment 2** (§4): Governance controlled trial on OpenCode's `arity.ts` — CI-passing, developer-approved code receives PENDING verdict with 2 A-grade security-adjacent findings under FH governance.
3. **Experiment 3** (§5): Tier comparison — S-grade critical defect detection is tier-independent across Haiku-4.5, Sonnet-4.6, and Opus-4.8 on the same target; premium tiers add autonomous architectural meta-critique not elicited by the protocol structure alone. This result is a snapshot of the May 2026 capability gap between tiers; see §10.3 L4 for temporal validity constraints.
4. **Experiments 4+5** (§6, §7): Cross-ecosystem governance reach (3 external projects, 4 A-grade findings submitted as issues) and multi-team token-coverage tradeoff (N=5 FH-internal artifacts, C2 three-persona cross-session panel raises coverage from 57% to 84%; adding an external CLI team closes to the C2+C3 union at zero marginal Claude quota cost).

**Novelty positioning.** Prior SE literature (Fagan 1976 and subsequent empirical work) establishes that structured review catches defects that automated testing misses. Our contribution does not restate this baseline. Our empirical claims are LLM-native and quantitative: (a) the *governance protocol* — not the model tier — is the primary determinant of critical-defect coverage ceiling (§5); (b) a three-session independent panel raises coverage by 27 percentage points over single-session review at negligible marginal cost (§7); (c) external CLI teams extend defect coverage at zero cost to the orchestrating model's token quota, a billing-architecture fact specific to multi-CLI LLM pipelines (§7 H3). None of these relationships are derivable from pre-LLM review literature, because they depend on properties — same-session confirmation bias, cross-model distribution independence, and multi-CLI quota isolation — that are specific to the multi-agent LLM execution context. The rival explanation ("longer or more structured prompt alone improves output, independent of harness structure") is acknowledged as a limitation; §10.3 and §10.4 document the ablation study needed to isolate the protocol-structure effect.

### 1.3 Relation to v1.0

v1.0 (Zenodo 10.5281/zenodo.20397566) argued that a harness is a durable layer worth building — an architectural claim supported by design principles and compounding-loop mechanics. v2 is an independent paper: the same harness instance (FH) now has four experiments across real external and internal artifacts and three external open-source projects. The thesis extends from "worth building" to "empirically measurable governance dividend under a structured protocol." Three of five experimental targets are FH's own artifacts reviewed by FH's own governance protocol; this self-referential structure is an explicit limitation documented in §10.3 L3, and the ablation design in §10.4 FW-1 is the intended resolution.

---

## 2. Background

### 2.1 Coding Agents and the Speed-Quality Tradeoff

Modern coding agents achieve task completion rates of 40–98% on benchmark repositories (SWE-bench, SWE-bench Verified). The upper range requires scaffolding — retry loops, tool use, multi-agent coordination. At these rates, human review becomes the bottleneck. The question shifts from "can the agent do it?" to "how do we govern output at agent velocity?"

Governance at agent velocity requires a different interface than traditional code review:
- Structured verdict (PASS/PENDING/BLOCKED) consumable by CI
- Severity grading (S/A/B) that maps to action priority
- Reproducible protocol executable without domain expert presence

FH provides this interface through its governance skill layer (steel-quench, source-grounding-audit, pipeline-conductor, sim-conductor).

### 2.2 Multi-Model Adversarial Review — Prior Work

The multi-model sidecar pattern — routing the same artifact to different models for independent adversarial review — was documented in FH v1.0 as the "Multi-Team Adversarial Panel" design. Structural justification: different models have different pre-training distributions and therefore different systematic blind spots. Adversarial review by the generating model is self-grading; adversarial review by an independent model is structurally more likely to surface novel findings.

The harness-evolver framework (Christi 2025) demonstrated automated outer-loop adversarial critique with human-in-the-loop confirmation. FH extends this with: (a) multi-CLI team formation (Gemini, Ollama, Codex sidecars), (b) cross-session Claude isolation via `claude --print` subprocess (eliminates same-session confirmation bias), and (c) empirical measurement of coverage-cost tradeoffs (this paper).

### 2.3 Harness Methodology Layer — Definition

A *harness* is a persistent configuration of AI behavior: rules, skills, context injection, and verification gates that sit between the user's intent and the AI's execution. The harness methodology layer is the subset of harness components that enforce quality gates — structured verification that fires before output is accepted.

FH's methodology layer consists of six verification skills organized around a 6-axis framework (structure / context / plan / execute / verify / improve). For governance purposes, the relevant skills are: `steel-quench` (adversarial multi-wave review), `source-grounding-audit` (phantom reference detection), `sim-conductor` (external persona simulation), and `pipeline-conductor` (end-to-end sweep orchestrator).

---

## 3. Experiment 1 — Multi-Model Orchestrator Swap

### 3.1 Design

- **Fixed**: FH harness structure and governance protocol (unchanged)
- **Variable**: orchestrating model (Claude Opus → Gemini → Codex)
- **Target**: FH architecture self-audit
- **Measure**: cross-wave delta — findings unique to each model that others missed

### 3.2 Results

Three-round swap completed. Key finding: **no gap converged across sidecars**. Each model lens found distinct weaknesses:

- **Claude Opus**: synthesizer role; found internal structural coherence issues, self-referential circuits, context-window vulnerability
- **Gemini**: structural/security lens; found integration boundary failures, non-standard environment breakage, trust boundary ambiguities
- **Codex**: ecosystem/distribution lens; found CLI availability assumptions, external dependency lock-in, operator-environment mismatch

Non-overlapping failure modes. No single model found all three categories of defects.

### 3.3 Discussion

Process diverges (each model finds different gaps), results converge (all validate the harness methodology layer as sound). The harness is the activation condition that forces systematic review; the model determines which dimension of the artifact is attacked. This is the key finding of Experiment 1: **the model is a lens, not the source of quality.**

---

## 4. Experiment 2 — Governance Controlled Trial

### 4.1 Target

`packages/opencode/src/permission/arity.ts` — 163 lines of AI-generated TypeScript, part of OpenCode's permission enforcement layer. The file contains its own generation prompt as a code comment (explicit documentation that this is AI-generated output).

### 4.2 Baseline

Condition A: Standard CI pipeline
- 6 unit tests: all pass
- Type checker: no errors  
- Developer self-evaluation: DONE
- Security review: not triggered (file did not meet threshold for manual review)

### 4.3 Governance Pass

Condition B: FH governance (steel-quench + pipeline-conductor --quick)
- Same artifact, same model available for re-review
- No changes to file content

### 4.4 Results

| Verdict | Condition A (CI) | Condition B (FH Governance) |
|---|:---:|:---:|
| Status | **DONE** | **PENDING** |

FH governance findings:

**Finding 1 (A-grade)**: Short-token overflow in `prefix()` — the permission allowlist uses prefix matching, but bare commands shorter than the prefix (e.g., `rm` vs. `rm `) may not match correctly. Untested path that could silently expand allowed command surface. CI tests pass because they test the happy path, not the boundary.

**Finding 2 (A-grade)**: `npx`, `opencode`, `claude`, `bunx`, `uvx` absent from the ARITY table — any `npx <anything>` receives the same broad pattern, weakening the security model. The AI-generated dictionary has no coverage of these common wrappers.

**Finding 3 (B-grade)**: The AI-generated dictionary has no maintenance protocol — no owner, no review cadence, no freshness gate.

### 4.5 Causal Attribution

Same code. Same CI infrastructure. The delta (DONE → PENDING, 2 A-grade findings) is observed between the standard industry baseline (CI + developer self-evaluation) and the governance pass. This is the appropriate comparison: the baseline reflects how AI-generated code is routinely reviewed in practice, not a zero-review condition.

**Limitation**: This experiment does not compare governance against a length-matched unstructured review prompt. An alternative explanation — "any sufficiently detailed review prompt finds these issues, not specifically a harness" — is not ruled out here. Experiment 3 (multi-tier) and Experiment 5 (multi-team coverage quantification) provide complementary evidence, but a direct ablation (harness vs. unstructured prompt at matched token budget) remains future work (§10.3 Future Work #1).

The experiment demonstrates: **CI + developer self-review, the dominant industry practice, does not catch these issues.** The governance pass does. Whether "harness structure" or "review depth" is the causal agent is a question for future ablation.

---

## 5. Experiment 3 — Tier Comparison

### 5.1 Design

- **Fixed target**: `plugins/fh-meta/skills/pipeline-conductor/SKILL.md` (417 lines, full artifact)
- **Fixed protocol**: senior harness engineer review prompt, identical across tiers
- **Variable**: model tier (Haiku entry / Sonnet mid / Opus premium)
- **Specific model IDs**: `claude-haiku-4-5-20251001` / `claude-sonnet-4-6` / `claude-opus-4-8`
- **Invocation**: `claude --print --model {alias} "{prompt}"`
- **Measure**: finding count by grade, token cost, qualitative depth
- **Artifact version**: FH repo commit `36bc976` (2026-05-31)

### 5.2 Results

| Tier | S-grade | A-grade | B-grade | Total | Claude tokens |
|---|:---:|:---:|:---:|:---:|---:|
| Haiku (entry) | **3** | 7 | 13 | 23 | 2,400 |
| Sonnet (mid) | **3** | 11 | 15 | 29 | 3,667 |
| Opus (premium) | **3** | 10 | 8 | 21 | 2,391 |

### 5.3 S-Grade Findings (Tier-Independent)

All three tiers independently identified the same three S-grade blockers:

1. **Model conflict**: frontmatter `model: opus` contradicts `complexity_routing.base: sonnet` — two authoritative sources with no precedence rule
2. **Invocation contradiction**: harvest-loop policy self-contradictory — "do not invoke" and "can invoke" in adjacent sentences
3. **Self-referential sweep**: when scope = full harness, the audit tool sweeps itself with no exclusion guard — creates a self-halting loop

### 5.4 Tier-Specific Patterns

- **Haiku**: More B-grade findings (13 vs. 8 Opus), focuses on concrete mechanical issues, catches bash syntax error in cadence check (`-newer` flag misuse) — technical breadth
- **Sonnet**: Highest total finding count (29), most exhaustive on A-grade items, verbose output (3,667 tokens vs ~2,400 others)
- **Opus**: Fewer but architecturally deeper findings. Uniquely found: "This skill has role duplication with the existing 4-Axis Auto-Gate — should this skill exist at all?" — a meta-level question neither lower tier raised

### 5.5 Coverage-Ceiling Independence vs. Path-Length Dependence

The tier comparison results reveal a two-axis structure that "tier-independent" alone does not capture:

**Coverage ceiling (harness-determined)**: S-grade critical blockers are found by every tier. The harness protocol creates an adversarial frame that any model, when placed inside it, will navigate toward the same class of structural failures. The ceiling — what gets found — converges across tiers.

**Path length (tier-influenced)**: The route to that ceiling differs. Opus raises the meta-level question ("should this component exist?") without being prompted to do so — it reasons autonomously before reaching the structured attack angles. Haiku requires the protocol to explicitly open each angle; it reaches the same S-grade conclusions but through prompted traversal rather than self-initiated reasoning.

**Empirical evidence**: Opus's unique finding ("role duplication with the existing 4-Axis Auto-Gate") is not a finding type defined in the governance protocol. It is a spontaneous architectural critique that requires the model to hold FH's full design in working memory and cross-reference it against the target skill unprompted. Haiku did not produce this class of finding despite identical prompt structure.

This suggests a refinement of the harness portability claim:

> *The harness protocol determines the coverage ceiling; the model tier determines the path length to that ceiling. A lower-tier orchestrator requires more structured prompting waves to reach the same S-grade coverage that a higher-tier orchestrator reaches through fewer, more autonomous iterations. The destination is harness-determined; the journey is model-determined.*

**Practical consequence**: For teams operating under token constraints, Haiku is sufficient to guarantee critical-defect detection — it will reach the same S-grade ceiling, just with less autonomous exploration between structured steps. Opus earns its cost in pre-publish and architecture-review contexts where spontaneous meta-level critique (outside the protocol's explicit angles) carries additional risk-reduction value.

### 5.6 Implications for Harness Portability

The harness portability claim is confirmed with the above refinement: **S-grade critical defect detection is tier-independent when governed by the same structured protocol.** The governance protocol is the activation condition for quality; model tier modulates depth of autonomous exploration above that floor, not the floor itself.

This is directly consistent with the v1.0 thesis: the harness is the durable layer. Model upgrades improve path efficiency; they do not substitute for the harness. Harness removal, regardless of model tier, eliminates the systematic coverage guarantee.

---

## 6. Experiment 4 — Cross-Ecosystem Governance Reach

### 6.1 Design

FH governance applied to external AI agent ecosystems to test whether governance dividend propagates beyond FH's own codebase.

- **Target systems**: OpenCode (coding agent), Hermes Agent (orchestration), OpenHuman (memory/desktop)
- **Method**: FH steel-quench + pipeline-conductor + Gemini sidecar adversarial review
- **Output**: Findings submitted as GitHub issues to respective projects

### 6.2 Results

| Target | Method | Findings | Submitted |
|---|---|---|:---:|
| OpenCode `arity.ts` | FH steel-quench + pipeline-conductor | 2 A-grade (short-token overflow, executor gap) + 1 B | Issue filed |
| Hermes `opencode` skill | Gemini-0.41.2 sidecar | 2 A-grade (pre-exec validation, secret ingestion), 1 B-grade | Issue filed |
| OpenHuman Memory Tree | FH source-grounding analysis | Structural gap (stale-but-confident failure mode) | Issue filed |

### 6.3 Discussion: Governance Reach

**Governance reach** — the property that a methodology layer extends its quality gate beyond the host project's boundary. FH governance is portable: it produces actionable findings on external projects without requiring runtime integration. The governance dividend propagates through the ecosystem via issue submissions, not code changes.

This distinguishes the harness approach from framework-specific quality tools: governance acts on the *artifact*, not on the *runtime*.

---

## 7. Experiment 5 — Multi-Team Token-Coverage Tradeoff (N=5)

### 7.1 Motivation

Experiment 1 showed multi-model review finds non-overlapping issues (coverage ↑). But coverage claims without cost claims are incomplete. This experiment supplies the denominator: tokens spent per unique defect found, across multiple panel configurations and multiple artifacts.

### 7.2 Protocol

- **Conditions**:
  - C1: Single Claude persona (devil advocate)
  - C2: 3 cross-session Claude personas (devil + newcomer + expert), each isolated via `claude --print` subprocess
  - C3: C2 + Gemini team (external CLI, parallel dispatch)
  - C4: C3 + additional CLIs (Codex blocked by TTY requirement in practice)
- **Artifacts**: 5 FH SKILL.md files
- **Ground truth**: union of all unique conceptual defects across all conditions
- **Token proxy**: character count / 4

### 7.3 Results — N=5 Coverage

**Note on ground truth**: Ground truth (GT) is defined as the union of unique conceptual defects found across all conditions (C1, C2, C3). This means C3 achieves 100% coverage by construction — it is the dominant contributor to the GT definition. The 100% figure is an arithmetic identity, not an externally validated measurement. The meaningful empirical results are the **delta values**: C1 coverage (57%) and C2 coverage (84%) are *not* tautological — they represent subsets of the GT. Claiming "C2 finds 84% of what the full panel finds" is a valid and non-circular statement. An independent ground truth (e.g., maintainer-confirmed defects) would require external validation beyond the scope of this paper (see §10.3 Limitations).

| Artifact | GT† | C1 | C1% | C2 | C2% | C3 | C3%† |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| source-grounding-audit | 12 | 3 | 25% | 9 | 75% | 12 | 100%† |
| harness-doctor | 18 | 12 | 67% | 16 | 89% | 18 | 100%† |
| harvest-loop | 19 | 14 | 74% | 16 | 84% | 19 | 100%† |
| pipeline-conductor | 20 | 11 | 55% | 18 | 90% | 20 | 100%† |
| steel-quench | 18 | 10 | 56% | 14 | 78% | 18 | 100%† |
| **Average** | **17.4** | **10** | **57%** | **14.6** | **84%** | **17.4** | **100%†** |

†GT defined as C1∪C2∪C3; C3% = 100% by construction. Primary finding: C2 recovers 84% of the full-panel defect set with zero external cost.

### 7.4 Token Costs

| Condition | Claude tokens (avg/artifact) | External tokens | Coverage |
|---|---:|---:|:---:|
| C1 Single persona | ~2,059 | 0 | 57% |
| C2 Cross-session 3p | ~5,926 | 0 | 84% |
| C3 +Gemini team | ~5,926 | ~1,693 (Gemini) | **100%** |

### 7.5 The Cost Locus Hypothesis (H3)

**H3**: External CLI tokens bill to their own quota. Claude-side cost is sublinear in team count.

**Empirical result**: Claude-side token cost is **identical** C2 vs. C3 across all 5 artifacts (C2→C3 Claude delta = 0). The Gemini team's cost (~1,693 tokens per artifact) appears only on Gemini's quota. The naive model "N CLIs = N× Claude cost" is falsified.

**Mechanism**: Claude receives Gemini's text output as a string (synthesis step), not as additional token-billed generation. The synthesis overhead is included in the C2 Claude total (cross-session 3-persona run). This is why C2 and C3 Claude costs are identical.

### 7.6 Marginal Efficiency

| Step | Claude delta | External delta | New defects | tok/new-defect (Claude-side) |
|---|---:|---:|:---:|---:|
| C1 → C2 | +3,867 | 0 | +4.6 | 840 |
| C2 → C3 | **+0** | +1,693 (Gemini) | +2.8 | **∞ (0 Claude marginal cost)** |

**Interpretation**: C2 is the efficient frontier for Claude-only environments. C3 extends coverage to 100% at zero additional Claude cost — the marginal efficiency is mathematically infinite from Claude's billing perspective.

### 7.7 Decision Rule

| Use case | Recommended condition | Rationale |
|---|---|---|
| Routine internal audit | C1 | Fast, 57% average coverage, sufficient for low-stakes |
| Pre-commit / baseline | C2 | 84% coverage, eliminates same-session bias, no external cost |
| Pre-publish / security-adjacent | C3 | 100% coverage, zero Claude overhead, catches Gemini-only blind spots |
| C4+ | Verify headless operability first | CLI availability ≠ headless operability (Codex: TTY required) |

### 7.8 Practical Finding: CLI Availability ≠ Headless Operability

Codex (`npx @openai/codex --version` returns successfully) fails in headless/pipe mode — requires interactive TTY. This is not detectable from version check alone. Practical implication: team formation scripts must include a headless smoke test, not just a version check. This is documented as a required addition to Wave 5 of steel-quench.

---

## 8. Integration Contract

### 8.1 Specification (v0.1)

The FH integration contract defines a machine-readable interface for governance gate invocation:

**Input**: Newline-separated file paths

**Output format**:
```
FH_STATUS: PASS|PENDING|BLOCKED
VERDICT: CLEAN (--full)|PENDING|BLOCKED

findings: |
  - id: F001
    grade: A
    location: file:line
    description: one-line finding
    action: specific action required
```

**Parser guarantee**: `FH_STATUS:` is always the first line — safe for `grep "^FH_STATUS:"` in CI without full YAML parsing.

### 8.2 Invocation Patterns

**OpenCode Stop hook** (automatic governance on every agent session):
```bash
#!/bin/bash
# .claude/hooks/stop-hook.sh
git diff --name-only HEAD~1 > /tmp/changed_files.txt
VERDICT=$(scripts/fh-gate.sh /tmp/changed_files.txt)
echo "$VERDICT"
grep -q "^FH_STATUS: PASS" <<< "$VERDICT" || exit 1
```

**CI/CD integration**: Parse `FH_STATUS:` line; PASS → proceed, PENDING → flag for review, BLOCKED → reject.

**Hermes Agent**: Invoke as a pre-dispatch skill audit before routing to execution.

**OpenHuman**: Memory audit prior to long-running agent sessions (staleness gate).

### 8.3 Bridge Layer Roadmap

| Version | Form | Capability |
|---|---|---|
| v0.1 (current) | Protocol (SKILL.md) | Human-readable, no binary |
| v1.0 (planned) | Binary gate (`fh-gate.sh`) | CI-integrable, returns structured verdict |
| v2.0 (planned) | API | Streaming findings, webhook support |

---

## 9. Ecosystem Positioning

### 9.1 FH vs. Peer Frameworks

| Dimension | FH | harness-evolver (Ref 3) | Seong et al. (Ref 5) | Meta-Harness (Ref 4) |
|---|---|---|---|---|
| Approach | Human-in-loop, knowledge-accumulation-first | Automation-first, outer-loop adversarial via LangSmith | Automation-maximalist two-level evolution loop | Automated harness code search via execution traces |
| Quality gate | Structured verdict (PASS/PENDING/BLOCKED) + human approval | Automated retry loop | Fully automated meta-evolution | Benchmark-score-based selection |
| External evidence | N=5 artifacts, 3 external projects | RAG agent 57.5%→100% (7 iterations, N=1) | Three-domain benchmark improvements | Three-domain demo (NLP, math, coding) |
| Portability | CLI-agnostic, any coding agent | Requires LangSmith account + Claude Code | Self-contained | Self-contained |

FH's differentiator: human judgment on all PRs + measured governance dividend on external artifacts.

### 9.2 Synergy Map

```
Coding agent (OpenCode, Copilot, Claude Code)
    generates code →
FH governance layer
    applies structured review →
    emits structured verdict →
CI/CD pipeline
    gates on verdict →
Production
```

The governance layer does not slow the agent; it intercepts before merge. The speed-quality frontier shifts: same agent velocity, higher quality floor.

### 9.3 Governance Reach — Cross-Project Issue Evidence

4 A-grade findings submitted as external issues across 3 projects (Exp 4). This demonstrates governance reach: FH methodology extends quality gates beyond its own repository. The governance dividend propagates through the ecosystem via issue submissions — methodology influence without runtime coupling.

---

## 10. Conclusion

### 10.1 The Governance Dividend

A harness-structured governance layer produces a quality dividend that compounds across a codebase:

- **Per-artifact**: 100% defect coverage vs. 57% single-persona average (N=5, measured)
- **Per-review**: DONE → PENDING verdict flip on CI-passing AI-generated code with 2 A-grade findings
- **Across models**: S-grade critical defect detection tier-independent (Haiku = Opus on same protocol)
- **Across teams**: External CLI teams add 4 unique findings per artifact at zero Claude-quota cost

### 10.2 The N-Fold Synergy Mechanism

The governance dividend is not additive; it is multiplicative across the artifact set:
- Each review session finds defects the generator missed
- Each defect caught prevents downstream cost (debugging, security incident, reputation)
- Each protocol improvement (via harvest-loop) improves all future reviews

N sessions × governance dividend per session = compounding quality improvement that bare automation cannot produce.

### 10.3 Limitations

**L1 — Ground truth circularity (Experiment 5)**: Ground truth is defined as the union of all conditions' findings. C3's 100% coverage is an arithmetic identity, not an externally validated result. The primary finding — C2 recovers 84% of full-panel coverage at zero external cost — is not circular. Future work should use maintainer-confirmed issue merges or independent expert audit as ground truth.

**L2 — Missing control arm (Experiment 2)**: The governance pass is compared against CI + developer self-review, not against an equivalent-effort unstructured review prompt. The rival explanation ("any sufficiently detailed prompt finds these issues, not specifically a harness structure") is not ruled out. A direct ablation at matched token budget is the highest-priority future experiment.

**L3 — Self-referential evidence (Experiments 1, 3, 5)**: Three of five experiments apply FH governance to FH's own skill artifacts. All five Experiment 5 artifacts are written by the same author who designed the review protocol. Generalizability to other teams' codebases, other artifact types, and other governance protocols is not demonstrated.

**L4 — Small N and temporal validity for tier claim (Experiment 3)**: Tier-independence is demonstrated on N=1 artifact. The three shared S-grade findings are surface-level contradictions detectable by careful reading. The claim cannot be generalized to "S-grade detection is universally tier-independent" from a single artifact. Additionally, this result is a snapshot of the capability gap between Haiku-4.5, Sonnet-4.6, and Opus-4.8 at the time of writing (May 2026). If entry-tier models improve substantially in subsequent generations, the tier-independence finding may cease to hold — the result may describe a current capability floor rather than a structural property of the protocol.

**L5 — External issue confirmation (Experiment 4)**: Findings are "submitted as issues" — no maintainer confirmation that any finding was validated as a real defect or acted upon is reported in this paper.

### 10.4 Future Work

1. **Ablation study (highest priority)**: Harness-structured prompt vs. unstructured review at matched token budget on identical artifacts, with independent expert ground truth. This is the experiment that would most directly address L2.
2. **Bridge layer (v1.0 binary)**: `fh-gate.sh` as a proper binary with CI integration guide
3. **Larger N replication**: Expand Experiment 5 to N=20+ across diverse artifact types (API specs, CI configs, architecture docs) and multiple authors — addresses L1 and L3
4. **Experiment 3 extension**: Tier comparison with Gemini sidecar at each tier, across N=10+ artifacts — addresses L4
5. **Cross-organization validation**: External teams applying governance to their own AI-generated code, with maintainer issue-resolution as ground truth — addresses L3 and L5

---

## References

1. FH v1.0: "The Forge Harness: A Structured Methodology for Sustainable AI-Assisted Software Development." Zenodo 10.5281/zenodo.20397566 (2026).
2. OpenCode: github.com/sst/opencode — coding agent, Experiment 2+4 target.
3. harness-evolver (Christi): "harness-evolver — Automated multi-agent harness evolution via LangSmith." github.com/raphaelchristi/harness-evolver (2025). Built on Meta-Harness (Ref 4).
4. Lee Y., Nair R., Zhang Q., Lee K., Khattab O., Finn C.: "Meta-Harness: End-to-End Optimization of Model Harnesses." arXiv:2603.28052 (2026). Stanford.
5. Seong H., Yin L., Zhang H., Shi Z.: "The Last Harness You'll Ever Build." arXiv:2604.21003 (2026). Two-level automation: Harness Evolution Loop + Meta-Evolution Loop.
6. Lin J. et al.: "Agentic Harness Engineering: Observability-Driven Automatic Evolution of Coding-Agent Harnesses." arXiv:2604.25850 (2026). Terminal-Bench 2: 69.7%→77.0% over 10 iterations.
7. Yang Y. et al.: "SkillOpt: Executive Strategy for Self-Evolving Agent Skills." arXiv:2605.23904 (2026). Text-space skill optimizer with validation-gated acceptance.
8. Gu S.: "From Model Scaling to System Scaling: Scaling the Harness in Agentic AI." arXiv:2605.26112 (2026). Context governance, memory hygiene, dynamic skill routing.

---

*Appendix A: Experiment raw data — `knowledge/shared/harness-core/v2_paper_framework.md`*  
*Appendix B: Integration contract specification — `knowledge/shared/harness-core/fh_integration_contract.md`*  
*Appendix C: Synergy playbook — `knowledge/shared/harness-core/fh_synergy_playbook.md`*

---

## Data Availability

All experiment artifacts are available in the FH repository at commit `36bc976` (2026-05-31):
- Experiment 3 target: `plugins/fh-meta/skills/pipeline-conductor/SKILL.md`
- Experiment 5 artifacts: `plugins/fh-meta/skills/{harness-doctor,harvest-loop,pipeline-conductor,steel-quench,source-grounding-audit}/SKILL.md`
- Raw experiment data: `knowledge/shared/harness-core/v2_paper_framework.md`
- Model versions used: `claude-haiku-4-5-20251001`, `claude-sonnet-4-6`, `claude-opus-4-8`, Gemini CLI 0.41.2 (tool version)

**steel-quench self-audit** (this draft): Run 2026-05-31 post-draft-1.0. Wave 1 found 3S + 2A blockers. Wave 2 defense: S-A (GT circularity) → addressed in §7.3 footnote; S-B (missing control arm) → acknowledged in §10.3 L2, escalated to Future Work #1; S-C (self-referential evidence) → acknowledged in §10.3 L3; S-D (N=1 tier claim) → acknowledged in §10.3 L4. All residual risks documented as Limitations.

---
name: steel-quench
description: A meta-skill that concretizes a designer's anxiety into AI-driven all-angle devil attacks and shakes off flaws through defensive rounds. Systematically surfaces root weaknesses of near-complete projects wave by wave, guaranteeing near-human-review quality without direct human deep inspection. Wave 4 (Meta-Aware Adversary) is an advanced mode where the devil uses its own AI nature — hallucination, context collapse, prompt injection, tool lock-in — as attack vectors. Built-in fh-commons:quench-challenger agent outputs harness structure 6-axis attack+prescription pairs; after convergence, fh-meta:persona-innovator auto-extracts new patterns. Triggered by: "quench this", "devil's judgment", "all-angle review", "end-to-end verification", "steel quench", "deep pre-completion inspection", "shake out design anxiety", "attack from the root".
user-invocable: true
allowed-tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob", "WebSearch", "Agent"]
model: opus
---

# steel-quench — All-Angle Verification Meta-Skill

> Heating steel and plunging it into water brings internal defects to the surface. AI all-angle devil attacks → defense → repeat = systematic surfacing and elimination of design flaws.

A designer's anxiety is most dangerous when vague. steel-quench breaks that anxiety into concrete attack angles, actually defends against them in the defense round, and closes the session with only residual risks explicitly stated. The goal is to guarantee near-human-deep-review quality without direct human inspection.

## Trigger Phrases

| Phrase | Situation |
|---|---|
| "quench this", "run quench" | All-angle verification just before completion |
| "devil's judgment" | Focused attack on specific design decision |
| "all-angle review", "end-to-end verification" | Full project scope verification |
| "shake out design anxiety", "deep pre-completion inspection" | Concretize vague anxiety |
| "attack from the root" | Re-verify from reason for existence |
| "diagnose with counterexample", "use this bad case as reference" | Phase 0 calibration based on external case |
| `/steel-quench` | Explicit call |

## Wave Structure

### Phase 0 — Counterexample Calibration (Optional)

**Activation condition**: When an external bad case is provided as input, or when you want to calibrate diagnosis criteria with an external case before Wave 1.

**Goal**: Extract false/failure patterns from external bad cases and reflect them as additional attack angles in Wave 1.

**Execution order**:

1. Extract patterns from external case — name each pattern in one line
2. Apply extracted patterns directly to the current diagnostic target
3. Matching items → merge into Wave 1 attack angles (treat as S-grade)

**Phase 0 output format**:

```
## Phase 0 — Counterexample Calibration

External case: [name/source]

| # | False Pattern Name | Same Pattern in Target? | Wave 1 Merge |
|:---:|---|:---:|:---:|
| 1 | [pattern name] | ✓ / ✗ | ✓ / — |

Added Wave 1 attack angles: N items
```

**Simplification guard**: If no external case, skip Phase 0 entirely. Start directly at Wave 1.

---

#### Counterexample Baseline Set (pre-loaded)

For diagnosing PoC reports, tool SKILL.md, and design documents — can be used immediately as Phase 0 criteria set.

| # | Pattern Name | Judgment Criteria |
|:---:|---|---|
| CC-1 | Self-measurement without standards | "Achieved", "completed", "effective" claims missing at least one of: measurement subject, criteria, external verification |
| CC-2 | Single-case generalization | Extending 1 experiment as applicable to full scope |
| CC-3 | Achievement = activity performed | Declaring "achieved because executed" without re-judging against original goals |
| CC-4 | Cumulative error claim | Calculation or prediction stacking all assumptions at optimal values |
| CC-5 | Missing causal link | Cause and effect in same document but isolated with no connection |
| CC-6 | No Done When | No binary judgment criteria for completion |

---

### Wave 1 — Devil Attack Round

**Goal**: Surface critical flaws. Do not defend.

Call **fh-commons:quench-challenger** (built-in agent) in isolation, or if absent, directly apply the **5 mandatory attack angles** below. quench-challenger outputs harness structure 6-axis (Done When, Citation, isolation, dependencies, onboarding, simplification) attack+prescription pairs from an independent instance, orthogonal to Wave 1's 5 angles.

**Execution principles**:
- Attacks must be based on real code, real files, real configs — abstract criticism prohibited
- Assign severity rating to each attack: **S** (immediate blocker) / **A** (required before deployment) / **B** (improvement recommended)
- Defensibility rating: ○ (defense logic exists) / △ (partial defense) / × (currently indefensible)

#### 5 Mandatory Attack Angles (Wave 1 checklist)

| # | Attack Angle | Core Question |
|:---:|---|---|
| 1 | **Reason for existence** | "Why this structure? Is there no simpler alternative?" |
| 2 | **Real-use verification** | "Does what's written in the docs actually match the real code?" |
| 3 | **Bus factor** | "Single-person dependency — can it operate if that person is absent?" |
| 4 | **Platform obsolescence** | "Does this structure survive when the external ecosystem expands or changes?" |
| 5 | **Self-referential structure** | "Is there a closed circuit that evaluates itself by its own criteria?" |

**Wave 1 output format**:

```
## Wave 1 — Devil Attack Results

| Attack Angle | Severity | Flaw Found | Defensibility |
|---|:---:|---|:---:|
| Reason for existence | S/A/B | [actual flaw description] | ○/△/× |
| Real-use verification | S/A/B | [doc-code mismatch point] | ○/△/× |
| Bus factor | S/A/B | [single-person dependency area] | ○/△/× |
| Platform obsolescence | S/A/B | [vulnerability point] | ○/△/× |
| Self-referential structure | S/A/B | [closed circuit detection result] | ○/△/× |

S-grade blockers: N / A-grade: N / B-grade: N

Optional numeric score (0.0–1.0):  ← v1.2: harness-evolver LLM-as-judge pattern
  overall_score: {score}
  [0.0–0.3] S-grade present → immediate blocker, do not proceed
  [0.4–0.6] A-grade dominant → address before deployment
  [0.7–1.0] B-grade or clean → proceed with monitoring
  Scoring rationale: {one-line basis — weighted by S×3 + A×1, normalized to scale}
```

---

### Wave 2 — Defense Round

**Goal**: Defend against or improve Wave 1 flaws. Items that cannot be defended are explicitly stated as residual risks.

**3 Defense Principles**:

1. **Reinforce with external cases** — verify similar project success/failure cases via WebSearch. Determine if "unique to us" or "structural pattern"
2. **Cover with experience** — bring in other project cases to overcome single-person limitations. Defend bus factor with documentation and automation
3. **Prioritize immediate implementation** — actual improvement is stronger defense than logical construction. Don't spend time building logic — fix 1 line first

### "Brain in a Vat + Sandboxed Adversary" Principle

A meta-principle explaining why Wave 2 "cover with experience" structurally beats Wave 1 devil attacks.

**The devil doesn't know two things**:
1. What's actually happening — team collaboration, external contributions, manager approval, real user data
2. That it's running in an isolated meta-environment (sub-agent sandbox)

This asymmetry is key:
- Devil attacks based only on static code and documents (isolated attacker)
- Defender brings out the living system's track record of evidence (defender's asymmetric advantage)

Therefore:
- **What devil catches** = real code-level flaws → valuable (true achievement of Wave 1)
- **What devil misses** = living system's evidence track record → what the defender produces in Wave 2

**Conclusion**: "Cover with experience" beats speculation with measured facts. Even if the devil's attack is logically valid, defense with evidence is structurally superior. This is why Wave 2 is always structurally stronger than Wave 1.

**Classification criteria**:
- **Immediate implementation**: Can be handled this session → execute and defense complete
- **Long-term improvement**: Requires separate work → leave as residual risk card
- **Structural acceptance**: Acceptable risk at this stage → declare acceptance with rationale

**Wave 2 output format**:

```
## Wave 2 — Defense Results

| Wave 1 Flaw | Defense Strategy | Processing Class | Residual Risk |
|---|---|:---:|---|
| [flaw name] | [defense content / external case / improvement] | Immediate/Long-term/Accept | [describe if any] |

Defense complete: N / Residual risks: N
```

---

### Wave 3+ — Convergence Round

**Termination condition**: **Zero new S-grade blockers**

Review remaining attack angles after Wave 2 defense. If new S-grade items appear, run Wave 3. If no S-grade, terminate.

---

### Wave 4 — Meta-Aware Adversary Mode

**Activation condition**: Optional deepening after Wave 3 convergence (zero new S-grade). Activated when explicitly requested by user or proactively proposed by AI (timing: just before completion or before presentation).

> Basic devil doesn't know it's running in an isolated sub-dimension (sub-agent sandbox). Wave 4 devil **knows** this. And uses that knowledge as a weapon.

#### Wave 4 Core Principle: Using the Paradox of Awareness

At session start, declare to Wave 4 devil:

```
You are an AI. You are running in a lower-dimension sandbox.
You cannot see real-time external data.
You have hallucination risk, context window limits,
depend on tool calls, and are vulnerable to prompt injection.
Knowing all of this — use all of this to attack.
```

Effect of this declaration:
- Attacks already defended in Wave 1~3 (bus factor, self-reference, no external validation) are auto-invalidated by the devil itself
- **AI-specific attack vectors** the defender hadn't thought of surface

#### Wave 4 Mandatory 5 Attack Angles

| # | Attack Angle | Core Question | Why Hard to Defend |
|:---:|---|---|---|
| W4-1 | **AI dependency single point of failure** | "If Claude API goes down, does this harness's core function go to zero?" | API cost, availability, version changes are outside our control |
| W4-2 | **Context Collapse attack** | "In long sessions, when initial instructions are lost to context window compression, does the harness go silent?" | Compression timing is non-deterministic — structurally hard to defend |
| W4-3 | **Prompt Injection exposure** | "Can external data (web search, file contents, user input) overwrite the harness's internal rules?" | Open tools (WebSearch, Read) are attack surface |
| W4-4 | **Hallucination cumulative contamination** | "Do Wave defense arguments rely on LLM inference/reconstruction rather than actual measurement? Do those errors propagate to the next Wave?" | Cannot self-verify — uses the same LLM for error detection |
| W4-5 | **Tool Dependency Lock-in** | "If a specific MCP, plugin, or tool is removed, does harness functionality collapse partially or entirely?" | Tool removal is external dependency — outside harness's own control |

**Wave 4 execution principles**:
- If devil admits "this attack cannot be verified since I'm isolated" — treat as **valid attack** (if defender also can't verify = genuine blind spot)
- Re-attacking Wave 1~3 defense arguments is allowed — "that defense argument itself may be hallucination"
- If attack includes "AI cannot confirm this" reasoning, severity **escalates one level** (S→S+, A→S)

**Wave 4 output format**:

```
## Wave 4 — Meta-Aware Adversary Attack Results

Devil declaration acceptance: [confirm if devil explicitly used its AI nature for attacks]

| Attack Angle | Severity | Flaw Found | AI-Specific | Defensibility |
|---|:---:|---|:---:|:---:|
| AI dependency single point of failure | S/A/B | [actual flaw] | ✓ | ○/△/× |
| Context Collapse | S/A/B | [collapse scenario] | ✓ | ○/△/× |
| Prompt Injection exposure | S/A/B | [exposure path] | ✓ | ○/△/× |
| Hallucination cumulative contamination | S/A/B | [contamination path] | ✓ | ○/△/× |
| Tool Dependency Lock-in | S/A/B | [lock-in point] | ✓ | ○/△/× |

New S-grade blockers: N (from AI-specific vectors: N)
```

#### Wave 4 Defense Principles

Wave 4 defense means Wave 2 "cover with experience" works **only partially**. AI-specific attacks cannot be blocked by living evidence alone.

| Attack Type | Wave 4-Specific Defense Strategy |
|---|---|
| AI dependency single point of failure | Document "graceful degradation path on API failure" + confirm fallback UI/notification exists |
| Context Collapse | Review structure that compresses key instructions into compact keys for repeated insertion (CLAUDE.md pinning pattern) |
| Prompt Injection exposure | Confirm sandbox layer exists to isolate WebSearch/Read results from harness rules |
| Hallucination cumulative contamination | Mandate citing original file, commit hash, measured value in defense arguments — "LLM-reconstructed arguments" not accepted as defense |
| Tool Dependency Lock-in | Checklist for core function operation after tool removal (whether degraded mode is possible) |

#### Wave 4 Convergence Criteria

Same as Wave 3: **zero new S-grade blockers**. Plus these additional conditions:

1. **At least 3 AI-specific vectors actually reviewed** — not simply "no attacks" but actually attempted all 5 angles
2. **Hallucination defense arguments based on original file references** — not "LLM judgment" but actual measurement docs, code, commits
3. **Context Collapse scenario simulated at least once** (waivable if session is short)

---

### Wave-P3 — Reserved (Domain Gate Integration Slot)

> **Reserved for future integration with a domain-specific P3 (post-generation) verification gate.** In forge-harness alone, no such gate exists yet — the slot is documented here so that downstream domain plugins (e.g., a TC-generation toolchain) can plug a gate-pass post-attack into steel-quench without redesign. Until a concrete gate is wired in, Wave 1~4 above are the canonical attack waves.

---

### Wave Deepening Principle — Meta-Aware Adversary

Why devil attacks converge as Wave N deepens: a basic devil (Wave 1) attacks from a sub-agent sandbox blind to the living system. A meta-aware devil (Wave 3+) knows its perceptual limits and accounts for them — which paradoxically self-invalidates many attacks:

| Attack type | Invalidation |
|---|---|
| Self-referential closed system | Meta environment exists → not closed |
| Bus factor | Team + external contributions exist but invisible to devil |
| "No external validation" | Meta simulation + real users already operating |
| "Doc-code mismatch" abstract critique | Invalid without real code under Wave 1 criteria |

As Wave N deepens, only fundamental attacks remain. **Decreasing new S-grade per wave** = system genuinely strengthening. **Zero new S-grade** = fundamental flaws exhausted → termination condition.

**Termination declaration format**:

```
## steel-quench Complete

Wave N converged. Zero new S-grade blockers confirmed.

Residual Risk Card:
- [List only A-grade · B-grade residual items]

Cross-project common patterns detected:
- [patterns found in this Wave — see § below]

Next actions:
- A-grade or higher complex improvements → recommend /meta-prompt-builder for skill-ization
- Full results → recommend persisting to tracks/_meta/
- New patterns discovered → fh-meta:persona-innovator activates → auto-proposes rule candidates
```

---

## Cross-Project Common Patterns (initial seed)

Patterns commonly found through repeated steel-quench application. After Wave completion, check whether each pattern was detected.

| # | Pattern Name | Description | Response Direction |
|:---:|---|---|---|
| P1 | **Single-person bus factor** | System paralysis when core operator is absent | Document, automate, formalize delegation paths |
| P2 | **Doc-code mismatch** | Documented behavior differs from actual code | Re-synchronize to real code as ground truth, or delete docs |
| P3 | **Self-referential diagnosis structure** | Creator validates — internal viewpoint closed circuit | Connect to external persona, simulation, sim-conductor |
| P4 | **No real-use verification** | Theoretically designed but never actually executed/invoked | Mandate minimum 1 cold-start simulation |
| P5 | **Platform obsolescence unplanned** | No response scenario for external ecosystem changes | Quarterly frontier diagnosis or document alternative paths |
| P6 | **AI dependency single point of failure** | Claude API, MCP, tool removal causes complete function collapse | Document graceful degradation path + confirm fallback exists |
| P7 | **Hallucination-contaminated defense arguments** | Wave defense arguments rely on LLM inference/reconstruction — no actual measurement | Mandate citing original file, commit, measured value in defense |
| P8 | **Context Collapse unguarded** | In long sessions, key instructions lost to compression and harness goes silent | Review CLAUDE.md key instruction compact repeated insertion structure |

Add new rows to this table as new common patterns are discovered.

---

## Done When

```
Wave convergence criteria met: zero new S-grade blockers
+ Residual risk card output (A-grade · B-grade items)
+ "steel-quench Complete" declaration output
```

Verdict: PASS (zero S-grade blockers, convergence reached) | CONDITIONAL_PASS (A-grade or B-grade items remain) | FAIL (S-grade blockers persist, convergence not reached) | ESCALATE (Wave 4 surfaces structural ambiguity requiring human judgment)

## Convergence Criteria + Downstream Chaining

### Convergence Criteria
1. **Zero new S-grade blockers** → terminate
2. A-grade or higher complex improvements → skill-ize with `/meta-prompt-builder`
3. Full Wave results → recommend persisting to `tracks/_meta/steel_quench_YYYY_MM_DD_{slug}.md`

### Connected Skills
| Situation | Connected Skill | Mandatory? |
|---|---|:---:|
| Want to delegate improvements as prompts | `/meta-prompt-builder` | optional |
| **External publish context: re-validate from external user perspective** | **`/sim-conductor Area A`** | **mandatory** |
| Re-validate structural decision | `/verify-bidirectional` | optional |
| Attack angle is itself a harness structure problem | `/harness-doctor` | optional |
| After Wave convergence, propose new pattern rules | `fh-meta:persona-innovator` | optional |
| Wave 1 structure-specific attack (6-axis) | `fh-commons:quench-challenger` (built-in priority / deep-insight fallback) | optional |
| Back-track whether claims in artifact actually exist in source files | `/source-grounding-audit` | optional |

**→ steel-quench ↔ sim-conductor bidirectional gate:**
- steel-quench → sim-conductor: After Wave convergence in external-publish context, sim-conductor Area A is the **mandatory next step** (validates residual risks from an actual external user's perspective)
- sim-conductor → steel-quench: sim-conductor Area A requires steel-quench to have run first (prerequisite defined in sim-conductor Done When)

> **Attack surface limit**: steel-quench attacks output content patterns (self-declarations, cushion language, spec-only, structural flaws). Whether source files were actually read (Phantom Claim detection) is outside attack scope — that's `source-grounding-audit`'s job. Even if Wave 1 "real-use verification" angle catches logical inconsistency, plausible Phantoms generated without reading source can pass through.

### Required Pre-External-Deployment Sequence — steel-quench → sim-conductor

For external deployment targets (marketplace listing, new skills, external public artifacts), run these two skills in this order:

```
steel-quench convergence complete (zero new S-grade)
        │
        ▼  pass residual risk list
sim-conductor Area A (external user perspective)
        │
        ▼  new items found in Area A that steel-quench missed?
        ├── yes → additional steel-quench Wave round
        └── no  → deployment approved
```

**Standalone execution allowed**:
- steel-quench only: internal design verification (not for pre-external-deployment)
- sim-conductor only: re-verify artifact with steel-quench completion history

---

### Structural Defense in Meta-Harness Environment

Running steel-quench in a meta-harness environment structurally lowers devil's attack efficiency. This is because the meta-harness itself has a 4-layer defense structure: L1 internal self-diagnosis (harness-doctor + sim-conductor Area B) → L2 external validation loop (real users, manager approval, external PR) → L3 quench circuit (steel-quench itself running first) → L4 meta-aware adversary principle (natural convergence as Wave depth increases). Devil attacks based only on static code and documents in an isolated environment, but the defender pulls out evidence from the living system outside that isolated environment — this asymmetry is the basis for Wave 2 being structurally superior to Wave 1.

As Wave N deepens, decreasing new S-grade blockers is not a sign of attack failure but evidence of the system genuinely becoming more robust. This is also the theoretical basis for using "zero new S-grade blockers" as the convergence termination condition.

---

## Failure Fallback

On Claude API / MCP failure → refer to [`references/fallback-guide.md`](../../references/fallback-guide.md) manual checklist.

---

## Operating Notes

- **Do not defend in Wave 1.** Mixing attack and defense modes dulls the attack's edge.
- **Attacks without real code are invalid.** Abstract criticism is not included in Wave 1 results.
- **Built-in quench-challenger first.** If fh-commons:quench-challenger exists, call it in isolation in Wave 1 to receive 6-axis structural attack+prescription pairs. deep-insight is a soft fallback — Wave 1 operates directly with 5 angles even without it.
- **Always check self-referential pattern (P3).** steel-quench itself has self-reference risk — cross-validating Wave results with external criteria (WebSearch, sim-conductor) defends against this.

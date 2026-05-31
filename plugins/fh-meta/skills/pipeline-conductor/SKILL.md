---
name: pipeline-conductor
description: Chains the four core FH verification pipelines (harvest-loop → steel-quench → source-grounding-audit → sim-conductor) into a single gated sweep. Accepts a scope (single skill, specific asset, full harness) and aggregates results into one structured report. Supports --quick mode (steps 2+3 only) and --full mode (all four steps). Triggered by "run the full pipeline", "chain all verifications", "end-to-end sweep", "pipeline-conductor", or "verify everything".
user-invocable: true
allowed-tools: ["Read", "Write", "Bash", "Grep", "Glob", "Agent"]
model: opus
---

# pipeline-conductor — Chained Verification Sweep

Chains the four standalone FH verification pipelines into a gated sequence. Each step receives the previous step's verdict before proceeding. Aggregates all findings into a single structured report at the end.

The gap this closes: harvest-loop, steel-quench, source-grounding-audit, and sim-conductor are each invocable independently but have no automatic hand-off between them. Running them sequentially by hand loses inter-step signal — a FAIL in step 2 should block step 3 rather than silently continuing. pipeline-conductor enforces that ordering.

## Triggers

- `/pipeline-conductor`
- "Run the full verification pipeline", "chain all four verifications"
- "End-to-end sweep before I push", "verify everything at once"
- "I want to run all the checks in order", "do a full harness review"
- "Run quench then grounding then sim", "chain the pipelines"
- "Full pipeline on this skill", "sweep this asset before release"

> **Disambiguation**: "run the pipeline" alone may trigger harvest-loop (which uses identical phrasing). Prefer "run pipeline-conductor" or "chain all verifications" for unambiguous activation.

## Modes

| Flag | Steps run | When to use |
|---|---|---|
| `--full` (default) | Steps 1 → 2 → 3 → 4 | Complete verification sweep |
| `--quick` | Steps 2 → 3 only | Fast adversarial + phantom check; skip knowledge loop and simulation |
| `--no-sim` | Steps 1 → 2 → 3 | Skip sim-conductor (e.g., no sim environment available) |

**Mode qualifier on verdicts**: `CLEAN (--quick)` and `CLEAN (--no-sim)` do not qualify as pre-release gates. Only `CLEAN (--full)` is sufficient for external publish or PR approval.

## Verdict Format

Every step emits exactly one verdict line before handing control to the next step:

```
Verdict: PASS | CONDITIONAL_PASS | FAIL | ESCALATE
Basis:   [one-line summary of deciding factor]
```

| Verdict | Meaning | Chain behavior |
|---|---|---|
| `PASS` | Step complete, no blocking issues | Proceed to next step |
| `CONDITIONAL_PASS` | Issues found but none are blockers; must be resolved before final report | Capture items, proceed to next step; flag in final report |
| `FAIL` | Blocking issue found | Halt chain, surface to user immediately |
| `ESCALATE` | Ambiguous state requiring human judgment | Pause chain, present three options to user |

`CONDITIONAL_PASS` means proceed, not skip. Items captured under `CONDITIONAL_PASS` accumulate into the final report's Pending section and must be addressed before the sweep is considered clean.

`FAIL` halts the chain. The user decides whether to fix-and-resume or abandon the sweep.

`ESCALATE` pauses the chain. The user chooses one of three paths — the chain resumes or closes based on their decision.

### ESCALATE Handling

When any step returns `ESCALATE`, present:

> "Step N returned ESCALATE: [basis]. Choose:
> (a) Make a decision — state your judgment and I will incorporate it and continue the chain.
> (b) Accept and continue — mark this as PENDING in the report and proceed to the next step.
> (c) Abort — close the sweep as BLOCKED."

- Option (a): User provides judgment → incorporate as resolution note → re-evaluate step gate with decision context → continue chain.
- Option (b): Mark ESCALATE item as PENDING → continue chain from step N+1.
- Option (c): Halt, output BLOCKED report with ESCALATE item in blocking section.

---

## Step 0. Scope, Mode, and Translation

Determine the following before running any pipeline step.

**1. Scope**: What is being verified?
   - Single skill: path to `SKILL.md` (e.g., `plugins/fh-meta/skills/foo/SKILL.md`)
   - Specific asset: file or directory path
   - Full harness: all assets under `plugins/` and `templates/`

**2. Mode**: `--quick`, `--no-sim`, or `--full` (default)

**3. Branch**: Current git branch (used for regression guard and report header)

If scope is not specified, ask:
> "What should I sweep? (e.g., a specific skill path, a directory, or the full harness)"

Do not infer scope — a wrong scope produces misleading verdicts.

### Scope Translation Table

The four constituent skills use heterogeneous scope models. Translate the pipeline scope to each skill's invocation form before running any step:

| Pipeline scope | harvest-loop (Step 1) | steel-quench (Step 2) | source-grounding-audit (Step 3) | sim-conductor (Step 4) |
|---|---|---|---|---|
| Single SKILL.md | Check session findings relevant to this skill; propose mode only | Adversarial attack on this SKILL.md | Back-trace claims in this SKILL.md to declared sources | Area D (artifact review) on this SKILL.md |
| Specific directory | Check session findings in this domain | Attack all SKILL.md files in directory | Back-trace all claims in directory | Area A + Area D on the domain |
| Full harness | Check all recent session findings | Attack all harness assets under scope | Back-trace all claims across harness | Area A + Area B + Area D |

### Step 0 Output

```
pipeline-conductor — Sweep Plan
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Scope:  {scope}
  Mode:   {--full / --quick / --no-sim}
  Branch: {branch name}
  Steps:  {1 → 2 → 3 → 4 / 2 → 3 / 1 → 2 → 3}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Proceed? (Y: run / N: cancel)
```

---

## Step 0.5. return-path-gate — Pre-flight Chain Audit (optional)

> Recommended when scope includes core pipeline skills. Skip if return-path-gate is not installed or scope is a single non-pipeline skill.

Run `/return-path-gate --skill [scope]`. If HIGH severity OPEN chains are found in scope:

```
[Step 0.5 — return-path-gate]
  Verdict: CONDITIONAL_PASS
  Basis:   HIGH severity OPEN chains detected — sweep may produce unreliable inter-step verdicts
  Open:    [list of OPEN chains]
```

Proceed with the sweep regardless — Step 0.5 is advisory, not a chain blocker. OPEN chain findings are captured in the final report's Pending section.

---

## Step 1. harvest-loop — Knowledge Loop Check

> Skipped in `--quick` mode.

Check for harvest-loop signals in the current session. pipeline-conductor reads session context for harvest-loop findings rather than invoking harvest-loop directly — invoking harvest-loop mid-sweep would start a new harvest cycle that conflicts with the sweep's own pattern collection. If no harvest-loop run exists in this session, pipeline-conductor can invoke harvest-loop in proposal mode (`/harvest-loop`) as a pre-Step-1 option, but this is not automatic.

**What it checks**: Whether recent session learnings have been absorbed, whether duplicate skill candidates are pending, whether knowledge loop integrity issues exist in the current session.

**Invocation path**:
- If harvest-loop ran in this session: read its output and incorporate findings.
- If harvest-loop did not run in this session: output `CONDITIONAL_PASS` — knowledge loop not validated in this sweep.
- If harvest-loop auto-skipped (fewer than 3 patterns found): output `CONDITIONAL_PASS` — sub-threshold, knowledge loop not validated.

**Verdict criteria**:

| harvest-loop result | pipeline-conductor verdict |
|---|---|
| Ran this session — all steps pass, no pending patterns | `PASS` |
| Ran this session — patterns found but no blockers | `CONDITIONAL_PASS` — capture pattern list |
| Ran this session — semantic drift or loop failure detected | `FAIL` |
| Did not run this session | `CONDITIONAL_PASS` — note: knowledge loop not validated |
| Auto-skipped (< 3 patterns) | `CONDITIONAL_PASS` — note: sub-threshold, not validated |

**On FAIL**: Output the harvest-loop failure reason. Ask:
> "harvest-loop reported a blocking issue. Fix and re-run Step 1, or abort the sweep?"

**On CONDITIONAL_PASS**: Log all pending patterns or unvalidated notes. Continue to Step 2.

```
[Step 1 — harvest-loop]
  Verdict: {verdict}
  Basis:   {one-line}
  Pending: {list of items if CONDITIONAL_PASS, else "none"}
```

---

## Step 2. steel-quench — Adversarial Verification

Run steel-quench against the target scope.

**What it checks**: Design attack surface, trigger phrase collisions, over-engineered steps, self-declaration language, structural flaws surfaced by devil-advocate rounds.

**Invocation**: Run steel-quench in its standard mode. For `--quick`, this is the first step.

**steel-quench severity vocabulary** (S/A/B grade — not M/S/R):
- **S-grade**: Immediate blocker — must fix before proceeding
- **A-grade**: Required before deployment — fix before external release
- **B-grade**: Improvement recommended — non-blocking

**Verdict criteria**:

| steel-quench result | pipeline-conductor verdict |
|---|---|
| 0 S-grade findings | `PASS` |
| A-grade or B-grade findings only | `CONDITIONAL_PASS` — capture finding list |
| 1+ S-grade findings | `FAIL` |
| Wave 4 (Meta-Aware Adversary) surfaces structural ambiguity | `ESCALATE` |

**On FAIL**: Output S-grade finding(s) from steel-quench. Ask:
> "steel-quench found a blocking issue. Fix and re-run Step 2, or abort the sweep?"

**On CONDITIONAL_PASS**: Capture A-grade and B-grade findings. Continue to Step 3.

```
[Step 2 — steel-quench]
  Verdict: {verdict}
  Basis:   {one-line}
  Findings:
    S-grade: {count} — {top item or "none"}
    A-grade: {count} — {top item or "none"}
    B-grade: {count} — {top item or "none"}
```

---

## Step 3. source-grounding-audit — Phantom Claim Detection

Run source-grounding-audit against the target scope.

**What it checks**: Proper nouns, numerical values, file paths, and branching conditions back-traced to declared source files. Claims not found in source are marked Phantom.

**Invocation**: Run source-grounding-audit scoped to the same target as Steps 1 and 2.

**Load-bearing Phantom** (binary test — apply mechanically):

A Phantom is load-bearing if it appears in any of:
- `§Done When` section of the skill under audit
- Any numbered `§Step N` execution body
- `§Chains` with mandatory dispatch language (`→ Mandatory next`)

All other locations (§Triggers, advisory §Chains language, frontmatter description) are non-load-bearing by definition.

**Verdict criteria**:

| source-grounding-audit result | pipeline-conductor verdict |
|---|---|
| 0 Phantoms, all claims grounded | `PASS` |
| Phantom claims found, none load-bearing (binary test) | `CONDITIONAL_PASS` — list Phantoms |
| 1+ load-bearing Phantoms | `FAIL` |
| Grounding ambiguous (source file exists but content unclear) | `ESCALATE` |

**On FAIL**: Output the load-bearing Phantom(s). Ask:
> "source-grounding-audit found a load-bearing Phantom claim. Fix and re-run Step 3, or abort the sweep?"

**On CONDITIONAL_PASS**: Capture non-load-bearing Phantoms. Continue to Step 4.

```
[Step 3 — source-grounding-audit]
  Verdict: {verdict}
  Basis:   {one-line}
  Phantoms: {count} — {load-bearing: Y/N} — {top item or "none"}
```

---

## Step 4. sim-conductor — Pre-Deploy Simulation

> Skipped in `--quick` and `--no-sim` modes.

Run sim-conductor against the target scope.

**What it checks**: Transferability to external users, new-user entry point friction, power-user edge cases, artifact quality from an outside perspective.

**Area B cadence check** (sim-conductor Area B has a once-per-week frequency limit):

```bash
find tracks/_meta/ -name "*sim_conductor*" -newer "$(date -v-7d +%Y-%m-%d 2>/dev/null || date -d '7 days ago' +%Y-%m-%d 2>/dev/null)" 2>/dev/null | head -1
```

- Result found (Area B ran within 7 days): skip Area B → run Area A + Area D only. Capture as `CONDITIONAL_PASS` with note: "Area B skipped — within 7-day cadence limit."
- No result (Area B not run within 7 days): run Area A + Area B + Area D (scope permitting).

**Invocation**: Area A + Area B (if cadence allows) + Area D (if scope is a specific SKILL.md or document).

**Verdict criteria**:

| sim-conductor result | pipeline-conductor verdict |
|---|---|
| 0 M-tier findings across all personas | `PASS` |
| S/R-tier findings only | `CONDITIONAL_PASS` — capture finding list |
| 1+ M-tier findings from any persona | `FAIL` |
| Persona results conflict, resolution requires human judgment | `ESCALATE` |

**On FAIL**: Output M-tier finding(s) from sim-conductor. Ask:
> "sim-conductor found a blocking issue. Fix and re-run Step 4, or accept findings and close with FAIL status?"

**On CONDITIONAL_PASS**: Capture S/R-tier findings. Proceed to final report.

```
[Step 4 — sim-conductor]
  Verdict: {verdict}
  Basis:   {one-line}
  Area B:  {ran / skipped — cadence limit}
  Findings:
    M: {count} — {top item or "none"}
    S: {count} — {top item or "none"}
    R: {count} — {top item or "none"}
```

---

## Step 5. Aggregated Report

After all steps complete (or after chain halt), output the aggregated report.

```
pipeline-conductor — Sweep Report
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Scope:  {scope}
  Mode:   {mode}
  Branch: {branch}
  Date:   {YYYY-MM-DD}

  Step 0.5 — return-path-gate:       {PASS / CONDITIONAL_PASS / SKIPPED}
  Step 1   — harvest-loop:           {PASS / CONDITIONAL_PASS / FAIL / ESCALATE / SKIPPED}
  Step 2   — steel-quench:           {verdict}
  Step 3   — source-grounding-audit: {verdict}
  Step 4   — sim-conductor:          {verdict}

  Overall: {CLEAN (--full) / CLEAN (--quick) / CLEAN (--no-sim) / PENDING / BLOCKED}

  ── Pending items (CONDITIONAL_PASS steps + accepted ESCALATE) ──
  {item list, or "none"}

  ── Blocking items (FAIL steps + unresolved ESCALATE) ──
  {item list, or "none — sweep completed cleanly"}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Overall verdict logic**:

| Condition | Overall |
|---|---|
| All steps PASS | `CLEAN ({mode})` |
| Any step CONDITIONAL_PASS or accepted ESCALATE; none FAIL | `PENDING` |
| Any step FAIL or unresolved ESCALATE (option c) | `BLOCKED` |

**Mode semantics**:
- `CLEAN (--full)`: Safe to proceed with commit, PR, or external release.
- `CLEAN (--quick)` / `CLEAN (--no-sim)`: Safe for internal iteration only — not sufficient for external publish or PR approval gate.
- `PENDING`: Resolve captured items before external release.
- `BLOCKED`: Do not proceed. Fix blocking items and re-run affected step(s).

### Report Persistence

Save the report to:
```
tracks/_meta/pipeline_conductor_{YYYY-MM-DD}_{scope-slug}.md
```

If `tracks/_meta/` does not exist, output a B-grade warning and skip persistence.

---

## Resume After Fix

**After FAIL**:

1. User fixes the issue.
2. User says "resume from step N" or "re-run step N".
3. pipeline-conductor re-runs only the failed step and its gate.
4. On PASS, continues the chain from step N+1.
5. Does not re-run steps that already passed (unless user explicitly requests a full restart).

Resume is scope-bound — the scope from Step 0 is preserved across resume calls.

**After ESCALATE**:

1. Present the three options (see ESCALATE Handling above).
2. Option (a) — user provides decision: incorporate as resolution note, re-evaluate the step gate with decision context, continue chain from step N or N+1.
3. Option (b) — accept and continue: mark ESCALATE item as PENDING, continue chain from step N+1.
4. Option (c) — abort: close sweep, output BLOCKED report with ESCALATE item in blocking section.

---

## Simplification Guards

- Do not propose pipeline-conductor for single-file read tasks or exploratory sessions.
- If the user invokes one of the four constituent skills directly, do not auto-redirect to pipeline-conductor.
- If only one step is needed, guide the user to call that skill directly.
- For `--quick` mode on a trivial scope (single short SKILL.md), Steps 2+3 should complete in one pass without sub-Wave fan-out.

---

## Chains

After a `CLEAN (--full)` or `PENDING` sweep, the following are natural follow-ons:

- `field-harvest` — harvest patterns surfaced during the sweep
- `hub-cc-pr-reviewer` — if sweep was run pre-PR, feed results into PR review
- `agent-composer` — if multiple fix tasks are needed across the Pending list, compose agents to resolve them in parallel
- `return-path-gate --all` — if Step 0.5 surfaced OPEN chains, run a full chain closure audit

## Complexity Routing

```yaml
complexity_routing:
  base: sonnet
  escalate_when:
    - high_stakes      # pre-external-publish or pre-deploy sweep
    - full_revalidation # user requested "start over"
    - cross_project    # scope spans 3+ projects
  high: opus
```

---

## Done When

```
Step 0 scope confirmed and scope translation table applied
+ Step 0.5 return-path-gate pre-flight completed or explicitly skipped
+ All in-scope steps executed and verdicts emitted
+ Aggregated report output (Step 5 format)
+ Report saved to tracks/_meta/ (or skip warning issued)
+ Overall verdict qualified with mode: CLEAN (--full) / CLEAN (--quick) / CLEAN (--no-sim) / PENDING / BLOCKED
+ If BLOCKED: blocking items listed and user notified
+ If PENDING: pending items listed in report
+ If ESCALATE occurred: user presented three options; choice recorded in report
```

Verdict: PASS (all conditions met, sweep complete) | CONDITIONAL_PASS (sweep complete, pending items captured) | FAIL (chain halted, blocking items remain) | ESCALATE (chain paused, human decision required)

A sweep is not done until the Step 5 report is output. Emitting per-step verdicts without the aggregated report is incomplete.

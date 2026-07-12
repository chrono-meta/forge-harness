---
name: harness-doctor
description: Scans a project's harness structure (.claude/ directory, CLAUDE.md, rules, agents) to diagnose complexity, drift, missing files, and broken references, then suggests improvements. `--lint` flag adds language-pattern scan (self-marketing, cushion words, version brags). Triggered by "harness check", "structure diagnosis", "CLAUDE.md audit".
user-invocable: true
allowed-tools: ["Read", "Bash", "Glob", "Grep"]
model: sonnet
complexity_routing:
  base: sonnet
  high: opus
  escalate_when:
    - cold_start
    - cross_project
---

# harness-doctor — Harness Structure Diagnosis + Prescription

"A good harness gets simpler over time. If it's getting more complex, something is wrong."

Diagnoses harness structural health across 5 layers and proposes M/S/R prescriptions:

1. **L1 Structural completeness** — required file existence (CLAUDE.md · .claudeignore · .claude/)
2. **L2 Complexity** — current state vs. simplification principle (line count · unused files · duplicate definitions)
3. **L3 Drift** — rule vs. actual pattern mismatch (broken references · stale files · conflicting rules)
4. **L4 Connection diagnosis** *(FH environment only)* — meta hub ↔ field project reference consistency
5. **L5 Pattern analysis** *(FH environment only)* — skill activity · call context appropriateness · effect metrics

---

## Execution Steps

### Step 1. Confirm Diagnostic Target

Check current cwd harness file structure and determine if FH environment (tracks/ + knowledge/ + plugins/ all present).

### Step 2. L1 — Structural Completeness

| File | When Missing |
|---|---|
| `CLAUDE.md` | **M-tier** — harness entry impossible |
| `.claudeignore` | S-tier — context-doctor execution recommended |
| `.claude/` directory | M-tier (when rule files exist) |

### Step 2-E. L1-E — ETCLOVG Layer Coverage *(functional-layer lens — orthogonal to the file-presence table above)*

A harness is not only files; it is **seven functional layers** (ETCLOVG — arXiv:2606.06324, a component
taxonomy *orthogonal* to FH's 6-axis process model; cross-audit
`tracks/_audit/session_2026_06_19_harnessfix-etclovg-cross-audit.md`). FH adopts only the **taxonomy as a
coverage lens** — not the paper's scoring model. A **coverage checklist, not a mandate**: not every
harness needs all seven (a read-only doc harness needs no Execution or Governance). For each layer ask
"is there an asset covering it?"; surface gaps, let the human judge if each is real for *this* harness.

| Layer | Covers | Typical FH asset | If the gap is judged real → priority hint |
|---|---|---|---|
| **E** Execution | isolated/reproducible env, bounded autonomy | Agent-dispatch isolation · goal-quench budget | advisory |
| **T** Tooling | tool discovery / selection / gating | mcp_tool_gating · plugin-recommender | advisory |
| **C** Context | what the model sees: card, memory, retrieval | session card · CATALOG · context-doctor | advisory |
| **L** Lifecycle | loops, retries, orchestration, termination | agent-composer · goal-quench | advisory |
| **O** Observability | traces / logs / cost to diagnose failures | subagent_invocations_log · audit logs · activity log | advisory |
| **V** Verification | readiness · intermediate · final · regression checks | 4-axis gate (steel/phantom/regression_guard) | higher-stakes |
| **G** Governance | permissions · approvals · audit trails | HITL gates · public-surface gate | higher-stakes |

**Relationship to the Harness-Defect Taxonomy (below)**: ETCLOVG = *component coverage* (is the layer
present?); the Defect Taxonomy = *failure modes* (is a present layer degrading?). Orthogonal — coverage vs health.

**Check class**: judged (advisory) — the presence test is mechanical, but "is this gap real for this
harness's purpose?" is a judged call, **paired** with the human review at Step 7's M-tier gate. **Never
auto-tier a missing layer into the M/S/R report** — the priority column is a *hint only if a human
confirms the gap*, never a verdict the report emits on its own; surface each gap tagged "(human-confirm)".
(FH's own weak layer is **Observability** — retrospective audit only, no runtime layer; named in the cross-audit.)

### Step 3. L2 — Complexity Diagnosis

| Check | Verdict |
|---|---|
| CLAUDE.md ~100 lines | Normal (project) / FH threshold: 500 lines |
| CLAUDE.md 100~200 lines | S-tier warning |
| CLAUDE.md 200+ lines | M-tier — separation or reduction needed |
| 15+ `##` sections in CLAUDE.md | S-tier warning |
| SKILL.md > 300 lines AND no `SKILL_detail.md` | S-tier — propose `/salience-splitter` (governance-semantic split, not compression) |
| Rules files unreferenced in CLAUDE.md | R-tier |
| Always-loaded footprint (CLAUDE.md + every `.claude/rules/*.md` lacking `paths:` frontmatter) > 40k chars | S-tier — relocate detail rules to a non-loaded dir (e.g. `knowledge/shared/rules/`), pointers stay in CLAUDE.md |
| Always-loaded footprint > 80k chars | M-tier — same prescription, mandatory |
| **Pointer-illusion**: a CLAUDE.md "detail/detailed procedure" pointer whose target is itself an always-loaded `.claude/rules/*.md` | S-tier — the split saves zero context (rules/ auto-loads regardless); move the target out of auto-load, keep the pointer |
| weekly_audit 14~30 days elapsed | S-tier |
| weekly_audit 30+ days elapsed | M-tier |

Always-loaded + pointer-illusion checks are mechanical (found 2026-07-12 — FH itself shipped ~50k chars of rules/ behind "detail pointers" that saved nothing; the meta-harness blind spot this row closes):

```bash
# always-loaded footprint (chars): CLAUDE.md + rules files with no paths: frontmatter
T=$(wc -c < CLAUDE.md 2>/dev/null); for f in .claude/rules/*.md; do [ -f "$f" ] || continue; head -5 "$f" | grep -q '^paths:' || T=$((T + $(wc -c < "$f"))); done; echo "always-loaded: $T chars"
# pointer-illusion: CLAUDE.md pointers targeting still-auto-loaded rules files
grep -oE '\.claude/rules/[a-z_]+\.md' CLAUDE.md | sort -u | while read p; do [ -f "$p" ] && echo "ILLUSION: $p (pointed-to AND always-loaded)"; done
```

### Step 3-L. Language Lint (`--lint` mode only)

> Activate with `/harness-doctor --lint` or when harvest-loop surfaces a P10-series signal. Skipped in standard runs.

Grep-based scan of SKILL.md, agent `.md`, and doc files for self-marketing language patterns. Outputs replacement suggestions — no automatic edits.

**Detection patterns**:

| Pattern | Examples | Replacement direction |
|---|---|---|
| Self-declarations of quality | "industry-leading", "the world's first", "core skill", "best" | Delete — no external evidence |
| Version / iteration labels | "v0.3", "22nd naming round", "26th iteration", "(added 2026-05-24)" | Remove (git history manages versioning) |
| Cushion language | "easily", "instantly", "seamlessly", "without burden", "fully automated" | Replace with behavior-based description |
| Owner self-reference loops | "validated by our team", "proven internally" | Delete or replace with external evidence |
| Marketing word stacking | 3+ adjectives in one sentence | Reduce to functional description |
| Spec-only artifacts | SKILL.md or agent file missing `Done When` section | Add observable output criteria |

**Scan targets**:
```bash
find {FH_ROOT}/plugins -name "SKILL.md" | sort
find {FH_ROOT}/.claude/agents -name "*.md" | sort
find {FH_ROOT}/docs -name "*.md" 2>/dev/null | sort
```

**Detection commands**:
```bash
# version / iteration labels
grep -n "v[0-9]\+\.[0-9]\|[0-9]\+th\|[0-9]\+th iteration\|prototype [0-9]\+" {file}
# cushion language
grep -n "fully\|instantly\|full coverage\|automatically\|conveniently\|easily\|without burden\|seamlessly" {file}
# self-declaration patterns
grep -n "core skill\|world's first\|best\|most\|top\|industry-leading" {file}
```

**Output format** (per file):
```
File: {path}
  L{N}: "{original text}"
  → Suggested: "{replacement}" (reason: {pattern type})
  → Or: remove (reason: {pattern type})
```

**Lint findings** feed into Step 7 report as a separate "Language Quality" section — not mixed into structural M/S/R tiers. Lint findings are advisory: HIGH (spec-only = missing Done When, treat as S-tier) / LOW (language patterns, R-tier).

---

### Step 4. L3 — Drift Diagnosis

| Check | Tier |
|---|---|
| Broken local file references in CLAUDE.md | M-tier |
| .claude/rules files unmodified 90+ days | R-tier |
| settings.json JSON syntax error | M-tier |
| Hooks in settings.json (PostToolUse/Stop) that don't fire in Agent View | S-tier or M-tier |
| Public-surface FH recommendation or default changed — no N-shot measurement evidence traceable in session records or PR body | S-tier |
| Pre-commit-adjacent gate reads the working tree (cat/glob of a *tracked* path) with no `--staged`/`--cached`/`git show :` on that path, when its verdict is about *what's committed* | S-tier |

Hook divergence verdict: 0 hooks = Normal · 1+ hooks (session-end/Stop) = S-tier · 1+ hooks (PostToolUse file writes or external API) = M-tier (data loss risk in Agent View).

**Index-vs-worktree gate lint** (2026-06-21, gate-locality corollary — `[[feedback_gate_locality_principle]]`):
a gate whose verdict is about *what is being committed* must read the **staged index**
(`git ls-files --cached` / `git show :path`), not the working tree (`cat`/glob of a tracked file) —
else it false-PASSes a commit whose staged content ≠ disk (origin: `count_check.sh` read the worktree
while the pre-commit hook fired on the index; the sibling `regression_guard` already used `--staged`,
so the lesson existed but was non-local). Mechanical scan — in the pre-commit hook + the scripts it
invokes (+ `scripts/*-check.sh`): flag a `cat`/`<`/glob read of a tracked path with no
`--staged`/`--cached`/`git show :` on that path. **Conditional (NOT universal)**: a gate whose verdict is
about what *runs/deploys* (pre-push tests, build, an auto-fixer that rewrites the worktree) correctly
reads the working tree — a line-level `# worktree-intentional:` comment suppresses the flag. FP surface
(isolated-critic): display/log reads and untracked generated files are not violations → keep advisory
(S-tier, never M).

### Step 5. L4 — Connection Diagnosis *(FH only)*

- Tracks with no sync in 30+ days → R-tier
- CATALOG.md: 5+ open items in recent 5 sessions → S-tier
- Field project CLAUDE.md missing → S-tier
- **Knowledge cross-ref lint**: `knowledge/**/*.md` with no CATALOG.md entry → S-tier
  (index orphan — unfindable via CATALOG-first search); with no inbound reference from
  any CLAUDE.md / rules / SKILL.md / knowledge doc → R-tier (orphan page).
  Mechanical: `grep -L` filenames against CATALOG.md, then `grep -rl` for inbound refs.

### Step 6. L5 — Pattern Analysis *(FH only)*

**L5-A Skill Activity** (grep-based on session records):

| State | Criteria | Tier |
|---|---|---|
| ACTIVE | 2+ times in 30 days | Normal |
| LOW_ACTIVE | 1 time in 30 days | R-tier |
| INACTIVE_30D | 0 times in 30 days | S-tier |
| INACTIVE_90D | 0 times in 90 days | M-tier |

**L5-B Call Context Appropriateness**: Keyword grep for known misuse patterns (hub-persona-auditor in code PR context · sim-conductor without onboarding · harness-doctor self-loop). Report as "suspected (false positive possible)" — no LLM call.

**L5-C Effect Metrics**:

| Metric | OK condition | Tier if failing |
|---|---|---|
| E1 CLAUDE.md lines | Decrease or ±10 | E1_WARN if +50 lines |
| E2 Complexity ratio | ≤100 lines/skill | E2_WARN (≤200) / E2_FAIL (>200) |
| E3 CATALOG open consumption | ≥50% in 30 days | — |
| E4 harvest signals | ≥3 in 30 days | — |
| E5 SKILL.md change | Within 14 days | — |
| E6 Cold audit | Within 30 days | E6_WARN |
| E7 Evolution-loop observability | Asset edits have edit_manifest predictions | E7_WARN = S-tier |

**HHS** (Harness Health Score): Each OK condition = +1 point (7 max). HHS ≥ 4 = Healthy · 2~3 = Caution · ≤1 = Critical.

> **Detail**: See `SKILL_detail.md §L5-Detail` — bash scripts for L5-A, L5-B, L5-C/E metrics — read when running L5 pattern analysis.

---

## Harness-Defect Taxonomy (frontier cross-check)

| Defect class | FH detectable signals | Tier |
|---|---|:---:|
| **Context Drift** | Stale paths in CLAUDE.md (L3) · rules unmodified 90+ days (L3) · CLAUDE.md over threshold (L2) | S |
| **Schema Misalignment** | Plugin count drift · SKILL.md missing `Done When` (undocumented contract) | M |
| **State Degradation** | tracks/ no sync 30+ days (L4) · INACTIVE_90D skills (L5-A) · orphaned memory entries | M |
| **Agentic Laziness** *(runtime)* | Completion claims without per-item evidence — "all N done" with no enumerable list in session records / PR bodies · Done When lacking any mandatory-pass condition | S |
| **Self-Preferential Bias** *(runtime)* | judged-class check without a named adversarial pairing (gate-rejectable for new skills; scan existing for backfill) · a self-graded verdict cited as sole completion evidence | M |
| **Goal Drift** *(runtime)* | Long session with S/A-tier work but no pre-compaction completion log (`fh_completed_*` missing) · early-stated constraints absent from card/manifest at close | S |
| **Comprehension Debt** *(runtime/operator)* | Merged FH-asset change with no CATALOG entry · edit_manifest `validation_status: pending` backlog piling up unverified · session closed with work done but zero card delta | S |
| **Evidence Gap** *(FH self-dev)* | Public-surface FH recommendation or default changed with no N-shot measurement evidence traceable in session records or PR history (L3 check) | S |

Signal in 2+ classes → escalate one tier.
Rows 1–3 = structural (2026-06-02 frontier diagnosis). Rows 4–6 = runtime behavioral, agent-side —
named from dynamic-workflows discourse (2026-06). Row 7 = runtime, operator-side — named from
loop-engineering discourse (Osmani, 2026-06): loop output outpacing operator understanding. FH
countermeasures already exist and are what the signals check for: golden probes + multi-persona
coverage (laziness) · judged-pairing rule (bias) · pre-compaction completion log + card-last guard
(drift) · CATALOG 3-line summaries + manifest predict-verify + card protocol (comprehension debt).

---

### Step 7. M/S/R Prescription Report Output

```
## harness-doctor Diagnostic Results

### 🟥 M-tier (Immediate Action)
### 🟧 S-tier (Strongly Recommended)
### 🟩 R-tier (Recommended)

---
## ETCLOVG Layer Coverage (L1-E)
- Covered: [layers with an asset, e.g. E·T·C·L·V·G]
- Gaps (surfaced, never auto-tiered — each "(human-confirm)"): [e.g. "O Observability (human-confirm) — retrospective audit only, no runtime layer"] or "full coverage"

---
## L5 Pattern Analysis
- Activity (L5-A): [list]
- Context appropriateness (L5-B): [suspected misuse or "no issues"]
- Effect metrics (L5-C): E1=[result] / E3=[result] / E5=[result]

---
## Language Quality (`--lint` mode only)
- HIGH (spec-only — missing Done When): [list or "none"]
- LOW (language patterns): [file: L{N}: "{text}" → {suggestion}]

Diagnostic scope: L1 (+L1-E ETCLOVG coverage) ~L3 [· L4 · L5 (FH only)] [· --lint]
```

M-tier 0 → output "Structure healthy. Maintaining simplification trend."

**M-tier Immediate Human Gate**: If 1+ M-tier found → pause, surface options: (a) AI proceeds to Step 8 / (b) human review first / (c) abort. Do not auto-apply prescriptions that could close a self-referential loop.

### Step 8. harvest-loop Integration *(when tracks/_audit/ exists)*

When 1+ M-tier found → propose adding `## Harness Structure Check (harness-doctor)` section to latest weekly_audit file.

### Step 9. Eval-First Quantitative Gate *(v0.x → v1 promotion only)*

**Thresholds** (measured over 5 sim-conductor runs): Tool Selection Accuracy > 0.90 · Multi-Step Coherence > 0.85 · Clarification Rate < 0.30.

### Step 10. Regression Guard *(when SKILL.md / rules / CLAUDE.md modified)*

Verifies that prescription application didn't strip operational content. Run after prescription applied, at pre-merge gate, or when harvest-loop Step 4 detects file changes.

| Check | Tier |
|:---:|:---:|
| F1 Frontmatter integrity | M |
| F2 Critical section preservation (Execution Steps · Done When · Triggers) | M |
| F3 Code block count not reduced by 4+ | S |
| F4 Operational keyword preservation (M-tier/S-tier/Wave/Step/Done When) | M if ≥50% drop · S if 20~49% |
| F5 Cross-reference paths resolve | M |
| F6 Line reduction ≥30% | S |
| F7 Bash block syntax (bash -n parse) | M if net increase in bad blocks |

Verdict: ✅ PASS (0M 0S) · ⚠️ REVIEW (0M 1+S) · ❌ BLOCK (1+M).

Implementation: `bash templates/regression_guard.sh` (compare vs main) or `bash templates/regression_guard.sh BASE HEAD`.

> **Detail**: See `SKILL_detail.md §Step-1-3` — bash scripts for Steps 1~6 (L1~L4 diagnostics) — read when running the diagnostic commands.

### Step 11. PR Change Consistency Check *(triggered on "PR" / "push" / branch with FH changes)*

Detect changed files vs main → category-based consistency checks:

| Category | What's checked |
|---|---|
| SKILL.md changes | Plugin description count drift · README skill table · CATALOG entry |
| Agent file changes | README agent count · agent_cards.json count sync |
| knowledge/shared/ changes | CATALOG coverage |
| README.md changed | Stale org/version references |
| AGENTS.md / CLAUDE.md changed | Agent count cross-reference sanity |

Verdict: ✅ CONSISTENT · 🟧 INCONSISTENT (fix before push) · 🟩 REVIEW (intent check).

**Auto-propose** (non-blocking) when "PR", "push", "merge" detected in session.

> **Detail**: See `SKILL_detail.md §Step11` — bash scripts for each consistency check category — read when running PR change verification.

---

## Done When

| Stage | Completion |
|---|---|
| Step 7 M/S/R prescription report output | ✅ Diagnosis complete |
| Step 2-E ETCLOVG coverage line in report (covered layers + gaps, or "full coverage") | ✅ Layer-coverage lens applied |
| M-tier 0 + "Structure healthy" output | ✅ Diagnosis complete (no prescription needed) |
| Step 8 weekly_audit section proposed | ✅ Integration proposal complete |
| Step 9 Eval-First verdict output (when requested) | ✅ Promotion verdict complete |
| Step 10 Regression Guard verdict (PASS/REVIEW/BLOCK) | ✅ Post-fix verification complete |
| Step 11 PR consistency check verdict | ✅ PR pre-push verification complete |

**This skill Done When = "prescription report output complete".** Actual resolution of M/S/R items belongs to user or follow-up work.

**Check classes** (`harness_6axis_framework.md` §Axis 5): report-output completions above = mandatory-pass (report exists or not). M/S/R tier *assignments* = judged — paired with verify-bidirectional when the user challenges a tier.

Verdict: PASS (M-tier 0, "Structure healthy") | CONDITIONAL_PASS (S/R remain, no M) | FAIL (1+ M-tier found) | ESCALATE (structural ambiguity before prescription can be issued)

**Three-Doctor Loop chain** (auto-propose after prescription report):
- M-tier + context/token waste → propose `/context-doctor`
- M-tier + user-facing behavior changes → propose `/sim-conductor Area A`
- SKILL.md S-tier (> 300 lines, no SKILL_detail.md) → auto-propose `/salience-splitter`: `"I see [skill] SKILL.md is [N] lines with no SKILL_detail.md. Want me to run /salience-splitter?"`
- Both → propose full Three-Doctor Loop: context-doctor → sim-conductor Area A

---

## Trigger Phrases

- `/harness-doctor` · "harness diagnosis" · "harness structure check" · "CLAUDE.md audit"
- `/harness-doctor --lint` · "check FH files for marketing language" · "description diet" · "remove marketing language" (→ Step 3-L)
- "my Claude settings seem off" · "something that used to work doesn't anymore" · "skill isn't triggering"
- "PR 올려줘" · "PR check" · "변경사항 영향 범위" (→ Step 11)

No auto-firing — only executes when user explicitly invokes. Step 11 exception: propose as one-liner when "PR"/"push"/"merge" detected.

## Failure Fallback

On Claude API / MCP failure → refer to [`references/fallback-guide.md`](../../references/fallback-guide.md).

---

## Three-Doctor Loop Integration

harness-doctor = **current structure diagnostician**. context-doctor = context collapse. sim-conductor = future behavior prediction. Together: diagnose → prescribe → re-diagnose closed loop.

# Harness 6-Axis Framework

> Top-level meta-framework for forge-harness operations. The 6 axes form a decision tree that governs all harness-level work — from initial structure through continuous improvement.

**Core principle (field harness)**: "A good harness gets simpler over time. If it's getting more complex, something is wrong."

**Meta-harness variant**: A good meta-harness *optimizes* over time — complexity is justified when it earns its scope. Red flags: orphaned skills (never invoked), redundant overlap (two skills doing the same thing), decorative structure (exists but doesn't change behavior). Complexity itself is not the warning signal.

**Completeness model (frame-wise ultimate)**: A harness is never *finally* complete — it is **frame-wise ultimate**. A *frame* is the scope one verification cycle can currently see: per-asset, an edit-manifest RECORD (Axis 3) → verify (Axis 5) cycle; for FH-as-a-whole, a release/version milestone (cf. a model's knowledge cutoff = its release frame's timestamp). A frame is *closed* — ultimate **for that frame** — when every **visible** gap is resolved or **named**: a named gap is evidence the frame closed (you saw the edge), not evidence against it; the only signal of incompleteness is an **un-named** gap. This reframes the existing completion-claim discipline (Axis 5 before "done", residuals declared) — growth is not the opposite of completeness but its **ladder**: Axis 6 carries one frame's closure into the next frame's baseline. **Two guards keep this honest, not self-congratulatory:** (1) never declare a frame closed before the gap-surfacing pass (Axis 5) has run — premature closure (e.g. "downloads ≠ validated usage"); (2) the verdict "are all *visible* gaps named?" is **judged, so it is adversarially paired** (Axis 5's challenger, or an external sister-GT) — never self-asserted, because an un-named gap is invisible *to the self-judge by construction*; only a non-self pass expands what is visible (mechanical-anchor / Non-Model-Ground principle, §Scope Hierarchy's no-self-commit kin). An *irreducible* gap (visible but unclosable — e.g. the 4-axis gate's autonomous-runner self-verification residual, documented honest in CLAUDE.md §FH 4-Axis Gate) closes its frame **at the ceiling**; the next frame opens only when a new capability changes what is visible.

---

## The 6 Axes

| Axis | Name | Question it answers |
|:---:|---|---|
| **1** | **Structure** | Where does this work live? (hub vs. project, rules vs. skills, knowledge vs. tracks) |
| **2** | **Context** | What does the AI need to know before starting? (session card, CATALOG, relevant docs) |
| **3** | **Plan** | What is the intended change and its predicted impact? (edit-manifest RECORD) |
| **4** | **Execute** | What is the minimal, reversible action? (direct edit, agent dispatch, parallel dispatch) |
| **5** | **Verify** | Did the change do what was predicted? (regression guard, adversarial, source-grounding) |
| **6** | **Improve** | What pattern is worth keeping? (harvest-loop, field-harvest, compounding loop) |

---

## Decision Tree (Condensed)

```
New work arrives
    │
    ▼ Axis 1 — Structure
    Where does this live?
    ├── Hub meta (rules/skills/templates) → FH 4-axis auto-gate applies
    ├── Field project → route via Agent dispatch or direct edit
    └── Cross-project knowledge → knowledge/shared/

    ▼ Axis 2 — Context
    What must the AI know?
    ├── Read session_card (reference_next_session_starter.md)
    ├── Read CATALOG.md → candidate files only
    └── Load LOCAL_SKILL_REGISTRY if cross-project dispatch

    ▼ Axis 3 — Plan
    What will change?
    └── edit-manifest RECORD entry: branch, change, predicted_impact, verify_next

    ▼ Axis 4 — Execute
    Minimum viable action:
    ├── Direct edit (simple, known file, absolute path)
    ├── Single Agent dispatch (field task, one project)
    └── Parallel Agent dispatch (2+ independent tasks — no asking, just dispatch)

    ▼ Axis 5 — Verify
    Did it work?
    ├── Axis 1 (backward): regression_guard.sh
    ├── Axis 2 (adversarial): steel-quench
    ├── Axis 3 (forward): phantom-quench
    ├── Axis 4 (record): confirm edit-manifest entry exists
    └── Before claiming "done": attach (a) evidence (b) failure-checks run
        (c) residual risk — bare "completed" does not pass (see Completion-claim discipline)

    ▼ Axis 6 — Improve
    Worth keeping as a pattern?
    ├── 3+ repeats → skill-candidate tag → field-harvest
    ├── Session end → harvest-loop (weekly cycle)
    └── Compounding: hub_compounding_loop.md
```

---

## Axis 5 — FH 4-Axis Verification Gate (detail)

Applies automatically when any FH asset is modified (SKILL.md, rules, templates, CLAUDE.md, substantive knowledge/ docs).

| Gate axis | Tool | Class | What it catches |
|---|---|---|---|
| **Backward** | `regression_guard.sh` | mandatory-pass | Critical section loss, broken refs, syntax errors, line reduction |
| **Adversarial** | `steel-quench` | judged | Trigger phrase collisions, design attack surface, over-engineered steps |
| **Forward** | `phantom-quench` | judged | Phantom references, paths that don't exist, stale external links |
| **Record** | `edit-manifest RECORD` | mandatory-pass | Logs predicted impact — closes the predict-verify loop |

**Check classes**: every verify check is one of three classes — **mandatory-pass**
(deterministic; blocks on fail), **measured** (quantitative; tracked, not blocking alone —
e.g. `token-budget-gate`, goal-quench calibration), **judged** (LLM-judge emitting verdict +
cited evidence + a corrective action — a judge score without a fix path is unactionable, and
self-judges grade leniently). **Judged rule**: a judge verdict alone never passes — it must be
paired with adversarial re-verification (`steel-quench` / `verify-bidirectional`), and its
cited evidence is itself subject to `phantom-quench`. (Taxonomy adapted from external
supervisor-loop discourse, 2026-06; FH adds the judged-pairing rule and evidence
re-verification, which the source leaves open.)

**Completion-claim discipline** (judged-class sharpening): a "done" / "passed" claim is itself a judged
verdict and must carry three things, not just an assertion — **(a) an evidence artifact** (the output,
diff, or run that shows it), **(b) the enumerated failure-checks actually run** (which negative cases
were tested, not only that it "works"), and **(c) the explicit residual risk** (what could still be
wrong). A bare "completed" with none of these is an ungrounded judge verdict and does not pass. Each of
(a)–(c) must be **non-vacuous** — a named artifact, an enumerated case list, and a specific risk; "it
works" / "tested" / "none known" are vacuous fills and fail the discipline (same non-vacuity bar as the
CLAUDE.md §marker rule: a recorded verdict/count, not "it ran"). Bounded scope: (b) means the negative
cases you *actually ran*, not all conceivable ones; (c) means the one or two risks you can name now, not
an exhaustive proof of safety. Applies to every skill's Done When and to `goal-quench` /
`pipeline-conductor` completion gates. (Harvested as independent-convergence reinforcement from sister
assets — oh-my-claudecode "Ralph" Done-When + book/19689's verification-before-completion-claim theme;
cross-audit `tracks/_audit/session_2026_06_14_wikidocs-deep-sweep.md`.)

**Hard gate**: git pre-commit hook (`templates/.git-hooks/pre-commit`) blocks commit until marker + manifest entry exist.

**Lightweight exception** (Axis 1 + 4 only): sessions where zero SKILL.md/rules/templates files changed.

---

## Scope Hierarchy

```
Hub common principles (CLAUDE.md)
    └── Project CLAUDE.md
            └── Domain session rules (.claude/rules/session.md)
```

Lower levels cannot override higher. AI contribution → PR proposal only (no direct commit to shared repos without explicit user approval).

---

## Related

- `harness_design_decision_lens.md` — orthogonal companion: the 7 architectural-bet decisions (which design point at Axis 1 / Axis 4) + default-bias checklist + scaffolding-removal method
- `crucible_mode.md` — total-immersion absorption stance: chains Axis 5 (the melt) + Axis 6 (the rebirth) with an unmeltable identity core; used when a whole corpus on a core FH axis is absorbed
- `hub_compounding_loop.md` — Axis 6 automation (weekly/monthly/quarterly cycles)
- `ai_dialogue_playbook.md` — Axis 2 dialogue principles (how to ask, delegate, record)
- `claude_code_runtime_flow.md` — Axis 4 runtime behavior (chronological session flow)
- `.claude/rules/operations.md` — Sub-agent operations, weekly cycle detail

**External sibling (independent convergence)**

- arXiv:2603.25723 (*Natural-Language Agent Harnesses*, NLAH) — external academic sibling that independently converges on the same core thesis: a harness control layer can be an executable natural-language object, not code. NLAH measures the natural-language-harness form empirically; FH governs and compounds it.
- arXiv:2606.06324 (*HarnessFix / ETCLOVG*, 2026-06) — sibling on the **orthogonal** axis: where NLAH and FH describe the harness as a *process/control* object, HarnessFix supplies a *component taxonomy* of what a deployed harness contains (7 layers — Execution · Tooling · Context · Lifecycle · Observability · Verification · Governance). Its **V layer maps onto FH's Axis-5 gate on 3 of its 4 functions** (intermediate validation → steel/phantom-quench · final-output eval → completion-claim discipline · regression testing → regression_guard); its *readiness-check* function maps to FH pre-flight gates (install-doctor / asset-placement-gate) that sit outside Axis-5. Its named **Observability** layer is a structural axis FH lacks — FH's nearest coverage is *retrospective audit* (weekly_audit, subagent_invocations_log), not runtime observability (import candidate for `harness-doctor`). Cross-audit: `tracks/_audit/session_2026_06_19_harnessfix-etclovg-cross-audit.md`.
- "Loop Engineering" (실밸개발자 video, 2026-06-22) — independent-convergence sibling on the **component lens** (Osmani's 6 components: Automation/trigger · Worktree · Skill · Connector · Sub-agent maker/checker · Memory) and on **Axis-5**: its central claim "a verifiable goal or it's a token-burning machine" is FH's Done-When + check-class, and its mandatory Generator≠Evaluator split is FH's no-judge-only-path. FH increment beyond the frame = the Surface-Class Degrade Invariant (irreversible → fail-closed), which structurally blocks the video's "production accident" failure mode it only budget-caps. Cross-audit: `tracks/_audit/session_2026_06_27_loop-engineering-silbal.md`.
- **Mechanical-anchor / Non-Model Ground — training-layer external anchors** (Axis-5, verified 2026-06-27): arXiv:2606.27369 (*RiVER*, 2026-06-25) trains LLMs on optimization/coding tasks using **deterministic execution feedback in place of ground-truth labels** — FH's "bind the terminal verdict to a non-model anchor, not a judge's agreement" stated at the training layer; arXiv:2606.27359 (*When are likely answers right?*, Zenn & Geiping, 2026-06-25) shows sequence probability is **predictive within a dataset but does not transfer to decoding decisions** — peer evidence that likelihood/self-consistency is not reliable correctness. Both are independent-convergence anchors for `feedback_judge_robustness_mechanical_anchor`, not FH measurements.

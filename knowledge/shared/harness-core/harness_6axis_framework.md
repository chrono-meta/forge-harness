# Harness 6-Axis Framework

> Top-level meta-framework for forge-harness operations. The 6 axes form a decision tree that governs all harness-level work — from initial structure through continuous improvement.

**Core principle**: "A good harness gets simpler over time. If it's getting more complex, something is wrong."

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
    ├── Axis 3 (forward): source-grounding-audit
    └── Axis 4 (record): confirm edit-manifest entry exists

    ▼ Axis 6 — Improve
    Worth keeping as a pattern?
    ├── 3+ repeats → skill-candidate tag → field-harvest
    ├── Session end → harvest-loop (weekly cycle)
    └── Compounding: hub_compounding_loop.md
```

---

## Axis 5 — FH 4-Axis Verification Gate (detail)

Applies automatically when any FH asset is modified (SKILL.md, rules, templates, CLAUDE.md, substantive knowledge/ docs).

| Gate axis | Tool | What it catches |
|---|---|---|
| **Backward** | `regression_guard.sh` | Critical section loss, broken refs, syntax errors, line reduction |
| **Adversarial** | `steel-quench` | Trigger phrase collisions, design attack surface, over-engineered steps |
| **Forward** | `source-grounding-audit` | Phantom references, paths that don't exist, stale external links |
| **Record** | `edit-manifest RECORD` | Logs predicted impact — closes the predict-verify loop |

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

- `hub_compounding_loop.md` — Axis 6 automation (weekly/monthly/quarterly cycles)
- `ai_dialogue_playbook.md` — Axis 2 dialogue principles (how to ask, delegate, record)
- `claude_code_runtime_flow.md` — Axis 4 runtime behavior (chronological session flow)
- `.claude/rules/operations.md` — Sub-agent operations, weekly cycle detail

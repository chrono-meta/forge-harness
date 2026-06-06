---
name: source-grounding-audit
description: >-
  RENAMED to phantom-quench (2026-06-06, quench-series rebrand). Same skill, same ruleset — only the
  label changed to fit the quench family (steel-quench · phantom-quench · goal-quench). Use
  /phantom-quench. This alias is retained so old references and the v1 paper's name still resolve.
user-invocable: false
allowed-tools: []
model: sonnet
deprecated: true
deprecated_reason: renamed to phantom-quench (label-only; not a merge — same skill)
deprecated_date: 2026-06-06
successor: phantom-quench
---

# source-grounding-audit — RENAMED to `phantom-quench`

> **Renamed to `phantom-quench` (2026-06-06).** This is a **label rename, not a deprecation-by-merge** —
> the skill is unchanged and fully active under its new name. Invoke **`/phantom-quench`**.

## Why the rename

phantom-quench is the **grounding member of the quench series** (steel-quench attacks output patterns ·
phantom-quench traces inputs for Phantom Claims · goal-quench gates autonomous runs). The old descriptive
name did not signal that family membership; the function is identical.

## Where the skill lives now

`plugins/fh-meta/skills/phantom-quench/SKILL.md` (+ `SKILL_detail.md`) — full ruleset preserved
(S-grade blocker, Human Gate, Pattern Diagnosis, etc.).

## Record note (do not "fix")

The **v1 paper** (Zenodo 10.5281/zenodo.20397566; arXiv submission) cites `source-grounding-audit`.
That is the **immutable historical name**, not a phantom — `paper/forge_harness_v1.0.html` is left
unchanged by design. Future readers map: *source-grounding-audit (v1 paper) = phantom-quench (current)*.

## Done When

Deprecated alias — no active execution path of its own. Done When: all invocation routes through
`/phantom-quench` (the successor); this entry exists only so old names resolve. Satisfies the
harness-doctor L2 M-tier Done-When requirement (CLAUDE.md §New Skill Creation Pre-Commit Gate).

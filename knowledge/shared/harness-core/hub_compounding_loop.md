# Hub Compounding Loop

> Axis-6 automation: the mechanism by which the forge-harness hub improves itself over time through structured feedback cycles.

**Principle**: Each session's learnings are absorbed back into the hub so the harness evolves on its own — without requiring manual re-triggering.

---

## Cycle Overview

| Cadence | Trigger | Key actions |
|---|---|---|
| **Per-session** | Session close ("wrap up", "done", "good work") | harvest-loop → card update → push check |
| **Weekly** | 7 days since last `frontier_digest_*.md` | `/frontier-digest` → CATALOG entry + 6-candidate implementation |
| **Monthly** | 30 days since last harness-doctor run | `/harness-doctor` → L1~L4 diagnosis + M/S/R prescription |
| **Quarterly** | ~90 days | Sister asset sync, Phase transition gate review |

---

## Per-Session Close Chain (Automatic — Not Skippable)

```
Closing phrase detected
  → ① git diff check
  → ② if diff exists → harvest-loop
  → ③ card update (reference_next_session_starter.md) — independent obligation
  → ④ unpushed commits → propose "push?"
```

Card update is NOT a sub-step of harvest-loop — runs even if harvest-loop is skipped.

**Real-time tracking**: Complete S-tier/A-tier items get immediately appended to
`tracks/_meta/fh_completed_{YYYY-MM-DD}.md` (before context compression).
harvest-loop Step 0-b uses this file — relying on LLM memory after compression causes omissions.

---

## harvest-loop Pipeline (8 Steps)

```
field-harvest (pattern extraction)
    → contention-layer (collision signals)
    → [persona-devil-advocate + persona-innovator] (parallel)
    → synthesizer (devil/innovator collision harvest)
    → Critic isolated Agent (SAGE critique)
    → harness-doctor (health check)
    → verify-bidirectional (consistency validation)
    → curator (skill lifecycle management)
```

Session learnings automatically absorbed back into FH ecosystem.

**In main dev env**: runs automatically at session end.
**For external FH users**: proposes execution first.

---

## Weekly Audit Cycle (Phase 1.5)

1. Gather window data by hand — `git log --since="{window}" --oneline` (+ count), `git tag --sort=-creatordate`, tail of `knowledge/shared/learnings/subagent_invocations_log.yaml`, stale-file spot checks.
   (**No `_scanner.sh` exists** — a prior reference here was a phantom; the automation path is Phase 2 harvest-loop, a standalone scanner script is deliberately not built.)
2. `bash scripts/below_floor_scan.sh` — below-floor marker re-run queue (exit 1 = pending floor-tier re-validations, treat as S-tier)
3. Write `tracks/_audit/weekly_audit_YYYY-MM-DD.md` mirroring the previous audit file's format — frontmatter + activity table + 🟥🟧🟩 + pattern table. (**No `_template_weekly.md` exists**; the previous audit file is the template.)
4. Propose 3-tier improvements (🟥mandatory / 🟧strong / 🟩recommended)

> **Why this correction is here (2026-07-20)**: the same phantom pair (`_scanner.sh` · `_template_weekly.md`)
> was fixed in `knowledge/shared/rules/operations.md` on 2026-06-11, but **this file — its sibling
> describing the same Phase 1.5 — was not updated**, so the phantom survived in the document a reader
> is more likely to open for the loop itself. Half-applied fixes leave the weaker copy authoritative.

**Phase 2 (skill-ized)**: `/harvest-loop` automates the above (manual ~10 min → auto ~3 min target).

---

## Cadence Files (Session-Start Auto-Detection)

| File | Cadence | Auto-propose condition |
|---|---|---|
| `tracks/_meta/frontier_digest_*.md` | 7 days | Propose `/frontier-digest` at session start if 7+ days |
| `tracks/_meta/*harness_doctor*.md` | 30 days | Propose `/harness-doctor` at session start if 30+ days |

---

## 3-Phase Maturity Roadmap

| Phase | Name | Criteria |
|---|---|---|
| **Phase I** | Entering Maturity | 5-criteria gate — consistent weekly audit, no critical debt, harvest-loop running |
| **Phase II** | Frontier Following | frontier-digest cadence + sister asset sync + external PR evidence |
| **Phase III** | Frontier Leading | 6 indicators + writing guide for org-level propagation |

**Shared condition for all transitions**: optimization principle — field harness: getting simpler over time; meta-harness: complexity justified by scope (no orphaned/redundant/decorative units).

Detailed frame: `hub_maturity_roadmap.md`.

---

## FH Improvement Signal Recording

When friction is detected during a session, record it for the next session's awareness:

```
tracks/_meta/fh_signal_{YYYY_MM_DD}_{source}.md
```

Fields: friction point, FH registration candidate, status (pending hub review).

**Guard**: 1 file per session (append if same date+source). Structural improvements only — no minor typos.

---

## Related

- `harness_6axis_framework.md` — Axis 6 is the "Improve" step that feeds into this loop
- `knowledge/shared/rules/operations.md` — Sub-agent invocation log, weekly audit scanner detail
- `knowledge/shared/rules/sync_push_protocols.md` — Session Sync Protocol (how learnings enter the loop)

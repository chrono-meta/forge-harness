---
title: fh-meta Roadmap
type: roadmap
date: 2026-05-19
tags: [roadmap, v1.0, milestones]
---

# fh-meta Roadmap

> Version policy: v0.x = internal validation phase / v1.0 = declared when C1~C5 all achieved / v2.0 = cross-project skill bus fully implemented

---

## v1.0 Declaration Criteria — C1~C5 Checklist

| Criteria | Description | Status |
|:---:|---|:---:|
| **C1** | Natural-language trigger activation confirmed for 17 core skills (cascade α) | ⚠️ In progress |
| **C2** | At least 1 external user successfully runs a skill autonomously (cascade β) | ✅ Done |
| **C3** | Utterance coverage audit M-tier items all resolved (M1/M2) | ✅ Done |
| **C4** | install-wizard bootstrap paradox resolved (G6) | ✅ Done |
| **C5** | Three-Doctor Loop closed-loop operation confirmed | ✅ Done |

**Completion evidence**:
- C2: External user meta-simulation autonomous run + PR #3 bug catch + merge complete (2026-05-12)
- C3: M1 (hub-persona-auditor had no trigger path) → added "next step skills" block to install-wizard Step 5 / M2 (fact-checker role unrecognizable) → added fact-checker role description to agent-composer Wave 0 (v0.3.0)
- C4: install-wizard v0.2 bootstrap paradox branch added 2026-05-18
- C5: harness-doctor · context-doctor · sim-conductor each at v0.3 with Three-Doctor Loop linkage sections complete

**C1 incomplete status** (based on utterance coverage audit 2026-05-17):
- ✅ Natural utterance possible: 9/17 (plugin-recommender · install-wizard · context-doctor · audit-learnings · verify-bidirectional · sim-conductor · hub-cc-pr-reviewer · install-doctor + 1)
- ⚠️ Internal vocabulary dependent: 8/17 (deliberation · harness-doctor · marketplace-gate · agent-composer · field-harvest · asset-placement-gate · cross-ecosystem-synergy-detection · meta-prompt-builder)
- v1.0 declaration criteria: ✅ 9 + S-tier top 2 (deliberation · agent-composer) improvements complete

---

## v0.3.0 — 2026-05-19 (current)

**M1/M2 resolved + fallback guide + sim-conductor human gate formalized**

- install-wizard Step 5 "next step skills" block added (M1 resolved)
- agent-composer Wave 0 fact-checker role description added (M2 resolved)
- sim-conductor "Human Gate Principle" section added
- references/fallback-guide.md maintained (W4-1 AI dependency single point of failure response)
- Wave 4 steel-quench meta-aware adversary complete (fda203a — prior to v0.2.8)

---

## v1.0 — Target: declare when C1~C5 all achieved

**Condition**: C1 complete = ✅ 9 triggerable + S-tier 2 (deliberation · agent-composer) natural language trigger reinforcement

**Remaining work**:

| Item | Action |
|---|---|
| deliberation trigger reinforcement | Add "which one is right?", "two views are clashing", "look at this decision from multiple angles" |
| agent-composer trigger reinforcement | Add 1-line intro "next step → agent-composer" after install-wizard or audit-learnings completes |
| 2+ external install measurements | cascade β 1 instance → confirm diversity with 2+ instances |
| v1.0 declaration commit | Write CHANGELOG.md `[1.0.0]` entry + update plugin.json version |

---

## v1.x — meta-devil lightweight version (Wave 5, external users)

**Goal**: Extract steel-quench Wave 4 (meta-aware adversary) into a lightweight version usable by external users

**Current**: steel-quench presupposes knowledge of the internal harness structure (Wave 4 attacks reference it)

**Direction**:
- Wave 1~3 standalone lightweight profile (`--basic` flag)
- Wave 4 condition: restricted to returning users with 3+ FH skill usage history
- Redefine triggers based on external user simulation results (sim-conductor Area A)

---

## v2.0 — cross-project skill bus fully implemented

**Goal**: FH can cross-utilize project skills via registry, without manual copying

**Current state**: passive install hub (installed, then each project calls individually)

**v2.0 direction**:
- FH skill registry: track per-project install status + auto-sync
- active synergy node: collect patterns from multiple projects → auto-extract common patterns → field-harvest reverse-injection
- cross-project Agent dispatch: dispatch another project's agent directly from one project session
- Foundational technology: EnterWorktree / RemoteTrigger tools (currently piloted in meta hub only)

---

## History

| Version | Date | Key Milestone |
|:---:|:---:|---|
| v0.1.0 | 2026-05-16 | rc1~rc10 integrated / versioning rationalized |
| v0.2.0 | 2026-05-17 | deliberation added / 17-skill regime |
| v0.2.6 | 2026-05-18 | meta-prompt-builder v0.2 inclusion confirmed |
| v0.2.7 | 2026-05-18 | Wave 4 Final Judgment Gate + 2 skills deprecated |
| v0.2.8 | 2026-05-18 | steel-quench added / Wave 4 meta-aware adversary |
| **v0.3.0** | **2026-05-19** | **M1/M2 resolved / sim-conductor human gate formalized** |

---

*This document created at v0.3.0. Prior history in CHANGELOG.md.*

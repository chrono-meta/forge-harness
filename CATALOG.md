# Knowledge Catalog

AI reads this file first when searching past work. Open individual files for detailed content.

---

## Sessions

<!-- Add entries in reverse date order (newest at top) -->
<!--
### YYYY-MM-DD | {project} | tag1, tag2, tag3
**File:** tracks/{project}/session_YYYY_MM_DD_{slug}.md
Summary (within 3 lines).
- Decision: key decision
-->

### YYYY-MM-DD | your-project | example, pattern, architecture
**File:** tracks/your-project/session_YYYY_MM_DD_example.md
Example session entry. Replace with your own project sessions as you work.
- Decision: example decision recorded here

---

## Reference Documents

<!-- Time-independent reference documents -->

### 2026-04-28 | template | maturity-roadmap, 3-phase-frame, frontier-tracking, simplification-gate
**File:** `knowledge/shared/harness-core/hub_maturity_roadmap.md`
Hub long-term evolution path frame. Phase I (entering maturity) → Phase II (frontier following (b)cadence) → Phase III (leading) 3-stage model + 5-criteria gate (audit automation·operations guide·external propagation·sub-agent judgment·self-diagnosis warning) + 6 indicators (seed repo·blog·citations·external adoption·self-evolving·industry original) + simplification gate (self-diagnosis + within 200 lines + unreferenced archive at each transition). General-purpose template derived from first verified operating instance.
- Decision: (b) quarterly + monthly cadence recommended — if adopting other option, need to prove simplification gate passed
- Decision: Phase III has no completion (ongoing state) — 3+ of 6 indicators continuously rising is the maintenance condition
- Decision: Phase regression allowed — do not force linear progression (allow partial Phase I redo if frontier following routine is missed)

---

## Plugins

### 2026-05-08 | fh-meta v0.5.0 | six-skills-operation, path-b-generalization, command-tower-gate, mode-c-user, beta-release
**File:** plugins/fh-meta/.claude-plugin/plugin.json + .claude-plugin/marketplace.json
Hub meta operations tool bundle — 6 skills operation. audit-learnings path B generalization + verify-bidirectional path B generalization + frontier-status-summary path B generalization + cross-ecosystem-synergy-detection + plugin-recommender + **hub-cc-pr-reviewer** command tower gate operations rule automation (new). 2 agents (hub-persona-auditor + fact-checker). Beta operation — harness core principle *"beta + public release = practical capability obligation"* followed.
- Decision: hub-cc-pr-reviewer skill newly created — command tower gate operations rule automation + PR lifecycle 4-run accumulated + explicit decision trigger
- Decision: plugin level v0.4.3 → v0.5.0 promoted — 6 skills operation baseline + path B generalization baseline followed
- Decision: 3 skills path B generalization — audit-learnings + verify-bidirectional + frontier-status-summary / external user environment adaptation path enhanced

---

## Skills

### 2026-05-08 | fh-meta | audit-learnings, weekly-audit, real-time-pattern-catch, hub-cwd-only, phase-2-plus
**File:** plugins/fh-meta/skills/audit-learnings/SKILL.md
Hub weekly audit automation — `/audit-learnings [period]` runs scanner + drafts weekly_audit + detects repetitive patterns + searches existing matches first + proposes promotion/deprecation candidates + proposes Git commit/PR (user approval gate). Hub cwd only (Phase 2 · activated 2026-04-27 / Phase 2+ · PR automation 2026-05-06).
- Decision: v0.2 official release — Phase 2+ PR automation baseline aligned

### 2026-05-08 | fh-meta | verify-bidirectional, layer-5-cross-verification, conscious-self-activation, diff-gate
**File:** plugins/fh-meta/skills/verify-bidirectional/SKILL.md
Bidirectional self-verification pattern automation — when user's precision counter-argument manifests after AI recommendation/agreement persistence, baseline update channel 6-step processing.
- Decision: v0.5 official release — accumulated runs + mode C correction catch fully persisted

### 2026-05-08 | fh-meta | hub-cc-pr-reviewer, command-tower-gate-automation, baseline-coherence-check, layer-5-self-catch
**File:** plugins/fh-meta/skills/hub-cc-pr-reviewer/SKILL.md
Command Tower Gate operations rule automation — on PR input, auto-generates baseline coherence check 8-matrix + Layer 5 self-catch matrix + review comment attachment + admin override merge recommendation.
- Decision: v0.1 newly created — PR lifecycle 4-run accumulated + explicit decision trigger met

### 2026-05-20 | fh-meta | context-bridge-dispatch, agent-view-context-blindness, parallel-dispatch, session-context-card
**File:** plugins/fh-meta/skills/context-bridge-dispatch/SKILL.md
Parallel agent dispatch pre-session context card injection pattern automation — sub-agents read files but cannot access main session living context. Context Card (purpose·completed·this agent's task·caution) generation and injection into each prompt before 2+ parallel dispatches. Simple file lookup agents can omit.
- Decision: v0.1 newly created — agent view blindspot captured in the field → FH skill decision

---

## Agents

### 2026-05-08 | fh-meta | hub-persona-auditor, persona-simulation, three-tier-revision, external-asset-pre-publication
**File:** plugins/fh-meta/agents/hub-persona-auditor.md
External-facing asset (briefing·card·public guide) pre-publication persona audit — 3+ virtual reader persona simulation + 4-axis (resonance·confusion·resistance·supplement) review + 3-tier (mandatory·strong·recommended) revision proposals.
- Decision: fh-meta agent separate operation (not a skill / external-facing cadence activation)

### 2026-05-08 | fh-meta | fact-checker, hub-asset-grep-verification, duplicate-detection, stale-fact-detection
**File:** plugins/fh-meta/agents/fact-checker.md
Hub asset grep verification — (1) hub asset duplicate check before recommending new asset/skill/agent (2) stale data detection in memory/docs (3) when duplicate work is suspected.
- Decision: hub self-review circuit baseline established

---

## Learnings

<!-- Accumulated feedback/lessons -->

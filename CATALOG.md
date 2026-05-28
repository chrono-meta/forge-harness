# Knowledge Catalog

AI reads this file first when searching past work. Open individual files for detailed content.

---

## Sessions

<!-- Add entries in reverse date order (newest at top) -->

### 2026-05-28 | _meta | install-wizard, plugin-autoinstall, deprecated-cleanup, fh-ops, external-validation
**File:** tracks/_meta/session_2026_05_28_fh-external-ops.md
FH 외부 운용 첫 실행 — install-wizard 첫 실행(57/100)에서 마찰 포인트 2개 발견 및 즉시 수정. PR #7 (install-wizard plugin 자동 설치) + PR #8 (deprecated refs 정리) 완료.
- Decision: install-wizard FH plugin MISS → AI가 Bash로 자동 실행 (수동 3-turn 제거) — "빌더가 직접 써봐야 보이는 마찰" 패턴
- Decision: deprecated 참조는 CHANGELOG 업데이트 시 연결 파일도 동시 업데이트 필요 — 별도 cleanup PR 필요

### 2026-05-27 | _meta | two-layer-storage, memory-vs-tracks, cross-session-state
**File:** tracks/_meta/fh_signal_2026_05_27_session-starter.md
Two-layer storage principle formalized: `tracks/` = local work history (machine-bound), `memory/` = critical cross-session state (durable, survives re-clone). Gap: session starter files in tracks/ are lost on machine change.
- Decision: Critical cross-session state must also be written to `~/.claude/projects/.../memory/` — tracks/ alone is insufficient for durability

### 2026-05-26 | _audit | sister-asset, harness-evolver, meta-harness, stanford, arxiv
**File:** tracks/_audit/session_2026_05_26_harness_evolver.md
Sister asset cross-audit — harness-evolver (raphaelchristi) + Meta-Harness (Lee et al., arXiv:2603.28052, Stanford IRIS Lab). Independent architectural convergence confirmed: outer-loop field observation → adversarial critique → synthesis → integration → verification. Cross-reference links proposed; Issue #26 filed.
- Decision: harness-evolver = direct complement (automation-first) vs FH (knowledge-accumulation-first) — mutual citation proposed

### 2026-05-26 | _audit | sister-asset, sylph-ai, arxiv, simplification-principle
**File:** tracks/_audit/session_2026_05_26_sylph_sister.md
Sister asset cross-audit — "The Last Harness You'll Ever Build" (Sylph.AI, arXiv:2604.21003). Title resonates with FH simplification principle but approach diverges: Sylph = fully automated adversarial agent loops, FH = human-in-the-loop curated knowledge evolution.
- Decision: Sylph.AI = automation-maximalist counterpart; FH distinction is human judgment layer

### 2026-05-26 | _meta | external-network, wave3-validation, sase, install-wizard, frontier-digest
**File:** tracks/_meta/external_network_verification_2026_05_26.md
Wave 3 meta-validation: confirmed all previously [redacted-system]-blocked capabilities work on personal network — install-wizard dry-run, plugin-recommender live GitHub search, frontier-digest fetch, git push. Baseline for external user environment parity.
- Decision: All core FH capabilities verified functional outside corporate network

### 2026-05-26 | forge-harness | v1.2, public-release, harness-evolver-absorb
**File:** tracks/_meta/reference_next_session_starter.md
v1.2 release complete (PR #1–#5): harvest-loop Step 0, agent-composer worktree isolation, steel-quench numeric scoring, README positioning. Repo made public.
- Decision: harness-evolver 3대 혁신 흡수 — regression guard / worktree isolation / numeric scoring

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
Hub meta operations tool bundle — 6 skills operation. harvest-loop path B generalization + verify-bidirectional path B generalization + frontier-digest path B generalization + cross-ecosystem-synergy-detection + plugin-recommender + **hub-cc-pr-reviewer** command tower gate operations rule automation (new). 2 agents (hub-persona-auditor + fact-checker). Beta operation — harness core principle *"beta + public release = practical capability obligation"* followed.
- Decision: hub-cc-pr-reviewer skill newly created — command tower gate operations rule automation + PR lifecycle 4-run accumulated + explicit decision trigger
- Decision: plugin level v0.4.3 → v0.5.0 promoted — 6 skills operation baseline + path B generalization baseline followed
- Decision: 3 skills path B generalization — harvest-loop + verify-bidirectional + frontier-digest / external user environment adaptation path enhanced
- Note: audit-learnings deprecated from plugin (2026-05-xx) → transferred to hub-internal deprecated/; replaced by harvest-loop
- Note: frontier-status-summary deprecated (2026-05-xx) → replaced by frontier-digest

---

## Skills

### 2026-05-08 | fh-meta | harvest-loop, weekly-audit, self-evolution-pipeline, session-harvest, phase-2-plus
**File:** plugins/fh-meta/skills/harvest-loop/SKILL.md
Self-evolution pipeline — field-harvest → contention-layer → devil/innovator parallel → synthesizer → Critic Agent → harness-doctor → verify-bidirectional → curator (8 steps). Lightweight mode for weekly audit. Replaces deprecated audit-learnings.
- Decision: harvest-loop = audit-learnings successor + full self-evolution pipeline integrated

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

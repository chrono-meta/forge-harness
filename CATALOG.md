# Knowledge Catalog

AI reads this file first when searching past work. Open individual files for detailed content.

---

## Sessions

<!-- Add entries in reverse date order (newest at top) -->

### 2026-06-03 | forge-harness | #goal-quench, #sidecar-routing, #token-calibration, #steel-quench, #skill-evolution
**File:** plugins/fh-meta/skills/goal-quench/SKILL.md
Added scope-driven sidecar routing (Step D) to goal-quench Phase 1.5: task-type signals auto-route to steel-quench C3 (code review), agent-composer panel (architecture), or sim-conductor+steel-quench Wave 5 (external publish). Formalized session overhead calibration at 4.7× factor (N=10), adding `session_type`, `actual_vs_estimate_ratio`, and `sidecar` fields to the calibration schema. Resolved steel-quench meta-audit S+A+B findings: sub-goal loop rewritten as user-driven queue, pre-flight check added, Opus escalation cost disclosed.
- Decision: overhead multiplier documented as empirical calibration constant; sidecar routing is scope-signal-driven, not mode-locked

### 2026-06-03 | forge-harness | #goal-quench, #non-coercive, #companion-store, #ephemeral-handoff
**File:** .claude/rules/modes_and_value.md
Formalized two non-coercive guidances: companion-store recommendation conditioned on accumulating context into meta-harness without a local fork; ephemeral-environment handoff rule made mode-agnostic (Mode D → companion-store handoff/, all others → committed note or PR comment in working repo).
- Decision: single-source preserved — rule lives in public mirror; companion store holds only outputs, never a rule copy

### 2026-06-03 | forge-harness | #goal-quench, #skill-evolution, #meta-audit, #prompt-regression
**File:** plugins/fh-meta/skills/goal-quench/SKILL.md
Post-merge micro R-tier cleanup: corrected two prompt-regression probe expectations mis-FAILing correct skills (P-CHAIN-01/02). Made LOCAL_SKILL_REGISTRY trigger in cross-ecosystem-synergy-detection honestly optional. Closes full-harness refactor backlog.
- Decision: leftover placeholder bash blocks and challenger wiring gap are verified non-defects

### 2026-06-03 | forge-harness | #goal-quench, #skill-evolution, #mode-ladder, #sidecar-routing
**File:** plugins/fh-meta/skills/goal-quench/SKILL.md
Evolved goal-quench into a fluid core→pro→max mode ladder. Core: token-budget-gate + pipeline-conductor --quick; pro: +context-doctor +agent-composer; max: +plugin-recommender +cross-ecosystem-synergy-detection. Phase-1 budget verdict auto-recommends mode. Ran full-harness dogfood sweep (33 skills): fixed phantom refs, dead blocks, stale agent forks (4 deleted), trigger collision, and 3 skill-splitter splits.
- Decision: RED tier reframed as max-mode decomposition on-ramp, not hard block

### 2026-06-02 | _audit | sister-asset, token-efficiency, compression, headroom
**File:** tracks/_audit/session_2026_06_02_headroom_context_doctor.md
Cross-audited Headroom (Netflix engineer's OSS token-compression tool, vendor-reported 60–95% reduction) against context-doctor's Compression Pass per sister_asset_protocol. Same goal, different layer: Headroom is the runtime executor FH lacks; context-doctor is the judgment Headroom lacks — they compose.
- Decision: import redundancy-category targeting heuristic (MCP outputs ~70% → logs ~90% → DB → file trees) into context-doctor + name Headroom as the production-proven local option; no clone-and-own (reference + record only)
- Open: actual proxy/agent-wrap routing is a local runtime setup (outside the FH repo); v0.22 maturity — pilot first

### 2026-06-02 | frontier-digest, identity, propagation | harness-engineering, a2a, mcp, observability, context
**File:** knowledge/shared/harness-core/harness_frontier_diagnosis_2026-06-02.md
Frontier digest anchored on FH's 3-layer identity + Core Axis (WebSearch engine; curl blocked, no API key). 2026-06 signal: "Harness Engineering" named 4th AI-engineering paradigm (65% of AI failures = harness defects); A2A Agent Cards + MCP registry standardize agent discovery; AHE thesis — observability is the self-improvement bottleneck.
- Decision: 6 strengthening candidates mapped per identity (agent-card registry + dispatch overhead budget → ①; harness-defect taxonomy + observability/eval hooks → ②; L1/L2/L3 context hierarchy + compression pass → ③)
- Open: candidates are proposals only — none implemented yet. Raw signal + processing checklist held in private store (fh-be), not this public repo.

### 2026-06-01 | cross-audit, sidecar, sister-asset | pmh, agent-in-agent, multi-model, verification
**File:** tracks/_audit/session_2026_06_01_pmh_sidecar_verification.md
PMH(chrono-code) → FH cross-team 검증 요청(Issue #47) 회신. sidecar-orchestrator 환원 관련 gh copilot Critical 중 FH 소관 2건 검증. (1) multi_model_sidecar_strategy.md 완성도 = 부분 수정 필요(ollama·restricted-network 메시지·경로 어댑터·gh copilot 우선은 환원 측 책임, FH 원문 유지); (2) sidecar 존재 이유 = 검증 완료 — §Mechanism "Not an agent dispatch / stateless"가 agent-in-agent 재귀 공격을 구조적으로 반박 + Experiment 1·2 실증.
- Decision: FH 원문 유지 + 환원 어댑터는 PMH 보유 (Sister Asset Protocol — clone-and-own 금지)
- Open: sidecar 문서가 CATALOG 미등록이었던 기록 갭 → 본 커밋으로 보강

### 2026-05-31 | multi-model, sidecar, adversarial, validated | orchestrator-swap, perspective-diversity, cross-cli
**File:** knowledge/shared/harness-core/multi_model_sidecar_strategy.md
외부 모델(Gemini/Codex/Copilot CLI)을 Claude Code/FH 세션 안에서 Bash tool로 sidecar 호출하는 검증된 패턴. Experiment 1(직접 sidecar 호출) + Experiment 2(3-round orchestrator-swap)로 실증 — 각 orchestrator가 비중복 findings 발견, cross-wave delta가 convergence를 개선. perspective diversity(1순위)·model-access fallback(2순위)·token economy(3순위). §Mechanism: agent dispatch 아닌 stateless 서브프로세스.
- Decision: 하네스가 multi-model synthesis의 activation condition — sidecar는 quality compounding 메커니즘이지 단순 coverage 체크 아님

### 2026-05-31 | anti-bias, multi-team, adversarial, token-coverage | steel-quench, sim-conductor, experiment, v2-paper
**File:** tracks/_meta/fh_multiteam_token_coverage_2026_05_31.md
Experiment 5 — Multi-Team Adversarial Panel measured on source-grounding-audit SKILL.md. 4 conditions (C1 single / C2 cross-session / C3 +gemini / C4 codex-TTY-fail=C3). Key results: C1→25% coverage, C2→75%, C3→100%. Claude blind spots: 3 findings (25% of total), 1 S-grade. Claude-side cost C2→C3: +0 tokens (H3 validated — Gemini billed to separate quota). Codex CLI present but headless-inoperable. Updated steel-quench/sim-conductor/source-grounding-audit/harness-doctor/harvest-loop with Multi-Team Panel design + human gates + synthesizer cross-session. v2 paper Experiment 5 section drafted with full metrics table.
- Decision: decision rule confirmed — routine→C2 (cross-session), pre-publish→C3+ (zero Claude overhead)
### 2026-05-31 | synergy, integration, playbook | opencode, hermes, openhuman, governance, marketing
**File:** knowledge/shared/harness-core/fh_synergy_playbook.md
Concrete workflow specifications for using FH with OpenCode/Hermes/OpenHuman — grounded only in recorded experiments. Three patterns: (1) OpenCode: fh-gate.sh after code gen → DONE→PENDING flip, 2 A-grade on arity.ts; (2) Hermes: skill audit before dispatch → 2 A-grade pre-exec/credential gaps; (3) OpenHuman: Memory Tree staleness audit → GROUNDED/STALE/BROKEN verdict. Includes honest finding-rate estimates, "no integration required" value prop, and compounding effect explanation.
- Decision: no unverified claims — every stated outcome traces to a specific experiment or structural guarantee

### 2026-05-31 | integration-contract, bridge-layer, governance-interface | opencode, hermes, openhuman, v2-paper
**File:** knowledge/shared/harness-core/fh_integration_contract.md
Formal v0.1 specification for how callers (OpenCode, Hermes, OpenHuman, CI) invoke FH governance gates and receive structured verdicts. Defines: input format (newline-separated files), FH_STATUS+verdict format, findings in YAML block, parse recipe. Includes caller-specific guidance + Stop hook pattern + record spec. Gemini adversarial review found 2 A-grade issues (space-separated paths, non-parseable multi-line fields) — both fixed in v0.1. Also includes `scripts/fh-gate.sh` prompt-generator wrapper.
- Decision: findings use YAML block (not flat key-value) to prevent delimiter ambiguity; FH_STATUS mandatory for fail-safe parsing

### 2026-05-31 | opencode, governance, usage-guide, synergy | pipeline-conductor, steel-quench, v2-paper
**File:** knowledge/shared/harness-core/fh_opencode_governance_wrapper.md
Step-by-step usage guide for FH + OpenCode governance integration. 3-step protocol (diff capture → steel-quench → pipeline-conductor). No API adapter required. Includes empirical baseline from arity.ts trial: CI=DONE, FH governance=PENDING, 2 A-grade security-adjacent findings caught. Stop hook automation pattern included.
- Decision: governance wrapper documented as protocol (not API) — FH reads files OpenCode writes

### 2026-05-31 | v2-paper, opencode, governance, controlled-experiment | steel-quench, pipeline-conductor, synergy
**File:** tracks/_meta/fh_opencode_governance_experiment_2026_05_31.md
FH governance (steel-quench + pipeline-conductor --quick) applied to OpenCode's AI-generated `arity.ts`. Baseline: CI green, DONE. FH governance: PENDING — 2 A-grade findings (short-token overflow in permission allowlist, npx/opencode missing from arity table) + 1 B-grade. Delta not attributable to model — attributable to methodology layer. v2 paper prototype: controlled experiment evidence for N-fold synergy claim.
- Decision: governance layer catches issues CI misses; arity.ts short-token overflow is permission-critical and untested

### 2026-05-30 | fh-meta | edit-manifest, predict-verify, validation-gate, skill-evolution, SkillOpt, AHE
**File:** plugins/fh-meta/skills/edit-manifest/SKILL.md
New skill: predict-verify loop for harness edits. Every SKILL.md/rules/CLAUDE.md edit records a falsifiable prediction; next session verifies against actual outcomes. Validation gate (SkillOpt pattern) accepts only edits with measurable improvement; rejected edits retained as negative-feedback buffer. Integrated as harvest-loop Step 0-c.
- Decision: based on AHE (arXiv:2604.25850) change manifest + SkillOpt (arXiv:2605.23904) selection-split gate

### 2026-05-30 | fh-meta | memory-hygiene, stale-memory, staleness-detection, verification
**File:** plugins/fh-meta/skills/memory-hygiene/SKILL.md
New skill: detects "stale-but-confident" memory entries (facts verified once but silently drifted). Classifies by type (project 14d / reference 30d / feedback 90d / user 180d), re-verifies live via gh CLI or WebFetch (FH online advantage), proposes archival. Integrated as harvest-loop Step 0-c.
- Decision: based on Scaling the Harness (arXiv:2605.26112) §3.2 stale-but-confident failure mode

### 2026-05-29 | harness-core | return-path-gate, skill-chain, conditional-pass, closed-loop
**File:** knowledge/shared/harness-core/return_path_gate.md
Pattern: downstream skill returns structured verdict (PASS/CONDITIONAL_PASS/FAIL/ESCALATE) back to caller, which gates next step on it. Verified in apex-review→sim-conductor and agent-composer↔deliberation.
- Decision: promoted to knowledge/shared/ — same pattern appeared independently in 2 skill pairs

### 2026-05-29 | harness-core | meta-harness-engineering, definition, frontier, academic-convergence
**File:** knowledge/shared/harness-core/meta_harness_engineering_definition.md
Formal definition of meta harness engineering + FH positioning vs. academic convergence (arXiv 2605.18747 "Code as Agent Harness", arXiv 2604.14228 98.4% finding). Maps FH 6-axis to 3-layer taxonomy; distinguishes human-in-loop (FH) vs automation-first vs automation-maximalist approaches.
- Decision: FH differentiator = human judgment gate on all PRs, not automation maximization

### 2026-05-29 | fh-commons | token-budget-gate, token-estimation, cost-guard, multi-agent
**File:** plugins/fh-commons/skills/token-budget-gate/SKILL.md
New skill: pre-task token cost estimation with Green/Yellow/Orange/Red gate verdict. Post-task calibration loop improves future estimates. Auto-proposed before agent-composer, sim-conductor, steel-quench, harvest-loop.
- Decision: placed in fh-commons (project-agnostic, useful before any expensive multi-agent task)
- Thresholds: <10K green / 10-30K yellow / 30-60K orange / >60K red (user-configurable)

### 2026-05-29 | fh-commons | mcp-circuit-breaker, mcp-reliability, tool-failure, fallback
**File:** plugins/fh-commons/skills/mcp-circuit-breaker/SKILL.md
New skill: detects MCP tool failure patterns (3 consecutive fails = trip), blocks further calls, proposes 3-tier fallbacks, and resets via HALF-OPEN probe after cooldown.
- Decision: placed in fh-commons (project-agnostic MCP guard, useful in any Claude Code project)
- Circuit states: CLOSED → OPEN → HALF-OPEN → CLOSED

### 2026-05-29 | fh-meta | prompt-regression, regression-detection, harness-quality
**File:** plugins/fh-meta/skills/prompt-regression/SKILL.md
New skill: detects harness behavioral regressions after CLAUDE.md / rule / skill edits by running standard probe suite and comparing against baselines.
- Decision: placed in fh-meta (harness-specific behavioral testing, not general-purpose)
- Chain: FAIL verdict → harness-doctor → verify-bidirectional

### 2026-05-28 | _meta | install-wizard, plugin-autoinstall, deprecated-cleanup, fh-ops, external-validation
**File:** tracks/_meta/session_2026_05_28_fh-external-ops.md
First external run of FH — install-wizard (score 57/100) revealed 2 friction points, both fixed immediately. PR #7 (plugin auto-install) + PR #8 (deprecated refs cleanup) merged.
- Decision: install-wizard FH plugin MISS → AI auto-runs via Bash (eliminates 3-turn manual flow) — "friction only visible when the builder actually uses it" pattern
- Decision: deprecated refs must be updated alongside CHANGELOG — separate cleanup PR required

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
Wave 3 meta-validation: confirmed all previously restricted-network-blocked capabilities work on a standard network — install-wizard dry-run, plugin-recommender live GitHub search, frontier-digest fetch, git push. Baseline for external user environment parity.
- Decision: All core FH capabilities verified functional on a standard (unrestricted) network

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

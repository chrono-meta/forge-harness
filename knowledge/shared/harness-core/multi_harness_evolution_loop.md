# Multi-Harness Evolution Loop — audit → persona → fix → devolution-check → settle

> Operator-forged pattern (2026-07-17). The operator ran this sequence once across three harnesses
> and named it afterward: *"오늘 내가 제시한 기법 자체가 fh·pmh를 진화시킬 수 있는 루프였을 거라고
> 생각해."* This doc is the harvest — the loop as a repeatable protocol, with its n=1 evidence and
> a promotion gate. It is a **composition of existing FH checks** (no-reinvention: every phase
> routes to an existing asset); what is net-new is the loop shape and its two doctrine points below.

## The loop (5 phases)

| Phase | What runs | Existing asset routed | Check class |
|---|---|---|---|
| **1. Structure audit** | harness-doctor lens per harness **+ a cluster lens across them** (registry freshness · track sync · cross-refs · skill-bus reachability · gate propagation · orchestration artifacts) | `/harness-doctor` · LOCAL_SKILL_REGISTRY · Field-Harness gates | mechanical + judged |
| **2. Persona usability audit** | beginner (cold-read, minutes-to-first-value) · main-player (daily intent-utterance test: do natural phrases reach the right skill?) · expert (frontier bar, external citations mandatory) — per harness | fh-meta persona agents (beginner / main-player / expert) | judged, adversarially paired by tier diversity |
| **3. Fix application** | fixer agents per repo, **verify-before-act on every claimed defect** (a false finding gets skipped with evidence, not applied); each repo's own gates honored, HITL-deferred items go to a ranked backlog instead of being forced | fixer dispatch + per-repo 4-axis / pre-commit gates | mechanical (grep-verify per fix) |
| **4. Devolution check** | adversarial regression audit of the fixes themselves — *"is anything now WORSE than before?"* — cross-family (codex) on public repos, same-family with an honest residency note on company repos; **iterate fix→re-verify until CONVERGED** | `auto-decorrelation` posture · codex headless · target-tier blind sim | cross-family + mechanical anchor |
| **5. Settle** | canonical wiki node + INDEX pointer (machine side) **+ operator-readable report pushed to where the operator actually reads** (Obsidian/iCloud mirror) + ranked M/S/R backlog of operator-decision items | wiki 규약 · sync-wiki-to-icloud | mandatory-pass (artifacts exist) |

## Two doctrine points (the net-new judgment content)

1. **Usability is a first-class diagnostic axis, not polish.** The loop's n=1 run found the same
   root defect in all three harnesses — *the routing surface was narrower than the user's real
   daily utterances* — and structure-only audits (phase 1 alone) had missed it for months. The
   operator's framing is the axis: "성능이 좋아도 결국 사용하기 쉽고 직관적이어야" — a harness whose
   speech doesn't reach is failing regardless of internal rigor. Phase 2 is therefore not optional
   decoration on phase 1; it is the half of the diagnosis that structure scans cannot see.
2. **Improvement without a devolution check is half a loop.** Phase 4 exists because phase 3's
   fixes are themselves AI-authored changes — the same optimistic-author blind spot the
   cross-family gate guards. In the n=1 run, phase 4 caught a real regression that phases 1–3
   produced (a README layer mis-attribution that made vague wording *wrong*), plus two S-tier
   follow-ups in the field fixes. "다 하고 나서 기존보다 어떻게 개선되었는지, 오히려 퇴화한 부분은
   없는지 점검" — the loop is not done at "fixes applied"; it is done at CONVERGED.

## Guards (inherited, restated for the loop)

- **Residency**: company-token repos never go to an external model family; their devolution check
  runs same-family with the limitation recorded, not hidden.
- **Verify-before-act**: every audit finding is re-verified against disk before a fixer applies it
  (n=1 run: one "typo" finding was in-house jargon — correctly skipped with source evidence).
- **HITL boundary**: judgment items (canonical-count decisions, dual-source direction, gate
  loosening, architecture surgery) are never auto-applied — they land in the ranked backlog.
- **Autonomy floor**: compose/rank judgments at opus-tier+; the loop was designed to run
  autonomously on an explicit operator go ("자체적으로 돌아줘"), not as a standing daemon.

## n=1 evidence (2026-07-17)

Three harnesses (FH hub + two mapped field harnesses), 21 agents total (12 audit · 2 fixer ·
7 verification). Outcomes: hub always-loaded footprint over-threshold closed (TARGET-rooted
95.8k → 79.9k chars); three repos' routing surfaces extended to cover the measured daily
utterances; ~10 phantom references replaced with disk-verified targets; registry brought to
parity (mirror-dedup for the fork, lockline for the irreversible-execution skill); one real
regression caught and fixed by the cross-family pass; final verdicts CONVERGED across all three
repos. Ranked residual backlog delivered for operator decisions.

## Promotion gate

This doc is the pattern's home at **n=1**. Per evidence-threshold build discipline, do NOT build a
skill or runner from it yet. Promotion path: a second full run (n=2, ideally on a different harness
set or triggered from a field cwd) → then decide skill-ification (`/harness-evolution-loop`
orchestrator skill, chamber-screened) vs staying a documented protocol. Cadence candidate
(quarterly, alongside the harness-doctor 30-day cadence) is also an n≥2 decision.

Related: `harness_6axis_framework.md` (axes 5–6) · `field_harness_diagnostic.md` (single-project
pull sibling) · `hub_compounding_loop.md` (the learning-return this loop feeds) ·
`measurement-integrity-checklist.md` (phase-4 instrument hygiene — the n=1 run also invalidated a
contaminated sim and re-ran it with a verbatim-quote protocol).

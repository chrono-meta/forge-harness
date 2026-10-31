---
name: verify-bidirectional-detail
description: On-demand detail for verify-bidirectional SKILL.md (moved verbatim; salience split).
load: on-demand
---

# verify-bidirectional — on-demand detail

## §Doctrine-Miss-Measurement

**Why these were missed 4 times out of 4** — they sit in the blind spot between the triggers (which
expect a *challenge*) and the **Exceptions** list in SKILL.md (which release a *simple correction* with "no
review"). A doctrine statement is neither: it does not dispute a claim, and it is not a one-off fix
to apply and forget. Treated as the exception, it gets a verbal acknowledgment and evaporates at
session end. **Measured**: four such statements in one session, all acknowledged in conversation,
**zero landed in any file** until a later review grepped for them and found nothing.

## §Dead-Key-History

(Previously cited as `feedback_markdown_edit_discipline` — that memory key is **absent, verified
2026-08-12**. The rule is live; only the pointer was dead, so it is written out here. A prohibition
that rests on a file nobody can open is not enforceable.)

## §Proactive-Concern-Background

Background: If the user proceeds without detecting a wrong direction or without being able to express doubt, it comes back at a much greater cost later. Waiting for the back-and-forth build-up transfers the responsibility of detecting premise errors to the user.

## §External-User-Adaptation

### Fallback Matrix (origin environment → external environment replacement)

| Origin Environment Dependency | External User Environment Fallback |
|---|---|
| Rule body — **this SKILL.md itself** (the origin environment's `memory feedback_bidirectional_self_validation.md` is **absent, verified 2026-08-12**; there is no origin-side file to fall back from) | User environment's own `memory/` or `notes/` bidirectional validation rule / if absent, this skill's own rule baseline — which is now the only baseline in either environment |
| `memory feedback_*.md` grep scope (Step 2 priority 1) | User environment's own `learnings/` · `docs/` · `CLAUDE.md` grep (user's own baseline) |
| `tracks/*/learnings/feedback_*.md` (Step 2 priority 2) | User environment's own learnings area (auto-detect naming variations) |
| `knowledge/shared/harness-core/*.md` (Step 2 priority 4) | User environment's own `docs/` or `knowledge/` grep |
| `CATALOG.md` entry addition (Step 4) | User environment's own history archive (skip if absent) |
| `reference_next_session_starter.md §1` (Step 4) | User environment's own next-session material (skip if absent) |
| Mandatory grep keywords ("drift", asset ownership, etc.) | User environment's own baseline keywords (prioritize asset names, abbreviations, identifiers from user's message) |

### External User Scenarios

1. **General bidirectional validation**: AI recommendation → user refinement challenge → this skill auto-activates → 6-step processing (Step 1 immediate baseline update / Step 2 consistency grep / Step 3 fact-checker self-catch / Step 4 immediate patch / Step 4.5 diff gate / Step 5 compatibility enhancement / Step 6 update trigger count)
2. **User's own baseline cross-ref**: Generalize Step 2 grep scope to user environment's own assets
3. **Fact-checker count generalization**: Start user's own self-catch count from 0 (narrow 1 / broad N+1)
4. **Same user approval gate**: Step 4.5 diff review / Step 4 major decision cascading / Step 6 Skill v0.x update

### Limits

- **External users can use their own model cross-check channel** (e.g., other LLM API, other in-house model)
- **Accumulated validation history** = accumulates from origin for the original developer / external users start their own count from 0
- **Autonomous activation baseline examples** (harvest-loop + hub-persona-auditor) = origin environment baseline / external users can also trigger autonomous activation on their own natural cadence
- External users also follow same user approval gate (Human-in-the-loop principle baseline)

## §Why-Judged-And-Paired

> **Why the last two are judged, and paired.** This skill fires when the user pushes back, which is
> precisely the moment agreement is cheapest. A Done When that only counts steps is satisfied by a
> run that folded immediately. The pairing is the whole check: an isolated re-grep, and an isolated
> critic — neither of which has seen this session's reasoning.

## §References

> **All memory keys below were checked on 2026-08-12 and every one is absent** (same-run
> known-positive control: `feedback_verify_before_downgrade.md` and `memory_intent_recall.md`
> both resolve, so the check is not misreporting). A struck entry here is not a fix if the same
> name is still load-bearing above — the rules those keys carried have been written into the body
> of this skill (Step 4 markdown discipline, §Constraints, §Validation Ledger), which is why the
> strikethroughs below are safe to leave as history.

- ~~Rule body: `memory feedback_bidirectional_self_validation.md`~~ — **absent (verified 2026-08-12)**. The rule body is **this file**; the cumulative count lives in §Validation Ledger.
- ~~Operating model text: `memory feedback_hub_cc_operating_model.md §2.5·§2.6`~~ — **absent (verified 2026-08-12)**. The live equivalent is `CLAUDE.md §Identity`; cite that, not this filename.
- ~~Consistency rules: `feedback_external_ai_github_recommendation_verification` · `feedback_reference_own_hub_assets_first` · `feedback_simplification_evidence` · `feedback_markdown_edit_discipline` · `feedback_impact_first_then_tune`~~ — **absent (verified 2026-08-12)**. The two that this skill actually depends on are restated in §Constraints above.
- Live, verified references (these resolve): `tracks/_meta/reference_next_session_starter.md` (session card, Step 4) · `CATALOG.md` · the `fact-checker` agent (Step 3).

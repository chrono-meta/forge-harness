---
type: audit
date: 2026-05-17
scope: fh-meta 18 skills + 3 agents
auditor: report-agent
version: v1.0
---

# fh-meta Utterance Coverage Audit — 2026-05-17

> **Purpose**: Evaluate whether 18 skills + 3 agents can be naturally triggered by real user utterances.  
> Check install-wizard coverage scope + map discovery paths by user type + output M/S/R tiers.

---

## 1. Full Utterance Coverage Table

| # | Asset | Type | Verdict | Natural Utterance Examples | User Stage | Notes |
|:---:|---|:---:|:---:|---|:---:|---|
| 1 | plugin-recommender | skill | ✅ | "I want to handle Jira tickets", "recommend a plugin", "how do I visualize DB?" | new/returning | Most natural coverage |
| 2 | install-wizard | skill | ✅ | "initial setup", "help me configure", "wizard" | new | separate slash-command `/install-wizard` |
| 3 | context-doctor | skill | ✅ | "wasting tokens", "session is slow", "clean up context", "claudeignore" / auto-triggers if .claudeignore missing | new | Suppress sentinel prevents duplicates |
| 4 | pr-review-watcher | skill | ✅ | "I submitted a PR", "when will review come", "notify me when review arrives" | returning | Monitoring role — distinct from hub-cc-pr-reviewer |
| 5 | audit-learnings | skill | ✅ | "summarize what I did this week", "let's do a retrospective", "this looks like a skill candidate", "let's organize repeating patterns" | returning | Auto-proposed when 7+ days elapsed / no bg parallel |
| 6 | verify-bidirectional | skill | ✅ | "isn't that right?", "something seems off", "any counterarguments?", "double-check" | returning | v0.8 added proactive concern utterances |
| 7 | sim-conductor | skill | ✅ | "look at this from an external user's perspective" (Area A), "check the harness" (B), "any new ideas?" (C), "code review" (D), "is the output good?" (E) | returning/advanced | Diverse natural language per Area |
| 8 | hub-cc-pr-reviewer | skill | ✅ | "review PR #N", "check PR #N", "command tower review", "baseline consistency check" | returning | Review role — distinct from pr-review-watcher |
| 9 | install-doctor | skill | ✅ | "is it okay to add this plugin?", "any overlaps?", "something's off after install", "check install conflicts" | returning | install-wizard Three-Doctor Loop link |
| 10 | deliberation | skill | ⚠️ | "battle them out", "make them argue", "clash and synthesize" / agent-composer Wave next-D | returning/advanced | New v0.1 — "battle"/"argue" vocabulary needed; "look at this decision from multiple angles" may be more natural |
| 11 | harness-doctor | skill | ⚠️ | "harness diagnosis", "check harness structure", "structure audit" | returning | Requires "harness" vocabulary; cannot trigger without it |
| 12 | marketplace-gate | skill | ⚠️ | "can I put this in the marketplace?", "pre-registration check", "confirm before publish" | advanced | Requires "marketplace" concept |
| 13 | agent-composer | skill | ⚠️ | "compose the agents", "pick automatically", "which agent should I use?" | advanced | Presupposes "agent" concept; "compose" may be unfamiliar |
| 14 | field-harvest | skill | ⚠️ | "should I add this to FH?", "is this worth reverse-injecting?", "pattern harvest" | advanced | Depends on internal FH vocabulary |
| 15 | asset-placement-gate | skill | ⚠️ | "can I make this an FH skill?", "where should I put this agent?" | advanced | All internal FH vocabulary; external users cannot trigger |
| 16 | frontier-status-summary | skill | ⚠️ | "show FH frontier status", "where are we at", "what Phase are we at" | advanced | Requires "frontier", "Phase" internal vocabulary |
| 17 | cross-ecosystem-synergy-detection | skill | ⚠️ | "check the environment", "are things working in silos?", "can they integrate?" | advanced | Requires "cross-ecosystem", "synergy" vocabulary; some triggers are natural |
| 18 | meta-prompt-builder | skill | ⚠️ | "what should I tell each agent?", "write prompts per Wave", "design the instructions" | advanced | Only natural after agent-composer composition — standalone entry is difficult |
| 19 | hub-persona-auditor | agent | ❌ | None — main agent invoke only | — | No direct user trigger; core quality gate for external assets but self-discovery impossible |
| 20 | fact-checker | agent | ❌ | None — auto-invoked in agent-composer Wave 0 | — | No direct trigger; no user awareness path |
| 21 | persona-innovator | agent | ❌ | None — indirect via sim-conductor Area B/C / Mode T internal path | advanced | No direct trigger; no intentional invocation path |

**Verdict criteria**:
- ✅ Natural utterance possible: triggerable via general user natural language (no FH vocabulary required)
- ⚠️ Internal vocabulary dependent: requires FH-specific terminology or conceptual awareness
- ❌ No trigger path: direct user trigger undefined / orchestrator-only access

---

## 2. install-wizard Coverage Gaps

### Skills Covered by install-wizard (5)

| Skill | install-wizard guidance |
|---|---|
| audit-learnings | Weekly audit routine — recurring pattern harvest |
| context-doctor | .claudeignore setup guidance |
| harness-doctor | Harness structure diagnosis link (Three-Doctor Loop) |
| sim-conductor | Meta-simulation quality verification link (Three-Doctor Loop) |
| install-doctor | Plugin conflict diagnosis link (Three-Doctor Loop) |

### Skills/Agents Not Covered by install-wizard (13)

| Asset | Gap Severity | Reason |
|---|:---:|---|
| plugin-recommender | S | Most likely needed first by new users — natural to link at end of install-wizard flow |
| verify-bidirectional | R | Discoverable via natural utterance by returning users; no need to introduce right after install |
| pr-review-watcher | R | Discoverable via natural utterance at PR creation stage |
| hub-cc-pr-reviewer | R | Discoverable via natural utterance at PR creation stage |
| deliberation | S | New skill (v0.1) — even a one-line intro in install-wizard would secure a discovery path |
| agent-composer | S | Core entry point for advanced users but introduced nowhere |
| meta-prompt-builder | R | Post-agent-composer stage — natural utterance possible after prerequisite skill is found |
| field-harvest | R | Advanced users only — internal vocabulary dependent |
| asset-placement-gate | R | Advanced users only — internal vocabulary dependent |
| frontier-status-summary | R | Advanced users only — internal vocabulary dependent |
| marketplace-gate | R | Advanced users only — natural utterance at marketplace registration time |
| cross-ecosystem-synergy-detection | R | Advanced users only — triggers at ecosystem expansion time |
| hub-persona-auditor | S | Agent — direct trigger impossible, but recommend introducing "auto-audit after external asset completion" concept in install-wizard |
| fact-checker | R | Agent — Wave 0 auto-invocation; description sufficient |
| persona-innovator | R | Agent — indirect access via sim-conductor; sufficient |

**Core gap**: The 5 skills install-wizard introduces are centered on the Three-Doctor Loop, which is thorough for establishing **daily work routines**, but lacks paths for **plugin ecosystem exploration** (plugin-recommender) and **agent discovery** (agent-composer, hub-persona-auditor, deliberation).

---

## 3. Discovery Paths by User Type

### 3-1. New User (first time with FH)

```
Entry: install-wizard (✅ directly guided)
  └─ context-doctor   (auto-triggers if .claudeignore missing)
  └─ harness-doctor   (Three-Doctor Loop intro)
  └─ sim-conductor    (Three-Doctor Loop intro)
  └─ install-doctor   (Three-Doctor Loop intro)
  └─ audit-learnings  (weekly audit routine intro)

Discovered via natural utterance:
  └─ plugin-recommender  ("I want to do X" → immediately triggers)
  
❌ Not discoverable by new users:
  └─ agent-composer, deliberation, hub-persona-auditor, fact-checker, persona-innovator
  └─ all ⚠️ internal vocabulary skills (except harness-doctor)
```

### 3-2. Returning User (1~2 uses, basic vocabulary known)

```
Triggered via natural utterance:
  └─ audit-learnings        ("summarize what I did this week")
  └─ verify-bidirectional   ("is that right?", "any counterarguments?")
  └─ pr-review-watcher      ("I submitted a PR", "when will review come?")
  └─ hub-cc-pr-reviewer     ("review PR #N")
  └─ install-doctor         ("any overlaps?")
  └─ sim-conductor          ("look from an external user's perspective")

Triggered after learning internal vocabulary:
  └─ harness-doctor         ("harness diagnosis" — if "harness" is known)
  └─ deliberation           ("battle them out", "make them argue" — if vocabulary is known)

❌ Difficult for returning users:
  └─ agent-composer, meta-prompt-builder, field-harvest, asset-placement-gate
  └─ frontier-status-summary, cross-ecosystem-synergy-detection
  └─ hub-persona-auditor, fact-checker, persona-innovator
```

### 3-3. Advanced User (understands agent-composer, has FH vocabulary)

```
Active combinatorial utterances:
  └─ agent-composer         ("compose agents", "what's the optimal combination?")
  └─ meta-prompt-builder    (after agent-composer: "design the instructions")
  └─ deliberation           (Wave next-D auto-proposed or direct "/deliberation")
  └─ marketplace-gate       ("can I put this in the marketplace?")
  └─ field-harvest          ("should I add this to FH?")
  └─ asset-placement-gate   ("where should I put this as an FH skill?")
  └─ frontier-status-summary ("show FH frontier status")
  └─ cross-ecosystem-synergy-detection ("check the environment", "are things siloed?")

Discovered via agents:
  └─ hub-persona-auditor    (main agent call — after external asset completion)
  └─ fact-checker           (agent-composer Wave 0 auto-invocation)
  └─ persona-innovator      (via sim-conductor Area B/C)
```

---

## 4. deliberation Special Review (new skill v0.1)

**4 review items:**

| Item | Current State | Verdict |
|---|---|:---:|
| Trigger natural language sufficiency | "battle them out", "make them argue", "clash and synthesize" — requires specific vocabulary ("battle", "argue") | ⚠️ |
| agent-composer linkage path | Wave next-D auto-proposed — advanced users can auto-trigger | ✅ |
| slash-command existence | `/deliberation` exists | ✅ |
| New user discovery path | Not introduced in install-wizard / no natural utterance | ❌ |

**Recommendation**: Adding general decision-making utterances like "look at this from different perspectives", "which one is right?", "two views are clashing" as triggers should increase returning user discovery.

---

## 5. M/S/R Tier Summary

### M (Mandatory) — 2 items requiring immediate action

| # | Asset | Issue | Recommended Action |
|:---:|---|---|---|
| M-1 | **hub-persona-auditor** | Zero direct user trigger utterances. Core quality gate for externally distributed assets, yet users cannot know it exists. Not introduced in install-wizard either. | Add trigger utterances for hub-persona-auditor OR add 1-line "auto-audit runs after external asset completion" to install-wizard |
| M-2 | **fact-checker** | Wave 0 auto-invoked agent but users cannot recognize its existence or role. No awareness path without using agent-composer. Only explained in README. | README introduction + add 1-line fact-checker role description to agent-composer SKILL.md Wave 0 / add mention in install-wizard |

### S (Strong) — 7 items recommended within next session

| # | Asset | Issue | Recommended Action |
|:---:|---|---|---|
| S-1 | **deliberation** | New skill (v0.1). Requires "battle", "argue" vocabulary — general utterance "look at this decision" does not trigger. Not introduced in install-wizard. | Add "which one is right?", "two views are clashing", "look at this decision from multiple angles" to triggers |
| S-2 | **agent-composer** | Presupposes "compose", "agent" vocabulary. Not introduced in install-wizard — only advanced users can discover it. Core FH coordinator with a narrow discovery path. | Add 1-line intro "next step — automate complex work with agent-composer" after install-wizard or audit-learnings completes |
| S-3 | **plugin-recommender** | Coverage is ✅ but not introduced in install-wizard. The skill new users most likely need first, yet install-wizard does not link to it directly. | Add "not sure which plugin you need? → plugin-recommender" link at the end of install-wizard |
| S-4 | **persona-innovator** | No trigger utterances. Only accessible via sim-conductor Area B/C. Has naming function (Mode T) valuable to advanced users, but no access path. | Add hint "persona-innovator can be called directly: /persona-innovator" to sim-conductor SKILL.md Area B/C output |
| S-5 | **cross-ecosystem-synergy-detection** | Some natural utterances ("check the environment", "are things siloed?") exist but skill name ("cross-ecosystem") is too far from natural speech. No auto-proposal mechanism after install. | Link cross-ecosystem-synergy-detection auto-proposal in context-doctor or install-wizard when multiple plugins are detected |
| S-6 | **frontier-status-summary** | Requires "frontier", "Phase" internal vocabulary. Could be used by external users to understand FH status, but no trigger path. | Add natural trigger utterances like "where is FH now?", "show FH status" |
| S-7 | **hub-persona-auditor trigger intro** | (S-tier follow-up from M-1) Add 1-line "hub-persona-auditor auto-audits before external asset publishing" to install-wizard | Include in install-wizard Step final checklist |

### R (Recommended) — 5 backlog items

| # | Asset | Issue | Recommended Action |
|:---:|---|---|---|
| R-1 | **harness-doctor** | "Harness" vocabulary required. Returning users who know the term can trigger naturally. Recommend adding general expressions like "check the structure", "is everything organized?" as triggers. | Trigger natural language reinforcement (backlog) |
| R-2 | **meta-prompt-builder** | Post-agent-composer stage only. Structure where natural utterance is possible after prerequisite skill is found is correct. However, recommend adding hint "for detailed instructions → /meta-prompt-builder" to agent-composer SKILL.md Step 2 output. | Add hint to agent-composer SKILL.md Step 2 output format |
| R-3 | **field-harvest** | "Should I add this to FH?" utterance is context-dependent. More natural triggers like "save this pattern", "record this for later use" could be added. | Trigger natural language reinforcement (backlog) |
| R-4 | **marketplace-gate** | Natural utterance possible at marketplace registration time. Appropriate as advanced user only. Current triggers sufficient. | Keep as-is |
| R-5 | **asset-placement-gate** | Internal FH vocabulary dependent but appropriate as advanced user only. Can share triggers with field-harvest. | Keep as-is or link with field-harvest triggers |

---

## 6. Overall Summary

| Verdict | Count | Assets |
|:---:|:---:|---|
| ✅ Natural utterance possible | 9 | plugin-recommender, install-wizard, context-doctor, pr-review-watcher, audit-learnings, verify-bidirectional, sim-conductor, hub-cc-pr-reviewer, install-doctor |
| ⚠️ Internal vocabulary dependent | 9 | deliberation, harness-doctor, marketplace-gate, agent-composer, field-harvest, asset-placement-gate, frontier-status-summary, cross-ecosystem-synergy-detection, meta-prompt-builder |
| ❌ No trigger path | 3 | hub-persona-auditor, fact-checker, persona-innovator |

| Tier | Count | Action Criteria |
|:---:|:---:|---|
| M | 2 | Immediate — no trigger path + core function |
| S | 7 | Within next session — improve internal vocabulary dependency or add intro |
| R | 5 | Backlog — improvement valuable but does not impede current operations |

**install-wizard coverage**: 5 of 18 introduced (28%) — Three-Doctor Loop focused. Adding plugin-recommender · agent-composer · deliberation · hub-persona-auditor introductions achieves 50%+ coverage.

**deliberation verdict**: ⚠️ S-tier given new v0.1 status. agent-composer Wave next-D linkage works but standalone discovery path needs reinforcement. Recommend adding 3~4 general decision-making trigger utterances.

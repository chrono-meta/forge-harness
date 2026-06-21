---
description: Defines the 4 harness usage modes (A canonical / B resident / C plugin-only / D developer) and the differentiated value automatically received on install (Layer 1 rules + Layer 2 skills).
---

# Harness Usage Modes + Differentiated Value

## Usage Modes — "Don't block those who come, don't block those who leave"

The forge-harness maintains **a reference asset identity** — user entry and exit are free. The AI guides and supports any mode without refusal.

### 4 Mode branches

| Mode | Essence | AI guidance and support obligation | Contribution path |
|---|---|---|---|
| **A — Canonical** | Harness cwd setup → hand off to separate project cwd → field agent works | Active onboarding 5-skill cascade + cwd handoff guidance | Direct (bidirectional sync circuit active) |
| **B — Resident** | Create a **separate project directory** in the harness install environment and work there | Required to guide "separate project directory + proper `.gitignore`" | Indirect (harness itself maintains reference asset identity) |
| **C — Plugin/skill only** | Install only plugin/skill without cloning harness | Guide user to accumulate history on their own project side. Explicitly state no automatic harness signals expected | Indirect + dependent on user active invocation |
| **D — Developer/Researcher** | **Using FH while also developing/researching FH itself.** Public mirror (forge-harness) holds methodology; a private companion store (the `*-be` companion pattern) holds paper drafts, experiment logs, raw signals, and a mirror of gitignored local session data. | Guide companion-store setup (the `*-be` companion pattern). Mandatory: `.gitignore` keeps drafts local; `handoff/` enables cloud→local session continuity; a sync hook (e.g. a CC Stop hook) auto-mirrors gitignored local session data → the companion store. | Direct + private (gitignored local files auto-synced to companion store via Stop hook; explicit push for paper-drafts/signals) |

### AI guidance principles

- If user explicitly states a mode, immediately guide that mode. Do not force canonical mode (Mode A).
- Mode B: **Mandatory check of separate project directory creation + `.gitignore` harness asset isolation**
- Mode C: Guide history accumulation mechanism on user's project side. Harness side actively absorbs via issue monitoring and PR audit cadence.
- Mode D: **Mandatory companion-store setup guidance** (backend pluggable — `*-be` repo · Obsidian vault · gbrain LLM-wiki; see *Pluggable backends* below). Public mirror = methodology only. Private store layout: `paper-drafts/` · `paper-signals/` · `digests/` · `handoff/` · `tracks-meta/`. `handoff/` files bridge cloud session → local session. `tracks-meta/` receives gitignored local session data via a sync hook (e.g. a CC Stop hook) so sync is automatic after setup. Field projects can use the same dual-repo pattern.
- In any mode: do not accumulate user personal work in the harness directory itself (protect reference asset identity)

---

## Companion-Store Recommendation + Ephemeral-Environment Handoff

> Two related, **non-coercive** guidances. FH is public and forces nothing — a user with no companion store and no ephemeral runs is never prompted by either.

### When to recommend a companion store (conditional — never forced)

Recommend the private companion store (the `*-be` companion pattern) **only when both** hold:
- the user is **accumulating their own context/synergy into the meta-harness** — preparing a contribution, or building personal synergy on top of FH — **and**
- they keep **no separate local fork / project directory** for it.

In that state the accumulation would otherwise be **lost on an ephemeral reclaim** or **pollute the public reference asset** (drift). A private companion store gives the drafts / signals / handoffs a durable, separate home, keeping the public mirror methodology-only.

**Not prompted**: users with a local fork or separate project dir; Mode A/B/C users who do not accumulate personal context into FH. The companion store is a suggestion surfaced to those who would benefit — not a requirement, and not implied by any other rule.

### Pluggable backends — the store's role is backend-agnostic

The companion store is a **role** (durable private home for drafts · signals · handoffs · gitignored-session mirror), not a fixed technology. Do **not** force a new `*-be` git repo on a user who already runs a durable knowledge store. At setup, offer the backend that fits their existing workflow:

**FH emits the same artifact for every backend — markdown output files.** The backend differs only in how it *consumes* them, so no per-backend writer needs building:

| Backend | When | Consumption (FH just writes markdown to a target path) |
|---|---|---|
| **`*-be` git repo** (default) | Operator wants git-versioned state + Stop-hook auto-mirror | markdown committed to the private repo |
| **Obsidian vault** | User already gardens knowledge in Obsidian | point the output path at the vault — Obsidian *is* markdown, so it's backlinked instantly, zero new infra (works today). Its **graph view is a near-free Observability surface** — FH's self-named weak ETCLOVG layer (`harnessfix_etclovg_sister`): the compounding link structure becomes *visible* for this backend at no added cost (imported from the 김효율 AX-Obsidian cross-audit, `tracks/_audit/session_2026_06_21_kim-hyoyul-ax-obsidian-wiki-harness.md` §4). |
| **LLM-wiki / gbrain** | User runs a queryable memory brain | the user's gbrain **ingests** the emitted markdown (`gbrain` ingest); a deeper FH→gbrain MCP integration is a future candidate, **not wired today** |

**Invariant across all backends** (unchanged): methodology stays in the public mirror (single-source guard); the store holds only *outputs*, never a rule copy; no domain-work pollution of the reference asset. Backend is a setup-time choice; the role, guards, and ephemeral-handoff rule below are identical regardless of backend. Rationale + import/propagate ledger: `knowledge/shared/harness-core/companion_store_pluggable_cross_audit_2026-06-11.md`.

### Ephemeral-environment handoff (mode-agnostic — applies to anyone)

When FH work runs in an **ephemeral, git-invoked environment** (Claude Code on the web, a GitHub Action, any cloud sandbox reclaimed after the session) **and** an open next action can only run locally (machine-bound steps the cloud session cannot do — installing hooks, native CLI runs like `/goal`, long-lived processes), **leave a surfaced handoff in a durable location before the session ends**:
- **Mode D (companion store exists)** → the store's `handoff/` file.
- **Otherwise (default — anyone)** → a handoff note committed to the **working repo**, or a PR comment. Everyone has the working repo, so **no companion store is required** for this.

The handoff must be the obvious entry point a fresh local session lands on — its own file/comment carrying status + the single immediate next action + exact steps — not a footnote buried in a digest. **Never rely on gitignored / local-only files** (`.claude/settings.json`, and `tracks/_meta/*` unless you are Mode D with sync confirmed) for cross-session continuity in an ephemeral environment; they are wiped on reclaim. Mode D exception: gitignored local session data is auto-synced to the companion store via a Stop hook — durable for local-to-local continuity, but the sync hook itself does not run in cloud/ephemeral environments, so `handoff/` remains the correct channel there.

### Session-start freshness — the card is a pointer, the committed store may be fresher (Mode D)

At session start, after loading the companion store (or, for non-Mode-D users, the working-repo handoff), **check the store's newest *committed* work, not only the session card**. The companion store is a **durable git-committed repo** — distinct from the gitignored local mirror the paragraph above warns against; reading its commit history is safe *because* it is committed. A session card is written at one moment, but another environment or a later session can commit **newer** work to the store *after* that card. So **"pull is up-to-date" ≠ "I have seen the latest work."**

- Concretely: compare the store's **newest commit date** to the card's date; if newer, read that content and reconcile it into the session plan/greeting *before* acting.
- Precedence is **reconcile, not override**: newer-by-date content *triggers a read-and-reconcile* — it never silently wins over the card. The card may have been deliberately edited *after* a mechanical auto-sync commit (the card is written last in the close chain; the Stop hook fires on every stop), so **commit-recency ≠ authoring-authority**. When card and recent commits disagree, surface both and reconcile — do not let the newer timestamp auto-win.
- Distinct from the Agent-View pre-read (in the hub `CLAUDE.md` §Session Wrap-up, which fires only in worktree/Agent-View sessions): this fires on **every** session start.

*Salience note*: session-start prose, not hook-enforced (no SessionStart hook — `operational_adaptation.md` §Guards defers it, 2026-06-16); on a weaker tier it may silently not fire. Accepted, not silent — revisit if a target-tier sim measures a miss.

**Single-source guard**: this methodology lives here in the public mirror. A companion store holds only the *outputs* that follow it (digests · signals · handoff files), never a copy of the rule.

---

## What You Get on Install — the value the harness adds

The forge-harness bundles **rules, skills, and session protocols** into one environment — not a standalone plugin list. Two layers combined:

### Layer 1 — Core assets (rules domain / auto-activated on harness install)

| Core asset | Essence | Mode A | Mode B | Mode C | Mode D |
|---|---|:---:|:---:|:---:|:---:|
| **Active onboarding protocol** | Greeting trigger → 5-skill auto cascade | ✅ | ✅ | ❌ | ✅ |
| **Harness usage mode 4 branches** | User-free mode branching + AI guidance obligation | ✅ | ✅ | ❌ | ✅ |
| **Asset synergy branch judgment** | Auto-judgment of meta/hub seed vs field persistent location for new assets | ✅ | ✅ | ❌ | ✅ |
| **Memory system auto-operation** | User utterances/insights auto-persisted + intent-based + associative auto-recall | ✅ | Partial | ❌ | ✅ |
| **Companion-store routing** | Drafts/signals/handoffs → private store; methodology → public mirror | ❌ | ❌ | ❌ | ✅ |

### Layer 2 — Skills domain (can separate plugin/skill / available in all Modes A·B·C·D)

| Skill | Essence |
|---|---|
| `plugin-recommender` | Tier 1·2·3 classification + organization GHE + token check |
| `cross-ecosystem-synergy-detection` | GHE cluster + Tier classification baseline |
| `harvest-loop` | Weekly audit + self-evolution pipeline + Phase 2+ PR auto-proposal |
| `verify-bidirectional` | Bidirectional self-verification + user-AI baseline update circuit |
| `frontier-digest` | External-facing asset cross-ref + frontier trend + per-audience guide |
| `hub-cc-pr-reviewer` | PR diff → baseline coherence check → review comment auto-generation |
| `context-doctor` | `.claudeignore` auto-generation + large file detection + `/clear` timing guidance |
| `harness-doctor` | Harness structure L1~L4 diagnosis + M/S/R prescription |
| `sim-conductor` | External scenario/internal audit/ideation scan autonomous execution + M-tier auto PR |

### Synergy — Layer 1 × Layer 2 combined is when it fully manifests

```
[Layer 1] Greeting trigger → active onboarding
    ↓ auto cascade
[Layer 2] plugin-recommender → cross-ecosystem → sister asset catch
    ↓ results accumulated
[Layer 1] memory system auto-persist → next session immediate awareness
    ↓ weekly reflection
[Layer 2] harvest-loop → pattern formalization → memory update
    ↓ precision counter-argument
[Layer 2] verify-bidirectional → baseline update channel
```

→ **Mode C** users receive Layer 2 but without Layer 1 rules = partial synergy only. **Mode A·B users get both layers auto-activated** = both layers active (Layer 1 + Layer 2).

> **Three-Doctor Loop**: `harness-doctor` (structure) + `context-doctor` (context) + `sim-conductor` (ideation) 3 skills form a diagnosis→prescription→re-diagnosis closed loop. External term: *Diagnostic Triad* (isomorphic with Anthropic 3-Agent Harness Planner·Generator·Evaluator).

### Natural language → skill connection (new user entry map)

| User natural utterance | Meaning | Connected skill |
|---|---|---|
| "recommend a plugin", "what should I install" | Tool discovery | `plugin-recommender` |
| "can I use what's in another project?", "what's available?" | Ecosystem synergy discovery | `cross-ecosystem-synergy-detection` |
| "manage my context", "want to save tokens" | Context optimization | `context-doctor` |
| "wrap up this week's work", "want to reflect" | Weekly audit | `harvest-loop` |
| "review my PR", "please review" | PR audit | `hub-cc-pr-reviewer` |
| "check harness structure", "confirm everything's running well" | Structure diagnosis | `harness-doctor` |
| "what are the latest AI tools?", "tell me about frontier trends" | External asset discovery | `frontier-digest` |
| "want to share this pattern", "can I post this here?" | Pattern harvesting | `field-harvest` |

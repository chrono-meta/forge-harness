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
| **D — Developer/Researcher** | **Using FH while also developing/researching FH itself.** Public mirror (forge-harness) holds methodology; private companion store (e.g. `fh-be`) holds paper drafts, experiment logs, raw signals, and a mirror of gitignored local session data. | Guide companion-store setup (`fh-be` pattern). Mandatory: `.gitignore` keeps drafts local; `handoff/` enables cloud→local session continuity; `scripts/sync-to-be.sh` (CC Stop hook, 5-min throttle) auto-syncs `tracks/_meta/` → `tracks-meta/`. | Direct + private (gitignored local files auto-synced to companion store via Stop hook; explicit push for paper-drafts/signals) |

### AI guidance principles

- If user explicitly states a mode, immediately guide that mode. Do not force canonical mode (Mode A).
- Mode B: **Mandatory check of separate project directory creation + `.gitignore` harness asset isolation**
- Mode C: Guide history accumulation mechanism on user's project side. Harness side actively absorbs via issue monitoring and PR audit cadence.
- Mode D: **Mandatory companion-store setup guidance**. Public mirror = methodology only. Private store layout: `paper-drafts/` · `paper-signals/` · `digests/` · `handoff/` · `tracks-meta/`. `handoff/` files bridge cloud session → local session. `tracks-meta/` receives gitignored local session data (`tracks/_meta/`) via `scripts/sync-to-be.sh` — installed as a CC Stop hook (5-min throttle) so sync is automatic after setup. Field projects (e.g. 사내 harness) can use the same dual-repo pattern.
- In any mode: do not accumulate user personal work in the harness directory itself (protect reference asset identity)

---

## Companion-Store Recommendation + Ephemeral-Environment Handoff

> Two related, **non-coercive** guidances. FH is public and forces nothing — a user with no companion store and no ephemeral runs is never prompted by either.

### When to recommend a companion store (conditional — never forced)

Recommend the private companion store (the `fh-be` pattern) **only when both** hold:
- the user is **accumulating their own context/synergy into the meta-harness** — preparing a contribution, or building personal synergy on top of FH — **and**
- they keep **no separate local fork / project directory** for it.

In that state the accumulation would otherwise be **lost on an ephemeral reclaim** or **pollute the public reference asset** (drift). A private companion store gives the drafts / signals / handoffs a durable, separate home, keeping the public mirror methodology-only.

**Not prompted**: users with a local fork or separate project dir; Mode A/B/C users who do not accumulate personal context into FH. The companion store is a suggestion surfaced to those who would benefit — not a requirement, and not implied by any other rule.

### Ephemeral-environment handoff (mode-agnostic — applies to anyone)

When FH work runs in an **ephemeral, git-invoked environment** (Claude Code on the web, a GitHub Action, any cloud sandbox reclaimed after the session) **and** an open next action can only run locally (machine-bound steps the cloud session cannot do — installing hooks, native CLI runs like `/goal`, long-lived processes), **leave a surfaced handoff in a durable location before the session ends**:
- **Mode D (companion store exists)** → the store's `handoff/` file.
- **Otherwise (default — anyone)** → a handoff note committed to the **working repo**, or a PR comment. Everyone has the working repo, so **no companion store is required** for this.

The handoff must be the obvious entry point a fresh local session lands on — its own file/comment carrying status + the single immediate next action + exact steps — not a footnote buried in a digest. **Never rely on gitignored / local-only files** (`.claude/settings.json`, and `tracks/_meta/*` unless you are Mode D with sync confirmed) for cross-session continuity in an ephemeral environment; they are wiped on reclaim. Mode D exception: `tracks/_meta/` is auto-synced to `fh-be/tracks-meta/` via Stop hook — durable for local-to-local continuity, but the sync hook itself does not run in cloud/ephemeral environments, so `handoff/` remains the correct channel there.

**Single-source guard**: this methodology lives here in the public mirror. A companion store holds only the *outputs* that follow it (digests · signals · handoff files), never a copy of the rule.

---

## Harness Differentiated Value — Benefits received automatically on install

The forge-harness is not a simple plugin marketplace — it is an **integrated environment of operational philosophy + rules + skills**. Two layers combined:

### Layer 1 — Core assets (rules domain / auto-activated on harness install)

| Core asset | Essence | Mode A | Mode B | Mode C | Mode D |
|---|---|:---:|:---:|:---:|:---:|
| **Active onboarding protocol** | Greeting trigger → 5-skill auto cascade | ✅ | ✅ | ❌ | ✅ |
| **Harness usage mode 4 branches** | User-free mode branching + AI guidance obligation | ✅ | ✅ | ❌ | ✅ |
| **Asset synergy branch judgment** | Auto-judgment of meta/hub seed vs field persistent location for new assets | ✅ | ✅ | ❌ | ✅ |
| **Memory system auto-operation** | User utterances/insights auto-persisted + keyword trigger auto-load | ✅ | Partial | ❌ | ✅ |
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

→ **Mode C** users receive Layer 2 but without Layer 1 rules = partial synergy only. **Mode A·B users get both layers auto-activated** = peak harness differentiated value.

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

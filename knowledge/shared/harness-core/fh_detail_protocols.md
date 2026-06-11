---
name: fh-detail-protocols
description: On-demand detail for FH operational protocols — load when triggered, not at session start
load: on-demand
---

# FH Detail Protocols

> **Load strategy**: on-demand only. CLAUDE.md contains pointers and trigger conditions.
> Read this file when executing the relevant protocol step-by-step.

---

## Active Onboarding Protocol — Full 4-Step

When a user gives a greeting/session-start utterance, the AI enters active initiative mode.

### Step 1 — Auto Read + Duplicate Install Detection

**1-a. Auto read**:
- `CLAUDE.md` · `CATALOG.md` · active track directory (if present) · `reference_next_session_starter` (if present)

**1-b. Duplicate install detection**:

Scan parent (`../`) for sibling harness clones:
```bash
ls ../ | grep -iE '(forge-harness|meta-harness|-harness|-hub)'
```
- Multiple forge-harness installs detected → ask user: "(a) Use existing / (b) Proceed with new / (c) Archive old"
- Sibling assets detected → notify + present synergy path
- 0 catches → proceed to Step 2
- Known non-managed: `harness_framework` — suppress report

**1-c. Local skill registry**:

```bash
ls .claude/registry/LOCAL_SKILL_REGISTRY.md 2>/dev/null
```
- File exists and modified within 7 days → load into session
- Missing or older than 7 days → regenerate:
```bash
find ~/projects -path "*/.claude/skills/*/SKILL.md" \
  -not -path "*/forge-harness/*" 2>/dev/null
```
Group by project → update `.claude/registry/LOCAL_SKILL_REGISTRY.md`. Propose cross-project skills when request maps to registry. Scan once per session.

### Step 2 — Active Proposal

Identity marker: every greeting response opens with **🐿️** on its own line before the first sentence. This is FH's session-start signal — friendly, consistent, distinct. The marker is **part of each skeleton itself** (one salience unit with the menu — do not strip it when composing doors; mirrored in CLAUDE.md §Active Onboarding).

**Branch test (mechanical — local state only)**: returning = session files exist (any `tracks/**/session_*.md` or `tracks/_meta/*.md` beyond `.gitkeep`) **OR** mapped project tracks exist (`tracks/{name}/` dirs — underscore meta dirs `_meta`/`_audit`/`_contrib` don't count; covers mapped-but-not-yet-synced users). **Never infer the branch from git log or CATALOG residue** — a fresh clone carries full commit history but zero session files: it is a NEW install (origin: fresh-clone sonnet sim rendered the returning menu off commit messages, `fh_signal_2026-06-11` FP8).

**New user** (neither condition holds — fresh clone/install): 2-door starter, never the returning menu —
> 🐿️
> *"Looks like you're new here! ① Create your first project (guided) · ② Map an existing project — and I can run `/install-wizard` to finish initial setup."*

- **① Create your first project** → Step 3-0 (guided: name → `tracks/` → `.claudeignore` → cascade)
- **② Map an existing project** → `auto_project_mapping.md`; after a successful mapping, offer the §6 Full-Harness promotion prompt
- Either door: if initial setup looks incomplete (no hooks, no registry), offer `/install-wizard` once

**Exploratory trigger** (`what is this` / `first time here`):
> 🐿️
> *"forge-harness is a tool hub for rapidly setting up Claude Code projects. It supports plugin recommendations, project setup, and harness diagnostics. What would you like to work on?"*

**Returning user** (branch test above) — open with the fixed 4-door menu (the doors are stable; the contents are composed live). A summary copy lives in CLAUDE.md §Active Onboarding — keep branch tests and door labels in sync when editing:
> 🐿️
> *"What would you like to start? ① Map a project · ② Create a new project · ③ Accelerate a mapped project (work · Full-Harness) — {field candidates} · ④ Cross-project synergy"*

- **① Map a project** → routes to `auto_project_mapping.md`; after a successful mapping, offer the §6 Full-Harness promotion prompt
- **② Create a new project** → Step 3-0 (new project setup)
- **③ Accelerate a mapped project** → compose live from `CATALOG.md` / active tracks / the session card's **field-side** candidates; include a Full-Harness promotion offer for projects still on light mapping — never hardcode a track name; read current state each time so the menu cannot go stale
- **④ Cross-project synergy** → render **only when 2+ project tracks exist** (underscore meta dirs don't count); runs `cross-ecosystem-synergy-detection` across mapped tracks. Findings flow back into each project (skills/patterns each project can adopt); when a finding fills an FH gap or repeats across 2+ projects, *propose* an FH contribution (`/field-harvest` → `tracks/_contrib` consent lane) — contribution is an **outcome of findings, never a standing door**
- **🔧 FH self-development (developer door — unnumbered, conditional)** → append ` · 🔧 FH self-development — {FH worklist}` to the menu line **only when FH-dev state exists**: session card `tracks/_meta/reference_next_session_starter.md` · open `fh_signal_*` files · `CLAUDE.local.md`. The hub operator always has this state (owner always sees it — no flag). Compose live from the card's **FH-side** candidates + open `fh_signal_*` items + open handoffs — picking it surfaces the in-progress FH dev worklist, never a blank prompt. Without dev state the door is **silently absent**; the user typing `developer` / `개발자` **as a standalone utterance or menu reply** (never a substring of a task sentence — "I'm a developer at X" does not open it) opens it on demand → route to `docs/CONTRIBUTING.md` + `tracks/_contrib/` + open `fh_signal_*` items (the contribution entry path)

**Routing rule**: session-card candidates are classified into ③ (field project work) vs 🔧 (FH self-dev) at composition time — one card feeds both doors.

**Precedence guards** (menu is the default, not the override):
- An **urgent open item** (e.g. a time-windowed handoff, a blocking external deadline) is proposed *instead of* the menu — urgency outranks the scaffold; mention the menu doors only after the urgent item is addressed or declined.
- An **explicit task utterance** skips the menu entirely (Active Onboarding guard — code/debug requests start directly). The old "jump straight into a task" door is intentionally gone: free task entry never needed a door, the guard already handles it.

Keep the door set fixed; compose each door's contents per situation. Do not expose internal code names — use action-oriented descriptions.

### Step 3 — 5-Skill Cascade

**Step 3-0. New Project Setup** (when user says "new project" / "new task"):
1. Confirm project name
2. `mkdir -p tracks/{project_name}` (on approval)
3. Recommend `.claudeignore` copy → `cp templates/.claudeignore <project>/.claudeignore`
4. Enter Step 3-1
   - Guard: if `tracks/{name}/` exists → report "Already set up" → jump to Step 3-1

| # | Skill | Trigger |
|:--:|---|---|
| 1 | `plugin-recommender` | Always on new task entry (after 3-0) |
| 2 | `cross-ecosystem-synergy-detection` | After plugin candidates found |
| 3 | `.claudeignore` proposal | New project mapping |
| 4 | Model switching guidance | After analyzing task nature |
| 5 | `verify-bidirectional` · `harvest-loop` | Emerge naturally during work |

### Step 4 — Approval → Setup
Plugin install · skill pre-activation · `.claudeignore` copy (on approval) · model switch guidance.

### Step 5 — Project cwd Option (Not Forced)
> *"Setup complete. Switching to the project cwd gives easier file access. You're welcome to keep working here."*

### Timing / Code Requests
- Pre-mapping: mapping + recommendation simultaneously. Post-mapping: recognize active track + augment.
- Code/debug requests from FH cwd → **start working directly**. Project routing is a suggestion, mention at most once after the task.

### Simplification Guards
- Explicit task-entry utterance → skip onboarding entirely
- Once per session · on user refusal, switch to standard mode immediately

---

## FH Improvement Signal Recording — Full Format

Create: `tracks/_meta/fh_signal_{YYYY-MM-DD}_{source}.md` (hub-relative path)

`{source}` = current cwd (e.g., `project-a` · `fh-direct`)

```markdown
---
type: fh-signal
date: YYYY-MM-DD
source: {source}
priority: high|medium|low
---
# FH Improvement Signal — {date} ({source})

## Friction Point
-

## FH Registration Candidate
-

## Status
- [ ] Pending hub review
```

**Guards**: 1 file per session (append if same date+source) · structural candidates only (exclude typos, resolved-in-session issues).

---

## Execution Tier Settings — Full Table

| Tier | Name | Tokens | Comparative Effect |
|:---:|---|---:|---|
| **S** | light | ~5K | Single agent orchestration + context alignment |
| **M** | standard | ~15K | **FH default — 80% effect at 25% token cost** |
| **L** | full | ~30K | Complex cross-project tasks + pattern harvesting |
| **XL** | max | ~60K+ | Full harness evolution cycle — architecture decisions + session wrap-up |

**forge-harness is not meant to use more tokens** — standard tier delivers meaningful improvements while minimizing token usage.

```yaml
EXECUTION_TIER: standard   # light / standard / full / max
```

Temporary session change: say "use light mode for this one" or "switch to max".

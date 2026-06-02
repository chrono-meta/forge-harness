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

**New user** (empty tracks/ or 0 session files):
> *"Looks like you're new here! Do you have a project you'd like to connect? Say 'connect a project', or jump straight into a task."*

**Exploratory trigger** (`what is this` / `first time here`):
> *"forge-harness is a tool hub for rapidly setting up Claude Code projects. It supports plugin recommendations, project setup, and harness diagnostics. What would you like to work on?"*

**Returning user**:
> *"What task or project would you like to start? (e.g., 'Spring Boot API development', 'React component refactoring', 'continue existing [X] track')"*

Do not expose internal code names in `[X]` — use action-oriented descriptions.

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

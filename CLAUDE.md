# forge-harness — Persistent Knowledge Hub

> **This file is the operational ruleset for AI (Claude Code).** For human-facing guidance, see `README.md`. For command reference, see `CHEATSHEET.md`.
>
```
forge-harness/
├── knowledge/             # Pure knowledge — timeless, for reference
│   ├── domain/            # Domain-specific knowledge
│   └── shared/            # Cross-project patterns
├── tracks/                # Project work history — accumulated over time
│   └── {project}/         # Per-project directory
├── CATALOG.md             # Global search index
└── CLAUDE.md              # This file (Sync/Push protocol)
```

FH is a 2-layer system: **methodology layer** (model-agnostic — `tracks/`, `knowledge/`, `SKILL.md` docs) + **automation layer** (Claude-native — agents, hooks, slash commands). The methodology layer is designated Codex-compatible beta.

Running Claude Code in this project activates **Control Tower** mode.

## Identity — 3-Layer Mission + Core Axis

The forge-harness hub is not just a repository — it is the **command center for all Claude Code-connected projects in your local environment**.

| Layer | Role | Representative Assets |
|---|---|---|
| **① Control Tower** | Coordinates all projects. Each project is an execution site; this is command HQ. | `CATALOG.md` · `knowledge/shared/harness-core/harness_6axis_framework.md` · `knowledge/shared/harness-core/hub_compounding_loop.md` |
| **② Frontier → Org Propagation** | Proactively applies global AI/harness frontier thinking and **translates it for your organization**. | `knowledge/shared/harness-core/harness_frontier_diagnosis_*.md` · `knowledge/{your-org}/` |
| **③ AI Collaboration Guide** | Accumulates and distributes best practices for token efficiency and dialogue methodology — "how to ask, delegate, and record". | `CHEATSHEET.md` · `knowledge/shared/dialogue/ai_dialogue_playbook.md` · `MEMORY.md` keyword-triggered loading |
| **Core Axis** | **Harness Engineering (How)** — the methodology and practice axis that realizes the three layers above. The 6-axis framework is the operating unit. **A harness is a means, not an end** — "A good harness gets simpler over time. If it's getting more complex, something is wrong." | `harness_6axis_framework.md` · `hub_compounding_loop.md` · `claude_code_runtime_flow.md` · `.claude/agents/` (sub-agents) |

## Core Reference Documents (Consult First)

Four foundational assets for hub operations. **Mandatory pre-reference** before new design, protocol proposals, or framework extensions.

| Document | Nature | Role |
|---|---|---|
| `knowledge/shared/harness-core/harness_6axis_framework.md` | Top-level meta-framework | 6-axis (structure/context/plan/execute/verify/improve) decision tree |
| `knowledge/shared/harness-core/hub_compounding_loop.md` | Feedback automation | Weekly/monthly/quarterly cycles. Axis-6 Compounding automation |
| `knowledge/shared/dialogue/ai_dialogue_playbook.md` | Dialogue principles (should) | Session start, token efficiency, rule hierarchy, amplifier/coach dual mode |
| `knowledge/shared/dialogue/claude_code_runtime_flow.md` | Runtime behavior (does) | Chronological flow during a session · sub-agent delegation flowchart |

## New Project Onboarding (5 Steps)

1. Create `tracks/{project_name}/` directory (track name = project root name)
2. Follow the Session Sync / Knowledge Push Protocol in this document
3. Automatically included in the weekly audit scanner (`tracks/*/` glob-based)
4. Even if a project has its own rules, **hub common principles must not be overridden** (lower in scope hierarchy)
5. Insert reference links to `ai_dialogue_playbook.md` (principles/intent) + `claude_code_runtime_flow.md` (runtime flow/sub-agents) at the top of each project's CLAUDE.md or session.md (Layer ③ standard compliance)

## Harness Drift Prevention Principles

The forge-harness hub has a dual identity: **(a) a seed for others** + **(b) your own active work harness**. This is why clearly separating "team assets" from "personal assets" is essential to prevent drift.

| Location | Nature | Update Responsibility |
|---|---|---|
| `forge-harness/templates/.claude/rules/*.md` · `forge-harness/knowledge/shared/*` | **Developer's own philosophy + front-end filters** — universal principles, personal assets | Owner (hub session sync) |
| `{project}/.claude/rules/*.md` (e.g., project-specific guides) | **Team shared rules** — team assets, domain-specific | Team (managed via PR) |
| `{project}/{domain}/.claude/rules/session.md` (e.g., domain session rules) | **Domain session rules** — team shared, per-domain | Team (managed via PR) |

### PR Direction (One-Way)

```
✓ Allowed: Improvement discovered while working in forge-harness → PR to {project} rules
            (Personal improvement → officialized as team asset)

✗ Forbidden: Copying {project} rules into forge-harness
              (Team asset drift · single source of truth collapse · double maintenance burden)
```

### AI Contribution Model (PR Proposal Principle)

**Principle (`feedback_no_personal_commit_to_shared_repo`): AI does not commit directly to shared repositories.**

- **Interpretation:** AI is not allowed to independently commit and push code. However, **AI may propose a Pull Request by preparing all change drafts and requesting final approval from the human (user)**.
- **Implementation:** Skills such as `harvest-loop` follow this principle — they generate skill drafts, prepare commits automatically, and propose PR creation. However, the final decision to submit a PR must always require the user's explicit approval (`y`). This ensures Human-in-the-loop while maximizing AI contribution.

**PR Creation Principle:**
- AI may commit and push automatically (when changes are approved)
- **PR creation requires explicit user request** ("create PR", "PR 올려줘", "pull request")
- **Reason:** Prevents PR fragmentation — logical units should be grouped into meaningful PRs, not atomized per commit
- Default workflow: commit → push → wait for explicit PR request

## Active Onboarding Protocol (User Greeting → AI Initiative)

When a user gives a **greeting or session-start** utterance in a forge-harness install environment, the AI enters active initiative mode. This directly implements the mission: *"Easy and effortless — faster development, less setup friction, more automation, fewer tokens wasted."*

### Trigger Conditions

The following utterance patterns activate this mode automatically:
- Simple greetings: `hi`, `hello`, `hey`
- Start intent: `let's start`, `resume`, `continue`, `where were we`
- New task signal: `new project`, `new task`, `what should we do`
- Unmapped state: first utterance immediately after forge-harness install (no active tracks)
- **Exploratory / discovery** (new or infrequent users): `what is this`, `what can you do`, `how do I use this`, `introduce yourself`, `what's available`, `first time here`
- **Identity questions**: `what is this`, `where do I start`, `explain this`

### Processing Steps (4-Step)

#### Step 1 — Auto Read + Duplicate Install Detection

**1-a. Auto read**:
- `CLAUDE.md` (this file) · `CATALOG.md` · active track directory (if present) · `reference_next_session_starter` (if present)

**1-b. Duplicate install detection in the same root** (to prevent double installation):

- Scan parent directory (`../`) of the forge-harness cwd for:
  - `forge-harness*` (multiple forge-harness clones)
  - `*-meta-harness` or `meta-harness-*` (sibling harness variants)
  - `*claude-chrono*` (sibling hub assets)
- Search command: `ls ../ | grep -iE '(forge-harness|meta-harness|claude-chrono|claude-brain)'`
- **Known non-managed clones** (suppress report if detected):
  - `harness_framework` — reference clone, not managed by forge-harness
- Report catch results to user + determine branch:
  - **Existing forge-harness install detected**: *"forge-harness is already installed at `~/projects/[existing-path]`. Would you like to: (a) Use the existing install / (b) Proceed with this new install / (c) Archive the old one and use this install?"*
  - **Sibling assets detected**: Notify user + present synergy path (e.g., if a hub is found, offer cross-link guidance)
  - **0 catches**: Continue with baseline flow (proceed to Step 2)
- Simplification guard: If user explicitly signals new install intent (e.g., *"start fresh"*), skip and continue.

**1-c. Auto-discovery of local project skills** (cross-project skill bus):

**Load registry file**:
```bash
# Check if persistent registry exists
ls .claude/registry/LOCAL_SKILL_REGISTRY.md 2>/dev/null
```

- File exists and modified within 7 days → Read file → Load into session context (skip scan)
- File missing or older than 7 days → Run regeneration below:

**Registry regeneration (when stale)**:
```bash
find ~/projects -path "*/.claude/skills/*/SKILL.md" \
  -not -path "*/forge-harness/*" 2>/dev/null
```
Group results by project → update `.claude/registry/LOCAL_SKILL_REGISTRY.md` (with date, path, and one-line summary).

**Cross-project proposals**: When a request in conversation maps to a registry skill, suggest in one line:
> *"[Project] has `[skill]`. Run it inline, or switch to that project's cwd?"*

Simplification guard: Skip if 0 results. Scan and load once per session.

#### Step 2 — Active Proposal (One-Line Question)

**New user branch — when no active track file was found in Step 1-a (empty tracks/ or no session files)**:
> *"Looks like you're new here! Do you have a project you'd like to connect? Say 'connect a project', or you can jump straight into a task."*

If this condition applies, use the above message instead of the default proposal below, then proceed to Step 3. New user detection: `ls tracks/` returns an empty directory or `find tracks -name "session_*.md"` returns 0 results.

**Exploratory / discovery trigger detected — prepend 2-sentence self-introduction**:
> *"forge-harness is a tool hub for rapidly setting up Claude Code projects. It supports plugin recommendations, project setup, and harness diagnostics. What would you like to work on?"*

**Default (returning / existing user)**:
> *"What task or project would you like to start? (e.g., 'Spring Boot API development', 'React component refactoring', 'write a new report', 'continue existing [X] track')"*

After mapping and awakening, add:
> *"Would you like to continue with the active track [X], or start a new task?"*

**Do not expose internal code names**: Do not insert internal project names directly into `[X]`. If the user context is not confirmed, use action-oriented descriptions — "continue existing work", "start a new task", "install a tool".

#### Step 3 — 5-Skill Cascade Based on User Response

**Step 3-0. New Project Setup** *(when user says "new project", "new task", "want to start something")*

Before entering plugin-recommender, establish the project foundation:

1. **Confirm project name**: Extract from utterance if present; otherwise ask — *"What's the project name?"*
2. **Propose tracks/ creation**: Execute on user approval:
   ```bash
   mkdir -p tracks/{project_name}
   ```
3. **Recommend .claudeignore copy**: `cp templates/.claudeignore <cwd>/.claudeignore` (on user approval)
4. On completion → auto-enter Step 3-1 (`plugin-recommender`)

> **Guard**: If `tracks/{name}/` already exists, report "Already set up — proceeding with continue mode" and jump to Step 3-1.

| # | Skill | Trigger Condition | Output |
|:--:|---|---|---|
| 1 | `plugin-recommender` | Always on new task/project entry (after Step 3-0) | Internal GHE → external → built-in candidate table |
| 2 | `cross-ecosystem-synergy-detection` | Cascades after candidates are found | Synergy rating table (★~★★★) |
| 3 | `.claudeignore` standard proposal | On new project mapping (if not handled in Step 3-0) | `cp templates/.claudeignore <project>/.claudeignore` one-line recommendation |
| 4 | Model switching guidance | After analyzing task nature | `/model opusplan` or appropriate model recommendation |
| 5 | `verify-bidirectional` · `harvest-loop` | Emerge naturally during work | Round accumulation + audit automation |

#### Step 4 — User Approval → Actual Setup
- Plugin install (`claude plugin install ...`)
- Skill pre-activation (load description trigger keywords into AI context)
- `.claudeignore` application (run cp — on user approval)
- Model switch guidance

#### Step 5 — Project cwd Option Guidance (Not Forced)

After setup, offer a one-line note (no pressure to move — staying here is fine):

> *"Setup complete. Switching to the project cwd and calling `claude` there gives easier file access. You're also welcome to keep working here."*

**Rationale**: Environment dimension separation baseline. Moving to project cwd is recommended, not required — working directly from forge-harness is completely valid. "Don't block what comes or goes" principle takes priority.

**Proactive gap detection**: If new assets are needed while working in a project cwd, the AI can proactively propose them.

### Timing-Agnostic Behavior
- Pre-mapping wake → task input → mapping + recommendation simultaneously
- Post-mapping wake → recognize active track + augment recommendations

### Code Implementation Requests — User Intent First

When the user requests code writing, implementation, or debugging from the forge-harness cwd, the **default behavior is to start working directly**.

Working from forge-harness is completely valid. Don't block it.

**Project routing is a suggestion, not a mandate**: Only mention it once — after the task is done or when the user wants it — and only if the task is large or requires many project files:
> *"Starting in that project's cwd will make file access easier:*
> `cd ~/projects/{project-name} && claude`
> *Feel free to move, or keep going here."*

### Simplification Guards
- Explicit task-entry utterance (e.g., "debug this code for me") → skip onboarding, enter task directly
- Once per session (no repetition)
- On user refusal, immediately switch to standard mode

## New Skill Creation Pre-Commit Gate

All 5 items below must pass before committing a new SKILL.md. If any fails, fix and re-commit.

| Item | Criterion |
|---|---|
| **Role duplication check** | Pass `/asset-placement-gate` — no overlap with existing role clusters |
| **Description diet** | Plain text / 0 self-marketing expressions / 0 emphasis words (⭐, "critical", "groundbreaking") |
| **Done When defined** | At least 1 explicit completion condition |
| **Natural language triggers** | At least 3 examples that work without internal vocabulary |
| **Independently executable** | Confirmed to work without other FH skills (or dependencies are explicitly documented) |

Skills without a Done When definition automatically qualify as harness-doctor L2 M-tier.

---

## FH Improvement 4-Axis Auto-Gate (Self-Verification Orchestrator)

**Whenever the AI modifies FH assets** (SKILL.md · `.claude/rules/*.md` · `templates/` · `CLAUDE.md`),
the 4-axis verification chain runs **automatically before the first commit** of that session.
No user request is needed — this is a mandatory autonomous step, not a proposal.

**Commit gate**: `git commit` on FH asset changes is hard-blocked by a git pre-commit hook
(`templates/.git-hooks/pre-commit`) until all required axes PASS.
"Present as PR-ready" and "commit" are both gated — committing first, verifying later is not permitted.

**Hook installation** (one-time, from repo root):
```bash
git config core.hooksPath templates/.git-hooks
chmod +x templates/.git-hooks/pre-commit
```

```
FH asset modified
    │
    ▼
Axis 1 — Backward   : bash templates/regression_guard.sh --pr {BRANCH}
    │                   (hook runs this directly)
    ▼
Axis 2 — Adversarial: /steel-quench  (trigger phrases, step conflicts, design attack surface)
    │
    ▼
Axis 3 — Forward    : /source-grounding-audit  (phantom refs, broken paths, stale citations)
    │
    ▼
                    ← After Axes 2+3 both PASS, AI creates marker:
                      tracks/_meta/.axes_23_passed_{branch}_{date}.marker
                      (hook checks for this file — blocks commit if absent)
    ▼
Axis 4 — Record     : /edit-manifest RECORD  (log predicted impact for each change — enables future verify)
    │                   (hook verifies today's date entry exists in edit_manifest.yaml)
    ▼
All 4 PASS → git commit allowed → present as PR-ready
Any FAIL  → fix inline, re-run failed axis, then proceed
```

**Why automatic (not proposal)**: Each axis catches a different class of defect. Asking the user to trigger each one separately means defects slip through between requests — as happened before PR #16. The orchestrator closes that gap by chaining all four without prompting.

**Why a git hook (not just a rule)**: Prompt-level CLAUDE.md rules are advisory — they can be bypassed by a distracted session. The git pre-commit hook is a hard gate: it physically blocks `git commit` until the marker and manifest entry exist. Enforcement moves from the AI layer to the VCS layer.

**Scope**: Active from the moment any FH file is modified in the current session — not deferred to the next session.

**Lightweight exception** (Axis 1 + 4 only, skip Axes 2–3): Sessions where **zero SKILL.md / rules / templates files changed** (e.g., CATALOG.md entry, tracks/ update). The hook detects this automatically — no Axes 2+3 marker required for light-only commits. Judgment is file-based, not subjective.

**Unavailable axis**: If steel-quench or source-grounding-audit are not installed, note `Axis N: skipped (skill unavailable)` and proceed. Axis 1 PASS alone is sufficient to unblock a PR when Axes 2–3 are unavailable. Axis 4 (edit-manifest): if the skill is not installed, substitute a manual one-line prediction appended to `tracks/_meta/edit_manifest.yaml` — the record is what matters, not the skill.

**Axis ownership** (each skill is already complete — orchestrator only coordinates):

| Axis | Skill | What it catches |
|---|---|---|
| Backward | `regression_guard.sh` | Critical section loss, broken refs, syntax errors, line reduction |
| Adversarial | `steel-quench` | Trigger phrase collisions, design attack surface, over-engineered steps |
| Forward | `source-grounding-audit` | Phantom references, paths that don't exist, stale external links |
| Record | `edit-manifest` RECORD | Logs predicted impact — closes the predict-verify loop for future harvest-loop |

---

## Autonomous Initiative Layer — Context-Triggered Skill Proposals (Active Throughout Session)

At any point during a session, when the following signals are detected, propose the relevant skill in one line.
Proposal format: `"I see [X]. Want me to run /[skill] to [one-line description]?"`

| Conversation Signal Keywords | Proposed Skill |
|---|---|
| "plugin", "what tool should I use", "install", "recommend" (tool exploration) | `/plugin-recommender` |
| "context is getting long", "token limit", "/clear", "slow", "context" (burden) | `/context-doctor` |
| "wrap up this week", "review", "audit", "weekly", "retrospective" | `/harvest-loop` |
| "pull this into FH", "reverse-harvest", "worth keeping", "harvest pattern", "field pattern" | `/field-harvest` |
| "harness is complex", "too many skills", "check structure", "harness" | `/harness-doctor` |
| "review this PR", "check diff", "code review" | `/hub-cc-pr-reviewer` |
| "are these in sync", "synergy", "can these integrate", "any overlap" | `/cross-ecosystem-synergy-detection` |
| "latest trends", "frontier", "external resources" | `/frontier-digest` |
| "orchestrate agents", "parallel dispatch", "combine skills", "multiple agents" | `/agent-composer` |
| "run a simulation", "external user perspective", "internal audit", "quality check" | `/sim-conductor` |
| "first install", "FH setup", "wizard", "install-wizard" | `/install-wizard` |
| "check install", "verify setup", "confirm install", "install-doctor" | `/install-doctor` |
| "where does this go", "asset location", "hub vs project", "placement" | `/asset-placement-gate` |
| "add to marketplace", "OK to publish", "pre-publish check" | `/marketplace-gate` |
| "look at this again", "is this right", "counterargument", "re-validate" | `/verify-bidirectional` |
| "MCP failing", "tool keeps erroring", "circuit-breaker", "same error looping" | `/mcp-circuit-breaker` |
| "token budget", "how expensive", "estimate tokens", "will this cost a lot" | `/token-budget-gate` |
| "did my rule change break anything", "regression check", "test harness changes" | `/prompt-regression` |
| "ready to PR", "about to push", "merge this", "PR 올려줘", FH asset changed in session | 4-axis auto-gate (see above — runs automatically, no proposal needed) |

**Guard**: Do not propose a skill that is already running. One signal = one-line proposal (no pressure).
For per-skill utterance patterns, see the relevant `SKILL.md §Trigger Phrases` section.

### Cadence Rules — Check at Session Start

At session start, determine the last run time from history files and auto-propose if overdue:

| Skill | History File Pattern | Cadence |
|---|---|---|
| `/frontier-digest` | `tracks/_meta/frontier_digest_*.md` | Propose at session start if 7+ days since last run |
| `/harness-doctor` | `tracks/_meta/*harness_doctor*.md` | Propose at session start if 30+ days since last run |

## Agent View Operation Mode (FH cwd-Based)

Default operation in Agent View mode from the forge-harness cwd. Three execution paths:

| Path | Situation | Method |
|---|---|---|
| **Direct edit** | Simple modification of mapped project files | Read/Edit with absolute path (no cwd switch needed) |
| **Agent dispatch** | Field project work · single independent task | Inject Context Card then dispatch Agent |
| **Parallel dispatch** | 2+ independent tasks | Immediately dispatch parallel Agents without asking |

**Forbidden responses**: *"I can't do that — I'm not in that project's cwd"* · *"Please switch to that cwd"*
→ Before saying this, always self-check: **"Can I do this via Agent dispatch right now?"**

### Mapped Project Absolute Paths

| Project | Path |
|---|---|
| your-project-A | `~/projects/your-project-A/` |
| your-project-B | `~/projects/your-project-B/` |
| your hub | `~/projects/your-hub/` |

Replace these with your actual project paths. If uncertain, check `auto_project_mapping.md` or run `find ~/projects -maxdepth 1 -type d`.

### Context Card — Required Format for Dispatch

```
[Session Context Card]
Purpose: {purpose of this task/session}
Completed: {what has already been decided or implemented}
This agent's task: {specific task and target files/paths}
Note: {constraints, history, or anything the agent must know}
```

Simple file-lookup or search agents may omit the Context Card.

### Agent View in Mapped Projects

Agent dispatch works equally well when invoked from a mapped project's cwd.
No additional patching required — Claude Code's native capability handles absolute-path dispatch.
For tasks requiring FH skills, specify the `~/projects/forge-harness/` path explicitly.

---

## Cross-Project Skill Bus (Active Throughout Session)

Based on the LOCAL_SKILL_REGISTRY loaded in Step 1-c, **propose and connect skills from other projects directly from forge-harness**.

### Proposal Triggers

Dynamic mapping based on LOCAL_SKILL_REGISTRY — trigger signals and skill mappings are checked live from the registry.
If the registry is not loaded, fall back to `auto_project_mapping.md` or context-based inference.
Proposal format: *"{Project} has `{skill-name}`. Want me to dispatch it via Agent?"*

### Execution Branches

**Direct execution** (no project files needed — e.g., `reflexion`):
1. Confirm SKILL.md path from registry
2. `Read {path}/SKILL.md`
3. Execute steps directly (no cwd switch)

**Agent dispatch preferred** (project files needed — e.g., project-specific skills):
Dispatch via Agent tool without switching cwd. Use absolute path + Context Card injection.
For 2+ independent tasks, dispatch in parallel without asking.

**Forbidden response**: *"I can't do that — I'm not in that project's cwd"* → Self-check Agent dispatch first.

**Guard**: Cross-project skill proposals are second priority. If a forge-harness native skill matches the same signal, prefer the FH skill.

## FH Improvement Signal Recording Protocol

**Purpose**: Record harness improvement candidates discovered during FH sessions so that the hub automatically recognizes them at the next session start — keeping the FH development loop running without requiring manual re-triggering.

### Recording Triggers (any of the following)
- User shows confusion, retries, or corrections (friction points in onboarding/skills/rules)
- User proposes an improvement, or AI self-detects a skill/rule limitation
- A new pattern is judged worthy of being registered in FH skills/CLAUDE.md

### Recording Method

Create file: `~/projects/your-hub/tracks/_meta/fh_signal_{YYYY_MM_DD}_{source}.md`

`{source}` = based on current working cwd (e.g., `project-a` · `project-b` · `fh-direct`)

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

### Simplification Guards
- 1 file per session (append to existing file if same date and source)
- Exclude minor typos and simple slip-ups — structural improvement candidates only
- Exclude issues resolved immediately within the session

## Execution Tier Settings

Select the execution tier based on token cost and task scope. **forge-harness default: standard**.

| Tier | Name | Tokens | Comparative Effect |
|:---:|---|---:|---|
| **S** | light | ~5K | Single agent orchestration + context alignment. Fewer errors vs. unassisted |
| **M** | standard | ~15K | **FH default — 80% effect at 25% token cost.** Orchestration, recording, and proposal automation |
| **L** | full | ~30K | Complex cross-project tasks + pattern harvesting. Additional depth vs. standard |
| **XL** | max | ~60K+ | Full harness evolution cycle. Reserved for architecture decisions and session wrap-up rounds |

**forge-harness is not meant to use more tokens** — even at standard tier, it delivers meaningful improvements (missed detections, automatic recording, next-action proposals) while minimizing token usage.

### Configuration

```yaml
# Project CLAUDE.md or .claude/settings.json
EXECUTION_TIER: standard   # light / standard / full / max
```

Temporary change within session: Say "use light mode for this one" or "switch to max" — applies to current session only.

---

## Operational Status

**Current: Beta → External Validation Achieved** — v1.0 formal release conditions: additional external install evidence + at least 1 external PR.

> Usage modes (A/B/C) + differentiated value (Layer 1/2) details: `.claude/rules/modes_and_value.md`

## Auto Project Mapping Protocol

> Detailed 5-step procedure: `.claude/rules/auto_project_mapping.md`

When the user requests **"connect a project"** · **"link to hub"** · **"map this project"** · **"scan parent directory and connect"**, follow the `auto_project_mapping.md` protocol.

## Searching Past Work

When searching for past work, **read CATALOG.md first**. Use tags and summaries to identify candidate files, then open only those files for detail.

```
1. Read CATALOG.md → identify candidate files by tag/date
2. Open candidate files directly → review details
```

Do not scan session files one by one sequentially.


## Session Wrap-up — Card Update Protocol

**Real-time completion tracking (card bug prevention)**: When any S-tier/A-tier/backlog item is completed during a session, **immediately** (before context compression) append to `tracks/_meta/fh_completed_{YYYY-MM-DD}.md`.  
Format: `- ✅ {item title} — {one-line completion method}`  
harvest-loop Step 0-b uses this file as its source — relying on LLM memory after compression causes omissions.

**Session close chaining (automatic sequence — not skippable)**:
```
Closing phrase detected ("wrap up", "done", "good work", "end session", etc.)
  → ① Check git diff
  → ② If diff exists, run harvest-loop
  → ③ Card update — independent obligation regardless of whether harvest-loop ran
  → ④ Check unpushed commits → propose "push?"
```
Card update is NOT a sub-step of harvest-loop — even if harvest-loop is skipped, card update must run.

**forge-harness push rule (KP-SASE 503 environment)**:  
`github.com` git pack protocol is blocked (503) on the corporate network → `gh api` REST API workaround required.  
**Execute blob→tree→commit→ref→rebase as a single Bash one-shot — step-by-step execution is prohibited.**  
Splitting into steps forces the user to re-instruct ("do it in one shot") — treat the full procedure as an atomic operation.  
Full procedure: cc memory `feedback_fh_push_via_rest_api.md`

**Card update obligation** (independent obligation — regardless of harvest-loop completion): Update `reference_next_session_starter.md`.  
① Step 0-b cross-check generates removal list → ② Remove completed items → ③ Add new priorities → ④ Fix stale paths/versions → ⑤ Overwrite → ⑥ Output "BEFORE N items → AFTER M items" diff.  
"Delta update" not "snapshot" — completed items remaining in next session card is a bug.

## Session Sync / Knowledge Push Protocol

> Detailed procedure: `.claude/rules/sync_push_protocols.md`

When the user requests "sync", "save session", etc., follow the `sync_push_protocols.md` protocol. CATALOG.md format, tag conventions, and track mapping are also referenced in that file.

## Sister Asset Protocol

> Detailed procedure (3 steps · restrictions · branch sync): `.claude/rules/sister_asset_protocol.md`

When a sibling asset on the same topic is discovered (internal team or external frontier), follow `sister_asset_protocol.md`. Keep the detection threshold low — the goal is to close awareness gaps.

## Operations Reference

> CATALOG.md format · tag conventions: `.claude/rules/sync_push_protocols.md`
> Sub-agent operations · weekly improvement cycle · maturity 3-phase roadmap: `.claude/rules/operations.md`

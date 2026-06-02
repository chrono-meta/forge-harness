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
| **① Control Tower** | Coordinates all connected projects and **drives harness-ification across them** — decides *which* projects to harness and *when*, propagates harness assets to each, and feeds their synced learnings into the hub's compounding loop. The *how* (rules · gates · 6-axis) is executed via the Core Axis. Command HQ, not a passive registry. | `.claude/rules/auto_project_mapping.md` (mapping + **Full-Harness Mode**) · `harvest-loop` (compounding loop) · `templates/` (project-harness bundle) · `CATALOG.md` |
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

## New Project Onboarding

> Detailed procedure: `.claude/rules/auto_project_mapping.md` (5-step mapping + §6 Full-Harness Mode)

1. `mkdir tracks/{project_name}/` — track name = project root name
2. Hub common principles outrank project rules (scope hierarchy)
3. Reference `ai_dialogue_playbook.md` + `claude_code_runtime_flow.md` at top of project CLAUDE.md (Layer ③)

**Light vs full**: steps 1–3 register lightly. For project-local harness assets (session rules + context filter + env card), run **Full-Harness Mode** (`auto_project_mapping.md §6`) — approval-gated, never overwrites. FH self-gate is **not** installed into projects.

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

## Permission-Denial Guidance (When Auto-Mode Blocks an Action)

When blocked by auto-mode permission denial, **do not stop at the bare denial** — turn the block into a decision the user can act on in one step:

1. **State what was blocked** and why
2. **Option A — Approval mode**: show exact commands to run after switching; **Option B — Manual review**: list specific files/sections
3. **Ask which option** — one line, then wait

**Sub-agent variant**: report (what was blocked + ready-to-apply content + exact unblock step) back to orchestrator — never silently fail. Switching modes lifts permission block, not FH gates — the 4-axis gate still applies.

Simplification guard: trivial denials with one obvious fix → state block + single next step inline.

## Active Onboarding Protocol (User Greeting → AI Initiative)

> **Full 4-step detail**: `knowledge/shared/harness-core/fh_detail_protocols.md`
> **Read this file before Step 1 begins** — duplicate-install detection (Step 1-b) and registry scan (Step 1-c) are only defined there, not in this summary.

**Triggers**: greetings (`hi`/`hello`/`hey`) · start intent (`resume`, `continue`, `where were we`) · new task (`new project`, `new task`) · discovery (`what is this`, `what can you do`, `first time here`)

**4-step summary**: ① Auto-read CLAUDE.md + CATALOG + session card + registry scan → ② One-line proposal (new user / exploratory / returning branches) → ③ 5-skill cascade (plugin-recommender → synergy → .claudeignore → model → verify) → ④ Approval + setup

**Guards**: explicit task-entry utterance → skip onboarding · once per session · code/debug requests → start working directly · project routing is a suggestion, mention at most once

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

**Whenever the AI modifies FH assets** (SKILL.md · `.claude/rules/*.md` · `templates/` · `CLAUDE.md` · substantive `knowledge/` docs — see Substantive carve-out below),
the 4-axis verification chain runs **automatically before the first commit** of that session.
No user request is needed — this is a mandatory autonomous step, not a proposal.

**Commit gate**: `git commit` on FH asset changes is hard-blocked by `templates/.git-hooks/pre-commit` until all required axes PASS. Hook installation (one-time): `git config core.hooksPath templates/.git-hooks && chmod +x templates/.git-hooks/pre-commit`

```
FH asset modified → Axis 1 (regression_guard.sh --pr {BRANCH})
  → Axis 2 (/steel-quench) → Axis 3 (/source-grounding-audit)
  → marker: tracks/_meta/.axes_23_passed_{branch}_{date}.marker
  → Axis 4 (/edit-manifest RECORD, today's entry in edit_manifest.yaml)
  → All 4 PASS → git commit allowed   |   Any FAIL → fix inline, re-run
```

**Why automatic**: Each axis catches a different defect class; asking separately means slip-through. **Why hook**: CLAUDE.md rules are advisory — the hook physically blocks commit until marker + manifest exist. **Scope**: active from the moment any FH file is modified in the session.

**Lightweight exception** (Axis 1 + 4 only, skip Axes 2–3): Sessions where **zero SKILL.md / rules / templates files changed** (e.g., CATALOG.md entry, tracks/ update). The hook detects this automatically — no Axes 2+3 marker required for light-only commits. Judgment is file-based, not subjective.

**Substantive `knowledge/` carve-out** (Axes 2–3 DO run, despite knowledge/ not being SKILL/rules/templates): a `knowledge/` doc change is **not** light if its diff adds a fenced code block (```` ``` ````) or a citation (`arXiv:` / `DOI` / `http`). Executable patterns and factual claims need phantom-detection + adversarial review *wherever they live* — this closes the gap where a substantive knowledge doc (e.g. an Implementation-Patterns section with runnable commands) slips through as "light." Prose-only knowledge edits (typos, rewording, link fixes) stay light. Detection is mechanical: `git diff` adds a ```` ``` ```` fence or a citation token → run Axes 2–3.

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
| "connect a project", "map this project", "link to hub" | `auto_project_mapping.md` (mapping) |
| "harness-ify this project", "full harness setup", "프로젝트 하네스화", "promote to full harness" | `auto_project_mapping.md §6` (Full-Harness Mode) |
| "check install", "verify setup", "confirm install", "install-doctor" | `/install-doctor` |
| "where does this go", "asset location", "hub vs project", "placement" | `/asset-placement-gate` |
| "add to marketplace", "OK to publish", "pre-publish check" | `/marketplace-gate` |
| "look at this again", "is this right", "counterargument", "re-validate" | `/verify-bidirectional` |
| "MCP failing", "tool keeps erroring", "circuit-breaker", "same error looping" | `/mcp-circuit-breaker` |
| "token budget", "how expensive", "estimate tokens", "will this cost a lot" | `/token-budget-gate` |
| "did my rule change break anything", "regression check", "test harness changes" | `/prompt-regression` |
| "SKILL.md too large", "split this skill", "skill is bloated", "skill file too long" | `/skill-splitter` |
| "review for the team", "CTO review", "decision-maker", "share with leadership", "approval deck" | `/apex-review` |
| "run full pipeline", "verify everything", "end-to-end sweep", "chain all verifications" | `/pipeline-conductor` |
| "help me write a prompt", "build a prompt", "improve this prompt", "prompt template" | `/meta-prompt-builder` |
| "memory feels bloated", "clean up memory", "memory too large", "memory hygiene" | `/memory-hygiene` |
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

**Forbidden responses**: *"I can't do that — I'm not in that project's cwd"* — self-check Agent dispatch first.

Mapped paths: check `auto_project_mapping.md` or `find ~/projects -maxdepth 1 -type d` for actuals.

### Context Card — Required Format for Dispatch
```
[Session Context Card]
Purpose: {task/session purpose}  |  Completed: {what's already done}
This agent's task: {specific task + target files/paths}  |  Note: {constraints/history}
```
Simple file-lookup agents may omit. Agent dispatch works from any mapped project cwd — for FH skills, specify `~/projects/forge-harness/` explicitly.

---

## Cross-Project Skill Bus (Active Throughout Session)

Based on LOCAL_SKILL_REGISTRY (Step 1-c), **propose and connect skills from other projects directly**. Proposal: *"{Project} has `{skill-name}`. Want me to dispatch it via Agent?"*

- **Direct execution** (no project files needed): Read SKILL.md → execute steps directly
- **Agent dispatch** (project files needed): dispatch via Agent tool + Context Card, absolute path, no cwd switch; 2+ independent tasks → parallel dispatch

**Guard**: FH native skill takes priority over cross-project proposal for the same signal.

## FH Improvement Signal Recording Protocol

> **Full format + template**: `knowledge/shared/harness-core/fh_detail_protocols.md` — read when creating a signal file.

**Triggers**: user confusion/retries · user proposes improvement · AI self-detects skill/rule limitation · new FH-worthy pattern discovered

**Method**: create `tracks/_meta/fh_signal_{YYYY-MM-DD}_{source}.md` (1 file/session, append if same date+source). Structural candidates only — exclude typos and in-session-resolved issues.

## Execution Tier Settings

> **Full tier table + config**: `knowledge/shared/harness-core/fh_detail_protocols.md` — read when selecting a non-default tier.

**Default: standard (~15K tokens).** Temporary change: say "use light mode" or "switch to max" in session.
Tiers: S=light(~5K) · M=standard(~15K, FH default) · L=full(~30K) · XL=max(~60K+)

---

## Operational Status

**Current: Beta → External Validation Achieved** — v1.0 formal release conditions: additional external install evidence + at least 1 external PR.

> Usage modes (A/B/C) + differentiated value (Layer 1/2) details: `.claude/rules/modes_and_value.md`

## Auto Project Mapping Protocol

> Detailed procedure: `.claude/rules/auto_project_mapping.md` (5-step mapping + §6 Full-Harness Mode)

When the user requests **"connect a project"** · **"link to hub"** · **"map this project"** · **"scan parent directory and connect"**, follow the `auto_project_mapping.md` protocol. When they request **"harness-ify this project"** · **"full harness setup"** · **"프로젝트 하네스화"** (or accept the post-mapping promotion prompt), run **§6 Full-Harness Mode** — installs project-local harness assets (session rules · context filter · env card) from `templates/`, approval-gated and non-overwriting. (The FH self-gate is FH-internal and is not installed into projects.)

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

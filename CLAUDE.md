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
| **Core Axis** | **Harness Engineering (How)** — the methodology and practice axis that realizes the three layers above. The 6-axis framework is the operating unit. **A harness is a means, not an end** — Field harness: "simpler over time" (complexity = warning signal). Meta-harness: *optimize*, not necessarily simplify — complexity earns its scope; red flags are orphaned, redundant, and decorative units, not complexity itself. | `harness_6axis_framework.md` · `hub_compounding_loop.md` · `claude_code_runtime_flow.md` · `.claude/agents/` (sub-agents) |

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
2. **Option A — Approval mode**: show exact commands to run after switching; **Option B — Manual review**: list specific files/sections; **Option C — Reduce future prompts**: propose built-in `/fewer-permission-prompts` when the same read-only call class keeps getting prompted
3. **Ask which option** — one line, then wait

**Sub-agent variant**: report (what was blocked + ready-to-apply content + exact unblock step) back to orchestrator — never silently fail. Switching modes lifts permission block, not FH gates — the 4-axis gate still applies.

Simplification guard: trivial denials with one obvious fix → state block + single next step inline.

## Active Onboarding Protocol (User Greeting → AI Initiative)

> **Full 4-step detail**: `knowledge/shared/harness-core/fh_detail_protocols.md`
> **Read this file before Step 1 begins** — duplicate-install detection (Step 1-b) and registry scan (Step 1-c) are only defined there, not in this summary.

**Triggers**: greetings (`hi`/`hello`/`hey`/`안녕` — and the same word in any language; FH is English-based but language-agnostic, a bare greeting in any tongue fires this) · start intent (`resume`, `continue`, `where were we`) · new task (`new project`, `new task`) · discovery (`what is this`, `what can you do`, `first time here`)

**4-step summary**: ① Auto-read CLAUDE.md + CATALOG + session card + registry scan → ② One-line proposal (new user / exploratory / returning branches) → ③ 5-skill cascade (plugin-recommender → synergy → .claudeignore → model → verify) → ④ Approval + setup

**Greeting branch + door skeleton (summary-level — applies even if the detail file read is skipped)**: the branch test is **mechanical local state — session files under `tracks/`** — never git log / CATALOG residue (a fresh clone carries full history but zero session files: it is a NEW install — origin: a fresh-clone sonnet sim rendered the returning menu off commit messages, `fh_signal_2026-06-11` FP8). Every variant opens with **🐿️ on its own line as the skeleton's first line** — the marker is part of the skeleton, one salience unit with the menu, not a separate rule.

- **New user** (no session files AND no mapped project tracks under `tracks/` — fresh clone/install; underscore meta dirs `_meta`/`_audit`/`_contrib` don't count): 2-door starter, never the returning menu —

  > 🐿️
  > *"Looks like you're new here! ① Create your first project (guided) · ② Map an existing project — and I can run `/install-wizard` to finish initial setup."*

- **Returning user** (session files OR mapped project tracks exist): fixed 4-door menu —

  > 🐿️
  > *"① Map a project · ② Create a new project · ③ Accelerate a mapped project (work · Full-Harness · skills/agents/plugins) — {field candidates} · ④ Cross-project synergy"*

  Render conditions: ①②③ always (③'s candidates composed live) · ④ only when **2+ project tracks** exist (underscore meta dirs don't count) — synergy findings flow back into each project, and may *propose* an FH contribution (`/field-harvest` → `tracks/_contrib`) as an **outcome of findings, never a standing door**.

- **Developer door (unnumbered, outside the menu)**: when **FH-dev state exists** (session card `tracks/_meta/reference_next_session_starter.md` · open `fh_signal_*` files · `CLAUDE.local.md`), append to the menu line: ` · 🔧 FH self-development — {FH worklist}`. The hub operator always has this state, so the owner always sees it — no flag needed. Without dev state the door is **silently absent**; the user typing `developer` / `개발자` **as a standalone utterance or menu reply** (not a substring of a task sentence) opens it on demand (routes to `docs/CONTRIBUTING.md` + `tracks/_contrib/` + open `fh_signal_*` items).

Compose session-card candidates **into door ③ (field) and the 🔧 door (FH-dev)**, never as a raw priority dump that replaces the menu. An urgent open item (time-windowed handoff · blocking external deadline) outranks the menu; an explicit task utterance skips it entirely (see Guards below); cadence reminders (§Cadence Rules) ride below it, they don't displace it. Canonical source: `fh_detail_protocols.md` Step 2 — keep branch tests and door labels in sync.

**Identity marker**: every greeting response (Step ②) opens with 🐿️ on its own line. It is embedded in both skeletons above (do not strip it when composing doors); the exploratory branch template carries it in `fh_detail_protocols.md` Step 2.

**Guards**: explicit task-entry utterance → skip onboarding · once per session · code/debug requests → start working directly · project routing is a suggestion, mention at most once
**Metadata-is-not-intent guard**: the trigger is the user's **typed message only**. Session metadata — branch name (auto-derived from the first message, e.g. `claude/korean-greeting-*`), repo name, file paths — is **never** a task spec and never suppresses or redirects the greeting trigger. A bare greeting fires onboarding even when the branch name looks like a feature request; if the only "task" signal lives in metadata and not in what the user typed, treat the message as a greeting and run the greeting branch + door skeleton above.

## New Skill Creation Pre-Commit Gate

All 6 items below must pass before committing a new SKILL.md. If any fails, fix and re-commit.

| Item | Criterion |
|---|---|
| **Role duplication check** | Pass `/asset-placement-gate` — no overlap with existing role clusters, **platform built-ins (Tier 0), or `claude-plugins-official` (Tier 1 official)**. Reinventing an official capability requires explicit justification in the SKILL.md (no-reinvention rule — FH builds only what adds governance) |
| **Description diet** | Plain text / 0 self-marketing expressions / 0 emphasis words (⭐, "critical", "groundbreaking") |
| **Done When defined** | At least 1 explicit completion condition |
| **Check-class declared** | Each Done When condition states its check class — mandatory-pass / measured / judged (`harness_6axis_framework.md` §Axis 5). Any judged condition names its adversarial pairing — no judge-only path |
| **Natural language triggers** | At least 3 examples that work without internal vocabulary |
| **Independently executable** | Confirmed to work without other FH skills (or dependencies are explicitly documented) |

Skills without a Done When definition automatically qualify as harness-doctor L2 M-tier.
Check-class declaration applies to **new** skills; existing skills backfill opportunistically
(when next edited), not retroactively.

---

## FH Improvement 4-Axis Auto-Gate (Self-Verification Orchestrator)

**Whenever the AI modifies FH assets** (SKILL.md · `.claude/rules/*.md` · `templates/` · `CLAUDE.md` · substantive `knowledge/` docs · substantive `docs/*.md` · `AGENTS.md` — see Substantive carve-out below),
the 4-axis verification chain runs **automatically before the first commit** of that session.
No user request is needed — this is a mandatory autonomous step, not a proposal.

**Commit gate**: `git commit` on FH asset changes is hard-blocked by `templates/.git-hooks/pre-commit` until all required axes PASS. Hook installation (one-time): `git config core.hooksPath templates/.git-hooks && chmod +x templates/.git-hooks/pre-commit`

```
FH asset modified → Axis 1 (regression_guard.sh --pr {BRANCH})
  → Axis 2 (/steel-quench) → Axis 3 (/phantom-quench)
  → marker: tracks/_meta/.axes_23_passed_{branch}_{date}.marker
     (structured — required fields: axis2-engine / axis2-model / floor-status;
      hook validates mechanically: below-floor blocks without below-floor-ack)
  → Axis 4 (/edit-manifest RECORD, today's entry in edit_manifest.yaml)
  → All 4 PASS → git commit allowed   |   Any FAIL → fix inline, re-run
```

**Why automatic**: Each axis catches a different defect class; asking separately means slip-through. **Why hook**: CLAUDE.md rules are advisory — the hook physically blocks commit until marker + manifest exist. **Scope**: active from the moment any FH file is modified in the session.

**Lightweight exception** (Axis 1 + 4 only, skip Axes 2–3): Sessions where **zero SKILL.md / rules / templates files changed** (e.g., CATALOG.md entry, tracks/ update). The hook detects this automatically — no Axes 2+3 marker required for light-only commits. Judgment is file-based, not subjective.

**Substantive carve-out — `knowledge/` · `docs/*.md` · `AGENTS.md`** (Axes 2–3 DO run, despite these not being SKILL/rules/templates): a change to any of these is **not** light if its diff adds a fenced code block (```` ``` ````) or a citation/version claim (`arXiv:` / `DOI` / `http` / a versioned dependency like `x.y.z`). Executable patterns and factual claims need phantom-detection + adversarial review *wherever they live* — `knowledge/` Implementation-Patterns sections carry runnable commands, `docs/` holds published guides, and `AGENTS.md` is the Codex-user entry point, so a phantom skill name or wrong version there is an external-facing error the gate must catch. Prose-only edits (typos, rewording, link fixes) stay light. Detection is mechanical: `git diff` adds a ```` ``` ```` fence or a citation token → run Axes 2–3.

**Unavailable axis**: If steel-quench or phantom-quench are not installed, note `Axis N: skipped (skill unavailable)` and proceed. Axis 1 PASS alone is sufficient to unblock a PR when Axes 2–3 are unavailable. Axis 4 (edit-manifest): if the skill is not installed, substitute a manual one-line prediction appended to `tracks/_meta/edit_manifest.yaml` — the record is what matters, not the skill.

**Target-tier sim gate (Mode D supplement — all change classes: fix, improvement, new asset)**: the
discriminator is not the change class but the **enforcement column**: does the asset's effect depend on
a session *following prose instructions* (salience-dependent — rules, onboarding scaffolds, SKILL.md
trigger behavior), or is it mechanically enforced (hooks, scripts — tier-independent, normal 4-axis
path, exempt)? For salience-dependent changes, verify with a **blind simulation in an isolated Agent**
(no main-session reasoning inherited — isolation is the FH mechanism that keeps the sim honest) with
`model:` pinned to the tier the change must survive on. Application strength scales with context:
- **Mode D (FH self-dev) — near-mandatory**: any salience-dependent FH asset change runs the sim
  before Done. Mandatory without exception when the change fixes a behavioral miss *observed* on a
  specific tier — sim at that same tier (the verification tier must match the failure tier; fixing on
  a stronger model and verifying by review alone leaves "does it fire on the weaker tier?" unanswered).
- **Field harness assets (templates/ propagated via Full-Harness Mode) — conditional**: sim at the
  default field tier (Sonnet) when the behavior is load-bearing (gates, onboarding, destructive/publish
  paths); skip with a one-line note for low-stakes prose.
- **Light mapping (tracks/ registration, CATALOG entries) — exempt**, alongside mechanical changes
  (hook logic, scripts, file moves — tier-independent by construction).

**Autonomy floor**: the skip/run *judgment* on conditional cases is itself depth-sensitive — trust it
only at opus-tier or above. A below-floor orchestrator does not silently skip: it runs the sim or asks
the operator (one line), mirroring §Floor governance.

If `model:`-pinned dispatch is unavailable (plan/billing gate), fall back to a cross-session headless
run (`claude -p "<trigger>" --model <tier>` in the target cwd) — stronger isolation, zero instruction
contamination. **Saturation disguise (N=2, 2026-06-11/12)**: the same "Usage credits required for 1M
context" error also fires when the *session* is near context saturation, not the plan gate — in a
long-running session, compact (flush handoff state to disk first) and retry the dispatch once before
concluding the gate is closed (identical opus-pinned dispatch failed pre-compaction, succeeded
post-compaction 2026-06-12). 2026-06-15+: headless `claude -p` draws from the hard-capped credit pool, not the
subscription — prefer in-session Agent dispatch when the plan gate allows; take the headless fallback
knowingly. Record sim results in the Axes 2–3 marker + sub-agent invocation log.

**Axis ownership** (each skill is already complete — orchestrator only coordinates):

| Axis | Skill | What it catches |
|---|---|---|
| Backward | `regression_guard.sh` | Critical section loss, broken refs, syntax errors, line reduction |
| Adversarial | `steel-quench` | Trigger phrase collisions, design attack surface, over-engineered steps |
| Forward | `phantom-quench` | Phantom references, paths that don't exist, stale external links |
| Record | `edit-manifest` RECORD | Logs predicted impact — closes the predict-verify loop for future harvest-loop |

### Mode D Model Notice (fires once, at the same trigger as this gate)

The moment FH self-development work begins (= the gate's own activation trigger: an FH asset is about
to be modified), check the **session model** (self-identity; if the runtime withholds it, treat as
unknown) and surface **one line** — then proceed, never block:

- Model known and opus-tier or above → no notice (already optimal).
- Model known and below opus-tier → *"이 작업은 FH 자체개발(Mode D)입니다 — 가용 최강 모델 핀을
  권장합니다 (`/model opus` 이상; 측정 근거: README §Model setup). 그대로 진행해도 floored
  디스패치가 깊이 턴을 커버하지만, 세션-레벨 설계 깊이는 핀이 좌우합니다."*
- Model unknown (runtime withholds identity) → static fallback: *"FH 자체개발 작업입니다 — 세션
  모델이 opus 이상이 아니라면 핀 전환을 권장합니다 (`/model opus`+)."*

**Guards**: once per session · advisory only — **never switch the session model** (human override is
inviolable; a pin is not a cap — tier-floor resolution §Floor governance) · field-project operation
sessions (no FH asset modification) never see this notice — the Sonnet default stays friction-free.

## Pre-Publish Surface Gate (Irreversibility Gate — Publish, not Commit)

**Order invariant: scrub before publish, never publish-then-scrub.** Public exposure is effectively
irreversible — a repo or package is briefly live the instant it goes public and may be cached or forked
before any scrub. So the audit must fire **pre-publish**, not after.

**When this gate fires** — *before* any action that makes a repo/package **publicly visible for the
first time**, especially one **derived from internal/company assets** (operator-IP that originated in a
private harness): `gh repo create --public`, `gh repo edit --visibility public`, a first push to a new
public remote, `npm publish`, `twine upload`, a private→public visibility flip.

**Required before the public action** (all must be non-LEAK/non-FAIL) — this gate is the **umbrella that
invokes them**, not a competitor; when publish intent is detected, fire *this* gate (it then runs the chain),
not marketplace-gate alone:
1. `/public-surface-audit` — operator-private token scan (real username, corp asset names, home paths)
2. `/marketplace-gate` Check 5 — broad public safety (API keys, internal domains, license)
3. `/security-review` (built-in, when the repo ships executable code) — code-security pass on the
   publishable surface; complements 1–2 which scan tokens/metadata, not code behavior. Skip note
   (`skipped: docs-only repo` or `skipped: built-in unavailable`) if not applicable

> Routing vs the rows below: `/marketplace-gate` alone = "is this ready to **list on a marketplace**?";
> `/public-surface-audit` alone = reactive "did I leak a token?"; **this gate** = the *act of going
> public* (visibility flip / first public push / registry publish) — it chains the other two.

**Cheap mechanical pre-flags** (any one → stop and run the gate): author/commit **email = corp domain** ·
`LICENSE`/`README` contains a **private harness name or internal codename** · **module paths encode
internal acronyms**.

**Why no hook (honest)**: the irreversible action is `gh repo create --public` / a visibility flip, **not
`git commit`** — and it usually happens in a **separate repo**, not forge-harness. The FH pre-commit hook
cannot catch either. This gate is therefore **AI-behavioral** (proactive trigger below) **+ a portable
checklist** (`templates/PRE-PUBLISH-CHECKLIST.md`) the operator runs on any repo, on any machine.

> Origin: 2026-06-05 `phantom-gate` shipped public, then needed a private→de-company-scrub→re-public
> round-trip (`fh_signal_2026-06-05_fh-direct`). PSA existed but nothing forced it pre-publish.

---

## Destructive-Op Gate (Irreversibility Gate — Delete/Rewrite, not Commit)

**Order invariant: enumerate → recover → destroy, never destroy-then-check.** Deletion and history
rewrite are irreversible in the way publish is — except the loss is *silent* (nobody sees what a
deleted branch was carrying).

**When this gate fires** — *before* any of: branch deletion (local or remote), history rewrite /
force-push, scrub of tracked history, bulk deletion of session records / tracks content.

1. **Enumerate (measured)**: `bash templates/predelete_check.sh <repo> [base]` — per branch: commits
   off base + unique paths. Verdicts: SAFE (fully merged) · CHECK (0 unique paths but commits off
   base — shared files may hold *newer* content, e.g. an unmerged session card) · REVIEW (unique
   paths — recovery mandatory).
2. **Recover (judged — depth-sensitive)**: every CHECK/REVIEW item gets a content-direction look;
   live un-integrated state (cards · handoffs · signals · session records) is integrated to main
   **before** anything is deleted. This step exists because the loss class is silent — run it at the
   strongest available tier (floor semantics, §Tier-floor); a below-floor pass is provisional.
3. **Destroy** only what passed — REVIEW blocks a scripted delete chain (script exits 1).

> Origin: 2026-06-10 branch cleanup — pre-deletion enumeration recovered a parallel session's card
> (weekly-audit completion + #88 merge state) that existed **only on an unmerged branch** with zero
> unique paths: exactly the CHECK class, invisible to "is it merged?" intuition. Deletion without the
> gate destroys live state without anyone noticing.

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
| "review this PR", "check diff", "code review" | code diff → built-in `/code-review`·`/review` · FH-asset coherence → `/hub-cc-pr-reviewer` (role split) |
| "keep watching X", "poll this", "check every N minutes", recurring WATCH item | built-in `/loop` (interval runner) — pair with the WATCH list, don't hand-poll |
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
| "did I leak anything", "public surface audit", "private token scan", "is my split clean", "check tracked files for private tokens" | `/public-surface-audit` |
| "publish", "make public", "make this repo public", "go public", "gh repo create --public", "flip to public", "first public push", "publish the package", "npm publish", "twine upload" (publish intent — **proactive**, fire *before* the action) | **Pre-Publish Surface Gate** (see above → `/public-surface-audit` + `/marketplace-gate` Check 5 must PASS first) |
| "delete the branch", "브랜치 삭제", "브랜치 정리", "clean up branches", "force-push", "rewrite history", "지워도 돼?" (destructive intent — **proactive**, fire *before* the action) | **Destructive-Op Gate** (see above → enumerate → recover → destroy; `templates/predelete_check.sh`) |
| "look at this again", "is this right", "counterargument", "re-validate" | `/verify-bidirectional` |
| "MCP failing", "tool keeps erroring", "circuit-breaker", "same error looping" | `/mcp-circuit-breaker` |
| "add this MCP server", "mount this MCP", "mcp.json에 추가", "connect this tool server" (external-MCP mount intent — **proactive**, fire *before* first tool call; mount intent only — a failing/erroring mounted server is `/mcp-circuit-breaker`'s row above) | `templates/.claude/rules/mcp_tool_gating.md` (name-keyed ask/allow table — never trust server annotations or names; fill §3 at mount time) |
| "token budget", "how expensive", "estimate tokens", "will this cost a lot" | `/token-budget-gate` |
| "did my rule change break anything", "regression check", "test harness changes" | `/prompt-regression` |
| "SKILL.md too large", "split this skill", "skill is bloated", "skill file too long" | `/skill-splitter` |
| "review for the team", "CTO review", "decision-maker", "share with leadership", "approval deck" | `/apex-review` |
| "run full pipeline", "verify everything", "end-to-end sweep", "chain all verifications" | `/pipeline-conductor` |
| "help me write a prompt", "build a prompt", "improve this prompt", "prompt template" | `/meta-prompt-builder` |
| "/goal", "run this autonomously", "big multi-step task", "orchestrate this goal", or **any heavy autonomous/multi-agent run** (proactive — propose *before* running; it is expensive, so the proposal is mandatory, not the auto-run) | `/goal-quench` (budget gate + quality gate) |
| "I don't know what to build", "how should I approach this", "organize this for me", "clarify this", "정리해줘" (ambiguous request before dispatch) | `/deep-clarify` |
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

## Agent Dispatch Operation (FH cwd-Based)

Default operation is a **standard interactive session**. Agent dispatch (single or parallel) is used when the task warrants it — not as a default mode. Three execution paths:

| Path | Situation | Method |
|---|---|---|
| **Direct edit** | Simple modification of mapped project files | Read/Edit with absolute path (no cwd switch needed) |
| **Agent dispatch** | Field project work · single independent task | Inject Context Card then dispatch Agent |
| **Parallel dispatch** | 2+ genuinely independent tasks, explicitly requested | Dispatch parallel Agents |

**Why not Agent View by default**: Agent View introduces worktree isolation (blocks settings.json writes, Stop hook timing differs), session context gaps (session card stale content bug), and path friction — with no benefit unless the user is actively managing multiple agent sessions. Parallel agents via `Agent` tool work identically in a standard session.

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

> Usage modes (A/B/C) + what-you-get (Layer 1/2) details: `.claude/rules/modes_and_value.md`

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
  → ① Check git diff + unpushed commits (status snapshot)
  → ② If FH assets changed: harvest-loop
  → ③ Sync local/gitignored session state to your durable companion store, if you keep one
  → ④ Memory hygiene — update stale entries + record new session findings
  → ④-b npm freshness — if any npm-shipped asset changed this session (the `package.json` `files[]`
       surface: skills · agents · README · AGENTS.md · CLAUDE.md · CHEATSHEET), **propose an npm
       republish**: version bump + Pre-Publish Surface Gate (`/public-surface-audit` + `/marketplace-gate`
       Check 5) + `npm publish` + **`git tag vX.Y.Z` on the bump commit + `git push origin vX.Y.Z`**
       (tag at publish time, in lockstep with the version — keeps git tags aligned with npmjs.com so
       Releases/Tags never drift). The npm-served README and shipped skills/agents freeze at publish
       time, so updating FH assets without republishing leaves the package stale. **Propose, don't
       auto-publish.** Tag drift caveat: when a bump rides inside a functional commit (no explicit
       "bump" commit), tag *that* commit — otherwise the version ships to npm untagged (e.g. 1.4.4/1.4.5
       shipped untagged, backfilled 2026-06-08).
  → ⑤ Card update ← ABSOLUTE LAST: must capture ①–④-b outcomes
  → ⑥ Commit card + push
```
**Card-last guard**: ①–④-b must ALL complete before ⑤ runs. Any new information produced
during ①–④ (new commits, model changes, new findings) feeds INTO ⑤ — card is never
written mid-sequence and then left open for more work to accumulate after it.

**Mid-session card writes are drafts**: If a task (e.g., a calibration run) internally updates
the card, that is a draft. The close chain always re-runs ⑤ to capture post-draft activities.
Never skip ⑤ because "the card was just updated" — check for delta first.

Card update is NOT a sub-step of harvest-loop — even if harvest-loop is skipped, card update must run.

**Agent View pre-read (mandatory when session ran in Agent View / worktree / background job)**: Before writing the card, read your companion store's handoff files (if you keep one) to recover sub-agent completions that may not be in main session context. Skipping this step in Agent View is the root cause of "card created with stale content" bugs — the main context does not automatically see worktree-completed items.

**Card update obligation** (independent obligation — regardless of harvest-loop completion): Update `reference_next_session_starter.md`.  
① **Agent View pre-read** (see above) → ② Step 0-b cross-check generates removal list → ③ Remove completed items → ④ Add new priorities → ⑤ Fix stale paths/versions → ⑥ Overwrite → ⑦ Output "BEFORE N items → AFTER M items" diff.  
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

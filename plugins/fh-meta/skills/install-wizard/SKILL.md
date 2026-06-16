---
name: install-wizard
description: Run when setting up a new project for the first time or onboarding after installing FH (first setup, initial configuration, onboarding start, configure project, help me set up). Performs environment detection → gap diagnosis → item-by-item suggestions → user approval → execution → acceleration baseline setup in sequence. Use --dry-run to output diagnosis report only (bg dispatch compatible).
user-invocable: true
allowed-tools: ["Read", "Write", "Bash", "Glob", "Grep", "Edit"]
model: opus
category: Composability Gate
---

# install-wizard — Onboarding Setup Wizard

> ⚠️ **Prerequisite — Read first if this is your first install**
>
> This skill is available **after the fh-meta plugin is registered in Claude Code**.
> If you type `/install-wizard` and CC doesn't respond, the plugin hasn't been registered yet.
>
> **When running Claude Code from the FH directory**: the AI detects the MISS automatically
> and installs the plugin via Bash — no manual input needed. Just say "install the plugin."
>
> **Manual fallback (if needed):**
> ```bash
> claude plugin marketplace add https://github.com/chrono-meta/forge-harness.git
> claude plugin install -s user fh-meta@forge-harness
> ```
> After install, if `install-wizard` appears in `/skills` list in CC chat, you're ready.
> See `README.md > Advanced Settings > Plugin Install` for detailed guide.

Run immediately after cloning forge-harness (FH), or when setting up a new project for the first time.
Sets up the periodic-audit notification structure: a permanent zshrc hook (`fh_audit_check.zsh`, runs on terminal start) plus FH's session-start mtime detection. Both surface a weekly-audit reminder when 7+ days have elapsed since the last `weekly_audit` — no persistent cron is used (a session-scoped scheduler cannot survive to fire on a later day).

## Key Terms

| Term | Definition |
|---|---|
| **sentinel** | An empty file that records whether a specific event (audit complete, install complete, etc.) has occurred. Created in `~/.cc_sentinels/`. |
| **zshrc hook** | Shell function added to `~/.zshrc`. Automatically runs on terminal start and applies permanently. |
| **session-start detection** | FH's durable weekly-audit cadence — at session start the mtime of the latest `weekly_audit_*` is checked and `/harvest-loop` is proposed if 7+ days elapsed (see CLAUDE.md Cadence Rules). No persistent scheduler required. |

## Execution Modes

| Mode | Trigger | Action |
|---|---|---|
| **Normal mode** (default) | `/install-wizard` | Gap diagnosis → per-item approval → execution → zshrc/sentinel install (interactive) |
| **Analysis mode** | `/install-wizard --dry-run` | Gap diagnosis + report output only. No approval gate or execution. bg dispatch compatible |

> On `--dry-run`, outputs Step 2 report then skips Steps 3~4 and exits early.

## Core Principles

- **Propose-First**: Show proposal list and get approval before any changes
- **Per-item approval**: Select each item individually (Y approve / N skip / L later)
- **Double-confirm irreversible changes**: Preview before file writes and zshrc modifications
- **User review before PR creation**: Output PR parameters (title, base branch, included files, body) and get approval before execution. No automatic submission.
- **Periodic audit structure setup**: zshrc hook (permanently applied on terminal start) + sentinel initialization + session-start mtime detection (7-day threshold)

## Execution Steps

> Overall flow summary (guide for first-time readers):
>
> | Stage | Name | Condition |
> |---|---|---|
> | **Step 0-A** | FH suitability pre-check (pre-flight) | Always run |
> | **Step 0-B** | Git token pre-injection | When repo creation/fork/push included |
> | **Step 0** | Auto environment detection + environment card output | Always run (after 0-A/B) |
> | **Step 0-C** | Existing harness detection + integration proposal | Auto-run when CLAUDE.md >50 lines or 3+ rules |
> | **Step 1** | Gap diagnosis | Always run |
> | **Step 2** | Diagnosis report + proposal list | Always run (`--dry-run` exits here) |
> | **Step 3** | User approval → per-item execution | Normal mode only |
> | **Step 4** | Acceleration baseline setup | Normal mode only |
> | **Step 5** | Completion report + contribution guidance | Normal mode only |
>
> **Sub-step vs Main step**: Steps 0-A/B/C are sub-steps of Step 0 environment detection.
> Proceed in order 0-A → 0-B → 0 (environment card) → 0-C, then move to Step 1.

### Step 0-A. FH Suitability Pre-check (pre-flight)

If this is your first time with FH, confirm 3 things before install. All should apply for maximum effect.

| Check item | Optimal situation | If not |
|---|---|---|
| **Are you using Claude Code as your primary tool?** | ✅ Using CC daily | FH only works on top of CC. Need to adopt CC first |
| **Are you running 2+ projects in parallel or have a meta-hub?** | ✅ Multiple projects or team shared environment | FH may not be needed for a single small project |
| **Do you want to structurally improve AI collaboration quality?** | ✅ Repeatedly performing verification/simulation/diagnosis | If you only want simple coding automation, deeper skills after install-wizard are optional |
| **Are you developing or researching FH itself?** | ✅ Extending skills, writing papers, running experiments on FH | → **Mode D** — companion-store setup needed |

Fewer than 2 of 3 (first three) → Proceed with install but recommend using only core skills (`context-doctor`, `harness-doctor`) first.
All 3 → Proceed in order: Step 0-B (token injection) → Step 0 (environment card) → Step 0-C (existing harness).

**Mode D detected (FH developer/researcher)**: Guide companion-store setup before Step 1. **Ask the backend first** — the store is a role (durable private home for artifacts), not a fixed `*-be` git repo: Obsidian vault / gbrain-ingest / `*-be` git repo (default) all qualify. Do not assume the repo path.

> **Detail**: See `SKILL_detail.md §Mode-D-Companion-Setup` — backend-branching question (Obsidian / gbrain / *-be git default), remote-backed and local-only setup commands, cross-backend invariants — read when Mode D is detected.

### Step 0-B. Git Token Pre-injection (when repo creation/fork/push included)

When the work involves Git authentication needs like GitHub repo creation, fork, push, etc.,
inject the token as an environment variable in the terminal **before starting the CC session**.
Pasting tokens directly in chat exposes them in conversation history; environment-variable injection keeps them out of the record while gh / git CLI automatically recognizes them.

> **Detail**: See `SKILL_detail.md §Token-Injection` — Method A (per-session export) and Method B (permanent local secret file) — read when executing Step 0-B.

### Step 0. Auto Environment Detection — Environment Card Output

*(Run after Step 0-A·B pre-checks. Output results as environment card, then continue to Step 0-C.)*

CC runs the detection bash automatically (injection pre-flight scan → FH_DIR/CC_HUB_DIR → cwd project info → plugins → MCP → zshrc hook → optional framework detection), then outputs the environment card.

**Stop rule (behavioral)**: if `FH_DIR` is not set, output the bootstrap guidance and **do not proceed to subsequent Steps** — install FH first, then rerun.

> **Detail**: See `SKILL_detail.md §Step0-Detection-Bash` (detection script + FH_DIR bootstrap guidance) · `§Env-Card-Format` (card template + optional pattern-pack note) — read when executing Step 0.

### Step 0-C. Existing Harness Detection + Integration Proposal

> **Safe**: This step is analysis/proposal output only. No file writes. Runs safely regardless of `--dry-run` flag.

> **Core message**: FH is not something placed on top of an existing harness.
> It analyzes existing rules to remove duplicates — making things lighter.

**Detection condition (behavioral)**: run integration analysis when `CLAUDE.md > 50 lines` OR `3+ .claude/rules/*.md files`. Otherwise → new install, move to Step 1.

**When existing harness detected — analyze existing CLAUDE.md + rules along 3 axes:**

| Analysis axis | What to check | FH response |
|---|---|---|
| **Duplicate rules** | Patterns already covered by FH standard skills (context-doctor, harness-doctor, verify-bidirectional, etc.) | Classify as removable items |
| **Project-specific** | Rules valid only for this project/domain | Keep (FH does not touch these) |
| **FH-delegatable** | Manually written recurring patterns (commit format, review checklists, audit schedule, etc.) | Classify as delegatable to FH skills |

**Respect user judgment**: FH mapping (duplicate removal, skill delegation) is not forced.
If FH is truly frontier, it will be chosen naturally. The choice is the user's.
Y (add integration plan items to Step 1) / N (add-only, keep existing rules) / S (skip, reanalyze later) — any choice continues to Step 1.

> **Detail**: See `SKILL_detail.md §Step0C-Integration` — illustrative single-run measurements, detection bash, integration analysis output format — read when executing Step 0-C.

### Step 1. Gap Diagnosis

**[Prerequisite] install-doctor conflict diagnosis (only in environments without install history)**: if `~/.cc_sentinels/{project-name}_wizard_done` doesn't exist (first install), call `/install-doctor --plugin fh-meta` first. CONFLICT/WARNING items → add ❗ markers to Step 2 proposal list. Items the doctor already diagnosed (`FH plugin install` · `zshrc hook` · `.claudeignore`) → map results directly, skip re-diagnosis; all other items → check directly.

Auto-check each item as PASS / MISS / FAIL. Check items: `.claudeignore` · `local_fh_context.md` · `zshrc hook` · `weekly_audit` freshness · `sentinel` setup · FH plugin install · `.git/info/exclude` · MCP plugin · `deep-insight` plugin (optional) · `fh_env_context.jsonc` · `phantom-gate` (Python + AI-output projects only) · domain pattern pack (optional, none ship by default).

> **Detail**: See `SKILL_detail.md §Step1-Checks` — full check table with criteria and verification commands per item — read when executing Step 1.

**Score calculation (behavioral)**: PASS = 1 / MISS = 0.5 / FAIL = 0. Formula: `score = round( Σ(points) ÷ (applicable item count) × 100 )`. Conditional items (domain pattern pack / phantom-gate / MCP / deep-insight) are excluded from the denominator when not relevant, so always print the denominator next to the score (e.g. `{score}/100 over {n} applicable items`) — the percentage is reproducible only when the item count is shown.

### Step 2. Diagnosis Report + Proposal List

Output diagnosis results and generate per-item proposals. Each item: **Y (approve) / N (skip) / L (later) / A (approve all)**.

**cross-install detection → agent-composer auto-update proposal**: when external plugins are cross-installed, collect their trigger keywords, check against `agent-composer/SKILL.md` Step 1 mapping table, and propose an update for missing triggers (included in Step 3). No gaps → output "agent-composer mapping up to date".

**`--dry-run` branch point (behavioral)**: if the flag is set, output the dry-run summary and **exit here** (skip Steps 3~4).

> **Detail**: See `SKILL_detail.md §Step2-Formats` — diagnosis report template, 9-item proposal list with per-item commands, cross-install output format, dry-run exit message — read when executing Step 2.

### Step 3. User Approval → Per-item Execution

After receiving approval input, execute in order. **Output actual action preview before each execution.**

Execution priority (behavioral):
1. FAIL items (immediate effect)
2. MISS items (configuration supplementation)
3. Optimization items (optional)

> **Detail**: See `SKILL_detail.md §Step3-Execution` — action preview example, FH plugin auto-install bash + error handling table + success format, agent-composer mapping update format — read when executing Step 3.

### Step 4. Acceleration Baseline Setup

After executing approved items, install the automatic maintenance structure: zshrc hook (idempotent, preview-then-confirm) + sentinel initialization (per-project) + weekly-audit cadence (no cron — zshrc hook + session-start detection are the durable mechanisms).

**4-axis pre-commit gate (behavioral — OPT-IN, double-confirm)**: Mode D / FH-self-development only. It gates commits **in the user's FH clone** and is **never installed into field projects** (FH-internal infra — see `auto_project_mapping.md §6`). Not auto-run: a separate explicit Y/N, never folded into the baseline-setup batch.

> **Detail**: See `SKILL_detail.md §Step4-Baseline-Bash` — zshrc hook block, 4-axis gate install commands with scope statement, sentinel init — read when executing Step 4.

### Step 5. Completion Report + Contribution Guidance

Output the completion summary (executed/skipped/later counts + what runs automatically from now on) followed by next-step skill suggestions, FH contribution guidance, Mode D companion-store pointer, and the fork-your-own-hub option.

> **Detail**: See `SKILL_detail.md §Step5-Completion-Report` — full completion report template — read when executing Step 5.

## Re-run (Inspection Mode)

When run again in an environment that has already passed the wizard (`~/.cc_sentinels/{project-name}_wizard_done` exists — per-project independent), operates in **inspection mode**:
- Only runs Step 1 gap diagnosis
- Proposes only newly found MISS/FAIL items
- No full reinstall

## External User Environment Adaptation

| Mode | Environment | Action |
|---|---|---|
| **A** (full) | FH clone + CC hub (your-hub etc.) present | Run all Steps 0~5 |
| **B** (FH standalone) | FH clone + no CC hub | Skip CC_HUB_DIR-related items, focus on FH setup |
| **C** (plugin only) | CC plugin install only (no FH clone) | Steps 0~2 diagnosis + guide output / no file writes |

## Activation Triggers

> **CC auto-detection**: Based on description field keywords (list below is for human reference).

- `/install-wizard`
- "first setup", "initial configuration", "onboarding start", "help me set up"
- "configure project", "onboarding start", "help me set up"
- "wizard" (when used standalone, confirm FH context before activating)

## Three-Doctor Loop Integration

| Situation | Integrated skill |
|---|---|
| Structural anomaly detected | `/harness-doctor` |
| Token waste pattern detected | `/context-doctor` |
| External user simulation needed | `/sim-conductor` |
| Install conflict suspected | `/install-doctor` |

## Per-Cluster Deferred Loading (Progressive Disclosure)

Only activate the cluster matching the utterance — loading all skills degrades selection quality.

| Cluster | Trigger keywords | Skills |
|---|---|---|
| **A — Harvest/Evolution** | harvest · session wrap-up · pattern · reverse absorption · fh evolution | field-harvest · harvest-loop · contention-layer · verify-bidirectional |
| **B — Diagnosis (doctor)** | diagnose · health · check · inspect · token waste · install conflict · doctor | harness-doctor · context-doctor · sim-conductor · install-doctor · install-wizard |
| **C — Compose (composer)** | agent composition · parallel · compose prompt · context card | agent-composer · meta-prompt-builder |
| **D — Audit/Review** | review · audit · PR review · steel quench · adversarial · lint · placement | hub-cc-pr-reviewer · steel-quench · apex-review · harness-doctor (--lint) · marketplace-gate · asset-placement-gate |
| **E — Explore/Frontier** | trends · plugin recommendation · synergy · frontier | frontier-digest · plugin-recommender · cross-ecosystem-synergy-detection |
| **F — Common (always-on)** | — | convergence-loop · deliberation (fh-commons) |

Rules: single match → that cluster only · multi-match → all matched · unclear → default B + delegate to agent-composer.

---

## Failure Response

On Claude API / MCP failure → refer to [`references/fallback-guide.md`](../../references/fallback-guide.md) manual checklist.

---

## Done When

```
☐ Environment detection complete: shell, CC version, OS, project type identified
☐ Gap diagnosis output: present vs missing items listed
☐ User approval/decline recorded for each suggested item
☐ All approved items installed with no failure state
  (failed installs surfaced to user — not silently skipped)
☐ Acceleration baseline confirmed: zshrc alias + sentinels active (or user declined)
☐ Summary output: "N items installed, M items skipped — setup complete"
```

`--dry-run` mode Done When: gap diagnosis report written, no installation executed.

---

## Hub Orchestration Hint

After setup, **where you work** significantly affects efficiency:

| Work type | Recommended location |
|---|---|
| Single project coding/debugging | That project's cwd |
| Meta/audit/simulation / 2+ projects simultaneously | Meta-harness cwd → Agent parallel dispatch |

Dispatching multiple tasks simultaneously using the `Agent` tool from the meta-harness cwd enables 5-6x acceleration vs sequential. However, this isn't forced — focused work on a single project is best done at each project's own cwd.

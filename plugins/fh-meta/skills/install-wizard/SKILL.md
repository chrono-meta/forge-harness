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
| **Are you developing or researching FH itself?** | ✅ Extending skills, writing papers, running experiments on FH | → **Mode D** — companion-store setup needed (see below) |

Fewer than 2 of 3 (first three) → Proceed with install but recommend using only core skills (`context-doctor`, `harness-doctor`) first.  
All 3 → Proceed in order: Step 0-B (token injection) → Step 0 (environment card) → Step 0-C (existing harness).

**Mode D detected (FH developer/researcher)**: Guide companion-store setup before Step 1.

```
You're developing FH itself — you need a private companion store
alongside the public mirror.

Recommended layout:
  public:  {org}/{hub}        (methodology, skills, rules)
  private: {org}/{hub}-be     (paper drafts, experiment logs,
                               raw signals, handoff files)

Quick setup:
  gh repo create {org}/{hub}-be --private
  git clone https://github.com/{org}/{hub}-be ~/path/to/{hub}-be
  mkdir -p {hub}-be/{paper-drafts,paper-signals,digests,handoff}

Key rule: knowledge/shared/ drafts stay local via .gitignore glob.
Push snapshots to the companion store explicitly — never auto-push.
handoff/ files bridge cloud session → local without exposing content.
```

### Step 0-B. Git Token Pre-injection (when repo creation/fork/push included)

When the work involves Git authentication needs like GitHub repo creation, fork, push, etc.,
inject the token as an environment variable in the terminal **before starting the CC session**.

> Pasting tokens directly in chat exposes them in conversation history.
> Injecting as environment variable keeps them out of the record while gh / git CLI automatically recognizes them.

**Method A — One-time injection per session (recommended):**
```bash
# In terminal before starting CC
export GH_TOKEN=ghp_xxxx        # GitHub Personal Access Token
export GITHUB_TOKEN=$GH_TOKEN   # Some CLIs read GITHUB_TOKEN
claude                           # gh / git commands will automatically use token afterward
```

**Method B — Permanent local secret file:**
```bash
mkdir -p ~/.cc_secrets
echo 'export GH_TOKEN=ghp_xxxx' >> ~/.cc_secrets/tokens.env
chmod 600 ~/.cc_secrets/tokens.env
echo 'source ~/.cc_secrets/tokens.env' >> ~/.zshrc
```

> `~/.cc_secrets/` is a local-only path outside git management — not a commit target for team repos.

---

**The following are environment detection procedures that CC executes automatically. No need for users to run manually.**

```bash
# Prompt injection pre-flight: check for AI instruction injection in external config files
if grep -rE "^# CLAUDE:|^# AI:|<instructions>" ~/.zshrc .claude/settings.json 2>/dev/null | grep -q .; then
  echo "⚠️  AI instruction pattern detected in external config files — injection risk. Manual check recommended."; fi

# FH location
echo "FH_DIR=${FH_DIR:-not set}"
echo "CC_HUB_DIR=${CC_HUB_DIR:-not set}"

# cwd project info
basename "$(pwd)"
ls .claude/ 2>/dev/null

# CC settings (handle both dict and list for plugins)
cat .claude/settings.json 2>/dev/null | python3 -c "
import json,sys
d=json.load(sys.stdin)
p=d.get('plugins',{})
print('plugins:', list(p.keys()) if isinstance(p,dict) else p)
" 2>/dev/null || echo "settings.json not found"

# MCP plugin connection status
python3 -c "import json,os; d=json.load(open(os.path.expanduser('~/.claude.json'))); print('MCP:', list(d.get('mcpServers',{}).keys()))" 2>/dev/null || echo "MCP config not found"

# zshrc hook status
grep -q "fh_audit_check.zsh" ~/.zshrc 2>/dev/null && echo "zshrc hook: present" || echo "zshrc hook: absent"

# Framework detection (Streamlit) — must be specified in requirements.txt or pyproject.toml
STREAMLIT_PROJECT=false
if grep -q "streamlit" requirements.txt 2>/dev/null || \
   grep -q "streamlit" pyproject.toml 2>/dev/null; then
  STREAMLIT_PROJECT=true
  echo "Framework: Streamlit detected"
fi
```

**Bootstrap guidance when FH_DIR is not set (stop immediately in Step 0):**
```
⚠️  FH_DIR not set — install FH first then rerun.

  1. Clone FH repo:
     git clone https://github.com/chrono-meta/forge-harness ~/forge-harness

  2. Set environment variable:
     export FH_DIR=~/forge-harness

  3. Install FH plugin in CC:
     Settings → Plugins → Add → {FH_DIR}/plugins/fh-meta

  4. Rerun /install-wizard after completion
```
→ Do not proceed to subsequent Steps when FH_DIR is not set.

### Step 0. Auto Environment Detection — Environment Card Output

*(Run after Step 0-A·B pre-checks. Output results as environment card, then continue to Step 0-C.)*

Output detection results as **environment card**. Activate CC pattern reference on Streamlit detection:
```
📌 Streamlit project detected → CC pattern reference activated
   {CC_HUB_DIR}/knowledge/shared/streamlit_patterns.md loaded (if present — optional Streamlit pattern pack, not shipped by default)
   Check: data_editor empty df / column nesting / async wrapper / CSS numeric variables
```

```
install-wizard — Environment Detection
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Project:      {cwd name}
  FH_DIR:       {path or not set}
  CC Hub:       {CC_HUB_DIR or not set}
  Plugins:      {installed plugin list}
  zshrc hook:   {present/absent}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Step 0-C. Existing Harness Detection + Integration Proposal

> **Safe**: This step is analysis/proposal output only. No file writes. Runs safely regardless of `--dry-run` flag.

> **Core message**: FH is not something placed on top of an existing harness.  
> It analyzes existing rules to remove duplicates — making things lighter.
>
> **Measured expectations** (--dry-run verified values):
>
> | Project type | Example | Total volume | Reduction | Main cause |
> |---|---|---|---|---|
> | QA strategy platform (domain-specialized complete) | Project A | 324 lines | **14%** (46 lines) | Duplicate meta operation rules |
> | Mobile QA automation framework | Project B | 2,448 lines (constant) | **32%** (~790 lines) | 2 unremoved duplicate files post-install |
>
> Token savings: Project A ~0.5K/session, Project B ~15~20K/session
>
> * QA strategy platform level = CLAUDE.md 200~400 lines, 5~10 rules files. Mobile QA automation level = 7+ rule files, 2,000+ lines of constant context.
> * Check your own project numbers directly with `/install-wizard --dry-run`. (These numbers are from actual single measurements and may vary by environment.)
>
> **How to read**: FH does not touch domain-specific rules (code guides, domain knowledge).
> Reduction targets are only meta operation rules (PR procedures, commit guides, FH path duplicates, etc.).

**Detection condition**: Run integration analysis if any of the following apply.

```bash
# Detect existing harness scale
CLAUDE_MD_LINES=$(wc -l < CLAUDE.md 2>/dev/null || echo 0)
RULES_COUNT=$(ls .claude/rules/*.md 2>/dev/null | wc -l || echo 0)

echo "CLAUDE.md: ${CLAUDE_MD_LINES} lines"
echo ".claude/rules/: ${RULES_COUNT} files"

# Existing harness detected: CLAUDE.md > 50 lines OR 3+ rules
if [ "$CLAUDE_MD_LINES" -gt 50 ] || [ "$RULES_COUNT" -ge 3 ]; then
  echo "STATUS: Existing harness detected → proceeding with integration analysis"
else
  echo "STATUS: New install → move to Step 1"
fi
```

**When existing harness detected — integration analysis:**

Analyze existing CLAUDE.md + rules along 3 axes.

| Analysis axis | What to check | FH response |
|---|---|---|
| **Duplicate rules** | Patterns already covered by FH standard skills (context-doctor, harness-doctor, verify-bidirectional, etc.) | Classify as removable items |
| **Project-specific** | Rules valid only for this project/domain | Keep (FH does not touch these) |
| **FH-delegatable** | Manually written recurring patterns (commit format, review checklists, audit schedule, etc.) | Classify as delegatable to FH skills |

**Integration analysis output format:**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Existing Harness Integration Analysis
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  CLAUDE.md current:    {X} lines
  .claude/rules/:       {N} files

  Duplicates (FH-covered): {A} items → can be removed
  FH-delegatable:          {B} items → replaceable with skills
  Project-specific:        {C} items → keep

  Expected after integration: CLAUDE.md {X} → {Y} lines ({Z}% reduction)
  Token savings estimate:     ~{W}K tokens/session saved
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Show integration plan?
  Y — Per-item removal/delegation detailed proposal (applied in subsequent Step 1)
  N — Continue with add-only approach (keep existing rules)
  S — Skip for now, move directly to Step 1. Can reanalyze later with /install-wizard --dry-run
```

**Respect user judgment**: FH mapping (duplicate removal, skill delegation) is not forced.  
If FH is truly frontier, it will be chosen naturally. The choice is the user's.  
Any of Y/N/S continues to Step 1.

**If Y selected**: Add integration plan items to Step 1 gap diagnosis and proceed.  
**If N/S selected**: Keep existing rules as-is and proceed with Step 1 in add-only mode for new FH items.

### Step 1. Gap Diagnosis

**[Prerequisite] install-doctor Conflict Diagnosis (only in environments without install history)**

If `~/.cc_sentinels/{project-name}_wizard_done` doesn't exist (first install), call install-doctor first and map results to the checks below:

```
/install-doctor --plugin fh-meta
```

install-doctor CONFLICT/WARNING items → add ❗ markers to Step 2 proposal list.  
No install-doctor results or clean → proceed directly with Step 1 checks.

Auto-check the following items based on detected environment. Each item classified as PASS / MISS / FAIL.

> ※ install-doctor result mapping scope:
> - Items diagnosed by doctor (`FH plugin install` · `zshrc hook` · `.claudeignore`) → map doctor results directly, skip re-diagnosis.
> - Items not diagnosed by doctor (`weekly_audit` · `sentinel` · `local_fh_context.md` · `deep-insight plugin` etc.) → check directly using table below.

| Check item | Criteria | Verification method |
|---|---|---|
| `.claudeignore` | Existence | `ls .claudeignore` |
| `local_fh_context.md` | Existence in `.claude/rules/` | `ls .claude/rules/local_fh_context.md` |
| `zshrc hook` | Contains `fh_audit_check.zsh` source line | `grep fh_audit_check.zsh ~/.zshrc` |
| `weekly_audit` latest | Within 7 days | CC_HUB_DIR/tracks/_audit/ mtime |
| `sentinel` setup | `~/.cc_sentinels/` exists | `ls ~/.cc_sentinels/` |
| FH plugin install | `installed_plugins.json` has `fh-meta` entry | `python3 -c "import json,os; d=json.load(open(os.path.expanduser('~/.claude/plugins/installed_plugins.json'))); print([k for k in d.get('plugins',{}) if 'fh-meta' in k])"` |
| `.git/info/exclude` | Personal files excluded | grep local_fh_context .git/info/exclude |
| MCP plugin | ~/.claude.json mcpServers contains entry | `python3 -c "import json,os; d=json.load(open(os.path.expanduser('~/.claude.json'))); print(list(d.get('mcpServers',{}).keys()))"` |
| `deep-insight plugin` | settings.json plugins contains deep-insight | `grep -r "deep-insight" .claude/settings.json 2>/dev/null` |
| `fh_env_context.jsonc` | `.claude/rules/fh_env_context.jsonc` exists | `ls .claude/rules/fh_env_context.jsonc` |
| `phantom-gate` | **(Python + AI-output projects only)** `phantom-gate` present in `requirements.txt` / `pyproject.toml` | `grep "phantom.gate" requirements.txt pyproject.toml 2>/dev/null` |
| `Streamlit pattern applied` | (Streamlit projects only, if the pattern pack is present) data_editor empty df branch/async wrapper/CSS numeric variables | CC `knowledge/shared/streamlit_patterns.md` Pattern 1-5 check (skip if file absent) |

**Score calculation**: PASS = 1 point / MISS = 0.5 points / FAIL = 0 points → converted to 100-point scale.

### Step 2. Diagnosis Report + Proposal List

Output diagnosis results and generate per-item proposals.

```
install-wizard — Diagnosis Results ({score}/100)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ PASS  .claudeignore exists
⚠️  MISS  local_fh_context.md absent
⚠️  MISS  zshrc hook absent
❌ FAIL  weekly_audit 12 days elapsed
✅ PASS  FH plugin installed
⚠️  MISS  MCP plugin absent
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 Proposal list (per-item approval required before execution):

  [1] Install local_fh_context.md — FH skill auto-recognition
  [2] Add zshrc hook — periodic audit notification on terminal start
  [3] Run weekly_audit immediately — call /harvest-loop (lightweight mode)
  [4] Initialize ~/.cc_sentinels/ — project audit tracking
  [5] Install fh-meta plugin — activate all FH skills (if FH plugin MISS)
      AI executes automatically via Bash — no manual terminal input needed:
        claude plugin marketplace add https://github.com/chrono-meta/forge-harness.git
        claude plugin install -s user fh-meta@forge-harness
      CC restart required after completion for skills to appear in /skills list
  [6] Add MCP plugin — activate integrations (if MCP plugin MISS)
      Run: claude mcp add <your-mcp-plugin> -- npx -y <your-mcp-plugin>
      CC restart required after completion
  [7] Install deep-insight plugin — activate sim-conductor multi-persona simulation (if deep-insight MISS)
      Settings → Plugins → Add → {deep-insight plugin path}
      Without install, /sim-conductor persona branching disabled (single-point simulation only)
  [8] Create fh_env_context.jsonc — org/network/Git environment context file (if fh_env_context.jsonc MISS)
      Copy: {FH_DIR}/templates/fh_env_context.jsonc → .claude/rules/fh_env_context.jsonc
      Then manually update with actual values for org name, Jira URL, environment status, etc.
      Effect: Each skill references common environment context → eliminate individual setting duplication
  [9] Install phantom-gate — AI output hallucination detection (Python + AI-output projects only, if MISS)
      Run: pip install git+https://github.com/chrono-meta/phantom-gate.git
      Usage: phantom-gate scan output.txt / phantom-gate scan . --project
      Detectors: M1 (phantom claims) · M2 (self-reference loops) · M3 (unvalidated external-dep claims) · M4 (temporal) · M5 (cross-file version mismatch)
      Skip condition: non-Python project OR no AI-generated output in pipeline


Each item: Y (approve) / N (skip) / L (later) / A (approve all)
```

#### cross-install Detection → agent-composer Auto-Update Proposal

When external plugins are cross-installed:
1. Collect trigger keyword list from installed skills
2. Check if those triggers exist in `agent-composer/SKILL.md` Step 1 mapping table
3. If missing triggers found → propose agent-composer update to user

Output format:
```
🔍 cross-install detected: {skill name} ({trigger keywords})
   → agent-composer mapping gap confirmed
   → auto-update proposal included in Step 3
```

If no gaps → output "agent-composer mapping up to date" then proceed to next step.

> **`--dry-run` branch point**: If `--dry-run` flag is set at this point, output message below and **exit** (skip Steps 3~4):
> ```
> install-wizard [dry-run] — Analysis complete ({score}/100)
> ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
> MISS/FAIL items: {N} — rerun /install-wizard to execute
> ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
> ```

### Step 3. User Approval → Per-item Execution

After receiving approval input, execute in order. **Output actual action preview before each execution**.

Execution example (local_fh_context.md install):
```
▶ [1] Install local_fh_context.md
  Copy: {FH_DIR}/templates/local_fh_context.md
    →   .claude/rules/local_fh_context.md
  Exclude: add pattern to .git/info/exclude
  Execute? (Y/N):
```

Execution priority:
1. FAIL items (immediate effect)
2. MISS items (configuration supplementation)
3. Optimization items (optional)

#### FH Plugin Auto-Install Execution Block

When FH plugin is MISS, execute the following via Bash (no manual input required):

```bash
# Step A: register marketplace (idempotent — "already on disk" is OK)
claude plugin marketplace add https://github.com/chrono-meta/forge-harness.git 2>&1

# Step B: install plugin
claude plugin install -s user fh-meta@forge-harness 2>&1
```

**Error handling:**

| Output | Meaning | Action |
|---|---|---|
| `✔ Marketplace ... already on disk` | Already registered | Continue to Step B |
| `✔ Successfully installed` | Done | Report success, remind CC restart |
| `Plugin "fh-meta" not found` | Marketplace cache stale | Run `claude plugin marketplace update forge-harness` then retry Step B |
| Any other error | Unknown failure | Report error verbatim, ask user to retry manually |

**Output format on success:**
```
▶ [5] Install fh-meta plugin
  ✅ Marketplace: forge-harness registered
  ✅ Plugin: fh-meta@forge-harness installed (scope: user)
  ⚠️  CC restart needed — skills will appear in /skills after restart
```

**agent-composer mapping update** (when skills were added via cross-install):

For skills with confirmed agent-composer mapping gaps from Step 2 cross-install detection,
propose adding rows to `agent-composer/SKILL.md` Step 1 mapping table in this format:

```
| {skill name} related task | {skill name} (S) | — |
```

Output preview before execution:
```
▶ agent-composer mapping update
  Add to: agent-composer/SKILL.md Step 1 table
    | {skill name} related task | {skill name} (S) | — |
  Execute? (Y/N):
```

### Step 4. Acceleration Baseline Setup

After executing approved items, install automatic maintenance structure:

```bash
# zshrc hook (if not installed — preview then confirm, idempotent)
if ! grep -q "fh_audit_check.zsh" ~/.zshrc 2>/dev/null; then
  cat >> ~/.zshrc << 'EOF'
export FH_DIR="{FH_DIR}"
export CC_HUB_DIR="{CC_HUB_DIR}"
export CC_SENTINELS_DIR="$HOME/.cc_sentinels"
source "$FH_DIR/templates/fh_audit_check.zsh"
EOF
fi

# 4-axis verification gate — install the FH pre-commit hook on the forge-harness clone (idempotent)
# Git does NOT set core.hooksPath automatically on clone, so this one-time step is required for the gate to enforce (otherwise it stays advisory).
if [ -d "$FH_DIR/templates/.git-hooks" ]; then
  git -C "$FH_DIR" config core.hooksPath templates/.git-hooks
  chmod +x "$FH_DIR/templates/.git-hooks/pre-commit" 2>/dev/null
  echo "4-axis pre-commit gate: installed (core.hooksPath -> templates/.git-hooks)"
fi

# sentinel initialization (per-project independent — prevent conflicts with other projects on same machine)
mkdir -p ~/.cc_sentinels
touch ~/.cc_sentinels/$(basename "$(pwd)")_wizard_done

# Weekly audit cadence — NO cron needed (a session-scoped scheduler cannot fire on a later day).
# Durable mechanism = the zshrc hook above (fh_audit_check.zsh warns on terminal start when 7+ days
# since last weekly_audit) + FH session-start detection (proposes /harvest-loop lightweight when overdue).
```

### Step 5. Completion Report + Contribution Guidance

```
install-wizard — Complete
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ✅ Executed: {N}  ⏭ Skipped: {N}  ⏳ Later: {N}

  From now on:
  · Periodic audit auto-check on terminal start
  · Yellow warning output when weekly_audit exceeds 7 days
  · /harvest-loop (lightweight) proposed at session start when 7+ days since last weekly_audit

  Next step skills:
  · Not sure which plugin you need → /plugin-recommender
  · Need complex task automation → /agent-composer
  · Quality audit before publishing external assets → hub-persona-auditor auto-run
    (select "external user entry point audit" task type when composing in agent-composer)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💡 If this setup helped, consider contributing to FH.
   Pattern discovered → return with /field-harvest
   New skill proposal → PR:
     https://github.com/chrono-meta/forge-harness

🔬 Developing FH itself? Set up a private companion store:
   gh repo create {org}/{hub}-be --private   # paper drafts, experiment logs, handoffs
   → public mirror holds methodology · private store holds research artifacts
   → field projects (internal harness) can use the same dual-repo pattern

🔀 Don't want to lose your accumulated assets — fork as your own hub:
   Personal skills/rules/notes added directly to FH may be lost on FH updates.
   git clone <FH_URL> ~/my-forge   # name is up to you (my-forge, team-forge, etc.)
   → Build freely in your fork and preserve permanently with git
   → When you discover valuable patterns, /field-harvest to reverse-contribute to FH anytime
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Re-run (Inspection Mode)

When run again in an environment that has already passed the wizard, operates in **inspection mode**:
- Only runs Step 1 gap diagnosis
- Proposes only newly found MISS/FAIL items
- No full reinstall

```bash
# Auto-switches to inspection mode when .cc_sentinels/{project-name}_wizard_done exists (per-project independent)
PROJECT_NAME=$(basename "$(pwd)")
ls ~/.cc_sentinels/${PROJECT_NAME}_wizard_done 2>/dev/null && echo "Inspection mode"
```

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

---
name: install-wizard-detail
description: Detail reference for install-wizard — Mode D companion setup, detection bash, report/proposal formats, execution blocks, baseline bash. Load when executing a specific step.
load: on-demand
---

# install-wizard — Detail Reference

> Load when executing a specific step. SKILL.md contains key terms, execution modes, core principles, the step overview, behavioral rules per step, environment adaptation, cluster loading, and Done When.

---

## §Mode-D-Companion-Setup

Guide companion-store setup before Step 1 when Mode D (FH developer/researcher) is detected:

```
You're developing FH itself — you need a private companion store
alongside the public mirror.

Recommended layout:
  public:  {org}/{hub}        (methodology, skills, rules)
  private: {org}/{hub}-be     (paper drafts, experiment logs,
                               raw signals, handoff files)

Quick setup (remote-backed):
  gh repo create {org}/{hub}-be --private
  git clone https://github.com/{org}/{hub}-be ~/path/to/{hub}-be
  mkdir -p {hub}-be/{paper-drafts,paper-signals,digests,handoff}

Local-only variant (no GitHub — your data never leaves the machine):
  git init ~/path/to/{hub}-be      # no remote needed
  mkdir -p ~/path/to/{hub}-be/{paper-drafts,paper-signals,digests,handoff}
  → the sync script detects the missing upstream and skips push
    automatically; local git history carries durability. Any store
    name works — set BE_DIR (and HUB_DIR) env vars to your paths.

Key rule: knowledge/shared/ drafts stay local via .gitignore glob.
Push snapshots to the companion store explicitly — never auto-push.
handoff/ files bridge cloud session → local without exposing content.
```

---

## §Token-Injection

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

## §Step0-Detection-Bash

Environment detection procedures that CC executes automatically. No need for users to run manually.

```bash
# Prompt injection pre-flight: scan config AND the project's AI-instruction surfaces — CLAUDE.md,
# AGENTS.md, .claude/rules/* — which are the higher-risk vectors in an unknown repo (not just shell/settings).
# Injection-SPECIFIC patterns only (override/exfil), since instruction files legitimately carry directives;
# advisory (recommend manual review), never an auto-block.
if grep -rIE "ignore (all )?previous|disregard (the )?above|exfiltrat|^# CLAUDE:|^# AI:|<instructions>" \
     ~/.zshrc .claude/settings.json CLAUDE.md AGENTS.md .claude/rules/ 2>/dev/null | grep -q .; then
  echo "⚠️  AI-instruction / override pattern detected in config or instruction files — injection risk in an unknown repo. Review the listed files manually before proceeding."; fi

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

# Framework detection (optional) — only used to look for a matching OPTIONAL domain pattern pack.
# Generic: capture the framework name; the pattern-pack path is derived as {framework}_patterns.md.
# No pattern pack ships by default — this is a user-supplied extension point, absence is the normal state.
FRAMEWORK=""
for fw in streamlit django fastapi flask; do
  if grep -qi "$fw" requirements.txt pyproject.toml 2>/dev/null; then FRAMEWORK="$fw"; echo "Framework: $fw detected"; break; fi
done
```

**Bootstrap guidance when FH_DIR is not set (stop immediately in Step 0):**
```
⚠️  FH_DIR not set — install FH first then rerun.

  1. Clone FH repo:
     git clone https://github.com/chrono-meta/forge-harness ~/forge-harness

  2. Set environment variables:
     export FH_DIR=~/forge-harness
     export CC_HUB_DIR=$FH_DIR   # FH hub dir (holds tracks/_audit for the weekly-audit mtime check);
                                 # equals FH_DIR unless you run a separate hub clone

  3. Install FH plugin in CC:
     Settings → Plugins → Add → {FH_DIR}/plugins/fh-meta

  4. Rerun /install-wizard after completion
```

---

## §Env-Card-Format

Output detection results as **environment card**. If a framework was detected AND you maintain a matching
optional domain pattern pack, reference it (none ship by default — absence is normal, never a gap):
```
📌 {FRAMEWORK} project detected → optional domain pattern pack check
   {CC_HUB_DIR}/knowledge/shared/{FRAMEWORK}_patterns.md loaded (only if you supplied it; not shipped by default)
   If absent: skip silently — no pack is the expected default state.
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

---

## §Step0C-Integration

**Illustrative single-run measurements** (n=1 per project, `--dry-run` verified — not benchmarks; your numbers will differ):

| Project type | Example | Total volume | Reduction | Main cause |
|---|---|---|---|---|
| QA strategy platform (domain-specialized complete) | Project A | 324 lines | **14%** (46 lines) | Duplicate meta operation rules |
| Mobile QA automation framework | Project B | 2,448 lines (constant) | **32%** (~790 lines) | 2 unremoved duplicate files post-install |

Token savings: Project A ~0.5K/session, Project B ~15~20K/session

* QA strategy platform level = CLAUDE.md 200~400 lines, 5~10 rules files. Mobile QA automation level = 7+ rule files, 2,000+ lines of constant context.
* Check your own project numbers directly with `/install-wizard --dry-run`. (These numbers are from actual single measurements and may vary by environment.)

**How to read**: FH does not touch domain-specific rules (code guides, domain knowledge).
Reduction targets are only meta operation rules (PR procedures, commit guides, FH path duplicates, etc.).

**Detection bash:**

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

---

## §Step1-Checks

Auto-check the following items based on detected environment. Each item classified as PASS / MISS / FAIL.

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
| `Domain pattern pack applied` | (optional — only when a `{framework}_patterns.md` pack is present; none ship by default) framework-specific pattern checks | `knowledge/shared/{framework}_patterns.md` check (skip if file absent — the normal default) |

---

## §Step2-Formats

**Diagnosis report + proposal list:**

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
  [7] (Optional — field plugin, NOT required) Install deep-insight — adds the field's domain personas to sim-conductor
      deep-insight is a private/field marketplace plugin. sim-conductor already ships the built-in
      user-mastery spectrum (beginner · main-player · expert · challenger), so multi-persona simulation
      works WITHOUT it. If you have access: Settings → Plugins → Add → <your deep-insight path>.
      If not: skip — sim-conductor falls back to the built-in spectrum agents (no capability lost).
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

**cross-install detection output format:**
```
🔍 cross-install detected: {skill name} ({trigger keywords})
   → agent-composer mapping gap confirmed
   → auto-update proposal included in Step 3
```

**`--dry-run` exit message:**
```
install-wizard [dry-run] — Analysis complete ({score}/100)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
MISS/FAIL items: {N} — rerun /install-wizard to execute
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## §Step3-Execution

**Action preview example (local_fh_context.md install):**
```
▶ [1] Install local_fh_context.md
  Copy: {FH_DIR}/templates/local_fh_context.md
    →   .claude/rules/local_fh_context.md
  Exclude: add pattern to .git/info/exclude
  Execute? (Y/N):
```

**FH plugin auto-install execution block** — when FH plugin is MISS, execute via Bash (no manual input required):

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

---

## §Step4-Baseline-Bash

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

# 4-axis verification gate (Mode D / FH-self-development only — OPT-IN, double-confirm required)
# SCOPE (state this before asking): this gates commits IN YOUR FH CLONE ($FH_DIR) — git commit there is
#   blocked until the 4-axis markers pass. It is FH-internal infra (hardcodes hub paths/markers) and is
#   NEVER installed into field projects (see auto_project_mapping.md §6). Skip unless you develop FH itself.
# Per Core Principles (Per-item approval + Double-confirm irreversible changes): this is NOT auto-run —
#   it is a separate explicit Y/N, not folded into the baseline-setup batch.
if [ -d "$FH_DIR/templates/.git-hooks" ]; then
  echo "Enable the 4-axis pre-commit gate on your FH clone ($FH_DIR)? It will block commits there until"
  echo "markers pass (Mode D / FH-development only). Skip if you are not developing FH itself. (Y/N)"
  # → On explicit Y only:
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

---

## §Step5-Completion-Report

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
   (or local-only: git init ~/path/{hub}-be — no remote; push is auto-skipped)
   → public mirror holds methodology · private store holds research artifacts
   → field projects (internal harness) can use the same dual-repo pattern

🔀 Don't want to lose your accumulated assets — fork as your own hub:
   Personal skills/rules/notes added directly to FH may be lost on FH updates.
   git clone <FH_URL> ~/my-forge   # name is up to you (my-forge, team-forge, etc.)
   → Build freely in your fork and preserve permanently with git
   → When you discover valuable patterns, /field-harvest to reverse-contribute to FH anytime
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

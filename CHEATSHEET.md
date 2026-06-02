# forge-harness User Cheatsheet

Frequently used commands and phrases.

> **`<harness-root>`** = the path where you cloned this repo. Example: `~/projects/forge-harness`. Replace `<harness-root>` in the commands below with your actual path.

---

## 1. Memory check

```bash
# Local memory (currently active)
ls ~/.claude/projects/*/memory/

# Persistent memory (full history)
# <harness-root> replacement example: ls ~/projects/forge-harness/tracks/
ls <harness-root>/tracks/

# Find past sessions
ls <harness-root>/tracks/*/session_*.md
```

---

## 2. Domain knowledge

```bash
# Domain list
ls <harness-root>/knowledge/domain/

# Add new domain
mkdir -p <harness-root>/knowledge/domain/<domain-name>/{tc,knowledge}
```

---

## 3. Symbolic Link setup

```bash
# Project → domain knowledge
ln -s <harness-root>/knowledge/domain/<domain>/ <project>/docs/domain/<domain>

# New project → copy skeleton
cp -r <harness-root>/templates/.claude/ <project>/.claude/
cp <harness-root>/templates/CLAUDE.md <project>/CLAUDE.md
```

---

## 4. Common Claude Code phrases

### Universal (any project)
| What you want | What to say to Claude |
|-------------|---------------------|
| Start session (greeting) | "hi" → auto-reads CATALOG.md and guides today's work |
| Start session (fallback) | "read root memory" → reliable trigger when greeting doesn't work |
| Check past session | "read the 04-12 session from forge-harness" |
| Clean memory | "clean up local memory" |
| Save session | "save the current session" |
| Evaluate structure | "how do you evaluate this structure from an AI perspective" |
| Check duplicates | "check for duplicate or meaningless data" |

---

## 5. Session Sync

| What you want | What to say to Claude |
|-------------|---------------------|
| Persist session record | "sync this session to forge-harness" |
| Clean local memory + sync | "clean local and sync forge-harness" |
| Check sync status | "check forge-harness sync status" |
| Search past work | "what did I do on 04-13?" (searches CATALOG.md) |

### Manual check
```bash
# Fast past work search via CATALOG.md
cat <harness-root>/CATALOG.md

# Check latest session per track
ls -1t <harness-root>/tracks/*/session_*.md | head -5
```

---

## 6. Git

```bash
cd ~/projects/forge-harness
git add -A && git commit -m "message"
```

### 4-Axis Gate (one-time setup per clone)

```bash
# Activate the pre-commit hook — run once after cloning
git config core.hooksPath templates/.git-hooks
chmod +x templates/.git-hooks/pre-commit
```

After running `/steel-quench` and `/source-grounding-audit` in your session, Claude creates the Axes 2+3 pass marker automatically. If it doesn't (e.g., session interrupted), create it manually:

```bash
touch "tracks/_meta/.axes_23_passed_$(git rev-parse --abbrev-ref HEAD | tr '/' '_')_$(date +%Y-%m-%d).marker"
```

---

## 7. Weekly improvement cycle

The hub audits and improves itself weekly through `/harvest-loop` (the unified session-wrap + pattern-harvest pipeline).

| What you want | What to say to Claude |
|-------------|---------------------|
| Run session wrap + weekly harvest | `/harvest-loop` or "wrap up this week" → pattern scan + 3-tier improvement proposals + PR draft |
| Meta-simulation audit | `/sim-conductor B` → internal 3-persona audit + M/S/R backlog auto-generation (Area B weekly recommended) |
| Check status | "when was the last harvest?" |
| Apply improvements | "apply only 🟥 mandatory items now" |

**L1 auto-detection:** When hub cwd session starts, Claude auto-checks recent harvest file mtime → proposes `/harvest-loop` if 7+ days elapsed.

---

## 8. Sub-agent operations (optional · pilot phase)

Define custom sub-agents with Claude Code standard `.claude/agents/*.md`.

```bash
# Hub sub-agents list
ls <harness-root>/.claude/agents/

# Project sub-agents list (be careful with shared repos)
ls <project>/.claude/agents/

# Keep personal agents local-only in shared repos
echo '.claude/agents/' >> <project>/.git/info/exclude
```

### Mode D — Copy only agent files (minimal entry without plugin install)

```bash
# Copy only the agents you need to your project
cp <harness-root>/.claude/agents/fact-checker.md <my-project>/.claude/agents/
```

Copy just 1 agent without plugin install and it's immediately callable. Updates require manual re-copy.

| What you want | What to say to Claude |
|-------------|---------------------|
| Audit external reader asset | "run persona audit" → calls `hub-persona-auditor` |
| Code review | "review this diff" → calls project `code-reviewer` |
| Naming gap detection + ideation | `/persona-innovator` or "find naming candidates" → 6-type classification + external signal scan |
| Meta-simulation run | `/sim-conductor` (Area C default) · `/sim-conductor B` (internal audit) · `/sim-conductor A` (external user perspective) |

**Promotion gate (after 2+ week pilot):** accepted ≥ 60% → maintain · rejected ≥ 40% → deprecate.

---

## 9. Plugin management

| What you want | What to say to Claude |
|-------------|---------------------|
| Plugin recommendation | "what plugins do you recommend", "find a plugin for Jira ticket handling" |

```bash
# [Terminal] Update fh-meta (manual run required when new skills are added)
claude plugin update fh-meta@forge-harness

# [Terminal] Check installed plugin list
claude plugin list
```

> Plugins are not auto-updated. When you receive notification of skills/agents added to FH, update with the command above.

---

## 10. Token efficiency best practices (AI collaboration guide)

4 levers to reduce context cost. Combine for amplified effect.

### Lever 1 — `.claudeignore` (token reduction)

Exclude unnecessary files from context. Create in project root.

```bash
# Basic recommended patterns
node_modules/
.git/
dist/
build/
*.log
*.lock
coverage/
__pycache__/
.venv/
```

> Tell Claude: `"apply standard .claudeignore"` → auto-generate proposal.

### Lever 2 — `/clear` (context reset)

Use when conversation has grown long and past context becomes noise. Clears context only without ending session.

```
/clear   ← context reset (session and file state maintained)
```

**When to use**: When direction has changed / when switching to a different track / when too much was accidentally read.

### Lever 3 — Model switching

| Situation | Recommended model | Command |
|---|---|---|
| Complex design/reasoning | Opus | `/model opus` |
| Code writing/editing | Sonnet (default) | `/model sonnet` |
| Fast simple tasks | Haiku | `/model haiku` |

> Using Opus continuously for the same task multiplies token cost 3–5x. Switching down strategically is a strategy.

### Lever 4 — Keyword trigger load (Context Isolate)

Only read necessary documents at the necessary time. MEMORY.md keyword trigger method.

```
✅ Only read CATALOG.md first at session start
✅ Delayed load of related files only when keyword is spoken
❌ Do not pre-load all knowledge files at session start
```

> Tier context as L1 always-on (~2–5K, CLAUDE.md core rules) · L2 session (~5–20K, active track) · L3 on-demand (`knowledge/` docs), and keep critical info at the **start and end** of a document, never the middle — mid-context info loses ~10–30% accuracy ("lost in the middle"). See `knowledge/shared/harness-core/harness_frontier_diagnosis_2026-06-02.md`.

### Combined effect measurement examples

| Before | After | Savings |
|---|---|---|
| No `.claudeignore` + Opus fixed | `.claudeignore` + model switching | Token/cost reduction (varies by environment) |
| Not using `/clear` even when session grows long | Habit of `/clear` when direction changes | Noise removal → accuracy improvement |

> **Core principle**: Everything loaded into context has a cost. Block it from the start if it doesn't need to be read.

### Lever 5 — `/goal` (session goal locking) — Claude Code v2.1.139+

Set a goal at session start and a separate **condition evaluation LLM** monitors Claude's text output in real-time and judges whether conditions are met.

```
/goal <condition>
```

#### Key to writing conditions: write as observable state

| Pattern | Example | Evaluation method |
|---|---|---|
| **Test result** | `86 tests green` | pytest output itself is the signal |
| **Quantity criterion** | `generate 20+ test cases` | Explicit number declaration |
| **Variable state** | `bin_b_output not None` | Observable from output |
| **Task completion declaration** | `implementation complete` | Claude's declaration sentence is the signal |

> **How it works**: The condition evaluation LLM reads Claude's **text output**. So Claude explicitly declaring a result matching the condition is itself the achievement signal. Even vague conditions can be satisfied by "wrote it" declaration — but more measurable conditions provide more accurate gating effects.

```
Example: /goal implementation complete + 86 tests green + /goal function verified working
Example: /goal 20+ test cases + all cases include verification link
Example: /goal weekly audit complete — pattern scan → through PR
```

**When to use**: Prevent mid-session drift in multi-step work / test/TC quantity gating / when you want to clearly define session completion conditions.

> `/goal` operates independently from CLAUDE.md. Suitable for per-session temporary goals.

---

## 11. New technology introduction pipeline

Standard 3-step path for actually integrating new features, tools, and frameworks into FH.

```
Proposal → Simulation → Optimization
```

### Step 1. Proposal (detection)

Catch signals of new technology.

| Signal source | Tool |
|---|---|
| Claude Code new features (release notes) | `/frontier-digest` |
| Patterns discovered in field projects | `/field-harvest` |
| User direct utterance ("should we try this?") | Immediately to Step 2 |

→ Output: gap analysis of whether FH integration is possible + candidate list

### Step 2. Simulation

Explore integration possibility in advance without experimentation.

```
/sim-conductor Area C    # Ideation scan — idea × FH applicability
/sim-conductor Area A    # External user perspective — perspective of people who would actually use it
```

→ Output: Concrete proposal of how to attach it to which FH asset (SKILL.md / CHEATSHEET / agents)

### Step 3. Optimization (apply)

Actual integration after simulation approval.

| Output type | Application location |
|---|---|
| New command/feature guidance | `CHEATSHEET.md` corresponding section |
| Extend existing skill | Corresponding `SKILL.md` step addition |
| New workflow pattern | New skill candidate (if simplification guard passed) |
| Agent integration | `.claude/agents/` or plugin agents/ |

→ commit + push + CATALOG.md Decision record

### Application examples

```
/goal feature
  Proposal: after project experiment, propose introduction
  Simulation: measured in project session
  Optimization: CHEATSHEET Lever 5 updated ✅

Claude agents feature
  Proposal: insight received about parallel management
  Simulation: /sim-conductor Area C ← here now
  Optimization: TBD
```

| What to say to Claude | Action |
|---|---|
| "simulate how to use this in FH" | Immediately enter Step 2 |
| "scan CC new features" | Step 1 (`--cc-scan`) → Step 2 auto-proposal |
| "apply simulation results" | Immediately enter Step 3 |

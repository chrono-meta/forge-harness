---
name: goal-quench
description: >-
  Wraps /goal with a tiered safety + orchestration ladder. core (default): a token budget gate (pre-run estimate), mid-run budget thresholds, and an automatic post-run quality verification via pipeline-conductor — closing /goal's two gaps (Haiku evaluates completion, pipeline-conductor evaluates correctness). pro: adds context-doctor token reduction and agent-composer goal decomposition. max: adds plugin-recommender capability-gap fill and cross-ecosystem-synergy-detection pre-validation. The Phase-1 budget verdict auto-recommends the mode. Triggered by "goal with quality gate", "safe goal", "goal-quench", "orchestrate this goal", or before running /goal on high-stakes tasks.
user-invocable: true
allowed-tools: ["Read", "Write", "Bash", "Grep"]
model: sonnet
complexity_routing:
  base: sonnet
  escalate_when:
    - pro_mode       # orchestration: context-doctor + agent-composer decomposition
    - max_mode       # + external discovery: plugin-recommender + synergy pre-validation
  high: opus
  # NOTE: CC switches models per-turn by task weight, not per-skill invocation.
  # With `/model opusplan`: Opus activates on plan-mode turns (reasoning, decomposition);
  # Sonnet handles execution turns (tool calls, edits). Both appear in session jsonl.
  # Without opusplan: all turns use the session model regardless of mode.
---

# goal-quench — /goal with Token Budget + Quality Gate

`/goal` runs until Haiku says "done" — but Haiku only checks completion, not quality. Without a budget ceiling, sessions can exhaust tokens silently. goal-quench adds three things that /goal currently lacks:

1. **Pre-run**: token-budget-gate estimate — know the cost before committing
2. **Mid-run**: budget threshold awareness — signal before exhaustion (instructional; not mechanically enforced)
3. **Post-run**: pipeline-conductor — verify quality before accepting "done"

The evaluator principle: Haiku judges completion (every turn, cheap). pipeline-conductor judges quality (once at the end, structured). Separating the two closes the self-evaluation bias that a single evaluator cannot avoid.

> **Scope by mode**: core = budget gate + stop-hook verification (v1 behavior, unchanged). pro/max add token reduction, goal decomposition, and external discovery (see Modes below). (Tier names mirror Claude Code's subscription units — core / pro / max — and avoid colliding with pipeline-conductor's `--full` flag.) Mid-run Sonnet quality signals remain deferred (requires empirical calibration).

---

## Modes — core → pro → max (fluid)

goal-quench is a ladder, not a fixed shape. The tier names mirror Claude Code's subscription units (core / pro / max). The default (**core**) is the narrow safety belt — for users who only want /goal's two structural gaps closed. **pro** and **max** add optimization and orchestration on top, and are **auto-recommended by the Phase-1 budget verdict** so the orchestration cost is only paid when the task is large enough to justify it.

| Mode | Adds over previous | Chained skills | Auto-recommended when |
|---|---|---|---|
| **core** (default) | budget gate + mid-run thresholds + post-run quality gate | token-budget-gate, pipeline-conductor --quick | budget GREEN / YELLOW |
| **pro** | token-reduction pre-pass + goal decomposition into Waves | + context-doctor, agent-composer | budget ORANGE |
| **max** | capability-gap fill + synergy pre-validation before the run | + plugin-recommender, cross-ecosystem-synergy-detection | budget RED |

Each mode is a **superset** of the one before it — pro does everything core does, plus more. Nothing in core is removed by escalating.

**Selection**:
- Explicit flag: `/goal-quench --core` (default) · `--pro` · `--max`
- Auto: Phase 1's budget verdict proposes the mode (see Phase 1 Step 2). The user can always override **down** to core.

**Token-honesty guard** (what empirical calibration showed): The cost structure of pro/max depends on which sidecar pattern is in use:

| Sidecar type | Who uses it | Cost visibility | Estimation |
|---|---|---|---|
| External CLI (Gemini, Codex, Copilot) | Multi-LLM environment | **Not visible in CC** | Low — external billing only |
| CC sub-agent (isolated context, steel-quench pattern) | CC-only environment | **Visible in CC** | Estimable: Sonnet × sub-agent scope |

For **CC-only users**, pro/max sidecars run as isolated sub-agents (Sonnet for execution), with the orchestrator running at Opus (`complexity_routing`). Both are CC-visible. Cost estimate: `(Opus orchestrator turns × ~3×) + (Sonnet sub-agent tokens)`. The sub-agent context isolation means sidecar work does not load the main context — the context-preservation property holds regardless of sidecar type.

Therefore:
- **Never auto-escalate a GREEN/YELLOW task to pro/max.** For external CLI users, sidecar costs are untracked and invisible in CC's budget display. For CC sub-agent users, the overhead is estimable but still real — orchestrator Opus × 3 applies. Note the appropriate caveat when disclosing cost.
- **Model escalation cost**: With `/model opusplan`, Opus activates on plan-mode turns (reasoning, decomposition decisions) and Sonnet handles execution turns — both CC-visible in session jsonl under `message.model`. External CLI sidecar fees are additional and invisible to CC; state both when present.
- **RED is no longer a dead-end.** v1 hard-blocked RED ("split manually"). v2 turns RED into the **on-ramp to max** — agent-composer decomposes the over-budget goal into sequential sub-goals automatically.

---

## Triggers

- `/goal-quench`
- "run /goal with a quality gate", "safe goal run", "goal with verification"
- "I want to use /goal but worried about tokens", "goal with budget control"
- "goal-quench", before any long /goal session
- `/goal-quench --pro`, `/goal-quench --max`, "orchestrate this goal", "decompose this goal", "optimize then run this goal"
- "this goal is too big for one run", "find a tool for this goal if FH lacks one" (→ max mode)
- Automatically proposed when user mentions `/goal` on tasks estimated > 15K tokens
- Mode is auto-recommended by the Phase-1 budget verdict (GREEN/YELLOW → core, ORANGE → pro, RED → max)

---

## One-Time Setup (required)

### Claude Code Runtime

Copy the hook snippet from `templates/goal-quench-hook-setup.md` and merge into your `.claude/settings.json`.

Add to `.gitignore`:
```
.claude/goal-quench.active
.claude/goal-quench.pending
```

**Hook failure fallback**: The Stop hook may fire silently without triggering verification (hook failure, session reset, or CC version differences). If Phase 3 verification has not run after /goal completes, manually trigger it:
> `/goal-quench --verify` — skips Phase 1+2, runs pipeline-conductor --quick using current session scope.

**Interrupted /goal recovery**: If /goal is interrupted (error, user abort, CC crash), the Stop hook may not fire — leaving `.claude/goal-quench.active` without a `.pending`. Detect and recover:
```bash
[ -f .claude/goal-quench.active ] && ! [ -f .claude/goal-quench.pending ] && echo "Interrupted — run /goal-quench --recover"
```
> `/goal-quench --recover` — promotes `.active` → `.pending` and runs Phase 3 verification on partially-completed work.

### Codex Runtime

Codex has its own goal/session capability. Do not replace it with goal-quench state files. In Codex-primary sessions:

1. Use Codex's native goal/session feature for goal control.
2. Use `fh-run` for any FH skill/agent sub-step that would otherwise require Claude Code `Agent(...)`.
3. After the Codex goal completes, run FH governance on changed files:

```bash
FH_BACKEND=codex npx @chrono-meta/fh-gate "{changed-files}" quick codex-goal
```

For non-interactive one-shot runs only, `fh-goal` can run a backend task and then invoke `fh-gate` automatically:

```bash
FH_BACKEND=codex npx --package @chrono-meta/fh-gate fh-goal \
  --prompt "{task}" \
  --gate quick
```

`fh-goal` is not a Codex goal replacement; it is a post-run governance wrapper.

---

## Phase 1 — Pre-run Gate

### Step 1. Collect task description

Ask:
> "What will you run with /goal? Describe the task and expected scope."

Collect: task description, target files or directories, expected output.

**Pre-flight check (pro/max mode only)**: before proposing pro/max, verify required chained skills are available:
```bash
for skill in context-doctor agent-composer; do
  [ -f ".claude/plugins/cache/forge-harness/fh-meta/"*"/skills/${skill}/SKILL.md" ] 2>/dev/null \
  || find ~/.claude/plugins -name "${skill}" -type d 2>/dev/null | grep -q . \
  || echo "WARNING: ${skill} not found — pro/max mode requires it. Falling back to core."
done
```
If any required skill is missing, **fall back to core and warn**: "Pro/max mode requires `{skill}` — not installed. Running in core mode instead."

### Step 2. token-budget-gate estimate

**Invocation contract**:
```
Input:  task description (one paragraph), target file count (approximate)
Trigger phrase: "estimate token budget for: {task description}"
Expected output fields:
  - estimated_tokens: N
  - verdict: GREEN | YELLOW | ORANGE | RED
  - reasoning: one-line basis for estimate
```

If `token-budget-gate` skill is not installed, use this fallback estimator:
```
< 5 files changed, no new architecture  → GREEN  (< 10K)
5–20 files or new module/feature        → YELLOW (10K–30K)
20+ files or cross-system refactor      → ORANGE (30K–60K)
Full-project migration or rewrite       → RED    (> 60K)
```
**Session overhead factor (empirical calibration, N=10, 2026-06-01–06-03)**: The tiers above estimate *task* tokens only. Actual full CC session tokens average 4.7× the task estimate (range: 1.3×–10.5×) for harness-heavy projects (dense CLAUDE.md + multi-rule auto-load). Multiply task estimate by 4× for FH-density projects (rough inference only — not measured for non-FH projects), to get expected session total. This multiplier informs the mode recommendation — it does not change the go/no-go gate thresholds.

Note the fallback in `.active` as `budget_source: fallback-heuristic` instead of `budget_source: token-budget-gate`.

Run token-budget-gate against the task description. Map the result to a go/no-go decision:

| token-budget-gate verdict | goal-quench action |
|---|---|
| GREEN (< 10K) | Proceed without comment |
| YELLOW (10K–30K) | Proceed — note estimated cost, suggest /goal scope if possible |
| ORANGE (30K–60K) | Propose **pro mode** as the cheaper path: "This is expensive. Run as a single /goal, or let pro mode optimize (context-doctor) + decompose (agent-composer) it?" Proceed in core only if the user declines orchestration. |
| RED (> 60K) | Propose **max mode** instead of a hard block: "Too big for one /goal run. Route through max mode — agent-composer decomposes into sequential sub-goals, plugin-recommender fills any capability gaps." Hard-block only if the user declines orchestration. |

On RED, the user has two paths:
- **Accept max mode** (recommended) → goal-quench enters Phase 1.5 and lets agent-composer decompose the over-budget goal into sequential sub-goals, each small enough to run under its own budget. This is the v2 recovery path that replaces v1's dead-end.
- **Decline orchestration** → goal-quench halts and does not write `.active` or inject thresholds. The user may still run `/goal` manually — but goal-quench will not gate or verify a session started without its active file.

### Step 3. Write state file

Create `.claude/goal-quench.active`:

```
scope: {task description — one line}
mode: core | pro | max
target_files: {comma-separated file paths or directory; "inferred from git diff" if not known}
budget_estimate: {N} tokens
budget_source: token-budget-gate | fallback-heuristic
budget_verdict: {GREEN/YELLOW/ORANGE/RED}
pipeline_mode: {--quick for core/pro · --full for max}
composed_plan: {sub-goal list from Phase 1.5 agent-composer; "n/a" in core mode}
timestamp: {YYYY-MM-DD HH:MM}
session_pid: {$$}
start_commit: {git rev-parse HEAD}
```

`target_files` is the **verification artifact** — what pipeline-conductor --quick will evaluate in Phase 3. Specify files/directories explicitly if known; otherwise write `"inferred from git diff"` and Phase 3 will resolve using `git diff {start_commit}..HEAD` to capture all changes including interim commits made during the /goal session.

> **Control flow (core vs pro/max)**: in **core** mode, proceed directly Step 3 → Step 4. In **pro/max** mode, run **Phase 1.5 (orchestration) here — after Step 3, before Step 4** — then return to Step 4 to inject thresholds and hand off. The `composed_plan` field in `.active` stays `n/a` until Phase 1.5 fills it.

### Step 4. Inject mid-run budget thresholds

Before the user runs /goal, output the following instruction block so Claude carries it into the /goal session:

```
─── goal-quench budget thresholds (active for this /goal run) ───
50% of estimated budget consumed:
  → Output a one-line progress summary. No action required.

70% consumed:
  → YELLOW: re-prioritize remaining tasks. Drop lowest-priority items
    if the goal can still be met without them.

85% consumed:
  → ORANGE: stop current task, commit completed work, surface to user:
    "Budget at 85%. Completed: [X]. Remaining: [Y]. Continue / stop?"

95% consumed:
  → RED: stop immediately. Commit everything completed so far.
    Output: "Budget exhausted. Completed tasks: [list]. Incomplete: [list]."
─────────────────────────────────────────────────────────────────
```

### Step 5. Hand off to /goal

Output:
> "goal-quench ready. Budget: {verdict} (~{N} tokens). Now run: `/goal {your condition}`
> When /goal finishes, the Stop hook will trigger pipeline-conductor --quick automatically."

---

## Phase 1.5 — Pro / Max Orchestration Layer

> Runs only in `--pro` or `--max` mode (auto-proposed on ORANGE/RED budget, or user-selected). **Skipped entirely in core mode** — core hands off straight to /goal after Step 5.

The ordering is deliberate: optimize the context first (cheapest win), then decompose, then — only if a capability gap remains — reach outside FH.

### Step A — context-doctor (token-reduction pre-pass) · pro + max

Invoke context-doctor on the target scope before /goal runs. It generates/updates `.claudeignore`, flags over-read files, and recommends `/clear` timing. This lowers the per-turn token floor /goal will consume — actual reduction, not just the estimate the budget gate produced.

**Re-estimate** the budget after the pre-pass. If the verdict drops (e.g., ORANGE → YELLOW), offer to step back down to core: "Context trimmed; estimate is now YELLOW. Continue in pro, or drop to core?" (See Simplification Guards — post-optimization step-down.)

### Step B — agent-composer (goal decomposition) · pro + max

Hand the task description to agent-composer in compose-only mode. It returns a Wave plan: the goal split into independent/sequential sub-tasks with capability-fit scoring (agent-composer Step 0.2). For RED-origin runs this decomposition is the recovery path v1 lacked — each sub-goal is small enough to run under its own budget.

**Sub-goal execution (user-driven, not automatic)**: `/goal` is a user-invoked command — goal-quench cannot programmatically drive a loop over sub-goals. After agent-composer produces the Wave plan, goal-quench writes it to `.claude/goal-quench.queue` and outputs:

> "Sub-goal plan ready. Run each sub-goal in order by invoking `/goal-quench` again with the next sub-goal description. goal-quench will gate each sub-goal independently."

Sub-goal queue format (`.claude/goal-quench.queue`):
```
remaining:
  - sub-goal-1: {description}
  - sub-goal-2: {description}
completed: []
```

Each `/goal-quench` invocation pops the first `remaining` item, runs it as a core-mode run (Phase 1 GREEN/YELLOW expected → /goal → Phase 3 verify → commit), then moves it to `completed`. The outer pro/max run owns the decomposition; each inner invocation owns its sub-goal's gate. When `remaining` is empty, delete `.claude/goal-quench.queue`. (Parallel sub-goal execution is deferred — sequential is the v2 contract.)

goal-quench does **not** re-implement agent-composer's gates — its destructive-action gate (Step 2.7) and per-wave fan-out cap apply as-is.

### Step C — plugin-recommender + synergy pre-validation · max only

Triggered only when agent-composer Step 0.2 reports a capability **GAP** (`fit_score < 0.5` on a required-weight sub-task):
1. `plugin-recommender` searches FH + Codex + Claude Code marketplaces for a fitting skill/agent.
2. For each candidate, `cross-ecosystem-synergy-detection` pre-validates fit + overlap **before anything is installed**.
3. User decides: install / skip / general-purpose fallback (agent-composer's degraded-composition rule applies — `⚠️ degraded: [role]`).

max mode never installs anything silently — discovery and synergy-check are surfaced for approval first.

### Step D — scope-driven sidecar configuration · pro + max

Runs after Step C (or after Step B if no capability gap). Selects an adversarial sidecar based on the task's quality-risk profile — distinct from Step C's capability-gap sidecar, which addresses missing tools. Step D's sidecar addresses **blind-spot risk**: the generator and reviewer sharing the same reasoning distribution.

> **Availability resolution**: "Gemini sidecar if available" / "if external CLIs available" below is decided by the canonical Tier 1→2→3 recipe in `knowledge/shared/harness-core/multi_model_sidecar_strategy.md §Sidecar Engine Resolution Protocol` — discovery is automatic, invocation stays value-gated. Tier 3 (Claude sub-agent) guarantees this step never hard-fails even with zero external CLIs/keys.

**Scope → sidecar routing table**:

| Task scope signal | Sidecar | Invocation point |
|---|---|---|
| Code quality review / new SKILL.md / governance gate change | `steel-quench` C3 config (Gemini sidecar if available) | Post-/goal, before pipeline-conductor |
| Architecture design / cross-project dependency | `agent-composer` multi-model panel (if external CLIs available; otherwise single-Claude sub-agent) | Parallel to /goal as separate Agent |
| External publication / marketplace-gate / skill release | `sim-conductor` + `steel-quench` Wave 5 | Post-/goal quality gate |
| No signal match (default) | None — pipeline-conductor handles quality alone | — |

Write resolved sidecar to `.active`:
```
sidecar: none | steel-quench-c3 | agent-composer-panel | sim-conductor | {cli-name}
sidecar_rationale: {one-line reason — which scope signal triggered this}
```

Output to user (one line only):
> "Sidecar: {config} — {rationale}"

Do not ask for confirmation. The user may override by re-running `/goal-quench --sidecar none`.

### Hand-off

After orchestration, **update** (not re-create) `.claude/goal-quench.active` — add `mode:` and `composed_plan:` lines alongside existing budget fields. Re-creating the file loses the `start_commit` field written in Phase 1 Step 3. Then proceed to threshold injection (Phase 1 Step 4) and hand off to /goal. Phase 3 verification then runs as in core — `pipeline-conductor --quick` for pro, `--full` for max (max implies external-facing stakes).

---

## Phase 2 — Mid-run (during /goal execution)

goal-quench does not directly control /goal execution. The budget thresholds injected in Phase 1 are instructions Claude follows during the /goal session.

**What Claude should do mid-run**:

- Track approximate token consumption against the Phase 1 estimate
- At each threshold (50/70/85/95%), execute the corresponding action
- Do not wait for goal-quench to intervene — the thresholds are self-enforced

**Threshold enforcement caveat**: Claude cannot reliably read its own real-time token consumption during a /goal session. The 50/70/85/95% thresholds are instructional — Claude approximates consumption based on task complexity and turn count. They are not mechanically enforced. For hard enforcement, see the Anthropic feature request (--budget flag).

**Queue mode (per-sub-goal threshold scope)**: When running sequential sub-goals from `.claude/goal-quench.queue`, each `/goal-quench` invocation is an independent core-mode run — thresholds are re-injected fresh for each sub-goal's Phase 1 estimate, not inherited from the outer pro/max run. The outer run owns the decomposition plan; each inner invocation owns its sub-goal's budget gate. Concretely: if sub-goal-1 estimate is 12K (YELLOW), thresholds are set against 12K — not against the outer RED estimate that triggered the queue in the first place.

**What goal-quench cannot do in v1** (requires native Anthropic support):
- Hard-enforce token ceiling mid-run (--budget flag, not yet available)
- Auto-checkpoint commit on sub-goal completion (--checkpoint flag, not yet available)
- Mid-run Sonnet quality signal (requires structured evaluator hooks)

These gaps are the basis for the Anthropic feature request (see `knowledge/shared/harness-core/goal_quench_anthropic_issue.md`).

---

## Phase 3 — Post-run Verification

### Claude Code path

When /goal stops, the Stop hook fires and:
1. Detects `.claude/goal-quench.active`
2. Copies it to `.claude/goal-quench.pending`
3. Removes `.active`
4. Prints: "[goal-quench] /goal finished. Verification pending — starting pipeline-conductor --quick."

On the next Claude response (after /goal), check for `.claude/goal-quench.pending` **with a freshness guard** — only act if the timestamp in the file is within the current session (< 4 hours old):

```bash
if [ -f .claude/goal-quench.pending ]; then
  PENDING_TIME=$(grep "^timestamp:" .claude/goal-quench.pending | sed 's/^timestamp: //')
  NOW=$(date +%s)
  PENDING_EPOCH=$(date -d "$PENDING_TIME" +%s 2>/dev/null || date -j -f "%Y-%m-%d %H:%M" "$PENDING_TIME" +%s 2>/dev/null)
  AGE_HOURS=$(( (NOW - PENDING_EPOCH) / 3600 ))
  if [ "$AGE_HOURS" -lt 4 ]; then
    echo "goal-quench verification pending (created: $PENDING_TIME — ${AGE_HOURS}h ago)"
  else
    echo "STALE: goal-quench.pending is ${AGE_HOURS}h old. Run /goal-quench --verify to re-evaluate or delete to clear."
    exit 0
  fi
fi
```

If found and fresh: **automatically run pipeline-conductor** before responding to any other request — `--quick` for core/pro, `--full` for max (the `mode:` field in `.pending` selects which). This is not optional — pending verification takes priority.

If found but stale (> 4 hours): warn the user — "A stale goal-quench.pending exists from {timestamp}. Run `/goal-quench --verify` to re-evaluate, or delete it to clear." Do not auto-trigger verification on stale state.

### Codex path

No Stop hook is required. After the Codex goal/session completes, resolve changed files with git and run:

```bash
FH_BACKEND=codex npx @chrono-meta/fh-gate "{changed-files}" quick codex-goal
```

For high-stakes or external-facing work, use `full` instead of `quick`. Treat `BLOCKED` or `ESCALATE` the same as the Claude path: fix and re-run the gate, or surface the decision to the user.

### Verification flow

```bash
# Read scope and target from pending file
SCOPE=$(grep "^scope:" .claude/goal-quench.pending | sed 's/^scope: //')
TARGET=$(grep "^target_files:" .claude/goal-quench.pending | sed 's/^target_files: //')

# Resolve artifact: explicit target or git diff
# Use git diff against the commit recorded at Phase 1 start, NOT HEAD,
# to capture files changed during the entire /goal session including interim commits.
GOAL_START_COMMIT=$(grep "^start_commit:" .claude/goal-quench.pending | sed 's/^start_commit: //')
if [ "$TARGET" = "inferred from git diff" ] || [ -z "$TARGET" ]; then
  if [ -n "$GOAL_START_COMMIT" ]; then
    TARGET=$(git diff "$GOAL_START_COMMIT"..HEAD --name-only 2>/dev/null | tr '\n' ' ')
  else
    # Fallback: staged + unstaged changes (does not capture interim commits)
    TARGET=$(git status --short 2>/dev/null | awk '{print $2}' | tr '\n' ' ')
  fi
fi
# Guard: reject empty target
[ -z "$TARGET" ] && echo "ERROR: cannot resolve verification artifact — no files changed or start_commit missing" && exit 1
```

Run `pipeline-conductor --quick` on `$TARGET` (the artifact changed during this /goal session). Gate on result:

| pipeline-conductor verdict | goal-quench action | Delete `.pending`? |
|---|---|---|
| `CLEAN (--quick)` | Output: "Quality gate passed (--quick). Safe for local iteration and internal commits. Run pipeline-conductor --full before external release or PR." Log tokens. | **Yes — immediately** |
| `PENDING` | Proceed with caution. Output pending items. Recommend: "Resolve before any external release." | **Yes — immediately** |
| `BLOCKED` | Block commit. Output blocking items. Ask: "Fix and re-run /goal, or accept partial completion?" | **Only after user acknowledges** |
| `ESCALATE` | Surface to user for decision. Do not auto-delete — preserve state until user explicitly decides. | **Only after user decision** |

**Deletion rule**: On BLOCKED or ESCALATE, `.pending` must survive until the user makes an explicit decision. Deleting before that decision loses the recovery anchor.

**Deadlock prevention**: While `.pending` exists (BLOCKED/ESCALATE), the next-turn verification check runs ONCE per turn only — not on every subsequent turn. After the first verification output, suppress further auto-trigger until the user explicitly acts (fix + re-run, accept, or delete). If the user starts a new `/goal-quench` run while `.pending` exists, warn: "A previous verification is pending. Resolve it first (`/goal-quench --verify`) or clear it (`rm .claude/goal-quench.pending`)." Do not silently overwrite with a new `.active` file.

Record actual token usage in `tracks/_meta/goal_quench_{YYYY-MM-DD}.md` for calibration (regardless of verdict).

### Step 3-c — Sidecar verdict gate (pro + max, when sidecar ≠ none)

After pipeline-conductor completes, read `sidecar:` from `.pending`. If non-none, gate on the sidecar's verdict before advancing to Done When:

| Sidecar | Wait for | Failure action |
|---|---|---|
| `steel-quench-c3` | Wave 2 convergence: PASS or CONDITIONAL_PASS | FAIL → reopen Phase 2, surface blocking findings to user |
| `agent-composer-panel` | Panel findings file written + incorporated into pipeline-conductor context | Not yet written → re-run pipeline-conductor with panel findings |
| `sim-conductor` + `steel-quench-w5` | Both: sim-conductor Area A PASS **and** steel-quench W5 convergence PASS | Either FAIL → block Done When; surface failing verdict |

This gate is **blocking** — Done When cannot be reached until the sidecar verdict is resolved. Record `sidecar_findings_count` in the calibration record before closing.

---

## Calibration Record

After each goal-quench run, append to `tracks/_meta/goal_quench_{YYYY-MM-DD}.md`:

```yaml
- run_id: GQ-{YYYYMMDD}-{N}  # e.g. GQ-20260603-01 — unique per run, links to session JSONL
  session_id: "{first-8-chars-of-jsonl-filename}"  # for JSONL back-trace
  date: YYYY-MM-DD
  task: {one-line description}
  scope_hint: "{N files affected, task type}"  # e.g. "3 new files, signal doc"
  mode: core | pro | max
  session_type: minor | normal | heavy | continuation  # for within-type comparison
  estimated_tokens: N
  budget_source: token-budget-gate | fallback-heuristic
  actual_tokens: N  # from ~/.claude/projects/*/conversation*.jsonl or user-reported; "unknown" if unavailable
  estimation_error: over | under | accurate
  estimation_error_pct: "N%"  # e.g. "717%" — magnitude of under/over; omit if accurate
  actual_vs_estimate_ratio: N.N  # actual / estimated (e.g., 4.7 means actual was 4.7× estimate)
  budget_verdict: GREEN/YELLOW/ORANGE/RED
  pipeline_verdict: CLEAN/PENDING/BLOCKED/ESCALATE
  sidecar: none | steel-quench-c3 | agent-composer-panel | sim-conductor | {cli-name}
  sidecar_type: none | cc-subagent | external-cli  # cc-subagent = isolated Sonnet context; external-cli = untracked
  sidecar_model: none | sonnet | {model-name}  # standard baseline: sonnet; external CLIs vary by tier
  orchestrator_tokens: N | unknown  # Opus orchestrator CC tokens (pro/max only; visible in CC)
  sidecar_tokens: N | unknown  # Sonnet sub-agent CC tokens if cc-subagent; "untracked" if external-cli
  sidecar_findings_count: N  # 0 if sidecar=none
  threshold_triggered: none/50/70/85/95
  notes: {optional — why estimate was off, what scope changed}
```

**`actual_tokens` collection**: Claude cannot read session token counts directly. Preferred method:
```bash
python3 -c "
import json, glob
f = sorted(glob.glob('~/.claude/projects/*/conversation*.jsonl'.replace('~', __import__('os').path.expanduser('~'))))[-1]
lines = [json.loads(l) for l in open(f)]
total = sum(m.get('message',{}).get('usage',{}).get('input_tokens',0) + m.get('message',{}).get('usage',{}).get('output_tokens',0) for m in lines)
print(f'Session tokens: {total:,}')
"
```
Fallback: turn count × estimated tokens/turn (~2K for short turns, ~8K for long file edits). Write `"unknown"` if no estimate is possible.

**Retrospective calibration baseline (N=10, 2026-06-01–06-03, Sonnet)**: mean actual/estimate ratio = 4.7× (range 1.3×–10.5×). Systematic underestimation due to session overhead. Full data held in the private companion store (`paper-signals/`).

After 10 additional prospective runs, compute mean estimation error per mode — calibrate the session_overhead_factor if systematic over/under persists.

`pipeline_verdict` enum includes `ESCALATE` — record it when Phase 3 required user decision before proceeding.

This data calibrates future estimates. Target: 10 prospective runs per mode before treating mode comparison as reliable. Runs with `budget_source: fallback-heuristic` calibrate the fallback tiers; runs with `token-budget-gate` calibrate the skill itself.

---

## Simplification Guards

- Do not activate goal-quench for exploratory or single-turn tasks — only for /goal sessions.
- If the user runs /goal without going through goal-quench setup, propose retroactively: "Run /goal-quench --verify to quality-check the output."
- `--verify` mode: skip Phase 1+2, go directly to Phase 3 verification using current session scope.
- **core is the default and the floor** — never auto-escalate a GREEN/YELLOW task to pro/max. Sidecar CLI costs (external, untracked in CC) apply in pro/max — auto-escalation requires ORANGE/RED budget or explicit user flag.
- **pro/max are supersets of core, not replacements** — a user who wants only the v1 safety belt stays in core and sees no orchestration.
- **Post-optimization step-down**: if a pro/max run's re-estimated budget drops to GREEN/YELLOW after context-doctor trims (Phase 1.5 Step A), offer to drop back to core — don't run orchestration the trimmed scope no longer needs.
- Phase 1.5 does not re-implement the gates of the skills it chains (agent-composer's destructive/fan-out gates, plugin-recommender's install approval) — it defers to them.

---

## Chains

- `token-budget-gate` — Phase 1 cost estimation (all modes)
- `context-doctor` — Phase 1.5 Step A token-reduction pre-pass (pro + max)
- `agent-composer` — Phase 1.5 Step B goal decomposition into Waves (pro + max)
- `plugin-recommender` — Phase 1.5 Step C capability-gap fill (max only, GAP-triggered)
- `cross-ecosystem-synergy-detection` — Phase 1.5 Step C pre-validation of discovered candidates (max only)
- `pipeline-conductor` — Phase 3 quality gate (`--quick` for core/pro, `--full` for max; called by Stop hook)
- `field-harvest` — capture calibration data as reusable pattern after 10 runs

---

## Done When

```
Phase 1: token-budget-gate verdict output + mode resolved (core default, or pro/max via budget verdict / explicit flag)
+ .claude/goal-quench.active written (with mode: field) + thresholds injected
+ If pro/max: Phase 1.5 ran — context-doctor pre-pass + agent-composer plan;
  max additionally: GAP-triggered plugin-recommender + cross-ecosystem-synergy-detection pre-validation
+ Phase 3 (on next response after /goal): .pending file detected + pipeline-conductor run
  (--quick for core/pro, --full for max)
+ Verification verdict output (CLEAN/PENDING/BLOCKED/ESCALATE)
+ If sidecar invoked (pro/max Step D): Step 3-c sidecar verdict resolved (PASS/CONDITIONAL_PASS) before closing
+ .pending file deleted + calibration record appended
```

Verdict: PASS (CLEAN verification) | CONDITIONAL_PASS (PENDING verification) | FAIL (BLOCKED verification) | ESCALATE (user decision required on partial completion)

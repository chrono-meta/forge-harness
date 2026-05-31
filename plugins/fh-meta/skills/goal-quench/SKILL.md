---
name: goal-quench
description: >-
  Wraps /goal with a token budget gate (pre-run estimate), mid-run budget thresholds, and an automatic post-run quality verification via pipeline-conductor. Closes the quality gap /goal leaves: Haiku evaluates completion, pipeline-conductor evaluates correctness. Triggered by "goal with quality gate", "safe goal", "goal-quench", or before running /goal on high-stakes tasks.
user-invocable: true
allowed-tools: ["Read", "Write", "Bash", "Grep"]
model: sonnet
---

# goal-quench — /goal with Token Budget + Quality Gate

`/goal` runs until Haiku says "done" — but Haiku only checks completion, not quality. Without a budget ceiling, sessions can exhaust tokens silently. goal-quench adds three things that /goal currently lacks:

1. **Pre-run**: token-budget-gate estimate — know the cost before committing
2. **Mid-run**: budget threshold awareness — intervene before exhaustion
3. **Post-run**: pipeline-conductor --quick — verify quality before accepting "done"

The evaluator principle: Haiku judges completion (every turn, cheap). pipeline-conductor judges quality (once at the end, structured). Separating the two closes the self-evaluation bias that a single evaluator cannot avoid.

> **v1 scope**: budget gate + stop-hook verification. Goal decomposition and mid-run Sonnet quality signals are deferred to v2 (requires empirical calibration).

---

## Triggers

- `/goal-quench`
- "run /goal with a quality gate", "safe goal run", "goal with verification"
- "I want to use /goal but worried about tokens", "goal with budget control"
- "goal-quench", before any long /goal session
- Automatically proposed when user mentions `/goal` on tasks estimated > 15K tokens

---

## One-Time Setup (required)

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

---

## Phase 1 — Pre-run Gate

### Step 1. Collect task description

Ask:
> "What will you run with /goal? Describe the task and expected scope."

Collect: task description, target files or directories, expected output.

### Step 2. token-budget-gate estimate

Run token-budget-gate against the task description. Map the result to a go/no-go decision:

| token-budget-gate verdict | goal-quench action |
|---|---|
| GREEN (< 10K) | Proceed without comment |
| YELLOW (10K–30K) | Proceed — note estimated cost, suggest /goal scope if possible |
| ORANGE (30K–60K) | Confirm before proceeding: "This will be expensive. Reduce scope or continue?" |
| RED (> 60K) | Block: "Budget too high for a single /goal run. Split into smaller goals first." |

On RED: propose 2–3 smaller sub-goals the user could run sequentially. **goal-quench halts and does not write `.active` or inject thresholds. The user may still run `/goal` manually — but goal-quench will not gate or verify a session started without its active file.**

### Step 3. Write state file

Create `.claude/goal-quench.active`:

```
scope: {task description — one line}
target_files: {comma-separated file paths or directory; "inferred from git diff" if not known}
budget_estimate: {N} tokens
budget_verdict: {GREEN/YELLOW/ORANGE/RED}
pipeline_mode: --quick
timestamp: {YYYY-MM-DD HH:MM}
session_pid: {$$}
```

`target_files` is the **verification artifact** — what pipeline-conductor --quick will evaluate in Phase 3. Specify files/directories explicitly if known; otherwise write `"inferred from git diff"` and Phase 3 will use `git diff HEAD --name-only` to resolve.

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

## Phase 2 — Mid-run (during /goal execution)

goal-quench does not directly control /goal execution. The budget thresholds injected in Phase 1 are instructions Claude follows during the /goal session.

**What Claude should do mid-run**:

- Track approximate token consumption against the Phase 1 estimate
- At each threshold (50/70/85/95%), execute the corresponding action
- Do not wait for goal-quench to intervene — the thresholds are self-enforced

**Threshold enforcement caveat**: Claude cannot reliably read its own real-time token consumption during a /goal session. The 50/70/85/95% thresholds are instructional — Claude approximates consumption based on task complexity and turn count. They are not mechanically enforced. For hard enforcement, see the Anthropic feature request (--budget flag).

**What goal-quench cannot do in v1** (requires native Anthropic support):
- Hard-enforce token ceiling mid-run (--budget flag, not yet available)
- Auto-checkpoint commit on sub-goal completion (--checkpoint flag, not yet available)
- Mid-run Sonnet quality signal (requires structured evaluator hooks)

These gaps are the basis for the Anthropic feature request (see `knowledge/shared/harness-core/goal_quench_anthropic_issue.md`).

---

## Phase 3 — Post-run Verification

When /goal stops, the Stop hook fires and:
1. Detects `.claude/goal-quench.active`
2. Copies it to `.claude/goal-quench.pending`
3. Removes `.active`
4. Prints: "[goal-quench] /goal finished. Verification pending — starting pipeline-conductor --quick."

On the next Claude response (after /goal), check for `.claude/goal-quench.pending` **with a freshness guard** — only act if the timestamp in the file is within the current session (< 4 hours old):

```bash
if [ -f .claude/goal-quench.pending ]; then
  PENDING_TIME=$(grep "^timestamp:" .claude/goal-quench.pending | cut -d' ' -f2-)
  # If timestamp is recent (< 4h), trigger verification; else warn and skip
  echo "goal-quench verification pending (created: $PENDING_TIME)"
fi
```

If found and fresh: **automatically run pipeline-conductor --quick** before responding to any other request. This is not optional — pending verification takes priority.

If found but stale (> 4 hours): warn the user — "A stale goal-quench.pending exists from {timestamp}. Run `/goal-quench --verify` to re-evaluate, or delete it to clear." Do not auto-trigger verification on stale state.

### Verification flow

```bash
# Read scope and target from pending file
SCOPE=$(grep "^scope:" .claude/goal-quench.pending | cut -d' ' -f2-)
TARGET=$(grep "^target_files:" .claude/goal-quench.pending | cut -d' ' -f2-)

# Resolve artifact: explicit target or git diff
if [ "$TARGET" = "inferred from git diff" ] || [ -z "$TARGET" ]; then
  TARGET=$(git diff HEAD --name-only 2>/dev/null | tr '\n' ',')
fi
```

Run `pipeline-conductor --quick` on `$TARGET` (the artifact changed during this /goal session). Gate on result:

| pipeline-conductor verdict | goal-quench action | Delete `.pending`? |
|---|---|---|
| `CLEAN (--quick)` | Output: "Quality gate passed (--quick). Safe for local iteration and internal commits. Run pipeline-conductor --full before external release or PR." Log tokens. | **Yes — immediately** |
| `PENDING` | Proceed with caution. Output pending items. Recommend: "Resolve before any external release." | **Yes — immediately** |
| `BLOCKED` | Block commit. Output blocking items. Ask: "Fix and re-run /goal, or accept partial completion?" | **Only after user acknowledges** |
| `ESCALATE` | Surface to user for decision. Do not auto-delete — preserve state until user explicitly decides. | **Only after user decision** |

**Deletion rule**: On BLOCKED or ESCALATE, `.pending` must survive until the user makes an explicit decision. Deleting before that decision loses the recovery anchor.

Record actual token usage in `tracks/_meta/goal_quench_{YYYY-MM-DD}.md` for calibration (regardless of verdict).

---

## Calibration Record

After each goal-quench run, append to `tracks/_meta/goal_quench_{YYYY-MM-DD}.md`:

```yaml
- date: YYYY-MM-DD
  task: {one-line description}
  estimated_tokens: N
  budget_verdict: GREEN/YELLOW/ORANGE/RED
  pipeline_verdict: CLEAN/PENDING/BLOCKED
  threshold_triggered: none/50/70/85/95
```

This data calibrates future token-budget-gate estimates for /goal-type tasks. Target: 10 runs before treating estimates as reliable.

---

## Simplification Guards

- Do not activate goal-quench for exploratory or single-turn tasks — only for /goal sessions.
- If the user runs /goal without going through goal-quench setup, propose retroactively: "Run /goal-quench --verify to quality-check the output."
- `--verify` mode: skip Phase 1+2, go directly to Phase 3 verification using current session scope.

---

## Chains

- `token-budget-gate` — Phase 1 cost estimation (called by this skill)
- `pipeline-conductor --quick` — Phase 3 quality gate (called by Stop hook)
- `field-harvest` — capture calibration data as reusable pattern after 10 runs

---

## Done When

```
Phase 1: token-budget-gate verdict output + .claude/goal-quench.active written + thresholds injected
+ Phase 3 (on next response after /goal): .pending file detected + pipeline-conductor --quick run
+ Verification verdict output (CLEAN/PENDING/BLOCKED)
+ .pending file deleted + calibration record appended
```

Verdict: PASS (CLEAN verification) | CONDITIONAL_PASS (PENDING verification) | FAIL (BLOCKED verification) | ESCALATE (user decision required on partial completion)

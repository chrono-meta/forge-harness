---
name: harvest-loop
description: A self-evolution pipeline that runs automatically after field sessions end. field-harvest (pattern extraction) → contention-layer (collision signals) → [persona-devil-advocate + persona-innovator parallel] → synthesizer (devil/innovator collision harvest) → Critic isolated Agent (SAGE automated critique) → harness-doctor (health check) → verify-bidirectional (consistency validation) → curator (skill lifecycle management) — 8 steps. Session learnings are automatically absorbed back into the FH ecosystem so the harness evolves on its own. In the main development environment, runs automatically at session end. For external FH users, proposes execution first. Triggered by "session harvest", "learning absorption", "fh evolution", "harvest-loop", or "run the pipeline".
user-invocable: true
allowed-tools: ["Read", "Write", "Bash", "Grep", "Glob", "Agent"]
model: opus
---

# harvest-loop — Field Session → FH Self-Evolution Pipeline

> Automatically absorbs patterns/conflicts/discoveries from field sessions back into the FH ecosystem.
> Internalizes as a pipeline the return loop from field projects to the harness that was previously done manually.
> One of the core functions is real-time detection and blocking of **Semantic Drift** — where agent terminology gradually diverges in meaning as sessions grow longer — at the field-harvest stage.

## Operation Modes

| Mode | Description | Trigger |
|---|---|---|
| **Forced mode** | Auto-runs at end of local development session. Executes without approval, only confirms final suggestions | Session wrap-up rules in hub CLAUDE.md |
| **Lightweight mode** | Immediate harvest after Wave completion within a session. Skip Steps 3/4 (devil/innovator/synthesizer) — prioritize fast recording | agent-composer Step 4-c auto-recording gate (2+ new files created or 3+ existing files changed, **or M-tier resolution decision made**) |
| **Proposal mode** | External FH users — confirms "run harvest-loop?" before executing | User utterance or `/harvest-loop` |

**Simplification guard**: Sessions that only browsed/explored (no code changes or outputs) auto-skip even in forced mode.

### Lightweight Mode Pipeline

```
agent-composer Wave complete (2+ new files or 3+ existing files changed, or M-tier resolution decision made)
    │
    ▼
[Step 1] field-harvest — extract patterns based on changed files
    │
    ▼
[Step 2] contention-layer — detect collision signals against existing skills
    │
    ▼
[Step 5] verify-bidirectional — consistency validation  ← same as full mode Step 5
    │
    ▼
Result summary (1-3 lines) + if patterns harvested, propose "run full harvest-loop?"
```

Time: ~3 min (50% reduction vs full). Skip Steps 3/3.5/4 — creative synthesis runs in full mode at session end.

**Lightweight mode Done When**:
```
Step 0 (Regression Guard) + Step 1 (field-harvest) + Step 2 (contention-layer) + Step 5 (verify-bidirectional) complete
+ harvested pattern summary 1~3 lines output
+ "run full harvest-loop?" proposed (if patterns found)
+ [Card update prohibited] Do NOT update reference_next_session_starter.md in lightweight mode alone
  → Card update must run with full harvest-loop Step 0-b proof gate
  → Lightweight mode only + session end = card update missing = bug
```

---

### Early Trigger (mid-session activation conditions)

Conditions for running mid-session harvest-loop without waiting for session end.

| Condition | Threshold | Meaning |
|---|---|---|
| Same pattern discovered repeatedly | 3+ times | Sufficient new skill candidate signal — must record before session ends to avoid loss |
| Existing skill consecutive failures | 2+ consecutive | Immediate devil attack/alternative exploration needed |
| Session elapsed time | 2+ hours | Long session mid-point check — harvest before context window pressure |

**Activation procedure**:
1. When condition is met → "Early harvest condition detected (reason: {condition}). Run mid-session harvest?"
2. If Y → run only field-harvest → contention-layer → verify-bidirectional (skip Steps 3/3.5/4)
3. Immediately persist results to `tracks/_meta/fh_signal_{date}_{slug}.md`
4. At session end, run official full harvest-loop → deduplicate and merge with early trigger results

**Simplification guard**: Same pipeline as agent-composer Step 4-c lightweight mode. Prevent duplicate runs — if lightweight mode already ran, auto-skip early trigger.

---

## Pipeline Structure

```
Session end
    │
    ▼
[Step 0-a] SKILL.md change detection → auto-quench
    │  git diff --name-only HEAD | grep "SKILL.md"
    │  → 1+ SKILL.md changes detected: run quench-challenger automatically (S/A/B severity)
    │  → No changes: proceed to Step 0-b immediately
    │  S-tier 1+: require prescription applied before commit (hard gate)
    │  A-tier and below: output prescription list, proceed to Step 0-b (soft gate)
    │
    ▼
[Step 0-b] Card cross-check — reconstruct completed items (no memory dependency)
    │  Read reference_next_session_starter.md
    │  + Read tracks/_meta/fh_completed_{today}.md (if real-time log exists)
    │  + Scan git log --since=today 00:00 --oneline
    │  → Generate removal candidate list from 3-source cross-check
    │  → Output "N items scheduled for removal"
    │  (Even if context is compressed, accurate reconstruction via source rebuild)
    │
    ▼
[Step 0] Regression Guard  ← v1.2: harness-evolver Learn-stage pattern
    │  Before extracting new patterns, check: does anything from this session
    │  conflict with or regress an already-validated skill?
    │  → Scan tracks/{project}/learnings/ + existing FH SKILL.md Done When criteria
    │  → Regression detected: flag the conflicting signal, route to contention-layer
    │    for explicit resolution (do not silently overwrite validated patterns)
    │  → No regression: proceed normally
    │  → Output: "Regression check: clear / N conflicts flagged"
    │
    ▼
[Step 1] field-harvest
    │  Scan field git diff / outputs
    │  → Extract patterns as FH absorption candidates (proceed if 3+, skip if fewer)
    │
    ▼
[Step 2] contention-layer
    │  Compare extracted patterns ↔ existing FH skills for collisions
    │  → Collision = new skill candidate signal
    │
    ▼ (Step 3 parallel)
[Step 3a] persona-devil-advocate          [Step 3b] persona-innovator
    │  Attack existing related skills              │  Formally propose new skill/PFD candidates
    │  (does new discovery expose weakness?)       │  (based on contention results)
    │                                              │
    └──────────────────┬─────────────────────────┘
                       ▼
[Step 3.5] deep-insight:synthesizer
    │  Cross-synthesize devil attack results ↔ innovator proposal results
    │  → Does the attack invalidate the proposal? (proposal rejection criteria)
    │  → Do the attack and proposal point at the same location? (HIGH signal)
    │  → Areas with proposal but no attack? (LOW candidate)
    │  → Readjust final proposal grades (HIGH/MED/LOW)
    │
    ▼
[Step 3.75] Critic (isolated Agent — SAGE pattern)
    │  Critique synthesizer proposals in an independent instance
    │  → Done When logic validation: does success actually get verified?
    │  → Failure mode exploration: 2+ edge cases where skill could fail
    │  → Claim vs. implementation alignment: description promises ↔ execution guide contradictions
    │  → PASS → Step 4 / FAIL → synthesizer re-synthesis or deferred persistence
    │  Source: SAGE (arXiv 2603.15255) Challenger→Planner→Solver→Critic
    │
    ▼
[Step 4] harness-doctor
    │  Check FH health status when adding new candidates
    │  → Whether complexity increases, whether Done When exists
    │
    ▼
[Step 5] verify-bidirectional
    │  Verify candidate skill is consistent with existing skills in both directions
    │  → Detect one-way broken connections/conflicts/duplicates
    │
    ▼
Output final proposal list (user Y/N approval gate)
    → Y: field-harvest → FH PR creation / skill file draft
    → N: persist proposals to tracks/_meta/ as fh_signal
    │
    ▼ (auto-run after Y selection)
[Step 6] Curator lifecycle review
    │  Scan all existing FH skills' status
    │  → 30+ day unused skills: suggest [STALE] marking
    │  → user-pinned skills: leave alone (pin protection)
    │  → Skill pairs with ≥70% overlap: suggest merge candidates
    │  Source: hermes-agent curator pattern (Nous Research)
```

---

## Execution Instructions

### Step 1 — field-harvest Call

```
/field-harvest --since 1d    # based on today's session
```

Extraction criteria:
- New output files (TC/experiment/analysis documents)
- Skill modifications (version bumps/new judgment rules/new steps)
- Feedback patterns (FAIL→FIX patterns, new gate discoveries)
- New memory entries (new user behavior patterns)

**Fewer than 3 patterns** → harvest-loop auto-skip + output "no session harvest targets".

### Step 2 — contention-layer Call

Compare each candidate pattern from field-harvest output against existing FH skills:

```
/contention-layer [field-harvest output patterns]
```

| Collision type | Routing |
|---|---|
| Overlaps with existing skill coverage | Existing skill enhancement candidate |
| New area not covered by existing skills | New skill candidate |
| Two existing skills conflict with each other | Mediation skill candidate |

### Step 3 — Parallel devil + innovator

**3a. devil-advocate attack angles**:
- "Does this new discovery overturn the premise of existing skill X?"
- "Doesn't the existing skill already handle this case?"
- "Does adding this make FH more complex or simpler?"

**3b. innovator proposal angles**:
- Field-discovered pattern → abstraction → naming candidates
- Synergy points with existing skills
- "Criteria for this to become a skill" (Done When draft required)

### Step 3.5 — synthesizer Call

Cross-synthesize devil (3a) and innovator (3b) results. Prevent attack and proposal from running in parallel without interaction.

> **Fallback (when deep-insight is not installed)**: Perform inline synthesis. Apply same judgment matrix. Achieve Step 3.5 purpose (attack↔proposal cross-synthesis), but persona-specialized depth will be lower. If synthesis result quality is low, Step 3.75 Critic processes as CONDITIONAL PASS.

**synthesizer input**:
- 3a results: existing skill weakness list + severity (S/A/B)
- 3b results: new skill/enhancement candidate list + Done When draft

**synthesizer judgment matrix**:

| devil attack | innovator proposal | synthesizer verdict |
|:---:|:---:|---|
| S-tier attack exists | Proposal for that area exists | **HIGH** — attack validates proposal. Immediate reflection candidate |
| S-tier attack exists | No proposal for that area | **HIGH** — attack without proposal = fix existing skill weakness immediately |
| No attack | Proposal exists | **MED** — unvalidated proposal. Re-review in next wave |
| Attack exists | Proposal rebuts attack | Attack invalidated — proposal valid. Downgrade to **MED** and keep |
| Attack overturns proposal premise | — | Proposal **rejected** — persist as fh_signal on hold |

**synthesizer output**: Only the final candidate list with readjusted grades passes to Step 3.75.

### Step 3.75 — Critic Call (Isolated Agent)

> **Source**: SAGE (arXiv 2603.15255) Challenger→Planner→Solver→**Critic** structure's Critic layer.
> Evaluating in the same context as synthesizer (Solver) causes Cost of Consensus → isolated Agent call is mandatory.

> **Meaning of isolation**: The Critic reads the conclusion generated by the synthesizer, but does not inherit the reasoning chain that reached the conclusion (devil attack reflection/grade adjustment process).
> Independent reasoning path = resolves Cost of Consensus. Isolating the conclusion itself makes the Critic a meaningless call that doesn't know what to evaluate.

```
Agent(
  prompt="Independently evaluate the following skill proposals.\n[synthesizer output passed]",
  # synthesizer reasoning chain not inherited — blind evaluation
)
```

**Critic evaluation items** (content quality, not structural check):

| Item | Judgment criteria |
|---|---|
| Done When logic validation | When condition is met, is the goal actually achieved? Is it measurable? |
| Failure mode exploration | Present 2+ edge cases where this skill could fail |
| Claim vs. implementation alignment | Does the description promise contradict the execution guide? |
| Scope appropriateness | Under-designed (Too Narrow) / Over-designed (Too Broad) verdict |

**Critic verdict**:
- **PASS**: 4+ items without issues → proceed to Step 4 (harness-doctor)
- **CONDITIONAL PASS**: 1~2 items with minor findings → attach findings and proceed to Step 4
- **FAIL**: Fundamental Done When flaw or 3+ issues → state reason + routing below

**FAIL routing** (infinite loop prevention):
- First FAIL → pass Critic findings to synthesizer for **1 re-synthesis** allowed
- FAIL after re-synthesis → auto-persist as `fh_signal` on hold (no additional retries)
- Maximum retries: **1** — beyond that is considered this session's limit, re-enter in next harvest-loop

> **Distinction from harness-doctor (Step 4)**: Critic = logical sufficiency of proposed skill content (does Done When actually verify success, does it cover failure modes?). harness-doctor = FH ecosystem fit (overlap, self-reference structure). Different layers.

### Post-Core-Skill Critic Verdict Connection (verifiable pattern)

In addition to harvest-loop new skill proposals, the following core skills can have a Critic isolated Agent called inline immediately after outputting their completion report to independently judge Done When fulfillment.

**Targets**: harness-doctor · verify-bidirectional · hub-cc-pr-reviewer · context-doctor · sim-conductor

**Call condition**: Immediately after skill completion announcement + "steel-quench", "re-validate", "run Critic" utterance or when subsequent harvest-loop steel-quench runs

**Judgment criteria**: Each skill's Done When items (`skill_quality_rubric.md` verifiable criteria)

**Result**: PASS → next step / FAIL → re-run relevant skill or persist as `fh_signal` on hold

### Step 4 — harness-doctor Call

```
/harness-doctor --scope new-candidates
```

Check items:
- Whether Done When exists (put candidate on hold if absent)
- Whether ≥70% overlap with existing skills (redirect to existing skill enhancement if overlapping)
- Whether self-reference structure exists (new skill evaluating itself by its own criteria is forbidden)

### Step 5 — verify-bidirectional Call

```
/verify-bidirectional [new skill draft]
```

Check: If A references B, does B also back-reference A? Are there any one-way broken connection points?

### Step 6 — Curator Lifecycle Review (auto-run after Y approval)

> **Source**: hermes-agent curator.py pattern (Nous Research) — structure where an independent fork instance reviews/integrates/patches skills, adapted to FH context.

**Scan target**: `plugins/*/skills/*/SKILL.md` all files + `memory/` files

#### 6-1. SKILL.md Lifecycle

```bash
# Detect skills unused for 30+ days (based on git log)
git log --since="30 days ago" --name-only --pretty=format: \
  plugins/*/skills/*/SKILL.md | sort -u > /tmp/recently_touched.txt

find plugins -name "SKILL.md" | while read f; do
  grep -qxF "$f" /tmp/recently_touched.txt || echo "[STALE candidate] $f"
done
```

| Status | Judgment criteria | Action |
|---|---|---|
| **STALE** | 30+ day git no-modify + no recent session mention | Confirm with user whether to archive, then mark `status: stale` in frontmatter |
| **Pin protected** | `pinned: true` in frontmatter | Never touch under any circumstances |
| **Merge candidate** | Two skills with ≥70% functional overlap (reuse harness-doctor overlap judgment) | Suggest merge draft (no auto-execution) |
| **Normal** | None of the above | Keep skill |

#### 6-2. Memory Self-Correction

**Scan target**: Full `memory/` directory (MEMORY.md index + individual memory files)

**Purpose**: Prevent accumulated stale memory from contaminating the next session's context.

```bash
# MEMORY.md index vs actual files consistency check
grep -oP '\[.*?\]\(\K[^)]+' memory/MEMORY.md | while read f; do
  [ -f "memory/$f" ] || echo "[INDEX-ORPHAN] memory/$f — in index but file missing"
done

# Detect orphan files not in index
find memory -name "*.md" ! -name "MEMORY.md" | while read f; do
  fname=$(basename "$f")
  grep -q "$fname" memory/MEMORY.md || echo "[FILE-ORPHAN] $f — file exists but not indexed"
done

# Detect memory files unmodified for 30+ days
git log --since="30 days ago" --name-only --pretty=format: -- memory/ \
  | sort -u > /tmp/recently_touched_mem.txt

find memory -name "*.md" ! -name "MEMORY.md" | while read f; do
  grep -qxF "$f" /tmp/recently_touched_mem.txt || echo "[MEM-STALE candidate] $f"
done
```

| Status | Judgment criteria | Action |
|---|---|---|
| **INDEX-ORPHAN** | Linked in MEMORY.md but file missing | Remove that line from MEMORY.md immediately (auto-allowed) |
| **FILE-ORPHAN** | File exists but not registered in MEMORY.md | Confirm with user: "add to index or delete?" |
| **MEM-STALE** | (auto) 30+ day git no-modify → candidate output / (manual) recent mention in session card or session files is user-confirmed | Confirm with user: "archive or delete?" |
| **PROJECT type priority** | memory file with `type: project` | Suggest moving to CLOSED section if completed/ended |
| **Normal** | None of the above | Keep |

**Memory curator safety principles**:
- Only INDEX-ORPHAN removal (MEMORY.md edit) is auto-allowed — everything else requires user approval
- `type: reference` items with 🔑 keywords are excluded from STALE detection (active-load targets)
- Actual file deletion is absolutely prohibited without explicit approval

**Common curator safety principles**:
- Only suggest touching agent-generated skills (protect core skills written directly by humans)
- Skills with `pinned: true` are automatically excluded from STALE/merge suggestion targets
- Actual deletion/modification only after explicit user approval

### Step 6-a — Skill Usage Leaderboard Update

Immediately after curator, record the list of skills called in this session in `tracks/_meta/skill_usage.md`.

```bash
# Check whether skill_usage.md exists
ls tracks/_meta/skill_usage.md 2>/dev/null || echo "MISSING"
```

**If absent**: Initialize from template:
```bash
cp {FH_DIR}/templates/skill_usage_template.md tracks/_meta/skill_usage.md
```
**If present**: Add a row at the bottom of the "Recent session records" table:

```markdown
| {YYYY-MM-DD} | {comma-separated list of skills called this session} |
```

And update the `Last used` date for those skills in the Leaderboard table.

**Flag skills with 4+ weeks no call** (linked with curator STALE detection):
- Leaderboard status is `⚠️ Under observation` + last used 28+ days → change status to `❌ Deprecation candidate`
- If deprecation candidates exist → report to user: `"Deprecation candidate detected: {skill name} — keep?"`

### Step 6-b — Harness Evolution Cadence (4-week cycle)

> **DemoEvolve strategy implementation**: Adjust agent capabilities by updating only external skill parameters (`escalate_when`) without model re-training. Only run when 4+ weeks of real usage data has accumulated.

**Execution condition**: Automatically propose when 2+ `fh_signal_*.md` files exist in `tracks/_meta/`.

**Procedure**:

1. Scan skills with `complexity_routing`
   ```bash
   grep -rl "complexity_routing" plugins/*/skills/*/SKILL.md
   ```

2. Aggregate escalation-related records from `tracks/_meta/fh_signal_*.md`
   - Search for mentions of "cases where Opus escalation actually occurred"
   - Search for signals of "over-escalation where Sonnet was sufficient but went to Opus"

3. Condition validity judgment:

   | Status | Criteria | Action |
   |---|---|---|
   | **Valid** | 1+ actual activations within last cycle | Keep |
   | **Removal candidate** | Never activated + 4+ weeks | Suggest removal |
   | **New candidate** | Pattern appearing repeatedly in fh_signal | Suggest addition |

4. Output update candidate list → modify relevant SKILL.md after user approval:
   ```
   [harness-doctor] escalate_when update candidates:
     Remove: cross_project (no activation in 4 weeks)
     Add: multi_wave (pattern found in 3+ pipeline sessions)
   ```

**Safety principle**: No auto-modification — output candidate list then require user approval gate.

5. **skill_usage.md Leaderboard auto-aggregation integration** (evolution observation layer):

   Automatically update the "30-day call estimate" column using fh_signal grep results, replacing manual estimates:

   ```bash
   grep -rh "" tracks/_meta/fh_signal_*.md 2>/dev/null | \
     grep -oE "(harness-doctor|verify-bidirectional|hub-cc-pr-reviewer|context-doctor|sim-conductor|agent-composer|harvest-loop|steel-quench)" | \
     sort | uniq -c | sort -rn
   ```

   Aggregation results → update Leaderboard "30-day call estimate" column in skill_usage.md.
   **Manual estimate → fh_signal auto-aggregation replacement** — evolution observation layer actually running (`skill_quality_rubric.md` evolution 80% achievement condition).

---

## Output Format

```
## harvest-loop Execution Results

Session: [date] [project name]
field-harvest: [N patterns extracted]
contention-layer: [N collision signals]
synthesizer: [HIGH N / MED N / rejected N]

### Final Proposals (sorted by synthesizer grade)

| # | Proposal type | Target | Grade | devil | innovator | synthesizer verdict |
|:---:|---|---|:---:|---|---|---|
| 1 | Existing skill enhancement | [skill name] | HIGH | [attack result] | [enhancement direction] | attack+proposal aligned |
| 2 | New skill candidate | [candidate name] | MED | none | [Done When draft] | proposal only |

→ Y: Create PR / draft skill file
→ N: Persist to tracks/_meta/fh_signal_YYYY_MM_DD_{slug}.md

### [Required final step] Session card update (proof gate)

Immediately after harvest-loop completes:

1. Read `memory/reference_next_session_starter.md` → **record BEFORE item count**
2. Apply removal list from Step 0-b (no LLM memory — source-based reconstruction)
3. Add new priorities
4. Write (overwrite) + git commit
5. **Output "BEFORE N items → AFTER M items (removed N-M: [item name list])" diff — required**

If no diff (N=M): warn "Step 0-b cross-check re-verification needed — possible completed item omission"

**When fh_completed file is absent (2-source mode)**:
- Source: starter card + git log only
- Items confirmed by git log alone → "confirmed removal"
- Card item name ↔ commit message mismatch → "removal candidate (uncertain)" + output "real-time log missing — manual check needed: [item list]"
- Exact match required for item name matching — no LLM semantic judgment for "confirmed" status

**Natural-language close judgment (4th source — conversation context)**:
Even without git log match, items with the following patterns explicitly stated in this session are treated as "natural-language closed" and removed immediately:
- "not possible / confirmed impossible" (endorsement not possible, cannot proceed, etc.)
- "no response + N weeks elapsed" → abandoned
- "mutual citation confirmed" · "merged" · "cancelled" · "no longer needed"
- User directly says "stop monitoring" · "close this" · "remove it"

Natural-language closed items → remove from card immediately (leave only "✅ closed" one-liner in reference table). Do not re-mention.

Leaving completed items in the card until the next session is a bug.
```

---

## Linked Skills

| Situation | Linked skill |
|---|---|
| 3+ new skill candidates | `/agent-composer` for dispatch plan composition |
| Need to design existing skill enhancement direction | `/meta-prompt-builder` |
| Validate candidates from external user perspective | `fh-meta:hub-persona-auditor` |
| Review before sharing with team | `/apex-review` |
| When self-marketing pattern discovered as HIGH P10 | `/self-marketing-lint` auto-propose |

## Done When

```
All stages Step 0 → 1 → 2 → 3 (parallel) → 3.5 → 3.75 → 4 → 5 complete
+ synthesizer grade readjustment complete (rejected candidates separated)
+ Step 3.75 Critic verdict complete (PASS/CONDITIONAL PASS/FAIL stated)
+ Final proposal list output (sorted by HIGH/MED criteria)
+ User Y/N approval gate complete
+ (If Y selected) Step 6 Curator lifecycle review complete
  → 6-1: SKILL.md STALE candidate list output + merge candidates included if any
  → 6-2: Memory self-correction — INDEX-ORPHAN/FILE-ORPHAN/MEM-STALE detection results output
+ [Required] reference_next_session_starter.md delta update complete
  → Step 0-b based reconstruction (no LLM memory — git log + fh_completed source-based)
  → BEFORE N items → AFTER M items diff output required (proof gate)
  → No diff (N=M) = warning output + Step 0-b re-check obligation
  → Completed items remaining = bug (Done When not met)
```

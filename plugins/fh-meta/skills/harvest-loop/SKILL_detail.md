---
name: harvest-loop-detail
description: Detail file for harvest-loop — bash scripts for Step 6 curator, observability hook spec, Step 3.5-X bash, Critic Agent call format. Load when executing a specific step.
load: on-demand
---

# harvest-loop — Detail Reference

> Load when executing a specific step. SKILL.md contains operation modes, pipeline structure diagram, execution instructions overview, and Done When.

---

## §Step3-75 — Critic Isolated Agent Call

```
Agent(
  prompt="Independently evaluate the following skill proposals.\n[synthesizer output passed]",
  # synthesizer reasoning chain not inherited — blind evaluation
)
```

Meaning of isolation: The Critic reads the synthesizer conclusion but does not inherit the reasoning chain that reached it (devil attack reflection/grade adjustment process). Independent reasoning path = resolves Cost of Consensus.

**Evaluation items**:

| Item | Judgment criteria |
|---|---|
| Done When logic validation | When condition is met, is the goal actually achieved? Is it measurable? |
| Failure mode exploration | 2+ edge cases where this skill could fail |
| Claim vs. implementation alignment | Does description promise contradict execution guide? |
| Scope appropriateness | Too Narrow / Too Broad verdict |

**FAIL routing** (infinite loop prevention):
- First FAIL → pass Critic findings to synthesizer for **1 re-synthesis** allowed
- FAIL after re-synthesis → auto-persist as `fh_signal` on hold (no additional retries)
- Maximum retries: **1**

**Post-Core-Skill Critic Verdict Connection**: Following core skills can have Critic called inline after completion: harness-doctor · verify-bidirectional · hub-cc-pr-reviewer · context-doctor · sim-conductor. Trigger: immediately after completion announcement + "steel-quench" / "re-validate" / "run Critic" utterance.

---

## §Step3-5X — Cross-Session 2nd Validation Bash

```bash
# Option A: External CLI team (if available — same detection as steel-quench Wave 5)
SYNTH_CHALLENGE=$(printf \
  'You are an adversarial reviewer with zero prior context.\nEvaluate these skill proposals and find flaws in the synthesis logic.\nFlag any HIGH-grade items that are over-promoted.\nFormat: [item · flaw · downgrade-to]\n---\n%s' \
  "${SYNTHESIZER_OUTPUT}" | gemini 2>/dev/null)

# Option B: Cross-session Claude (fallback)
SYNTH_CHALLENGE=$(claude --print \
  "Adversarial reviewer, zero context. Evaluate these skill proposals.
Flag over-promoted HIGH-grade items. Format: [item · flaw · downgrade-to]
---
${SYNTHESIZER_OUTPUT}" 2>/dev/null)
```

**Outcome**:
- Items flagged as over-promoted → downgrade HIGH → MED, proceed with caution
- Confirmed across both → HIGH-confirmed → pass to Step 3.75 with elevated confidence
- Zero new issues → synthesis confirmed, proceed normally

Token cost: External CLI ~1K–2K tokens (billed to that CLI). Cross-session Claude ~2K–3K. Propose once — user may skip.

---

## §Step6-Detail — Bash Scripts for Curator + Memory + Leaderboard

### 6-1. SKILL.md Lifecycle (bash)

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
| **STALE** | 30+ day git no-modify + no recent session mention | Confirm with user, then mark `status: stale` in frontmatter |
| **Pin protected** | `pinned: true` in frontmatter | Never touch under any circumstances |
| **Merge candidate** | Two skills with ≥70% functional overlap | Suggest merge draft (no auto-execution) |
| **Normal** | None of the above | Keep |

### 6-2. Memory Self-Correction (bash)

**Theoretical basis — Agent Aging 4 Mechanisms** (arXiv:2605.26302, AgingBench):

| Aging type | Definition | 6-2 defense |
|---|---|---|
| **Compression aging** | Information loss during history compression | harvest-loop Step 0-a/b real-time recording obligation |
| **Interference aging** | New knowledge corrupts existing | FILE-ORPHAN detection |
| **Revision aging** | Stale facts after updates create inconsistency | MEM-STALE detection |
| **Maintenance aging** | Side effects from routine cleanup | Curator safety principles — no auto-delete |

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

| Status | Judgment | Action |
|---|---|---|
| **INDEX-ORPHAN** | In MEMORY.md but file missing | Remove from MEMORY.md immediately (auto-allowed) |
| **FILE-ORPHAN** | File exists but not indexed | Confirm: "add to index or delete?" |
| **MEM-STALE** | 30+ day git no-modify | Confirm: "archive or delete?" |
| **PROJECT type priority** | `type: project` file | Suggest moving to CLOSED section if completed |

Memory curator safety: Only INDEX-ORPHAN removal is auto-allowed. `type: reference` items with 🔑 keywords excluded from STALE detection.

### 6-a. Skill Usage Leaderboard (bash)

```bash
# Check whether skill_usage.md exists
ls tracks/_meta/skill_usage.md 2>/dev/null || echo "MISSING"
```

**If absent**: `cp {FH_DIR}/templates/skill_usage_template.md tracks/_meta/skill_usage.md`
**If present**: Add row at bottom of "Recent session records" table:
```markdown
| {YYYY-MM-DD} | {comma-separated list of skills called this session} |
```

Update `Last used` date for called skills in Leaderboard table.
Flag skills with 4+ weeks no call: status `⚠️ Under observation` → if 28+ days → `❌ Deprecation candidate`.

### 6-b. Harness Evolution Cadence (bash — run when 4+ weeks of data accumulated)

```bash
# 1. Scan skills with complexity_routing
grep -rl "complexity_routing" plugins/*/skills/*/SKILL.md

# 2. Aggregate escalation records from fh_signal files
grep -rh "" tracks/_meta/fh_signal_*.md 2>/dev/null | \
  grep -oE "(harness-doctor|verify-bidirectional|hub-cc-pr-reviewer|context-doctor|sim-conductor|agent-composer|harvest-loop|steel-quench)" | \
  sort | uniq -c | sort -rn
```

| Status | Criteria | Action |
|---|---|---|
| **Valid** | 1+ actual activations within last cycle | Keep |
| **Removal candidate** | Never activated + 4+ weeks | Suggest removal |
| **New candidate** | Pattern appearing repeatedly in fh_signal | Suggest addition |

Output update candidate list → modify relevant SKILL.md after user approval. No auto-modification.

---

## §Observability — Full Observability Hook Spec

> Frontier basis: `harness_frontier_diagnosis_2026-06-02.md` §Frontier Highlights 3 (AHE — agents cannot reliably improve a black-box harness).

Every evolution decision must leave a 3-part trace in `tracks/_meta/edit_manifest.yaml`:

| Trace part | Where | When written |
|---|---|---|
| **(a) what changed** | `edit_manifest.yaml` entry (file + diff summary) | On accepting a proposal (Y gate) |
| **(b) predicted effect** | same entry's `predicted_impact` + `predicted_measurable_by` | Same moment — decision with no prediction is blind |
| **(c) verify checkpoint** | same entry's `validation_status` (accepted/rejected) | Next harvest-loop Step 0-c VERIFY |

**Decision-log obligation**: When Y gate accepts a proposal, append (a)+(b) pair to `edit_manifest.yaml` in the same step — do not defer. A proposal accepted without a recorded prediction is a black-box edit — flag, not silently applied.

**Glass-box Done When**: harvest-loop should be able to answer "for each change, what did we predict and did it hold?" purely from `edit_manifest.yaml` — zero reliance on session memory.

---

## §Output-Detail — Session Card Update (Natural Language Close Judgment)

**Natural-language close judgment (4th source — conversation context)**:

Even without git log match, items with the following patterns stated in session are treated as "natural-language closed" and removed immediately:
- "not possible / confirmed impossible" (endorsement not possible, cannot proceed)
- "no response + N weeks elapsed" → abandoned
- "mutual citation confirmed" · "merged" · "cancelled" · "no longer needed"
- User directly says "stop monitoring" · "close this" · "remove it"

Natural-language closed items → remove from card immediately (leave only "✅ closed" one-liner in reference table). Do not re-mention.

**When fh_completed file is absent (2-source mode)**:
- Source: starter card + git log only
- Items confirmed by git log alone → "confirmed removal"
- Card item name ↔ commit message mismatch → "removal candidate (uncertain)" + "real-time log missing — manual check needed: [item list]"
- Exact match required — no LLM semantic judgment for "confirmed" status

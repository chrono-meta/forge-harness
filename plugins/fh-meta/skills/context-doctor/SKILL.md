---
name: context-doctor
description: Reduces token waste in Claude Code sessions. Scans projects to automatically generate .claudeignore files, and guides on over-read files and /clear timing. In hub environments, regularly audits bloated CLAUDE.md/MEMORY.md/memory/*.md files and proposes compression. Usable standalone without a hub clone.
user-invocable: true
allowed-tools: ["Read", "Write", "Bash", "Glob", "Grep"]
model: sonnet
complexity_routing:
  base: sonnet
  high: opus
  escalate_when:
    - cold_start
    - cross_project
---

# context-doctor — Token Efficiency Diagnosis + Automatic Prescription

Diagnoses the 3 main causes of session token waste and prescribes immediate remedies:
1. No `.claudeignore` → unnecessary files loaded wholesale into context
2. Repeated full reads of large files → paying the same cost N times
3. Not using `/clear` after direction changes → continuing work with accumulated noise

**Standalone install** — this skill works normally with plugin install only, without cloning the full meta-harness.

## Execution Steps

### Step 1. `.claudeignore` Diagnosis + Generation

Check whether `.claudeignore` exists in the project root (bash in §Step-Bash).

**If absent**: Scan project structure and auto-generate.

**If already present**: Keep existing content + suggest additional patterns only (no overwrite). Check for sentinel comment (`# context-doctor:`) and add to first line if absent.

Generation criteria — by project type:

| Detected type | Additional patterns |
|---|---|
| Node.js (`package.json`) | `node_modules/` · `dist/` · `build/` · `.next/` · `coverage/` |
| Python (`pyproject.toml` / `setup.py`) | `__pycache__/` · `.venv/` · `*.egg-info/` · `dist/` · `.pytest_cache/` |
| Java (`pom.xml` / `build.gradle`) | `target/` · `build/` · `.gradle/` |
| Common (always include) | `.git/` · `*.log` · `*.lock` · `*.min.js` · `*.min.css` |

Present preview to user after generation → save after confirmation.

Automatically add sentinel comment to first line when generating/updating:
```
# context-doctor: configured YYYY-MM-DD
```
→ Suppresses auto-invocation in subsequent sessions.

> **Detail**: See `SKILL_detail.md §Step-Bash` — detection bash for Steps 1/2/4/5, large-file warning format, audit report format — read when executing any step's commands.

### Step 2. Large File Detection + Split Strategy Guidance

Detect files exceeding 500 lines (top 10 — bash in §Step-Bash) and output the split-read guidance per file (offset + limit, section by section).

**Repeated full-read pattern** (burst pattern) detection criteria (behavioral):
- 3+ files over 500 lines exist and `.claudeignore` was absent
- User mentions "read it all at once" / "re-read the whole thing every time"

When burst pattern is detected → **trigger harvest-loop integration in Step 4**.

### Step 3. `/clear` + Model Switching Timing Guide

Check session state with the user, then prescribe according to context:

**Wrap-then-Compact** (when approaching context limit — CC subscription only):

When context is near the limit and you want to *preserve state* rather than reset:
1. Ask Claude: `"wrap up — completed items, modified files, pending tasks"`
2. Claude writes a structured summary → that summary anchors the `/compact` output
3. Run `/compact` — the wrap becomes the cold-start primer for next session

> This is superior to blind `/compact` because you control what's preserved. Bedrock/API has no meter warning — CC subscription only.

→ Full pattern + table: `CHEATSHEET.md §10 Lever 6`

**`/clear` recommended situations** (reset, not preserve):
```
□ Work direction has changed significantly (exploration → implementation, bug fix → refactor, etc.)
□ Switching to a different track/project
□ Error debugging has gone long and noise has accumulated
□ Previous attempts are unrelated to current work
□ Context has grown large (context rot — measurable quality degradation as input length grows,
  well before the window fills; threshold varies by model/task. Chroma 2025 context-rot research)
```

→ Recommend immediate `/clear` and restart in fresh context.

**Model switching criteria**:

| Current task | Recommended | Command |
|---|---|---|
| Complex design decisions · architecture review | Opus | `/model opus` |
| Code writing · file editing · refactoring | Sonnet (default) | — |
| Simple file lookup · short Q&A | Haiku | `/model haiku` |

> Models are tools for allocating the right expertise to complexity. Opus for simple tasks = wasted expertise; Haiku for design decisions = insufficient expertise. Switch models when task nature changes.

### Step 4. harvest-loop Integration (burst pattern recording)

When burst pattern is detected and `tracks/_audit/` exists: locate the latest weekly_audit file and suggest adding the Token Efficiency Check items to it (bash + checklist block in §Step-Bash).

Environments without `tracks/_audit/` (Mode C — plugin only): → output items to terminal only, skip file writes.

### Step 5. CC Context Structure Regular Audit (Hub Environment Only)

**Hub environment detection condition**: CLAUDE.md contains "your-hub" or "meta hub" + `memory/MEMORY.md` exists. Skip Step 5 when not in a hub environment.

Run the audit bash (§Step-Bash) and apply thresholds:

| Target | Threshold | Prescription |
|---|---|---|
| CLAUDE.md | Exceeds 300 lines | Section-by-section compression / move completed sections to archive |
| MEMORY.md | Exceeds 180 lines | Check entry count + move `✅ CLOSED` items to archive section |
| memory/*.md single file | Exceeds 30K (300 lines) | Suggest splitting accumulated history into separate files |
| SKILL.md (any) | > 300 lines AND no SKILL_detail.md | Propose `/skill-splitter` — governance-semantic split (not compression); compression removes content, splitting routes it on-demand |

**Frequency**: When explicitly called with `/context-doctor` or auto-invoked at session start when MEMORY.md is detected at 180+ lines.

## Context Hierarchy (L1/L2/L3)

Information buried in the middle of a long context window suffers measurable accuracy loss — the "lost in the middle" effect, ~10–30% degradation for mid-context information (see `../../../../knowledge/shared/harness-core/harness_frontier_diagnosis_2026-06-02.md`). The remedy is two-fold: tier the context, and place the most important instructions at the **start and end**, never buried in the middle.

**Three tiers — keep each within its band**:

| Tier | What lives here | Rough budget | FH example |
|---|---|---|---|
| **L1 — always-on** | System / critical instructions that must hold every turn | ~2–5K tokens | `CLAUDE.md` core rules, active session.md header |
| **L2 — session summary** | Current task state, decisions made this session | ~5–20K tokens | active track session file, `reference_next_session_starter.md` |
| **L3 — on-demand** | Reference material retrieved only when needed | unbounded, loaded then dropped | `knowledge/` docs, large source files via Read offset/limit |

**Placement norm** (applies to CLAUDE.md, prompts, and dispatched Context Cards):
- Put the load-bearing rule or task goal in the **first lines and restate it in the last lines**.
- Do not park a critical constraint in the middle of a long document — it is the most likely place to be missed.
- Promote frequently-needed L3 docs to L2 summaries; demote stale L1/L2 content to L3 (load on demand) rather than keeping it always-on.

When auditing CLAUDE.md / MEMORY.md in Step 5, check tier placement too: a critical rule sitting mid-file is a placement defect even if the file is within its line budget.

**Measured anchor — select what to feed back, don't truncate at overflow.** *Less Context, Better Agents* (arXiv:2606.10209) measures this: pruning the fed-back context to the last 5 tool-call/response pairs raises **complete itemization to 79.0%** (vs 71.0% keeping full history, 8.0% naive truncation) while cutting total token use to 535,274; adding summarization reaches **91.6%**. Evidence that selective retention beats a blind `/compact` or overflow truncation — measured on agent tool-call history (a runtime analogue of the L1/L2/L3 tiering above, not a direct test of it).

## Compression Pass

Optional step, run when context is large (e.g. after Step 5 flags a bloated file, or an L3 doc is long but must be loaded). This goes **beyond** `.claudeignore` — `.claudeignore` blocks files from loading; compression shrinks content that does need to load. LLMLingua-style compression is reported to reach ~100K→20K token reductions with minimal loss on long retrieved context (see `../../../../knowledge/shared/harness-core/harness_frontier_diagnosis_2026-06-02.md` Provenance).

Advisory and tool-agnostic — recommend (and, where a doc is being authored/edited in-session, apply) these reductions:

- Strip boilerplate: repeated headers/footers, navigation, license blocks, generated banners.
- Collapse repeated or near-duplicate sections into a single canonical statement plus a pointer.
- Summarize long retrieved docs to the task-relevant slice before pinning them into context; keep the full doc as an L3 file to re-read only if needed.
- Prefer Read offset/limit over full-file reads for large files (ties back to Step 2).

Keep it reversible: compress the *working copy* in context, not the source of truth on disk, unless the user is explicitly editing that file.

> **Detail**: See `SKILL_detail.md §Headroom` — external tooling option (redundancy-category targeting, integration surfaces, caveats) — read when executing a compression pass and considering tooling.

## External User Environment Adaptation

| Environment | Behavior |
|---|---|
| Meta-harness cloned (Mode A) | Perform full Steps 1–5 / integrate with harvest-loop files |
| Plugin only (Mode C) | Perform Steps 1–3 / Step 4 output only (no file writes) |
| External general environment | Focus on `.claudeignore` generation + large file guidance |

## Invocation Triggers

### Auto-Invocation Conditions (at session start)

Invokes **only when `.claudeignore` is absent**:
```
"This project has no .claudeignore. Token waste may be occurring. Check with /context-doctor?"
```

When `.claudeignore` exists → skip auto-invocation (treated as already configured).

> **Burst pattern auto-detection (500+ line files) is excluded from auto-invocation** — only performs on explicit call. Firing every session becomes noise.

### Suppress Mechanism

context-doctor adds a sentinel comment to the first line when generating or updating `.claudeignore`:

```
# context-doctor: configured 2026-05-10
```

Auto-invocation decision order:
1. `.claudeignore` absent → auto-invoke O
2. `.claudeignore` present + sentinel present → auto-invoke X (fully suppressed)
3. `.claudeignore` present + sentinel absent (manually written) → auto-invoke X (file existence itself is suppress signal)

**Manual suppress**: User adds the following to the first line of `.claudeignore` for permanent suppress:
```
# context-doctor: suppress
```

Explicit invocation (`/context-doctor`) always runs regardless of suppress state.

### Explicit Triggers

- `/context-doctor`
- "token waste", "session is slow", "reading the whole file", "claudeignore", "context cleanup"
- "context diet", "memory audit", "CLAUDE.md is heavy", "MEMORY.md size"
- "context engineering", "context rot", "context collapse"

### Natural Language Triggers (activates without internal vocabulary)

Also activates when an external user expresses without token/context terminology:

| Example utterance | Intent | Mapped diagnosis |
|---|---|---|
| "The context seems to be getting too large" | Suspected context bloat | Step 5 (hub) / Step 2 |
| "Tokens are being wasted" | Suspected token efficiency degradation | Step 1 + Step 2 |
| "The conversation feels inefficient" | Suspected accumulated session noise | Step 3 (/clear timing) |
| "Why is Claude so slow?" | Burst pattern or context overload | Step 2 |
| "Seems like it keeps re-reading the same thing" | Repeated full-read detected | Step 2 (burst pattern) |
| "Answers get weird as the session gets longer" | Accumulated context noise | Step 3 (/clear recommended) |
| "Context is getting full", "context meter is high" | Approaching context limit | Step 3 — propose Wrap-then-Compact pattern |
| "context engineering", "doing context engineering", "context rot setting in" | 2026 industry term for context discipline (Chroma 2025 / Anthropic) | Step 2 + Step 3 |

## Three-Doctor Loop Integration

### context-doctor's Role in Three-Doctor Loop

```
harness-doctor   → current skeleton diagnosis   "Is the structure correct? Any drift/complexity/broken references?"
context-doctor   → current context diagnosis    "Is Context Collapse occurring?"
sim-conductor    → future behavior prediction   "What happens when a real person uses this system?"
```

context-doctor is the **current context diagnostic role** among the three skills. It detects token waste/burst patterns/context contamination and presents prescriptions (.claudeignore/clear timing), which harness-doctor (skeleton) and sim-conductor (future behavior) then pick up to complete the closed loop.

---

> **Context Anxiety**: Agents make uncertain inferences when relevant context is absent — this is the engineering rationale behind the context-doctor/bridge structure. (Anthropic official naming 2025)

context-doctor (token/context) · harness-doctor (structure) · sim-conductor (simulation/ideation) — the three skills form a **diagnosis→prescription→re-diagnosis** closed loop.

| Situation | Next skill |
|---|---|
| Want to also check structure after resolving token waste | `/harness-doctor` |
| Want to validate prescription results from external user perspective | `/sim-conductor Area A` |
| SKILL.md diagnosed as over-loaded (> 300 lines, no SKILL_detail.md) | `/skill-splitter` — governance-semantic split |
| All three skills mentioned simultaneously | Three-Doctor Loop circuit activated — diagnosis→prescription→re-diagnosis cycle

## Done When

| Condition | Completion verdict |
|---|---|
| Diagnosis results output to conversation (relevant stages among Steps 1~5) | ✅ Diagnosis complete |
| `.claudeignore` created or modified + path output | ✅ Prescription complete |
| Large file detected with split strategy guidance output | ✅ Step 2 complete |
| "No context structure issues" judgment output | ✅ Health check complete |

**This skill's Done When = "diagnosis report output complete"**. Actual resolution of prescription items is in the user's or follow-up work domain and is not included in this skill's completion criteria.

**External validation path**: harvest-loop Step 3.75 Critic isolated Agent can independently judge against the above criteria (`skill_quality_rubric.md` verifiable criteria). Automatically linked when subsequent steel-quench runs.

**→ Three-Doctor Loop chain (auto-propose after diagnosis):**
- Prescription modifies SKILL.md / rules / CLAUDE.md → **propose `/harness-doctor`** re-check after fix (structural integrity)
- Prescription addresses user-facing context (onboarding, README, install guides) → **propose `/sim-conductor Area A`** (external user impact validation)
- SKILL.md detected as over-loaded → **auto-propose `/skill-splitter`**: `"I see [skill-name] SKILL.md is [N] lines with no SKILL_detail.md. Want me to run /skill-splitter to do a governance-semantic split?"`

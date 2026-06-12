---
name: frontier-digest
description: Collects the latest AI/harness engineering trends from HackerNews and arxiv, then synthesizes them into actionable insights directly relevant to forge-harness operations. Triggered by "AI trends", "latest trends", "this week's AI updates", "what's on the frontier", "harness trends", "frontier-digest".
user-invocable: true
allowed-tools: ["Bash", "WebFetch", "WebSearch", "Write"]
model: sonnet
---

# frontier-digest — FH Frontier Insight Collection & Synthesis

> Automatically collects the latest AI/agent/harness engineering trends from HackerNews and arxiv,
> then compresses and synthesizes them into insights directly relevant to forge-harness skills and structure.

## Triggers

```
/frontier-digest                # immediate execution
/frontier-digest --save         # save result to file
"what's on the frontier"
"this week's AI trends"
"harness trends"
"latest agent developments"
"any ideas for improving the harness?"
```

---

## Step 0. API Environment Detection

```
Priority:
0. /deep-research built-in available (check live session skill list)
   → use it as the collection+verification engine (staged source gathering,
     cross-checking, cited synthesis) — Tier-0 route, no API key needed
1. ANTHROPIC_API_KEY environment variable → Claude Sonnet
2. Neither → WebSearch mode (raw data only, no synthesis)
```

Report detection result in one line. Example: `🔑 Using Claude Sonnet` / `🔑 Engine: /deep-research (built-in)`

On first run without an API key, output the environment setup guide (format in §Output-Formats).

---

## Step 0.5. Operator Intake (speculative-interview arm — walled channels)

On **cadence-triggered** runs (7d), ask the operator one line before collecting:

> *"이번 주에 본 벽 뒤 소스(YouTube·LinkedIn·X 등 기계가 못 닿는 링크/요약)가 있으면 던져 주세요 — triage해서 기록합니다. 없으면 그냥 진행할게요."*

- Operator may skip — zero pressure; the autonomous arms (Step 1) run regardless.
- Why: walled channels return 403 to machine fetch — **the operator is the only wide-net sensor for them**. This arm turns ad-hoc link-throwing into a scheduled intake (manual-validated n=2).
- Received sources route to the sister-asset/triage flow with its **lightweight path**: C-tier (territory already covered) = one-paragraph entry only; full cross-audit reserved for A/B-tier. Partial wall-bypass is allowed first: try WebSearch + secondary sources before declaring unfetchable.
- **Video sources (local/laptop only — cloud VMs typically 403 on video hosts)**: probe by **capability, not engine name** via the Sidecar Engine Resolution Protocol. Tier 1 = natively multimodal CLI ingesting the URL directly (⚠️ direct `gemini` CLI EOL 2026-06-18 — probe `agy` or the Gemini API after); never route video to a coding-agent CLI without native video access (it burns tokens and recovers only metadata). Tier 3 = `yt-dlp` transcript fallback, **conditional** — probe the environment first, never assume it works. Unresolvable → operator summary remains the path.

> **Detail**: See `SKILL_detail.md §Video-Harvest` — full tier ladder, probe commands, EOL/router-shell notes — read when a video source needs harvesting.

---

## Step 1. Data Collection

Collect from four sources (bash per source in §Collection-Bash):

| Source | Method | Cap |
|---|---|---|
| HackerNews | Algolia API, score > 10, keyword-relevant | 15 items |
| arxiv | export API, latest by submittedDate | 6 items |
| TLDR AI | RSS, title + link | 5 items |
| The Batch (deeplearning.ai) | HTML scraping, title + issue slug | 5 items |

Report progress: `📡 HN 15 items · arxiv 5 items · TLDR 5 items · Batch 5 items collected`

> **Detail**: See `SKILL_detail.md §Collection-Bash` — curl commands per source with parsing notes — read when executing Step 1.

---

## Step 2. Synthesis

- **With Anthropic API**: run the synthesis prompt (full prompt in §Synthesis-Prompt) — outputs This Week's Frontier Highlights (max 3) / FH Immediate Application Candidates (2-3) / Warning Signals, within 400 characters, no preamble.
- **WebSearch mode (no API key)**: search directly with the WebSearch tool, then synthesize in context (queries in §Synthesis-Prompt).

> **Detail**: See `SKILL_detail.md §Synthesis-Prompt` — full API prompt with FH context block, WebSearch queries — read when executing Step 2.

---

## Step 3. Output

Print the synthesis result in the conversation (format in §Output-Formats): engine line + Highlights + Immediate Application Candidates + Warning Signals + collection stats.

**With `--save` flag**: save to `digests/frontier_{today}.md` (path priority: FH install path → `~/.claude/frontier-digest/digests/` → cwd; details in §Output-Formats). After saving: `✅ Saved: {path}`

> **Detail**: See `SKILL_detail.md §Output-Formats` — conversation output template, save path priority, fh_signal file format, env setup guide — read when executing Steps 3–4.

---

## Step 4. Chaining — Improvement Suggestion Connection

Immediately after Step 3 output, if **"FH Immediate Application Candidates"** has 1+ items, automatically suggest one of the following:

### 4-a. FH Skill/Structure Improvement Suggestion (default)

```
💡 Improvement candidate found — would you like to connect to:

  [1] /field-harvest       — absorb above candidates into FH skills/plugins
  [2] /meta-prompt-builder — write immediate candidates as skill prompts
  [3] Save fh_signal       — record signal to tracks/_meta/fh_signal_{today}.md
  [4] persona-innovator    — run innovator agent against candidates (naming/framing proposals + gap analysis)
  [5] Skip (insights only for now)
```

**→ When to use [4] persona-innovator**: Frontier candidates contain new architectural patterns, naming opportunities, or design frames not yet in FH vocabulary. persona-innovator compares the external signal against existing FH assets and proposes concrete naming/framing actions. Runs as Mode E (external scan) with the frontier candidates as input context.

If user selects [3], create the signal file (format in §Output-Formats).

### 4-b. Connected Project Improvement Suggestion (when context detected)

If keywords related to user projects appear in collected data:

```
📌 [Project name] related signal detected — would you like to forward insights to that project?
  e.g.: "QA testing automation" paper → can connect to your-project
```

### 4-c. Automatic Chaining (--chain flag)

When running `/frontier-digest --chain`:
1. Auto-save immediate application candidates as fh_signal file (with `--save`)
2. Auto-invoke `persona-innovator` Mode E with candidates as input — extracts naming/framing proposals (no user prompt needed)
3. Auto-propose `field-harvest` skill with persona-innovator output as context (with user approval gate)

---

## Done When

| Condition | Completion |
|---|---|
| Step 3 synthesis result printed in conversation | ✅ Basic execution complete |
| With `--save` flag: `✅ Saved: {path}` confirmed | ✅ Save complete |
| With `--chain` flag: persona-innovator Mode E invoked + field-harvest proposed | ✅ Chaining complete |
| All curl failures → fallback to WebSearch synthesis output | ✅ Fallback complete |

**Incomplete**: Exiting without collection + synthesis output = Fail. `--save` invoked but no file = Fail.

**→ Auto-propose chain when 1+ Immediate Application Candidates found (without --chain flag):**
Present Step 4 menu options [1]–[5]. Do not skip to [5] silently — surface the chain options even for basic runs.

---

## Simplification Guards

- Video Tier-3 probe fails (any of `yt-dlp` / `curl_cffi` / `ffmpeg` missing, or timedtext returns 429) → fall through to operator summary; never assume `yt-dlp` works
- If 3+ arxiv queries fail, proceed with HN only (do not abort)
- On curl timeout, skip that item and continue with the rest
- If synthesis result exceeds 400 characters, retain top 3 items and truncate the rest
- Without `--save`, do not create files (conversation output only)

---

## External Environment Adaptation

| Environment | Behavior |
|---|---|
| ANTHROPIC_API_KEY available | Claude Sonnet auto-selected |
| No API key | WebSearch mode auto-downgrade |
| All curl blocked | WebSearch mode forced |

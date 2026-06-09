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

---

## Step 1. Data Collection

### HackerNews (Algolia API)

Collect latest stories by keyword. Via `curl`:

```bash
for KW in "AI agent" "LLM harness" "Claude" "multi-agent" "context engineering"; do
  curl -s --max-time 8 \
    "https://hn.algolia.com/api/v1/search?query=$(echo $KW | tr ' ' '+')&tags=story&hitsPerPage=5&numericFilters=points>10"
done
```

Collection criteria: score > 10, keyword-relevant items only. Max 15 items.

### arxiv

```bash
for Q in "multi-agent LLM" "AI software testing" "context engineering agents"; do
  curl -s --max-time 8 \
    "https://export.arxiv.org/api/query?search_query=all:${Q// /+}&max_results=2&sortBy=submittedDate&sortOrder=descending"
done
```

Max 6 items.

### TLDR AI (RSS)

```bash
curl -s --max-time 8 "https://tldr.tech/api/rss/ai"
```

Parse `<item>` → title + link. Max 5 items.

### The Batch — deeplearning.ai (HTML scraping)

```bash
curl -s --max-time 10 -L "https://www.deeplearning.ai/the-batch/"
```

Extract `"title":"..."` + `"slug":"issue-\d+"` pattern → URL: `https://www.deeplearning.ai/the-batch/{slug}/`. Max 5 items.

Report progress: `📡 HN 15 items · arxiv 5 items · TLDR 5 items · Batch 5 items collected`

---

## Step 2. Synthesis

### With Anthropic API

Prompt:

```
You are an AI harness engineering expert.
Analyze the collected external data below and extract insights
directly relevant to forge-harness (FH) operations and improvement.

FH Context:
- FH = AI collaboration meta-harness (skill · plugin · agent system)
- Core skills: steel-quench, harness-doctor, sim-conductor,
               agent-composer, apex-review
- Areas of interest: multi-agent orchestration, context engineering,
                     self-check gate, frontier cross-diagnosis

[Insert collected data]

Output format:
## This Week's Frontier Highlights (max 3)
**[Title]** — FH connection point in one sentence

## FH Immediate Application Candidates
2-3 specific ideas

## Warning Signals
Noise or excessive complexity alerts (if any)

Length: within 400 characters. Start directly with content, no preamble.
```

### WebSearch Mode (no API key)

Search directly with WebSearch tool, then synthesize in context:

```
Search: "AI agent harness 2025 site:news.ycombinator.com"
Search: "multi-agent LLM orchestration latest"
```

---

## Step 3. Output

Print synthesis result in the conversation:

```markdown
## 🔭 FH Frontier Digest — YYYY-MM-DD

🔑 [Engine used: Claude Sonnet / WebSearch]

## This Week's Frontier Highlights
...

## FH Immediate Application Candidates
...

## Warning Signals
...

---
📊 Collected: HN N items · arxiv N items · TLDR N items · Batch N items | [View sources →]
```

### With --save flag

```python
# Save path priority
# 1. FH install path digests/
# 2. ~/.claude/frontier-digest/digests/
# 3. current cwd/digests/

path = f"digests/frontier_{today}.md"
```

After saving: `✅ Saved: {path}`

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

If user selects [3], create signal file in this format:

```markdown
---
date: YYYY-MM-DD
source: frontier-digest
engine: [Claude Sonnet / WebSearch]
---

# FH Improvement Signal — YYYY-MM-DD

## Sources
HN N items + arxiv N items collected

## Immediate Application Candidates
[Copy Step 2 "FH Immediate Application Candidates" items here]

## Processing Status
- [ ] Pending review
```

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

## Environment Setup Guide (initial notice)

When running `/frontier-digest` for the first time without API key set:

```
🔑 No API key detected — running in WebSearch mode.

For more precise synthesis:
  Anthropic: export ANTHROPIC_API_KEY=sk-ant-xxx

To save key permanently (~/.cc_secrets pattern):
  echo 'export ANTHROPIC_API_KEY=sk-ant-xxx' > ~/.cc_secrets
  chmod 600 ~/.cc_secrets
```

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

---
name: video-ingest
description: Ingests a video's content (YouTube and similar) for agent context, routing by capability, by what the task needs, and by video length. When the task needs video understanding it prefers a natively multimodal engine that ingests the URL directly (Gemini via agy or the Gemini API, best for long video); when no such engine is present it uses Claude's own vision over ffmpeg-extracted frames (the claude-video pattern, best for short/medium, no external-runtime dependency); when the transcript alone suffices it uses yt-dlp's caption-track path; auth-gated videos fall back to the logged-in claude-in-chrome session. The governor cross-checks any multimodal comprehensive-read rather than trusting it. Reuses frontier-digest's Sidecar Engine Resolution Protocol for the capability probe. Triggered by "ingest this video", "what does this video show", "get the transcript from this YouTube video", "video-ingest".
user-invocable: true
allowed-tools: ["Read", "Bash"]
model: sonnet
---

# video-ingest — Video Content Ingestion (capability-routed)

A video carries two separable signals: the **spoken transcript** (text) and the **visual content**
(on-screen demos, slides, UI). Captions give only the first. So the route is chosen by **what the task
needs** × **what engine is available** × **video length** — not a single fixed path. This reuses
frontier-digest's capability-over-engine logic and adds on-demand, need-based routing, a Claude-native
frame path, output normalization, and a governance cross-check.

FH's increment over a raw video executor (sister asset `claude-video`, github bradautomates/claude-video;
cross-audit note in a private companion store): the executors *watch*; FH **governs** — the
governor never trusts a multimodal "comprehensive read" at face value, it cross-checks claims against the
transcript / a second pass. Same compose pattern as the other FH↔executor pairs.

## Triggers

- "ingest this video" · "what does this video show / demonstrate"
- "get the transcript from this YouTube video" · "pull the captions from <URL>"
- "summarize what's on screen in this video"
- "video-ingest"

## Step 0 — What does the task need? (picks the tier)

- **Video understanding** (visual: demos, UI walkthroughs, slides, anything not in the spoken words)
  → a vision path (Tier 1a or 1b below). Captions miss the screen.
- **Transcript only** (spoken words suffice — a talk, an interview) → go straight to **yt-dlp** (Tier 3);
  do not spend a vision engine when text is all that's needed (cost guard).

## Step 1 — Capability + length probe, then tier ladder (REUSE the probe — do not re-specify)

Resolve the engine by **capability, not name**, via frontier-digest's **Sidecar Engine Resolution
Protocol** (`plugins/fh-meta/skills/frontier-digest/SKILL_detail.md §Video-Harvest` — single source of
the probe commands). **Length is the 2nd axis** (claude-video is sparse past ~10min). The ladder:

- **Tier 1a — native multimodal, URL-direct (best for LONG video)**: an engine that watches the video and
  returns spoken + visual detail, no frame cap. Verified: **Gemini ingests a YouTube URL directly**
  (returns verbatim dialogue AND on-screen detail). Probe for a live route — the direct `gemini` CLI is
  EOL (2026-06-18), so probe `agy` / the Gemini API. **Caveat (measured)**: a *YouTube URL* works, but an
  **arbitrary (non-YouTube) stream is not reachable headless** (needs file upload) — degrade for those.
- **Tier 1b — Claude-native frame extraction (Claude-only; SHORT/MEDIUM ≤~10min)**: when no external
  multimodal engine is present, do not give up on visual content — `ffmpeg` extracts frames (auto-scaled,
  cap ~2fps/100 frames) → **Claude's own vision via Read** reads them as images (the claude-video
  pattern). No separate runtime, **no Gemini-EOL exposure**. Caution: claude-video itself is a 3rd-party
  executable (brew installs + optional Whisper egress) — if invoking it directly, review first; the
  ffmpeg+Read mechanism can also be run inline without it.
- **Never route video to a coding-agent CLI** (codex, a non-multimodal model) — burns tokens, recovers
  only metadata.
- **Tier 3 — yt-dlp transcript** (text only; conditional — probe first, never assume):
  ```bash
  yt-dlp --no-update --skip-download --write-auto-subs --sub-langs en \
    --sub-format json3 -o "/tmp/yt_%(id)s.%(ext)s" "<URL>"
  python3 -c "import json,sys,re;d=json.load(open(sys.argv[1]));print(re.sub(r'\s+',' ',' '.join(s.get('utf8','') for e in d['events'] for s in e.get('segs',[]) if s.get('utf8','').strip())).strip())" /tmp/yt_<id>.en.json3
  ```
  `--write-subs` (human captions) preferred when present. Keep yt-dlp current (`pip install -U yt-dlp`;
  version/impersonation warnings are non-blocking). yt-dlp also supplies the transcript the governor
  cross-checks a Tier-1 visual read against.
- **Auth-gated** (members-only / age-gated) → **claude-in-chrome** (operator's logged-in session).
  video-ingest **surfaces this route as a handoff** — it does not drive the browser itself (the
  `mcp__claude-in-chrome__*` tools are outside this skill's `allowed-tools`). Caveat: needs the Anthropic
  "direct" plan — unavailable on a corp Bedrock laptop; surface the limit, do not loop.
- **Unresolvable** (no vision engine, yt-dlp probe fails, not auth-fixable) → operator summary remains the
  path; say so plainly.

## Step 1.5 — Governance cross-check (FH's increment; do not skip on a multimodal read)

A Tier-1 engine's "comprehensive read" is a **self-report**, untrusted like any sidecar output. The
governor cross-checks its key claims against the transcript (Tier 3) or a second targeted frame pass
before accepting; a visual claim that contradicts the transcript or cannot be re-grounded is flagged, not
relayed as fact. (This is the governance claude-video has no equivalent for.)

## Step 2 — Normalize + hand off

Write clean text (+ visual notes if Tier 1) and metadata (video id, title, duration, source: multimodal
vs transcript, caption type human/auto) to a predictable path (`/tmp/yt_<id>_ingest.txt` or a
caller-specified path). Downstream grounding ingest is `corpus-grounding-expander`'s job — video-ingest
produces the artifact, it does not ingest into a store.

## Done When

- Output artifact written AND character count > 0 (or a specific failure reason surfaced). *[measured]*
- Tier chosen matches the task need × the live capability probe × length (video-understanding → Tier 1a
  for long / Tier 1b for short-medium; transcript-only → yt-dlp). *[judged, pair: the probe is the
  mechanical anchor]*
- A Tier-1 multimodal comprehensive-read was cross-checked against the transcript / a second pass before
  its claims were relayed as fact. *[judged, pair: transcript diff is the mechanical anchor]*
- On failure, a specific reason is surfaced (no-captions / auth-required / no-vision-engine /
  arbitrary-stream-headless-unreachable) — never a silent empty result. *[mandatory-pass]*

## Guards

- **No-reinvention** — the capability probe + tier ladder are frontier-digest's Sidecar Engine Resolution
  Protocol (single source); the executors are yt-dlp (Bash), the Gemini path, ffmpeg+Read (claude-video
  pattern), and claude-in-chrome (MCP). This skill routes by need × length, cross-checks, normalizes, and
  reports — it builds no caption engine, no frame extractor, no browser automation.
- **Governor never trusts a multimodal self-report** — Step 1.5 cross-check is FH's increment over a raw
  video executor; a visual claim is grounded before it is relayed.
- **Capability over engine name** — probe what an engine can actually do (EOL/availability drifts);
  never assume `gemini`/`agy`/`yt-dlp`/`ffmpeg` is present.
- **Cost guard** — transcript-only need never spends a vision engine.
- **3rd-party executable caution** — claude-video (brew installs + optional Whisper egress) is reviewed
  before install; the ffmpeg+Read mechanism can run inline without adopting the whole tool.
- **Corp-host honesty** — when a path is unavailable (Bedrock laptop, EOL CLI, headless-stream limit),
  state it; do not loop on a path that cannot run.

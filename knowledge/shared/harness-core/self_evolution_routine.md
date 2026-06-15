# Self-Evolution Routine — Remote Daily/Weekly Innovator Loop

> **What this is**: a paste-ready Claude Code **Routines** configuration that runs `frontier-digest` +
> `persona-innovator` on a remote schedule, accumulating frontier signals daily and proposing one
> concrete FH improvement weekly — **as a draft PR for human merge, never auto-merge**.
>
> **Governance stance (proposal-type, HITL-preserving)**: the routine *runs* autonomously; the
> decision to *adopt* an improvement stays with the operator. This keeps the
> `feedback_no_personal_commit_to_shared_repo` spine intact even though Routine sessions execute with
> no approval prompts. See §3.

## 1. Why a routine (and why this shape)

Claude Code on the web supports **Routines** (`code.claude.com/docs/en/routines.md`): a saved
prompt + repo + connectors that runs automatically on a **schedule** (≥1h interval), a **GitHub
event**, or an **HTTP API** call. Each run is a fresh, ephemeral cloud session — no local state
survives, the container is reclaimed, and by default it may only push to `claude/`-prefixed branches.

Three platform facts shape the design below:

| Platform fact | Consequence for this loop |
|---|---|
| Runs are **ephemeral** (fresh clone each time) | Cross-run memory cannot live in the working tree — it lives on **GitHub** (issue comments / draft PR). |
| `tracks/**` is **gitignored** (public mirror = methodology only) | Daily digests **must not** be committed to `tracks/_meta/` — they would be dropped by git and lost on reclaim. Durable store = a standing GitHub Issue. |
| Routine sessions run with **no approval prompts** | "Self-improvement" must be **gated by a draft PR**, not auto-merged — the human merge IS the HITL gate. |

## 2. Architecture — Daily scan, Weekly propose

```
[Daily Routine]  (schedule: daily, model: sonnet)
  frontier-digest autonomous collection (HN + arxiv; operator-intake arm skipped — no human in loop)
    → post the digest as a COMMENT on the standing Issue "🛰️ Frontier Digest Log"
    → no repo commit, no PR   (cheap, ephemeral-safe)

[Weekly Routine]  (schedule: weekly, model: OPUS — required, see §4 floor note)
  ① read the last 7 days of comments on the "🛰️ Frontier Digest Log" issue
  ② persona-innovator Mode F — gap + external-frontier scan against current FH assets
  ③ pick AT MOST ONE concrete, scoped improvement candidate (or none — "no proposal this week" is valid)
  ④ install + run the FH 4-axis gate on the change (see §4)
  ⑤ commit to a fresh  claude/frontier-auto-{YYYY-MM-DD}  branch → open a **DRAFT PR**
  ⑥ STOP.  The operator reviews and merges.   ← HITL gate
```

**Why the daily/weekly split** (not "daily full"): FH's own cadence is 7-day for `frontier-digest`
and event-bound for `persona-innovator` — a daily full synthesis would tax tokens and risk
decorative-unit over-generation (the exact failure `steel-quench` Wave-1 #1 attacks). Daily =
cheap signal accumulation; weekly = one considered proposal.

## 3. Governance guards (do not weaken)

- **Draft PR only — never merge.** The weekly routine opens a *draft* PR and stops. Auto-merge would
  bypass `feedback_no_personal_commit_to_shared_repo`.
- **One proposal per week, or none.** "No proposal this week" is a valid, preferred outcome over a
  forced low-value change. Promotion of `persona-innovator` itself is *measured* (accepted ≥ 60% gate,
  `operations.md`) — the draft-PR accept/reject history IS that pilot data.
- **`claude/` branch prefix only.** Do not enable "unrestricted branch pushes" for this routine.
- **Methodology mirror stays clean.** Daily digests live on the GitHub Issue, never in `tracks/**`
  (gitignored) and never committed to the methodology tree.
- **Cost ceiling.** Both arms run `WebSearch`/`WebFetch`. Daily draws subscription usage and counts
  against the per-account routine daily cap; keep the daily prompt to collection-only.

## 4. The 4-axis gate inside the weekly routine

Because a fresh clone does **not** install the FH pre-commit hook, the weekly routine must install and
run it before committing an FH-asset change:

```bash
git config core.hooksPath templates/.git-hooks && chmod +x templates/.git-hooks/pre-commit
bash templates/regression_guard.sh --pr "$(git branch --show-current)"   # Axis 1
# Axis 2 steel-quench + Axis 3 phantom-quench → write tracks/_meta/.axes_23_passed_{branch}_{date}.marker
# Axis 4 edit-manifest RECORD → append today's predicted-impact line to tracks/_meta/edit_manifest.yaml
```

**Floor note — why the weekly routine MUST be opus (load-bearing).** The pre-commit hook cross-checks
the marker's `axis2-model` against `floor-status`: a `sonnet`/`haiku` model claiming `at-floor` or
`above-floor` is **rejected**, and `below-floor` is rejected too **unless** a `below-floor-ack:` line
quotes a live operator utterance. A routine runs with **no human online**, so there is no utterance to
quote — meaning a Sonnet weekly run **cannot legally pass the gate and cannot commit**. That dead-end
is itself a hazard: under "produce a draft PR" pressure a session may improvise an unsanctioned escape
(fabricate an ack, mislabel the floor, `--no-verify`). **Pin the weekly routine to opus** so the
honest marker is `floor-status: at-floor` and the gate passes unattended. (If opus is ever unavailable
in routines, the sanctioned fallback is: do **not** commit — attach the proposed patch to a draft PR
opened via the GitHub tools as a diff in the PR body / a patch file, bypassing the local hook, and
label it `gate: deferred — opus re-run needed` for the operator. Never `--no-verify`.)

**Marker carve-out (the one sanctioned `tracks/**` write).** The two gate files
(`tracks/_meta/.axes_23_passed_*.marker` and `tracks/_meta/edit_manifest.yaml`) live under gitignored
`tracks/**` and are **never committed** — the hook reads them from the **working tree**, which
persists for the duration of the run. The §3 "no `tracks/**`" guard is about *committing the digest*,
not these working-tree gate markers.

If `steel-quench`/`phantom-quench` are unavailable in the routine session, note
`Axis N: skipped (skill unavailable)` — Axis 1 PASS alone unblocks a *draft* PR (Axes 2–3 are the
operator's residual at merge review).

## 5. Setup steps (operator, one-time)

1. **Standing issue** — create one GitHub issue in `chrono-meta/forge-harness` titled
   `🛰️ Frontier Digest Log`, label `frontier-digest`. (Can be auto-created; see §6.) This is the
   durable daily store.
2. **Daily Routine** — at `claude.ai/code/routines` → New routine:
   - Repo: `chrono-meta/forge-harness`
   - Schedule: daily (pick a low-traffic hour)
   - Model: sonnet
   - Prompt: paste **§7 Daily prompt** (replace every `{ISSUE}` with the issue number from step 1 before saving)
3. **Weekly Routine** — New routine:
   - Repo: `chrono-meta/forge-harness`
   - Schedule: weekly
   - Model: **opus (required — see §4 floor note; a Sonnet weekly run cannot pass the commit gate)**
   - Prompt: paste **§7 Weekly prompt**
   - **Before saving**: replace every `{ISSUE}` in the prompt with the actual issue number from step 1.
4. **Network policy**: default "Trusted" allows HN/arxiv/web search. No change needed unless you add
   walled sources.
5. **Connectors**: keep the GitHub connector; remove others to reduce surface.

## 6. Auto-bootstrap (optional)

The standing issue can be created from a normal session in FH cwd via the GitHub MCP tools (issue
title `🛰️ Frontier Digest Log`, body = "Daily frontier-digest comments accumulate here; the weekly
routine reads the last 7 days."). The two Routines themselves must be created in the web UI — there is
no documented API to define a routine from inside a session (only to *fire* an existing one).

## 7. Paste-ready routine prompts

> These are **self-contained** — a fresh Routine session sees no prior context. Each restates its full
> task. `{ISSUE}` = the "🛰️ Frontier Digest Log" issue number.

### 7-a. Daily prompt

```
You are the FH self-evolution DAILY scan, running as an autonomous Claude Code routine in a fresh
clone of chrono-meta/forge-harness. There is no human in the loop and no prior context.

Task — collect, do NOT modify the repo:
1. Read plugins/fh-meta/skills/frontier-digest/SKILL.md and run its AUTONOMOUS collection arm only
   (HackerNews + arxiv). Let SKILL.md Step 0 resolve the engine itself — it prefers the /deep-research
   built-in (Priority 0: staged gather + cross-check + cited synthesis) if it is in this session's
   skill list, then ANTHROPIC_API_KEY/Sonnet, then plain WebSearch. Do not force an engine. SKIP the
   Step 0.5 operator-intake question — there is no operator online.
2. In this sandbox expect WebSearch mode (no ANTHROPIC_API_KEY, so the SKILL's API-synthesis arm is
   unavailable) — YOU, the session model, do the synthesis in-context from the WebSearch results.
   Produce a short digest: 3–6 bullets of frontier signals relevant to FH skills/structure, each with
   a source URL and a one-line "relevance to FH" note.
3. Post the digest as a COMMENT on issue #{ISSUE} ("🛰️ Frontier Digest Log") using the GitHub tools.
   Title the comment with today's date.
4. Do NOT commit, do NOT push, do NOT open a PR. Daily is collection-only.
Stop after posting the comment.
```

### 7-b. Weekly prompt

```
You are the FH self-evolution WEEKLY proposer, running as an autonomous Claude Code routine in a fresh
clone of chrono-meta/forge-harness. No human is online during the run. Your output is a DRAFT PR for
later human review — you must NOT merge anything.

Task:
1. Read the last 7 days of comments on issue #{ISSUE} ("🛰️ Frontier Digest Log") via the GitHub tools.
   These are the week's accumulated frontier signals.
2. Dispatch the persona-innovator agent (plugins/fh-meta/agents/persona-innovator.md) in Mode F
   (gap + external-frontier scan) against the current FH assets and those signals. If sub-agent
   dispatch is unavailable in this runtime, run it INLINE: read the agent file and execute its Mode F
   steps in this session.
3. Select AT MOST ONE concrete, well-scoped FH improvement. THE BAR: the candidate must name a
   SPECIFIC FH asset (file + section) AND cite a SPECIFIC signal URL from this week's issue comments.
   If you cannot cite both, post a comment on #{ISSUE} saying "No proposal this week — signals logged"
   and STOP. A no-op week is the PREFERRED outcome when the bar isn't met (it is also pilot data: it
   shows the bar holds). A forced low-value PR costs the operator a review and erodes trust — when in
   doubt, no-op.
4. If you have one improvement, implement it minimally on a NEW branch named
   claude/frontier-auto-<today's date>.
5. Run the FH 4-axis gate before committing:
   - git config core.hooksPath templates/.git-hooks && chmod +x templates/.git-hooks/pre-commit
   - bash templates/regression_guard.sh --pr "$(git branch --show-current)"   (Axis 1, must PASS)
   - Axis 2 steel-quench + Axis 3 phantom-quench if available → write the
     tracks/_meta/.axes_23_passed_<branch>_<date>.marker with fields axis2-engine / axis2-model /
     floor-status / axis2-evidence. If a skill is unavailable, note "skipped (skill unavailable)".
   - Axis 4: append a one-line predicted-impact entry to tracks/_meta/edit_manifest.yaml.
6. Commit (the hook enforces the gate), push the claude/frontier-auto-* branch, and open a DRAFT pull
   request titled "frontier-auto: <one-line summary>" describing the signal it came from and the
   predicted impact.
7. Do NOT mark the PR ready, do NOT merge. STOP after opening the draft PR.
```

## 8. Field-project adoption — any user, any project (e.g. QASP)

The loop is **not FH-only**. Anyone accelerating their own project — or the operator on a field project
like QASP — can adopt the same shape. Only **two things are FH-specific and must be swapped**; the rest
is project-agnostic.

| Layer | FH (this doc) | Field-project version |
|---|---|---|
| Daily scan lens | "frontier signals relevant to FH skills/structure" | "...relevant to **{project}'s domain/stack**" (QASP → QA automation, TC quality, MCP/JIRA frontier) |
| Durable daily store | `🛰️ Frontier Digest Log` issue in `forge-harness` | same pattern, an issue in the **project's own repo** |
| Weekly verification gate | **FH 4-axis gate** (hub-internal hook — hard-codes hub paths/markers) | **the project's OWN gate** — NOT the FH hook (per `auto_project_mapping.md §6`, the FH gate is deliberately not installed into projects; it would block the project's commits). QASP → `pytest -q` + **Self-Check Gate 33/33** + `regression_guard.sh`; a generic project → its test suite + lint |
| HITL spine | draft PR → operator merge | **identical** — draft PR → owner merge (never auto-merge) |
| Branch | `claude/frontier-auto-*` | **identical** — `claude/`-prefixed |

**The invariant (do not change across projects)**: daily = cheap signal accumulation to a GitHub
issue; weekly = at most one scoped proposal as a **draft PR**, gated by *whatever verification that
project trusts*, merged by a human. Substitute the lens + the gate; keep the ephemeral-safe GitHub
store and the draft-PR HITL.

**For QASP specifically**: the weekly proposer's gate is the project's own — run `pytest -q` and the
33/33 Self-Check Gate (`docs` references in qasp CLAUDE.md) instead of the FH marker/hook, and the
model floor concern (§4) does **not** apply (no FH marker = no `floor-status` cross-check), so the
weekly QASP routine can run on sonnet. Open the draft PR against the qasp repo's `claude/` branch.

**Propagation path**: this pattern can ride **Full-Harness Mode** (`auto_project_mapping.md §6`) as an
opt-in project-local asset — offered, never auto-installed, owner approves each routine. It is a
*recommendation surface*, not a daemon dropped into the project.

## 9. Honest limits

- **Research preview**: Routines' limits/API may change; GitHub webhook + daily caps apply.
- **Salience-dependent**: these prompts are prose the routine session must follow; on a weaker model
  the gate/draft-only discipline can slip. Mitigation: the prompts restate the hard guards inline, the
  weekly arm is opus-pinned (§4), and the `claude/`-branch-only default makes an accidental
  protected-branch write impossible **while that restriction stays on** — do not disable it (§3).
- **innovator is v0.2** (no pilot data). This loop is the mechanism that *produces* that data via the
  draft-PR accept/reject record — treat early proposals as candidates, not authority.

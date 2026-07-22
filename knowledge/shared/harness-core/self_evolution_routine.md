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

[Weekly Routine]  (schedule: weekly, model: opus preferred / sonnet first-class, see §4 floor note)
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
- **Cite-verify (PR #112 lesson, 2026-06-22) — do not weaken.** Any citation / source / version claim
  the weekly change *introduces into an FH asset* (distinct from citing the signal URL) must be
  WebSearch-verified before commit. Unverifiable → omit it or mark `(unverified)`; never ship a
  plausible-sounding but unchecked citation. **Origin**: a weekly run added a fabricated "O'Reilly AI
  Agents Stack 2026" citation (+ an over-specific "~32K" threshold) that reached draft PR #112; the
  merger caught it via WebSearch (real source = Chroma 2025), but **Axis 3 phantom-quench is
  "if available"** in the routine sandbox, so the prompt must enforce cite-verify directly — the gate
  cannot be relied on for it.

## 4. The 4-axis gate inside the weekly routine

Because a fresh clone does **not** install the FH pre-commit hook, the weekly routine must install and
run it before committing an FH-asset change:

```bash
git config core.hooksPath templates/.git-hooks && chmod +x templates/.git-hooks/pre-commit
bash templates/regression_guard.sh --pr "$(git branch --show-current)"   # Axis 1
# Axis 2 steel-quench + Axis 3 phantom-quench → write tracks/_meta/.axes_23_passed_{branch}_{date}.marker
# Axis 4 edit-manifest RECORD → append today's predicted-impact line to tracks/_meta/edit_manifest.yaml
```

**Floor note — dispatch-first, Sonnet first-class (re-semanticized 2026-07-10, Sonnet-Floor
Doctrine).** The pre-commit hook cross-checks the marker's `axis2-model` against `floor-status`.
The routine's honest, unattended paths in preference order:
1. **Dispatch the Axis-2 audit** (cross-family sidecar or an opus sub-agent, consent permitting) —
   marker is `floor-status: at-floor` with the dispatched engine recorded; strongest and preferred.
2. **Opus inline** (when the routine session itself runs at opus) — `at-floor`, as before.
3. **Sonnet inline** — first-class, no operator utterance needed: `floor-status: sonnet-floor` +
   an `axis2-anchor:` line naming the mechanical evidence that grounds the judged verdict (a
   regression test, scan output, probe count). The marker auto-enters the weekly re-validation
   queue (`below_floor_scan.sh`, R-tier advisory). The old dead-end — "a Sonnet run cannot legally
   commit, so it improvises an escape" — is gone *because* the sanctioned lane exists; the anchor
   requirement is what keeps the lane from being a free pass.
Sub-Sonnet tiers remain `below-floor` + operator ack (a routine with no human online genuinely
cannot pass there — that residual is intended). If no anchor can be produced at Sonnet either, the
fallback stays: do **not** commit — attach the patch to a draft PR opened via the GitHub tools,
label it `gate: deferred — floor re-run needed`. Never `--no-verify`.

**Marker carve-out (the one sanctioned `tracks/**` write).** The two gate files
(`tracks/_meta/.axes_23_passed_*.marker` and `tracks/_meta/edit_manifest.yaml`) live under gitignored
`tracks/**` and are **never committed** — the hook reads them from the **working tree**, which
persists for the duration of the run. The §3 "no `tracks/**`" guard is about *committing the digest*,
not these working-tree gate markers.

If `steel-quench`/`phantom-quench` are unavailable in the routine session, note
`Axis N: skipped (skill unavailable)` — Axis 1 PASS alone unblocks a *draft* PR (Axes 2–3 are the
operator's residual at merge review).

> ⚠️ **"Axis 1 PASS" 는 종료코드로 판정하지 마라.** `regression_guard.sh` 의 `exit 0` 은
> **PASS 와 SKIP 을 둘 다** 뜻한다 — SKIP 은 "게이트 pathspec 에 걸린 파일이 없었다"이지
> "검사했고 괜찮다"가 아니다. 무인 루틴이 종료코드만 보면 **미검사가 draft PR 을 unblock 한다.**
> 구분: stdout 에 `REGRESSION_GUARD_RESULT=skip` 이 있으면 SKIP 이다 — 그 경우 Axis 1 은
> *통과가 아니라 미실행*이므로 Axes 2–3 과 같은 운영자 잔여로 올려라.
> (2026-07-22 실측: `pre-commit` 이 정확히 이 혼동을 일으켜 AGENTS.md 변경이 `✅ PASS` 를
> 받고 지나갔다. `pre-commit` 은 배선 완료 · 이 루틴을 포함한 나머지 소비자는 **미배선 잔여**.)

**Skip-visibility at the handoff (load-bearing for honest HITL escalation).** When Axis 2
(challenger / steel-quench) is skipped, the adversarial check did not run autonomously — it becomes
the *merger's* responsibility. An intelligent hand-off must make that visible at the hand-off point,
not bury it. So the draft PR opened by the weekly routine MUST carry a top-of-body label whenever
Axis 2 was skipped: `⚠️ Axis 2 (adversarial/challenger) NOT RUN this routine — adversarial review is
the merger's before merge.` A silent skip turns the draft PR into an unchallenged proposal wearing a
"gate passed" coat; the label keeps the escalation honest. (Axis 2 *passing* needs no such label — the
marker already records `axis2-engine`/`axis2-evidence`.)

**Merge-side citation residual (auto-PR cite floor — 2026-06-22 harvest-loop).** §3's cite-verify is
the *generator-side* half; this is the *merger-side* redundancy. Because the routine sandbox runs
phantom-quench only "if available" (line above) and **no CI job runs phantom-quench at the merge
boundary** (the merge-time mechanical gates are `regression-guard.yml` Axis 1 + `validate.yml`
token/JSON/count only), the citation check on an auto-authored (`claude/`-branch) PR is the **merger's
explicit, non-skippable residual** — not a mechanical gate. *Honest scope: this is judged prose, not a
CI check.* Obligation: before merging any auto-authored PR that **adds a citation / URL / version
claim**, run phantom-quench on that citation surface (or WebSearch-verify it directly); a fabricated
citation reaching `main` is the failure this closes (origin: PR #112's "O'Reilly AI Agents Stack 2026"
phantom — the human merger was the only catch).

> **Measured-trigger → CI escalation (do not build the CI gate speculatively).** One occurrence (PR
> #112) is N=1, below `operations.md`'s N=3 recurrence threshold for instrumenting a defect class as a
> CI probe. So the fix today is the prose residual above, **not** a workflow. **If an auto-PR phantom
> citation recurs (N≥2 toward N=3)**, escalate to a real mechanical gate: a CI job (extend
> `validate.yml` or a new workflow) that greps `claude/`-branch PR diffs for added citation tokens and
> **fails** unless phantom-quench evidence is attached. Until that recurrence is measured, a prose
> checklist is the right weight — calling it "mechanical" now would be the gate-locality error in
> reverse (a decorative gate nobody's traffic justifies). See `[[measurement-integrity-checklist]]` for
> the sibling "instrument-before-trusting" discipline.

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
   **CITE-VERIFY (mandatory — distinct from step 3's signal URL):** if your change introduces ANY
   citation, source name, version, benchmark number, or "per <source> <year>" claim INTO an FH asset,
   WebSearch-verify it FIRST. If you cannot confirm the exact source, OMIT it or write "(unverified)" —
   never ship a plausible-but-unchecked citation. A fabricated citation in an FH asset is a phantom;
   Axis 3 (phantom-quench) may be skipped in this sandbox, so this step does NOT depend on the gate.
   (This guard exists because a prior run shipped a fabricated "O'Reilly AI Agents Stack 2026" cite to
   PR #112 — real source was Chroma 2025.)
5. Run the FH 4-axis gate before committing:
   - git config core.hooksPath templates/.git-hooks && chmod +x templates/.git-hooks/pre-commit
   - bash templates/regression_guard.sh --pr "$(git branch --show-current)"   (Axis 1, must PASS)
   - Axis 2 steel-quench + Axis 3 phantom-quench if available → write the
     tracks/_meta/.axes_23_passed_<branch>_<date>.marker with fields axis2-engine / axis2-model /
     floor-status / axis2-evidence. If a skill is unavailable, note "skipped (skill unavailable)".
   - Axis 4: append a one-line predicted-impact entry to tracks/_meta/edit_manifest.yaml.
6. Commit (the hook enforces the gate), push the claude/frontier-auto-* branch, and open a DRAFT pull
   request titled "frontier-auto: <one-line summary>" describing the signal it came from and the
   predicted impact. IF Axis 2 (challenger/steel-quench) was skipped (skill unavailable), the FIRST
   line of the PR body MUST be: "⚠️ Axis 2 (adversarial/challenger) NOT RUN — adversarial review is
   the merger's." Do not bury the skip — the merger has to know the proposal is unchallenged.
7. Do NOT mark the PR ready, do NOT merge. STOP after opening the draft PR.
```

## 8. Field-project adoption — any user, any project

The loop is **not FH-only**. Anyone accelerating their own project — or the operator on any mapped field
project — can adopt the same shape. Only **two things are FH-specific and must be swapped**; the rest
is project-agnostic.

| Layer | FH (this doc) | Field-project version |
|---|---|---|
| Daily scan lens | "frontier signals relevant to FH skills/structure" | "...relevant to **{project}'s domain/stack**" |
| Durable daily store | `🛰️ Frontier Digest Log` issue in `forge-harness` | same pattern, an issue in the **project's own repo** |
| Weekly verification gate | **FH 4-axis gate** (hub-internal hook — hard-codes hub paths/markers) | **the project's OWN gate** — NOT the FH hook (per `auto_project_mapping.md §6`, the FH gate is deliberately not installed into projects; it would block the project's commits). A project supplies its own: its test suite + lint + whatever quality gate it trusts |
| HITL spine | draft PR → operator merge | **identical** — draft PR → owner merge (never auto-merge) |
| Branch | `claude/frontier-auto-*` | **identical** — `claude/`-prefixed |

**The invariant (do not change across projects)**: daily = cheap signal accumulation to a GitHub
issue; weekly = at most one scoped proposal as a **draft PR**, gated by *whatever verification that
project trusts*, merged by a human. Substitute the lens + the gate; keep the ephemeral-safe GitHub
store and the draft-PR HITL.

**For a field project**: the weekly proposer's gate is the project's own — run the project's test
suite and its own quality gate instead of the FH marker/hook, and the model floor concern (§4) does
**not** apply (no FH marker = no `floor-status` cross-check), so a field project's weekly routine can
run on sonnet. Open the draft PR against the project repo's `claude/` branch.

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

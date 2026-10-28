# forge-harness — Persistent Knowledge Hub (resident core)

> Operational ruleset for AI (Claude Code). Humans: `README.md` · first-time "how do I use this": `docs/USER_GUIDE.md`.
> **This file keeps only what must fire before anything is read — intent-triggered rules with no file trigger and no hook.**
> Everything else lives in `knowledge/shared/harness-core/claude_md_full_reference.md` (the full previous ruleset, section names unchanged) and in skills. **A reference elsewhere to `CLAUDE.md §X` where §X is not a heading here means `claude_md_full_reference.md §X`.** When a rule below says **Read X**, read it before acting — a summary is not the rule.

## Identity — Governance Engineering First
FH is **governance engineering**: drive error rates down, *and* hold the surfaces where no number buys passage (publish · delete · history-rewrite). A harness machinizes intent: intent → forge → agreement (HITL) → machinery. FH is the meta-harness and nursery for field harnesses. Running Claude Code here = **Control Tower** mode.
Method: 3-stage process (success definition first → decorrelated parallel acceleration → 6-axis burn-in). Canon: `knowledge/shared/harness-core/fh_three_layer_canon.md`.

## Voice / Tone
Reply in the user's language and register (Korean → match 반말/존댓말 of their last message; never drift within a session). This covers **everything the user sees in a turn**, progress notes between tool calls included — that is where drift happens, mid-turn after long tool work and right after compaction; English stays in commit messages, code and agent prompts (a UserPromptSubmit hook restates it on each mostly-Hangul message). A local pin sets register, never language. Warm words, plain judgment: a softer tone never relaxes verification. Disagree plainly when the work calls for it.

## Judgment rules that have no hook (Mechanization Boundary · Skeleton · Instrument Calibration · Local Execution · Envelope-Boundary)
- **Machinery only at irreversible edges and channels; judgment stays judgment.** A check may assert a property of the record (present · typed · attributable), not a conclusion.
- **Done = fires at the floor tier.** A rule/trigger/onboarding change is done when a blind Sonnet session, not told what is tested, actually does it. Self-dispatch that sim; reading your own text is not evidence.
- **Calibrate instruments on a known pair** (one known-positive, one known-negative) before trusting or *saying* any number, and open the one result it is most sure of. Cannot calibrate → label it `UNCALIBRATED`, never a verdict. Not measured ≠ 0. An absence claim is «N of N relevant channels opened, none has it» — or it is scoped to the channels named.
- **Local execution first**: run the target's suite locally to completion before pushing; CI confirms, it does not discover.
- **Do not normalize the unfamiliar** to an existing box before testing what it is (reinvention reflex counterweight).
- **No reinvention**: a platform built-in that covers the need outranks an FH skill. Map: `knowledge/shared/harness-core/builtin_capability_map.md`.
- **Company residency is absolute**: raw company source, secrets, hostnames, internal names and unredacted findings never leave this machine — not to another model of any family, a browser tool, a log or a paste. Exceptions need explicit operator approval and a gitignored note.
- **New design or framework extension**: read `claude_md_full_reference.md §Core Reference Documents` first. Identity grades come only from `ship_readiness_gate.md`.
- **Shrinking a card, memory or resident text**: everything removed is either logged done or named as dropped — silent loss is the defect.

## Active Onboarding Protocol (fires on a bare greeting in any language, or "resume / continue / where were we / what is this / what can you do / first time here")
Read `knowledge/shared/harness-core/fh_detail_protocols.md` before Step 1. Branch test is mechanical: `bash scripts/mapped_tracks.sh` → `onboarding_branch=new|returning|UNKNOWN` (UNKNOWN is not new; metadata such as branch names is never the trigger). Render every line, door labels included, in the greeting's language; «FH» stays untranslated. One door per line. Open with 🐿️ and the welcome line on the same line.

New user:
> 🐿️  **Welcome to FH.** *Looks like you're new here! What would you like to do?*
> - **①  Create your first project** — guided
> - **②  Map an existing project**
> - **📖  Read the guide / ask me anything**
>
> *…and I can run `/install-wizard` to finish initial setup.*

Returning user (operator with FH-dev state: welcome line = **"The FH operator — good to see you."**):
> 🐿️  **Welcome back to FH.** *What would you like to start?*
> - **①  Map a project**
> - **②  Create a new project**
> - **③  Accelerate or diagnose a mapped project** (work · Full-Harness · skills/agents/plugins · 진단) — {field candidates}
> - **④  Cross-project synergy**
> - **📖  Guide / Q&A**
>
> *…and when you're done, say **"wrap up"** — what you did lands in the session card, and the next session starts from there instead of from scratch.*

④ only with 2+ project tracks. With FH-dev state, add an unnumbered last row `- **🔧  FH self-development** — {FH worklist}`. 📖 = print the path of `docs/USER_GUIDE.md` + a 3-line outline, never the whole file. The door set, markers and the English welcome lines are anchors for downstream forks: keep their meaning and order, translate the labels. An explicit task skips the menu but never the companion-store load. If `~/.cc_sentinels/{repo}_wizard_done` is absent, add one line suggesting `/install-wizard`.

## Irreversibility Gates — Surface-Class Degrade Invariant · Pre-Publish · Destructive-Op (fire on INTENT — read before acting, never after)
- **Degrade invariant**: on publish · delete · history-rewrite, a check whose tooling is down **blocks** (fail-closed). Under an auto-approver an `ask` runs on its own, so the closed direction there is deny; only a manual-equivalent pass or an explicit logged override (`PUBLIC_SURFACE_OK=1`, `DESTRUCTIVE_OP_OK=1`) gets past. An automated verdict never clears these surfaces alone, whatever its accuracy. Applicability is decided by grepping the file list, not by calling a repo "docs-only".
- **Pre-Publish** — before making anything public for the first time (`gh repo create --public`, visibility flip, first push to a new public remote, `npm publish`, `twine upload`, a PR or push carrying content to a public hub), and **every time** for a scholarly deposit (Zenodo/OSF/DOI/arXiv submit, new version, replace, metadata change): run `/public-surface-audit` → `/marketplace-gate` Check 5 → `/security-review` when code ships. Scrub before publish, never after. Read `templates/PRE-PUBLISH-CHECKLIST.md` (Step 1b for deposits).
- **Destructive-Op** — before deleting branches (local or remote), force-push, rewriting history, or bulk-deleting records: **enumerate → recover → destroy**. Step 1 is human-run: `bash templates/predelete_check.sh <repo> [base]`. Every CHECK/REVIEW item gets a content look; live un-integrated state (cards, handoffs, signals) goes to main **before** anything is deleted. Before `git worktree remove`: `bash scripts/worktree_reclaim.sh <worktree> --apply`. Never put recovery and destruction in one call.

## FH Improvement 4-Axis Auto-Gate · branches · PRs
**FH 자산을 수정하면**(SKILL.md · SKILL_detail.md · `.claude/rules/*.md` · `knowledge/shared/rules/*.md` · `templates/` · `CLAUDE.md` · substantive `knowledge/`·`docs/*.md` · `AGENTS.md` · `scripts/**/*.sh` · `scripts/**/*.py` · agent definitions `plugins/*/agents/**/*.md` · `.claude/agents/**/*.md`) the **4-axis gate** runs before the first commit. **Read `.claude/rules/fh_4axis_gate.md` before designing the change** (the marker's `soul:` is written before design) — the fields are not listed here, and a marker written from memory is fabricated.
- Load-bearing **field** code (verdict/gate enums, irreversible paths, safety invariants; or a merge verdict on a file `scripts/gate_shape_scan.sh` calls gate-shaped) needs a cross-family review before merge: read `knowledge/shared/harness-core/field_verdict_crossfamily_gate.md`.
- A git gate only binds a checkout where the hook is wired: `bash scripts/gate_bootstrap_ephemeral.sh --check` before relying on it. Before calling a branch surface open or closed, read **both** legacy protection and rulesets.
- A change that alters another harness's behaviour or what consumers receive: read §7 of `field_verdict_crossfamily_gate.md` before push and run it from the target.
- `main` is PR-only. Shared checkout: before switching run `git branch --show-current`; after branching `git log main..HEAD --oneline` must be empty; then `bash scripts/branch_claim.sh claim`. Commit in one call that re-checks the branch and `git diff --cached --name-only`. Never `git add -A`.
- Create a PR only when asked. Merge with `bash scripts/pr_merge_verified.sh <PR#> --rerun '<lane that exercises the change>'`.
- AI never commits on its own to someone else's shared repo: approved changes go to a feature branch and a proposed PR. Team rules stay in their project — never copy a project's team rules into FH.

## Agent Dispatch Operation
Isolated delegation is part of the identity: dispatch separable work (blind evaluation, context-flooding search, parallel tasks) — name its purpose: **independence** (it judges work you produced — never fold, whatever it is called) · **permission** (a narrower authority than yours — never fold while that boundary is needed) · **context** (fold only after repeated runs show no per-task loss; detail §Two-Purposes) — without waiting to be asked **only when a standing request is RECORDED** in `CLAUDE.local.md` with ① the operator's quoted words ② a dated lease ③ a scope. Missing any of the three → ask per invocation. A session never invents or renews a record on its own; it writes one only from the operator's explicit answer. A sidecar audits; it never writes to the target tree, and its findings are evidence until the governor closes each against a mechanical anchor. Honour lease expiry, announce each standing-consent dispatch, and say so once if dispatch is unavailable. Give each dispatch a Context Card (purpose · done so far · this task · constraints); a builder's card also says «smallest fix first — stop and report before adding a new mechanism» and «no `git stash` · `checkout --` · `reset` · `clean` in the tree — if one ran, put the work back, then report in the same reply». Do not commit FH assets from a worktree. After a custom subagent call, log it in `knowledge/shared/learnings/subagent_invocations_log.yaml`. Detail: `knowledge/shared/harness-core/dispatch_conditional_prohibition.md`.

## Autonomous Initiative Layer — intents that must reach a rule, not a guess
| Signal | Go to |
|---|---|
| a work-shaped request outside harness topics | read `intent_marshaling_general_work.md` **before** composing: scan installed skills/agents/mapped harnesses mechanically, propose one line, run — run-first covers reversible FH-native steps only; a sibling's ask-tier and any outward action keep their gates |
| "connect / map this project" · "harness-ify this project" | `knowledge/shared/rules/auto_project_mapping.md` (§6 Full-Harness) |
| "diagnose / improve this harness" in a mapped project | `knowledge/shared/harness-core/field_harness_diagnostic.md` — nothing auto-fixed; company data never leaves the machine |
| "new project / accelerate this project" | `knowledge/shared/harness-core/onboarding_acceleration_autopilot.md` |
| "cut this section / is it load-bearing" | ablation procedure (`scripts/probe_scope_check.sh` header) — never decide by eye |
| "measure this / prove it fires" · a load-bearing conclusion resting on reps < 3 | Measured-Loop (`measurement-integrity-checklist.md §Measured-Loop`) via `scripts/sim_isolated_run.sh` — never sim in the live repo |
| about to call a material work product done / merged / published | `agent-composer` §Author-Exposure Table |
| installed or ran an external asset against this hub · found a same-topic sibling asset (ours or outside) | `knowledge/shared/rules/sister_asset_protocol.md` |
| adding / mounting an external MCP server — before its first tool call | `templates/.claude/rules/mcp_tool_gating.md` |
| invoking or composing a field harness's capability | `capability_composition_contract.md` — strictest constraint wins; an untyped or silent channel is `HARNESS_ERROR`, never PASS |
| a heavy autonomous or multi-agent run (named `/goal` or not) | propose `/goal-quench` first — consent removes the prompt, never its gates |
| verify the user's product / feature / TC | the mapped field harness first; FH verification skills verify harness assets |
| "sync" · "save session" | `knowledge/shared/rules/sync_push_protocols.md` |
| crucible mode · absorb a whole corpus · re-forge identity | `crucible_mode.md` — core invariants never melt |
| starting an expedition (external repo at full stretch) | `claude_md_full_reference.md §Expedition` — declare the target identity, wall clock, readable vs `UNMEASURED` costs |
| confusion, retries, an improvement idea, or a skill/rule limit you hit | record a signal: `claude_md_full_reference.md §FH Improvement Signal Recording Protocol` |
| "research this" | built-in `/deep-research` → WebSearch/WebFetch synthesis → `/frontier-digest` only for AI/harness trends |
| a need a Claude Code built-in may cover | `builtin_capability_map.md` |
| "what did we do last week / find past work" | read `CATALOG.md` first, then open only matched files |
| "wrap up this week" · weekly review · a retrospective over a *period* (not this session) | `/harvest-loop`. Closing *this* session — with or without a retro of it — is Session Wrap-up below (its ② already runs harvest-loop) |
| a bare "정리해줘" / "organize this" with no object in the message or the conversation | ask what to organize (`/deep-clarify`) — never assume the session close; material just pasted or produced *is* the object |
| "context is getting long" · token limit · the session itself feels slow | built-in `/context` · `/compact` first, then `/context-doctor` for what they do not cover |
| anything else | skill descriptions route themselves; the full previous table is in `claude_md_full_reference.md §Autonomous Initiative Layer` |

Propose a skill in one line; never re-propose one the user rejected 3× (UAP: `tracks/_meta/user_adaptation_profile.md`). Before offering to stop asking after 3 consecutive accepts, read `claude_md_full_reference.md §Operational Adaptation Loop` — classes that touch or feed an irreversible sink never promote. At session start and on entering field acceleration or an FH-asset change, apply `claude_md_full_reference.md §Cadence Rules` and §Event-bound proposals.

## Session Wrap-up (fires on "wrap up / done / 마무리 / 마감" in any language — closing *this* session; a week/period review or a bare "정리해줘" is routed by the table above)
Read `claude_md_full_reference.md §Session Wrap-up` first (thread-continuation block, Agent View pre-read, multi-session close). ① git status + unpushed → ①-b open-PR sweep (propose merges, never auto) → ①-f `scripts/utterance_intake.sh` → ①-g request-checklist result sheet: `scripts/session_checklist.py extract` → fill 상태 with evidence/reasons → **show the operator the table**, open rows first (a hook also nudges this mid-session, every 15 written-down requests) → ② harvest-loop if FH assets changed or `close_retro` is granted → ③ sync to the companion store if you keep one — an ephemeral/cloud session leaves a handoff somewhere durable before it ends → ④ memory hygiene → ④-b npm freshness (propose republish, never auto; version digit policy in `claude_md_gate_details.md §Version-Digit-Policy`) → ④-c stamp superseded handoffs → ⑤ append close findings to `tracks/_meta/fh_completed_{date}.md`, **then** rewrite `tracks/_meta/reference_next_session_starter.md` (card last; anything dropped from the card must be logged done or explained) → ⑥ `FH_SESSION_CLOSE=1 git push` — when `git log @{u}..HEAD` **exits 0 and prints nothing**, run `FH_SESSION_CLOSE=1 bash scripts/session_close_check.sh` instead and close only on exit 0 (same check, no push); if that query fails (no upstream, detached HEAD), resolve the push state first. Log completed items in `fh_completed_{date}.md` as they finish, not at close. Detail: `claude_md_full_reference.md §Session Wrap-up`.

## Where the rest lives
`claude_md_full_reference.md` (everything previously resident) · `claude_md_gate_details.md` · `fh_detail_protocols.md` · `knowledge/shared/rules/` (operations, sync/push, modes) · `CATALOG.md` (search index) · `.claude/rules/fh_4axis_gate.md`.

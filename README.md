<p align="center">
  <img src="https://raw.githubusercontent.com/chrono-meta/forge-harness/main/docs/banner.png" alt="forge-harness — Forge your projects, pass them through, faster. Quality is the lever — speed is the result." width="680">
</p>

<p align="center">
  <a href="https://github.com/walkinglabs/awesome-harness-engineering#coding-agent-harnesses"><img src="https://awesome.re/mentioned-badge.svg" alt="Mentioned in Awesome Harness Engineering"></a>
  <a href="https://github.com/VoltAgent/awesome-agent-skills#community-skills"><img src="https://img.shields.io/badge/listed_in-awesome--agent--skills-0ea5e9.svg" alt="Listed in awesome-agent-skills"></a>
  <a href="https://github.com/anthropics/claude-code"><img src="https://img.shields.io/badge/Claude_Code-compatible-a855f7.svg" alt="Claude Code compatible — official Claude Code repository"></a>
  <a href="https://chrono-meta.github.io/forge-harness/"><img src="https://img.shields.io/badge/whole_map-interactive-6366f1.svg" alt="FH whole map — interactive diagrams on GitHub Pages"></a>
  <a href="https://github.com/marketplace/actions/fh-gate-typed-ai-code-review-verdict"><img src="https://img.shields.io/badge/GitHub_Action-marketplace-2088FF.svg" alt="GitHub Actions Marketplace — fh-gate"></a>
  <a href="https://www.npmjs.com/package/@chrono-meta/fh-gate"><img src="https://img.shields.io/npm/v/@chrono-meta/fh-gate.svg?color=cb3837" alt="npm"></a>
  <a href="https://github.com/chrono-meta/homebrew-forge-harness"><img src="https://img.shields.io/badge/homebrew-tap-FBB040.svg" alt="Homebrew tap"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-22c55e.svg" alt="MIT License"></a>
</p>

<p align="center">
  <b>English</b> · <a href="README.ko.md">한국어</a> · <a href="README.zh.md">中文</a> · <a href="README.ja.md">日本語</a>
</p>

# forge-harness (FH)

**FH is a meta-harness for [Claude Code](https://github.com/anthropics/claude-code): it helps you build harnesses and skills — the rules, gates and memory a project needs — and checks them before they ship.**

A *harness* is what you wrap around an AI agent in one project so it stops needing the same instructions
every session: rules it follows, checks that block bad changes, and a record of what it learned. A
*meta*-harness is the one that builds and verifies those, project after project.

> **Stop re-explaining your rules to your agent. Put them in the project.**

<!-- The two lines above and below were chosen, not drafted. Before rewriting them, read docs/ETHOS.md
     §"Who this line is for" — two rejected alternatives are recorded there with why. -->
<p align="center"><b>Quality gates that catch you, not just your agent.</b></p>

## Who it is for, and what you get

For people who use Claude Code (or another coding agent) on real projects and are tired of repeating
themselves or of finding out too late that a change was wrong. You get three things:

| You get | In practice | Evidence |
|---|---|---|
| **A gate before merge** | A diff is judged *before* it lands, and the verdict names what the change lost. The verdict is a typed value (`PASS · PENDING · BLOCKED · ESCALATE`), not text you grep. It works on your own code, not only an agent's. | Demo GIF below · a run on code someone else wrote and a planted-hole test, with sample sizes: [Evidence](#evidence-and-where-it-is-thin) |
| **Memory that carries over** | `tracks/` keeps what each session learned, so session 2 starts where session 1 stopped. | Design intent. At session end the card in `tracks/_meta/` is updated and the next session reads it at startup ([`CLAUDE.md`](CLAUDE.md) §Session Wrap-up). No measured benefit is linked from this page; it only shows from session 2 on. |
| **Someone who picks the check for you** | Say "diagnose this project" or "accelerate this project" and you get a ranked list of what to fix or install. Nothing is changed until you approve each item. | Described in [`CLAUDE.md`](CLAUDE.md) (§Field-Harness Diagnostic); no benchmark of how often it is right |

<p align="center">
  <img src="https://raw.githubusercontent.com/chrono-meta/forge-harness/main/docs/demo/gate-block.gif" alt="regression guard blocking a change that dropped a Done When section, then passing once it is restored" width="820">
</p>
<p align="center">
  <sub>Recorded from a real run of the guard (not a mock-up; the script that regenerates it is linked below): an agent “tidied up” a skill spec (<code>SKILL.md</code>) and dropped its <b>Done When</b> section. The guard BLOCKs and names the missing section; put it back and it returns PASS and the cleanup ships unchanged.<br>Regenerate: <code>brew install vhs &amp;&amp; vhs docs/demo/gate-block.tape</code></sub>
</p>

## Quick start

Pick one door. They install differently and give you different things.

**Door ① — just the gate. No clone, no plugin, no Claude Code session.**

```bash
cd your-repo && npx --package @chrono-meta/fh-gate fh-gate     # reviews the git diff of the current repo
```

It finds your changed files from `git diff`, sends them to a review backend, and prints a verdict
(`FH_GATE_VERDICT: PASS | PENDING | BLOCKED | ESCALATE`) plus an exit code. A PASS counts only if the review actually ran: a backend that never answered, a dry run, or an unknown exit code is not a PASS, and the GitHub Actions step fails on it by default. Needs Node ≥ 16 and one backend
CLI installed and logged in: `claude` (default) or `codex` (`FH_BACKEND=codex`). Use it in CI, a pre-commit
hook, or beside another agent. A GitHub Actions step and a Homebrew tap exist too — see [Run the gate](docs/REFERENCE.md#run-it-outside-claude-code--the-fh-gate-cli).

**Door ② — the whole harness, inside Claude Code.**

```bash
claude plugin marketplace add https://github.com/chrono-meta/forge-harness.git
claude plugin install -s user fh-meta@forge-harness
git clone https://github.com/chrono-meta/forge-harness.git ~/projects/forge-harness
cd ~/projects/forge-harness && claude          # then type: hi   (or 안녕 · こんにちは · 你好)
```

1. **Open the cloned folder in Claude Code** (the `cd … && claude` line).
2. **Say hello.** In a fresh clone FH reads the checkout, sees no session files, and opens a short
   menu for new users: *create your first project · map an existing project · read the guide*. It also
   tells you if the install wizard has not run yet.

   <img src="https://raw.githubusercontent.com/chrono-meta/forge-harness/main/docs/demo/door2-menu.gif" alt="typing hi in a fresh forge-harness clone; FH reads the checkout, opens the new-user menu, and warns that the install wizard has not run yet" width="760">

3. **Take one win in the same session.** Say **"Connect a project"** (FH scans `../` for git repos and
   creates `tracks/{project}/`), then **"accelerate this project"** (ranked, approval-gated plan) or
   **"run /context-doctor"** (token-waste scan). For full setup, run **`/install-wizard`**: every item is
   approved one by one and a decline is recorded.

**Requirements.** Door ② needs the Claude Code CLI (`claude --version`). Door ① needs Node and a `claude` or
`codex` CLI, not a Claude Code session. One of FH's own gates (the test suite in a clone) additionally
needs Python + PyYAML (`python3 -m pip install --user pyyaml`) and fails closed without it.
**Not sure which door?** Start with ①: one command and no global install. Door ② is a larger install that
also ships the `fh-gate` CLI ([`CHEATSHEET.md`](CHEATSHEET.md)); nothing you learn in ① is wasted.

Plugin-only (no clone) works but is partial: you get skills and agents, not the `CLAUDE.md` governance
or the `tracks/` memory. First-time walkthrough in Korean: [`docs/USER_GUIDE.md`](docs/USER_GUIDE.md).

## How it works, in one picture

This is the intended flow. Which steps are enforced by code and which by rules the AI is told to follow is
in the Can / Cannot table below and in [`docs/map/FH_MAP.md`](docs/map/FH_MAP.md).

```
   you say what you want  ──►  FH reads the intent  ──►  forges it into one of two forms
   (plain language)                                        ├─ rules an AI follows  (CLAUDE.md, skills)
                                                           └─ code that needs no AI (hooks, gates, scripts)
                                                                     │
        every change to the harness passes through ◄─────────────────┘
        ┌──────────────────────────────────────────────────────────┐
        │ 1. write down "what counts as success / what it never does" BEFORE designing
        │ 2. try it from several independent angles (other model family, other repo's view)
        │ 3. attack it until what is left is sound — then ship
        └──────────────────────────────────────────────────────────┘
                                   │
   irreversible steps (publish · delete · rewrite history) stop and ask a human
   what a check could not measure is reported as "not measured" — never as 0
   what each session learned is written to tracks/  ──►  the next session starts there
```

The hub (this repo) holds shared `knowledge/` and per-project `tracks/`; each project you connect points
back to it. Full map, every node a real path: [`docs/map/FH_MAP.md`](docs/map/FH_MAP.md) (interactive:
[chrono-meta.github.io/forge-harness](https://chrono-meta.github.io/forge-harness/)).

## Three beliefs

1. **Quality is the lever; speed is the result.** The working hypothesis: work that survived a cold pass needs less rework afterwards. Not benchmarked on this page.
2. **The author is the worst reviewer.** After building with an AI you are its advocate, so the check that
   counts is one by a reviewer who never saw your reasoning — [`docs/WHY.md`](docs/WHY.md).
3. **Machines at irreversible edges; judgment left open.** Block where undoing is impossible, and
   admit what you did not measure — [`docs/ETHOS.md`](docs/ETHOS.md).

## What it can and cannot do

| Can | Cannot (stated by the repo itself) |
|---|---|
| Judge a diff before merge and name what it lost | **Replace review after the fact.** It makes what reaches a human smaller, not unnecessary. Anything that only shows up when the thing runs on a real screen with real state stays a person's job |
| Block commits and pushes through git hooks (rules, scripts, deletes, force-push) | **Guarantee the block.** The hooks are client-side and `--no-verify` bypasses them; the server-side floor is "main is PR-only" plus required CI checks. Its pre-commit hook is for developing FH itself — do not install it into your own repo; use door ① there |
| Carry a project's lessons into the next session | **Work the same everywhere.** Matching your language in the greeting is a prose rule with no mechanical floor; one greeting variant produced no menu in a 2026-08-21 blind test |
| Run a review through another model family (Codex, Gemini, local) to catch what one family misses | **Be fully available outside Claude Code.** Other runtimes get the methodology and `fh-gate`/`fh-run`, not the autopilot ([`docs/codex-compat.md`](docs/codex-compat.md)) |
| Build a harness for a project from a short request | **Emit finished harnesses on demand.** The incubator that would do this has emitted once, and that run skipped the full flow — direction of travel, not a shipped feature |

## Evidence, and where it is thin

- **A real third-party diff (2026-05-31).** `fh-gate` on OpenCode's AI-written `permission/arity.ts`
  (163 lines, CI green): verdict BLOCKED on two A-grade findings CI had missed.
- **Planted holes, model held fixed (2026-07-14).** Eight fail-open holes written by two other models.
  Plain review 5/8 (2 of those the wrong bug) · + FH's degrade-direction lens 6/8 · + a second model
  family 8/8, 0 false alarms. **Single draw, small sample.** The point is that both single-model runs
  missed the *same* two holes. Method in [`ship_readiness_gate.md`](knowledge/shared/harness-core/ship_readiness_gate.md); more runs in [`docs/OUTPUT_EVIDENCE.md`](docs/OUTPUT_EVIDENCE.md).
- **Maturity is graded, not claimed.** The five identities named below carry dated grades in
  [`ship_readiness_gate.md`](knowledge/shared/harness-core/ship_readiness_gate.md); read the grade before relying on one.
- Counts on this page (**46 skills · 14 agents**) are the skill folders and agent files under `plugins/`
  (`fh-meta`, `fh-commons`, `fh-qp`, `fh-preprep`), counted 2026-10-10. Phrasebook: [`CHEATSHEET.md` §12](CHEATSHEET.md#12-skills--agents--what-each-does-and-what-to-say).

## Words you will meet once you use it

You do not need these to start. They name how FH is built, so you can look them up when the greeting or a
gate uses one. Definitions here are one-liners; the canon is [`fh_three_layer_canon.md`](knowledge/shared/harness-core/fh_three_layer_canon.md).

| Term | One line | Read more |
|---|---|---|
| **Three-stage process** | The order FH work runs in: define success first → parallel, decorrelated attempts → burn it on six axes. Speed comes out the end. | [`ETHOS.md`](docs/ETHOS.md#the-forge) |
| **Four engines** | The cores output comes from: `judgment-circuit` · `ship-gate` · `context-continuity` · `external-grounding`. | canon above |
| **Five identities** | The shapes the skills clump into: harness cluster · project incubator · governance gate · frontier absorption · amplifier. Graded per identity. | [`docs/IDENTITIES.md`](docs/IDENTITIES.md) · [`ship_readiness_gate.md`](knowledge/shared/harness-core/ship_readiness_gate.md) |
| **Six-axis verification** | Six ways to review, split by *what the reviewer was given*: other model family · target's own canon · isolated grounding · third-party repo · first real use · revert-and-observe. You pick, not run all six. | canon above |
| **Decorrelation** | Making two checks fail *differently*, so what one is blind to another sees. | [`docs/REFERENCE.md`](docs/REFERENCE.md) |

Other terms: [`GLOSSARY.md`](knowledge/shared/GLOSSARY.md).

## Read next

| If you want… | Go to |
|---|---|
| A first session, step by step (Korean) | [`docs/USER_GUIDE.md`](docs/USER_GUIDE.md) |
| Commands and trigger phrases | [`CHEATSHEET.md`](CHEATSHEET.md) |
| The whole old README (engines, model setup, `fh-gate` flags, skills list, papers) | [`docs/REFERENCE.md`](docs/REFERENCE.md) |
| Use cases and model-tier expectations | [`docs/USE_CASES.md`](docs/USE_CASES.md) · [`docs/model_tier_expectations.md`](docs/model_tier_expectations.md) |
| Why it exists / what it believes / the evidence | [`docs/WHY.md`](docs/WHY.md) · [`docs/ETHOS.md`](docs/ETHOS.md) · [`docs/OUTPUT_EVIDENCE.md`](docs/OUTPUT_EVIDENCE.md) |
| Contribute | [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md) |
| AI operating rules / runtime entry | [`CLAUDE.md`](CLAUDE.md) · [`AGENTS.md`](AGENTS.md) |

> **This document is for humans.** If this is useful, a star helps others find it.

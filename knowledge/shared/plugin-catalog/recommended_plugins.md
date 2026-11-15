---
name: forge-harness Recommended Plugins Catalog
description: Persistent record of plugin-recommender skill execution results. The primary asset for plugin-recommender skill Step 2 [1st priority] Curated List. Updated cumulatively each time the skill runs.
date: 2026-05-08
version: 0.1
---

# forge-harness Recommended Plugins Catalog

> Primary search asset for the plugin-recommender skill. Updated cumulatively each run.

## Run History

| Run | Date | Context | Result |
|:--:|---|---|---|
| 1 | 2026-05-07/08 | `.claudeignore` + model switching / project automation path | Organization GHE 0 items / Claude Code built-in sufficient / external OSS simulation phase |
| 2 | 2026-05-08 | UX Writing QA / NLP — self-simulation | Top asset utilization + md-wiki activation / external NLP plugin simulation phase |
| 3 | 2026-05-08 | Virtual: full-stack (React + Spring Boot) — self-simulation | `.claudeignore` big effect (node_modules·target·build) + model switching / external LSP·ESLint simulation phase |
| 4 | 2026-05-08 | **Organization GHE Tier 1 cross-recommendation simulation** — 5 repos | ★★★ 2 items + ★★ 3 items found / harness return value 4 paths |
| 5 | 2026-05-08 | **Organization GHE Tier 2 sister asset cross-recommendation simulation** — 6 repos | ★★★ 1 item + ★★ 4 items + ★ 2 items / Tier 1+2 cumulative n=11 |
| 6 | 2026-11-15 | Category 0.5 re-enumerated from the live official directory | 36 → 43 plugins (7 new) · built-in / FH overlap column · «enable only where used» (headless arms load every enabled plugin, #1121) · LSP plugins need their language server installed separately (each README's first step) |

## Category 0.5 — claude-plugins-official (Tier 1 official — check BEFORE building or searching elsewhere)

> **No-reinvention rule (meta-harness 철칙)**: if an official plugin covers the capability, use it —
> do not rebuild it as an FH skill or hunt third-party. FH builds only what adds *governance* on top.
> Source: [`anthropics/claude-plugins-official/plugins`](https://github.com/anthropics/claude-plugins-official/tree/main/plugins)
> — **re-enumerated 2026-11-15 from the live directory (43 plugins; repo head `b5b01ac4f8`, 2026-11-14)**.
> The 2026-06-10 snapshot had 36; the 7 added since are marked 🆕, none were removed. Each line below is
> taken from that plugin's own `plugin.json` description or README, not from the group label.
> **This list goes stale: re-enumerate the directory before recommending.**

> 🟥 **Enable a plugin only where it is clearly used.** Every enabled plugin also loads into headless
> `claude -p` sessions — measurement arms, sims, scheduled runs — not just the session you meant it for.
> A plugin set that differs between two arms makes them different instruments; the live-eval scorer
> reports that as `INVALID-COMPARISON` (#1121). A plugin enabled "just in case" adds that noise to every run.

> **Before installing, check the "Already covered" column.** Some plugins duplicate a skill that ships with
> Claude Code (`/code-review` and `/simplify` — rows in `builtin_capability_map.md`; `/security-review`,
> which CLAUDE.md §Pre-Publish already calls when code ships) or an FH skill. Use the built-in or FH path first; install the plugin only for something they do not do.

**Language servers (12).** clangd · csharp · gopls · jdtls · kotlin · lua · php · pyright · ruby · rust-analyzer · swift · typescript (`*-lsp`). Each connects Claude Code to a language server for code intelligence and diagnostics in one language. ⚠️ **The server is a separate install**: each README's first step installs it (checked for pyright — npm/pip/pipx, typescript — `npm install -g typescript-language-server typescript`, gopls — `go install`, whose README also says to put its bin dir on `PATH`). Enable only the languages the mapped project actually uses (Full-Harness Mode step 4). Practical advice, not from the READMEs: check that the server command resolves in the environment that runs the session — a scheduled or headless run can see a different `PATH` from your interactive shell.

| Plugin | What it does (its own words, condensed) | Already covered / FH overlap |
|---|---|---|
| **Dev workflow** | | |
| feature-dev | structured feature workflow with agents for exploration, architecture and quality review | — field-project execution layer |
| commit-commands | commands for committing, pushing and opening PRs | FH's commit/PR path has its own gates (4-axis, `pr_merge_verified.sh`) — don't let a shortcut command skip them in this hub |
| pr-review-toolkit | PR review agents: comments, tests, error handling, type design, quality, simplification | partly the built-in `/code-review`; FH-asset coherence → `/harness-pr-reviewer` |
| code-review | multi-agent PR review with confidence scoring to filter false positives | **built-in `/code-review`** (bundled; `--comment`, `ultra`) — try it first; not proven equivalent |
| code-simplifier | an agent that simplifies code while keeping behaviour | **built-in `/simplify`** does the same job and applies its fixes to the tree — try it first |
| code-modernization | legacy codebase → assessment, plan you approve, upgrade/rewrite with proof it behaves like the old | — |
| frontend-design | production-grade frontend UI that avoids generic AI look | — |
| **Authoring / extension** | | |
| skill-creator | create, improve and measure skills (evals, variance) | may already be available as an account skill; FH 6-item gate still applies to what it produces |
| plugin-dev | toolkit for building plugins: agents, commands, hooks, MCP, marketplace | FH gate still applies |
| hookify | create hooks that block unwanted behaviour, from conversation patterns or explicit instructions | a hook that blocks is machinery — in FH, irreversible edges only (§Mechanization Boundary) |
| mcp-server-dev | design and build MCP servers (deployment models, tool design, auth) | adding a server → `templates/.claude/rules/mcp_tool_gating.md` first |
| agent-sdk-dev | create and verify Agent SDK apps (Python, TypeScript) | — |
| **Setup / session** | | |
| claude-code-setup | analyse a codebase and recommend hooks, skills, MCP servers, subagents | overlaps `/install-wizard` and `plugin-recommender` — FH adds the gate and the consent step |
| claude-md-management | audit CLAUDE.md quality, capture session learnings | ⚠️ overlaps FH (`/harness-doctor`, `/salience-splitter`, session wrap-up) — file mechanics → plugin, governance → FH; evaluate before adopting |
| mcp-tunnels | reach a private-network MCP server through an Anthropic MCP tunnel (Docker Compose quickstart) | network/secret surface — operator decision |
| session-report | HTML report of session usage (tokens, cache, subagents, costly prompts) from local transcripts | built-in `/context` covers the live session; this is the after-the-fact view |
| explanatory-output-style · learning-output-style | SessionStart hooks that recreate the Explanatory / Learning output styles | loads into every session including headless arms — see the warning above |
| **Security** | | |
| security-guidance | pattern warnings on edits, LLM diff review on Stop, an agentic commit reviewer (injection, XSS, SSRF, secrets …) | **built-in `/security-review`** covers on-demand review (CLAUDE.md §Pre-Publish calls it). Its hooks fire in every session where the plugin is enabled, headless runs included |
| 🆕 claude-security | agents map the architecture, build a threat model, hunt and verify every finding before the report, at a chosen effort tier; patches are verified by a panel and applied when you choose | candidate when a field project needs a full audit beyond `/security-review` — every patch is a code change through that project's own gates |
| **Reporting** | | |
| 🆕 project-artifact | a tabbed project status page published as a private claude.ai artifact, refreshed from live state | needs the built-in Artifact tool (claude.ai login) |
| 🆕 receipts | a personal impact report (what you shipped, per-project usage share) from local transcripts and read-only git | reads `~/.claude/projects`; the README says everything is read locally and only counts, project names and your git name reach the model — check that against company residency before running in a company repo |
| 🆕 champion-kit | routines for internal Claude Code champions: hackathons, office hours, adoption steps, maturity report | — |
| **Domain / other** | | |
| 🆕 claude-for-manufacturing | manufacturing skills (joining exports, quoting jobs, nonconformances/8D, breakdown diagnosis); README: reference implementation, not actively maintained | — |
| math-olympiad | competition math with adversarial fresh-context verification | — |
| 🆕 math-proof | two skills for hard proofs: staged solo work, or hours of judge/worker rounds that say what is and is not proved | — |
| ralph-loop | runs Claude in a loop on the same prompt until done | a heavy autonomous run → propose `/goal-quench` first |
| playground | single-file interactive HTML explorers with live preview | — |
| 🆕 theme-examples | example plugin: animated desktop-app backdrops | cosmetic; loads like any other plugin |
| example-plugin | a demo of every extension type | reading material, not for daily use |
| cwc-makers | onboarding for the Code-with-Claude Makers Cardputer kit | hardware kit only |

## Category 1 — Claude Code Built-in (Standard usage / no install)

| Item | Mechanism | Usage path |
|---|---|---|
| **`.claudeignore`** | `.gitignore` syntax / per-session token cost 20-40% ↓ | `cp templates/.claudeignore <project>/.claudeignore` |
| **`/model` + model switching** | Switch models mid-session | `/model opus` / `/model sonnet` / `/model haiku` |

## Category 2 — Forge-Harness Meta Skills (already installed / use fully)

- **fh-meta 5 skills**: `harvest-loop` · `verify-bidirectional` · `frontier-digest` · `cross-ecosystem-synergy-detection` · `plugin-recommender`
- **`hub-persona-auditor`** + **`fact-checker`** agents
- **Active onboarding protocol** (forge-harness `CLAUDE.md`) — greeting/start trigger → 5-skill cascade

## Category 3 — Organization Internal Tools / MCP (install as needed)

> Replace this section with your organization's specific MCP tools and internal plugins.

| Item | Source | Usage path |
|---|---|---|
| **`<your-mcp-plugin>`** | `<your-org>/<your-plugin-repo>` | Configure in `.mcp.json` / refer to your organization's MCP setup guide |

### Examples of what to put here:
- Calendar / task management MCP (e.g., Google Calendar, Jira)
- Internal wiki / docs MCP
- Slack / messaging MCP
- Organization-specific API adapters

## Category 4 — External OSS (evaluate then decide / simulation phase)

| Item | Evaluation | Priority |
|---|---|---|
| TestSprite MCP | May be covered by internal tools | ⚠ Follow-up |
| TestCollab MCP | May be covered by internal tools | ⚠ Follow-up |
| claude-code-skills (levnikolaevich) | Possible overlap with fh-meta 5 skills | ⚠ Follow-up |
| ClaudeMarketplaces.com (4,200+ skills) | Additional search area — not covered in 1st run | ⚠ Follow-up |
| awesome-claude-skills (ComposioHQ) | Curated list — not covered in 1st run | ⚠ Follow-up |

## Domain-Specific Simulation Matrix (n=3 accumulated)

| Domain | ★★★ Immediate | ★★ Gradual | ★ Follow-up evaluation |
|---|---|---|---|
| **QA automation** (test prep automation) | `.claudeignore` · active onboarding · `verify-bidirectional` | `harvest-loop` | domain-specific test plugins |
| **Technical writing / docs QA** | `.claudeignore` · active onboarding · `<your-wiki-mcp>` · `verify-bidirectional` | `<your-messaging-mcp>` | NLP plugin |
| **Virtual full-stack** (React + Spring Boot) | `.claudeignore` (node_modules·target big effect) · active onboarding · `/model opus` for reasoning | `verify-bidirectional` | ESLint MCP · TS LSP |

### Common 3 items (all domains ★★★)
**`.claudeignore`** + **active onboarding protocol** + **harness meta skills**

→ These 3 are automatically applied in active onboarding Step 4 setup. Core of the user's fast path (direct implementation of harness mission — *"easy + no setup burden"*).

### Domain-differentiated tools

| Domain area | Differentiated tool |
|---|---|
| QA domain | `verify-bidirectional` · `harvest-loop` |
| Frontend/full-stack | `/model opus` (coding/reasoning split) |
| Wiki/documentation | `<your-wiki-mcp>` (publish · update · sync) |
| Collaboration notifications | `<your-messaging-mcp>` |
| All domains | harness meta skills (cross-validation) |

### n=3 simulation learnings (maturity improvement path)

1. **Common 3 auto-applied** — active onboarding protocol naturally manifests (no user burden)
2. **Domain-differentiated tools matched after user answer** (plugin-recommender 5-step)
3. **External OSS decided after evaluation** (simplification guard — 80%+ covered by harness meta skills)
4. **plugin-recommender skill v0.2 patch decision after 3+ runs** (currently at 3 runs)

## Update obligation (cumulative each run)

- Add 1 row to run history table
- Update per-category matrix (new recommendations / evaluation changes)
- Persist domain-specific results
- Immediately reflect when new insights are caught

## Next trigger

- On new work/project entry, read this file first → match against Category 1·2·3 first
- On external plugin search cycle, update Category 4 (ClaudeMarketplaces.com / awesome-claude-skills direct fetch)
- plugin-recommender skill v0.2 evolution: decide after 5-run accumulation

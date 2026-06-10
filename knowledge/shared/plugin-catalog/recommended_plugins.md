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

## Category 0.5 — claude-plugins-official (Tier 1 official — check BEFORE building or searching elsewhere)

> **No-reinvention rule (meta-harness 철칙)**: if an official plugin covers the capability, use it —
> do not rebuild it as an FH skill or hunt third-party. FH builds only what adds *governance* on top.
> Source: [`anthropics/claude-plugins-official/plugins`](https://github.com/anthropics/claude-plugins-official/tree/main/plugins)
> — inventory snapshot 2026-06-10 (36 plugins), **name-based grouping; verify each plugin's actual
> behavior via its README before install — do not trust the group label alone. Re-enumerate the
> directory when recommending; this list goes stale.**

| Group | Plugins | FH / mapped-project relevance |
|---|---|---|
| **Language servers (12)** | clangd · csharp · gopls · jdtls · kotlin · lua · php · pyright · ruby · rust-analyzer · swift · typescript (`*-lsp`) | Full-Harness Mode step 4: match to the mapped project's language — instant capability boost, zero FH build |
| **Dev workflow** | feature-dev · commit-commands · pr-review-toolkit · code-review · code-simplifier · code-modernization · frontend-design | Field-project execution layer. Role split: code work → these; FH-asset coherence → FH skills |
| **Authoring/extension** | skill-creator · plugin-dev · hookify · mcp-server-dev · agent-sdk-dev | Drafting tools. **FH 6-item gate still applies to anything they produce** |
| **Setup/session** | claude-code-setup · claude-md-management · mcp-tunnels · session-report · explanatory/learning-output-style | ⚠️ `claude-md-management` overlaps FH territory — role split: file mechanics → plugin; methodology/governance → FH. Evaluate before adopting |
| **Other** | security-guidance · ralph-loop · math-olympiad · playground · example-plugin · cwc-makers | `security-guidance`: candidate complement to Pre-Publish gate — evaluate |

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

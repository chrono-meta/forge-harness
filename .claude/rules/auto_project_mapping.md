---
description: When the user requests "connect a project" or similar, automatically scans parent directories for candidates and handles the 5-step mapping flow (discovery, filtering, confirmation, mapping, summary). Also covers §6 opt-in Full-Harness Mode ("harness-ify this project") — installs project-local harness assets from templates/.
---

# Auto Project Mapping Protocol

When the user requests **"connect a project"** · **"link hub"** · **"map project here"** · **"scan parent directory and connect"** or similar, follow this protocol instead of manual copy (cp).

## 1. Scan

| Scenario | Search path | Condition |
|---|---|---|
| **A. Default inference** | Parent (`../`) of hub cwd | Default when user specifies no path |
| **B. User specified** | Path explicitly stated by user | Preferred when path keyword detected |
| **C. Multiple roots** | Both A + B as candidates | When user uses both |
| **D. 0 candidates** | — | Ask user: **"Please provide the project root path"** |

## 2. Candidate filtering

Only directories meeting all of the following conditions qualify as candidates:

- `.git/` exists (real projects only, no empty directories)
- Exclude the hub itself and sibling hub cwds
- Exclude track names already mapped in `tracks/` (prevent duplicates)

## 3. Mapping confirmation

| Candidate count | Action |
|---|---|
| **0** | Scenario D — ask user |
| **1** | Confirm: `"Map {name} project to tracks/{name}/?"` |
| **Multiple** | Show numbered list, accept multi-select (e.g., "map 1,3 only") |

## 4. Mapping execution (for each selected project)

1. Create `tracks/{project}/learnings/` directory (with `.gitkeep`)
2. **If project root has no CLAUDE.md:**
   - Copy `templates/CLAUDE.md` → `{project_root}/CLAUDE.md`
   - Replace `{project_name}` placeholder with actual track name
3. **If project root already has CLAUDE.md:**
   - **Do not modify existing content**
   - **Propose adding** the following hub reference block at the top (insert after user confirmation):

   ```markdown
   ## Knowledge Hub (forge-harness)

   Persistent knowledge for this project is stored in `~/projects/forge-harness/`.

   - **Search past work**: `~/projects/forge-harness/CATALOG.md`
   - **Learnings/feedback source**: `~/projects/forge-harness/tracks/{project}/learnings/`
   - **At session end**: `sync_push_protocols.md` (Session Sync Protocol)
   ```
4. Auto-add a row for the project in the **track mapping table** in CLAUDE.md
5. Summarize git status changes (user decides whether to commit)

## 5. Summary report (required)

```
Mapping complete: N projects
- {proj-a}: tracks/proj_a/ created, CLAUDE.md newly written
- {proj-b}: tracks/proj_b/ created, hub block added to top of existing CLAUDE.md
- {proj-c}: tracks/proj_c/ created, CLAUDE.md unchanged (user declined block addition)
```

## 6. Full-Harness Mode (opt-in) — harness-ify the mapped project

Basic mapping (steps 1–5) registers a project *lightly* (tracks/ + a starter CLAUDE.md + hub link). **Full-Harness Mode adds the project-local harness assets** — identity ① (Control Tower) propagating harness structure to a connected project; the *how* is executed via the Core Axis.

**Scope**: target *mapped* projects only. For FH-self setup / acceleration baseline (zshrc, sentinels, the FH self-gate) use `/install-wizard` — do **not** run §6 on the FH hub itself. **Prerequisite**: the project is already mapped (steps 1–5); §6 is strictly additive.

**Triggers**: "harness-ify this project", "full harness setup", "프로젝트 하네스화", "promote to full harness", or an opt-in prompt offered right after a basic mapping (*"Promote {project} to a full harness now?"*).

**Installs (each item approval-gated · never overwrite — propose skip/merge if it exists · all from `templates/`):**

| # | Item | Source → target | Effect |
|---|---|---|---|
| 1 | Session rules | `templates/.claude/rules/session.md` → `{project}/.claude/rules/session.md` | Session-start auto-read, backup, rule hierarchy |
| 2 | Context filter | `templates/.claudeignore` → `{project}/.claudeignore` | Token footprint control |
| 3 | Env card | `templates/fh_env_context.jsonc` → `{project}/.claude/rules/fh_env_context.jsonc` | Environment context for sessions |
| 4 | **MCP tool gating** (conditional — offered only when the project mounts an external MCP server: `.mcp.json`/`mcp.json` present, or the user is adding one) | `templates/.claude/rules/mcp_tool_gating.md` → `{project}/.claude/rules/mcp_tool_gating.md` | Name-keyed ask/allow tiers for external MCP tools — server annotations are unreliable (measured 2026-06-11: a live server shipped all-None hints incl. its irreversible send tool); §3 table filled at mount time |
| 5 | **Official-plugin scan** (recommend list only — **never auto-install**) | plugin-recommender Tier 0/1 pass on the project's stack | No-reinvention acceleration: matching `*-lsp` for the project's language + workflow plugins (code-review · commit-commands · feature-dev …) from `claude-plugins-official` — see `knowledge/shared/plugin-catalog/recommended_plugins.md` §Category 0.5. Each install user-approved |

**Not installed (deliberately)**: the FH 4-axis **pre-commit gate** (`templates/.git-hooks/`) is FH-*internal* infra — it hard-codes hub paths and requires hub markers (`tracks/_meta/.axes_23_passed_*`, `tracks/_meta/edit_manifest.yaml`), so dropping it into a target project would **block that project's commits**, not help. A project-generic regression gate is a future candidate, not shipped today.

**Loop linkage (honest — no autonomous daemon)**: `tracks/{project}/` (created in step 1, basic mapping) is what makes the project's **session-synced** learnings visible to the hub's `harvest-loop` weekly audit — *once the user runs the Session Sync Protocol from that project*. §6 adds project-local harness assets; it does **not** add loop automation inside the project, and the session-start cadence (frontier-digest 7d / harness-doctor 30d) runs in the **hub cwd**, not the project. "Acceleration" = the hub's compounding loop ingests the project on sync — not a process running in the project.

**Report (required)**: list each item as `installed` / `skipped (exists)` / `declined`, then state: *"{project}: mapped (light) → project-local harness installed; learnings feed the hub loop on sync."*

**Guards**: respects all Boundaries below (no overwrite, confirm-first). If the project already has its own `.claude/rules/`, propose side-by-side/merge — never clobber. Hub common principles outrank project rules (scope hierarchy); project-specific rules are preserved.

## Boundaries and caution

- **Do not execute without confirmation** — present candidate list → user selects → execute mapping (3 steps)
- **Do not overwrite existing project files** — if CLAUDE.md exists, propose block addition only
- **Warn when large monorepo detected** — repos with 10+ subprojects: ask "Which subproject is the track unit?"
- **Name collision** — if track name already exists, ask user to specify a new track name

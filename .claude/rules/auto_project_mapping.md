---
description: When the user requests "connect a project" or similar, automatically scans parent directories for candidates and handles the full 5-step flow: discovery, filtering, confirmation, mapping, and summary report.
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

## Boundaries and caution

- **Do not execute without confirmation** — present candidate list → user selects → execute mapping (3 steps)
- **Do not overwrite existing project files** — if CLAUDE.md exists, propose block addition only
- **Warn when large monorepo detected** — repos with 10+ subprojects: ask "Which subproject is the track unit?"
- **Name collision** — if track name already exists, ask user to specify a new track name

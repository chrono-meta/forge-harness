---
name: plugin-recommender
description: Given a task description, searches internal and external open-source ecosystems to find and recommend suitable plugins with installation guidance. Activates on "recommend a plugin", "what tool should I use?", "is there a plugin for this?", "recommend a tool". Also checks for duplicate installations.
user-invocable: true
allowed-tools: ["Grep", "GoogleWebSearch", "Bash"]
model: sonnet
---

> **Note:** In external user install environments, the internal GHE org inventory and sister asset clusters are organization-specific examples from the original developer's environment. Adapt the core of this skill (multi-layer search + synergy evaluation + install support) to your own environment (see `## External User Environment Adaptation Path` §).

# plugin-recommender

Takes a task description as input, searches internal GHE and external open-source ecosystems, and outputs a list of suitable plugins and install commands. Also reports duplicate installs and potential conflicts.

## Activation Triggers

Activates on the following types of phrasing.

1. **Direct recommendation request**: "Recommend a plugin", "What plugin should I use?", "Find a useful tool"
2. **Task-based implicit request**: "I want to handle Jira tickets", "I need to visualize DB data", "I want to auto-generate API docs"
3. **Environment setup questions**: "How do I integrate with Confluence?", "Set up plugins needed for a new project"
4. **Chained from sim-conductor** (persona/simulation amplification): "Find a persona/simulation validation plugin", "Install stronger personas for the review". When invoked this way, scope the search to persona/simulation/review-oriented plugins (e.g., deep-insight) and **return control to sim-conductor after install** so the simulation can re-run with the installed personas — see `## Return Path` §.

## Processing Steps (Step 0 Pre-check + 5-Step)

### Step 0: Search Pre-check — GitHub Token Auth Status

Before entering Step 2 multi-layer search, **gh CLI auth status check is mandatory**. Internal GHE + external GitHub auth are separate — if unauthenticated, guide user on how to generate and store tokens.

#### Check Command
```bash
gh auth status
```

#### Unauthenticated Guidance Path (present to user as-is)

**Internal GHE unauthenticated**:
1. **Generate Personal Access Token**: Go to `https://<your-ghe-url>/settings/tokens` → Generate new token (classic) → scopes: `repo`, `read:org` (minimum)
2. **Save to gh CLI**:
   ```bash
   gh auth login --hostname <your-ghe-url>
   # Prompt: Select HTTPS → Paste an authentication token → enter token
   ```
3. **Verify**: `GH_HOST=<your-ghe-url> gh api /user --jq '.login'`

**External GitHub (`github.com`) unauthenticated**:
1. **Generate Personal Access Token**: Go to `https://github.com/settings/tokens` → Generate new token (classic) → scopes: `repo`, `read:org`
2. **Save to gh CLI**: `gh auth login --hostname github.com` (or default `gh auth login`)

#### Search Call Host Branching
- **Internal GHE search**: `GH_HOST=<your-ghe-url> gh api ...` or `gh search repos --owner <your-ghe-org> ... --hostname <your-ghe-url>`
- **External GitHub search**: `gh search repos ...` (default host)

#### External Users (outside org) — Step 0 Skip Branch

In environments without access to an internal GHE, **skip the entire Step 0 internal GHE auth check**. Only verify external GitHub auth status then proceed directly to Step 1.

```bash
# External user Step 0 replacement
gh auth status  # default host (github.com) only
# Authenticated → proceed to Step 1 immediately
# Unauthenticated → guide github.com PAT generation (see "External GitHub unauthenticated" above)
```

**Internal non-hub users** (internal GHE access, not owner): Run Step 0 as-is — but remap `Step 2 [1.5 priority]` sister asset clusters based on your own org. See `## External User Environment Adaptation Path` for details.

### Step 1: User Goal Analysis and Core Keyword Extraction

Analyze the user's natural language request to extract core **domain** and **task** keywords.
- `"I want to create Jira tickets and update their status"` → `domain: jira`, `task: create, update`
- `"I want to auto-generate API docs"` → `domain: api, documentation`, `task: generate, auto`

### Step 2: Multi-Layer Search Space Setup

Search in priority order based on extracted keywords.

1. **[Priority 1] Internal Curated List**: `knowledge/shared/plugin-catalog/recommended_plugins.md` — check this first for verified internal/external plugin list + Tier 1·2·3 classification matrix. If user's task domain already appears in catalog, use results immediately.

2. **[Priority 1.5] Internal GHE Sister Assets (partially completed work — Tier 2)**: Check if user's task domain already exists in internal sister asset clusters. Prioritize direct use or adoption of sister assets if the user's task falls within these cluster domains.

3. **[Priority 2.5] Project Reference/Contribution Path**:

    For cases where referencing or contributing to the project itself is more appropriate than installing a plugin. Provide guidance when there's intent for medium-term contribution rather than immediate use.

    - **Fork reference**: Fork a similar project and customize for your environment
    - **PR contribution**: Propose a PR to the relevant project if the desired feature is missing
    - **Issue filing**: Guide on how to file a feature request issue

    **Role separation (boundary with cross-ecosystem-synergy-detection)**:
    - `plugin-recommender` [Priority 2.5]: When no immediately usable plugin is available → guide to project-level reference/contribution path (alternative to installing)
    - `cross-ecosystem-synergy-detection`: Discover hidden synergies among already-installed skills (post-install utilization optimization)

    Activation condition: Automatically entered when Step 2 [Priority 1]~[Priority 2] search yields no suitable plugin.

4. **[Priority 2] Organization's Internal GHE (Tier 1·3)**: Search internal GHE with keywords like `claude-plugin`, `gemini-plugin` + user keywords / API search. Replace with your organization's internal GHE orgs.

4. **[Priority 3] External Open-Source Ecosystem**: WebSearch / WebFetch — "best github actions for X", "claude plugin for Y", etc. Simplification guard: defer external install if internal assets suffice.

   **Verified external search targets (as of 2026-05):**
   - [`anthropics/claude-plugins-official`](https://github.com/anthropics/claude-plugins-official) — Anthropic-curated official plugin directory. Search here first for any task domain.
   - [`Chat2AnyLLM/awesome-claude-plugins`](https://github.com/Chat2AnyLLM/awesome-claude-plugins) — Community aggregator: 75+ marketplaces, 1,196+ plugins catalogued (2026-05-25). Use for broad discovery.
   - [`anthropics/claude-code/plugins/`](https://github.com/anthropics/claude-code/tree/main/plugins) — Anthropic first-party plugins bundled with Claude Code (e.g., `code-review` with 5 parallel Sonnet agents).

### Step 3: Candidate Plugin Analysis and Ranking

Analyze each candidate plugin's `README.md` and `plugin.json` to score and rank based on:

- **Feature relevance**: How well does the description and keywords match user goals?
- **Reliability and recency**: Recent commit date, star/fork count (external), internal usage frequency, etc.
- **Install convenience**: Does it support `claude plugin install` directly?
- **Synergy effect**: Call `cross-ecosystem-synergy-detection` to check synergy grade (★~★★★) with other currently installed plugins.

### Step 4: Present Recommendation List

Output top 2-3 plugins in the following table format.

| Rank | Plugin Name | Recommendation Reason | Key Features | Synergy Effect |
| :--- | :--- | :--- | :--- | :--- |
| **1** | `jira-automator` | Fully satisfies Jira ticket create/modify/query. Highest internal usage. | Ticket creation, status change, comment addition | ★★★ (auto-links docs when used with `confluence-linker`) |
| **2** | `agile-sprint-board` | Specialized for Jira-integrated sprint board visualization. | Sprint visualization, burndown chart | ★ (standalone use) |

### Step 5: Install and Configuration Support

When user selects desired plugin from recommendation list, help with installation.

**5-0. Pre-install Duplicate Detection (pre-check — mandatory)**

Before attempting install, check if already active:

```bash
claude plugin list
```

3 things to check:
- **Manual install status**: If target plugin name exists in `claude plugin list` output → reinstall unnecessary
- **Repo-level activation status**: If plugin is registered in current cwd's `.claude/settings.json` `enabledPlugins` field → already active
- **Same-name different-function conflict**: If a skill with the same name but different origin/function is already installed → perform conflict handling below

**Same-name Conflict Handling**:

If same skill name already exists in environment, check separately for conflict rather than simple duplicate:

1. Compare existing install skill's description vs recommended skill's description
2. **Feature match** → Report "Equivalent feature already installed" + skip reinstall
3. **Feature mismatch** → Issue conflict warning:
   ```
   ⚠️ Name conflict: `<skill-name>` is already installed but has different functionality.
   
   Currently installed: <summary of existing skill description>
   Recommendation target: <summary of new skill description>
   
   Options:
   A. Keep existing (skip install)
   B. Install with namespace qualifier — e.g., `fh-<skill-name>`
   C. Remove existing and install new (⚠️ existing skill will be removed)
   ```
4. If user selects Option B: Guide adding prefix to `name` field in plugin.json + present modification path

If either condition is met, skip install step → report "Already active — reinstall unnecessary" then proceed to Step 5-3 configuration guidance only.

1. Confirm intent: "Would you like to install the `jira-automator` plugin?"
2. On agreement, run `claude plugin marketplace add` and `claude plugin install` commands.
3. Post-install initial configuration guidance:
    - **API token input**: If plugin uses external service API, guide token generation path (e.g., Jira/Confluence/Slack — specify each service's token generation page URL + environment variable or plugin config storage location)
    - **MCP connection**: If plugin uses MCP server, guide auto-update of `.mcp.json` or `claude mcp add` command
    - **Verify**: Confirm install consistency with `claude plugin list` or `/plugin` UI + recommend first-call dry-run

**5-B. External Asset Migration Path *(when non-plugin asset is found)***

Activation condition: Step 3 analysis discovered a promising external asset but it lacks `plugin.json` or `claude plugin install` support — i.e., **install not possible but pattern has value**.

#### 5-B-1. Migration Suitability Assessment

Quick 3-criteria check:

| Criteria | OK | NG |
|---|---|---|
| **Single purpose** | Clearly performs 1 task | Complex framework/SDK level |
| **Dependency complexity** | Standard CLI tools only (bash, gh, grep etc.) | Requires custom runtime/database |
| **FH gap coverage** | No similar skill currently in FH | Existing skill covers 95%+ |

All 3 OK → Recommend migration. Any NG → Report "Recommend referencing rather than installing" then guide Step 2 [Priority 2.5] contribution path.

#### 5-B-2. SKILL.md Conversion Guide

Present template to user + provide draft filled with external asset analysis results:

```markdown
---
name: {1-3 words for the external asset's core action}
description: {one sentence, plain text only — first line is the core spec}
user-invocable: true
allowed-tools: ["Read", "Bash", "Grep"]  # only actually needed tools
model: sonnet
---

# {name} — {one-line description}

## Activation Triggers
- When user says "{core action}"

## Execution Steps

### Step 1. ...
### Step 2. ...
```

Conversion checklist:
- [ ] description first line = core spec (no marketing language)
- [ ] allowed-tools = only actually called tools (no over-declaration)
- [ ] External asset original URL → explicitly stated in `## Source` section (license check mandatory)

#### 5-B-3. Migration Location Guidance

| Purpose | Path | Notes |
|---|---|---|
| FH official skill (org-wide distribution) | `plugins/fh-meta/skills/{name}/SKILL.md` | PR mandatory — must pass team review |
| Local experiment (own environment only) | `.claude/rules/{name}.md` | No plugin install needed |
| Mode D standalone deployment | `.claude/agents/{name}.md` | Only when operating as agent form |

> FH official skill inclusion criteria: Recommend PR after confirming 2+ actual uses (simplification guard — immediate inclusion after 1 experiment is prohibited).

---

## Constraints

- **Recommendations, not guarantees**: Does not guarantee plugin performance, stability, or security.
- **User consent required**: Does not auto-install without explicit consent.
- **Search scope limitations**: Only searches within configured search space.

## External User Environment Adaptation Path

The internal GHE org inventory + sister asset clusters in this skill are examples from the original developer's environment. External user (mode C install) environment adaptation path — following forge-harness core proposition *"Beta + public release = obligation to have practical capabilities"*.

### External User Environment Assumptions

External users in 2 tiers:

| Type | Internal GHE access | Applicable path |
|---|---|---|
| **Internal non-hub** (org employee, not owner) | Yes — run Step 0 as-is / remap Step 2 [1.5 priority] to own org sister assets | Use original developer environment as reference baseline / search based on own sister assets/org |
| **External** (outside org) | No — apply entire Fallback Matrix below | Auto-skip internal GHE steps / search based on external GitHub |

The core 5-step procedure (goal analysis → multi-layer search → candidate analysis → recommendation → install support) is cross-applicable to both types.

> The Fallback Matrix below is for **external users**. Internal non-hub users can use Step 0·2 as-is.

### Fallback Matrix (Original Developer Environment → External Environment Replacement)

| Original developer environment dependency | External user environment fallback |
|---|---|
| **Step 0** internal GHE auth check | Check external GitHub auth only (`gh auth status` default host) — auto-skip internal GHE step |
| **Step 2 [Priority 1.5]** internal sister asset clusters | User's own sister assets (personal/team GitHub org · internal marketplace) — this skill auto-maps user's own sister asset matrix |
| **Step 2 [Priority 2]** internal GHE org inventory | External GitHub default org inventory (`anthropics` · `oh-my-claudecode` etc. plugin ecosystem marketplace) |
| **Step 4** Tier 1·2·3 classification matrix | User's own Tier classification — direct task domain match vs partial work vs tools/utilities (user's own priorities) |

### External User Usage Scenarios

1. **External GitHub priority recommendations**: In environments without internal GHE access, call only Step 2 [Priority 1] curated list + [Priority 3] external GitHub search / auto-skip [Priority 1.5]·[Priority 2] internal GHE steps
2. **Plugin marketplace discovery assistance**: Auto-search external ecosystems like `anthropics/claude-code` marketplaces · `oh-my-claudecode` · personal/team marketplaces
3. **Core synergy evaluation**: Step 3 synergy evaluation + auto-calling cross-ecosystem-synergy-detection is cross-applicable to all environments
4. **Same install support baseline**: Step 5 token generation path · MCP connection · 3 verification sub-paths work the same in external GitHub environments

### Limitations (Explicit)

- **Internal GHE org inventory** (Step 0 / Step 2 [Priority 2]) = original developer's organization-specific environment / external users should treat as reference baseline (auto-skipped)
- **Sister asset clusters** (Step 2 [Priority 1.5]) = original developer's own environment / external users should map their own sister assets
- **Core 5-step of this skill** (goal analysis + multi-layer search + candidate analysis + recommendation + install) = cross-applicable to all user environments / original developer examples are for reference
- **catalog `recommended_plugins.md`** = original developer environment accumulated operation baseline / external users should create their own catalog or use this as reference baseline

## Return Path (when chained from sim-conductor)

When invoked as sim-conductor's **③ external-fetch branch** (Activation Trigger 4), this skill hands control back after install so the simulation can run with the new personas.

```
sim-conductor needs persona X (no installed/built-in match)
  → plugin-recommender: scope search to persona/simulation/review plugins (e.g., deep-insight)
  → recommend → install (user approval)
  → RETURN to sim-conductor: report "[plugin] installed, personas [list] now available"
  → sim-conductor re-runs the Area with persona X
```

**Done When (chained mode)**: install complete **AND** control returned to sim-conductor with the available-persona list. Ending at install without the return handoff = incomplete chain.

**Simplification guard**: If a suitable persona is already installed or a built-in role brief covers the need, do not search/install — report the existing match and return immediately. The cheapest persona is the one already present.

## Done When

```
All Steps 0~5 completed
+ Recommendation list table output (top 2~3 items, synergy grade included)
+ Install completed after user selection (or install skipped / 5-B migration path guided)
+ Duplicate detection results reported
```

## Failure Response

On Claude API / MCP failure → refer to [`references/fallback-guide.md`](../../references/fallback-guide.md) manual checklist.

---

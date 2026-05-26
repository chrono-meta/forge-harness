# forge-harness (FH)

> **A central Claude Code harness for anyone managing multiple projects — fork it, reshape it, and make it yours. Persistent memory, shared skills, and connected knowledge across projects.**

You've learned the basics. forge-harness is the next step —
an acceleration hub to **customize Claude Code for your team, accumulate know-how, and integrate with internal and external assets to get more out of it**.

**The standard usage is to fork and reshape it into your own team hub or personal multi-project hub.** Just rename the repo and it's yours. The original forge-harness remains as a template.

| If you're at this stage after adopting Claude Code | forge-harness solves it |
|---|---|
| You have to find plugins and methods yourself each time | Contains verified plugins, skills, and best practices |
| Context disappears when a session ends | Recorded in a persistent hub, resumable from anywhere |
| Hard to pass your AI know-how to the team | Codify it so the whole team shares it |
| You repeat the same setup for every project | Connect once to the hub and share across all projects |
| You want to use assets from other teams or external sources | Instantly available via federated marketplace architecture |

> **Worried about token costs?** New install context footprint is approximately 14.5% (based on 200K context). Even if you have an existing team harness, optimization can reduce this. → [See token guide](#token-cost-optimization)

| Current situation | Stage | Jump to |
|---|---|---|
| Want to set up Claude Code properly from scratch | **Start** | [Get started in 2 minutes](#get-started-in-2-minutes-recommended--semi-automated-claude-mapping) |
| Already using it, want to use it better | **Optimize** | [Already using it](#already-using-it----29-asset-activation-check-25-skills--4-agents) |
| Want to spread it to the team or contribute skills back | **Advance** | [Operating model Phase 3](#operating-model----3-phase-essence-invocation-flow) |

---

> **This document is for humans.**
> AI operating rules are in `CLAUDE.md` · Command reference is in `CHEATSHEET.md`

| User | Plugin combination | Scope |
|---|---|---|
| **External** | fh-meta | Full access to all core skills |

---

## What is this?

An **acceleration hub** for teams already using Claude Code. Connect N projects to one hub, and the work, learnings, and patterns from each project **mutually reinforce** each other, raising the level of every individual project. Common skills and agents are built once in the hub and shared across all projects — eliminating the cost of every team reinventing the same capabilities.

> **Goal**: A path to get into orbit in the age of AI acceleration **without burning out like a racehorse**. Minimize setup friction, lower the barrier, optimize context (`.claudeignore` / `/clear`), distribute expertise by task complexity (model and agent selection), and increase task success rate and speed.

---

## Going deeper — why a "meta" harness?

Teams that have systematically used AI collaboration tools are already doing **harness engineering**. QA protocols, TC design gates, verification pipelines — any structure designed to make AI behave more consistently is harness engineering.

forge-harness is the **OS one layer above that harness**.

```
Single-layer view:
  My project → [harness engineering] → better AI collaboration results

Meta-layer view (forge-harness):
  harness → [meta harness engineering] → better harness
      ↑           (forge-harness)              ↓
      └───────── feedback + evolution loop ─────┘
```

| Layer | What it does | Examples |
|---|---|---|
| Harness engineering | Installs rules, gates, and context management for a specific project | QA protocols, CLAUDE.md rulesets, TC verification pipelines |
| **Meta harness engineering** | Builds a system to measure, improve, and evolve the harness itself | FH skill bus, harness-doctor HHS, steel-quench, field-harvest |

**What the designer of forge-harness does**: Not using a single project harness, but designing and operating a system where the harnesses of multiple projects all grow stronger together. Not writing code directly, but designing the frame of which structures solve which problems.

> For a detailed definition of this concept → `knowledge/shared/harness-core/meta_harness_engineering_definition.md` (accessible after cloning forge-harness)

### Environment Engineering

forge-harness doesn't change the agent — it changes the environment. The MEMORY.md keyword-trigger, mandatory Context Card injection, and PFD domain knowledge pre-loading are practices of Environment Engineering that remove the "orientation tax" agents pay before they can find their direction.

| Mechanism | Cost it eliminates |
|---|---|
| MEMORY.md keyword-trigger load | Attention waste from loading all knowledge even when unnecessary |
| Mandatory Context Card injection | Orientation cost of agents reconstructing session context from scratch |
| PFD domain knowledge pre-loading | First-round waste of agents exploring the codebase and domain |

**"Not making the agent smarter, but making the environment easier for the agent to work in."**

---

## Why do you need it?

When a Claude Code conversation ends, **context disappears**. And what was learned in Project A is unknown to Project B.

Three things this hub solves:

| Problem | Solution |
|------|------|
| Context lost when session ends | Session records persistently stored in `tracks/` |
| Hard to find past work | Instantly searchable via `CATALOG.md` tag+summary index |
| Knowledge gap between projects | Accessible from anywhere via hub connection |

---

## How does it work?

```
forge-harness (the brain — persistent hub)
├── knowledge/   →  referenced from all projects
└── tracks/      →  work records per project

Project A (the execution site)
  → connect hub in CLAUDE.md → auto-referenced

Project B (the execution site)
  → connect hub in CLAUDE.md → auto-referenced
```

- **From the hub**: invoke Claude Code → cross-project judgment with integrated context
- **From each project**: invoke Claude Code → project-specific work + hub reference
- **Say "hello"** → Claude automatically pulls recent context and today's tasks from the hub *(when running `claude` from the FH cwd)*

> **Essential understanding before starting**: Both plugin install (tool registration) and git clone (hub context connection) are required.
> The "hello" promise only works when you run `claude` **from the clone's FH cwd**. With only the plugin installed, you can use skills but the hub context auto-load won't trigger.

> **Core principle**: Claude Code automatically reads the `CLAUDE.md` file in the project root and follows it as rules throughout the session. forge-harness uses this mechanism to connect the settings, learnings, and patterns of N projects. Works with just a single file, no separate code integration needed.

> **Making it yours (fork path)**: You can clone FH directly, but **fork → rename → operate as your personal hub** is the standard path for long-term use.
> ```bash
> # After forking on GitHub
> git clone https://github.com/{your-org}/forge-harness.git ~/my-claude-hub
> cd ~/my-claude-hub
> ```
> Accumulate your `tracks/` and `knowledge/` in the forked repo as your personal hub, and periodically pull new skills and updates from the original forge-harness (upstream merge). For teams, create one team fork and share it the same way.

---

## Finding your entry path — 1-minute self-diagnosis

Count how many of the following apply to you.

- [ ] You have 2 or more Claude Code projects
- [ ] You lose previous work context when a session ends
- [ ] You repeatedly explain the same patterns and rules across multiple projects
- [ ] You want to spread AI collaboration methodology to your team or codify it as an asset
- [ ] You want AI to help better as work accumulates

| Check count | Recommended path |
|:---:|---|
| **3 or more** | Standard entry → `## Get started in 2 minutes` |
| **1-2** | Plugin first → `claude plugin install fh-meta@forge-harness` (Mode B) |
| **0** | Single project Claude Code stage — recommended to re-enter when you grow to 2+ projects. What you can use now: `context-doctor` available as a standalone install |

---

## Runtime Requirements

forge-harness is designed with a large context window in mind. Works correctly in the following environments:

| Environment | Support | Notes |
|---|---|---|
| Claude Code + Anthropic API Key | ✅ Recommended | 200K context · officially supported |
| claude.ai Pro / Team Plan | ✅ Recommended | 200K context · officially supported |
| AWS Bedrock (direct API) | ⚠️ Conditional | Possible with sufficient account quota |
| Bedrock + claude-code-router (LiteLLM proxy) | ⚠️ Unofficial | Frequent `Input is too long` errors · not recommended |
| Internal AI API proxy | ⚠️ Conditional | Depends on `max_input_tokens` configuration |

> **If you're getting errors in a Bedrock proxy environment**: Request an AWS quota increase (TPM/RPM) or an increase in LiteLLM `max_input_tokens` from your administrator. The root solution is switching to direct Anthropic API access.

---

## Get started in 2 minutes (Recommended — semi-automated Claude mapping)

### Step 0. Register the plugin (prerequisite for using skills)

> **If this is your first install, complete this step first.** FH skills like `/install-wizard` only activate after the fh-meta plugin is registered in Claude Code.

```bash
# [Terminal] Add marketplace
claude plugin marketplace add https://github.com/chronology-dev/forge-harness.git

# [Terminal] Install plugin (user scope — available in all projects)
claude plugin install -s user fh-meta@forge-harness
```

Verify installation: type `/skills` in the CC chat → if `install-wizard` appears in the list, you're done.

> If you've already installed the plugin, skip straight to Step 1.

### Step 1. Clone the hub

> **Prerequisites**: A GitHub account and git credentials configured. If `git clone` fails with an authentication error, set up SSH keys or create a personal access token (GitHub → Settings → Developer settings → Personal access tokens) and retry.

```bash
git clone https://github.com/chronology-dev/forge-harness.git ~/PycharmProjects/forge-harness

cd ~/PycharmProjects/forge-harness
```

### Step 2. Say something to Claude

```bash
# [Terminal] Launch Claude Code
claude
```

> ✅ **Expected Claude response on success** (doesn't have to match exactly — roughly this flow):
> ```
> I've read forge-harness CLAUDE.md.
> What would you like to work on?
> (Continue an active track / Start a new task / Connect a project)
> ```

> ❌ **Failure symptoms & fixes**:
> - **Only a generic response like "Hello! How can I help you today?"** → Run `pwd` to confirm you're in the `forge-harness` root. If not, run `cd ~/PycharmProjects/forge-harness` then `claude` again.
> - **"CLAUDE.md not found" error** → Verify the clone went to the right path: `ls ~/PycharmProjects/forge-harness/CLAUDE.md`
> - **Clone fails with authentication error** → SSH key or personal access token setup required (see Step 1 prerequisites above)

Once open, just talk to Claude:

- **"Connect a project"** → The hub automatically scans `../` (the directory above the hub), lists projects with `.git` as candidates
- **Select the desired project number** (this step requires user selection) → `tracks/{project}/` is auto-created, a template CLAUDE.md is placed if none exists, or a hub reference block is proposed if one exists
- **"My projects are in `~/work/`"** → You can specify a different root
- If unclear, Claude will ask first

See `CLAUDE.md > Auto Project Mapping Protocol` for detailed detection and mapping procedures.

---

## Already using it — 29 asset activation check (25 skills + 4 agents)

Check which of the following 29 (23 fh-meta skills + 2 fh-commons skills + 3 fh-meta agents + 1 fh-commons agent) are **regularly activating** for you. The table below lists the assets bundled with forge-harness plugins (fh-meta + fh-commons). `.claude/agents/` adds `plan` and a local `quench-challenger` mirror, available to FH itself when working in the FH cwd.

| Asset | Role | Natural language trigger examples | Active |
|---|---|---|:---:|
| `agent-composer` | Agent composition layer coordinator — plans optimal dispatch | "How should I split this task across agents?", "I want to run this in parallel" | □ |
| `apex-review` | Final quality review of deliverables + improvement proposals | "Will this hold up with decision-makers?", "Review from an executive perspective" | □ |
| `verify-bidirectional` | Reverse-verify new decisions | "Is that right?", "I don't think that's it", "Double-check this" | □ |
| `deliberation` *(fh-commons)* | Structured deliberation and argument reinforcement | "Battle it out", "Review this decision from multiple angles" | □ |
| `cross-ecosystem-synergy-detection` | Detect cross-ecosystem synergies | "Are the things I installed working well together?", "The tools seem to be working in silos" | □ |
| `plugin-recommender` | Plugin recommendations for new tasks | "Is there a good tool for this task?" | □ |
| `hub-cc-pr-reviewer` | Automated PR review | "Review this PR", "Is it okay to merge?" | □ |
| `context-doctor` | Token efficiency diagnosis + `.claudeignore` automation | "Token waste", "Session is slow", "Clean up the context" | □ |
| `sim-conductor` | Meta-simulation automation orchestrator | "Look at this from an external user's perspective", "Run an internal audit" | □ |
| `steel-quench` | Full-spectrum verification — surfaces and defends design flaws with AI devil attack Waves. **Dedicated to output pattern attacks** (self-declarations, cushion language, structural flaws) | "Run the quench", "Full-spectrum review", "Attack from the root", "Clear design anxiety" | □ |
| `source-grounding-audit` | Source back-tracing of deliverable claims — detects Phantom Claims generated without reading sources and classifies by severity. **Dedicated to input tracing** (where did this come from?) | "Verify the source", "Trace TC basis", "Grounding audit", "Trace the origin" | □ |
| `harness-doctor` | Harness structure L1~L5 diagnosis + M/S/R prescription | "Something seems wrong with my Claude setup", "A hook isn't working" | □ |
| `deep-clarify` | Socratic requirements clarification — draws out goals, completion criteria, and constraints, saves as a spec document | "I'm not sure what I need to build", "Help me clarify", "Organize the requirements" | □ |
| `meta-prompt-builder` | Meta prompt design + optimization | "Write a prompt for each Wave", "What should I tell the agent?" | □ |
| `install-doctor` | Diagnose conflict and overwrite risks before/after plugin install | "Is it okay to add this plugin?", "Something seems off after installing" | □ |
| `install-wizard` | Initial environment diagnosis + onboarding automation | "First-time setup", "Initial configuration", "Help me with setup", "Just installed this", "After cloning FH", "wizard" | □ |
| `asset-placement-gate` | Evaluate whether a new asset belongs in forge-harness | "Should I make this a separate file?", "Can this pattern be shared?" | □ |
| `marketplace-gate` | 5-point fitness gate before marketplace listing | "Is it okay to list this in the marketplace?", "Check before publishing" | □ |
| `field-harvest` | Back-propagation of field patterns — trigger from a field cwd | "I could reuse this in other projects", "I want to save what I found this time" | □ |
| `hub-persona-auditor` | Pre-publish audit of external assets | "Take a look before external release", "How will this look to others?" | □ |
| `fact-checker` | Asset deduplication check | "Isn't there something similar already?", "Check for duplicates" | □ |
| `persona-innovator` | Naming gap detection + ideation algorithm | "Any new ideas?", "What would be a good name for this?" | □ |
| `contention-layer` | Treat conflicts between skills/agents as harvest signals → propose new skills | "These two skills conflict", "They clash when used together", "Contention layer", "Harvest the conflict" | □ |
| `context-bridge-dispatch` | Inject session context cards into parallel agent dispatch prompts before fan-out | "Brief the agents first", "Bridge the context", "Parallel dispatch context" | □ |
| `frontier-digest` | Collect frontier signals (HN, arXiv, etc.) and synthesize PMH/FH-relevant insights | "AI trend digest", "Frontier digest", "What's new this week" | □ |
| `harvest-loop` | End-of-session learning → reverse-evolution pipeline (field-harvest → contention → personas → synth → doctor → verify) | "Harvest the session", "Reverse-absorb learnings", "Run the pipeline" | □ |
| `self-marketing-lint` | Detect and remove self-marketing language, owner self-reference, version/round bragging in skill descriptions | "Lint self-marketing", "Description diet", "Strip the marketing tone" | □ |
| `convergence-loop` *(fh-commons)* | Replace single-pass gates with N-round convergence loops; only declare "truly passed" after convergence | "How many rounds do we need", "Suspicious of single-pass", "Convergence loop" | □ |

| Check count | Diagnosis |
|:---:|---|
| **22-29** | Advanced stage — focus on `agent-composer` + `sim-conductor` + `steel-quench` + synergy cascade (chained verification) |
| **8-21** | Activation stage — gradually activate unchecked assets |
| **0-7** | Early stage — go back to the self-diagnosis above and follow the standard entry |

---

## Core Usage

### How to talk to Claude

| What you want to do | What to say |
|-------------|--------|
| Start a session | "Hello" → automatically reads hub and guides today's tasks *(when running `claude` from the FH cwd)* |
| Fallback | "What have we done so far?" / "Where did we leave off?" → when "hello" doesn't get a response |
| Save session | "Sync this session to forge-harness" |
| Search past work | "What did I do around April 13th?" |
| Clean up | "Check for duplicate or meaningless data" |

### Knowledge flow

```
Search:  CATALOG.md (tags+summary) → open that file directly
Store:   End of session → save to tracks/{project}/ → update CATALOG.md
Return:  New pattern found → save feedback to tracks/{project}/learnings/
Share:   Common to 2+ projects → write to knowledge/shared/
```

---

## Agent dispatch guide

forge-harness includes 3 specialized agents, plus the `agent-composer` coordinator that automatically plans their optimal combination.

### Quick start — agent-composer

```
/agent-composer
```

Analyzes the current task and proposes a plan for which agents to dispatch in what order. Execute immediately after approval.

### FH agents (3 types)

| Agent | Role | When to use |
|---|---|---|
| `fact-checker` | Asset deduplication and staleness check | Before adding new assets — preemptive Wave 0 gate for all tasks |
| `hub-persona-auditor` | 3+ persona audit of externally published assets | Before publishing READMEs, briefings, or guides |
| `persona-innovator` | Naming gap detection + external frontier scan | When you need to discover new patterns or names |

> When the `deep-insight` plugin is installed alongside, `sim-conductor` Area A simulations automatically integrate with persona agents (newcomer, power-user, devil-advocate).

### Parallel dispatch — parallel first for 2+ independent tasks

Request two agents in a single message to run them in parallel:

```
"Run fact-checker and persona-innovator in parallel.
  First: check [asset path] for duplicates and staleness
  Second: scan current harness for naming gaps"
```

> **Validated**: 6 background agents dispatched in parallel from meta-harness cwd → completed in ~3 minutes (~5x faster than sequential).

### Which cwd to dispatch from

| Task | Recommended cwd |
|---|---|
| Single project coding/debugging | That project's cwd |
| Agent dispatch, audit, simulation | **Meta-harness cwd** |
| Working on 2+ projects simultaneously | **Meta-harness cwd (parallel Agent)** |

---

## Advanced Configuration

> The "Get started in 2 minutes" section above is sufficient for basic use. This section covers advanced setup: plugins, mode branching, and cost optimization.

### Plugin install (meta tool bundle — optional path)

Viewed from an **asset dimension**, the hub has two entry paths:

- **[Clone path] Persistent meta hub** = `git clone` path (see `## Get started in 2 minutes` above — `tracks/` + `knowledge/` persistent materials + CLAUDE.md mapping)
- **[Plugin path] Meta tool bundle** = `claude plugin install` path (this §) — fully activates meta operation tools in the form of Claude Code skills and agents

The two asset paths are **different in nature** (clone path = persistent hub / plugin path = meta tool bundle). Installing both creates synergy.

> **User entry modes** = There are three separate **Mode A/B/C branches** (*"don't block those who come, don't block those who go"* principle) — standard (both clone + plugin) / resident (clone + separate directory work) / **plugin only** (plugin path only / without cloning meta-harness). This § focuses on the plugin path install procedure; for Mode C full onboarding, see `## Mode C user guide` below.

#### Adding the marketplace

> **All commands below are run in the Terminal app. Not in the Claude chat window.**

```bash
# [Terminal] Register marketplace
claude plugin marketplace add https://github.com/chronology-dev/forge-harness.git
```

> **Note:** You must append `.git` to the URL. (Git repositories aren't auto-detected without the `.git` suffix)

#### Installing the plugin

```bash
# [Terminal] Install plugin
claude plugin install -s user fh-meta@forge-harness
```

> **Scope guide**: `-s user` (default) = available in all projects (recommended). `-s project` = current project only. Since fh-meta is a cross-project meta tool, user scope is recommended.

After installing, type `/skills` or `/agents` in the **Claude Code chat window** — if the fh-meta skill list appears, the install was successful.

> **Plugin updates**: New skills and changes are not automatically applied. Run the following periodically (in terminal):
> ```bash
> claude plugin update fh-meta@forge-harness
> ```

> **Mode C (plugin only) user note — legitimate path + honest limitations**
>
> The `fh-meta` plugin is the **"active component" that automates the meta hub system**. **Mode C — installing only the plugin without cloning the meta-harness — is also a legitimate path** (*"don't block those who come, don't block those who go"* principle), but skills that depend on meta-harness assets will partially activate.
>
> *   **Asset-dependent skills (partially activate in Mode C):** `verify-bidirectional` (depends on `knowledge/`) · `apex-review` (missing hub-accumulated baseline)
> *   **Asset-independent skills (fully activate in Mode C):** `cross-ecosystem-synergy-detection` · `plugin-recommender` (fh-meta) · `deliberation` · `convergence-loop` (fh-commons) — though hub-accumulated knowledge cross-reference will be missing, leaving only your own project history available
>
> **For full synergy** = Follow the `## Get started in 2 minutes` guide for Mode A standard (both A+B). **For Mode C full onboarding** = See `## Mode C user guide` below.

#### Plugin catalog

| Plugin | Nature | skills | agents |
|---|---|---|---|
| **fh-meta** (v1.1.4) | Hub meta operation tool bundle — 23 skills (agent-composer · apex-review · asset-placement-gate · contention-layer · context-bridge-dispatch · context-doctor · cross-ecosystem-synergy-detection · deep-clarify · field-harvest · frontier-digest · harness-doctor · harvest-loop · hub-cc-pr-reviewer · install-doctor · install-wizard · marketplace-gate · meta-prompt-builder · plugin-recommender · self-marketing-lint · sim-conductor · source-grounding-audit · steel-quench · verify-bidirectional) + 3 agents (hub-persona-auditor · fact-checker · persona-innovator). **Verification pair**: steel-quench (output pattern attack) + source-grounding-audit (input source tracing) | 23 | 3 |
| **fh-commons** (v0.1.1) | Domain-agnostic general utilities — 2 skills (convergence-loop · deliberation) + 1 agent (quench-challenger) | 2 | 1 |

> **Asset count SoT**: `plugins/fh-meta/.claude-plugin/plugin.json` is the canonical source. If the numbers above don't match, use plugin.json as the reference.

#### External persona layer synergy install (optional, no MCP required)

A validated combination you can add immediately without any MCP setup. Adding the following after installing `fh-meta` immediately expands persona agent capabilities.

| Plugin | Provided assets | fh-meta synergy |
|---|---|---|
| **deep-insight** `@<your-team-marketplace>` | 6 persona agents (newcomer · power-user · pm · qa · devil-advocate · synthesizer) | Automatically runs sim-conductor Area A scenarios · supplements hub-persona-auditor |

```bash
claude plugin marketplace add <your-team-marketplace-url>
claude plugin install -s user deep-insight@<your-team-marketplace>
```

> `sim-conductor` and `hub-persona-auditor` work without `deep-insight`, but the 3 Area A external user simulation types (persona-newcomer · power-user · devil-advocate) automatically integrate when `deep-insight` is installed.

#### Mode C user guide (plugin only, without cloning meta-harness)

*"Don't block those who come, don't block those who go"* — meta-harness supports free user entry and exit, and must support any mode. This § is the full onboarding channel for Mode C users.

**Users Mode C suits**

- Users who don't need the meta-harness native assets (`tracks/` · `knowledge/`) and just want to **use plugins and skills**
- Users who accumulate their own project history on their side and use the meta-harness directory only as a **reference asset**
- Users adopting skills that work without hub mapping (`cross-ecosystem-synergy-detection` · `plugin-recommender` (fh-meta) · `deliberation` · `convergence-loop` (fh-commons)) into their own projects

**Install procedure (Mode C only)**

```bash
# 1. Add marketplace (no meta-harness clone)
claude plugin marketplace add https://github.com/chronology-dev/forge-harness.git

# 2. Install plugin
claude plugin install fh-meta@forge-harness

# 3. Invoke Claude Code from your project cwd (no meta-harness cwd entry)
cd ~/PycharmProjects/{your-project}
claude
```

**Limitations (honest disclosure)**

| Area | Mode A (standard) | Mode C (plugin only) |
|---|:---:|:---:|
| `verify-bidirectional` | ✅ Full activation | ⚠️ Partial activation (no `knowledge/`) |
| `cross-ecosystem-synergy-detection` | ✅ Hub-accumulated cross-ref | ⚠️ Your project only |
| `plugin-recommender` | ✅ Hub baseline grep | ⚠️ Your project baseline only |
| `apex-review` | ✅ Hub-accumulated baseline applied | ⚠️ Your project baseline only |
| `deliberation` *(fh-commons)* | ✅ Hub-accumulated argument cross-ref | ⚠️ Your project context only |
| Meta/hub seed accumulation | ✅ `knowledge/shared/` | ❌ Accumulated in your project only |

**History accumulation location**: Accumulated in your project only — user work does not accumulate in the meta-harness directory itself. Meta-harness maintains its identity as a **reference asset**.

**Indirect contribution channels (4 types)**

Mode C doesn't automatically transmit signals to the hub. Hub absorption **depends on user initiative**:

1. **GitHub Issue** — file an issue in the `forge-harness` repo
2. **External PR** — fork and submit a PR (CODEOWNERS alignment + hub review)
3. **Community channels** — discussion forums or communication channels relevant to your org
4. **Feature Request** — explicit request (user → maintainer → hub)

**Mode switching path (Mode C → A)**

```bash
git clone https://github.com/chronology-dev/forge-harness.git
cd forge-harness
claude   # Active onboarding auto-triggers → Mode A standard entry
```

Existing plugin install stays as-is (duplicate install check triggers automatically in active onboarding Step 1-b).

---

> **3-mode comparison summary** = `CLAUDE.md > Meta-harness usage modes (3 branches)` reference

#### Mode D — Agent file copy only (without plugin install)

The lightest entry method. Just copying a single agent `.md` file is enough to use immediately, without any plugin install.

```bash
# Copy only the fact-checker agent into your project
mkdir -p <your-project>/.claude/agents/
cp <harness-root>/.claude/agents/fact-checker.md <your-project>/.claude/agents/
```

| Item | Mode C (plugin) | Mode D (file copy) |
|---|---|---|
| Install method | `claude plugin install` | 1-line file copy |
| Updates | `claude plugin update` | Manual re-copy |
| Skill access | All plugin skills | Agent only |
| Best when | You want skills too | You only need 1-2 agents |

FH has 5 agents in `.claude/agents/`: `fact-checker` · `hub-persona-auditor` · `persona-innovator` · `plan` · `quench-challenger`

| Agent | Role | Tool restrictions |
|---|---|---|
| `plan` | Read-only design agent — analyzes files, maps impact scope, and plans before implementation | Read·Bash·Glob·Grep only (no Edit·Write) |
| `fact-checker` | Asset deduplication and staleness check | Read·Grep·Glob |
| `hub-persona-auditor` | 3+ persona audit of externally published assets | Read·Grep·Glob |
| `persona-innovator` | Naming exploration + frame proposals | Read·Grep·Glob·WebSearch·WebFetch |
| `quench-challenger` | Steel-quench adversary — pressure-tests near-final artifacts | Read·Grep·Glob |

#### Connecting FH context to existing project CC (cross-context)

Even after installing the plugin, **your existing project's Claude Code won't automatically recognize FH skills and sessions.** Adding the following single local file makes the project CC aware of forge-harness.

```bash
# 1. Copy the template
cp {FH_ROOT}/templates/local_fh_context.md .claude/rules/local_fh_context.md

# 2. Exclude from git tracking (so it's not committed to a shared team repo)
echo ".claude/rules/local_fh_context.md" >> .git/info/exclude
```

After this, when you run `claude` in that project, CC recognizes the FH skill list, session locations, and how to reference them as context. See `templates/local_fh_context.md` for the full template content.

> **Token efficiency**: The template is a pointer file containing only paths and skill names (~200 tokens). Skill details are referenced on-demand.

#### Federated marketplace architecture

This harness aims for a **federated ecosystem** where multiple marketplaces coexist, rather than a single monolithic marketplace.

*   **Meta marketplace (current):** `forge-harness` serves as a "meta marketplace" focused on operating and improving the overall system.
*   **Specialized marketplaces (roadmap):** Just as a plugin like `<your-mcp-plugin>` might specialize in "internal infrastructure integration," each "field" project can also develop its own unique skill set and become an independent "specialized marketplace."
*   **Synergy (current):** The `cross-ecosystem-synergy-detection` skill detects synergies among skills that come from multiple distributed marketplaces and are installed together, maximizing the value of the entire ecosystem.

---

### Manual path (when auto-mapping doesn't fit)

Only use when the recommended path doesn't work in your environment (e.g., projects scattered across multiple roots, monorepos, special structures).

**Step 1. Clone**

```bash
git clone https://github.com/chronology-dev/forge-harness.git ~/PycharmProjects/forge-harness
```

**Step 2. Create track directories**

```bash
# Track name = project name
mkdir -p ~/PycharmProjects/forge-harness/tracks/my-project/learnings
```

**Step 3. Copy CLAUDE.md to your project**

```bash
cp ~/PycharmProjects/forge-harness/templates/CLAUDE.md ~/my-project/CLAUDE.md
```

In the copied CLAUDE.md, replace `{project_name}` with **the track name you created in Step 2**.

**(Optional) Copy session rules**

```bash
cp -r ~/PycharmProjects/forge-harness/templates/.claude/ ~/my-project/.claude/
```

Customize sections marked with `[CUSTOMIZE]` comments to fit your project.

---

### Token cost optimization

Two paths to reduce cost and token usage when working with Claude Code. Immediately applicable in a meta-harness install environment.

#### FH native token overhead — measured

| Case | Overhead | Conclusion |
|---|:---:|---|
| **New install (FH standalone)** | ~29K tokens · 14.5% of 200K | ✅ Safe |
| **Existing team harness + adding FH** | Relative +48% increase | ⚠️ Resolved by applying optimizations below |

**Top 2 heavy files**: `.claude/rules/*.md` (~20K tokens) · `CLAUDE.md` (~8.7K tokens)

**Optimization**: Switching infrequently-used `.claude/rules` files to a keyword-trigger approach can save 5~8K tokens. The `context-doctor` skill can automatically diagnose this.

**Progressive Disclosure — deferred skill loading**

As skills grow, loading all skills at once causes attention fragmentation. FH uses keyword-trigger-based deferred loading to control "which skills are shown when."

| Approach | Behavior |
|---|---|
| Full upfront load | Full skill list always occupies context → attention scattered |
| Keyword-trigger deferred load | Only skills matching conversation context are loaded → focused context |

The `🔑` keyword pattern in `MEMORY.md` is the implementation of this mechanism. `.claude/rules` files can be configured the same way — load only when needed.

**1. `.claudeignore` standard — context blocking**

Specifies patterns that Claude Code should not read as context, using the same syntax as `.gitignore`. **Token cost savings** occur depending on project scale and structure.

```bash
# Copy the meta-harness standard template to your project root
cp ~/PycharmProjects/forge-harness/templates/.claudeignore <project>/.claudeignore
```

Default blocked targets: `node_modules/` · `dist/` · `.next/` · `*.lock` · `*.min.js` · `.env` · `.idea/` · `secrets/` · etc. Per-project customization recommended.

**2. Model switching — Sonnet for coding / Opus for reasoning**

Use Claude Code's built-in `/model` slash command to switch models mid-session. **opusplan hybrid** recommended — Opus for planning/reasoning, Sonnet for code generation, automatically.

```
# Manual switch
/model sonnet      # coding
/model opus        # reasoning/analysis

# Auto hybrid
/model opusplan    # planning/reasoning = Opus / code = Sonnet
```

> **Synergy ★★★**: Combining both paths produces **dual cost optimization** (reading fewer files + using the right model = multiplicative cost reduction).

**3. Agent view parallel execution — eliminating redundant rework cost**

In a normal single session, processing multiple tasks sequentially accumulates full context for each task. Agent view parallel dispatch is different:

| Approach | Token structure |
|---|---|
| Single session sequential | Task N × full accumulated context → cost spikes |
| Agent view parallel dispatch | Each agent works in a separate context with focus → overall cost reduced |

**Context Bridge supplement**: A session context card is automatically injected to prevent parallel agents from redundantly re-executing already completed work. See `context-bridge-dispatch` skill — automatically applied when you say "run in parallel."

> 2+ independent tasks → parallel dispatch via agent view is the default. 5-6x acceleration without wasted rework tokens.

**4. Automated periodic audits (zshrc hook)**

Checks the elapsed days since each audit item each time you open a terminal, and outputs a yellow warning when the threshold is exceeded.

```bash
# 1. Set path in .zshrc
export FH_DIR="$HOME/path/to/forge-harness"        # Required
export CC_HUB_DIR="$HOME/path/to/your-cc-hub"      # If you have a CC hub
export CC_SENTINELS_DIR="$HOME/.cc_sentinels"       # Project sentinel (optional)

# 2. Source the template
source "$FH_DIR/templates/cc_audit_check.zsh"
```

Auto-checked items:

| Item | Threshold | Condition |
|---|---|---|
| weekly_harvest | 7 days | `CC_HUB_DIR` set + recent `tracks/_meta/harvest_*.md` present |
| frontier_diagnosis | 90 days | `CC_HUB_DIR` set + `knowledge/shared/harness-core/` exists |
| FH internal sim (sim Area B) | 30 days | `FH_DIR` set + `tracks/_meta/` exists |
| Custom sentinel | Default 90 days | File in `CC_SENTINELS_DIR` + `CC_SENTINEL_{NAME}_DAYS` |

Custom sentinel — example of tracking quarterly project audits:

```bash
mkdir -p ~/.cc_sentinels
touch ~/.cc_sentinels/my_project_pfd          # Record audit completion
export CC_SENTINEL_MY_PROJECT_PFD_DAYS=90     # 90-day threshold
# After completing audit: touch ~/.cc_sentinels/my_project_pfd
```

> Full template: `templates/cc_audit_check.zsh` — works on macOS and Linux. Can also be pasted directly into `.zshrc`.

---

## Operating model — 3 Phase essence (invocation flow)

The meta-harness is **not a direct work tool**. Its actual role is split into 3 phases:

### Phase 1 — Initial setup assistance (active onboarding)

When a user greets or starts from the meta-harness cwd, this AI proactively proposes → asks about the task → runs 5 skills in sequence → setup → hands off to the project cwd. See `CLAUDE.md > Active onboarding behavior protocol` for details.

### Phase 2 — Backstage intermediary optimization

After initial setup, the user works directly from **the field project cwd**. The meta-harness is **not directly invoked**, but performs lateral optimization in its mapped state:
- `.claudeignore` standard applied (blocks unnecessary files from context → token savings)
- Model switching (`/model opusplan` — Opus reasoning / Sonnet code)
- fh-meta 23 skills naturally activate (description triggering — a mechanism where Claude automatically invokes a skill when keywords in the skill description match the conversation context)
- Optional persona layer plugin usage (e.g., `deep-insight`)

### Phase 3 — Threshold return (autonomous reverse proposals)

> **External validation**: Anthropic has officially demonstrated through experiments that harness combinations must move to a higher level — external basis for FH Phase III (autonomous synthesis, cross-project skill bus) direction.

When work matures and reaches a **threshold** where new skills or upgrades are possible, this AI **proactively proposes** meta-harness return from the field cwd:

| Trigger | Threshold signal |
|---|---|
| **New asset emerges** | First discovery of a generalizable pattern, skill, or behavioral protocol |
| **3+ accumulated upgrades** | Stabilization signal from the same asset evolving (aligned with simplification evidence baseline) |
| **Sister asset absorption** | PR audit gate passed for external assets (work from other CLIs, plugins, etc.) |

→ PR proposal to meta-harness after user approval gate. AI does not commit directly and follows the human approval path (`CLAUDE.md > How AI contributes (PR proposal principles)` aligned).

### Command tower orchestration pattern (advanced)

An advanced pattern using the meta-harness cwd as an **agent dispatch command tower**. Not pulling all work here, but choosing the optimal location by task type.

| Task type | Recommended location | Reason |
|---|---|---|
| Single project focused coding/debugging | **That project's cwd** | Domain CLAUDE.md rules + optimized execution environment |
| Meta/audit/simulation | **Meta-harness cwd + Agent** | Direct dispatch of sim-conductor·apex-review |
| Working on 2+ projects simultaneously | **Meta-harness cwd + parallel Agent** | 5-6x faster than sequential |
| field-harvest · PR audit · CATALOG updates | **Meta-harness cwd + Agent** | Has cross-project context |

**Parallel agent validated**: 1 meta-harness cwd instance → 6 background agents dispatched in parallel (3 field tasks + 3 simulation personas) → completed in ~3 minutes.

#### How to use Agents (parallel execution mode) — the environment where FH shines

**FH is the ideal environment for `claude agents` (parallel mode running multiple AI agents simultaneously).**
This is because the command tower structure (cc hub) + agent-composer (composition) + sim-conductor (persona dispatch) + deep-insight (3 agents) are already in place.

**How to enter** (terminal, v2.1.139+):
```bash
cd ~/PycharmProjects/forge-harness   # or your cc hub cwd
claude agents                         # Enter Agent View dashboard
```

Running agents are displayed in the bottom panel of Agent View. Click each one to view individual logs.

**Trigger via natural language in conversation**:
```
"Run this in parallel"
"Let's go into agents mode"
"These two tasks are independent so run them at the same time"
"Let's run a meta-simulation (multi-agent simulation)"
```

When there are 2 or more independent tasks, Claude Code automatically distributes them using the Agent tool.
If the composition is complex, run the **`agent-composer` skill** first to plan the Wave before dispatching.

> **Token efficiency**: Since each agent works in a separate context, overall token cost is lower than single-session sequential processing. The `context-bridge-dispatch` skill compensates for context gaps between agents, preventing redundant rework.

**Why FH maximizes this**:
- Ideation (Layer 2) → dispatch instructions via natural language
- Claude combines agent-composer · sim-conductor · deep-insight for parallel composition
- User focuses only on verifying results in Agent View (Layer 5 verification)
- Result absorption (Layer 6) → automatically returned via field-harvest · apex-review

**Related**:
- `plugins/fh-meta/skills/agent-composer/SKILL.md` — agent composition layer (Wave design + fan-in)
- [Claude Code Agents official documentation](https://docs.anthropic.com/en/docs/claude-code/sub-agents)

> "Don't block those who come, don't block those who go" — natural convergence, not forced passage. Deep focus on a single project stays at each field cwd as-is.

### Agent View optimized operations guide

Patterns to strictly follow when operating FH in Agent View (`claude agents`). Failing to follow these will result in repeated agent execution errors and inefficiency.

#### 1. Orchestrator principle — this cc composes only

In Agent View, this cc (orchestrator) handles **only composition decisions and result integration**. Even reconnaissance tasks like reading files and understanding structure are not done directly — they are dispatched to agents.

```
[Wrong pattern] This cc reads files directly → understands → dispatches agents
[Right pattern] Wave 0: dispatch reconnaissance agent → receive results → compose Wave 1
```

If the composition is complex, use `/agent-composer` to plan the Wave first before dispatching.

#### 2. Writing self-contained briefs

Each agent runs in an **independent context**. It does not share the context of other agents or this cc's session.

Required brief items:
- Goal (1-2 lines of clear task description)
- Target file paths (based on absolute paths)
- Expected output format
- How to pre-load required tools (see Deferred tool pattern below)

#### 3. Deferred tool pre-loading — required when using MCP tools

MCP tools start in a **Deferred state** in Agent View. Calling them directly without `ToolSearch` causes `InputValidationError`.

Include the following pattern in the agent brief:

```
1. First call the ToolSearch tool to load the required tool schema:
   ToolSearch query "select:jira_search_issues"
2. After the schema loads, call that tool.
```

#### 4. Working around MCP pagination limits

Some MCP tools have restricted pagination parameters. Known workarounds:

| Tool | Restriction | Workaround |
|---|---|---|
| `jira_search_issues` | `startAt` parameter not supported | Sequential collection via `key < XXXXX ORDER BY created DESC` JQL chaining |

#### 5. Hook considerations in Agent View

Claude Code hooks (PostToolUse, Stop, etc. configured in settings.json) **do not trigger in Agent View.** Hook execution semantics differ from standard terminal.

Affected hook examples:
- Session end push confirmation trigger
- Stop event-based notifications

Response: If hook-dependent behavior is needed for Agent View-specific tasks, **replace with explicit skills** or verify in standard terminal after completion.

### Dual verification principle (external + internal verification in parallel)

> **Dual verification**: The principle of running an external verification path (real user reactions) and an internal verification path (multi-skill automated chain) simultaneously to eliminate self-reference risk.

Running only a single path is a self-reference risk. Run both paths in parallel for independent verification:

| Verification path | Path | Purpose |
|---|---|---|
| **External verification** | External install → collect reactions → record timestamp | External mirror — real external user validation |
| **Internal verification** | `deep-insight` → `cross-ecosystem-synergy-detection` → `verify-bidirectional` → learnings push | Internal multi-skill verification chain |

External only = waiting for external reactions manually + no internal quality supplement
Internal only = owner environment internal loop = self-reference risk
**Parallel** = external mirror + internal multi-verification running simultaneously → eliminates single point of failure

> **External validation status** (last updated: 2026-05-15):
> - **cascade α** (internal users including owner running autonomously): achieved
> - **cascade β** (user other than owner running autonomously): validated by an external user on 5/12 — first autonomous run by a non-owner achieved
> - **External review of agent deliverables**: PR #280 merged by external reviewer (5/15) → v1.0 release gate condition fulfilled.

### Steel-quench convergence — multi-layer defense structure

steel-quench sessions on this harness consistently show a pattern: Wave 1 surfaces S-grade blockers, Wave 2 defends or patches them, and Wave 3 terminates without new S-grade findings. This section documents the structural design that produces that convergence, along with supporting evidence.

#### Observed evidence

| Milestone | Date | Verification type |
|---|---|---|
| cascade α: owner autonomous run | prior to 5/12 | Internal session logs |
| cascade β: non-owner autonomous run | 5/12 | External user — first non-owner autonomous execution |
| Agent deliverable external review | 5/15 | PR #280 merged by external reviewer |
| Wave 4 (meta-devil) convergence | 5/19 | steel-quench 4-Wave session log |

#### 4-Layer Defense structure

| Layer | Name | Role |
|:---:|---|---|
| **L1** | Internal self-diagnosis | harness-doctor + context-doctor + sim-conductor Area B — periodic internal weakness detection. Structural analogue of N-Version Programming (multi-version cross-validation) applied to AI orchestration. |

> **Self-Evaluation Bias**: When the same model evaluates its own output, confirmation bias occurs. Three-Doctor Loop addresses this with isolated third-person evaluation roles. (Pattern documented in Anthropic multi-agent research, 2025)
| **L2** | External verification loop | Real user feedback + external PR review — evidence generated outside the owner environment |
| **L3** | Quenching circuit | steel-quench pre-runs the same attack angles internally. Flaws surfaced here are patched before external devil sessions begin. |
| **L4** | Meta-aware adversary principle | As Wave N deepens, remaining attackable S-grade surface shrinks because prior waves have already consumed it — convergence is structural, not coincidental |

#### Why wave convergence happens

**1. Brain in a Vat asymmetry**

The devil operates from an isolated sub-agent sandbox, seeing only static code and documents. Living evidence from the operating system — external contributions, real user sessions, approval records — exists outside that boundary. The defender can reach this evidence; the devil cannot. Asymmetric information access, not inherent system strength, explains the divergence in Wave 2 defense quality.

**2. Sandboxed Adversary structure**

The devil runs as an agent dispatched by the same meta-harness it is attacking. Its "self-referential closed system" attack must contend with the fact that it is itself one component in the orchestration it is evaluating. This does not invalidate the attack, but it structurally limits the depth of the closed-loop claim.

**3. Pre-patching via simulation**

sim-conductor Area B runs periodic internal simulations ahead of any external devil session. Flaws discovered by simulation are patched immediately. When the devil arrives, the surface area of discoverable S-grade findings is already reduced — not by defense arguments, but by prior implementation fixes.

#### Evidence against common attack vectors

| Attack angle | Devil's claim | Counter-evidence |
|---|---|---|
| Self-referential closed system | "Only internal loops" | sim-conductor isolated environment + external user verification (5/12, 5/15) |
| Single bus factor | "Stops without the owner" | PR #280 merged by external reviewer (5/15) without owner involvement |
| No real users | "No actual users" | Non-owner autonomous run confirmed 5/12 |
| Anthropic ecosystem obsolescence | "Will be absorbed by the official ecosystem" | Domain-specific curation layer operates at a different abstraction than general tools |
| AI-specific attacks (meta-devil W4) | "API failure · Context Collapse · Prompt Injection · self-verification closure — 4 compounded risks" | steel-quench 4-Wave session (5/19): SessionStart hook + prompt injection sanitizer implemented. Open: heterogeneous model external gate |

**Convergence pattern**: Decreasing S-grade blockers per wave is not attack failure — each wave patches real flaws; subsequent waves find fewer because fewer remain. Run `/steel-quench` to observe this pattern on your own installation.

---

### Why isolation — the structural limitation of self-inspection

The biggest pitfall in AI tool quality verification is **the creator doing the testing**. The creator already knows the internal structure and cannot reproduce the confusion points that new users encounter.

`sim-conductor` solves this structural limitation.

```
Development environment (~/PycharmProjects/forge-harness/)
         ↕ Physical isolation
Isolated environment (~/sim/observer/)   ← New user reproduction space
```

- **Physical isolation**: Starts from zero development context. Internal knowledge the creator has is blocked.
- **3 personas**: newcomer (new user) · power-user (advanced user) · devil-advocate (critical reviewer) — each reproduces different confusion points.
- **Self-reference awareness**: devil-advocate also captures that the simulation itself is an internal consistency check. This meta-awareness clarifies the necessity of an external mirror (actual external user validation).

Evidence: PR #18 cleaned up descriptions, but the same vocabulary recontaminated plugin.json. Self-inspection was cleaning, not vaccination. Simulation automatically surfaced 6 ship-blockers + 14 improvements (first run 2026-05-09).

---

**Core**: meta-harness = **launch pad** (accelerates and coordinates field projects / does not do direct work). Mediates setup, optimization, and evolutionary return for all field projects. *"A good harness gets progressively simpler"* principle — however, meta-harness **gets simpler within its own specification (the meta layer)**.

---

## Learn more

- `CLAUDE.md` — Sync/Push protocol details
- `CATALOG.md` — Search index format
- `CHEATSHEET.md` — Full command reference
- `templates/.claude/rules/session.md` — Session rules template (check `[CUSTOMIZE]` points)

---

## Appendix

### Identity — 3-layer mission

| Layer | Role | Reference |
|---|---|---|
| **① Meta hub** | Connect and coordinate field projects. Each project is an execution site; here is the common standard and return center | `CLAUDE.md` · `CATALOG.md` |
| **② Frontier → org propagation** | Take the lead in applying AI/harness frontier philosophy, translate and propagate in your organization's language | `knowledge/shared/harness-core/` |
| **③ AI collaboration guide** | Accumulate and distribute best practices for token efficiency and dialogue methodology | `CHEATSHEET.md §4·§10` |
| **Cross-cutting axis** | **Harness engineering (How)** — the methodology realizing the 3 layers above. "A good harness gets progressively simpler" principle | `CHEATSHEET.md §7·§8` |

**Cross-cutting axis ④ execution patterns — external applicability:**

| Pattern | Applicability |
|---|---|
| Single / Subagent / Team pattern selection principles | ✅ Generally applicable — works in all environments |
| Ralph Loop (collaboration pattern where completion criteria are agreed first, then iterated) | ✅ Generally applicable — works in all environments |
| Phase 1 → 2 → 3 progression | ✅ Generally applicable — works in all environments |
| Owner track configuration (specific project tracks) | ⚠️ Owner-specific example — replace with your own project tracks |
| Internal infrastructure + internal MCP integration | ⚠️ Owner-specific example — replace with your own internal infrastructure |

### Directory structure

```
forge-harness/
├── knowledge/             # Pure knowledge — time-independent, for reference
│   ├── domain/            # Domain-specific knowledge (TC, policy glossaries, etc.)
│   └── shared/            # Cross-project patterns
│
├── tracks/                # Work records per project — time-accumulated
│   └── {project_name}/    # Per-project directory
│       ├── session_*.md   # Session history
│       └── learnings/     # Accumulated feedback
│
├── templates/             # Skeletons to copy for new projects
│   ├── .claude/rules/session.md
│   └── CLAUDE.md
├── CATALOG.md             # Full search index
├── CLAUDE.md              # Sync/Push protocol
└── CHEATSHEET.md          # Command cheat sheet
```

### Key terms

| Term | One-line definition |
|---|---|
| **Meta-harness** | A persistent hub that connects the work, learnings, and patterns of N projects in a Claude Code environment for mutual reinforcement |
| **Meta hub** | The role of connecting and coordinating all field projects from the meta-harness cwd — the hub centers on common standards and return, while each project is an execution site |
| **Launch pad effect** | Using meta-harness as a launch pad rather than a final destination — even a brief stopover produces setup, pattern-sharing, and speed-improvement effects. The user-perspective expression of **Transit Acceleration Value** |
| **Transit Acceleration Value** | The core value of meta-harness — passing through itself accelerates the starting line. Acceleration effect occurs the moment of passing, with no obligation to absorb or settle (Transit Acceleration Value). **Launch pad effect** is the field-observation result of this principle |
| **Shared skill pool** | Eliminating the cost of each team and harness individually reinventing the same skills and agents — meta-harness provides a common pool and each project uses it |
| **persona-innovator** | Naming gap detection + ideation algorithm + technology bridge exploration agent — discovers unnamed patterns in existing assets, scans external frontier signals, and proposes technical constraint workaround paths (Mode I/E/F/T) |
| **sim-conductor** | **[Three-Doctor Loop — future behavior prediction role]** Meta-simulation automation orchestrator — answers the question "What happens when real people use this system?" Unlike harness-doctor (current skeleton diagnosis) and context-doctor (current context diagnosis), **predicts future behavior that hasn't happened yet** via personas. Pre-runs the experience of specific users (new team members, external installers, critical reviewers) encountering the system for the first time, in a physically isolated environment (`~/sim/`). Autonomously completes Area A (external user) · B (internal audit) · C (innovator scan) · D (deliverable verification) · E (output quality review), processes M-tier PRs automatically. **Validated**: external user autonomous run 5/12 → cascade β achieved (first autonomous run by non-owner) |
| **context-doctor** | Token efficiency diagnosis skill — auto-generates `.claudeignore`, detects large file bursts, guides `/clear` timing |
| **hub-persona-auditor** | Pre-publication audit agent for externally published assets — simulates 3+ virtual reader personas · 4-axis review (empathy/doubt/resistance/supplement) · 3-tier revision proposals. Internal notes, code, and PR reviews are not targets |
| **fact-checker** | Duplicate and stale fact checking agent — verifies existing assets via grep before recommending new assets + detects memory, document date, and counter errors |
| **External user** | Anyone outside the hub — a non-owner user from another team in your organization or an entirely external user. Skill operation scope differs depending on available infrastructure |

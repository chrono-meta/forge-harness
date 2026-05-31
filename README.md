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

Teams that have systematically used AI collaboration tools are already doing **harness engineering** (QA protocols, TC design gates, verification pipelines — any structure that makes AI behave more consistently). forge-harness is the **OS one layer above** — a system that measures, improves, and evolves the harness itself across multiple projects.

| Layer | What it does | Examples |
|---|---|---|
| Harness engineering | Per-project rules, gates, context management | QA protocols, CLAUDE.md rulesets, TC verification pipelines |
| **Meta harness engineering** | Cross-project system to measure, improve, evolve harnesses | FH skill bus, harness-doctor HHS, steel-quench, field-harvest |

> **FH v1.0 paper** — published 2026-05-30 on [Zenodo](https://zenodo.org/records/20397566) (DOI: 10.5281/zenodo.20397566) · arXiv submission pending. Documents the 2-layer design, 6-axis framework, 4-agent orchestration, and compounding loop with controlled empirical evidence.

> **External validation (2026)** — three independent research findings converge:
> - VILA-Lab analysis of Claude Code v2.1.88 (512K lines): [98.4% is harness infrastructure, 1.6% AI logic](https://arxiv.org/abs/2604.14228)
> - "[Code as Agent Harness](https://arxiv.org/abs/2605.18747)" (arXiv, May 2026, 43 authors) — code as foundation for agent infrastructure
> - Stanford IRIS Lab: "[Meta-Harness](https://arxiv.org/abs/2603.28052)" (Lee et al., Mar 2026) — outer-loop harness optimization; +7.7pts at 4× fewer tokens
>
> FH is applied meta-harness engineering at exactly this layer. Detailed concept: `knowledge/shared/harness-core/meta_harness_engineering_definition.md`.

#### FH vs. automated harness tools

The Stanford paper inspired [harness-evolver](https://github.com/raphaelchristi/harness-evolver) (MIT, 2026) — a fully automated 7-stage CODE optimizer (LangSmith + Python). FH independently converged on the same loop architecture from the opposite direction:

| Axis | harness-evolver | forge-harness |
|---|---|---|
| **Optimization target** | Harness code (prompts, routing) | Harness knowledge (context, patterns, expertise) |
| **Evolution** | Auto-merge winners to git | Human-approved at every stage |
| **Infrastructure** | LangSmith + Python 3.10+ | CLAUDE.md + skills only, zero extra |
| **Scope** | Single-harness optimization | Multi-project federation, shared skill bus |
| **Knowledge layer** | No persistent curation | `tracks/` + `knowledge/` grow over time |

**Use FH** for accumulated domain knowledge, multi-project coordination, human-judgment gates, and zero infrastructure. **Use harness-evolver** for fully automated CODE search at benchmark scale on existing LangSmith. They're complementary — FH's approval gates + knowledge layer fill exactly the gaps automated CODE search leaves open.

### Environment Engineering

FH doesn't change the agent — it changes the environment. Three mechanisms remove the "orientation tax" agents pay before they can find their direction: **MEMORY.md keyword-trigger** (skip loading unused knowledge), **mandatory Context Card injection** (no rebuilding session context from scratch), **PFD domain knowledge pre-loading** (no first-round codebase exploration).

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

## Real-world case — AI TC generation prompt hardening

> **Context**: An AI-powered test case generation tool was merging TC outputs without quality validation. Prompts contained cushion language, phantom claims, and no priority guardrails.

**Applied**: `steel-quench` (W1–W8 adversarial hardening) + `source-grounding-audit` (phantom claim detection)

| Wave | What was attacked | Result |
|---|---|---|
| W1–W2 | Cushion language ("it would be good to…") → forced conditions | Ambiguity eliminated |
| W4–W5 | No self-check step → Self-Check quality gate added (3-a stage) | Quality bypass path closed |
| W6 | Soft review → Hard gate ("no next step until fix complete") | Incomplete TC merge blocked |
| W7 | P0 ratio inflation → forced re-review above 30% | Priority inflation prevented |
| W8 | Phantom Claim Guard — unspecified values/button names/error messages banned | Fabricated expected results blocked |
| Execution | `### Result` header missing bug found (parser `has_result=False`) | Fixed immediately |

**Outcome**: 4 bugs found and fixed (missed in theory review, caught by live execution) · 8-layer quality gate complete · output noise eliminated (`### Thinking`, `### Review Report` sections removed)

> The self-healing loop: steel-quench attacks the prompt → execution catches bugs the review missed → fixes are verified in the same pass. The harness improved itself during validation.

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

## Architecture — 2-layer design

forge-harness is structured as two distinct layers with different portability profiles:

| Layer | Contents | AI compatibility |
|---|---|---|
| **Methodology layer** (model-agnostic) | `tracks/`, `knowledge/`, `SKILL.md` documents, session protocols | Any AI model |
| **Automation layer** (Claude-native) | `.claude/agents/`, hooks, slash commands, `CLAUDE.md` rules | Claude Code only |

**Methodology layer** is the portable core: the pattern of connecting projects to a persistent hub, accumulating learnings in `tracks/`, and curating cross-project knowledge in `knowledge/shared/` works regardless of which AI you use. SKILL.md files document the methodology in plain language.

**Automation layer** is what makes the methodology frictionless when running Claude Code: agents dispatch automatically, hooks fire at session boundaries, and slash commands invoke skills without manual prompting.

> **Codex-compatible beta**: The Methodology layer is designated Codex-compatible beta. Gemini, Codex, and other AI users can apply FH methodology manually — the tracks/ and knowledge/ structure, sync protocols, and skill documentation all translate. Automation layer features (agents, hooks) require Claude Code as host.

> **Multi-model via sidecar (validated)**: Any FH user can delegate tasks to other models as sidecars — Gemini CLI, OpenAI/Codex CLI, or Copilot CLI's model catalog (Codex / Gemini / Claude Opus) — called via `Bash` from within a Claude Code session. FH remains the orchestrating harness; the sidecar is a routing/access layer, not a second harness. Use cases: token economy (offload subsidiary tasks), model-access fallback (e.g., when CC standalone is Sonnet-only on a restricted network, a sidecar reaches Opus), adversarial diversity (route a second challenger pass to a different model). Validated empirically with `gemini` CLI and Copilot CLI.

For runtime agent specs, see `AGENTS.md`. For session rules and orchestration protocol, see `CLAUDE.md`.

### Governance layer for AI-generated code (empirically validated)

FH can wrap any coding agent (OpenCode, Codex, etc.) as a **post-generation governance layer** — no runtime adapter needed. FH reads files the agent writes; the protocol is the interface.

```bash
# After a coding agent completes a task:
./scripts/fh-gate.sh                   # auto-detects changed files from git diff
# → steel-quench adversarial pass      # behavioral edges, untested contracts, security
# → pipeline-conductor --quick         # 4-axis: regression / adversarial / grounding / record
# → FH_STATUS + FH_GATE_VERDICT        # PASS | PENDING | BLOCKED | ESCALATE
```

**Empirical result (2026-05-31)**: Applied to OpenCode's own AI-generated `permission/arity.ts` (163 lines, 6 tests passing, CI green). Governance verdict: PENDING — 2 A-grade findings CI didn't cover (short-token overflow in allowlist, executor tools absent from arity table). Delta attributable to methodology layer, not the model.

Full specification: `knowledge/shared/harness-core/fh_integration_contract.md` · Usage guide: `knowledge/shared/harness-core/fh_opencode_governance_wrapper.md`

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

> **git push on personal/external networks**: Direct HTTPS push to github.com works without any workaround. Corporate environments with a SASE or TLS-inspection proxy may need a REST API alternative — check with your network team.

---

## Get started in 2 minutes (Recommended — semi-automated Claude mapping)

### Step 0. Register the plugin (prerequisite for using skills)

> **If this is your first install, complete this step first.** FH skills like `/install-wizard` only activate after the fh-meta plugin is registered in Claude Code.

```bash
# [Terminal] Add marketplace
claude plugin marketplace add https://github.com/chrono-meta/forge-harness.git

# [Terminal] Install plugin (user scope — available in all projects)
claude plugin install -s user fh-meta@forge-harness
```

Verify installation: type `/skills` in the CC chat → if `install-wizard` appears in the list, you're done.

> If you've already installed the plugin, skip straight to Step 1.

### Step 1. Clone the hub

> **Prerequisites**: A GitHub account and git credentials configured. If `git clone` fails with an authentication error, set up SSH keys or create a personal access token (GitHub → Settings → Developer settings → Personal access tokens) and retry.

```bash
git clone https://github.com/chrono-meta/forge-harness.git ~/forge-harness

cd ~/forge-harness
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
> - **Only a generic response like "Hello! How can I help you today?"** → Run `pwd` to confirm you're in the `forge-harness` root. If not, run `cd ~/forge-harness` then `claude` again.
> - **"CLAUDE.md not found" error** → Verify the clone went to the right path: `ls ~/forge-harness/CLAUDE.md`
> - **Clone fails with authentication error** → SSH key or personal access token setup required (see Step 1 prerequisites above)

Once open, just talk to Claude:

- **"Connect a project"** → The hub automatically scans `../` (the directory above the hub), lists projects with `.git` as candidates
- **Select the desired project number** (this step requires user selection) → `tracks/{project}/` is auto-created, a template CLAUDE.md is placed if none exists, or a hub reference block is proposed if one exists
- **"My projects are in `~/work/`"** → You can specify a different root
- If unclear, Claude will ask first

See `CLAUDE.md > Auto Project Mapping Protocol` for detailed detection and mapping procedures.

---

## Already using it — 35 asset activation check (29 fh-meta + 4 fh-commons skills, 6 agents)

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
| `pipeline-conductor` | 4-axis quality gate (backward / adversarial / forward / record) for FH assets and external code | "Run the quality gate", "4-axis check", "pipeline-conductor before merge" | □ |
| `goal-quench` | `/goal` wrapper: pre-run token budget gate + mid-run thresholds + post-run pipeline-conductor verification | "Safe goal run", "Goal with budget control", "Run /goal with a quality gate" | □ |
| `edit-manifest` | Predict-verify loop for harness edits — records falsifiable prediction, verifies outcome next session | "Log this edit", "Predict what this changes", "Manifest before committing" | □ |
| `memory-hygiene` | Detect stale-but-confident memory entries — re-verify live, classify by staleness, propose archival | "Check stale memory", "Memory drift", "Verify my memory entries" | □ |
| `prompt-regression` | Detect harness behavioral regressions after CLAUDE.md / rule / skill edits via probe suite | "Did my rule change break anything?", "Regression check", "Test harness changes" | □ |
| `convergence-loop` *(fh-commons)* | Replace single-pass gates with N-round convergence loops; only declare "truly passed" after convergence | "How many rounds do we need", "Suspicious of single-pass", "Convergence loop" | □ |
| `token-budget-gate` *(fh-commons)* | Pre-task token cost estimate (GREEN/YELLOW/ORANGE/RED) before expensive multi-agent tasks | "How expensive is this?", "Token budget estimate", "Will this cost a lot" | □ |
| `mcp-circuit-breaker` *(fh-commons)* | Detects MCP tool failure patterns (3 fails = trip), blocks further calls, proposes fallbacks | "MCP keeps failing", "Tool error loop", "Circuit-breaker" | □ |
| `quench-challenger` *(fh-commons)* | Steel-quench adversary — pressure-tests near-final artifacts from devil + innovator + prescriber angles | "Challenge this with a devil", "Adversarial review", "Quench challenger" | □ |

| Check count | Diagnosis |
|:---:|---|
| **28-35** | Advanced stage — focus on `agent-composer` + `sim-conductor` + `steel-quench` + `pipeline-conductor` + governance layer (chained verification) |
| **10-27** | Activation stage — gradually activate unchecked assets |
| **0-9** | Early stage — go back to the self-diagnosis above and follow the standard entry |

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

The hub has two entry paths: **clone** = persistent hub (`tracks/` + `knowledge/` + CLAUDE.md mapping, see `Get started in 2 minutes`) and **plugin** = meta tool bundle activating skills + agents. Both installed = full synergy. Three user modes (Mode A standard / B resident / C plugin-only) follow *"don't block those who come or go"*; this § covers the plugin path. For Mode C onboarding see `Mode C user guide` below.

```bash
# [Terminal — not in the Claude chat window]
claude plugin marketplace add https://github.com/chrono-meta/forge-harness.git    # .git suffix required
claude plugin install -s user fh-meta@forge-harness                                # -s user = all projects (recommended)
```

Verify with `/skills` or `/agents` in the Claude Code chat window. Updates aren't automatic — run `claude plugin update fh-meta@forge-harness` periodically.

> **Mode C (plugin-only)** is legitimate but partial: `verify-bidirectional`, `apex-review` activate without their `knowledge/` baseline; `cross-ecosystem-synergy-detection`, `plugin-recommender`, `deliberation`, `convergence-loop` work fully. For full synergy use Mode A; full Mode C onboarding below.

#### Plugin catalog

| Plugin | Nature | skills | agents |
|---|---|---|---|
| **fh-meta** (v1.2.0) | Hub meta operation tool bundle — 29 skills (agent-composer · apex-review · asset-placement-gate · contention-layer · context-bridge-dispatch · context-doctor · cross-ecosystem-synergy-detection · deep-clarify · edit-manifest · field-harvest · frontier-digest · goal-quench · harness-doctor · harvest-loop · hub-cc-pr-reviewer · install-doctor · install-wizard · marketplace-gate · memory-hygiene · meta-prompt-builder · pipeline-conductor · plugin-recommender · prompt-regression · self-marketing-lint · sim-conductor · source-grounding-audit · steel-quench · verify-bidirectional · and more) + 3 agents (hub-persona-auditor · fact-checker · persona-innovator). **Verification pair**: steel-quench (output pattern attack) + source-grounding-audit (input source tracing) | 29 | 3 |
| **fh-commons** (v0.2.0) | Domain-agnostic general utilities — 4 skills (convergence-loop · deliberation · mcp-circuit-breaker · token-budget-gate) + 1 agent (quench-challenger) | 4 | 1 |

> **Asset count SoT**: `plugins/fh-meta/.claude-plugin/plugin.json` is the canonical source. If the numbers above don't match, use plugin.json as the reference.

#### External persona layer synergy (optional)

`sim-conductor` and `hub-persona-auditor` work standalone. Adding a persona agent plugin (validated 6-role pattern: newcomer · power-user · pm · qa · devil-advocate · synthesizer) expands `sim-conductor` Area A from single-perspective to multi-role simulation. Integration contract: `plugins/fh-meta/skills/sim-conductor/SKILL.md §Area A`.

```bash
claude plugin marketplace add <your-marketplace-url>
claude plugin install -s user <your-persona-plugin>@<your-marketplace>
```

#### Mode C user guide (plugin only — no clone)

Use Mode C if you only want plugin skills and prefer to keep your own project history on your side (FH stays as a reference asset).

```bash
claude plugin marketplace add https://github.com/chrono-meta/forge-harness.git
claude plugin install fh-meta@forge-harness
cd ~/projects/{your-project} && claude   # no FH cwd entry
```

**Limitations** (Mode A vs Mode C):

| Skill / area | Mode A | Mode C |
|---|:---:|:---:|
| `verify-bidirectional` · `apex-review` | ✅ hub baseline | ⚠️ no `knowledge/` |
| `cross-ecosystem-synergy-detection` · `plugin-recommender` · `deliberation` | ✅ hub cross-ref | ⚠️ your project only |
| Meta/hub seed accumulation | ✅ `knowledge/shared/` | ❌ your project only |

**Hub contribution channels** (no automatic signals in Mode C): GitHub Issue · External PR (fork + review) · community channels · Feature Request.

**Upgrade to Mode A**: `git clone https://github.com/chrono-meta/forge-harness.git && cd forge-harness && claude` — existing plugin install is preserved (duplicate-check in active onboarding Step 1-b). Full mode reference: `CLAUDE.md > Meta-harness usage modes`.

---

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
*   **Specialized marketplaces (roadmap):** Just as a domain-specific plugin might specialize in "internal infrastructure integration" or "QA automation," each "field" project can develop its own unique skill set and become an independent "specialized marketplace."
*   **Synergy (current):** The `cross-ecosystem-synergy-detection` skill detects synergies among skills that come from multiple distributed marketplaces and are installed together, maximizing the value of the entire ecosystem.

---

### Manual path (when auto-mapping doesn't fit)

Use when the recommended path doesn't work (projects across multiple roots, monorepos, special structures):

```bash
git clone https://github.com/chrono-meta/forge-harness.git ~/forge-harness
mkdir -p ~/forge-harness/tracks/my-project/learnings              # track name = project name
cp ~/forge-harness/templates/CLAUDE.md ~/my-project/CLAUDE.md     # then replace {project_name} with the track name
cp -r ~/forge-harness/templates/.claude/ ~/my-project/.claude/    # (optional) session rules — customize [CUSTOMIZE] markers
```

---

### Token cost optimization

**FH native overhead** — measured: new install standalone = ~29K tokens (14.5% of 200K, safe). Existing team harness + FH = +48% relative; offset by the four optimizations below. Top 2 heaviest files are `.claude/rules/*.md` (~20K) and `CLAUDE.md` (~8.7K). `context-doctor` diagnoses and recommends keyword-trigger deferral for infrequently-used rules (saves 5–8K).

**Progressive Disclosure**: FH uses keyword-trigger deferred loading so only context-relevant skills enter attention. The `🔑` keyword pattern in `MEMORY.md` implements this; `.claude/rules` files can be configured the same way.

**1. `.claudeignore` standard** — `.gitignore`-syntax patterns Claude Code skips. Copy `templates/.claudeignore` to your project root. Defaults: `node_modules/` · `dist/` · `.next/` · `*.lock` · `*.min.js` · `.env` · `.idea/` · `secrets/`.

**2. Model switching** — `/model sonnet` (coding) · `/model opus` (reasoning) · `/model opusplan` (auto hybrid: Opus reasoning + Sonnet code). Combined with .claudeignore: multiplicative cost reduction.

**3. Agent view parallel execution** — Single-session sequential accumulates full context per task; Agent View dispatches each task to a separate focused context, cutting overall cost. `context-bridge-dispatch` skill auto-injects a session context card (say "run in parallel"). 2+ independent tasks → parallel by default; 5–6× acceleration.

**4. Automated periodic audits** — terminal-start zshrc hook warns when audit thresholds are exceeded:

```bash
export FH_DIR="$HOME/path/to/forge-harness"
export CC_HUB_DIR="$HOME/path/to/your-cc-hub"      # optional
export CC_SENTINELS_DIR="$HOME/.cc_sentinels"      # optional
source "$FH_DIR/templates/fh_audit_check.zsh"
```

Checked items: `weekly_harvest` (7d, `CC_HUB_DIR` + `tracks/_meta/harvest_*.md`) · `frontier_diagnosis` (90d, `knowledge/shared/harness-core/`) · `sim Area B` (30d, `FH_DIR` + `tracks/_meta/`) · custom sentinels (`CC_SENTINEL_{NAME}_DAYS`, e.g. `touch ~/.cc_sentinels/my_project_pfd` + `export CC_SENTINEL_MY_PROJECT_PFD_DAYS=90`). Full template: `templates/fh_audit_check.zsh` (macOS / Linux).

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

#### How to use Agents (parallel execution mode)

FH is purpose-built for `claude agents` (parallel mode) — the command tower (cc hub) + agent-composer (composition) + sim-conductor (persona dispatch) + optional deep-insight are already wired together.

```bash
cd ~/forge-harness && claude agents      # v2.1.139+ — Agent View dashboard
```

Running agents appear in the bottom panel; click for individual logs. Trigger via natural language: *"Run this in parallel"* · *"Let's go into agents mode"* · *"Run a meta-simulation"*. With 2+ independent tasks, Claude Code auto-distributes via the Agent tool. For complex compositions, run `/agent-composer` first to plan Waves. Each agent has separate context → lower total cost than sequential; `context-bridge-dispatch` injects session cards to prevent rework.

Related: `plugins/fh-meta/skills/agent-composer/SKILL.md` · [Claude Code Agents docs](https://docs.anthropic.com/en/docs/claude-code/sub-agents).

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

### Dual verification (external + internal in parallel)

Running a single verification path = self-reference risk. FH runs both in parallel: **external** (real-user install → reactions → timestamp) as the external mirror, and **internal** (`deep-insight` → `cross-ecosystem-synergy-detection` → `verify-bidirectional` → learnings push) as the multi-skill chain. Parallel eliminates the single point of failure.

> **External validation status** (2026-05-15): cascade α (owner autonomous) ✅ · cascade β (non-owner autonomous run 5/12) ✅ · external review of agent deliverables — PR #280 merged 5/15 by external reviewer (v1.0 release gate fulfilled).

### Steel-quench convergence — multi-layer defense structure

steel-quench sessions on this harness consistently converge: Wave 1 surfaces S-grade blockers, Wave 2 patches them, Wave 3 terminates without new findings. Each wave patches real flaws; subsequent waves find fewer because fewer remain. Run `/steel-quench` to observe this on your own installation.

**4-Layer Defense**:

| Layer | Mechanism |
|:---:|---|
| **L1** Internal self-diagnosis | harness-doctor + context-doctor + sim-conductor Area B — isolated third-person evaluation roles address self-evaluation bias (Anthropic multi-agent research, 2025) |
| **L2** External verification | Real user feedback + external PR review — evidence generated outside owner environment |
| **L3** Quenching circuit | steel-quench pre-runs attack angles internally; flaws patched before external devil sessions |
| **L4** Meta-aware adversary | Remaining attack surface shrinks per wave; convergence is structural, not coincidental |

**Why it converges**: (1) Devil sees only static artifacts; living evidence (PRs, user sessions) sits outside its sandbox — defender can reach it, devil cannot. (2) The devil is itself an agent in the system it's evaluating, structurally limiting closed-loop attacks. (3) sim-conductor Area B pre-patches flaws via internal simulation, reducing discoverable S-grade surface before external devils run.

**Validated against common attacks**: self-referential closure (sim-conductor isolation + external verification), single bus factor (PR #280 merged 5/15 by external reviewer without owner), no real users (non-owner autonomous run 5/12), Anthropic obsolescence (domain curation operates at different abstraction), AI-specific compound risks (steel-quench W4 5/19: SessionStart hook + prompt injection sanitizer), harness unnecessary (VILA-Lab: [98.4% of Claude Code is harness infrastructure](https://arxiv.org/abs/2604.14228)).

---

### Why isolation — structural limitation of self-inspection

Creators can't reproduce the confusion points new users encounter — they already know the internal structure. `sim-conductor` solves this with physical isolation (`~/sim/observer/` blocks dev context) and 3 personas (newcomer · power-user · devil-advocate) that surface different confusion patterns. Evidence: PR #18 cleaned descriptions but the same vocabulary recontaminated `plugin.json` — self-inspection was cleaning, not vaccination. Simulation surfaced 6 ship-blockers + 14 improvements on first run (2026-05-09).

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
| **Meta-harness** | A persistent hub connecting work, learnings, and patterns of N Claude Code projects for mutual reinforcement |
| **Meta hub** | Coordinator role of the meta-harness cwd — common standards + return center; each project is an execution site |
| **Launch pad effect / Transit Acceleration Value** | Meta-harness as launch pad, not destination — passing through accelerates the starting line; no obligation to absorb or settle |
| **Shared skill pool** | Common skill/agent pool eliminating reinvention cost across teams and projects |
| **sim-conductor** | Three-Doctor Loop — future behavior predictor. Persona-driven meta-simulation (Areas A/B/C/D/E) in isolated `~/sim/` env. Cascade β validated 5/12 (first non-owner autonomous run) |
| **context-doctor** | Token efficiency — auto-generates `.claudeignore`, detects large-file bursts, guides `/clear` timing |
| **persona-innovator** | Naming gap detection + ideation + tech-bridge exploration (Mode I/E/F/T) |
| **hub-persona-auditor** | Pre-publication 4-axis (empathy/doubt/resistance/supplement) audit for externally-published assets across 3+ personas |
| **fact-checker** | Pre-recommendation duplicate/stale check via grep — also catches memory/document date/counter errors |
| **External user** | Anyone outside the hub (other-team or external); skill scope varies by available infrastructure |

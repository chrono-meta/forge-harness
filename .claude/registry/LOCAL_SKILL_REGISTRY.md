# Local Project Skill Registry

Auto-generated: 2026-05-31. Refresh after 7 days or when new projects are added.

**Ecosystem**: 4 projects in `/Users/akaa1941/PycharmProjects/`

| Project | Role | Skills |
|---|---|---|
| `forge-harness` | Control Tower / governance / methodology | 33 (29 fh-meta + 4 fh-commons) |
| `hermes-agent` | Execution seat / integration hub | 176 (90 core + 86 optional) |
| `opencode` | Fast autonomous coding agent | CLI only (npx runnable) |
| `openhuman` | Community AI desktop / memory layer | 4 local + external registry |

---

## forge-harness — Primary host

Invocation: native CC plugin — `/skill-name` or natural language.

| Skill | Summary |
|---|---|
| `steel-quench` | Adversarial review — 5-wave, challenger agent |
| `pipeline-conductor` | 4-axis quality gate (backward/adversarial/forward/record) |
| `goal-quench` | /goal wrapper: budget gate + stop-hook verification |
| `harvest-loop` | Weekly audit + self-evolution pipeline |
| `sim-conductor` | Multi-scenario simulation |
| `source-grounding-audit` | Phantom reference detection |
| `agent-composer` | Wave-based agent orchestration |
| `harness-doctor` | Harness structure L1–L4 diagnosis |
| `token-budget-gate` | Pre-task token cost estimate |
| `hub-cc-pr-reviewer` | PR diff → coherence check |
| _(+23 more)_ | Full list: `plugins/fh-meta/plugin.json` |

---

## hermes-agent — 176 skills

Invocation: Agent dispatch → `Read {path}/SKILL.md` → execute. No cwd switch needed.

### High-synergy with FH

| Skill | Path | FH synergy |
|---|---|---|
| `opencode` | `skills/autonomous-ai-agents/opencode/SKILL.md` | Hermes orchestrates OpenCode; FH governance wraps output |
| `claude-code` | `skills/autonomous-ai-agents/claude-code/SKILL.md` | Hermes delegates to CC/FH as harness layer |
| `codex` | `skills/autonomous-ai-agents/codex/SKILL.md` | Sidecar for orchestrator-swap experiment |
| `github-code-review` | `skills/github/github-code-review/SKILL.md` | Post-governance inline comments via gh |
| `github-pr-workflow` | `skills/github/github-pr-workflow/SKILL.md` | PR after governance PASS |
| `arxiv` | `skills/research/arxiv/SKILL.md` | v2 paper related-work search |
| `research-paper-writing` | `skills/research/research-paper-writing/SKILL.md` | v2 paper drafting |
| `test-driven-development` | `skills/software-development/test-driven-development/SKILL.md` | Write tests for governance findings (e.g., arity.ts Finding 1) |
| `systematic-debugging` | `skills/software-development/systematic-debugging/SKILL.md` | Debug issues found by steel-quench |
| `subagent-driven-development` | `skills/software-development/subagent-driven-development/SKILL.md` | FH orchestrates, hermes sub-agents code |
| `adversarial-ux-test` | `optional-skills/dogfood/adversarial-ux-test/SKILL.md` | FH usability + UX adversarial testing |

### Research (v2 paper)

| Skill | Path |
|---|---|
| `lm-evaluation-harness` | `skills/mlops/evaluation/lm-evaluation-harness/SKILL.md` |
| `weights-and-biases` | `skills/mlops/evaluation/weights-and-biases/SKILL.md` |
| `dspy` | `skills/mlops/research/dspy/SKILL.md` |

### Other categories available

MLOps (vllm, llama-cpp, whisper, qdrant, pinecone, stable-diffusion), security (web-pentest, sherlock, 1password), finance (DCF, LBO, 3-statement, merger-model), blockchain (EVM, Solana, Hyperliquid), creative (ComfyUI, Blender, manim, ascii-art), DevOps (docker, CLI, watchers), productivity (Notion, Linear, Google Workspace, Airtable, PowerPoint).

---

## opencode

Version: 1.15.13 | Source: `/Users/akaa1941/PycharmProjects/opencode`
Invocation: `npx opencode-ai run "prompt" --dangerously-skip-permissions` (needs provider credentials)
FH role: coding worker → FH governance wrapper runs after (`fh_opencode_governance_wrapper.md`)
Hermes integration: `hermes-agent/skills/autonomous-ai-agents/opencode/SKILL.md`

---

## openhuman

Version: v0.53.45 | Source: `/Users/akaa1941/PycharmProjects/openhuman`
FH role: memory audit target — harvest-loop on Memory Tree → audited methodology

| Skill | Path | Summary |
|---|---|---|
| `pr-review-shepherd` | `src/openhuman/skills/defaults/pr-review-shepherd/SKILL.md` | PR → ready-for-merge via Composio + local git |
| `dev-workflow` | `src/openhuman/skills/defaults/dev-workflow/SKILL.md` | Development workflow |
| `github-issue-crusher` | `src/openhuman/skills/defaults/github-issue-crusher/SKILL.md` | Autonomous issue resolution |
| `ship-and-babysit` | `.codex/skills/ship-and-babysit/SKILL.md` | PR ship + CI babysit for openhuman |

External registry: `github.com/tinyhumansai/openhuman-skills`

---

## Full-Stack Synergy Path (v2 paper experiment)

```
FH orchestrates:
  1. hermes.opencode → generates code in target dir
  2. FH steel-quench + pipeline-conductor → governance pass
  3. hermes.github-code-review → inline comments on findings
  4. hermes.test-driven-development → tests for uncovered cases
  5. hermes.arxiv → related-work search for v2 paper
  6. hermes.research-paper-writing → draft section
```

No cwd switch at any step. Agent dispatch from FH.

---

## XL-tier Expansion Candidates

Next autonomous discovery targets (git clone on user confirmation):
- `github.com/tinyhumansai/openhuman-skills` — openhuman external skill registry
- GitHub topic `hermes-agent-skill` — community skills not yet in local optional-skills/
- GitHub topic `claude-code-plugin` — new FH-compatible skills

# Built-in Capability Map — Claude Code features to reach for BEFORE an FH skill

> **Why this exists.** FH's no-reinvention rule says a platform built-in that covers the need outranks
> an FH skill (Tier 0 before Tier 1 before net-new). That rule only fires if the session *knows* the
> built-in exists. A feature that is not on any routing surface gets used only when the model happens
> to remember it — muscle, not skeleton — so a Sonnet session or another person's install silently
> skips it. This map is the routing surface. It is a lookup table, not doctrine: keep it current with
> the platform, and route to it from `CLAUDE.md` §Autonomous Initiative Layer.
>
> **Verified 2026-10-15** against the official command reference (`code.claude.com/docs` — commands,
> skills, model-config pages) and a local `claude --version` = 2.1.300 / `claude --help`. Trigger: an
> external cheat sheet (Claude Code Cheat Sheet v2, 2026-10-15) listed 51 items; 13 had no FH route.
> **Re-verify when the CLI version changes** — names and flags churn (`multi_model_sidecar_strategy.md`
> §Binary names churn).

## Routing table — intent → preferred built-in (after its prerequisites) → what FH adds

"Built-in first" means *prefer the built-in over rebuilding it*, not *run it before its prerequisites*: where a row names a step that must happen first, that step comes first.

| User intent / situation | Preferred built-in | FH on top / prerequisite |
|---|---|---|
| "how full is my context", "why so slow", token pressure | `/context` (usage grid + heavy-tool / memory-bloat hints; `/context all` itemises) | `/context-doctor` — writes `.claudeignore`, routes CLI output through a trimming proxy, audits hub CLAUDE.md / MEMORY.md bloat on a cadence |
| context nearly full, keep working | `/compact [focus]` (summarise to free space) | **before** compacting: write down what must survive (completion log, card, memory) — compaction loses what was only in the conversation |
| a side question that should not pollute this context | `/btw [question]` | — |
| "check my install / setup", CLAUDE.md problems | `/doctor` (bundled skill; installation, settings, extensions, CLAUDE.md; `prompt-audit`) | `/install-doctor` — FH plugin conflicts and overwrite risk · `/harness-doctor` — harness structure, drift, broken references. 🟥 Name clash: built-in `/doctor` ≠ `/harness-doctor` |
| cost / plan limits / "how much did this use" | `/usage` (aliases `/cost`, `/stats`) | `/token-budget-gate` — *estimates before* an expensive run; it consumes `/usage` output as the actual |
| "how have I been using this", usage patterns | `/insights` (HTML report over recent local sessions; not in cloud sessions) | its findings are input for the UAP and the weekly audit — FH does not rebuild this report |
| review a diff for bugs | `/code-review [--comment]` (bundled; `ultra` = cloud deep review) | `/harness-pr-reviewer` for FH-asset coherence. 🟥 `--fix` writes to the tree — author use only; a sidecar reviewer never uses it (§Runtime Authority) |
| simplify / de-duplicate changed code | `/simplify [target]` (bundled; 4 parallel agents; not a bug hunt). 🟥 **It applies fixes to the tree** | author use only — never as a read-only review lane or a sidecar (§Runtime Authority: a sidecar does not write). The 4-axis gate verifies afterwards |
| see what changed | `/diff` | — |
| undo the last edits / go back in the conversation | `/rewind` (aliases `/checkpoint`, `/undo`) — restores **checkpoint-tracked** edits only | 🟥 files changed by Bash commands and most subagent edits are not restored; nothing outside the session (pushed commits, remote branches) is. Check `git status` after a rewind; the Destructive-Op gate still governs remote state |
| keep working until a condition holds | `/goal [condition]` | **before** starting: `/goal-quench`'s budget gate for an expensive run; verification after |
| repeat / watch on an interval | `/loop [interval] [prompt]` | pair with the WATCH list |
| try another direction without losing this one | `/branch [name]` (conversation branch; back via `/resume`). 🟥 Not a git branch | git branches still follow §PR Direction and the branch-claim steps |
| hand a copy of this conversation to a background session | `/fork [prompt]` (by default the copy is told to create its own worktree before editing) | 🟥 isolation is **conditional**: with `worktree.bgIsolation: "none"`, outside git, or with agent view off, the copy edits the same checkout. Check the copy's actual working directory. If it is a worktree: no FH-asset commits from it, reclaim gitignored output before removing it |
| free the terminal, let this session run on | `/background` (`/bg`, CLI `--bg`; watch with `claude agents`) | close-protocol Agent-View pre-read applies |
| think harder on this turn / this session | `ultrathink` in the prompt (that turn only; API effort unchanged) · `/effort low…max\|auto` | Mode D model notice and `capability_escalation_consent.md` decide when to *ask* for more |
| faster output | `/fast` (extra cost; limited under `-p`) | — |

## Skill frontmatter `context: fork` — what it is NOT

`context: fork` runs a skill body as a prompt in a new subagent (general-purpose unless `agent:` says
otherwise), without the conversation history. **It does not isolate the subagent from the project
`CLAUDE.md`.** Measured 2026-10-15 in a folder outside this repo, Sonnet, 3 runs per arm, with a
canary string placed only in the project `CLAUDE.md`:

| Arm | Setup | Answer |
|---|---|---|
| F | `context: fork` + CLAUDE.md | canary 3/3 |
| control A | no fork + CLAUDE.md | canary 3/3 |
| control B | no CLAUDE.md | NONE 3/3 |

The canary came from the forked subagent itself (its task prompt did not contain it; the final message
was the relayed subagent output). So a blind evaluation still needs a clone outside the repo run
headless (`scripts/sim_isolated_run.sh`), exactly as before. Not measured: the docs' claim that
`agent: Explore` / `Plan` start without `CLAUDE.md`; whether the user-level `~/.claude/CLAUDE.md` is
visible to the fork. ⚠️ The `-p` JSON summary reported `subagent_stats.spawned: 0` and `num_turns: 0`
for the forked run although the stream shows `task_started … spawn_depth=1` — read the stream, not the
summary, before concluding a fork did or did not happen.

## Limits

- Built-in names, aliases and flags come from one CLI version (2.1.300) and the docs read on
  2026-10-15; the docs' skills and model-config pages were read up to 100,000 characters (their last
  ~9k / ~17k characters unread).
- The exact text `ultrathink` injects is not documented.
- This map routes; it does not prove a session follows it. Whether a floor-tier session reaches for the
  built-in first is a separate measurement (blind sim, isolated clone, with and without this map).

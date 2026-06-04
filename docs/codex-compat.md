# Codex Compatibility — Known Limitations & Validated Patterns

> Status: **beta**. This document is beta-removal condition #2 (see `AGENTS.md` → Codex Compatibility → Beta removal conditions). It lists what works, what breaks, and what to expect when applying forge-harness (FH) methodology through OpenAI Codex (`codex exec`) instead of Claude Code.

FH is a 2-layer system: a **methodology layer** (`tracks/`, `knowledge/`, `SKILL.md` docs) that is model-agnostic, and an **automation layer** (Claude Code hooks, `.claude/agents/`, `/model`, settings.json) that is Claude-native. Codex users run the methodology layer by reading `SKILL.md` files directly; the automation layer requires manual substitution or does not apply.

## Validated invocation pattern

```bash
# headless, stdin — codex-cli >= 0.135.0
cat plugins/fh-meta/skills/<skill>/SKILL.md path/to/artifact \
  | codex exec -m gpt-5.5 -
```

- `codex exec -m gpt-5.5 -` reads the combined prompt from stdin and runs headless.
- `npx @openai/codex` (interactive) requires a TTY and is **not** suitable for piped skill application.
- Inside a git repository (e.g. a clone of this repo) no extra flag is needed. **Outside** a git repo (e.g. running from `/tmp`), add `--skip-git-repo-check`.
- `codex exec` has its own file-read tools, so a skill that back-traces claims to source files (e.g. `source-grounding-audit`) can verify paths itself — it produced real `file:line` citations in validation.

## Author-run M1 validations (2026-06-04)

These are **author** runs — they confirm the M1 tier assignments are accurate and ground the limitations below. They do **not** count toward the external-validation gate (conditions #1 and #3 below), which by definition requires non-author users.

| Skill | Tier | Method | Result |
|---|---|---|---|
| `source-grounding-audit` | M1 | Fed a fixture with 2 real + 2 phantom claims (a non-existent skill path, a fabricated "47 M1 skills" count) | **4/4 correct** — both real claims Grounded with `file:line` citations, both phantoms caught (the fabricated count corrected against the actual `AGENTS.md`) |
| `asset-placement-gate` | M1 | Fed a proposed `phantom-checker` skill that duplicates `source-grounding-audit` | **Correct** — applied the 4-criteria bar, flagged criterion ④ overlap, routed to **Drop** with "route intent to source-grounding-audit" |

Both ran end-to-end with no Claude-native dependency. The M1 tier claim holds for the two skills tested.

## Known limitations

### 1. CC-native hooks fire and fail (noise, not breakage)
When `codex exec` runs **inside this repo**, FH's Claude-native git/Stop/PostToolUse hooks attempt to fire and emit `hook: Stop Failed` / `hook: PostToolUse Failed` lines interleaved with output. These are **harmless to the skill result** — the skill's verdict is produced correctly — but they are visible noise. Running from a directory **without** FH's `.claude/settings.json` (the normal Codex-user case) avoids them entirely. Filter with `grep -vE "^hook:"` if needed.

### 2. M2 skills need manual agent substitution
M2 skills (`steel-quench`, `harness-doctor`, `context-doctor`, `sim-conductor`, `harvest-loop`) have a core workflow that runs under Codex, but any step that dispatches `Agent(subagent_type=...)` or a slash command must be replaced by a direct `codex exec` call reading the sub-agent's `SKILL.md`/agent `.md` — same workflow, different runtime (the "M2 adaptation pattern" in `AGENTS.md`). Example: `steel-quench` Waves 1–3 run; the `quench-challenger` agent step is manual.

### 3. M3 skills do not run under Codex
M3 skills (`goal-quench` Phase-3 Stop hook, `hub-cc-pr-reviewer` CC session context, `install-wizard` settings.json write) require Claude-Code-native runtime and are **methodology reference only** under Codex. Read them for the approach; do not expect them to execute.

### 4. No token accounting
Codex token usage is billed in the Codex CLI quota and is **not** recorded in any FH session log or orchestrator measurement. Cross-family runs (Gemini/Codex) are invisible to FH's token-budget tooling by construction.

### 5. Cross-family sibling note (Gemini)
The sibling pattern for Gemini is `gemini -p "$(cat <skill+artifact>)"`. Outside a trusted directory Gemini requires `--skip-trust` (or `GEMINI_CLI_TRUST_WORKSPACE=true`). Gemini's headless output may bracket identifiers (`[ID]:`) where Codex does not — parse tolerantly.

## Per-tier expectation summary

| Tier | Under Codex | Action |
|---|---|---|
| **M1** | Runs fully | `cat SKILL.md artifact \| codex exec -m gpt-5.5 -` |
| **M2** | Core runs; agent/slash steps manual | Substitute each dispatch with a direct `codex exec` on the sub-agent's `.md` |
| **M3** | Does not run | Read as methodology reference only |

## Beta removal — remaining (external-blocked)

| Condition | Status |
|---|---|
| Known limitation list published (this doc) | ✅ done (2026-06-04) |
| 5+ externally validated M1 skill runs (not FH author) | ⬜ pending — needs external Codex users |
| At least 1 external Codex user confirms methodology reproduces | ⬜ pending — needs external Codex users |
| README badge updated (`Codex-compatible` without `beta`) | ⬜ blocked on the two above |

To report a validated run, open an issue at `chrono-meta/forge-harness` with label `codex-validation`.

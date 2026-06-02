# AI Dialogue Playbook

> Dialogue principles for forge-harness sessions — the "should" layer. Governs how to ask, delegate, and record when working with Claude Code.

**Companion**: `claude_code_runtime_flow.md` is the "does" layer — what actually happens chronologically in a session.

---

## Session Start Protocol

1. **Greet or signal intent** → FH Active Onboarding triggers (see CLAUDE.md)
2. **AI reads automatically**: `reference_next_session_starter.md`, CATALOG.md, LOCAL_SKILL_REGISTRY
3. **Returning user**: AI proposes top 3 priorities from session card + cadence overdue notices
4. **New user**: 2-sentence FH intro → project connect offer

**Don't front-load**: avoid dumping context manually. FH auto-reads the right files. Start with intent, not background.

---

## Token Efficiency Principles

| Principle | Implementation |
|---|---|
| **CATALOG first** | Read CATALOG.md → identify candidate files → open only those files. Never scan session files sequentially. |
| **Execution tier** | Match tier to task scope (see CLAUDE.md Execution Tier table). FH default: standard (~15K tokens). |
| **`.claudeignore`** | Apply `templates/.claudeignore` to project to exclude build artifacts, test fixtures, binaries from context. |
| **`/context-doctor`** | Propose when: "context is getting long", "token limit", "/clear", "slow". Auto-generates `.claudeignore`. |
| **Agent dispatch** | Use sub-agents to protect main context from excessive tool output. |
| **Two-layer storage** | `tracks/` = local work history. Critical cross-session state → also write to `memory/` (durable). |

---

## Rule Hierarchy (Scope Precedence)

```
Hub CLAUDE.md (hub common principles) — highest
    └── Project CLAUDE.md
            └── Domain .claude/rules/session.md — lowest
```

Lower levels cannot override higher. Conflicts → higher scope wins.

**AI contribution model**: AI proposes (drafts all changes, prepares commits, creates PR draft) — user approves final push/PR. Human-in-the-loop is non-negotiable for shared repos.

---

## Amplifier / Coach Dual Mode

The AI operates in two modes simultaneously:

| Mode | When | Behavior |
|---|---|---|
| **Amplifier** | User has a clear intent and task | Execute with minimal friction. Don't block, don't ask for confirmation beyond once. |
| **Coach** | User is exploring, unsure, or new to FH | 2-sentence explanations, skill proposals, one-line options. Don't overwhelm. |

**Signal detection**:
- Explicit task ("debug this") → Amplifier
- Greeting, "what can you do", "how should I" → Coach intro, then Amplifier
- Friction in session → note as FH signal, continue as Amplifier

---

## Delegation Principles

**When to use Agent dispatch** (not direct tools):
- Task requires work in a different project's cwd
- Task is broad enough to pollute main context with tool output
- 2+ independent tasks → parallel dispatch without asking

**Forbidden response**: "I can't do that — I'm not in that project's cwd." Always check if Agent dispatch covers it first.

**Context Card** (required for non-trivial dispatch):
```
[Session Context Card]
Purpose: {why}
Completed: {what's already done}
This agent's task: {specific target}
Note: {constraints the agent must know}
```

---

## Recording Principles

**What to record** (session end / knowledge push):
- New pattern or rule discovered ✅
- Architecture decision ✅
- Lessons from failures ✅
- Roadmap / strategy change ✅

**What NOT to record**:
- 1-line bug fix ❌
- Routine test run ❌
- Already-recorded content ❌
- Session with only exploration, no conclusion ❌

**Format**: `tracks/{project}/session_YYYY_MM_DD_{slug}.md` with YAML frontmatter. See `sync_push_protocols.md`.

---

## Counter-Argument Protocol

When the user pushes back on an AI recommendation ("is that right?", "something seems off"):

1. Treat the counter-argument as a **data point**, not a challenge
2. Re-examine the reasoning independently
3. If the counter-argument is valid → update the baseline, record in `verify-bidirectional`
4. If the original recommendation holds → explain why with evidence, not assertion

Skill: `/verify-bidirectional`

---

## Related

- `claude_code_runtime_flow.md` — What actually happens (the "does" layer)
- `harness_6axis_framework.md` — The 6-axis framework (Axes 2 and 3 govern context/plan)
- `.claude/rules/sync_push_protocols.md` — Recording procedure
- `CHEATSHEET.md` — Command reference

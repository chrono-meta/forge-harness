# Claude Code Runtime Flow

> What actually happens chronologically during a forge-harness session — the "does" layer. Companion to `ai_dialogue_playbook.md` (the "should" layer).

---

## Session Lifecycle (Chronological)

```
1. User opens session in forge-harness cwd
        │
        ▼
2. CLAUDE.md loaded → Control Tower mode activated
        │
        ▼
3. Session-start auto-read (Active Onboarding Protocol)
   ├── CLAUDE.md (already loaded)
   ├── CATALOG.md
   ├── tracks/_meta/reference_next_session_starter.md (if exists)
   └── LOCAL_SKILL_REGISTRY.md (if fresh — <7 days)
        │
        ▼
4. Cadence checks (automatic)
   ├── frontier_digest_*.md → if 7+ days → propose /frontier-digest
   └── *harness_doctor*.md → if 30+ days → propose /harness-doctor
        │
        ▼
5. User gives first utterance → Onboarding branch decision
   ├── Greeting / session-start → Active Onboarding (5-skill cascade)
   ├── Explicit task → skip onboarding, enter task directly
   └── Exploratory → 2-sentence intro + What would you like to work on?
        │
        ▼
6. Task execution loop
   ├── Simple known-file edit → Read/Edit with absolute path (no cwd switch)
   ├── Field project task → Context Card → Agent dispatch
   └── 2+ independent tasks → Parallel Agent dispatch (no asking)
        │
        ▼
7. Real-time tracking
   ├── S-tier/A-tier completed → append to tracks/_meta/fh_completed_{date}.md immediately
   └── FH asset modified → 4-axis auto-gate runs (see harness_6axis_framework.md)
        │
        ▼
8. Closing phrase detected ("wrap up", "done", "good work", "end session")
   ├── ① git diff check
   ├── ② if diff → harvest-loop
   ├── ③ card update (reference_next_session_starter.md) — mandatory, independent
   └── ④ unpushed commits → propose "push?"
```

---

## Sub-Agent Delegation Flowchart

```
Main session receives task
        │
        ├── Can I do this directly with Read/Edit?
        │   (known path, simple change, no cwd switch needed)
        │   YES → do it directly
        │   NO → ↓
        │
        ├── Is it a field project task?
        │   YES → inject Context Card → Agent dispatch (absolute path)
        │   NO → ↓
        │
        ├── Are there 2+ independent sub-tasks?
        │   YES → Parallel Agent dispatch (single message, multiple tool calls)
        │   NO → Single Agent dispatch
        │
        └── Does the task need a FH skill from another project?
            → Check LOCAL_SKILL_REGISTRY → propose + dispatch
```

**Forbidden**: "I can't do that — I'm not in that project's cwd."  
Self-check Agent dispatch first.

---

## FH 4-Axis Auto-Gate (Runtime Detail)

Triggered automatically when any FH asset is modified:

```
FH asset modified (SKILL.md / rules / templates / CLAUDE.md / substantive knowledge/)
        │
        ▼
Axis 1 — Backward: bash templates/regression_guard.sh --pr {BRANCH}
        │ (git pre-commit hook runs this directly)
        ▼
Axis 2 — Adversarial: /steel-quench
        │
        ▼
Axis 3 — Forward: /source-grounding-audit
        │
        ← After Axes 2+3 both PASS:
          AI creates marker: tracks/_meta/.axes_23_passed_{branch}_{date}.marker
        ▼
Axis 4 — Record: /edit-manifest RECORD (or manual append to edit_manifest.yaml)
        │
        ▼
All 4 PASS → git commit allowed
Any FAIL → fix inline → re-run failed axis → proceed
```

**Lightweight exception** (Axis 1 + 4 only): sessions where zero SKILL.md/rules/templates changed.

**Substantive knowledge/ carve-out**: a knowledge/ doc that adds a code fence (` ``` `) or citation (`arXiv:` / `DOI` / `http`) → Axes 2+3 required. Prose-only edits stay light.

---

## Agent View Operation (from FH cwd)

| Path | When | Method |
|---|---|---|
| **Direct edit** | Known file, simple change | Read/Edit with absolute path |
| **Agent dispatch** | Field project work, one task | Context Card → Agent |
| **Parallel dispatch** | 2+ independent tasks | Single message, multiple Agent tool calls |

**Context Card format** (required for non-trivial dispatch):
```
[Session Context Card]
Purpose: {purpose}
Completed: {already done}
This agent's task: {specific task + target files}
Note: {constraints}
```

---

## Memory System Flow

```
User utterance / insight detected
        │
        ▼
Auto-memory trigger? (user_role, feedback, project state, reference)
        │
        YES → Write to ~/.claude/projects/.../memory/{slug}.md
              Update MEMORY.md index
        NO → continue
        │
        ▼
MEMORY.md loaded at session start as system context (always-on)
Specific memory files loaded on-demand (keyword trigger from MEMORY.md index)
```

**Two-layer storage rule**: `tracks/` = local detailed history (survives session, not machine change).
Critical cross-session state → also write to `memory/` (survives re-clone + machine change).

---

## Skill Proposal Cadence (Autonomous Initiative)

Throughout the session, when conversation signals match the table in CLAUDE.md:
- Propose relevant skill in one line: `"I see [X]. Want me to run /[skill] to [description]?"`
- One signal = one proposal (no pressure)
- Do not re-propose a skill already running

---

## Related

- `ai_dialogue_playbook.md` — The "should" layer (principles)
- `harness_6axis_framework.md` — Full 6-axis decision tree
- `hub_compounding_loop.md` — Session close → harvest-loop → weekly cycle
- `.claude/rules/operations.md` — Sub-agent invocation log format + weekly scanner

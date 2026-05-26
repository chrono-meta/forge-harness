<!--
session.md — Claude Code Session Rules Template

Purpose of this file:
- Define Claude's session operating rules (how to behave)
- Behavioral guidelines applied across the entire project
- Commit to Git and share with the team
- Edited and managed directly by the user

Difference from MEMORY.md:
- MEMORY.md: Stores data/experience learned during conversation (auto-managed by Claude)
- session.md: Defines procedures/rules for Claude to follow (edited directly by the user)

Usage:
- Copy this file to your project's .claude/rules/session.md
- Add, remove, or modify sections to fit your project
- Change sections marked with [CUSTOMIZE] comments to match your project
-->

### Automatic Actions at Session Start

#### Root Memory (Knowledge Hub) Connection

At the start of a conversation ("hello", "let's start", "load root memory"), perform the following:

1. Read `{FH_ROOT}/CATALOG.md`
   - Understand recent work context
   - Check today's tasks (todo/plan)

2. Load project memory index
   - Check `.claude/projects/.../memory/MEMORY.md`
   - Prioritize loading memory most relevant to current work
   - Proceed naturally without notifying the user that memory was loaded

#### Exceptions
- If the user explicitly requests not to use memory
- For simple one-off questions, load is optional

---

### Session Backup Before Tests

<!-- [CUSTOMIZE] Adjust trigger conditions to match your test framework -->

#### Automatic Backup Trigger

At any point when tests could be run, **automatically** perform a session backup:

1. **When I recommend running tests** — **immediately before** the recommendation message
2. **When the user signals intent to start tests** — **before** running the test command

#### Why Backup
- Sessions can be forcibly terminated when tests start
- Prevents loss of conversation context, analysis results, and change history

#### How to Backup

```bash
cat > .claude/session_backup_$(date +%Y%m%d_%H%M%S).md << 'EOF'
# Session Backup - [Task Title]

## Problem
- [Issue currently being resolved]

## Changes Made
- [filename:line]
- [before/after]

## Next Steps
- [Things to verify after tests]
EOF
```

#### Important
- Perform **automatically** even without an explicit user request
- Never recommend tests without first creating a backup

---

### Automatic Response to Issues

<!-- [CUSTOMIZE] Adjust report tool/path to match your project -->

#### Automatic Check Trigger

When the user mentions a problem, **automatically** locate and analyze the latest test report:

1. **Trigger keywords**
   - "something broke", "got an error", "it failed", "not working"
   - "issue occurred", "test failed", "broken", "failed"

2. **Analyze and report**
   - Names of failing test cases
   - Error messages and stack traces
   - Summarize in a concise format

---

### Code Writing Principles

<!-- [CUSTOMIZE] Adjust to match your project's coding conventions. The 5 principles below are universal and valid for any project. -->

Be conscious of all 5 principles **before** writing code — directly reduces back-and-forth where Claude rushes to create something and the user has to correct it.

#### 1. Reference Existing Code (Consistency First)

- **Reference targets**: Code with similar functionality or in the same layer within the project
- **No introducing new patterns** — follow existing patterns first; only abstract when the same pattern repeats 3+ times and needs consolidation
- **Follow framework Core/Base class patterns** — if the project has `.claude/rules/`, that hierarchy takes precedence

#### 2. Independence and Regression Prevention

- Verify that new code **does not break existing tests or functionality**
- Manage side effects (shared state, global variables, file locks)
- Use `git grep` before changes to understand the impact surface — check for unexpected callers

#### 3. Locator and Identifier Stability (UI code only)

<!-- [CUSTOMIZE] Can be removed for non-mobile QA / non-web QA projects -->

- Do not depend on dynamically generated attributes (auto-generated id, timestamps in content-desc)
- Avoid absolute XPath — fragile to structural changes
- Consider i18n for text-based identifiers (multilingual projects)
- If the project has `.claude/rules/LOCATOR_*` guides, those take precedence

#### 4. Flakiness Risk Management

- **No `time.sleep`** — use explicit waits (implicit/explicit wait) + condition-based polling
- No unbounded waits without a timeout
- Allow tolerance in screenshot-based assertions
- Minimize assumptions about device/environment state (keyboard visibility, previous screen state, etc.)

#### 5. Mandatory grep Before Design (Prevent Missing Own Assets)

**Before** designing a new feature or pattern:

1. grep for similar implementations in the project — reuse if already present
2. grep learnings from sibling projects in the hub (e.g., `{FH_ROOT}/`) — prevent reinventing solutions already solved elsewhere
3. Re-read the project's CLAUDE.md and rules/*.md — check for overlooked constraints

Starting design with zero cited references is a warning signal for **missing own assets**. Always present at least 1 grep result before beginning design.

---

### Rule Hierarchy and Priority

<!-- [CUSTOMIZE] Define rule sources and priority for your project -->

**Priority when conflicts arise:**
1. **Framework rules** — code patterns (non-negotiable)
2. **Test design philosophy** — "what to test" (QA Identity, etc.)
3. **Learned feedback** — rules based on user experience
4. **Operational rules** — session backup, report analysis, and other work processes

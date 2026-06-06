---
name: skill-splitter-detail
description: Detail reference for skill-splitter — content classification algorithm, pointer format variants, verification checklist. Load when executing a specific step.
load: on-demand
---

# skill-splitter — Detail Reference

> Load when executing a specific step. SKILL.md contains the core principle, step overview, pointer format requirement, and Done When.

---

## §Classification — Content Classification Algorithm

### Decision algorithm (per section)

```
For each section in target SKILL.md:

1. Is this content needed to RECOGNIZE the trigger or understand WHAT the skill does?
   → YES → Always-loaded (keep in SKILL.md)

2. Is this content a BEHAVIORAL RULE (governs what counts as X, what is allowed, what is forbidden)?
   → YES → Always-loaded (keep in SKILL.md, regardless of length)
   → "what counts as closed", "auto-allowed vs prohibited", "never touch" rules are behavioral

3. Is this content needed only when EXECUTING a specific step?
   → YES → On-demand (move to SKILL_detail.md)

4. Is this a DECISION TABLE (compact lookup, not step-by-step procedure)?
   → YES → Always-loaded (tables are high information density, keep)
   → Exception: table > 20 rows → candidate for SKILL_detail.md

5. Is this BASH CODE or a FORMAT TEMPLATE?
   → YES → On-demand (move to SKILL_detail.md)
   → Exception: one-liner illustration (≤1 line) used to identify a concept → may stay in SKILL.md
```

### 12 annotated examples

| Content type | Layer | Reason |
|---|---|---|
| Trigger phrases table | Always | Needed to recognize invocation |
| Step names + one-line criteria | Always | Overview — consumer needs to see the full sequence |
| Collision type routing table (3 rows) | Always | Decision table, compact |
| "natural-language close" patterns | Always | Behavioral rule — governs what counts as closed |
| "Memory curator safety: only INDEX-ORPHAN auto-allowed" | Always | Behavioral rule — prohibition |
| Multi-step synthesizer verdict matrix (5 rows) | Always | Decision table |
| Bash script for STALE detection | On-demand | Execution detail, step-specific |
| Agent() call format with prompt template | On-demand | Execution detail |
| 20-row edge case catalog | On-demand | Reference, not needed every invocation |
| Output format template (12 fields) | On-demand | Execution detail |
| "Done When" block | Always | Completion criterion — always needed |
| Connected skills table | Always | Navigation aid, compact |

### Ambiguous content test

When unsure, apply the **D-skill cold-start test mentally**:

> *"If a consumer agent had only SKILL.md and typed the trigger phrase, would they need this content in the first 2 steps?"*
> - YES → Always-loaded
> - NO → On-demand

Behavioral rules always pass this test (even if rarely triggered, the consumer needs to know the constraint exists).

---

## §Pointers — Pointer Format Variants

### Standard pointer (single section reference)

```markdown
> **Detail**: See `SKILL_detail.md §SectionName` — [one-line description of what's there] — read when [specific condition that triggers need].
```

### Multi-item pointer (several related sections)

```markdown
> **Detail**: See `SKILL_detail.md §SectionName-A` (bash scripts) · `§SectionName-B` (format templates) — read when executing this step.
```

### Pointer placement rules

1. Place immediately **after** the summary/overview of the removed content in SKILL.md
2. If an entire step's execution detail is removed, place pointer **at the end of the step's one-line summary**
3. One pointer per removed block — do not stack multiple pointers for the same removal
4. The `— read when [condition]` clause is mandatory — it is the activation trigger for imperative loading

### What makes a pointer imperative vs advisory

Advisory (risky — consumer may skip):
```
"See SKILL_detail.md for bash scripts."
"Refer to SKILL_detail.md §Step6-Detail for details."
```

Imperative (required form):
```
"> **Detail**: See `SKILL_detail.md §Step6-Detail` — bash for STALE detection, memory scan, skill usage leaderboard — read when executing Step 6."
```

The imperative form includes:
- Blockquote + bold `**Detail**:` prefix (visual weight)
- Backtick-quoted path
- What's inside (one line)
- When to read (activation condition)

---

## §Split-Execution — Step-by-Step Procedure

### Step 1: Produce classification table

Read target SKILL.md. For every H2/H3 section, output:

```
| Section | Lines | Classification | Reason |
|---|---|---|---|
| ## Trigger Phrases | 8 | Always | Invocation recognition |
| ## Step 3 — bash scripts | 45 | On-demand | Execution detail, step-specific |
| "auto-allowed" rule | 2 | Always | Behavioral rule |
...
```

Count: Always N lines / On-demand N lines / Expected SKILL.md reduction: N%

### Step 2: Trim SKILL.md

1. For each On-demand section: delete content, replace with imperative pointer
2. Pointer §SectionName must match the header you will create in SKILL_detail.md exactly
3. Check: does SKILL.md still flow logically? Step overview must remain complete (names + criteria, no gaps)

### Step 3: Create SKILL_detail.md

Front-matter:
```yaml
---
name: {skill-name}-detail
description: Detail reference for {skill-name} — [what's here]. Load when executing a specific step.
load: on-demand
---
```

Opening line:
```
> Load when executing a specific step. SKILL.md contains [list what stays there].
```

For each pointer in SKILL.md: create matching `## §SectionName` header, paste removed content under it.

Orphan check: every `## §SectionName` in SKILL_detail.md must have a corresponding pointer in SKILL.md. If not → either add pointer or merge with adjacent section.

### Step 4: Verification sequence

```bash
# 1. Pointer extraction from SKILL.md
grep -oE "SKILL_detail\.md §[A-Za-z0-9_-]+" plugins/{plugin}/skills/{name}/SKILL.md

# 2. Section headers in SKILL_detail.md
grep "^## §" plugins/{plugin}/skills/{name}/SKILL_detail.md

# 3. Diff — every pointer must have a matching section
# Any pointer with no matching section = Phantom → fix before commit
```

Then run:
- `/phantom-quench` — artifact: SKILL.md, declared source: SKILL_detail.md
- `/sim-conductor D skill {name}` — provide SKILL.md only, attempt core task from trigger phrase

---

## §Verification-Checklist

Use before committing a completed split:

| Check | Pass condition |
|---|---|
| Trigger phrases ≥ 3 | SKILL.md §Trigger Phrases has 3+ entries |
| Done When defined | SKILL.md has Done When block with ≥1 measurable condition |
| All §pointers resolve | phantom-quench: 0 phantoms |
| Cold-start grade F | sim-conductor Area D-skill: consumer reaches core completion |
| No behavioral rule in SKILL_detail only | Any rule governing "what counts as X" present in SKILL.md |
| No orphan §sections | Every ## §SectionName in SKILL_detail.md has a pointer from SKILL.md |
| SKILL.md ≤ 50% of original | Line count check |
| SKILL.md flows without gaps | Reading SKILL.md alone gives complete step sequence understanding |

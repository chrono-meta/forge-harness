---
name: self-marketing-lint
description: Detects self-marketing language (version labels, emphasis words, iteration counts, overstatement declarations) in FH skill, agent, and documentation files and outputs replacement suggestions. Detection criteria are defined inline in this skill. Triggered by "check FH files", "remove marketing language", "description diet", "self-marketing-lint".
user-invocable: true
allowed-tools: ["Read", "Grep", "Glob", "Bash"]
model: sonnet
---

# self-marketing-lint — FH Self-Marketing Language Detection + Replacement Suggestions

> Detection criteria are defined inline in this skill (see "Inline Baseline" below).
> The skill is self-contained and does not depend on external personal-memory documents.

## Triggers

- `/self-marketing-lint`
- "Check FH files", "remove marketing language", "description diet"
- "Catch self-marketing language", "run the lint"
- When surfaced as a HIGH item in harvest-loop (P10 series)

## Detection Patterns (Inline Baseline)

The following criteria are self-contained inside this skill. No external personal-memory file is required.

### Self-Marketing Anti-Patterns

1. **Self-declarations of quality**: "industry-leading", "world-class", "production-ready", "the world's first" without external evidence
2. **Round-counters and version brags**: "after 26 iterations", "v0.5 maturity", "22nd naming round", "prototype 9th iteration" — irrelevant to function
3. **Cushion language**: "perfectly", "easily", "seamlessly", "instantly", "without burden" — content-free intensifiers
4. **Owner self-reference loops**: "validated by our team", "proven internally" — circular evidence with no external check
5. **Marketing word stacking**: 3+ adjectives in one sentence
6. **Spec-only artifacts**: skills/agents missing a Done When section — declaration without observable output

| Pattern type | Examples (detection targets) | Replacement direction |
|---|---|---|
| Version labels | "v0.3", "latest version", "(added 2026-05-24)" | Remove (git history manages versioning) |
| Emphasis words | "fully automated", "instantly", "automatically", "full coverage" | Replace with functional description |
| Iteration counts | "22nd naming", "26th round", "prototype 9th iteration" | Remove or move to external document |
| Self-declarations | "This skill is the world's first", "Core FH skill" | Delete |
| Cushion language | "easily", "conveniently", "without burden" | Replace with behavior-based description |
| Spec-only (no outputs) | Skills missing Done When | Require adding an outputs section |

## Execution Steps

### Step 1. Scan Target Files

```bash
# full list of skill files
find {FH_ROOT}/plugins -name "SKILL.md" | sort

# full list of agent files
find {FH_ROOT}/.claude/agents -name "*.md" | sort

# docs/ public documents
find {FH_ROOT}/docs -name "*.md" | sort
```

Scope: specified files only if target is given / full scan if unspecified.

### Step 2. Confirm Inline Baseline

Re-read the "Detection Patterns (Inline Baseline)" section above. No external file load is required — the skill is self-contained.

### Step 3. Pattern Detection

Grep detection patterns in each file's description field + body.

```bash
# version / iteration count patterns
grep -n "v[0-9]\+\.[0-9]\|[0-9]\+th\|[0-9]\+th iteration\|prototype [0-9]\+" {file}

# emphasis word patterns
grep -n "fully\|instantly\|full coverage\|automatically\|conveniently\|easily\|without burden" {file}

# self-declaration patterns
grep -n "core skill\|world's first\|best\|most\|top" {file}
```

### Step 4. Output Replacement Suggestions

Organize and output detection results per file.

```
File: {path}
  L{line}: "{original text}"
  → Suggested: "{replacement text}" (reason: {pattern type})
  → Or: recommend removal (reason: {pattern type})
```

**No automatic edits**: Output suggestions only. Actual edits proceed after user confirmation.

### Step 5. Summary Report

```
## self-marketing-lint results

Target: {N} files
Detected: {N} items

| File | Detection count | Most common pattern |
|---|---|---|
...

Recommendation: prioritize files with highest detection counts for review
```

## Done When

```
1. Full scan of target files complete
2. Inline baseline criteria applied (no external file dependency)
3. Detection results organized and output per file
4. No automatic edits — user confirmation gate maintained
```

## Connections

| Situation | Connection |
|---|---|
| harvest-loop HIGH P10 series triggered | auto-suggest `/self-marketing-lint` |
| During cold audit | `/steel-quench` + self-marketing-lint in parallel |
| Before external distribution | `fh-meta:hub-persona-auditor` followed by self-marketing-lint |

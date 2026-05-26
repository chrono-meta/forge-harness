---
name: self-marketing-lint
description: Detects self-marketing language (version labels, emphasis words, iteration counts, overstatement declarations) in FH skill, agent, and documentation files and outputs replacement suggestions. Reference standards are external baseline documents. Triggered by "check FH files", "remove marketing language", "description diet", "self-marketing-lint".
user-invocable: true
allowed-tools: ["Read", "Grep", "Glob", "Bash"]
model: sonnet
---

# self-marketing-lint — FH Self-Marketing Language Detection + Replacement Suggestions

> Reference documents: `feedback_description_diet_baseline.md` · `feedback_cold_audit_harness_pattern.md`
> Criteria are NOT defined inside this skill — external reference is required (prevents self-reference bias).

## Triggers

- `/self-marketing-lint`
- "Check FH files", "remove marketing language", "description diet"
- "Catch self-marketing language", "run the lint"
- When surfaced as a HIGH item in harvest-loop (P10 series)

## Detection Patterns (external reference criteria)

The following is a summary based on `feedback_description_diet_baseline.md` + `feedback_cold_audit_harness_pattern.md`.
Read both files before execution to apply the latest criteria.

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

### Step 2. Load Reference Criteria

```
Read: {hub_memory_path}/feedback_description_diet_baseline.md
Read: {hub_memory_path}/feedback_cold_audit_harness_pattern.md
```

Confirm latest criteria before proceeding to Step 3.

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
2. Reference documents (2 files) Read complete and latest criteria applied
3. Detection results organized and output per file
4. No automatic edits — user confirmation gate maintained
```

## Connections

| Situation | Connection |
|---|---|
| harvest-loop HIGH P10 series triggered | auto-suggest `/self-marketing-lint` |
| During cold audit | `/steel-quench` + self-marketing-lint in parallel |
| Before external distribution | `fh-meta:hub-persona-auditor` followed by self-marketing-lint |

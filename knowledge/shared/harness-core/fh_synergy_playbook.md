---
name: fh-synergy-playbook
description: Concrete workflow specifications for using FH governance alongside OpenCode, Hermes, and OpenHuman — grounded in empirical results, no unverified claims.
date: 2026-05-31
tags: [synergy, integration, opencode, hermes, openhuman, governance, playbook, marketing]
---

# FH Synergy Playbook — How to Use FH with OpenCode, Hermes, and OpenHuman

This document describes **exact workflows** for combining forge-harness with three AI agent projects. Every outcome stated here is backed by a recorded experiment or a structural guarantee from the software itself. Nothing is promised without evidence.

---

## The Core Pattern (Abstract)

```
AI agent generates or mutates code
    ↓
FH governance pass (before merge)
    ↓
Structured verdict: PASS | PENDING | BLOCKED
    ↓
Merge (if PASS) or fix-cycle (if PENDING/BLOCKED)
```

**What FH adds:** a structured verification layer that runs the same criteria every time, regardless of which model generated the code or which CI system is in use. It reads files the agent writes — no API integration, no runtime adapter.

**What FH does NOT do:**
- It does not fix the code for you (it produces findings, not patches)
- It does not replace CI (unit tests and FH governance are complementary, not competing)
- It does not guarantee zero bugs in output — it guarantees that structured verification ran

---

## With OpenCode — AI Code Generation + FH Quality Gate

### The gap FH closes

OpenCode generates code rapidly. Its own CI (unit tests, type checks) validates syntax and basic behavior. What it misses: security-adjacent logic, arity/allowlist edge cases, AI-generated assumptions that pass tests but break real-world usage.

### Workflow

```bash
# 1. Let OpenCode do its work
opencode run "implement the feature"

# 2. Capture what changed
export FH_TARGET_FILES=$(git diff main..HEAD --name-only)

# 3. Run FH governance pass
./scripts/fh-gate.sh "$FH_TARGET_FILES"
# → generates structured prompt for steel-quench + pipeline-conductor

# 4. Read the verdict
# FH_STATUS: SUCCESS
# FH_GATE_VERDICT: PASS | PENDING | BLOCKED
# findings: (YAML block — actionable issues with grade A/B/C)
```

### Evidence

**Controlled trial (2026-05-31):** Applied to `packages/opencode/src/permission/arity.ts` — 163 lines, AI-generated, 6 unit tests all passing, self-evaluation verdict: DONE.

FH governance verdict: **PENDING**.

Findings:
- **A-grade:** `prefix()` short-token path — permission allowlist may not cover bare commands. Untested execution path.
- **A-grade:** `npx`, `opencode`, `claude`, `bunx`, `uvx` absent from ARITY table — `npx <anything>` receives the same broad allow pattern, security model weakened.
- **B-grade:** AI-generated dictionary has no maintenance protocol.

**Causal attribution:** same code, same model (Claude), same CI — different methodology layer. The delta is attributed to the governance pass, not the model.

### When to use

- After any OpenCode session that touches security-sensitive files (`permission/`, `auth/`, `token/`, `key/`)
- Before merging AI-generated code to main
- As part of a Stop hook: OpenCode exits → fh-gate.sh auto-triggers → verdict in git notes

---

## With Hermes — Skill Configuration Audit Before Dispatch

### The gap FH closes

Hermes orchestrates agents through skill files. Skill configuration errors (missing validation, unsandboxed context, credential exposure) only surface at runtime — sometimes in production. FH governance catches these before the skill is dispatched.

### Workflow

```bash
# 1. After adding or modifying a Hermes skill
SKILL_PATH="skills/autonomous-ai-agents/opencode/SKILL.md"

# 2. Run FH governance on the skill file
export FH_TARGET_FILES="$SKILL_PATH"
export FH_CALLER="hermes"
export FH_GATE_LEVEL="standard"
./scripts/fh-gate.sh "$FH_TARGET_FILES" "$FH_GATE_LEVEL" "$FH_CALLER"

# 3. Before dispatching the skill, check verdict
# If PENDING → review findings before allowing live dispatch
```

### Evidence

**Gemini sidecar review (2026-05-31):** Applied to Hermes `skills/autonomous-ai-agents/opencode/SKILL.md`.

Findings:
- **A-grade:** No pre-execution plan validation — OpenCode operates directly on `workdir` without a review step before file mutations. Destructive rewrites land unreviewed.
- **A-grade:** Secret ingestion risk — OpenCode may ingest `.env` files or `.git` history into prompt context, potentially exposing credentials to external LLM providers.
- **B-grade:** No convergence verification — background sessions can exit with success status while leaving codebase in broken state.

**Filed as:** Hermes issue [#35709](https://github.com/NousResearch/hermes-agent/issues/35709).

### When to use

- Before committing any new Hermes skill that dispatches an external agent
- During Hermes skill review cycles
- As part of Hermes CI: run fh-gate.sh on changed skill files in PRs

---

## With OpenHuman — Memory Tree Staleness Audit

### The gap FH closes

OpenHuman's Memory Tree stores persistent context (technical decisions, file paths, architectural claims). These are validated once at write time, then trusted indefinitely. FH's `memory-hygiene` + `source-grounding-audit` pattern re-verifies memory entries against live state.

### Workflow

```bash
# 1. Extract memory entries that reference file paths or technical claims
# (OpenHuman Memory Tree format — paths, decisions, URLs)

# 2. For each entry, verify it still holds
for entry in memory_entries:
    verify file paths exist in current codebase
    verify external URLs still reachable
    verify technical claims match current code

# 3. Verdict per entry:
#   GROUNDED  — verified, safe to use
#   STALE     — entry exists but referenced reality changed (warn, prompt for update)
#   BROKEN    — hard reference failure (flag for immediate update)
```

### Evidence

**Structural analysis (2026-05-31):** OpenHuman's `pr-review-shepherd` skill documentation notes that "Composio catalog slugs occasionally drift" — an acknowledgment that the stale-but-confident failure mode exists in the project's own documentation.

**FH's `memory-hygiene` skill** implements this pattern for harness memory with a verified weekly cadence. The same algorithm applies directly to OpenHuman's Memory Tree.

**Filed as:** OpenHuman issue [#3069](https://github.com/tinyhumansai/openhuman/issues/3069).

### When to use

- Weekly, or on session start if >7 days since last audit
- After major refactors that move or delete files
- After reversing a significant architectural decision

---

## Expected Outcomes (Honest Estimates)

Based on the controlled trial and sidecar experiments:

| Scenario | Expected FH Verdict | Finding Rate |
|---|---|---|
| AI-generated code, CI passing, no prior governance | PENDING (expected) | 1–3 A/B-grade findings per session (empirical: 2A+1B on arity.ts) |
| Hermes skill configuration, new external agent | PENDING (expected) | 1–2 A-grade findings per skill (empirical: 2A+1B on opencode skill) |
| Human-written code, existing tests passing | PASS (expected) | 0–1 B-grade; A-grade unlikely but possible |
| Previously FH-reviewed code, no changes | PASS | Near-zero new findings (compounding effect) |

**Important caveat:** These are estimates from a small sample. Your actual finding rate depends on code quality, domain, and how much adversarial pressure the governance pass applies. The finding rate is not guaranteed — the governance execution is.

---

## The "No Integration Required" Value Proposition

All three workflows above require:
1. `git diff` to capture changed files
2. `./scripts/fh-gate.sh` to generate a structured governance prompt
3. Reading the verdict

No API integration. No OpenCode plugin. No Hermes adapter. No OpenHuman SDK.

FH reads files OpenCode / Hermes / OpenHuman write. The protocol is the interface.

This also means FH governance can be added **at any point in an existing workflow** — no architectural changes required.

---

## Compounding Effect

The first FH governance pass on a codebase finds the most issues. Each subsequent pass finds fewer — not because the tool is degrading, but because the codebase is improving. This is the governance dividend:

```
Pass 1: PENDING (2 A-grade, 1 B-grade)
    ↓ fix
Pass 2: PENDING (0 A-grade, 1 B-grade)
    ↓ fix
Pass 3: PASS
    ↓ future changes re-enter at Pass 1 only for the changed files
```

Over time, the governance overhead per PR decreases while baseline code quality rises. The tool does not get harder to satisfy — the codebase gets easier to verify.

---

## References

- **Controlled trial (Experiment 2):** `tracks/_meta/fh_opencode_governance_experiment_2026_05_31.md`
- **Sidecar experiment (Experiment 1):** `knowledge/shared/harness-core/multi_model_sidecar_strategy.md`
- **Integration contract spec:** `knowledge/shared/harness-core/fh_integration_contract.md`
- **fh-gate.sh:** `scripts/fh-gate.sh`
- **v2 paper framework (full experimental record):** `knowledge/shared/harness-core/v2_paper_framework.md`
- **OpenCode issue:** github.com/anomalyco/opencode/issues/30057
- **Hermes issue:** github.com/NousResearch/hermes-agent/issues/35709
- **OpenHuman issue:** github.com/tinyhumansai/openhuman/issues/3069

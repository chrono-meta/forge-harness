# Meta-Validation Session Context

> **TEMPORARY FILE** — Remove after validation is complete.
> Purpose: supplies session context to a fresh Claude Code instance doing external meta-validation.

## What this repo is

forge-harness is the public English mirror of an internal meta-harness system. It has two plugins:
- `plugins/fh-meta/` — 23 skills + 3 agents (hub meta-engineering)
- `plugins/fh-commons/` — 2 skills + 1 agent (cross-project utilities)

Current version: fh-meta v1.1.4 / fh-commons v0.1.1 (commit `08ff7ef`)

## What was just done (Wave 2 steel-quench — resolved)

12 S-grade + 4 A-grade blockers were resolved in the previous dev session:

**S-grade (all resolved):**
- `.idea/` internal URL leak removed
- All Korean/PMH-internal vocabulary translated to English
- Skill counts unified to filesystem truth (23+3 / 2+1)
- Version unified to v1.1.4 across plugin.json + marketplace.json + README
- 9 phantom `mcp-spec-to-tc` references removed
- Deprecated skill refs fixed (audit-learnings→harvest-loop, frontier-status-summary→frontier-digest)
- self-marketing-lint baseline inlined
- `local_pmh_context.md` → `local_fh_context.md`

**A-grade (all resolved):**
- `engines.claudeCode >= 1.0.0` added to both plugin.json files
- Author placeholder replaced: `harness-contributor` → `chronology-dev`
- CI added: `.github/workflows/validate.yml`
- README §"Why devil is not easy" rewritten to evidence-first framing

## Your mission: external meta-validation

You are a fresh Claude Code instance with no prior context. Validate whether forge-harness actually works as claimed for an external user in a non-corporate environment (no KP_SASE proxy).

### Validation protocol

**Step 1 — Cold read**
Read `README.md` as if you're a new user. Can you understand what forge-harness does, how to install it, and what each skill does — without prior context? Flag anything confusing.

**Step 2 — Phantom claim audit (source-grounding-audit)**
Run `/source-grounding-audit` or manually check: does every claimed skill exist as an actual SKILL.md file? Does every count match the filesystem?

```bash
# Verify fh-meta skill count
ls plugins/fh-meta/skills/ | wc -l     # expect 23
ls plugins/fh-meta/agents/ | wc -l     # expect 3
ls plugins/fh-commons/skills/ | wc -l  # expect 2
ls plugins/fh-commons/agents/ | wc -l  # expect 1
```

**Step 3 — Vocabulary residue check**
```bash
grep -r "pmh-meta\|pmh-commons\|카카오\|KPAP\|chrono\.logy\|KP_SASE" \
  --include="*.md" --include="*.json" --include="*.zsh" \
  --exclude-dir=".git" .
```
Expect: 0 results (except this file and any local_fh_context.md references to KP_SASE as explanation).

**Step 4 — Self-marketing lint**
Run `/self-marketing-lint` on README.md or manually check for:
- Claims without external evidence
- "The reason is simple" / "already has circuits" style self-declaration
- Owner self-reference closed loops

**Step 5 —망분리 해제 이점 검증 (non-corporate network advantages)**
These skills should work BETTER here than in corporate environment. Test each:

| Skill | Test | Expected |
|---|---|---|
| `frontier-digest` | `/frontier-digest` | HN + arxiv + TLDR direct fetch (no SASE block) |
| `plugin-recommender` | `/plugin-recommender` | github.com search works directly |
| WebSearch-based skills | Any `/steel-quench` or `/harness-doctor` | WebSearch calls resolve cleanly |

**Step 6 — Install flow cold start**
From this directory, try: `/install-wizard` or natural triggers like:
- "how do I install this?"
- "set up forge-harness"
- "what skills are available?"

Do triggers fire without prior context? Does install-wizard walk through setup cleanly?

**Step 7 — steel-quench (optional, if time permits)**
`/steel-quench` on the full repo. Expect Wave 3 convergence (no new S-grade). Previous Wave 1 found 12 S-grade — all patched. If new S-grade appears, it's a genuine regression.

## Report format

After validation, summarize:
```
## External Meta-Validation Report — [date]

### Cold read clarity: PASS/FAIL (issues found)
### Phantom claims: PASS/FAIL (N phantoms found)
### Vocabulary residue: PASS/FAIL (N hits found)
### Self-marketing: PASS/FAIL (issues)
### 망분리 해제 이점: confirmed/not-confirmed per skill
### Install cold start: PASS/FAIL
### steel-quench result: Wave N convergence / new S-grade found

Regression vs previous session: YES/NO
```

Feed results back to the dev session in claude-chrono for incorporation.

## Cleanup

After validation is complete, delete this file:
```bash
rm .claude/rules/meta-validation-session.md
git add -A && git commit -m "chore: remove meta-validation context (session complete)"
```

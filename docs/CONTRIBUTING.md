# forge-harness Contribution Guide

If you'd like to make forge-harness better, pull requests are welcome.

## What You Can Contribute

| Type | Example |
|---|---|
| **New skill** | You've discovered a repeating pattern and want to turn it into a skill |
| **Improve existing skill** | Bug fix, external environment adaptation, adding triggers |
| **Add agent** | New persona (canonical: `plugins/*/agents/`; `.claude/agents/` only for project-local override) |
| **Templates** | Common files to add under `templates/` |
| **Documentation** | README, skill description refinement, typo fixes |
| **Field pattern harvest** | Proposing a pattern discovered in real use as a skill (see `/field-harvest`) |
| **Session contribution (consent lane)** | Share a de-identified work session in `tracks/_contrib/` — see §Consent Lane below |

## Choosing a Contribution Path — Check First

| Contribution Type | Path | Overhead |
|---|---|---|
| Typo fix, 1–3 line improvement, trigger addition | **Lightweight path** — PR rules 1–4 only | Minimal |
| Add step to existing skill, expand section | **Lightweight path** — PR rules 1–5 | Light |
| Create new skill or agent | **Full path** — PR rules 1–8 + rc bump checklist | Full |
| Plugin Level version bump | **Full path** + 3-piece set | Full |

> **Adding a new skill = Full path required**. Improving an existing skill = Lightweight path available.

## Consent Lane — share a session (`tracks/_contrib/`)

Everything under `tracks/` is private by design **except** `tracks/_contrib/` — the consent lane.
Placing a session file there is your explicit consent to publish it; it lands via PR through the lane
gate (`/public-surface-audit` + `/marketplace-gate` Check 5 + ingest contradiction scan + reviewer pass).

- Start from `templates/contrib_session.md` → `tracks/_contrib/{your-handle}/{topic}/session_YYYY_MM_DD_{slug}.md`
- **De-identify first** (no employer/project/colleague names, paths, domains, credentials) — the gate
  re-checks, but scrubbing is yours first
- Full charter, gate table, and what-happens-after-merge: [`tracks/_contrib/README.md`](../tracks/_contrib/README.md)
- Overhead: minimal — the skill-PR rules don't apply (it's a session, not a skill); only the lane gate + frontmatter floor

Merged sessions get CATALOG credit under your handle, and `harvest-loop` distills repeating patterns
into shared knowledge/skills — your session becomes compound interest for every cloner.

## PR Rules (Short Version)

1. **New skill** → Create `plugins/fh-meta/skills/{name}/SKILL.md` + add version line to `plugins/fh-meta/CHANGELOG.md`
2. **New agent** → Register the canonical file under `plugins/fh-meta/agents/{name}.md` (or `plugins/fh-commons/agents/{name}.md` for commons), then update `AGENTS.md` + `.claude/registry/agent_cards.json`. Use `.claude/agents/{name}.md` only for project-local / non-plugin override agents.
3. **Description must be plain text** — no markdown bold, emphasis words, version mentions, or embedded names (removes self-marketing tone)
4. **Simplification guard** — verify that existing assets cannot cover the use case before creating something new
5. **External environment adaptation section** — recommend explicitly noting `Mode A/C` branches in skills and agents
6. **Plugin version bump 3-piece set** — when bumping Plugin Level version, always update all three simultaneously:
   - Add `[vX.Y.Z]` entry to `CHANGELOG.md` Plugin Level section
   - Sync the `version` field in `plugins/fh-meta/.claude-plugin/plugin.json`
   - Create and push tag with `git tag -a vX.Y.Z -m "..."`
7. **Run fact-checker before version bump** — use `/fact-checker` to verify 3-way consistency of plugin.json version/skill count, CHANGELOG, README, and SKILL.md files. 0 FAIL items is a prerequisite for any version bump.
8. **Version policy**: `v0.x` = internal validation phase / `v1.0` = external install validation complete. Claiming v1.0 without external usage evidence is prohibited.
   - **v1.0 validation criteria**: A user other than the owner must ① clone + install FH → ② trigger a skill using natural language → ③ confirm successful completion. Minimum 1 person. Record tester, date, and environment in the PR body.

## rc Bump Pre-Requisite Checklist

Before any version bump (rc or official release), pass the checklist below **in order**.
If any item FAILs, **rc bump is blocked** — fix and re-validate.

### 1. Run fact-checker — confirm 0 stale numbers

Run `/fact-checker` skill for 3-way consistency check:

| Validation Target | Check Items |
|---|---|
| `plugins/fh-meta/.claude-plugin/plugin.json` | `version` field, `skills` count |
| `plugins/fh-meta/marketplace.json` | version and skill count in sync |
| `README.md` (root + plugin) | Stale skill counts or version numbers |

**Pass criterion**: 0 stale items. Even 1 FAIL blocks the rc bump.

### 2. Pass marketplace-gate skill

Run `/marketplace-gate` → All Checks 1–5 must PASS:

| Check | Content |
|---|---|
| Check 1 | Skill description is plain text (no markdown bold, version mentions, embedded names) |
| Check 2 | SKILL.md meets minimum structure (frontmatter + triggers + simplification guard) |
| Check 3 | No external install conflicts (`install-doctor` result linked) |
| Check 4 | CHANGELOG.md version line exists |
| Check 5 | Version policy compliance (`v0.x` = internal validation / `v1.0` = external validation complete) |

1 or more FAILs blocks the rc bump.

### 3. CHANGELOG.md must be updated

The changes for the target bump version must be recorded in `CHANGELOG.md`.

```markdown
## [vX.Y.Z-rcN] - YYYY-MM-DD
### Added
- ...
### Fixed
- ...
```

rc bump without CHANGELOG update is not allowed.

### Checklist Summary

```
[ ] fact-checker — plugin.json ↔ marketplace.json ↔ README 3-way stale: 0
[ ] marketplace-gate — Check 1–5 FAIL: 0
[ ] CHANGELOG.md — entry for this version written
```

Complete all three before running `git tag` and version bump.

---

## How to Submit a PR

```bash
# 1. fork or create branch
git checkout -b feat/my-skill-name

# 2. do the work
# plugins/fh-meta/skills/my-skill/SKILL.md — write skill
# CHANGELOG.md — add version line

# 3. create PR
gh pr create --title "feat(my-skill): one-line description" \
  --body "## What was added\n\n## Why it's needed\n\n## Test environment"
```

## Minimum SKILL.md Structure

```markdown
---
name: skill-name
description: One sentence. Plain text only.
user-invocable: true
allowed-tools: ["Read", "Bash"]
model: sonnet
version: 0.1
# complexity_routing (optional): only add if this sonnet skill needs conditional Opus escalation
# complexity_routing:
#   base: sonnet
#   high: opus
#   escalate_when:
#     - cold_start          # first run with no session context
#     - cross_project       # work spanning 3+ projects
#     - adversarial         # devil/steel-quench mode active
#     - high_stakes         # pre-release or pre-publish validation
#     - full_revalidation   # full re-validation requested
#     - destructive         # irreversible operations included (push, delete, deploy, etc.)
---

# skill-name — one-line description

## Steps

### Step 1. ...

## Trigger Phrases

| Utterance Pattern | Example | Trigger Strength |
|---|---|---|
| **Direct call** | `/skill-name` | Immediate |
| **Natural language A** | "do X for me", "analyze X" | Immediate |
| **Natural language B** | "check X", "how about X" | Suggest |

**Simplification guard**: Do not re-propose if this task is already in progress.

## External User Environment Adaptation

| Environment | Behavior |
|---|---|
| forge-harness clone present | ... |
| Plugin only (Mode C) | ... |
```

## External API Call Standard

When a skill calls an external API (your internal tool, task tracker, messaging platform, etc.), always implement 4-state separation.

### State Definitions

| State | Meaning | Handling |
|---|---|---|
| `EXECUTED` | API call succeeded + result returned | Normal completion |
| `SKIPPED_NO_KEY` | Auth key/token not set | Guide user on how to configure |
| `SKIPPED_EMPTY_INPUT` | No input provided, call unnecessary | Silent skip |
| `FAILED` | Call attempted but error occurred | Output error details + retry guide |

### Implementation Example (Bash-based skill)

```bash
API_KEY="${YOUR_API_KEY:-}"
if [ -z "$API_KEY" ]; then
  echo "STATUS: SKIPPED_NO_KEY — YOUR_API_KEY not set. Configure it and retry."
  exit 0
fi

RESPONSE=$(curl -s -w "\n%{http_code}" -H "X-API-Key: $API_KEY" "$ENDPOINT")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)

case $HTTP_CODE in
  200) echo "STATUS: EXECUTED"; echo "$BODY" ;;
  401|403) echo "STATUS: SKIPPED_NO_KEY — Key invalid. Check your credentials." ;;
  *) echo "STATUS: FAILED — HTTP $HTTP_CODE. Network or server error." ;;
esac
```

**Principle**: Without explicit state output, users cannot tell whether a skill executed, was skipped, or failed.

## Questions

Leave a comment on the PR or open an issue.

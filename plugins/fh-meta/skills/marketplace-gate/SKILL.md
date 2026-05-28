---
name: marketplace-gate
description: Evaluates whether a repository meets marketplace listing criteria via a 5-point check and outputs a listing suitability verdict. Checks README completeness, zero-config readiness, maintenance signals, duplication, and public safety.
user-invocable: true
allowed-tools: ["Read", "Bash", "Grep", "Glob"]
model: sonnet
category: Composability Gate
---

# marketplace-gate — Marketplace Listing Suitability Gate

Automatically evaluates quality, value, and safety of a repository before listing it in an internal or external marketplace via a 5-point check.

> While `asset-placement-gate` answers "is this asset suitable for FH?",
> `marketplace-gate` answers "is this repo ready to be listed in a marketplace?"

## Triggers

- `/marketplace-gate`
- `/marketplace-gate --target <repo path>`
- "Can I list this in the marketplace?", "Pre-listing repo check", "Verify before publishing", "Is this ready for marketplace listing?"
- "Can other teams use this repo?", "Is there a checklist before external distribution?", "Check if this is ready to be public"
- "Review for open-source release", "Verify before sharing outside the team"

---

## Step 0. Confirm Target Path

Use the path specified by `--target <path>` if provided. Otherwise use current cwd.

```bash
REPO_PATH="${ARGUMENTS#--target }"
REPO_PATH="${REPO_PATH:-$(pwd)}"
echo "Target: $REPO_PATH"
ls "$REPO_PATH" 2>/dev/null | head -20 || echo "Path not found — please verify the path"
```

Stop immediately if path is not found.

---

## Step 1. 5-Point Check

### Check 1 — README Completeness

```bash
README=$(ls "$REPO_PATH"/README* 2>/dev/null | head -1)
[ -z "$README" ] && echo "FAIL: No README found" && exit
# Installation command exists
grep -i "install\|clone\|setup" "$README" | head -3
# Code block (usage example) exists
grep -c '```' "$README" 2>/dev/null
```

| Criterion | Check |
|---|---|
| README file exists | ls |
| Purpose in 1 sentence (first 50 lines) | presence check |
| Installation path documented | install·clone·setup keywords |
| At least 1 usage example | code block presence |
| Version notation | version·v[0-9] pattern |

Result: **PASS** (5/5) / **PARTIAL** (3-4/5) / **FAIL** (≤2/5)

### Check 2 — Immediate Usability (zero-config)

```bash
# plugin manifest exists
ls "$REPO_PATH"/.claude-plugin/plugin.json "$REPO_PATH"/package.json 2>/dev/null
# single-line install command (from README)
grep -i "claude plugin install\|npm install\|pip install\|brew install" "$README" 2>/dev/null | head -3
# prerequisites documented
grep -i "prerequisite\|requirement\|env\|api.key" "$README" -A 2 | head -6
```

| Criterion | Check |
|---|---|
| Single-line install command in README | grep |
| Prerequisites documented (API key, env var, etc.) | grep |
| Plugin manifest exists | ls |

Result: **PASS** / **PARTIAL** / **FAIL**

### Check 3 — Maintenance Signals

```bash
cd "$REPO_PATH" 2>/dev/null || cd "$(pwd)"
git log -1 --format="Last commit: %ar (%ad)" --date=short 2>/dev/null
ls CHANGELOG* 2>/dev/null && echo "CHANGELOG found" || echo "No CHANGELOG"
git tag -l 2>/dev/null | tail -5
```

| Criterion | Check |
|---|---|
| Last commit within 60 days | git log |
| CHANGELOG or version bump history | ls |
| git tags exist (version management) | git tag |

Result: **ACTIVE** / **STALE** (60–180 days) / **ABANDONED** (180+ days)

### Check 4 — Duplication / Conflict Detection

```bash
# list skills in current repo (directory-based)
find "$REPO_PATH" -name "SKILL.md" 2>/dev/null | xargs -I{} dirname {} | xargs -I{} basename {}
# compare with existing FH skills (if FH_DIR is set)
[ -n "$FH_DIR" ] && ls "$FH_DIR/plugins/fh-meta/skills/" 2>/dev/null
# cross-check registered skills in plugin.json (SoT)
[ -n "$FH_DIR" ] && python3 -c "
import json, sys
with open('$FH_DIR/plugins/fh-meta/.claude-plugin/plugin.json') as f:
    d = json.load(f)
skills = [s['name'] for s in d.get('skills', [])]
print('plugin.json registered skills (' + str(len(skills)) + '):', ', '.join(skills))
" 2>/dev/null || echo "plugin.json parse failed (FH_DIR not set or path error)"
```

**Duplication verdict**: If directory-based list and plugin.json list don't match → **STALE** warning.

| Criterion | Check |
|---|---|
| No name conflict with existing FH skills | name comparison |
| No functional duplication | description keyword comparison |
| plugin.json list matches directory list | cross-check (SoT consistency) |

Result: **CLEAN** / **OVERLAP** (N candidates) / **CONFLICT** (direct conflict)

### Check 5 — Public Safety

```bash
# detect hardcoded internal domains
grep -r "<your-ghe-url>\|internal-domain\|sandbox\|internal-api" \
  "$REPO_PATH" --include="*.md" --include="*.json" --include="*.yaml" -l 2>/dev/null | head -10
# sensitive information exposure
grep -r "API_KEY\s*=\|SECRET\s*=\|PASSWORD\s*=" \
  "$REPO_PATH" --include="*.md" --include="*.json" -l 2>/dev/null | head -5
# license
ls "$REPO_PATH"/LICENSE* 2>/dev/null && echo "LICENSE found" || echo "No LICENSE"
```

| Criterion | Check |
|---|---|
| No hardcoded internal domains (or clearly marked as internal-only) | grep |
| No sensitive information exposed | grep |
| LICENSE file exists | ls |

Result: **SAFE** / **WARNING** (N items to review) / **BLOCKED** (sensitive info exposed)

---

## Step 2. Verdict Output

```
marketplace-gate — Listing Suitability Verdict
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Target: {REPO_PATH}

  Check 1 README completeness  : ✅ PASS / ⚠️ PARTIAL / ❌ FAIL
  Check 2 zero-config          : ✅ PASS / ⚠️ PARTIAL / ❌ FAIL
  Check 3 Maintenance signals  : ✅ ACTIVE / ⚠️ STALE / ❌ ABANDONED
  Check 4 Duplication detection: ✅ CLEAN / ⚠️ OVERLAP({N}) / ❌ CONFLICT
  Check 5 Public safety        : ✅ SAFE / ⚠️ WARNING({N}) / ❌ BLOCKED

  Overall verdict:
    🟢 Recommended for listing  — 0 FAIL + 0 BLOCKED
    🟡 Conditional listing      — ≤1 FAIL + 0 BLOCKED
    🔴 Listing on hold          — 2+ FAIL or 1+ BLOCKED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Follow-up Connections

| Situation | Next skill |
|---|---|
| Check 1 FAIL — README needs improvement | `hub-persona-auditor` — external reader perspective audit |
| Check 4 OVERLAP — confirm duplication | `cross-ecosystem-synergy-detection` — explore synergy potential |
| Check 5 WARNING — internal assets need cleanup | `harness-doctor` — internal structure consistency diagnosis |
| After 🟢 verdict — install test | `install-doctor` — pre-install conflict verification |

## Done When

```
All steps 0–2 completed
+ Full 5-point check results output (Check 1–5 individual verdicts)
+ Overall verdict output (🟢 Recommended / 🟡 Conditional / 🔴 On hold)
```

**→ Mandatory before 🟢 Recommended verdict: `source-grounding-audit`** — forward axis check on all citations, external URLs, and file path references in the asset being reviewed. A 🟢 verdict without source-grounding-audit is incomplete. If source-grounding-audit finds phantom refs → verdict downgrades to 🟡 Conditional automatically.

> When `agent-composer` receives a "comprehensive marketplace listing audit" request,
> recommend: Wave 0 `fact-checker` → Wave 1 `marketplace-gate` + `hub-persona-auditor` in parallel.

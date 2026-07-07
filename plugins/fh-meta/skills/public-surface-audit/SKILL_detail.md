---
name: public-surface-audit-detail
description: On-demand execution detail for public-surface-audit — scan scripts, report/JSON templates, provenance.
load: on-demand
---

## §Step3-Scan-Script

```bash
cd "$REPO_PATH" || exit 1
# Build the tracked-file list once.
git ls-files > /tmp/_psa_tracked.txt

# Load your real patterns from the gitignored source (one "severity<TAB>regex" per line).
PATTERN_SRC="${PSA_PATTERNS:-.claude/rules/.public-surface-patterns}"
# Absent file ≠ CLEAN. An absent file is unconfigured (silent-failure risk); an EMPTY file is an
# explicit "no tokens to protect" → CLEAN. Distinguish the two.
[ -e "$PATTERN_SRC" ] || { echo "⚪ NOT CONFIGURED: no pattern source at $PATTERN_SRC. Create it (empty = explicit CLEAN) before trusting any verdict. Not scanning."; exit 2; }

# One grep pass per pattern row; the regex comes from the file, never hardcoded here.
while IFS=$'\t' read -r severity regex; do
  [ -z "$regex" ] && continue
  grep -nIE "$regex" $(cat /tmp/_psa_tracked.txt) 2>/dev/null | sed "s/^/[$severity] /"
done < "$PATTERN_SRC"
```

For each pattern, run `grep -nIE "<regex>" $(git ls-files)`:
- `-n` → line numbers (required for `file:line` output)
- `-I` → skip binary files
- `-E` → extended regex (alternation in the pattern table)

Then remove any hit whose `file` + matched `token` is on the Step 2 allowlist. Do this for **every**
pattern row before producing the report — do not stop at the first HIT.

**Binary / generated carve-out**: `-I` already skips binaries. Additionally note (do not auto-suppress)
hits inside generated artifacts (e.g. `paper/*.html` exported from a private source) — these are real
leaks on the public surface and must be reported, but the fix is "regenerate from a sanitized source",
not "edit the HTML by hand". Flag them with a `(generated artifact)` note.

---

## §Step3b-FP-Hygiene-Script

```bash
# FP-hygiene tests the MATCHED TOKEN only — never the whole line. A line-level `grep -v` would
# suppress a real leak that merely *mentions* an example (e.g. `user=<realname> # see EXAMPLE.md`),
# violating PSA's "allowlist tight" rule. So extract the matched span per hit and drop it only when
# the span is *entirely* a placeholder/example (anchored ^…$).
PLACEHOLDER='^(<[a-z0-9_-]+>|\{project\}|EXAMPLE|dummy|changeme|REDACTED|xxxx)$'
grep -nIE "$regex" $(cat /tmp/_psa_tracked.txt) 2>/dev/null | while IFS= read -r hit; do
  tok=$(printf '%s' "$hit" | grep -oiE "$regex" | head -1)
  printf '%s' "$tok" | grep -qiE "$PLACEHOLDER" && continue   # token IS a placeholder → drop
  printf '%s\n' "$hit"
done
```

This differs from the Step 2 allowlist: Step 2 suppresses by **file::token legitimacy**, Step 3b by
**token value-shape**. Both run — Step 2 then Step 3b. Keep it tight (PSA's "allowlist tight" rule): if a
token only *contains* an example substring but is otherwise a real private value, it still reports.

---

## §Step3c-Ignore-Verification-Script

```bash
# Expected-private set = conventional FH local-only files, EXTENDED with any `# private-path: <path>`
# lines the operator added to the gitignored pattern source (self-extends per repo — not a frozen
# operator snapshot). Built one-path-per-line + while-read so it is portable across bash AND zsh
# (zsh does not word-split an unquoted variable, so `for f in $VAR` would break). A non-existent file
# is skipped; an all-absent set emits n/a, never a silent pass.
present=$({ printf '%s\n' CLAUDE.local.md .claude/rules/.public-surface-patterns \
             .claude/rules/local_fh_context.md tracks/_meta/user_adaptation_profile.md
           grep -E '^# private-path:' .claude/rules/.public-surface-patterns 2>/dev/null \
             | sed -E 's/^# private-path:[[:space:]]*//'; } \
         | awk 'NF' | sort -u | while IFS= read -r f; do [ -e "$f" ] && printf '%s\n' "$f"; done)
[ -z "$present" ] && echo "n/a (no expected-private files present in this repo — add '# private-path:' lines to the pattern source if any exist)"
printf '%s\n' "$present" | while IFS= read -r f; do
  [ -z "$f" ] && continue
  # Tracked status is tested FIRST: a file can match an ignore rule yet still be force-added
  # (`git add -f`) — the exact ignored-but-committed mechanism behind the PR #109 leak. Tracked wins,
  # so an ignored-but-committed file reports TRACKED (not a false-clean OK).
  if git ls-files --error-unmatch "$f" >/dev/null 2>&1; then
    echo "TRACKED $f (already committed — Step 3 scans its contents; un-track if it must be private: git rm --cached)"
  elif rule=$(git check-ignore -v "$f" 2>/dev/null); then
    echo "OK      $f → ignored by [$rule]"
  else
    echo "MISS    $f (exists, NOT ignored, NOT tracked — one 'git add .' from a leak; add an ignore rule)"
  fi
done
```

Why this is the safeguard for **gitignore mistakes** (a wrong assumption about what is ignored):
`.gitignore` is committed/shared, `.git/info/exclude` is local/personal, and a global `core.excludesFile`
ignores across all repos — `git check-ignore -v` is the one command that says *which* rule (if any)
applies, so an "I thought it was ignored" error surfaces here instead of in a public PR (the PR #109
class of leak). Diagnostic-only: this step never writes — it reports, the operator adds the ignore rule.

---

## §Report-Template

```
public-surface-audit — Operator-Private Token Scan
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Target: {REPO_PATH}   |   Tracked files scanned: {N}

  🔴 HIGH  ({count})
    {file}:{line}  →  {matched token}   [class: username | company asset]
  🟠 MED   ({count})
    {file}:{line}  →  {matched token}   [class: absolute home path | ignore-MISS (Step 3c)]
  🟡 LOW   ({count})
    {file}:{line}  →  {matched token}   [class: companion-store | private wiring]

  Allowlist-suppressed: {count} hit(s) (legitimate references — not leaks)

  Verdict:
    ⚪ NOT CONFIGURED — pattern source absent (nothing scanned — NOT a clean result; set up first)
    🟢 CLEAN        — pattern source present (incl. empty), 0 HIGH + 0 MED + 0 LOW (after allowlist)
    🟡 REVIEW       — 0 HIGH + 0 MED, LOW-only (drift, not a breach)
    🔴 LEAK         — 1+ HIGH or 1+ MED (block publish / fix before commit)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## §JSON-Schema

```json
{
  "target": "{REPO_PATH}",
  "tracked_files": 0,
  "findings": [
    {"file": "path", "line": 42, "token": "<matched>", "severity": "HIGH", "class": "username"}
  ],
  "counts": {"HIGH": 0, "MED": 0, "LOW": 0, "suppressed": 0},
  "verdict": "CLEAN"
}
```

---

## §Sister-Asset-Provenance

Step 3b (FP hygiene) and Step 5 (`--json`) were imported from **garrytan/gstack** `gstack-redact`
(`lib/redact-engine.ts`) during a hands-on sister-asset cross-audit (2026-06-06; see
`tracks/_audit/session_2026_06_06_gstack_sister_handson.md`). They are adapted to PSA's operator-IP
ontology — `gstack-redact`'s generic secret/PII classes (AWS / PEM / JWT / hostname) stay out of PSA's
scope (orthogonal coverage: PSA = operator-IP leak, redact = generic secret). The reverse direction
(PSA's operator private-codename + bare-username classes, which `gstack-redact` structurally cannot
detect) is a candidate contribution back to gstack.

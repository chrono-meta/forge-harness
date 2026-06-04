---
name: public-surface-audit
description: Scans git-tracked (public) files for operator-private tokens that should live only in gitignored files — real usernames, absolute home paths, companion-store names, company asset names. Reports file:line + matched token + severity, so a public/private split stays clean before publish. Triggered by "public surface audit", "did I leak anything", "check tracked files for private tokens", "private token scan", "public-surface-audit".
user-invocable: true
allowed-tools: ["Read", "Bash", "Grep", "Glob"]
model: sonnet
category: Composability Gate
---

# public-surface-audit — Operator-Private Token Leak Scan

Scans the git-tracked file set (the public surface) for operator-private tokens that were supposed
to stay in gitignored files (e.g. `CLAUDE.local.md`, companion store). After a public/private split,
a front-door fix is not enough — a leaked username or absolute home path anywhere in the tracked set
breaks the "public repo = model-agnostic methodology only" invariant.

> While `marketplace-gate` Check 5 answers "is this repo broadly safe to publish?" (API keys, internal
> domains, license), `public-surface-audit` answers a narrower question: "did any operator-private
> token survive the public/private split into a tracked file?" It scans `git ls-files` only — gitignored
> files like `CLAUDE.local.md` are intentionally out of scope (they are the *correct* home for these tokens).

## Triggers

- `/public-surface-audit`
- `/public-surface-audit --target <repo path>`
- "Did I leak anything into the public repo?", "public surface audit", "private token scan"
- "Check tracked files for private tokens", "is my public/private split clean?"
- "Did any operator-private token survive into a tracked file?", "scan before publish"

---

## Scope — Tracked Files Only

This skill scans **only `git ls-files`** (committed/staged tracked files). Gitignored files are
deliberately excluded — `CLAUDE.local.md`, the companion store, and local session data are the
*correct* home for operator-private tokens, so finding them there is not a leak.

```bash
REPO_PATH="${ARGUMENTS#--target }"
REPO_PATH="${REPO_PATH:-$(pwd)}"
git -C "$REPO_PATH" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || { echo "Not a git repo — public-surface-audit scans git-tracked files only. Aborting."; exit 1; }
echo "Target: $REPO_PATH"
git -C "$REPO_PATH" ls-files | wc -l | xargs echo "Tracked files:"
```

---

## Step 1. Pattern List (configurable)

The patterns **are themselves operator-private** — your real username and employer name must not be
hardcoded *here*, on the public surface, or this skill would leak exactly what it hunts. So the literal
values live in a **gitignored source you supply** (`.claude/rules/.public-surface-patterns`, or a
section of `CLAUDE.local.md`) — one `severity<TAB>regex` per line. This SKILL.md carries only
placeholders; the scan reads the gitignored file, never literals from this table. The skill dogfoods
its own rule.

| # | Token class | Severity | Placeholder (real value goes in the gitignored source) | Why private |
|:-:|---|:-:|---|---|
| 1 | Real username | HIGH | `<your-unix-username>` | Personal identity — must not appear on public surface |
| 2 | Company / employer asset name | HIGH | `<company-asset>` (alternation OK) | Company-confidential, leak-forbidden |
| 3 | Operator absolute home path | MED | `/Users/[a-z0-9_-]+/` (generic — carries no literal name) | Machine-bound, leaks username + local layout |
| 4 | Companion-store name | LOW | `<companion-store-name>` | Private companion store — methodology should not name it |
| 5 | Operator-private script / handoff name | LOW | `<private-script>`, `<private-dir>/` | Operator-specific wiring, belongs in `CLAUDE.local.md` |

**Severity meaning**:
- **HIGH** — real name or company asset. A leak is a confidentiality / identity exposure. Block publish.
- **MED** — absolute home path. Leaks username + local filesystem layout; also a portability bug.
- **LOW** — companion-store / private-wiring name. Methodology should be model-agnostic; naming a private
  store is drift, not a confidentiality breach.

> **Setup**: put your real values in the gitignored pattern source (one `severity<TAB>regex` per line);
> the scan reads that file, never literals from this SKILL.md. If the source is **absent**, the scan
> reports **NOT CONFIGURED** — *not* CLEAN. A missing pattern file must never masquerade as a clean bill
> of health (that would be a silent failure: "nothing scanned" misread as "nothing leaked"). To declare
> "I genuinely have no private tokens", create the file **empty** — an empty file is an explicit CLEAN,
> an absent file is unconfigured.

---

## Step 2. Allowlist (legitimate references)

Some tracked files legitimately reference otherwise-private tokens — the scan must not flag these as
leaks. Maintain an allowlist of `file path :: token` pairs. A match is suppressed only when **both**
the file and the token are on the allowlist row.

| Tracked file | Allowed tokens | Reason |
|---|---|---|
| `.gitignore` | companion-store name, sync-script name | Must name what it ignores |
| your sync script (e.g. `scripts/<sync-script>`) | companion-store name, operator-dir names, home path | The sync script's whole job is the companion store |
| an install-template rules file | home path, companion-store name | Install template — the install path is its content |
| a doc describing the companion-store *pattern* | the `*-be` pattern (no literal store name) | Documents the pattern generically |

**Allowlist rule**: a hit on file F matching token T is **suppressed** iff a row exists with file == F
and T in that row's allowed tokens. Everything else is reported. Keep the allowlist tight — when in
doubt, report and let the user confirm. Genuinely model-agnostic mentions (the `*-be` companion
*pattern* without the literal store name) should not require allowlisting because they do not match a
literal private token.

---

## Step 3. Scan

For each pattern in Step 1, grep the tracked set, then drop allowlisted hits.

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

## Step 4. Report

```
public-surface-audit — Operator-Private Token Scan
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Target: {REPO_PATH}   |   Tracked files scanned: {N}

  🔴 HIGH  ({count})
    {file}:{line}  →  {matched token}   [class: username | company asset]
  🟠 MED   ({count})
    {file}:{line}  →  {matched token}   [class: absolute home path]
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

Per HIGH/MED hit, append a one-line prescription:
- **HIGH (username/company)** — move the line to `CLAUDE.local.md` (or regenerate the artifact from a
  sanitized source); never edit-in-place if it is a generated file.
- **MED (absolute path)** — replace with a relative path, a `~`-anchored path, or a `{project}`
  placeholder; absolute home paths are also a portability bug for external clones.
- **LOW (companion-store/wiring)** — rephrase to the model-agnostic *pattern* (e.g. "a private companion
  store" / "the `*-be` companion pattern") instead of the literal name, unless the file is the
  `.gitignore` / sync script that must name it (allowlist those).

**Simplification guard**: 🟢 CLEAN → collapse the report to one line: "public surface clean — 0 private
tokens in {N} tracked files (X allowlist-suppressed)." Do not print empty severity buckets.

---

## Connected Skills

| Situation | Connected skill |
|---|---|
| Broader pre-publish repo readiness (README, license, API keys) | `/marketplace-gate` (Check 5 Public Safety is the wide net; this skill is the private-token detail) |
| A leak is a recurring process gap, not a one-off | log via `field-harvest` → candidate `#rule-candidate` |
| Where should the leaked content actually live? | `/asset-placement-gate` (hub vs project vs CLAUDE.local.md) |
| Phantom refs / stale links on the same surface | `/source-grounding-audit` (forward axis — orthogonal to this leak axis) |

---

## External User Environment Adaptation

Usable standalone — no hub clone required.
- **No companion store / no operator-private tokens** → create the pattern source **empty** to declare
  this explicitly; the scan then reports CLEAN. Leaving the file *absent* instead yields NOT CONFIGURED
  (a deliberate distinction — absence is "unknown", not "clean"). The skill is only useful once you have
  a public/private split to protect.
- **No `.gitignore` allowlist needs** → Step 2 allowlist may be empty; every hit is then reported.

---

## Done When

```
Step 1 pattern list confirmed (defaults shown / user-adapted)
+ Step 2 allowlist applied
+ Step 3 scan run for every pattern over git ls-files (tracked only — gitignored excluded)
+ Step 4 report output: per-hit file:line + token + severity, plus overall verdict
+ "public-surface-audit Complete" declaration output
```

Verdict: **CLEAN** (0 tokens after allowlist) | **REVIEW** (LOW-only — drift, prescriptions noted) |
**LEAK** (1+ HIGH or 1+ MED — block publish, prescriptions attached).

---

## Operating Notes

- **Tracked-only is the point**: never scan gitignored files. A token in `CLAUDE.local.md` is correct
  placement, not a leak — scanning it would produce false LEAK verdicts and erode trust in the skill.
- **Patterns are data, not code**: the Step 1 table is the configurable surface. A user with a different
  username/employer/companion-store edits the table; the scan logic is unchanged.
- **Generated artifacts are real leaks**: an exported HTML/PDF carrying a username is still a public-surface
  leak even though hand-editing it is wrong — report it, prescribe "regenerate from sanitized source".
- **Allowlist tight, not loose**: when unsure whether a reference is legitimate, report it. A false LEAK
  the user dismisses is cheaper than a real leak suppressed by an over-broad allowlist.

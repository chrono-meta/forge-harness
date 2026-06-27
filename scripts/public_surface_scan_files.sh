#!/usr/bin/env bash
# public_surface_scan_files.sh — Pre-Publish confidentiality floor for `npm publish`.
#
# Mechanizes the npm-publish half of the Pre-Publish Surface Gate (CLAUDE.md). The pre-commit
# confidentiality scan sees only the ADDED LINES of this repo's commits; a token committed before
# that scan existed, or carried in a files[] entry, would otherwise reach the registry unscanned.
# This scans the FULL CONTENT of the exact npm-published file set (npm pack --dry-run) against the
# same operator-private patterns, and blocks `npm publish` on a HIGH/MED hit.
#
# Honest scope: covers `npm publish` only (wired via package.json prepublishOnly). The separate-repo
# go-public surface (gh repo create --public / visibility flip / first push to a new public remote) is
# not an npm or git op against this repo, so no hook here sees it — it stays prose + PRE-PUBLISH-CHECKLIST.md
# (genuinely un-hookable). Same shape as the Destructive-Op story: git/npm surface mechanized, the
# separate-repo go-public surface stays prose.
#
# Degrade direction: irreversible surface (publish) → fail-CLOSED. Patterns absent, or the published
# file set unresolved → BLOCK (proceed only on an explicit, logged PUBLIC_SURFACE_OK=1). Never silent-allow.
#
# Override (explicit, logged — mirrors the pre-commit PUBLIC_SURFACE_OK channel):
#   PUBLIC_SURFACE_OK=1 npm publish …   ← after conscious review of the flagged hit(s).
#
# Patterns are single-source (shared with the pre-commit scan): .claude/rules/.public-surface-patterns.defaults
# (committed, universal) + .claude/rules/.public-surface-patterns (gitignored, operator literals).

set -uo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PSA_DEFAULTS="$REPO_ROOT/.claude/rules/.public-surface-patterns.defaults"
PSA_OVERRIDE="${PSA_PATTERNS:-$REPO_ROOT/.claude/rules/.public-surface-patterns}"
# Placeholder/example shapes that must PASS (documented example paths, not real literals).
PSA_PLACEHOLDER='^(<[a-z0-9_-]+>|\{[a-z_]+\}|EXAMPLE|dummy|changeme|REDACTED|xxxx|/Users/(EXAMPLE|yourname|\{[a-z_]+\}|<[a-z0-9_-]+>)/)$'

# LOW-severity allowlist by file (HIGH/MED still block). For the PUBLISH scan this is nearly vacuous:
# a published file should carry NO operator-private token at all. Deliberately names no operator-private
# file literal here (the pre-commit copy of this list does, but it lives in a git-hooks-allowlisted path;
# THIS script is public-tracked, so hardcoding e.g. a companion-script name would itself be a LOW leak —
# caught by the pre-commit confidentiality scan, 2026-06-27). Generic template paths only.
psa_low_allowlisted() {
  case "$1" in
    templates/*) return 0 ;;
    *) return 1 ;;
  esac
}

echo "[Pre-Publish] public-surface scan (npm-published file content)..."

# ── Load patterns (single source, shared with pre-commit) ──
PSA_STREAM=""
[ -f "$PSA_DEFAULTS" ] && PSA_STREAM=$(cat "$PSA_DEFAULTS")
OVERRIDE_PRESENT=0
if [ -f "$PSA_OVERRIDE" ]; then
  PSA_STREAM="$PSA_STREAM"$'\n'"$(cat "$PSA_OVERRIDE")"
  OVERRIDE_PRESENT=1
fi
if [ -z "$(printf '%s' "$PSA_STREAM" | grep -vE '^[[:space:]]*(#|$)' || true)" ]; then
  # No patterns at all on an irreversible surface → fail-closed (unless override).
  echo "  ❌ no public-surface patterns loaded — confidentiality gate cannot run."
  if [ "${PUBLIC_SURFACE_OK:-0}" = "1" ]; then
    echo "  ⚠️  proceeding by PUBLIC_SURFACE_OK=1 (no scan performed — conscious override)"
    exit 0
  fi
  echo "     Populate .claude/rules/.public-surface-patterns.defaults (or the gitignored override),"
  echo "     or publish with PUBLIC_SURFACE_OK=1 to override. Fail-closed on an irreversible surface."
  exit 1
fi
# Override absent = INCOMPLETE INSTRUMENT on an irreversible surface (challenger S5): the gitignored
# operator-literal patterns (HIGH company/companion names) are absent — true on EVERY fresh clone / CI
# runner by construction. The committed .defaults only carries the universal home-path pattern, so a
# HIGH company-name leak would scan-clean and print a green PASS. Per the Surface-Class Degrade
# Invariant (irreversible → fail-CLOSED), an incomplete instrument BLOCKS rather than prints PASS.
if [ "$OVERRIDE_PRESENT" -eq 0 ]; then
  echo "  ❌ operator-literal pattern override absent (.claude/rules/.public-surface-patterns)."
  echo "     Only the committed home-path defaults are active — HIGH company/companion literals are NOT scanned."
  if [ "${PUBLIC_SURFACE_OK:-0}" = "1" ]; then
    echo "  ⚠️  proceeding DEFAULTS-ONLY by PUBLIC_SURFACE_OK=1 (conscious — HIGH literals unscanned)"
    echo "$(date +%Y-%m-%dT%H:%M:%S) PUBLIC_SURFACE_OK override (npm publish, DEFAULTS-ONLY scan)" \
      >> "$REPO_ROOT/tracks/_meta/.psa_override_log" 2>/dev/null || true
  else
    echo "     Fail-closed on an irreversible surface: populate the override, or PUBLIC_SURFACE_OK=1 to publish defaults-only."
    exit 1
  fi
fi

# ── Resolve the exact npm-published file set (fail-closed if unresolved OR partial) ──
FILES=$(npm pack --dry-run --json 2>/dev/null \
  | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{JSON.parse(s)[0].files.forEach(f=>console.log(f.path))}catch(e){process.exit(3)}})' 2>/dev/null || true)
if [ -z "$FILES" ]; then
  echo "  ❌ could not resolve the npm-published file set (npm pack --dry-run failed)."
  [ "${PUBLIC_SURFACE_OK:-0}" = "1" ] && { echo "  ⚠️  proceeding by PUBLIC_SURFACE_OK=1"; exit 0; }
  echo "     Fail-closed on an irreversible surface. Fix npm pack or override with PUBLIC_SURFACE_OK=1."
  exit 1
fi
# Wrong-set guard (challenger M6): a future npm --json shape change could yield a NON-empty but PARTIAL
# file list (forEach iterates a renamed/nested structure without throwing) → files silently unscanned.
# npm always ships package.json in the tarball; its absence means the parse got a wrong set → fail-closed.
if ! printf '%s\n' "$FILES" | grep -qx "package.json"; then
  echo "  ❌ published file set looks wrong — 'package.json' (always shipped) is absent from the parse."
  [ "${PUBLIC_SURFACE_OK:-0}" = "1" ] && { echo "  ⚠️  proceeding by PUBLIC_SURFACE_OK=1"; exit 0; }
  echo "     Fail-closed (possible npm --json shape change). Verify npm pack output or PUBLIC_SURFACE_OK=1."
  exit 1
fi

# ── Scan full content of each published file ──
LEAK=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  path="$REPO_ROOT/$f"
  [ -f "$path" ] || continue
  while IFS=$'\t' read -r sev regex; do
    [ -z "$regex" ] && continue
    case "$sev" in \#*) continue;; esac
    while IFS= read -r tok; do
      [ -z "$tok" ] && continue
      printf '%s' "$tok" | grep -qiE "$PSA_PLACEHOLDER" && continue
      if [ "$sev" = "LOW" ] && psa_low_allowlisted "$f"; then continue; fi
      echo "  ❌ $sev leak — $f: '$tok' would ship to the registry"
      LEAK=1
      # -a forces every published file to scan as TEXT (challenger S1): -I skipped binary-classified
      # files, so a token in an SVG / null-byte file (docs/pillars.svg ships) would slip unscanned.
    done <<< "$(grep -aoiE "$regex" "$path" 2>/dev/null | sort -u || true)"
  done <<< "$PSA_STREAM"
done <<< "$FILES"

if [ "$LEAK" -eq 1 ]; then
  if [ "${PUBLIC_SURFACE_OK:-0}" = "1" ]; then
    echo "  ⚠️  public-surface hit(s) allowed by PUBLIC_SURFACE_OK=1 (conscious, reviewed intent)"
    echo "$(date +%Y-%m-%dT%H:%M:%S) PUBLIC_SURFACE_OK override (npm publish) — suppressed hit(s) above" \
      >> "$REPO_ROOT/tracks/_meta/.psa_override_log" 2>/dev/null || true
    exit 0
  fi
  echo "  An operator-private token would ship in the npm package. Generalize it (real home path → '~'"
  echo "  or '{project}'; companion/corp name → a generic phrase), or PUBLIC_SURFACE_OK=1 npm publish …"
  exit 1
fi

if [ "$OVERRIDE_PRESENT" -eq 0 ]; then
  echo "  ⚠️  PASS (DEFAULTS-ONLY) — no home-path leak, but HIGH operator literals were NOT scanned (override absent)."
else
  echo "  ✅ PASS — no operator-private token in the published file set (full pattern set)."
fi
# Residual (named, not closed): the scan is a DENYLIST against loaded patterns — an un-patterned secret
# shape (an API key the patterns don't describe) still ships. This gate is not a general secret-detector.
exit 0

#!/usr/bin/env bash
# selfcheck.sh — mandatory-pass (deterministic) checks on FH's own executable surface.
# Class: mandatory-pass (harness_6axis_framework.md §Axis 5 check classes) — blocks on fail.
# Scope: executables shipped via npm files[] + the bash infra driving the FH gate chain.
# Syntax-only (node --check / bash -n): zero side effects, no network, runs anywhere.
# Wiring: `npm test` for any session; `prepublishOnly` so a publish cannot ship a
# syntactically broken executable.
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/.."
fail=0

check() { # check <label> <cmd...>
  local label="$1"; shift
  if "$@" 2>/dev/null; then
    echo "PASS  $label"
  else
    echo "FAIL  $label"
    "$@" || true
    fail=1
  fi
}

# Node executables (npm-shipped)
for f in bin/*.js; do
  check "node --check $f" node --check "$f"
done

# Bash surface: npm-shipped scripts + local bin wrappers + gate-chain infra
for f in scripts/*.sh bin/fh-gate bin/fh-run bin/fh-goal \
         templates/regression_guard.sh templates/temper_check.sh templates/predelete_check.sh templates/.git-hooks/pre-commit; do
  [ -f "$f" ] || continue
  check "bash -n $f" bash -n "$f"
done

# Count consistency: stated skill/agent counts vs actual directories.
# Drift class recurred 4x on 2026-06-10 alone (local_fh_context 26, plugin.json "3 agents",
# README "5 agents", marketplace.json "3 agents") — this makes the check mechanical and permanent.
# Logic extracted to scripts/count_check.sh so the SAME check also runs at commit time in
# the pre-commit hook (shift-left, gated on a skills-dir add/remove — fh_signal_2026-06-21
# gate-locality gap: the check previously lived only here at the publish boundary, so a
# skill-adding PR could merge with stale counts undetected until the next publish).
if ! bash scripts/count_check.sh; then
  fail=1
fi

# Referenced-path existence: backtick-quoted repo-relative file refs in the always-loaded
# governance surface (CLAUDE.md + .claude/rules/*.md) must exist. Phantom-reference class
# recurred N>=3 in the 2026-06-11 audit window (operations.md _scanner.sh, claude-chrono path,
# stale templates ref) — instrument-not-habit. Globs/placeholders/{vars} are excluded by the
# filter; tracks/ is machine-local and deliberately out of scope. Gitignored refs (e.g.
# `.claude/settings.json` named in prose *about* gitignored files) are skipped — they exist
# locally but not on a fresh clone, and "must exist" here means "must ship".
while IFS= read -r p; do
  if git check-ignore -q "$p" 2>/dev/null; then
    echo "SKIP  ref-path (gitignored): $p"
  elif [ -f "$p" ]; then
    echo "PASS  ref-path: $p"
  else
    echo "FAIL  ref-path: $p — referenced in CLAUDE.md/.claude/rules but missing"
    fail=1
  fi
done < <(grep -hoE '\`[^\` ]+\`' CLAUDE.md .claude/rules/*.md 2>/dev/null \
  | sed 's/\`//g' \
  | grep -E '^(knowledge|templates|scripts|docs|plugins|\.claude)/[^*{}<>$]+\.(md|sh|ya?ml|jsonc|json)$' \
  | sort -u)

if [ "$fail" -ne 0 ]; then
  echo "SELFCHECK: FAIL"
  exit 1
fi
echo "SELFCHECK: PASS"

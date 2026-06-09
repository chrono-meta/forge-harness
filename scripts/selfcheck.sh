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
         templates/regression_guard.sh templates/.git-hooks/pre-commit; do
  [ -f "$f" ] || continue
  check "bash -n $f" bash -n "$f"
done

if [ "$fail" -ne 0 ]; then
  echo "SELFCHECK: FAIL"
  exit 1
fi
echo "SELFCHECK: PASS"

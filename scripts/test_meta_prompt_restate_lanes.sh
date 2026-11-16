#!/usr/bin/env bash
# test_meta_prompt_restate_lanes.sh — meta-prompt-builder carries the cold-reader restate check.
#   Record-shape only: item 4 of Step 3 names the three fields, the GUESS -> WARN rule, the
#   self-restate exclusion and the NOT RUN rule, and Done When lists it as a mandatory-pass row.
#   Whether a session actually runs it is a blind sim, not this lane.
#   Known-negative in-file: the same check on a copy with item 4 removed must FAIL.
# exit: 0 PASS · 1 FAIL · 10 harness error
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
F="${1:-$ROOT/plugins/fh-meta/skills/meta-prompt-builder/SKILL.md}"
[ -f "$F" ] || { echo "harness error: $F missing -- not a pass" >&2; exit 10; }

check() {  # $1 = file; prints findings, returns 0 if all present
  local f="$1" item4 done_rows rc=0 n
  # item 4 = from its own line to the next numbered item or "Items that fail"
  item4=$(awk '/^4\. \*\*Restate check/{on=1} on && /^Items that fail/{on=0} on' "$f")
  done_rows=$(awk '/^## Done When/{on=1;next} /^## /{on=0} on' "$f")
  for n in 'GOAL' 'DONE' 'CONSTRAINTS' 'RESTATABLE' '`GUESS`' 'brief not restatable' \
           'Do not tell the reader' 'Restating your own draft yourself does not count' 'NOT RUN'; do
    printf '%s\n' "$item4" | grep -qF -- "$n" || { echo "  missing in item 4: $n"; rc=1; }
  done
  printf '%s\n' "$done_rows" | grep -qF 'Step 3 item 4 ran on every draft' \
    || { echo "  missing in Done When: item-4 row"; rc=1; }
  return $rc
}

if check "$F"; then echo "PASS: item 4 and its Done When row present"; else echo "FAIL: $F"; exit 1; fi

# known-negative: strip item 4 and its Done When row -> must fail
tmp=$(mktemp) || { echo "harness error: mktemp" >&2; exit 10; }
trap 'rm -f "$tmp"' EXIT
awk '/^4\. \*\*Restate check/{skip=1} skip && /^Items that fail/{skip=0} !skip' "$F" \
  | grep -vF 'Step 3 item 4 ran on every draft' > "$tmp"
if check "$tmp" >/dev/null; then echo "FAIL: control alive check — stripped copy still passed (lane is decorative)"; exit 1; fi
echo "PASS: control — stripped copy fails"
exit 0

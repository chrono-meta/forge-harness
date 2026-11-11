#!/usr/bin/env bash
# test_session_ledger_lanes.sh — lanes for session_ledger_write.sh + session_ledger_read.py.
# Each lane names the failure it guards. Runs in a temp dir; never touches the real ledger.
# Usage: bash scripts/test_session_ledger_lanes.sh   (rc = number of failed lanes)
set -uo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
W="$D/session_ledger_write.sh"; R="$D/session_ledger_read.py"
T="$(mktemp -d "${TMPDIR:-/tmp}/ledger_lanes.XXXXXX")"; trap 'rm -rf "$T"' EXIT
export FH_SESSION_LEDGER="$T/ledger.tsv"
fail=0; pass=0
ok()  { pass=$((pass+1)); echo "PASS $1"; }
bad() { fail=$((fail+1)); echo "FAIL $1"; }
reset() { rm -f "$FH_SESSION_LEDGER"; }
# run reader: sets out / rc
rd() { out="$(python3 "$R" "$@" 2>&1)"; rc=$?; }

# L1 empty ledger: missing file and empty file are both NO-LEDGER-LINES rc 4, never a clean table
reset; rd --expect a,b
[ "$rc" -eq 4 ] && grep -q "NO-LEDGER-LINES — file missing" <<<"$out" && grep -q "NOT-WRITTEN: a, b" <<<"$out" && ok L1a-missing || bad "L1a-missing rc=$rc"
: > "$FH_SESSION_LEDGER"; rd
[ "$rc" -eq 4 ] && grep -q "file empty" <<<"$out" && grep -q "UNKNOWN" <<<"$out" && ok L1b-empty || bad "L1b-empty rc=$rc"

# L2 broken lines: wrong field count, bad state, truncated last line → listed as MALFORMED, rc 3, valid line kept
reset
bash "$W" --session s1 --task t1 --kind board --state in_progress >/dev/null
printf 'garbage line\n' >> "$FH_SESSION_LEDGER"
printf '2026-11-11T00:00:00Z\ts1\tt1\tboard\tfinished\t\t\n' >> "$FH_SESSION_LEDGER"
printf '2026-11-11T00:00:00Z\ts1\tt1\tboard\tdone\tpr=#1\t' >> "$FH_SESSION_LEDGER"   # no newline
rd --expect s1
[ "$rc" -eq 3 ] && [ "$(grep -c MALFORMED\ line <<<"$out")" -eq 3 ] && grep -q "s1 .*in_progress" <<<"$out" && ok L2-malformed || bad "L2-malformed rc=$rc"

# L3 same session two lines: latest wins, line count shown
reset
bash "$W" --session s1 --task t1 --kind board --state in_progress >/dev/null
bash "$W" --session s1 --task t1 --kind board --state done --evidence "pr=#7 head=abcdef1" >/dev/null
rd --expect s1
row="$(grep '^s1 ' <<<"$out")"
[ "$rc" -eq 0 ] && [ "$(wc -l <<<"$row")" -eq 1 ] && grep -q "done .* 2 " <<<"$row" && ! grep -q in_progress <<<"$row" && ok L3-latest-wins || bad "L3-latest-wins rc=$rc :: $row"

# L4 silent session: expected but wrote nothing → NOT-WRITTEN row + count, rc 6
reset
bash "$W" --session s1 --task t1 --kind board --state blocked --text "waiting on CI" >/dev/null
rd --expect s1,s2
[ "$rc" -eq 6 ] && grep -q "^s2 .*NOT-WRITTEN" <<<"$out" && grep -q "2 expected · 1 wrote · 1 NOT-WRITTEN (s2)" <<<"$out" && ok L4-silent || bad "L4-silent rc=$rc"
# L4b without --expect the silence is UNKNOWN, not «all fine»
rd
grep -q "expected set UNKNOWN" <<<"$out" && ok L4b-unknown || bad L4b-unknown

# L5 writer refuses free-prose state, done without evidence, absolute path; writes nothing
reset
bash "$W" --session s1 --task t1 --kind board --state "almost done" 2>/dev/null; r1=$?
bash "$W" --session s1 --task t1 --kind board --state done 2>/dev/null; r2=$?
bash "$W" --session s1 --task t1 --kind landing --state file_written --evidence "path=/etc/x" 2>/dev/null; r3=$?
[ $r1 -eq 2 ] && [ $r2 -eq 2 ] && [ $r3 -eq 2 ] && [ ! -e "$FH_SESSION_LEDGER" ] && ok L5-writer-refuses || bad "L5 $r1 $r2 $r3"

# L6 unmeasured ≠ silent: a landing/unmeasured line counts as written and shows the state
reset
bash "$W" --session s1 --task t1 --kind landing --state unmeasured --evidence "none=no-ci-in-repo" >/dev/null
rd --expect s1
[ "$rc" -eq 0 ] && grep -q "unmeasured" <<<"$out" && ok L6-unmeasured || bad "L6 rc=$rc"

# L7-L11: cross-family codex R1 findings (each reproduced before the fix)
# L7 reader refuses a parent-traversal path the writer would refuse
reset; printf '2026-11-11T00:00:00Z\ts1\tt1\tboard\tdone\tpath=../outside\t\n' > "$FH_SESSION_LEDGER"; rd --expect s1
[ "$rc" -eq 3 ] && grep -q "MALFORMED line 1" <<<"$out" && ok L7-reader-traversal || bad "L7 rc=$rc"
# L8 writer refuses a line too long for one atomic append
reset; long="$(printf 'x%.0s' $(seq 1 600))"
bash "$W" --session s1 --task t1 --kind note --state info --text "$long" 2>/dev/null; r=$?
[ $r -eq 2 ] && [ ! -e "$FH_SESSION_LEDGER" ] && ok L8-oversize || bad "L8 rc=$r"
# L9 a trailing option without a value is usage (rc 2), not an endless loop
reset; ( bash "$W" --session s1 --task t1 --kind board --state planned --text >/dev/null 2>&1 & p=$!; sleep 2; if kill -0 $p 2>/dev/null; then kill $p; exit 99; fi; wait $p ); r=$?
[ $r -eq 2 ] && ok L9-missing-value || bad "L9 rc=$r"
# L10 two states in one value are refused
reset; bash "$W" --session s1 --task t1 --kind board --state "planned in_progress" 2>/dev/null; r=$?
[ $r -eq 2 ] && [ ! -e "$FH_SESSION_LEDGER" ] && ok L10-multi-state || bad "L10 rc=$r"
# L11 reader refuses a carriage return / control char in any field
reset; printf '2026-11-11T00:00:00Z\ts1\tt1\tnote\tinfo\t\tok\rhidden\n' > "$FH_SESSION_LEDGER"; rd --expect s1
[ "$rc" -eq 3 ] && ok L11-control-char || bad "L11 rc=$rc"

# L12 (codex R2) writer and reader split evidence the same way: a non-ASCII space inside a token stays one token
reset; bash "$W" --session s1 --task t1 --kind board --state done --evidence "$(printf 'path=docs/a\302\240b')" >/dev/null; rd --expect s1
[ "$rc" -eq 0 ] && ok L12-same-tokenizer || bad "L12 rc=$rc"

# L13 (codex R3) a glob in --evidence is not expanded against the current directory
reset; G="$T/globdir"; mkdir -p "$G"; : > "$G/pr=#7"
( cd "$G" && bash "$W" --session s1 --task t1 --kind board --state done --evidence 'pr=#*' >/dev/null 2>&1 ); r=$?
[ $r -eq 2 ] && [ ! -e "$FH_SESSION_LEDGER" ] && ok L13-no-glob || bad "L13 rc=$r"

echo "lanes: $pass passed · $fail failed"
exit "$fail"

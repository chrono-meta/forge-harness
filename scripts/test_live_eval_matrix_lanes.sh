#!/usr/bin/env bash
# Lanes for scripts/live_eval_matrix.py (per-probe verdicts across nightly reports, record only).
# Known pair: a probe that never passed must land in never-pass; one that always passed in always-pass.
# Shapes that must NOT read as a bin: a probe that did not run (UNCALIBRATED / FAILED-TO-RUN) is not a FAIL,
# a probe with fewer than 2 scored reports is too-few, a file without a run table is named unreadable.
set -u
FH="$(cd "$(dirname "$0")/.." && pwd)"
S="$FH/scripts/live_eval_matrix.py"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok() { if eval "$2"; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL $1"; fi; }

rep() { # rep <date> <id:verdict>...
  local f="$T/r/live_eval_$1.md"; shift
  { echo "# live eval"; echo; echo "| id | verdict | note |"; echo "|---|---|---|"
    for kv in "$@"; do echo "| ${kv%%:*} | ${kv#*:} | x |"; done; } > "$f"
}
mkdir -p "$T/r"
rep 2026-11-01 G-ALW:PASS G-NEV:FAIL G-MIX:PASS G-RUN:FAIL G-ONE:PASS
rep 2026-11-02 G-ALW:PASS G-NEV:FAIL G-MIX:FAIL G-RUN:FAILED-TO-RUN
rep 2026-11-03 G-ALW:PASS G-NEV:FAIL G-MIX:PASS G-RUN:UNCALIBRATED "G-ONE:NOT-LIVE-MEASURABLE (no tool)"
printf '# live eval\n\nno table here\n' > "$T/r/live_eval_2026-11-04.md"
printf '| G-ALW | FAIL | x |\n' > "$T/r/live_eval_stratify_RESULT_2026-11-05.md"   # not a nightly report name

out=$(python3 "$S" --dir "$T/r"); rc=$?
ok M1-rc0            '[ $rc -eq 0 ]'
ok M2-never-pass     'grep -qx "never-pass: 1 — G-NEV" <<<"$out"'
ok M3-always-pass    'grep -qx "always-pass: 1 — G-ALW" <<<"$out"'
ok M4-mixed          'grep -qx "mixed: 1 — G-MIX" <<<"$out"'
# G-RUN: one FAIL + two not-run reports → too-few, never never-pass
ok M5-notrun-not-fail 'grep -qx "too-few: 2 — G-ONE, G-RUN" <<<"$out"'
ok M6-row-cells      'grep -Eq "^G-RUN +FRU +pass=0 fail=1 not-scored=2 absent=0 +too-few$" <<<"$out"'
# G-ONE: absent on 11-02 (.), present with an out-of-enum verdict on 11-03 (N) — not absent
ok M7-absent-vs-oos  'grep -Eq "^G-ONE +P\.N +pass=1 fail=0 not-scored=1 absent=1 +too-few$" <<<"$out"'
ok M8-unreadable     'grep -q "reports unreadable or without a run table: 1 — live_eval_2026-11-04.md" <<<"$out"'
ok M9-name-filter    'grep -q "reports read: 3 (2026-11-01 .. 2026-11-03)" <<<"$out"'

mkdir -p "$T/empty"
out=$(python3 "$S" --dir "$T/empty"); rc=$?
ok M10-empty-not-zero '[ $rc -eq 0 ] && grep -q "not measured, not zero" <<<"$out" && ! grep -q "^never-pass" <<<"$out"'

python3 "$S" --dir "$T/nope" >/dev/null 2>&1; rc=$?
ok M11-missing-dir   '[ $rc -eq 10 ]'
python3 "$S" --bogus >/dev/null 2>&1; rc=$?
ok M12-bad-arg       '[ $rc -eq 10 ]'

# exit code ignores bins: a folder that is all never-pass still exits 0
mkdir -p "$T/bad"; cp "$T/r/live_eval_2026-11-01.md" "$T/bad/"; cp "$T/r/live_eval_2026-11-02.md" "$T/bad/"
python3 "$S" --dir "$T/bad" >/dev/null; rc=$?
ok M13-no-verdict-rc '[ $rc -eq 0 ]'

echo "live_eval_matrix lanes: pass=$pass fail=$fail"
[ $fail -eq 0 ]

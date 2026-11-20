#!/usr/bin/env bash
# Lanes for scripts/job_heartbeat.py — fixture meta/agents dirs only (never the real LaunchAgents or tracks).
#   H1 a missing day, no pause record        → the date is named, and «pause record not read»
#   H2 a pause row covering that day         → «paused (recorded)», not «no output»; another job's gap stays a gap
#   H3 every day present                     → silent
#   H4 a job whose plist is not installed    → silent about it
#   H5 days before the job's first output    → not counted (a new job is not «missing» last week)
#   H6 daily-report is named for D-1         → its run day D is checked against daily_report_<D-1>.md
#   H7 a bad --today                         → one HARNESS-ERROR line, rc 0 (advisory, never a crash)
#   H8 a pause row for another label / «*»   → the other label does not cover; «*» covers every job
#   H9 revert probe: pause lookup disabled   → H2 turns red
#   H11 a 0-byte file (crashed run)          → not output: the day is named
#   H12 an installed job that never wrote    → named once, never silent
#   H13 bad pause rows (3 fields · from>to)  → not a pause, counted next to the gap
#   H14 run from a git worktree, no --meta   → reads the main checkout's tracks/_meta (fixture guard first)
#   H15 pause file unreadable (a directory)  → gaps still listed, «absent or unreadable»
set -u
. "$(dirname "${BASH_SOURCE[0]}")/fixture_guard_lib.sh"   # scrub inherited GIT_* env first (#1088) — H14 calls git
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S="$HERE/job_heartbeat.py"
T=$(mktemp -d "${TMPDIR:-/tmp}/jhb.XXXXXX"); trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok() { echo "PASS $1"; pass=$((pass + 1)); }
no() { echo "FAIL $1"; printf '%s\n' "$2" | sed 's/^/     /' | head -5; fail=$((fail + 1)); }
run() { python3 "${PY:-$S}" --meta "$T/m" --agents "$T/a" --today 2026-11-20 --days 3 "$@" 2>&1; }
fresh() { rm -rf "$T/m" "$T/a"; mkdir -p "$T/m/selfdev" "$T/a"; for l in "$@"; do : > "$T/a/com.forge-harness.$l.plist"; done; }
le() { for d in "$@"; do echo x > "$T/m/live_eval_$d.md"; done; }
sd() { for d in "$@"; do echo x > "$T/m/selfdev/report_$d.md"; done; }

fresh live-eval selfdev-loop; le 2026-11-15 2026-11-16 2026-11-17 2026-11-19; sd 2026-11-15 2026-11-16 2026-11-17 2026-11-19
o=$(run); rc=$?
[ $rc = 0 ] && [[ "$o" == *"live-eval — no output for 2026-11-18"* ]] && [[ "$o" == *"pause record not read"* ]] && ok H1-missing-named || no H1-missing-named "$o"

printf 'live-eval\t2026-11-17\t2026-11-18\toperator 11-17 bootout\n' > "$T/m/job_pauses.tsv"
o=$(run)
[[ "$o" == *"live-eval — paused (recorded): 2026-11-18"* ]] && [[ "$o" != *"live-eval — no output"* ]] \
  && [[ "$o" == *"selfdev-loop — no output for 2026-11-18"* ]] && [[ "$o" != *"pause record not read"* ]] && ok H2-pause-sets-apart || no H2-pause-sets-apart "$o"

le 2026-11-18; sd 2026-11-18
o=$(run); [ -z "$o" ] && ok H3-all-present-silent || no H3-all-present-silent "$o"

fresh selfdev-loop; le 2026-11-15; sd 2026-11-17 2026-11-18 2026-11-19
o=$(run); [ -z "$o" ] && ok H4-uninstalled-job-silent || no H4-uninstalled-job-silent "$o"

fresh live-eval; le 2026-11-19
o=$(run); [ -z "$o" ] && ok H5-before-first-output-not-counted || no H5-before-first-output-not-counted "$o"

fresh daily-report; for d in 2026-11-15 2026-11-16 2026-11-18; do echo x > "$T/m/daily_report_$d.md"; done
o=$(run)   # run days 11-17 → _16 ✓ · 11-18 → _17 ✗ · 11-19 → _18 ✓
[[ "$o" == *"daily-report — no output for 2026-11-18 "* ]] && ok H6-daily-report-offset || no H6-daily-report-offset "$o"

o=$(python3 "$S" --meta "$T/m" --agents "$T/a" --today not-a-date); rc=$?
[ $rc = 0 ] && [[ "$o" == *"HARNESS-ERROR"* ]] && ok H7-bad-input-named-rc0 || no H7-bad-input-named-rc0 "rc=$rc $o"

fresh live-eval selfdev-loop; le 2026-11-16 2026-11-17 2026-11-19; sd 2026-11-16 2026-11-17 2026-11-19
printf 'selfdev-loop\t2026-11-18\t2026-11-18\tx\n' > "$T/m/job_pauses.tsv"
o1=$(run)
printf '*\t2026-11-18\t2026-11-18\tx\n' > "$T/m/job_pauses.tsv"
o2=$(run)
[[ "$o1" == *"live-eval — no output for 2026-11-18"* ]] && [[ "$o2" == *"live-eval — paused (recorded)"* ]] && [[ "$o2" == *"selfdev-loop — paused (recorded)"* ]] \
  && ok H8-label-scoped-and-star || no H8-label-scoped-and-star "$o1 / $o2"

mkdir -p "$T/mut"; sed 's/if pauses and any(p\[0\] in (label/if False and any(p[0] in (label/' "$S" > "$T/mut/job_heartbeat.py"
if grep -q 'if False and any' "$T/mut/job_heartbeat.py"; then
  fresh live-eval; le 2026-11-16 2026-11-17 2026-11-19; printf 'live-eval\t2026-11-18\t2026-11-18\tx\n' > "$T/m/job_pauses.tsv"
  o=$(PY="$T/mut/job_heartbeat.py" run)
  [[ "$o" == *"live-eval — no output for 2026-11-18"* ]] && ok "H9-revert-probe (pause lookup off → H2 would be red)" || no H9-revert-probe "$o"
else no H9-revert-probe "mutation did not apply (instrument error, not a pass)"; fi

o=$(python3 "$S" --self-test); [[ "$o" == *"3/3"* ]] && ok H10-self-test || no H10-self-test "$o"

fresh live-eval; le 2026-11-16 2026-11-17 2026-11-19; : > "$T/m/live_eval_2026-11-18.md"
o=$(run); [[ "$o" == *"live-eval — no output for 2026-11-18"* ]] && ok H11-empty-file-is-not-output || no H11-empty-file-is-not-output "$o"

fresh live-eval
o=$(run); [[ "$o" == *"live-eval — installed, but no output file found"* ]] && ok H12-never-produced-named || no H12-never-produced-named "$o"

fresh live-eval; le 2026-11-16 2026-11-17 2026-11-19
printf 'live-eval\t2026-11-18\t2026-11-18\n*\t2026-11-18\t2026-11-17\tbackwards\n' > "$T/m/job_pauses.tsv"
o=$(run); [[ "$o" == *"live-eval — no output for 2026-11-18"* ]] && [[ "$o" == *"2 unreadable row(s)"* ]] && ok H13-bad-rows-not-a-pause || no H13-bad-rows-not-a-pause "$o"

g() { git -c user.name=t -c user.email=t@t -c commit.gpgsign=false "$@"; }
mkdir -p "$T/repo" && ( cd "$T/repo" && g init -q && printf 'tracks/\n' > .gitignore && g add .gitignore && g commit -qm i && mkdir -p scripts tracks/_meta && cp "$S" scripts/ && g worktree add -q "$T/rwt" -b w 2>/dev/null )
mkdir -p "$T/rwt/scripts" && cp "$S" "$T/rwt/scripts/"
for d in 2026-11-16 2026-11-17 2026-11-19; do echo x > "$T/repo/tracks/_meta/live_eval_$d.md"; done
fresh live-eval
o=$(python3 "$T/rwt/scripts/job_heartbeat.py" --agents "$T/a" --today 2026-11-20 --days 3 2>&1)
[[ "$o" == *"live-eval — no output for 2026-11-18"* ]] && [[ "$o" != *"no output file found"* ]] && ok H14-worktree-reads-main || no H14-worktree-reads-main "$o"

fresh live-eval; le 2026-11-16 2026-11-17 2026-11-19; mkdir -p "$T/m/job_pauses.tsv"
o=$(run); rc=$?
[ $rc = 0 ] && [[ "$o" == *"live-eval — no output for 2026-11-18"* ]] && [[ "$o" == *"absent or unreadable"* ]] && ok H15-unreadable-pause-file || no H15-unreadable-pause-file "rc=$rc $o"

[ $((pass + fail)) -eq 15 ] || { echo "HARNESS-ERROR: counted $((pass + fail)) lanes, expected 15"; exit 2; }
echo "job_heartbeat lanes: $pass passed · $fail failed"
[ "$fail" -eq 0 ]

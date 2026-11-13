#!/usr/bin/env bash
# test_fixture_guard_coverage_lanes.sh — ratchet: every lane that calls git must source
# fixture_guard_lib.sh BEFORE its first git call.
#
# WHY: the lib unsets inherited GIT_DIR / GIT_INDEX_FILE / … at source time (#1088). A lane that calls
# git without it, run directly from a shell with GIT_DIR exported, commits into (or reads) that repo
# instead of its fixture. Measured 2026-11-13 on a decoy: 62 of 90 lanes wrote into it under GIT_DIR.
#
# RULE (one rule, no writer/reader split): a file matching scripts/test_*.sh or scripts/*_lanes.sh that
# contains a git invocation must contain a line sourcing fixture_guard_lib.sh, and that line must come
# before the first git invocation. Readers are included on purpose: under an exported GIT_DIR a
# read-only lane inspects the wrong repo and reports on it — a wrong answer, not just a leak.
#
# NOT SEEN (named residuals): git reached through a variable (`G=git; "$G" commit`), and a guard line
# that sits inside a heredoc or an unexecuted branch — the scan reads lines, not control flow.
#
# SUBJECT: the scan below, run over the live scripts/ directory (L-live) and over planted fixtures
# (calibration). Revert probe: delete the guard line from any one lane → L-live goes red naming it.
. "$(dirname "${BASH_SOURCE[0]}")/fixture_guard_lib.sh"   # scrub inherited GIT_* env first (#1088)
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/.."
pass=0; fail=0
chk() { if [ "$1" -eq 0 ]; then pass=$((pass+1)); echo "  PASS  $2"; else fail=$((fail+1)); echo "  FAIL  $2"; fi; }

GIT_RE='(^|[^A-Za-z0-9_.-])(/[A-Za-z0-9_./-]*/)?"?git"?[[:space:]]+(-[A-Za-z-]|[a-z])'
SRC_RE='^[[:space:]]*(\.|source)[[:space:]]+("[^"#]*("[^"#]*"[^"#]*)*fixture_guard_lib\.sh"|[^[:space:]"#]*fixture_guard_lib\.sh)[[:space:]]*(#.*)?$'

# scan <dir> → prints one line per offending file; exit 0 when none, 1 when any, 2 when nothing scanned
scan() {
  _n=0; _bad=0; _seen=""
  for f in "$1"/test_*.sh "$1"/*_lanes.sh; do
    [ -f "$f" ] || continue
    case "$f" in "$1"/test_*_lanes.sh) case " $_seen " in *" $f "*) continue ;; esac ;; esac
    _seen="${_seen:-} $f"
    case "$f" in */fixture_guard_lib.sh) continue ;; esac
    g="$(grep -nE "$GIT_RE" "$f" | grep -vE '^[0-9]+:[[:space:]]*#' | head -1 | cut -d: -f1)"
    [ -n "$g" ] || continue
    _n=$((_n+1))
    s="$(grep -nE "$SRC_RE" "$f" | head -1 | cut -d: -f1)"
    if [ -z "$s" ]; then echo "UNGUARDED  $f (first git call line $g, no fixture_guard_lib.sh source)"; _bad=$((_bad+1))
    elif [ "$s" -gt "$g" ]; then echo "LATE-GUARD $f (guard line $s after first git call line $g)"; _bad=$((_bad+1)); fi
  done
  echo "SCANNED $_n"
  [ "$_n" -gt 0 ] || return 2
  [ "$_bad" -eq 0 ]
}

T="$(mktemp -d "${TMPDIR:-/tmp}/fgcov.XXXXXX")"; trap 'rm -rf "$T"' EXIT
GUARD='. "$(dirname "${BASH_SOURCE[0]}")/fixture_guard_lib.sh"'

# ── calibration: planted fixtures ──
mkdir "$T/c1"; printf '#!/bin/bash\n%s\ngit -C "$d" init -q\n' "$GUARD" > "$T/c1/test_ok_lanes.sh"
out="$(scan "$T/c1")"; rc=$?; [ "$rc" -eq 0 ]; chk $? "C1 guarded writer → green (rc=$rc)"
mkdir "$T/c2"; printf '#!/bin/bash\ngit -C "$d" commit -q -m base\n' > "$T/c2/test_w_lanes.sh"
out="$(scan "$T/c2")"; rc=$?; [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'UNGUARDED.*test_w_lanes'; chk $? "C2 planted unguarded writer → red, named (rc=$rc)"
mkdir "$T/c3"; printf '#!/bin/bash\nx=$(git log -1 --format=%%h)\n' > "$T/c3/test_r_lanes.sh"
out="$(scan "$T/c3")"; rc=$?; [ "$rc" -eq 1 ]; chk $? "C3 unguarded read-only lane → red too (rule covers readers) (rc=$rc)"
mkdir "$T/c4"; printf '#!/bin/bash\ngit -C "$d" init -q\n%s\n' "$GUARD" > "$T/c4/test_late_lanes.sh"
out="$(scan "$T/c4")"; rc=$?; [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q LATE-GUARD; chk $? "C4 guard after first git call → red (rc=$rc)"
mkdir "$T/c5"; printf '#!/bin/bash\n# git commit is only mentioned in a comment\necho digit init\n' > "$T/c5/test_none_lanes.sh"
out="$(scan "$T/c5")"; rc=$?; [ "$rc" -eq 2 ]; chk $? "C5 no git call anywhere → nothing scanned = rc 2, not a pass (rc=$rc)"
mkdir "$T/c6"; printf '#!/bin/bash\ngit init -q\n' > "$T/c6/helper.sh"; printf '#!/bin/bash\n%s\ngit status\n' "$GUARD" > "$T/c6/test_x_lanes.sh"
out="$(scan "$T/c6")"; rc=$?; [ "$rc" -eq 0 ]; chk $? "C6 non-lane script is out of scope (rc=$rc)"

mkdir "$T/c7"; printf '#!/bin/bash\n. /dev/null # fixture_guard_lib.sh\ngit -C "$d" commit -q\n' > "$T/c7/test_fake_lanes.sh"
out="$(scan "$T/c7")"; rc=$?; [ "$rc" -eq 1 ]; chk $? "C7 decoy source line (\`. /dev/null # fixture_guard_lib.sh\`) does not count as a guard (rc=$rc, codex R1)"
mkdir "$T/c8"; printf '#!/bin/bash\ngit --git-dir="$d/.git" commit -q\n' > "$T/c8/test_gd_lanes.sh"; printf '#!/bin/bash\ngit\tstatus\n' > "$T/c8/test_tab_lanes.sh"
out="$(scan "$T/c8")"; rc=$?; [ "$rc" -eq 1 ] && [ "$(printf '%s\n' "$out" | grep -c UNGUARDED)" -eq 2 ]; chk $? "C8 \`git --git-dir=…\` and tab-separated git are both seen (rc=$rc, codex R1)"

mkdir "$T/c9"; for form in 'git -p status' 'git -C"$d" status' '/usr/bin/git status' '"git" status'; do printf '#!/bin/bash\n%s\n' "$form" > "$T/c9/test_$(printf '%s' "$form" | tr -c 'a-z' _)_lanes.sh"; done
out="$(scan "$T/c9")"; rc=$?; [ "$rc" -eq 1 ] && [ "$(printf '%s\n' "$out" | grep -c UNGUARDED)" -eq 4 ]; chk $? "C9 git -p · git -C\"…\" · /usr/bin/git · \"git\" are all seen (rc=$rc, codex R2)"

# ── live ──
out="$(scan scripts)"; rc=$?
printf '%s\n' "$out" | grep -vE '^SCANNED' | sed 's/^/    /'
n="$(printf '%s\n' "$out" | sed -n 's/^SCANNED //p')"
[ "$rc" -eq 0 ] && [ "${n:-0}" -ge 80 ]; chk $? "L-live every git-calling lane sources the guard first (scanned ${n:-0}, floor 80 — measured 86 on 2026-11-13; a sharp drop means the scan regex broke)"

echo "fixture-guard coverage lanes: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

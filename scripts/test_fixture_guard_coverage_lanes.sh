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
# SEEN since 2026-11-14: git captured into a variable (`G=$(command -v git)`, `G=/usr/bin/git`) and a
# guard line inside a heredoc body (not counted). NOT SEEN (named residuals): git reached through
# indirection the assignment regex does not name (`eval`, arrays, a function wrapping git), and a guard
# in an unexecuted branch (`if false; then . …; fi`) — the scan reads lines, not control flow.
# Known over-block (fail-closed, red not green): a quoted `"<<EOF"` in text opens heredoc state, so a
# real guard right after it is not counted until a line equal to EOF appears. The heredoc tracker is a
# line scanner, not a shell parser: two codex rounds each found new delimiter shapes (R1 numeric ·
# multiple; R2 tab strip · `EOF-X`), all fixed with fixtures C15–C17; further shapes are this residual.
#
# SUBJECT: the scan below, run over the live scripts/ directory (L-live) and over planted fixtures
# (calibration). Revert probe: delete the guard line from any one lane → L-live goes red naming it.
. "$(dirname "${BASH_SOURCE[0]}")/fixture_guard_lib.sh"   # scrub inherited GIT_* env first (#1088)
set -u
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
cd "$(dirname "${BASH_SOURCE[0]}")/.."
pass=0; fail=0; skipped=0
sk() { skipped=$((skipped+1)); echo "  SKIP  $1"; }
chk() { if [ "$1" -eq 0 ]; then pass=$((pass+1)); echo "  PASS  $2"; else fail=$((fail+1)); echo "  FAIL  $2"; fi; }

GIT_RE='(^|[^A-Za-z0-9_.-])(/[A-Za-z0-9_./-]*/)?"?git"?[[:space:]]+(-[A-Za-z-]|[a-z])'
SRC_RE='^[[:space:]]*(\.|source)[[:space:]]+("[^"#]*("[^"#]*"[^"#]*)*fixture_guard_lib\.sh"|[^[:space:]"#]*fixture_guard_lib\.sh)[[:space:]]*(#.*)?$'

# git captured into a variable (`G=git`, `G=/usr/bin/git`, `G=$(command -v git)`, `$(which git)`): the
# assignment line counts as the first git reference, so a lane that only ever runs "$G" is in scope.
VAR_RE='^[[:space:]]*(export[[:space:]]+|local[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*=("|'"'"')?((/[A-Za-z0-9_./-]*/)?git|\$\((command -v|which)[[:space:]]+git\))("|'"'"')?([[:space:];]|$)'
# guard_line <file> → line number of the first guard source line that is NOT inside a heredoc body
# (a `. …fixture_guard_lib.sh` written into a here-document is data for another file, not a guard here).
guard_line() {
  SRC_RE="$SRC_RE" awk 'BEGIN { re = ENVIRON["SRC_RE"]; np = 0; qi = 0 }
    qi < np { t = $0; if (dash[qi]) sub(/^\t+/, "", t); if (t == q[qi]) qi++; next }
    /^[[:space:]]*#/ { next }
    $0 ~ re { print NR; exit }
    { l = $0; gsub(/<<</, "", l)
      while (match(l, /<<-?[[:space:]]*[^[:space:]<>|&;()]+/)) {
        tag = substr(l, RSTART, RLENGTH); dash[np] = (tag ~ /^<<-/)
        sub(/^<<-?[[:space:]]*/, "", tag); gsub(/["\047\\]/, "", tag)
        q[np++] = tag; l = substr(l, RSTART + RLENGTH) } }
  ' "$1"
}

# scan <dir> → prints one line per offending file; exit 0 when none, 1 when any, 2 when nothing scanned
scan() {
  _n=0; _bad=0; _seen=""
  for f in "$1"/test_*.sh "$1"/*_lanes.sh; do
    [ -f "$f" ] || continue
    case "$f" in "$1"/test_*_lanes.sh) case " $_seen " in *" $f "*) continue ;; esac ;; esac
    _seen="${_seen:-} $f"
    case "$f" in */fixture_guard_lib.sh) continue ;; esac
    g="$(grep -nE "$GIT_RE|$VAR_RE" "$f" | grep -vE '^[0-9]+:[[:space:]]*#' | head -1 | cut -d: -f1)"
    [ -n "$g" ] || continue
    _n=$((_n+1))
    s="$(guard_line "$f")"
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

# C10: the same file run from a non-git copy (an installed package's shape) must SKIP L-live by name,
# exit 0, and NOT print a PASS for it. The checkout run below is the opposite arm (L-live measured).
if [ -z "${FGCOV_INNER:-}" ]; then
  mkdir -p "$T/pkg/scripts"; cp "$SELF" scripts/fixture_guard_lib.sh "$T/pkg/scripts/"
  out="$(cd "$T/pkg" && FGCOV_INNER=1 bash scripts/test_fixture_guard_coverage_lanes.sh 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -q '^  SKIP  L-live — NOT-APPLICABLE' \
    && ! printf '%s\n' "$out" | grep -q 'PASS  L-live' && printf '%s\n' "$out" | grep -q '1 skipped (not a pass)'
  chk $? "C10 non-git tree (installed package) → L-live SKIPPED by name, not red, not counted as pass (rc=$rc)"
fi

mkdir "$T/c11"; printf '#!/bin/bash\nG=$(command -v git)\n"$G" -C "$d" commit -q\n' > "$T/c11/test_var_lanes.sh"; printf '#!/bin/bash\nREALGIT=/usr/bin/git\n"$REALGIT" status\n' > "$T/c11/test_var2_lanes.sh"
out="$(scan "$T/c11")"; rc=$?; [ "$rc" -eq 1 ] && [ "$(printf '%s\n' "$out" | grep -c UNGUARDED)" -eq 2 ]; chk $? "C11 git only through a variable (\$(command -v git) · /usr/bin/git) is seen (rc=$rc)"
mkdir "$T/c12"; printf '#!/bin/bash\n%s\nG=$(command -v git)\n"$G" status\n' "$GUARD" > "$T/c12/test_vok_lanes.sh"
out="$(scan "$T/c12")"; rc=$?; [ "$rc" -eq 0 ]; chk $? "C12 control: guarded variable lane stays green (rc=$rc)"
mkdir "$T/c13"; printf '#!/bin/bash\ncat > "$d/x.sh" <<EOF\n%s\nEOF\ngit -C "$d" status\n' "$GUARD" > "$T/c13/test_hd_lanes.sh"
out="$(scan "$T/c13")"; rc=$?; [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'UNGUARDED.*test_hd_lanes'; chk $? "C13 guard line inside a heredoc body does not count (rc=$rc)"
mkdir "$T/c14"; printf '#!/bin/bash\ncat > "$d/x.sh" <<'"'"'EOF'"'"'\necho hi\nEOF\n%s\ngit -C "$d" status\n' "$GUARD" > "$T/c14/test_hdok_lanes.sh"
out="$(scan "$T/c14")"; rc=$?; [ "$rc" -eq 0 ]; chk $? "C14 control: heredoc closes, real guard after it counts (rc=$rc)"

mkdir "$T/c15"; printf '#!/bin/bash\ncat <<123\n%s\n123\ngit status\n' "$GUARD" > "$T/c15/test_num_lanes.sh"; printf '#!/bin/bash\ncat <<ONE <<TWO\nfirst\nONE\n%s\nTWO\ngit status\n' "$GUARD" > "$T/c15/test_two_lanes.sh"
out="$(scan "$T/c15")"; rc=$?; [ "$rc" -eq 1 ] && [ "$(printf '%s\n' "$out" | grep -c UNGUARDED)" -eq 2 ]; chk $? "C15 numeric heredoc delimiter and two heredocs on one line are both tracked (rc=$rc, codex R1)"

mkdir "$T/c16"; printf '#!/bin/bash\ncat <<EOF\n\tEOF\n%s\nEOF\ngit status\n' "$GUARD" > "$T/c16/test_tab_lanes.sh"; printf '#!/bin/bash\ncat <<EOF-X\nEOF\n%s\nEOF-X\ngit status\n' "$GUARD" > "$T/c16/test_dash_lanes.sh"
out="$(scan "$T/c16")"; rc=$?; [ "$rc" -eq 1 ] && [ "$(printf '%s\n' "$out" | grep -c UNGUARDED)" -eq 2 ]; chk $? "C16 tab-prefixed terminator closes only <<- heredocs · delimiter EOF-X is not closed by EOF (rc=$rc, codex R2)"
mkdir "$T/c17"; printf '#!/bin/bash\ncat <<-EOF\n\tbody\n\tEOF\n%s\ngit status\n' "$GUARD" > "$T/c17/test_dok_lanes.sh"
out="$(scan "$T/c17")"; rc=$?; [ "$rc" -eq 0 ]; chk $? "C17 control: <<- heredoc closed by a tab-indented terminator, guard after it counts (rc=$rc)"

# ── live ──
# The floor 80 is a CHECKOUT number: an installed npm package ships fewer lanes (70 in 3.41.0), so run
# there the scan is not wrong, it is measuring a different tree. Same test selfcheck uses for package
# mode (`[ ! -e .git ]`). Non-git → the live lane is SKIPPED by name and the summary says so; it is
# never counted as a pass. Calibration C1–C9 above still runs — the scanner itself works anywhere.
if [ ! -e .git ]; then
  sk "L-live — NOT-APPLICABLE: not a git checkout (installed package mode); the floor 80 counts the checkout's lanes. Run in a clone to measure. Not a pass."
else
  out="$(scan scripts)"; rc=$?
  printf '%s\n' "$out" | grep -vE '^SCANNED' | sed 's/^/    /'
  n="$(printf '%s\n' "$out" | sed -n 's/^SCANNED //p')"
  [ "$rc" -eq 0 ] && [ "${n:-0}" -ge 80 ]; chk $? "L-live every git-calling lane sources the guard first (scanned ${n:-0}, floor 80 — measured 86 on 2026-11-13; a sharp drop means the scan regex broke)"
fi

echo "fixture-guard coverage lanes: $pass passed, $fail failed$( [ "$skipped" -gt 0 ] && printf ', %s skipped (not a pass)' "$skipped")"
[ "$fail" -eq 0 ]

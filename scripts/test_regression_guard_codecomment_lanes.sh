#!/usr/bin/env bash
# test_regression_guard_codecomment_lanes.sh — Axis 1 F4 must not count `#` comment lines in code.
#
# WHY (2026-11-04): F4 counts operational tokens (PASS, BLOCK, M-tier, ...) and blocks at >=50%
# loss. In a .py file a `PASS` that sits only in a comment is prose, yet it was counted: a
# downstream harness's utterance_checklist_hook.py reworded one comment, `PASS` went 1 -> 0, and
# the guard hard-blocked an otherwise clean port. F4 now drops real Python comments (found by
# Python's tokenizer) before counting. Shell is not filtered. These lanes pin both directions:
#   C1 .py, token only in a comment, comment reworded          -> no M-tier  (the fix)
#   C2 .py, token in a string literal, dropped                 -> M-tier     (still guards code)
#   C3 .sh, `# BLOCK` inside a heredoc, changed                -> M-tier     (shell not filtered)
#   C4 .md, `# PASS ...` heading dropped                       -> M-tier     (md is not code)
#   C5 .py, `# BLOCK` line inside a triple-quoted string       -> M-tier     (string data, not a comment)
#   C6 .py that does not parse, comment-only token dropped     -> M-tier     (tokenizer fails -> stricter)
#   C7 .py with a form feed before a string holding PASS       -> M-tier     (rows must not shift)
#   C8 .py, comment then a lone CR then a string holding PASS  -> M-tier     (only the comment text goes)
# C3, C5 (round 1) and C7 (round 2), C8 (round 3) are the cross-family findings against a first draft that matched `^#` lines.
# REVERT PROBE: the .py case is disabled in a copy of the guard and C1 must turn red.
#
# Usage: bash scripts/test_regression_guard_codecomment_lanes.sh   Exit: 0 = all behave; 1 = regression.

set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/fixture_guard_lib.sh"   # fixtures never write the real repo
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GUARD="$REPO_ROOT/templates/regression_guard.sh"
T="$(fh_fixture_root "$(mktemp -d)")"
: "${T:?fixture root unset — refusing to run git in cwd}"
trap 'rm -rf "$T"' EXIT
FAIL=0

PY_BEFORE='import sys

def main():
    # retry on a busy lock (5x PASS under contention)
    return 0
'
PY_AFTER='import sys

def main():
    # retry on a busy lock, measured under contention
    return 0
'
PYS_BEFORE='def verdict(ok):
    return "PASS" if ok else "FAIL"
'
PYS_AFTER='def verdict(ok):
    return "ok" if ok else "FAIL"
'
SH_BEFORE='#!/usr/bin/env bash
cat <<EOF
# BLOCK
EOF
'
SH_AFTER='#!/usr/bin/env bash
cat <<EOF
# allow
EOF
'
PYQ_BEFORE='MSG = """
    # BLOCK
"""
print(MSG)
'
PYQ_AFTER='MSG = """
    # allow
"""
print(MSG)
'
PYBAD_BEFORE='def broken(:
    # PASS here
    return 0
'
PYBAD_AFTER='def broken(:
    # fine here
    return 0
'
PYFF_BEFORE=$(printf 'x=0\f\ns="PASS"\n# note\n')
PYFF_AFTER=$(printf 'x=0\f\ns="okay"\n# note\n')
PYCR_BEFORE=$(printf '# note\rs="PASS"\n')
PYCR_AFTER=$(printf '# note\rs="okay"\n')
MD_BEFORE='# s
# PASS criteria
the run is green.
'
MD_AFTER='# s
the run is green.
'

# $1=dir $2=path $3=before $4=after — base commit with $3, then stage $4
mkcase() {
  local d=$1 p=$2
  mkdir -p "$d/$(dirname "$p")"
  git -C "$d" init -q && git -C "$d" config user.email t@t && git -C "$d" config user.name t
  printf '%s' "$3" > "$d/$p"
  git -C "$d" add -A && git -C "$d" commit -q -m base
  printf '%s' "$4" > "$d/$p"
  git -C "$d" add -A
}

# $1=id $2=dir $3=guard $4=expect(block|pass)
run_lane() {
  local id=$1 d=$2 g=$3 want=$4 rc out
  out=$(cd "$d" && bash "$g" --staged 2>&1); rc=$?; [ -n "${SHOW:-}" ] && printf "%s\n" "$out" | grep -E "M-TIER" | sed "s/^/     [$id] /"
  if [ -z "$out" ]; then echo "  ❌ $id — guard printed nothing (instrument silence, not a pass)"; FAIL=1; return; fi
  if [ "$rc" -ne 0 ] && [ "$rc" -ne 1 ] && [ "$rc" -ne 2 ]; then
    echo "  ❌ $id — guard rc=$rc (could not run)"; printf '%s\n' "$out" | tail -3 | sed 's/^/       /'; FAIL=1; return
  fi
  if ! grep -c "Files changed: 1" <<<"$out" >/dev/null; then
    echo "  ❌ $id — the fixture file was not selected (inert pathspec reads as a clean 0)"; FAIL=1; return
  fi
  if [ "$want" = block ] && [ "$rc" -eq 2 ]; then echo "  ✅ $id — M-tier block (rc=2)"
  elif [ "$want" = pass ] && [ "$rc" -ne 2 ]; then echo "  ✅ $id — no M-tier (rc=$rc)"
  else echo "  ❌ $id — want $want, got rc=$rc"; printf '%s\n' "$out" | grep -E 'M-TIER|token' | head -3 | sed 's/^/       /'; FAIL=1
  fi
}

echo "regression_guard F4 — code comments are not operational tokens"
mkcase "$T/c1" scripts/hook.py "$PY_BEFORE" "$PY_AFTER";       run_lane C1 "$T/c1" "$GUARD" pass
mkcase "$T/c2" scripts/verdict.py "$PYS_BEFORE" "$PYS_AFTER";  run_lane C2 "$T/c2" "$GUARD" block
mkcase "$T/c3" scripts/gate.sh "$SH_BEFORE" "$SH_AFTER";       run_lane C3 "$T/c3" "$GUARD" block
mkcase "$T/c4" README.md "$MD_BEFORE" "$MD_AFTER";             run_lane C4 "$T/c4" "$GUARD" block
mkcase "$T/c5" scripts/msg.py "$PYQ_BEFORE" "$PYQ_AFTER";      run_lane C5 "$T/c5" "$GUARD" block
mkcase "$T/c6" scripts/bad.py "$PYBAD_BEFORE" "$PYBAD_AFTER";  run_lane C6 "$T/c6" "$GUARD" block
mkcase "$T/c7" scripts/ff.py "$PYFF_BEFORE" "$PYFF_AFTER";     run_lane C7 "$T/c7" "$GUARD" block
mkcase "$T/c8" scripts/cr.py "$PYCR_BEFORE" "$PYCR_AFTER";     run_lane C8 "$T/c8" "$GUARD" block

echo "revert probe — disable the .py case; C1 must turn red"
G2="$T/guard_reverted.sh"
sed 's/^    \*\.py)$/    __never_matches__)/' "$GUARD" > "$G2"
if cmp -s "$GUARD" "$G2"; then
  echo "  ❌ R1 — revert did not apply (pattern not found in guard; probe is dead)"; FAIL=1
else
  out=$(cd "$T/c1" && bash "$G2" --staged 2>&1); rc=$?
  if [ "$rc" -eq 2 ]; then echo "  ✅ R1 — reverted guard blocks C1 (rc=2): the case is load-bearing"
  else echo "  ❌ R1 — reverted guard still passes C1 (rc=$rc): lane C1 is decoration"; FAIL=1
  fi
fi

[ "$FAIL" -eq 0 ] && echo "PASS — 8 lanes + revert probe" || echo "FAIL"
exit "$FAIL"

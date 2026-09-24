#!/usr/bin/env bash
# test_post_squash_verify_lanes.sh — anchor for scripts/post_squash_verify.sh.
#
# Known pairs from the origin signal (fh_signal_2026-09-21_post-squash-verify.md §설계 조건):
#   ⓐ a clean squash → pass              ⓑ a squash that drops one file → 🟥 rc=1
#   ⓒ no --rerun → rc=2                  🟥 without ⓒ the "② is required" clause is decoration
# plus: trivial ② refused (rc=3) · failing ② (rc=1) · silent ② (rc=4) · a path main ALSO changed is
# COMBINED, not DIFFERS · an extra path in the squash is 🟥 EXTRA · the caller's HEAD is untouched.
# Every fixture is a throwaway repo built here (portable; no dependency on this repo's history).
set -uo pipefail
cd "$(dirname "$0")/.."
SC="$PWD/scripts/post_squash_verify.sh"
[ -f "$SC" ] || { echo "🟥 HARNESS-ERROR: target missing ($SC)" >&2; exit 9; }

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ✅ %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  ❌ %s\n' "$1"; }

T=$(mktemp -d "${TMPDIR:-/tmp}/psv-lane-XXXXXX")
trap 'rm -rf "$T"' EXIT INT TERM
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

# mk <dir>: main has a,b,c · branch `feat` changes a and b · returns via globals TIP
mk() {
  local d="$1"; git init -q -b main "$d"
  printf 'a1\n' > "$d/a"; printf 'b1\n' > "$d/b"; printf 'c1\nc2\nc3\n' > "$d/c"
  git -C "$d" add -A; git -C "$d" commit -qm init --no-verify
  git -C "$d" switch -qc feat
  printf 'a2\n' > "$d/a"; printf 'b2\n' > "$d/b"
  git -C "$d" commit -qam feat --no-verify
  TIP=$(git -C "$d" rev-parse HEAD)
  git -C "$d" switch -q main
}
# squash <dir> [drop-path] : squash-merge feat into main, optionally reverting one path before commit
squash() {
  local d="$1" drop="${2:-}"
  git -C "$d" merge --squash -q feat >/dev/null 2>&1
  [ -n "$drop" ] && git -C "$d" checkout -q HEAD -- "$drop"
  git -C "$d" commit -qm squash --no-verify
}
run() { OUT=$(bash "$SC" --repo "$1" --tip "$2" "${@:3}" 2>&1); RC=$?; }

printf '── post_squash_verify ──\n'
GOOD='grep -q a2 a && grep -q b2 b && echo instrument-ok'

# ⓐ clean squash → rc=0
mk "$T/ok"; squash "$T/ok"; TIP_OK="$TIP"
# 🟥 every later "$T/ok" run uses TIP_OK, never the global: mk() for another repo overwrites TIP, and
#    the stale value only "worked" when both repos committed in the same second (identical hashes).
#    Found 2026-09-24 as a 1-in-2 flake: ② failing-lane got rc=4 «--tip not a commit».
run "$T/ok" "$TIP_OK" --rerun "$GOOD"
[ "$RC" -eq 0 ] && ok "ⓐ clean squash + live ② → rc=0" || { bad "ⓐ clean squash rc=$RC"; printf '%s\n' "$OUT" | tail -5; }

# ⓑ squash that silently dropped b → rc=1 with DIFFERS b (② checks only a, so ① alone must catch it)
mk "$T/drop"; squash "$T/drop" b
run "$T/drop" "$TIP" --rerun 'grep -q a2 a && echo a-ok'
{ [ "$RC" -eq 1 ] && printf '%s' "$OUT" | grep -q 'DIFFERS    b'; } \
  && ok "ⓑ dropped file → rc=1 · DIFFERS b (① catches what a narrow ② misses)" \
  || { bad "ⓑ dropped file rc=$RC"; printf '%s\n' "$OUT" | tail -6; }

# ⓒ no --rerun → rc=2, and it must refuse BEFORE doing anything
run "$T/ok" "$TIP_OK"
[ "$RC" -eq 2 ] && ok "ⓒ no --rerun → rc=2 (① alone cannot go green)" || bad "ⓒ no --rerun rc=$RC"

# trivial ② refused — each spelling
_tf=0
for triv in ':' 'true' ' true ; ' 'exit 0' '' '/usr/bin/true'; do
  run "$T/ok" "$TIP_OK" --rerun "$triv"
  [ "$RC" -eq 3 ] || { bad "trivial ② '$triv' → rc=$RC (want 3)"; _tf=1; }
done
[ "$_tf" -eq 0 ] && ok "trivial ② (: · true · ' true ; ' · exit 0 · '' · /usr/bin/true) → rc=3 each"

# failing ② on a byte-correct merge → rc=1
run "$T/ok" "$TIP_OK" --rerun 'grep -q NOPE a'
[ "$RC" -eq 1 ] && ok "failing ② on a byte-correct squash → rc=1" || { bad "failing ② rc=$RC"; printf '%s\n' "$OUT" | tail -4; }

# silent ② (rc=0, no output) → rc=4, never a pass
run "$T/ok" "$TIP_OK" --rerun 'grep -q a2 a'
[ "$RC" -eq 4 ] && ok "silent ② (rc=0, empty output) → rc=4" || { bad "silent ② rc=$RC"; printf '%s\n' "$OUT" | tail -4; }

# COMBINED: main also changed a (different line region) after the branch was cut → not DIFFERS
mk "$T/comb"; printf 'c1\nc2\nc3\nc4\n' > "$T/comb/c"; git -C "$T/comb" commit -qam main-c --no-verify
git -C "$T/comb" switch -q feat; printf 'c0\nc1\nc2\nc3\n' > "$T/comb/c"; git -C "$T/comb" commit -qam feat-c --no-verify
TIP=$(git -C "$T/comb" rev-parse HEAD); git -C "$T/comb" switch -q main; squash "$T/comb"
run "$T/comb" "$TIP" --rerun 'grep -q c0 c && grep -q c4 c && echo merged-ok'
{ [ "$RC" -eq 0 ] && printf '%s' "$OUT" | grep -q 'COMBINED   c'; } \
  && ok "path changed on both sides → COMBINED (not DIFFERS), rc=0 when ② passes" \
  || { bad "COMBINED rc=$RC"; printf '%s\n' "$OUT" | tail -6; }

# EXTRA: squash commit carries a path the branch never touched → rc=1
mk "$T/ext"; git -C "$T/ext" merge --squash -q feat >/dev/null 2>&1
printf 'x\n' > "$T/ext/extra"; git -C "$T/ext" add extra; git -C "$T/ext" commit -qm squash --no-verify
run "$T/ext" "$TIP" --rerun "$GOOD"
{ [ "$RC" -eq 1 ] && printf '%s' "$OUT" | grep -q 'EXTRA      extra'; } \
  && ok "path in squash but not on branch → EXTRA · rc=1" || { bad "EXTRA rc=$RC"; printf '%s\n' "$OUT" | tail -4; }

# caller's HEAD and worktree list are untouched (② runs in a throwaway worktree)
H0=$(git -C "$T/ok" rev-parse HEAD); B0=$(git -C "$T/ok" branch --show-current)
run "$T/ok" "$TIP_OK" --rerun "$GOOD"
WTN=$(git -C "$T/ok" worktree list | wc -l | tr -d ' ')
{ [ "$(git -C "$T/ok" rev-parse HEAD)" = "$H0" ] && [ "$(git -C "$T/ok" branch --show-current)" = "$B0" ] && [ "$WTN" = "1" ]; } \
  && ok "caller HEAD/branch unchanged · throwaway worktree removed" || bad "side effect: HEAD/branch moved or worktrees=$WTN"

# ── cross-family R1 (codex/gpt-5.5, 2026-09-24) — each lane below was RED before its fix ──
# X1 newline in a path: --name-only C-quotes it, the quoted string is looked up literally, both
#    sides read ABSENT and the path renders SAME. Squash drops the file → must be DIFFERS, rc=1.
mk "$T/nl"; git -C "$T/nl" switch -q feat; printf 'n\n' > "$T/nl/$(printf 'x\ny')"
git -C "$T/nl" add -A; git -C "$T/nl" commit -qm nl --no-verify; TIP_NL=$(git -C "$T/nl" rev-parse HEAD)
git -C "$T/nl" switch -q main; squash "$T/nl" "$(printf 'x\ny')" 2>/dev/null
git -C "$T/nl" rm -q --cached "$(printf 'x\ny')" 2>/dev/null; git -C "$T/nl" commit -q --amend --no-edit --no-verify 2>/dev/null
run "$T/nl" "$TIP_NL" --rerun 'echo hi && grep -q a2 a'
[ "$RC" -eq 1 ] && ok "X1 newline path dropped by squash → rc=1 (not SAME)" || { bad "X1 newline path rc=$RC"; printf '%s\n' "$OUT" | tail -5; }

# X2 --tip == --merge compares the commit to itself → rc=4, never a pass
M_OK=$(git -C "$T/ok" rev-parse HEAD)
run "$T/ok" "$M_OK" --rerun "$GOOD"
[ "$RC" -eq 4 ] && ok "X2 --tip == --merge → rc=4" || bad "X2 --tip == --merge rc=$RC"

# X3 echo/printf-only ② exercises nothing → rc=3 (the exact-string list missed these)
_tf=0
for triv in 'printf ok' 'echo ok; :' 'echo a && echo b' 'true; printf x'; do
  run "$T/ok" "$TIP_OK" --rerun "$triv"
  [ "$RC" -eq 3 ] || { bad "X3 echo-only ② '$triv' → rc=$RC (want 3)"; _tf=1; }
done
[ "$_tf" -eq 0 ] && ok "X3 echo/printf/:/true-only ② → rc=3"
# X3 control: a real command that ALSO echoes must still run (over-block guard)
run "$T/ok" "$TIP_OK" --rerun 'grep -q a2 a; echo checked'
[ "$RC" -eq 0 ] && ok "X3-ctrl grep + echo is not refused" || bad "X3-ctrl real command refused rc=$RC"

# X4 a true merge commit (2 parents) is not a squash → rc=4
mk "$T/mm"; git -C "$T/mm" merge -q --no-ff --no-edit feat >/dev/null 2>&1
run "$T/mm" "$TIP" --merge HEAD --rerun "$GOOD"
[ "$RC" -eq 4 ] && ok "X4 two-parent merge commit → rc=4" || bad "X4 multi-parent rc=$RC"

# ── cross-family R2 ──
# X5 a real \001 byte in a path collided with the R1 sentinel → dropped file rendered SAME
mk "$T/c1"; git -C "$T/c1" switch -q feat; printf 'q\n' > "$T/c1/$(printf 'x\001y')"
git -C "$T/c1" add -A; git -C "$T/c1" commit -qm c1 --no-verify; TIP_C1=$(git -C "$T/c1" rev-parse HEAD)
git -C "$T/c1" switch -q main; git -C "$T/c1" merge --squash -q feat >/dev/null 2>&1
git -C "$T/c1" rm -q --cached "$(printf 'x\001y')" >/dev/null 2>&1; git -C "$T/c1" commit -qm s --no-verify
run "$T/c1" "$TIP_C1" --rerun 'echo hi && grep -q a2 a'
[ "$RC" -eq 1 ] && ok "X5 \\001 byte in a dropped path → rc=1 (no sentinel collision)" || { bad "X5 \\001 path rc=$RC"; printf '%s\n' "$OUT" | tail -4; }
# X6 echo first, real check after `&&` → must NOT be refused (splitter over-block guard)
run "$T/ok" "$TIP_OK" --rerun 'echo checked && grep -q a2 a'
[ "$RC" -eq 0 ] && ok "X6 'echo … && grep …' runs (split on && works)" || bad "X6 echo-then-real refused rc=$RC"
# X7 a path with a space survives the array path end to end
mk "$T/sp"; git -C "$T/sp" switch -q feat; printf 's\n' > "$T/sp/has space"; git -C "$T/sp" add -A
git -C "$T/sp" commit -qm sp --no-verify; TIP_SP=$(git -C "$T/sp" rev-parse HEAD); git -C "$T/sp" switch -q main; squash "$T/sp"
run "$T/sp" "$TIP_SP" --rerun 'test -f "has space" && echo ok'
[ "$RC" -eq 0 ] && ok "X7 path with a space → SAME · rc=0" || { bad "X7 space path rc=$RC"; printf '%s\n' "$OUT" | tail -4; }

# ── cross-family R3 ──
# X8 an option with no operand must be a usage error, not an endless `shift 2` loop
_xf=0
for opt in --tip --merge --repo --rerun; do
  OUT=$(timeout 10 bash "$SC" --repo "$T/ok" $opt 2>&1); RC=$?
  [ "$RC" -eq 2 ] || { bad "X8 '$opt' with no operand → rc=$RC (want 2; 124 = hung)"; _xf=1; }
done
[ "$_xf" -eq 0 ] && ok "X8 option with no operand → rc=2 (checked: --tip --merge --repo --rerun)"
# X9 a failing `git diff` for the squash list must be rc=4, not an empty list that skips EXTRA
FB="$T/fakebin"; mkdir -p "$FB"; RG=$(command -v git)
printf '#!/bin/sh\ncase " $* " in *" diff "*"%s"*) exit 128 ;; esac\nexec "%s" "$@"\n' "$(git -C "$T/ext" rev-parse HEAD)" "$RG" > "$FB/git"; chmod +x "$FB/git"
OUT=$(PATH="$FB:$PATH" bash "$SC" --repo "$T/ext" --tip "$(git -C "$T/ext" rev-parse feat)" --rerun "$GOOD" 2>&1); RC=$?
# 🟥 rc=4 alone is not enough — «branch changed no paths» is also rc=4. Require the diff-failure message.
{ [ "$RC" -eq 4 ] && printf '%s' "$OUT" | grep -q 'git diff failed'; } && ok "X9 git diff fails on the squash list → rc=4 (named)" || { bad "X9 swallowed git diff failure rc=$RC"; printf '%s\n' "$OUT" | tail -3; }

# ── cross-family R4 ──
# X10 a mode-only change (chmod +x) dropped by the squash → same blob, different entry → rc=1.
#     This is the exec-bit class that silently disarms git hooks ([[feedback_exec_bit_loss_disarms_hooks_silently]]).
mk "$T/md"; git -C "$T/md" switch -q feat; chmod +x "$T/md/a"; git -C "$T/md" add a
git -C "$T/md" commit -qm mode --no-verify; TIP_MD=$(git -C "$T/md" rev-parse HEAD); git -C "$T/md" switch -q main
git -C "$T/md" merge --squash -q feat >/dev/null 2>&1; chmod -x "$T/md/a"; git -C "$T/md" add a; git -C "$T/md" commit -qm s --no-verify
run "$T/md" "$TIP_MD" --rerun 'grep -q a2 a && echo ok'
{ [ "$RC" -eq 1 ] && printf '%s' "$OUT" | grep -q 'DIFFERS'; } && ok "X10 dropped mode change → DIFFERS · rc=1" || { bad "X10 mode-only drop rc=$RC"; printf '%s\n' "$OUT" | tail -4; }

# X11 --precheck validates --rerun with no git state: trivial → 3 · real → 0 · missing → 2 (no --tip needed)
_p1=$(bash "$SC" --precheck --rerun 'true' >/dev/null 2>&1; echo $?)
_p2=$(bash "$SC" --precheck --rerun 'grep -q x y; echo z' >/dev/null 2>&1; echo $?)
_p3=$(bash "$SC" --precheck >/dev/null 2>&1; echo $?)
[ "$_p1$_p2$_p3" = "302" ] && ok "X11 --precheck: trivial=3 · real=0 · missing=2" || bad "X11 --precheck got $_p1/$_p2/$_p3 (want 3/0/2)"

printf 'PASS %d · FAIL %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]

#!/usr/bin/env bash
# test_prepush_marker_lookup_lanes.sh — the pre-push Load-Bearing gate must find THIS branch's marker where the
# pre-commit hook writes it (the main checkout's tracks/_meta, i.e. EVIDENCE_ROOT), and nothing else.
#
# Why (2026-11-15, found pushing FH #1118 from a worktree): the gate read `$REPO_ROOT/tracks/_meta` — the worktree's
# own folder — and took the newest marker of ANY branch. Two wrong answers followed from one line:
#   W1  a worktree push was BLOCKED although its branch's marker existed in the main checkout;
#   M1  a main-checkout push PASSED on another branch's marker.
# Lanes (each in a throwaway clone of this checkout with a bare origin; nothing here touches the real repo):
#   W1  worktree, marker for the pushed branch in the main checkout only            → push passes
#   M1  main checkout, only a FOREIGN branch's marker (newer)                       → push blocked
#   M2  control: main checkout, the pushed branch's own marker                      → push passes
#   M3  control: main checkout, no marker at all                                    → push blocked
#   M4  only a longer branch's marker (lane/m4_extra for lane/m4 — glob prefix)         → push blocked
#   M5  two local branches share one marker name (lane/m5 · lane_m5)                    → push blocked
#   M6  same as M5 plus a tag of that name (the short refname would hide the collision)   → push blocked
#   M7  <sha>:refs/heads/lane/m7 while standing on a branch that has a marker            → push blocked
#   M8  <sha>:refs/heads/lane/m8, no local lane/m8, a local lane_m8 with a marker          → push blocked
#   W1/M2 «gate-pass» = rc 0 AND the gate printed its ✅ line (proves the hook ran, not just that the push worked)
#   N1  control: a push that carries no load-bearing file, no marker                → push passes (gate not involved)
#   N2  an outside contributor's clone (no tracks/_meta), load-bearing file, no marker → push passes (FH-dev scope)
#   M9  the pushed branch's own marker, dated 10 days ago   → push passes AND the gate names that file as not today's
#   M10 control: the same, dated today                      → push passes AND the gate names that file, not as stale
# Exit 0 all lanes pass · 1 a lane failed · 2 harness error.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/fixture_guard_lib.sh"   # scrub inherited GIT_* env first (#1088)
SRC=$(cd "$(dirname "$0")/.." 2>/dev/null && pwd) || { echo "HARNESS-ERROR: cannot resolve the repo root"; exit 2; }
[ -f "$SRC/templates/.git-hooks/pre-push" ] || { echo "HARNESS-ERROR: no pre-push hook in $SRC"; exit 2; }
W=$(mktemp -d "${TMPDIR:-/tmp}/prepush-marker.XXXX") || { echo "HARNESS-ERROR: mktemp"; exit 2; }
trap 'rm -rf "$W"' EXIT
unset PUBLIC_SURFACE_OK DESTRUCTIVE_OP_OK MAIN_PUSH_OK PUSH_ZONE_OK TAG_VERSION_OK FH_SESSION_CLOSE 2>/dev/null || true
G() { git -c user.name=lane -c user.email=lane@localhost -c commit.gpgsign=false "$@"; }
TODAY=$(date +%Y-%m-%d)
pass=0; fail=0

# one fixture = a clone of this checkout (committed HEAD + this working tree's hook, so the hook under test is the
# one on disk), a bare origin, hooks wired by absolute path like the operator's setup.
fixture() {   # $1 = dir
  local d="$1"
  G clone -q --no-hardlinks "$SRC" "$d/main" < /dev/null || return 1
  cp "$SRC/templates/.git-hooks/pre-push" "$d/main/templates/.git-hooks/pre-push" || return 1
  G init -q --bare "$d/origin.git" < /dev/null || return 1
  # 🟥 receive.shallowUpdate — without it this whole suite dies at its FIRST fixture on a shallow
  # checkout, and no lane runs. Measured 2026-11-23 in a clean-room container whose clone is shallow
  # (`git rev-parse --is-shallow-repository` = true, 281 commits): the push below is refused with
  # «! [remote rejected] HEAD -> main (shallow update not allowed)», the suite exits 2 at
  # «HARNESS-ERROR: fixture W1», and 0 of its lanes reach a verdict. Known pair, one variable, same
  # tree: without this line the push is rejected; with it, «* [new branch] HEAD -> main». CI is not
  # affected (validate.yml checks out with fetch-depth: 0), which is why the hole stayed invisible —
  # it only opens where the checkout is shallow, i.e. for a contributor who cloned with --depth.
  # It loosens nothing about the gate under test: it only lets a shallow history reach the throwaway
  # bare repo this fixture pushes to.
  git -C "$d/origin.git" config receive.shallowUpdate true || return 1
  G -C "$d/main" remote set-url origin "$d/origin.git" || return 1
  G -C "$d/main" push -q --no-verify origin HEAD:refs/heads/main < /dev/null || return 1
  G -C "$d/main" fetch -q origin < /dev/null || return 1
  G -C "$d/main" config core.hooksPath "$d/main/templates/.git-hooks" || return 1   # checked (codex R2)
  mkdir -p "$d/main/tracks/_meta" || return 1
}
lb_commit() {   # $1 = repo dir · $2 = branch — a commit touching a load-bearing path
  G -C "$1" switch -q -c "$2" origin/main < /dev/null || return 1
  lb_change "$1" "$2"
}
lb_change() {   # $1 = repo dir · $2 = label — the change itself, every step checked (codex R1: an unchecked failure
  # left the branch at origin/main, so the push carried nothing load-bearing and «passed» without exercising the gate)
  printf '\n# lane %s\n' "$2" >> "$1/scripts/predelete_check.sh" || return 1
  G -C "$1" add scripts/predelete_check.sh || return 1
  G -C "$1" commit -q --no-verify -m "lane $2" < /dev/null || return 1
  [ -n "$(G -C "$1" log --format=%h origin/main..HEAD -- scripts/predelete_check.sh)" ] || return 1
}
plain_commit() {   # $1 = repo dir · $2 = branch — a commit touching no load-bearing path
  G -C "$1" switch -q -c "$2" origin/main < /dev/null || return 1
  printf 'lane\n' > "$1/lane_note_${2//\//_}.txt"; G -C "$1" add "lane_note_${2//\//_}.txt"
  G -C "$1" commit -q --no-verify -m "lane $2" < /dev/null
}
marker() {   # $1 = evidence dir · $2 = branch · $3 = date in the NAME (default: today)
  # MARKER_BN carries the basename back (a global, not stdout: printing it would add a line to every
  # existing call site's output, and M9/M10 need the exact name the gate must echo back).
  MARKER_BN=".axes_23_passed_${2//\//_}_${3:-$TODAY}.marker"
  printf 'crossfamily: panel(codex) — residency=CLEAN(files=1) · evidence=SHARED(lane) · R1 no S/A\n' \
    > "$1/tracks/_meta/$MARKER_BN"
}
push() {   # $1 = repo dir · $2 = branch → prints rc
  G -C "$1" push origin "$2" > "$W/last_push.log" 2>&1 < /dev/null; echo $?
}
lane() {   # $1 id · $2 want (pass | gate-pass = pass AND the gate printed its ✅ line | block) · $3 rc
  if { [ "$2" = pass ] && [ "$3" -eq 0 ]; } \
     || { [ "$2" = gate-pass ] && [ "$3" -eq 0 ] && grep -q '✅ FH Load-Bearing Change Gate' "$W/last_push.log"; } \
     || { [ "$2" = block ] && [ "$3" -ne 0 ] && grep -q 'no cross-family leg recorded' "$W/last_push.log"; }; then
    pass=$((pass+1)); echo "  ✅ $1 (want $2, rc=$3)"
  else
    fail=$((fail+1)); echo "  ❌ $1 — want $2, got rc=$3"; awk '/⛔|❌|error/ && n < 4 { n++; print "       " $0 }' "$W/last_push.log"
  fi
}
echo "pre-push marker lookup lanes"

# W1 — worktree push, marker only in the main checkout
D="$W/w1"; mkdir -p "$D"; fixture "$D" || { echo "HARNESS-ERROR: fixture W1"; exit 2; }
G -C "$D/main" worktree add -q "$D/wt" -b lane/w1 origin/main < /dev/null || { echo "HARNESS-ERROR: worktree"; exit 2; }
mkdir -p "$D/wt/tracks/_meta"   # the real worktrees have this folder too (it is gitignored, created by tools)
lb_change "$D/wt" w1 || { echo "HARNESS-ERROR: commit W1"; exit 2; }
marker "$D/main" lane/w1
lane W1 gate-pass "$(push "$D/wt" lane/w1)"

# M1 — main checkout, only a foreign (newer) marker
D="$W/m1"; mkdir -p "$D"; fixture "$D" || { echo "HARNESS-ERROR: fixture M1"; exit 2; }
lb_commit "$D/main" lane/m1 || { echo "HARNESS-ERROR: commit M1"; exit 2; }
marker "$D/main" lane/someone-else
lane M1 block "$(push "$D/main" lane/m1)"

# M2 — main checkout, own marker
marker "$D/main" lane/m1
lane M2 gate-pass "$(push "$D/main" lane/m1)"

# M4 — prefix collision: only a LONGER branch's marker (lane/m1 already pushed; lane_m4_extra is not lane/m4's)
G -C "$D/main" switch -q -c lane/m4 origin/main < /dev/null && lb_change "$D/main" m4 || { echo "HARNESS-ERROR: commit M4"; exit 2; }
marker "$D/main" lane/m4_extra
lane M4 block "$(push "$D/main" lane/m4)"

# M5 — slug collision: lane/m5 and lane_m5 both exist locally; the one marker cannot be attributed to either
G -C "$D/main" branch -q lane_m5 origin/main < /dev/null || { echo "HARNESS-ERROR: branch M5"; exit 2; }
G -C "$D/main" switch -q -c lane/m5 origin/main < /dev/null && lb_change "$D/main" m5 || { echo "HARNESS-ERROR: commit M5"; exit 2; }
marker "$D/main" lane/m5
lane M5 block "$(push "$D/main" lane/m5)"

# M6 — tag ambiguity: lane/m6 and lane_m6 both exist AND a tag lane_m6 (refname:short would print heads/lane_m6)
G -C "$D/main" branch -q lane_m6 origin/main < /dev/null && G -C "$D/main" tag lane_m6 origin/main < /dev/null || { echo "HARNESS-ERROR: refs M6"; exit 2; }
G -C "$D/main" switch -q -c lane/m6 origin/main < /dev/null && lb_change "$D/main" m6 || { echo "HARNESS-ERROR: commit M6"; exit 2; }
marker "$D/main" lane/m6
lane M6 block "$(push "$D/main" lane/m6)"

# M7 — commit-expression refspec: standing on lane/m1 (its marker exists), push an unreviewed load-bearing commit to a
#      NEW branch name with <sha>:refs/heads/lane/m7 — it must need lane/m7's marker, not borrow lane/m1's
G -C "$D/main" switch -q -c lane/m7-src origin/main < /dev/null && lb_change "$D/main" m7 || { echo "HARNESS-ERROR: commit M7"; exit 2; }
M7SHA=$(G -C "$D/main" rev-parse HEAD); G -C "$D/main" switch -q lane/m1 < /dev/null || { echo "HARNESS-ERROR: switch M7"; exit 2; }
G -C "$D/main" push origin "$M7SHA:refs/heads/lane/m7" > "$W/last_push.log" 2>&1 < /dev/null; lane M7 block "$?"

# M8 — <sha>:refs/heads/lane/m8 where lane/m8 does not exist locally but lane_m8 does, with a marker → blocked
G -C "$D/main" branch -q lane_m8 origin/main < /dev/null || { echo "HARNESS-ERROR: branch M8"; exit 2; }
marker "$D/main" lane_m8
G -C "$D/main" push origin "$M7SHA:refs/heads/lane/m8" > "$W/last_push.log" 2>&1 < /dev/null; lane M8 block "$?"

# M3 — main checkout, no marker
D="$W/m3"; mkdir -p "$D"; fixture "$D" || { echo "HARNESS-ERROR: fixture M3"; exit 2; }
lb_commit "$D/main" lane/m3 || { echo "HARNESS-ERROR: commit M3"; exit 2; }
lane M3 block "$(push "$D/main" lane/m3)"

# N1 — no load-bearing file, no marker
plain_commit "$D/main" lane/n1 || { echo "HARNESS-ERROR: commit N1"; exit 2; }
lane N1 pass "$(push "$D/main" lane/n1)"

# N2 — an outside contributor's clone (no tracks/_meta anywhere), load-bearing file, no marker → not blocked by this gate
D="$W/n2"; mkdir -p "$D"; fixture "$D" || { echo "HARNESS-ERROR: fixture N2"; exit 2; }
rm -rf "$D/main/tracks/_meta"
lb_commit "$D/main" lane/n2 || { echo "HARNESS-ERROR: commit N2"; exit 2; }
lane N2 pass "$(push "$D/main" lane/n2)"

# ── M9 · M10: WHICH marker answered, and was it today's ────────────────────────────────────────────
# Why (2026-11-23, clean-room audit round 10): the lanes above pin WHOSE marker the gate reads, and
# every one of them writes TODAY's date, so the date half of the address was never measured here.
# Measured with a known pair on one tree: a marker dated 2026-10-01 and one dated today produced the
# same «✅ FH Load-Bearing Change Gate: …» line, byte for byte. Accepting an older marker is the
# gate's choice (a commit made yesterday is pushed today); printing WHICH file answered is not.
# These two lanes pin the record line only — neither asserts a verdict change, and M9 still expects
# the push to pass.
lane_src() {   # $1 id · $2 want-rc · $3 rc · $4 basename that must appear · $5 stale|fresh
  local _ok=1 _line
  _line=$(grep -F 'evidence read from:' "$W/last_push.log" | head -1)
  [ "$3" = "$2" ] || { _ok=0; echo "  ❌ $1 — rc=$3 (want $2): the record line must not change the verdict"; }
  case "$_line" in *"$4"*) ;; *) _ok=0; echo "  ❌ $1 — the gate did not name the marker it read ($4): [${_line:-ABSENT}]";; esac
  if [ "$5" = stale ]; then
    case "$_line" in *"NOT today"*) ;; *) _ok=0; echo "  ❌ $1 — an older marker passed without being marked as not today's: [${_line:-ABSENT}]";; esac
  else
    case "$_line" in *"NOT today"*) _ok=0; echo "  ❌ $1 — today's marker was labelled as not today's: [$_line]";; *) ;; esac
  fi
  if [ "$_ok" = 1 ]; then pass=$((pass+1)); echo "  ✅ $1 ($5 marker named in the record line, rc=$3)"; else fail=$((fail+1)); fi
}
D="$W/m9"; mkdir -p "$D"; fixture "$D" || { echo "HARNESS-ERROR: fixture M9"; exit 2; }
lb_commit "$D/main" lane/m9 || { echo "HARNESS-ERROR: commit M9"; exit 2; }
STALE_DATE=$(date -d '10 days ago' +%Y-%m-%d 2>/dev/null || date -v-10d +%Y-%m-%d 2>/dev/null || echo 2026-01-01)
[ "$STALE_DATE" = "$TODAY" ] && { echo "HARNESS-ERROR: could not build a date that is not today"; exit 2; }
marker "$D/main" lane/m9 "$STALE_DATE" || { echo "HARNESS-ERROR: marker M9"; exit 2; }
M9BN="$MARKER_BN"
lane_src M9 0 "$(push "$D/main" lane/m9)" "$M9BN" stale

# M10 — control: the same fixture, a marker dated today → named, and not labelled stale
lb_commit "$D/main" lane/m10 || { echo "HARNESS-ERROR: commit M10"; exit 2; }
marker "$D/main" lane/m10 || { echo "HARNESS-ERROR: marker M10"; exit 2; }
M10BN="$MARKER_BN"
lane_src M10 0 "$(push "$D/main" lane/m10)" "$M10BN" fresh

echo "pre-push marker lookup lanes: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

#!/usr/bin/env bash
# Lanes for scripts/below_floor_scan.sh — fixture repos only.
#
# Why (2026-11-20 weekly audit): run from a git worktree, the scan read the worktree's own
# tracks/_meta — gitignored, so empty — and printed «0 total, 0 pending» with rc 0. The main
# checkout held 4 markers. «Not read» rendered as «clean». With no root given, a worktree now reads
# the main checkout's tracks/_meta — the EVIDENCE_ROOT the pre-commit hook writes markers to — and
# says so; if the main checkout has no tracks/_meta it says NOT READ (rc unchanged).
#
# B1 worktree, no arg       → reads the main checkout: 1 pending, rc 1, names the source
# B2 main checkout, no arg  → unchanged: 1 pending, rc 1, no worktree note
# B3 explicit root arg      → that root only (the worktree path given → «no tracks/_meta», rc 0)
# B4 fresh repo, no tracks  → unchanged: «no tracks/_meta directory», rc 0 (CI / public clone)
# B5 worktree with an EMPTY tracks/_meta (session hooks create one) → still reads the main checkout
# B6 worktree with a marker file of its own → still the main checkout (the writer's place wins)
# B7 worktree whose main checkout has no tracks/_meta → NOT READ, rc 0 (a CI worktree stays green)
# B8 worktree, cwd in a subdirectory → still the main checkout (relative common dir resolved from cwd)
# B9 main checkout, cwd in a subdirectory → unchanged, no worktree note
set -u
. "$(dirname "${BASH_SOURCE[0]}")/fixture_guard_lib.sh"   # scrub inherited GIT_* env first (#1088)
FH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
S="$FH/scripts/below_floor_scan.sh"
T=$(mktemp -d "${TMPDIR:-/tmp}/bfs.XXXXXX")
trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok() { echo "PASS $1"; pass=$((pass + 1)); }
no() { echo "FAIL $1 — $2"; fail=$((fail + 1)); }

g() { git -c user.name=t -c user.email=t@t -c commit.gpgsign=false "$@"; }
mkdir -p "$T/main" && cd "$T/main" && g init -q && printf 'tracks/\n' > .gitignore && g add .gitignore && g commit -qm init || { echo "HARNESS-ERROR: fixture repo"; exit 2; }
mkdir -p tracks/_meta
cat > tracks/_meta/.axes_23_passed_x_2026-11-01.marker <<'EOF'
floor-status: below-floor
axis2-model: haiku
below-floor-ack: operator ok
EOF
g worktree add -q "$T/wt" -b wt-branch 2>/dev/null || { echo "HARNESS-ERROR: worktree add"; exit 2; }
[ -d "$T/wt/tracks" ] && { echo "HARNESS-ERROR: fixture worktree already has tracks/ (gitignore not applied)"; exit 2; }

out=$(cd "$T/wt" && bash "$S" 2>&1); rc=$?
MAINDIR=$(cd "$T/main" && pwd -P)/tracks/_meta
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q '1 total, 1 pending' && printf '%s' "$out" | grep -qF "scan: $MAINDIR ──" && printf '%s' "$out" | grep -q 'main checkout'; then ok B1-worktree-reads-main
else no B1-worktree-reads-main "rc=$rc · $(printf '%s' "$out" | tail -2 | tr '\n' ' ')"; fi

out=$(cd "$T/main" && bash "$S" 2>&1); rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q '1 total, 1 pending' && ! printf '%s' "$out" | grep -q 'main checkout'; then ok B2-main-unchanged
else no B2-main-unchanged "rc=$rc · $(printf '%s' "$out" | tail -2 | tr '\n' ' ')"; fi

out=$(cd "$T/wt" && bash "$S" "$T/wt" 2>&1); rc=$?
if [ "$rc" = 0 ] && printf '%s' "$out" | grep -q 'no tracks/_meta directory'; then ok B3-explicit-root-only
else no B3-explicit-root-only "rc=$rc · $(printf '%s' "$out" | tail -1)"; fi

mkdir -p "$T/fresh" && (cd "$T/fresh" && g init -q)
out=$(cd "$T/fresh" && bash "$S" 2>&1); rc=$?
if [ "$rc" = 0 ] && printf '%s' "$out" | grep -q 'no tracks/_meta directory'; then ok B4-fresh-clone-unchanged
else no B4-fresh-clone-unchanged "rc=$rc · $(printf '%s' "$out" | tail -1)"; fi

mkdir -p "$T/wt/tracks/_meta"
out=$(cd "$T/wt" && bash "$S" 2>&1); rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q '1 total, 1 pending' && printf '%s' "$out" | grep -q 'main checkout'; then ok B5-empty-dir-still-reads-main
else no B5-empty-dir-still-reads-main "rc=$rc · $(printf '%s' "$out" | tail -2 | tr '\n' ' ')"; fi

printf 'floor-status: above-floor\n' > "$T/wt/tracks/_meta/.axes_23_passed_wt_2026-11-02.marker"
out=$(cd "$T/wt" && bash "$S" 2>&1); rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -qF "scan: $MAINDIR ──"; then ok B6-own-marker-still-reads-main
else no B6-own-marker-still-reads-main "rc=$rc · $(printf '%s' "$out" | head -2 | tr '\n' ' ')"; fi

mkdir -p "$T/wt/sub/deeper"
out=$(cd "$T/wt/sub/deeper" && bash "$S" 2>&1); rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -qF "scan: $MAINDIR ──"; then ok B8-subdir-cwd-reads-main
else no B8-subdir-cwd-reads-main "rc=$rc · $(printf '%s' "$out" | head -2 | tr '\n' ' ')"; fi

mkdir -p "$T/main/sub"
out=$(cd "$T/main/sub" && bash "$S" 2>&1); rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -qF "scan: $MAINDIR ──" && ! printf '%s' "$out" | grep -q 'git worktree'; then ok B9-main-subdir-unchanged
else no B9-main-subdir-unchanged "rc=$rc · $(printf '%s' "$out" | head -2 | tr '\n' ' ')"; fi

mkdir -p "$T/main2" && (cd "$T/main2" && g init -q && printf 'tracks/\n' > .gitignore && g add .gitignore && g commit -qm init && g worktree add -q "$T/wt2" -b wt2 2>/dev/null)
mkdir -p "$T/wt2/tracks/_meta"
out=$(cd "$T/wt2" && bash "$S" 2>&1); rc=$?
if [ "$rc" = 0 ] && printf '%s' "$out" | grep -q 'NOT READ'; then ok B7-no-main-record-says-not-read
else no B7-no-main-record-says-not-read "rc=$rc · $(printf '%s' "$out" | head -3 | tr '\n' ' ')"; fi

echo "below_floor_scan lanes: $pass passed · $fail failed"
[ "$fail" -eq 0 ]

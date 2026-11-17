#!/usr/bin/env bash
# test_fixture_git_env_lanes.sh — a fixture commit must never land in the repo named by an inherited
# GIT_DIR / GIT_INDEX_FILE / GIT_COMMON_DIR. SUBJECT: scripts/fixture_guard_lib.sh (+ the selfcheck.sh
# scrub line and scripts/lane_identity_tripwire.sh).
#
# Every case uses a DECOY «victim» repo under a temp dir — never a real repo. The victim gets a
# base commit and three staged files; its fingerprint (refs · local config · index · object count ·
# authors) must be identical before and after.
#
# Revert probe: delete the `for _fg_v in $FH_FIXTURE_GIT_ENV; do unset …` line in the lib → L1-L3 go red.
. "$(dirname "${BASH_SOURCE[0]}")/fixture_guard_lib.sh"   # scrub inherited GIT_* env first (#1088)
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/.."
LIB="$PWD/scripts/fixture_guard_lib.sh"; TRIP="$PWD/scripts/lane_identity_tripwire.sh"
pass=0; fail=0
chk() { if [ "$1" -eq 0 ]; then pass=$((pass+1)); echo "  PASS  $2"; else fail=$((fail+1)); echo "  FAIL  $2"; fi; }
for f in "$LIB" "$TRIP"; do [ -f "$f" ] || { echo "HARNESS-ERROR missing $f"; exit 2; }; done

T="$(mktemp -d "${TMPDIR:-/tmp}/fgenv.XXXXXX")"; trap 'rm -rf "$T"' EXIT
clean() { env -u GIT_DIR -u GIT_INDEX_FILE -u GIT_WORK_TREE -u GIT_COMMON_DIR -u GIT_OBJECT_DIRECTORY "$@"; }
mkvictim() { rm -rf "$1"; mkdir -p "$1"; ( cd "$1" && clean git init -q && clean git -c user.name=v -c user.email=v@v commit -q --allow-empty -m root \
  && for i in 1 2 3; do echo "s$i" > "s$i.txt"; done && clean git add s1.txt s2.txt s3.txt ); }
snap() { ( cd "$1" && clean bash -c 'git for-each-ref --format="%(refname) %(objectname)"; git config --local --list | sort; git ls-files -s; git count-objects -v | grep -E "^(count|in-pack)"; git log --all --format="%ae %s"' ); }

# a lane-shaped body: source the lib, make a fixture, init + commit as the lane identity
LANE='. "$LIB"; d="$(fh_fixture_root "$(mktemp -d "$T/fx.XXXXXX")")" || exit 3
git -C "$d" init -q && echo a > "$d/a" && git -C "$d" add a && git -C "$d" -c core.hooksPath=/nonexistent -c user.name=lane -c user.email=lane@example.invalid commit -q --no-verify -m base || exit 4
git -C "$d" log --format=%s | grep -qx base || exit 5'

# ── C0 control: no inherited env → lane commits in its fixture, victim untouched ──
V="$T/v0"; mkvictim "$V"; b="$(snap "$V")"
clean env LIB="$LIB" T="$T" bash -c "$LANE"; rc=$?
[ "$rc" -eq 0 ] && [ "$b" = "$(snap "$V")" ]; chk $? "C0 control: no env → fixture commit ok (rc=$rc), victim unchanged"

# ── C0b control: the leak is real — without the lib, exported GIT_DIR lands the commit in the victim ──
V="$T/vc"; mkvictim "$V"; b="$(snap "$V")"
d="$(mktemp -d "$T/raw.XXXXXX")"
GIT_DIR="$V/.git" bash -c 'git -C "$1" init -q; git -C "$1" -c user.name=lane -c user.email=lane@example.invalid commit -q --allow-empty -m base' _ "$d" >/dev/null 2>&1
[ "$b" != "$(snap "$V")" ]; chk $? "C0b control: unguarded git -C under GIT_DIR DOES write the victim (leak reproduced)"

# ── L1-L3: inherited env, guarded lane → victim untouched ──
for spec in "GIT_DIR=.git" "GIT_INDEX_FILE=.git/index" "GIT_COMMON_DIR=.git"; do
  var="${spec%%=*}"; V="$T/v_$var"; mkvictim "$V"; b="$(snap "$V")"
  env "$var=$V/${spec#*=}" LIB="$LIB" T="$T" bash -c "$LANE" >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 0 ] && [ "$b" = "$(snap "$V")" ]; chk $? "L $var exported at victim → lane rc=$rc, victim unchanged"
done
V="$T/v_dw"; mkvictim "$V"; b="$(snap "$V")"
GIT_DIR="$V/.git" GIT_WORK_TREE="$V" LIB="$LIB" T="$T" bash -c "$LANE" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && [ "$b" = "$(snap "$V")" ]; chk $? "L GIT_DIR+GIT_WORK_TREE → lane rc=$rc, victim unchanged"

# ── L4: env re-exported AFTER sourcing → fh_fixture_root refuses (fail-closed, HARNESS-ERROR) ──
V="$T/v4"; mkvictim "$V"; b="$(snap "$V")"
out="$(LIB="$LIB" T="$T" V="$V" bash -c '. "$LIB"; export GIT_DIR="$V/.git"; fh_fixture_root "$(mktemp -d "$T/fx.XXXXXX")"' 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'HARNESS-ERROR inherited GIT_DIR' && [ "$b" = "$(snap "$V")" ]; chk $? "L4 GIT_DIR re-exported after source → refused (rc=$rc)"

# ── L5: fixture root inside a repo's work tree → git resolves it outside → refused ──
V="$T/v5"; mkvictim "$V"; mkdir -p "$V/sub"
out="$(LIB="$LIB" V="$V" bash -c '. "$LIB"; fh_fixture_root "$V/sub"' 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'outside the fixture'; chk $? "L5 root inside another repo's work tree → refused (rc=$rc)"

# ── L6: fh_fixture_git_check — own repo passes, foreign git dir refuses ──
d="$(mktemp -d "$T/gc.XXXXXX")"; clean git -C "$d" init -q
LIB="$LIB" bash -c '. "$LIB"; fh_fixture_git_check "$1"' _ "$d" >/dev/null 2>&1; chk $? "L6a git_check on the fixture's own repo → ok"
d2="$(mktemp -d "$T/gc2.XXXXXX")"
LIB="$LIB" V="$T/v5" bash -c '. "$LIB"; mkdir -p "$V/x"; fh_fixture_git_check "$V/x"' >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ]; chk $? "L6b git_check on a dir that git resolves to another repo → refused (rc=$rc)"

# ── L7: selfcheck.sh scrubs the same list before any lane runs ──
line="$(grep -m1 '^unset GIT_ALTERNATE_OBJECT_DIRECTORIES' scripts/selfcheck.sh)"; miss=0
list="$(LIB="$LIB" bash -c '. "$LIB"; echo $FH_FIXTURE_GIT_ENV')"
for v in $list; do case " $line " in *" $v "*) ;; *) miss=$((miss+1)); echo "    missing in selfcheck: $v" ;; esac; done
[ -n "$line" ] && [ "$miss" -eq 0 ] && [ "$(grep -n '^unset GIT_ALTERNATE' scripts/selfcheck.sh | cut -d: -f1)" -lt "$(grep -n '^cd "\$(dirname' scripts/selfcheck.sh | head -1 | cut -d: -f1)" ]
chk $? "L7 selfcheck.sh unsets all $(echo $list | wc -w | tr -d ' ') vars before cd/lanes"

# ── L8: tripwire known pair + harness error ──
V="$T/v8"; mkvictim "$V"; out="$(bash "$TRIP" "$V")"; rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '^LANE-TRIPWIRE ok: 0'; chk $? "L8a tripwire clean repo → ok, rc=0"
( cd "$V" && clean git -c user.name=lane -c user.email=lane@example.invalid commit -q --allow-empty -m base )
out="$(bash "$TRIP" "$V")"; rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'WARN: 1 commit'; chk $? "L8b tripwire lane commit → WARN, record-only rc=0"
bash "$TRIP" "$V" --strict >/dev/null; rc=$?; [ "$rc" -eq 1 ]; chk $? "L8c tripwire --strict → rc=1 (got $rc)"
( cd "$V" && clean git -c user.name=v -c user.email=v@v commit -q --allow-empty -m tip && clean git rev-parse HEAD > "$T/shallow" )
out="$(GIT_SHALLOW_FILE="$T/shallow" bash "$TRIP" "$V")"; rc=$?
printf '%s' "$out" | grep -q 'WARN: 1 commit'; chk $? "L8e inherited GIT_SHALLOW_FILE cutting history at the tip → lane commit still found (codex R1)"
bash "$TRIP" "$T/nope" >/dev/null; rc=$?; [ "$rc" -eq 2 ]; chk $? "L8d tripwire on non-repo → HARNESS-ERROR rc=2, not «ok» (got $rc)"

# ── L9: the session-start caller (fh_session_load.sh) — non-git FH silent, clean git silent, lane commit warns ──
# BE must be a git repo or the loader exits before its banner; no remote, so the fetch fails fast offline.
LOAD="$PWD/scripts/fh_session_load.sh"; BE9="$T/be9"; mkdir -p "$BE9" "$T/h9"; ( cd "$BE9" && clean git init -q && touch INDEX.md )
mkfh() { rm -rf "$1"; mkdir -p "$1/scripts"; cp "$TRIP" "$1/scripts/"; }
sl() { env -u GIT_DIR -u GIT_INDEX_FILE HOME="$T/h9" CLAUDE_PROJECT_DIR="$1" BE_DIR="$BE9" bash "$LOAD" </dev/null 2>&1 | grep 'LANE-TRIPWIRE'; }
mkfh "$T/fh_nongit"; out="$(sl "$T/fh_nongit")"
[ -z "$out" ]; chk $? "L9a session start, FH not a git repo (npm install) → no tripwire line (got: ${out:-none})"
mkfh "$T/fh_git"; ( cd "$T/fh_git" && clean git init -q && clean git -c user.name=v -c user.email=v@v commit -q --allow-empty -m root )
out="$(sl "$T/fh_git")"; [ -z "$out" ]; chk $? "L9b session start, clean git FH → no tripwire line"
( cd "$T/fh_git" && clean git -c user.name=lane -c user.email=lane@example.invalid commit -q --allow-empty -m base )
out="$(sl "$T/fh_git")"; printf '%s' "$out" | grep -q 'WARN: 1 commit'; chk $? "L9c session start, lane commit in FH → WARN line (control: the caller does run the tripwire)"
out="$(GIT_DIR="$T/missing" GIT_COMMON_DIR="$T/missing" HOME="$T/h9" CLAUDE_PROJECT_DIR="$T/fh_git" BE_DIR="$BE9" bash "$LOAD" </dev/null 2>&1 | grep 'LANE-TRIPWIRE')"
printf '%s' "$out" | grep -q 'WARN: 1 commit'; chk $? "L9d session start with an inherited bogus GIT_DIR → the git-repo probe is not fooled, WARN still prints (codex R1)"

echo "fixture-git-env lanes: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

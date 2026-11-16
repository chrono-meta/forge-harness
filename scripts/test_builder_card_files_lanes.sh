#!/usr/bin/env bash
# Lanes for builder_card_files_check.py — known pairs in a throwaway git repo (FH-6, AQ-20261104-3/-1105-3).
#   B0 the shipped file runs by its own path
#   B1 known-negative: only editable + required changed → CLEAN rc 0, counts printed
#   B2 known-positive: a protected file modified (uncommitted) → VIOLATION rc 1 naming the path
#   B3 protected file CREATED untracked under a protected dir → VIOLATION (untracked side is read)
#   B4 protected file deleted, and renamed away → VIOLATION (both sides of a rename are read)
#   B5 inspect-only touched → VIOLATION · undeclared path → VIOLATION · required missing → VIOLATION
#   B6 a path matching editable AND protected → protected wins
#   B7 committed change against --base is seen (not only the working tree)
#   B8 empty / vacuous input → HARNESS-ERROR rc 2: no files block · no protected role · near-miss key
#      (even beside a correct line) · bad base ref · neither input
#   B9 --changed list path agrees with the git path on the same change
#   B10 revert probe: remove the protected/inspect-only branch on a COPY, confirm the edit applied,
#       B2 must turn green-for-the-wrong-reason (rc 0) — the lane anchors that branch
set -u
. "$(dirname "${BASH_SOURCE[0]}")/fixture_guard_lib.sh"   # scrub inherited GIT_* env first (#1088)
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; C="${BUILDER_CARD_CHECK:-$HERE/builder_card_files_check.py}"
pass=0; fail=0; ok(){ pass=$((pass+1)); echo "  ✅ $1"; }; bad(){ fail=$((fail+1)); echo "  ❌ $1"; }
T="$(mktemp -d "${TMPDIR:-/tmp}/bcfc.XXXXXX")"; trap 'rm -rf "$T"' EXIT
R="$T/repo"
mk(){ rm -rf "$R"; mkdir -p "$R/scripts" "$R/hooks" "$R/docs"
  git -C "$R" init -q -b main; git -C "$R" config user.email lane@example.invalid; git -C "$R" config user.name lane
  echo a > "$R/scripts/foo.py"; echo h > "$R/hooks/pre-commit"; echo c > "$R/CLAUDE.md"; echo d > "$R/docs/x.md"
  git -C "$R" add scripts hooks docs CLAUDE.md; git -C "$R" commit -q -m base; BASE=$(git -C "$R" rev-parse HEAD); }
cat > "$T/card.md" <<'EOF'
purpose: context — build foo
files:
  editable: scripts/foo.py
  required: scripts/test_foo_lanes.sh
  inspect-only: CLAUDE.md
  protected: hooks/**
constraints: smallest fix first
EOF
run(){ out=$(python3 "$C" --card "$1" --repo "$R" --base "$BASE" 2>&1); rc=$?; }

mk; b0=$(python3 "$HERE/builder_card_files_check.py" --card "$T/card.md" --repo "$R" --base "$BASE" 2>&1)
[[ "$b0" == *"VERDICT="* ]] && ok "B0 runs by its own path and prints a verdict" || bad "B0 direct run printed no verdict (a crash exits 1 — rc alone is not enough): $b0"

mk; echo b >> "$R/scripts/foo.py"; echo t > "$R/scripts/test_foo_lanes.sh"; run "$T/card.md"
[ $rc -eq 0 ] && [[ "$out" == *"VERDICT=CLEAN"* ]] && [[ "$out" == *"changed=2"* ]] && [[ "$out" == *"protected=1"* ]] \
  && ok "B1 editable+required only → CLEAN, counts printed" || bad "B1: rc=$rc $out"

b2(){ mk; echo t > "$R/scripts/test_foo_lanes.sh"; echo x >> "$R/hooks/pre-commit"; run "$T/card.md"
  [ $rc -eq 1 ] && [[ "$out" == *"touched-protected: hooks/pre-commit"* ]]; }
b2 && ok "B2 protected modified → VIOLATION names it" || bad "B2: rc=$rc $out"

mk; echo t > "$R/scripts/test_foo_lanes.sh"; mkdir -p "$R/hooks/sub"; echo n > "$R/hooks/sub/new"; run "$T/card.md"
[ $rc -eq 1 ] && [[ "$out" == *"touched-protected: hooks/sub/new"* ]] && ok "B3 untracked new file in protected dir → VIOLATION" || bad "B3: rc=$rc $out"

mk; echo t > "$R/scripts/test_foo_lanes.sh"; git -C "$R" rm -q hooks/pre-commit; run "$T/card.md"
[ $rc -eq 1 ] && [[ "$out" == *"touched-protected: hooks/pre-commit"* ]] && ok "B4 protected deleted → VIOLATION" || bad "B4 delete: rc=$rc $out"
mk; echo t > "$R/scripts/test_foo_lanes.sh"; git -C "$R" mv hooks/pre-commit scripts/moved; run "$T/card.md"
[ $rc -eq 1 ] && [[ "$out" == *"touched-protected: hooks/pre-commit"* ]] && ok "B4 protected renamed away → VIOLATION (old side read)" || bad "B4 rename: rc=$rc $out"

mk; echo t > "$R/scripts/test_foo_lanes.sh"; echo y >> "$R/CLAUDE.md"; run "$T/card.md"
[ $rc -eq 1 ] && [[ "$out" == *"touched-inspect-only: CLAUDE.md"* ]] && ok "B5 inspect-only touched → VIOLATION" || bad "B5 inspect: rc=$rc $out"
mk; echo t > "$R/scripts/test_foo_lanes.sh"; echo y >> "$R/docs/x.md"; run "$T/card.md"
[ $rc -eq 1 ] && [[ "$out" == *"undeclared: docs/x.md"* ]] && ok "B5 undeclared path → VIOLATION" || bad "B5 undeclared: rc=$rc $out"
mk; echo b >> "$R/scripts/foo.py"; run "$T/card.md"
[ $rc -eq 1 ] && [[ "$out" == *"required-missing: scripts/test_foo_lanes.sh"* ]] && ok "B5 required missing → VIOLATION" || bad "B5 required: rc=$rc $out"

printf 'files:\n  editable: scripts/foo.py\n  editable: hooks/pre-commit\n  required: scripts/test_foo_lanes.sh\n  protected: hooks/**\n' > "$T/card_both.md"
grep -q 'editable: hooks/pre-commit' "$T/card_both.md" || bad "B6 fixture: overlap line not written"
mk; echo t > "$R/scripts/test_foo_lanes.sh"; echo x >> "$R/hooks/pre-commit"; run "$T/card_both.md"
[ $rc -eq 1 ] && [[ "$out" == *"touched-protected: hooks/pre-commit"* ]] && ok "B6 editable ∩ protected → protected wins" || bad "B6: rc=$rc $out"

mk; echo t > "$R/scripts/test_foo_lanes.sh"; echo x >> "$R/hooks/pre-commit"; git -C "$R" add scripts hooks; git -C "$R" commit -q -m builder; run "$T/card.md"
[ $rc -eq 1 ] && [[ "$out" == *"touched-protected: hooks/pre-commit"* ]] && ok "B7 committed change vs --base → VIOLATION" || bad "B7: rc=$rc $out"

he(){ [ $rc -eq 2 ] && [[ "$out" == *"VERDICT=HARNESS-ERROR"* ]]; }
mk; printf 'purpose: x\nconstraints: none\n' > "$T/c_none.md"; run "$T/c_none.md"; he && ok "B8 no files block → HARNESS-ERROR" || bad "B8 none: rc=$rc $out"
printf 'files:\n  editable: scripts/foo.py\n' > "$T/c_noprot.md"; run "$T/c_noprot.md"; he && [[ "$out" == *"no protected"* ]] && ok "B8 no protected role → HARNESS-ERROR (empty ∩ is not a pass)" || bad "B8 noprot: rc=$rc $out"
printf 'files:\n  protected: hooks/**\n' > "$T/c_noedit.md"; run "$T/c_noedit.md"; he && ok "B8 no editable/required → HARNESS-ERROR" || bad "B8 noedit: rc=$rc $out"
for k in 'read-only' 'Protected' 'protect' 'inspect_only'; do
  printf 'files:\n  editable: scripts/foo.py\n  protected: hooks/**\n  %s: CLAUDE.md\n' "$k" > "$T/c_near.md"; run "$T/c_near.md"
  he && [[ "$out" == *"unknown key"* ]] && ok "B8 near-miss key «$k:» beside correct lines → HARNESS-ERROR" || bad "B8 near «${k}»: rc=$rc $out"
done
out=$(python3 "$C" --card "$T/card.md" --repo "$R" --base no-such-ref 2>&1); rc=$?; he && ok "B8 bad base ref → HARNESS-ERROR" || bad "B8 ref: rc=$rc $out"
out=$(python3 "$C" --card "$T/card.md" 2>&1); rc=$?; he && ok "B8 no change source → HARNESS-ERROR" || bad "B8 src: rc=$rc $out"

printf 'scripts/test_foo_lanes.sh\nhooks/pre-commit\n' > "$T/changed.txt"
out=$(python3 "$C" --card "$T/card.md" --changed "$T/changed.txt" 2>&1); rc=$?
[ $rc -eq 1 ] && [[ "$out" == *"touched-protected: hooks/pre-commit"* ]] && ok "B9 --changed list agrees with git path" || bad "B9: rc=$rc $out"

# B11 codex R1 regressions — each was CLEAN rc 0 before the fix
mk; echo t > "$R/scripts/test_foo_lanes.sh"; printf 'files:\n  editable: scripts/foo.py\n  protected: hooks/**\n\n  Protected: CLAUDE.md\n' > "$T/c_blank.md"; run "$T/c_blank.md"
he && [[ "$out" == *"unknown key"* ]] && ok "B11 blank line does not end the block (near-miss after it still caught)" || bad "B11 blank: rc=$rc $out"
printf 'files:\n  editable: **\n  protected: unused/**\nfiles:\n  protected: hooks/**\n' > "$T/c_dup.md"; run "$T/c_dup.md"
he && ok "B11 two files: blocks → HARNESS-ERROR" || bad "B11 dup: rc=$rc $out"
mk; echo t > "$R/scripts/test_foo_lanes.sh"; echo mod > "$R/hooks/pre-commit"; git -C "$R" add hooks/pre-commit; echo h > "$R/hooks/pre-commit"; run "$T/card.md"
[ $rc -eq 1 ] && [[ "$out" == *"touched-protected: hooks/pre-commit"* ]] && ok "B11 staged edit hidden by restored file → VIOLATION" || bad "B11 staged: rc=$rc $out"
mk; echo t > "$R/scripts/test_foo_lanes.sh"; echo k > "$R/hooks/한글 파일"; run "$T/card.md"
[ $rc -eq 1 ] && [[ "$out" == *"touched-protected: hooks/한글 파일"* ]] && ok "B11 untracked unicode+space name in protected dir → VIOLATION (no quotepath escape)" || bad "B11 unicode untracked: rc=$rc $out"
mk; echo k > "$R/hooks/한글"; git -C "$R" add hooks; git -C "$R" commit -q -m k; BASE=$(git -C "$R" rev-parse HEAD); echo t > "$R/scripts/test_foo_lanes.sh"; echo z >> "$R/hooks/한글"; run "$T/card.md"
[ $rc -eq 1 ] && [[ "$out" == *"touched-protected: hooks/한글"* ]] && ok "B11 tracked unicode name modified → VIOLATION" || bad "B11 unicode tracked: rc=$rc $out"
printf 'files:\n  editable: safe\n  protected: safe?\n' > "$T/c_sp.md"; printf 'safe \n' > "$T/ch_sp.txt"
out=$(python3 "$C" --card "$T/c_sp.md" --changed "$T/ch_sp.txt" 2>&1); rc=$?
[ $rc -eq 1 ] && [[ "$out" == *"touched-protected: safe "* ]] && ok "B11 --changed keeps trailing space («safe » ≠ «safe»)" || bad "B11 space: rc=$rc $out"
g(){ printf 'files:\n  editable: **\n  protected: %s\n' "$1" > "$T/c_g.md"; printf '%s\n' "$2" > "$T/ch_g.txt"
  out=$(python3 "$C" --card "$T/c_g.md" --changed "$T/ch_g.txt" 2>&1); rc=$?; }
# want=0 must be an explicit CLEAN: a crash must not read as «not protected»
for c in 'hooks/pre-commi?|hooks/pre-commit|1' 'hooks/*|hooks/a|1' 'hooks/*|hooks/a/b|0' '**/x.sh|x.sh|1' '**/x.sh|a/b/x.sh|1' 'vendor/lib/|vendor/lib|1' 'vendor/lib/**|vendor/lib|1' 'vendor/lib/|vendor/libx|0' 'a?c|a/c|0'; do
  IFS='|' read -r pat path want <<<"$c"; g "$pat" "$path"
  if [ "$want" = 1 ]; then [ $rc -eq 1 ] && [[ "$out" == *"touched-protected: $path"* ]]; else [ $rc -eq 0 ] && [[ "$out" == *"VERDICT=CLEAN"* ]]; fi \
    && ok "B12 glob «${pat}» vs «${path}» → protected=$want" || bad "B12 glob «${pat}» vs «${path}»: rc=$rc $out"
done

# B13 codex R2 regressions
printf 'files:\n  editable: hooks/*\n  protected: hooks/**\n' > "$T/c_nl.md"; printf 'hooks/a\nb' > "$T/nlname"
mk; echo t > "$R/scripts/test_foo_lanes.sh"; cp "$T/nlname" /dev/null; touch "$R/$(printf 'hooks/a\nb')"; run "$T/card.md"
[ $rc -eq 1 ] && [[ "$out" == *"touched-protected: hooks/a"* ]] && ok "B13 newline in a protected file name → VIOLATION (DOTALL)" || bad "B13 newline: rc=$rc $out"
mk; echo t > "$R/scripts/test_foo_lanes.sh"; git -C "$R" update-index --assume-unchanged hooks/pre-commit; echo x >> "$R/hooks/pre-commit"; run "$T/card.md"
he && [[ "$out" == *"assume-unchanged"* ]] && ok "B13 assume-unchanged on a tracked path → HARNESS-ERROR (not CLEAN)" || bad "B13 assume: rc=$rc $out"
mk; echo t > "$R/scripts/test_foo_lanes.sh"; git -C "$R" config diff.relative true; echo x >> "$R/hooks/pre-commit"
out=$(python3 "$C" --card "$T/card.md" --repo "$R/scripts" --base "$BASE" 2>&1); rc=$?
[ $rc -eq 1 ] && [[ "$out" == *"touched-protected: hooks/pre-commit"* ]] && ok "B13 --repo subdir + diff.relative → still sees hooks/ (VIOLATION)" || bad "B13 relative: rc=$rc $out"
for pth in './hooks/pre-commit' 'scripts/../hooks/pre-commit' '/abs/x' 'hooks//x'; do
  printf '%s\n' "$pth" > "$T/ch_nc.txt"; out=$(python3 "$C" --card "$T/card.md" --changed "$T/ch_nc.txt" 2>&1); rc=$?
  he && ok "B13 non-canonical «${pth}» → HARNESS-ERROR" || bad "B13 «${pth}»: rc=$rc $out"
done
printf 'files:\n  editable: scripts/foo.py\n  required: hooks/pre-commit\n  protected: hooks/**\n' > "$T/c_rp.md"
printf 'hooks/pre-commit\n' > "$T/ch_rp.txt"; out=$(python3 "$C" --card "$T/c_rp.md" --changed "$T/ch_rp.txt" 2>&1); rc=$?
[ $rc -eq 1 ] && [[ "$out" == *"touched-protected: hooks/pre-commit"* ]] && ok "B13 required ∩ protected → protected wins" || bad "B13 req∩prot: rc=$rc $out"
printf 'files:\n  required: CLAUDE.md\n  inspect-only: CLAUDE.md\n  protected: hooks/**\n' > "$T/c_ri.md"
printf 'CLAUDE.md\n' > "$T/ch_ri.txt"; out=$(python3 "$C" --card "$T/c_ri.md" --changed "$T/ch_ri.txt" 2>&1); rc=$?
[ $rc -eq 1 ] && [[ "$out" == *"touched-inspect-only: CLAUDE.md"* ]] && ok "B13 required ∩ inspect-only → inspect-only wins" || bad "B13 req∩insp: rc=$rc $out"

# B10 revert probe — on a copy, the protected/inspect-only branch reads as editable. Confirm, then run B2.
M="$T/mutant.py"; sed 's/if role in ("protected", "inspect-only"):      # FH6-PROTECTED-CHECK/if False:  # mutant/' "$C" > "$M"
if cmp -s "$C" "$M"; then bad "B10 mutation did not apply (marker line moved?) — probe is dead, not passing"
else
  keep="$C"; C="$M"; b2; mrc=$rc; mout=$out; C="$keep"
  # must be exactly CLEAN: a crashed mutant (rc 2) is a dead probe, not an anchored one (measured: absent checker scored ✅ here)
  [ $mrc -eq 0 ] && [[ "$mout" == *"VERDICT=CLEAN"* ]] && ok "B10 revert probe: protected branch removed → B2 no longer VIOLATION (rc=$mrc) — lane anchors it" \
    || bad "B10 revert probe: mutant still VIOLATION — B2 does not anchor the branch"
  b2 && ok "B10 restored → B2 VIOLATION again" || bad "B10 restore: rc=$rc $out"
fi

echo "builder_card_files_check lanes: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

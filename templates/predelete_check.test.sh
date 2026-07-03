#!/usr/bin/env bash
# Regression test for predelete_check.sh — the mechanical anchor for the 2026-07-03 fail-closed fix
# (cross-family default-toward-PASS sweep). Reproduces each closed degrade-OPEN hole. bash-3.2 safe.
# Run: bash templates/predelete_check.test.sh   (exit 0 = all pass)
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/predelete_check.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
ok(){ pass=$((pass+1)); echo "  ok: $1"; }
no(){ fail=$((fail+1)); echo "  FAIL: $1"; }

# helper: make a bare "origin" + a working clone with main
mkrepo(){
  local d="$1"
  ( git init -q --bare "$d/origin.git"
    git clone -q "$d/origin.git" "$d/wc" 2>/dev/null
    cd "$d/wc"
    git config user.email t@t; git config user.name t
    echo base > a.txt; git add a.txt; git commit -qm base
    git push -q origin HEAD:main 2>/dev/null
    git branch -q -m main 2>/dev/null || true ) >/dev/null 2>&1
}

# 1. non-existent repo path → exit 2 (fail-closed, not 0)
"$SCRIPT" "$TMP/nope" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 2 ] && ok "non-existent repo → exit 2" || no "non-existent repo exit=$rc (want 2)"

# 2. a dir that is not a git repo → exit 2
mkdir -p "$TMP/plain"; "$SCRIPT" "$TMP/plain" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 2 ] && ok "non-git dir → exit 2" || no "non-git dir exit=$rc (want 2)"

# 3. unresolvable base ref → exit 2 (was: misclassified SAFE, exit 0)
D3="$TMP/r3"; mkrepo "$D3"
"$SCRIPT" "$D3/wc" origin/does-not-exist >/dev/null 2>&1; rc=$?
[ "$rc" -eq 2 ] && ok "bad base ref → exit 2" || no "bad base ref exit=$rc (want 2)"

# 4. a branch named 'main-backup' must NOT be substring-excluded — it must be enumerated
D4="$TMP/r4"; mkrepo "$D4"
( cd "$D4/wc"; git checkout -q -b main-backup; echo x > uniquefile.txt; git add uniquefile.txt
  git commit -qm x; git push -q origin main-backup ) >/dev/null 2>&1
out=$("$SCRIPT" "$D4/wc" origin/main 2>/dev/null); rc=$?
echo "$out" | grep -q "main-backup" && ok "main-backup enumerated (not substring-skipped)" \
  || no "main-backup was NOT enumerated (substring-exclusion regression)"
[ "$rc" -eq 1 ] && ok "main-backup w/ unique path → REVIEW exit 1" || no "main-backup exit=$rc (want 1)"

# 5. a fully-merged branch → SAFE, exit 0
D5="$TMP/r5"; mkrepo "$D5"
( cd "$D5/wc"; git checkout -q -b merged; git push -q origin merged ) >/dev/null 2>&1
out=$("$SCRIPT" "$D5/wc" origin/main 2>/dev/null); rc=$?
{ echo "$out" | grep -q "SAFE    merged" && [ "$rc" -eq 0 ]; } \
  && ok "merged branch → SAFE exit 0" || no "merged branch: $out (exit $rc)"

echo "---- predelete_check.test: $pass passed, $fail failed ----"
[ "$fail" -eq 0 ]

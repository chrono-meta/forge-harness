#!/usr/bin/env bash
# Lanes for scripts/card_status_tags.sh (⑤-S). Known pair + the two NOT-MEASURED shapes + the
# empty set (which must not read as a pass). Each lane prints the line it judged.
set -u
FH="$(cd "$(dirname "$0")/.." && pwd)"
S="$FH/scripts/card_status_tags.sh"
T=$(mktemp -d "${TMPDIR:-/tmp}/cst.XXXXXX")
pass=0; fail=0
lane() { # name, card body, expected exit, expected pattern
  printf '%s' "$2" > "$T/card.md"
  out=$(bash "$S" "$T/card.md" 2>&1); rc=$?
  if [ "$rc" = "$3" ] && printf '%s' "$out" | grep -q -E "$4"; then
    echo "PASS $1 — $(printf '%s' "$out" | head -1)"; pass=$((pass + 1))
  else
    echo "FAIL $1 — rc=$rc out=$(printf '%s' "$out" | head -2 | tr '\n' ' ')"; fail=$((fail + 1))
  fi
}
HEAD='# 🗓️ 2026-11-03 마감

> 완료 = x

## 🌅 다음에 볼 것
'
TAIL='
## ↩️ 닫힌 것
- 1. not an item of this section

---

# 🗓️ older block
## 🌅 다음에 볼 것
1. untagged item in an OLDER block (must not count)
'
lane S1-all-tagged  "$HEAD"'1. [merged] #1008 머지
2. [open-pr] FoD #203
3. [operator] 임시 폴더 정리
'"$TAIL" 0 '^✅ ⑤-S status tags: 3/3'
lane S2-untagged    "$HEAD"'1. [merged] #1008 머지
2. FoD #203 열림
3. **임시 폴더** 정리
'"$TAIL" 0 '^⚠️  ⑤-S status tags: 2/3'
lane S3-unknown-tag "$HEAD"'1. [done] 끝
2. [planned] 다음
'"$TAIL" 0 '1/2 .*lack a tag'
lane S4-tag-not-first "$HEAD"'1. FoD #203 [open-pr]
'"$TAIL" 0 '1/1 .*lack a tag'
lane S5-empty-set   "$HEAD"'(없음)
'"$TAIL" 0 '^⬜ ⑤-S status tags: 0 items'
lane S6-no-section  '# 🗓️ block
## 🧵 이어가려면
1. [merged] x
' 3 'NOT MEASURED — newest card block has no'
# S7: card path that does not exist (the lane() helper always writes a file, so run it directly)
out=$(bash "$S" "$T/missing.md" 2>&1); rc=$?
if [ "$rc" = 3 ] && printf '%s' "$out" | grep -q 'card not found'; then echo "PASS S7-missing-card — $out"; pass=$((pass + 1)); else echo "FAIL S7-missing-card — rc=$rc $out"; fail=$((fail + 1)); fi
rm -rf "$T"
echo "card_status_tags lanes: $pass pass · $fail fail"
[ "$fail" -eq 0 ]

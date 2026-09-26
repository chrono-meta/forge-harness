#!/usr/bin/env bash
# test_claude_md_size_lanes.sh — CLAUDE.md 크기 가드 (2026-09-26 신설).
#
# 왜: Claude Code 는 세션 시작 시 CLAUDE.md 가 150.0k **문자**를 넘으면
#   `⚠ CLAUDE.md is over the 150.0k-char limit` 경고를 띄운다. 허브 CLAUDE.md 는 tracked·출하 파일이라
#   README 주 경로(git clone)로 들어온 모든 사용자가 그 경고를 본다(v3.16.0~v3.21.0 실측: 150,733 → 154,149).
#   파일은 주당 ~1k 씩 자라므로, 경고가 뜨기 **전에** 이 레인이 빨개지도록 한계를 145,000 으로 둔다.
# 무엇을 세나: Python `len()` 을 UTF-8 디코드한 텍스트에 건다 = **문자 수**(바이트 아님). CC 경고가 문자를
#   세므로 같은 단위다. `wc -c` 는 바이트라 한글 한 글자를 3 으로 세어 과차단한다(L4 가 그 차이를 박는다).
# 처방: 빨개지면 지우지 말고 **옮겨라** — 근거·실측·철회 경위를 detail 파일로 verbatim 이관하고 상주에는
#   규칙 + 포인터만 남긴다(선례: tracks/_meta/claude_md_diet_2026-09-26/ 의 diet.py·verify.py).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/.." && pwd)"
LIMIT=145000
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); printf '  ✅ %s\n' "$1"; }
no(){ FAIL=$((FAIL+1)); printf '  ❌ %s — %s\n' "$1" "${2:-}"; }

# size_check <file> <limit> → prints the char count; rc 0 = within, 1 = over, 2 = cannot measure.
size_check() {
  python3 - "$1" "$2" <<'PY'
import sys
path, limit = sys.argv[1], int(sys.argv[2])
try:
    n = len(open(path, encoding="utf-8").read())
except (OSError, UnicodeDecodeError) as e:
    print(f"UNMEASURED: {e}"); sys.exit(2)
print(n); sys.exit(0 if n <= limit else 1)
PY
}

echo "── test_claude_md_size_lanes (limit ${LIMIT} chars) ──"
command -v python3 >/dev/null 2>&1 || { no "L0 환경" "python3 없음 — 레인 미측정(통과 아님)"; echo "PASS=$PASS FAIL=$FAIL"; echo "FAILED=1"; exit 1; }
D="$(mktemp -d 2>/dev/null)" || D=""
[ -n "$D" ] && [ -w "$D" ] || { no "L0 환경" "mktemp -d 불가 — 레인 미측정(통과 아님)"; echo "PASS=$PASS FAIL=$FAIL"; echo "FAILED=1"; exit 1; }
trap 'rm -rf "$D"' EXIT

# L2 known-positive: 150k ASCII chars (the CC warning line) must FAIL.
python3 -c 'import sys; open(sys.argv[1],"w",encoding="utf-8").write("a"*150000)' "$D/big.md"
OUT=$(size_check "$D/big.md" "$LIMIT"); RC=$?
[ "$RC" -eq 1 ] && ok "L2 known-positive: 150,000자 → FAIL (rc=1, count=$OUT)" || no "L2 known-positive" "rc=$RC out=$OUT — 가드가 죽었다"

# L3 known-negative: small file must PASS.
printf '# small\n' > "$D/small.md"
OUT=$(size_check "$D/small.md" "$LIMIT"); RC=$?
[ "$RC" -eq 0 ] && ok "L3 known-negative: 작은 파일 → PASS" || no "L3 known-negative" "rc=$RC out=$OUT"

# L4 unit = characters, not bytes: 100,000 Hangul chars = 300,000 bytes must PASS.
python3 -c 'import sys; open(sys.argv[1],"w",encoding="utf-8").write("가"*100000)' "$D/ko.md"
OUT=$(size_check "$D/ko.md" "$LIMIT"); RC=$?; BYTES=$(wc -c < "$D/ko.md" | tr -d ' ')
[ "$RC" -eq 0 ] && [ "$OUT" = "100000" ] && [ "$BYTES" -gt "$LIMIT" ] \
  && ok "L4 단위 = 문자: 한글 100,000자(${BYTES} bytes) → PASS" || no "L4 단위" "rc=$RC chars=$OUT bytes=$BYTES — 바이트를 세고 있다"

# L5 boundary: exactly LIMIT passes, LIMIT+1 fails.
python3 -c 'import sys; open(sys.argv[1],"w",encoding="utf-8").write("a"*int(sys.argv[2]))' "$D/eq.md" "$LIMIT"
python3 -c 'import sys; open(sys.argv[1],"w",encoding="utf-8").write("a"*(int(sys.argv[2])+1))' "$D/p1.md" "$LIMIT"
size_check "$D/eq.md" "$LIMIT" >/dev/null; R1=$?; size_check "$D/p1.md" "$LIMIT" >/dev/null; R2=$?
[ "$R1" -eq 0 ] && [ "$R2" -eq 1 ] && ok "L5 경계: ${LIMIT} PASS · $((LIMIT+1)) FAIL" || no "L5 경계" "eq rc=$R1 +1 rc=$R2"

# L6 absent file is UNMEASURED (rc=2), never a pass.
OUT=$(size_check "$D/nope.md" "$LIMIT"); RC=$?
[ "$RC" -eq 2 ] && ok "L6 부재 → UNMEASURED rc=2 (0 으로 접지 않는다)" || no "L6 부재" "rc=$RC out=$OUT"

# L1 the real subject: the hub CLAUDE.md.
if [ ! -f "$ROOT/CLAUDE.md" ]; then
  no "L1 CLAUDE.md" "파일 부재 — 미측정(통과 아님)"
else
  OUT=$(size_check "$ROOT/CLAUDE.md" "$LIMIT"); RC=$?
  if [ "$RC" -eq 0 ]; then ok "L1 CLAUDE.md = ${OUT}자 ≤ ${LIMIT} (CC 경고선 150,000 까지 $((150000-OUT)))"
  else no "L1 CLAUDE.md" "${OUT}자 > ${LIMIT} — 지우지 말고 detail 파일로 옮겨라(헤더 처방)"; fi
fi

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || { echo "FAILED=1"; exit 1; }

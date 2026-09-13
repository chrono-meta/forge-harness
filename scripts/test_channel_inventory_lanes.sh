#!/usr/bin/env bash
# channel_inventory.sh 의 known-pair 앵커.
#
# 이 도구가 존재하는 이유는 **하루에 세 번 같은 실수를 했기 때문**이다 — 산출 디렉터리에서
# 「기록이 없다」를 판정하면서 **내가 연 채널에만 없는 것**을 무기록으로 단정했다. 그래서
# 이 레인의 핵심 픽스처는 합성이 아니라 **그날 실제로 틀린 그 디렉터리**다(C5).
#
# 실행: bash scripts/test_channel_inventory_lanes.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$HERE" || exit 2
PASS=0; FAIL=0; SKIP=0
ok(){ printf '  ✅ %s\n' "$1"; PASS=$((PASS+1)); }
ng(){ printf '  ❌ %s\n' "$1"; FAIL=$((FAIL+1)); }
sk(){ printf '  ⬜ SKIP %s\n' "$1"; SKIP=$((SKIP+1)); }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
CI="$HERE/scripts/channel_inventory.sh"

echo "== 합성 known-pair =="
mkdir -p "$T/box"
printf 'x\n' > "$T/box/alpha.jsonl"
: > "$T/box/beta.jsonl"                      # 🟥 있는데 비었다
printf 'log\n' > "$T/box/gamma.log"

out=$(bash "$CI" "$T/box" 2>&1); rc=$?
[ "$rc" = "0" ] && ok "C0 열거만 하면 rc=0 (판정을 안 한다)" || ng "C0 열거가 rc=$rc"
printf '%s' "$out" | /usr/bin/grep -qE 'beta\.jsonl +1 +1' \
  && ok "C1 «있는데 비었음» 을 비었음 칸으로 센다(«아예 없음» 과 갈린다)" \
  || ng "C1 빈 파일을 안 가른다 — 이 도구의 존재 이유가 사라진다"

out=$(bash "$CI" "$T/box" --read alpha.jsonl 2>&1); rc=$?
if [ "$rc" = "1" ] && printf '%s' "$out" | /usr/bin/grep -q '안 읽음 gamma.log'; then
  ok "C2 known-positive: 일부만 선언 → rc=1 · 안 연 채널을 이름으로 댄다"
else
  ng "C2 안 연 채널을 못 잡는다 (rc=$rc)"
fi

ALL=$(bash "$CI" "$T/box" 2>/dev/null | awk '/^  [a-z]/{print $1}' | paste -sd, -)
out=$(bash "$CI" "$T/box" --read "$ALL" 2>&1); rc=$?
if [ "$rc" = "0" ] && ! printf '%s' "$out" | /usr/bin/grep -q '안 읽음'; then
  ok "C3 known-negative: 전부 선언 → rc=0 (과차단 아님)"
else
  ng "C3 전부 선언했는데도 막는다 (rc=$rc) — 항상 막으면 판별력 0"
fi

out=$(bash "$CI" "$T/does_not_exist" 2>&1); rc=$?
[ "$rc" = "2" ] && ok "C4 디렉터리 부재 → rc=2 (계기 오류이지 «부재 판정» 이 아니다)" \
                || ng "C4 부재 디렉터리가 rc=$rc — 계기 오류가 판정으로 접힌다"
mkdir -p "$T/empty"
out=$(bash "$CI" "$T/empty" 2>&1); rc=$?
[ "$rc" = "2" ] && ok "C5 파일 0개 → rc=2 (셀 채널이 없으면 판정 불가)" \
                || ng "C5 빈 디렉터리가 rc=$rc"

echo
echo "== 🟥 실사고 픽스처 — 그날 실제로 틀린 그 디렉터리 =="
REAL="$HERE/tracks/_meta/dominance_B2/run/F_pair_blind/case_h04.rs__r1"
if [ -d "$REAL" ]; then
  out=$(bash "$CI" "$REAL" --read confirmed.jsonl,dropped.jsonl 2>&1); rc=$?
  if [ "$rc" = "1" ] && printf '%s' "$out" | /usr/bin/grep -q '안 읽음 pipeline.log'; then
    ok "C6 «confirmed·dropped 만 읽었다» 선언 → pipeline.log 를 안 연 채널로 지목 (rc=1)"
  else
    ng "C6 그날의 실수를 재현 못 한다 (rc=$rc) — 이 레인은 장식이다"
  fi
else
  sk "C6 실사고 디렉터리 없음 — gitignored 코퍼스라 이 머신에만 있다(부재이지 통과 아님)"
fi

echo
echo "════════════════════════════════════════"
printf '  PASS %s   FAIL %s   SKIP %s\n' "$PASS" "$FAIL" "$SKIP"
echo "  ⚠️ SKIP 은 통과가 아니다."
echo "════════════════════════════════════════"
[ "$FAIL" -eq 0 ] || exit 1

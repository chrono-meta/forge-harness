#!/usr/bin/env bash
# test_card_drift_probe.sh — session_close_check.sh ⑤-b 카드-드리프트 프로브의 known-pair 픽스처.
#
# WHY: 프로브 자체가 계기다 — CLAUDE.md §Instrument Calibration 이 요구하는 known-pair
# (양성 1 + 음성 1)를 통과하지 못하는 프로브는 배선하면 안 된다(다음 오판정의 원천이 된다).
# 이 파일이 그 캘리브레이션의 회귀 앵커: 프로브 정규식/토큰추출을 고칠 때마다 재실행.
#
# 픽스처 3종:
#   P  (known-positive): 카드가 🔴 "foo-digest 미가동 — 산출물 0" 주장 + 실물
#                        tracks/_meta/foo_digest_2026_07_22.md 존재 → ⑤-b 경고가 떠야 한다
#   N1 (known-negative): 카드가 부재 주장하는 bar-report 는 진짜 없음 → 경고 0
#   N2 (과발화 가드):    같은 실물이 있어도 부재-주장이 아닌 🟢 줄 → 경고 0
#                        (건강한 날 뜨는 경고는 무시를 학습시킨다 — 과발화도 결함)
#
# Exit 0 = 3/3 캘리브레이션 통과 · exit 1 = 프로브 계기 불량 (배선 금지)

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$SCRIPT_DIR/session_close_check.sh"
FAILED=0

run_fixture() {  # $1=name  $2=card-content  $3=make-artifact(0/1)  $4=expect-warn(0/1)
  local name="$1" card="$2" mkart="$3" expect="$4"
  local T; T=$(mktemp -d)
  mkdir -p "$T/tracks/_meta/logs"
  printf '%s\n' "$card" > "$T/tracks/_meta/reference_next_session_starter.md"
  [ "$mkart" = 1 ] && touch "$T/tracks/_meta/foo_digest_2026_07_22.md"
  # git 없는 디렉토리라도 다른 스텝은 조용히 지나간다(모두 2>/dev/null 가드)
  local out; out=$(bash "$CHECK" "$T" 2>/dev/null)
  local warned=0
  printf '%s\n' "$out" | grep -q "⑤-b card-drift" && warned=1
  rm -rf "$T"
  if [ "$warned" = "$expect" ]; then
    echo "✅ $name (warn=$warned, expected=$expect)"
  else
    echo "❌ $name — warn=$warned, expected=$expect"
    FAILED=1
  fi
}

run_fixture "P  known-positive: 부재주장+실물존재 → 경고" \
  "- 🔴 **foo-digest 잡 미가동(07-22)** — 로그도 산출물도 0(launchd 확인 필요)." 1 1

run_fixture "N1 known-negative: 부재주장+진짜부재 → 무경고" \
  "- 🔴 **bar-report 잡 미가동** — 산출물 0, 미착수." 0 0

run_fixture "N2 과발화가드: 실물존재+부재주장아님 → 무경고" \
  "- 🟢 **foo-digest 가동 중** — 오늘자 산출 확인." 1 0

run_fixture "N3 정정문맥가드: 부재주장 인용+오판정 명시 → 무경고" \
  "- 🔴 **foo-digest 산출 누락 수리 미완**. 기존 카드의 \"미가동\"은 오판정이었음." 1 0

run_fixture "N4 날짜토큰가드: 부재주장이나 토큰이 날짜뿐 → 무경고" \
  "- 🔴 잡 미가동 2026-07-22 산출물 0" 1 0

# challenger A-1 반례 (2026-07-23): 살아있는 주장 + 무관한 debunk 어휘 = 경고가 떠야 한다.
# debunk-단독 가드는 이 두 줄을 무음 삼켰다(FN) — 인용부 조건이 판별자.
run_fixture "P2 살아있는 주장+무관한 '정정 필요' → 경고 (A-1 FN 앵커)" \
  "- 🔴 **foo-digest 미가동 지속** — 산출물 0. 지난 카드의 실행횟수 수치는 정정 필요." 1 1

run_fixture "P3 살아있는 주장+무관한 '거짓' → 경고 (A-1 FN 앵커)" \
  "- 🔴 **foo-digest 미가동** — 산출물 0, 로그는 거짓 성공만 찍힘" 1 1

run_fixture "N5 위치-언급 디렉토리 → 무경고 (A-2 FP 앵커)" \
  "- 🟡 bar-report 미생성 — tracks/_meta/ 산출물 0" 0 0

run_fixture "N6 카드 자신 매치 제외 (A-3 FP 앵커)" \
  "- 🔴 next_session_starter 갱신 부재 — 0건" 0 0

run_fixture "P4 영어 부재주장 (A-4 앵커)" \
  "- 🔴 **foo-digest job not running** — zero outputs" 1 1

run_fixture "N7 인용된 부재키워드+정정 → 무경고 (실카드 07-22 클래스)" \
  "- 🔴 foo-digest 산출 누락. 기존 카드의 \"미가동\" 주장은 오판정이었음" 1 0

echo "── card-drift probe calibration: $([ "$FAILED" -eq 0 ] && echo "PASS (전 픽스처) — 배선 가능" || echo "FAIL — 계기 불량, 배선 금지") ──"
exit "$FAILED"

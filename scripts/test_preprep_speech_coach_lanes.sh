#!/usr/bin/env bash
# test_preprep_speech_coach_lanes.sh — preprep L16(발표 코칭)의 계약을 고정한다.
#
# WHY: 이 레인은 녹화를 듣고 코칭 6항 표를 낸다. 의존성이 셋(ffmpeg 필수 · whisper-cli 선택 ·
# 모델 파일 선택)이라 «없는 것」이 가장 흔한 상태다. 🟥 그래서 이 래퍼가 고정하는 것은
# «잘 듣는다」보다 먼저 **«못 들었을 때 0 을 안 낸다」** 다:
#   ffmpeg 없음        → ①~④ 측정불가 · exit 2
#   whisper/모델 없음  → ①② 측정불가 · ③④ 는 오디오만으로 · exit 2 (선언 --audio-only 면 0)
#   어느 경우에도 1 은 없다 — 문턱이 UNCALIBRATED 라 숫자를 «발견」으로 종료코드에 안 태운다.
#
# 픽스처는 self-test 가 실행 중에 합성한다(사람 목소리 · 녹화 원본 없음). whisper 와 ffmpeg 는
# 가짜 도구로 대신하므로 둘 다 없는 기계(CI)에서도 전 구간이 돈다. 진짜 ffmpeg 팔은 있으면 돈다.
#
# 종료코드: 0 pass · 1 레인 실패 · 2 대상 부재 · 10 setup 실패
set -uo pipefail
cd "$(dirname "$0")/.." || exit 10
LANE=plugins/fh-preprep/skills/preprep/lane_speech_coach.py
SELFTEST=plugins/fh-preprep/skills/preprep/test_lane_speech_coach.py
[ -f "$LANE" ] || { echo "ⓘ $LANE absent — subject missing (NOT a pass)"; exit 2; }
[ -f "$SELFTEST" ] || { echo "ⓘ $SELFTEST absent — subject missing (NOT a pass)"; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "ⓘ python3 absent — setup broke"; exit 10; }
rm -rf plugins/fh-preprep/skills/preprep/__pycache__
PASS=0; FAIL=0
ok(){ echo "  ✅ $1"; PASS=$((PASS+1)); }
ng(){ echo "  ❌ $1"; FAIL=$((FAIL+1)); }

echo "== K·D·R known-pair · 퇴화 · 되돌림 (레인 self-test) =="
OUT=$(python3 "$SELFTEST" 2>&1); RC=$?
echo "$OUT" | sed 's/^/  /'
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q 'FAIL 0'; then
  ok "self-test 전항 통과 (rc=$RC) — SKIP 수는 위 줄에 따로 찍힌다(SKIP != PASS)"
else
  ng "self-test 실패 (rc=$RC)"
fi

# 🟥 되돌림 레인이 실제로 돌았나 — self-test 가 그 절을 조용히 건너뛰면 «통과」가 장식이 된다
echo "$OUT" | grep -qE 'R1-b .*MUT [0-9]+' \
  && ok "되돌림 프로브가 실행됐다(BASE → MUT 숫자가 찍힘)" \
  || ng "되돌림 프로브 출력 없음 — 지역 문턱의 하중을 아무도 안 쟀다"

echo "== CLI 계약 — self-test 밖에서 한 번 더 =="
EMPTY=$(mktemp -d) || exit 10
OUT=$(cd plugins/fh-preprep/skills/preprep && PATH="$EMPTY" "$(command -v python3)" lane_speech_coach.py /nonexistent.wav 2>&1); RC=$?
rmdir "$EMPTY"
[ "$RC" -eq 2 ] && echo "$OUT" | grep -q '통과 아님' \
  && ok "ffmpeg 없음 → rc 2 · «통과 아님」 (0 도 1 도 아니다)" \
  || ng "ffmpeg 없음이 rc=$RC 로 나간다: $(echo "$OUT" | tail -3)"

grep -q "lane_speech_coach" plugins/fh-preprep/skills/preprep/SKILL.md \
  && ok "명세: SKILL.md 가 이 레인을 적는다(고아 구현 아님)" \
  || ng "SKILL.md 에 없다 — 명세 없는 구현"

# 🟥 공개 레포 — 모델 경로를 코드에 박지 않는다(기본값이 있으면 다른 머신에서 거짓 «있음」이 된다)
if grep -nE '(/Users/|/home/|~/models|ggml-[a-z0-9.-]+\.bin)' "$LANE" >/dev/null; then
  ng "레인에 머신 경로/모델 파일 이름이 박혀 있다 — 환경변수(PREPREP_WHISPER_MODEL)로만 받아라"
else
  ok "모델·홈 경로 하드코딩 0 (PREPREP_WHISPER_MODEL 로만 받는다)"
fi

echo "── preprep speech-coach lanes: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0

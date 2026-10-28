#!/usr/bin/env bash
# test_absorption_queue_lanes.sh — absorption_queue.py 의 기록 규칙 known-pair (얇은 래퍼).
#   닫기 근거(landed=PR#·커밋 · declined/deferred=사유) · 중복 추가 · digest 후보 추출(같은 체커의 --extract)
#   · 깨진 행/절 없는 digest 는 오류(0 아님) · 자산 후보 색인(스킬 + 에이전트). 레인은 파이썬 안에 있다.
# exit: 0 전 레인 PASS · 1 실패 · 10 harness error(python3 부재)
set -uo pipefail
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v python3 >/dev/null 2>&1 || {
  echo "harness error: python3 absent -- cannot measure. Not a pass." >&2; exit 10; }
python3 "$SRC/absorption_queue.py" --self-test

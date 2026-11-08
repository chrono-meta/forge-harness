#!/usr/bin/env bash
# test_catch_tally_lanes.sh — catch_tally.py 의 기록 규칙 known-pair (얇은 래퍼).
#   절 없는 날·범위 없는 0건 = 미기록(0 아님) · 목록 밖 방법/놓친 쪽 = INVALID(세지 않음)
#   · 다른 절·범위 밖 날은 안 셈 · 컨트롤(유효 기록만이면 rc=0). 레인은 파이썬 안에 있다.
# exit: 0 전 레인 PASS · 1 실패 · 10 harness error(python3 부재)
set -uo pipefail
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v python3 >/dev/null 2>&1 || {
  echo "harness error: python3 absent -- cannot measure. Not a pass." >&2; exit 10; }
python3 "$SRC/catch_tally.py" --self-test

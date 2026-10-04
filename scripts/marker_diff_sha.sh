#!/usr/bin/env bash
# marker_diff_sha.sh — 4축 마커의 `diff-sha:` 값을 계산한다(현재 staged diff 의 정규화 지문).
# 정본 계산은 templates/.git-hooks/pre-commit 의 _staged_diff_sha() 이고, 이 스크립트는 그 함수를
# 훅에서 추출해 그대로 부른다 — 두 벌로 손으로 적으면 조용히 갈라진다.
# Usage: bash scripts/marker_diff_sha.sh    (staged 상태에서, 축을 돌린 직후)
# Exit: 0 = 값 출력 · 1 = 추출/계산 실패(stdout 비어 있음)
set -uo pipefail
HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/templates/.git-hooks/pre-commit"
fn=$(sed -n '/^_staged_diff_sha()/,/^}/p' "$HOOK")
[ -n "$fn" ] || { echo "HARNESS-ERROR — _staged_diff_sha 를 $HOOK 에서 추출하지 못했다" >&2; exit 1; }
eval "$fn"
out=$(_staged_diff_sha) && [ -n "$out" ] || { echo "HARNESS-ERROR — staged diff 지문 계산 실패" >&2; exit 1; }
printf '%s\n' "$out"

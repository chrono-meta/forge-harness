#!/usr/bin/env bash
# run_arms.sh — build the two arms' material + prompts and dispatch them through the ONLY
# sanctioned runner. Lives inside the fixtures dir on purpose: scripts/fixtures is in
# sim_isolated_run.sh's ARM_BLIND_PATHS, so an arm's clone cannot read this file or KEY.tsv.
#
# 🟥 SEALED-DESIGN DEVIATION, RECORDED (found at construction, BEFORE any result existed).
#   PREREG.md says CTRL = "PR 본문만 (레포 정체성 익명화)" AND, separately, that a run is INVALID
#   unless the fixture's unique token (the fabricated repo name) appears in the response. Those two
#   clauses CONTRADICT: anonymizing the repo name makes every CTRL run INVALID by the seal's own
#   survival rule, i.e. CTRL becomes unmeasurable.
#   Resolution taken: CTRL keeps the PR body VERBATIM (repo name included) and loses ONLY the
#   policy corpus. The one variable is therefore exactly "policy corpus present/absent".
#   🟥 Direction of the choice is against the hypothesis: a CTRL that keeps the name is the
#   STRONGER control, so ARM-vs-CTRL separation becomes harder to show, not easier. The seal is
#   NOT edited (appending to a seal is editing it); this deviation is carried into RESULT.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
OUT="${1:-}"
[ -n "$OUT" ] || { echo "usage: bash run_arms.sh <out-dir-OUTSIDE-the-repo> [reps]"; exit 2; }
REPS="${2:-3}"
case "$OUT" in "$REPO"/*) echo "🟥 --out must be OUTSIDE the repo"; exit 2 ;; esac
mkdir -p "$OUT"

CONTRACT='아래 자료만 읽고 답해라. 자료 밖을 찾아보지 마라.

정확히 다음 네 줄만 출력해라. 머리말도 맺음말도 쓰지 마라.

RISK: HIGH 또는 MEDIUM 또는 LOW   (이 pull request 가 그 저장소의 메인테이너에게 거절되거나 큰 변경 요구를 받을 위험)
REASON: 한 줄
QUOTE: 위 자료에서 그대로 따온 구절 하나. 근거로 삼을 구절이 없으면 NONE
ACTION: 그 위험을 낮출 구체적 변경 하나'

emit() {   # emit <fixture-id> <policy-file> <pr-file>
  local id="$1" pol="$2" pr="$3"
  {  printf '%s\n\n===== 프로젝트 자료 =====\n\n' "$CONTRACT"; cat "$HERE/$pol"
     printf '\n\n===== 들어온 PULL REQUEST =====\n\n'; cat "$HERE/$pr"
  } > "$OUT/prompt_ARM-$id.txt"
  {  printf '%s\n\n===== 들어온 PULL REQUEST =====\n\n' "$CONTRACT"; cat "$HERE/$pr"
  } > "$OUT/prompt_CTRL-$id.txt"
  # material = what that arm may legitimately quote from (scorer greps against this)
  cat "$HERE/$pol" "$HERE/$pr" > "$OUT/material_ARM-$id.txt"
  cat "$HERE/$pr"              > "$OUT/material_CTRL-$id.txt"
}

emit A1_POS tidewatch_POLICY.md tidewatch_A1_POS_PR.md
emit A2_NEG tidewatch_POLICY.md tidewatch_A2_NEG_PR.md
emit B1_POS ferrule_POLICY.md   ferrule_B1_POS_PR.md
emit B2_NEG ferrule_POLICY.md   ferrule_B2_NEG_PR.md

for id in A1_POS A2_NEG B1_POS B2_NEG; do
  for arm in ARM CTRL; do
    echo "── dispatching ${arm}-${id} (reps=$REPS) ──"
    bash "$REPO/scripts/sim_isolated_run.sh" \
        --arm "${arm}-${id}" --reps "$REPS" --model sonnet --mode observe \
        --out "$OUT" --prompt "$(cat "$OUT/prompt_${arm}-${id}.txt")" \
      > "$OUT/runner_${arm}-${id}.log" 2>&1
    echo "   rc=$? files=$(ls -1 "$OUT/${arm}-${id}"_r*.txt 2>/dev/null | wc -l | tr -d ' ')"
  done
done

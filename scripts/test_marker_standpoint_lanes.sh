#!/usr/bin/env bash
# test_marker_standpoint_lanes.sh — regression fixtures for pre-commit's
# validate_standpoint_leg (typed standpoint verdict, 2026-08-17).
#
# WHY: `standpoint:` shipped 2026-08-14 with its value DELIBERATELY unvalidated — the doctrine
# said "mechanize on the first recorded false value, not before". That value has now been
# recorded (three, in fact): a `release_2.3.0` marker wrote `not-applicable` on a delta whose own
# grounds line concedes "소비자 install 의 게이트 수용은 바뀐다 (BREAKING 2건)", and two
# 2026-08-14 deltas that altered shipped gate scripts / a shipped SKILL.md carried no line at all.
# The threshold the doctrine set for this field is met; this lane is that mechanization.
#
# SCOPE — channel, not judgment (CLAUDE.md §Mechanization Boundary). These lanes assert the
# RECORD's properties: present · single · a member of the closed enum · not vacuous · not wearing
# the OTHER axis's tokens. They never assert the value is CORRECT.
#
# 🟥 NAMED RESIDUAL — the execution claim is WARN, not BLOCK. `tier2`/`tier2b`/`tier3` assert that
# something was EXECUTED in the target, and the doctrine calls that "the load-bearing half". A
# blocking check for it needs a vocabulary grep, and on first contact with the real corpus that
# grep over-blocked a legitimate marker whose grounds read "그 레포에서 실제로 호출해 양·음 arm 을
# 확인했다" — it simply did not know 「호출」. Over-blocking trains `--no-verify`, which would
# disarm the Destructive-Op gate living in the same hook, so the check warns. The cost is stated
# rather than hidden: a fabricated `tier2` with a fluent reason PASSES this lane. That hole is
# what §4-b (cross-family reads the marker) is for — it is not closed here.
#
# Fixtures assert BOTH directions (known-pair): every intended shape is admitted, and every hole
# the lane closes still blocks. Asserting only BLOCK cannot tell "blocked" from "blocked for the
# wrong reason"; asserting only PASS cannot see a lane that admits everything.
#
# Usage: bash scripts/test_marker_standpoint_lanes.sh   Exit: 0 = all behave; 1 = regression.

set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$REPO_ROOT/templates/.git-hooks/pre-commit"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

sed -n '/^validate_standpoint_leg()/,/^}/p' "$HOOK" > "$T/fn.sh"

# Instrument calibration — an empty extraction would let every fixture "pass" against nothing.
if ! grep -q 'DEGRADED_NO_TARGET_ACCESS' "$T/fn.sh"; then
  echo "❌ HARNESS-ERROR — validate_standpoint_leg did not extract from $HOOK."
  echo "   Fixtures below would measure an empty function. Aborting rather than reporting green."
  exit 1
fi

# 🟥 STANDPOINT_GROUNDS_GRACE_DATE 는 함수 «바깥» 에 살아서 이 추출에 안 들어온다. 주입하지 않으면
#    `set -u` 아래에서 그 확장이 죽거나(날짜 있는 마커) 조용히 grace 를 무효화한다(날짜 없는 마커).
#    훅 쪽에도 `:?` 가드를 뒀으므로 미주입은 이제 **크게** 죽는다 — 그래서 여기서 반드시 읽어 온다.
GRACE_SP=$(grep -m1 '^STANDPOINT_GROUNDS_GRACE_DATE=' "$HOOK" | sed -E 's/.*"(.*)"/\1/')
[ -n "$GRACE_SP" ] || { echo "❌ HARNESS-ERROR — STANDPOINT_GROUNDS_GRACE_DATE 를 못 읽었다"; exit 1; }
# 마커명에 날짜를 박는다 — validate_standpoint_leg 의 mdate 추출은 `.*_(YYYY-MM-DD)\.marker$` 다.
# 기본은 grace «이후» 로 둔다: 새 계약이 기본값이어야 한다.
POST_SP="$GRACE_SP"
FAIL=0
lane() { # $1 = id  $2 = expect(BLOCK|PASS)  $3 = marker body  [$4 = marker date]
  local id="$1" expect="$2" body="$3" mdate="${4:-$POST_SP}" rc out
  printf '%s\n' "$body" > "$T/m_${mdate}.marker"
  out=$( bash -c "set -uo pipefail; STANDPOINT_GROUNDS_GRACE_DATE='$GRACE_SP'; . \"\$1\"; validate_standpoint_leg \"\$2\"" _ "$T/fn.sh" "$T/m_${mdate}.marker" 2>&1 ); rc=$?
  local got=PASS; [ $rc -ne 0 ] && got=BLOCK
  if [ "$got" = "$expect" ]; then
    printf '  ✅ %-34s %s\n' "$id" "$got"
  else
    printf '  ❌ %-34s expected %s, got %s\n     %s\n' "$id" "$expect" "$got" "$(printf '%s' "$out" | head -2)"
    FAIL=1
  fi
}

echo "== standpoint lanes — BLOCK side (holes that must stay closed) =="
lane S1-missing        BLOCK 'axis2-model: opus'
lane S2-duplicate      BLOCK 'standpoint: tier1
standpoint: not-applicable — 나중에 고침'
lane S3-bare-na        BLOCK 'standpoint: not-applicable'
lane S4-unknown-value  BLOCK 'standpoint: tier9(qasp) — 새 등급을 지어냈다'
lane S5-crossfamily    BLOCK 'standpoint: DEGRADED_SINGLE_FAMILY — codex 안 붙었다'
lane S6-panel-token    BLOCK 'standpoint: panel(codex) — 축을 헷갈렸다'
lane S7-ungrounded-unk BLOCK 'standpoint: UNKNOWN'
lane S8-ungrounded-deg BLOCK 'standpoint: DEGRADED_NOT_RUN — 안 했음'

echo "== standpoint lanes — PASS side (legitimate shapes must not over-block) =="
lane N1-tier1          PASS  'standpoint: tier1'
lane N2-na-grounded    PASS  'standpoint: not-applicable — FH 내부 문서이고 출하 표면·peer 계약을 안 건드린다(확인함)'
lane N3-tier1b         PASS  'standpoint: tier1b(pmh-dev) — pmh-dev 정본 사본 직독 + 마커 42건 grep, 재분류 대상 0'
lane N4-tier2-exec     PASS  'standpoint: tier2(qasp-dev) — 그 레포에서 스위트 실행, rc=0 / 3176 passed 출력 확인'
lane N5-deg-grounded   PASS  'standpoint: DEGRADED_NOT_RUN — 표적 접근 가능했으나 안 돌렸다, 다음 라운드 이월'
lane N6-deg-targets    PASS  'standpoint: DEGRADED_NOT_RUN(qasp-dev · pmh-dev) — 전파 자산이라 해당되나 대상 레포에서 아무것도 실행 안 했다'
lane N7-quoted-value   PASS  'standpoint: "tier2(pmh-dev) — 그 레포 로컬 클론에서 실제로 실행, 양·음 arm 확인"'

echo "== tier2+ grounds — BLOCKING since 2026-09-12 (was advisory) =="
# ⚠️ 계약 변경 2026-09-12 — 이 픽스처는 PASS 를 단언하고 있었다(advisory 시절). 뒤집는 이유:
#   arXiv:2609.10969 이 출처 축을 40.9 %p, 모델 축을 11.3 %p 로 재면서(n=2,880, 고정 호출예산)
#   «강한 축의 grounds 를 advisory 로 두고 약한 축을 하드 차단» 이 균형이 아니게 됐다. 옛 기대값은
#   조용히 지우지 않고 여기서 이유와 함께 뒤집는다(crossfamily k3 의 선례와 같은 형태).
lane N8-tier2-vague    BLOCK 'standpoint: tier2(pmh-dev) — 그쪽 레포 기준으로 판단했다'
lane N8b-tier2-named   PASS  'standpoint: tier2(pmh-dev) — 그 클론에서 `bash scripts/x.sh` 를 돌렸고 출력은 30/30 PASS 였다'
lane N8c-tier1b-vague  PASS  'standpoint: tier1b(pmh-dev) — 그쪽 파일만 읽었다, 실행은 안 했다'
# grace 경계 — 하루 전 날짜의 마커는 종전 advisory 대로 통과(소급 없음)
lane N8d-pre-grace     PASS  'standpoint: tier2(pmh-dev) — 그쪽 레포 기준으로 판단했다' 2026-09-11

echo "== 과차단 수리 (cross-family agy 적발 — 차단이 된 순간 이건 override 를 훈련시키는 결함이다) =="
# 초판 키워드에 «뒤따르는 공백» 이 박혀 있어 콜론·다른 러너가 전부 막혔다. 실측으로 셋 다 BLOCK 이었다.
lane N8e-cargo         PASS  'standpoint: tier2(pmh-dev) — 그쪽 클론에서 cargo check 로 확인했고 결과는 0 errors 였다'
lane N8f-python        PASS  'standpoint: tier2(pmh-dev) — python scripts/eval.py 를 그 레포에서 수행, 12 passed 나왔다'
lane N8g-colon         PASS  'standpoint: tier2(pmh-dev) — ran: ./ci.sh 결과 30/30 초록이었다'
lane N8h-output-only   PASS  'standpoint: tier2(pmh-dev) — 그 레포에서 스위트를 돌렸고 53/53 으로 끝났다'
# 컨트롤 — 느슨하게 만든 뒤에도 «명령도 출력도 안 적은 줄» 은 여전히 막힌다(과교정 방지)
lane N8i-still-vague   BLOCK 'standpoint: tier2(pmh-dev) — 그쪽 관점에서 충분히 검토했다고 판단한다'

[ $FAIL -eq 0 ] && { echo "✅ all standpoint lanes behave"; exit 0; }
echo "❌ standpoint lane regression"; exit 1

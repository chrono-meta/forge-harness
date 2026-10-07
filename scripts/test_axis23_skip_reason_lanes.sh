#!/usr/bin/env bash
# test_axis23_skip_reason_lanes.sh — «Axes 2+3 이 왜 안 돌았나» 라는 문장이 참인지 고정한다.
#
# WHY (2026-10-05, 주간 클린룸 감사 실측 known-pair): 경량 모드의 SKIP 줄은 사유를
# «lightweight mode — CATALOG.md / tracks/ only» 라는 **리터럴**로 찍고 있었다. $LIGHT 는 두
# 경로로 채워지는데 — ⓐ 경로-light(CATALOG.md · tracks/) · ⓑ carve-out 강등(knowledge/**.md ·
# docs/*.md · AGENTS.md · README*.md 의 prose-only diff) — 그 문장은 ⓐ만 말했다. 실측:
#     CATALOG.md 만 staged        → «CATALOG.md / tracks/ only»   (참)
#     prose-only knowledge/** 만  → «CATALOG.md / tracks/ only»   (거짓 — CATALOG 도 tracks 도 없다)
# **판정은 맞고 사유가 거짓**이라 아무 레인도 빨개지지 않았다. 손해를 보는 쪽은 커밋이 아니라
# 훅 출력을 읽고 «이 커밋은 왜 전체 게이트를 안 탔나»를 재구성하는 **감사자**다 — 이 저장소가
# 이미 이름을 가진 결함 부류다([[feedback_rule_misdescribes_its_own_machine]]).
#
# SCOPE — 채널이지 판정이 아니다(§Mechanization Boundary). 이 레인은 «경량으로 가는 게 맞나»를
# 안 묻는다(그 라우팅은 `test_heavy_classifier_lanes.sh` 가 고정한다). 묻는 것은 하나다:
# 라우팅이 스스로를 설명하는 문장이 그 라우팅의 실제 출처와 일치하나.
#
# 방법 — 두 층을 다 잰다. 함수만 격리해 재면 «호출되는가»를 구조적으로 볼 수 없고(그 결함의
# 정본은 `test_hook_leg_wiring_lanes.sh` 머리말), 훅만 돌리면 경계 입력을 못 만든다.
#   ① 픽스처  : 훅에서 `_axis23_skip_reason` 을 **추출**해 경계 입력으로 돌린다(리터럴 재작성 금지)
#   ② 배선    : 합성 레포에서 **진짜 훅**을 돌려 ⓑ 팔이 실제로 그 문장을 내는지 본다 +
#               호출부를 옛 리터럴로 되돌린 사본에서 사라지는지(known-negative)
#
# Usage: bash scripts/test_axis23_skip_reason_lanes.sh   Exit: 0 PASS · 1 회귀 · 10 계기 불량
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$REPO_ROOT/templates/.git-hooks/pre-commit"
[ -f "$HOOK" ] || { echo "❌ HARNESS-ERROR — hook not found: $HOOK"; exit 10; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
FAIL=0

# ── ① 함수 추출. 🟥 비면 아래 픽스처가 «아무것도 아닌 것»을 재고 전부 통과한다 → fail CLOSED.
sed -n '/^_axis23_skip_reason()/,/^}/p' "$HOOK" > "$T/fn.sh"
if ! grep -q '_axis23_skip_reason' "$T/fn.sh"; then
  echo "❌ HARNESS-ERROR — _axis23_skip_reason 이 $HOOK 에서 추출되지 않았다."
  echo "   훅의 모양이 바뀌었다. 이 추출을 고쳐라 — 레인을 지우거나 사유 문자열의 사본을"
  echo "   여기 인라인하지 마라(그것이 레인이 대상을 덮기를 멈추는 방식이다)."
  exit 10
fi

f() { bash -c 'set -uo pipefail; . "$1"; _axis23_skip_reason "$2"' _ "$T/fn.sh" "${1-}" 2>&1; }

lane() { # $1=id $2=LIGHT $3=기대 사유(완전 일치)
  local id="$1" light="$2" want="$3" got
  got=$(f "$light")
  if [ "$got" = "$want" ]; then printf '  ✅ %-26s %s\n' "$id" "$got"
  else printf '  ❌ %-26s 기대 «%s» · 실제 «%s»\n' "$id" "$want" "$got"; FAIL=1; fi
}
lane_not() { # $1=id $2=LIGHT $3=나오면 안 되는 조각
  local id="$1" light="$2" never="$3" got
  got=$(f "$light")
  if grep -qF -- "$never" <<<"$got"; then
    printf '  ❌ %-26s «%s» 가 사유에 섞였다 — 실제 «%s»\n' "$id" "$never" "$got"; FAIL=1
  else printf '  ✅ %-26s «%s» 없음 — %s\n' "$id" "$never" "$got"; fi
}

echo "== ① 사유 ↔ \$LIGHT 출처 (경계 입력) =="
lane S1-path-catalog  'CATALOG.md'                                   'CATALOG.md / tracks/'
lane S2-path-tracks   'tracks/_meta/fh_completed_2026-10-05.md'      'CATALOG.md / tracks/'
lane S3-prose-only    'knowledge/shared/harness-core/x.md (prose-only)' 'prose-only carve-out'
lane S4-both          'CATALOG.md
docs/USER_GUIDE.md (prose-only)'                                     'CATALOG.md / tracks/ + prose-only carve-out'
# 🟥 빈 값은 ⓐ가 아니다. 미측정/부재를 «CATALOG.md / tracks/» 로 접는 것이 이 결함의 일반형이다.
lane S5-empty         ''                                             'no heavy-class file staged'
lane S6-blank-lines   '

'                                                                    'no heavy-class file staged'

echo "== ① 컨트롤 — 사유가 그냥 양쪽 다 찍는 것이 아니다 =="
lane_not C1-prose-not-path 'AGENTS.md (prose-only)'                  'CATALOG.md'
lane_not C2-path-not-prose 'CATALOG.md'                              'prose-only'

echo "== ② 배선 — 진짜 훅이 그 문장을 내나 (되돌림 known-negative) =="
WP="$T/wp"; mkdir -p "$WP/knowledge/shared/harness-core" "$WP/tracks/_meta"
( cd "$WP" && git init -q . && git config user.email t@example.invalid && git config user.name t ) \
  || { echo "❌ HARNESS-ERROR — git init failed"; exit 10; }
ln -s "$REPO_ROOT/scripts" "$WP/scripts"
printf '# prose\n' > "$WP/knowledge/shared/harness-core/doctrine.md"
( cd "$WP" && git add knowledge/shared/harness-core/doctrine.md && git commit -qm init ) >/dev/null 2>&1
printf '\n한 줄 산문.\n' >> "$WP/knowledge/shared/harness-core/doctrine.md"
( cd "$WP" && git add knowledge/shared/harness-core/doctrine.md ) >/dev/null 2>&1

# known-negative: 호출부를 옛 리터럴로 되돌린 사본
NH="$T/hook_literal.sh"
sed -E 's/\[Axis 2\+3\] SKIP \(lightweight mode — \$\(_axis23_skip_reason "\$LIGHT"\)\)/[Axis 2+3] SKIP (lightweight mode — CATALOG.md \/ tracks\/ only)/' "$HOOK" > "$NH"
if grep -qF '_axis23_skip_reason "$LIGHT"' "$NH" || ! bash -n "$NH" 2>/dev/null; then
  echo "❌ HARNESS-ERROR — 되돌림 사본이 호출부를 그대로 들고 있거나 구문이 깨졌다. 초록 보고 안 한다."
  exit 10
fi

live=$( cd "$WP" && bash "$HOOK" 2>&1 | grep -cF 'prose-only carve-out' )
dead=$( cd "$WP" && bash "$NH"   2>&1 | grep -cF 'prose-only carve-out' )
if [ "$live" -gt 0 ] && [ "$dead" -eq 0 ]; then
  printf '  ✅ %-26s WIRED (live=%s dead=%s)\n' W1-prose-arm "$live" "$dead"
elif [ "$live" -eq 0 ]; then
  printf '  ❌ %-26s NOT REACHED — 진짜 훅이 «prose-only carve-out» 을 안 찍었다\n' W1-prose-arm; FAIL=1
else
  printf '  ❌ %-26s HARNESS-ERROR — 되돌려도 문장이 남는다(live=%s dead=%s). 배선을 재는 게 아니다.\n' \
    W1-prose-arm "$live" "$dead"; FAIL=1
fi

echo
echo "🟥 이 레인이 덮지 않는 것 (이름으로 남긴다):"
echo '   · 경량/전체 **라우팅** 자체 — test_heavy_classifier_lanes.sh 가 고정한다.'
echo "   · \`diff_is_substantive\` 의 판정(어떤 diff 가 prose-only 인가) — 거기도 별도 앵커가 없다."
echo "   · 전체 모드의 출력 문구 — 이 레인은 SKIP 쪽 한 줄만 본다."
echo
if [ $FAIL -eq 0 ]; then echo "AXIS23 SKIP REASON LANES: PASS"; exit 0; fi
echo "AXIS23 SKIP REASON LANES: FAIL"; exit 1

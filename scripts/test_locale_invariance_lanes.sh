#!/usr/bin/env bash
# test_locale_invariance_lanes.sh — 같은 마커를 두 로케일에서 읽었을 때 **판정이 같은가**.
#
# ## 왜 있나 (2026-09-21 실측, 갓 클론한 컨테이너 = 「동료의 기계」)
#
# `templates/.git-hooks/pre-commit` 의 비공허성 바닥은 한글 근거 줄을 «낱말 수»로 센다.
# 그 선택의 근거가 훅 주석에 적혀 있었다 — *"Word count is locale-independent."* — 그리고
# **그 문장이 거짓이었다.** `wc -w` 는 로케일의 문자 분류로 공백을 가르므로, `LANG` 이 안 걸린
# 기계(=베어 컨테이너·CI 러너의 기본값, `LC_CTYPE=POSIX`)에서는
#
#     LC_ALL=POSIX   '성공 정의는 이것이고 절대 안 하는 것은 저것이다'  →  0 낱말
#     LC_ALL=C.UTF-8 같은 바이트                                      →  8 낱말
#
# 이 된다. 즉 **계기를 그것이 갖지 않은 속성 때문에 골랐다.** 같은 커밋 `a9e9b29` 에서 마커
# 레인 22건이 로케일만 바꿔 FAIL↔PASS 로 뒤집혔다.
#
# 🟥 그리고 방향이 둘이다 — 한쪽만 보면 «시끄러우니 안전하다»고 잘못 접는다:
#   ⓐ 과차단(시끄러움): 한글 근거가 0 낱말로 읽혀 **정상 마커가 차단**된다.
#   ⓑ 무음 침묵      : `Q1-one-slot-only-warns` 는 advisory 가 **안 찍힌다**(WARN→QUIET) —
#                       바닥에서 먼저 죽어 경고 가지에 도달하지 못한다.
#   ⓒ fail-OPEN      : 브래킷 안의 멀티바이트(`[:—-]`)는 POSIX 에서 **바이트 집합**이라
#                       「①」의 선두 바이트에 걸린다. `D9-copy-of-soul-blocks` 가
#                       BLOCK→**PASS** 로 샜다. 막아야 할 것이 통과한다.
#
# ## 이 레인이 주장하는 것 — 한 문장
#
# **판정은 로케일에 의존하지 않는다.** 내용이 옳은지는 각 레인 스위트가 이미 본다. 여기서
# 새로 박는 것은 「그 판정이 기계가 바뀌어도 같은가」뿐이다.
#
# 🟥 UTF-8 로케일이 없는 기계에서는 «통과»가 아니라 **rc=2 계기 오류**다. 대조군이 없으면
#    분리능이 없고, 분리능 없는 초록은 측정이 아니다(CLAUDE.md §Instrument Calibration).
#
# Usage: bash scripts/test_locale_invariance_lanes.sh   Exit: 0 = 판정 일치 · 1 = 회귀 · 2 = 계기 오류
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$REPO_ROOT/templates/.git-hooks/pre-commit"
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
FAIL=0
_t(){ printf '  %-56s' "$1"; }
_ok(){ echo "ok"; }
_no(){ echo "FAIL — $1"; FAIL=1; }

echo "── locale-invariance lanes ──"
[ -r "$HOOK" ] || { echo "❌ HARNESS-ERROR — 훅을 못 읽는다: $HOOK"; exit 2; }

# ── 계기 교정 ①: 적대 로케일에서 도는 UTF-8 로케일을 하나 찾는다 ────────────────
UTF8=""
for c in C.UTF-8 C.utf8 en_US.UTF-8 en_US.utf8; do
  if LC_ALL="$c" locale >/dev/null 2>&1; then UTF8="$c"; break; fi
done
if [ -z "$UTF8" ]; then
  echo "❌ HARNESS-ERROR — UTF-8 로케일이 이 기계에 없다. 대조군 없이는 분리능이 0 이다."
  echo "   🟥 UNMEASURED 다. 통과로 렌더하지 않는다."
  exit 2
fi
echo "  대조 로케일: POSIX  ↔  $UTF8"

KO='성공 정의는 이것이고 절대 안 하는 것은 저것이다'

# ── 계기 교정 ②: 이 기계에서 위험이 «실재하나» — wc -w 가 실제로 갈리는지 먼저 보인다.
#    안 갈리면(예: POSIX 구현이 멀티바이트를 알아서 처리) 아래 레인들은 아무것도 못 가른다.
w_posix=$(LC_ALL=POSIX bash -c 'printf "%s" "$1" | wc -w | tr -d " "' _ "$KO")
w_utf8=$(LC_ALL="$UTF8" bash -c 'printf "%s" "$1" | wc -w | tr -d " "' _ "$KO")
_t "L0 계기 교정 — 이 기계에서 \`wc -w\` 가 로케일로 갈린다"
if [ "$w_posix" != "$w_utf8" ]; then _ok
else
  echo "SKIP — wc -w 가 $w_posix/$w_utf8 로 같다(이 기계엔 위험이 없다)."
  echo "     🟥 아래 레인은 분리능이 없다 — 초록으로 읽지 마라. rc=2."
  exit 2
fi

# ── L1: 훅이 실제로 쓰는 셈법이 두 로케일에서 같은 수를 낸다 ────────────────────
#    표현식을 여기 다시 적지 않는다 — **훅에서 뽑아 쓴다**. 복사본을 두면 훅만 되돌아가도
#    이 레인이 초록으로 남는다(정본이 둘이 되는 자리).
EXPR=$(grep -m1 -oE "tr -s ' \\\\t\\\\n' '\\\\n' \| LC_ALL=C grep -c '\.'" "$HOOK")
if [ -z "$EXPR" ]; then
  echo "❌ HARNESS-ERROR — 훅에서 로케일 독립 셈법을 못 찾았다."
  echo "   훅이 \`wc -w\` 로 되돌아갔거나 표현이 바뀌었다. 부재는 통과가 아니다."
  exit 2
fi
c_posix=$(LC_ALL=POSIX  bash -c "printf '%s\n' \"\$1\" | $EXPR" _ "$KO")
c_utf8=$(LC_ALL="$UTF8" bash -c "printf '%s\n' \"\$1\" | $EXPR" _ "$KO")
_t "L1 훅의 셈법이 두 로케일에서 같은 수를 낸다"
if [ "$c_posix" = "$c_utf8" ] && [ "$c_posix" -gt 0 ]; then _ok
else _no "POSIX=$c_posix UTF8=$c_utf8 — 셈법이 여전히 로케일 의존이다"; fi

# ── L2: 그리고 그 수는 UTF-8 기계의 옛 `wc -w` 값과 **같다** ───────────────────
#    (문턱값은 전부 UTF-8 기계에서 실행으로 교정된 것이라, 셈법을 바꾸면서 그 값이 움직이면
#     이미 돌던 게이트의 의미가 조용히 바뀐다. 그건 고침이 아니라 다른 결함이다.)
_t "L2 UTF-8 기계에서는 옛 \`wc -w\` 와 같은 수 (문턱값 불변)"
if [ "$c_utf8" = "$w_utf8" ]; then _ok
else _no "새 셈법 $c_utf8 ≠ 옛 wc -w $w_utf8 — 문턱값의 의미가 움직인다"; fi

# ── L3–L6: 마커 레인 스위트를 **적대 로케일에서** 통째로 돌린다 ─────────────────
#    🟥 «이 트리에 스위트가 없다» 는 **회귀가 아니라 커버리지 결손**이다 — 둘을 같은 ❌ 로 내면
#    소비자 트리에서 이 레인이 «로케일 회귀» 를 보고한다. 실측 2026-09-21: npm 타르볼에는
#    `test_marker_soul_tenet_lanes.sh` · `test_marker_first_use_lanes.sh` 와
#    `.claude/soul_tenets.txt` 가 안 실려 있어서 그 팔이 구조적으로 못 돈다. 그래서 부재는
#    **UNMEASURED + rc=2(계기 오류)** 로 낸다 — 통과도 아니고 회귀도 아니다.
INSTRUMENT_INCOMPLETE=0
for suite in test_marker_oracle_lanes test_marker_soul_check_lanes \
             test_marker_soul_tenet_lanes test_marker_affected_lanes; do
  s="$REPO_ROOT/scripts/$suite.sh"
  if [ ! -f "$s" ]; then
    _t "L3+ $suite"; echo "UNMEASURED — 이 트리에 스위트가 없다 (통과 아님, 회귀도 아님)"
    INSTRUMENT_INCOMPLETE=1; continue
  fi
  _t "L3+ $suite @ LC_ALL=POSIX"
  if LC_ALL=POSIX bash "$s" >"$T/$suite.out" 2>&1; then _ok
  else
    _first="$(grep -m1 '❌' "$T/$suite.out" | sed 's/^ *//')"
    case "$_first" in
      *HARNESS-ERROR*) echo "UNMEASURED — 그 스위트 자체가 계기 오류다: $_first"
                       INSTRUMENT_INCOMPLETE=1 ;;
      *) _no "적대 로케일에서 FAIL: $_first" ;;
    esac
  fi
done

# ── 되돌림 프로브 — 변이는 **리터럴 치환**으로 만든다 ─────────────────────────
#    (초판은 sed 정규식으로 만들었다가 부분 일치로 `| wc -w | tr -d ' '|wc -w | tr -d ' '`
#     라는 이중 파이프를 낳았고, 그 변이체는 «1 낱말»을 내며 두 로케일에서 똑같이 막혔다 —
#     즉 되돌림 팔이 로케일이 아니라 자기 오타를 재고 있었다. L8 컨트롤이 그걸 잡았다.)
#    🟥 `-v` 로 넘기지 않는다 — awk 는 `-v` 값의 이스케이프를 **해석해서** `\t` 를 진짜 탭으로
#    바꾼다. 훅 안의 그 두 글자는 리터럴이라 그러면 영영 안 맞고, 변이는 조용히 no-op 이 된다.
#    ENVIRON 은 그 해석을 안 탄다.
_lit_replace() { # $1=file $2=from(literal) $3=to(literal) → stdout
  _LR_F="$2" _LR_R="$3" awk '
    BEGIN { f = ENVIRON["_LR_F"]; r = ENVIRON["_LR_R"] }
    { while ((p = index($0, f)) > 0) $0 = substr($0, 1, p-1) r substr($0, p+length(f)); print }
  ' "$1"
}
NEWC="| tr -s ' \t\n' '\n' | LC_ALL=C grep -c '.'"
OLDC="| wc -w | tr -d ' '"

# ── L7 되돌림 (낱말 수): `wc -w` 로 되돌리면 POSIX 에서 **과차단**이 살아나야 한다.
MUT="$T/mut_wc.sh"
_lit_replace "$HOOK" "$NEWC" "$OLDC" > "$MUT"
if [ "$(grep -c "wc -w | tr -d ' '|wc" "$MUT")" -ne 0 ]; then
  echo "❌ HARNESS-ERROR — 되돌림 변이가 중복 치환됐다. 이 팔은 자기 오타를 잰다."; exit 2
fi
sed -n '/^_marker_template_residue()/,/^}/p' "$MUT" >  "$T/fn_wc.sh"
sed -n '/^validate_affected_leg()/,/^}/p'    "$MUT" >> "$T/fn_wc.sh"
grep -q "wc -w" "$T/fn_wc.sh" || { echo "❌ HARNESS-ERROR — 되돌림 변이가 안 먹었다"; exit 2; }
printf 'affected: %s\n' "$KO" > "$T/m.marker"
_t "L7 되돌림 — \`wc -w\` 로 되돌리면 POSIX 에서 다시 막힌다"
if LC_ALL=POSIX bash -c 'set -uo pipefail; . "$1"; validate_affected_leg "$2"' _ "$T/fn_wc.sh" "$T/m.marker" >/dev/null 2>&1; then
  _no "되돌렸는데도 통과 — 이 레인은 셈법을 안 보고 있다(이빨 없음)"
else _ok; fi

# ── L8 컨트롤: 같은 변이체·같은 마커가 UTF-8 에서는 **통과한다** ───────────────
#    (L7 이 「로케일 때문」이 아니라 「픽스처나 변이가 원래 나쁨」이어서 막힌 것이면 여기서도 막힌다)
_t "L8 컨트롤 — 같은 변이체·같은 마커가 UTF-8 에서는 통과"
if LC_ALL="$UTF8" bash -c 'set -uo pipefail; . "$1"; validate_affected_leg "$2"' _ "$T/fn_wc.sh" "$T/m.marker" >/dev/null 2>&1; then _ok
else _no "UTF-8 에서도 막힌다 — L7 의 원인이 로케일이 아니다(픽스처나 변이의 결함)"; fi

# ── L9 되돌림 (브래킷): `(:|—|-)` 를 `[:—-]` 로 되돌리면 POSIX 에서 **fail-OPEN** ──
#    ①영혼 줄의 복붙 검출이 조용히 통과하는 자리. 방향이 반대라서 따로 박는다.
#    🟥 되돌림은 «브래킷 한 글자»가 아니라 **원래의 구문 전체**여야 한다. 고침이 바꾼 것은
#    부정 클래스 `[^:—-]*` 의 구조지 괄호 한 쌍이 아니고, 괄호만 되돌리면 앵커가 「①」를 먼저
#    먹어 버려 위험이 재현되지 않는다(초판이 그래서 두 로케일 모두 BLOCK 을 냈다).
MUT2="$T/mut_br.sh"
_NEW_SED="| sed -E 's/^[[:space:]]*#*[[:space:]]*(①영혼|soul)[[:space:]]*(:|—|-)[[:space:]]*//; s/[[:space:]]+\$//')"
_OLD_SED="| sed -E 's/^[^:—-]*[:—-][[:space:]]*//; s/[[:space:]]+\$//')"
_lit_replace "$HOOK" "$_NEW_SED" "$_OLD_SED" > "$T/_br1.sh"
_lit_replace "$T/_br1.sh" "(①영혼|soul)[[:space:]]*(:|—|-)'" "(①영혼|soul)[[:space:]]*[:—-]'" > "$MUT2"
sed -n '/^_marker_template_residue()/,/^}/p' "$MUT2" >  "$T/fn_br.sh"
sed -n '/^validate_defeater_leg()/,/^}/p'    "$MUT2" >> "$T/fn_br.sh"
if ! grep -q '\[\^:—-\]' "$T/fn_br.sh"; then
  _t "L9 되돌림 (브래킷)"; _no "변이가 안 먹었다 — 훅의 대체 형태가 바뀌었다"
else
  _SOUL='①영혼: 성공 정의 = 소비자 경로에서 완주해 rc=0 을 낸다'
  D="$T/.axes_23_passed_fix_x_$(date +%Y-%m-%d).marker"
  printf '%s\ndefeater: %s\n' "$_SOUL" "성공 정의 = 소비자 경로에서 완주해 rc=0 을 낸다" > "$D"
  _t "L9 되돌림 — 브래킷 형태는 POSIX 에서 복붙 검출이 샌다"
  r_posix=0; LC_ALL=POSIX  bash -c 'set -uo pipefail; DEFEATER_GRACE_DATE=2000-01-01; . "$1"; validate_defeater_leg "$2"' _ "$T/fn_br.sh" "$D" >/dev/null 2>&1 || r_posix=1
  r_utf8=0;  LC_ALL="$UTF8" bash -c 'set -uo pipefail; DEFEATER_GRACE_DATE=2000-01-01; . "$1"; validate_defeater_leg "$2"' _ "$T/fn_br.sh" "$D" >/dev/null 2>&1 || r_utf8=1
  if [ "$r_posix" -eq 0 ] && [ "$r_utf8" -eq 1 ]; then _ok
  else _no "POSIX rc=$r_posix UTF8 rc=$r_utf8 — 되돌린 브래킷이 이 픽스처로 안 갈린다(이빨 확인 불가)"; fi

  # L10 컨트롤 — **지금의** 훅(브래킷 아님)은 두 로케일에서 똑같이 막아야 한다
  sed -n '/^_marker_template_residue()/,/^}/p' "$HOOK" >  "$T/fn_ok.sh"
  sed -n '/^validate_defeater_leg()/,/^}/p'    "$HOOK" >> "$T/fn_ok.sh"
  _t "L10 컨트롤 — 지금의 훅은 두 로케일에서 똑같이 막는다"
  o_posix=0; LC_ALL=POSIX  bash -c 'set -uo pipefail; DEFEATER_GRACE_DATE=2000-01-01; . "$1"; validate_defeater_leg "$2"' _ "$T/fn_ok.sh" "$D" >/dev/null 2>&1 || o_posix=1
  o_utf8=0;  LC_ALL="$UTF8" bash -c 'set -uo pipefail; DEFEATER_GRACE_DATE=2000-01-01; . "$1"; validate_defeater_leg "$2"' _ "$T/fn_ok.sh" "$D" >/dev/null 2>&1 || o_utf8=1
  if [ "$o_posix" -eq 1 ] && [ "$o_utf8" -eq 1 ]; then _ok
  else _no "POSIX rc=$o_posix UTF8 rc=$o_utf8 — 고친 훅이 복붙을 두 로케일에서 똑같이 막지 못한다"; fi
fi

if [ "$FAIL" -eq 0 ] && [ "$INSTRUMENT_INCOMPLETE" -eq 1 ]; then
  echo "── 회귀는 없다. 그러나 팔 하나 이상이 UNMEASURED 다 — rc=2 (계기 오류) ──"
  exit 2
fi
echo "── $([ "$FAIL" -eq 0 ] && echo 'all lanes ok' || echo 'FAILURES above') ──"
exit "$FAIL"

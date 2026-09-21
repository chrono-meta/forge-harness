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
#    🟥 그러나 «기대하는 문자열과 글자 그대로 같은가»로 뽑으면 안 된다. 초판이 그렇게 뽑았고,
#    그러면 훅이 **무엇으로 바뀌든** L1·L2 는 한 줄도 실행되지 않은 채 계기 오류로 빠진다 —
#    즉 두 레인은 셈법을 한 번도 «판정»한 적이 없는 장식이 된다(되돌림 프로브 R2·R3 로 확인).
#    뽑는 것은 **구조**(셈법 줄의 첫 파이프 뒤)로 하고, 그것이 옳은 수를 내는지는 L1·L2 가
#    **실행해서** 판정한다. 줄 자체가 사라지면 그때는 부재 → 계기 오류가 맞다.
_CNT_LINES=$(grep -nE '^[[:space:]]*(words|soul_words|_rwords)=\$\(printf ' "$HOOK")
if [ -z "$_CNT_LINES" ]; then
  echo "❌ HARNESS-ERROR — 훅에서 낱말 수 셈법 줄을 못 찾았다 (이름이 바뀌었나)."
  echo "   부재는 통과가 아니다."
  exit 2
fi
_EXPRS=$(printf '%s\n' "$_CNT_LINES" \
         | sed -E 's/^[0-9]+://; s/^[^|]*\|[[:space:]]*//; s/\)[[:space:]]*(;.*)?$//' | sort -u)
EXPR=$(printf '%s\n' "$_EXPRS" | head -1)
_n_sites=$(printf '%s\n' "$_CNT_LINES" | wc -l | tr -d ' ')
_n_exprs=$(printf '%s\n' "$_EXPRS"    | wc -l | tr -d ' ')
# L1a: 한 벌만 되돌아가도 L1·L2 는 **못 본다**(첫 자리만 재니까). 자리가 전부 같은 표현인지
#      먼저 박는다 — 되돌림 프로브 R4(여섯 중 한 자리만 되돌림)가 이 팔에서만 빨개졌다.
_t "L1a 셈법 줄 $_n_sites 개가 전부 같은 표현이다"
if [ "$_n_exprs" -eq 1 ] && [ -n "$EXPR" ]; then _ok
else _no "훅 안에 셈법이 $_n_exprs 벌이다 — 한 벌만 되돌아가도 L1·L2 가 못 본다:
$(printf '%s\n' "$_EXPRS" | sed 's/^/       · /')"; fi
c_posix=$(LC_ALL=POSIX  bash -c "printf '%s\n' \"\$1\" | $EXPR" _ "$KO")
c_utf8=$(LC_ALL="$UTF8" bash -c "printf '%s\n' \"\$1\" | $EXPR" _ "$KO")
_t "L1 훅의 셈법이 두 로케일에서 같은 수를 낸다"
if [ "$c_posix" = "$c_utf8" ] && [ "$c_posix" -gt 0 ]; then _ok
else _no "POSIX=$c_posix UTF8=$c_utf8 — 셈법이 여전히 로케일 의존이다"; fi

# ── L2: 그 수가 «ASCII 공백으로 갈린 토큰 수»라는 의도된 의미와 같다 (문턱값 불변) ──
#
#    🟥 초판은 여기에 «UTF-8 기계에서는 옛 `wc -w` 와 같은 수» 라고 적었다. **그 단언은
#    플랫폼 의존이라 macOS 에서 거짓이고, 그대로 머지하면 운영자 맥에서 selfcheck 가 빨개진다.**
#    실측 2026-09-21 (Darwin 25.6.0 · /usr/bin/wc · 픽스처 KO = ASCII 토큰 8개):
#        LC_ALL=POSIX       옛 wc -w = 8    새 셈법 = 8     (일치)
#        LC_ALL=C.UTF-8     옛 wc -w = 11   새 셈법 = 8     ← 레인이 실제로 고르는 짝
#        LC_ALL=en_US.UTF-8 옛 wc -w = 11   새 셈법 = 8
#    BSD `wc -w` 는 UTF-8 로케일에서 한글 토큰 **안**을 쪼갠다 (토큰별 실측: `정의는`→2 ·
#    `절대`→2 · `저것이다`→2, 나머지는 1). ASCII 컨트롤(`one two three`)은 두 로케일 모두 3 —
#    즉 계기는 살아 있고 어긋남은 진짜다. 요컨대 **옛 값 자체가 낱말 수가 아니라 잡음**이고,
#    그것과의 일치를 요구하는 것은 새 셈법더러 다른 플랫폼의 버그를 재현하라는 말이다.
#
#    지켜야 할 성질은 「옛 수와 같다」가 아니라 **「의도한 의미와 같다」**다. 훅의 문턱
#    (defeater<6 · affected<3 · oracle<2)은 전부 «공백으로 갈린 토큰 수»를 보고 정해졌으니,
#    그 의미가 유지되면 문턱은 안 움직인다 — 옛 계기가 어느 플랫폼에서 그 의미를 못 냈든.
#    실측으로도 그렇다: 저자 트리의 실제 마커 **275 필드에서 문턱 판정이 뒤집힌 건 0 건**
#    (C.UTF-8 에서 옛≠새가 272 건인데도 0 — 차이가 문턱을 넘길 만큼 크지 않았다).
#    대조군은 훅과 **다른 프로그램**으로 짠다 (awk 기본 FS = 공백/탭/줄바꿈 · LC_ALL=C).
_ref_words(){ printf '%s\n' "$1" | LC_ALL=C awk '{ n += NF } END { print n+0 }'; }

#    계기 교정 ③ — 대조군 자신이 살아 있나. 손으로 센 값과 맞는지 **먼저** 본다.
#    (대조군이 훅 값을 되읊기만 하면 아래 단언은 언제나 참인 장식이다. 실제로 이 단계가
#     저자의 손셈 오류를 한 번 잡았다 — 혼합 줄을 7 로 셌는데 8 이었다.)
_ref_dead=0
for _p in "8:성공 정의는 이것이고 절대 안 하는 것은 저것이다" "3:one two three" "1:hello" "0:"; do
  _exp="${_p%%:*}"; _got=$(_ref_words "${_p#*:}")
  if [ "$_got" != "$_exp" ]; then
    echo "❌ HARNESS-ERROR — 대조군이 «${_p#*:}» 에서 $_got 을 냈다 (손으로 센 값 $_exp)."
    echo "   대조군이 죽었으면 아래 단언은 아무것도 안 잰다. UNMEASURED."
    _ref_dead=1
  fi
done
[ "$_ref_dead" -eq 0 ] || exit 2

#    본 단언 — 훅의 셈법이 **두 로케일 × 코퍼스 전부**에서 의도한 수를 낸다.
#    (기대값은 전부 손으로 세고 대조군으로 재확인했다. 코퍼스가 레인 «안에» 있으므로
#     저자 트리가 아니어도 이 팔은 돈다 — 소비자 기계에서 조용히 죽는 팔이 아니다.)
_l2=0; _l2_detail=""
while IFS='|' read -r _exp _s; do
  [ -n "$_exp" ] || continue
  _r=$(_ref_words "$_s")
  if [ "$_r" != "$_exp" ]; then
    echo "❌ HARNESS-ERROR — 코퍼스 기대값이 대조군과 어긋난다: «$_s» exp=$_exp ref=$_r"; exit 2
  fi
  for _L in POSIX "$UTF8"; do
    _h=$(LC_ALL="$_L" bash -c "printf '%s\n' \"\$1\" | $EXPR" _ "$_s")
    if [ "$_h" != "$_exp" ]; then
      _l2=1
      _l2_detail="$_l2_detail
       · $(printf '%-10s 훅=%-4s 의도=%-4s «%s»' "$_L" "$_h" "$_exp" "$_s")"
    fi
  done
done <<'L2CORPUS'
8|성공 정의는 이것이고 절대 안 하는 것은 저것이다
3|  성공   정의는	이것이고
8|훅 셈법과 locale 레인 — 열린 질문 없음
3|one two three
1|hello
0|
L2CORPUS
_t "L2 훅의 셈법 = ASCII 토큰 수 (두 로케일 × 코퍼스 6 · 문턱값 불변)"
if [ "$_l2" -eq 0 ]; then _ok
else _no "셈법이 의도한 의미와 다르다 — 문턱값의 의미가 움직인다:$_l2_detail"; fi

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
  # 🟥 from == to 는 no-op 으로 빠져나간다. 안 넣으면 아래 while 이 **안 끝난다** — 치환해도
  #    문자열이 그대로라 `index` 가 같은 자리를 영원히 다시 찾는다(known-pair 재현:
  #    from!=to → rc=0, from==to → timeout). 이 레인은 selfcheck 에 배선돼 있어서, 앞으로
  #    어떤 수리가 두 식을 **우연히 같게** 만드는 순간 selfcheck 가 FAIL 이 아니라 **행(hang)**
  #    한다. 실패보다 나쁜 방향이다 — CI 는 타임아웃으로만 죽고 원인이 안 보인다.
  [ "$2" = "$3" ] && { cat "$1"; return; }
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
# ── 픽스처를 이 기계에 맞춰 «문턱을 가로지르게» 짓는다 ─────────────────────────
#    🟥 초판은 여기에 KO(ASCII 토큰 8개)를 박아 두고 «POSIX 에서 막힌다»를 단언했다.
#    **그건 GNU wc 의 증상이지 지켜야 할 성질이 아니고, macOS 에서 거짓이다** — BSD wc 는
#    POSIX 에서 한글을 ASCII 공백으로 제대로 갈라 8 을 내므로 과차단이 안 일어나고, 이 팔은
#    (수리가 멀쩡한데) «이빨 없음»이라고 잘못 보고한다. 실측 2026-09-21 맥에서 L7 은 FAIL 이었다.
#    성질은 **「되돌리면 게이트 판정 자체가 로케일에 따라 갈린다」**이므로, 그 갈림이 드러나는
#    크기의 픽스처를 두 로케일의 **실측** wc -w 로 찾아서 짓는다 — 어긋남이 어느 방향이든 잡힌다.
#    (맥: POSIX 가 옳고 UTF-8 이 부풀린다 / GNU: UTF-8 이 옳고 POSIX 가 0 으로 죽는다.)
AFF_THR=3   # validate_affected_leg 의 문턱 (words -lt 3 → FAIL)
_POOL='정의는 절대 저것이다 이것이고 성공 하는 것은 하나 둘 셋 넷 다섯'
STRADDLE=""; s_p=""; s_u=""
for _k in 1 2 3 4 5 6 7 8 9 10 11 12; do
  _cand=$(printf '%s' "$_POOL" | LC_ALL=C awk -v k="$_k" \
          '{ for (i = 1; i <= k && i <= NF; i++) printf "%s%s", (i > 1 ? " " : ""), $i }')
  [ -n "$_cand" ] || continue
  _p=$(LC_ALL=POSIX   bash -c 'printf "%s" "$1" | wc -w | tr -d " "' _ "$_cand")
  _u=$(LC_ALL="$UTF8" bash -c 'printf "%s" "$1" | wc -w | tr -d " "' _ "$_cand")
  if { [ "$_p" -lt "$AFF_THR" ] && [ "$_u" -ge "$AFF_THR" ]; } \
  || { [ "$_u" -lt "$AFF_THR" ] && [ "$_p" -ge "$AFF_THR" ]; }; then
    STRADDLE="$_cand"; s_p="$_p"; s_u="$_u"; break
  fi
done
if [ -z "$STRADDLE" ]; then
  echo "❌ HARNESS-ERROR — 되돌림 변이가 이 기계에서 문턱을 가로지르는 픽스처를 못 만든다."
  echo "   옛 셈법의 로케일 차이가 affected 문턱($AFF_THR)을 넘길 만큼 크지 않다. UNMEASURED —"
  echo "   되돌림 팔이 이빨을 가졌는지 «확인 불가»다. 통과로 렌더하지 않는다."
  exit 2
fi
printf 'affected: %s\n' "$STRADDLE" > "$T/m.marker"

_run_aff(){ # $1=로케일 $2=함수 파일 → rc (0=통과 · 1=차단)
  LC_ALL="$1" bash -c 'set -uo pipefail; . "$1"; validate_affected_leg "$2"' \
    _ "$2" "$T/m.marker" >/dev/null 2>&1
}

# ── L7 되돌림: 옛 셈법으로 되돌리면 **게이트 판정이 로케일에 따라 갈린다** ──────
_t "L7 되돌림 — 옛 셈법은 판정을 로케일에 따라 갈리게 만든다"
m_p=0; _run_aff POSIX   "$T/fn_wc.sh" || m_p=1
m_u=0; _run_aff "$UTF8" "$T/fn_wc.sh" || m_u=1
if [ "$m_p" -ne "$m_u" ]; then _ok
else _no "변이체가 두 로케일에서 같은 판정(rc=$m_p) — 이 팔은 셈법을 안 보고 있다(이빨 없음). 실측 옛 wc -w: POSIX=$s_p $UTF8=$s_u · 문턱=$AFF_THR · 픽스처=«$STRADDLE»"; fi

# ── L8 컨트롤: **같은 픽스처·같은 러너**로 지금의 훅은 두 로케일 판정이 같다 ────
#    L7 과 L8 이 known-pair 를 이룬다 — 바뀐 것은 셈법 하나뿐이므로, L7 이 갈리고 L8 이
#    안 갈리면 그 차이의 원인은 셈법이다. (L8 혼자는 «컨트롤 있음 ≠ 판별력 있음»이다.)
sed -n '/^_marker_template_residue()/,/^}/p' "$HOOK" >  "$T/fn_aff_ok.sh"
sed -n '/^validate_affected_leg()/,/^}/p'    "$HOOK" >> "$T/fn_aff_ok.sh"
_t "L8 컨트롤 — 지금의 훅은 같은 픽스처에서 두 로케일 판정이 같다"
h_p=0; _run_aff POSIX   "$T/fn_aff_ok.sh" || h_p=1
h_u=0; _run_aff "$UTF8" "$T/fn_aff_ok.sh" || h_u=1
if [ "$h_p" -eq "$h_u" ]; then _ok
else _no "POSIX rc=$h_p UTF8 rc=$h_u — 고친 훅도 이 픽스처에서 로케일에 갈린다"; fi

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

# ── L11 — `soul-check` 의 ①영혼 본문 추출 (`[^[:alnum:]«]*`) ─────────────────────
#    🟥 이 자리는 **낱말 세기를 고친 뒤에야 관측 가능하다** — 그 전에는 셈법이 먼저 죽어서
#    어느 쪽이 원인인지 안 갈렸다. `[:alnum:]` 은 POSIX 에서 ASCII 전용이라, 「«」 도 ASCII
#    영숫자도 없는 **순한글 ①영혼 줄**이 부정 클래스에 통째로 먹힌다. 방향이 둘이다.
#    ⚠️ 위 L3+ 의 `test_marker_soul_check_lanes` 는 이것을 **구조적으로 못 본다**: 그 스위트의
#    영혼 픽스처가 `«` 와 `rc=0` 을 달고 있어 부정 클래스가 거기서 멈춘다. 픽스처 자신의
#    구두점이 결함을 가리는 자리라, 「«」 도 ASCII 도 없는 팔을 여기 따로 세운다.
_SC_KO='①영혼: 성공 정의는 이것이고 절대 안 하는 것은 저것이다'
_SC_EN='①영혼: success means this and the thing never done is that'
_sc_fns() { # $1 = 훅(또는 변이체) 경로 → $2 에 함수 둘을 뽑는다
  sed -n '/^_marker_template_residue()/,/^}/p' "$1" >  "$2"
  sed -n '/^validate_soul_check_leg()/,/^}/p'  "$1" >> "$2"
}
_sc_rc() { # $1=함수파일 $2=로케일 $3=영혼줄 $4=soul-check 값 → rc
  printf '%s\nsoul-check: %s\n' "$3" "$4" > "$T/sc.marker"
  LC_ALL="$2" bash -c 'set -uo pipefail; . "$1"; validate_soul_check_leg "$2"' \
    _ "$1" "$T/sc.marker" >/dev/null 2>&1; echo $?
}
_SC_OK='reflected(되돌아본 결과 어긋남 없다 두 절반 모두 지켰다)'
_SC_OK_EN='reflected(read it back and nothing drifted both halves held)'
_SC_LIE='DEGRADED_NO_SOUL(영혼 줄이 없어서 대조를 못 했다)'
_SC_LIE_EN='DEGRADED_NO_SOUL(no soul line present so nothing to reflect against)'

_sc_fns "$HOOK" "$T/fn_sc_now.sh"
_t "L11 지금의 훅 — 순한글 ①영혼 이 두 로케일에서 같은 판정"
a=$(_sc_rc "$T/fn_sc_now.sh" POSIX   "$_SC_KO" "$_SC_OK")
b=$(_sc_rc "$T/fn_sc_now.sh" "$UTF8" "$_SC_KO" "$_SC_OK")
c=$(_sc_rc "$T/fn_sc_now.sh" POSIX   "$_SC_KO" "$_SC_LIE")
d=$(_sc_rc "$T/fn_sc_now.sh" "$UTF8" "$_SC_KO" "$_SC_LIE")
if [ "$a" = "$b" ] && [ "$c" = "$d" ] && [ "$a" = "0" ] && [ "$c" = "1" ]; then _ok
else _no "정상=$a/$b (0/0 이어야) · 거짓DEGRADED=$c/$d (1/1 이어야) — 판정이 로케일을 탄다"; fi

_t "L11b 컨트롤 — ASCII 본문은 원래부터 두 로케일에서 같다"
e=$(_sc_rc "$T/fn_sc_now.sh" POSIX   "$_SC_EN" "$_SC_OK_EN")
f=$(_sc_rc "$T/fn_sc_now.sh" "$UTF8" "$_SC_EN" "$_SC_OK_EN")
g=$(_sc_rc "$T/fn_sc_now.sh" POSIX   "$_SC_EN" "$_SC_LIE_EN")
h=$(_sc_rc "$T/fn_sc_now.sh" "$UTF8" "$_SC_EN" "$_SC_LIE_EN")
if [ "$e" = "0" ] && [ "$f" = "0" ] && [ "$g" = "1" ] && [ "$h" = "1" ]; then _ok
else _no "ASCII 팔이 $e/$f/$g/$h — 픽스처나 레그가 원래 나쁘다(L11 의 원인이 로케일이 아니다)"; fi

# L11c 되돌림 — `[^[:alnum:]«]*` 로 되돌리면 **네 칸이 갈려야** 한다(과차단 + fail-open).
_SC_NEW="(①영혼|soul)([[:space:]]*(:|—|-))*[[:space:]]*//')"
_SC_OLD="(①영혼|soul)[^[:alnum:]«]*//')"
_lit_replace "$HOOK" "$_SC_NEW" "$_SC_OLD" > "$T/mut_sc.sh"
if ! grep -q '\[\^\[:alnum:\]«\]' "$T/mut_sc.sh"; then
  _t "L11c 되돌림 (alnum 브래킷)"; _no "변이가 안 먹었다 — 훅의 대체 형태가 바뀌었다"
else
  _sc_fns "$T/mut_sc.sh" "$T/fn_sc_old.sh"
  _t "L11c 되돌림 — 옛 형태는 POSIX 에서 과차단하고 거짓 DEGRADED 를 흘린다"
  ra=$(_sc_rc "$T/fn_sc_old.sh" POSIX   "$_SC_KO" "$_SC_OK")   # 기대 1 (과차단)
  rb=$(_sc_rc "$T/fn_sc_old.sh" "$UTF8" "$_SC_KO" "$_SC_OK")   # 기대 0
  rc=$(_sc_rc "$T/fn_sc_old.sh" POSIX   "$_SC_KO" "$_SC_LIE")  # 기대 0 (fail-open)
  rd=$(_sc_rc "$T/fn_sc_old.sh" "$UTF8" "$_SC_KO" "$_SC_LIE")  # 기대 1
  if [ "$ra" = "1" ] && [ "$rb" = "0" ] && [ "$rc" = "0" ] && [ "$rd" = "1" ]; then _ok
  else _no "되돌렸는데 $ra/$rb/$rc/$rd (1/0/0/1 이어야) — 이 팔은 이빨이 없다"; fi
fi

# ── L12 — `axes-run` 의 ⓔ 값 포착 (`[^ⓕ]*`) ────────────────────────────────────
#    브래킷 안의 「ⓕ」는 POSIX 에서 바이트 집합이라, ⓔ 값이 E2 로 시작하면(`→…`·한글) 포착이
#    빈 문자열이 되고 **채워진 필드가 «none» 으로 차단**된다. 방향은 과차단 한쪽뿐이지만,
#    하필 정본이 권하는 포인터 형태가 그 모양이라 실사용에서 바로 걸린다.
#    🟥 포착식은 **훅에서 뽑아 쓴다** — 복사본을 두면 훅만 되돌아가도 이 레인이 초록으로 남는다.
_E_EXPR=$(grep -m1 -o "sed -E -n '/\[\[:space:\]\]ⓔ=/{ s/\.\*\[\[:space:\]\]ⓔ=//; s/ⓕ\.\*//; p; }'" "$HOOK")
if [ -z "$_E_EXPR" ]; then
  _t "L12 ⓔ 포착 (훅에서 추출)"
  echo "❌ HARNESS-ERROR — 훅에서 ⓔ 포착식을 못 찾았다. 훅이 되돌아갔거나 형태가 바뀌었다."
  echo "   🟥 부재는 통과가 아니다."
  exit 2
fi
_e_get() { # $1=로케일 $2=axes-run 줄
  LC_ALL="$1" bash -c "printf '%s' \"\$1\" | $_E_EXPR | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*\$//'" _ "$2"
}
_E_MB='axes-run: ⓐ=none ⓑ=→standpoint ⓒ=none ⓓ=none ⓔ=→shadow(N=3, F=2) ⓕ=되돌림'
_E_AS='axes-run: ⓐ=none ⓑ=→standpoint ⓒ=none ⓓ=none ⓔ=shadow(N=3, F=2) ⓕ=되돌림'
_t "L12 지금의 훅 — 멀티바이트로 시작하는 ⓔ 값이 두 로케일에서 같게 잡힌다"
m1=$(_e_get POSIX "$_E_MB"); m2=$(_e_get "$UTF8" "$_E_MB")
if [ -n "$m1" ] && [ "$m1" = "$m2" ]; then _ok
else _no "POSIX=[$m1] UTF8=[$m2] — 채워진 ⓔ 가 한쪽에서 빈칸으로 읽힌다(=«none» 으로 차단)"; fi

_t "L12b 컨트롤 — ASCII 로 시작하는 ⓔ 값은 원래부터 같다"
n1=$(_e_get POSIX "$_E_AS"); n2=$(_e_get "$UTF8" "$_E_AS")
if [ -n "$n1" ] && [ "$n1" = "$n2" ]; then _ok
else _no "ASCII 팔이 [$n1]/[$n2] — L12 의 원인이 로케일이 아니다(식이나 픽스처의 결함)"; fi

_t 'L12c 되돌림 — `[^ⓕ]*` 로 되돌리면 POSIX 에서 빈칸이 된다'
o1=$(LC_ALL=POSIX   sed -n 's/.*[[:space:]]ⓔ=\([^ⓕ]*\).*/\1/p' <<< "$_E_MB")
o2=$(LC_ALL="$UTF8" sed -n 's/.*[[:space:]]ⓔ=\([^ⓕ]*\).*/\1/p' <<< "$_E_MB")
if [ -z "$o1" ] && [ -n "$o2" ]; then _ok
else _no "되돌렸는데 POSIX=[$o1] UTF8=[$o2] — 옛 식이 이 픽스처로 안 갈린다(이빨 확인 불가)"; fi

# ── L13 — below-floor-ack 의 고무도장 가드 (`“[^”]{2,}”`) ──────────────────────
#    같은 브래킷 클래스, 같은 방향(과차단), 그리고 같은 공정성 결함이다: 운영자 발화를
#    **한글 따옴표로** 인용하면 LANG 없는 기계에서 «인용이 없다» 로 읽혀 막히고, 똑같은
#    영어 인용은 통과한다. `”` = E2 80 9D 이고 한글 음절은 이어지는 바이트로 80 을 자주
#    싣는다(`대` = EB 8C 80) — 그래서 부정 클래스가 인용 안에서 끝난다.
#    🟥 레그는 **훅에서 통째로 뽑는다** — 식만 복사하면 훅이 되돌아가도 초록으로 남는다.
_mf_fn() { sed -n '/^validate_marker_floor()/,/^}/p' "$1" > "$2"; }
_mf_fn "$HOOK" "$T/fn_mf_now.sh"
if ! grep -q 'rubber-stamp guard' "$T/fn_mf_now.sh"; then
  _t "L13 고무도장 가드 (훅에서 추출)"
  echo "❌ HARNESS-ERROR — validate_marker_floor 에서 고무도장 가드를 못 찾았다."
  echo "   🟥 부재는 통과가 아니다."
  exit 2
fi
_mf_v() { # $1=함수파일 $2=로케일 $3=ack 줄(빈 문자열 가능) → pass|BLOCK
  { printf 'floor-status: below-floor\naxis2-engine: inline\n'
    [ -n "$3" ] && printf '%s\n' "$3"; } > "$T/mf.marker"
  # 🟥 파이프로 잃지 않는다 — `set -o pipefail` 이라 레그가 1 을 내면 파이프라인이
  #    grep 의 성공과 무관하게 1 이 되어 **모든 칸이 pass 로 읽힌다**(실제로 당했다).
  local _mf_out
  _mf_out=$(LC_ALL="$2" bash -c 'set -uo pipefail; . "$1"; validate_marker_floor "$2"' \
              _ "$1" "$T/mf.marker" 2>&1) || true
  case "$_mf_out" in *'rubber-stamp guard'*) echo BLOCK ;; *) echo pass ;; esac
}
_MF_KO='below-floor-ack: “그대로 진행해” — 운영자가 승인했다'
_MF_EN='below-floor-ack: "go ahead" — operator approved'
_MF_NO='below-floor-ack: 운영자가 승인했다고 한다'

_t "L13 지금의 훅 — 한글 따옴표 인용이 두 로케일에서 같은 판정"
a=$(_mf_v "$T/fn_mf_now.sh" POSIX "$_MF_KO"); b=$(_mf_v "$T/fn_mf_now.sh" "$UTF8" "$_MF_KO")
if [ "$a" = "pass" ] && [ "$b" = "pass" ]; then _ok
else _no "POSIX=$a UTF8=$b — 한글로 인용한 운영자 발화가 한쪽에서만 막힌다"; fi

_t "L13b 컨트롤 — ASCII 따옴표는 원래부터 두 로케일에서 같다"
c=$(_mf_v "$T/fn_mf_now.sh" POSIX "$_MF_EN"); d=$(_mf_v "$T/fn_mf_now.sh" "$UTF8" "$_MF_EN")
if [ "$c" = "pass" ] && [ "$d" = "pass" ]; then _ok
else _no "ASCII 팔이 $c/$d — L13 의 원인이 로케일이 아니다(레그나 픽스처의 결함)"; fi

_t "L13c 알려진 음성 — 인용이 아예 없으면 두 로케일 다 막는다"
e=$(_mf_v "$T/fn_mf_now.sh" POSIX "$_MF_NO"); f=$(_mf_v "$T/fn_mf_now.sh" "$UTF8" "$_MF_NO")
if [ "$e" = "BLOCK" ] && [ "$f" = "BLOCK" ]; then _ok
else _no "인용 없는 ack 가 $e/$f — 가드가 풀렸다(고무도장이 통과한다)"; fi

_t 'L13d 되돌림 — `“[^”]{2,}”` 로 되돌리면 POSIX 에서만 막힌다'
_MF_NEW='"[^"]{2,}"|“.{2,}”'
_MF_OLD='"[^"]{2,}"|“[^”]{2,}”'
_lit_replace "$HOOK" "$_MF_NEW" "$_MF_OLD" > "$T/mut_mf.sh"
if ! grep -q '“\[\^”\]{2,}”' "$T/mut_mf.sh"; then
  _no "되돌림 변이가 안 먹었다 — 훅의 가드 형태가 바뀌었다"
else
  _mf_fn "$T/mut_mf.sh" "$T/fn_mf_old.sh"
  g=$(_mf_v "$T/fn_mf_old.sh" POSIX "$_MF_KO"); h=$(_mf_v "$T/fn_mf_old.sh" "$UTF8" "$_MF_KO")
  if [ "$g" = "BLOCK" ] && [ "$h" = "pass" ]; then _ok
  else _no "되돌렸는데 POSIX=$g UTF8=$h (BLOCK/pass 여야) — 이 팔은 이빨이 없다"; fi
fi

if [ "$FAIL" -eq 0 ] && [ "$INSTRUMENT_INCOMPLETE" -eq 1 ]; then
  echo "── 회귀는 없다. 그러나 팔 하나 이상이 UNMEASURED 다 — rc=2 (계기 오류) ──"
  exit 2
fi
echo "── $([ "$FAIL" -eq 0 ] && echo 'all lanes ok' || echo 'FAILURES above') ──"
exit "$FAIL"

#!/usr/bin/env bash
# gate_bootstrap_ephemeral.sh — 휘발하는 클론에서 4축 게이트를 «실제로 돌게» 만들고,
#                               그래도 못 서는 층을 **이름으로** 남긴다.
#
# ## 왜 있나 (2026-09-21 실측, 클라우드 컨테이너 클론)
#
# `env_layer_fingerprint.sh` 가 이미 «층이 있나»를 잰다. 이 스크립트는 그 다음 칸이다 —
# **없는 층 중 무엇이 여기서 세울 수 있고 무엇이 구조적으로 못 서는가.** 둘은 다른 물음이고,
# 앞의 것만 답하면 세션은 ABSENT 열한 줄을 보고 «여긴 게이트가 안 돈다»로 접는다. 실측은
# 그 반대였다: 같은 컨테이너에서 **네 축 전부 통과**시켰다(`checkout_layer_drift.md`
# §Ephemeral-Clone-Gate-Floor 의 축별 표).
#
# 🟥 **이 스크립트는 증거를 만들지 않는다.** 마커도 매니페스트도 쓰지 않고, 주소만 찍는다.
#    자동 생성은 게이트를 통과시키는 게 아니라 «가짜로 닫는» 것이고, 4축 게이트 정본이
#    그걸 이름으로 금지한다(`fh_4axis_gate.md`: *a fabricated marker is … by design, do NOT
#    fake-close it*). 여기서 기계화하는 것은 **배선**(ENFORCE 층)이지 **판정**이 아니다
#    (CLAUDE.md §Mechanization Boundary).
#
# ## 모드
#   --check     (기본) 아무것도 안 바꾼다. 층을 재고 판정만 낸다.
#   --apply     위에 더해 이 레포의 `core.hooksPath` 를 잡는다 (레포-로컬 config 한 줄).
#               🟥 `--global` 은 절대 안 건드린다 — 사용자 기계 설정은 이 스크립트 밖이다.
#   --selftest  known-pair. 비공허성 **바닥**을 합성 입력 셋(ASCII 컨트롤 · 정직한 한글 ·
#               공허한 한글)으로 때려 분리능을 보인다. 낱말 «수»가 아니라 «바닥을 넘느냐»다.
#
# ## 종료코드
#   0  게이트가 여기서 돌고, 통과도 가능하다
#   1  막는 층이 비어 있다 (ENFORCE 미배선 · 정직한 한글이 비공허성 바닥을 못 넘음)
#   10 HARNESS-ERROR (레포가 아니다 · 훅 소스가 없다) — 통과도 경고도 아니다
#
# 🟥 **rc=0 은 «게이트가 돌 수 있다»이지 «네 커밋이 옳다»가 아니다.** 축을 실제로 통과시키는
#    것은 여전히 저자의 몫이고, 이 스크립트는 그 문이 닫혀 있는지 열려 있는지만 본다.
set -u

MODE="check"
case "${1:-}" in
  ""|--check) MODE="check" ;;
  --apply)    MODE="apply" ;;
  --selftest) MODE="selftest" ;;
  --help|-h)  sed -n '2,40p' "$0"; exit 0 ;;
  *) echo "unknown argument: $1 (try --help)" >&2; exit 2 ;;
esac

# ── 비공허성 «바닥»을 여기서 넘을 수 있나 ───────────────────────────────────
# 훅의 비공허성 다리들(`soul:` · `defeater:` · `affected:` · `reflected(...)`)은 낱말 수로
# 공허를 판정하고, 판정은 **바닥 비교**다 — `templates/.git-hooks/pre-commit` 의 가장 엄격한
# 자리가 `defeater` 의 `[ "$words" -lt 6 ]`(`:1647`) 이다.
#
# 🟥 **재는 것은 «몇 낱말이냐»가 아니라 «바닥을 넘느냐»다.** 초판은 낱말 수를 기대 토큰 수와
#    **같은지** 봤고, 그게 틀렸다 — 바닥은 방향이 있는 검사인데 등식은 방향이 없다. 훅 자신이
#    적어 뒀다: *"stable per-machine and monotonic, which is all a floor needs."* **초과는
#    결함이 아니고 미달만 결함이다.** 등식으로 재면 토큰 안을 쪼개는 `wc` 를 가진 기계(BSD)가
#    11 토큰 줄을 12 로 세는 것만으로 `BROKEN` 이 뜨고, `selfcheck.sh` 가 이 레인을 돌리므로
#    **멀쩡한 기계가 통째로 빨개진다**(2026-09-21 운영자 맥 실측, PR #783 리뷰).
#
# 🟥 **계기는 훅이 «지금» 쓰는 셈법을 그대로 쓴다 — `wc -w` 가 아니다.** PR #780(머지됨)이
#    훅의 여섯 자리를 바이트 수준 공백 분리로 바꿨다: `tr -s ' \t\n' '\n' | LC_ALL=C grep -c '.'`.
#    복제가 아니라 **추적**이고, 그 결합은 레인 L15 가 기계로 확인한다 — 훅에서 그 파이프라인이
#    사라지면 L15 가 이 파일을 지목하며 빨개진다. 안 그러면 계기가 훅과 **다른 것을 재면서
#    조용히 초록**을 낸다. (초판은 `wc -w` 를 썼고, #780 이 머지된 순간 바로 그 상태가 됐다.)
#    ⚠️ PR #784 는 **문자 길이**(`${#var}`·`wc -m`) 축이라 이 낱말 바닥과 무관하다 — 확인함.
_FLOOR=6

_H_STR='성공 정의 는 이 클론 에서 축 을 실행 으로 가른다'   # 정직한 한글 (알려진 양성)
_H_VAC='확인함'                                            # 진짜 공허한 한글 (알려진 음성)
_A_STR='success definition is measured in this clone by running the axes'  # ASCII 컨트롤

# 훅 `:1646` 과 같은 파이프라인. 바꾸려면 훅과 같이 바꿔라 (L15 가 잡는다).
_words() {  # $1 = 로케일 (빈 값이면 현재 환경) · $2 = 문자열
  local n
  if [ -n "$1" ]; then
    n=$(LC_ALL="$1" printf '%s\n' "$2" 2>/dev/null | LC_ALL="$1" tr -s ' \t\n' '\n' | LC_ALL=C grep -c '.')
  else
    n=$(printf '%s\n' "$2" | tr -s ' \t\n' '\n' | LC_ALL=C grep -c '.')
  fi
  printf '%s' "${n:-0}"
}
_clears() {  # $1 = 로케일 · $2 = 문자열 → 바닥을 넘으면 0
  local n; n=$(_words "$1" "$2"); n=${n:-0}
  [ "$n" -ge "$_FLOOR" ] 2>/dev/null
}
_hangul_words() { _words "$1" "$_H_STR"; }
_ascii_words()  { _words "$1" "$_A_STR"; }

_find_utf8_locale() {
  local l
  for l in $(locale -a 2>/dev/null); do
    case "$l" in
      *[Uu][Tt][Ff]8|*[Uu][Tt][Ff]-8)
        _clears "$l" "$_H_STR" && { printf '%s' "$l"; return 0; } ;;
    esac
  done
  # `locale -a` 가 소문자 별칭만 내는 기계가 있다(C.utf8). 별칭 후보를 직접 때려본다.
  for l in C.UTF-8 C.utf8; do
    _clears "$l" "$_H_STR" && { printf '%s' "$l"; return 0; }
  done
  return 1
}

if [ "$MODE" = "selftest" ]; then
  # known-pair — **이 기계의 현재 환경**에서 바닥 판정이 갈리는가. 로케일 대조가 아니다:
  # 로케일이 하나뿐인 기계에서도 「정직한 한글이 바닥을 넘나」는 직접 재진다.
  a_n=$(_words "" "$_A_STR"); h_n=$(_words "" "$_H_STR"); v_n=$(_words "" "$_H_VAC")
  echo "floor=$_FLOOR (pre-commit defeater 다리와 같은 값)"
  echo "known-pair — ASCII 컨트롤 : $a_n 낱말 (넘어야 한다)"
  echo "known-pair — 정직한 한글  : $h_n 낱말 (넘어야 한다)"
  echo "known-pair — 공허한 한글  : $v_n 낱말 (못 넘어야 한다)"
  rc=0
  if ! _clears "" "$_A_STR"; then
    echo "❌ HARNESS-ERROR — ASCII 컨트롤이 바닥을 못 넘는다. 낱말 셈 자체가 고장났다."; rc=10
  elif _clears "" "$_H_VAC"; then
    echo "❌ HARNESS-ERROR — 공허한 한글이 바닥을 넘는다. 이 계기는 공허를 분리하지 못한다."; rc=10
  elif _clears "" "$_H_STR"; then
    echo "✅ 분리능 있음 — 정직한 한글은 넘고 공허한 한글은 못 넘는다"
  else
    echo "⚠️  정직한 한글이 바닥을 **못 넘는다** — 이 환경에서 한국어 마커는 차단된다."
    echo "   🟥 계기 고장이 아니라 **측정된 결함**이다(LC_CTYPE). 수리는 PR #780."
    rc=1
  fi
  exit "$rc"
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "❌ HARNESS-ERROR — git 레포가 아니다 (cwd=$(pwd))"; exit 10; }
cd "$REPO_ROOT" || exit 10
HOOKSRC="templates/.git-hooks"
[ -f "$HOOKSRC/pre-commit" ] || {
  echo "❌ HARNESS-ERROR — 훅 소스가 없다: $HOOKSRC/pre-commit"
  echo "   이 레포가 forge-harness 인지 먼저 확인해라."; exit 10; }

BLOCK=0
echo "══ 휘발 클론 게이트 배선 — ${MODE} ══"
echo "repo : $REPO_ROOT"
echo "head : $(git rev-parse --short HEAD 2>/dev/null)  branch: $(git branch --show-current 2>/dev/null)"
echo ""

# ── ① ENFORCE — 훅이 배선돼 있나 ─────────────────────────────────────────────
CUR="$(git config --local core.hooksPath 2>/dev/null || true)"
# 🟥 문자열 비교만 하면 **같은 훅을 절대경로로 잡아 둔 체크아웃**이 「남의 값」으로 읽혀
#    BLOCK=1 을 받는다(2026-09-21 운영자 맥에서 실측 — `/Users/…/templates/.git-hooks` 가
#    `templates/.git-hooks` 와 같은 디렉터리인데 ⚠️ 분기를 탔다). 절대경로 형태는 이 레포가
#    문서로 인정하는 설정이고(`CLAUDE.md` — 워크트리 우회가 없는 **더 안전한** 쪽이다),
#    그것을 「미배선」으로 렌더하면 과차단이라 override 를 훈련시킨다.
#    ⇒ 표기가 아니라 **가리키는 디렉터리**로 비교한다. 진짜 다른 훅 디렉터리는 종전대로 ⚠️.
_same_dir() { [ -n "$1" ] && [ -n "$2" ] && [ -d "$1" ] && [ -d "$2" ] \
              && [ "$(cd "$1" 2>/dev/null && pwd -P)" = "$(cd "$2" 2>/dev/null && pwd -P)" ]; }
echo "① ENFORCE  core.hooksPath"
if [ "$CUR" = "$HOOKSRC" ] || _same_dir "$CUR" "$HOOKSRC"; then
  echo "   ✅ WIRED — $CUR"
elif [ -n "$CUR" ]; then
  echo "   ⚠️  다른 값이 잡혀 있다: $CUR"
  echo "      건드리지 않는다 — 저자가 일부러 잡은 값일 수 있다. 4축 게이트를 원하면"
  echo "      직접 바꿔라: git config --local core.hooksPath $HOOKSRC"
  BLOCK=1
elif [ "$MODE" = "apply" ]; then
  git config --local core.hooksPath "$HOOKSRC" || { echo "   ❌ HARNESS-ERROR — config 쓰기 실패"; exit 10; }
  echo "   ✅ WIRED (방금 잡았다) — $HOOKSRC"
  echo "      🟥 레포-로컬이다. 사용자 전역 설정은 안 건드렸다."
else
  echo "   ❌ ABSENT — 훅이 안 걸려 있다. 지금 커밋하면 게이트가 **안 돈 채로 무음 성공**한다."
  echo "      «통과했다»와 «안 돌았다»는 터미널 출력이 둘 다 무음이라 구분되지 않는다."
  echo "      배선: bash scripts/gate_bootstrap_ephemeral.sh --apply"
  BLOCK=1
fi
echo ""

# ── ② LOCALE — 비공허성 바닥이 여기서 넘어지나 ───────────────────────────────
echo "② LOCALE   비공허성 낱말 바닥 (soul / defeater / affected / reflected) — floor=$_FLOOR"
NOW_H=$(_words "" "$_H_STR"); NOW_A=$(_words "" "$_A_STR"); NOW_V=$(_words "" "$_H_VAC")
if ! _clears "" "$_A_STR"; then
  echo "   ❌ HARNESS-ERROR — ASCII 컨트롤이 바닥을 못 넘는다 ($NOW_A 낱말). 낱말 셈이 고장났다."
  exit 10
fi
if _clears "" "$_H_VAC"; then
  echo "   ❌ HARNESS-ERROR — 공허한 한글이 바닥을 넘는다 ($NOW_V 낱말). 계기가 공허를 분리 못 한다."
  exit 10
fi
if _clears "" "$_H_STR"; then
  echo "   ✅ OK — 정직한 한글이 바닥을 넘는다 ($NOW_H ≥ $_FLOOR · 공허 팔은 $NOW_V 로 막힌다)"
  echo "      (LC_CTYPE=$(locale 2>/dev/null | sed -n 's/^LC_CTYPE=//p' | tr -d '\"'))"
  echo "      🟥 낱말 수가 토큰 수와 **달라도 결함이 아니다** — 바닥은 단조롭기만 하면 된다."
  echo "        미달만 결함이다."
else
  echo "   ❌ BROKEN — 정직한 한글이 바닥을 **못 넘는다** ($NOW_H < $_FLOOR · ASCII 컨트롤은 $NOW_A 로 정상)."
  echo "      ⇒ 정직하게 한국어로 쓴 마커가 «공허하다»로 **차단된다**. 축이 틀려서가 아니라"
  echo "        이 기계의 LC_CTYPE 때문이다."
  # 🟥 여기서 **막는다.** 이 결함의 방향은 과차단이라 「게이트는 건전하다」가 참이고,
  #    초판은 그걸 근거로 rc=0 을 냈다. 그런데 이 스크립트를 읽는 쪽은 사람이 아니라
  #    «지금 커밋하려는 세션»이고, 그 세션에게 참인 명제는 **정직한 한글 기록이 차단된다**
  #    쪽이다. 자기 프로브에서 BROKEN 을 찍고도 마지막 줄이 ✅ 로 끝나는 걸 보고 고쳤다.
  BLOCK=1
  if UTF8=$(_find_utf8_locale); then
    echo "      절차상 해소: export LC_ALL=$UTF8   (이 셸에서 한 번)"
    echo "      🟥 우회이지 수리다운 수리가 아니다. 훅의 셈법은 PR #780 이 이미 로케일 불변으로"
    echo "         바꿨으므로, 여기서 이 줄이 뜬다면 그 셈법 자체가 이 기계에서 깨진 것이다."
  else
    echo "      ❌ 이 기계엔 UTF-8 로케일이 없다 — 절차로도 못 푼다."
    echo "         남는 길은 마커를 ASCII 낱말이 충분한 문장으로 쓰는 것뿐인데, 그건"
    echo "         «낱말 수를 채우는 글쓰기»라 이 필드들이 막으려던 의례 그 자체다."
  fi
fi
echo ""

# ── ③ EVIDENCE — 주소만 찍는다. 만들지 않는다 ────────────────────────────────
TODAY=$(date +%Y-%m-%d)
BR=$(git branch --show-current 2>/dev/null)
SLUG=$(printf '%s' "$BR" | tr '/' '_')
MK="tracks/_meta/.axes_23_passed_${SLUG}_${TODAY}.marker"
MF="tracks/_meta/edit_manifest.yaml"
echo "③ EVIDENCE 훅이 읽는 두 주소 (🟥 이 스크립트는 **안 만든다**)"
printf '   %-6s %s\n' "$([ -f "$MK" ] && echo '✅' || echo '⬜')" "$MK"
printf '   %-6s %s\n' "$([ -f "$MF" ] && echo '✅' || echo '⬜')" "$MF"
echo "   둘 다 gitignored 다 — 이 컨테이너와 함께 사라지고 CI 는 구조적으로 못 본다."
echo "   살아남는 채널은 **커밋 메시지**다: claude/* 브랜치는 scripts/remote_marker_gate.sh 가"
echo "   axes-run · crossfamily · standpoint 세 줄을 커밋 기록에서 요구한다."
echo ""

# ── ④ 여기서 못 닫는 것 — 이름으로 ───────────────────────────────────────────
echo "④ 구조적 잔여 (휘발 클론에서 못 닫는다 — 고치라는 뜻이 아니라 알고 쓰라는 뜻)"
if [ -s ".claude/rules/.public-surface-patterns" ]; then
  echo "   ✅ pattern.psa 있음 — 기밀성 스캔이 전체 패턴셋으로 돈다"
else
  echo "   🟥 pattern.psa 없음 — 기밀성 스캔이 defaults-only 로 돌고 **초록을 낸다.**"
  echo "      회사명·실명 토큰 클래스는 UNSCANNED 다. 그 파일은 실제 리터럴을 담아서"
  echo "      gitignored 이므로, 클론에는 **구조적으로 올 수 없다.** 차단이 아니라 커버리지"
  echo "      축소이고, 훅은 🟧 배너로 그렇게 말한다 — 그 PASS 를 전체 통과로 읽지 마라."
fi
echo "   🟥 ⓐ 다른 계열 축: 이 컨테이너에 codex/gemini 계열 CLI 가 없으면 crossfamily 는"
echo "      DEGRADED_SINGLE_FAMILY 가 정직한 최대값이다. 근거를 같은 줄에 적어야 통과한다."
echo "   🟥 마커·매니페스트의 provenance: 여기서 쓴 기록은 주간 감사도 below_floor_scan 도"
echo "      다시 읽지 못한다 — 재검증 큐에 **안 들어간다.**"
echo ""

if [ -x scripts/env_layer_fingerprint.sh ] || [ -f scripts/env_layer_fingerprint.sh ]; then
  echo "층 전체 표: bash scripts/env_layer_fingerprint.sh"
fi

if [ "$BLOCK" -ne 0 ]; then
  echo ""
  echo "❌ 남은 층이 있다 — 지금 이 셸에서 커밋하지 마라."
  echo "   ENFORCE 가 비면 게이트가 **안 돈 채로 무음 성공**하고(뒷받침 없음),"
  echo "   LOCALE 이 깨지면 게이트가 **정직한 한글 기록을 차단**한다(통과 불가)."
  echo "   둘은 반대 방향의 고장이고, 둘 다 여기서 끝낼 일이지 커밋 시점에 발견할 일이 아니다."
  exit 1
fi
echo ""
echo "✅ 게이트가 이 클론에서 돈다. 🟥 «돈다»이지 «통과했다»가 아니다 — 축은 네가 통과시켜라."
exit 0

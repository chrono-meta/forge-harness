#!/usr/bin/env bash
# test_multibyte_bracket_lint_lanes.sh — scripts/multibyte_bracket_lint.sh 의 앵커.
#
# 🟥 왜 린트의 «내장 자가검정» 으로 충분하지 않은가. `_calibrate` 의 known pair 는 **린트 파일
#    안에** 산다 — 정규식이 약해져도 자기 픽스처는 계속 통과할 수 있고, 실제로 이 결함 클래스를
#    전수 열거하려던 첫 계기가 정확히 그렇게 **11 중 1 을 놓쳤다**(`[:alnum:]` 의 첫 `]` 에서
#    끊겨서). 그래서 이 스위트는 **실물 훅의 사본을 되돌려** 잡히는지를 본다 — 내장 자가검정이
#    구조적으로 못 하는 팔이다.
#
# 🟥 트래킹 파일은 절대 안 건드린다. 모든 변이는 $T 안의 사본에서 일어난다.
#
# Usage: bash scripts/test_multibyte_bracket_lint_lanes.sh
# Exit:  0 = 전부 통과 · 1 = 회귀 · 2 = 계기 오류
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LINT="$REPO_ROOT/scripts/multibyte_bracket_lint.sh"
HOOK="$REPO_ROOT/templates/.git-hooks/pre-commit"
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
FAIL=0
_t(){ printf '  %-58s' "$1"; }
_ok(){ echo "ok"; }
_no(){ echo "FAIL — $1"; FAIL=1; }

echo "── multibyte-bracket lint lanes ──"
[ -r "$LINT" ] || { echo "❌ HARNESS-ERROR — 린트를 못 읽는다: $LINT"; echo "   🟥 부재는 통과가 아니다."; exit 2; }
[ -r "$HOOK" ] || { echo "❌ HARNESS-ERROR — 훅을 못 읽는다: $HOOK"; echo "   🟥 부재는 통과가 아니다."; exit 2; }

_rc(){ bash "$LINT" "$@" >/dev/null 2>&1; echo $?; }

_t "L0 내장 자가검정이 살아 있다 (--selftest)"
[ "$(bash "$LINT" --selftest >/dev/null 2>&1; echo $?)" = "0" ] && _ok \
  || _no "린트가 자기 known-pair 를 분리 못 한다 — 아래 팔들의 값이 의미 없다"

# ── L1/L2 — 실물 훅의 사본. 내장 자가검정이 구조적으로 못 가지는 팔 ──────────────
cp "$HOOK" "$T/clean" || exit 2
_NEW='"[^"]{2,}"|“.{2,}”'
_OLD='"[^"]{2,}"|“[^”]{2,}”'
_LR_F="$_NEW" _LR_R="$_OLD" awk '
  BEGIN { f = ENVIRON["_LR_F"]; r = ENVIRON["_LR_R"] }
  { while ((p = index($0, f)) > 0) $0 = substr($0, 1, p-1) r substr($0, p+length(f)); print }
' "$T/clean" > "$T/reverted"

_t "L1 되돌린 실물 훅 사본에서 그 자리를 잡는다"
if ! grep -q '“\[\^”\]{2,}”' "$T/reverted"; then
  _no "되돌림 변이가 안 먹었다 — 훅의 가드 형태가 바뀌었다(계기 확인 불가)"
elif [ "$(_rc "$T/reverted")" = "1" ]; then _ok
else _no "되돌렸는데 rc=$(_rc "$T/reverted") (1 이어야) — 린트가 실물 결함을 못 잡는다"; fi

_t "L2 컨트롤 — 손 안 댄 같은 사본은 깨끗하다"
[ "$(_rc "$T/clean")" = "0" ] && _ok \
  || _no "rc=$(_rc "$T/clean") — 지금의 훅에서 오탐이 난다(L1 의 원인이 되돌림이 아니다)"

# ── L3 — 11 중 1 을 놓치게 만든 바로 그 형태. 회귀 자물쇠 ──────────────────────
printf '%s\n' 'b=$(printf %s "$l" | sed -E "s/^[[:space:]]*(①영혼|soul)[^[:alnum:]«]*//")' > "$T/posixclass"
_t 'L3 POSIX 클래스가 든 브래킷도 잡는다 — [^[:alnum:]«] 형태'
[ "$(_rc "$T/posixclass")" = "1" ] && _ok \
  || _no "rc=$(_rc "$T/posixclass") (1 이어야) — 정규식이 `[:alnum:]` 의 첫 `]` 에서 끊겼다. 이게 11 중 1 을 놓친 형태다"

# ── L4 — 오탐 픽스처. 「무엇이든 잡는」 린트는 린트가 아니다 ────────────────────
{
  printf '%s\n' '# 주석 안의 [^—-] 와 [^”] 는 코드가 아니다'
  printf '%s\n' 'x=$(printf %s "$l" | sed -E "s/^(:|—|-)*//")'
  printf '%s\n' 'y=$(printf %s "$l" | grep -oE "[A-Za-z0-9_]+")'
  printf '%s\n' 'z=$(printf %s "$l" | sed -E "s/[[:space:]]+$//")'
  printf '%s\n' 'w="멀티바이트가 브래킷 밖에 있는 것은 —  해당 없다"'
} > "$T/fp"
_t "L4 오탐 픽스처 — 주석·교차·순ASCII·브래킷 밖 멀티바이트"
[ "$(_rc "$T/fp")" = "0" ] && _ok \
  || _no "rc=$(_rc "$T/fp") (0 이어야) — 정당한 형태에서 빨개진다. 과차단은 override 를 훈련시킨다"

_t "L4b 컨트롤 — 같은 파일에 결함 한 줄을 더하면 빨개진다"
cp "$T/fp" "$T/fp_plus"; printf '%s\n' 'v=$(printf %s "$l" | sed -E "s/^[^:—-]*[:—-]//")' >> "$T/fp_plus"
[ "$(_rc "$T/fp_plus")" = "1" ] && _ok \
  || _no "rc=$(_rc "$T/fp_plus") (1 이어야) — L4 의 초록이 «못 잡아서» 일 수 있다(분리능 없음)"

# ── L5 — degrade 방향. 못 읽는 것은 통과가 아니다 ───────────────────────────────
_t "L5 없는 경로는 rc=2 (계기 오류지 통과가 아니다)"
[ "$(_rc "$T/does-not-exist.sh")" = "2" ] && _ok \
  || _no "rc=$(_rc "$T/does-not-exist.sh") (2 여야) — 부재가 초록으로 읽힌다"

# ── L6 — 실물 데이터로 주석 건너뛰기가 실제로 실행되는지 ────────────────────────
# 🟥 2026-09-22 — 이 계수기가 **플랫폼마다 다른 것을 쟀고, CI 는 «틀린 이유로» 초록이었다.**
#    옛 패턴은 브래킷 안에 `[^\x00-\x7F]` 를 썼다. POSIX 브래킷은 `\xNN` 을 «이스케이프» 로
#    안 읽는다 — BSD grep(macOS)은 `invalid character range` 로 **죽고**(rc=2), GNU grep 은
#    그것을 리터럴 `\`·`x`·`0`-`7`·`F` 로 읽어 **유효한 범위**로 받아 넘어간다.
#    ⇒ 같은 레인이 macOS 에서는 계기 오류, CI 에서는 «다른 질문» 에 답하고 있었다.
# 🟥 **더 나쁜 것은 `|| echo 0` 이었다** — 계기가 죽은 것(rc=2)을 «0줄» 이라는 **측정값**으로
#    접었다. 「안 쟀다」가 「0 이었다」로 렌더되는 오늘의 그 일가다. 이제 rc 를 먼저 잡고
#    2 이상이면 **HARNESS-ERROR 로 이름을 붙인다.**
# 이식성 있는 형태: `LC_ALL=C` 에서 `[^ -~]` = ASCII 인쇄 가능 범위의 여집합.
#    실측으로 파이썬 기준값(10)과 **정확히 일치**하고, 탭 오탐은 0 이다.
_ncmt=$(LC_ALL=C grep -c '^[[:space:]]*#.*\[[^]]*[^ -~][^]]*\]' "$HOOK" 2>/dev/null); _ncmt_rc=$?
_t "L6 실물 훅의 주석에 그 형태가 실재하고, 그런데도 깨끗하다"
if [ "$_ncmt_rc" -ge 2 ]; then
  _no "계수기 자신이 rc=$_ncmt_rc 로 죽었다 — HARNESS-ERROR. «0줄» 로 접지 않는다"
elif [ "${_ncmt:-0}" -ge 1 ] && [ "$(_rc "$HOOK")" = "0" ]; then _ok
elif [ "${_ncmt:-0}" -lt 1 ]; then _no "훅 주석에 브래킷+멀티바이트가 0줄 — 이 팔은 아무것도 안 잰다(UNMEASURED)"
else _no "주석 $_ncmt 줄이 있는데 rc=$(_rc "$HOOK") — 주석 건너뛰기가 안 돈다"; fi

# ── L6b — 계수기가 «이 플랫폼에서» 실제로 도는가. L6 의 컨트롤이다 ─────────────
# L6 이 초록이어도 그것이 «세었다» 인지 «못 셌는데 접혔다» 인지 구분되지 않던 자리를 못박는다.
_t "L6b 계수기가 이 플랫폼에서 실행 가능하다(rc<2) — 옛 \\xNN 형태였다면 여기서 적색"
[ "$_ncmt_rc" -lt 2 ] && _ok \
  || _no "rc=$_ncmt_rc — 브래킷 패턴이 이 grep 에서 안 돈다. 이식성 결함이지 «0줄» 이 아니다"

echo "── $([ "$FAIL" -eq 0 ] && echo 'all lanes ok' || echo 'FAILURES above') ──"
exit "$FAIL"

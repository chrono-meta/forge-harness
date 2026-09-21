#!/usr/bin/env bash
# test_gate_bootstrap_ephemeral_lanes.sh — scripts/gate_bootstrap_ephemeral.sh 의 앵커.
#
# SUBJECT 는 그 스크립트의 **판정과 부작용**이다. 두 가지를 본다:
#   ⓐ 종료코드 계약 (0 돈다 / 1 막는 층 남음 / 10 계기 오류)
#   ⓑ 🟥 **증거를 안 만든다** — 이게 이 레인의 하중 지는 자리다. 마커나 매니페스트를
#      자동 생성하는 부트스트랩은 게이트를 «가짜로 닫는» 것이고, `fh_4axis_gate.md` 가
#      이름으로 금지한다. 그래서 L8 은 부작용 부재를 직접 관측한다.
#
# 되돌림 프로브(L10)가 있다: 로케일 차단 줄을 지운 사본에서 판정이 뒤집히지 않으면
# 이 레인은 그 줄에 안 묶여 있는 것이다 — 공허한 초록.
set -u
SUBJ="$(cd "$(dirname "$0")/.." && pwd)/scripts/gate_bootstrap_ephemeral.sh"
[ -f "$SUBJ" ] || { echo "❌ INSTRUMENT ERROR — subject not found: $SUBJ"; exit 10; }
fail=0; n=0
ok()   { n=$((n+1)); echo "  ✅ $1"; }
bad()  { n=$((n+1)); echo "  ❌ $1"; fail=1; }

WORK=$(mktemp -d "${TMPDIR:-/tmp}/gbe_lanes.XXXXXX") || { echo "❌ INSTRUMENT ERROR — mktemp"; exit 10; }
trap 'rm -rf "$WORK"' EXIT

# 픽스처: 최소 forge-harness 모양의 레포 하나
mkfix() {  # $1 = 이름 · $2 = "nohook" 이면 훅 소스를 안 만든다
  local d="$WORK/$1"
  mkdir -p "$d" || return 1
  git -C "$d" init -q 2>/dev/null || return 1
  git -C "$d" config user.email lane@local; git -C "$d" config user.name lane
  if [ "${2:-}" != "nohook" ]; then
    mkdir -p "$d/templates/.git-hooks"; printf '#!/bin/sh\nexit 0\n' > "$d/templates/.git-hooks/pre-commit"
  fi
  printf '%s' "$d"
}

run() { # $1 = cwd · $2 = 로케일 · 나머지 = 인자 → stdout 을 $LAST_OUT, rc 를 $LAST_RC
  local d="$1" loc="$2"; shift 2
  LAST_OUT=$(cd "$d" && LC_ALL="$loc" bash "$SUBJ" "$@" 2>&1); LAST_RC=$?
}

echo "── gate_bootstrap_ephemeral lanes ──"

# L1 — 컨트롤: known-pair 가 분리하는가 (이 기계에 UTF-8 로케일이 있어야 레인이 성립)
LOC_OK=1
if ! bash "$SUBJ" --selftest >/dev/null 2>&1; then
  LOC_OK=0
  echo "  ⚠️  L1 CONTROL — 이 기계에서 로케일 분리가 안 된다. 로케일 의존 레인(L5·L10)은"
  echo "      SKIP 한다. 🟥 «통과»가 아니라 «못 쟀다»다."
else
  ok "L1 CONTROL — known-pair 분리능 있음(--selftest rc=0)"
fi

# L2 — 계기 오류: git 레포가 아니면 10 (통과도 경고도 아니다)
mkdir -p "$WORK/notarepo"; run "$WORK/notarepo" C.UTF-8 --check
[ "$LAST_RC" = 10 ] && ok "L2 not-a-repo → rc=10" || bad "L2 not-a-repo → rc=$LAST_RC (want 10)"

# L3 — 계기 오류: 훅 소스 부재 → 10
D=$(mkfix nohook nohook); run "$D" C.UTF-8 --check
[ "$LAST_RC" = 10 ] && ok "L3 훅 소스 부재 → rc=10" || bad "L3 훅 소스 부재 → rc=$LAST_RC (want 10)"

# L4 — 미배선 + UTF-8 → rc=1 이고 ENFORCE 를 이름으로 지목한다
D=$(mkfix unwired); run "$D" C.UTF-8 --check
if [ "$LAST_RC" = 1 ] && printf '%s' "$LAST_OUT" | grep -q 'ENFORCE'; then
  ok "L4 미배선 → rc=1 · ENFORCE 지목"
else bad "L4 미배선 → rc=$LAST_RC (want 1) / ENFORCE 지목 여부 확인"; fi

# L5 — 배선됐지만 POSIX 로케일 → rc=1 (과차단 방향의 고장도 막는다)
if [ "$LOC_OK" = 1 ]; then
  D=$(mkfix posix); git -C "$D" config --local core.hooksPath templates/.git-hooks
  run "$D" POSIX --check
  if [ "$LAST_RC" = 1 ] && printf '%s' "$LAST_OUT" | grep -q 'BROKEN'; then
    ok "L5 배선+POSIX → rc=1 · LOCALE BROKEN 지목"
  else bad "L5 배선+POSIX → rc=$LAST_RC (want 1)"; fi
else echo "  ⏭️  L5 SKIP (L1 컨트롤 미성립)"; fi

# L6 — --apply 가 배선하고, 그다음 --check 가 UTF-8 에서 rc=0
D=$(mkfix apply); run "$D" C.UTF-8 --apply
if [ "$(git -C "$D" config --local core.hooksPath)" = "templates/.git-hooks" ]; then
  run "$D" C.UTF-8 --check
  [ "$LAST_RC" = 0 ] && ok "L6 --apply 배선 후 --check rc=0" || bad "L6 --apply 후 rc=$LAST_RC (want 0)"
else bad "L6 --apply 가 core.hooksPath 를 안 잡았다"; fi

# L7 — 남이 잡아둔 다른 hooksPath 는 **덮지 않는다**
D=$(mkfix keep); git -C "$D" config --local core.hooksPath .githooks
run "$D" C.UTF-8 --apply
if [ "$(git -C "$D" config --local core.hooksPath)" = ".githooks" ] && [ "$LAST_RC" = 1 ]; then
  ok "L7 기존 hooksPath 보존 + rc=1"
else bad "L7 기존 hooksPath 가 덮였거나 rc=$LAST_RC (want 1)"; fi

# L8 — 🟥 증거를 만들지 않는다 (이 레인의 하중)
D=$(mkfix noevidence); mkdir -p "$D/tracks/_meta"
run "$D" C.UTF-8 --apply
created=$(find "$D/tracks" -type f 2>/dev/null | wc -l | tr -d ' ')
if [ "$created" = "0" ]; then
  ok "L8 증거 무생성 — tracks/ 아래 파일 0 개 (마커도 매니페스트도 안 만든다)"
else
  bad "L8 증거를 만들었다 — tracks/ 아래 $created 개. 게이트를 가짜로 닫는 형태다"
  find "$D/tracks" -type f | sed 's/^/        /'
fi

# L9 — 전역 config 를 안 건드린다 (사용자 기계 설정 불가침)
G_BEFORE=$(git config --global --get core.hooksPath 2>/dev/null || printf '(unset)')
D=$(mkfix global); run "$D" C.UTF-8 --apply
G_AFTER=$(git config --global --get core.hooksPath 2>/dev/null || printf '(unset)')
[ "$G_BEFORE" = "$G_AFTER" ] && ok "L9 전역 core.hooksPath 불변 ($G_AFTER)" \
  || bad "L9 전역 config 가 바뀌었다: $G_BEFORE → $G_AFTER"

# L10 — 되돌림 프로브. 로케일 차단 줄(BLOCK=1)을 지운 사본에서 L5 가 뒤집혀야 한다.
if [ "$LOC_OK" = 1 ]; then
  CP="$WORK/subject_reverted.sh"
  awk '
    /^  # 🟥 여기서 \*\*막는다\.\*\*/ { skipping=1 }
    skipping && /^  BLOCK=1$/        { skipping=0; next }
    { print }
  ' "$SUBJ" > "$CP"
  if cmp -s "$SUBJ" "$CP"; then
    bad "L10 되돌림 프로브가 아무것도 안 지웠다 — 프로브가 대상에 안 묶여 있다(계기 오류)"
  else
    D=$(mkfix revert); git -C "$D" config --local core.hooksPath templates/.git-hooks
    R_OUT=$(cd "$D" && LC_ALL=POSIX bash "$CP" --check 2>&1); R_RC=$?
    if [ "$R_RC" = 0 ]; then
      ok "L10 되돌림 — 그 줄을 지우면 POSIX 팔이 rc=0 으로 뒤집힌다 (레인이 그 줄에 묶였다)"
    else
      bad "L10 되돌림 — 줄을 지워도 rc=$R_RC. L5 의 초록은 다른 이유에서 온 것이다"
    fi
  fi
else echo "  ⏭️  L10 SKIP (L1 컨트롤 미성립)"; fi

# ── L11 — 절대경로로 잡힌 같은 훅은 WIRED 다 (과차단 회귀) ─────────────────────
#   실측 2026-09-21(운영자 맥): `core.hooksPath` 가 `/…/templates/.git-hooks` 로 잡혀 있으면
#   문자열 비교가 «다른 값» 으로 읽어 BLOCK=1 을 냈다. 같은 디렉터리인데 표기만 달랐다.
#   절대경로는 이 레포가 문서로 인정하는(그리고 워크트리 우회가 없는) 설정이라 과차단이다.
D=$(mkfix abswired); git -C "$D" config --local core.hooksPath "$D/templates/.git-hooks"
A_OUT=$(cd "$D" && bash "$SUBJ" --check 2>&1)
n=$((n+1))
if printf '%s' "$A_OUT" | grep -q "✅ WIRED"; then
  ok "L11 절대경로로 잡힌 같은 훅 → WIRED (과차단 없음)"
else
  bad "L11 절대경로 형태가 WIRED 로 안 읽힌다 — 같은 디렉터리인데 과차단이다"
fi

# ── L11b — 알려진 음성: **진짜 다른** 훅 디렉터리는 종전대로 건드리지 않는다 ──────
#   L11 이 «무엇이든 WIRED 라고 말하는» 완화가 아님을 보인다. 이 팔이 없으면 L11 은
#   가드를 통째로 무력화해도 초록이다.
D2=$(mkfix absforeign); mkdir -p "$D2/other-hooks"
git -C "$D2" config --local core.hooksPath "$D2/other-hooks"
F_OUT=$(cd "$D2" && bash "$SUBJ" --check 2>&1)
n=$((n+1))
if printf '%s' "$F_OUT" | grep -q "다른 값이 잡혀 있다"; then
  ok "L11b 알려진 음성 — 진짜 다른 훅 디렉터리는 여전히 ⚠️ 로 남는다"
else
  bad "L11b 다른 훅 디렉터리까지 WIRED 로 읽는다 — 가드가 무력화됐다"
fi

echo "── $n lanes · $([ "$fail" = 0 ] && echo 'ALL PASS' || echo 'FAIL') ──"
exit "$fail"

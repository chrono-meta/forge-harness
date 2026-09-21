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

mkshim() {  # $1 = 이름 · $2 = 한글 입력에 적용할 보정식(shell 산술, n = 실제 낱말 수)
  local d="$WORK/shim_$1"; mkdir -p "$d"
  cat > "$d/tr" <<SHIM
#!/usr/bin/env bash
# 낱말-분리 호출만 가로챈다. 다른 tr 호출은 진짜 tr 로 넘긴다.
if [ "\$1" = "-s" ] && [ "\$2" = ' \t\n' ]; then
  in=\$(cat); n=\$(printf '%s' "\$in" | /usr/bin/tr -s ' \t\n' '\n' | LC_ALL=C grep -c '.')
  # 비ASCII 범위를 쓰지 않는다 — 한글 범위는 바이트 로케일에서 바이트 집합으로 퇴화하고,
  # GNU grep 은 C 로케일에서 exit 2 로 죽어 결과가 «무매치» 로 읽힌다. 이 레포의
  # locale-range lint 가 내 초판에서 바로 이 줄을 잡았다 (#780/#784 와 같은 클래스).
  # 그래서 «출력 가능한 ASCII 밖의 바이트가 있나» 를 ASCII 범위로만 묻는다.
  case "\$in" in *[!\ -~]*) n=\$(( $2 ));; esac
  i=0; while [ "\$i" -lt "\$n" ]; do echo x; i=\$((i+1)); done
else exec /usr/bin/tr "\$@"; fi
SHIM
  chmod +x "$d/tr"; printf '%s' "$d"
}
runshim() { # $1 = cwd · $2 = shim dir · 나머지 = 인자
  local d="$1" sh="$2"; shift 2
  LAST_OUT=$(cd "$d" && LC_ALL=C.UTF-8 PATH="$sh:$PATH" bash "$SUBJ" "$@" 2>&1); LAST_RC=$?
}

echo "── gate_bootstrap_ephemeral lanes ──"

# L1 — 컨트롤: known-pair 가 분리하는가 (이 기계에 UTF-8 로케일이 있어야 레인이 성립)
#      🟥 `--selftest` 는 **현재 환경**을 재므로(selfcheck.sh 가 그 뜻으로 쓴다) 여기서는
#         로케일을 명시해서 부른다. 안 그러면 POSIX 가 기본인 컨테이너에서 컨트롤이 죽어
#         아래 레인들이 통째로 SKIP 된다 — 「못 쟀다」가 「통과」로 보이는 자리다.
LOC_OK=1
if ! LC_ALL=C.UTF-8 bash "$SUBJ" --selftest >/dev/null 2>&1; then
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

# L5 — 🟥 의미가 뒤집혔다, 그리고 그 이유가 이 PR 의 내용이다.
#      종전 L5 는 «배선 + POSIX → rc=1 BROKEN» 이었다. PR #780(머지됨)이 훅의 낱말 셈을
#      로케일 불변으로 바꿔서 **POSIX 가 더는 안 깨진다** — 계기도 그 셈법을 따라가므로 이
#      팔은 «안 깨진다»를 확인하는 방향이 된다. 🟥 그 전환이 안 되면 **훅은 통과하는데
#      계기만 커밋하지 말라고 하는 거짓 빨강**이 된다(주간 감사 갈래가 #784 브랜치의 훅과
#      나란히 돌려 관측). 차단 방향은 사라진 게 아니라 **L14b 로 옮겼다** — 로케일이 아니라
#      셈이 고장난 기계를 shim 으로 만든다. 레인의 의미가 뒤집힌 것과 커버리지가 준 것은
#      다르므로, 조용히 바꾸지 않고 여기 적는다.
if [ "$LOC_OK" = 1 ]; then
  D=$(mkfix posix); git -C "$D" config --local core.hooksPath templates/.git-hooks
  run "$D" POSIX --check
  if [ "$LAST_RC" = 0 ]; then
    ok "L5 배선+POSIX → rc=0 (#780 이후 로케일이 낱말 바닥을 안 바꾼다)"
  else bad "L5 배선+POSIX → rc=$LAST_RC (want 0) — 훅은 통과하는데 계기만 막는 거짓 빨강이다"; fi
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

# L10 — 되돌림 프로브: 로케일 차단 줄(BLOCK=1)을 지운 사본에서 판정이 뒤집혀야 한다.
#       🟥 구동 팔이 «POSIX» 에서 «미달 셈 shim» 으로 바뀌었다 — #780 이후 POSIX 자체는
#       안 깨지므로(위 L5), 차단을 만드는 것은 로케일이 아니라 깨진 셈이다.
if [ "$LOC_OK" = 1 ] && [ -x /usr/bin/tr ]; then
  CP="$WORK/subject_reverted.sh"
  awk '
    /^  # 🟥 여기서 \*\*막는다\.\*\*/ { skipping=1 }
    skipping && /^  BLOCK=1$/        { skipping=0; next }
    { print }
  ' "$SUBJ" > "$CP"
  if cmp -s "$SUBJ" "$CP"; then
    bad "L10 되돌림 프로브가 아무것도 안 지웠다 — 프로브가 대상에 안 묶여 있다(계기 오류)"
  else
    _S10=$(mkshim revunder '0')
    D=$(mkfix revert); git -C "$D" config --local core.hooksPath templates/.git-hooks
    R_RC=0; (cd "$D" && LC_ALL=C.UTF-8 PATH="$_S10:$PATH" bash "$CP" --check >/dev/null 2>&1) || R_RC=$?
    if [ "$R_RC" = 0 ]; then
      ok "L10 되돌림 — 그 줄을 지우면 미달 셈 팔이 rc=0 으로 뒤집힌다 (레인이 그 줄에 묶였다)"
    else
      bad "L10 되돌림 — 줄을 지워도 rc=$R_RC. L14b 의 초록은 다른 이유에서 온 것이다"
    fi
  fi
else echo "  ⏭️  L10 SKIP (컨트롤 미성립 또는 /usr/bin/tr 부재)"; fi

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

# ── ②LOCALE 바닥 판정 known-pair (운영자 맥 리뷰 2 — PR #783, 05:35) ──────────
# 🟥 **재현이 이 컨테이너에서 돈다.** 「남의 기계에서만 보이는 결함」을 그 기계 없이 붙잡는
#    유일한 방법이라 **셈법을 갈아끼운다**. 갈아끼우는 대상은 훅이 지금 쓰는 파이프라인의
#    `tr` 이다 — #780 이후 `wc -w` 는 훅에도 계기에도 없다.
# 재는 것: 판정이 **바닥 비교**인가. 초과는 결함이 아니고 미달만 결함이다. 등식 판정은 토큰
#    안을 쪼개는 셈만으로 멀쩡한 기계를 BROKEN 으로 찍고, `selfcheck.sh` 가 이 레인을 돌리므로
#    본진이 통째로 빨개진다.
if [ -x /usr/bin/tr ]; then
  # L14 — 알려진 양성(회귀): 토큰 안을 쪼개는 셈(초과) → BROKEN 이 아니어야 한다
  S_OVER=$(mkshim over 'n+1')
  D=$(mkfix bsdlike); git -C "$D" config --local core.hooksPath templates/.git-hooks
  runshim "$D" "$S_OVER" --check
  if [ "$LAST_RC" = 0 ] && printf '%s' "$LAST_OUT" | grep -q '② LOCALE' \
     && ! printf '%s' "$LAST_OUT" | grep -q 'BROKEN'; then
    ok "L14 초과 셈 → BROKEN 아님 · rc=0 (과차단 회귀)"
  else bad "L14 초과 셈을 BROKEN 으로 찍었다 (rc=$LAST_RC) — 멀쩡한 기계가 빨개지는 그 자리다"; fi

  # L14b — 알려진 음성: 미달 셈(한글을 0 으로) → BROKEN · rc=1
  #        L14 가 «검사를 꺼서» 초록이 된 게 아님을 보인다. 차단 방향이 여기 달렸다.
  S_UNDER=$(mkshim under '0')
  D=$(mkfix underlike); git -C "$D" config --local core.hooksPath templates/.git-hooks
  runshim "$D" "$S_UNDER" --check
  if [ "$LAST_RC" = 1 ] && printf '%s' "$LAST_OUT" | grep -q 'BROKEN'; then
    ok "L14b 미달 셈 → BROKEN · rc=1 (바닥이 살아 있다)"
  else bad "L14b 미달 셈을 놓쳤다 (rc=$LAST_RC) — 바닥 검사가 무력화됐다"; fi

  # L14c — 알려진 음성 2: 공허한 한글까지 바닥을 넘는 셈 → HARNESS-ERROR 10
  #        내 수리의 fail-open 방향을 막는다 — 「무엇이든 넘으면 OK」면 계기가 죽은 것이다.
  S_CHAR=$(mkshim char 'n+40')
  D=$(mkfix charlike); git -C "$D" config --local core.hooksPath templates/.git-hooks
  runshim "$D" "$S_CHAR" --check
  if [ "$LAST_RC" = 10 ]; then
    ok "L14c 공허한 한글까지 넘는 셈 → rc=10 HARNESS-ERROR (분리 불가를 통과로 안 접는다)"
  else bad "L14c 공허가 바닥을 넘는데 rc=$LAST_RC — 계기 사망을 통과로 접었다"; fi

  # L14d — 되돌림 프로브: 바닥 비교를 **등식**으로 되돌리면 L14 가 뒤집힌다
  CP3="$WORK/subject_equality.sh"
  sed 's/^  \[ "\$n" -ge "\$_FLOOR" \] 2>\/dev\/null$/  [ "$n" = "$_FLOOR" ] 2>\/dev\/null/' "$SUBJ" > "$CP3"
  if cmp -s "$SUBJ" "$CP3"; then
    bad "L14d 되돌림 프로브가 아무것도 안 바꿨다 — 프로브가 대상에 안 묶여 있다(계기 오류)"
  else
    D=$(mkfix revert_floor); git -C "$D" config --local core.hooksPath templates/.git-hooks
    R3_RC=0; (cd "$D" && LC_ALL=C.UTF-8 PATH="$S_OVER:$PATH" bash "$CP3" --check >/dev/null 2>&1) || R3_RC=$?
    if [ "$R3_RC" != 0 ]; then
      ok "L14d 되돌림 — 바닥 비교를 등식으로 바꾸면 L14 가 rc=$R3_RC 로 뒤집힌다"
    else
      bad "L14d 되돌림 — 등식으로 바꿔도 rc=0. L14 의 초록은 다른 이유에서 온 것이다"
    fi
  fi
else
  echo "  ⏭️  L14~L14d SKIP — /usr/bin/tr 가 없어 shim 을 못 만든다. 🟥 «통과»가 아니라 «못 쟀다»다."
fi

# ── L15 — 배선: 계기가 «훅이 지금 쓰는 셈법»을 재는가 ─────────────────────────
# 🟥 목록이 아니라 **관계**를 박는다. 계기가 훅과 다른 셈법을 쓰면 훅이 막는 것과 다른 것을
#    재고, 그 어긋남은 두 방향으로 샌다 — 조용한 초록, 그리고 **거짓 빨강**(훅은 통과하는데
#    계기만 커밋하지 말라고 한다). 실제로 후자가 났다: 초판은 `wc -w` 를 썼고, #780 이 훅을
#    `tr`/`grep` 으로 바꿔 머지된 순간 계기만 옛 셈법에 남았다.
HOOK="$(cd "$(dirname "$0")/.." && pwd)/templates/.git-hooks/pre-commit"
PIPE="tr -s ' \t\n' '\n' | LC_ALL=C grep -c"
if [ ! -f "$HOOK" ]; then
  echo "  ⏭️  L15 SKIP — 훅 파일이 없다(소비자 트리). 🟥 «통과»가 아니라 «못 쟀다»다."
else
  h_hits=$(grep -cF "$PIPE" "$HOOK" 2>/dev/null); h_hits=${h_hits:-0}
  s_hits=$(grep -cF "$PIPE" "$SUBJ" 2>/dev/null); s_hits=${s_hits:-0}
  if [ "$h_hits" -gt 0 ] && [ "$s_hits" -gt 0 ]; then
    ok "L15 배선 — 훅($h_hits 곳)과 계기($s_hits 곳)가 같은 낱말 셈법을 쓴다"
  elif [ "$h_hits" = 0 ]; then
    bad "L15 훅의 셈법이 바뀌었다 — gate_bootstrap_ephemeral.sh 의 _words() 와 _FLOOR 를 따라가게 고쳐라"
  else
    bad "L15 계기가 훅과 다른 셈법을 쓴다 — 거짓 빨강이나 조용한 초록이 된다"
  fi
fi
echo "── $n lanes · $([ "$fail" = 0 ] && echo 'ALL PASS' || echo 'FAIL') ──"
exit "$fail"

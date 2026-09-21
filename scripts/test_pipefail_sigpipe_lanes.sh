#!/usr/bin/env bash
# test_pipefail_sigpipe_lanes.sh — `set -o pipefail` × 조기종료 소비자 × 64 KiB 파이프 버퍼.
#
# 무엇을 막나: `생산자 | grep -q 패턴` 은 **패턴을 찾았을 때** 실패로 읽힐 수 있다.
# `grep -q` 가 첫 매치에서 즉시 종료하는데 생산자가 아직 버퍼보다 많이 쓸 것이 남아 있으면
# SIGPIPE 로 죽어 141 을 남기고, `pipefail` 이 그 141 을 파이프라인 종료코드로 올린다.
# ⇒ **찾았는데 `if` 는 거짓이 된다.** 무매치일 때는 grep 이 EOF 까지 읽으므로 안 난다 —
#    즉 이 결함은 **통과해야 할 때만 거짓 빨강을 낸다.** fail-open 은 아니지만, 그 거짓
#    빨강이 정확히 «재실행으로 넘기기» 를 훈련시킨다.
#
# 🟥 판별자는 「파일이 크다」가 아니라 **「매치 이후 남은 바이트가 파이프 버퍼를 넘나」** 다.
#    버퍼 안에 다 들어가면 생산자는 소비자가 읽기도 전에 정상 종료하므로 경합 자체가 없다.
#    그래서 L3 이 있다 — 그 줄이 없으면 이 레인은 「파이프는 다 나쁘다」라는 과차단이 된다.
#
# 실사고(2026-09-21): `scripts/sync_to_be_lanes.sh:579` 가 70,726 B 짜리
# `scripts/sync-to-be.sh` 를 흘려 `grep -q` 로 받았고(매치 이후 17,918 B 잔여),
# PR #782 의 `validate` 가 **같은 커밋에서** push 회차 초록 · pull_request 회차 빨강으로 갈렸다.
# 실측 4/200. 이 레인은 그 구멍을 재현하고(L1) 수리가 실제로 닫았는지 본다(L4).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); printf '  ✅ %s\n' "$1"; }
no(){ FAIL=$((FAIL+1)); printf '  ❌ %s — %s\n' "$1" "${2:-}"; }
echo "── test_pipefail_sigpipe_lanes ──"

D="$(mktemp -d)"
trap '/bin/rm -rf "$D"' EXIT

# 픽스처: 매치는 1 행, 그 뒤로 ~300 KB — 버퍼(64 KiB)를 확실히 넘긴다.
{ echo "NEEDLE_HERE"; head -c 300000 /dev/zero | tr '\0' 'x' | fold -w 100; } > "$D/over.txt"
# 대조 픽스처: 통째로 버퍼 안.
{ echo "NEEDLE_HERE"; echo small; } > "$D/under.txt"
_sz(){ wc -c < "$1" | tr -d ' '; }
[ "$(_sz "$D/over.txt")" -gt 65536 ] && ok "L0 픽스처가 버퍼(65536 B)를 넘는다 ($(_sz "$D/over.txt") B)" \
  || no "L0 픽스처" "$(_sz "$D/over.txt") B — 안 넘으면 아래 known-positive 가 뜨지 않는다"

# ── L1 known-POSITIVE: 취약한 형태는 «찾았는데» 실패로 읽힌다 ──────────────────────
# 결정적이다 — 300 KB 를 64 KiB 버퍼에 못 밀어 넣으므로 생산자는 반드시 블록되고,
# grep 은 1 행에서 이미 끝났다. (확률적 레인은 그 자신이 flaky 가 되므로 쓰지 않는다.)
_n=0
for _i in 1 2 3 4 5 6 7 8 9 10; do
  ( set -uo pipefail; sed -n '1,$p' "$D/over.txt" | grep -q NEEDLE_HERE ) || _n=$((_n+1))
done
[ "$_n" -eq 10 ] && ok "L1 known-positive: 취약 형태가 10/10 뒤집힌다 (매치했는데 rc≠0)" \
  || no "L1 known-positive" "$_n/10 만 뒤집혔다 — 계기가 이 결함을 재현 못 하면 L4 의 초록은 증거가 아니다"

# grep 자신은 실제로 찾았다는 것을 따로 못 박는다 — 「안 찾아서 1」과 구별한다.
_grc=$( { sed -n '1,$p' "$D/over.txt" | grep -c NEEDLE_HERE ; } 2>/dev/null )
[ "${_grc:-0}" -ge 1 ] && ok "L2 그 파이프의 grep 은 실제로 매치한다 (무매치 1 과 다른 사건이다)" \
  || no "L2" "grep -c = ${_grc:-?}"

# ── L3 과차단 방지: 버퍼 안이면 같은 형태도 안전하다 ─────────────────────────────
_n=0
for _i in $(seq 1 50); do
  ( set -uo pipefail; sed -n '1,$p' "$D/under.txt" | grep -q NEEDLE_HERE ) || _n=$((_n+1))
done
[ "$_n" -eq 0 ] && ok "L3 버퍼 안 생산자는 0/50 — 판별자는 «크기» 가 아니라 «잔여 바이트» 다" \
  || no "L3 과차단" "$_n/50 — 이 값이 0 이 아니면 위 판별자 서술이 틀린 것이다"

# ── L4 수리된 형태: 파이프가 없으면 경합할 상대가 없다 ───────────────────────────
_n=0
for _i in $(seq 1 50); do
  ( set -uo pipefail; grep -q NEEDLE_HERE "$D/over.txt" ) || _n=$((_n+1))
done
[ "$_n" -eq 0 ] && ok "L4 수리 형태(파일 직접 grep)는 같은 픽스처에서 0/50" \
  || no "L4" "$_n/50 — 수리가 안 닫았다"

# ── L5/L6 실사고 자리 자체: sync_to_be_lanes.sh:A 가 수리된 형태인가 ─────────────
SUT="$REPO/scripts/sync_to_be_lanes.sh"

# 판정을 함수로 뽑는다 — L8 이 **같은 코드**를 되돌린 사본에 걸어야 하기 때문이다.
# 레인이 자기 판정을 다시 적으면 대상이 되돌아가도 통과한다([[feedback_anchor_can_be_decorative]]).
_sut_verdict(){  # FIXED | VULNERABLE | MISSING
  [ -f "$1" ] || { echo MISSING; return; }
  # 🟥 주석 줄은 뺀다 — 수리 자리의 «왜» 주석이 그 형태를 **인용**하고 있어서, 안 빼면
  #    자기 근거 문장에 걸려 빨개진다(초판이 실제로 그랬다). 코드 줄만 본다.
  if /usr/bin/grep -n '_sync_src | grep -q' "$1" | /usr/bin/grep -qv ':[[:space:]]*#'; then
    echo VULNERABLE; return
  fi
  /usr/bin/grep -q 'if grep -q .tar cf - ' "$1" && echo FIXED || echo VULNERABLE
}

_V="$(_sut_verdict "$SUT")"
[ "$_V" = FIXED ] && ok "L5 실사고 자리가 수리 형태다 (파일을 직접 grep, 취약 형태는 코드 줄에 없다)" \
  || no "L5" "판정 = $_V"

# ── L6 되돌림 프로브: 그 판정이 장식이 아님을 같은 실행에서 증명한다 ────────────────
# 적용확인 → 실행 → (사본이므로 복원 불요). 되돌린 사본이 FIXED 로 나오면 L5 의 초록은 무의미하다.
if [ "$_V" = MISSING ]; then
  no "L6 되돌림 프로브" "대상이 없어 되돌릴 것이 없다"
else
  sed 's/^  if grep -q .tar cf - .*$/  if _sync_src | grep -q '"'"'tar cf - "\\${tex\\[@\\]}"'"'"'; then/' \
    "$SUT" > "$D/sut_reverted.sh"
  if /usr/bin/grep -n '_sync_src | grep -q' "$D/sut_reverted.sh" | /usr/bin/grep -qv ':[[:space:]]*#'; then
    ok "L6a 되돌림 적용됨 (수리 자리를 옛 파이프 형태로)"
    [ "$(_sut_verdict "$D/sut_reverted.sh")" = VULNERABLE ] \
      && ok "L6b 되돌린 사본은 VULNERABLE 로 판정된다 (L5 가 장식이 아니다)" \
      || no "L6b 장식" "되돌렸는데도 FIXED 로 읽는다 — 이 앵커는 아무것도 안 막는다"
  else
    no "L6a 되돌림 미적용" "sed 가 아무것도 안 바꿨다 — L6b 는 증거가 아니다"
  fi
fi

# ── L7 수리가 «검사 자체» 를 약화시키지 않았나 ──────────────────────────────────
# 🟥 경합만 없애고 판별력을 잃으면 그건 수리가 아니라 무음화다.
#    대상 사본에서 tar 배열을 손목록으로 되돌리고, 수리된 형태가 여전히 적발하는지 본다.
TGT="$REPO/scripts/sync-to-be.sh"
if [ ! -f "$TGT" ]; then
  no "L7 대상 부재" "$TGT"
else
  ( set -uo pipefail; grep -q 'tar cf - "\${tex\[@\]}"' "$TGT" ) \
    && ok "L7a 컨트롤: 손 안 댄 대상에서 수리 형태가 배열을 찾는다" \
    || no "L7a 컨트롤" "찾지 못했다 — 아래 되돌림 판정은 증거가 아니다"
  sed 's/tar cf - "${tex\[@\]}"/tar cf - --exclude=logs --exclude=.git/' "$TGT" > "$D/reverted.sh"
  if grep -q 'tar cf - --exclude=logs' "$D/reverted.sh"; then
    ok "L7b 되돌림 적용됨 (배열 → 손목록)"
    ( set -uo pipefail; grep -q 'tar cf - "\${tex\[@\]}"' "$D/reverted.sh" ) \
      && no "L7c 판별력 상실" "손목록으로 되돌렸는데도 통과한다 — 수리가 검사를 무음화했다" \
      || ok "L7c 손목록으로 되돌리면 수리 형태가 rc≠0 으로 적발한다 (판별력 유지)"
  else
    no "L7b 되돌림 미적용" "sed 가 아무것도 안 바꿨다 — L7c 는 증거가 아니다"
  fi
fi

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || { echo "FAILED=1"; exit 1; }
exit 0

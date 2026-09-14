#!/usr/bin/env bash
# 레인 — scripts/remote_marker_gate.sh 의 판별력.
#
# 🟥 «FAIL 0» 이 «검사가 도는 것» 을 증명하지 않는다. 합성 레포 픽스처로 양·음성을 둘 다 보인다.
# 🟥 그리고 컨트롤이 **살아 있는지** 를 값으로 찍는다 — 죽은 컨트롤은 깨끗한 대상의 0 과
#    똑같이 생겼다([[feedback_catches_come_from_two_signals_disagreeing]]).
set -u
SRC_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0; FAIL=0
ok(){ printf '  ✅ %s\n' "$1"; PASS=$((PASS+1)); }
ng(){ printf '  ❌ %s\n' "$1"; FAIL=$((FAIL+1)); }

TMPD=$(mktemp -d); trap 'rm -rf "$TMPD"' EXIT

# ── 픽스처 레포 ──────────────────────────────────────────────────────────────
FX="$TMPD/repo"
mkdir -p "$FX/scripts" "$FX/templates" "$FX/plugins/fh-meta/skills/demo" "$FX/docs"
cp "$SRC_ROOT/scripts/remote_marker_gate.sh" "$FX/scripts/"
cp "$SRC_ROOT/templates/regression_guard.sh" "$FX/templates/"
cd "$FX" || exit 2
git init -q -b main .
git config user.email t@t; git config user.name t
echo "base" > README.md
echo "# demo" > plugins/fh-meta/skills/demo/SKILL.md
git add -A >/dev/null; git commit -qm "base"
git branch -f _base main            # BASE_REF 로 쓸 로컬 ref (origin 없음)

# $1=브랜치 $2=바꿀 파일 $3=커밋메시지
mk(){ git checkout -q -B "$1" _base; printf 'changed %s\n' "$(date +%s%N)" >> "$2"; git add "$2" >/dev/null; git commit -q -F - <<EOF
$3
EOF
}
run(){ RMG_BASE_REF=_base RMG_HEAD_REF="$(git rev-parse --abbrev-ref HEAD)" bash scripts/remote_marker_gate.sh 2>&1; }

FULL='frontier-auto: demo

axes-run: ⓐ=none ⓑ=→standpoint ⓒ=출처 직독 ⓓ=none ⓔ=none ⓕ=none
crossfamily: DEGRADED_PANEL_UNUSED — 코드 0줄이라 패널보다 출처 직독이 강한 계기
standpoint: not-applicable — 소비자 가시 동작이 안 바뀐다(산문 한 문단)'

echo "== 컨트롤 — 경로 정본 추출이 살아 있나 =="
SPEC=$(awk '/^GUARD_PATHSPEC=\(/{f=1;next} f&&/^\)/{exit} f' templates/regression_guard.sh \
       | sed -E "s/#.*$//" | sed -E "s/^[[:space:]]*'//; s/'[[:space:]]*$//" | /usr/bin/grep -vE '^[[:space:]]*$')
NSPEC=$(printf '%s\n' "$SPEC" | /usr/bin/grep -c .)
printf '     추출 패턴 수 = %s\n' "$NSPEC"
printf '%s\n' "$SPEC" | /usr/bin/grep -qx 'CLAUDE.md' \
  && ok "C0-a known-positive: 정본 배열에서 'CLAUDE.md' 를 뽑는다 (추출 $NSPEC 개)" \
  || ng "C0-a 컨트롤 사망 — 파서가 정본 배열을 못 읽는다. 아래 레인 전부 UNCALIBRATED"
# 🟥 known-negative 를 한 번 잘못 골랐다(2026-09-14): 'README.md' 를 «자산 아님» 으로 잡았는데
#    정본 배열에 `README*.md` 가 실재한다. 계기가 옳고 **픽스처가 틀렸다** — 그래서 지금은
#    «파일 하나» 가 아니라 «전칭 패턴이 새어들어왔나» 를 본다(과추출의 진짜 얼굴).
if printf '%s\n' "$SPEC" | /usr/bin/grep -qxE '\*|\*\*|\.|\./\*'; then
  ng "C0-b known-negative 오탐 — 전칭 패턴(*)이 추출됐다. 무엇이든 «자산» 으로 읽힌다"
else
  ok "C0-b known-negative: 전칭 패턴(* · ** · .)은 안 뽑는다(과추출 아님)"
fi

echo
echo "== 판별력 (known-pair) =="
mk claude/frontier-auto-x plugins/fh-meta/skills/demo/SKILL.md "frontier-auto: 마커 없음"
out=$(run); rc=$?
[ "$rc" -eq 1 ] && ok "P1 known-positive: 플로어없는채널 + FH자산 + 마커없음 → rc=1" \
                || ng "P1 놓쳤다 (rc=$rc) — 이 레인은 UNCALIBRATED 다"

mk claude/frontier-auto-y plugins/fh-meta/skills/demo/SKILL.md "$FULL"
out=$(run); rc=$?
[ "$rc" -eq 0 ] && ok "N1 known-negative: 같은 채널·같은 자산인데 마커 3필드 있음 → rc=0" \
                || ng "N1 과차단 (rc=$rc) — 정상 기록을 막는다. override 훈련기다: $(printf '%s' "$out" | tail -3)"

# 🟥 README.md 를 쓰면 안 된다 — 정본 배열에 `README*.md` 가 있다(위 C0-b 주석).
mkdir -p notes; : > notes/scratch.txt; git add notes/scratch.txt >/dev/null
git commit -qm "fixture: non-asset file" >/dev/null; git branch -f _base HEAD
mk claude/frontier-auto-z notes/scratch.txt "frontier-auto: 자산 아님"
out=$(run); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | /usr/bin/grep -q "FH 자산을 건드리지 않았다"; then
  ok "N2: 같은 채널인데 FH 자산 미접촉 → rc=0 PASS(‘자산 0’ 이라고 말하고 통과)"
else ng "N2 어긋남 (rc=$rc) — 자산 판별이 안 듣는다"; fi

mk fix/normal-branch plugins/fh-meta/skills/demo/SKILL.md "fix: 마커 없음(로컬 훅 관할)"
out=$(run); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | /usr/bin/grep -q "SKIP"; then
  ok "N3 과차단 방지: 보통 브랜치 + FH자산 + 마커없음 → rc=0 SKIP(이중 요구 안 한다)"
else ng "N3 과차단 (rc=$rc) — 보통 브랜치까지 막으면 만족 불가능한 게이트다"; fi

mk claude/frontier-auto-v plugins/fh-meta/skills/demo/SKILL.md "frontier-auto: 자리표시자

axes-run: ⓐ=none ⓑ=→standpoint ⓒ=x ⓓ=x ⓔ=x ⓕ=x
crossfamily: <value>
standpoint: not-applicable — 산문"
out=$(run); rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | /usr/bin/grep -q "공허한 필드"; then
  ok "P2: 필드는 있는데 자리표시자(\`<value>\`) → rc=1 (존재≠기록)"
else ng "P2 놓쳤다 (rc=$rc) — 자리표시자가 기록으로 계상된다"; fi

echo
echo "== 분리 축 — 체크아웃한 HEAD ≠ 검사 대상 ref =="
# 🟥 이 레인이 없어서 초판의 리터럴 `...HEAD` 버그를 **10개 레인이 전부 통과시켰다**(2026-09-14).
#    위 레인들은 전부 대상 브랜치를 체크아웃한 채로 돌려서 둘이 늘 같았다 — 계기가 그 축을
#    아예 안 잰 것이지 결함이 없던 게 아니다([[feedback_three_reasons_a_lane_is_green]] ②).
#    실물 PR 사후 재현(체크아웃=내 브랜치, 과녁=fetch 한 ref)에서 처음 갈라졌다.
mk claude/frontier-auto-split plugins/fh-meta/skills/demo/SKILL.md "frontier-auto: 마커 없음"
TARGET=$(git rev-parse --abbrev-ref HEAD)
git checkout -q _base                      # ← 체크아웃만 딴 데로 옮긴다. 과녁은 그대로
out=$(RMG_BASE_REF=_base RMG_HEAD_REF="$TARGET" bash scripts/remote_marker_gate.sh 2>&1); rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | /usr/bin/grep -q "FH 자산 1 개"; then
  ok "S1: 다른 브랜치에 서서 과녁 ref 를 검사해도 그 ref 의 diff 를 본다(자산 1개, rc=1)"
else
  ng "S1 어긋남 (rc=$rc) — 체크아웃한 HEAD 를 보고 있다. 대상이 아니라 «내가 선 자리»를 잰다: $(printf '%s' "$out" | /usr/bin/grep -cE '^     ') 개 파일"
fi
git checkout -q "$TARGET"

echo
echo "== 계기 고장은 «통과» 가 아니다 (부재 ≠ 0) =="
mk claude/frontier-auto-h plugins/fh-meta/skills/demo/SKILL.md "frontier-auto: $FULL"
mv templates/regression_guard.sh templates/_hidden.sh
out=$(run); rc=$?
[ "$rc" -eq 10 ] && ok "H1: 경로 정본을 못 읽으면 rc=10 HARNESS-ERROR (0 도 1 도 아니다)" \
                 || ng "H1 어긋남 (rc=$rc) — 계기 부재가 판정으로 접혔다"
mv templates/_hidden.sh templates/regression_guard.sh

mk claude/frontier-auto-anc plugins/fh-meta/skills/demo/SKILL.md "frontier-auto: 마커 없음"
ANC=$(git rev-parse --abbrev-ref HEAD); ANC_SHA=$(git rev-parse HEAD)
# base 를 head 보다 **엄밀히 앞서게** 만든다 — 그래야 head 가 진부분 조상이 된다
# (동일 커밋은 H4 가 담당한다: 그건 퇴화가 아니라 정직한 «변경 없음»).
echo "later" >> plugins/fh-meta/skills/demo/SKILL.md; git add -A >/dev/null
git commit -qm "base moved ahead"; git branch -f _after HEAD
git checkout -q "$ANC_SHA" 2>/dev/null; git checkout -q -B "$ANC" "$ANC_SHA"
out=$(RMG_BASE_REF=_after RMG_HEAD_REF="$ANC" bash scripts/remote_marker_gate.sh 2>&1); rc=$?
[ "$rc" -eq 10 ] && ok "H3: head 가 base 의 조상이면 rc=10 — «변경 0» 을 «자산 미접촉» 으로 안 읽는다" \
                 || ng "H3 어긋남 (rc=$rc) — 퇴화 비교의 0 이 통과로 접힌다"

# 🟥 과차단 반대편: **막 자른 브랜치**(head == base, 커밋 0개)는 퇴화가 아니라 정직한 «변경 없음» 이다.
#    초판의 조상 가드가 이 경우까지 rc=10 으로 잡아서 빈 브랜치 push 를 빨갛게 만들었다.
git checkout -q -B claude/frontier-auto-empty _base
out=$(RMG_BASE_REF=_base RMG_HEAD_REF="$(git rev-parse --abbrev-ref HEAD)" bash scripts/remote_marker_gate.sh 2>&1); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | /usr/bin/grep -q "FH 자산을 건드리지 않았다"; then
  ok "H4 과차단 방지: 막 자른 빈 브랜치(head==base) → rc=0 PASS (퇴화로 안 읽는다)"
else ng "H4 과차단 (rc=$rc) — 커밋 0개인 브랜치 push 가 빨개진다"; fi

printf 'GUARD_PATHSPEC=(\n  %s\n)\n' "'CLAUDE.md'" > templates/_tiny.sh
out=$(RMG_GUARD_FILE=templates/_tiny.sh run); rc=$?
[ "$rc" -eq 10 ] && ok "H2: 배열 추출이 5개 미만이면 rc=10 (파서 파손을 «자산 없음» 으로 안 읽는다)" \
                 || ng "H2 어긋남 (rc=$rc) — 깨진 파서가 조용히 통과시킨다"

echo
echo "== 되돌림 프로브 — 앵커가 장식인가 =="
# 필수 필드 루프를 무력화한 사본으로 P1 을 다시 돌린다. 적색이 초록이 되어야 «그 줄이 일한다».
sed -E 's/^for field in "axes-run" "crossfamily" "standpoint"; do$/for field in ; do/' \
    scripts/remote_marker_gate.sh > scripts/_reverted.sh
if /usr/bin/grep -q '^for field in ; do' scripts/_reverted.sh; then
  mk claude/frontier-auto-r plugins/fh-meta/skills/demo/SKILL.md "frontier-auto: 마커 없음"
  out=$(RMG_BASE_REF=_base RMG_HEAD_REF="$(git rev-parse --abbrev-ref HEAD)" bash scripts/_reverted.sh 2>&1); rc=$?
  [ "$rc" -eq 0 ] && ok "R1 되돌림: 필드 검사를 떼면 P1 이 **초록**이 된다 → 그 줄이 실제로 막고 있다" \
                  || ng "R1: 떼도 여전히 rc=$rc — 다른 것이 막고 있다(앵커 귀속 틀림)"
else
  ng "R1 계기 오류 — 되돌림 치환이 안 먹었다(대상 줄의 표기가 바뀌었나). 프로브가 죽었다"
fi
rm -f scripts/_reverted.sh templates/_tiny.sh

echo
echo "== CI 배선 — 새 스텝이 기존 스텝을 «죽이지» 않았나 =="
# 🟥 이 레인은 내가 실제로 낸 사고에서 나왔다(2026-09-14). 새 스텝을 validate.yml 에 끼우면서
#    `bash scripts/selfcheck.sh` 를 내 스텝의 `exit $rc` **뒤로** 밀어 넣었다 — YAML 은 통과하고
#    CI 는 초록인데 **레인 스위트 전체가 한 줄도 안 도는** 상태였다. 조용한 무장해제다.
#    판별자는 «호출이 있나» 가 아니라 «호출이 죽은 자리에 있지 않나» 다.
WF="$SRC_ROOT/.github/workflows/validate.yml"
if [ ! -r "$WF" ]; then
  ng "W0 계기 오류 — validate.yml 을 못 읽는다"
else
  L_SELF=$(/usr/bin/grep -nE '^[[:space:]]+bash scripts/selfcheck\.sh[[:space:]]*$' "$WF" | head -1 | cut -d: -f1)
  L_GATE=$(/usr/bin/grep -n 'name: Floorless-channel' "$WF" | head -1 | cut -d: -f1)
  L_EXIT=$(/usr/bin/grep -nE '^[[:space:]]+exit \$rc[[:space:]]*$' "$WF" | head -1 | cut -d: -f1)
  printf '     selfcheck 호출=%s · 새 스텝 선언=%s · exit=%s\n' "${L_SELF:-none}" "${L_GATE:-none}" "${L_EXIT:-none}"
  if [ -z "${L_SELF:-}" ]; then
    ng "W1: validate.yml 에 `bash scripts/selfcheck.sh` 호출이 없다 — 레인 스위트가 CI 에서 안 돈다"
  elif [ -n "${L_GATE:-}" ] && [ "$L_SELF" -gt "$L_GATE" ]; then
    ng "W1: selfcheck 호출($L_SELF)이 새 스텝 선언($L_GATE) **뒤**에 있다 — 죽은 자리다"
  else
    ok "W1: selfcheck 호출($L_SELF)이 새 스텝($L_GATE)보다 앞이다 — 무장해제 아님"
  fi
  /usr/bin/grep -q 'remote_marker_gate.sh' "$WF" \
    && ok "W2: validate.yml 이 remote_marker_gate.sh 를 실제로 부른다(배선됨)" \
    || ng "W2: 게이트가 CI 에 배선 안 됐다 — 산문이 실행기다"
fi

echo
echo "════════════════════════════════════════"
printf '  PASS %s   FAIL %s\n' "$PASS" "$FAIL"
echo "════════════════════════════════════════"
[ "$FAIL" -eq 0 ] || exit 1

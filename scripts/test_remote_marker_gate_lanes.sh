#!/usr/bin/env bash
# 레인 — scripts/remote_marker_gate.sh 의 판별력.
#
# 🟥 «FAIL 0» 이 «검사가 도는 것» 을 증명하지 않는다. 합성 레포 픽스처로 양·음성을 둘 다 보인다.
# 🟥 그리고 컨트롤이 **살아 있는지** 를 값으로 찍는다 — 죽은 컨트롤은 깨끗한 대상의 0 과
#    똑같이 생겼다([[feedback_catches_come_from_two_signals_disagreeing]]).
. "$(dirname "${BASH_SOURCE[0]}")/fixture_guard_lib.sh"   # scrub inherited GIT_* env first (#1088)
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
echo "== push 실행의 PR 본문 조회 (AQ-20261114-10 — 같은 HEAD 두 판정) =="
# 🟥 #1095 · #1103: 마커가 PR 본문에만 있으면 pull_request 실행은 초록인데 push 실행은 빨강이었다.
#    push 실행은 이벤트 본문이 없어서다. 가짜 gh 로 조회 응답을 꽂아 다섯 갈래를 가른다.
FAKEGH="$TMPD/fakegh"; mkdir -p "$FAKEGH"
mkgh(){ # $1=이름 $2=모드(json|fail|garbage) $3=json 본문
  printf '#!/usr/bin/env bash\n' > "$FAKEGH/$1"
  case "$2" in
    json)    printf 'cat <<'"'"'JSON'"'"'\n%s\nJSON\n' "$3" >> "$FAKEGH/$1" ;;
    fail)    printf 'echo "HTTP 502: Bad Gateway" >&2; exit 1\n' >> "$FAKEGH/$1" ;;
    garbage) printf 'echo "<html>not json</html>"\n' >> "$FAKEGH/$1" ;;
  esac
  chmod +x "$FAKEGH/$1"
}
BODY_JSON=$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$(printf '%s' "$FULL" | sed 1,2d)")
mk claude/frontier-auto-push plugins/fh-meta/skills/demo/SKILL.md "frontier-auto: 마커는 PR 본문에만"
PBR=$(git rev-parse --abbrev-ref HEAD)
mkgh ok    json "[{\"head\":{\"ref\":\"$PBR\",\"repo\":{\"full_name\":\"o/r\"}},\"body\":$BODY_JSON}]"
mkgh fork  json "[{\"head\":{\"ref\":\"$PBR\",\"repo\":{\"full_name\":\"x/fork\"}},\"body\":$BODY_JSON}]"
mkgh nulle json "[null]"
mkgh noref json "[{\"head\":{},\"body\":$BODY_JSON}]"
mkgh norepo json "[{\"head\":{\"ref\":\"$PBR\",\"repo\":null},\"body\":$BODY_JSON}]"
mkgh empty json "[]"
mkgh other json "[{\"head\":{\"ref\":\"claude/someone-else\",\"repo\":{\"full_name\":\"o/r\"}},\"body\":$BODY_JSON}]"
mkgh fail  fail
mkgh junk  garbage
plook(){ RMG_PR_LOOKUP=1 RMG_REPO=o/r RMG_GH="$FAKEGH/$1" RMG_BASE_REF=_base RMG_HEAD_REF="$PBR" bash "${2:-scripts/remote_marker_gate.sh}" 2>&1; }
out=$(plook ok); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | /usr/bin/grep -q "PR($PBR) 1 개 본문"; then
  ok "L1 (a) push + 이 채널 PR 본문에 마커 → rc=0 (pull_request 실행과 같은 판정)"
else ng "L1 어긋남 (rc=$rc) — push 실행이 PR 본문을 못 읽는다: $(printf '%s' "$out" | tail -2)"; fi
out=$(plook empty); rc=$?
[ "$rc" -eq 1 ] && printf '%s' "$out" | /usr/bin/grep -q "PR 이 없다" \
  && ok "L2 (c) push + PR 없음 + 커밋에 마커 없음 → rc=1 (빨강 유지)" \
  || ng "L2 어긋남 (rc=$rc) — PR 없는 push 가 통과한다"
out=$(plook other); rc=$?
[ "$rc" -eq 1 ] && ok "L3 (d) 같은 커밋을 품은 «남의 채널» PR 본문으로는 통과 안 한다 → rc=1" \
                || ng "L3 어긋남 (rc=$rc) — 다른 head ref 의 본문을 기록으로 셌다"
out=$(plook fail); rc=$?
[ "$rc" -eq 10 ] && printf '%s' "$out" | /usr/bin/grep -q "PR 조회가 실패" \
  && ok "L4 (e) PR 조회 실패 → rc=10 빨강 («PR 없음» 으로 안 접는다)" \
  || ng "L4 어긋남 (rc=$rc) — 조회 실패가 판정으로 접혔다"
out=$(plook junk); rc=$?
[ "$rc" -eq 10 ] && ok "L5 (e') 조회 응답이 JSON 이 아니면 rc=10" \
                 || ng "L5 어긋남 (rc=$rc) — 깨진 응답을 «PR 없음» 으로 읽었다"
out=$(plook fork); rc=$?
[ "$rc" -eq 1 ] && ok "L3b 같은 브랜치 이름의 «포크» PR 본문으로는 통과 안 한다 → rc=1 (codex R1)" \
                || ng "L3b 어긋남 (rc=$rc) — 포크 PR 본문을 기록으로 셌다"
out=$(plook nulle); rc=$?
[ "$rc" -eq 10 ] && ok "L5b 응답 항목이 깨졌으면([null]) rc=10 — 조용히 버리지 않는다 (codex R1)" \
                 || ng "L5b 어긋남 (rc=$rc) — 깨진 항목을 «PR 없음» 으로 읽었다"
for _m in noref norepo; do
  out=$(plook "$_m"); rc=$?
  [ "$rc" -eq 10 ] && ok "L5c 응답 항목에 head.ref / head.repo 가 없으면($_m) rc=10 (codex R2)" \
                   || ng "L5c 어긋남 ($_m rc=$rc) — 귀속 불가 항목을 «PR 없음» 으로 읽었다"
done
out=$(RMG_PR_LOOKUP=1 RMG_GH="$FAKEGH/ok" RMG_BASE_REF=_base RMG_HEAD_REF="$PBR" bash scripts/remote_marker_gate.sh 2>&1); rc=$?
[ "$rc" -eq 10 ] && ok "L6 RMG_REPO 없이 조회 모드 → rc=10 (조회 불가를 통과로 안 읽는다)" \
                 || ng "L6 어긋남 (rc=$rc)"
# 되돌림 known-pair: 조회 블록만 끈 사본에서 L1 이 빨개져야 그 블록이 일한다.
sed -E 's/^if \[ -z "\$BODY_FILE" \] && \[ "\$\{RMG_PR_LOOKUP:-0\}" = "1" \]; then$/if false; then/' \
    scripts/remote_marker_gate.sh > scripts/_nolookup.sh
if /usr/bin/grep -q '^if false; then$' scripts/_nolookup.sh; then
  out=$(plook ok scripts/_nolookup.sh); rc=$?
  [ "$rc" -eq 1 ] && ok "R2 되돌림: 조회 블록을 끄면 L1 이 rc=1 빨강 → 그 블록이 push 판정을 바꾼다" \
                  || ng "R2: 꺼도 rc=$rc — 다른 것이 L1 을 통과시킨다(앵커 귀속 틀림)"
else
  ng "R2 계기 오류 — 되돌림 치환이 안 먹었다. 프로브가 죽었다"
fi
rm -f scripts/_nolookup.sh

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
  # W3 은 «글자가 있나» 가 아니라 «그 스텝의 env 값이 그것인가» 를 YAML 로 읽는다(codex R2 — 주석 처리한 줄도 grep 엔 남는다).
  w3(){ python3 - "$1" <<'PY'
import sys
try:
    import yaml
except ImportError:
    print("NO-YAML"); sys.exit(3)
wf = yaml.safe_load(open(sys.argv[1], encoding="utf-8"))
want = "${{ github.event_name == 'push' && '1' || '0' }}"
for job in (wf.get("jobs") or {}).values():
    for st in job.get("steps") or []:
        if str(st.get("name", "")).startswith("Floorless-channel"):
            env = st.get("env") or {}
            sys.exit(0 if env.get("RMG_PR_LOOKUP") == want and env.get("RMG_REPO") and env.get("GH_TOKEN") else 1)
sys.exit(2)
PY
  }
  w3 "$WF" >/dev/null; w3rc=$?
  sed -E 's/^([[:space:]]+)RMG_PR_LOOKUP:/\1# RMG_PR_LOOKUP:/' "$WF" > "$TMPD/wf_mut.yml"
  w3 "$TMPD/wf_mut.yml" >/dev/null; w3m=$?
  if [ "$w3rc" -eq 0 ] && [ "$w3m" -eq 1 ] && /usr/bin/grep -q '# RMG_PR_LOOKUP:' "$TMPD/wf_mut.yml"; then
    ok "W3: Floorless 스텝 env 에 push 조회가 배선됐다 · 그 줄을 주석 처리한 사본은 빨강(되돌림 컨트롤 살아 있음)"
  else
    ng "W3: push 조회 배선 판정 어긋남 (실물 rc=$w3rc · 주석 사본 rc=$w3m — 3 = PyYAML 없음 · 2 = 스텝 못 찾음)"
  fi
fi

echo
echo "== 지적 기록 (findings:) — 형식만, 내용 아님 (2026-11-23, 운영자 (B)) =="
# 🟥 왜: 리뷰 지적 센서스(2026-11-23) — 리뷰가 있었다는 PR 138건 중 59건은 본문이 «codex R1 5 findings, all fixed» 처럼
#    개수만 적어 무엇이었는지 읽을 수 없었다. 본문 195건 실측: 산문 «N findings» 42 · 등급만 «1 A · 2 B» 16 · «N items» 3.
#    그래서 개수는 «타입 줄» 로 받고(R-a/R-b, 첫날부터 막음), 산문 개수 감지(R-c)는 한 주 경고만 낸다.
#    판정 대상은 형식뿐이다 — 지적 문장이 참인지, sha 가 그 수리를 담는지는 안 본다.
fr(){ # $1=브랜치 꼬리 $2=커밋 메시지에 FULL 뒤로 붙일 텍스트 · 나머지 env 는 호출자가
  mk "claude/frr-$1" plugins/fh-meta/skills/demo/SKILL.md "$FULL
$2"
  RMG_BASE_REF=_base RMG_HEAD_REF="$(git rev-parse --abbrev-ref HEAD)" bash scripts/remote_marker_gate.sh 2>&1; }
PAST=2000-01-01; FUTURE=2999-01-01
FIVE='findings: 5
- codex R1 · help flag read as a file list · fixed@0123abc
- codex R1 · CI unset passes · fixed@0123abd
- sonnet · README overstates the scope · fixed@0123abe
- root · lane control dead on macOS · named-residual
- codex R2 · near-key not caught · rejected — the hook already blocks it'
out=$(RMG_FINDINGS_BLOCK_FROM=$PAST fr f1 'codex R1 5 findings, all fixed.'); rc=$?
[ "$rc" -eq 1 ] && printf '%s' "$out" | /usr/bin/grep -q 'findings:' \
  && ok "F1 (R-c) 산문 «5 findings» + 타입 줄 없음 · 차단일 이후 → rc=1" \
  || ng "F1 어긋남 (rc=$rc) — 개수만 적은 본문이 통과했다"
out=$(RMG_FINDINGS_BLOCK_FROM=$FUTURE fr f1w 'codex R1 5 findings, all fixed.'); rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$out" | /usr/bin/grep -q 'FINDINGS_TRIPWIRE_HIT' \
  && ok "F1w (R-c) 같은 본문 · 차단일 이전 → rc=0 + 경고 토큰 FINDINGS_TRIPWIRE_HIT(적중 목록)" \
  || ng "F1w 어긋남 (rc=$rc) — 경고 주간에 막았거나 적중을 안 남겼다"
out=$(RMG_FINDINGS_BLOCK_FROM=$PAST fr f2 "$FIVE"); rc=$?
[ "$rc" -eq 0 ] && ok "F2 (R-a) findings: 5 + 형식 맞는 5줄 → rc=0" || ng "F2 어긋남 (rc=$rc): $(printf '%s' "$out" | tail -3)"
out=$(RMG_FINDINGS_BLOCK_FROM=$PAST fr f3 'findings: none — no review ran, doc-only change'); rc=$?
[ "$rc" -eq 0 ] && ok "F3 (R-b) findings: none — 이유 → rc=0 (리뷰 안 돌았다는 기록)" || ng "F3 어긋남 (rc=$rc)"
out=$(RMG_FINDINGS_BLOCK_FROM=$PAST fr f3z 'findings: 0 — codex R2 found nothing new'); rc=$?
[ "$rc" -eq 0 ] && ok "F3z (R-b) findings: 0 — 무엇을 돌렸나 → rc=0" || ng "F3z 어긋남 (rc=$rc)"
out=$(fr f4 'findings: 2
- codex R1 · help flag read as a file list · fixed@0123abc'); rc=$?
[ "$rc" -eq 1 ] && ok "F4 (R-a) findings: 2 인데 1줄 → rc=1" || ng "F4 어긋남 (rc=$rc)"
out=$(fr f4b 'findings: 1
- codex R1 · help flag read as a file list · fixed@0123abc
- codex R1 · CI unset passes · fixed@0123abd'); rc=$?
[ "$rc" -eq 1 ] && ok "F4b (R-a) findings: 1 인데 지적 줄 2개 → rc=1" || ng "F4b 어긋남 (rc=$rc)"
out=$(fr f5 'findings: 1
- codex R1 · help flag read as a file list · done'); rc=$?
[ "$rc" -eq 1 ] && ok "F5 (R-a) 처리 칸이 enum 밖(done) → rc=1" || ng "F5 어긋남 (rc=$rc)"
out=$(fr f5s 'findings: 1
- reviewer · help flag read as a file list · fixed@0123abc'); rc=$?
[ "$rc" -eq 1 ] && ok "F5s (R-a) 출처 칸이 형식 밖(라운드 없는 이름) → rc=1" || ng "F5s 어긋남 (rc=$rc)"
out=$(fr f6 'Findings: 1
- codex R1 · help flag read as a file list · fixed@0123abc'); rc=$?
[ "$rc" -eq 1 ] && ok "F6 (R-a) 근사 키 «Findings:» → rc=1" || ng "F6 어긋남 (rc=$rc)"
out=$(fr f7 'findings: none'); rc=$?
[ "$rc" -eq 1 ] && ok "F7 (R-b) 이유 없는 «findings: none» → rc=1 (공허)" || ng "F7 어긋남 (rc=$rc)"
out=$(fr f7z 'findings: 0'); rc=$?
[ "$rc" -eq 1 ] && ok "F7z (R-b) 이유 없는 «findings: 0» → rc=1" || ng "F7z 어긋남 (rc=$rc)"
out=$(RMG_FINDINGS_BLOCK_FROM=$PAST fr f8 'codex R1: 1 A · 2 B, all fixed.'); rc=$?
[ "$rc" -eq 0 ] && ok "F8 이름 붙인 놓침: 등급만(«1 A · 2 B») 쓴 본문은 R-c 가 못 본다 → rc=0 (측정된 한계, 통과 주장 아님)" \
                || ng "F8 어긋남 (rc=$rc) — 등급 표기를 잡기 시작했다면 이 레인과 PR 본문의 «놓침» 문장을 같이 고쳐라"
out=$(RMG_FINDINGS_BLOCK_FROM=$PAST fr f9 'Nothing was reviewed here.'); rc=$?
[ "$rc" -eq 0 ] && ! printf '%s' "$out" | /usr/bin/grep -q 'FINDINGS_TRIPWIRE_HIT' \
  && ok "F9 (R-d) 타입 줄도 산문 개수도 없음 → rc=0, 경고 없음 (침묵은 판정 안 함)" || ng "F9 어긋남 (rc=$rc)"

# codex R1 · blind Sonnet (2026-11-23) — 각각 고치기 전에 재현했다
out=$(fr f10 'findings: 0 — root reviewed it
- root · crashes on startup · named-residual'); rc=$?
[ "$rc" -eq 1 ] && ok "F10 «findings: 0» 뒤에 지적 줄이 따라오면 rc=1 (codex R1)" || ng "F10 어긋남 (rc=$rc)"
out=$(fr f10n 'findings: none — no review ran
- root · crashes on startup · named-residual'); rc=$?
[ "$rc" -eq 1 ] && ok "F10n «findings: none» 뒤에 지적 줄 → rc=1" || ng "F10n 어긋남 (rc=$rc)"
out=$(fr f11 'findings: 2
- root · crashes · named-residual
- codex R1 · 도움말플래그를파일목록으로읽음 · fixed@0123abc'); rc=$?
[ "$rc" -eq 0 ] && ok "F11 한 낱말 구절 · 띄어쓰기 없는 한국어 구절도 형식이다 → rc=0 (codex R1)" || ng "F11 어긋남 (rc=$rc)"
out=$(fr f12 'findings: 2
- codex R1 · bash 4 claim not backed by a run · named-residual (known limitation, not verified here)
- codex R1 · a 0 read as not run · fixed@4f2a9c1 — counter now keeps the value'); rc=$?
[ "$rc" -eq 0 ] && ok "F12 처리 칸 뒤의 설명(«named-residual (…)» · «fixed@sha — …») 허용 → rc=0 (블라인드 Sonnet 이 쓴 모양)" || ng "F12 어긋남 (rc=$rc)"
out=$(fr f12r 'findings: 1
- codex R1 · bash 4 claim · rejected'); rc=$?
[ "$rc" -eq 1 ] && ok "F12r 이유 없는 «rejected» → rc=1" || ng "F12r 어긋남 (rc=$rc)"

# codex R2 (2026-11-23) — 각각 고치기 전에 재현했다(마지막 라운드라 이 수리는 재검토 안 됨 — PR 본문에 적는다)
out=$(fr f15 'findings: 1
- root · crashes · fixed@0123abcXYZ'); rc=$?
[ "$rc" -eq 1 ] && ok "F15 처리 토큰에 글자가 붙으면(fixed@…XYZ) rc=1" || ng "F15 어긋남 (rc=$rc)"
out=$(fr f15n 'findings: 1
- root · crashes · named-residual-invalid'); rc=$?
[ "$rc" -eq 1 ] && ok "F15n named-residual-invalid → rc=1" || ng "F15n 어긋남 (rc=$rc)"
out=$(fr f16 'findings: 0 — root reviewed it

- root · crashes · named-residual'); rc=$?
[ "$rc" -eq 1 ] && ok "F16 «findings: 0» 뒤 빈 줄 다음의 지적 줄도 모순 → rc=1" || ng "F16 어긋남 (rc=$rc)"
mkgh badbody json "[{\"head\":{\"ref\":\"$PBR\",\"repo\":{\"full_name\":\"o/r\"}},\"body\":[]}]"
out=$(plook badbody); rc=$?
[ "$rc" -eq 10 ] && ok "L5d push 조회 경로도 본문 값이 문자열·null 이 아니면 rc=10" || ng "L5d 어긋남 (rc=$rc)"

# F17 — 코드 펜스 안의 예시는 기록이 아니다(이 PR 자기 본문의 형식 예시가 기록으로 읽혀 막혔다 — 마지막 라운드 뒤 수리)
FENCE_BODY='The record looks like this:
```
findings: 3
- codex R1 · <mechanism> · fixed@<sha>
```
findings: 1
- codex R1 · help flag read as a file list · fixed@0123abc'
out=$(RMG_FINDINGS_BLOCK_FROM=$PAST fr f17 "$FENCE_BODY"); rc=$?
[ "$rc" -eq 0 ] && ok "F17 펜스 안 예시(findings: 3 + 자리표시자)는 건너뛰고 펜스 밖 진짜 블록만 본다 → rc=0" || ng "F17 어긋남 (rc=$rc)"
out=$(RMG_FINDINGS_BLOCK_FROM=$PAST fr f17p 'codex R1 5 findings, all fixed.
```
findings: 1
- codex R1 · example · fixed@0123abc
```'); rc=$?
[ "$rc" -eq 1 ] && ok "F17p 펜스 안의 findings: 줄은 산문 개수를 덮지 못한다 → rc=1 (R-c 그대로)" || ng "F17p 어긋남 (rc=$rc)"

# F18 — 닫히지 않은 펜스(루트 지적, 읽기로 발견): 끝까지 열린 펜스가 그 뒤 주장(산문 개수 · findings: 줄)을 가리면
#   «주장 없음» 으로 조용히 통과했다 → 형식 오류. 가린 구간에 주장이 없으면 R-d 그대로(통과).
out=$(RMG_FINDINGS_BLOCK_FROM=$FUTURE fr f18 'Notes:
```
codex R1 3 findings, all fixed.'); rc=$?
[ "$rc" -eq 1 ] && printf '%s' "$out" | /usr/bin/grep -q 'unclosed code fence' \
  && ok "F18 닫히지 않은 펜스가 산문 «3 findings» 를 가리면 rc=1 «unclosed code fence» (경고 주간에도)" || ng "F18 어긋남 (rc=$rc)"
out=$(RMG_FINDINGS_BLOCK_FROM=$FUTURE fr f18c 'Notes:
```
an example
```
codex R1 3 findings, all fixed.'); rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$out" | /usr/bin/grep -q 'FINDINGS_TRIPWIRE_HIT' \
  && ok "F18c 같은 본문, 펜스를 닫으면 지금 동작(경고 주간 → 경고 + rc=0)" || ng "F18c 어긋남 (rc=$rc)"
out=$(fr f18e 'Example:
```
codex R1 3 findings
```
Log:
```
just a log line, no claim'); rc=$?
[ "$rc" -eq 0 ] && ok "F18e 앞의 닫힌 펜스 안 «3 findings» 는 뒤의 열린 펜스 판정에 안 섞인다 → rc=0" || ng "F18e 어긋남 (rc=$rc)"
out=$(fr f18n 'Notes:
```
just a log line, no claim'); rc=$?
[ "$rc" -eq 0 ] && ok "F18n 닫히지 않은 펜스 안에 주장이 없으면 R-d 그대로 통과" || ng "F18n 어긋남 (rc=$rc)"

# F19 — 줄바꿈된 산문이 우연히 «findings: » 로 시작해도 기록이 아니다(이 PR 의 세 번째 커밋 메시지에서 실제로 났다).
#   값이 숫자 · none 으로 시작할 때만 기록으로 본다. 그 밖은 산문 — 대신 «findings: five» 같은 오타는 못 잡는다(이름 붙인 느슨함).
out=$(fr f19 'when the hidden part of that fence holds a claim (a
findings: line, a near-key, or a prose count), R-a fails.'); rc=$?
[ "$rc" -eq 0 ] && ok "F19 «findings: line, …» 로 시작하는 줄바꿈 산문은 기록이 아니다 → rc=0" || ng "F19 어긋남 (rc=$rc)"
out=$(fr f19d 'findings: 3x
- root · a · named-residual'); rc=$?
[ "$rc" -eq 1 ] && ok "F19d 숫자로 시작하는 깨진 값(3x)은 여전히 기록 오류 → rc=1" || ng "F19d 어긋남 (rc=$rc)"

# F14 — 마지막 커밋 날짜를 못 읽으면(빈 값) 경고로 접지 않고 판정 불가(rc 2 → 스크립트 rc 10). 날짜만 실패하게 만드는 길이
#   스크립트 실행엔 없어서(앞 단계가 같은 ref 를 이미 읽었다) 파서를 스크립트에서 그대로 떼어 직접 부른다(codex R1).
awk '/^FOUT=\$\(python3 - /{f=1;next} /^FPY$/{f=0} f' scripts/remote_marker_gate.sh > "$TMPD/findings_parser.py"
printf 'codex R1 5 findings, all fixed.\n' > "$TMPD/rec_prose.txt"
if /usr/bin/grep -q 'block_from, last_date, rec' "$TMPD/findings_parser.py"; then
  python3 "$TMPD/findings_parser.py" 2000-01-01 "" "$TMPD/rec_prose.txt" >/dev/null 2>&1; r14=$?
  python3 "$TMPD/findings_parser.py" 2000-01-01 2026-11-23 "$TMPD/rec_prose.txt" >/dev/null 2>&1; r14c=$?
  [ "$r14" -eq 2 ] && [ "$r14c" -eq 1 ] && ok "F14 날짜를 못 읽으면 rc 2(판정 불가) · 같은 기록에 날짜가 있으면 rc 1(차단) — 컨트롤 살아 있음" \
                                        || ng "F14 어긋남 (빈 날짜 rc=$r14 · 날짜 있음 rc=$r14c)"
else
  ng "F14 계기 오류 — 파서를 스크립트에서 떼어 내지 못했다(표기가 바뀌었나)"
fi

echo
echo "== pull_request 실행의 본문은 이벤트가 아니라 API 에서 새로 읽는다 (#1196 — 고친 본문이 재실행에 안 실렸다) =="
mk claude/frr-fresh plugins/fh-meta/skills/demo/SKILL.md "frontier-auto: 마커는 PR 본문에만 (pull_request)"
FBR=$(git rev-parse --abbrev-ref HEAD)
mkgh prok    json "{\"number\":7,\"head\":{\"ref\":\"$FBR\",\"repo\":{\"full_name\":\"o/r\"}},\"body\":$BODY_JSON}"
mkgh prfork  json "{\"number\":7,\"head\":{\"ref\":\"$FBR\",\"repo\":{\"full_name\":\"x/fork\"}},\"body\":$BODY_JSON}"
mkgh prbadbody json "{\"number\":7,\"head\":{\"ref\":\"$FBR\",\"repo\":{\"full_name\":\"o/r\"}},\"body\":[]}"
mkgh prwrong json "{\"number\":7,\"head\":{\"ref\":\"claude/other\",\"repo\":{\"full_name\":\"o/r\"}},\"body\":$BODY_JSON}"
prnum(){ RMG_PR_NUMBER=7 RMG_REPO=o/r RMG_GH="$FAKEGH/$1" RMG_BASE_REF=_base RMG_HEAD_REF="$FBR" bash "${2:-scripts/remote_marker_gate.sh}" 2>&1; }
out=$(prnum prok); rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$out" | /usr/bin/grep -q 'PR #7 본문을 API 로 새로 읽었다' \
  && ok "P7a pull_request: PR 번호로 본문을 새로 읽는다 → 본문의 마커로 rc=0" \
  || ng "P7a 어긋남 (rc=$rc): $(printf '%s' "$out" | tail -2)"
out=$(prnum prfork); rc=$?
[ "$rc" -eq 0 ] && ok "P7e 포크에서 온 PR(같은 번호 · 같은 head ref) 본문도 읽는다 → rc=0 (번호가 PR 을 정확히 가리킨다)" || ng "P7e 어긋남 (rc=$rc) — 포크 PR 을 거절했다"
out=$(prnum prbadbody); rc=$?
[ "$rc" -eq 10 ] && ok "P7f 본문 값이 문자열·null 이 아니면([]) rc=10 (codex R1 — 빈 본문으로 접히던 자리)" || ng "P7f 어긋남 (rc=$rc)"
out=$(prnum fail); rc=$?
[ "$rc" -eq 10 ] && ok "P7b 본문 조회 실패 → rc=10 («본문 없음» 으로 안 접는다)" || ng "P7b 어긋남 (rc=$rc)"
out=$(prnum junk); rc=$?
[ "$rc" -eq 10 ] && ok "P7c 응답이 JSON 이 아님 → rc=10" || ng "P7c 어긋남 (rc=$rc)"
out=$(prnum prwrong); rc=$?
[ "$rc" -eq 10 ] && ok "P7d 그 번호의 PR head 가 이 채널이 아님 → rc=10 (남의 본문으로 통과 안 함)" || ng "P7d 어긋남 (rc=$rc)"
w4(){ python3 - "$1" <<'W4PY'
import sys
try:
    import yaml
except ImportError:
    sys.exit(3)
wf = yaml.safe_load(open(sys.argv[1], encoding="utf-8"))
for job in (wf.get("jobs") or {}).values():
    for st in job.get("steps") or []:
        if str(st.get("name", "")).startswith("Floorless-channel"):
            env = st.get("env") or {}
            ok = env.get("RMG_PR_NUMBER") == "${{ github.event.pull_request.number }}" and "PR_BODY" not in env
            sys.exit(0 if ok else 1)
sys.exit(2)
W4PY
}
if [ -r "$WF" ]; then
  w4 "$WF"; w4rc=$?
  [ "$w4rc" -eq 0 ] && ok "W4: Floorless 스텝이 이벤트 본문(PR_BODY) 대신 RMG_PR_NUMBER 로 새로 읽는다" \
                    || ng "W4: Floorless 스텝이 아직 이벤트 본문을 쓴다 (rc=$w4rc — 3 = PyYAML 없음)"
fi

echo
echo "== 게이트가 자기 판정을 고칠 수 없게 — 기준(base) 사본으로 판정 (2026-11-23, H2) =="
# 🟥 실측: pull_request 체크아웃은 PR 쪽(merge ref)이라, FH 자산을 마커 없이 바꾸면서 같은 PR 에서 이 스크립트의
#    필드 루프 한 줄을 지우면 CI 판정이 rc 1 → rc 0 이 됐다(로컬 재현, 세 팔: 위반만 1 · 위반+게이트 수정 0 ·
#    같은 브랜치에 base 사본 1). 그래서 Floorless 스텝은 base 의 스크립트와 경로 정본을 꺼내 그것으로 판정한다.
#    🟥 남는 구멍: 워크플로 파일 자체도 PR 쪽이라 validate.yml 을 같이 고치면 이것도 풀린다 — 막는 것은 저장소
#    설정(base 에서 정의된 필수 검사 · 코드 소유자 리뷰)이고 그건 운영자 결정이다. 이 레인은 «한 줄 지우기» 를
#    «워크플로까지 고치기» 로 올렸는지만 본다.
w5(){ python3 - "$1" <<'W5PY'
import sys
try:
    import yaml
except ImportError:
    sys.exit(3)
wf = yaml.safe_load(open(sys.argv[1], encoding="utf-8"))
for job in (wf.get("jobs") or {}).values():
    for st in job.get("steps") or []:
        if str(st.get("name", "")).startswith("Floorless-channel"):
            run = st.get("run") or ""
            ok = ("git show" in run and ":scripts/remote_marker_gate.sh" in run
                  and ":templates/regression_guard.sh" in run and "RMG_GUARD_FILE" in run
                  and "bash scripts/remote_marker_gate.sh" not in run)
            sys.exit(0 if ok else 1)
sys.exit(2)
W5PY
}
if [ -r "$WF" ]; then
  w5 "$WF"; w5rc=$?
  [ "$w5rc" -eq 0 ] && ok "W5: Floorless 스텝이 PR 쪽 스크립트가 아니라 base 의 게이트·경로 정본 사본으로 판정한다" \
                    || ng "W5: Floorless 스텝이 PR 쪽 게이트를 그대로 돌린다 — PR 이 자기 판정을 고칠 수 있다 (rc=$w5rc)"
fi

# W6 — 행동 레인(codex R1): 워크플로의 그 스텝 블록을 그대로 꺼내 픽스처 레포에서 돌린다.
#   알려진 쌍: 같은 «위반 + 게이트 한 줄 삭제» 브랜치를 (a) 실물 스텝으로 → rc 1, (b) base 읽기를 뗀 스텝 사본으로 → rc 0.
#   (b) 가 0 이 아니면 컨트롤이 죽은 것이다 — W6 는 base 읽기가 실제로 판정을 바꾸는지를 본다.
#   (c) 기준 sha 가 없는 객체면 rc 10 (PR 사본으로 떨어지지 않는다, codex R1).
stepblk(){ python3 - "$1" "$2" <<'W6PY'
import sys, yaml, re
wf = yaml.safe_load(open(sys.argv[1], encoding="utf-8"))
for job in (wf.get("jobs") or {}).values():
    for st in job.get("steps") or []:
        if str(st.get("name", "")).startswith("Floorless-channel"):
            run = st["run"]
            run = "\n".join(l for l in run.splitlines() if "git fetch" not in l)
            if sys.argv[2] == "nobase":   # the control: run the change's own copy, as before this fix
                run = re.sub(r'bash "\$GATE"', "bash scripts/remote_marker_gate.sh", run)
            print(run); sys.exit(0)
sys.exit(2)
W6PY
}
if python3 -c 'import yaml' 2>/dev/null && [ -r "$WF" ]; then
  stepblk "$WF" real > "$TMPD/step_real.sh"; stepblk "$WF" nobase > "$TMPD/step_nobase.sh"
  git checkout -q -B claude/w6-self _base
  printf 'changed %s\n' "$(date +%s%N)" >> plugins/fh-meta/skills/demo/SKILL.md
  sed -i.bak 's/^for field in "axes-run" "crossfamily" "standpoint"; do$/for field in ; do/' scripts/remote_marker_gate.sh; rm -f scripts/remote_marker_gate.sh.bak
  git add -A >/dev/null; git commit -qm "violation + gate loosened" --no-verify
  git update-ref refs/remotes/origin/main "$(git rev-parse _base)"
  w6(){ RUNNER_TEMP="$TMPD" GATE_BASE_SHA="$2" RMG_CHANNEL_NAME=claude/w6-self RMG_PR_LOOKUP=0 PR_BODY= bash "$1" >/dev/null 2>&1; }
  w6 "$TMPD/step_real.sh" "$(git rev-parse _base)"; r_real=$?
  w6 "$TMPD/step_nobase.sh" "$(git rev-parse _base)"; r_ctl=$?
  w6 "$TMPD/step_real.sh" 1111111111111111111111111111111111111111; r_miss=$?
  if [ "$r_real" -eq 1 ] && [ "$r_ctl" -eq 0 ] && [ "$r_miss" -eq 10 ]; then
    ok "W6: 실물 스텝은 «위반 + 게이트 수정» 을 rc 1 로 막고, base 읽기를 뗀 사본은 rc 0(컨트롤 살아 있음), 없는 기준 sha 는 rc 10"
  else
    ng "W6 어긋남 — 실물 rc=$r_real (1 이어야) · base 읽기 뗀 사본 rc=$r_ctl (0 이어야) · 없는 sha rc=$r_miss (10 이어야)"
  fi
  git checkout -q main 2>/dev/null || true
else
  ng "W6 계기 오류 — PyYAML 또는 validate.yml 이 없다"
fi

echo
echo "════════════════════════════════════════"
printf '  PASS %s   FAIL %s\n' "$PASS" "$FAIL"
echo "════════════════════════════════════════"
[ "$FAIL" -eq 0 ] || exit 1

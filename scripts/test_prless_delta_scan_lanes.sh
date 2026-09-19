#!/usr/bin/env bash
# test_prless_delta_scan_lanes.sh — `scripts/prless_delta_scan.sh` 의 회귀 앵커.
#
# 🟥 **known-pair 가 이 레인의 존재 이유다.** 양성(진짜 PR 없는 델타) 하나만 있는 레인은
#    «판별력» 을 증명하지 못한다 — 전부 고발하는 계기도 그 레인을 통과한다. 그래서 각 팔마다
#    **반대 팔**을 같이 돌린다. 핵심 음성 컨트롤은 **squash 잔재**다: 이 레포는 squash 머지를
#    쓰므로 이미 착륙한 브랜치의 커밋 해시·per-commit patch-id 가 main 에 없고, 순진한 계기는
#    그것을 «미착륙» 으로 읽는다(2026-09-19 실측: naive 33/40 · git cherry 17/40 · 이 계기 10/40).
#
# 레인은 **합성 레포**를 짓는다 — 라이브 레포를 sim 대상으로 쓰지 않는다.
#
# 실행: bash scripts/test_prless_delta_scan_lanes.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SCAN="$HERE/prless_delta_scan.sh"
[ -f "$SCAN" ] || { echo "❌ HARNESS-ERROR: $SCAN 없음 — 레인이 대상을 못 찾았다"; exit 2; }

PASS=0; FAIL=0
ok(){ echo "✅ $1"; PASS=$((PASS+1)); }
no(){ echo "❌ $1"; FAIL=$((FAIL+1)); }

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT

# ── 합성 레포 ────────────────────────────────────────────────────────────────
# main:      c0 -- c1 -- SQUASH(b_squash 합본) -- c2
# b_ff:      c0 -- c1                                   (main 의 조상 → NO_DELTA)
# b_squash:  c1 -- s1 -- s2                             (합본이 main 에 squash 로 들어감)
# b_uniq*:   c1 -- u                                    (고유 델타, PR 상태만 다름)
R="$WORK/repo"
mkdir -p "$R"; cd "$R"
git init -q -b main .
git config user.email lane@example.com; git config user.name lane
git config commit.gpgsign false
echo base > base.txt; git add base.txt; git commit -qm c0
echo one > one.txt;  git add one.txt;  git commit -qm c1
C1=$(git rev-parse HEAD)
git branch b_ff "$C1"

# squash 팔: 두 커밋짜리 브랜치를 만든 뒤, 그 «합본» 을 main 에 한 커밋으로 심는다
git switch -q -c b_squash "$C1"
printf 'alpha\n' > sq.txt; git add sq.txt; git commit -qm s1
printf 'alpha\nbeta\n' > sq.txt; git add sq.txt; git commit -qm s2
git switch -q main
git checkout -q b_squash -- sq.txt; git add sq.txt; git commit -qm "squash: b_squash (#100)"

# 고유 델타 팔 — 내용은 같고 PR 상태만 다르게 붙인다
for n in nopr open closed merged; do
  git switch -q -c "b_$n" "$C1"
  echo "unique-$n" > "uniq_$n.txt"; git add "uniq_$n.txt"; git commit -qm "u_$n"
done
git switch -q main
echo two > two.txt; git add two.txt; git commit -qm c2
# origin/main 을 로컬 ref 로 흉내 (scan 의 기본 base 를 --base 로 갈음)
git update-ref refs/remotes/origin/main "$(git rev-parse main)"
git branch -D main >/dev/null 2>&1 || true   # main 로컬 브랜치는 제외 대상이므로 지워도 무방하나…
git switch -q --detach refs/remotes/origin/main

PRJ="$WORK/prs.json"
cat > "$PRJ" <<'JSON'
[{"number":100,"state":"MERGED","headRefName":"b_squash"},
 {"number":101,"state":"OPEN","headRefName":"b_open"},
 {"number":102,"state":"CLOSED","headRefName":"b_closed"},
 {"number":103,"state":"MERGED","headRefName":"b_merged"}]
JSON

run(){ PRLESS_REPO="$R" PRLESS_PR_JSON="$PRJ" bash "$SCAN" "$@" 2>&1; }
verdict_of(){ echo "$1" | awk -v b="$2" '$0 ~ ("(^|[^a-z_])" b "([ ]|$)") {for(i=1;i<=NF;i++) if($i ~ /^(NO_DELTA|SQUASH_IN_BASE|COMMITS_IN_BASE|DELTA_NO_PR|DELTA_PR_OPEN|DELTA_PR_CLOSED|DELTA_AFTER_MERGED_PR|PATCHID_UNAVAILABLE|UNRELATED_HISTORY)$/) print $i}' | head -1; }

OUT=$(run); RC=$?
echo "--- scan output ---"; echo "$OUT"; echo "--- rc=$RC ---"; echo

# ── L1 양성: PR 이 없는 고유 델타 ──────────────────────────────────────────────
[ "$(verdict_of "$OUT" b_nopr)" = "DELTA_NO_PR" ] \
  && ok "L1 POSITIVE  b_nopr → DELTA_NO_PR" || no "L1 POSITIVE  b_nopr → '$(verdict_of "$OUT" b_nopr)' (기대 DELTA_NO_PR)"

# ── L2 음성 컨트롤(핵심): squash 잔재를 고유 델타로 읽지 않는다 ────────────────
V2=$(verdict_of "$OUT" b_squash)
[ "$V2" = "SQUASH_IN_BASE" ] \
  && ok "L2 NEGATIVE  b_squash → SQUASH_IN_BASE (판별력 성립)" || no "L2 NEGATIVE  b_squash → '$V2' (기대 SQUASH_IN_BASE) — 판별력 없음"

# ── L2-b 컨트롤의 컨트롤: 순진한 계기는 이 팔에서 실제로 «틀린다» ──────────────
#    이 줄이 없으면 L2 는 «원래 안 걸리는 것이 안 걸렸다» 와 구분되지 않는다(죽은 컨트롤).
NAIVE=$(cd "$R" && git cherry refs/remotes/origin/main b_squash 2>/dev/null | /usr/bin/grep -c '^+')
[ "${NAIVE:-0}" -gt 0 ] \
  && ok "L2-b KNOWN-POSITIVE-FOR-THE-NAIVE  git cherry 가 b_squash 를 $NAIVE 커밋 미착륙으로 «틀리게» 본다" \
  || no "L2-b 죽은 컨트롤 — git cherry 도 b_squash 를 안 건드린다(픽스처가 이 결함을 안 담았다)"

# ── L3 음성: main 의 조상 ────────────────────────────────────────────────────
[ "$(verdict_of "$OUT" b_ff)" = "NO_DELTA" ] \
  && ok "L3 NEGATIVE  b_ff → NO_DELTA" || no "L3 NEGATIVE  b_ff → '$(verdict_of "$OUT" b_ff)'"

# ── L4~L6 PR 상태별 분기 ────────────────────────────────────────────────────
[ "$(verdict_of "$OUT" b_open)"   = "DELTA_PR_OPEN" ]          && ok "L4 b_open → DELTA_PR_OPEN (①-b 관할, 발견 아님)"   || no "L4 b_open → '$(verdict_of "$OUT" b_open)'"
[ "$(verdict_of "$OUT" b_closed)" = "DELTA_PR_CLOSED" ]        && ok "L5 b_closed → DELTA_PR_CLOSED"                      || no "L5 b_closed → '$(verdict_of "$OUT" b_closed)'"
[ "$(verdict_of "$OUT" b_merged)" = "DELTA_AFTER_MERGED_PR" ]  && ok "L6 b_merged → DELTA_AFTER_MERGED_PR (부분 머지)"     || no "L6 b_merged → '$(verdict_of "$OUT" b_merged)'"

# ── L7 advisory: 발견이 있어도 rc=1 이지 차단(≥2)이 아니다 ────────────────────
[ "$RC" -eq 1 ] && ok "L7 ADVISORY  발견 있음 → rc=1 (차단 아님)" || no "L7 ADVISORY  rc=$RC (기대 1)"

# ── L8 부재 ≠ 0: PR 출처가 없으면 UNMEASURED(rc=2), «깨끗함» 아니다 ───────────
O8=$(PRLESS_REPO="$R" PATH=/usr/bin:/bin bash "$SCAN" 2>&1); R8=$?
if [ "$R8" -eq 2 ] && echo "$O8" | /usr/bin/grep -q 'UNMEASURED'; then
  ok "L8 UNMEASURED  gh 부재 → rc=2 + UNMEASURED (0 으로 안 접는다)"
else
  no "L8 UNMEASURED  gh 부재 → rc=$R8 / '$O8'"
fi

# ── L9 깨진 PR JSON 도 «PR 0건» 이 아니다 ────────────────────────────────────
echo 'not json' > "$WORK/bad.json"
O9=$(PRLESS_REPO="$R" PRLESS_PR_JSON="$WORK/bad.json" bash "$SCAN" 2>&1); R9=$?
[ "$R9" -eq 2 ] && ok "L9 깨진 PR JSON → rc=2 UNMEASURED" || no "L9 깨진 PR JSON → rc=$R9 (기대 2 — «PR 0건» 으로 읽으면 전부 오탐)"

# ── L10 읽기 전용: 스캔이 레포 상태를 바꾸지 않는다 ───────────────────────────
S_BEFORE=$(cd "$R" && git rev-parse HEAD; git for-each-ref --format='%(refname) %(objectname)' | sort; git status --porcelain)
run >/dev/null 2>&1
S_AFTER=$(cd "$R" && git rev-parse HEAD; git for-each-ref --format='%(refname) %(objectname)' | sort; git status --porcelain)
[ "$S_BEFORE" = "$S_AFTER" ] && ok "L10 READ-ONLY  ref·HEAD·워킹트리 무변경" || no "L10 READ-ONLY  스캔이 레포 상태를 바꿨다"

# ── L11 되돌림 프로브: squash 판별을 «빼면» 정확히 L2 만 적색이 되나 ───────────
#    3단 — 적용확인 → 실행 → 복원. 적용을 확인 안 하면 «안 바뀐 파일로 통과» 를 초록으로 읽는다.
MUT="$WORK/mutant.sh"
sed 's#^      elif grep -qxF "$pid" "$PIDMAP" 2>/dev/null; then#      elif false; then#' "$SCAN" > "$MUT"
if ! /usr/bin/grep -q 'elif false; then' "$MUT"; then
  no "L11 REVERT-PROBE  HARNESS-ERROR — 뮤턴트가 안 만들어졌다(앵커 줄이 바뀌었나). 이 결과는 증거가 아니다"
else
  OM=$(PRLESS_REPO="$R" PRLESS_PR_JSON="$PRJ" bash "$MUT" 2>&1)
  VM_SQ=$(verdict_of "$OM" b_squash); VM_FF=$(verdict_of "$OM" b_ff); VM_NP=$(verdict_of "$OM" b_nopr)
  if [ "$VM_SQ" != "SQUASH_IN_BASE" ] && [ "$VM_FF" = "NO_DELTA" ] && [ "$VM_NP" = "DELTA_NO_PR" ]; then
    ok "L11 REVERT-PROBE  판별 줄을 빼면 b_squash 만 뒤집힌다 ('$VM_SQ') · b_ff·b_nopr 불변 → 앵커가 장식이 아니다"
  else
    no "L11 REVERT-PROBE  b_squash='$VM_SQ' b_ff='$VM_FF' b_nopr='$VM_NP' — 앵커가 그 줄에 안 묶여 있다"
  fi
fi

# ── L12 detached HEAD 를 «브랜치» 로 읽지 않는다 ──────────────────────────────
#    이 픽스처는 detached HEAD 에서 돈다(위 setup 이 origin/main 으로 detach 한다).
#    `git branch` 는 그 상태에서 `(HEAD detached at …)` 를 한 줄 뱉고, 그것을 ref 로 읽으면
#    merge-base 가 안 잡혀 **가짜 UNRELATED_HISTORY 발견**이 나간다. 계기가 자기 사각을 만든 자리.
if echo "$OUT" | /usr/bin/grep -q 'HEAD detached'; then
  no "L12 detached HEAD 의사항목이 브랜치로 집계됐다 — 가짜 발견"
else
  DET=$(cd "$R" && git rev-parse --abbrev-ref HEAD)
  if [ "$DET" = "HEAD" ]; then
    ok "L12 detached HEAD 에서 돌았고(컨트롤 확인: abbrev-ref=HEAD) 의사항목이 집계 안 됨"
  else
    no "L12 죽은 컨트롤 — 픽스처가 detached 상태가 아니다(abbrev-ref=$DET). 이 레인은 아무것도 안 쟀다"
  fi
fi

echo
echo "── PASS=$PASS FAIL=$FAIL ──"
[ "$FAIL" -eq 0 ] || exit 1
exit 0

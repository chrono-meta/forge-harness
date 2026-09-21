#!/usr/bin/env bash
# test_worktree_reclaim_lanes.sh — known pairs for scripts/worktree_reclaim.sh (2026-09-05).
# Fixture: a real `git init` main checkout + a real `git worktree add`, gitignored tracks/ on both sides.
# The lanes assert the ORDER (list file before copy) as well as the verdicts — the list is the evidence
# that survives the copy, which is the whole reason the script exists.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
ROOT="$(pwd -P)"
SUT="$ROOT/scripts/worktree_reclaim.sh"   # own line: new_code_anchor_check resolves the variable per line
PASS=0; FAIL=0
ok() { echo "  ✅ $1"; PASS=$((PASS+1)); }
ng() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }
[ -f "$SUT" ] || { echo "ⓘ worktree_reclaim.sh absent — subject missing when we looked (NOT a pass)"; exit 2; }
T="$(mktemp -d 2>/dev/null)" || { echo "ⓘ mktemp failed (NOT a pass)"; exit 10; }
trap 'rm -rf "$T"' EXIT INT TERM

mk_pair() {  # $1=root → creates $1/main (checkout) + $1/wt (worktree); echoes nothing
  mkdir -p "$1" && ( cd "$1" && git init -q main && cd main \
    && git config user.email l@example.invalid && git config user.name lane \
    && mkdir -p tracks/_meta && printf 'tracks/\n' > .gitignore && echo x > README.md \
    && git add .gitignore README.md && git commit -qm init && git worktree add -q ../wt -b wt-branch ) 2>/dev/null
}

echo "── W1 enumerate: only-in files are listed, list file written, rc=1, nothing copied ──"
mk_pair "$T/a"; M="$T/a/main"; W="$T/a/wt"
mkdir -p "$W/tracks/_meta/sub"; echo "signal body" > "$W/tracks/_meta/fh_signal_lost.md"; echo nested > "$W/tracks/_meta/sub/deep.yaml"
OUT="$(bash "$SUT" "$W" 2>&1)"; RC=$?
[ "$RC" -eq 1 ] && ok "W1 rc=1 (only-in exists, not yet reclaimed)" || { ng "W1 rc=$RC (기대 1)"; printf '%s\n' "$OUT" | sed 's/^/     /'; }
N=$(printf '%s\n' "$OUT" | grep -c '   ONLY  '); [ "$N" -eq 2 ] && ok "W1b 2 only-in files listed (nested dir walked)" || ng "W1b listed $N (기대 2)"
L=$(ls "$M"/tracks/_meta/dispatch/reclaim_wt_*.txt 2>/dev/null | wc -l | tr -d ' '); [ "$L" -eq 1 ] && ok "W1c list file written in MAIN tracks/_meta/dispatch" || ng "W1c list files: $L (기대 1)"
grep -q $'^ONLY\t_meta/sub/deep.yaml' "$M"/tracks/_meta/dispatch/reclaim_wt_*.txt && ok "W1d list carries the relative path" || ng "W1d list lacks the nested path"
[ ! -e "$M/tracks/_meta/fh_signal_lost.md" ] && ok "W1e enumerate mode copies nothing (known-negative)" || ng "W1e enumerate mode copied a file"

echo "── W2 --apply: copied, byte-verified, rc=0; re-run says nothing left ──"
OUT="$(bash "$SUT" "$W" --apply 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && ok "W2 --apply rc=0" || { ng "W2 rc=$RC (기대 0)"; printf '%s\n' "$OUT" | sed 's/^/     /'; }
cmp -s "$W/tracks/_meta/fh_signal_lost.md" "$M/tracks/_meta/fh_signal_lost.md" && cmp -s "$W/tracks/_meta/sub/deep.yaml" "$M/tracks/_meta/sub/deep.yaml" \
  && ok "W2b both files byte-identical in main" || ng "W2b copies differ or missing"
OUT="$(bash "$SUT" "$W" 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && ok "W2c re-run after reclaim → rc=0 (idempotent)" || ng "W2c re-run rc=$RC"
case "$OUT" in *"safe to: git worktree remove"*) ok "W2d prints the next (human) step, never runs it" ;; *) ng "W2d no next-step line" ;; esac
[ -d "$W" ] && ok "W2e worktree still exists (script never removes)" || ng "W2e worktree vanished"

echo "── W3 differ-both-sides: listed, NOT copied, rc=1 even with --apply ──"
echo same > "$M/tracks/_meta/shared.md"; echo "changed in wt" > "$W/tracks/_meta/shared.md"
OUT="$(bash "$SUT" "$W" --apply 2>&1)"; RC=$?
[ "$RC" -eq 1 ] && ok "W3 rc=1 (needs a human)" || ng "W3 rc=$RC (기대 1)"
case "$OUT" in *"DIFF  _meta/shared.md"*) ok "W3b the differing file is named" ;; *) ng "W3b DIFF not listed" ;; esac
grep -q '^same$' "$M/tracks/_meta/shared.md" && ok "W3c main copy untouched (known-negative: no overwrite)" || ng "W3c main copy was overwritten"

echo "── W4 list-before-copy: unwritable list dir → rc=10 and NO copy happened ──"
mk_pair "$T/b"; M="$T/b/main"; W="$T/b/wt"
mkdir -p "$W/tracks/_meta" && echo body > "$W/tracks/_meta/only.md"; rm -rf "$M/tracks/_meta/dispatch"; touch "$M/tracks/_meta/dispatch"   # a FILE where the dir must be
[ -f "$W/tracks/_meta/only.md" ] && ok "W4-FIXTURE the only-in file exists in the worktree (potency)" || ng "W4-FIXTURE fixture file missing — W4b would pass vacuously"
OUT="$(bash "$SUT" "$W" --apply 2>&1)"; RC=$?
[ "$RC" -eq 10 ] && ok "W4 rc=10 when the evidence file cannot be written" || ng "W4 rc=$RC (기대 10)"
[ ! -e "$M/tracks/_meta/only.md" ] && ok "W4b nothing was copied before the list failed (order holds)" || ng "W4b copy happened without a list"

echo "── W5 argument guards ──"
OUT="$(bash "$SUT" "$M" 2>&1)"; RC=$?; [ "$RC" -eq 2 ] && ok "W5 main checkout as argument → rc=2" || ng "W5 rc=$RC (기대 2)"
OUT="$(bash "$SUT" "$T" 2>&1)"; RC=$?; [ "$RC" -eq 2 ] && ok "W5b non-repo dir → rc=2" || ng "W5b rc=$RC (기대 2)"
OUT="$(bash "$SUT" "$W" --bogus 2>&1)"; RC=$?; [ "$RC" -eq 2 ] && ok "W5c unknown flag → rc=2" || ng "W5c rc=$RC (기대 2)"
OUT="$(bash "$SUT" 2>&1)"; RC=$?; [ "$RC" -eq 2 ] && ok "W5d no argument → rc=2" || ng "W5d rc=$RC (기대 2)"
# 🟥 W5e 는 2026-09-21 에 기대값이 뒤집혔다. 종전 판은 «tracks/ 없음 → rc=0 회수할 것 없음» 을
#    **옳은 동작으로 박아** 뒀는데, 그게 결함이다 — 스크립트가 tracks/ 만 보던 시절의 기대값이
#    레인에 화석으로 남아 거짓 초록을 인증하고 있었다. tracks/ 가 없으면 «그 구역이 빈» 것이지
#    «워크트리에 아무것도 없는» 것이 아니다. 지금은 진짜로 비어 있을 때만 rc=0 이다.
mk_pair "$T/c"; rm -rf "$T/c/wt/tracks"; OUT="$(bash "$SUT" "$T/c/wt" 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && ok "W5e worktree with no tracks/ AND no other artifact → rc=0" || ng "W5e rc=$RC (기대 0)"

echo "── W6 범위: «안 본 것» 을 «없는 것» 으로 렌더하나 (2026-09-21 실측) ──"
# WHY: 정책렌즈 워크트리가 `scripts/fixtures/…`(52파일)과 `scripts/score_policy_lens.sh` 를
# untracked 로만 들고 있었다. tracks/ 만 보던 스크립트는 «only-in-worktree: 0» 을 내고
# **«✅ safe to: git worktree remove»** 를 찍었다 — 비가역 표면에서 파괴를 «승인» 한 것이다.

mk_pair "$T/f"; M="$T/f/main"; W="$T/f/wt"
mkdir -p "$W/tracks/_meta" "$W/scripts/fixtures/kp"          # tracks/ 는 있고 «비어 있다» = 순수 얼굴
echo scorer > "$W/scripts/score_policy_lens.sh"; echo fx > "$W/scripts/fixtures/kp/a.txt"
OUT="$(bash "$SUT" "$W" 2>&1)"; RC=$?
case "$RC:$OUT" in
  0:*"safe to"*) ng "W6 tracks/ 밖 산출 2건인데 «safe to remove» 를 찍었다 — 거짓 초록" ;;
  0:*)           ng "W6 rc=0 (기대 비영) — 제거를 막지 않는다" ;;
  *"score_policy_lens.sh"*) ok "W6 tracks/ 밖 untracked 산출을 이름으로 세우고 제거를 안 승인한다 (rc=$RC)" ;;
  *)             ng "W6 rc=$RC 인데 출력에 파일명이 없다 — 왜 막는지 안 알려준다" ;;
esac
[ ! -e "$M/scripts/score_policy_lens.sh" ] \
  && ok "W6b OUTSIDE 는 자동 복사 «안» 한다 (목적지는 판단이지 기본값이 아니다)" \
  || ng "W6b OUTSIDE 를 본 체크아웃에 멋대로 옮겼다"

mk_pair "$T/g"; W="$T/g/wt"; rm -rf "$W/tracks"; echo art > "$W/leftover.md"
OUT="$(bash "$SUT" "$W" 2>&1)"; RC=$?
case "$RC:$OUT" in
  0:*"nothing to reclaim"*) ng "W6c tracks/ 부재를 «회수할 것 없음» 으로 읽었다 (:42 조기 exit)" ;;
  0:*) ng "W6c rc=0 — leftover.md 가 있는데 제거를 승인했다" ;;
  *"leftover.md"*) ok "W6c tracks/ 가 없어도 다른 산출을 본다 (rc=$RC)" ;;
  *) ng "W6c rc=$RC / 출력에 leftover.md 없음" ;;
esac

# 🟥 과차단 컨트롤 — 재생성 가능한 것으로 막으면 override 를 훈련시킨다(= 게이트 무장해제).
mk_pair "$T/h"; W="$T/h/wt"; mkdir -p "$W/tracks/_meta" "$W/node_modules/x" "$W/__pycache__" "$W/dist"
printf 'tracks/\nnode_modules/\n__pycache__/\ndist/\n.DS_Store\n*.pyc\n' > "$W/.gitignore"
echo j > "$W/node_modules/x/p.js"; echo c > "$W/__pycache__/m.pyc"; echo d > "$W/dist/out.js"
echo s > "$W/.DS_Store"; echo y > "$W/stale.pyc"
OUT="$(bash "$SUT" "$W" 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && ok "W6d 과차단 컨트롤: node_modules·__pycache__·dist·.DS_Store·*.pyc 는 안 막는다" \
                || ng "W6d 재생성 가능한 것으로 막았다 (rc=$RC) — override 훈련 방향"
# 🟥 그 컨트롤이 «아무거나 다 통과» 라서 초록인 게 아님을 같이 증명한다(죽은 컨트롤 방지).
echo real > "$W/keepme.md"; OUT="$(bash "$SUT" "$W" 2>&1)"; RC=$?
[ "$RC" -ne 0 ] && printf '%s' "$OUT" | grep -q "keepme.md" \
  && ok "W6e 같은 트리에 진짜 산출 1개를 더하면 막는다 — W6d 가 죽은 컨트롤이 아니다" \
  || ng "W6e rc=$RC — 제외 목록이 전부를 삼키고 있다"

# --apply 로도 OUTSIDE 는 안 사라진다: tracks/ 는 회수하고, 밖의 것은 여전히 사람 몫.
mk_pair "$T/i"; M="$T/i/main"; W="$T/i/wt"; mkdir -p "$W/tracks/_meta"
echo sig > "$W/tracks/_meta/sig.md"; echo out > "$W/outside.md"
OUT="$(bash "$SUT" "$W" --apply 2>&1)"; RC=$?
if [ -f "$M/tracks/_meta/sig.md" ] && [ ! -e "$M/outside.md" ] && [ "$RC" -ne 0 ]; then
  ok "W6f --apply: tracks/ 는 회수, OUTSIDE 는 안 옮기고 제거 승인도 안 한다 (rc=$RC)"
else
  ng "W6f copied=$([ -f "$M/tracks/_meta/sig.md" ] && echo 1 || echo 0) leaked=$([ -e "$M/outside.md" ] && echo 1 || echo 0) rc=$RC"
fi

echo "── W7 cross-family 가 잡은 것들 (2026-09-21, 적대검증 S1·A3) ──"
# 🟥 W6 가 전부 초록이었는데도 아래 넷이 살아 있었다. 원인 하나: mk_pair 의 .gitignore 가
#    `tracks/` 한 줄뿐이라 픽스처에 ⓐ `!!` 접두 ⓑ ignored 디렉터리 ⓒ tracked-modified 줄 이
#    **원리적으로 존재하지 않았다.** 계기가 대상과 다른 형태였다([[feedback_instrument_blindspot_correlated_with_arm]]).

# W7a 🟥 S-1 — 열거기가 죽으면 «빈 결과» 가 «깨끗함» 으로 읽히나. 실측 재현: git rc=128 · script rc=0 · «safe to».
mk_pair "$T/j"; W="$T/j/wt"; mkdir -p "$W/tracks/_meta"
G="$(git -C "$W" rev-parse --git-dir 2>/dev/null)"; printf 'garbage' > "$G/index"
OUT="$(bash "$SUT" "$W" 2>&1)"; RC=$?
if printf '%s' "$OUT" | grep -q "safe to"; then
  ng "W7a 열거기가 죽었는데 «safe to remove» 를 찍었다 (rc=$RC) — 이 스크립트 자신의 병"
elif [ "$RC" -eq 10 ]; then ok "W7a git status 실패 → rc=10 harness-error (빈 결과를 «깨끗함» 으로 안 읽는다)"
else ng "W7a rc=$RC (기대 10)"; fi

# W7b 🟥 A-1 — `${_l#?? }` 의 `?` 가 glob 이라 모든 상태줄을 먹었다. tracked-modified 가 OUTSIDE 로 샜다.
mk_pair "$T/k"; W="$T/k/wt"; mkdir -p "$W/tracks/_meta"; echo more >> "$W/README.md"
OUT="$(bash "$SUT" "$W" 2>&1)"; RC=$?
if printf '%s' "$OUT" | grep -q "OUTSIDE  README.md"; then
  ng "W7b tracked 파일(README.md)이 «git will not carry this» 로 찍혔다 — 거짓 라벨 + 과차단"
elif [ "$RC" -eq 0 ]; then ok "W7b tracked-modified 는 OUTSIDE 가 아니다 (커밋하면 살아남는다)"
else ng "W7b rc=$RC (기대 0) — tracked 변경만 있는데 막았다"; fi

# W7c 🟥 A-3 — ignored(«규칙을 일부러 쓴 것») 은 나열하되 막지 않는다. 안 그러면 실제 레포에서 rc=1 이 영구가 되고
#      «치울 수 없는 게이트» 가 `--force` 를 훈련시킨다(실측: fod 워크트리 `!!` 6줄, FH 본체는 세션마다 늘어난다).
mk_pair "$T/l"; W="$T/l/wt"; mkdir -p "$W/tracks/_meta" "$W/.claude"
# 🟥 초판 픽스처는 `.claude/.sentinel_abc` 라는 «지어낸 이름» 이었고, 그게 S-2 를 «옳음» 으로
#    동결했다 — 이름은 실물에서 뽑는다([[feedback_fixture_shape_from_artifact_not_mental_model]]).
printf 'tracks/\n.claude/.prior_art_prompted_*\n' > "$W/.gitignore"
echo s > "$W/.claude/.prior_art_prompted_abc123"
OUT="$(bash "$SUT" "$W" 2>&1)"; RC=$?
if [ "$RC" -eq 0 ] && printf '%s' "$OUT" | grep -q "SKIP  .claude/.prior_art_prompted_abc123"; then
  ok "W7c 세션 런타임 센티널은 «이름으로 나열하되 안 막는다» (rc=0)"
elif [ "$RC" -ne 0 ]; then ng "W7c 런타임 센티널로 막았다 (rc=$RC) — 영구 rc=1 · --force 훈련 방향"
else ng "W7c rc=0 인데 SKIP 목록에 이름이 없다 — 조용히 버렸다"; fi

# W7d 컨트롤 — W7c 가 «ignored 면 다 통과» 로 새지 않았나. 같은 트리에 untracked 를 하나 더하면 막아야 한다.
echo real > "$W/keep_me.md"; OUT="$(bash "$SUT" "$W" 2>&1)"; RC=$?
[ "$RC" -ne 0 ] && printf '%s' "$OUT" | grep -q "OUTSIDE  keep_me.md" \
  && ok "W7d untracked 는 여전히 막는다 — W7c 가 차단을 통째로 끄지 않았다" \
  || ng "W7d rc=$RC — ignored 완화가 untracked 차단까지 껐다"

# W7e 🟥 A-2 — 제외 목록의 «과소차단» 방향이 무음이었다. 이제 SKIP 으로 세고 목록 파일에 남긴다.
mk_pair "$T/m"; M="$T/m/main"; W="$T/m/wt"; mkdir -p "$W/tracks/_meta" "$W/node_modules/x"
printf 'tracks/\nnode_modules/\n' > "$W/.gitignore"    # 🟥 ignored 여야 SKIP (B-7: untracked 는 막는다)
echo j > "$W/node_modules/x/p.js"
OUT="$(bash "$SUT" "$W" 2>&1)"; RC=$?
L="$(ls -t "$M"/tracks/_meta/dispatch/reclaim_wt_*.txt 2>/dev/null | head -1)"
if [ "$RC" -eq 0 ] && printf '%s' "$OUT" | grep -q "non-blocking: skipped 1" \
   && [ -n "$L" ] && grep -q "^SKIP	node_modules/x/p.js" "$L"; then
  ok "W7e 제외분은 «버리는» 게 아니라 «세고 목록에 남긴다» — 과소차단 방향이 더는 무음이 아니다"
else
  ng "W7e rc=$RC · 요약에 skipped-regenerable 없음 또는 리스트에 SKIP 줄 없음"
fi

# W7f 🟥 B-4 — bash 3.2 호환 주장에 실행 팔이 0개였다. 빈 배열 경로를 /bin/bash 로 한 번 민다.
if [ -x /bin/bash ]; then
  mk_pair "$T/n"; W="$T/n/wt"; rm -rf "$W/tracks"
  OUT="$(/bin/bash "$SUT" "$W" 2>&1)"; RC=$?
  [ "$RC" -eq 0 ] && ok "W7f /bin/bash(3.2) 로 빈 배열 전 경로 통과 — 주장이 실행으로 선다" \
                  || ng "W7f /bin/bash rc=$RC: $(printf '%s' "$OUT" | head -2)"
else
  ng "W7f /bin/bash 가 없다 — 3.2 주장은 이 머신에서 미측정(NOT a pass)"
fi

# W7g 🟥 S-2 — ignored 인데 «지우면 아픈» 내용물. 1차 수리(«ignored 는 안 막는다»)가 판 구멍이다.
mk_pair "$T/o"; W="$T/o/wt"; mkdir -p "$W/tracks/_meta" "$W/knowledge/shared" "$W/outputs"
printf 'tracks/\nknowledge/**/*_paper_draft.md\noutputs/\n' > "$W/.gitignore"
echo draft > "$W/knowledge/shared/fh_paper_draft.md"; echo art > "$W/outputs/act2.png"
OUT="$(bash "$SUT" "$W" 2>&1)"; RC=$?
if printf '%s' "$OUT" | grep -q "safe to"; then
  ng "W7g 미출간 초고·주행 산출을 두고 «safe to remove» 를 찍었다 (rc=$RC) — ignored 완화가 판 구멍"
elif [ "$RC" -ne 0 ] && printf '%s' "$OUT" | grep -q "fh_paper_draft.md"; then
  ok "W7g ignored 라도 «화이트리스트 밖» 내용물은 막는다 (rc=$RC)"
else ng "W7g rc=$RC 인데 출력에 초고 이름이 없다"; fi

# W7h 🟥 A-5 — git 이 rc=0 으로 끝나면서 경고만 내는 «부분 열거». rc 만 보면 못 본다.
mk_pair "$T/q"; W="$T/q/wt"; mkdir -p "$W/tracks/_meta" "$W/blocked/inner"
echo real > "$W/blocked/inner/artifact.md"; chmod 000 "$W/blocked" 2>/dev/null
OUT="$(bash "$SUT" "$W" 2>&1)"; RC=$?
chmod 755 "$W/blocked" 2>/dev/null
if printf '%s' "$OUT" | grep -q "safe to"; then
  ng "W7h 읽기불가 디렉터리로 열거가 잘렸는데 «safe to remove» 를 찍었다 (rc=$RC)"
elif [ "$RC" -ne 0 ]; then ok "W7h 부분 열거를 «깨끗함» 으로 안 읽는다 (rc=$RC)"
else ng "W7h rc=0 — 부분 열거가 초록으로 갔다"; fi

# W7i 🟥 A-4 — SKIP 이 0 이 아닐 때 초록 문장이 그 사실을 데리고 나가나.
mk_pair "$T/r"; W="$T/r/wt"; mkdir -p "$W/tracks/_meta" "$W/node_modules"
printf 'tracks/\nnode_modules/\n' > "$W/.gitignore"; echo j > "$W/node_modules/p.js"
OUT="$(bash "$SUT" "$W" 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && printf '%s' "$OUT" | grep -q "skipped as regenerable/sentinel" \
  && ok "W7i 초록 문장이 «무엇을 건너뛰었는지» 를 데리고 나간다" \
  || ng "W7i rc=$RC — «nothing left» 가 SKIP 을 가린다"

echo
echo "── worktree-reclaim lanes: PASS=$PASS FAIL=$FAIL ──"
[ "$FAIL" -eq 0 ] || exit 1
exit 0

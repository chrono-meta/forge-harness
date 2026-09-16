#!/usr/bin/env bash
# test_precommit_gitlink_lanes.sh — known pair for pre-commit's nested-repo gitlink guard.
#
# WHAT IT GUARDS. `.gitignore` does not apply to a nested repository. `tracks/**` ignores every
# FILE under tracks/, but a directory that carries its own `.git` is offered to the index as a
# mode-160000 entry anyway — so `git add -A` stages it while the author believes the subtree is
# ignored. Measured 2026-09-16: `tracks/_meta/dominance_bench_B/recovered_2026-09-09/benchB/
# target_repo_O` (a benchmark's target repo) was staged by `git add -A --dry-run`.
#
# 🟥 WHY IT IS SILENT, which is why it needs a gate rather than a habit. A gitlink records a commit
# SHA in ANOTHER repository. A clone cannot fetch it, so the content is absent while the tree still
# looks complete — nothing in the commit output says the subtree did not travel.
#
# 🟥 SCOPE IS ASYMMETRIC ON PURPOSE, and L4 pins the half that is easy to "unify" away. Under
# tracks/ a gitlink is provably wrong (local-only lane) → BLOCK. Elsewhere this repo has no
# submodules today, but calling that a defect would over-block a legitimate future one, and a gate
# that over-blocks trains `--no-verify` — which disarms the Destructive-Op gate in the SAME hook.
# So elsewhere it surfaces and proceeds. The absence of a block there is the design, not a gap.
#
# HERMETIC: every fixture is a throwaway repo under mktemp. Never reads the real tree or real tracks/.
#
# Usage: bash scripts/test_precommit_gitlink_lanes.sh   Exit: 0 = all behave · 1 = regression · 10 = own setup broke.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
ROOT="$(pwd -P)"
HOOK="$ROOT/templates/.git-hooks/pre-commit"
PASS=0; FAIL=0
ok() { echo "✅ $1"; PASS=$((PASS+1)); }
ng() { echo "❌ $1"; FAIL=$((FAIL+1)); }

[ -f "$HOOK" ] || { echo "ⓘ subject missing: $HOOK — skipped is NOT passed"; exit 2; }

T="$(mktemp -d 2>/dev/null)" || { echo "ⓘ mktemp failed — this suite's own setup broke (NOT a pass)"; exit 10; }
trap 'rm -rf "$T"' EXIT INT TERM

# 🟥 The guard is a block inside a long hook that runs many other gates. Running the whole hook
# would make this suite measure everything EXCEPT what it claims to. So the block is extracted and
# run against a fixture repo — the same bytes, isolated. If the anchor ever moves, extraction yields
# nothing and L0 fails loudly rather than every lane passing vacuously.
awk '/^echo "\[Privacy\] nested-repo gitlink\.\.\."$/,/^fi$/' "$HOOK" > "$T/block.sh"
if [ ! -s "$T/block.sh" ] || ! grep -q 'GITLINK_BLOCKED' "$T/block.sh"; then
  ng "L0 setup — could not extract the gitlink block from the hook (anchor moved?)"
  echo "── precommit-gitlink lanes: PASS=$PASS FAIL=$FAIL ──"; exit 1
fi
ok "L0 block extracted from the live hook (not a second copy)"

# 픽스처 레포 하나 + 그 안에 중첩 레포 하나. 실제 사고와 같은 모양으로 짓는다
# ([[feedback_fixture_shape_from_artifact_not_mental_model]]) — 손으로 mode 160000 을 써넣지 않고,
# **진짜 중첩 레포를 만들어** git 이 스스로 gitlink 으로 계상하게 둔다.
mk_repo() {  # $1=경로
  git init -q "$1" 2>/dev/null || return 1
  git -C "$1" config user.email t@t; git -C "$1" config user.name t
  echo x > "$1/f.txt"; git -C "$1" add f.txt; git -C "$1" commit -qm init
}
# 🟥 **레인마다 자기 픽스처 레포를 짓는다.** 초판은 하나를 공유했고 앞 레인이 스테이징한
#    gitlink 이 인덱스에 남아 L3(known-negative)·L4 를 오염시켰다 — «막았다» 가 아니라
#    «앞 레인 것을 막고 있었다»였다. 공유 상태는 known-negative 를 구조적으로 무효화한다.
new_outer() {  # $1=이름 → stdout: 경로
  local d="$T/$1"
  mk_repo "$d" >/dev/null 2>&1 || return 1
  printf 'tracks/**\n!tracks/**/\n' > "$d/.gitignore"
  mkdir -p "$d/tracks/_meta/bench"
  printf '%s' "$d"
}

run_block() {  # cwd=$1, env 나머지는 호출자가 export
  ( cd "$1" && FAILED=0 && . "$T/block.sh" >"$T/out.txt" 2>&1; echo "$FAILED" )
}

# ── L1 known-positive: tracks/ 밑 중첩 레포가 실제로 gitlink 으로 스테이징되고, 가드가 막는다 ──
# 🟥 이 레인이 증명하는 첫 번째 것은 가드가 아니라 **결함 자체**다: .gitignore 가 `tracks/**` 인데도
#    add 가 그 디렉터리를 집는다. 그게 성립 안 하면 이 가드는 존재 이유가 없다.
O1=$(new_outer o1) || { ng "L0b 픽스처 레포 생성 실패"; exit 10; }
mk_repo "$O1/tracks/_meta/bench/target" >/dev/null 2>&1 || { ng "L0c 중첩 레포 생성 실패"; exit 10; }
( cd "$O1" && git add -A 2>/dev/null )
STAGED_MODE=$(cd "$O1" && git diff --cached --raw --no-renames 2>/dev/null | awk -F'\t' '$1 ~ / 160000 /{print $2}')
if [ "$STAGED_MODE" = "tracks/_meta/bench/target" ]; then
  ok "L1 결함 재현: .gitignore 가 tracks/** 인데도 중첩 레포가 gitlink 으로 스테이징된다"
else
  ng "L1 결함이 재현 안 됨 — 스테이징된 gitlink: [$STAGED_MODE] (계기 오류: 이 가드의 전제가 성립 안 함)"
fi
RC=$(run_block "$O1")
if [ "$RC" = "1" ] && grep -q "nested repo staged as a gitlink under tracks/" "$T/out.txt"; then
  ok "L2 BLOCK — tracks/ 밑 gitlink 에서 FAILED=1 이고 경로를 이름으로 댄다"
else
  ng "L2 안 막았다 (FAILED=$RC)"; sed 's/^/     /' "$T/out.txt"
fi

# ── L3 known-negative: gitlink 이 없으면 통과. 「아무거나 막는 가드」가 아님을 박는다 ──
O3=$(new_outer o3) || { ng "L3 setup 실패"; }
echo y > "$O3/plain.txt"; ( cd "$O3" && git add plain.txt 2>/dev/null )
RC=$(run_block "$O3")
if [ "$RC" = "0" ] && grep -q "✅ PASS" "$T/out.txt"; then
  ok "L3 known-negative: 평범한 파일만 스테이징되면 PASS (과차단 없음)"
else
  ng "L3 gitlink 없는데 막았다 (FAILED=$RC)"; sed 's/^/     /' "$T/out.txt"
fi

# ── L4 비대칭 고정: tracks/ **밖** 의 gitlink 은 표면화하되 막지 않는다 ──
# 🟥 이 레인이 없으면 다음 사람이 「일관성」이라며 repo-wide 차단으로 «통일»하고, 그 순간
#    정당한 서브모듈이 과차단되어 --no-verify 를 훈련시킨다. 부재가 설계임을 여기서 박는다.
O4=$(new_outer o4) || { ng "L4 setup 실패"; }
mkdir -p "$O4/vendor"
mk_repo "$O4/vendor/dep" >/dev/null 2>&1 || { ng "L4 setup 실패(중첩)"; }
( cd "$O4" && git add -A 2>/dev/null )
RC=$(run_block "$O4")
if [ "$RC" = "0" ] && grep -q "surfaced, not blocked" "$T/out.txt"; then
  ok "L4 비대칭: tracks/ 밖 gitlink 은 표면화만 (차단 아님 — 부재가 설계다)"
else
  ng "L4 tracks/ 밖 gitlink 처리가 규격과 다르다 (FAILED=$RC)"; sed 's/^/     /' "$T/out.txt"
fi

# ── L5 override 채널 — 검토된 경우에만, 그리고 조용하지 않게 ──
O5=$(new_outer o5) || { ng "L5 setup 실패"; }
mk_repo "$O5/tracks/_meta/bench/target2" >/dev/null 2>&1
( cd "$O5" && git add -A 2>/dev/null )
RC=$( cd "$O5" && FAILED=0 && TRACKS_GITLINK_OK=1 . "$T/block.sh" >"$T/out.txt" 2>&1; echo "$FAILED" )
if [ "$RC" = "0" ] && grep -q "TRACKS_GITLINK_OK=1" "$T/out.txt"; then
  ok "L5 override: TRACKS_GITLINK_OK=1 이면 통과하되 그 사실이 출력에 남는다"
else
  ng "L5 override 채널이 규격과 다르다 (FAILED=$RC)"; sed 's/^/     /' "$T/out.txt"
fi

# ── L6 되돌림 프로브 — 가드를 떼면 L2 가 정확히 빨개진다 ──
# 🟥 적용 확인은 **의미**로 한다. 텍스트만 보면 무효 뮤턴트가 통과한다(2026-09-16 실측).
sed 's/GITLINK_BLOCKED=1; FAILED=1/GITLINK_BLOCKED=0/' "$T/block.sh" > "$T/block_neutered.sh"
if ! grep -q 'GITLINK_BLOCKED=0$' "$T/block_neutered.sh"; then
  ng "L6 뮤턴트가 안 만들어졌다 (계기 오류)"
else
  RC=$( cd "$O1" && FAILED=0 && . "$T/block_neutered.sh" >"$T/out.txt" 2>&1; echo "$FAILED" )
  if [ "$RC" = "0" ]; then
    ok "L6 되돌림: 차단을 떼면 같은 입력이 통과한다 (앵커 생존)"
  else
    ng "L6 차단을 뗐는데도 FAILED=$RC — 이 레인이 재는 것은 이 가드가 아니다"
  fi
fi

echo
echo "── precommit-gitlink lanes: PASS=$PASS FAIL=$FAIL ──"
[ "$FAIL" -eq 0 ] || exit 1
exit 0

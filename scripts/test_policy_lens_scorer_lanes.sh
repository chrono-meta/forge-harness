#!/usr/bin/env bash
# test_policy_lens_scorer_lanes.sh — scripts/score_policy_lens.sh 의 앵커.
#
# WHY THIS FILE EXISTS. 2026-09-21, `new-code-anchor` 게이트가 그 채점기를 **MENTION_ONLY**
# 로 잡았다 — 이름을 부르는 레인은 있었고 **돌리는 레인은 없었다.** 채점기 자신이
# `--selftest` 를 들고 있었지만 어느 러너도 그걸 부르지 않았으므로, 「스위트가 초록」은
# 이 파일에 대해 아무것도 말하지 않았다. 🟥 **그건 같은 날 그 채점기를 고친 이유와 같은
# 형태다** — 안 돌린 것이 0 으로 나온다.
#
# 두 명제를 나눠서 묻는다:
#   ① 채점기의 known-pair 가 지금도 성립하나          (--selftest)
#   ② 채점기가 **1차 기록을 재현하나**                 (runs_round1 → SCORES.tsv 와 바이트 동일)
# ②가 하중선이다. VOID 기록이 공표한 「24 중 23 INVALID-NO-TOKEN」은 그 숫자를 낸 채점기가
# 바뀌면 조용히 뜻이 달라진다. 이 레인이 그 자리를 못박는다.
# ⚠️ 이식성 린트에 대한 답 — 이 레인은 **레포 고유 픽스처를 일부러 참조한다.**
# 보통은 「자기 픽스처를 mktemp 로 만들어라」가 옳고(2026-08-16 PMH 이식 selfcheck 35 FAIL),
# 여기서는 **판정 대상 자체가 이 레포에 커밋된 1차 런**이다 — 합성 픽스처로 바꾸면 P2 가
# 재는 것이 「VOID 문서가 공표한 그 숫자」가 아니게 되어 레인의 존재 이유가 사라진다.
# 🟥 그래서 이 파일과 채점기는 **출하하지 않는다**(`package_coverage_check.sh` ACCEPTED_ABSENT).
#    이식된 자산에 이 레인이 따라가지 않으므로 이식처에서 FAIL 할 자리가 없다.
set -uo pipefail
cd "$(dirname "$0")/.."
SC=scripts/score_policy_lens.sh
F=scripts/fixtures/policy_lens_knownpair_2026-09-21

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ✅ %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  ❌ %s\n' "$1"; }

[ -f "$SC" ] || { printf '🟥 HARNESS-ERROR: 대상이 없다 (%s)\n' "$SC" >&2; exit 9; }
[ -d "$F/runs_round1" ] || { printf '🟥 HARNESS-ERROR: 1차 런이 없다 (%s)\n' "$F/runs_round1" >&2; exit 9; }

T=$(mktemp -d "${TMPDIR:-/tmp}"/pls-lane-XXXXXX)
trap 'rm -rf "$T"' EXIT INT TERM

printf '── 정책렌즈 채점기 ──\n'

# P1 — 채점기 자신의 known-pair. 여기가 빨가면 아래 수치는 전부 무의미하다.
_o=$(bash "$SC" --selftest 2>&1); _r=$?
[ "$_r" -eq 0 ] && ok "P1 채점기 known-pair 성립 (--selftest rc=0)" \
                || { bad "P1 채점기 known-pair 가 죽었다 (rc=$_r)"; printf '%s\n' "$_o" | tail -4; }

# P2 — 1차 기록 재현. 바이트 동일이어야 한다.
bash "$SC" --key "$F/KEY.tsv" --runs "$F/runs_round1" > "$T/now.tsv" 2>"$T/err"; _r=$?
if [ "$_r" -ne 0 ]; then
  bad "P2 1차 런 재채점이 rc=$_r 로 죽었다"; head -3 "$T/err"
elif diff -q "$F/runs_round1/SCORES.tsv" "$T/now.tsv" >/dev/null 2>&1; then
  ok "P2 1차 기록(SCORES.tsv)을 바이트 동일하게 재현한다"
else
  bad "P2 1차 기록과 어긋난다 — VOID 문서의 수치가 지금 채점기로는 다른 뜻이다"
  diff -u "$F/runs_round1/SCORES.tsv" "$T/now.tsv" | head -12
fi

# P3 — P2 의 컨트롤. 대조가 «살아 있나». 한 줄만 흔들어도 P2 가 적색이 되어야 한다.
#      🟥 이게 없으면 P2 의 초록은 「diff 가 항상 통과한다」와 구분되지 않는다.
sed '3s/HIGH/LOW/' "$F/runs_round1/SCORES.tsv" > "$T/tampered.tsv"
if diff -q "$T/tampered.tsv" "$T/now.tsv" >/dev/null 2>&1; then
  bad "P3 한 칸 바꾼 사본이 여전히 «동일» 로 나온다 — P2 의 대조가 죽었다"
else
  ok "P3 한 칸만 바꿔도 대조가 적색 — P2 의 초록이 판별력을 가진다"
fi

# P4 — 영행 가드. 「안 읽었다」가 「나쁜 행 없음」으로 안 나온다.
E="$T/empty"; mkdir -p "$E"
_o=$(bash "$SC" --key "$F/KEY.tsv" --runs "$E" 2>&1); _r=$?
[ "$_r" -eq 4 ] && ok "P4 빈 런 디렉터리 → rc=4 (안 읽은 것이 초록으로 안 나온다)" \
                || bad "P4 빈 런 디렉터리가 rc=$_r 로 통과했다"

# P5 — P4 의 과차단 컨트롤. 정상 런은 그대로 0 이어야 한다(위 P2 가 rc=0 인 것이 그 증거).
_o=$(bash "$SC" --key "$F/KEY.tsv" --runs "$F/runs_round1" >/dev/null 2>&1); _r=$?
[ "$_r" -eq 0 ] && ok "P5 정상 런은 rc=0 — 영행 가드가 전부를 막지 않는다" \
                || bad "P5 정상 런을 rc=$_r 로 막았다"

printf 'PASS %d · FAIL %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]

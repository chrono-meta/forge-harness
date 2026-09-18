#!/usr/bin/env bash
# test_publish_verify_poll_lanes.sh — known-pair lanes for scripts/publish_verify_poll.sh.
#
# Runs the REAL script against a STUBBED `npm` (never touches the network/registry). The stub's
# shape is pulled from the real 2026-09-06/2026-09-18 incidents, not a mental model: a
# not-yet-visible exact version returns EMPTY STDOUT + NONZERO EXIT (matches the documented E404
# shape), never a stale different version.
#
# Lane summary (each is a known-positive or known-negative on a specific claim):
#   A  visible within budget, but only after the OLD 6-attempt/60s budget would have expired
#      -> proves the fix: exit 0, outcome=visible (this is today's incident, replayed against
#         the NEW script)
#   B  visible on the first call -> exit 0, outcome=visible, and NO wasted poll/sleep lines
#   C  never visible, budget exhausted -> exit 0 (**not a failure**), outcome=not_yet_visible.
#      This is the load-bearing negative lane: it proves budget exhaustion no longer reads as
#      "publish failed".
#   D  PKG_VERSION unset -> exit 2 (instrument error). Proves D is distinguishable from C: a
#      real misconfiguration must still fail closed even though C (a real timeout) must not.
#   E  POLL_ATTEMPTS non-numeric -> exit 2 (instrument error), same reasoning as D.
#
# Fixture note: the OLD script (the one this replaces) is deliberately NOT re-implemented here —
# lane A's threshold (call 9) is chosen because it is documented in publish.yml's own history
# comment as the observed real lag, and it is *larger* than the old 6-attempt budget, so it acts
# as the regression anchor: if someone shrinks POLL_ATTEMPTS back down without noticing, lane A
# starts failing loudly instead of silently losing coverage.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${PUBLISH_VERIFY_SCRIPT:-$HERE/publish_verify_poll.sh}"
STUB_NPM_IMPL="${PUBLISH_VERIFY_STUB_IMPL:-$HERE/publish_verify_poll_stub_npm.sh}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

STUBBIN="$WORK/stubbin"
mkdir -p "$STUBBIN"
{
  echo '#!/usr/bin/env bash'
  echo "exec \"$STUB_NPM_IMPL\" \"\$@\""
} > "$STUBBIN/npm"
chmod +x "$STUBBIN/npm"

PASS=0
FAIL=0

check() {
  # check <label> <expected_exit> <actual_exit> <expected_outcome_or_-> <outputs_file_or_->
  label="$1"; want_exit="$2"; got_exit="$3"; want_outcome="$4"; outfile="$5"
  ok=1
  if [ "$got_exit" != "$want_exit" ]; then
    echo "FAIL $label: exit code = $got_exit, want $want_exit"
    ok=0
  fi
  if [ "$want_outcome" != "-" ]; then
    if [ ! -f "$outfile" ]; then
      echo "FAIL $label: expected outputs file '$outfile' missing"
      ok=0
    else
      got_outcome=$(/usr/bin/grep -m1 '^outcome=' "$outfile" | cut -d= -f2- || true)
      if [ "$got_outcome" != "$want_outcome" ]; then
        echo "FAIL $label: outcome='$got_outcome', want '$want_outcome'"
        ok=0
      fi
    fi
  fi
  if [ "$ok" = 1 ]; then
    echo "PASS $label"
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
  fi
}

run_case() {
  # run_case <counter_file> <threshold> <pkg_version> <attempts> <interval> <outfile> [extra_env...]
  cf="$1"; threshold="$2"; ver="$3"; attempts="$4"; interval="$5"; outfile="$6"
  rm -f "$cf" "$outfile"
  set +e
  PATH="$STUBBIN:$PATH" \
  STUB_TARGET_VERSION="$ver" STUB_CALLS_UNTIL_VISIBLE="$threshold" STUB_COUNTER_FILE="$cf" \
  PKG_VERSION="$ver" POLL_ATTEMPTS="$attempts" POLL_INTERVAL_S="$interval" \
  PUBLISH_VERIFY_OUTPUT="$outfile" \
    bash "$SCRIPT" > "$outfile.log" 2>&1
  rc=$?
  set -e
  echo "$rc"
}

echo "== lane A: visible on 9th call (today's incident shape), 30-attempt/1s-scaled budget =="
rc=$(run_case "$WORK/cnt_a" 9 "9.9.9" 30 0 "$WORK/out_a")
check "A (eventually visible within new budget)" 0 "$rc" visible "$WORK/out_a"

echo "== lane B: visible on 1st call — no wasted attempts =="
rc=$(run_case "$WORK/cnt_b" 1 "9.9.9" 30 10 "$WORK/out_b")
check "B (immediately visible)" 0 "$rc" visible "$WORK/out_b"
calls_b=$(cat "$WORK/cnt_b" 2>/dev/null || echo "?")
if [ "$calls_b" = "1" ]; then
  echo "PASS B (exactly 1 registry call, no idle waiting)"
  PASS=$((PASS + 1))
else
  echo "FAIL B: expected exactly 1 stub call, got $calls_b"
  FAIL=$((FAIL + 1))
fi

echo "== lane C: never visible, budget exhausted — MUST stay non-failing =="
rc=$(run_case "$WORK/cnt_c" 999 "9.9.9" 3 0 "$WORK/out_c")
check "C (budget exhausted is not_yet_visible, not a failure)" 0 "$rc" not_yet_visible "$WORK/out_c"
if /usr/bin/grep -q "Do NOT hand-publish" "$WORK/out_c.log" 2>/dev/null; then
  echo "PASS C (carries the do-not-hand-publish warning)"
  PASS=$((PASS + 1))
else
  echo "FAIL C: missing the do-not-hand-publish warning text"
  FAIL=$((FAIL + 1))
fi

echo "== lane D: PKG_VERSION unset — instrument error, distinguishable from C =="
set +e
rm -f "$WORK/out_d"
PATH="$STUBBIN:$PATH" PUBLISH_VERIFY_OUTPUT="$WORK/out_d" bash "$SCRIPT" > "$WORK/out_d.log" 2>&1
rc=$?
set -e
check "D (PKG_VERSION unset -> exit 2)" 2 "$rc" - "$WORK/out_d"
if [ -f "$WORK/out_d" ]; then
  echo "FAIL D: outputs file should not exist on an instrument error (no outcome should be claimed)"
  FAIL=$((FAIL + 1))
else
  echo "PASS D (no outcome claimed on instrument error)"
  PASS=$((PASS + 1))
fi

echo "== lane E: POLL_ATTEMPTS=abc — instrument error =="
set +e
PKG_VERSION="9.9.9" POLL_ATTEMPTS="abc" bash "$SCRIPT" > "$WORK/out_e.log" 2>&1
rc=$?
set -e
check "E (non-numeric POLL_ATTEMPTS -> exit 2)" 2 "$rc" - -

echo
echo "== known-negative on the checker itself: D and E must NOT collide with C's exit code =="
# This is the calibration pair the mission asked for: if a future edit made timeouts exit 2 too
# (or instrument errors exit 0), this lane goes red instead of the drift passing silently.
rc_c=$(run_case "$WORK/cnt_c2" 999 "9.9.9" 2 0 "$WORK/out_c2")
if [ "$rc_c" = "0" ]; then
  echo "PASS calibration (timeout=0 stays distinct from instrument-error=2)"
  PASS=$((PASS + 1))
else
  echo "FAIL calibration: timeout exit changed to $rc_c — now indistinguishable from instrument error"
  FAIL=$((FAIL + 1))
fi

echo
echo "== lane F: NPM_VIEW_BIN 이 실행 불가 — 계기 오류이고 전파 지연이 아니다 =="
# 🟥 cross-family(codex 2026-09-18) S급 1 의 회귀 앵커. 종전 `|| true` 는 command-not-found 를
#    삼켜서 got 을 비우고 그대로 `not_yet_visible`(비차단 경고)로 보냈다 — 「미측정」이 「통과」다.
_of="$WORK/out_f"; : > "$_of"
set +e
PKG_VERSION="9.9.9" POLL_ATTEMPTS=1 POLL_INTERVAL_S=0 \
  NPM_VIEW_BIN="$WORK/definitely-not-a-binary-zzz" \
  PUBLISH_VERIFY_OUTPUT="$_of" bash "$SCRIPT" >"$WORK/f.log" 2>&1
rc_f=$?
set -e
if [ "$rc_f" = "2" ]; then
  echo "PASS F (조회기 부재 -> exit 2, 계기 오류)"; PASS=$((PASS + 1))
else
  echo "FAIL F: 조회기가 없는데 rc=$rc_f 였다 (2 를 기대) — 계기 오류가 전파 지연으로 접혔다"
  sed 's/^/        /' "$WORK/f.log" | head -5; FAIL=$((FAIL + 1))
fi
if grep -q "outcome=not_yet_visible" "$_of" 2>/dev/null; then
  echo "FAIL F: 계기 오류인데 outcome=not_yet_visible 을 적었다 — 판정을 내지 말아야 한다"
  FAIL=$((FAIL + 1))
else
  echo "PASS F (계기 오류에서 outcome 을 주장하지 않는다)"; PASS=$((PASS + 1))
fi

echo
echo "== lane G: 출력 채널이 없을 때 판정이 stdout 으로라도 나가는가 =="
# 🟥 cross-family S급 2 의 회귀 앵커. 채널이 없으면 호출부의 `if: outputs.outcome == ...` 가
#    비어서 false 로 평가되고 경고가 아예 안 뜬다. 채널을 하나로 두지 않는 것이 처방이다.
set +e
( unset GITHUB_OUTPUT PUBLISH_VERIFY_OUTPUT
  PKG_VERSION="9.9.9" POLL_ATTEMPTS=1 POLL_INTERVAL_S=0 \
  PUBLISH_VERIFY_STUB_COUNTER="$WORK/cnt_g" PATH="$STUBBIN:$PATH" bash "$SCRIPT" ) >"$WORK/g.log" 2>&1
rc_g=$?
set -e
if [ "$rc_g" = "0" ] && grep -q "PUBLISH_VERIFY_OUTCOME=not_yet_visible" "$WORK/g.log"; then
  echo "PASS G (채널 부재에서도 stdout 에 기계가독 판정이 있다)"; PASS=$((PASS + 1))
else
  echo "FAIL G: rc=$rc_g · stdout 에 PUBLISH_VERIFY_OUTCOME 이 없다 — 판정이 조용히 사라졌다"
  sed 's/^/        /' "$WORK/g.log" | head -8; FAIL=$((FAIL + 1))
fi
if grep -q "no output channel" "$WORK/g.log"; then
  echo "PASS G (채널 부재를 stderr 로 시끄럽게 알린다)"; PASS=$((PASS + 1))
else
  echo "FAIL G: 채널 부재가 조용했다 — 경고가 없으면 호출부가 못 알아챈다"; FAIL=$((FAIL + 1))
fi

echo
echo "TOTAL: $PASS passed, $FAIL failed"
[ "$FAIL" = 0 ]

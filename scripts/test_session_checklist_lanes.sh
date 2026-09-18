#!/bin/bash
# test_session_checklist_lanes.sh — known-pair lanes for session_checklist.py
# bash 3.2 compatible: no mapfile, no ${var,,}, no associative arrays.
set -u

SUBJ="${SUBJ:-scripts/session_checklist.py}"

PASS_COUNT=0
FAIL_COUNT=0

pass() { echo "✅ PASS $1"; PASS_COUNT=$((PASS_COUNT+1)); }
fail() { echo "❌ FAIL $1"; FAIL_COUNT=$((FAIL_COUNT+1)); }

run() {
  local out="$1"
  shift
  python3 "$SUBJ" "$@" >"$out" 2>&1
  RC=$?
}

TMPDIR_ROOT=$(mktemp -d 2>/dev/null || mktemp -d -t schk)
trap 'rm -rf "$TMPDIR_ROOT"' EXIT

# ---------------------------------------------------------------------------
# L1 — syntax + --help names the rc contract
# ---------------------------------------------------------------------------
L1_SYN_OUT="$TMPDIR_ROOT/l1_syn.out"
python3 -c "import ast; ast.parse(open('$SUBJ').read())" >"$L1_SYN_OUT" 2>&1
L1_SYN_RC=$?

run "$TMPDIR_ROOT/l1_help.out" --help
L1_HELP_RC=$RC

if [ "$L1_SYN_RC" -eq 0 ] && [ "$L1_HELP_RC" -eq 0 ] \
   && grep -q "rc=4" "$TMPDIR_ROOT/l1_help.out" \
   && grep -q "rc=10" "$TMPDIR_ROOT/l1_help.out" \
   && grep -qi "DEAD CONTROL" "$TMPDIR_ROOT/l1_help.out"; then
  pass "L1 syntax clean + --help names rc contract"
else
  fail "L1 syntax_rc=$L1_SYN_RC help_rc=$L1_HELP_RC (see $TMPDIR_ROOT/l1_help.out)"
fi

# ---------------------------------------------------------------------------
# fixture builder for L2 / L2b — 3 raw + 4 excluded-class entries + 1 compaction
# summary carrying 3 quotes (1 duplicate of a raw utterance)
# ---------------------------------------------------------------------------
build_l2_fixture() {
  # $1 = out path, $2 = "with_summary" | "no_summary"
  python3 - "$1" "$2" <<'PYEOF'
import json, sys
out_path, mode = sys.argv[1], sys.argv[2]

RAW1 = "체크리스트 인스트루먼트 만들어줘 스크래치패드에 파이썬으로"
RAW2 = "L2 레인 통과하는지 확인해줘"
RAW3 = "야간자율주행 계속해도 좋아"

rows = [
    {"type": "user", "timestamp": "2026-09-17T05:56:00.000Z",
     "message": {"role": "user", "content": RAW1}},
    {"type": "user",
     "message": {"role": "user", "content": [
         {"type": "tool_result", "tool_use_id": "t1", "content": "some tool output"}
     ]}},
    {"type": "user",
     "message": {"role": "user",
                 "content": "<system-reminder>\nreminder body\n</system-reminder>"}},
    {"type": "user",
     "message": {"role": "user",
                 "content": "<task-notification>agent finished</task-notification> extra"}},
    {"type": "user",
     "message": {"role": "user",
                 "content": "Another Claude session sent a message: hello there"}},
    {"type": "user", "timestamp": "2026-09-17T06:01:00.000Z",
     "message": {"role": "user", "content": RAW2}},
    {"type": "user", "timestamp": "2026-09-17T06:05:00.000Z",
     "message": {"role": "user", "content": RAW3}},
]

if mode == "with_summary":
    summary_text = (
        "This session is being continued from a previous conversation "
        "that ran out of context.\n\n"
        "Summary:\n"
        "1. Primary Request and Intent:\n"
        "   - placeholder narrative text, not a quote list.\n\n"
        "6. All user messages:\n"
        '   - "' + RAW1 + '"\n'
        '   - "새로운 이월 항목 검토해줘"\n'
        '   - "체크리스트 스펙 문서 확인해봐"\n\n'
        "7. Pending Tasks:\n"
        "   - something not in the quote list\n"
    )
    rows.append({"type": "user", "message": {"role": "user", "content": summary_text}})

with open(out_path, "w", encoding="utf-8") as f:
    for r in rows:
        f.write(json.dumps(r, ensure_ascii=False) + "\n")
PYEOF
}

L2_JSONL="$TMPDIR_ROOT/l2.jsonl"
build_l2_fixture "$L2_JSONL" "with_summary"

run "$TMPDIR_ROOT/l2.out" extract --transcript "$L2_JSONL"
L2_ROWCOUNT=$(grep -c '^| ' "$TMPDIR_ROOT/l2.out")
# subtract the header row (which also starts with '| ') to get data rows
L2_DATAROWS=$((L2_ROWCOUNT - 1))

if [ "$RC" -eq 0 ] \
   && grep -q "채널 2/2" "$TMPDIR_ROOT/l2.out" \
   && grep -q "raw 3건" "$TMPDIR_ROOT/l2.out" \
   && grep -q "압축 요약 3건(중복 제거 후 2건 추가)" "$TMPDIR_ROOT/l2.out" \
   && [ "$L2_DATAROWS" -eq 5 ]; then
  pass "L2 extract: 3 raw + 2/3 summary added, 5 data rows, channel 2/2"
else
  fail "L2 rc=$RC datarows=$L2_DATAROWS (see $TMPDIR_ROOT/l2.out)"
fi

L2B_JSONL="$TMPDIR_ROOT/l2b.jsonl"
build_l2_fixture "$L2B_JSONL" "no_summary"

run "$TMPDIR_ROOT/l2b.out" extract --transcript "$L2B_JSONL"
L2B_ROWCOUNT=$(grep -c '^| ' "$TMPDIR_ROOT/l2b.out")
L2B_DATAROWS=$((L2B_ROWCOUNT - 1))

if [ "$RC" -eq 0 ] \
   && grep -q "채널 2/2" "$TMPDIR_ROOT/l2b.out" \
   && grep -q "압축 요약 0건(중복 제거 후 0건 추가)" "$TMPDIR_ROOT/l2b.out" \
   && [ "$L2B_DATAROWS" -eq 3 ]; then
  pass "L2b extract without summary entry: channel still 2/2, 0/0, 3 rows"
else
  fail "L2b rc=$RC datarows=$L2B_DATAROWS (see $TMPDIR_ROOT/l2b.out)"
fi

# ---------------------------------------------------------------------------
# L3 — check on a fully filled fixture -> rc=0
# ---------------------------------------------------------------------------
L3_MD="$TMPDIR_ROOT/l3_clean.md"
{
  echo "# clean checklist"
  echo ""
  echo "| # | 시각 | 발화(요지) | 상태 | 증거 | 사유 / 남은 것 | 제안 |"
  echo "|---|---|---|---|---|---|---|"
  echo "| 1 | 09-17 05:56 | greeting | n/a | — | — | — |"
  echo "| 2 | 09-17 06:01 | did the thing | ✅ | fixture.md:1 | — | — |"
  echo "| 3 | 09-17 06:05 | still going | ⏳ | wip.md | 팔이 도는 중 | 다음 세션 |"
  echo "| 4 | 09-17 06:10 | half done | 🟡 | partial.md:9 | 일부만 착지 | 이번 세션 |"
  echo "| 5 | 09-17 06:15 | held by operator | ⏸ | — | 운영자 보류 지시 | 이월 |"
  echo "| 6 | 09-17 06:20 | cannot confirm | 🔎 | — | 기록에서 증거 못 찾음 | 다음 세션 재구성 |"
  echo "| 7 | 09-17 06:25 | dropped | ❌ | — | 우선순위 밀림 | 이월 |"
} > "$L3_MD"

run "$TMPDIR_ROOT/l3.out" check --file "$L3_MD"
if [ "$RC" -eq 0 ] && grep -q "rows=7 ok=7 violations=0 rc=0" "$TMPDIR_ROOT/l3.out"; then
  pass "L3 check on fully filled fixture -> rc=0"
else
  fail "L3 rc=$RC (see $TMPDIR_ROOT/l3.out)"
fi

# ---------------------------------------------------------------------------
# L4 — three known violations -> rc=1, three violations naming right rows
# ---------------------------------------------------------------------------
L4_MD="$TMPDIR_ROOT/l4_violations.md"
{
  echo "# violating checklist"
  echo ""
  echo "| # | 시각 | 발화(요지) | 상태 | 증거 | 사유 / 남은 것 | 제안 |"
  echo "|---|---|---|---|---|---|---|"
  echo "| 1 | 09-17 05:56 | clean done row | ✅ | fixture.md:1 | — | — |"
  echo "| 2 | 09-17 06:01 | enum violation | ✔ done | ev | reason | proposal |"
  echo "| 3 | 09-17 06:05 | not-done missing reason | ❌ | — |  | some proposal |"
  echo "| 4 | 09-17 06:10 | done missing evidence | ✅ | — | — | — |"
} > "$L4_MD"

run "$TMPDIR_ROOT/l4.out" check --file "$L4_MD"
if [ "$RC" -eq 1 ] \
   && grep -q "^row 2 invalid" "$TMPDIR_ROOT/l4.out" \
   && grep -q "^row 3 missing 사유" "$TMPDIR_ROOT/l4.out" \
   && grep -q "^row 4 DONE missing 증거" "$TMPDIR_ROOT/l4.out" \
   && grep -q "violations=3" "$TMPDIR_ROOT/l4.out"; then
  pass "L4 check: 3 known violations, right rows named, rc=1"
else
  fail "L4 rc=$RC (see $TMPDIR_ROOT/l4.out)"
fi

# ---------------------------------------------------------------------------
# L5 — header + zero data rows -> rc=4 (DEAD CONTROL)
# ---------------------------------------------------------------------------
L5_MD="$TMPDIR_ROOT/l5_empty.md"
{
  echo "# empty table"
  echo ""
  echo "| # | 시각 | 발화(요지) | 상태 | 증거 | 사유 / 남은 것 | 제안 |"
  echo "|---|---|---|---|---|---|---|"
} > "$L5_MD"

run "$TMPDIR_ROOT/l5.out" check --file "$L5_MD"
if [ "$RC" -eq 4 ] && grep -q "rows=0 ok=0 violations=0 rc=4" "$TMPDIR_ROOT/l5.out"; then
  pass "L5 check on header-only table -> rc=4 DEAD CONTROL"
else
  fail "L5 rc=$RC (see $TMPDIR_ROOT/l5.out)"
fi

# ---------------------------------------------------------------------------
# L6 — missing path -> rc=10
# ---------------------------------------------------------------------------
run "$TMPDIR_ROOT/l6.out" check --file "$TMPDIR_ROOT/does_not_exist_$$.md"
if [ "$RC" -eq 10 ] && grep -q "rc=10" "$TMPDIR_ROOT/l6.out"; then
  pass "L6 check on missing path -> rc=10"
else
  fail "L6 rc=$RC (see $TMPDIR_ROOT/l6.out)"
fi

# ---------------------------------------------------------------------------
# L7 — revert probe: patch enum-membership fallthrough to always pass,
#      show L4(a) violation goes GREEN on the copy while original stays RED.
# ---------------------------------------------------------------------------
L7_COPY="$TMPDIR_ROOT/session_checklist_patched.py"
cp "$SUBJ" "$L7_COPY"

L7_PATCH_OUT="$TMPDIR_ROOT/l7_patch.out"
python3 - "$L7_COPY" >"$L7_PATCH_OUT" 2>&1 <<'PYEOF'
import sys
path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    lines = f.readlines()
target = "    return None  # ENUM-MEMBERSHIP-FALLTHROUGH\n"
count = sum(1 for l in lines if l == target)
print("ANCHOR-COUNT", count)
if count != 1:
    sys.exit(2)
for i, l in enumerate(lines):
    if l == target:
        lines[i] = "    return 'DONE'  # PATCHED-FOR-REVERT-PROBE\n"
        break
with open(path, "w", encoding="utf-8") as f:
    f.writelines(lines)
PYEOF
L7_PATCH_RC=$?

L7_MD="$TMPDIR_ROOT/l7_single_violation.md"
{
  echo "# single enum violation"
  echo ""
  echo "| # | 시각 | 발화(요지) | 상태 | 증거 | 사유 / 남은 것 | 제안 |"
  echo "|---|---|---|---|---|---|---|"
  echo "| 1 | 09-17 06:01 | enum violation | ✔ done | ev | reason | proposal |"
} > "$L7_MD"

python3 "$SUBJ" check --file "$L7_MD" >"$TMPDIR_ROOT/l7_orig.out" 2>&1
L7_ORIG_RC=$?
python3 "$L7_COPY" check --file "$L7_MD" >"$TMPDIR_ROOT/l7_patched.out" 2>&1
L7_PATCHED_RC=$?

if [ "$L7_PATCH_RC" -eq 0 ] && grep -q "ANCHOR-COUNT 1" "$L7_PATCH_OUT" \
   && [ "$L7_ORIG_RC" -eq 1 ] && grep -q "^row 1 invalid" "$TMPDIR_ROOT/l7_orig.out" \
   && [ "$L7_PATCHED_RC" -eq 0 ] && ! grep -q "invalid" "$TMPDIR_ROOT/l7_patched.out"; then
  pass "L7 revert probe: exactly 1 anchor line, original RED / patched GREEN"
else
  fail "L7 patch_rc=$L7_PATCH_RC orig_rc=$L7_ORIG_RC patched_rc=$L7_PATCHED_RC (see $TMPDIR_ROOT/l7_*.out)"
fi

# ---------------------------------------------------------------------------
# L8 — real transcript, env-gated
# ---------------------------------------------------------------------------
if [ -z "${CHECKLIST_REAL_TRANSCRIPT:-}" ]; then
  echo "⏭ SKIP L8 (SKIP ≠ PASS)"
else
  run "$TMPDIR_ROOT/l8.out" extract --transcript "$CHECKLIST_REAL_TRANSCRIPT"
  L8_ROWCOUNT=$(grep -c '^| ' "$TMPDIR_ROOT/l8.out")
  L8_DATAROWS=$((L8_ROWCOUNT - 1))
  if [ "$RC" -eq 0 ] && [ "$L8_DATAROWS" -ge 1 ] && grep -q "채널 2/2" "$TMPDIR_ROOT/l8.out"; then
    pass "L8 real-transcript extract: rows=$L8_DATAROWS, channel 2/2"
  else
    fail "L8 rc=$RC datarows=$L8_DATAROWS (see $TMPDIR_ROOT/l8.out)"
  fi
fi

echo "── $PASS_COUNT passed, $FAIL_COUNT failed ──"

if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
exit 0

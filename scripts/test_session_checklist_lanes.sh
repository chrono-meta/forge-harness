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

# ---------------------------------------------------------------------------
# L9–L14 — 🟥 cross-family round 1 (codex, 2026-09-18): 4 MAJOR + 3 MINOR, every one silent.
#   L9  a summary quote wrapped across two lines was dropped with no header signal
#   L10 two DISTINCT requests sharing their first 40 chars collapsed into one (dedupe on a prefix)
#   L11 a fenced example table was picked as THE checklist and masked the real one (rc=0)
#   L12 a clean earlier table masked a malformed later one (only the first table was checked)
#   L13 a row shorter than the header passed
#   L14 an escaped inner quote split one utterance into two rows (header over-counted)
# ---------------------------------------------------------------------------
build_jsonl() {  # build_jsonl <out> <python expr producing list of dicts>
  python3 - "$1" "$2" <<'PYEOF'
import json, sys
out, expr = sys.argv[1], sys.argv[2]
rows = eval(expr)
with open(out, "w", encoding="utf-8") as f:
    for r in rows:
        f.write(json.dumps(r, ensure_ascii=False) + "\n")
PYEOF
}
SUMHEAD='This session is being continued from a previous conversation that ran out of context.\n\nSummary:\n1. Primary Request and Intent:\n   - setup\n\n6. All user messages:\n'
SUMTAIL='\n7. Pending Tasks:\n   - keep going\n'

# L9
build_jsonl "$TMPDIR_ROOT/l9.jsonl" "[{'type':'user','message':{'role':'user','content':'$SUMHEAD   - \"Please update the rollout checklist,\n     then verify every unchecked item\"$SUMTAIL'}}]"
run "$TMPDIR_ROOT/l9.out" extract --transcript "$TMPDIR_ROOT/l9.jsonl"
if [ "$RC" -eq 0 ] && grep -q "압축 요약 1건(중복 제거 후 1건 추가)" "$TMPDIR_ROOT/l9.out" \
   && grep -q "rollout checklist, then verify every unchecked item" "$TMPDIR_ROOT/l9.out"; then
  pass "L9 extract: a summary quote wrapped over two lines is one row (was dropped silently)"
else
  fail "L9 rc=$RC (see $TMPDIR_ROOT/l9.out)"
fi

# L10
build_jsonl "$TMPDIR_ROOT/l10.jsonl" "[{'type':'user','timestamp':'2026-09-18T01:00:00.000Z','message':{'role':'user','content':'Please investigate the deployment checklist alpha path and record evidence for it.'}},{'type':'user','message':{'role':'user','content':'$SUMHEAD   - \"Please investigate the deployment checklist beta path and record a separate proposal.\"\n   - \"Please investigate the deployment checklist alpha path and record evidence for it.\"$SUMTAIL'}}]"
run "$TMPDIR_ROOT/l10.out" extract --transcript "$TMPDIR_ROOT/l10.jsonl"
if [ "$RC" -eq 0 ] && grep -q "압축 요약 2건(중복 제거 후 1건 추가)" "$TMPDIR_ROOT/l10.out" \
   && grep -q "^| S1 | (요약) | Please investigate the deployment checklist beta path" "$TMPDIR_ROOT/l10.out"; then
  pass "L10 extract: distinct request sharing the first 40 chars is ADDED; the true duplicate is dropped"
else
  fail "L10 rc=$RC (see $TMPDIR_ROOT/l10.out)"
fi

# L11
{
  echo "# code fence masks bad table"; echo
  echo '```md'
  echo "| # | 시각 | 발화(요지) | 상태 | 증거 | 사유 / 남은 것 | 제안 |"
  echo "|---|---|---|---|---|---|---|"
  echo "| 1 | 09-18 01:00 | fenced clean row | ✅ | fx/evidence.md:1 | — | — |"
  echo '```'; echo
  echo "| # | 시각 | 발화(요지) | 상태 | 증거 | 사유 / 남은 것 | 제안 |"
  echo "|---|---|---|---|---|---|---|"
  echo "| 1 | 09-18 01:05 | actual bad row | ❌ | — |  |  |"
} > "$TMPDIR_ROOT/l11.md"
run "$TMPDIR_ROOT/l11.out" check --file "$TMPDIR_ROOT/l11.md"
if [ "$RC" -eq 1 ] && grep -q "^row 1 missing 사유" "$TMPDIR_ROOT/l11.out" && grep -q "rows=1 " "$TMPDIR_ROOT/l11.out"; then
  pass "L11 check: a fenced example table is ignored; the real table's bad row is RED"
else
  fail "L11 rc=$RC (see $TMPDIR_ROOT/l11.out)"
fi

# L12
{
  echo "# earlier table masks bad table"; echo
  echo "| # | 시각 | 발화(요지) | 상태 | 증거 | 사유 / 남은 것 | 제안 |"
  echo "|---|---|---|---|---|---|---|"
  echo "| 1 | 09-18 01:00 | stale completed row | ✅ | old.md:1 | — | — |"; echo
  echo "Some later checklist is the one a reviewer would inspect."; echo
  echo "| # | 시각 | 발화(요지) | 상태 | 증거 | 사유 / 남은 것 | 제안 |"
  echo "|---|---|---|---|---|---|---|"
  echo "| 1 | 09-18 01:05 | actual bad row | ❌ | — |  |  |"
} > "$TMPDIR_ROOT/l12.md"
run "$TMPDIR_ROOT/l12.out" check --file "$TMPDIR_ROOT/l12.md"
if [ "$RC" -eq 1 ] && grep -q "^row table 2 1 missing 사유" "$TMPDIR_ROOT/l12.out" && grep -q "rows=2 .*tables=2" "$TMPDIR_ROOT/l12.out"; then
  pass "L12 check: every 상태 table is checked — the later bad table is RED (table 2 named)"
else
  fail "L12 rc=$RC (see $TMPDIR_ROOT/l12.out)"
fi

# L13
{
  echo "# short row"; echo
  echo "| # | 시각 | 발화(요지) | 상태 | 증거 | 사유 / 남은 것 | 제안 |"
  echo "|---|---|---|---|---|---|---|"
  echo "| 1 | 09-18 01:00 | truncated but accepted | n/a |"
  echo "| 2 | 09-18 01:01 | compact spelling is fine | ✅DONE | ev.md:1 | — | — |"
} > "$TMPDIR_ROOT/l13.md"
run "$TMPDIR_ROOT/l13.out" check --file "$TMPDIR_ROOT/l13.md"
if [ "$RC" -eq 1 ] && grep -q "^row 1 short (4 cells < header 7)" "$TMPDIR_ROOT/l13.out" && grep -q "violations=1" "$TMPDIR_ROOT/l13.out"; then
  pass "L13 check: a row shorter than the header is a violation; compact ✅DONE stays accepted (documented)"
else
  fail "L13 rc=$RC (see $TMPDIR_ROOT/l13.out)"
fi

# L14
build_jsonl "$TMPDIR_ROOT/l14.jsonl" "[{'type':'user','message':{'role':'user','content':'$SUMHEAD   - \"Please preserve the literal \"quoted\" word and finish the task\"$SUMTAIL'}}]"
run "$TMPDIR_ROOT/l14.out" extract --transcript "$TMPDIR_ROOT/l14.jsonl"
if [ "$RC" -eq 0 ] && grep -q "압축 요약 1건(중복 제거 후 1건 추가)" "$TMPDIR_ROOT/l14.out" \
   && grep -q 'preserve the literal "quoted" word and finish the task' "$TMPDIR_ROOT/l14.out"; then
  pass "L14 extract: an escaped inner quote stays inside one row (was split in two, header over-counted)"
else
  fail "L14 rc=$RC (see $TMPDIR_ROOT/l14.out)"
fi

# ---------------------------------------------------------------------------
# L15–L16 — 🟥 cross-family round 2 (codex): a 4-space-indented table (CommonMark code block) was read as THE
#   checklist (rc=0 with no real table — silent); a quote inside a trailing annotation became a phantom row.
# ---------------------------------------------------------------------------
{
  echo "# indented example only"; echo
  echo "    | # | 시각 | 발화(요지) | 상태 | 증거 | 사유 / 남은 것 | 제안 |"
  echo "    |---|---|---|---|---|---|---|"
  echo "    | 1 | 09-18 01:00 | indented clean row | ✅ | ev.md:1 | — | — |"
} > "$TMPDIR_ROOT/l15a.md"
run "$TMPDIR_ROOT/l15a.out" check --file "$TMPDIR_ROOT/l15a.md"
L15A_RC=$RC
{
  cat "$TMPDIR_ROOT/l15a.md"; echo
  echo "| # | 시각 | 발화(요지) | 상태 | 증거 | 사유 / 남은 것 | 제안 |"
  echo "|---|---|---|---|---|---|---|"
  echo "| 1 | 09-18 01:05 | real bad row | ❌ | — |  |  |"
} > "$TMPDIR_ROOT/l15b.md"
run "$TMPDIR_ROOT/l15b.out" check --file "$TMPDIR_ROOT/l15b.md"
if [ "$L15A_RC" -eq 10 ] && [ "$RC" -eq 1 ] && grep -q "rows=1 " "$TMPDIR_ROOT/l15b.out" && grep -q "^row 1 missing 사유" "$TMPDIR_ROOT/l15b.out"; then
  pass "L15 check: a 4-space-indented table is code, not a checklist (rc=10 alone; the real table below it is the one checked)"
else
  fail "L15 alone_rc=$L15A_RC with_real_rc=$RC (see $TMPDIR_ROOT/l15*.out)"
fi

build_jsonl "$TMPDIR_ROOT/l16.jsonl" "[{'type':'user','message':{'role':'user','content':'$SUMHEAD   - \"Deploy the release notes\" (already \"summarized\" above)\n   - Two inline quotes in prose: \"first ask\" and then \"second ask\"$SUMTAIL'}}]"
run "$TMPDIR_ROOT/l16.out" extract --transcript "$TMPDIR_ROOT/l16.jsonl"
if [ "$RC" -eq 0 ] && grep -q "압축 요약 3건(중복 제거 후 3건 추가)" "$TMPDIR_ROOT/l16.out" \
   && grep -q "^| S1 | (요약) | Deploy the release notes |" "$TMPDIR_ROOT/l16.out" && ! grep -q "summarized" "$TMPDIR_ROOT/l16.out" \
   && grep -q "^| S2 | (요약) | first ask |" "$TMPDIR_ROOT/l16.out" && grep -q "^| S3 | (요약) | second ask |" "$TMPDIR_ROOT/l16.out"; then
  pass "L16 extract: a quote inside a trailing annotation is not a row; a prose item still yields every quote"
else
  fail "L16 rc=$RC (see $TMPDIR_ROOT/l16.out)"
fi

echo "── $PASS_COUNT passed, $FAIL_COUNT failed ──"

if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
exit 0

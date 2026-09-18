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
                 "content": "<task-notification>agent finished</task-notification>"}},  # v11: the real shape ends with the closing tag
    {"type": "user",
     "message": {"role": "user",
                 "content": "Another Claude session sent a message:\n<agent-message from=\"peer\">\n[Subagent hand-back] hello there\n</agent-message>"}},  # v9: the REAL envelope shape (sentence + tag)
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
  # 🟥 known-positive of the SUMMARY channel: a string that exists only in the compaction summaries of the
  #    real transcript (default = the night-drive delegation phrase of this author's session). v6 first cut
  #    dropped 3 of 4 real summaries (heading `6. **All user messages:**` did not match) and only this
  #    assertion would have said so — «rows ≥ 1» was green.
  L8_KP="${CHECKLIST_REAL_KNOWN_POSITIVE:-야간자율주행}"
  if [ "$RC" -eq 0 ] && [ "$L8_DATAROWS" -ge 1 ] && grep -q "채널 2/2" "$TMPDIR_ROOT/l8.out" \
     && grep '^| S' "$TMPDIR_ROOT/l8.out" | grep -q -- "$L8_KP"; then
    pass "L8 real-transcript extract: rows=$L8_DATAROWS, channel 2/2, summary known-positive «${L8_KP}» present"
  else
    fail "L8 rc=$RC datarows=$L8_DATAROWS known-positive «${L8_KP}» in S-rows: $(grep '^| S' "$TMPDIR_ROOT/l8.out" | grep -c -- "$L8_KP") (see $TMPDIR_ROOT/l8.out)"
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

# ---------------------------------------------------------------------------
# L17–L19 — 🟥 cross-family round 3 (codex): an item opening with a quote that never closes was dropped
#   (silent); a Korean compaction heading «모든 사용자 메시지» disabled the summary channel (silent);
#   zero-width spacing around an emoji made a valid status invalid (loud); `n.a.` stays rejected by contract.
# ---------------------------------------------------------------------------
build_jsonl "$TMPDIR_ROOT/l17.jsonl" "[{'type':'user','message':{'role':'user','content':'$SUMHEAD   - \"Carry the unclosed request over to the next session$SUMTAIL'}}]"
run "$TMPDIR_ROOT/l17.out" extract --transcript "$TMPDIR_ROOT/l17.jsonl"
if [ "$RC" -eq 0 ] && grep -q "압축 요약 1건(중복 제거 후 1건 추가)" "$TMPDIR_ROOT/l17.out" \
   && grep -q "^| S1 | (요약) | Carry the unclosed request over to the next session |" "$TMPDIR_ROOT/l17.out"; then
  pass "L17 extract: an item that opens with a quote and never closes it is still one row"
else
  fail "L17 rc=$RC (see $TMPDIR_ROOT/l17.out)"
fi

build_jsonl "$TMPDIR_ROOT/l18.jsonl" "[{'type':'user','message':{'role':'user','content':'This session is being continued from a previous conversation that ran out of context.\n\n요약:\n1. 주요 요청:\n   - 준비\n\n6. 모든 사용자 메시지:\n   - \"한국어 헤딩 아래의 발화\"\n\n7. 남은 작업:\n   - 계속\n'}}]"
run "$TMPDIR_ROOT/l18.out" extract --transcript "$TMPDIR_ROOT/l18.jsonl"
if [ "$RC" -eq 0 ] && grep -q "압축 요약 1건(중복 제거 후 1건 추가)" "$TMPDIR_ROOT/l18.out" \
   && grep -q "^| S1 | (요약) | 한국어 헤딩 아래의 발화 |" "$TMPDIR_ROOT/l18.out"; then
  pass "L18 extract: a Korean compaction heading (모든 사용자 메시지) still opens the summary channel"
else
  fail "L18 rc=$RC (see $TMPDIR_ROOT/l18.out)"
fi

python3 - "$TMPDIR_ROOT/l19.md" <<'PYEOF'
import sys
zw = "​"; nb = " "
rows = [
    "# invisible spacing",
    "",
    "| # | 시각 | 발화(요지) | 상태 | 증거 | 사유 / 남은 것 | 제안 |",
    "|---|---|---|---|---|---|---|",
    "| 1 | 09-18 01:00 | zero-width around emoji | " + zw + "✅" + zw + " | ev.md:1 | — | — |",
    "| 2 | 09-18 01:01 | nbsp around emoji | " + nb + "✅" + nb + " | ev.md:2 | — | — |",
    "| 3 | 09-18 01:02 | n.a. is not an alias | n.a. | — | — | — |",
]
open(sys.argv[1], "w", encoding="utf-8").write("\n".join(rows) + "\n")
PYEOF
run "$TMPDIR_ROOT/l19.out" check --file "$TMPDIR_ROOT/l19.md"
if [ "$RC" -eq 1 ] && grep -q "^row 3 invalid" "$TMPDIR_ROOT/l19.out" && grep -q "rows=3 ok=2 violations=1" "$TMPDIR_ROOT/l19.out"; then
  pass "L19 check: zero-width / NBSP around a status is stripped (rows 1–2 ok); n.a. stays invalid by contract (row 3)"
else
  fail "L19 rc=$RC (see $TMPDIR_ROOT/l19.out)"
fi

# ---------------------------------------------------------------------------
# L20–L27 — 🟥 cross-family round 4 (codex): six silent MAJORs at the Markdown-table / JSONL boundary.
#   L20 `\|` inside the utterance cell shifted every later column (status read from the wrong cell)
#   L21 a header `이전 상태 메모` before `상태` stole the status column
#   L22 a 4-backtick fence "closed" by a 3-backtick line — the table stayed fenced code
#   L23 an indented delimiter row (code) still made a header a table
#   L24 an unparsable JSONL line silently dropped a user utterance (rc stayed 0)
#   L25 an ordinary utterance that starts with the compaction phrase was routed to the summary channel
#   L26 a BOM before the compaction prefix hid the summary channel
#   L27 a table with only `#` and `상태` passed as a checklist (schema)
# ---------------------------------------------------------------------------
{
  echo "# escaped pipe"; echo
  echo "| # | 시각 | 발화(요지) | 상태 | 증거 | 사유 / 남은 것 | 제안 |"
  echo "|---|---|---|---|---|---|---|"
  echo "| 1 | 09-18 01:00 | run a \\| b | ✅ | ev.md:1 | — | — |"
  echo "| 2 | 09-18 01:01 | run c \\| d |  | ev.md:2 | — | — |"
} > "$TMPDIR_ROOT/l20.md"
run "$TMPDIR_ROOT/l20.out" check --file "$TMPDIR_ROOT/l20.md"
if [ "$RC" -eq 1 ] && grep -q "^row 2 missing 상태" "$TMPDIR_ROOT/l20.out" && grep -q "rows=2 ok=1 violations=1" "$TMPDIR_ROOT/l20.out"; then
  pass "L20 check: an escaped pipe inside a cell is not a column boundary (row 1 ok, row 2's empty 상태 is caught)"
else
  fail "L20 rc=$RC (see $TMPDIR_ROOT/l20.out)"
fi

{
  echo "# ambiguous header"; echo
  echo "| # | 이전 상태 메모 | 발화(요지) | 상태 | 증거 | 사유 / 남은 것 | 제안 |"
  echo "|---|---|---|---|---|---|---|"
  echo "| 1 | ✅ | the real status is bogus | bogus | ev.md:1 | — | — |"
} > "$TMPDIR_ROOT/l21.md"
run "$TMPDIR_ROOT/l21.out" check --file "$TMPDIR_ROOT/l21.md"
if [ "$RC" -eq 1 ] && grep -q "^row 1 invalid 상태 (got 'bogus')" "$TMPDIR_ROOT/l21.out"; then
  pass "L21 check: the exact 상태 header wins over a contains-match (bogus is caught)"
else
  fail "L21 rc=$RC (see $TMPDIR_ROOT/l21.out)"
fi

{
  echo "# long fence, short closer"; echo
  echo '````'
  echo '```'
  echo "| # | 시각 | 발화(요지) | 상태 | 증거 | 사유 / 남은 것 | 제안 |"
  echo "|---|---|---|---|---|---|---|"
  echo "| 1 | 09-18 01:00 | still fenced | ✅ | ev.md:1 | — | — |"
  echo '````'
} > "$TMPDIR_ROOT/l22.md"
run "$TMPDIR_ROOT/l22.out" check --file "$TMPDIR_ROOT/l22.md"
L22_RC=$RC
{
  echo "# indented delimiter"; echo
  echo "| # | 시각 | 발화(요지) | 상태 | 증거 | 사유 / 남은 것 | 제안 |"
  echo "    |---|---|---|---|---|---|---|"
  echo "| 1 | 09-18 01:00 | not a table | ✅ | ev.md:1 | — | — |"
} > "$TMPDIR_ROOT/l23.md"
run "$TMPDIR_ROOT/l23.out" check --file "$TMPDIR_ROOT/l23.md"
if [ "$L22_RC" -eq 10 ] && [ "$RC" -eq 10 ]; then
  pass "L22/L23 check: a 4-backtick fence is not closed by 3 backticks; an indented delimiter row is not a table (both rc=10)"
else
  fail "L22 rc=$L22_RC L23 rc=$RC (see $TMPDIR_ROOT/l22.out $TMPDIR_ROOT/l23.out)"
fi

{
  echo '{"type":"user","timestamp":"2026-09-18T01:00:00.000Z","message":{"role":"user","content":"first request"}}'
  echo '{"type":"user","timestamp":"2026-09-18T01:01:00.000Z","message":{"role":"user","content":"broken line'
  echo '{"type":"user","timestamp":"2026-09-18T01:02:00.000Z","message":{"role":"user","content":"third request"}}'
} > "$TMPDIR_ROOT/l24.jsonl"
run "$TMPDIR_ROOT/l24.out" extract --transcript "$TMPDIR_ROOT/l24.jsonl"
if [ "$RC" -eq 2 ] && grep -q "JSONL 파싱 실패 1줄" "$TMPDIR_ROOT/l24.out" && grep -q "raw 2건" "$TMPDIR_ROOT/l24.out"; then
  pass "L24 extract: an unparsable JSONL line is loud (rc=2, header names the count) instead of a silent drop"
else
  fail "L24 rc=$RC (see $TMPDIR_ROOT/l24.out)"
fi

build_jsonl "$TMPDIR_ROOT/l25.jsonl" "[{'type':'user','timestamp':'2026-09-18T01:00:00.000Z','message':{'role':'user','content':'This session is being continued from a previous conversation? no — I am just quoting that phrase; please treat this as my request'}}]"
run "$TMPDIR_ROOT/l25.out" extract --transcript "$TMPDIR_ROOT/l25.jsonl"
if [ "$RC" -eq 0 ] && grep -q "raw 1건" "$TMPDIR_ROOT/l25.out" && grep -q "^| 1 | " "$TMPDIR_ROOT/l25.out"; then
  pass "L25 extract: an utterance that merely starts with the compaction phrase stays a raw row"
else
  fail "L25 rc=$RC (see $TMPDIR_ROOT/l25.out)"
fi

build_jsonl "$TMPDIR_ROOT/l26.jsonl" "[{'type':'user','message':{'role':'user','content':'﻿$SUMHEAD   - \"carried over behind a BOM\"$SUMTAIL'}}]"
run "$TMPDIR_ROOT/l26.out" extract --transcript "$TMPDIR_ROOT/l26.jsonl"
if [ "$RC" -eq 0 ] && grep -q "압축 요약 1건(중복 제거 후 1건 추가)" "$TMPDIR_ROOT/l26.out" && grep -q "carried over behind a BOM" "$TMPDIR_ROOT/l26.out"; then
  pass "L26 extract: a BOM before the compaction prefix does not hide the summary channel"
else
  fail "L26 rc=$RC (see $TMPDIR_ROOT/l26.out)"
fi

{
  echo "# status-only table"; echo
  echo "| # | 상태 |"
  echo "|---|---|"
  echo "| 1 | n/a |"
} > "$TMPDIR_ROOT/l27.md"
run "$TMPDIR_ROOT/l27.out" check --file "$TMPDIR_ROOT/l27.md"
if [ "$RC" -eq 10 ] && grep -q "schema" "$TMPDIR_ROOT/l27.out"; then
  pass "L27 check: a table without 증거/사유/제안 columns is not a checklist (schema, rc=10)"
else
  fail "L27 rc=$RC (see $TMPDIR_ROOT/l27.out)"
fi

# ---------------------------------------------------------------------------
# L28–L31 — 🟥 cross-family round 5 (codex): four silent MAJORs.
#   L28 an utterance containing the phrase «user messages» (no heading line) was routed to the summary channel
#   L29 a distinct follow-up sharing a long opening with an earlier summary quote was folded as a duplicate
#   L30 a GFM row without the outer pipes was not collected (its bad status went unchecked)
#   L31 a real utterance starting with «Caveat:» was excluded as if it were the synthetic local-command caveat
# ---------------------------------------------------------------------------
build_jsonl "$TMPDIR_ROOT/l28.jsonl" "[{'type':'user','timestamp':'2026-09-18T01:00:00.000Z','message':{'role':'user','content':'This session is being continued from a previous conversation is a phrase; the old user messages are gone, so re-derive the plan from the card'}}]"
run "$TMPDIR_ROOT/l28.out" extract --transcript "$TMPDIR_ROOT/l28.jsonl"
if [ "$RC" -eq 0 ] && grep -q "raw 1건 · 압축 요약 0건" "$TMPDIR_ROOT/l28.out"; then
  pass "L28 extract: the phrase «user messages» without a heading line does not make a compaction summary"
else
  fail "L28 rc=$RC (see $TMPDIR_ROOT/l28.out)"
fi

build_jsonl "$TMPDIR_ROOT/l29.jsonl" "[{'type':'user','message':{'role':'user','content':'$SUMHEAD   - \"Please investigate the deployment checklist and record evidence for the alpha path\"$SUMTAIL'}},{'type':'user','message':{'role':'user','content':'$SUMHEAD   - \"Please investigate the deployment checklist and record evidence for the alpha path, then open a PR\"\n   - \"Please investigate the deployment checklist and record evidence for the alpha…\"$SUMTAIL'}}]"
run "$TMPDIR_ROOT/l29.out" extract --transcript "$TMPDIR_ROOT/l29.jsonl"
if [ "$RC" -eq 0 ] && grep -q "압축 요약 3건(중복 제거 후 2건 추가)" "$TMPDIR_ROOT/l29.out" && grep -q "then open a PR" "$TMPDIR_ROOT/l29.out"; then
  pass "L29 extract: a distinct follow-up sharing a long opening is its own row; only a quote ending in «…» folds"
else
  fail "L29 rc=$RC (see $TMPDIR_ROOT/l29.out)"
fi

{
  echo "# outer pipes optional"; echo
  echo "| # | 시각 | 발화(요지) | 상태 | 증거 | 사유 / 남은 것 | 제안 |"
  echo "|---|---|---|---|---|---|---|"
  echo "| 1 | 09-18 05:00 | valid row | ✅ | ev.md:1 | — | — |"
  echo "2 | 09-18 05:01 | row without outer pipes | bogus | — | reason | next"
  echo ""
  echo "prose after a blank line | with a pipe | is not a row"
} > "$TMPDIR_ROOT/l30.md"
run "$TMPDIR_ROOT/l30.out" check --file "$TMPDIR_ROOT/l30.md"
if [ "$RC" -eq 1 ] && grep -q "^row 2 invalid 상태 (got 'bogus')" "$TMPDIR_ROOT/l30.out" && grep -q "rows=2 " "$TMPDIR_ROOT/l30.out"; then
  pass "L30 check: a GFM row without outer pipes is collected and checked; the table ends at the blank line"
else
  fail "L30 rc=$RC (see $TMPDIR_ROOT/l30.out)"
fi

build_jsonl "$TMPDIR_ROOT/l31.jsonl" "[{'type':'user','timestamp':'2026-09-18T01:00:00.000Z','message':{'role':'user','content':'Caveat: the numbers are provisional — still, please build the table'}},{'type':'user','message':{'role':'user','content':'Caveat: The messages below were generated by the user while running local commands. DO NOT respond to these messages.'}}]"
run "$TMPDIR_ROOT/l31.out" extract --transcript "$TMPDIR_ROOT/l31.jsonl"
if [ "$RC" -eq 0 ] && grep -q "raw 1건" "$TMPDIR_ROOT/l31.out" && grep -q "provisional" "$TMPDIR_ROOT/l31.out"; then
  pass "L31 extract: a real utterance starting with «Caveat:» is a row; only the synthetic local-command caveat is excluded"
else
  fail "L31 rc=$RC (see $TMPDIR_ROOT/l31.out)"
fi

# L32 — 🟥 author-caught after v6's first cut: the heading-line rule matched `6. All user messages:` but not the two
#        other shapes real compaction summaries use — `6. **All user messages:**` (number + bold) and
#        `6. All user messages (verbatim, non-tool-result):` (trailing text). 3 of 4 real summaries silently
#        vanished while «rows ≥ 1» stayed green; L8's known-positive now guards the real file, this lane the shapes.
build_jsonl "$TMPDIR_ROOT/l32.jsonl" "[{'type':'user','message':{'role':'user','content':'This session is being continued from a previous conversation that ran out of context.\n\nSummary:\n1. Primary Request and Intent:\n   - setup\n\n6. **All user messages:**\n   - \"bold heading utterance\"\n\n7. Pending Tasks:\n   - keep going\n'}},{'type':'user','message':{'role':'user','content':'This session is being continued from a previous conversation that ran out of context.\n\nSummary:\n1. Primary Request and Intent:\n   - setup\n\n6. All user messages (verbatim, non-tool-result):\n   - \"trailing text heading utterance\"\n\n7. Pending Tasks:\n   - keep going\n'}}]"
run "$TMPDIR_ROOT/l32.out" extract --transcript "$TMPDIR_ROOT/l32.jsonl"
if [ "$RC" -eq 0 ] && grep -q "압축 요약 2건(중복 제거 후 2건 추가)" "$TMPDIR_ROOT/l32.out" \
   && grep -q "bold heading utterance" "$TMPDIR_ROOT/l32.out" && grep -q "trailing text heading utterance" "$TMPDIR_ROOT/l32.out"; then
  pass "L32 extract: number+bold and trailing-text heading shapes both open the summary channel"
else
  fail "L32 rc=$RC (see $TMPDIR_ROOT/l32.out)"
fi

# ---------------------------------------------------------------------------
# L33–L34 — 🟥 cross-family round 6 (codex, first round with the contract boundaries stated): two silent, in-contract.
#   L33 a later table whose header AND delimiter omit the outer pipes was never found (its bad row unchecked)
#   L34 a user DRAFTING a compaction template (boilerplate + heading line, no quoted items) was routed to the summary channel
# ---------------------------------------------------------------------------
{
  echo "# outerless later table"; echo
  echo "| # | 시각 | 발화(요지) | 상태 | 증거 | 사유 / 남은 것 | 제안 |"
  echo "|---|---|---|---|---|---|---|"
  echo "| 1 | 09-18 05:00 | first table ok | ✅ | ev.md:1 | — | — |"
  echo
  echo "# | 시각 | 발화(요지) | 상태 | 증거 | 사유 / 남은 것 | 제안"
  echo "---|---|---|---|---|---|---"
  echo "1 | 09-18 05:01 | outerless table bad row | bogus | — | reason | next"
} > "$TMPDIR_ROOT/l33.md"
run "$TMPDIR_ROOT/l33.out" check --file "$TMPDIR_ROOT/l33.md"
if [ "$RC" -eq 1 ] && grep -q "^row table 2 1 invalid 상태 (got 'bogus')" "$TMPDIR_ROOT/l33.out" && grep -q "tables=2" "$TMPDIR_ROOT/l33.out"; then
  pass "L33 check: a table whose header and delimiter omit the outer pipes is found and checked (table 2 named)"
else
  fail "L33 rc=$RC (see $TMPDIR_ROOT/l33.out)"
fi

build_jsonl "$TMPDIR_ROOT/l34.jsonl" "[{'type':'user','timestamp':'2026-09-18T01:00:00.000Z','message':{'role':'user','content':'This session is being continued from a previous conversation that ran out of context. — let us use that as our template:\n\n1. Primary Request and Intent:\n   - (fill in)\n\n6. All user messages:\n   - (list them here)\n\n7. Pending Tasks:\n   - (fill in)\n'}}]"
run "$TMPDIR_ROOT/l34.out" extract --transcript "$TMPDIR_ROOT/l34.jsonl"
if [ "$RC" -eq 0 ] && grep -q "raw 1건 · 압축 요약 0건" "$TMPDIR_ROOT/l34.out"; then
  pass "L34 extract: a compaction-shaped utterance with no quoted items stays a raw row"
else
  fail "L34 rc=$RC (see $TMPDIR_ROOT/l34.out)"
fi

# L35 — 🟥 cross-family round 7 (codex): flush-left numbered quoted items (`1. "…"`) ended the «All user messages»
#        section (silent — the whole summary collapsed into one truncated raw row); a `7) Pending Tasks:` heading did
#        not end it (loud phantom row). v8: the section ends at the next flush-left numbered line WITHOUT a quote.
build_jsonl "$TMPDIR_ROOT/l35.jsonl" "[{'type':'user','message':{'role':'user','content':'This session is being continued from a previous conversation that ran out of context.\n\nSummary:\n1) Primary Request and Intent:\n   - setup\n\n6) All user messages:\n1. \"first flush-left numbered quote\"\n2. \"second flush-left numbered quote\"\n7) Pending Tasks:\n   - \"a quoted pending task is not a user message\"\n'}}]"
run "$TMPDIR_ROOT/l35.out" extract --transcript "$TMPDIR_ROOT/l35.jsonl"
if [ "$RC" -eq 0 ] && grep -q "raw 0건 · 압축 요약 2건(중복 제거 후 2건 추가)" "$TMPDIR_ROOT/l35.out" \
   && grep -q "second flush-left numbered quote" "$TMPDIR_ROOT/l35.out" && ! grep -q "pending task" "$TMPDIR_ROOT/l35.out"; then
  pass "L35 extract: flush-left numbered quoted items stay inside the section; a \`7)\` heading ends it"
else
  fail "L35 rc=$RC (see $TMPDIR_ROOT/l35.out)"
fi

# L36–L37 — 🟥 cross-family round 8 (codex): exclusions matched marker LITERALS inside ordinary utterances (three silent
#   drops — `<task-notification>` · `[Subagent hand-back]` · the peer-message sentence); a one-character quote was
#   mangled (loud). v9: exclusions are envelope-shaped (line start + tag); one-character quotes are quotes.
build_jsonl "$TMPDIR_ROOT/l36.jsonl" "[
 {'type':'user','timestamp':'2026-09-18T01:00:00.000Z','message':{'role':'user','content':'please grep the transcript for the literal <task-notification> marker and count it'}},
 {'type':'user','timestamp':'2026-09-18T01:01:00.000Z','message':{'role':'user','content':'the [Subagent hand-back] frame should be neutralized in our extractor — add a lane'}},
 {'type':'user','timestamp':'2026-09-18T01:02:00.000Z','message':{'role':'user','content':'Another Claude session sent a message: is the exact envelope sentence — use it as fixture text'}},
 {'type':'user','message':{'role':'user','content':'<task-notification>\n<task-id>x</task-id>\n</task-notification>'}},
 {'type':'user','message':{'role':'user','content':'Another Claude session sent a message:\n<agent-message from=\"abc\">\n[Subagent hand-back] report body\n</agent-message>'}}
]"
run "$TMPDIR_ROOT/l36.out" extract --transcript "$TMPDIR_ROOT/l36.jsonl"
if [ "$RC" -eq 0 ] && grep -q "raw 3건" "$TMPDIR_ROOT/l36.out" && grep -q "count it" "$TMPDIR_ROOT/l36.out" && grep -q "add a lane" "$TMPDIR_ROOT/l36.out" && grep -q "fixture text" "$TMPDIR_ROOT/l36.out" \
   && ! grep -q "report body" "$TMPDIR_ROOT/l36.out" && ! grep -q "task-id" "$TMPDIR_ROOT/l36.out"; then
  pass "L36 extract: marker literals inside utterances are rows; the real task-notification and agent-message envelopes are excluded"
else
  fail "L36 rc=$RC (see $TMPDIR_ROOT/l36.out)"
fi

build_jsonl "$TMPDIR_ROOT/l37.jsonl" "[{'type':'user','message':{'role':'user','content':'$SUMHEAD   - \"y\"\n   - \"ok go\"$SUMTAIL'}}]"
run "$TMPDIR_ROOT/l37.out" extract --transcript "$TMPDIR_ROOT/l37.jsonl"
if [ "$RC" -eq 0 ] && grep -q "압축 요약 2건(중복 제거 후 2건 추가)" "$TMPDIR_ROOT/l37.out" && grep -q "^| S1 | (요약) | y |" "$TMPDIR_ROOT/l37.out"; then
  pass "L37 extract: a one-character quoted item is one clean row"
else
  fail "L37 rc=$RC (see $TMPDIR_ROOT/l37.out)"
fi

# L38 — 🟥 cross-family round 9 (codex): prefix-only exclusions dropped ordinary utterances that START with an envelope
#        literal (`<system-reminder>` · `[SYSTEM NOTIFICATION` · `<local-command…>` · `<command-name>`) — silent.
#        v10: every exclusion is an envelope VALIDATOR (opening marker at line start + the closing/companion mark the
#        real Claude Code envelope always carries); a look-alike without the companion is a row.
build_jsonl "$TMPDIR_ROOT/l38.jsonl" "[
 {'type':'user','timestamp':'2026-09-18T01:00:00.000Z','message':{'role':'user','content':'<system-reminder> is the tag I want counted — look-alike, no closing tag'}},
 {'type':'user','timestamp':'2026-09-18T01:01:00.000Z','message':{'role':'user','content':'[SYSTEM NOTIFICATION style banners must be neutralized — write that lane'}},
 {'type':'user','timestamp':'2026-09-18T01:02:00.000Z','message':{'role':'user','content':'<local-command-stdout> lines are noise; strip them in the extractor'}},
 {'type':'user','timestamp':'2026-09-18T01:03:00.000Z','message':{'role':'user','content':'<command-name>deploy</command-name> is sample text for the parser docs — treat as my request'}},
 {'type':'user','message':{'role':'user','content':'<system-reminder>\nreminder body\n</system-reminder>'}},
 {'type':'user','message':{'role':'user','content':'[SYSTEM NOTIFICATION - NOT USER INPUT]\nThis is an automated background-task event\n\n<task-notification>\n<task-id>x</task-id>\n</task-notification>'}},
 {'type':'user','message':{'role':'user','content':'<local-command-stdout>hi</local-command-stdout>'}},
 {'type':'user','message':{'role':'user','content':'<command-name>/compact</command-name>\n<command-message>compact</command-message>'}}
]"
run "$TMPDIR_ROOT/l38.out" extract --transcript "$TMPDIR_ROOT/l38.jsonl"
if [ "$RC" -eq 0 ] && grep -q "raw 4건" "$TMPDIR_ROOT/l38.out" && grep -q "look-alike" "$TMPDIR_ROOT/l38.out" && grep -q "treat as my request" "$TMPDIR_ROOT/l38.out" \
   && ! grep -q "reminder body" "$TMPDIR_ROOT/l38.out" && ! grep -q "task-id" "$TMPDIR_ROOT/l38.out" && ! grep -q "compact" "$TMPDIR_ROOT/l38.out"; then
  pass "L38 extract: four envelope look-alikes are rows; the four real envelopes (with their closing marks) are excluded"
else
  fail "L38 rc=$RC (see $TMPDIR_ROOT/l38.out)"
fi

# L39 — 🟥 cross-family round 10 (codex): a user-authored FULL envelope literal (byte-identical text) was excluded by text
#        shape. Measured on the real transcript: Claude Code marks entries — origin.kind=human (48/48 typed utterances),
#        origin.kind=task-notification / peer (+isMeta), isCompactSummary. v11: METADATA FIRST — a human-origin entry is
#        never excluded by its text; flagged entries are excluded/routed by the flag; text validators only when NO metadata.
build_jsonl "$TMPDIR_ROOT/l39.jsonl" "[
 {'type':'user','timestamp':'2026-09-18T01:00:00.000Z','origin':{'kind':'human'},'promptSource':'typed','message':{'role':'user','content':'<system-reminder>\nthis whole envelope is what I pasted as my request\n</system-reminder>'}},
 {'type':'user','origin':{'kind':'task-notification'},'promptSource':'system','message':{'role':'user','content':'plain looking text that is actually a notification'}},
 {'type':'user','isMeta':True,'origin':{'kind':'peer'},'promptSource':'system','message':{'role':'user','content':'peer text without the sentence prefix'}},
 {'type':'user','isCompactSummary':True,'message':{'role':'user','content':'Summary (no boilerplate prefix):\n\n6. All user messages:\n   - \"flagged compaction quote\"\n\n7. Pending Tasks:\n   - x\n'}},
 {'type':'user','message':{'role':'user','content':'<system-reminder>\nno metadata at all — text fallback treats a full envelope as synthetic\n</system-reminder>'}}
]"
run "$TMPDIR_ROOT/l39.out" extract --transcript "$TMPDIR_ROOT/l39.jsonl"
if [ "$RC" -eq 0 ] && grep -q "raw 1건 · 압축 요약 1건(중복 제거 후 1건 추가)" "$TMPDIR_ROOT/l39.out" \
   && grep -q "what I pasted as my request" "$TMPDIR_ROOT/l39.out" && grep -q "flagged compaction quote" "$TMPDIR_ROOT/l39.out" \
   && ! grep -q "actually a notification" "$TMPDIR_ROOT/l39.out" && ! grep -q "peer text" "$TMPDIR_ROOT/l39.out" && ! grep -q "no metadata at all" "$TMPDIR_ROOT/l39.out"; then
  pass "L39 extract: metadata first — human-origin envelope text is a row; flagged notification/peer are excluded; isCompactSummary opens the summary channel; no-metadata envelope falls back to the text validator"
else
  fail "L39 rc=$RC (see $TMPDIR_ROOT/l39.out)"
fi

echo "── $PASS_COUNT passed, $FAIL_COUNT failed ──"

if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
exit 0

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

# L40 — re-extracting into a filled sheet carries the judgements forward (2026-10-18: the mid-session nudge
# re-extracts into the SAME file; a plain overwrite erased 259 filled rows). Known pair: a filled row is carried,
# an empty row stays empty; a filled row whose utterance is gone is kept under the orphan heading; no file → plain write.
build_jsonl "$TMPDIR_ROOT/l40.jsonl" "[{'type':'user','timestamp':'2026-10-18T01:00:00.000Z','message':{'role':'user','content':'Please move the session bar a little higher than it is now.'}},{'type':'user','timestamp':'2026-10-18T01:05:00.000Z','message':{'role':'user','content':'Please also fix the badge that sits too far to the right.'}}]"
L40="$TMPDIR_ROOT/l40.md"
run "$TMPDIR_ROOT/l40a.out" extract --transcript "$TMPDIR_ROOT/l40.jsonl" --out "$L40"
L40A_RC=$RC
L40_PLAIN=$(grep -c '↩️' "$L40")                                      # control: no prior file → no carry line
python3 - "$L40" <<'PYEOF'
import sys
p = sys.argv[1]; L = open(p, encoding="utf-8").read().split("\n")
for i, l in enumerate(L):
    if l.startswith("| 1 |"):
        L[i] = l.replace("|  |  |  |  |", "| ✅DONE | abc1234 (#99) | - | - |")
L.append("| 7 | 10-17 09:00 | an utterance no longer in the transcript | 🟡PARTIAL | - | half done | 이월: finish |")
open(p, "w", encoding="utf-8").write("\n".join(L))
PYEOF
run "$TMPDIR_ROOT/l40b.out" extract --transcript "$TMPDIR_ROOT/l40.jsonl" --out "$L40"
if [ "$L40A_RC" -eq 0 ] && [ "$RC" -eq 0 ] && [ "$L40_PLAIN" = 0 ] \
   && grep -q '^| 1 | .*session bar.* | ✅DONE | abc1234 (#99) | - | - |$' "$L40" \
   && grep -qE '^\| 2 \| .*badge.* \|  \|  \|  \|  \|$' "$L40" \
   && grep -q '^## 이전 결과서에서 이어받지 못한 판정' "$L40" \
   && grep -q 'an utterance no longer in the transcript | 🟡PARTIAL' "$L40" \
   && grep -q '판정 1줄 이어받음 · 못 맞춘 판정 1줄' "$L40"; then
  pass "L40 extract into a filled sheet: judgement carried (row 1), empty row stays empty (row 2), unmatched judgement kept under the orphan heading, no-file run writes plainly"
else
  fail "L40 rc=$L40A_RC/$RC plain=$L40_PLAIN (see $L40)"
fi

# ---------------------------------------------------------------------------
# L41-L45 — the hook record as a second channel (merge with the transcript, tag source, never a silent zero)
# transcript: alpha 09:00Z · beta 09:10Z · gamma 09:20Z; hook: alpha · delta (09:05Z, hook only) · beta (+20s); hook ts is local-naive
# ---------------------------------------------------------------------------
python3 - "$TMPDIR_ROOT" <<'PYEOF'
import json, sys, datetime
d = sys.argv[1]
def loc(z):  # UTC «…Z» -> local naive, as the hook writes it
    t = datetime.datetime.strptime(z, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=datetime.timezone.utc).astimezone()
    return t.strftime("%Y-%m-%dT%H:%M:%S")
tr = [("2026-10-01T09:00:00Z", "alpha request about the status bar"),
      ("2026-10-01T09:10:00Z", "beta request about the export button"),
      ("2026-10-01T09:20:00Z", "gamma request only the transcript saw")]
with open(d + "/l41_tr.jsonl", "w", encoding="utf-8") as f:
    for z, t in tr:
        f.write(json.dumps({"type": "user", "timestamp": z, "message": {"role": "user", "content": t}}) + "\n")
hk = [("2026-10-01T09:00:00Z", "alpha request about the status bar"),
      ("2026-10-01T09:05:00Z", "delta request sent while a tool was running"),
      ("2026-10-01T09:10:20Z", "beta request about the export button")]
with open(d + "/l41_hook.jsonl", "w", encoding="utf-8") as f:
    for n, (z, t) in enumerate(hk, 1):
        f.write(json.dumps({"ts": loc(z), "n": n, "text": t}) + "\n")
with open(d + "/l44_hook.jsonl", "w", encoding="utf-8") as f:   # one good row, one torn line, one row without text
    f.write(json.dumps({"ts": loc("2026-10-01T09:05:00Z"), "n": 1, "text": "delta request sent while a tool was running"}) + "\n")
    f.write('{"ts": "2026-10-01T09:06:00", "n": 2, "text": "torn li\n')
    f.write(json.dumps({"ts": loc("2026-10-01T09:07:00Z"), "n": 3}) + "\n")
with open(d + "/l42_tr.jsonl", "w", encoding="utf-8") as f:
    f.write(json.dumps({"type": "user", "timestamp": "2026-10-01T09:00:00Z", "message": {"role": "user", "content": "please continue with the next step"}}) + "\n")
with open(d + "/l42_hook.jsonl", "w", encoding="utf-8") as f:
    for z in ("2026-10-01T09:00:00Z", "2026-10-01T13:00:00Z"):
        f.write(json.dumps({"ts": loc(z), "n": 1, "text": "please continue with the next step"}) + "\n")
PYEOF
run "$TMPDIR_ROOT/l41.out" extract --transcript "$TMPDIR_ROOT/l41_tr.jsonl" --utterances "$TMPDIR_ROOT/l41_hook.jsonl"
L41_RC=$RC
L41_ROWS=$(grep -cE '^\| [0-9HS]+ \|' "$TMPDIR_ROOT/l41.out")
if [ "$L41_RC" -eq 0 ] && [ "$L41_ROWS" -eq 4 ] \
   && [ "$(grep -c 'alpha request' "$TMPDIR_ROOT/l41.out")" -eq 1 ] \
   && [ "$(grep -c 'beta request' "$TMPDIR_ROOT/l41.out")" -eq 1 ] \
   && grep -q '^| 3 | .*gamma request' "$TMPDIR_ROOT/l41.out" \
   && grep -q '^| H1 | 10-01 09:05 | delta request' "$TMPDIR_ROOT/l41.out" \
   && grep -q '훅 기록 채널 읽음 — 3건 · 전사와 일치 2건 · 훅 전용 1건' "$TMPDIR_ROOT/l41.out"; then
  pass "L41 hook+transcript: a message in both is ONE row (no dup), hook-only is an H row with its time, transcript-only keeps its number, header counts 3/2/1"
else
  fail "L41 rc=$L41_RC rows=$L41_ROWS (see $TMPDIR_ROOT/l41.out)"
fi

# L42 — the same words far apart in time are a distinct message, not folded into the first
run "$TMPDIR_ROOT/l42.out" extract --transcript "$TMPDIR_ROOT/l42_tr.jsonl" --utterances "$TMPDIR_ROOT/l42_hook.jsonl"
if [ "$RC" -eq 0 ] && [ "$(grep -c 'please continue' "$TMPDIR_ROOT/l42.out")" -eq 2 ] && grep -q '^| H1 | 10-01 13:00 |' "$TMPDIR_ROOT/l42.out"; then
  pass "L42 the same words 4h later are a second message (H row); the pair inside the window is one"
else
  fail "L42 rc=$RC (see $TMPDIR_ROOT/l42.out)"
fi

# L43 — hook file absent: the header says NOT READ (never zero), rc stays 0, transcript rows print
run "$TMPDIR_ROOT/l43.out" extract --transcript "$TMPDIR_ROOT/l41_tr.jsonl" --utterances "$TMPDIR_ROOT/no_such_hook.jsonl"
if [ "$RC" -eq 0 ] && grep -q '훅 기록 채널 안 읽음 — 파일 없음' "$TMPDIR_ROOT/l43.out" \
   && grep -q '0건이 아니라 미열람' "$TMPDIR_ROOT/l43.out" \
   && [ "$(grep -cE '^\| [0-9]+ \|' "$TMPDIR_ROOT/l43.out")" -eq 3 ]; then
  pass "L43 hook record absent: header says not read (not zero), the transcript's 3 rows intact, rc=0"
else
  fail "L43 rc=$RC (see $TMPDIR_ROOT/l43.out)"
fi

# L44 — malformed hook lines: loud in the header, rc=2, transcript rows and the readable hook row survive
run "$TMPDIR_ROOT/l44.out" extract --transcript "$TMPDIR_ROOT/l41_tr.jsonl" --utterances "$TMPDIR_ROOT/l44_hook.jsonl"
if [ "$RC" -eq 2 ] && grep -q '훅 기록 2줄 해석 실패' "$TMPDIR_ROOT/l44.out" \
   && [ "$(grep -cE '^\| [0-9]+ \|' "$TMPDIR_ROOT/l44.out")" -eq 3 ] \
   && grep -q '^| H1 | .*delta request' "$TMPDIR_ROOT/l44.out"; then
  pass "L44 malformed hook lines: header names 2 bad lines, rc=2, transcript rows and the readable hook row kept"
else
  fail "L44 rc=$RC (see $TMPDIR_ROOT/l44.out)"
fi

# L45 — hook path unreadable as a record (a directory): channel error in the header, rc=2, no crash, transcript rows kept
mkdir -p "$TMPDIR_ROOT/l45_dir"
run "$TMPDIR_ROOT/l45.out" extract --transcript "$TMPDIR_ROOT/l41_tr.jsonl" --utterances "$TMPDIR_ROOT/l45_dir"
if [ "$RC" -eq 2 ] && grep -q '훅 기록 채널 오류' "$TMPDIR_ROOT/l45.out" \
   && [ "$(grep -cE '^\| [0-9]+ \|' "$TMPDIR_ROOT/l45.out")" -eq 3 ]; then
  pass "L45 hook path unreadable: channel error in the header, rc=2, transcript rows kept"
else
  fail "L45 rc=$RC (see $TMPDIR_ROOT/l45.out)"
fi

# ---------------------------------------------------------------------------
# L46-L51 — merge edge cases a cross-family read reproduced (codex 2026-10-19). Each calls the REAL functions.
# L46 repeated short text: two «yes» pairs stay two rows (nearest-first greedy made three)
# L47 truncated hook row cannot steal the row a full hook row needs
# L48 hook row without a usable ts is a parse failure, not a text-only match
# L49 invalid UTF-8 in a hook line is a parse failure, not a replaced-character H row
# L50 DST fall-back hour: the nearer of the two instants is used (America/New_York)
# L51 carry_forward keeps BOTH judgments of two rows with the same minute and words
# ---------------------------------------------------------------------------
L46_OUT=$(python3 - "$SUBJ" "$TMPDIR_ROOT" <<'PYEOF'
import importlib.util, json, os, sys, datetime, time
spec = importlib.util.spec_from_file_location("sck", sys.argv[1]); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
d = sys.argv[2]
def loc(z):
    t = datetime.datetime.strptime(z, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=datetime.timezone.utc).astimezone()
    return t.strftime("%Y-%m-%dT%H:%M:%S")
res = {}
raw = [{"ts": "2026-10-01T09:00:00Z", "text": "yes"}, {"ts": "2026-10-01T09:20:00Z", "text": "yes"}]
hk = [{"ts": loc("2026-10-01T09:11:00Z"), "text": "yes", "truncated": False}, {"ts": loc("2026-10-01T09:40:00Z"), "text": "yes", "truncated": False}]
only, n = m.merge_hook_rows(raw, hk); res["L46"] = (len(only), n) == (0, 2)
raw = [{"ts": "2026-10-01T09:00:00Z", "text": "prefix B"}, {"ts": "2026-10-01T09:01:00Z", "text": "prefix A"}]
hk = [{"ts": loc("2026-10-01T09:00:00Z"), "text": "prefix", "truncated": True}, {"ts": loc("2026-10-01T09:00:01Z"), "text": "prefix B", "truncated": False}]
only, n = m.merge_hook_rows(raw, hk); res["L47"] = (len(only), n) == (0, 2)
with open(d + "/l48.jsonl", "w") as f:
    f.write(json.dumps({"n": 1, "text": "yes"}) + "\n"); f.write(json.dumps({"ts": "bad", "n": 2, "text": "yes"}) + "\n")
st, rows, bad, _ = m.read_hook_channel(d + "/l48.jsonl"); res["L48"] = (st, len(rows), bad) == ("read", 0, 2)
with open(d + "/l49.jsonl", "wb") as f:
    f.write(b'{"ts": "2026-10-01T09:00:00", "n": 1, "text": "y\xffs"}\n')
st, rows, bad, _ = m.read_hook_channel(d + "/l49.jsonl"); res["L49"] = (len(rows), bad) == (0, 1)
raw = [{"ts": "2026-10-01T09:00:00Z", "text": "prefix A"}, {"ts": "2026-10-01T09:01:00Z", "text": "prefix B"}]
hk = [{"ts": loc("2026-10-01T09:00:00Z"), "text": "prefix", "truncated": True}, {"ts": loc("2026-10-01T09:01:00Z"), "text": "prefix A", "truncated": True}]
only, n = m.merge_hook_rows(raw, hk); res["L47b"] = (len(only), n) == (0, 2)
res["L48b"] = m.parse_ts_candidates("2026-10-01T09:00:00garbage") == [] and m.parse_ts_candidates("2026-10-01T09:00:00.123Z") != []
os.environ["TZ"] = "America/New_York"; time.tzset()
raw = [{"ts": "2026-11-01T06:30:00Z", "text": "second half hour"}]
hk = [{"ts": "2026-11-01T01:30:00", "text": "second half hour", "truncated": False}]
only, n = m.merge_hook_rows(raw, hk); res["L50"] = (len(only), n) == (0, 1)
out = d + "/l51.md"
row = "| %s | 10-01 09:00 | yes | %s |  |  |  |"
with open(out, "w") as f:
    f.write("\n".join(["# t", "", "x", "", "| # | 시각 | 발화(요지) | 상태 | 증거 | 사유 / 남은 것 | 제안(이번 세션 vs 이월) |", "|---|---|---|---|---|---|---|", row % ("H1", "✅"), row % ("H2", "❌")]) + "\n")
new = ["# t", "", "x", "", "| # | 시각 | 발화(요지) | 상태 | 증거 | 사유 / 남은 것 | 제안(이번 세션 vs 이월) |", "|---|---|---|---|---|---|---|", row % ("H1", ""), row % ("H2", "")]
got = m.carry_forward(new, out)
res["L51"] = any(l.startswith("| H1 |") and "✅" in l for l in got) and any(l.startswith("| H2 |") and "❌" in l for l in got)
print(" ".join("%s=%s" % (k, int(v)) for k, v in sorted(res.items())))
PYEOF
)
for L in L46 L47 L47b L48 L48b L49 L50 L51; do
  case " $L46_OUT " in
    *" $L=1 "*) pass "$L merge edge case (codex 2026-10-19 repro) holds" ;;
    *) fail "$L merge edge case — got: ${L46_OUT:-<no output: the python block crashed>}" ;;
  esac
done

# L52 — `unblocked` on a sheet with an empty 상태 cell must not crash (TypeError: None in keys, 2026-10-23)
L52_FILE="$TMPDIR_ROOT/l52.md"
{
  echo "| # | 시각 | 발화(요지) | 상태 | 증거 | 사유 / 남은 것 | 제안 |"
  echo "|---|---|---|---|---|---|---|"
  echo "| A1 | 10-01 09:00 | first | ✅DONE | e | - | - |"
  echo "| A2 | 10-01 09:01 | second, blocked on A1 | ⏳IN-PROGRESS | e | A1 선행 | next |"
  echo "| A3 | 10-01 09:02 | never filled |  |  |  |  |"
} >"$L52_FILE"
run "$TMPDIR_ROOT/l52.out" unblocked --file "$L52_FILE"
if [ "$RC" -eq 1 ] && grep -q "A2 is still open, but its blocker A1 reads DONE" "$TMPDIR_ROOT/l52.out" \
   && ! grep -q "Traceback" "$TMPDIR_ROOT/l52.out"; then
  pass "L52 unblocked survives an empty 상태 cell and still reports the real finding"
else
  fail "L52 unblocked rc=$RC (want 1, finding A2/A1, no Traceback) — $(tail -2 "$TMPDIR_ROOT/l52.out" | tr '\n' ' ')"
fi

# L52b — an N/A row whose blocker reads DONE is closed, not «still open» (the key is "N/A"; a "n/a" compare never matched)
L52B_FILE="$TMPDIR_ROOT/l52b.md"
{
  echo "| # | 시각 | 발화(요지) | 상태 | 증거 | 사유 / 남은 것 | 제안 |"
  echo "|---|---|---|---|---|---|---|"
  echo "| A1 | 10-01 09:00 | first | ✅DONE | e | - | - |"
  echo "| A2 | 10-01 09:01 | second, blocked on A1 | ⏳IN-PROGRESS | e | A1 선행 | next |"
  echo "| A3 | 10-01 09:02 | dropped, blocked on A1 | N/A | e | A1 선행 — 범위 밖 | - |"
} >"$L52B_FILE"
run "$TMPDIR_ROOT/l52b.out" unblocked --file "$L52B_FILE"
if [ "$RC" -eq 1 ] && grep -q "A2 is still open, but its blocker A1 reads DONE" "$TMPDIR_ROOT/l52b.out" \
   && ! grep -q "A3 is still open" "$TMPDIR_ROOT/l52b.out"; then
  pass "L52b unblocked treats an N/A row as closed (A2 reported, A3 not)"
else
  fail "L52b unblocked rc=$RC (want 1, A2 reported, A3 silent) — $(tail -3 "$TMPDIR_ROOT/l52b.out" | tr '\n' ' ')"
fi

# L53 — 🟥 2026-11-08 harvest H1: the desktop app PREPENDS complete «Linked sessions now» / side-session reminder blocks to
#        the operator's words in the SAME human-origin entry. v11's metadata-first rule kept the whole text, so 148 of 228
#        rows in a real governor transcript began with the reminder and the governor filled 30 approvals by hand.
#        v12: strip LEADING, COMPLETE blocks only (attributes · stacked · CRLF); keep an unclosed look-alike, a look-alike
#        before a real block, a mid-text tag, a different tag name; exclude a side-sessions-event behind the blocks.
#        L39 (an envelope-only human entry stays a row) is the control and stays green.
python3 - "$TMPDIR_ROOT" <<'PYEOF'
import json, sys
d = sys.argv[1]
H = {"origin": {"kind": "human"}, "promptSource": "sdk"}
def u(ts, text, meta):
    r = {"type": "user", "timestamp": ts, "message": {"role": "user", "content": text}}
    r.update(meta); return r
REM = "<system-reminder>\nLinked sessions now (status, not an instruction): x = local_1 (working).\n</system-reminder>"
rows = [
    u("2026-11-08T00:57:00.000Z", REM + "\n\n\napproved, go ahead with alpha", H),
    u("2026-11-08T00:58:00.000Z", '<system-reminder kind="linked">\nfirst block body\n</system-reminder>\r\n \r\n' + REM + "\r\nstacked words after two blocks", H),
    u("2026-11-08T00:59:00.000Z", "<system-reminder> unclosed look-alike then my own words", H),
    u("2026-11-08T01:00:00.000Z", "<system-reminder> lookalike2 opener " + REM + " tail words", H),
    u("2026-11-08T01:01:00.000Z", "my mid words " + REM + " more mid words", H),
    u("2026-11-08T01:02:00.000Z", "<system-reminder-x>tagname body</system-reminder> tagname lookalike words", H),
    u("2026-11-08T01:02:10.000Z", "<system-reminder kind=broken " + REM + " brokenopener keep words", H),
    u("2026-11-08T01:02:30.000Z", '<system-reminder kind="linked">\nattrenvelope body\n</system-reminder>', {}),
    u("2026-11-08T01:03:00.000Z", REM + "\n\n<side-sessions-event>sidebody none of the sessions is working</side-sessions-event>", {"promptSource": "sdk"}),
]
with open(d + "/l53.jsonl", "w", encoding="utf-8") as f:
    for r in rows: f.write(json.dumps(r, ensure_ascii=False) + "\n")
# L54: the hook record holds the operator's words without the blocks — the pair must be ONE row
with open(d + "/l54_tr.jsonl", "w", encoding="utf-8") as f:
    f.write(json.dumps(u("2026-11-08T01:53:00.000Z", REM + "\n\n\nplease ship the badge fix now", H)) + "\n")
with open(d + "/l54_hook.jsonl", "w", encoding="utf-8") as f:
    f.write(json.dumps({"ts": "2026-11-08T01:53:00Z", "n": 1, "text": "please ship the badge fix now"}) + "\n")
PYEOF
run "$TMPDIR_ROOT/l53.out" extract --transcript "$TMPDIR_ROOT/l53.jsonl"
L53_REM=$(grep -cE '^\| [0-9]+ \| [^|]* \| <system-reminder>' "$TMPDIR_ROOT/l53.out")
if [ "$RC" -eq 0 ] && grep -q "raw 7건" "$TMPDIR_ROOT/l53.out" \
   && grep -qE '^\| [0-9]+ \| [^|]* \| approved, go ahead with alpha \|' "$TMPDIR_ROOT/l53.out" \
   && grep -qE '^\| [0-9]+ \| [^|]* \| stacked words after two blocks \|' "$TMPDIR_ROOT/l53.out" \
   && ! grep -q "first block body" "$TMPDIR_ROOT/l53.out" \
   && grep -q "unclosed look-alike then my own words" "$TMPDIR_ROOT/l53.out" \
   && grep -q "lookalike2 opener" "$TMPDIR_ROOT/l53.out" \
   && grep -q "my mid words .*Linked sessions now" "$TMPDIR_ROOT/l53.out" \
   && grep -q "<system-reminder-x>tagname body" "$TMPDIR_ROOT/l53.out" \
   && ! grep -q "sidebody" "$TMPDIR_ROOT/l53.out" && ! grep -q "attrenvelope body" "$TMPDIR_ROOT/l53.out" && grep -q "<system-reminder kind=broken <system-reminder> Linked" "$TMPDIR_ROOT/l53.out" && [ "$L53_REM" -eq 2 ]; then
  pass "L53 extract: leading complete reminder blocks are stripped (single · stacked with attrs/CRLF); unclosed look-alike, look-alike before a block, mid-text tag and other tag name are kept; side-sessions-event behind the blocks is excluded"
else
  fail "L53 rc=$RC reminder-rows=$L53_REM (want 2: the two exact-opener look-alike rows) (see $TMPDIR_ROOT/l53.out)"
fi
run "$TMPDIR_ROOT/l54.out" extract --transcript "$TMPDIR_ROOT/l54_tr.jsonl" --utterances "$TMPDIR_ROOT/l54_hook.jsonl"
L54_ROWS=$(grep -cE '^\| [0-9HS]+ \|' "$TMPDIR_ROOT/l54.out")
if [ "$RC" -eq 0 ] && [ "$L54_ROWS" -eq 1 ] && ! grep -qE '^\| H' "$TMPDIR_ROOT/l54.out" \
   && grep -qE '^\| 1 \| [^|]* \| please ship the badge fix now \|' "$TMPDIR_ROOT/l54.out"; then
  pass "L54 hook merge: a reminder-prefixed transcript row pairs with the hook's plain text — one row, no H duplicate"
else
  fail "L54 rc=$RC rows=$L54_ROWS (want 1, no H) (see $TMPDIR_ROOT/l54.out)"
fi

# L55 — re-extract keeps every line the table parser does not consume (2026-11-14 harvest H3: a result-sheet section
# written below the table — 13 lines — vanished on `extract --out`). Known pair + decoys:
#   preface above the table · a result section below it · a decoy that LOOKS 7-column but is not a row (no «| » lead) ·
#   an 8-cell line · a real 7-cell row with a judgment (must stay an orphan row, NOT be copied into the kept block too).
# Then a second re-extract over that output must be byte-identical (idempotent).
build_jsonl "$TMPDIR_ROOT/l55.jsonl" "[{'type':'user','timestamp':'2026-10-18T01:00:00.000Z','message':{'role':'user','content':'Please move the session bar a little higher than it is now.'}}]"
L55="$TMPDIR_ROOT/l55.md"
run "$TMPDIR_ROOT/l55a.out" extract --transcript "$TMPDIR_ROOT/l55.jsonl" --out "$L55"
L55A_RC=$RC
python3 - "$L55" <<'PYEOF'
import sys
p = sys.argv[1]; L = open(p, encoding="utf-8").read().rstrip("\n").split("\n")
i = next(k for k, l in enumerate(L) if l.startswith("| # |"))
L[i:i] = ["PREFACE-LINE operator note above the table", ""]
L += ["", "## 8차 결과 시트", "", "RESULT-LINE-1 merged #1095 after CI green", "",
      "|decoy|b|c|d|e|f|g|", "| e1 | e2 | e3 | e4 | e5 | e6 | e7 | e8 |",
      "RESULT-LINE-2 still open: P22-B", "| 9 | 10-17 08:00 | gone utterance | ✅DONE | x | - | - |"]
open(p, "w", encoding="utf-8").write("\n".join(L) + "\n")
PYEOF
run "$TMPDIR_ROOT/l55b.out" extract --transcript "$TMPDIR_ROOT/l55.jsonl" --out "$L55"
L55B_RC=$RC; cp "$L55" "$TMPDIR_ROOT/l55_after1.md"
run "$TMPDIR_ROOT/l55c.out" extract --transcript "$TMPDIR_ROOT/l55.jsonl" --out "$L55"
L55C_RC=$RC
L55_KEPT=$(awk '/^## 이전 결과서의 표 밖 내용/{f=1;next} f' "$L55")
L55_ORDER=$(printf '%s\n' "$L55_KEPT" | grep -nE '^(PREFACE-LINE|## 8차|RESULT-LINE-1|\|decoy|\| e1 |RESULT-LINE-2)' | cut -d: -f2- | awk '{print $1}' | tr '\n' ',')
if [ "$L55A_RC" -eq 0 ] && [ "$L55B_RC" -eq 0 ] && [ "$L55C_RC" -eq 0 ] \
   && [ "$L55_ORDER" = "PREFACE-LINE,##,RESULT-LINE-1,|decoy|b|c|d|e|f|g|,|,RESULT-LINE-2," ] \
   && [ "$(grep -c 'gone utterance' "$L55")" -eq 1 ] \
   && awk '/^## 이전 결과서에서 이어받지 못한 판정/{f=1} f && /gone utterance/{ok=1} /^## 이전 결과서의 표 밖 내용/{f=0} END{exit !ok}' "$L55" \
   && [ "$(grep -c 'PREFACE-LINE' "$L55")" -eq 1 ] && [ "$(grep -c '^|decoy|' "$L55")" -eq 1 ] \
   && ! printf '%s\n' "$L55_KEPT" | grep -qE '^(📎|↩️|채널 2/2|\|---)' \
   && grep -q '표 밖 줄 6줄은 맨 아래' "$L55" \
   && cmp -s "$L55" "$TMPDIR_ROOT/l55_after1.md"; then
  pass "L55 re-extract keeps non-table lines (preface · result section · 7-col-looking decoy · 8-cell line) in order, once; a real row stays an orphan row; a second re-extract is byte-identical"
else
  fail "L55 rc=$L55A_RC/$L55B_RC/$L55C_RC order=$L55_ORDER (see $L55 · $TMPDIR_ROOT/l55_after1.md)"
fi

# L56 — what an independent review reproduced against L55's first version (2026-11-15), each a known-positive:
#   a note starting with a generated prefix · a note appended to a generated status line · a hand-added row with empty
#   judgment cells · a fenced block holding a 7-cell line, a separator and two blank lines · a person's own 3-column table.
# Known-negative (the control that keeps the regexes honest): the transcript grows between runs, so «채널 2/2 …» and
# «📎 원장 … (N lines)» change counts — their stale copies must NOT pile up in the kept block. Then a further run is identical.
build_jsonl "$TMPDIR_ROOT/l56.jsonl" "[{'type':'user','timestamp':'2026-10-18T01:00:00.000Z','message':{'role':'user','content':'Please move the session bar a little higher than it is now.'}}]"
L56="$TMPDIR_ROOT/l56.md"
run "$TMPDIR_ROOT/l56a.out" extract --transcript "$TMPDIR_ROOT/l56.jsonl" --out "$L56"
L56A_RC=$RC
python3 - "$L56" <<'PYEOF'
import sys
p = sys.argv[1]; L = open(p, encoding="utf-8").read().rstrip("\n").split("\n")
i = next(k for k, l in enumerate(L) if l.startswith("채널 2/2"))
L.insert(i + 1, L[i] + " · NOTE-APPENDED by the operator")   # keep the pure status line too: its stale copy is the control
L += ["", "🟥 훅 기록 NOTE-PREFIX the operator's red note",
      "| hand | 10-17 07:00 | NOTE-HANDROW a request added by hand |  |  |  |  |",
      "", "```", "| a | b | c | d | e | f | g |", "", "", "code after two blanks", "|---|---|", "```",
      "", "| k | v | w |", "|---|---|---|", "| 1 | 2 | 3 |"]
open(p, "w", encoding="utf-8").write("\n".join(L) + "\n")
PYEOF
cp "$L56" "$TMPDIR_ROOT/l56_edited.md"
build_jsonl "$TMPDIR_ROOT/l56.jsonl" "[{'type':'user','timestamp':'2026-10-18T01:00:00.000Z','message':{'role':'user','content':'Please move the session bar a little higher than it is now.'}},{'type':'user','timestamp':'2026-10-18T01:09:00.000Z','message':{'role':'user','content':'Also make the badge smaller please.'}}]"
run "$TMPDIR_ROOT/l56b.out" extract --transcript "$TMPDIR_ROOT/l56.jsonl" --out "$L56"
L56B_RC=$RC; cp "$L56" "$TMPDIR_ROOT/l56_after1.md"
run "$TMPDIR_ROOT/l56c.out" extract --transcript "$TMPDIR_ROOT/l56.jsonl" --out "$L56"
L56C_RC=$RC
L56_KEPT=$(awk '/^## 이전 결과서의 표 밖 내용/{f=1;next} f' "$L56")
L56_FENCE=$(printf '%s\n' "$L56_KEPT" | awk '/^```/{n++; print; next} n==1{print}' | tr '\n' '~')
if [ "$L56A_RC" -eq 0 ] && [ "$L56B_RC" -eq 0 ] && [ "$L56C_RC" -eq 0 ] \
   && printf '%s\n' "$L56_KEPT" | grep -q 'NOTE-APPENDED by the operator' \
   && printf '%s\n' "$L56_KEPT" | grep -qF "🟥 훅 기록 NOTE-PREFIX the operator's red note" \
   && printf '%s\n' "$L56_KEPT" | grep -qF '| hand | 10-17 07:00 | NOTE-HANDROW a request added by hand |  |  |  |  |' \
   && [ "$L56_FENCE" = '```~| a | b | c | d | e | f | g |~~~code after two blanks~|---|---|~```~' ] \
   && printf '%s\n' "$L56_KEPT" | grep -qxF '|---|---|---|' \
   && ! grep -q '^| - | b | c |' "$L56" \
   && [ "$(printf '%s\n' "$L56_KEPT" | grep -c '^채널 2/2 열음 — raw [0-9]*건 · 압축 요약 [0-9]*건([^)]*)$')" -eq 0 ] \
   && [ "$(printf '%s\n' "$L56_KEPT" | grep -c '원장 = .* lines)$')" -eq 0 ] \
   && grep -q '^채널 2/2 열음 — raw 2건' "$L56" \
   && cmp -s "$L56" "$TMPDIR_ROOT/l56_after1.md"; then
  pass "L56 kept: prefix-looking note · note on a status line · hand row with empty judgments · fenced code verbatim · own 3-col table; stale status lines do not pile up when counts change; next run identical"
else
  fail "L56 rc=$L56A_RC/$L56B_RC/$L56C_RC fence=$L56_FENCE (see $L56 · $TMPDIR_ROOT/l56_edited.md)"
fi

# L57 — the second independent review (2026-11-15) against L56's version, each reproduced there:
#   (a) a hook-only H row from a run WITH the hook file must not be kept when the next run has no hook file
#   (b) skeleton rows of a longer transcript must not be kept when the sheet is re-extracted from a shorter one
#   (c) an UNCLOSED fence above the table must not swallow it: row 1's judgment is still carried into the live table
#   (d) a 4-backtick fence holding «```» and a filled 7-cell row is kept verbatim, not split or orphaned
#   (e) a person's own 7-column table keeps its separator line
python3 - "$TMPDIR_ROOT" <<'PYEOF'
import json, sys, datetime
d = sys.argv[1]
def loc(z):
    t = datetime.datetime.strptime(z, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=datetime.timezone.utc).astimezone()
    return t.strftime("%Y-%m-%dT%H:%M:%S")
def tr(path, texts):
    with open(path, "w", encoding="utf-8") as f:
        for k, t in enumerate(texts):
            f.write(json.dumps({"type": "user", "timestamp": "2026-10-18T01:0%d:00Z" % k, "message": {"role": "user", "content": t}}) + "\n")
tr(d + "/l57_long.jsonl", ["first request about the session bar", "second request about the badge", "third request about the footer"])
tr(d + "/l57_short.jsonl", ["first request about the session bar"])
with open(d + "/l57_hook.jsonl", "w", encoding="utf-8") as f:
    f.write(json.dumps({"ts": loc("2026-10-18T01:00:00Z"), "n": 1, "text": "first request about the session bar"}) + "\n")
    f.write(json.dumps({"ts": loc("2026-10-18T05:00:00Z"), "n": 2, "text": "HOOKONLY request typed while a tool ran"}) + "\n")
PYEOF
L57="$TMPDIR_ROOT/l57.md"
run "$TMPDIR_ROOT/l57a.out" extract --transcript "$TMPDIR_ROOT/l57_long.jsonl" --utterances "$TMPDIR_ROOT/l57_hook.jsonl" --out "$L57"
L57_RCS="$RC"
L57_HROW=$(grep -c '^| H1 | .*HOOKONLY' "$L57")               # control: the H row really existed in run 1
python3 - "$L57" <<'PYEOF'
import sys
p = sys.argv[1]; L = open(p, encoding="utf-8").read().rstrip("\n").split("\n")
L.insert(1, "```python"); L.insert(2, "x = 1   # FENCE-UNCLOSED the operator never closed this")
for k, l in enumerate(L):
    if l.startswith("| 1 |"):
        L[k] = l.replace("|  |  |  |  |", "| ✅DONE | L57-EVID | - | - |")
L += ["", "````", "```", "| 9 | 10-18 01:09 | FENCE4 in fence | x | y | z | w |", "```", "````",
      "", "OWN-TABLE:", "| a | b | c | d | e | f | g |", "|---|---|---|---|---|---|---|", "| 1x | p | q |  |  |  |  |"]
open(p, "w", encoding="utf-8").write("\n".join(L) + "\n")
PYEOF
run "$TMPDIR_ROOT/l57b.out" extract --transcript "$TMPDIR_ROOT/l57_short.jsonl" --out "$L57"
L57_RCS="$L57_RCS/$RC"; cp "$L57" "$TMPDIR_ROOT/l57_after1.md"
run "$TMPDIR_ROOT/l57c.out" extract --transcript "$TMPDIR_ROOT/l57_short.jsonl" --out "$L57"
L57_RCS="$L57_RCS/$RC"
L57_KEPT=$(awk '/^## 이전 결과서의 표 밖 내용/{f=1;next} f' "$L57")
L57_LIVE=$(awk '/^## /{exit} {print}' "$L57")
L57_F4=$(printf '%s\n' "$L57_KEPT" | awk '/^````$/{n++; print; next} n==1{print}' | tr '\n' '~')
if [ "$L57_RCS" = "0/0/0" ] && [ "$L57_HROW" -eq 1 ] \
   && ! grep -q 'HOOKONLY' "$L57" \
   && ! grep -qE '^\| [0-9]+ \| [^|]* \| (second|third) request' "$L57" \
   && printf '%s\n' "$L57_LIVE" | grep -qE '^\| 1 \| .*first request.* \| ✅DONE \| L57-EVID \| - \| - \|$' \
   && printf '%s\n' "$L57_KEPT" | grep -qF 'FENCE-UNCLOSED' \
   && [ "$L57_F4" = '````~```~| 9 | 10-18 01:09 | FENCE4 in fence | x | y | z | w |~```~````~' ] \
   && ! grep -q '^| - | 10-18 01:09 | FENCE4' "$L57" \
   && printf '%s\n' "$L57_KEPT" | awk '/^OWN-TABLE:/{f=1} f' | grep -qxF '|---|---|---|---|---|---|---|' \
   && printf '%s\n' "$L57_KEPT" | grep -qF '| 1x | p | q |  |  |  |  |' \
   && cmp -s "$L57" "$TMPDIR_ROOT/l57_after1.md"; then
  pass "L57 no stale H/skeleton rows kept · unclosed fence leaves the table live (judgment carried) · 4-tick fence verbatim · own 7-col separator kept · next run identical"
else
  fail "L57 rc=$L57_RCS hrow=$L57_HROW f4=$L57_F4 (see $L57 · $TMPDIR_ROOT/l57_after1.md)"
fi

echo "── $PASS_COUNT passed, $FAIL_COUNT failed ──"

if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
exit 0

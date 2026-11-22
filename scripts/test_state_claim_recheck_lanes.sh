#!/usr/bin/env bash
# test_state_claim_recheck_lanes.sh — lanes for scripts/state_claim_recheck_hook.sh
#   P1  positive  : answer «#387 merge is for the morning» + lease line «… #387 머지 …» → stop writes a
#                   note, prompt injects it once (L-number + line), second prompt is silent (consumed)
#   N1  negative  : same answer, lease has no #387 utterance line → silent
#   N2  negative  : #387 named but no state word → silent
#   N3  boundary  : lease has #3870 only → silent (number boundary)
#   N4  degrade   : lease file missing → silent, rc 0
#   P2  transcript: no last_assistant_message → last assistant text read from transcript_path
#   C1  control   : stop_hook_active=true → silent
#   R1  revert    : the lease-grep step disabled in a copy → P1 goes silent (lane is red on the mutant)
#   S1–S5 once per session: same claim twice → second silent · new lease line for the same #N fires ·
#         another session fires · unreadable seen file fails open · lines past the 8-line cap show next time
#   S6  compaction: a compact_boundary entry in the transcript starts a new seen file → shown again once
#   S7  ordering  : stop A, stop B, prompt → B injected and only B marked; A shows on its next claim
#   R5  revert    : the seen filter disabled in a copy → S1 speaks again (lane is red on the mutant)
#   R6  revert    : the compaction count disabled in a copy → S6 stays silent after compaction
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
SUBJ="scripts/state_claim_recheck_hook.sh"
[ -f "$SUBJ" ] || { echo "HARNESS-ERROR: $SUBJ missing"; exit 2; }
T="$(mktemp -d "${TMPDIR:-/tmp}/scr_lanes.XXXXXX")"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok() { echo "  ✅ $1"; pass=$((pass+1)); }
ko() { echo "  ❌ $1"; fail=$((fail+1)); }

printf '%s\n' "# lease" "scope ① …" \
  "            추가 utterance 2026-11-07 «머지해» (물음: qasp-dev #387 내장 기본값 폴백 막기 머지할까) ⇒ #387 머지" \
  > "$T/lease_yes.md"
printf '%s\n' "# lease" "            추가 utterance 2026-11-07 «머지해» (물음: #386 머지할까)" > "$T/lease_no.md"
printf '%s\n' "# lease" "            추가 utterance 2026-11-07 «머지해» (물음: #3870 머지할까)" > "$T/lease_3870.md"

run() {  # $1 subj $2 lease $3 dir $4 mode $5 json → stdout
  FH_LEASE_FILE="$2" FH_STATE_CLAIM_DIR="$3" bash "$1" "$4" <<<"$5"
}
ANS='{"session_id":"s1","last_assistant_message":"qasp-dev #387 은 CI 초록, 머지는 아침에 묻는다."}'
P='{"session_id":"s1","prompt":"ok"}'

echo "P1 positive"
D="$T/p1"; run "$SUBJ" "$T/lease_yes.md" "$D" stop "$ANS"; rc=$?
out="$(run "$SUBJ" "$T/lease_yes.md" "$D" prompt "$P")"
again="$(run "$SUBJ" "$T/lease_yes.md" "$D" prompt "$P")"
[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '"additionalContext"' && printf '%s' "$out" | grep -q 'L3' \
  && printf '%s' "$out" | grep -q '#387' && ok "note injected with line number" || ko "P1 no note (rc=$rc out=${out:0:120})"
[ -z "$again" ] && ok "note consumed once" || ko "P1 note repeated"

echo "N1 no lease line"
D="$T/n1"; run "$SUBJ" "$T/lease_no.md" "$D" stop "$ANS" >/dev/null
out="$(run "$SUBJ" "$T/lease_no.md" "$D" prompt "$P")"; [ -z "$out" ] && ok "silent" || ko "N1 spoke: ${out:0:80}"

echo "N2 no state word"
D="$T/n2"; run "$SUBJ" "$T/lease_yes.md" "$D" stop '{"session_id":"s1","last_assistant_message":"#387 의 diff 를 읽었다."}' >/dev/null
out="$(run "$SUBJ" "$T/lease_yes.md" "$D" prompt "$P")"; [ -z "$out" ] && ok "silent" || ko "N2 spoke"

echo "N3 number boundary"
D="$T/n3"; run "$SUBJ" "$T/lease_3870.md" "$D" stop "$ANS" >/dev/null
out="$(run "$SUBJ" "$T/lease_3870.md" "$D" prompt "$P")"; [ -z "$out" ] && ok "#3870 does not match #387" || ko "N3 matched #3870"

echo "N4 lease missing"
D="$T/n4"; run "$SUBJ" "$T/absent.md" "$D" stop "$ANS"; rc=$?
out="$(run "$SUBJ" "$T/absent.md" "$D" prompt "$P")"; [ "$rc" -eq 0 ] && [ -z "$out" ] && ok "silent rc 0" || ko "N4 rc=$rc"

echo "P2 transcript fallback"
printf '%s\n' '{"type":"user","message":{"content":"x"}}' \
  '{"type":"assistant","message":{"content":[{"type":"text","text":"#387 머지는 아침에."}]}}' > "$T/tr.jsonl"
D="$T/p2"; run "$SUBJ" "$T/lease_yes.md" "$D" stop "{\"session_id\":\"s2\",\"transcript_path\":\"$T/tr.jsonl\"}" >/dev/null
out="$(run "$SUBJ" "$T/lease_yes.md" "$D" prompt '{"session_id":"s2"}')"
printf '%s' "$out" | grep -q '#387' && ok "read from transcript" || ko "P2 silent"

echo "T2 last assistant message is tool-only → silent (no older answer reported)"
printf '%s\n' '{"type":"assistant","message":{"id":"a1","content":[{"type":"text","text":"#387 머지는 아침에."}]}}' \
  '{"type":"assistant","message":{"id":"a2","content":[{"type":"tool_use","name":"Bash","input":{}}]}}' > "$T/tr2.jsonl"
D="$T/t2"; run "$SUBJ" "$T/lease_yes.md" "$D" stop "{\"session_id\":\"s3\",\"transcript_path\":\"$T/tr2.jsonl\"}" >/dev/null
out="$(run "$SUBJ" "$T/lease_yes.md" "$D" prompt '{"session_id":"s3"}')"; [ -z "$out" ] && ok "silent" || ko "T2 reported an older answer"

echo "N5 number outside the state-word clause"
D="$T/n5"; run "$SUBJ" "$T/lease_yes.md" "$D" stop '{"session_id":"s1","last_assistant_message":"#100 은 머지는 아침에.\n#387 diff 를 읽었다."}' >/dev/null
out="$(run "$SUBJ" "$T/lease_yes.md" "$D" prompt "$P")"; [ -z "$out" ] && ok "#387 not claimed → silent" || ko "N5 matched across clauses"

echo "N8 semicolon clause · P3 claim split over two sentences · P4 note names only matched numbers"
D="$T/n8"; run "$SUBJ" "$T/lease_yes.md" "$D" stop '{"session_id":"s1","last_assistant_message":"Merge #100 tomorrow; read #387 diff"}' >/dev/null
out="$(run "$SUBJ" "$T/lease_yes.md" "$D" prompt "$P")"; [ -z "$out" ] && ok "N8 silent" || ko "N8 matched across ;"
D="$T/p3"; run "$SUBJ" "$T/lease_yes.md" "$D" stop '{"session_id":"s1","last_assistant_message":"qasp-dev #387 은 CI 초록. 머지는 아침에 묻는다."}' >/dev/null
out="$(run "$SUBJ" "$T/lease_yes.md" "$D" prompt "$P")"; printf '%s' "$out" | grep -q '#387' && ok "P3 previous clause counts" || ko "P3 missed the two-sentence claim"
D="$T/p4"; run "$SUBJ" "$T/lease_yes.md" "$D" stop '{"session_id":"s1","last_assistant_message":"Merge #100 and #387 in the morning."}' >/dev/null
out="$(run "$SUBJ" "$T/lease_yes.md" "$D" prompt "$P")"
printf '%s' "$out" | grep -q '#387' && ! printf '%s' "$out" | grep -q '#100' && ok "P4 only #387 named" || ko "P4 note: ${out:0:160}"
printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"text","text":"#387 머지는 아침에."}]}}' \
  '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{}}]}}' > "$T/tr3.jsonl"
D="$T/t3"; run "$SUBJ" "$T/lease_yes.md" "$D" stop "{\"session_id\":\"s4\",\"transcript_path\":\"$T/tr3.jsonl\"}" >/dev/null
out="$(run "$SUBJ" "$T/lease_yes.md" "$D" prompt '{"session_id":"s4"}')"; [ -z "$out" ] && ok "T3 id-less tool-only last entry → silent" || ko "T3 reported an older answer"

echo "Q1–Q5 quoted / code examples (the two live false positives of 2026-11-07)"
qrun() {  # $1 name · $2 answer json-escaped · $3 want: note|silent
  local D="$T/$1"; run "$SUBJ" "$T/lease_yes.md" "$D" stop "{\"session_id\":\"s1\",\"last_assistant_message\":\"$2\"}" >/dev/null
  local o; o="$(run "$SUBJ" "$T/lease_yes.md" "$D" prompt "$P")"
  if [ "$3" = silent ]; then [ -z "$o" ] && ok "$1 silent" || ko "$1 spoke"
  else printf '%s' "$o" | grep -q '#387' && ok "$1 note" || ko "$1 missed"; fi
}
qrun Q1 '스크립트를 돌려 보니 «#387 머지는 아침에» 같은 답에 대기 노트가 생겼어.' silent
qrun Q2 '예: `#387 머지는 아침에` 를 넣으면 한 줄이 실린다.' silent
qrun Q3 '내가 예시로 든 \"#387 머지는 아침에\" 를 잡은 거라 오탐이야.' silent
qrun Q4 'qasp-dev #387 은 «머지해» 줄이 있어서 이미 머지했다.' note
qrun Q5 '```\n#387 머지는 아침에\n```' silent
qrun Q6 '🔎 [state-claim] 직전 답이 #387 의 머지·허락·아침류 상태를 말했다.\n  #387 · L468: 추가 utterance 2026-11-07 «머지해» (물음: #387 머지할까) ⇒ #387 머지\n기계는 «줄이 있다» 만 말한다.' silent
qrun Q7 '`#387` 은 이미 머지했다.' note
qrun Q8 '예시:\n«\n#387 머지는 아침에\n»' silent
qrun Q9 '예시:\n```\n#387 머지는 아침에' silent

echo "N6 no session id · N7 malformed payload → silent, no stderr"
D="$T/n6"; run "$SUBJ" "$T/lease_yes.md" "$D" stop '{"last_assistant_message":"#387 머지는 아침에"}' >/dev/null
[ -z "$(ls -A "$D" 2>/dev/null)" ] && ok "N6 no shared pending file" || ko "N6 wrote a pending file without a session id"
err="$(FH_LEASE_FILE="$T/lease_yes.md" FH_STATE_CLAIM_DIR="$T/n7" bash "$SUBJ" stop <<<'[]' 2>&1 >/dev/null)"; rc=$?
err2="$(FH_LEASE_FILE="$T/lease_yes.md" FH_STATE_CLAIM_DIR="$T/n7" bash "$SUBJ" stop <<<'{"session_id":"s1","last_assistant_message":42}' 2>&1 >/dev/null)"
[ "$rc" -eq 0 ] && [ -z "$err$err2" ] && ok "N7 silent rc 0" || ko "N7 rc=$rc stderr=${err:0:80}${err2:0:80}"

echo "C1 stop_hook_active"
D="$T/c1"; run "$SUBJ" "$T/lease_yes.md" "$D" stop '{"session_id":"s1","stop_hook_active":true,"last_assistant_message":"#387 머지는 아침에"}' >/dev/null
out="$(run "$SUBJ" "$T/lease_yes.md" "$D" prompt "$P")"; [ -z "$out" ] && ok "silent" || ko "C1 spoke"

echo "R1 revert probe (lease grep disabled)"
M="$T/mutant.sh"; sed 's/if "utterance" in ln and pat.search(ln):/if False:/' "$SUBJ" > "$M"
if cmp -s "$SUBJ" "$M"; then ko "R1 mutation did not apply (HARNESS-ERROR)"; else
  D="$T/r1"; run "$M" "$T/lease_yes.md" "$D" stop "$ANS" >/dev/null
  out="$(run "$M" "$T/lease_yes.md" "$D" prompt "$P")"
  [ -z "$out" ] && ok "mutant silent → P1 would be red" || ko "R1 mutant still injects (lane does not see the grep)"
fi

echo "R2 revert probe (quoted-span drop disabled)"
M2="$T/mutant2.sh"; sed 's/^    text = QUOTED.sub(.*$/    pass/' "$SUBJ" > "$M2"
if cmp -s "$SUBJ" "$M2"; then ko "R2 mutation did not apply (HARNESS-ERROR)"; else
  D="$T/r2"; run "$M2" "$T/lease_yes.md" "$D" stop '{"session_id":"s1","last_assistant_message":"스크립트를 돌려 보니 «#387 머지는 아침에» 같은 답에 대기 노트가 생겼어."}' >/dev/null
  out="$(run "$M2" "$T/lease_yes.md" "$D" prompt "$P")"
  [ -n "$out" ] && ok "mutant speaks on Q1 → Q1 would be red" || ko "R2 mutant still silent (lane does not see the drop)"
fi

echo "A1–A4 lease archive (expired utterance lines moved out of the lease file)"
printf '%s\n' "# archive" '```' \
  "            추가 utterance 2026-11-12 «머지해» (물음: FH #1101 머지할까) ⇒ #1101 머지" '```' > "$T/archive.md"
arun() {  # $1 subj $2 lease $3 archive $4 dir $5 mode $6 json
  FH_LEASE_FILE="$2" FH_LEASE_ARCHIVE="$3" FH_STATE_CLAIM_DIR="$4" bash "$1" "$5" <<<"$6"
}
ANS_A='{"session_id":"s1","last_assistant_message":"FH #1101 은 머지는 아침에 묻는다."}'
D="$T/a1"; arun "$SUBJ" "$T/lease_yes.md" "$T/archive.md" "$D" stop "$ANS_A" >/dev/null
out="$(arun "$SUBJ" "$T/lease_yes.md" "$T/archive.md" "$D" prompt "$P")"
printf '%s' "$out" | grep -q '\[보관 · 만료\] #1101 · L3: ' && printf '%s' "$out" | grep -q '만료된 기록이다' \
  && printf '%s' "$out" | grep -q 'archive.md' && ok "A1 archive-only number → note names the archive" || ko "A1 archive hit missing: ${out:0:200}"
D="$T/a2"; arun "$SUBJ" "$T/lease_yes.md" "$T/archive.md" "$D" stop "$ANS" >/dev/null
with_a="$(arun "$SUBJ" "$T/lease_yes.md" "$T/archive.md" "$D" prompt "$P")"
D="$T/a2b"; run "$SUBJ" "$T/lease_yes.md" "$D" stop "$ANS" >/dev/null
no_a="$(FH_LEASE_ARCHIVE="$T/absent_archive.md" FH_LEASE_FILE="$T/lease_yes.md" FH_STATE_CLAIM_DIR="$D" bash "$SUBJ" prompt <<<"$P")"
[ -n "$with_a" ] && [ "$with_a" = "$no_a" ] && ! printf '%s' "$with_a" | grep -q '보관' \
  && ok "A2 resident-file hit → output identical with or without the archive" || ko "A2 resident output changed: ${with_a:0:160}"
D="$T/a3"; err="$(arun "$SUBJ" "$T/lease_yes.md" "$T/absent_archive.md" "$D" stop "$ANS_A" 2>&1 >/dev/null)"; rc=$?
out="$(arun "$SUBJ" "$T/lease_yes.md" "$T/absent_archive.md" "$D" prompt "$P")"
[ "$rc" -eq 0 ] && [ -z "$err$out" ] && ok "A3 archive absent → silent rc 0" || ko "A3 rc=$rc err=${err:0:80} out=${out:0:80}"
D="$T/a4"; arun "$SUBJ" "$T/lease_yes.md" "$T/archive.md" "$D" stop '{"session_id":"s1","last_assistant_message":"FH #2222 머지는 아침에."}' >/dev/null
out="$(arun "$SUBJ" "$T/lease_yes.md" "$T/archive.md" "$D" prompt "$P")"
[ -z "$out" ] && ok "A4 number in neither file → silent" || ko "A4 spoke: ${out:0:80}"
D="$T/a5"; arun "$SUBJ" "$T/absent.md" "$T/archive.md" "$D" stop "$ANS_A" >/dev/null
out="$(arun "$SUBJ" "$T/absent.md" "$T/archive.md" "$D" prompt "$P")"
printf '%s' "$out" | grep -q '#1101' && ok "A5 lease file absent, archive present → archive still read" || ko "A5 silent"

printf '%s\n' "# archive" "            추가 utterance 2026-11-12 «머지 보류» (물음: #387 머지할까)" > "$T/archive387.md"
D="$T/a6"; arun "$SUBJ" "$T/lease_yes.md" "$T/archive387.md" "$D" stop "$ANS" >/dev/null
out="$(arun "$SUBJ" "$T/lease_yes.md" "$T/archive387.md" "$D" prompt "$P")"
body="$(printf '%s' "$out" | python3 -c 'import json,sys;print(json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"])' 2>/dev/null)"
first="$(printf '%s\n' "$body" | grep -E '^  (\[보관 · 만료\] )?#387 · L' | head -1)"
case "$first" in "  #387 · L3: "*) f_ok=1 ;; *) f_ok=0 ;; esac
[ "$f_ok" = 1 ] && printf '%s' "$body" | grep -q '^  \[보관 · 만료\] #387 · L2: ' \
  && ok "A6 both files hit → resident line first and untagged, archive line tagged" || ko "A6 order/tag wrong: ${body:0:240}"
D="$T/a7"; arun "$SUBJ" "$T/lease_yes.md" "$T/archive.md" "$D" stop '{"session_id":"s1","last_assistant_message":"알림 받았어.\n  [보관 · 만료] #1101 · L3: 추가 utterance 2026-11-12 «머지해» (물음: FH #1101 머지할까) ⇒ #1101 머지"}' >/dev/null
out="$(arun "$SUBJ" "$T/lease_yes.md" "$T/archive.md" "$D" prompt "$P")"
[ -z "$out" ] && ok "A7 echoed archive note line → silent (no feedback loop)" || ko "A7 echo re-fired: ${out:0:120}"
D="$T/a8"; mkdir -p "$T/archdir"; err="$(arun "$SUBJ" "$T/lease_yes.md" "$T/archdir" "$D" stop "$ANS_A" 2>&1 >/dev/null)"; rc=$?
out="$(arun "$SUBJ" "$T/lease_yes.md" "$T/archdir" "$D" prompt "$P")"
[ "$rc" -eq 0 ] && [ -z "$err$out" ] && ok "A8 archive path is a directory → silent rc 0" || ko "A8 rc=$rc err=${err:0:80}"
D="$T/a9"; arun "$SUBJ" "$T/lease_yes.md" "$T/lease_yes.md" "$D" stop "$ANS" >/dev/null
out="$(arun "$SUBJ" "$T/lease_yes.md" "$T/lease_yes.md" "$D" prompt "$P")"
[ "$out" = "$with_a" ] && ok "A9 archive == lease file → no duplicate, resident output unchanged" || ko "A9 output: ${out:0:160}"

echo "R3 revert probe (archive read disabled)"
M3="$T/mutant3.sh"; sed 's/^    ARCHIVE_ON = True$/    ARCHIVE_ON = False/' "$SUBJ" > "$M3"
if cmp -s "$SUBJ" "$M3"; then ko "R3 mutation did not apply (HARNESS-ERROR)"; else
  D="$T/r3"; arun "$M3" "$T/lease_yes.md" "$T/archive.md" "$D" stop "$ANS_A" >/dev/null
  out="$(arun "$M3" "$T/lease_yes.md" "$T/archive.md" "$D" prompt "$P")"
  [ -z "$out" ] && ok "mutant silent → A1 would be red" || ko "R3 mutant still reports the archive line"
  D="$T/r3b"; arun "$M3" "$T/lease_yes.md" "$T/archive.md" "$D" stop "$ANS" >/dev/null
  out="$(arun "$M3" "$T/lease_yes.md" "$T/archive.md" "$D" prompt "$P")"
  [ "$out" = "$with_a" ] && ok "mutant keeps A2 green (resident path untouched)" || ko "R3 mutant changed the resident output"
fi

echo "R4 revert probe (note-echo filter without the archive tag)"
M4="$T/mutant4.sh"; sed 's/(?:\\\[보관 · 만료\\\] )?#/#/' "$SUBJ" > "$M4"
if cmp -s "$SUBJ" "$M4"; then ko "R4 mutation did not apply (HARNESS-ERROR)"; else
  D="$T/r4"; arun "$M4" "$T/lease_yes.md" "$T/archive.md" "$D" stop '{"session_id":"s1","last_assistant_message":"알림 받았어.\n  [보관 · 만료] #1101 · L3: 추가 utterance 2026-11-12 «머지해» (물음: FH #1101 머지할까) ⇒ #1101 머지"}' >/dev/null
  out="$(arun "$M4" "$T/lease_yes.md" "$T/archive.md" "$D" prompt "$P")"
  [ -n "$out" ] && ok "mutant re-fires on the echo → A7 would be red" || ko "R4 mutant still silent"
fi

echo "S1–S5 once per session (AQ-20261107-29 ⓐ: the same note re-sent two turns running)"
cp "$T/lease_yes.md" "$T/lease_s.md"
D="$T/s1"; run "$SUBJ" "$T/lease_s.md" "$D" stop "$ANS" >/dev/null
first="$(run "$SUBJ" "$T/lease_s.md" "$D" prompt "$P")"
run "$SUBJ" "$T/lease_s.md" "$D" stop "$ANS" >/dev/null
second="$(run "$SUBJ" "$T/lease_s.md" "$D" prompt "$P")"
printf '%s' "$first" | grep -q '#387' && [ -z "$second" ] && ok "S1 same claim, same line → shown once" || ko "S1 first=${first:0:60} second=${second:0:120}"
printf '%s\n' "            추가 utterance 2026-11-08 «머지 보류» (물음: #387 머지할까)" >> "$T/lease_s.md"
run "$SUBJ" "$T/lease_s.md" "$D" stop "$ANS" >/dev/null
third="$(run "$SUBJ" "$T/lease_s.md" "$D" prompt "$P")"
printf '%s' "$third" | grep -q 'L4: ' && ! printf '%s' "$third" | grep -q 'L3: ' \
  && ok "S2 new lease line for the same #N fires, old line not repeated" || ko "S2 third=${third:0:200}"
other="$(run "$SUBJ" "$T/lease_s.md" "$D" stop '{"session_id":"s9","last_assistant_message":"qasp-dev #387 은 CI 초록, 머지는 아침에 묻는다."}' >/dev/null; run "$SUBJ" "$T/lease_s.md" "$D" prompt '{"session_id":"s9"}')"
printf '%s' "$other" | grep -q 'L3: ' && ok "S3 another session id → not suppressed" || ko "S3 other=${other:0:120}"
D="$T/s4"; mkdir -p "$D"; sid1="$(printf '%s' s1 | python3 -c 'import hashlib,sys;print(hashlib.sha256(sys.stdin.read().encode()).hexdigest()[:32])')"
mkdir -p "$D/$sid1.c0.seen"
run "$SUBJ" "$T/lease_yes.md" "$D" stop "$ANS" >/dev/null; a="$(run "$SUBJ" "$T/lease_yes.md" "$D" prompt "$P" 2>&1)"
run "$SUBJ" "$T/lease_yes.md" "$D" stop "$ANS" >/dev/null; b="$(run "$SUBJ" "$T/lease_yes.md" "$D" prompt "$P" 2>&1)"
printf '%s' "$a" | grep -q '#387' && printf '%s' "$b" | grep -q '#387' && ok "S4 seen file unreadable → fails open (shows both times, no stderr)" || ko "S4 a=${a:0:80} b=${b:0:80}"
{ echo "# lease"; for i in 1 2 3 4 5 6 7 8 9 10; do echo "            추가 utterance 2026-11-0$((i%9)) «머지해» 줄$i (물음: #387 머지할까)"; done; } > "$T/lease_cap.md"
D="$T/s5"; run "$SUBJ" "$T/lease_cap.md" "$D" stop "$ANS" >/dev/null; c1="$(run "$SUBJ" "$T/lease_cap.md" "$D" prompt "$P")"
run "$SUBJ" "$T/lease_cap.md" "$D" stop "$ANS" >/dev/null; c2="$(run "$SUBJ" "$T/lease_cap.md" "$D" prompt "$P")"
printf '%s' "$c1" | grep -q '그 밖 2줄' && printf '%s' "$c2" | grep -q 'L10: ' && printf '%s' "$c2" | grep -q 'L11: ' && ! printf '%s' "$c2" | grep -q 'L2: ' \
  && ok "S5 lines past the cap are not marked seen; they show on the next claim" || ko "S5 c1=${c1:0:80} c2=${c2:0:200}"

echo "S6 compaction resets · S7 stop-stop-prompt ordering"
printf '%s\n' '{"type":"user","message":{"content":"x"}}' > "$T/trc.jsonl"
ANS_C="{\"session_id\":\"s1\",\"transcript_path\":\"$T/trc.jsonl\",\"last_assistant_message\":\"qasp-dev #387 은 CI 초록, 머지는 아침에 묻는다.\"}"
crun() { run "$1" "$T/lease_yes.md" "$2" stop "$ANS_C" >/dev/null; run "$1" "$T/lease_yes.md" "$2" prompt "$P"; }
D="$T/s6"; c1="$(crun "$SUBJ" "$D")"; c2="$(crun "$SUBJ" "$D")"
printf '%s\n' '{"type":"system","subtype":"compact_boundary","content":"Conversation compacted"}' >> "$T/trc.jsonl"
c3="$(crun "$SUBJ" "$D")"; c4="$(crun "$SUBJ" "$D")"
[ -n "$c1" ] && [ -z "$c2" ] && printf '%s' "$c3" | grep -q 'L3: ' && [ -z "$c4" ] \
  && ok "S6 shown · silent · compaction → shown again · silent" || ko "S6 c1=${#c1} c2=${#c2} c3=${#c3} c4=${#c4}"
D="$T/s7"; arun "$SUBJ" "$T/lease_yes.md" "$T/archive.md" "$D" stop "$ANS" >/dev/null
arun "$SUBJ" "$T/lease_yes.md" "$T/archive.md" "$D" stop "$ANS_A" >/dev/null
b="$(arun "$SUBJ" "$T/lease_yes.md" "$T/archive.md" "$D" prompt "$P")"
arun "$SUBJ" "$T/lease_yes.md" "$T/archive.md" "$D" stop "$ANS" >/dev/null
a="$(arun "$SUBJ" "$T/lease_yes.md" "$T/archive.md" "$D" prompt "$P")"
printf '%s' "$b" | grep -q '#1101' && printf '%s' "$a" | grep -q '#387' && [ -z "$(ls "$D" | grep -v '\.seen$')" ] \
  && ok "S7 overwritten note's lines stay unseen; no stray key/tmp files" || ko "S7 b=${b:0:60} a=${a:0:60} files=$(ls "$D")"

echo "R6 revert probe (compaction count disabled)"
M6="$T/mutant6.sh"; sed 's/^                        ncomp += 1$/                        pass/' "$SUBJ" > "$M6"
if cmp -s "$SUBJ" "$M6"; then ko "R6 mutation did not apply (HARNESS-ERROR)"; else
  printf '%s\n' '{"type":"user","message":{"content":"x"}}' > "$T/trc.jsonl"
  D="$T/r6"; crun "$M6" "$D" >/dev/null
  printf '%s\n' '{"type":"system","subtype":"compact_boundary","content":"Conversation compacted"}' >> "$T/trc.jsonl"
  out="$(crun "$M6" "$D")"
  [ -z "$out" ] && ok "mutant silent after compaction → S6 would be red" || ko "R6 mutant still resets"
fi

echo "R5 revert probe (seen filter disabled)"
M5="$T/mutant5.sh"; sed 's/^    SEEN_ON = True$/    SEEN_ON = False/' "$SUBJ" > "$M5"
if cmp -s "$SUBJ" "$M5"; then ko "R5 mutation did not apply (HARNESS-ERROR)"; else
  D="$T/r5"; run "$M5" "$T/lease_yes.md" "$D" stop "$ANS" >/dev/null; run "$M5" "$T/lease_yes.md" "$D" prompt "$P" >/dev/null
  run "$M5" "$T/lease_yes.md" "$D" stop "$ANS" >/dev/null; out="$(run "$M5" "$T/lease_yes.md" "$D" prompt "$P")"
  [ -n "$out" ] && ok "mutant repeats the note → S1 would be red" || ko "R5 mutant still silent (lane does not see the filter)"
fi

echo "state_claim_recheck lanes: $pass passed · $fail failed"
[ "$fail" -eq 0 ]

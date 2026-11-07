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

echo "state_claim_recheck lanes: $pass passed · $fail failed"
[ "$fail" -eq 0 ]

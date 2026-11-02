#!/usr/bin/env bash
# Lanes for scripts/utterance_checklist_hook.sh (UserPromptSubmit: capture · cadence nudge · language line).
# Every lane runs the real hook against a temp CLAUDE_PROJECT_DIR — nothing touches the real hub.
# Known pairs: Korean ↔ English prompt (language line present ↔ absent) · content ↔ ack (row ↔ counted only) ·
# cadence row N ↔ N+1 (nudge ↔ none) · good ↔ broken input (output ↔ silent, both rc 0).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
HOOK="$HERE/utterance_checklist_hook.sh"
pass=0; fail=0
ok() { pass=$((pass+1)); echo "  PASS $1"; }
no() { fail=$((fail+1)); echo "  FAIL $1 — $2"; }
[ -f "$HOOK" ] || { echo "HARNESS-ERROR: hook missing"; exit 10; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
SID="0123abcd-0000-4000-8000-000000000001"
run() {   # $1 prompt  [$2 sid]  → stdout; rc in $RC
  local p="$1" s="${2:-$SID}"
  OUT=$(python3 -c 'import json,sys;print(json.dumps({"prompt":sys.argv[1],"session_id":sys.argv[2],"transcript_path":"/x/t.jsonl","hook_event_name":"UserPromptSubmit"}))' "$p" "$s" | CLAUDE_PROJECT_DIR="$T" FH_CHECKLIST_CADENCE="${CAD:-15}" bash "$HOOK"); RC=$?
}
D="$T/tracks/_meta/utterances"

# U1 language line: Korean → present, English → absent
run "세션바를 조금 더 위로 올려 줘"
[ $RC = 0 ] && printf '%s' "$OUT" | grep -q '이번 메시지를 한글로' && ok "U1a Korean prompt → language line" || no U1a "rc=$RC out=$OUT"
run "please move the session bar up a little"
[ $RC = 0 ] && ! printf '%s' "$OUT" | grep -q '한글로' && ok "U1b English prompt → no language line" || no U1b "rc=$RC out=$OUT"

# U2 content is written down; a short ack is counted, not listed
rows_before=$(wc -l < "$D/$SID.jsonl" 2>/dev/null | tr -d " " || echo 0)
run "ㅇㅇ"
rows_after=$(wc -l < "$D/$SID.jsonl" 2>/dev/null | tr -d " " || echo 0)
acks=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["acks"])' "$D/$SID.state.json" 2>/dev/null)
[ "$rows_before" = "$rows_after" ] && [ "$acks" = 1 ] && ok "U2a ack → counted (acks=1), no row" || no U2a "rows ${rows_before}→${rows_after} acks=${acks}"
[ "$rows_before" = 2 ] && python3 -c 'import json,sys;r=[json.loads(l) for l in open(sys.argv[1])];assert r[0]["text"].startswith("세션바") and r[0]["n"]==1' "$D/$SID.jsonl" && ok "U2b content prompts → rows with text and n" || no U2b "rows=$rows_before"
run "왜 이게 떠?"                                  # short but a question → a row
[ "$(wc -l < "$D/$SID.jsonl" | tr -d " ")" = 3 ] && ok "U2c a short question is written down" || no U2c "rows=$(wc -l < "$D/$SID.jsonl" | tr -d " ")"

# U3 cadence nudge: with cadence 3, rows 3 and 6 nudge; rows 4 and 5 do not
S2="0123abcd-0000-4000-8000-000000000002"
CAD=3
n=0; got=""
for p in "첫 번째 요청을 받아 적어 둔다" "두 번째 요청을 받아 적어 둔다" "세 번째 요청을 받아 적어 둔다" "네 번째 요청을 받아 적어 둔다" "다섯 번째 요청을 받아 적어 둔다" "여섯 번째 요청을 받아 적어 둔다"; do   # content, not an ack
  n=$((n+1)); run "$p" "$S2"
  printf '%s' "$OUT" | grep -q '체크리스트 점검 시점' && got="$got$n,"
done
CAD=15
[ "$got" = "3,6," ] && ok "U3 cadence 3 → nudges at rows 3 and 6 only" || no U3 "nudged at: $got"
CAD=3; run "세 번째 다음의 요청 하나를 더 적어 둔다" "0123abcd-0000-4000-8000-000000000003"; run "두 번째 요청을 하나 더 받아 적는다" "0123abcd-0000-4000-8000-000000000003"; run "세 번째 요청을 하나 더 받아 적는다" "0123abcd-0000-4000-8000-000000000003"; CAD=15
printf '%s' "$OUT" | grep -q "session_checklist.py extract --transcript /x/t.jsonl --out tracks/_meta/session_checklist_" && ok "U3b the nudge names the extract command with this transcript" || no U3b "out=$OUT"

# U4 broken input → rc 0, silent; injected notices are not the operator
for bad in "" "not json" '{"prompt":"안녕하세요 반갑습니다","session_id":"../../etc"}' '{"prompt":"","session_id":"0123abcd-0000"}'; do
  OUT=$(printf '%s' "$bad" | CLAUDE_PROJECT_DIR="$T" bash "$HOOK"); RC=$?
  [ $RC = 0 ] && [ -z "$OUT" ] && ok "U4 bad input silent rc0: ${bad:0:24}" || no U4 "rc=$RC out=$OUT input=$bad"
done
ls "$T/etc" >/dev/null 2>&1 && no U4b "path escape created a dir" || ok "U4b a session id with ../ writes nothing outside"
before=$(wc -l < "$D/$SID.jsonl" | tr -d " "); run "<task-notification>배경 작업이 끝났다 길게 적은 알림</task-notification>"
[ "$(wc -l < "$D/$SID.jsonl" | tr -d " ")" = "$before" ] && ok "U4c an injected notice is not written down" || no U4c "row added"
# U4d a subagent hand-back relayed into the prompt is not the operator (first live use: 2 of 15 rows were hand-backs)
before=$(wc -l < "$D/$SID.jsonl" | tr -d " "); run '<agent-message from="a0000000000000000"> [Subagent hand-back] 체크리스트 259행을 전부 채웠다</agent-message>'
[ "$(wc -l < "$D/$SID.jsonl" | tr -d " ")" = "$before" ] && ok "U4d a subagent hand-back is not written down" || no U4d "row added"

# U5 output is valid JSON with the UserPromptSubmit shape whenever there is output
run "한글로 된 내용 있는 요청입니다"
printf '%s' "$OUT" | python3 -c 'import json,sys;o=json.load(sys.stdin);h=o["hookSpecificOutput"];assert h["hookEventName"]=="UserPromptSubmit" and h["additionalContext"]' && ok "U5 output shape" || no U5 "out=$OUT"

# U6 the real hub is untouched (control: the temp hub got the files)
[ -f "$D/$SID.jsonl" ] && [ ! -e "$HERE/../tracks/_meta/utterances/$SID.jsonl" ] && ok "U6 writes only under CLAUDE_PROJECT_DIR" || no U6 "real hub touched or temp missing"

# U7 the close chain asks for the result sheet (①-g) and reads session_checklist.py's rc the way that tool defines it
SCC="$HERE/session_close_check.sh"; SCPY="$HERE/session_checklist.py"
if grep -q '①-g' "$SCC" && grep -q 'python3 "$_SC_PY" check --file "$_f"' "$SCC"; then ok "U7a ①-g calls session_checklist.py check"; else no U7a "wiring missing"; fi
grep -q 'session_checklist_\*_"${_UI_SID:0:8}".md' "$SCC" && ok "U7c ①-g selects this session's sheet by id (not any sheet of today)" || no U7c "selection by today only"
grep -q 'restates it on each mostly-Hangul message' "$HERE/../CLAUDE.md" && grep -q 'every 15 written-down requests' "$HERE/../CLAUDE.md" && ok "U7d CLAUDE.md describes what the hook really does" || no U7d "wording drift" 
cat > "$T/ok.md" <<'MD'
| # | 발화 | 상태 | 증거 | 사유 | 제안 |
|---|---|---|---|---|---|
| 1 | 세션바를 올려 줘 | ✅DONE | FoD #70 | | |
MD
cat > "$T/empty.md" <<'MD'
| # | 발화 | 상태 | 증거 | 사유 | 제안 |
|---|---|---|---|---|---|
| 1 | 세션바를 올려 줘 | | | | |
MD
python3 "$SCPY" check --file "$T/ok.md" >/dev/null 2>&1; r_ok=$?
python3 "$SCPY" check --file "$T/empty.md" >/dev/null 2>&1; r_empty=$?
[ "$r_ok" = 0 ] && [ "$r_empty" = 1 ] && ok "U7b check rc: filled row 0 · empty status 1 (the values ①-g branches on)" || no U7b "rc ok=$r_ok empty=$r_empty"

# ── codex R1 (2026-10-18) cases ──
mk() { python3 -c 'import json,sys;print(json.dumps({"prompt":sys.argv[1],"session_id":sys.argv[2],"transcript_path":sys.argv[3] if len(sys.argv)>3 else "/x/t.jsonl"}))' "$@"; }
# U8 A1 symlink: a symlinked utterances dir (or file) is refused — nothing lands at the link target
T2="$(mktemp -d)"; mkdir -p "$T2/tracks/_meta" "$T2/outside"; ln -s "$T2/outside" "$T2/tracks/_meta/utterances"
mk "심볼릭 링크 너머로 쓰면 안 되는 요청이다" "0123abcd-0000-4000-8000-0000000000a1" | CLAUDE_PROJECT_DIR="$T2" bash "$HOOK" >/dev/null; RC=$?
[ $RC = 0 ] && [ -z "$(ls -A "$T2/outside")" ] && ok "U8a symlinked dir refused, nothing written at the target" || no U8a "rc=$RC files=$(ls "$T2/outside")"
T3="$(mktemp -d)"; mkdir -p "$T3/tracks/_meta/utterances" && : > "$T3/public.md"; ln -s "$T3/public.md" "$T3/tracks/_meta/utterances/0123abcd-0000-4000-8000-0000000000a2.jsonl"
mk "파일 심볼릭 링크로 공개 파일에 쓰면 안 된다" "0123abcd-0000-4000-8000-0000000000a2" | CLAUDE_PROJECT_DIR="$T3" bash "$HOOK" >/dev/null
[ ! -s "$T3/public.md" ] && ok "U8b symlinked jsonl refused (public file untouched)" || no U8b "written: $(cat "$T3/public.md")"
# control: the same prompt with no symlink IS written (the refusal is the symlink's doing)
mk "파일 심볼릭 링크로 공개 파일에 쓰면 안 된다" "0123abcd-0000-4000-8000-0000000000a3" | CLAUDE_PROJECT_DIR="$T3" bash "$HOOK" >/dev/null
[ -s "$T3/tracks/_meta/utterances/0123abcd-0000-4000-8000-0000000000a3.jsonl" ] && ok "U8c control: a regular path is written" || no U8c "not written"
# U9 A2 a FIFO at the record path does not stall the prompt
mkfifo "$T3/tracks/_meta/utterances/0123abcd-0000-4000-8000-0000000000a4.jsonl"
t0=$(python3 -c 'import time;print(time.time())')
# a hung hook must fail this lane, not hang the suite: run it under a 5 s limit (python — macOS has no timeout(1))
RC=$(python3 - "$HOOK" "$T3" <<'PY'
import json, subprocess, sys
inp = json.dumps({"prompt": "파이프 파일이 있어도 멈추면 안 되는 요청", "session_id": "0123abcd-0000-4000-8000-0000000000a4", "transcript_path": "/x/t.jsonl"})
import os, signal
p = subprocess.Popen(["bash", sys.argv[1]], stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                     env={"CLAUDE_PROJECT_DIR": sys.argv[2], "PATH": "/usr/bin:/bin", "HOME": "/tmp"}, start_new_session=True)
try:
    p.communicate(inp.encode(), timeout=5); print(p.returncode)
except subprocess.TimeoutExpired:
    os.killpg(p.pid, signal.SIGKILL); p.wait(); print("hung")   # the whole group: a grandchild blocked on the FIFO must not outlive the lane
PY
)
el=$(python3 -c "import time;print(round(time.time()-$t0,2))")
python3 -c "import sys;sys.exit(0 if $el < 2.0 else 1)" && [ $RC = 0 ] && ok "U9 FIFO: rc 0 in ${el}s (no block)" || no U9 "rc=$RC ${el}s"
# U10 B7 a 3 MB prompt is handled (stdin, not env)
# the input is generated inside python (a multi-MB argv would itself hit E2BIG in the test — measured)
OUT=$(python3 -c 'import json;print(json.dumps({"prompt":"가"*1500000,"session_id":"0123abcd-0000-4000-8000-0000000000a5","transcript_path":"/x/t.jsonl"},ensure_ascii=False))' | CLAUDE_PROJECT_DIR="$T" bash "$HOOK"); RC=$?
printf '%s' "$OUT" | grep -q '한글로' && [ $RC = 0 ] && ok "U10 a 1.5M-char prompt still gets the language line (no E2BIG)" || no U10 "rc=$RC"
python3 -c 'import json,sys;r=[json.loads(l) for l in open(sys.argv[1])][-1];assert r.get("truncated") is True and r["chars"]==1500000 and len(r["text"])==20000' "$D/0123abcd-0000-4000-8000-0000000000a5.jsonl" && ok "U10b a long utterance is marked truncated with its real length (B6)" || no U10b "not marked"
# U11 B5 short real requests and <tag> requests are written down; acks are not
for p in "버그 고쳐줘" "<div>이 컴포넌트를 수정해 주세요</div>"; do
  b=$(cat "$D/$SID.jsonl" 2>/dev/null | wc -l | tr -d ' '); run "$p"; a=$(wc -l < "$D/$SID.jsonl" | tr -d ' ')
  [ "$a" = $((b+1)) ] && ok "U11 written down: $p" || no U11 "not written: $p"
done
for p in "ㅇㅇ" "ㄱㄱ" "ㅇㅋ" "확인완료" "ok"; do
  b=$(wc -l < "$D/$SID.jsonl" | tr -d ' '); run "$p"; a=$(wc -l < "$D/$SID.jsonl" | tr -d ' ')
  [ "$a" = "$b" ] && ok "U11b ack not listed: $p" || no U11b "listed: $p"
done
# U12 B9 language: Japanese is not Korean; Korean prose with pasted English code is Korean
run "このバグを直してください。「한글」という単語を含みます"
! printf '%s' "$OUT" | grep -q '한글로' && ok "U12a Japanese prompt → no Korean line" || no U12a "fired"
run $'이 함수 좀 고쳐 줘\n```js\nfunction computeTheThingWithAVeryLongEnglishName(argumentOne, argumentTwo) { return argumentOne + argumentTwo }\n```'
printf '%s' "$OUT" | grep -q '한글로' && ok "U12b Korean prose + English code → Korean line" || no U12b "missed"
# U13 B12 the nudge names only statuses the checker accepts; B10 the path is shell-quoted
S4="0123abcd-0000-4000-8000-0000000000a6"; CAD=3
for i in 1 2 3; do OUT=$(mk "점검 박자 확인용 요청 번호 $i 입니다" "$S4" "/tmp/with space/t.jsonl" | CLAUDE_PROJECT_DIR="$T" FH_CHECKLIST_CADENCE=3 bash "$HOOK"); done; CAD=15
printf '%s' "$OUT" | grep -q '🔎UNVERIFIED' && ! printf '%s' "$OUT" | grep -q '❓' && ok "U13a nudge lists 🔎UNVERIFIED (accepted by session_checklist.py), not ❓" || no U13a "out=$OUT"
printf '%s' "$OUT" | grep -qF -- "--transcript '/tmp/with space/t.jsonl'" && ok "U13b transcript path is shell-quoted" || no U13b "out=$OUT"
# U14 B8 HOME and CLAUDE_PROJECT_DIR unset → still rc 0
OUT=$(mk "홈 변수가 없어도 죽으면 안 된다" "0123abcd-0000-4000-8000-0000000000a7" | env -i PATH=/usr/bin:/bin bash "$HOOK"); RC=$?
[ $RC = 0 ] && ok "U14 no HOME, no CLAUDE_PROJECT_DIR → rc 0" || no U14 "rc=$RC"
# U15 B3 ten prompts at once: ten rows, numbered 1..10 with no duplicate, state says 10
S5="0123abcd-0000-4000-8000-0000000000a8"
for i in $(seq 1 10); do (mk "동시에 들어온 요청 번호 $i 입니다 길게" "$S5" | CLAUDE_PROJECT_DIR="$T" bash "$HOOK" >/dev/null) & done; wait
python3 -c 'import json,sys;r=[json.loads(l)["n"] for l in open(sys.argv[1])];s=json.load(open(sys.argv[2]));assert sorted(r)==list(range(1,11)) and s["rows"]==10,(sorted(r),s)' "$D/$S5.jsonl" "$D/$S5.state.json" && ok "U15 10 concurrent prompts → rows 1..10, state 10 (locked)" || no U15 "race"
# U15b the deterministic half of U15 (2026-11-02): U15 loses a row only ~1% of runs, so reverting the fix leaves it green.
# Another holder keeps the session lock for 2.0 s; the prompt must still be written down once the lock frees.
# With the old 0.3 s wait this row is skipped in silence unless the hook starts >1.7 s late (2.0 s, not 1.0 s:
# at 1.0 s a 0.7 s scheduling delay was enough to turn the reverted code green — codex review 2026-11-02).
S5b="0123abcd-0000-4000-8000-0000000000a9"
python3 -c 'import fcntl,os,sys,time;fd=os.open(sys.argv[1],os.O_RDWR|os.O_CREAT,0o600);fcntl.flock(fd,fcntl.LOCK_EX);open(sys.argv[2],"w").close();time.sleep(2.0)' "$D/$S5b.lock" "$T/u15b.ready" &
HOLD=$!; for _ in $(seq 1 100); do [ -f "$T/u15b.ready" ] && break; sleep 0.02; done
mk "다른 쪽이 잠금을 쥐고 있는 동안 들어온 요청" "$S5b" | CLAUDE_PROJECT_DIR="$T" bash "$HOOK" >/dev/null; wait "$HOLD"
[ -f "$T/u15b.ready" ] && [ "$(wc -l < "$D/$S5b.jsonl" 2>/dev/null | tr -d ' ')" = 1 ] && ok "U15b prompt arriving while the lock is held 2.0 s is still written (no silent skip)" || no U15b "row skipped while lock held (ready=$([ -f "$T/u15b.ready" ] && echo y || echo n))"
rm -rf "$T2" "$T3"

# ── codex R2 (final round) cases ──
T4="$(mktemp -d)"; mkdir -p "$T4/tracks/_meta/utterances"; : > "$T4/outside.md"
ln "$T4/outside.md" "$T4/tracks/_meta/utterances/0123abcd-0000-4000-8000-0000000000b1.jsonl"
mk "하드 링크로 바깥 파일에 쓰면 안 되는 요청" "0123abcd-0000-4000-8000-0000000000b1" | CLAUDE_PROJECT_DIR="$T4" bash "$HOOK" >/dev/null
[ ! -s "$T4/outside.md" ] && ok "U16 hard-linked record refused (outside file untouched)" || no U16 "written through hard link"
t0=$(python3 -c 'import time;print(time.time())')
python3 -c 'import json;print(json.dumps({"prompt":"ㅋ"*20000+"x","session_id":"0123abcd-0000-4000-8000-0000000000b2"}))' | CLAUDE_PROJECT_DIR="$T4" bash "$HOOK" >/dev/null
el=$(python3 -c "import time;print(round(time.time()-$t0,2))")
python3 -c "import sys;sys.exit(0 if $el < 1.0 else 1)" && ok "U17 a 20000-char near-ack is handled in ${el}s (no regex blow-up)" || no U17 "${el}s"
S6="0123abcd-0000-4000-8000-0000000000b3"; mkdir -p "$T4/tracks/_meta/utterances/$S6.state.json"    # state can never be written
for i in 1 2 3; do mk "상태 저장이 안 돼도 번호가 겹치면 안 된다 $i" "$S6" | CLAUDE_PROJECT_DIR="$T4" bash "$HOOK" >/dev/null; done
python3 -c 'import json,sys;r=[json.loads(l)["n"] for l in open(sys.argv[1])];assert r==[1,2,3],r' "$T4/tracks/_meta/utterances/$S6.jsonl" && ok "U18 numbering comes from the record when state cannot be saved (1,2,3)" || no U18 "repeated numbers"
rm -rf "$T4"

# U19 the body runs on its own (the .sh is a thin wrapper): FH_HUB set → row + language line, FH_HUB unset → silent, rc 0 both
PYB="$HERE/utterance_checklist_hook.py"
S19="0123abcd-0000-4000-8000-000000000019"
J19=$(python3 -c 'import json,sys;print(json.dumps({"prompt":"본체를 직접 실행해서 받아 적는지 본다","session_id":sys.argv[1]}))' "$S19")
O19=$(printf '%s' "$J19" | FH_HUB="$T" python3 "$PYB"); R19=$?
[ $R19 = 0 ] && printf '%s' "$O19" | grep -q '한글로' && [ "$(wc -l < "$D/$S19.jsonl" 2>/dev/null | tr -d ' ')" = 1 ] && ok "U19a body run directly → row + language line" || no U19a "rc=$R19 out=$O19"
O19b=$(printf '%s' "$J19" | env -u FH_HUB python3 "$PYB"); R19b=$?
[ $R19b = 0 ] && [ -z "$O19b" ] && [ "$(wc -l < "$D/$S19.jsonl" | tr -d ' ')" = 1 ] && ok "U19b body without FH_HUB → silent, nothing written" || no U19b "rc=$R19b out=$O19b"

echo "lanes: pass=$pass fail=$fail"
[ $fail = 0 ]

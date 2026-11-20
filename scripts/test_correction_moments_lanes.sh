#!/usr/bin/env bash
# Lanes for scripts/correction_moments.py — fixture ledgers only (never the real ones, which can hold
# in-house context). Known pair: the same correction phrased differently on two days must pair;
# an approval must not be a hit. Plus the exclusions, each of which must be COUNTED, not dropped.
set -u
FH="$(cd "$(dirname "$0")/.." && pwd)"
S="$FH/scripts/correction_moments.py"
T=$(mktemp -d "${TMPDIR:-/tmp}/cmt.XXXXXX")
pass=0; fail=0
check() { # name, expected rc, pattern, [dir]
  out=$(python3 "$S" "${4:-$T/led}" 2>&1); rc=$?
  if [ "$rc" = "$2" ] && printf '%s' "$out" | grep -q -E "$3"; then echo "PASS $1"; pass=$((pass + 1))
  else echo "FAIL $1 — rc=$rc"; printf '%s\n' "$out" | head -4 | sed 's/^/     /'; fail=$((fail + 1)); fi
}
mkdir -p "$T/led" "$T/empty"
cat > "$T/led/aaaa1111.jsonl" <<'EOF'
{"ts": "2026-10-01T10:00:00", "n": 1, "text": "ㅇㅇ 머지하자 초록이면"}
{"ts": "2026-10-01T10:05:00", "n": 2, "text": "아니 보고서는 영어 말고 한글 반말로 써줘"}
{"ts": "2026-10-01T10:06:00", "n": 3, "text": "<agent-message from=\"x\"> 아니 이건 서브에이전트 보고다 보고서 한글 반말</agent-message>"}
{"ts": "2026-10-01T10:07:00", "n": 4, "text": "응"}
not json at all
EOF
cat > "$T/led/bbbb2222.jsonl" <<'EOF'
{"ts": "2026-10-04T09:00:00", "n": 1, "text": "또 보고서를 영어로 썼네. 한글 반말로 다시 해줘"}
{"ts": "2026-10-04T09:10:00", "n": 2, "text": "아니 머지 순서가 틀렸어 태그 먼저"}
EOF
listing=$(python3 "$S" "$T/led" --all)   # own variable: check() overwrites $out. --all: L3/L4 must see unpaired hits, or they pass on an empty listing
check L1-cross-day-pair      0 '^## R1 — shared: .*반말'
check L2-counts-exclusions   0 'envelope=1 short\(<6 chars\)=1 long\(>600 chars\)=0 malformed=1'
if printf '%s' "$listing" | grep -q '머지하자 초록이면'; then echo "FAIL L3-approval-not-a-hit"; fail=$((fail + 1)); else echo "PASS L3-approval-not-a-hit"; pass=$((pass + 1)); fi
if printf '%s' "$listing" | grep -q '서브에이전트 보고다'; then echo "FAIL L4-envelope-not-a-hit"; fail=$((fail + 1)); else echo "PASS L4-envelope-not-a-hit"; pass=$((pass + 1)); fi
if printf '%s' "$listing" | grep -q '머지 순서가 틀렸어'; then echo "PASS L3c-listing-alive"; pass=$((pass + 1)); else echo "FAIL L3c-listing-alive (L3/L4 would pass on an empty listing)"; fail=$((fail + 1)); fi
check L5-cue-hits            0 'cue hits=3 '
# L6: the same text re-pasted on another day is dropped as a re-paste, not reported as recurrence
mkdir -p "$T/rep"
printf '%s\n' '{"ts": "2026-10-01T10:00:00", "n": 1, "text": "아니 이 표의 분모가 틀렸어 재현율 다시 계산"}' > "$T/rep/c1.jsonl"
printf '%s\n' '{"ts": "2026-10-03T10:00:00", "n": 1, "text": "아니 이 표의 분모가 틀렸어 재현율 다시 계산"}' > "$T/rep/c2.jsonl"
check L6-repaste-dropped     0 'recurring pairs .*=0 · re-pasted pairs dropped=1' "$T/rep"
check L7-empty-not-zero      2 'NOT MEASURED' "$T/empty"
# L8: scheduled-trigger prompts land in the ledger as if the operator typed them. Two different cron
# prompts, each fired on three days, share words («linked list_sessions») and paired with each other
# across days — 2026-11-20 weekly audit: 24 of 24 «recurring pairs» were cron text. A prompt whose
# first 40 characters repeat >= 3 times is a scheduled prompt: excluded and COUNTED, never a hit.
# The one-off correction on the same days must still be a hit (control: the exclusion is not blanket).
mkdir -p "$T/cron"
for d in 01 02 03; do
  printf '%s\n' "{\"ts\": \"2026-10-${d}T01:17:00\", \"n\": 1, \"text\": \"[야간 자동 재개 점검 — 매시 17분] 왜 멈췄는지 linked list_sessions 로 확인하고 재개\"}"
  printf '%s\n' "{\"ts\": \"2026-10-${d}T03:53:00\", \"n\": 2, \"text\": \"Night check (root, lease) — list_sessions linked: don't merge what the lease does not allow\"}"
done > "$T/cron/c.jsonl"
printf '%s\n' '{"ts": "2026-10-02T12:00:00", "n": 3, "text": "증명을 한게 아니잖아 다시 확인해"}' >> "$T/cron/c.jsonl"
check L8-cron-prompt-excluded 0 'malformed=0 repeated-prompt=6 · cue hits=1 · recurring pairs .*=0 ' "$T/cron"
cron_all=$(python3 "$S" "$T/cron" --all)
if printf '%s' "$cron_all" | grep -q '증명을 한게 아니잖아'; then echo "PASS L8c-one-off-still-a-hit"; pass=$((pass + 1)); else echo "FAIL L8c-one-off-still-a-hit"; fail=$((fail + 1)); fi
# L9: an operator phrase said twice (below the threshold) is not a scheduled prompt
mkdir -p "$T/twice"
printf '%s\n' '{"ts": "2026-10-01T10:00:00", "n": 1, "text": "아니 그 표 분모가 틀렸어 재현율로"}' '{"ts": "2026-10-05T10:00:00", "n": 2, "text": "아니 그 표 분모가 틀렸어 정밀도 말고"}' > "$T/twice/t.jsonl"
check L9-twice-is-not-cron   0 'repeated-prompt=0 · cue hits=2 ' "$T/twice"
# L10: a SHORT correction said three times is the signal this tool exists for — never excluded
mkdir -p "$T/short3"
for d in 01 03 05; do printf '%s\n' "{\"ts\": \"2026-10-${d}T10:00:00\", \"n\": 1, \"text\": \"아니 증명을 한게 아니잖아\"}"; done > "$T/short3/s.jsonl"
check L10-short-repeat-kept  0 'repeated-prompt=0 · cue hits=3 ' "$T/short3"
# L11: three different corrections that share a long opener are not one repeated prompt
mkdir -p "$T/opener"
for w in 분모 분자 표본수; do printf '%s\n' "{\"ts\": \"2026-10-02T10:00:00\", \"n\": 1, \"text\": \"아니 지난번 보고서 둘째 표에서 계산한 숫자들 다시 봐야 해, ${w} 가 틀렸어\"}"; done > "$T/opener/o.jsonl"
check L11-shared-opener-kept 0 'repeated-prompt=0 · cue hits=3 ' "$T/opener"
# L12: the verdict does not depend on --since — one fire before the window still counts toward the repeat,
#      and a time inside the prompt (digits) does not hide the repeat
mkdir -p "$T/win"
for h in 1 2 3; do printf '%s\n' "{\"ts\": \"2026-10-0${h}T0${h}:17:00\", \"n\": 1, \"text\": \"[야간 점검 — 매시 ${h}7분, 10-0${h} 01시] 왜 멈췄는지 확인하고 멈춘 세션은 재개해 줘\"}"; done > "$T/win/w.jsonl"
printf '%s\n' '{"ts": "2026-10-03T12:00:00", "n": 2, "text": "아니 그건 틀렸어 다시 해"}' >> "$T/win/w.jsonl"
win_out=$(python3 "$S" "$T/win" --since 2026-10-02 2>&1)
if printf '%s' "$win_out" | grep -q 'repeated-prompt=2 · cue hits=1 '; then echo "PASS L12-since-and-digits"; pass=$((pass + 1)); else echo "FAIL L12-since-and-digits"; printf '%s\n' "$win_out" | sed -n 2p | sed 's/^/     /'; fail=$((fail + 1)); fi
# L13: a window holding only scheduled prompts is NOT MEASURED (rc 2), with the counts named
mkdir -p "$T/onlycron"
grep -v '그건 틀렸어' "$T/win/w.jsonl" > "$T/onlycron/c.jsonl"
check L13-only-cron-not-zero 2 'NOT MEASURED' "$T/onlycron"
rm -rf "$T"
echo "correction_moments lanes: $pass pass · $fail fail"
[ "$fail" -eq 0 ]

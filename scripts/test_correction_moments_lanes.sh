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
rm -rf "$T"
echo "correction_moments lanes: $pass pass · $fail fail"
[ "$fail" -eq 0 ]

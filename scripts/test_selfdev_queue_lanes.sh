#!/usr/bin/env bash
# test_selfdev_queue_lanes.sh — lanes for scripts/selfdev_queue.py on a fixture «live» checkout.
#   Q1 a row closed in a NEWER checklist does not resurface from an older one (and an open row does)
#   Q2 an operator-owned open row is tagged owner=operator
#   Q3 all five sources present → rc 0, every source has a count
#   Q4 absorption queue missing → that source is UNMEASURED and rc 3 (never «— 0»)
#   Q5 digest without its candidates section → UNMEASURED
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
Q="$HERE/selfdev_queue.py"
[ -f "$Q" ] || { echo "HARNESS-ERROR: $Q missing"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); echo "  ✅ $1"; }
bad() { fail=$((fail+1)); echo "  ❌ $1"; }

L="$W/live"; M="$L/tracks/_meta"; mkdir -p "$M" "$L/scripts"
HDR='| # | 시각 | 발화(요지) | 상태 | 증거 | 사유 / 남은 것 | 제안(이번 세션 vs 이월) |
|---|---|---|---|---|---|---|'
printf '%s\n| 1 | 11-01 | 레인 하나 더 달자 | 🟡PARTIAL | x | 레인 미작성 | 이월 |\n| 2 | 11-01 | 문서 고치자 | 🟡PARTIAL | x | 반쯤 | 이월 |\n| 3 | 11-01 | 플러그인 캐시 갱신 | 🟡PARTIAL | x | 운영자 몫 | 아침 |\n' "$HDR" > "$M/session_checklist_2026-11-01_a.md"
touch -t 202611010000 "$M/session_checklist_2026-11-01_a.md"
printf '%s\n| 1 | 11-02 | 레인 하나 더 달자 | ✅DONE | #1 | — | — |\n' "$HDR" > "$M/session_checklist_2026-11-02_b.md"
printf 'id\tadded\tsource\titem\tassets\tstatus\tclosed\tevidence\nAQ-1\t2026-11-01\tdigest:x\t열린 후보\t\topen\t\t\nAQ-2\t2026-11-01\tdigest:x\t닫힌 후보\t\tlanded\t\t#9\n' > "$M/absorption_queue.tsv"
printf '# card\n## 🌅\n1. [planned] 후보 하나\n2. [held] 보류\n\n---\n\n# old\n1. [planned] 옛 블록\n' > "$M/reference_next_session_starter.md"
printf '# d\n## FH Immediate Application Candidates\n\n- 후보 A\n- 후보 B\n\n## Warning Signals\n- w\n' > "$M/frontier_digest_2026_11_04.md"
printf 'import sys\nprint("# correction moments — stub")\nprint("cue hits=2")\n' > "$L/scripts/correction_moments.py"

out="$(python3 "$Q" --live "$L" --date 2026-11-04 2>&1)"; rc=$?
if printf '%s\n' "$out" | grep -q '문서 고치자' && ! printf '%s\n' "$out" | grep -q '레인 하나 더 달자'; then ok "Q1 newer DONE suppresses older open; other open row kept"; else bad "Q1"; printf '%s\n' "$out" | sed 's/^/     /'; fi
if printf '%s\n' "$out" | grep '플러그인 캐시' | grep -q 'owner=operator'; then ok "Q2 operator-owned row tagged"; else bad "Q2"; fi
if [ "$rc" -eq 0 ] && [ "$(printf '%s\n' "$out" | grep -cE '^## .* — [0-9]+$')" -eq 5 ] \
   && printf '%s\n' "$out" | grep -q '^## absorption queue (open) — 1$' \
   && printf '%s\n' "$out" | grep -q '^## session card \[planned\] — 1$' \
   && printf '%s\n' "$out" | grep -q '^## frontier digest candidates (2026-11-04) — 2$'; then ok "Q3 all sources counted, rc 0"; else bad "Q3 rc=$rc"; printf '%s\n' "$out" | grep '^## ' | sed 's/^/     /'; fi

mv "$M/absorption_queue.tsv" "$W/aq.bak"
out="$(python3 "$Q" --live "$L" --date 2026-11-04 2>&1)"; rc=$?
if [ "$rc" -eq 3 ] && printf '%s\n' "$out" | grep -q '^## absorption queue (open) — UNMEASURED'; then ok "Q4 missing source → UNMEASURED, rc 3"; else bad "Q4 rc=$rc"; fi
mv "$W/aq.bak" "$M/absorption_queue.tsv"

printf '# d\n## Something else\n- x\n' > "$M/frontier_digest_2026_11_04.md"
out="$(python3 "$Q" --live "$L" --date 2026-11-04 2>&1)"; rc=$?
if [ "$rc" -eq 3 ] && printf '%s\n' "$out" | grep -q '^## frontier digest candidates (2026-11-04) — UNMEASURED'; then ok "Q5 digest without section → UNMEASURED"; else bad "Q5 rc=$rc"; fi

[ $((pass+fail)) -eq 5 ] || { echo "HARNESS-ERROR: counted $((pass+fail)) lanes, expected 5"; exit 2; }
echo "selfdev_queue lanes: $pass passed · $fail failed"
[ "$fail" -eq 0 ]

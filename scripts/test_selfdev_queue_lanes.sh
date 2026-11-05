#!/usr/bin/env bash
# test_selfdev_queue_lanes.sh — lanes for scripts/selfdev_queue.py on a fixture «live» checkout.
#   Q1 a row closed in a NEWER checklist does not resurface from an older one (and an open row does)
#   Q2 an operator-owned open row is tagged owner=operator
#   Q3 all five sources present → rc 0, every source has a count
#   Q4 absorption queue missing → that source is UNMEASURED and rc 3 (never «— 0»)
#   Q5 digest without its candidates section → UNMEASURED
#   Q6 an open row only in an OLDER checklist is seed=recheck and left out of --emit-human; the newest checklist's open row stays seed=human
#   Q7 today's digest missing, yesterday's present → counted from yesterday, the source says «fallback»
#   Q8 neither today's nor yesterday's digest → UNMEASURED
#   Q10 four checklists of the latest day are all read and all seed=human (the --checklists cut does not drop one)
#   Q11 a checklist file with no date in its name is never newest: its rows are seed=recheck
#   Q9 a later edit (newer mtime) to the OLDER checklist does not make it newest: its rows stay recheck and the newer DONE still wins
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
printf '%s\n| 1 | 11-02 | 레인 하나 더 달자 | ✅DONE | #1 | — | — |\n| 2 | 11-02 | 새 요청 하나 | 🟡PARTIAL | x | 남음 | 이월 |\n' "$HDR" > "$M/session_checklist_2026-11-02_b.md"
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

if printf '%s\n' "$out" | grep '문서 고치자' | grep -q 'seed=recheck' && printf '%s\n' "$out" | grep '새 요청 하나' | grep -q 'seed=human' \
   && eh="$(python3 "$Q" --live "$L" --emit-human 2>&1)" && printf '%s\n' "$eh" | grep -q '새 요청 하나' && ! printf '%s\n' "$eh" | grep -q '문서 고치자'; then
  ok "Q6 older-checklist row → seed=recheck, not in --emit-human; newest row stays human"; else bad "Q6"; printf '%s\n' "$out" | grep -E '문서|새 요청' | sed 's/^/     /'; fi

touch "$M/session_checklist_2026-11-01_a.md"   # newer mtime than the 11-02 file
out="$(python3 "$Q" --live "$L" --date 2026-11-04 2>&1)"
eh="$(python3 "$Q" --live "$L" --emit-human 2>&1)"
if printf '%s\n' "$out" | grep '문서 고치자' | grep -q 'seed=recheck' && ! printf '%s\n' "$out" | grep -q '레인 하나 더 달자' \
   && ! printf '%s\n' "$eh" | grep -qE '문서 고치자|레인 하나 더 달자'; then ok "Q9 edited old checklist stays old (date from name, not mtime)"; else bad "Q9"; printf '%s\n' "$out" | grep -E '문서|레인 하나' | sed 's/^/     /'; fi
touch -t 202611010000 "$M/session_checklist_2026-11-01_a.md"

mv "$M/frontier_digest_2026_11_04.md" "$M/frontier_digest_2026_11_03.md"
out="$(python3 "$Q" --live "$L" --date 2026-11-04 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -q '^## frontier digest candidates (2026-11-04) — 2$' && printf '%s\n' "$out" | grep -q 'frontier_digest_2026_11_03.md — fallback'; then ok "Q7 yesterday's digest used and labelled"; else bad "Q7 rc=$rc"; printf '%s\n' "$out" | grep -i digest | sed 's/^/     /'; fi
mv "$M/frontier_digest_2026_11_03.md" "$W/d.bak"
out="$(python3 "$Q" --live "$L" --date 2026-11-04 2>&1)"; rc=$?
if [ "$rc" -eq 3 ] && printf '%s\n' "$out" | grep -q '^## frontier digest candidates (2026-11-04) — UNMEASURED'; then ok "Q8 no digest for today or yesterday → UNMEASURED"; else bad "Q8 rc=$rc"; fi
mv "$W/d.bak" "$M/frontier_digest_2026_11_04.md"

printf '# d\n## Something else\n- x\n' > "$M/frontier_digest_2026_11_04.md"
out="$(python3 "$Q" --live "$L" --date 2026-11-04 2>&1)"; rc=$?
if [ "$rc" -eq 3 ] && printf '%s\n' "$out" | grep -q '^## frontier digest candidates (2026-11-04) — UNMEASURED'; then ok "Q5 digest without section → UNMEASURED"; else bad "Q5 rc=$rc"; fi

L2="$W/live2"; M2="$L2/tracks/_meta"; mkdir -p "$M2"
for s in a b c d; do printf '%s\n| 1 | 11-05 | 요청 %s | 🟡PARTIAL | x | 남음 | 이월 |\n' "$HDR" "$s" > "$M2/session_checklist_2026-11-05_$s.md"; done
eh="$(python3 "$Q" --live "$L2" --emit-human 2>&1)"
if [ "$(printf '%s\n' "$eh" | grep -c '^요청 ')" -eq 4 ]; then ok "Q10 four same-day checklists all human"; else bad "Q10"; printf '%s\n' "$eh" | sed 's/^/     /'; fi
L3="$W/live3"; M3="$L3/tracks/_meta"; mkdir -p "$M3"
printf '%s\n| 1 | - | 날짜 없는 요청 | 🟡PARTIAL | x | 남음 | 이월 |\n' "$HDR" > "$M3/session_checklist_notes.md"
eh="$(python3 "$Q" --live "$L3" --emit-human 2>&1)"
if ! printf '%s\n' "$eh" | grep -q '날짜 없는 요청'; then ok "Q11 undated checklist never newest"; else bad "Q11"; fi

[ $((pass+fail)) -eq 11 ] || { echo "HARNESS-ERROR: counted $((pass+fail)) lanes, expected 11"; exit 2; }
echo "selfdev_queue lanes: $pass passed · $fail failed"
[ "$fail" -eq 0 ]

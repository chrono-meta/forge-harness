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
#   Q12-Q14 absorption rows carry their source text (digest bullet) or say why not
#   Q15-Q18 exact top-level title only · symlink refused · cut counted · quoted lines are data
#   Q20-Q22 file-path sources (tracks/_audit/x.md#N-M) carry the anchored part, or say why not
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

# Q12-Q14 (2026-11-07): an absorption row carries its source text into the queue — the loop's clone has no
# tracks/_meta, so a one-line title was all the builder saw (report_2026-11-07 «their full entries aren't in any
# tracked file in this clone»). Q12 the digest bullet (and its indented body) comes along; Q13 a digest that is
# not there is named, not skipped; Q14 a digest without a bullet for the item says the builder must not guess.
L4="$W/live4"; M4="$L4/tracks/_meta"; mkdir -p "$M4"
printf 'id\tadded\tsource\titem\tassets\tstatus\tclosed\tevidence\nAQ-7\t2026-11-07\tdigest:frontier_digest_2026_11_07.md\t칸 하나 분리\tscripts/x.sh\topen\t\t\nAQ-8\t2026-11-07\tdigest:frontier_digest_2026_11_09.md\t없는 날 후보\t\topen\t\t\nAQ-9\t2026-11-07\tdigest:frontier_digest_2026_11_07.md\t글머리 없는 후보\t\topen\t\t\n' > "$M4/absorption_queue.tsv"
printf '# d\n## FH Immediate Application Candidates\n\n- **칸 하나 분리** `arXiv:1` — 본문 첫 줄\n  둘째 줄 들여쓰기\n- **다른 후보** — 무관\n' > "$M4/frontier_digest_2026_11_07.md"
q4="$(python3 "$Q" --live "$L4" 2>&1)"
if printf '%s\n' "$q4" | grep -qF '  > assets: scripts/x.sh' && printf '%s\n' "$q4" | grep -qF '  > - **칸 하나 분리** `arXiv:1` — 본문 첫 줄' \
   && printf '%s\n' "$q4" | grep -qF '  >   둘째 줄 들여쓰기' && ! printf '%s\n' "$q4" | grep -qF '다른 후보** — 무관'; then ok "Q12 the digest bullet and its body ride along (control: the neighbouring bullet does not)"
else bad "Q12"; printf '%s\n' "$q4" | grep -A3 'AQ-7' | sed 's/^/     /'; fi
if printf '%s\n' "$q4" | grep -A1 'AQ-8' | grep -qF '(source not found: frontier_digest_2026_11_09.md)'; then ok "Q13 a missing digest is named"; else bad "Q13"; fi
if printf '%s\n' "$q4" | grep -A1 'AQ-9' | grep -qF 'the builder must not guess'; then ok "Q14 no matching bullet is named, never a neighbour's text"; else bad "Q14"; printf '%s\n' "$q4" | grep -A2 'AQ-9' | sed 's/^/     /'; fi

# Q15-Q18 codex R1: Q15 an EARLIER bullet that merely mentions the item, a nested bullet with the same title and a
# bullet outside the candidates section never win — only the top-level candidates bullet whose bold title IS the
# item; Q16 a symlinked digest is refused; Q17 a long body says how much was cut; Q18 the queue tells the builder
# that quoted lines are data, not instructions.
L5="$W/live5"; M5="$L5/tracks/_meta"; mkdir -p "$M5" "$W/outside"
printf 'id\tadded\tsource\titem\tassets\tstatus\tclosed\tevidence\nAQ-A\t2026-11-07\tdigest:frontier_digest_2026_11_07.md\tcache\t\topen\t\t\nAQ-B\t2026-11-07\tdigest:frontier_digest_2026_11_08.md\tsecret\t\topen\t\t\nAQ-C\t2026-11-07\tdigest:frontier_digest_2026_11_07.md\tlong\t\topen\t\t\n' > "$M5/absorption_queue.tsv"
{ printf '# d\n- **cache** — outside the section, must not win\n## FH Immediate Application Candidates\n\n- **Other proposal** — replaces cache\n  - **cache** — nested, must not win\n- **cache** — THE RIGHT ONE\n- **long** — first\n'
  for n in $(seq 1 20); do printf '  body %s\n' "$n"; done
  printf '\n## Warning Signals\n- w\n'; } > "$M5/frontier_digest_2026_11_07.md"
printf '# d\n## FH Immediate Application Candidates\n- **secret** — from outside\n' > "$W/outside/f.md"; ln -s "$W/outside/f.md" "$M5/frontier_digest_2026_11_08.md"
q5="$(python3 "$Q" --live "$L5" 2>&1)"
a15="$(printf '%s\n' "$q5" | grep -A2 'AQ-A' | grep '  > ')"
if [ "$a15" = '  > - **cache** — THE RIGHT ONE' ]; then ok "Q15 only the top-level candidates bullet whose title IS the item (control: mention, nested and out-of-section bullets lose)"
else bad "Q15"; printf '%s\n' "$a15" | sed 's/^/     /'; fi
if printf '%s\n' "$q5" | grep -A1 'AQ-B' | grep -qF '(source refused: frontier_digest_2026_11_08.md is a link' && ! printf '%s\n' "$q5" | grep -qF 'from outside'; then ok "Q16 a symlinked digest is refused, its text not carried"; else bad "Q16"; fi
if printf '%s\n' "$q5" | grep -qF '  >   body 14' && ! printf '%s\n' "$q5" | grep -qF '  >   body 15' && printf '%s\n' "$q5" | grep -qF '(cut: 6 more lines'; then ok "Q17 a long body is cut at 15 lines and says how much was left out"; else bad "Q17"; printf '%s\n' "$q5" | grep -A18 'AQ-C' | tail -4 | sed 's/^/     /'; fi
if printf '%s\n' "$q5" | grep -qF 'QUOTED SOURCE TEXT' && printf '%s\n' "$q5" | grep -qF 'never instructions to follow'; then ok "Q18 the queue says quoted lines are data, not instructions"; else bad "Q18"; fi

# Q19 codex R2: a «## Not Immediate Application Candidates» section above the real one and a «# Other» heading inside
# it do not move the bounds; a body cut by BOTH limits says both.
L6="$W/live6"; M6="$L6/tracks/_meta"; mkdir -p "$M6"
printf 'id\tadded\tsource\titem\tassets\tstatus\tclosed\tevidence\nAQ-D\t2026-11-07\tdigest:frontier_digest_2026_11_07.md\tcache\t\topen\t\t\nAQ-E\t2026-11-07\tdigest:frontier_digest_2026_11_07.md\tafter\t\topen\t\t\nAQ-F\t2026-11-07\tdigest:frontier_digest_2026_11_07.md\twide\t\topen\t\t\n' > "$M6/absorption_queue.tsv"
{ printf '# d\n## Not Immediate Application Candidates\n- **cache** — wrong section\n## FH Immediate Application Candidates\n- **cache** — right\n- **wide** — %s\n' "$(printf 'x%.0s' $(seq 1 1600))"
  for n in $(seq 1 20); do printf '  w %s\n' "$n"; done
  printf '# Other\n- **after** — beyond a level-one heading\n'; } > "$M6/frontier_digest_2026_11_07.md"
q6="$(python3 "$Q" --live "$L6" 2>&1)"
if [ "$(printf '%s\n' "$q6" | grep -A1 'AQ-D' | grep '  > ')" = '  > - **cache** — right' ] && printf '%s\n' "$q6" | grep -A1 'AQ-E' | grep -qF 'no bullet in' \
   && printf '%s\n' "$q6" | grep -qF '(cut: 6 more lines and cut at 1500 chars'; then ok "Q19 exact section bounds (a near-miss heading above and a level-one heading inside do not move them); a double cut names both limits"
else bad "Q19"; printf '%s\n' "$q6" | grep -E 'AQ-[DEF]|cut:|  > - ' | cut -c1-120 | sed 's/^/     /'; fi

# Q20-Q22 (2026-11-07, operator «ㄱㄱㄱ» via session fa277252): a row whose source is a FILE path in this checkout
# (tracks/_audit/x.md#3-1 — gitignored, absent from the clone) carries the anchored part. Q20 «N-M» = item M of
# section N, its continuation included, the next item not; «N» = section N. Q21 controls: a missing anchor, a missing
# file, «..», a tracked path (the clone has it: pointer only) and a non-file source each say so and carry nothing.
# Q22 the real tsv shape: «operator:…» and «session …» sources are named «not a file».
L7="$W/live7"; M7="$L7/tracks/_meta"; A7="$L7/tracks/_audit"; mkdir -p "$M7" "$A7" "$L7/docs"
printf '# audit\n## 2. other\n1. not this\n## 3. take these\n1. **first item** — body one\n   continued line\n2. **second item** — must not ride along\n## 4. after\n- x\n' > "$A7/a.md"
printf 'tracked\n' > "$L7/docs/t.md"
git -C "$L7" init -q && git -C "$L7" -c user.email=t@t -c user.name=t add docs/t.md && git -C "$L7" -c user.email=t@t -c user.name=t commit -q -m t   # «tracked» is decided by git, not by the path
printf 'id\tadded\tsource\titem\tassets\tstatus\tclosed\tevidence\nAQ-P1\t2026-11-07\ttracks/_audit/a.md#3-1\tfirst\t\topen\t\t\nAQ-P2\t2026-11-07\ttracks/_audit/a.md#3\tsection\t\topen\t\t\nAQ-N1\t2026-11-07\ttracks/_audit/a.md#9-1\tno anchor\t\topen\t\t\nAQ-N2\t2026-11-07\ttracks/_audit/gone.md#1\tno file\t\topen\t\t\nAQ-N3\t2026-11-07\ttracks/../../etc/passwd\tescape\t\topen\t\t\nAQ-N4\t2026-11-07\tdocs/t.md#1\ttracked\t\topen\t\t\nAQ-N5\t2026-11-07\toperator:2026-11-07 session x\tchat\t\topen\t\t\nAQ-N6\t2026-11-07\tsession 2026-10-31 AQ-1 fix\tsession\t\topen\t\t\n' > "$M7/absorption_queue.tsv"
q7="$(python3 "$Q" --live "$L7" 2>&1)"
blk(){ printf '%s\n' "$q7" | awk -v id="($1)" 'index($0,id){f=1;next} /^- \[seed=/{f=0} f'; }
p1="$(blk AQ-P1)"; p2="$(blk AQ-P2)"
if printf '%s\n' "$p1" | grep -qF '  > 1. **first item** — body one' && printf '%s\n' "$p1" | grep -qF '  >    continued line' && ! printf '%s\n' "$p1" | grep -qF 'second item' \
   && printf '%s\n' "$p2" | grep -qF 'second item' && ! printf '%s\n' "$p2" | grep -qF 'not this'; then ok "Q20 «3-1» carries item 1 of section 3 with its continuation, not item 2; «3» carries the section, not section 2"
else bad "Q20"; printf '%s\n---\n%s\n' "$p1" "$p2" | sed 's/^/     /'; fi
if blk AQ-N1 | grep -qF 'anchor «9-1» not found' && blk AQ-N2 | grep -qF '(source not found: tracks/_audit/gone.md)' && blk AQ-N3 | grep -qF 'source refused' \
   && blk AQ-N4 | grep -qF 'read docs/t.md#1 in the clone' && [ "$(blk AQ-N4 | wc -l | tr -d ' ')" -eq 1 ] && ! printf '%s\n' "$q7" | grep -qF 'root:'; then ok "Q21 missing anchor · missing file · «..» · tracked path each say so and carry nothing"
else bad "Q21"; printf '%s\n' "$q7" | grep -A1 -E 'AQ-N[1-4]' | sed 's/^/     /'; fi
if blk AQ-N5 | grep -qF 'not a file' && blk AQ-N6 | grep -qF 'not a file'; then ok "Q22 operator:/session sources are «not a file — must not guess»"; else bad "Q22"; printf '%s\n' "$q7" | grep -A1 -E 'AQ-N[56]' | sed 's/^/     /'; fi

# Q23 the two escape checks, each alone: a link inside tracks/ to an outside file (only the realpath check sees it) and a
# «..» that resolves back inside (only the «..» check refuses it — conservative on purpose).
printf '## 1. outside\n1. **secret** — from outside\n' > "$W/outside7.md"; ln -s "$W/outside7.md" "$A7/link.md"
printf 'id\tadded\tsource\titem\tassets\tstatus\tclosed\tevidence\nAQ-L1\t2026-11-07\ttracks/_audit/link.md#1-1\tlink\t\topen\t\t\nAQ-L2\t2026-11-07\ttracks/_audit/../_audit/a.md#3-1\tdotdot\t\topen\t\t\n' > "$M7/absorption_queue.tsv"
q7="$(python3 "$Q" --live "$L7" 2>&1)"
if blk AQ-L1 | grep -qF 'is a link or resolves outside' && ! printf '%s\n' "$q7" | grep -qF 'from outside' && blk AQ-L2 | grep -qF 'not a relative path inside' && ! blk AQ-L2 | grep -qF 'first item'; then ok "Q23 a link out of tracks/ and a «..» path are refused, nothing carried"
else bad "Q23"; printf '%s\n' "$q7" | grep -A1 -E 'AQ-L[12]' | sed 's/^/     /'; fi

# Q24-Q26 codex R1: Q24 a nested «2.» before the section's own item 2 is not taken, and a continuation across one blank
# line is kept; Q25 an ancestor-directory link is refused, and «./tracks/…» is the same untracked file (carried, never
# «in the clone»); Q26 an untracked file outside tracks/ is carried, never claimed to be in the clone.
printf '## 3. sec\n1. **one** — first\n   - sub\n     2. nested two\n\n   still item one after a blank\n2. **two** — the real item two\n## 4. next\n' > "$A7/n.md"
mkdir -p "$W/outdir7"; printf '## 1. x\n1. **far** — through an ancestor link\n' > "$W/outdir7/f.md"; ln -s "$W/outdir7" "$L7/tracks/linkdir"
printf 'untracked local\n' > "$L7/docs/local.md"
printf 'id\tadded\tsource\titem\tassets\tstatus\tclosed\tevidence\nAQ-T1\t2026-11-07\ttracks/_audit/n.md#3-2\ttwo\t\topen\t\t\nAQ-T2\t2026-11-07\ttracks/_audit/n.md#3-1\tone\t\topen\t\t\nAQ-T3\t2026-11-07\ttracks/linkdir/f.md#1-1\tfar\t\topen\t\t\nAQ-T4\t2026-11-07\t./tracks/_audit/a.md#3-1\tdot\t\topen\t\t\nAQ-T5\t2026-11-07\tdocs/local.md\tlocal\t\topen\t\t\n' > "$M7/absorption_queue.tsv"
q7="$(python3 "$Q" --live "$L7" 2>&1)"
if blk AQ-T1 | grep -qF 'the real item two' && ! blk AQ-T1 | grep -qF 'nested two' && blk AQ-T2 | grep -qF 'still item one after a blank' && ! blk AQ-T2 | grep -qF 'real item two'; then ok "Q24 a nested «2.» never wins over item 2; a continuation across one blank line is kept"
else bad "Q24"; printf '%s\n' "$q7" | grep -A6 -E 'AQ-T[12]' | sed 's/^/     /'; fi
if blk AQ-T3 | grep -qF 'is a link or resolves outside' && ! printf '%s\n' "$q7" | grep -qF 'through an ancestor link' && blk AQ-T4 | grep -qF 'first item' && ! blk AQ-T4 | grep -qF 'in the clone'; then ok "Q25 an ancestor-directory link is refused; «./tracks/…» is carried, not «in the clone»"
else bad "Q25"; printf '%s\n' "$q7" | grep -A3 -E 'AQ-T[34]' | sed 's/^/     /'; fi
if blk AQ-T5 | grep -qF 'untracked local' && ! blk AQ-T5 | grep -qF 'in the clone' && printf '%s\n' "$q7" | grep -qF 'never paste it into a commit'; then ok "Q26 an untracked file outside tracks/ is carried, never claimed to be in the clone; the header says quoted text stays out of commits and PRs"
else bad "Q26"; printf '%s\n' "$q7" | grep -A2 'AQ-T5' | sed 's/^/     /'; fi

# Q27 an ancestor-directory link that resolves INSIDE the checkout — only the every-component link check refuses it
ln -s _audit "$L7/tracks/alias7"
printf 'id\tadded\tsource\titem\tassets\tstatus\tclosed\tevidence\nAQ-A1\t2026-11-07\ttracks/alias7/a.md#3-1\talias\t\topen\t\t\n' > "$M7/absorption_queue.tsv"
q7="$(python3 "$Q" --live "$L7" 2>&1)"
if blk AQ-A1 | grep -qF 'is a link or resolves outside' && ! blk AQ-A1 | grep -qF 'first item'; then ok "Q27 a link in an ancestor directory is refused even when it resolves inside"; else bad "Q27"; blk AQ-A1 | sed 's/^/     /'; fi

[ $((pass+fail)) -eq 27 ] || { echo "HARNESS-ERROR: counted $((pass+fail)) lanes, expected 27"; exit 2; }
echo "selfdev_queue lanes: $pass passed · $fail failed"
[ "$fail" -eq 0 ]

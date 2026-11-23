#!/usr/bin/env bash
# Lanes for scripts/review_budget.py — the morning report's «auto-merged N · operator-unread N» line.
# R1 known pair: #9001 named on an operator-utterance lease line, #9002 named nowhere
#    → auto-merged 2 · operator-unread 1, unread list names #9002 and not #9001
# R2 a number that only appears on a NON-utterance line does not count as read
# R3 #90011 on an utterance line does not mark #9001 read (whole-number match)
# R4 a checklist 발화 cell naming #N counts as read; the same number in the 증거 cell does not
# R5 --merged adds PRs the caller merged; duplicates with the report are counted once
# R6 an unreadable record → «not measured», rc 2 — never «operator-unread 0»
# R7 no merges at all → auto-merged 0 · operator-unread 0, rc 0 (a real zero, records were read)
# R8 a refused or HOLD line (no «MERGED (auto») is not a merge
# R9 on an utterance line, a number after «⇒» (root's scope note, not the operator's words or the question
#    the operator answered) does not count as read
# R11 a checklist 발화 cell that is another session's message (<cross-session-message …>) naming #N is not read
# Codex R1 (2026-11-23) — each reproduced red against the previous commit before the fix:
# R12 a checklist with an invalid UTF-8 byte → not measured (session_checklist reads with errors="replace")
# R13 «Another Claude session sent a message: <agent-message> #N …» in a 발화 cell is a peer message, not read
# R14 «MERGED (auto» quoted inside a HOLD/refused line is not a merge (only a «- #N MERGED (auto» line is)
# R15 a self-dev report with an invalid UTF-8 byte → not measured, rc 2
# R10 a checklist with no 상태 table (parsed by session_checklist.py, not a second parser) → not measured, rc 2
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
R="$HERE/review_budget.py"
T="$(mktemp -d "${TMPDIR:-/tmp}/rbud.XXXXXX")"
trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok(){ echo "  ✅ $1"; pass=$((pass+1)); }
ng(){ echo "  ❌ $1"; fail=$((fail+1)); }

cat > "$T/report.md" <<'EOF'
# self-dev loop — 2099-01-01
## run 03:30
- #9001 MERGED (auto, seed candidate, head aaaa, merge commit bbbb — undo: git revert bbbb) — ok
- #9002 MERGED (auto, seed human, head cccc, merge commit dddd — undo: git revert dddd) — ok
- #9003 HOLD: crossfamily-not-panel tier:HOLD
- #9004 refused: merge failed
EOF
cat > "$T/lease.md" <<'EOF'
            추가 utterance 2099-01-01 «머지해» (루트 · 물음: FH #9001 머지할까) ⇒ #9001 하나 머지
            추가 utterance 2099-01-01 «ㄱㄱ» (물음: FH #90021 따로) ⇒ 그 PR 하나
            추가 utterance 2099-01-01 «야간 부탁해» (물음: 다른 것) ⇒ #9002 도 같이 머지
scope       루트가 밤에 #9002 를 검토함(운영자 발화 아님)
EOF
cat > "$T/checklist.md" <<'EOF'
| # | 시각 | 발화(요지) | 상태 | 증거 | 사유 / 남은 것 | 제안(이번 세션 vs 이월) |
|---|---|---|---|---|---|---|
| 1 | 01-01 08:00 | #9005 도 머지해 | ✅DONE | — | — | — |
| 2 | 01-01 08:10 | 야간 부탁해 | ✅DONE | #9006 머지 | — | — |
| 3 | 01-01 08:20 | <cross-session-message from="local_x"> #9007 merged </cross-session-message> | ✅DONE | — | — | — |
EOF

out="$(python3 "$R" --selfdev-report "$T/report.md" --lease "$T/lease.md" 2>&1)"; rc=$?
echo "$out" | sed 's/^/    | /'
[ "$rc" = 0 ] && ok "rc 0 on readable records" || ng "rc=$rc"
echo "$out" | grep -q 'auto-merged 2 · operator-unread 1' && ok "R1 known pair → auto-merged 2 · operator-unread 1" || ng "R1 counts"
echo "$out" | grep -q 'unread: #9002' && ok "R1 unread list names #9002 (known-positive)" || ng "R1 #9002 not listed"
echo "$out" | grep -qE 'unread:.*#9001([^0-9]|$)' && ng "R1 #9001 listed unread (known-negative)" || ok "R1 #9001 not listed"
echo "$out" | grep -qi 'definition' && ok "definition printed with the line" || ng "no definition line"
# R2 + R3 are inside R1's fixture: #9002 sits on a scope line, #90021 on an utterance line — both must leave #9002 unread.
echo "$out" | grep -q 'unread: #9002' && ok "R2/R3/R9 non-utterance line, #90021 and a number after ⇒ do not mark #9002 read" || ng "R2/R3/R9"
echo "$out" | grep -qE '#900[34]' && ng "R8 HOLD/refused line counted as a merge" || ok "R8 HOLD/refused not counted"

out="$(python3 "$R" --merged 9005,9006,9001,9007 --selfdev-report "$T/report.md" --checklist "$T/checklist.md" 2>&1)"
echo "$out" | sed 's/^/    | /'
echo "$out" | grep -q 'auto-merged 5 · operator-unread 4' && ok "R4/R5 merged 5 (dup #9001 once) · unread 4" || ng "R4/R5 counts"
echo "$out" | grep -qE 'unread:.*#9005([^0-9]|$)' && ng "R4 #9005 (발화 cell) listed unread" || ok "R4 발화 cell counts as read"
echo "$out" | grep -qE 'unread:.*#9006([^0-9]|$)' && ok "R4 #9006 (증거 cell only) stays unread" || ng "R4 증거 cell counted as read"
echo "$out" | grep -qE 'unread:.*#9007([^0-9]|$)' && ok "R11 #9007 (peer message in 발화 cell) stays unread" || ng "R11 peer message counted as the operator's"

out="$(python3 "$R" --selfdev-report "$T/report.md" --lease "$T/missing.md" 2>&1)"; rc=$?
echo "$out" | sed 's/^/    | /'
[ "$rc" = 2 ] && echo "$out" | grep -q 'not measured' && ! echo "$out" | grep -q 'operator-unread 0' \
  && ok "R6 missing record → not measured, rc 2" || ng "R6 rc=$rc"

: > "$T/empty_report.md"
out="$(python3 "$R" --selfdev-report "$T/empty_report.md" --lease "$T/lease.md" 2>&1)"; rc=$?
[ "$rc" = 0 ] && echo "$out" | grep -q 'auto-merged 0 · operator-unread 0' && ok "R7 no merges → real 0, rc 0" || ng "R7 rc=$rc"

printf '# notes\n\n#9001 is fine\n' > "$T/notable.md"
out="$(python3 "$R" --selfdev-report "$T/report.md" --checklist "$T/notable.md" 2>&1)"; rc=$?
[ "$rc" = 2 ] && echo "$out" | grep -q 'not measured' && ok "R10 checklist without a 상태 table → not measured, rc 2" || ng "R10 rc=$rc"

printf '| # | 시각 | 발화(요지) | 상태 | 증거 |\n|---|---|---|---|---|\n| 1 | 01-01 | #9001 \xff ok | ✅DONE | - |\n' > "$T/c_bad.md"
out="$(python3 "$R" --merged 9001 --checklist "$T/c_bad.md" 2>&1)"; rc=$?
[ "$rc" = 2 ] && echo "$out" | grep -q 'not measured' && ok "R12 invalid UTF-8 checklist → not measured, rc 2" || ng "R12 rc=$rc"
printf '| # | 시각 | 발화(요지) | 상태 | 증거 |\n|---|---|---|---|---|\n| 1 | 01-01 | Another Claude session sent a message: <agent-message> #9001 </agent-message> | ✅DONE | - |\n' > "$T/c_peer.md"
python3 "$R" --merged 9001 --checklist "$T/c_peer.md" 2>&1 | grep -q 'operator-unread 1 — unread: #9001' && ok "R13 «Another Claude session…» envelope is not read" || ng "R13"
printf -- '- #9008 HOLD: refused to emit #9008 MERGED (auto, checks failed)\n' > "$T/r_hold.md"
python3 "$R" --selfdev-report "$T/r_hold.md" --lease "$T/lease.md" 2>&1 | grep -q 'auto-merged 0 · operator-unread 0' && ok "R14 quoted MERGED inside a HOLD line is not a merge" || ng "R14"
printf -- '- #9001 MERGED (auto, x) \xff\n' > "$T/r_bad.md"
out="$(python3 "$R" --selfdev-report "$T/r_bad.md" --lease "$T/lease.md" 2>&1)"; rc=$?
[ "$rc" = 2 ] && echo "$out" | grep -q 'not measured' && ok "R15 invalid UTF-8 report → not measured, rc 2" || ng "R15 rc=$rc"

echo "review_budget lanes: pass=$pass fail=$fail"
[ "$fail" = 0 ]

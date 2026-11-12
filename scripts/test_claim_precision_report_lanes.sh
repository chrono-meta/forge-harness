#!/usr/bin/env bash
# Lanes for scripts/claim_precision_report.py — known pair + channel-gap cases.
# P1 DONE → PARTIAL in a later sheet           → M=1 (known-positive)
# P2 DONE → DONE                               → M=0 (known-negative, same run)
# P3 DONE → empty 상태                          → B=1, M unchanged (not re-judged ≠ corrected)
# P4 a session with one sheet                  → listed NOT MEASURED, contributes nothing
# P5 empty folder                              → rc 10, NOT MEASURED (absence ≠ 0)
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
R="$HERE/claim_precision_report.py"
T="$(mktemp -d "${TMPDIR:-/tmp}/cpr.XXXXXX")"
trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok(){ echo "  ✅ $1"; pass=$((pass+1)); }
ng(){ echo "  ❌ $1"; fail=$((fail+1)); }

hdr='| # | 시각 | 발화(요지) | 상태 | 증거 | 사유 / 남은 것 | 제안(이번 세션 vs 이월) |
|---|---|---|---|---|---|---|'
mkdir -p "$T/d"
{ echo "$hdr"
  echo '| 1 | 11-01 10:00 | alpha request | ✅DONE | e1 | — | — |'
  echo '| 2 | 11-01 11:00 | beta request | ✅DONE | e2 | — | — |'
  echo '| 3 | 11-01 12:00 | gamma request | ✅DONE | e3 | — | — |'; } > "$T/d/session_checklist_2026-11-01_sA.md"
{ echo "$hdr"
  echo '| 1 | 11-01 10:00 | alpha request | 🟡PARTIAL | e1 | narrowed | later |'
  echo '| 2 | 11-01 11:00 | beta request | ✅DONE | e2 | — | — |'
  echo '| 3 | 11-01 12:00 | gamma request |  |  |  |  |'; } > "$T/d/session_checklist_2026-11-02_sA.md"
{ echo "$hdr"
  echo '| 1 | 11-03 09:00 | solo request | ✅DONE | e | — | — |'; } > "$T/d/session_checklist_2026-11-03_sB.md"

out="$(python3 "$R" --dir "$T/d" 2>&1)"; rc=$?
echo "$out" | sed 's/^/    | /'
[ "$rc" = 0 ] && ok "rc 0 on sheets" || ng "rc=$rc"
echo "$out" | grep -q 'N done-rows=3 ' && ok "P2 N=3 (DONE rows of the measured session)" || ng "P2 N"
echo "$out" | grep -q 'M later reopened (non-DONE in the enum)=1 ' && ok "P1 M=1 known-positive" || ng "P1 M"
echo "$out" | grep -q 'alpha request' && ok "P1 reopened row is the alpha row" || ng "P1 row identity"
echo "$out" | grep -q 'beta request' && ng "P2 known-negative listed as reopened" || ok "P2 beta not listed"
echo "$out" | grep -q 'B not re-judged in newest sheet (blank, absent or outside the enum)=1 ' && ok "P3 blank counted apart (B=1)" || ng "P3 B"
echo "$out" | grep -q 'not-measured(<2 readable sheets)=1' && echo "$out" | grep -q 'readable sheets sB' \
  && ok "P4 single-sheet session named NOT MEASURED" || ng "P4"

mkdir -p "$T/empty"
out="$(python3 "$R" --dir "$T/empty" 2>&1)"; rc=$?
[ "$rc" = 10 ] && echo "$out" | grep -q 'NOT MEASURED' && ok "P5 empty folder → rc 10 NOT MEASURED" || ng "P5 rc=$rc"

# Codex R1 (2026-11-11) — each reproduced red against the first version before the fix.
# P6 two sheets that cannot be parsed → not measured, never «measured=1 N=0 M=0».
mkdir -p "$T/bad"; : > "$T/bad/session_checklist_2026-11-01_sC.md"; : > "$T/bad/session_checklist_2026-11-02_sC.md"
out="$(python3 "$R" --dir "$T/bad" 2>&1)"
echo "$out" | grep -q 'measured=0 ' && echo "$out" | grep -q 'unreadable sheets session_checklist_2026-11-01_sC.md' \
  && ok "P6 unreadable sheets → measured=0, named" || ng "P6"
# P7 DONE → PARTIAL → DONE: the reopening stays counted (sticky).
mkdir -p "$T/sticky"
{ echo "$hdr"; echo '| 1 | 11-01 10:00 | delta request | ✅DONE | e | — | — |'; } > "$T/sticky/session_checklist_2026-11-01_sD.md"
{ echo "$hdr"; echo '| 1 | 11-01 10:00 | delta request | 🟡PARTIAL | e | x | y |'; } > "$T/sticky/session_checklist_2026-11-02_sD.md"
{ echo "$hdr"; echo '| 1 | 11-01 10:00 | delta request | ✅DONE | e | — | — |'; } > "$T/sticky/session_checklist_2026-11-03_sD.md"
python3 "$R" --dir "$T/sticky" 2>&1 | grep -q 'M later reopened (non-DONE in the enum)=1 ' && ok "P7 reopening is sticky" || ng "P7"
# P8 a DONE row absent from the newest sheet counts in B (not re-judged), not as silence.
mkdir -p "$T/gone"
{ echo "$hdr"; echo '| 1 | 11-01 10:00 | eps request | ✅DONE | e | — | — |'; } > "$T/gone/session_checklist_2026-11-01_sE.md"
{ echo "$hdr"; echo '| 1 | 11-02 10:00 | other request | ✅DONE | e | — | — |'; } > "$T/gone/session_checklist_2026-11-02_sE.md"
python3 "$R" --dir "$T/gone" 2>&1 | grep -q '(blank, absent or outside the enum)=1 ' && ok "P8 absent row counted in B" || ng "P8"

# Codex R2: P9 sheets whose 상태 table lacks 시각/발화 → nothing measurable → not measured.
mkdir -p "$T/nocols"
for d in 01 02; do printf '| 상태 | 메모 |\n|---|---|\n| ✅DONE | x |\n' > "$T/nocols/session_checklist_2026-11-${d}_sF.md"; done
python3 "$R" --dir "$T/nocols" 2>&1 | grep -q 'measured=0 ' && ok "P9 no 시각/발화 columns → measured=0" || ng "P9"

# P10 a later «—» (outside the enum) is not a reopening: it counts in B, M stays 0.
mkdir -p "$T/dash"
{ echo "$hdr"; echo '| 1 | 11-01 10:00 | zeta request | ✅DONE | e | — | — |'; } > "$T/dash/session_checklist_2026-11-01_sG.md"
{ echo "$hdr"; echo '| 1 | 11-01 10:00 | zeta request | — | e | — | — |'; } > "$T/dash/session_checklist_2026-11-02_sG.md"
o="$(python3 "$R" --dir "$T/dash" 2>&1)"
echo "$o" | grep -q 'M later reopened (non-DONE in the enum)=0 ' && echo "$o" | grep -q 'outside the enum)=1 ' && ok "P10 «—» → B, not M" || ng "P10"

echo "claim_precision_report lanes: pass=$pass fail=$fail"
[ "$fail" = 0 ]

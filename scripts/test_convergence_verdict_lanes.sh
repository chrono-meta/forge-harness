#!/usr/bin/env bash
# test_convergence_verdict_lanes.sh — known-pair calibration for scripts/convergence_verdict.py
# (convergence-loop §Convergence Judgment: last round clean AND no repairs in response AND ≥ 2 rounds).
# C1 is the positive control (a vector that IS converged reads CONVERGED); every other lane is one way a vector
# must NOT read converged, or must read UNMEASURED instead of a guess.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
V="$HERE/convergence_verdict.py"
[ -f "$V" ] || { echo "HARNESS-ERROR: $V missing"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); echo "  ✅ $1"; }
bad() { fail=$((fail+1)); echo "  ❌ $1"; }
one() { # <label> <want rc> <want verdict word> <vector>
  out=$(python3 "$V" --rounds "$4" 2>&1); rc=$?
  if [ "$rc" = "$2" ] && printf '%s' "$out" | grep -q "^$3:"; then ok "$1"; else bad "$1 (rc=$rc · $out)"; fi
}
one "C1 control: R1 fixes, R2 clean with no repairs → CONVERGED"        0 CONVERGED     'R1 [new=3, fixed=3] → R2 [new=0, fixed=0]'
one "C2 one clean round → PROVISIONAL, rc 1 (condition 3: ≥ 2 rounds)"  1 PROVISIONAL   'R1 [new=0, fixed=0] → converged'
one "C3 last round triggered a fix → NOT-CONVERGED (the fix is unverified)" 1 NOT-CONVERGED 'R1 [new=2, fixed=2] → R2 [new=0, fixed=1]'
one "C4 last round found something new → NOT-CONVERGED"                  1 NOT-CONVERGED 'R1 [new=2, fixed=2] → R2 [new=1, fixed=1]'
one "C5 S/A/B form: all-zero last round after a finding round → CONVERGED" 0 CONVERGED   'R1 S1A2B3 → R2 S0A0B0'
one "C6 S/A/B form: a B finding in the last round with no fix info → UNMEASURED" 2 UNMEASURED 'R1 S1A4B5 → R2 S0A0B3'
one "C7 free prose → UNMEASURED, never guessed"                          2 UNMEASURED    'R1 0 and no change → converged'
one "C8 a bracketed round missing fixed= → UNMEASURED (not «judge R1»)"  2 UNMEASURED    'R1 [new=1, fixed=1] → R2 [new=0] → converged'
one "C9 rounds out of order → UNMEASURED"                                2 UNMEASURED    'R2 [new=0, fixed=0] → R1 [new=1, fixed=1]'
one "C10 a note inside the brackets is allowed («new=1 (med1)»)"         0 CONVERGED     'R1 [new=1 (med1), fixed=1] · R2 [new=0, fixed=0] → converged'
# codex R1 counterexamples — each read CONVERGED (exit 0) before the strict per-round parser
one "C10b a trailing round in another shape is not skipped (R3 S1A0B0)" 2 UNMEASURED 'R1 [new=1, fixed=1] → R2 [new=0, fixed=0] → R3 S1A0B0'
one "C10c a trailing unreadable round is not skipped (R3 ???)"           2 UNMEASURED 'R1 [new=1, fixed=1] → R2 [new=0, fixed=0] → R3 ???'
one "C10d a decimal count is not read as its integer part"               2 UNMEASURED 'R1 [new=1, fixed=1] → R2 [new=0.5, fixed=0.5]'
one "C10e a repeated S/A/B key does not overwrite a count"               2 UNMEASURED 'R1 S1A0B0 → R2 S1S0A0'
one "C10f repairs written after an all-zero S/A/B round are not «no repairs»" 2 UNMEASURED 'R1 S1A0B0 → R2 S0A0B0 fixed=2'
# codex R2
one "C10g a second shape inside one round is not ignored"                2 UNMEASURED 'R1 [new=1, fixed=1] → R2 [new=0, fixed=0] [new=3, fixed=0]'
one "C10h a S/A/B tail inside a [new=,fixed=] round is not ignored"      2 UNMEASURED 'R1 [new=1, fixed=1] → R2 [new=0, fixed=0] S3A0B0'
one "C10i an S/A/B round without S and A says nothing about S/A"         2 UNMEASURED 'R1 S1A0B0 → R2 B0C0'
one "C10j repairs written outside the counts are not «fixed=0»"         2 UNMEASURED 'R1 [new=1, fixed=1] → R2 [new=0, fixed=0] (repaired two defects)'
mk() { printf 'date: x\naxis2-rounds: %s\n' "$2" > "$W/m/.axes_23_passed_$1_2026-11-06.marker"; }
mkdir -p "$W/m"
mk true_claim   'R1 [new=2, fixed=2] → R2 [new=0, fixed=0] → converged'
mk false_claim  'R1 [new=0, fixed=0] → converged'
mk unreadable   'R1 0 and no change → converged'
mk honest       'R1 [new=0, fixed=0] → not converged (one round only)'
mk ko_claim     'R1 [new=0, fixed=0] → 수렴'
mk ko_honest    'R1 [new=0, fixed=0] → 수렴 안 함(한 라운드)'
mk ko_done      'R1 [new=0, fixed=0] → 수렴 완료'
mk en_notyet    'R1 [new=0, fixed=0] → not yet converged'
mk ko_notdone   'R1 [new=0, fixed=0] → 수렴하지 않음'
mk en_underscore 'R1 [new=0, fixed=0] → converged_완료'
out=$(python3 "$V" --scan-markers "$W/m" 2>&1); rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q 'contradicts it: 4 · claimed on a vector this tool cannot read: 1' \
   && printf '%s' "$out" | grep -q 'false_claim' && printf '%s' "$out" | grep -q 'ko_claim' && printf '%s' "$out" | grep -q 'ko_done' && printf '%s' "$out" | grep -q 'en_underscore' \
   && ! printf '%s' "$out" | grep -qE 'honest_2026|en_notyet|ko_notdone' && ! printf '%s' "$out" | grep -q 'true_claim_2026'; then
  ok "C11 scan: false claims flagged in English and Korean («→ 수렴»), one unauditable; the true claim and «not converged» / «수렴 안 함» lines are not"
else bad "C11 (rc=$rc)"; printf '%s\n' "$out" | sed 's/^/       /'; fi
for f in false_claim ko_claim ko_done en_underscore; do rm "$W/m/.axes_23_passed_${f}_2026-11-06.marker"; done
out=$(python3 "$V" --scan-markers "$W/m" 2>&1); rc=$?
[ "$rc" = 2 ] && ok "C12 no false claim left but one claim this tool cannot read → rc 2, not a clean audit (codex R1)" || bad "C12 (rc=$rc)"
rm "$W/m/.axes_23_passed_unreadable_2026-11-06.marker"
out=$(python3 "$V" --scan-markers "$W/m" 2>&1); rc=$?
[ "$rc" = 0 ] && ok "C12b control: nothing false and nothing unreadable → rc 0" || bad "C12b (rc=$rc · $out)"
mkdir -p "$W/empty"; out=$(python3 "$V" --scan-markers "$W/empty" 2>&1); rc=$?
[ "$rc" = 2 ] && printf '%s' "$out" | grep -q UNMEASURED && ok "C13 a folder with no axis2-rounds line → UNMEASURED (rc 2), not «no false claims»" || bad "C13 (rc=$rc)"
[ $((pass+fail)) -eq 23 ] || { echo "HARNESS-ERROR: counted $((pass+fail)) lanes, expected 23"; exit 2; }
echo "convergence_verdict lanes: $pass passed · $fail failed"
[ "$fail" -eq 0 ]

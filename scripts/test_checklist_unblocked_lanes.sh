#!/usr/bin/env bash
# test_checklist_unblocked_lanes.sh — regression anchor for `session_checklist.py unblocked`.
#
# WHAT IT PINS. A row that declared a blocker, whose blocker later landed DONE, while the row
# itself stayed open. Measured 2026-09-19 on this repo's own checklist: A6 and A8 sat in exactly
# that state and three operator requests degraded until the operator asked again. The existing
# `check` command passed the same file clean (rows=14 ok=14 violations=0 rc=0) — form was never
# the problem, so a form checker could never have caught it.
#
# 🟥 WHY rc=4 EXISTS. An instrument that parses zero dependency edges and reports "0 findings" has
# not measured anything. "not found" is not "0" — this repo has a named family for that mistake.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBJ="$HERE/session_checklist.py"
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  ✅ %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  ❌ %s\n' "$1"; }
[ -f "$SUBJ" ] || { echo "❌ HARNESS-ERROR: subject missing: $SUBJ"; exit 1; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
hdr='| # | 요청 | 상태 | 증거 | 사유 | 제안 |
|---|---|---|---|---|---|'

run() { out="$(python3 "$SUBJ" unblocked --file "$1" 2>&1)"; rc=$?; }

# ── L1 known-POSITIVE: blocker DONE, dependent open → rc=1 and the row is NAMED ──
printf '%s\n| A6 | sim | IN-PROGRESS | - | A13 선행 | later |\n| A13 | runner | DONE | c0ffee | - | - |\n' "$hdr" > "$T/pos.md"
run "$T/pos.md"
[ "$rc" -eq 1 ] && ok "L1 blocker DONE + dependent open → rc=1" || bad "L1 expected rc=1, got $rc"
printf '%s' "$out" | /usr/bin/grep -q "A6 is still open" && ok "L1b the finding NAMES the row (not just a count)" || bad "L1b row not named: $out"
printf '%s' "$out" | /usr/bin/grep -q "A13" && ok "L1c the finding names the BLOCKER too" || bad "L1c blocker not named"

# ── L2 known-NEGATIVE: blocker NOT done → rc=0. Same file shape, one cell different. ──
printf '%s\n| A6 | sim | IN-PROGRESS | - | A13 선행 | later |\n| A13 | runner | IN-PROGRESS | - | wip | - |\n' "$hdr" > "$T/neg.md"
run "$T/neg.md"
[ "$rc" -eq 0 ] && ok "L2 blocker still open → rc=0 (one cell separates L1/L2)" || bad "L2 expected rc=0, got $rc"

# ── L3 the dependent is ALREADY DONE → not idle, no finding ──
# 🟥 the dependency text STAYS — otherwise this fixture has zero edges and tests nothing (first
# draft made exactly that mistake and rc=4 was the correct answer to the wrong question).
printf '%s\n| A6 | sim | DONE | done | A13 선행 | - |\n| A13 | runner | DONE | c0ffee | - | - |\n' "$hdr" > "$T/done.md"
run "$T/done.md"
[ "$rc" -eq 0 ] && ok "L3 dependency resolved AND dependent closed → edge counted, no finding (rc=0, not 4)" || bad "L3 expected rc=0, got $rc"
printf '%s' "$out" | /usr/bin/grep -q "edges=1" && ok "L3b «all resolved» reports edges=1 — distinct from «nobody wrote a dependency» (edges=0)" || bad "L3b edge not counted: $out"

# ── L4 🟥 DEAD CONTROL: rows exist, zero dependency edges → rc=4, never 0 ──
printf '%s\n| A6 | sim | IN-PROGRESS | - | no dependency here | just do it |\n' "$hdr" > "$T/dead.md"
run "$T/dead.md"
[ "$rc" -eq 4 ] && ok "L4 zero edges parsed → rc=4 DEAD CONTROL (not a clean 0)" || bad "L4 expected rc=4, got $rc"
printf '%s' "$out" | /usr/bin/grep -q "DEAD CONTROL" && ok "L4b rc=4 says WHY in words" || bad "L4b no reason printed"

# ── L5 phantom blocker: points at a row that does not exist → not counted as an edge ──
printf '%s\n| A6 | sim | IN-PROGRESS | - | Z99 선행 | later |\n' "$hdr" > "$T/phantom.md"
run "$T/phantom.md"
[ "$rc" -eq 4 ] && ok "L5 pointer to a nonexistent row is not an edge (rc=4, not a false finding)" || bad "L5 expected rc=4, got $rc"

# ── L6 notation variants the real corpus uses ──
for v in "A13 선행" "A13 착지 후" "A13 이후" "A13 완료 후" "A13 after"; do
  printf '%s\n| A6 | sim | NOT-DONE | - | %s | later |\n| A13 | runner | DONE | c0ffee | - | - |\n' "$hdr" "$v" > "$T/v.md"
  run "$T/v.md"
  [ "$rc" -eq 1 ] && ok "L6 notation «${v}» is parsed as a dependency" || bad "L6 «${v}» missed (rc=$rc)"
done

# ── L7 input errors keep the load_tables contract ──
run "$T/nope.md";            [ "$rc" -eq 10 ] && ok "L7 missing file → rc=10" || bad "L7 expected 10, got $rc"
printf 'no table here\n' > "$T/notable.md"; run "$T/notable.md"
[ "$rc" -eq 10 ] && ok "L7b no 상태 table → rc=10" || bad "L7b expected 10, got $rc"

# ── L8 🟥 SHARED-PARSER: a fenced example table must not be read as the checklist ──
{ printf '%s\n' '```'; printf '%s\n| A6 | x | IN-PROGRESS | - | A13 선행 | - |\n| A13 | y | DONE | z | - | - |\n' "$hdr"; printf '%s\n' '```'; \
  printf '%s\n| B1 | real | IN-PROGRESS | - | no dep | - |\n' "$hdr"; } > "$T/fence.md"
run "$T/fence.md"
[ "$rc" -eq 4 ] && ok "L8 fenced table ignored — the shared parser's hardening reaches this command" || bad "L8 fence leaked (rc=$rc): $out"

# ── L9 🟥 NAMED LIMIT (honest, not a pass): a row that never WROTE its blocker is invisible ──
printf '%s\n| A9 | sim | IN-PROGRESS | - | 팔 1건 진행 중 | - |\n| A13 | runner | DONE | c0ffee | - | - |\n' "$hdr" > "$T/silent.md"
run "$T/silent.md"
[ "$rc" -eq 4 ] && ok "L9 an UNWRITTEN dependency is NOT detected — pinned as a known blind spot, not a feature" \
                || bad "L9 expected rc=4 (blind), got $rc — if this changed, update the doc claim"

printf -- '── %d passed, %d failed ──\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1

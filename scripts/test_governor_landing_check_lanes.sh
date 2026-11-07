#!/usr/bin/env bash
# test_governor_landing_check_lanes.sh — lanes for scripts/governor_landing_check.py
#   defaults: displayed 97, observed fire 96, growth 3, queue 1 → threshold 90
#   O1 89 → OK(0) · L1 90 → LAND(1) · L2 95 → LAND(1) · T1 96 → LATE(3) (displayed 97 is not trusted)
#   J1 get_usage JSON 92 → LAND · J2 status unavailable → 2 (never OK) · E1 no percent → 2
#   K1 --turn-growth 5 → threshold 86, 87 → LAND (margin is a parameter, not a constant)
#   R1 revert probe: the observed-fire clamp removed in a copy → 96 reads LAND, not LATE
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
S="scripts/governor_landing_check.py"; [ -f "$S" ] || { echo "HARNESS-ERROR: $S missing"; exit 2; }
T="$(mktemp -d "${TMPDIR:-/tmp}/glc.XXXXXX")"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
want() {  # $1 name $2 expected rc ; rest = args
  local n="$1" e="$2"; shift 2
  out="$(python3 "$S" "$@" 2>&1)"; rc=$?
  if [ "$rc" -eq "$e" ]; then echo "  ✅ $n rc=$rc"; pass=$((pass+1)); else echo "  ❌ $n rc=$rc want $e :: $out"; fail=$((fail+1)); fi
}
want O1 0 --percent 89 --displayed-at 97
want L1 1 --percent 90 --displayed-at 97
want L2 1 --percent 95 --displayed-at 97
want T1 3 --percent 96 --displayed-at 97
printf '{"context":{"status":"ok","percentUsed":92,"autoCompactsAtPercent":97}}' > "$T/u.json"
want J1 1 --usage-json "$T/u.json"
printf '{"context":{"status":"unavailable"}}' > "$T/x.json"
want J2 2 --usage-json "$T/x.json"
want E1 2
want F1 2 --percent nan --displayed-at 97
want F2 2 --percent 92 --turn-growth nan
printf '{"context":[1]}' > "$T/l.json"
want F3 2 --usage-json "$T/l.json"
printf '[]' > "$T/a.json"
want F4 2 --usage-json "$T/a.json"
want K1 1 --percent 87 --displayed-at 97 --turn-growth 5

M="$T/m.py"; sed 's/^OBSERVED_FIRE = 96$/OBSERVED_FIRE = 999/' "$S" > "$M"
if cmp -s "$S" "$M"; then echo "  ❌ R1 mutation did not apply (HARNESS-ERROR)"; fail=$((fail+1)); else
  python3 "$M" --percent 96 --displayed-at 97 >/dev/null; rc=$?
  [ "$rc" -eq 1 ] && { echo "  ✅ R1 mutant reads 96 as LAND → T1 would be red"; pass=$((pass+1)); } \
                  || { echo "  ❌ R1 mutant rc=$rc (lane does not see the clamp)"; fail=$((fail+1)); }
fi
echo "governor_landing_check lanes: $pass passed · $fail failed"
[ "$fail" -eq 0 ]

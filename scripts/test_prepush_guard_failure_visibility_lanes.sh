#!/usr/bin/env bash
# test_prepush_guard_failure_visibility_lanes.sh — when a known pair in prepush_guard_check.sh breaks,
# the reader of a TRUNCATED log must still see which pair broke, its exit code and how long it ran.
#
# WHY. A downstream consumer reported `[prepush-guard] ❌ BLOCKED — a known pair broke.` from a 2h+
# selfcheck under heavy load, and nobody could say which pair: selfcheck printed only the last 12
# lines of the check, the BLOCKED line named nothing, and the failing pair's own ❌ line sat above
# the cut. The cause of that failure is still UNMEASURED; these lanes only guard the instrument, so
# that a recurrence can be read as a timeout (long elapsed) or a wrong verdict (short elapsed).
#
# HOW. A throwaway repo gets the real hook, scan library, pattern defaults and the check under test.
# One arm is left clean; the other has one planted defect: the stacked-branch advisory's marker is
# renamed in the hook, so every pair that expects a warning now gets none (a broken pair, on purpose).
#   V1 clean arm passes and prints no BLOCKED line (control: the plant is what breaks it)
#   V2 the plant really landed (application check: marker gone from the planted hook only)
#   V3 planted arm exits 1
#   V4 the last 12 lines name every broken pair, with rc= and an elapsed time
#   V5 every pair line (✅ and ❌) carries an elapsed stamp [Ns]
#   V6 selfcheck's own renderer (_show_failure, extracted from selfcheck.sh and run) shows the names
#   V7 selfcheck's prepush-guard block renders through _show_failure, not a bare tail
# Control arm for the whole file: PG_SCRIPT=<older prepush_guard_check.sh> makes V4/V5 red.
#
# Usage: bash scripts/test_prepush_guard_failure_visibility_lanes.sh   (exit 0 all pass, 1 otherwise)
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
PG_SCRIPT="${PG_SCRIPT:-$ROOT/scripts/prepush_guard_check.sh}"
SELFCHECK="${SELFCHECK:-$ROOT/scripts/selfcheck.sh}"
PASS=0; FAIL=0
ok() { echo "  ✅ $1"; PASS=$((PASS+1)); }
no() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }

for f in "$PG_SCRIPT" "$SELFCHECK" "$ROOT/templates/.git-hooks/pre-push" "$ROOT/scripts/psa_scan_lib.sh" \
         "$ROOT/.claude/rules/.public-surface-patterns.defaults"; do
  [ -f "$f" ] || { echo "HARNESS-ERROR: missing $f"; exit 2; }
done

# shellcheck source=fixture_guard_lib.sh
. "$ROOT/scripts/fixture_guard_lib.sh"
WORK="$(fh_fixture_root "$(mktemp -d "${TMPDIR:-/tmp}/pg_vis.XXXXXX")")" || exit 2
: "${WORK:?fixture root unset — refusing to run git in cwd}"
trap 'rm -rf "$WORK"' EXIT

mkfix() {  # mkfix <dir> — a repo the check can treat as REPO_ROOT
  local d="$1"
  mkdir -p "$d/scripts" "$d/templates/.git-hooks" "$d/.claude/rules"
  cp "$PG_SCRIPT" "$d/scripts/prepush_guard_check.sh"
  cp "$ROOT/scripts/psa_scan_lib.sh" "$d/scripts/psa_scan_lib.sh"
  cp "$ROOT/templates/.git-hooks/pre-push" "$d/templates/.git-hooks/pre-push"
  cp "$ROOT/.claude/rules/.public-surface-patterns.defaults" "$d/.claude/rules/.public-surface-patterns.defaults"
  ( cd "$d" && git init -q -b main && git config user.email t@example.com && git config user.name t \
    && git add scripts templates .claude && git commit -qm fix >/dev/null ) || return 1
}

CLEAN="$WORK/clean"; PLANT="$WORK/plant"
mkfix "$CLEAN" || { echo "HARNESS-ERROR: clean fixture"; exit 2; }
mkfix "$PLANT" || { echo "HARNESS-ERROR: planted fixture"; exit 2; }
# The plant: rename the warning marker on the line that announces a stacked branch (not the SKIPPED one).
MARK='[fh-advisory:stacked-branch] %s carries'
python3 - "$PLANT/templates/.git-hooks/pre-push" "$MARK" <<'PY'
import sys
p, m = sys.argv[1], sys.argv[2]
s = open(p, encoding="utf-8").read()
open(p, "w", encoding="utf-8").write(s.replace(m, "[fh-advisory:planted-off] %s carries"))
PY
( cd "$PLANT" && git add templates/.git-hooks/pre-push && git commit -qm plant >/dev/null )

# V2 application check
c_clean=$(grep -cF "$MARK" "$CLEAN/templates/.git-hooks/pre-push")
c_plant=$(grep -cF "$MARK" "$PLANT/templates/.git-hooks/pre-push")
if [ "$c_clean" -ge 1 ] && [ "$c_plant" -eq 0 ]; then ok "V2 plant applied (marker clean=$c_clean planted=$c_plant)"
else no "V2 plant not applied (marker clean=$c_clean planted=$c_plant) — later lanes would read nothing"; fi

out_clean="$(cd "$CLEAN" && bash scripts/prepush_guard_check.sh 2>&1)"; rc_clean=$?
out_plant="$(cd "$PLANT" && bash scripts/prepush_guard_check.sh 2>&1)"; rc_plant=$?

# V1
case "$out_clean" in
  *"BLOCKED"*) no "V1 clean arm printed BLOCKED (rc=$rc_clean)" ;;
  *) if [ "$rc_clean" -eq 0 ]; then ok "V1 clean arm passes (rc=0, no BLOCKED)"
     else no "V1 clean arm rc=$rc_clean"; printf '%s\n' "$out_clean" | tail -8 | sed 's/^/       | /'; fi ;;
esac

# V3
if [ "$rc_plant" -eq 1 ]; then ok "V3 planted arm exits 1"; else no "V3 planted arm rc=$rc_plant (expected 1)"; fi

# Names of the broken pairs, as the per-pair ❌ lines print them (spaces squeezed; the elapsed stamp
# and everything after the em dash dropped).
names="$(printf '%s\n' "$out_plant" | python3 -c '
import re, sys
for line in sys.stdin:
    m = re.match(r"^\s+❌ (.*?) (?:\[\d+s\] )?— ", line)
    if m: print(re.sub(r" +", " ", m.group(1)).strip())
')"
n_names=$(printf '%s\n' "$names" | grep -c . || true)
tail12="$(printf '%s\n' "$out_plant" | tail -12)"

# V4 — each broken pair must appear in the BLOCKED line of the last 12 lines WITH its own
# «(rc=N, Ns)»: a summary naming every pair but carrying the numbers for only one would be decorative.
if [ "$n_names" -eq 0 ]; then
  no "V4 planted arm printed no per-pair ❌ line — nothing to look for"
else
  v4miss="$(TAIL="$tail12" NAMES="$names" python3 -c '
import os, re
blk = [l for l in os.environ["TAIL"].splitlines() if "BLOCKED" in l]
line = re.sub(r" +", " ", blk[-1]) if blk else ""
for nm in os.environ["NAMES"].splitlines():
    if nm and not re.search(re.escape(nm) + r" \(rc=\d+, \d+s\)", line):
        print(" | " + nm)
' | tr -d '\n')"
  if [ -z "$v4miss" ]; then ok "V4 last 12 lines name all $n_names broken pair(s), each with (rc=, Ns)"
  else no "V4 BLOCKED line in the last 12 lines lacks name+(rc=, Ns) for:$v4miss"; fi
fi

# V5
pair_lines=$(printf '%s\n' "$out_plant" | grep -E '^\s+(✅|❌) ' | grep -vE 'BLOCKED' || true)
n_pair=$(printf '%s\n' "$pair_lines" | grep -c . || true)
n_stamped=$(printf '%s\n' "$pair_lines" | grep -cE '\[[0-9]+s\]' || true)
if [ "$n_pair" -ge 10 ] && [ "$n_pair" -eq "$n_stamped" ]; then ok "V5 all $n_pair pair lines carry [Ns]"
else no "V5 pair lines stamped $n_stamped of $n_pair (want all, at least 10)"; fi

# V6 selfcheck's renderer, extracted and run on the planted output
fn="$(awk '/^_show_failure\(\) \{/{f=1} f{print} f&&/^\}/{exit}' "$SELFCHECK")"
if [ -z "$fn" ]; then
  no "V6 _show_failure not found in selfcheck.sh"
else
  shown="$(eval "$fn"; _show_failure "$out_plant" 2>&1)"
  sq="$(printf '%s\n' "$shown" | sed 's/  */ /g')"
  miss6=""
  while IFS= read -r nm; do
    [ -n "$nm" ] || continue
    case "$sq" in *"$nm"*) ;; *) miss6="$miss6 | $nm" ;; esac
  done <<EOF
$names
EOF
  if [ "$n_names" -gt 0 ] && [ -z "$miss6" ]; then ok "V6 selfcheck renderer shows all broken pair names"
  else no "V6 selfcheck renderer misses:${miss6:- (no names to check)}"; fi
fi

# V7 the prepush-guard block in selfcheck renders through _show_failure (comment lines ignored, so a
# commented-out call does not count; any tail -N in live lines is refused, not only tail -12)
blk="$(awk '/_pg_out="\$\(bash scripts\/prepush_guard_check.sh/{f=1} f{print} f&&/^fi$/{exit}' "$SELFCHECK" \
       | grep -vE '^[[:space:]]*#' || true)"
if [ -z "$blk" ]; then no "V7 prepush-guard block not found in selfcheck.sh"
elif ! printf '%s\n' "$blk" | grep -m1 -E '^[[:space:]]*_show_failure "\$_pg_out"' >/dev/null; then
  no "V7 selfcheck prepush block does not call _show_failure"
elif printf '%s\n' "$blk" | grep -m1 -E 'tail -[0-9]' >/dev/null; then
  no "V7 selfcheck prepush block still truncates with tail -N"
else ok "V7 selfcheck prepush block renders through _show_failure"; fi

echo
echo "prepush-guard failure visibility: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]

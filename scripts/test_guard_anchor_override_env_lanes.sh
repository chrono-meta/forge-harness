#!/usr/bin/env bash
# test_guard_anchor_override_env_lanes.sh — the two guard anchors must measure the hook as it behaves by default,
# whatever override the calling shell has exported.
#
# Why (2026-11-15, reported from a field harness intake, pmh-dev #91 item 2): the pre-commit hook calls
# universal_guard_check.sh with `env -u GIT_INDEX_FILE -u GIT_DIR -u GIT_WORK_TREE` but not `-u PUBLIC_SURFACE_OK`.
# A commit made with PUBLIC_SURFACE_OK=1 that stages the hook or the pattern source then runs the anchor with the
# override inherited: the hook under test lets its own planted leaks through, the anchor's known pairs break, and
# the commit is blocked for a reason that has nothing to do with the change. Measured on main 3572903:
#   universal_guard_check.sh  plain rc=0 · PUBLIC_SURFACE_OK=1 rc=1
#   prepush_guard_check.sh    plain rc=0 · PUBLIC_SURFACE_OK=1 rc=1
# The fix is inside each anchor (it unsets the hook overrides before building its sandbox), so every caller —
# the hook, selfcheck, CI, a person — gets the same verdict.
#
# Lanes:
#   A1/P1  anchor with PUBLIC_SURFACE_OK=1 exported → rc 0 (the default-hook verdict)
#   A2/P2  anchor with every other hook override exported at once → rc 0
#   A3/P3  the two non-override inputs the pre-push hook reads (PSA_PATTERNS, FH_DESTRUCTIVE_BASE) → rc 0
#   A4/P4  PSA_ALLOWLIST naming the anchors' own planted positive → rc 0
#   A0/P0  control: the same anchor with no override → rc 0 (if this is red, the anchor is broken, not this lane)
#   R1/R2  revert probes: a copy of each anchor with its unset line removed, PUBLIC_SURFACE_OK=1 → rc ≠ 0
#          (proves A1/P1 are green because of the fix, not because the override stopped mattering)
# Exit 0 all lanes pass · 1 a lane failed · 2 harness error.
set -uo pipefail
source "$(dirname "$0")/fixture_guard_lib.sh" 2>/dev/null || { echo "HARNESS-ERROR: fixture_guard_lib.sh not found"; exit 2; }
ROOT=$(cd "$(dirname "$0")/.." 2>/dev/null && pwd) || { echo "HARNESS-ERROR: cannot resolve the repo root"; exit 2; }
cd "$ROOT" || exit 2
UG=scripts/universal_guard_check.sh; PG=scripts/prepush_guard_check.sh
for f in "$UG" "$PG"; do [ -f "$f" ] || { echo "HARNESS-ERROR: $f missing"; exit 2; }; done
OTHERS="DESTRUCTIVE_OP_OK=1 FH_NOVELTY_OK=1 MAIN_PUSH_OK=1 PUSH_ZONE_OK=1 TAG_VERSION_OK=1 TRACKS_GITLINK_OK=1 TRACKS_PUBLIC_OK=1"
pass=0; fail=0
lane() {   # $1 id · $2 want (0 | nonzero) · $3… command
  local id="$1" want="$2"; shift 2
  local out rc; out=$("$@" 2>&1); rc=$?
  if { [ "$want" = 0 ] && [ "$rc" -eq 0 ]; } || { [ "$want" = nonzero ] && [ "$rc" -ne 0 ]; }; then
    pass=$((pass+1)); echo "  ✅ $id (rc=$rc)"
  else
    fail=$((fail+1)); echo "  ❌ $id — want rc $want, got rc=$rc"; printf '%s\n' "$out" | grep -E '❌' | head -4 | sed 's/^/       /'
  fi
}
echo "guard-anchor override-env lanes"
lane A0 0 env -u PUBLIC_SURFACE_OK bash "$UG"
lane A1 0 env PUBLIC_SURFACE_OK=1 bash "$UG"
lane A2 0 env $OTHERS bash "$UG"
lane P0 0 env -u PUBLIC_SURFACE_OK bash "$PG"
lane P1 0 env PUBLIC_SURFACE_OK=1 bash "$PG"
lane P2 0 env $OTHERS bash "$PG"
# R1 revert probe — run the copy from the real scripts/ dir so its relative lookups resolve the same way.
lane A3 0 env PSA_PATTERNS=/dev/null FH_DESTRUCTIVE_BASE=HEAD bash "$UG"
lane P3 0 env PSA_PATTERNS=/dev/null FH_DESTRUCTIVE_BASE=HEAD bash "$PG"
AL=$(mktemp) || { echo "HARNESS-ERROR: mktemp"; exit 2; }
printf 'notes.md\tzzsynthoperator\n' > "$AL"   # an allowlist row naming the anchors' own planted positive
lane A4 0 env PSA_ALLOWLIST="$AL" bash "$UG"
lane P4 0 env PSA_ALLOWLIST="$AL" bash "$PG"
RV="scripts/.rv_universal_guard_check_$$.sh"; RVP="scripts/.rv_prepush_guard_check_$$.sh"
trap 'rm -f "$RV" "$RVP" "$AL"' EXIT
# The revert runs start from a clean baseline (codex R2): the copy lacks the WHOLE fix line, so any inherited
# override or PSA_ input would otherwise turn its «plain» control red for a reason that is not the probe.
CLEAN_ENV="-u PUBLIC_SURFACE_OK -u DESTRUCTIVE_OP_OK -u FH_NOVELTY_OK -u MAIN_PUSH_OK -u PUSH_ZONE_OK -u TAG_VERSION_OK -u TRACKS_GITLINK_OK -u TRACKS_PUBLIC_OK -u FH_DESTRUCTIVE_BASE"
for _v in $(compgen -v | grep '^PSA_'); do CLEAN_ENV="$CLEAN_ENV -u $_v"; done
revert_probe() {   # $1 id · $2 subject · $3 copy path
  # A red copy proves the fix only if the copy is a working anchor minus exactly the unset line (codex R1):
  #   ① the copy was written and differs from the subject by exactly one removed line
  #   ② the copy is green with no override (it still runs and its pairs hold)
  #   ③ with PUBLIC_SURFACE_OK=1 it is red AND prints a known-pair ❌ line (a broken pair, not a crash)
  local want_rm out rc
  if ! grep -v '^unset .*PUBLIC_SURFACE_OK' "$2" > "$3" || [ ! -s "$3" ]; then
    fail=$((fail+1)); echo "  ❌ $1 — could not write the reverted copy"; return; fi
  want_rm=$(diff "$2" "$3" | grep -c '^<')
  if [ "$want_rm" -ne 1 ] || [ "$(diff "$2" "$3" | grep -c '^>')" -ne 0 ]; then
    fail=$((fail+1)); echo "  ❌ $1 — reverted copy differs by $want_rm removed line(s), want exactly 1"; return; fi
  out=$(env $CLEAN_ENV bash "$3" 2>&1); rc=$?
  if [ "$rc" -ne 0 ]; then fail=$((fail+1)); echo "  ❌ $1 — reverted copy is red even without the override (rc=$rc) — it is not a working anchor"; return; fi
  out=$(env $CLEAN_ENV PUBLIC_SURFACE_OK=1 bash "$3" 2>&1); rc=$?
  if [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -q '❌'; then
    pass=$((pass+1)); echo "  ✅ $1 (reverted copy: green plain · rc=$rc with the override, $(printf '%s\n' "$out" | grep -c '❌') ❌ line(s))"
  else
    fail=$((fail+1)); echo "  ❌ $1 — reverted copy with the override: rc=$rc, ❌ lines $(printf '%s\n' "$out" | grep -c '❌') (want red with a known-pair line)"
  fi
}
revert_probe R1 "$UG" "$RV"
revert_probe R2 "$PG" "$RVP"
echo "guard-anchor override-env lanes: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

#!/usr/bin/env bash
# test_liveness_echo_token_lanes.sh — anchor for the EVIDENCE/VERDICT token seam in
# scripts/test_prepush_destructive_liveness.sh.
#
# tenet: FH-T02 (기계는 채널에만 — 여기서는 «증거 줄과 판정 줄이 같은 채널을 쓰나»)
#
# ── WHAT THIS ANCHORS ────────────────────────────────────────────────────────────────────────
# Two roles, individually correct, sharing one glyph ([[feedback_two_roles_one_file_unowned_conflict]]):
#   · scripts/selfcheck.sh decides a suite FAILED by grepping its output for `❌`
#     (_show_failure; and the lane loop streams suite stdout straight into the CI log).
#   · test_prepush_destructive_liveness.sh is a REVERT PROBE. Its evidence IS a red line — it
#     disables a guard and re-prints the lane that went red as proof the anchor is not decorative.
# Measured 2026-09-19 (run 35426860480): `✅ P4 delete INTEGRATION branch` and
# `❌ P4 delete INTEGRATION branch` landed two seconds apart in the same log, BOTH correct, and the
# lane was misattributed twice in a row by a human reading it. Nothing was broken; the log was
# unreadable. The mechanical half was still open: if that probe ever exits non-zero, the
# aggregator's report mixes intended reds with real ones and has no way to tell them apart.
#   신호 정본: tracks/_meta/fh_signal_2026-09-19_liveness-echo-collides-with-verdict.md §4·§5
#
# ── THE INVARIANT ────────────────────────────────────────────────────────────────────────────
#   `❌` appears in that probe's stdout only on lines THE PROBE AUTHORED, at column 0.
#   Everything re-printed from a subject suite is indented `   | ` and its reds read
#   `[expected-red]` (the probe's `_echo_evidence`).
# Two consequences, and this file asserts BOTH directions:
#   ⓐ a GREEN probe run emits ZERO `❌`            → L1
#   ⓑ in a RED probe run every `❌` is REAL         → L2 · L3 (forced non-zero, two branches)
#
# 🟥 SUBSTITUTION, NOT DELETION. "No `❌` in the output" is trivially satisfied by deleting the
# echo — which would destroy the probe's whole evidentiary value. So every lane below ALSO asserts
# the re-tokenised evidence line is still THERE ([[feedback_deletion_beats_repair_dead_filter]] is
# about dead filters; this is its inverse — a filter that eats the payload).
#
# 🟥 WHY THE FIX IS IN THE PROBE AND NOT IN THE AGGREGATOR. An exemption list in selfcheck
# ("liveness is special") leaks at the next revert probe; re-tokenising at the source does not.
# This anchor therefore never reads selfcheck.sh — it pins the PROBE's output contract, which is
# what any aggregator (today's grep, tomorrow's parser, a human's eye) actually consumes.
#
# ── COST, STATED RATHER THAN HIDDEN ──────────────────────────────────────────────────────────
# L1 and R2 each execute the REAL probe against the REAL tree (~15s each; the probe runs its
# subject suite four times), so this suite costs ~35s. They are not mocked on purpose: L1 is the
# arm that reproduces the CI observation, and a stub standing in for the subject is the
# "실물 아닌 테스트 더블을 잼" half of [[feedback_anchor_can_be_decorative]]. L2/L3/R1 use fixtures
# because their branches are unreachable against a healthy real tree, and they are fast.
#
# Usage: bash scripts/test_liveness_echo_token_lanes.sh   Exit: 0 = contract holds; 1 = regression.

set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROBE="$REPO_ROOT/scripts/test_prepush_destructive_liveness.sh"
LIB="$REPO_ROOT/scripts/fixture_guard_lib.sh"
HOOK="$REPO_ROOT/templates/.git-hooks/pre-push"
. "$LIB" 2>/dev/null || { echo "❌ HARNESS-ERROR — cannot source $LIB"; exit 1; }

FAIL=0; N=0
ok()  { N=$((N+1)); printf '✅ %s\n' "$1"; }
no()  { N=$((N+1)); printf '❌ %s\n' "$1"; FAIL=1; }

# ── HARNESS GUARDS — an absent instrument is not a pass ──────────────────────────────────────
for f in "$PROBE" "$LIB" "$HOOK"; do
  [ -f "$f" ] || { echo "❌ HARNESS-ERROR — missing: $f (absent is NOT a pass)"; exit 1; }
done
# Instrument calibration: if the helper this file pins is gone, every lane below would pass or fail
# for a reason that has nothing to do with the contract. Say so instead of scoring.
if ! grep -q '^_echo_evidence()' "$PROBE"; then
  echo "❌ HARNESS-ERROR — _echo_evidence() not defined in $PROBE."
  echo "   That helper IS the contract this file anchors. Either it was renamed (re-point this"
  echo "   anchor) or the repair was reverted (restore it) — do not delete this suite."
  exit 1
fi
command -v python3 >/dev/null 2>&1 || { echo "❌ HARNESS-ERROR — python3 absent; the probe's stage ① needs it"; exit 1; }

# ── grep shapes, defined once ────────────────────────────────────────────────────────────────
# Echoed lines wear the `   | ` prefix; the probe's own verdicts sit at column 0.
#
# 🟥 `grep -c` returns rc=1 on a legitimate ZERO and rc≥2 on a real ERROR, and under `pipefail` a
# bare `|| true` would fold BOTH into "0" — i.e. a broken grep would read as "no violations found",
# which is this repo's most-named defect ([[feedback_not_found_is_not_zero_family]]). So rc is
# captured and the two are SPLIT: a genuine zero prints `0`, an error prints `ERR`. `ERR` cannot
# satisfy any `-eq`/`-ge` test, so every caller falls to its `no()` branch — loud, not silent.
# Verified by the K0 known pair below, not assumed.
_count() {   # $1 = ERE, $2 = text → count, or ERR
  local n rc
  n=$(printf '%s\n' "$2" | grep -cE "$1"); rc=$?
  case "$rc" in 0|1) printf '%s' "$n" ;; *) printf 'ERR' ;; esac
}
_n_echoed_red()  { _count '^   \|.*❌'                 "$1"; }
_n_echoed_tok()  { _count '^   \|.*\[expected-red\]'   "$1"; }
_n_own_red()     { _count '^❌'                        "$1"; }
_n_any_red()     { _count '❌'                         "$1"; }

# ── FIXTURE BUILDER — a throwaway repo whose SUITE is a stub, so the probe's red branches are
# reachable. The pre-push hook is COPIED FROM THE REAL TREE, not hand-written: the probe's stage ①
# looks for a verbatim GUARD_LINE, and a mental-model fixture would drift out from under it
# ([[feedback_fixture_shape_from_artifact_not_mental_model]]).
_build_fixture() {   # $1 = probe source file to install; $2 = stub suite body → echoes fixture root
  local probe_src="$1" stub_body="$2" F
  F="$(fh_fixture_root "$(mktemp -d)")" || return 1
  mkdir -p "$F/scripts" "$F/templates/.git-hooks" || return 1
  cp "$LIB"   "$F/scripts/fixture_guard_lib.sh"   || return 1
  cp "$probe_src" "$F/scripts/test_prepush_destructive_liveness.sh" || return 1
  cp "$HOOK"  "$F/templates/.git-hooks/pre-push"  || return 1
  printf '%s\n' "$stub_body" > "$F/scripts/test_prepush_destructive_lanes.sh" || return 1
  git -C "$F" init -q >/dev/null 2>&1 || return 1
  printf '%s\n' "$F"
}
# Stubs. Both print a red line so there is something to re-tokenise; they differ in EXIT CODE and
# in whether the lane name matches, which is what selects the probe's branch.
_STUB_WRONG='#!/usr/bin/env bash
echo "  ❌ Z9 some unrelated lane  → BLOCK — expected block, got pass"
echo "prepush-destructive 캘리브레이션: 11 passed, 1 failed (12 pairs)"
exit 1'
# rc=0 WITH a red line on stdout is not contrived — that is exactly the decorative shape the probe
# exists to catch (a suite that prints a failure and still reports success).
_STUB_DECOR='#!/usr/bin/env bash
echo "  ❌ P4 delete INTEGRATION branch (main)  → BLOCK — expected block, got pass"
echo "prepush-destructive 캘리브레이션: 11 passed, 1 failed (12 pairs)"
exit 0'

_TMPS=""
trap 'for d in $_TMPS; do rm -rf "$d"; done' EXIT

_run_fixture() {   # $1 = probe source; $2 = stub → sets _FRC/_FOUT
  local F
  F="$(_build_fixture "$1" "$2")" || { _FRC=99; _FOUT="fixture build failed"; return 1; }
  _TMPS="$_TMPS $F"
  _FOUT=$( cd "$F" && bash scripts/test_prepush_destructive_liveness.sh 2>&1 ); _FRC=$?
  return 0
}

# ── K0 — KNOWN PAIR FOR THE COUNTERS THEMSELVES ──────────────────────────────────────────────
# Every lane below is an arithmetic comparison against these four functions. A counter stuck at 0
# would make "zero echoed ❌" green by construction, and a counter that cannot tell a zero from an
# error would do it silently. Both directions are measured on a hand-built sample whose answers are
# known by eye ([[feedback_control_presence_is_not_discrimination]]).
_K0=$(printf '%s\n' \
  '❌ own verdict at column 0' \
  '   |   [expected-red] echoed red, re-tokenised' \
  '   | plain echoed line' \
  '   |   ❌ echoed red, RAW — the defect shape' \
  '✅ a green line')
_k0fail=0
_k0() { # $1=label $2=got $3=want
  N=$((N+1))
  if [ "$2" = "$3" ]; then printf '✅ K0 %s → %s\n' "$1" "$2"
  else printf '❌ K0 %s → %s (want %s)\n' "$1" "$2" "$3"; FAIL=1; _k0fail=1; fi
}
_k0 "own-red counts column-0 only"        "$(_n_own_red    "$_K0")" 1
_k0 "echoed-red counts the raw echo only" "$(_n_echoed_red "$_K0")" 1
_k0 "echoed-token counts the re-tokenised" "$(_n_echoed_tok "$_K0")" 1
_k0 "any-red counts both ❌ lines"         "$(_n_any_red    "$_K0")" 2
_k0 "known-negative: no ❌ at all → 0"     "$(_n_any_red    "only green here")" 0
# The error/zero split itself — an invalid ERE makes grep exit 2. Must read ERR, never 0.
_k0 "grep ERROR reads ERR, not 0"          "$(_count '[' "$_K0" 2>/dev/null)" ERR
if [ "$_k0fail" -ne 0 ]; then
  echo "❌ HARNESS-ERROR — the counters this suite decides with are miscalibrated."
  echo "   Every lane below would be scored by a broken instrument. Refusing to report them."
  exit 1
fi

# ── ⓪ STUB CALIBRATION — known-positive for the fixtures themselves ──────────────────────────
# Without this, lanes L2/L3 ("no echoed ❌") are satisfiable by a stub that never emitted one.
# Presence of a control is not discrimination ([[feedback_control_presence_is_not_discrimination]]).
_stubdir="$(fh_fixture_root "$(mktemp -d)")" && _TMPS="$_TMPS $_stubdir"
printf '%s\n' "$_STUB_WRONG" > "$_stubdir/s.sh"
_sout=$(bash "$_stubdir/s.sh" 2>&1); _src=$?
if [ "$(_n_any_red "$_sout")" -ge 1 ] && [ "$_src" -ne 0 ]; then
  ok "⓪ stub calibration — the stub really emits ❌ and exits $_src (so L2/L3 can fail)"
else
  no "⓪ stub calibration — stub emits $(_n_any_red "$_sout") ❌ / rc=$_src; L2/L3 would be vacuous"
fi

echo "── S — FORM: no echo path bypasses the helper ──"
# 🟥 NAMED RESIDUAL THIS CLOSES. L1/L2/L3 execute the FOUR echo branches that exist today. They are
# structurally blind to a FIFTH one added tomorrow — a new failure branch that pipes captured suite
# output through a bare `sed 's/^/…'` would leak raw `❌` again and every lane above would stay
# green ([[feedback_three_reasons_a_lane_is_green]] reason ②: the input never reaches the control).
# So this is a FORM check on the source, deliberately, not a behaviour check: it asserts the
# PROPERTY that all evidence leaves through one door. It is a channel check, not a verdict check
# (CLAUDE.md §Mechanization Boundary) — it says nothing about whether the output is correct.
# Degrade direction: the pattern is narrow (a prefix-sed on a pipe), so it UNDER-blocks — a novel
# spelling slips past. Under-blocking is the loud-later direction; over-blocking here would train
# authors to route around the helper, which is the thing being prevented.
_raw_echo=$(grep -nE "\| *sed +['\"]s/\^/" "$PROBE"); _raw_rc=$?
if [ "$_raw_rc" -eq 1 ]; then
  ok "S1 no bare prefix-sed remains in the probe — every evidence echo goes through _echo_evidence"
elif [ "$_raw_rc" -eq 0 ]; then
  no "S1 an evidence echo bypasses _echo_evidence — it will leak raw ❌ into the aggregator:"
  printf '%s\n' "$_raw_echo" | sed 's/^/       /'
else
  no "S1 could not scan $PROBE (grep rc=$_raw_rc) — UNMEASURED, not clean"
fi
# Known-negative for S1 itself: re-introduce the shape in a copy and require the scan to FIRE.
# Without this, "0 hits" is indistinguishable from a pattern that matches nothing at all.
_S1DIR="$(fh_fixture_root "$(mktemp -d)")" && _TMPS="$_TMPS $_S1DIR"
{ cat "$PROBE"; printf '%s\n' "echo x | sed 's/^/   | /'"; } > "$_S1DIR/p.sh"
if grep -qE "\| *sed +['\"]s/\^/" "$_S1DIR/p.sh"; then
  ok "S1-cal known-negative: the scan FIRES on a re-introduced bare prefix-sed (so S1 can fail)"
else
  no "S1-cal the scan does not fire on a planted violation — S1 is decorative, 0 hits means nothing"
fi

echo "── ⓐ GREEN RUN (the live arm — this is the run that fired in CI) ──"

# ── L1 — a PASSING probe run emits zero ❌, and still shows its evidence ──────────────────────
LOUT=$(bash "$PROBE" 2>&1); LRC=$?
if [ "$LRC" -ne 0 ]; then
  no "L1 PRECONDITION — the real probe exited $LRC; this lane measures a GREEN run, so it cannot"
  echo "     score. Fix the probe first; a red probe makes L1 UNCALIBRATED, not FAILED."
else
  if [ "$(_n_any_red "$LOUT")" -eq 0 ]; then
    ok "L1 green run emits 0 ❌ — the aggregator's failure glyph is absent from a passing probe"
  else
    no "L1 green run emits $(_n_any_red "$LOUT") ❌ — a PASSING probe is planting the aggregator's"
    printf '%s\n' "$LOUT" | grep -n '❌' | sed 's/^/       /'
  fi
  if [ "$(_n_echoed_tok "$LOUT")" -ge 1 ]; then
    ok "L1-b evidence survived as [expected-red] — substituted, not deleted"
  else
    no "L1-b no [expected-red] line — the red evidence was not re-tokenised (deleted, or still raw ❌)"
  fi
  # 🟥 Anchored on an ECHOED line (`^   | `), not on the glyph anywhere: the probe's own final
  # banner also contains `캘리브레이션`, so a file-wide grep would pass even with the echo deleted.
  # That would have been a decorative assertion — caught while writing this, by asking what the
  # control would report if the thing it measures were removed.
  if printf '%s\n' "$LOUT" | grep -qE '^   \|.*캘리브레이션'; then
    ok "L1-c the subject's 캘리브레이션 line is still echoed — that companion line is what"
    echo "     identified the SOURCE of the red in the 2026-09-19 misattribution (신호 §3)"
  else
    no "L1-c the 캘리브레이션 line is not present as an ECHOED (\`   | \`) line — it was either"
    echo "     deleted, or printed outside the evidence-echo shape. Both break the same thing:"
    echo "     that companion line is what identified the SOURCE of the red (신호 §3)."
  fi
fi

echo "── ⓑ RED RUNS (forced non-zero — every ❌ must be the probe's own) ──"

# ── L2 — branch: suite went red on the WRONG lane ─────────────────────────────────────────────
_run_fixture "$PROBE" "$_STUB_WRONG"
if [ "$_FRC" -eq 0 ]; then
  no "L2 PRECONDITION — forcing failed: the probe exited 0 against a wrong-lane stub"
else
  W_OUT="$_FOUT"
  [ "$(_n_own_red "$W_OUT")" -ge 1 ] \
    && ok "L2-a probe's OWN verdict is still ❌ at column 0 (rc=$_FRC) — a real failure stays loud" \
    || no "L2-a probe went red (rc=$_FRC) with NO ❌ verdict line — the aggregator would miss it"
  [ "$(_n_echoed_red "$W_OUT")" -eq 0 ] \
    && ok "L2-b ZERO echoed ❌ — intended red and real red are distinguishable in one report" \
    || { no "L2-b $(_n_echoed_red "$W_OUT") echoed ❌ — a red probe mixes intended with real"
         printf '%s\n' "$W_OUT" | grep -E '^   \|.*❌' | sed 's/^/       /'; }
  [ "$(_n_echoed_tok "$W_OUT")" -ge 1 ] \
    && ok "L2-c evidence kept as [expected-red]" \
    || no "L2-c no [expected-red] in the echo — evidence was not re-tokenised (deleted, or still raw)"
fi

# ── L3 — branch: suite exited 0 (DECORATIVE ANCHOR). Separate lane because it is a DIFFERENT
# call site reached for a different reason ([[feedback_candidate_list_completeness]]).
_run_fixture "$PROBE" "$_STUB_DECOR"
if [ "$_FRC" -eq 0 ]; then
  no "L3 PRECONDITION — forcing failed: the probe exited 0 against a decorative stub"
else
  D_OUT="$_FOUT"
  [ "$(_n_own_red "$D_OUT")" -ge 1 ] \
    && ok "L3-a DECORATIVE branch: own verdict still ❌ at column 0 (rc=$_FRC)" \
    || no "L3-a DECORATIVE branch went red with no ❌ verdict line"
  [ "$(_n_echoed_red "$D_OUT")" -eq 0 ] \
    && ok "L3-b DECORATIVE branch: zero echoed ❌" \
    || { no "L3-b DECORATIVE branch leaks $(_n_echoed_red "$D_OUT") echoed ❌"
         printf '%s\n' "$D_OUT" | grep -E '^   \|.*❌' | sed 's/^/       /'; }
  [ "$(_n_echoed_tok "$D_OUT")" -ge 1 ] \
    && ok "L3-c DECORATIVE branch: evidence kept as [expected-red]" \
    || no "L3-c DECORATIVE branch: no [expected-red] — evidence not re-tokenised (deleted, or still raw)"
fi

# ── ⓒ REVERT PROBES — is the repair load-bearing, or is this suite decorative? ────────────────
# Disable the ONE thing the repair added (the substitution inside _echo_evidence) and require the
# lanes above to go red — and require nothing else to move ([[feedback_anchor_can_be_decorative]]:
# 적용확인 → 실행 → 복원). Applied to a COPY; the real tree is never mutated (shared checkout).
_REV="$(fh_fixture_root "$(mktemp -d)")" && _TMPS="$_TMPS $_REV"
mkdir -p "$_REV/scripts"
cp "$LIB" "$_REV/scripts/fixture_guard_lib.sh"
# The mutation is the inverse of the repair and nothing else: the substitution becomes a NO-OP
# (`❌` → `❌`) while the `   | ` prefix stays. Done with python3 LITERAL string replacement rather
# than sed, for the same reason the probe itself does — a regex here would have to escape `[`, `]`,
# `^` and a multi-byte glyph, and a mis-escape fails by silently not applying, which is precisely
# the "unapplied mutation reads as a passing revert probe" hole.
_MUT_TARGET="s/❌/[expected-red]/g"
MUT_TARGET="$_MUT_TARGET" python3 - "$PROBE" "$_REV/scripts/test_prepush_destructive_liveness.sh" <<'PY'
import os, sys
src = open(sys.argv[1]).read()
old = os.environ['MUT_TARGET']
if old not in src:
    sys.stderr.write("revert target not found\n"); sys.exit(3)
open(sys.argv[2], 'w').write(src.replace(old, 's/❌/❌/g', 1))
PY
_mrc=$?
# 🟥 APPLY CHECK — an unapplied mutation makes "still red" mean nothing, which is the exact defect
# the probe under test spends its whole stage ① on.
if [ "$_mrc" -ne 0 ]; then
  no "R0 REVERT MUTATION FAILED (rc=$_mrc) — the substitution expression was reworded; re-point"
  echo "     _MUT_TARGET in this file. R1/R2 prove nothing until it applies."
  _REV_OK=0
elif grep -qF "$_MUT_TARGET" "$_REV/scripts/test_prepush_destructive_liveness.sh"; then
  no "R0 REVERT MUTATION NOT APPLIED — the substitution is still in the copy; R1/R2 prove nothing"
  _REV_OK=0
elif ! grep -qF "   | " "$_REV/scripts/test_prepush_destructive_liveness.sh"; then
  no "R0 REVERT MUTATION OVERSHOT — it removed the \`   | \` prefix too; R1/R2 would measure two"
  echo "     changes at once and could not attribute their result."
  _REV_OK=0
else
  ok "R0 revert mutation applied to a copy (substitution neutered, prefix untouched)"
  _REV_OK=1
fi

if [ "$_REV_OK" -eq 1 ]; then
  # R1 — fixture/red arm.
  _run_fixture "$_REV/scripts/test_prepush_destructive_liveness.sh" "$_STUB_WRONG"
  if [ "$_FRC" -eq 0 ]; then
    no "R1 PRECONDITION — reverted copy exited 0 against the wrong-lane stub"
  else
    [ "$(_n_echoed_red "$_FOUT")" -ge 1 ] \
      && ok "R1 revert: L2-b goes RED without the substitution ($(_n_echoed_red "$_FOUT") echoed ❌) — repair is load-bearing" \
      || no "R1 revert: removing the substitution changed NOTHING — L2-b is decorative"
    # Locality: the probe's VERDICT must be unchanged by the revert. Only the token assertion flips.
    [ "$(_n_own_red "$_FOUT")" -ge 1 ] \
      && ok "R1-b locality: the reverted copy still fails for the same reason (rc=$_FRC, own ❌ present)" \
      || no "R1-b locality: the revert changed the probe's VERDICT too — the mutation is not surgical"
  fi

  # R2 — live/green arm. This is the path that actually fired in CI, and it is a different call
  # site from R1's, so R1 does not cover it.
  RVOUT=$( cd "$REPO_ROOT" && bash "$_REV/scripts/test_prepush_destructive_liveness.sh" 2>&1 ); RVRC=$?
  if [ "$RVRC" -ne 0 ]; then
    no "R2 PRECONDITION — reverted copy exited $RVRC on the live tree; expected a green run"
    printf '%s\n' "$RVOUT" | tail -6 | sed 's/^/       /'
  else
    [ "$(_n_any_red "$RVOUT")" -ge 1 ] \
      && ok "R2 revert: L1 goes RED without the substitution ($(_n_any_red "$RVOUT") ❌ in a PASSING run)" \
      || no "R2 revert: L1 unchanged by the revert — L1 is decorative"
    ok "R2-b locality: reverted copy still exits 0 — the revert moved the TOKEN, not the verdict"
  fi
fi

echo
if [ "$FAIL" -eq 0 ]; then
  echo "LIVENESS-ECHO-TOKEN LANES: PASS ($N lanes)"
else
  echo "LIVENESS-ECHO-TOKEN LANES: FAIL ($N lanes)"
fi
exit $FAIL

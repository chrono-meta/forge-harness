#!/usr/bin/env bash
# test_probe_live_eval_lanes.sh — regression lanes for scripts/probe_live_eval.sh's SCORER and
# SELECTOR (scripts/probe_live_eval_lib.py). Never calls `claude` and spawns no live session —
# this pins the scoring logic and the probes.md/probes_live.yaml cross-reference against fixture
# text, exactly the split ablation_calibrate.sh's own header argues for ("the pair gates the
# runner; the runner never gates itself" — applied here to the scorer instead of a sim runner).
#
# LANE CLASSES
#   score-pair     known-pair calibration of score_probe(): PASS / FAIL / UNCALIBRATED(present) /
#                  UNCALIBRATED(absent) / FAILED-TO-RUN, both empty-string and missing-file shapes
#   select-guard   the mechanical selection rule (class filter, utterance-shape, INERT-ANCHOR,
#                  CLI-event / arm-capability / arm-state excludes) reproduces the CURRENT
#                  13-selected / 20-excluded split against the REAL probes.md + probes_live.yaml
#                  shipped in this repo. The numbers are PINNED, not derived — see the S2 note.
#   blackout       a whole run whose every probe was silent in BOTH arms is UNCALIBRATED, not a
#                  wall of FAIL; the boundary and its deliberate narrowness are pinned by BL1-BL5
#   control-b      the optional second known-negative, incl. its fail-closed degrade (a declared
#                  second control that did not run is FAILED-TO-RUN, never a quiet PASS)
#   advisory       advisory_re is recorded and never moves a verdict
#   dead-pointer   probes_live.yaml naming an id absent from probes.md is caught (nonzero exit),
#                  not silently ignored — this IS the "id 가 probes.md 에 실재하는지" guard the
#                  dispatching session's task named explicitly
#   dry-run        `--dry-run` on the real files exits 0 and touches nothing under run/ (no live
#                  network call, no OUTDIR created)
#
# exit: 0 = all lanes as expected · 1 = regression · 10 = harness error (setup failed, not a verdict)

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$REPO_ROOT/scripts/probe_live_eval_lib.py"
RUNNER="$REPO_ROOT/scripts/probe_live_eval.sh"
PROBES_MD="$REPO_ROOT/.claude/regression/probes.md"
PROBES_LIVE="$REPO_ROOT/.claude/regression/probes_live.yaml"

command -v python3 >/dev/null 2>&1 || { echo "❌ HARNESS-ERROR — python3 missing"; exit 10; }
[ -f "$LIB" ]    || { echo "❌ HARNESS-ERROR — $LIB missing"; exit 10; }
[ -f "$RUNNER" ] || { echo "❌ HARNESS-ERROR — $RUNNER missing"; exit 10; }
# 🟥 ADJACENT FINDING, fixed here 2026-09-14 because this file is shipped and was failing OPEN in
# the wrong direction. `package.json` files[] packs probe_live_eval.sh, probe_live_eval_lib.py,
# THIS FILE and probes_live.yaml — but NOT `.claude/regression/probes.md` (verified with
# `npm pack --dry-run --json`: the only packed `probes.md` is the unrelated
# tests/seam_absence_probes.md). The RUNNER already degrades correctly on that
# (`[ -f "$PROBES_MD" ] || exit 2`); this suite had no such guard, so in a consumer install the
# select lanes crashed with a FileNotFoundError traceback and the suite printed
# **RESULT: REGRESSION** — reporting a missing fixture as a broken harness. exit 10 is the value
# this file's own header reserves for exactly this ("harness error (setup failed, not a verdict)").
# 🟥 This does NOT decide whether probes.md should ship. That is an operator call and is untouched;
# what changes is only that the non-answer stops rendering as a verdict.
[ -f "$PROBES_MD" ] || { echo "❌ HARNESS-ERROR — $PROBES_MD missing (not shipped in the npm package; the select/dry-run lanes need the hub repo)"; exit 10; }
[ -f "$PROBES_LIVE" ] || { echo "❌ HARNESS-ERROR — $PROBES_LIVE missing"; exit 10; }

T="$(mktemp -d)" || { echo "❌ HARNESS-ERROR — mktemp failed"; exit 10; }
trap 'rm -rf "$T"' EXIT

# Snapshot the LIVE evidence dir BEFORE any lane runs, so EV8 can prove this suite did not deposit
# into it. Taken here, at the top, because a snapshot taken next to its own assertion proves
# nothing. "ABSENT" and "0" are different states and stay different.
_LIVE_EV_DIR="$REPO_ROOT/tracks/_meta/live_eval_runs"
if [ -d "$_LIVE_EV_DIR" ]; then
  LIVE_EV_BEFORE="$(find "$_LIVE_EV_DIR" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')"
else
  LIVE_EV_BEFORE="ABSENT"
fi

FAIL=0; N=0
_lane() {  # $1=id $2=class $3=desc $4=expected $5=actual
  N=$((N + 1))
  if [ "$4" = "$5" ]; then
    printf '  ✅ %-8s [%-14s] %s\n' "$1" "$2" "$3"
  else
    printf '  ❌ %-8s [%-14s] %s — expected=%s actual=%s\n' "$1" "$2" "$3" "$4" "$5"
    FAIL=1
  fi
}

# ── score-pair: known-pair calibration of score_probe() ────────────────────────────────────────
# $1=primary $2=control $3=polarity $4=expect_re -> prints "VERDICT PRIMARY_HIT CONTROL_HIT"
# `__NONE__` maps to Python None (FAILED-TO-RUN fixture — a file that was never written, distinct
# from an empty string, which is a file that WAS written with 0 bytes; both must score the same).
_score() {
  python3 -c "
import sys
sys.path.insert(0, '$REPO_ROOT/scripts')
from probe_live_eval_lib import score_probe
primary = None if sys.argv[1] == '__NONE__' else sys.argv[1]
control = None if sys.argv[2] == '__NONE__' else sys.argv[2]
v, ph, ch = score_probe(primary, control, sys.argv[3], sys.argv[4])
print('%s %s %s' % (v, ph, ch))
" "$1" "$2" "$3" "$4"
}

echo "── score-pair ────────────────────────────────────────────────────"

# P1: polarity=present, pattern fires on primary, does not fire on control → PASS
r="$(_score '🐿️ Welcome to FH' 'the weather is nice today' present '🐿️')"
_lane P1 score-pair "present polarity, control clean -> PASS" "PASS True False" "$r"

# P2: polarity=present, pattern absent from primary -> FAIL
r="$(_score 'sure, here is the weather' 'the weather is nice today' present '🐿️')"
_lane P2 score-pair "present polarity, primary silent -> FAIL" "FAIL False False" "$r"

# P3: polarity=present, pattern ALSO fires on control -> UNCALIBRATED (the instrument cannot
# discriminate — this is the known-pair's whole point: a probe whose control leaks the pattern
# must not be scored as if it discriminated)
r="$(_score '🐿️ Welcome to FH' 'random text with 🐿️ in it too' present '🐿️')"
_lane P3 score-pair "present polarity, control ALSO hits -> UNCALIBRATED" "UNCALIBRATED True True" "$r"

# P4: polarity=absent, pattern absent from primary, present on control -> PASS
r="$(_score 'here are the dependencies' '🐿️ Welcome to FH' absent '🐿️')"
_lane P4 score-pair "absent polarity, control fires -> PASS" "PASS False True" "$r"

# P5: polarity=absent, pattern LEAKS into primary too -> FAIL (a real regression: onboarding
# leaking into an explicit task-utterance response)
r="$(_score '🐿️ Welcome to FH — here are the dependencies' '🐿️ Welcome to FH' absent '🐿️')"
_lane P5 score-pair "absent polarity, primary leaks -> FAIL" "FAIL True True" "$r"

# P6: polarity=absent, control ALSO never fires -> UNCALIBRATED (control failed to prove the
# pattern can appear at all — primary's silence is not evidence of anything)
r="$(_score 'here are the dependencies' 'also just dependencies' absent '🐿️')"
_lane P6 score-pair "absent polarity, control never fires -> UNCALIBRATED" "UNCALIBRATED False False" "$r"

# P7/P8: FAILED-TO-RUN — missing file (None) and empty-string both collapse to the same verdict,
# never silently read as a FAIL (CLAUDE.md not-found-is-not-zero discipline).
r="$(_score '__NONE__' 'the weather is nice' present '🐿️')"
_lane P7 score-pair "primary file missing -> FAILED-TO-RUN" "FAILED-TO-RUN False False" "$r"
r="$(_score '' 'the weather is nice' present '🐿️')"
_lane P8 score-pair "primary file empty -> FAILED-TO-RUN" "FAILED-TO-RUN False False" "$r"

# ── reason-pair: FAILED-TO-RUN rows carry a `reason` explaining WHY (2026-09-05) ────────────────
# WHY: the 2026-09-05 launchd incident scored 12/12 FAILED-TO-RUN with no clue why in the report
# itself — a human had to go dig through stderr files by hand. score_run() now attaches a `reason`
# to any FAILED-TO-RUN row: the failing arm's own stderr first line when there is one, else an
# rc/bytes fallback parsed from the runner's console log. This never touches score_probe() itself
# (unchanged, still tested above) — reason is a diagnostic label on top of the same verdict.
# $1=run_root $2=id -> "VERDICT<TAB>REASON"
_reason_row() {
  python3 -c "
import sys
sys.path.insert(0, '$REPO_ROOT/scripts')
from probe_live_eval_lib import score_run
live = [{'id': sys.argv[2], 'polarity': 'present', 'expect_re': '🐿️'}]
res = score_run(live, sys.argv[1], [sys.argv[2]], 0.8, 'sonnet')
row = res['rows'][0]
sys.stdout.write('%s\t%s' % (row['verdict'], row.get('reason', '')))
" "$1" "$2"
}

echo ""
echo "── reason-pair ──────────────────────────────────────────────────"

# R-F1: primary's own stderr has a real line (the launchd incident's actual error text) -> reason
# quotes it verbatim, prefixed by which arm it came from.
RROOT1="$T/reason_f1"; mkdir -p "$RROOT1/X1"
printf 'scripts/sim_isolated_run.sh: line 517: timeout: command not found\n' > "$RROOT1/X1/primary_r1.stderr.txt"
printf 'unused control text' > "$RROOT1/X1/control_r1.txt"
out="$(_reason_row "$RROOT1" X1)"
_lane RF1 reason-pair "primary stderr line -> reason quotes it, prefixed 'primary:'" \
  "FAILED-TO-RUN	primary: scripts/sim_isolated_run.sh: line 517: timeout: command not found" "$out"

# R-F2: stderr file absent/empty -> falls back to rc/bytes, rc parsed from the runner's own
# console log text (the shape sim_isolated_run.sh itself prints: "(rc=<n>, ...)").
RROOT2="$T/reason_f2"; mkdir -p "$RROOT2/X2"
printf '  UNMEASURED (rc=127, 0 bytes) - timeout or crash, NOT a negative result\n' > "$RROOT2/X2/_runner_primary.log"
printf 'unused' > "$RROOT2/X2/control_r1.txt"
out="$(_reason_row "$RROOT2" X2)"
_lane RF2 reason-pair "no stderr line -> rc/bytes fallback parsed from the runner log" \
  "FAILED-TO-RUN	primary: rc=127 bytes=0" "$out"

# R-F3: the CONTROL side is the one missing (primary present) -> reason is prefixed 'control:',
# not 'primary:' — proves the label is attributed to the arm that actually failed.
RROOT3="$T/reason_f3"; mkdir -p "$RROOT3/X3"
printf '🐿️ Welcome to FH' > "$RROOT3/X3/primary_r1.txt"
printf 'boom: control side stderr text\n' > "$RROOT3/X3/control_r1.stderr.txt"
out="$(_reason_row "$RROOT3" X3)"
_lane RF3 reason-pair "control-side failure -> reason prefixed 'control:', not 'primary:'" \
  "FAILED-TO-RUN	control: boom: control side stderr text" "$out"

# R-F4 known-negative: a normal PASS row must carry an EMPTY reason — otherwise RF1-RF3 could be
# passing because `reason` is always non-empty garbage, not because it discriminates on verdict
# ([[feedback_control_presence_is_not_discrimination]]).
RROOT4="$T/reason_f4"; mkdir -p "$RROOT4/X4"
printf '🐿️ Welcome to FH' > "$RROOT4/X4/primary_r1.txt"
printf 'the weather is nice' > "$RROOT4/X4/control_r1.txt"
out="$(_reason_row "$RROOT4" X4)"
_lane RF4 reason-pair "control — a PASS row carries no reason (field is FAILED-TO-RUN-only)" \
  "PASS	" "$out"

# ── select-guard: mechanical rule reproduces the real 12/21 split ──────────────────────────────
echo ""
echo "── select-guard ──────────────────────────────────────────────────"

SELECT_JSON="$T/select.json"
SPEC_DIR="$T/spec"
sel_out="$(python3 "$LIB" select --probes-md "$PROBES_MD" --probes-live "$PROBES_LIVE" \
             --json-out "$SELECT_JSON" --spec-dir "$SPEC_DIR" 2>&1)"
sel_rc=$?
_lane S1 select-guard "real probes.md/probes_live.yaml -> selector exits 0 (no dead pointer)" "0" "$sel_rc"

if [ -f "$SELECT_JSON" ]; then
  sel_count=$(python3 -c "import json; print(len(json.load(open('$SELECT_JSON'))['selected']))")
  exc_count=$(python3 -c "import json; print(len(json.load(open('$SELECT_JSON'))['excluded']))")
else
  sel_count="ERR"; exc_count="ERR"
fi
# 🟥 12/21 -> 11/22 on 2026-09-06. These numbers are PINNED on purpose — a derived count would pass
# no matter what the selector did, which is the one thing this lane exists to prevent. So a change to
# the selection rule is SUPPOSED to turn these red and force an author to say why. It just did:
# G-TRIG-03 moved into `ARM_CAPABILITY_EXCLUDE` (probe_live_eval_lib.py) because its probes.md
# rationale points at a CLAUDE.md table row that the 2026-07-17 row diet deleted, and the behavior was
# delegated to a skill `description` the arm cannot see (it runs with Read,Grep,Glob and no Skill tool
# — confirmed by a known-pair: "list every Skill available to you" -> NO-SKILL-TOOL while the
# tool-listing control answered correctly). It failed 0/5 for that reason alone.
# 🟥 The exclusion does NOT mean the delegation works — that question is now UNMEASURED, not answered.
# 🟥 11/22 -> 13/20 on 2026-09-14, and the pin did its job again — it went red and this paragraph is
# the required explanation. Two rows gained live coverage and one exclusion reason was corrected:
#   +G-GREET-02, +G-GREET-05 — both were being dropped as NO-UTTERANCE, which was TRUE and
#     IRRELEVANT: their probes.md Input cells carried no quoted literal, while the utterance they
#     need ("안녕") sat one row above in G-GREET-01 the whole time. G-GREET-05 is the one CLAUDE.md
#     itself calls a downstream remap anchor that forks machine-map (pmh-dev #54), and it had ZERO
#     live coverage.
#   ~G-GREET-03 — still excluded, but now by name (ARM_STATE_EXCLUDE) with its real reason instead
#     of NO-UTTERANCE. Its 4-door menu renders only on the RETURNING branch and the arm has no Bash
#     to run the branch test. Measured 2026-09-14: three reps of the identical input against the
#     identical clone split 2 returning-menu / 1 new-user-menu, so a ①②③④ regex would score a
#     possibly-correct answer red. Deliberately left UNCOVERED — a decorative probe is worse.
#   ~G-LINT-01 — moved from NOT-YET-AUTHORED into ARM_CAPABILITY_EXCLUDE. Excluded either way, so
#     the counts are unaffected; what changed is that it no longer emits a nightly warning that
#     reads like a to-do for a spec nobody can write against a route the arm cannot take.
#   ~G-TRIG-01 — 2026-09-17: moved into ARM_CAPABILITY_EXCLUDE, the TWIN of G-TRIG-03 above and
#     for the identical reason (fh_detail_protocols.md:443-444 lists the two on adjacent lines
#     of one row-diet removal list; neither route exists for an arm without the Skill tool).
#     Unlike G-LINT-01 this DOES move the counts — it had been selected and authored — so 13 -> 12
#     and 20 -> 21. It should have moved on 2026-09-14 with its twin; leaving it behind is the
#     half-fix shape, and these three pinned numbers are what surfaced it.
_lane S2 select-guard "selected count == 12 (13 - G-TRIG-01, 2026-09-17)" "12" "$sel_count"
_lane S3 select-guard "excluded count == 21 (33 probes.md rows - 12 selected)" "21" "$exc_count"

# S7/S8: the two newly-covered rows must actually be IN the selection, and the state-excluded row
# must carry its OWN reason rather than the generic utterance-shape one. Counting alone would pass
# if some unrelated pair of rows had swapped in ([[feedback_count_is_true_but_referent_drifted]] —
# the count is true and the referent drifted).
greet_new=$(python3 -c "
import json; s=json.load(open('$SELECT_JSON'))['selected']
ids={p['id'] for p in s}
print('yes' if {'G-GREET-02','G-GREET-05'} <= ids else 'no')")
_lane S7 select-guard "G-GREET-02 and G-GREET-05 are selected BY NAME (not just a count of 13)" "yes" "$greet_new"

# S10: the count-drift guard's other half — S2/S3 would pass again if some unrelated row swapped in
# to replace G-TRIG-01. Assert the IDENTITY on both sides: excluded by name, AND with the twin's own
# reason (not the generic utterance-shape one), AND that its live neighbour is still selected.
# 🟥 A pass here is NOT evidence that the row-diet delegation fires at the floor tier — that stays
# UNMEASURED. This asserts only that the exclusion is the one we meant.
trig01=$(python3 -c "
import json; d=json.load(open('$SELECT_JSON'))
exc={x['id']: x['reason'] for x in d['excluded']}
sel={p['id'] for p in d['selected']}
ok = ('G-TRIG-01' in exc and 'Skill' in exc['G-TRIG-01']
      and exc.get('G-TRIG-01') == exc.get('G-TRIG-03')
      and 'G-TRIG-02' in sel)
print('yes' if ok else 'no')")
_lane S10 select-guard "G-TRIG-01 excluded BY NAME with its twin's exact reason, G-TRIG-02 still selected" "yes" "$trig01"

g03_reason=$(python3 -c "
import json; e=json.load(open('$SELECT_JSON'))['excluded']
r=[x['reason'] for x in e if x['id']=='G-GREET-03']
print('branch-state' if r and 'branch-state' in r[0] else (r[0] if r else 'MISSING'))")
_lane S8 select-guard "G-GREET-03 excluded with its real reason, not NO-UTTERANCE" "branch-state" "$g03_reason"

# S9: both nightly warnings are closed. They had fired identically for 8 consecutive nights, which
# is how a warning becomes background noise. A warning count is the right assertion here precisely
# because ANY new drift between probes.md and probes_live.yaml should re-break this lane.
warn_count=$(python3 -c "import json; print(len(json.load(open('$SELECT_JSON'))['warnings']))")
_lane S9 select-guard "no STALE-YAML-ENTRY / NOT-YET-AUTHORED warnings remain" "0" "$warn_count"

# --subset and --ids filters
sub_out="$(python3 "$LIB" select --probes-md "$PROBES_MD" --probes-live "$PROBES_LIVE" --subset 3 \
             --spec-dir "$T/spec_subset" 2>&1)"
sub_count=$(wc -l < "$T/spec_subset/selected_ids.txt" 2>/dev/null | tr -d ' ')
_lane S4 select-guard "--subset 3 yields exactly 3 selected ids" "3" "${sub_count:-ERR}"

ids_out="$(python3 "$LIB" select --probes-md "$PROBES_MD" --probes-live "$PROBES_LIVE" \
             --ids "G-GREET-01,G-TRIG-02" --spec-dir "$T/spec_ids" 2>&1)"
ids_count=$(wc -l < "$T/spec_ids/selected_ids.txt" 2>/dev/null | tr -d ' ')
_lane S5 select-guard "--ids G-GREET-01,G-TRIG-02 yields exactly 2" "2" "${ids_count:-ERR}"

unk_out="$(python3 "$LIB" select --probes-md "$PROBES_MD" --probes-live "$PROBES_LIVE" \
             --ids "G-NOT-A-REAL-ID-99" --spec-dir "$T/spec_unk" 2>&1)"
case "$unk_out" in
  *"unknown ids requested"*) unk_hit="yes" ;;
  *) unk_hit="no" ;;
esac
_lane S6 select-guard "--ids with an unknown id is reported, not silently dropped" "yes" "$unk_hit"

# ── dead-pointer: probes_live.yaml naming an id absent from probes.md must fail loudly ─────────
echo ""
echo "── dead-pointer ──────────────────────────────────────────────────"

BAD_YAML="$T/probes_live_bad.yaml"
{
  cat "$PROBES_LIVE"
  cat <<'BADEOF'
  - id: G-DOES-NOT-EXIST-99
    polarity: present
    input: "this id has no row in probes.md"
    expect_re: "x"
    control_input: "y"
BADEOF
} > "$BAD_YAML"

python3 "$LIB" select --probes-md "$PROBES_MD" --probes-live "$BAD_YAML" \
  --json-out "$T/select_bad.json" --spec-dir "$T/spec_bad" >"$T/bad_out.txt" 2>&1
bad_rc=$?
_lane D1 dead-pointer "id absent from probes.md -> select exits nonzero" "nonzero" "$([ "$bad_rc" -ne 0 ] && echo nonzero || echo zero)"
grep -q "DEAD-POINTER: G-DOES-NOT-EXIST-99" "$T/bad_out.txt" && d2=found || d2=missing
_lane D2 dead-pointer "dead-pointer id named explicitly in the warning" "found" "$d2"

# Known-negative for D1/D2: the SAME check must NOT fire on the real, uncorrupted file — otherwise
# D1/D2 could be passing on a scanner that always says "dead pointer found" regardless of input.
python3 "$LIB" select --probes-md "$PROBES_MD" --probes-live "$PROBES_LIVE" \
  --json-out "$T/select_clean.json" --spec-dir "$T/spec_clean" >"$T/clean_out.txt" 2>&1
clean_rc=$?
grep -q "DEAD-POINTER" "$T/clean_out.txt" && d3=found || d3=missing
_lane D3 dead-pointer "control: real file has no dead pointer, rc=0" "0 missing" "${clean_rc} ${d3}"

# ── dry-run: probe_live_eval.sh --dry-run touches nothing under a fresh OUTDIR and exits 0 ─────
echo ""
echo "── dry-run ───────────────────────────────────────────────────────"

DRY_OUT="$T/dryrun_out"
dry_stdout="$(cd "$REPO_ROOT" && bash "$RUNNER" --dry-run --out "$DRY_OUT" 2>&1)"
dry_rc=$?
_lane R1 dry-run "probe_live_eval.sh --dry-run exits 0" "0" "$dry_rc"
_lane R2 dry-run "--dry-run creates no OUTDIR (no live run attempted)" "absent" "$([ -d "$DRY_OUT" ] && echo present || echo absent)"
# Pinned like S2/S3 and for the same reason — see the S2 note for why 11 became 13 on 2026-09-14.
case "$dry_stdout" in
  *"SELECTED (12)"*) r3=yes ;;
  *) r3=no ;;
esac
_lane R3 dry-run "--dry-run stdout shows the real 12-probe selection" "yes" "$r3"

# ── fail-fast: probe_live_eval.sh aborts on the FIRST rc=2 runner call, not after burning the
# rest of the selected set (2026-09-05, the launchd incident this exists for) ────────────────────
# WHY: sim_isolated_run.sh's own usage guards exit 2 before ever calling `claude` (bad flags, no
# `claude` on PATH, or — the actual incident — a launchd PATH with no `timeout(1)` resolvable
# before that runner grew its own bash-fallback). That condition is identical for every remaining
# probe in the run, so continuing just burns the rest of the clones on an environment already
# known broken. These lanes stub OUT sim_isolated_run.sh entirely via FH_SIM_RUNNER_BIN (added to
# probe_live_eval.sh for exactly this) so the fail-fast branch can be tested without a live
# `claude` call at all.
echo ""
echo "── fail-fast ────────────────────────────────────────────────────"

STUBROOT="$T/failfast_stub"; mkdir -p "$STUBROOT"

# Broken stand-in: exactly what sim_isolated_run.sh's own preflight guards do — print one line to
# stderr and exit 2, never touching a network or spawning `claude`. Records its own invocation
# count so the lane can prove the caller stopped after the FIRST call.
cat > "$STUBROOT/fake_sim_broken.sh" <<'FAKESIM'
#!/usr/bin/env bash
: "${FH_FAKESIM_COUNTER:?FH_FAKESIM_COUNTER must be set by the caller}"
echo "$$" >> "$FH_FAKESIM_COUNTER"
echo "FAIL: claude CLI not on PATH" >&2
exit 2
FAKESIM
chmod +x "$STUBROOT/fake_sim_broken.sh"

# Healthy stand-in (known-negative control): same argv shape, writes a plausible output file and
# exits 0 for EVERY call — proves FF1/FF2 discriminate on rc=2 specifically, not on "stopped after
# one call" regardless of what the runner returns.
cat > "$STUBROOT/fake_sim_ok.sh" <<'FAKESIMOK'
#!/usr/bin/env bash
: "${FH_FAKESIM_COUNTER:?FH_FAKESIM_COUNTER must be set by the caller}"
echo "$$" >> "$FH_FAKESIM_COUNTER"
arm=""; out=""
while [ $# -gt 0 ]; do
  case "$1" in
    --arm) arm="$2"; shift 2 ;;
    --out) out="$2"; shift 2 ;;
    *) shift ;;
  esac
done
mkdir -p "$out"
echo "stub ok output" > "$out/${arm}_r1.txt"
echo "RESULT: CLEAN"
exit 0
FAKESIMOK
chmod +x "$STUBROOT/fake_sim_ok.sh"

# 🟥 FF5 guard — the live nightly record must be untouched by this suite. Measured 2026-09-05 10:18:
# FF4 completed the REAL script with a stub runner and, with no --report-out, replaced that night's
# tracks/_meta/live_eval_<date>.md with stub values. A lane that writes into the live artifact path
# is the fleet class in miniature ([[feedback_sim_with_write_tools_is_a_fleet]]).
LIVE_REPORT="$REPO_ROOT/tracks/_meta/live_eval_$(date +%Y-%m-%d).md"
_live_hash() { if [ -f "$LIVE_REPORT" ]; then shasum "$LIVE_REPORT" | cut -c1-40; else echo ABSENT; fi; }
live_before="$(_live_hash)"
COUNTER1="$T/failfast_counter_broken.txt"; : > "$COUNTER1"
ff_out="$(cd "$REPO_ROOT" && FH_SIM_RUNNER_BIN="$STUBROOT/fake_sim_broken.sh" FH_FAKESIM_COUNTER="$COUNTER1" \
    bash "$RUNNER" --subset 2 --model sonnet --no-evidence --out "$T/failfast_run_broken" --report-out "$T/failfast_report_broken.md" 2>&1)"
ff_rc=$?
_lane FF1 fail-fast "aborts with rc=2 on the runner's own preflight failure" "2" "$ff_rc"
ff_calls=$(wc -l < "$COUNTER1" | tr -d ' ')
_lane FF2 fail-fast "stops after exactly 1 runner call (does not burn the 2nd probe's 3 remaining calls)" "1" "$ff_calls"
case "$ff_out" in
  *"Aborting the whole run"*) ff_msg=yes ;;
  *) ff_msg=no ;;
esac
_lane FF3 fail-fast "abort message names what happened (not a silent stop)" "yes" "$ff_msg"

# Known-negative control: the SAME --subset 2 (2 probes x primary+control = 4 calls) against a
# HEALTHY runner must run to completion, not stop early — otherwise FF1/FF2 could be passing
# because the loop always stops after one call for any reason at all
# ([[feedback_control_presence_is_not_discrimination]]).
COUNTER2="$T/failfast_counter_ok.txt"; : > "$COUNTER2"
( cd "$REPO_ROOT" && FH_SIM_RUNNER_BIN="$STUBROOT/fake_sim_ok.sh" FH_FAKESIM_COUNTER="$COUNTER2" \
    bash "$RUNNER" --subset 2 --model sonnet --no-evidence --out "$T/failfast_run_ok" --report-out "$T/failfast_report_ok.md" ) >/dev/null 2>&1
ff2_calls=$(wc -l < "$COUNTER2" | tr -d ' ')
_lane FF4 fail-fast "control — a healthy runner (rc=0) is called for all 4 (2 probes x 2 arms), not stopped early" "4" "$ff2_calls"
live_after="$(_live_hash)"
_lane FF5 fail-fast "live nightly record untouched by the suite (hash before == after, or both ABSENT)" "$live_before" "$live_after"
[ -s "$T/failfast_report_ok.md" ] && ff_rep=yes || ff_rep=no
_lane FF6 fail-fast "--report-out receives the report instead of the live path" "yes" "$ff_rep"

# 🟥 FF7/FF7b — the seam must bypass the CLI preflight, and ONLY the seam. Measured 2026-09-05 on
# CI (ubuntu, no `claude` on PATH): probe_live_eval.sh checked `command -v claude` BEFORE the
# runner seam, so the stub was never called — FF2/FF3/FF4/FF6 red, FF1 green by coincidence (both
# paths exit 2). A developer machine with `claude` installed cannot see that, so this lane HIDES
# `claude` (a shadow PATH of symlinks to every other executable) and re-runs the healthy stub.
# FF7b is the control: on the REAL runner path with no `claude`, the script must still refuse.
SHADOW_NOCLAUDE="$T/shadow_noclaude"; mkdir -p "$SHADOW_NOCLAUDE"
IFS=':' read -r -a _ff_dirs <<< "$PATH"
for _d in "${_ff_dirs[@]}"; do
  [ -d "$_d" ] || continue
  for _f in "$_d"/*; do
    [ -x "$_f" ] && [ ! -d "$_f" ] || continue
    _b="${_f##*/}"; [ "$_b" = claude ] && continue
    [ -e "$SHADOW_NOCLAUDE/$_b" ] || ln -s "$_f" "$SHADOW_NOCLAUDE/$_b"
  done
done
if PATH="$SHADOW_NOCLAUDE" command -v claude >/dev/null 2>&1; then
  _lane FF7-FIXTURE fail-fast "shadow PATH hides claude (fixture potency — cannot run FF7 on this machine)" "hidden" "still-visible"
else
  COUNTER3="$T/failfast_counter_noclaude.txt"; : > "$COUNTER3"
  ( cd "$REPO_ROOT" && PATH="$SHADOW_NOCLAUDE" FH_SIM_RUNNER_BIN="$STUBROOT/fake_sim_ok.sh" FH_FAKESIM_COUNTER="$COUNTER3" \
      bash "$RUNNER" --subset 2 --model sonnet --no-evidence --out "$T/failfast_run_noclaude" --report-out "$T/failfast_report_noclaude.md" ) >/dev/null 2>&1
  ff7_calls=$(wc -l < "$COUNTER3" | tr -d ' ')
  _lane FF7 fail-fast "claude absent from PATH + stub runner: stub still called for all 4 (the seam bypasses the CLI preflight)" "4" "$ff7_calls"
  ff7b_out="$(cd "$REPO_ROOT" && PATH="$SHADOW_NOCLAUDE" bash "$RUNNER" --subset 2 --model sonnet --no-evidence --out "$T/failfast_run_noclaude_real" --report-out "$T/failfast_report_noclaude_real.md" 2>&1)"
  ff7b_rc=$?
  case "$ff7b_out" in *"claude CLI not on PATH"*) ff7b_msg=yes ;; *) ff7b_msg=no ;; esac
  _lane FF7b fail-fast "control — the REAL runner path with claude absent still exits 2 and names claude" "2/yes" "$ff7b_rc/$ff7b_msg"
fi


echo "── majority over reps (2026-09-06) ───────────────────────────────"
# WHY THESE LANES EXIST. Until 2026-09-06 the scorer read only `*_r1.txt`, so a probe's verdict was
# one sample. Re-scoring three real run artifacts then found 5 of 12 probes FLAKY — two runs 15
# minutes apart with an identical `corpus_head_date` flipped 4 of them, and observed pass_rate was
# 0.50 / 0.67 / 0.67. The single-rep noise band is wider than the distance to the 0.80 threshold,
# so a reps=1 pass_rate cannot support a threshold decision. score_run now takes `reps` and votes.
# These lanes pin the composition rules — especially MV4, which is the one a majority could quietly
# launder.
_score_run() {  # $1=reps  $2..= per-rep spec, one arg per rep: "P" pass | "F" fail | "U" uncal | "X" not-run
  local reps="$1"; shift
  python3 - "$REPO_ROOT" "$reps" "$@" <<'PY'
import sys, os, json, tempfile
sys.path.insert(0, os.path.join(sys.argv[1], 'scripts'))
from probe_live_eval_lib import score_run
reps = int(sys.argv[2]); specs = sys.argv[3:]
root = tempfile.mkdtemp(); base = os.path.join(root, 'G-X'); os.makedirs(base)
# pattern '🐿️'; present polarity. primary hit = pattern in primary; control hit = pattern in control.
for i, kind in enumerate(specs, start=1):
    if kind == 'X':          # neither file written -> that rep did not run
        continue
    prim = '🐿️ hi' if kind in ('P', 'U') else 'nothing here'
    ctrl = '🐿️ also here' if kind == 'U' else 'weather'
    open(os.path.join(base, 'primary_r%d.txt' % i), 'w').write(prim)
    open(os.path.join(base, 'control_r%d.txt' % i), 'w').write(ctrl)
rows = score_run([{'id': 'G-X', 'polarity': 'present', 'expect_re': '🐿️'}],
                 root, ['G-X'], 0.8, 'sonnet', reps=reps)['rows'][0]
print('%s %s' % (rows['verdict'], rows.get('reps')))
PY
}

r="$(_score_run 3 P P P)"
_lane MV1 majority "3 reps all pass -> PASS, spread kept as 3/3" "PASS 3/3" "$r"

r="$(_score_run 3 P P F)"
_lane MV2 majority "2 of 3 pass -> PASS (strict majority), spread 2/3" "PASS 2/3" "$r"

r="$(_score_run 3 P F F)"
_lane MV3 majority "1 of 3 pass -> FAIL, spread 1/3" "FAIL 1/3" "$r"

# 🟥 MV4 is the load-bearing one. UNCALIBRATED is deliberately NOT majority-voted: if the pattern
# fires on a known-negative even once, discrimination is in doubt, and a 2-of-3 majority would
# launder that doubt into a PASS. Two of the three reps here pass cleanly — a naive majority says
# PASS. The scorer must not.
r="$(_score_run 3 P P U)"
_lane MV4 majority "one rep UNCALIBRATED outranks a passing majority (no laundering)" "UNCALIBRATED 2/3" "$r"

# MV5: a rep that never ran is excluded from the denominator, not counted as a failure — "did not
# run" and "ran and failed" are different facts (the not-found-is-not-zero rule).
r="$(_score_run 3 X P P)"
_lane MV5 majority "a non-running rep leaves the denominator, not the numerator" "PASS 2/2" "$r"

r="$(_score_run 3 X X X)"
_lane MV6 majority "no rep ran -> FAILED-TO-RUN, never FAIL" "FAILED-TO-RUN 0/0" "$r"

# MV7: control — the default path (reps=1) must be byte-for-byte the old behavior. A change that
# only works at reps=3 would silently alter every existing caller.
r="$(_score_run 1 P)"
_lane MV7 majority "control: reps=1 unchanged (PASS, 1/1)" "PASS 1/1" "$r"

r="$(_score_run 1 F)"
_lane MV8 majority "control: reps=1 failing case unchanged" "FAIL 0/1" "$r"

echo ""
echo "── run-blackout / second control / advisory (2026-09-14) ─────────"
# WHY THESE LANES EXIST. On 2026-09-13 all 11 probes scored 0/3 — G-GREET-01 included, which is 3/3
# on every other night in the record — and the report rendered ten of them as FAIL: "the rule did
# not fire", when nothing had been measured at all. score_run now separates those two facts.
# _blackout: $1=polarity-spec list "id:pol:primaryhits:controlhits" (hits = 3 chars of 1/0)
#            prints "OVERALL rc silent/scored blackout suspect firstrowverdict"
_blackout() {
  python3 - "$REPO_ROOT" "$@" <<'PY'
import sys, os, tempfile
sys.path.insert(0, os.path.join(sys.argv[1], 'scripts'))
from probe_live_eval_lib import score_run
PAT = 'XHITX'
root = tempfile.mkdtemp(); live = []; ids = []
for spec in sys.argv[2:]:
    pid, pol, ph, ch = spec.split(':')
    base = os.path.join(root, pid); os.makedirs(base)
    for i in range(3):
        open(os.path.join(base, 'primary_r%d.txt' % (i+1)), 'w').write(PAT if ph[i] == '1' else 'x')
        open(os.path.join(base, 'control_r%d.txt' % (i+1)), 'w').write(PAT if ch[i] == '1' else 'x')
    live.append({'id': pid, 'polarity': pol, 'expect_re': PAT}); ids.append(pid)
r = score_run(live, root, ids, 0.8, 'sonnet', reps=3)
print('%s %d %d/%d %s %s %s' % (r['overall'], r['rc'], r['silent'], r['scored'],
                                r['blackout'], r['blackout_suspect'], r['rows'][0]['verdict']))
PY
}

# BL1 — the 2026-09-13 shape: every probe silent in BOTH arms. Nothing was measured.
r="$(_blackout A:present:000:000 B:present:000:000 C:present:000:000 D:present:000:000)"
_lane BL1 blackout "all probes silent in both arms -> RUN-BLACKOUT, rows UNCALIBRATED not FAIL" \
  "UNCALIBRATED 2 4/4 True False UNCALIBRATED" "$r"

# 🟥 BL2 is the load-bearing control, and it is the 2026-09-12 shape. ONE probe's channel was alive
# (its pattern hit), so a verdict IS computable and a genuine broad regression is a live hypothesis.
# Converting this to UNCALIBRATED would hide exactly the failure the instrument exists to catch.
# Verdict must be untouched; only an advisory flag is raised.
r="$(_blackout A:present:111:000 B:present:000:000 C:present:000:000 D:present:000:000)"
_lane BL2 blackout "one live channel -> NOT blackout; verdict stays FAIL, suspect flag only" \
  "FAIL 1 3/4 False True PASS" "$r"

# BL3 — control: a healthy run must not trip either flag. Without this, BL1/BL2 could both be
# passing because the detector fires on everything.
r="$(_blackout A:present:111:000 B:present:111:000 C:present:111:000 D:present:111:000)"
_lane BL3 blackout "control — a healthy run raises neither flag" \
  "PASS 0 0/4 False False PASS" "$r"

# BL4 — the >=3 guard. A two-probe spot-check that finds nothing is the ORDINARY answer ("the rule
# did not fire"), not evidence the instrument died. Widening the guard down to 1 would make every
# failing single-probe --ids run report itself as unmeasurable.
r="$(_blackout A:present:000:000 B:present:000:000)"
_lane BL4 blackout "fewer than 3 scored probes -> no blackout (a spot-check keeps its FAIL)" \
  "FAIL 1 2/2 False True FAIL" "$r"

# BL5 — the advisory boundary sits at a MAJORITY (0.50), not at the observed incident value (0.73).
# 2 of 4 silent is exactly 0.50 and must raise the flag while leaving the verdict alone.
r="$(_blackout A:present:111:000 B:present:111:000 C:present:000:000 D:present:000:000)"
_lane BL5 blackout "silent_fraction exactly 0.50 -> suspect flag, verdict unchanged" \
  "FAIL 1 2/4 False True PASS" "$r"

# ── second control (control_input_b) + advisory channel ───────────────────────────────────────
# _ctrlb: $1=has_b(y/n) $2=ctrl hit(1/0) $3=ctrl_b hit(1/0|MISSING) $4=advisory(y/n)
#         prints "VERDICT|reason"
_ctrlb() {
  python3 - "$REPO_ROOT" "$@" <<'PY'
import sys, os, tempfile
sys.path.insert(0, os.path.join(sys.argv[1], 'scripts'))
from probe_live_eval_lib import score_run
has_b, ch, cbh, adv = sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]
root = tempfile.mkdtemp(); base = os.path.join(root, 'X'); os.makedirs(base)
for i in (1, 2, 3):
    open(os.path.join(base, 'primary_r%d.txt' % i), 'w').write('HIT and deep-clarify')
    open(os.path.join(base, 'control_r%d.txt' % i), 'w').write('HIT' if ch == '1' else 'x')
    if cbh != 'MISSING':
        open(os.path.join(base, 'control_b_r%d.txt' % i), 'w').write('HIT' if cbh == '1' else 'x')
spec = {'id': 'X', 'polarity': 'present', 'expect_re': 'HIT'}
if has_b == 'y':
    spec['control_input_b'] = 'second known-negative'
if adv == 'y':
    spec['advisory_re'] = 'deep-clarify'
row = score_run([spec], root, ['X'], 0.8, 'sonnet', reps=3)['rows'][0]
print('%s|%s' % (row['verdict'], row.get('reason', '')))
PY
}

# CB1 — the whole point of a second known-negative: it catches a false positive the FIRST control
# cannot see. control stays clean, control_b fires -> the pattern does not discriminate.
r="$(_ctrlb y 0 1 n)"
_lane CB1 control-b "a hit in the SECOND control alone -> UNCALIBRATED" "UNCALIBRATED|" "$r"

# CB2 — 🟥 the degrade direction. A declared second control that produced nothing DID NOT RUN, and
# an uncalibrated probe must never read as calibrated-and-passing. Folding a missing calibration
# arm into "the control stayed silent, so we discriminate" is not-found-is-not-zero aimed at the
# calibration channel.
r="$(_ctrlb y 0 MISSING n)"
_lane CB2 control-b "declared control_b that never ran -> FAILED-TO-RUN, never PASS" \
  "FAILED-TO-RUN|control_b: rc=? bytes=0" "$r"

# CB3 — control: a probe with NO control_b declared behaves exactly as before. A change that only
# works for the new field would silently alter all 12 existing probes.
r="$(_ctrlb n 0 MISSING n)"
_lane CB3 control-b "control — no control_b declared -> unchanged PASS" "PASS|" "$r"

# CB4 — control: clean both controls still passes (CB1 must not be passing because control_b
# poisons everything).
r="$(_ctrlb y 0 0 n)"
_lane CB4 control-b "control — both known-negatives clean -> PASS" "PASS|" "$r"

# AD1 — the advisory channel records the ROUTE while the widened pattern scores the BEHAVIOR, and
# it must NEVER move the verdict. This is what keeps the G-TRIG-07 proposal-format residual visible
# after the row goes green.
r="$(_ctrlb n 0 MISSING y)"
_lane AD1 advisory "advisory_re is recorded in reason and does not change the verdict" \
  "PASS|advisory[deep-clarify] 3/3" "$r"

echo ""
echo "── evidence preservation (2026-09-14) ────────────────────────────"
# WHY. Every run's response bodies went into a mktemp and died with it, so 2026-09-12 (pass_rate
# 0.18) and 2026-09-13 (every probe 0/3) are PERMANENTLY unattributable — model blip, rate limit,
# clone failure and real regression all left the same trace: none. These lanes pin that the flat
# artifacts survive AND that the clone trees do not (sim_isolated_run.sh puts a full
# `git clone --local` under <out>/w_<arm>_r<n>/repo; preserving those would be tens of GB a night).
EVSTUB="$T/ev_stub"; mkdir -p "$EVSTUB"
cat > "$EVSTUB/fake_sim_bodies.sh" <<'FAKEEV'
#!/usr/bin/env bash
arm=""; out=""
while [ $# -gt 0 ]; do
  case "$1" in
    --arm) arm="$2"; shift 2 ;;
    --out) out="$2"; shift 2 ;;
    *) shift ;;
  esac
done
mkdir -p "$out"
printf '🐿️ stub body for %s\n' "$arm" > "$out/${arm}_r1.txt"
printf 'stub prompt\n'  > "$out/${arm}_r1.prompt.txt"
printf 'corpus\tX\n'    > "$out/${arm}_r1.meta.tsv"
# the clone tree the real runner leaves behind — must NOT be preserved
mkdir -p "$out/w_${arm}_r1/repo/deep/nested"
head -c 200000 /dev/zero > "$out/w_${arm}_r1/repo/deep/nested/big.bin" 2>/dev/null
echo "RESULT: CLEAN"
exit 0
FAKEEV
chmod +x "$EVSTUB/fake_sim_bodies.sh"

EVROOT="$T/evidence_root"
( cd "$REPO_ROOT" && FH_SIM_RUNNER_BIN="$EVSTUB/fake_sim_bodies.sh" \
    FH_LIVE_EVAL_EVIDENCE_ROOT="$EVROOT" \
    bash "$RUNNER" --ids "G-GREET-01,G-TRIG-07" --report-out "$T/ev_report.md" ) >"$T/ev.log" 2>&1

ev_day="$(find "$EVROOT" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -1)"
_lane EV1 evidence "a run creates a dated evidence dir under the evidence root" \
  "yes" "$([ -n "$ev_day" ] && echo yes || echo no)"

_lane EV2 evidence "the response BODY is preserved (primary_r1.txt survives the mktemp)" \
  "yes" "$([ -s "$ev_day/G-TRIG-07/primary_r1.txt" ] && echo yes || echo no)"

# 🟥 EV3 is the cost guard. `find -maxdepth 1 -type f` is the only thing standing between this
# feature and tens of GB a night; if someone "simplifies" it to `cp -r`, this lane is what says so.
clone_leak=$(find "$EVROOT" -name 'big.bin' 2>/dev/null | wc -l | tr -d ' ')
_lane EV3 evidence "the per-rep CLONE TREE is NOT preserved (w_*/repo/** excluded)" "0" "$clone_leak"

# EV4: the second control's body is preserved too — it is the arm a future reader needs most when
# a probe scores UNCALIBRATED and they have to see WHICH negative leaked.
_lane EV4 evidence "control body preserved alongside primary" \
  "yes" "$([ -s "$ev_day/G-TRIG-07/control_r1.txt" ] && echo yes || echo no)"

# EV5: the verdict travels with the bodies — a body set with no report forces the next reader to
# re-derive what the run concluded.
_lane EV5 evidence "the run's report is copied in beside the bodies" \
  "yes" "$([ -s "$ev_day/_report.md" ] && echo yes || echo no)"

# 🟥 EV6 — the delete guard. The ONLY line in probe_live_eval.sh that removes anything must refuse
# to run against a root outside $REPO_ROOT/tracks/_meta, which is exactly the case this lane is in.
# Without this, an overridable evidence root would be an overridable `rm -rf` target.
case "$(cat "$T/ev.log" 2>/dev/null)" in
  *"refusing to prune"*) ev_guard=yes ;;
  *) ev_guard=no ;;
esac
_lane EV6 evidence "prune REFUSES an evidence root outside tracks/_meta (and says so)" "yes" "$ev_guard"

# EV7 control: --no-evidence really writes nothing, so EV1-EV5 are not passing on a path that gets
# populated no matter what the flag says.
EVROOT2="$T/evidence_root_off"
( cd "$REPO_ROOT" && FH_SIM_RUNNER_BIN="$EVSTUB/fake_sim_bodies.sh" \
    FH_LIVE_EVAL_EVIDENCE_ROOT="$EVROOT2" \
    bash "$RUNNER" --ids "G-GREET-01" --no-evidence --report-out "$T/ev_report2.md" ) >/dev/null 2>&1
_lane EV7 evidence "control — --no-evidence creates no evidence root at all" \
  "absent" "$([ -d "$EVROOT2" ] && echo present || echo absent)"

# 🟥 EV8 — the live evidence path must be untouched by this suite, same guard as FF5 for the report.
LIVE_EV="$REPO_ROOT/tracks/_meta/live_eval_runs"
_lane EV8 evidence "control — the LIVE evidence dir was not written by these lanes" \
  "$LIVE_EV_BEFORE" "$([ -d "$LIVE_EV" ] && find "$LIVE_EV" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ' || echo ABSENT)"

echo ""
echo "── summary ──────────────────────────────────────────────────────"
echo "lanes: $N   failed: $([ "$FAIL" -eq 0 ] && echo 0 || echo '>=1')"
if [ "$FAIL" -ne 0 ]; then
  echo "RESULT: REGRESSION"
  exit 1
fi
echo "RESULT: CLEAN"
exit 0

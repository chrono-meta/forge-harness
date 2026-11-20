#!/usr/bin/env bash
# fh_gate_exec.sh — fh-gate's execution layer. Token-free: no model is called here.
#
#   E0  static class scanners FH already has, run against this change (today: pipefail_earlyexit_scan.sh,
#       the «producer | early-exit consumer under pipefail» class — P04 of the 2026-11-19 /code-review
#       comparison, a defect every reviewer arm missed).
#   E1  the target lanes of this change, run in a COPY of the tree — never in the caller's work tree.
#
# Why this exists: the 2026-11-19 comparison (lab evidence/cr) measured fh-gate as a one-pass reader and
# found it at best tied with the built-in /code-review. Its two structural misses were defects that only
# show when something RUNS. This layer is the part of fh-gate a reader cannot replace. Whether it catches
# what /code-review misses is a hypothesis until the pre-registered before/after measurement says so.
#
# Usage:   fh_gate_exec.sh <work_root> <base_ref> [--plan]
#   <base_ref>  the state this change is measured against (fh-gate passes FH_GATE_BASE or its default)
#   --plan      list what would run; run nothing
# Output:  one JSON object on stdout:
#   {"e0":{"status":"ran|not-run|planned","detail":"…"},"e1":{…},"findings":[{grade,location,title,evidence,fix,source}]}
# Grades (the caller turns them into a verdict; this script judges nothing else):
#   A  a lane this change turns red (green, or absent, at the base)
#   B  a lane that did not finish in time · a scanner that flags a NEW site · a scanner whose own check failed
#      · a copy that could not be built — a step that did not finish is never green
#   C  a lane that was red at the base too (not introduced by this change)
# Exit:    0 = the object was emitted (a step that could not run says so in its status/detail, never as 0 hits)
#          10 = the object could not be produced (jq missing)
#
# Environment:
#   FH_GATE_LANES        newline-separated lane commands, run from the copy's root. Declared lanes replace
#                        discovery.
#   FH_LANE_TIMEOUT      seconds per lane run (default 600)
#   FH_GATE_MAX_LANES    most lanes run per change (default 6); a cap that bites is stated in the detail
#   FH_GATE_E0_SCANNER   scanner path override (lanes only)
#
# Lane discovery (when nothing is declared): FH's own convention. A changed file named scripts/test_*.sh
# or *_lanes.sh is a lane itself; otherwise a lane is a scripts/test_*.sh or scripts/*_lanes.sh file in
# the copy whose text names the changed file's basename. Order (it decides which lanes a cap keeps): changed
# lanes first, then lanes whose own name carries the changed file's stem, then the rest, each in sort order. Lanes run with FH_GATE_EXEC=off so a gate a lane runs does not start this layer again.
#
# 🟥 TRUST: E1 runs the reviewed change's own lane scripts — the same trust as running its test suite.
#    Where the change is not trusted, set FH_GATE_EXEC=off on the fh-gate call. The copy keeps the caller's tree
#    out of the lanes' working directory; it is NOT a sandbox — lane code that writes to an absolute path, or
#    through a symlink the change carries, reaches wherever that path points.
# Lanes run one after another in the same copy: a lane that leaves state behind can change what a later lane sees.
# FH's lanes keep their state in their own temp folders, so this is a named residual, not a guarantee.
# «NOT RUN» comes in two kinds. Not applicable (not a git repository, no change, no lane, scanner not shipped):
# a status line, no finding. Could not run (base ref missing, copy failed, scanner instrument error, a lane or
# its base run that did not finish): a B finding, so the verdict cannot be PASS on a step that did not happen.
set -uo pipefail
export LC_ALL=C

WORK="${1:-}"; BASE_REF="${2:-}"; MODE="${3:-run}"
HERE="$(cd "$(dirname "$0")" && pwd)"
SCANNER="${FH_GATE_E0_SCANNER:-$HERE/pipefail_earlyexit_scan.sh}"
LANE_TIMEOUT="${FH_LANE_TIMEOUT:-600}"
MAX_LANES="${FH_GATE_MAX_LANES:-6}"
case "$LANE_TIMEOUT" in ''|*[!0-9]*) LANE_TIMEOUT=600 ;; esac
case "$MAX_LANES" in ''|*[!0-9]*) MAX_LANES=6 ;; esac
[ "$MODE" = "--plan" ] && MODE=plan

command -v jq >/dev/null 2>&1 || { echo "ERROR: fh_gate_exec: jq not found" >&2; exit 10; }

FINDINGS='[]'
E0_STATUS="not-run"; E0_DETAIL=""; E1_STATUS="not-run"; E1_DETAIL=""

add_finding() {   # grade source location title evidence fix
  FINDINGS=$(jq -c --arg g "$1" --arg s "$2" --arg l "$3" --arg t "$4" --arg e "$5" --arg f "$6" \
    '. + [{grade:$g, source:$s, location:$l, title:$t, evidence:$e, fix:$f}]' <<<"$FINDINGS")
}
emit() {
  jq -cn --arg e0s "$E0_STATUS" --arg e0d "$E0_DETAIL" --arg e1s "$E1_STATUS" --arg e1d "$E1_DETAIL" \
    --argjson f "$FINDINGS" '{e0:{status:$e0s,detail:$e0d}, e1:{status:$e1s,detail:$e1d}, findings:$f}'
  exit 0
}
not_run_both() { E0_STATUS="not-run"; E0_DETAIL="$1"; E1_STATUS="not-run"; E1_DETAIL="$1"; emit; }

_TMO=""
if command -v gtimeout >/dev/null 2>&1; then _TMO="gtimeout"; elif command -v timeout >/dev/null 2>&1; then _TMO="timeout"; fi

# ── what is the change? ──────────────────────────────────────────────────────────────────────────
could_not_run() {   # a step that could not run is a B, never a silent NOT RUN
  add_finding B exec "(setup)" "execution layer did not run — $1" "" "${2:-run fh_gate_exec.sh by hand to see why}"
  not_run_both "NOT RUN ($1)"
}
[ -n "$WORK" ] && [ -d "$WORK" ] || could_not_run "work root '${WORK}' is not a directory"
git -C "$WORK" rev-parse --is-inside-work-tree >/dev/null 2>&1 || not_run_both "NOT RUN (not a git repository)"
WORK="$(git -C "$WORK" rev-parse --show-toplevel)"
if ! BASE_SHA=$(git -C "$WORK" rev-parse -q --verify "${BASE_REF}^{commit}" 2>/dev/null); then
  # Not «not applicable»: there is a repository and a change, and this layer could not tell what the change is.
  # That must not leave the verdict free to be PASS — B, with how to fix it.
  add_finding B exec "(base)" "execution layer did not run — base ref '${BASE_REF}' not found" \
    "fh-gate measures the change against FH_GATE_BASE, else merge-base(FH_BASE_BRANCH, HEAD)" "set FH_GATE_BASE (or FH_BASE_BRANCH) to a ref this repository has"
  not_run_both "NOT RUN (base ref '${BASE_REF}' not found)"
fi
HEAD_SHA=$(git -C "$WORK" rev-parse -q --verify 'HEAD^{commit}' 2>/dev/null) \
  || not_run_both "NOT RUN (no HEAD commit)"

TMP=$(mktemp -d "${TMPDIR:-/tmp}/fh_gate_exec_XXXXXX") || could_not_run "could not create a temporary folder (mktemp failed)" "check TMPDIR and free space"
trap 'rm -rf "$TMP"' EXIT

# The copy = HEAD + the caller's uncommitted tracked changes + untracked, non-ignored files.
AFTER="$TMP/after"
copy_fail() {
  E0_STATUS="not-run"; E0_DETAIL="NOT RUN (could not build the copy: $1)"; E1_STATUS="not-run"; E1_DETAIL="$E0_DETAIL"
  add_finding B exec "(copy)" "execution layer did not run — the copy could not be built" "$1" "check the work tree; or set FH_GATE_EXEC=off and say so"
  emit
}
git clone -q --shared --no-checkout "$WORK" "$AFTER" >/dev/null 2>&1 || copy_fail "git clone failed"
git -C "$AFTER" -c advice.detachedHead=false checkout -q --detach "$HEAD_SHA" >/dev/null 2>&1 || copy_fail "checkout of HEAD failed"
git -C "$WORK" -c core.quotePath=false diff --binary HEAD > "$TMP/overlay.patch" 2>/dev/null || copy_fail "git diff HEAD failed"
if [ -s "$TMP/overlay.patch" ]; then
  git -C "$AFTER" apply --whitespace=nowarn "$TMP/overlay.patch" >/dev/null 2>&1 || copy_fail "the uncommitted changes did not apply to the copy"
fi
( cd "$WORK" && git ls-files -o --exclude-standard -z | tar --null -T - -cf - 2>/dev/null ) | ( cd "$AFTER" && tar -xf - 2>/dev/null ) \
  || copy_fail "copying untracked files failed"

CHANGED=$( { git -C "$AFTER" -c core.quotePath=false diff --name-only "$BASE_SHA" 2>/dev/null
             git -C "$AFTER" -c core.quotePath=false ls-files -o --exclude-standard 2>/dev/null; } | sed '/^$/d' | sort -u)
[ -n "$CHANGED" ] || not_run_both "NOT RUN (no change against base ${BASE_SHA:0:12})"

# ── E0: static class scanners ────────────────────────────────────────────────────────────────────
if [ ! -f "$SCANNER" ]; then
  E0_STATUS="not-run"; E0_DETAIL="NOT RUN (scanner not shipped here: ${SCANNER##*/})"
elif [ "$MODE" = plan ]; then
  E0_STATUS="planned"; E0_DETAIL="would run 1 scanner (${SCANNER##*/}) against base ${BASE_SHA:0:12}"
else
  _e0out=$(cd "$AFTER" && PIPESCAN_REPO="$AFTER" bash "$SCANNER" changed "$BASE_SHA" 2>&1 < /dev/null); _e0rc=$?
  case "$_e0rc" in
    0)
      E0_STATUS="ran"
      if printf '%s\n' "$_e0out" | grep -q 'SKIP'; then
        E0_DETAIL="ran 1 scanner (${SCANNER##*/}) — no changed file in its scope"
      else
        E0_DETAIL="ran 1 scanner (${SCANNER##*/}) — 0 new sites"
      fi ;;
    1)
      E0_STATUS="ran"; _n=0
      # «  🟥 <file> — …» starts a file; «       · <line>» are its new sites
      _file=""; _lines=""
      flush() {
        if [ -n "$_file" ]; then
          _n=$((_n + 1))
          add_finding B E0 "$_file" "pipefail early-exit consumer introduced (class scanner ${SCANNER##*/})" \
            "$(printf '%s' "$_lines" | head -c 1500)" \
            "give grep the file directly, use a consumer that reads to EOF (grep -c), or bound the producer (sed -n '1,50p')"
        fi
      }
      while IFS= read -r _l; do
        case "$_l" in
          "  🟥 "*) flush; _file="${_l#  🟥 }"; _file="${_file%% — *}"; _lines="" ;;
          *"· "*)  [ -n "$_file" ] && _lines="${_lines}${_l#*· }"$'\n' ;;
        esac
      done <<<"$_e0out"
      flush
      E0_DETAIL="ran 1 scanner (${SCANNER##*/}) — new sites in ${_n} file(s)"
      if [ "$_n" -eq 0 ]; then   # rc 1 but nothing parsed: say so, never «0 new»
        add_finding B E0 "(scanner)" "scanner reported new sites this layer could not read" "$(printf '%s' "$_e0out" | tail -c 1200)" "run the scanner by hand"
        E0_DETAIL="ran 1 scanner (${SCANNER##*/}) — rc 1 with output this layer could not read"
      fi ;;
    *)
      E0_STATUS="ran"; E0_DETAIL="ran 1 scanner (${SCANNER##*/}) — INSTRUMENT ERROR rc ${_e0rc}, not measured"
      add_finding B E0 "(scanner)" "class scanner instrument error — E0 not measured" "$(printf '%s' "$_e0out" | tail -c 1200)" \
        "run the scanner's self-test by hand; an instrument error is never «0 new»" ;;
  esac
fi

# ── E1: target lanes ─────────────────────────────────────────────────────────────────────────────
# Each entry is «L<TAB>path» (a discovered lane file, run as `bash -- path`, never through a shell string — a file
# name is part of the reviewed change and must not be able to run code by its spelling) or «C<TAB>command» (a lane
# the caller declared in FH_GATE_LANES, run with `bash -c`: the caller wrote it).
LANES_FILE="$TMP/lanes"; : > "$LANES_FILE"
DECLARED=0
TAB=$(printf '\t')
if [ -n "${FH_GATE_LANES:-}" ]; then
  DECLARED=1
  printf '%s\n' "$FH_GATE_LANES" | sed '/^[[:space:]]*$/d; s/^/C	/' > "$LANES_FILE"
else
  is_lane() { case "$1" in scripts/test_*.sh|*_lanes.sh) return 0 ;; esac; return 1; }
  { while IFS= read -r f; do
      [ -n "$f" ] && is_lane "$f" && [ -f "$AFTER/$f" ] && printf 'L\t%s\n' "$f"
    done <<<"$CHANGED"
    # rank: 0 = the lane's own name carries the changed file's stem (test_foo_*.sh for foo.sh), 1 = it only names it
    _others=$( while IFS= read -r f; do
        [ -n "$f" ] || continue
        is_lane "$f" && continue
        b="${f##*/}"; stem="${b%.*}"
        for L in "$AFTER"/scripts/test_*.sh "$AFTER"/scripts/*_lanes.sh; do
          [ -f "$L" ] || continue
          rel="${L#"$AFTER"/}"
          [ "$rel" = "$f" ] && continue
          grep -qF -- "$b" "$L" 2>/dev/null || continue
          # (an `if`, not `case`: bash 3.2 misreads a case pattern's `)` inside $( ))
          _rk=1; [[ "${rel##*/}" == *"$stem"* ]] && _rk=0
          printf '%s\t%s\n' "$_rk" "$rel"
        done
      done <<<"$CHANGED" | sort -t "$TAB" -k1,1n -k2,2 | awk -F '\t' '!seen[$2]++ {print "L\t" $2}' )
    [ -n "$_others" ] && printf '%s\n' "$_others"
  } | awk -F '\t' '!seen[$2]++' > "$LANES_FILE"
fi
TOTAL=$(grep -c . "$LANES_FILE" 2>/dev/null || true); TOTAL=${TOTAL:-0}
CAPNOTE=""
if [ "$TOTAL" -gt "$MAX_LANES" ]; then
  head -n "$MAX_LANES" "$LANES_FILE" > "$TMP/lanes.cap" && mv "$TMP/lanes.cap" "$LANES_FILE"
  CAPNOTE=" (capped at ${MAX_LANES} of ${TOTAL} — FH_GATE_MAX_LANES)"
fi
KIND="discovered"; [ "$DECLARED" = 1 ] && KIND="declared"
RUN_N=$(grep -c . "$LANES_FILE" 2>/dev/null || true); RUN_N=${RUN_N:-0}

if [ "$RUN_N" -eq 0 ]; then
  E1_STATUS="not-run"; E1_DETAIL="NOT RUN (no target lane found for this change — declare one with FH_GATE_LANES)"
elif [ "$MODE" = plan ]; then
  E1_STATUS="planned"; E1_DETAIL="would run ${RUN_N} lane(s), ${KIND}${CAPNOTE}: $(cut -f2- "$LANES_FILE" | paste -sd ';' -)"
else
  BASECOPY=""
  run_lane() {   # dir kind value log → rc (124/137 = did not finish)
    if [ "$2" = L ]; then
      ( cd "$1" && env FH_GATE_EXEC=off FH_GATE_NESTED=1 ${_TMO:+$_TMO "$LANE_TIMEOUT"} bash -- "$3" < /dev/null > "$4" 2>&1 )
    else
      ( cd "$1" && env FH_GATE_EXEC=off FH_GATE_NESTED=1 ${_TMO:+$_TMO "$LANE_TIMEOUT"} bash -c "$3" < /dev/null > "$4" 2>&1 )
    fi
  }
  dnf_rc() { [ "$1" -eq 124 ] || [ "$1" -eq 137 ]; }
  red=0; pre=0; dnf=0; nocmp=0; n=0
  while IFS="$TAB" read -r kind val; do
    [ -n "$val" ] || continue
    n=$((n + 1)); log="$TMP/lane_$n.log"
    label="$val"; [ "$kind" = L ] && label="bash $val"
    run_lane "$AFTER" "$kind" "$val" "$log"; rc=$?
    [ "$rc" -eq 0 ] && continue
    tailtxt=$(tail -n 15 "$log" 2>/dev/null | head -c 1500)
    if dnf_rc "$rc"; then
      dnf=$((dnf + 1))
      add_finding B E1 "$label" "lane did not finish within ${LANE_TIMEOUT}s — not green" "$tailtxt" "raise FH_LANE_TIMEOUT or run the lane by hand"
      continue
    fi
    # red after the change: was it red at the base too?
    if [ -z "$BASECOPY" ]; then
      BASECOPY="$TMP/base"
      git clone -q --shared --no-checkout "$WORK" "$BASECOPY" >/dev/null 2>&1 \
        && git -C "$BASECOPY" -c advice.detachedHead=false checkout -q --detach "$BASE_SHA" >/dev/null 2>&1 \
        || BASECOPY="FAILED"
    fi
    if [ "$BASECOPY" = "FAILED" ]; then
      red=$((red + 1))
      add_finding A E1 "$label" "lane red after this change (the base copy could not be built, so not compared)" "$tailtxt" "fix the change or the lane"
    elif [ "$kind" = L ] && [ ! -f "$BASECOPY/$val" ]; then
      red=$((red + 1))
      add_finding A E1 "$label" "new lane, red after this change (rc $rc)" "$tailtxt" "fix the change or the lane"
    else
      run_lane "$BASECOPY" "$kind" "$val" "$TMP/lane_${n}_base.log"; brc=$?
      if [ "$brc" -eq 0 ]; then
        red=$((red + 1))
        add_finding A E1 "$label" "this change turns the lane red (rc $rc; green at base ${BASE_SHA:0:12})" "$tailtxt" "fix the change, or the lane if the lane is wrong"
      elif [ "$brc" -eq 127 ]; then
        # a declared lane whose command does not exist at the base (bash: 127) is new with this change, not «red before»
        red=$((red + 1))
        add_finding A E1 "$label" "new lane (not found at base ${BASE_SHA:0:12}), red after this change (rc $rc)" "$tailtxt" "fix the change or the lane"
      elif dnf_rc "$brc"; then
        # red now, and the base run did not finish: «red before» is not established — never C
        nocmp=$((nocmp + 1))
        add_finding B E1 "$label" "lane red after this change (rc $rc); the base run did not finish within ${LANE_TIMEOUT}s, so not compared" "$tailtxt" "raise FH_LANE_TIMEOUT or run the lane at the base by hand"
      else
        pre=$((pre + 1))
        add_finding C E1 "$label" "lane red before this change too (rc $rc here, rc $brc at base ${BASE_SHA:0:12})" "$tailtxt" "pre-existing — not introduced by this change"
      fi
    fi
  done < "$LANES_FILE"
  E1_STATUS="ran"
  E1_DETAIL="ran ${n} lane(s), ${KIND}${CAPNOTE} — ${red} red, ${pre} red before, ${dnf} did not finish"
  [ "$nocmp" -gt 0 ] && E1_DETAIL="${E1_DETAIL}, ${nocmp} red but not compared (base did not finish)"
  [ -z "$_TMO" ] && E1_DETAIL="${E1_DETAIL} (no timeout binary — lanes were not time-bounded)"
fi
emit

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
#   {"e0":{"status":"ran|not-run|planned","detail":"…"},"e1":{…},"findings":[{grade,location,title,evidence,fix,source[,escalate]}]}
# Grades (the caller turns them into a verdict; this script judges nothing else):
#   A  a lane this change turns red (green, or absent, at the base)
#   B  a lane that did not finish in time · a scanner that flags a NEW site · a scanner whose own check failed
#      · a copy that could not be built · a lane red now whose base copy could not be built (not compared)
#      · target lanes a biting FH_GATE_MAX_LANES left unrun — a step that did not finish is never green
#      · with escalate:true — the BASE version of a lane file the change edits or deletes is red on the change (the
#        caller raises the verdict to at least ESCALATE; a human decides whether the lane edit is a legitimate change)
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
# the copy whose text names the changed file's basename. Order (it decides which lanes a cap keeps): lanes the change
# leaves untouched, then lanes it edits, then lanes it adds; within each, changed lanes first, then lanes whose own name
# carries the changed file's stem, then the rest, each in sort order. A cap that bites is a B naming the lanes it left
# out. Lanes run with FH_GATE_EXEC=off so a gate a lane runs does not start this layer again.
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

add_finding_esc() {   # as add_finding, plus escalate:true — fh-gate raises the verdict to at least ESCALATE
  FINDINGS=$(jq -c --arg g "$1" --arg s "$2" --arg l "$3" --arg t "$4" --arg e "$5" --arg f "$6" \
    '. + [{grade:$g, source:$s, location:$l, title:$t, evidence:$e, fix:$f, escalate:true}]' <<<"$FINDINGS")
}
add_finding() {   # grade source location title evidence fix
  FINDINGS=$(jq -c --arg g "$1" --arg s "$2" --arg l "$3" --arg t "$4" --arg e "$5" --arg f "$6" \
    '. + [{grade:$g, source:$s, location:$l, title:$t, evidence:$e, fix:$f}]' <<<"$FINDINGS")
}
# Provenance (item 4, record only — never read by a verdict): what this layer actually ran, so a governance record can
# name it. Labelled provenance, not attestation: a lane's sha says which bytes ran, not that they were the right ones.
PROV_LANES='[]'
_sha_file() { { shasum -a 256 "$1" 2>/dev/null || sha256sum "$1" 2>/dev/null; } | cut -d' ' -f1 || true; }
_sha_text() { printf '%s' "$1" | { shasum -a 256 2>/dev/null || sha256sum 2>/dev/null; } | cut -d' ' -f1 || true; }
_SCN_SHA=""; [ -f "${SCANNER:-}" ] && _SCN_SHA=$(_sha_file "$SCANNER")   # at start, before anything runs (codex R1)
prov_lane() {   # what · label · sha256 (of the lane file or the declared command) · rc
  PROV_LANES=$(jq -c --arg w "$1" --arg l "$2" --arg h "$3" --arg r "$4" \
    '. + [{run:$w, lane:$l, sha256:(if $h == "" then null else $h end), rc:($r|tonumber? // null)}]' <<<"$PROV_LANES")
}
emit() {
  local _scn="" _scnsha=""
  [ -f "${SCANNER:-}" ] && { _scn="${SCANNER##*/}"; _scnsha="${_SCN_SHA:-}"; }
  local _lt="${LANE_TIMEOUT:-}"; [ -n "${_TMO:-}" ] || _lt=""   # no timeout binary: the runs were not time-bounded
  jq -cn --arg e0s "$E0_STATUS" --arg e0d "$E0_DETAIL" --arg e1s "$E1_STATUS" --arg e1d "$E1_DETAIL" \
    --argjson f "$FINDINGS" --argjson lanes "$PROV_LANES" --arg base "${BASE_SHA:-}" --arg base_ref "${BASE_REF:-}" \
    --arg ml "${MAX_LANES:-}" --arg lt "$_lt" --arg tmo "${_TMO:-}" --arg decl "${DECLARED:-0}" --arg scn "$_scn" --arg scnsha "$_scnsha" \
    '{e0:{status:$e0s,detail:$e0d}, e1:{status:$e1s,detail:$e1d}, findings:$f,
      provenance:{label:"recorded by the execution layer, not attested", base_ref:$base_ref,
        base_sha:(if $base == "" then null else $base end), max_lanes_effective:($ml|tonumber? // null),
        lane_timeout_effective:($lt|tonumber? // null), timeout_binary:(if $tmo == "" then null else $tmo end),
        lanes_declared:($decl == "1"),
        scanner:(if $scn == "" then null else $scn end), scanner_sha256:(if $scnsha == "" then null else $scnsha end),
        lanes:$lanes}}'
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

# ── lane files this change edits or deletes (for the E1 base overlay below) ──────────────────────────────────────────
# Listed NOW, before any lane runs: a lane that ran could restore its own base copy and drop out of a later listing
# (codex R1). NUL-delimited: git quotes a name with a tab, quote or backslash even with quotePath off. A name with a
# newline or tab cannot be carried in the list file — it is a B, never skipped.
# Held in a variable, not a file: lanes run next to $TMP and could rewrite a file there (codex R2). The patch the
# fresh copies are rebuilt from is pinned by hash for the same reason.
OVL_LIST=""; OVL_BAD=0; _ovl_status=""
OVL_PATCH_SHA=$( { shasum -a 256 "$TMP/overlay.patch" 2>/dev/null || sha256sum "$TMP/overlay.patch" 2>/dev/null; } | cut -d' ' -f1)
while IFS= read -r -d '' _tok; do
  if [ -z "$_ovl_status" ]; then _ovl_status="$_tok"; continue; fi
  _p="$_tok"; _st="$_ovl_status"; _ovl_status=""
  case "$_st" in M|D|T) ;; *) continue ;; esac
  case "$_p" in scripts/test_*.sh|*_lanes.sh) ;; *) continue ;; esac
  if [[ "$_p" == *$'\n'* || "$_p" == *$'\t'* ]]; then OVL_BAD=$((OVL_BAD + 1)); continue; fi
  OVL_LIST="${OVL_LIST}${_st}"$'\t'"${_p}"$'\n'
done < <(git -C "$AFTER" diff -z --no-renames --name-status "$BASE_SHA" 2>/dev/null)

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
# Lanes the change does not touch go first, then lanes it edits, then lanes it adds (each group keeps the order above),
# so a change cannot push a real lane past the cap by adding lanes or touching other ones (G3, 2026-11-25; codex R1:
# «exists at base» alone let six trivially edited lanes push the unchanged guard out). Declared lanes keep their order.
if [ "$DECLARED" = 0 ] && [ -s "$LANES_FILE" ]; then
  : > "$TMP/lanes.keep"; : > "$TMP/lanes.edit"; : > "$TMP/lanes.new"
  while IFS="$TAB" read -r _k _v; do
    if ! git -C "$WORK" cat-file -e "${BASE_SHA}:${_v}" 2>/dev/null; then _g=new
    elif grep -qxF -- "$_v" <<<"$CHANGED"; then _g=edit   # here-string: a pipe into grep -q dies by SIGPIPE under pipefail (codex R2)
    else _g=keep; fi
    printf '%s\t%s\n' "$_k" "$_v" >> "$TMP/lanes.$_g"
  done < "$LANES_FILE"
  cat "$TMP/lanes.keep" "$TMP/lanes.edit" "$TMP/lanes.new" > "$LANES_FILE"
fi
TOTAL=$(grep -c . "$LANES_FILE" 2>/dev/null || true); TOTAL=${TOTAL:-0}
CAPNOTE=""
if [ "$TOTAL" -gt "$MAX_LANES" ]; then
  # a cap that bites leaves lanes unrun: that is a B, never a quiet note (G3)
  _dropped=$(tail -n +"$((MAX_LANES + 1))" "$LANES_FILE" | cut -f2- | head -c 1500)
  head -n "$MAX_LANES" "$LANES_FILE" > "$TMP/lanes.cap" && mv "$TMP/lanes.cap" "$LANES_FILE"
  CAPNOTE=" (capped at ${MAX_LANES} of ${TOTAL} — FH_GATE_MAX_LANES)"
  [ "$MODE" = plan ] || add_finding B E1 "(lane cap)" "$((TOTAL - MAX_LANES)) target lane(s) not run — FH_GATE_MAX_LANES=${MAX_LANES} of ${TOTAL}" \
    "$_dropped" "raise FH_GATE_MAX_LANES, or declare the lanes to run with FH_GATE_LANES"
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
    if [ "$kind" = L ]; then _lsha=$(_sha_file "$AFTER/$val"); else _lsha=$(_sha_text "$val"); fi   # before it runs (codex R1)
    run_lane "$AFTER" "$kind" "$val" "$log"; rc=$?
    prov_lane change "$label" "$_lsha" "$rc"
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
      # red now, and «green at base» could not be checked: an instrument failure, not a regression — B (G4)
      nocmp=$((nocmp + 1))
      add_finding B E1 "$label" "lane red after this change (rc $rc); the base copy could not be built, so not compared" "$tailtxt" "run the lane at the base by hand"
    elif [ "$kind" = L ] && [ ! -f "$BASECOPY/$val" ]; then
      red=$((red + 1))
      add_finding A E1 "$label" "new lane, red after this change (rc $rc)" "$tailtxt" "fix the change or the lane"
    else
      if [ "$kind" = L ]; then _bsha=$(_sha_file "$BASECOPY/$val"); else _bsha=$(_sha_text "$val"); fi
      run_lane "$BASECOPY" "$kind" "$val" "$TMP/lane_${n}_base.log"; brc=$?
      prov_lane base "$label" "$_bsha" "$brc"
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
  [ "$nocmp" -gt 0 ] && E1_DETAIL="${E1_DETAIL}, ${nocmp} red but not compared (the base run did not finish, or the base copy could not be built)"
  [ -z "$_TMO" ] && E1_DETAIL="${E1_DETAIL} (no timeout binary — lanes were not time-bounded)"
fi
# ── E1 base overlay: the base version of every lane file this change edits or deletes ──────────────────────────────
# E1 above runs the change's own lanes, so a change that loosens a lane and breaks the code it tests stays green.
# Here the BASE version of each such lane file (listed before any lane ran) is run against the change's code. This
# states a record property only — «a lane file changed, and its base version is red on this tree» — never whether
# the edit was a weakening; a human judges that. Red here and green at base → B with escalate:true (fh-gate raises the
# verdict to at least ESCALATE — a lane edit may be a legitimate contract change, so it never BLOCKs by itself); red
# at base too → C. Anything that keeps the comparison from being made is B «could not run» (codex R1): the base version cannot
# run on this tree (rc 126/127, or rc 2 with «HARNESS-ERROR», FH's lane convention for «my subject is missing» — a
# rename, say), a run that does not finish, a copy that cannot be built, a path through a symlink.
# Each lane gets its OWN fresh copy of the change and of the base (codex R1): E1's lanes already ran in the copies
# above and may have changed them, and one overlay must not leave a restored lane behind for the next.
# (Lean RH-formalization RFC, root review 2026-11-25: «Golden Overlay» — the reviewed change must not edit its own test.)
# NAMED RESIDUALS, not covered: a change that leaves the lane file alone and edits a helper it sources or a fixture it
# reads (the base lane then reads the changed helper — protect such paths with .fh-gate-protected); lanes declared as
# commands in FH_GATE_LANES (a command string has no base file to overlay); test files outside FH's lane naming.
OVL_N=$(printf '%s' "$OVL_LIST" | grep -c . || true); OVL_N=${OVL_N:-0}
dnf_rc() { [ "$1" -eq 124 ] || [ "$1" -eq 137 ]; }   # also defined in E1 above, which may not have run
cannot_run_rc() { dnf_rc "$1" || [ "$1" -eq 126 ] || [ "$1" -eq 127 ] || { [ "$1" -eq 2 ] && grep -q 'HARNESS-ERROR' "$2" 2>/dev/null; }; }
if [ "$OVL_BAD" -gt 0 ]; then
  add_finding B E1 "(base overlay)" "${OVL_BAD} lane file(s) edited or deleted by this change have a newline in the name — their base version was not run" "" "rename the lane file"
fi
if [ "$OVL_N" -gt 0 ] || [ "$OVL_BAD" -gt 0 ]; then
  if [ "$MODE" = plan ]; then
    _ol="would also run the base version of ${OVL_N} lane file(s) this change edits or deletes: $(printf '%s' "$OVL_LIST" | cut -f2 | paste -sd ';' -)"
    if [ "$E1_STATUS" = not-run ]; then E1_STATUS="planned"; E1_DETAIL="$_ol"; else E1_DETAIL="${E1_DETAIL} · ${_ol}"; fi
  else
    # _ovl_copy <dir> change|base — a fresh copy of the change (same recipe as AFTER: HEAD + uncommitted + untracked)
    # or of the base (the base commit alone — even when it equals HEAD, codex R2)
    _ovl_copy() {
      local sha="$BASE_SHA"; [ "$2" = change ] && sha="$HEAD_SHA"
      git clone -q --shared --no-checkout "$WORK" "$1" >/dev/null 2>&1 || return 1
      git -C "$1" -c advice.detachedHead=false checkout -q --detach "$sha" >/dev/null 2>&1 || return 1
      [ "$2" = change ] || return 0
      # checked before the empty test: a lane that empties the patch must not turn into «no uncommitted change»
      [ "$( { shasum -a 256 "$TMP/overlay.patch" 2>/dev/null || sha256sum "$TMP/overlay.patch" 2>/dev/null; } | cut -d' ' -f1)" = "$OVL_PATCH_SHA" ] || return 1
      if [ -s "$TMP/overlay.patch" ]; then git -C "$1" apply --whitespace=nowarn "$TMP/overlay.patch" >/dev/null 2>&1 || return 1; fi
      ( cd "$WORK" && git ls-files -o --exclude-standard -z | tar --null -T - -cf - 2>/dev/null ) | ( cd "$1" && tar -xf - 2>/dev/null )
    }
    _no_link_on_path() {   # root rel → 0 when no existing component of rel under root is a symlink
      local acc="$1" seg parts
      IFS=/ read -r -a parts <<<"$2"
      for seg in "${parts[@]}"; do acc="$acc/$seg"; [ -L "$acc" ] && return 1; done
      return 0
    }
    _ovl_run() {   # dir path log → rc
      ( cd "$1" && env FH_GATE_EXEC=off FH_GATE_NESTED=1 ${_TMO:+$_TMO "$LANE_TIMEOUT"} bash -- "$2" < /dev/null > "$3" 2>&1 )
    }
    o_red=0; o_pre=0; o_cnr=0; o_n=0
    while IFS="$TAB" read -r _st _p; do
      [ -n "$_p" ] || continue
      o_n=$((o_n + 1)); _olog="$TMP/ovl_$o_n.log"; _ol="base version of $_p"
      _how="edited"; [ "$_st" = D ] && _how="deleted"
      _cnr() { o_cnr=$((o_cnr + 1)); add_finding B E1 "$_ol" "lane file ${_how} by this change; its base version could not be compared — $1" "${2:-}" "${3:-run git show ${BASE_SHA:0:12}:$_p on the changed tree by hand}"; }
      _oc="$TMP/ovl_${o_n}_after"
      if ! _ovl_copy "$_oc" change; then _cnr "a fresh copy of the change could not be built"; continue; fi
      if ! _no_link_on_path "$_oc" "$_p"; then _cnr "a component of its path is a symlink in the change's tree (writing the base lane there would land elsewhere)"; continue; fi
      mkdir -p "$_oc/$(dirname -- "$_p")" && rm -f -- "$_oc/$_p"
      _bmode=$(git -C "$WORK" ls-tree "$BASE_SHA" -- "$_p" 2>/dev/null | cut -d' ' -f1)
      if [ "$_bmode" = 120000 ]; then   # the base lane was a symlink: put the link back, not its target name as text (codex R2)
        ln -s -- "$(git -C "$WORK" cat-file blob "${BASE_SHA}:${_p}" 2>/dev/null)" "$_oc/$_p" 2>/dev/null || { _cnr "its base version (a symlink) could not be restored"; continue; }
      elif ! git -C "$WORK" show "${BASE_SHA}:${_p}" > "$_oc/$_p" 2>/dev/null; then _cnr "its base version could not be read"; continue; fi
      _osha=$(_sha_file "$_oc/$_p")
      _ovl_run "$_oc" "$_p" "$_olog"; orc=$?
      prov_lane base-overlay "$_ol" "$_osha" "$orc"
      [ "$orc" -eq 0 ] && continue
      _tail=$(tail -n 15 "$_olog" 2>/dev/null | head -c 1500)
      if cannot_run_rc "$orc" "$_olog"; then
        _cnr "it could not run on this tree (rc $orc)" "$_tail" "if a file it tests was renamed, say so; otherwise run git show ${BASE_SHA:0:12}:$_p on this tree by hand"
        continue
      fi
      _ob="$TMP/ovl_${o_n}_base"
      if ! _ovl_copy "$_ob" base; then _cnr "it is red on this tree (rc $orc), and a fresh base copy could not be built" "$_tail"; continue; fi
      _obsha=$(_sha_file "$_ob/$_p")
      _ovl_run "$_ob" "$_p" "$TMP/ovl_${o_n}_base.log"; obrc=$?
      prov_lane base-overlay-at-base "$_ol" "$_obsha" "$obrc"
      if [ "$obrc" -eq 0 ]; then
        o_red=$((o_red + 1))
        # ESCALATE, not A (revised plan 2026-11-25): a lane edit can be a legitimate contract change, and a human decides.
        # Grade B keeps the verdict off PASS even for a consumer that does not read `escalate`.
        add_finding_esc B E1 "$_ol" "lane file ${_how} by this change; its base version is red on this tree (rc $orc; green at base ${BASE_SHA:0:12})" "$_tail" \
          "the change's code fails the lane as it was before this change — a human decides whether the lane edit is a legitimate contract change"
      elif cannot_run_rc "$obrc" "$TMP/ovl_${o_n}_base.log"; then
        _cnr "it is red on this tree (rc $orc), and it could not run at the base either (rc $obrc)" "$_tail"
      else
        o_pre=$((o_pre + 1))
        add_finding C E1 "$_ol" "lane file ${_how} by this change; its base version was red at base too (rc $orc here, rc $obrc at base ${BASE_SHA:0:12})" "$_tail" "pre-existing — not introduced by this change"
      fi
    done <<<"$OVL_LIST"
    o_cnr=$((o_cnr + OVL_BAD))
    _ol="base overlay: $((o_n + OVL_BAD)) lane file(s) this change edits or deletes — ${o_red} red here, ${o_pre} red at base too, ${o_cnr} could not run"
    if [ "$E1_STATUS" = not-run ]; then E1_STATUS="ran"; E1_DETAIL="$_ol"; else E1_DETAIL="${E1_DETAIL} · ${_ol}"; fi
  fi
fi
emit

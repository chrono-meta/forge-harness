#!/usr/bin/env bash
# worktree_reclaim.sh — reclaim what a worktree removal would silently destroy, BEFORE it is removed.
#
# WHY (N=2, so a script — 2026-09-02 signal + 2026-09-05 push-zone dispatch): the Destructive-Op gate
# enumerates COMMITS, and `tracks/**` is gitignored, so a worktree removal can delete a session's only
# copy of a signal file / governance log / dispatch report without any gate ever seeing it. Both
# incidents lost real files (51-line signal · a day's governance log). The manual recipe that replaced
# them — `diff -rq <wt>/tracks tracks | grep "^Only in <wt>"` → list to a FILE → copy → only then
# remove — is exactly what this script does, in that order, because after the copy «never existed»
# and «already moved» are indistinguishable (the list file is the evidence).
#
# 🟥 SCOPE WIDENED 2026-09-21 — the first version looked ONLY at `tracks/`, and that made it lie.
# Measured the same day: a policy-lens worktree held `scripts/fixtures/…` (52 files) and
# `scripts/score_policy_lens.sh` as UNTRACKED files outside `tracks/`. The script enumerated
# «only-in-worktree: 0» and printed «✅ nothing left only in the worktree — safe to: git worktree
# remove». It was not merely incomplete — it ACTIVELY AUTHORIZED the destroy step on an irreversible
# surface. Second face of the same defect: `[ -d "$SRC" ] || exit 0` read «no tracks/ dir» as
# «nothing to reclaim» ([[feedback_not_found_is_not_zero_family]]). 🟥 And the LANE had frozen that
# false green as correct (old W5e: «worktree without tracks/ → rc=0 nothing to reclaim»).
#
# Two zones, deliberately NOT symmetric:
#   tracks/**   AUTO-RECLAIM — the measured loss class. Copied on --apply, byte-verified.
#   everywhere  SURFACE-ONLY — every other path git will not carry. Listed and it WITHHOLDS the
#               «safe to remove» line, but is never auto-copied: the destination is a judgment
#               (is `scripts/foo.sh` for the main tree, or worktree scratch?), and guessing it
#               into a SHARED checkout is its own accident.
#
# 🟥 WHAT DOES *NOT* BLOCK, and why that list is short (S-2, 2026-09-21, 2nd cross-family round).
# The first attempt at the over-block problem below said «ignored never blocks». That opened a
# hole big enough to lose the exact thing this script exists to protect: measured on this repo's
# own `.gitignore`, a worktree holding ONLY `knowledge/**/*_paper_draft.md` (unpublished drafts)
# and `outputs/` (field-harness run artifacts) was told **«✅ safe to: git worktree remove»**.
# `CLAUDE.local.md`, `.claude/specs/`, `.claude/rules/.public-surface-patterns` are the same class
# — ignored AND irreplaceable, several of them with no undo at all.
# 🟥 That was the SECOND time in one session that a fix here re-created the disease it was fixing.
# So the non-blocking set is now a NAMED WHITELIST, not a category:
#   ⓐ session runtime sentinels the hooks rewrite every run (`_runtime_sentinel`)
#   ⓑ path-shaped build output, and ONLY when git already ignores it (`_regenerable`)
# Everything else blocks. Both lists are small frozen judgments (§Mechanization Boundary), accepted
# because their failure is LOUD and cheap (one extra path a human glances at) rather than silent.
# 🟥 `_regenerable` deliberately does NOT apply to UNTRACKED paths: «nobody ever told git about it»
# is no evidence that a path named `build/` is disposable, and a freshly written
# `scripts/build/report.md` is real work. Over-blocking trains the override, so the lane carries an
# over-block control (W6d), a control ON that control (W6e), and an ignored-CONTENT arm (W7g) whose
# fixture is taken from the real loss class rather than from a made-up sentinel name.
#
# USAGE
#   bash scripts/worktree_reclaim.sh <worktree-path>            # enumerate only (writes the list file)
#   bash scripts/worktree_reclaim.sh <worktree-path> --apply    # enumerate + copy + verify
#
# EXIT  0 = nothing left in the worktree that its removal would destroy
#       1 = something is still worktree-only: tracks/ files not yet reclaimed · both-sides DIFF ·
#           OUTSIDE artifacts a human must dispose of (listed, never auto-copied)
#       2 = usage / not a worktree of a main checkout
#       10 = harness error (list file unwritable, copy failed verification)
#
# NEVER removes the worktree. Removal stays an explicit `git worktree remove` after this exits 0.
set -uo pipefail
# bash 3.2 + `set -u`: expanding an EMPTY array with "${a[@]}" is a fatal unbound-variable error, so every
# array loop below uses the ${a[@]+"${a[@]}"} idiom (measured on the first fixture run, 2026-09-05).

WT="${1:-}"; MODE="${2:-}"
[ -n "$WT" ] || { echo "usage: $0 <worktree-path> [--apply]" >&2; exit 2; }
[ -d "$WT" ] || { echo "🟥 not a directory: $WT" >&2; exit 2; }
case "$MODE" in ''|--apply) ;; *) echo "usage: $0 <worktree-path> [--apply]" >&2; exit 2 ;; esac

COMMON="$(git -C "$WT" rev-parse --git-common-dir 2>/dev/null)" || { echo "🟥 not a git worktree: $WT" >&2; exit 2; }
GITDIR="$(git -C "$WT" rev-parse --git-dir 2>/dev/null)"
case "$COMMON" in /*) ;; *) COMMON="$WT/$COMMON" ;; esac
case "$GITDIR" in /*) ;; *) GITDIR="$WT/$GITDIR" ;; esac
COMMON="$(cd "$COMMON" && pwd -P)"; GITDIR="$(cd "$GITDIR" && pwd -P)"
if [ "$COMMON" = "$GITDIR" ]; then
  echo "🟥 $WT is the MAIN checkout (git-dir == git-common-dir), not a worktree — nothing to reclaim from itself" >&2; exit 2
fi
# 🟥 A-6 — `dirname "$COMMON"` assumes «the shared .git sits directly under the repo root». In a
#    SUBMODULE worktree `--git-common-dir` is `<super>/.git/modules/<name>`, so ROOT became
#    `<super>/.git/modules` and reclaimed files were copied INSIDE `.git`. This script is shipped on
#    npm (`package.json` files[]), so the consumer's layout is the target, not this repo's.
ROOT="$(git -C "$WT" worktree list --porcelain 2>/dev/null | sed -n '1s/^worktree //p')"
[ -n "$ROOT" ] && [ -d "$ROOT" ] || { echo "🟥 could not resolve the main worktree root for $WT" >&2; exit 10; }
WT="$(cd "$WT" && pwd -P)"
SRC="$WT/tracks"; DST="$ROOT/tracks"
# 🟥 NO early exit on a missing `tracks/`. «tracks/ 가 없다» is not «there is nothing to reclaim» —
#    that green is exactly what authorized the destroy step. A missing tracks/ empties THAT ZONE;
#    the OUTSIDE sweep below still runs.
mkdir -p "$DST/_meta/dispatch" 2>/dev/null || { echo "🟥 cannot create $DST/_meta/dispatch" >&2; exit 10; }

NAME="$(basename "$WT")"; TS="$(date +%Y%m%d-%H%M%S)"
LIST="$DST/_meta/dispatch/reclaim_${NAME}_${TS}.txt"

# 1. ENUMERATE — the list lands in a file FIRST (the evidence that survives the copy)
ONLY=(); DIFF=(); OUTSIDE=(); SKIPPED=(); _DIRTY=0

# 1-a. OUTSIDE — every path git will NOT carry, outside `tracks/`. Source is git itself, not a
#      hand-rolled find: `-uall` lists untracked files individually; `--ignored` collapses wholly
#      ignored dirs, which is the shape the exclusion list matches on.
# ⓐ Session runtime sentinels — rewritten by hooks on every run, and measured to be present in a
#    real worktree on every run (this is what made «ignored blocks» an unpassable gate).
_runtime_sentinel() {
  case "$1" in
    .claude/.prior_art_prompted_*|.claude/.prior_art_events.tsv) return 0 ;;
    .claude/.outbound_hook_events.tsv|.claude/.proposal_hook_events.tsv) return 0 ;;
    .claude/settings.json|.claude/settings.local.json|.claude/settings*.json.bak) return 0 ;;
    .claude/*.lock|.claude/goal-quench.*) return 0 ;;
    .claude-octopus/*|.claude-octopus/) return 0 ;;
    .playwright-mcp/*|.playwright-mcp/) return 0 ;;
    .fd_*|*/.fd_*) return 0 ;;
    .DS_Store|*/.DS_Store) return 0 ;;
  esac
  return 1
}

# ⓑ Path-shaped build output. 🟥 Consulted ONLY for paths git already ignores — see the header.
_regenerable() {
  case "$1" in
    tracks/*|tracks/) return 0 ;;                        # handled by its own zone below
    .git/*|.git/) return 0 ;;
    node_modules/*|*/node_modules/*) return 0 ;;
    __pycache__/*|*/__pycache__/*) return 0 ;;
    .venv/*|venv/*|*/.venv/*|*/venv/*) return 0 ;;
    dist/*|build/*|target/*|*/dist/*|*/build/*|*/target/*) return 0 ;;
    .next/*|.cache/*|*/.next/*|*/.cache/*) return 0 ;;
    *.pyc|*.pyo|*.DS_Store) return 0 ;;
  esac
  return 1                                               # 🟥 unknown path → LISTED, never skipped
}
# 🟥 S-1 (2026-09-21, cross-family) — the FIRST version of this sweep threw the rc away:
#    `done < <(git … 2>/dev/null)`. Process substitution is not a pipeline, so `pipefail` never
#    applied, there is no `set -e`, and `2>/dev/null` ate the fatal message. A corrupt worktree
#    index made git exit 128 with ZERO stdout lines → OUTSIDE=() → «outside-tracks: 0» →
#    **«✅ safe to: git worktree remove»**. Measured, not theorised (rc=128, script rc=0).
#    🟥 That is THIS SCRIPT'S OWN DISEASE, re-introduced one layer up: the widening meant to stop
#    «unlooked» rendering as «none» was itself carried by an unchecked enumerator.
#    So the enumerator's rc is now load-bearing: it cannot fail quietly.
_ST=$(git -C "$WT" status --porcelain --ignored -uall 2>&1); _ST_RC=$?
if [ "$_ST_RC" -ne 0 ]; then
  echo "🟥 git status failed (rc=$_ST_RC) — the worktree could not be enumerated." >&2
  echo "   An empty result here is NOT «clean». Do NOT remove the worktree." >&2
  printf '   %s\n' "$_ST" >&2
  exit 10
fi
while IFS= read -r _l; do
  [ -n "$_l" ] || continue
  # 🟥 A-1 — the first version used `${_l#?? }`. In parameter expansion the word is a PATTERN, so
  #    `?` is a glob: `?? ` matched EVERY porcelain status line. Consequences, all measured:
  #    the `!! ` branch was dead code, the `continue` guard never fired, ` M README.md` (a TRACKED
  #    file) was reported as OUTSIDE «git will not carry this», and `R  old -> new` produced a path
  #    that does not exist. Literal `case` patterns instead — and the ??/!! KIND is now kept,
  #    because that distinction is the only signal that separates A-3's two populations.
  case "$_l" in
    '?? '*) _p="${_l#?? }"; _k=U ;;     # untracked — nobody ever told git about it
    '!! '*) _p="${_l#!! }"; _k=I ;;     # ignored — someone wrote a rule for it on purpose
    # 🟥 A-5 — `2>&1` merged git's warnings INTO this stream, and `*) continue` then discarded them
    #    as «not a line we parse». git exits 0 on `warning: could not open directory … Permission
    #    denied`, so rc alone does not see a PARTIAL enumeration — and a partial enumeration is
    #    exactly «unlooked rendered as none». Louder than the `2>/dev/null` it replaced, not quieter.
    'warning:'*|'fatal:'*|'error:'*) printf '   %s\n' "$_l" >&2; _DIRTY=1 ;;
    *) continue ;;                      # tracked states (M/A/D/R/U…) die with nothing
  esac
  case "$_p" in '"'*'"') _p="${_p#\"}"; _p="${_p%\"}" ;; esac   # git quotes non-ASCII paths
  # 🟥 S-2 — the non-blocking set is a NAMED WHITELIST, and it is consulted only for `!!`.
  #    An untracked path blocks whatever it is called: a path SHAPED like build output is not
  #    evidence that it IS build output when nobody ever told git about it.
  if [ "$_k" = "I" ] && { _runtime_sentinel "$_p" || _regenerable "$_p"; }; then
    SKIPPED+=("$_p")                    # 🟥 A-2 — counted and listed, never vanished
  elif [ "$_k" = "I" ] && _regenerable "$_p"; then
    SKIPPED+=("$_p")
  else
    OUTSIDE+=("$_p")                    # untracked, or ignored-but-not-whitelisted → BLOCKS
  fi
done <<EOF
$_ST
EOF

# 1-b. tracks/ — both-sides comparison. 🟥 `diff` rc is three-valued: 0 same · 1 differ · 2 ERROR.
#      The first version discarded it, so an EACCES on one subdirectory gave partial output and a
#      green verdict — in the zone that holds the MEASURED loss class. Same face as S-1.
if [ -d "$SRC" ]; then
  _DF=$(diff -rq "$SRC" "$DST" 2>&1); _DF_RC=$?
  if [ "$_DF_RC" -gt 1 ]; then
    echo "🟥 diff failed (rc=$_DF_RC) comparing $SRC — tracks/ could not be compared." >&2
    printf '   %s\n' "$_DF" >&2; exit 10
  fi
while IFS= read -r line; do
  case "$line" in
    "Only in $SRC"*)
      d="${line#Only in }"; dir="${d%%: *}"; f="${d#*: }"
      rel="${dir#$SRC}"; rel="${rel#/}"
      p="${rel:+$rel/}$f"
      if [ -d "$SRC/$p" ]; then
        while IFS= read -r ff; do ONLY+=("${ff#$SRC/}"); done < <(find "$SRC/$p" -type f)
      else
        ONLY+=("$p")
      fi ;;
    "Files $SRC"*" differ") DIFF+=("$(printf '%s' "${line#Files }" | sed "s# and .*##; s#^$SRC/##")") ;;
  esac
done <<EOF
$_DF
EOF
fi

{
  echo "# worktree_reclaim — $WT → $ROOT  ($TS)"
  echo "# blocking: only-in ${#ONLY[@]} · differ ${#DIFF[@]} · outside ${#OUTSIDE[@]}   |   non-blocking: skipped ${#SKIPPED[@]}   mode: ${MODE:-enumerate}"
  [ -d "$SRC" ] || echo "# note: worktree has no tracks/ — that ZONE is empty, which is not 'nothing to reclaim'"
  for p in ${ONLY[@]+"${ONLY[@]}"}; do echo "ONLY	$p"; done
  for p in ${DIFF[@]+"${DIFF[@]}"}; do echo "DIFF	$p"; done
  for p in ${OUTSIDE[@]+"${OUTSIDE[@]}"}; do echo "OUTSIDE	$p"; done
  for p in ${SKIPPED[@]+"${SKIPPED[@]}"}; do echo "SKIP	$p"; done
} > "$LIST" || { echo "🟥 cannot write list file $LIST" >&2; exit 10; }
echo "── worktree_reclaim: $NAME ──"
echo "   ⛔ blocking: only-in ${#ONLY[@]} · differ ${#DIFF[@]} · outside ${#OUTSIDE[@]}   |   ℹ️  non-blocking: skipped ${#SKIPPED[@]}"
echo "   list: ${LIST#$ROOT/}"
for p in ${ONLY[@]+"${ONLY[@]}"}; do echo "   ONLY  $p"; done
for p in ${DIFF[@]+"${DIFF[@]}"}; do echo "   DIFF  $p   (both sides exist and differ — NOT copied, merge by hand)"; done
for p in ${OUTSIDE[@]+"${OUTSIDE[@]}"}; do echo "   OUTSIDE  $p   (untracked — git will not carry this, NOT auto-copied)"; done
for p in ${SKIPPED[@]+"${SKIPPED[@]}"}; do echo "   SKIP  $p   (ignored AND on the named regenerable/sentinel list — does not block)"; done

# 2. RECLAIM (--apply) — copy, then verify byte-identical; a copy that cannot be verified is a harness error
if [ "$MODE" = "--apply" ] && [ "${#ONLY[@]}" -gt 0 ]; then
  bad=0
  for p in ${ONLY[@]+"${ONLY[@]}"}; do
    mkdir -p "$(dirname "$DST/$p")" && cp -p "$SRC/$p" "$DST/$p" && cmp -s "$SRC/$p" "$DST/$p" \
      && echo "   ✅ reclaimed $p" || { echo "   🟥 copy/verify FAILED $p"; bad=$((bad+1)); }
  done
  [ "$bad" -eq 0 ] || { echo "🟥 $bad file(s) not reclaimed — do NOT remove the worktree" >&2; exit 10; }
fi

if [ "${#DIFF[@]}" -gt 0 ]; then
  echo "⚠️  ${#DIFF[@]} file(s) differ on both sides — reconcile by hand before removing the worktree (rc=1)"
  exit 1
fi
if [ "${#ONLY[@]}" -gt 0 ] && [ "$MODE" != "--apply" ]; then
  echo "ℹ️  ${#ONLY[@]} file(s) exist only in the worktree — re-run with --apply to copy them (rc=1 until reclaimed)"
  exit 1
fi
# 🟥 OUTSIDE does not clear with --apply — it is deliberately not copied, so a human must dispose
#    of it before this script will say the removal is safe.
# 🟥 A-3 — only UNTRACKED blocks. Measured on the real repo: an FH worktree carries ignored runtime
#    sentinels outside tracks/ on every run (`.claude/.prior_art_prompted_<session>`,
#    `.claude/.outbound_hook_events.tsv`, `.claude-octopus/state.json`, …). Blocking on those made
#    rc=1 PERMANENT, and the only ways past are deleting a sentinel the hooks still need or reaching
#    for `git worktree remove --force` — i.e. this script's own header warning («over-blocking trains
#    the override») coming true on its primary target.
#    🟥 NOT «ignored always passes»: `tracks/**` is ignored AND is the measured loss class, which is
#    exactly why it keeps its own zone above. The split is by PROVENANCE — untracked means nobody
#    ever told git about it, ignored means someone wrote a rule for it on purpose.
if [ "${#OUTSIDE[@]}" -gt 0 ]; then
  echo "🟥 ${#OUTSIDE[@]} untracked path(s) live ONLY in the worktree and git will not carry them."
  echo "   NOT copied — the destination is a judgment call, not a default."
  echo "   Move or delete each one, then re-run. Until then: do NOT remove the worktree (rc=1)."
  exit 1
fi
# 🟥 A-5 — a partial enumeration never reaches the green line.
if [ "$_DIRTY" -ne 0 ]; then
  echo "🟥 git reported a warning while enumerating — the sweep was PARTIAL, not clean (rc=10)." >&2
  exit 10
fi
# 🟥 A-4 — the green line used to be unconditional, so it said «nothing left» forty lines under a
#    list of files it had just printed. What is skipped must ride along with the verdict.
if [ "${#SKIPPED[@]}" -gt 0 ]; then
  echo "✅ nothing that needs reclaiming — safe to: git worktree remove $WT"
  echo "   (${#SKIPPED[@]} path(s) skipped as regenerable/sentinel — listed above, judged, not unseen)"
else
  echo "✅ nothing left only in the worktree — safe to: git worktree remove $WT"
fi
exit 0

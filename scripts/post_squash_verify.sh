#!/usr/bin/env bash
# post_squash_verify.sh — after a squash merge, check that the merge carried the branch AND that
# the instrument still passes on the merged tree. Two questions, and the second is mandatory.
#
# Origin: tracks/_meta/fh_signal_2026-09-21_post-squash-verify.md. Four PRs were squash-merged in
# one day and none of them was compared afterwards — a green `gh pr merge --squash` was taken as
# "the content landed". A squash guarantees no such thing: conflict resolution, partial apply or a
# moved base can make the branch tip and the merged main differ, silently.
#
#   ① blob check     is each file the branch touched identical on the merge commit?
#   ② rerun          does the instrument pass on the MERGED tree (the branch + everything else on main)?
#
# 🟥 ② IS REQUIRED. Without --rerun the script refuses to run (rc=2). A script that runs only ① and
#   prints green is the shape this repo already got wrong once: a strong half nobody calls beside a
#   weak half that looks like the whole check (CLAUDE.md §Destructive-Op Gate, 2026-08-23 retraction
#   of predelete_check.sh). ① alone cannot see "same files, but broken once combined".
# 🟥 A TRIVIAL ② IS REFUSED (rc=3): empty, `:`, `true`, `exit 0` and friends. And a ② that exits 0 but
#   prints nothing is reported as an instrument failure (rc=4), not a pass — silence is not a result.
#
# USAGE
#   bash scripts/post_squash_verify.sh --tip <branch-tip-sha> --merge <squash-commit> \
#        --rerun '<command that exercises the change>' [--repo <path>] [--keep]
#   --tip    record it BEFORE merging (the branch is deleted by --delete-branch); `git reflog` or the
#            PR's headRefOid also has it: gh pr view <n> --json headRefOid -q .headRefOid
#   --merge  the squash commit on the integration branch (default: HEAD of --repo)
#   --rerun  run with `bash -c` inside a throwaway detached worktree at --merge. Cwd = that worktree.
#
# EXIT  0 both halves pass · 1 content mismatch or ② failed · 2 usage (incl. missing --rerun)
#       3 trivial ② refused · 4 instrument/harness error (② silent, worktree not creatable, bad sha)
#
# Labels for ①, per path the branch changed (merge-base(tip, merge^) .. tip, machine-listed):
#   SAME          blob on --merge == blob on --tip (incl. both absent = deletion carried)
#   COMBINED      differs, AND main also changed that path since the branch was cut — expected for a
#                 merge, not a failure; ② is what vouches for it
#   🟥 DIFFERS    differs and main did not touch the path — the squash lost or altered branch content
# Extra paths in the squash commit that the branch never touched are reported as 🟥 EXTRA.

set -uo pipefail

TIP=""; MERGE=""; RERUN=""; RERUN_SET=0; REPO="."; KEEP=0; PRECHECK=0
# 🟥 cross-family R3: `shift 2` with one arg left fails WITHOUT shifting, so a trailing `--tip` looped
#   forever. Every operand-taking option checks $# first.
_need() { [ $# -ge 2 ] || { echo "🟥 $1 needs a value" >&2; exit 2; }; }
while [ $# -gt 0 ]; do
  case "$1" in
    --tip) _need "$@";   TIP="${2:-}"; shift 2 ;;
    --merge) _need "$@"; MERGE="${2:-}"; shift 2 ;;
    --rerun) _need "$@"; RERUN="${2-}"; RERUN_SET=1; shift 2 ;;
    --repo) _need "$@";  REPO="${2:-}"; shift 2 ;;
    --keep)  KEEP=1; shift ;;
    --precheck) PRECHECK=1; shift ;;   # validate --rerun only (rc 0/2/3), touch no git state — for callers that must refuse BEFORE merging
    -h|--help) sed -n '2,40p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ "$RERUN_SET" -eq 0 ]; then
  echo "🟥 --rerun is required. ① alone cannot see a merge that is byte-correct per file but broken" >&2
  echo "   once combined with the rest of main. Name the command that exercises this change." >&2
  exit 2
fi
[ "$PRECHECK" -eq 1 ] || [ -n "$TIP" ] || { echo "🟥 --tip is required (the branch tip before merge)" >&2; exit 2; }

# ── trivial-command refusal ── normalise whitespace and a trailing ';' then compare
_r=$(printf '%s' "$RERUN" | tr -s '[:space:]' ' ' | sed -e 's/^ *//' -e 's/ *;* *$//')
case "$_r" in
  ""|":"|"true"|"/usr/bin/true"|"/bin/true"|"exit"|"exit 0"|"return 0"|"echo"|"echo ok"|"true && true"|": && :")
    echo "🟥 --rerun '$RERUN' does not exercise anything — refused. A trivial command's rc=0 is not ②." >&2
    exit 3 ;;
esac
# 🟥 cross-family R1 (codex): the exact list above let `printf ok` / `echo ok; :` through — rc=0 with
#   output, so the silence guard passed too. Refuse a command whose EVERY segment (split on ; && || |)
#   starts with a no-op word. Named residual: wrapping (`bash -c 'echo ok'`, a script that only echoes)
#   still passes — closing that needs judging what a command does, which is not this script's call.
_noop=1
while IFS= read -r _seg; do
  _w=$(printf '%s' "$_seg" | sed -e 's/^[[:space:]]*//' | cut -d' ' -f1)
  [ -z "$_w" ] && continue
  case "$_w" in :|true|/bin/true|/usr/bin/true|echo|printf|exit|return) : ;; *) _noop=0; break ;; esac
done <<< "$(_x="${RERUN//&&/$'\n'}"; _x="${_x//||/$'\n'}"; printf '%s' "$_x" | tr ';|' '\n\n')"
# (R2: split with bash substitution, not `sed 's/&&/\n/'` — older BSD sed writes a literal "n".)
if [ "$_noop" -eq 1 ]; then
  echo "🟥 --rerun '$RERUN' only echoes / no-ops — refused. Printing is not exercising the change." >&2
  exit 3
fi

[ "$PRECHECK" -eq 0 ] || { echo "✅ --rerun accepted (precheck)"; exit 0; }

G() { git -C "$REPO" "$@"; }
G rev-parse --git-dir >/dev/null 2>&1 || { echo "🟥 HARNESS-ERROR: not a git repo: $REPO" >&2; exit 4; }
[ -n "$MERGE" ] || MERGE=$(G rev-parse HEAD)
TIP_C=$(G rev-parse --verify -q "$TIP^{commit}")   || { echo "🟥 HARNESS-ERROR: --tip not a commit: $TIP" >&2; exit 4; }
MERGE_C=$(G rev-parse --verify -q "$MERGE^{commit}") || { echo "🟥 HARNESS-ERROR: --merge not a commit: $MERGE" >&2; exit 4; }
PARENT=$(G rev-parse --verify -q "$MERGE_C^") || { echo "🟥 HARNESS-ERROR: --merge has no parent" >&2; exit 4; }
# 🟥 cross-family R1: a squash commit has exactly one parent, and --tip must not be the merge itself
#   (tip == merge compares the commit to itself and renders green).
NPAR=$(G rev-list --parents -n 1 "$MERGE_C" | wc -w | tr -d ' '); NPAR=$((NPAR-1))
[ "$NPAR" -eq 1 ] || { echo "🟥 HARNESS-ERROR: --merge has $NPAR parents — not a squash commit" >&2; exit 4; }
[ "$TIP_C" != "$MERGE_C" ] || { echo "🟥 HARNESS-ERROR: --tip equals --merge — nothing to compare" >&2; exit 4; }
MB=$(G merge-base "$TIP_C" "$PARENT") || { echo "🟥 HARNESS-ERROR: no merge-base between tip and merge^" >&2; exit 4; }

echo "── post-squash verify ── tip=${TIP_C:0:10} merge=${MERGE_C:0:10} base-of-branch=${MB:0:10}"

# ── ① blob check. Path lists come from git, never from the caller.
# 🟥 cross-family R1: without -z git C-quotes unusual names ("x\ny"), the quoted string is looked up
#   literally, both sides read ABSENT and a dropped file renders SAME.
# 🟥 cross-family R2: the R1 fix carried paths one-per-line with newlines swapped for \001 — and a
#   path containing a real \001 byte then collided with the sentinel (fail-open again). No sentinel
#   now: NUL-delimited lists go straight into arrays, membership is an exact array compare.
_names_into() {  # _names_into <array-name> <rev> <rev>
  # 🟥 cross-family R3: `< <(git diff …)` drops git's rc — a failed diff became an empty list and the
  #   EXTRA scan silently had nothing to scan. Capture to a file, check rc, then read.
  local _n="$1" _p _f _rc; shift; eval "$_n=()"
  _f=$(mktemp "${TMPDIR:-/tmp}/psv-names-XXXXXX")
  G diff -z --name-only "$@" > "$_f"; _rc=$?
  if [ "$_rc" -ne 0 ]; then rm -f "$_f"
    echo "🟥 HARNESS-ERROR: git diff failed (rc=$_rc) for $* — path inventory untrustworthy" >&2; exit 4; fi
  while IFS= read -r -d '' _p; do eval "$_n[\${#$_n[@]}]=\"\$_p\""; done < "$_f"
  rm -f "$_f"
}
_in() {  # _in <needle> <elements...>
  local _x="$1" _e; shift; for _e in "$@"; do [ "$_e" = "$_x" ] && return 0; done; return 1
}
_names_into BR   "$MB" "$TIP_C"
_names_into SQ   "$PARENT" "$MERGE_C"
_names_into MAIN "$MB" "$PARENT"
[ "${#BR[@]}" -gt 0 ] || { echo "🟥 HARNESS-ERROR: the branch changed no paths (mb..tip empty) — wrong --tip?" >&2; exit 4; }

# 🟥 cross-family R4: compare the TREE ENTRY (mode + type + oid), not the blob — a squash that drops a
#   `chmod +x` keeps the same blob and rendered SAME. Exec-bit loss is how hooks get silently disarmed.
# 🟥 no pipeline here (repo pipefail class-lock, 2026-09-24): the first version piped ls-tree into
#   `head -1`, and an early-closing reader can kill the producer → empty entry on BOTH sides →
#   ABSENT == ABSENT → SAME. A path-exact ls-tree prints at most one line; strip at the tab in bash.
_blob() { local _e; _e=$(G ls-tree "$1" -- "$2" 2>/dev/null) || _e=""
          _e="${_e%%$'\t'*}"; [ -n "$_e" ] && printf '%s' "$_e" || echo "ABSENT"; }
BAD=0; N=0
for p in "${BR[@]}"; do
  N=$((N+1))
  bt=$(_blob "$TIP_C" "$p"); bm=$(_blob "$MERGE_C" "$p")
  if [ "$bt" = "$bm" ]; then
    printf '  ✅ SAME       %q\n' "$p"
  elif _in "$p" ${MAIN[@]+"${MAIN[@]}"}; then
    printf '  ⚠️  COMBINED   %q  (main also changed it — ② vouches for this one)\n' "$p"
  else
    printf '  🟥 DIFFERS    %q  (tip=%s merge=%s)\n' "$p" "$bt" "$bm"; BAD=1
  fi
done
for p in ${SQ[@]+"${SQ[@]}"}; do
  _in "$p" "${BR[@]}" && continue
  printf '  🟥 EXTRA      %q  (in the squash, never on the branch)\n' "$p"; BAD=1
done
echo "  ① $N branch path(s) compared"

# ── ② rerun on the merged tree, in a throwaway detached worktree (never touches the caller's HEAD)
WT=$(mktemp -d "${TMPDIR:-/tmp}/post-squash-XXXXXX"); rmdir "$WT"
if ! G worktree add --detach -q "$WT" "$MERGE_C" >/dev/null 2>&1; then
  echo "🟥 HARNESS-ERROR: could not create a worktree at ${MERGE_C:0:10} — ② not run, not passed" >&2
  exit 4
fi
_cleanup() { [ "$KEEP" -eq 1 ] && { echo "  (kept worktree: $WT)"; return; }; G worktree remove --force "$WT" >/dev/null 2>&1 || true; }
trap _cleanup EXIT

echo "  ② rerun in merged tree: $RERUN"
OUT=$(cd "$WT" && bash -c "$RERUN" 2>&1); RC=$?
printf '%s\n' "$OUT" | tail -8 | sed 's/^/     │ /'
if [ "$RC" -ne 0 ]; then
  echo "  🟥 ② FAILED rc=$RC on the merged tree"; exit 1
fi
if [ -z "$(printf '%s' "$OUT" | tr -d '[:space:]')" ]; then
  echo "  🟥 ② exited 0 but printed NOTHING — instrument silence, not a pass" >&2; exit 4
fi
echo "  ✅ ② rc=0 on the merged tree"

[ "$BAD" -eq 0 ] || { echo "🟥 ① content mismatch — see DIFFERS/EXTRA above"; exit 1; }
echo "✅ post-squash verify: ① carried · ② passes on the merged tree"
exit 0

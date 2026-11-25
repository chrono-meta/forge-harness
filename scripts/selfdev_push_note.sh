#!/usr/bin/env bash
# selfdev_push_note.sh — one PR comment per self-dev push: what this push changed and how to undo it.
#
# Why (2026-11-25, Claude Ship method borrow, tracks/_meta/ship_method_borrow_design_2026-11-25.md candidate 1):
# when the unattended loop pushes to a PR, the morning reader had to open the diff to learn what moved, and no
# undo command was written anywhere. This leaves three machine-made lines on the PR: the commit range, how many
# commits and files, and the undo. It changes nothing in the repo and decides nothing.
#
# Usage: selfdev_push_note.sh --repo <clone> --slug <owner/name> --pr <n> --to <head oid> [--from <old head oid>] [--dry]
#   --from absent = a new PR: the range is merge-base(origin/main, head)..head and the undo is «close unmerged».
#   --dry prints the body and posts nothing.
# The body carries only ids and counts from git — no file names, no commit subjects — so nothing private can ride
# along on a public PR (named choice: the reader opens the range for the names).
# Exit: 0 posted (or printed with --dry) · 2 refused before posting (bad argument, git could not read the range —
# numbers are never guessed) · 3 gh comment failed.
set -u
REPO=""; SLUG=""; PR=""; FROM=""; TO=""; DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --repo|--slug|--pr|--from|--to)
      [ $# -ge 2 ] || { echo "push-note: $1 needs a value" >&2; exit 2; }
      case "$1" in --repo) REPO="$2" ;; --slug) SLUG="$2" ;; --pr) PR="$2" ;; --from) FROM="$2" ;; --to) TO="$2" ;; esac
      shift 2 ;;
    --dry)  DRY=1; shift ;;
    *) echo "push-note: unknown argument «$1»" >&2; exit 2 ;;
  esac
done
hex() { printf '%s' "$1" | grep -qE '^([0-9a-f]{40}|[0-9a-f]{64})$'; }
case "$PR" in ''|*[!0-9]*) echo "push-note: --pr must be a number" >&2; exit 2 ;; esac
[ -n "$SLUG" ] && [ -d "$REPO" ] || { echo "push-note: --repo <dir> and --slug are required" >&2; exit 2; }
hex "$TO" || { echo "push-note: --to is not a full commit id" >&2; exit 2; }
[ -z "$FROM" ] || hex "$FROM" || { echo "push-note: --from is not a full commit id" >&2; exit 2; }
[ "$FROM" != "$TO" ] || { echo "push-note: --from equals --to — nothing was pushed" >&2; exit 2; }

g() { git -C "$REPO" "$@" 2>/dev/null; }
g cat-file -e "$TO^{commit}" || { echo "push-note: head $TO not in $REPO — fetch first; not posting" >&2; exit 2; }
if [ -n "$FROM" ]; then
  g cat-file -e "$FROM^{commit}" || { echo "push-note: old head $FROM not in $REPO; not posting" >&2; exit 2; }
  # a rewritten branch (old head not an ancestor) has no honest «this push» range — say so instead of a range
  g merge-base --is-ancestor "$FROM" "$TO"; anc=$?
  case "$anc" in
    0) BASE="$FROM"; KIND=update ;;
    1) BASE=""; KIND=rewritten ;;
    *) echo "push-note: ancestry check failed (git rc $anc); not posting" >&2; exit 2 ;;   # codex R1: an error is not «rewritten»
  esac
else
  BASE=$(g merge-base origin/main "$TO") || { echo "push-note: no merge-base with origin/main; not posting" >&2; exit 2; }
  KIND=new
fi
if [ -n "$BASE" ]; then
  NC=$(g rev-list --count "$BASE..$TO") || { echo "push-note: rev-list failed; not posting" >&2; exit 2; }
  names=$(g diff --name-only "$BASE" "$TO") || { echo "push-note: diff failed; not posting" >&2; exit 2; }   # codex R1: the listing's own status
  NF=$(printf '%s\n' "$names" | grep -c .)
  NM=$(g rev-list --count --merges "$BASE..$TO") || { echo "push-note: rev-list failed; not posting" >&2; exit 2; }
fi
s() { printf '%s' "$1" | cut -c1-12; }
# codex R1 (A): a private, exclusively created file — never a predictable /tmp name another user could plant
BODY=$(mktemp "${TMPDIR:-/tmp}/push_note.XXXXXX") || { echo "push-note: mktemp failed; not posting" >&2; exit 2; }
trap 'rm -f "$BODY"' EXIT
{
  echo "selfdev push note (machine-written: ids and counts only)"
  case "$KIND" in
    update)
      echo "- this push: \`$(s "$BASE")..$(s "$TO")\` · $NC commit(s) · $NF file(s) changed"
      if [ "$NM" -eq 0 ]; then
        echo "- undo before merge: on this branch \`git revert --no-edit $(s "$BASE")..$(s "$TO")\`, then push (no reset, no force-push)"
      else   # codex R1: a range revert stops at a merge commit — say so instead of a command that fails half-way
        echo "- undo before merge: the range holds $NM merge commit(s), so a range revert stops part-way — revert by hand (\`git revert -m 1\` for each merge), then push"
      fi
      ;;
    new)
      echo "- new PR: \`$(s "$BASE")..$(s "$TO")\` from main · $NC commit(s) · $NF file(s) changed"
      echo "- undo before merge: close this PR unmerged"
      ;;
    rewritten)
      echo "- this push rewrote the branch: old head \`$(s "$FROM")\` is not in the new history (head \`$(s "$TO")\`) — no range to show"
      echo "- undo before merge: compare the two heads by hand; the loop never force-pushes, so this came from elsewhere"
      ;;
  esac
  echo "- undo after merge: the merge receipt prints \`git revert <merge commit>\`"
} > "$BODY" || exit 2
if [ "$DRY" = 1 ]; then cat "$BODY"; exit 0; fi
gh pr comment "$PR" -R "$SLUG" --body-file "$BODY" < /dev/null > /dev/null 2>&1 || { echo "push-note: gh pr comment failed for #$PR" >&2; exit 3; }
echo "push-note: posted on #$PR ($KIND)"
exit 0

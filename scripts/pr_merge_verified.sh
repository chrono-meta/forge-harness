#!/usr/bin/env bash
# pr_merge_verified.sh — squash-merge a PR, then verify the merge actually carried it.
#
# This is the WIRING for scripts/post_squash_verify.sh. That script needs the branch tip, and the
# tip is gone once `gh pr merge --delete-branch` runs — so the only reliable moment to capture it is
# before the merge. A verifier nobody can feed is a verifier nobody calls; this wrapper feeds it.
#
#   1. record the PR head (headRefOid) and fetch that object locally
#   2. gh pr merge --squash --delete-branch --admin     (the repo's normal path, CLAUDE.md §Integration)
#   3. read the merge commit from GitHub, fetch it
#   4. post_squash_verify.sh --tip <head> --merge <merge commit> --rerun <cmd>
#
# 🟥 --rerun is REQUIRED and is checked BEFORE the merge (rc=2). Discovering after an irreversible-ish
#   step that the verification half cannot run would recreate the exact defect post_squash_verify
#   exists to stop: a merge whose second half nobody ran.
# 🟥 This script does not decide whether to merge. Approval is still yours — it only makes the
#   verification impossible to forget once you do.
#
# USAGE   bash scripts/pr_merge_verified.sh <pr-number> --rerun '<command>' [--repo <path>]
# EXIT    0 merged + verified · 1 merged but verify FAILED (the merge stands — act on it)
#         2 usage (nothing merged) · 3 trivial --rerun refused (nothing merged)
#         4 harness error (see message: before or after the merge)
#         6 merge accepted but not completed (queue/lag) — NOT verified, nothing claimed
#         5 merge itself failed (nothing merged)

set -uo pipefail
PR=""; RERUN=""; RERUN_SET=0; REPO="."
_need() { [ $# -ge 2 ] || { echo "🟥 $1 needs a value" >&2; exit 2; }; }
while [ $# -gt 0 ]; do
  case "$1" in
    --rerun) _need "$@"; RERUN="${2-}"; RERUN_SET=1; shift 2 ;;
    --repo)  _need "$@"; REPO="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,24p' "$0"; exit 0 ;;
    -*) echo "unknown arg: $1" >&2; exit 2 ;;
    *) [ -z "$PR" ] || { echo "🟥 one PR number only" >&2; exit 2; }; PR="$1"; shift ;;
  esac
done
case "$PR" in ''|*[!0-9]*) echo "🟥 usage: pr_merge_verified.sh <pr-number> --rerun '<cmd>'" >&2; exit 2 ;; esac
[ "$RERUN_SET" -eq 1 ] || { echo "🟥 --rerun is required — checked before merging so the verify half cannot be skipped" >&2; exit 2; }
PSV="$(cd "$(dirname "$0")" && pwd)/post_squash_verify.sh"
[ -f "$PSV" ] || { echo "🟥 HARNESS-ERROR (before merge): $PSV missing — not merging" >&2; exit 4; }

# the --rerun is validated by the SAME code that will judge it after the merge — no second list to drift
bash "$PSV" --precheck --rerun "$RERUN" >/dev/null; _pc=$?
[ "$_pc" -eq 0 ] || { echo "🟥 --rerun refused before merging (rc=$_pc) — nothing merged" >&2; exit "$_pc"; }

cd "$REPO" || { echo "🟥 HARNESS-ERROR (before merge): cannot cd $REPO" >&2; exit 4; }

# 1. head before merge
HEAD_OID=$(gh pr view "$PR" --json headRefOid -q .headRefOid < /dev/null) || HEAD_OID=""
[ -n "$HEAD_OID" ] || { echo "🟥 HARNESS-ERROR (before merge): could not read PR #$PR head" >&2; exit 4; }
git fetch -q origin "pull/$PR/head" < /dev/null 2>/dev/null || git fetch -q origin "$HEAD_OID" < /dev/null 2>/dev/null || true
git cat-file -e "$HEAD_OID^{commit}" 2>/dev/null \
  || { echo "🟥 HARNESS-ERROR (before merge): PR head $HEAD_OID not fetchable — not merging" >&2; exit 4; }
echo "── PR #$PR head recorded: $HEAD_OID"

# 2. merge
# 🟥 cross-family W1: pin the merge to the head we RECORDED. Without it, a push landing between the
#   record and the merge gets squashed in unverified, and «merged and verified» describes a commit
#   nobody checked. GitHub refuses the merge if the head moved — that refusal is rc=5, nothing merged.
if ! gh pr merge "$PR" --squash --delete-branch --admin --match-head-commit "$HEAD_OID" < /dev/null; then
  echo "🟥 merge failed — nothing merged" >&2; exit 5
fi

# 3. merge commit
# 🟥 cross-family W1: `gh pr merge` exiting 0 is not «merged» — a merge queue or auto-merge accepts
#   the request and returns. Ask GitHub for the state; only MERGED with a real oid continues.
ST=$(gh pr view "$PR" --json state -q .state < /dev/null) || ST=""
MC=$(gh pr view "$PR" --json mergeCommit -q .mergeCommit.oid < /dev/null) || MC=""
if [ "$ST" != "MERGED" ] || [ -z "$MC" ] || [ "$MC" = "null" ]; then
  echo "🟥 merge ACCEPTED but not completed (state=${ST:-?} mergeCommit=${MC:-none}) — queued or lagging." >&2
  echo "   NOT verified. When it lands: bash $PSV --tip $HEAD_OID --merge <merge commit> --rerun '<cmd>'" >&2
  exit 6
fi
git fetch -q origin < /dev/null 2>/dev/null || true
# W2 (B): a narrow/single-branch refspec may not bring the merge commit — ask for it by oid too
git cat-file -e "$MC^{commit}" 2>/dev/null || git fetch -q origin "$MC" < /dev/null 2>/dev/null || true
git cat-file -e "$MC^{commit}" 2>/dev/null \
  || { echo "🟥 HARNESS-ERROR (AFTER merge): merge commit $MC not fetchable — run post_squash_verify by hand with --tip $HEAD_OID --merge $MC" >&2; exit 4; }
echo "── merged as $MC"

# 4. verify
bash "$PSV" --repo . --tip "$HEAD_OID" --merge "$MC" --rerun "$RERUN"; rc=$?
case "$rc" in
  0) echo "✅ PR #$PR merged and verified"; exit 0 ;;
  1) echo "🟥 PR #$PR IS MERGED but verification FAILED — the merge stands; fix forward or revert" >&2; exit 1 ;;
  *) echo "🟥 HARNESS-ERROR (AFTER merge): post_squash_verify rc=$rc — PR #$PR is merged, verification did not complete" >&2; exit 4 ;;
esac

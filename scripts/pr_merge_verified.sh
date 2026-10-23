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
# USAGE   bash scripts/pr_merge_verified.sh <pr-number> --rerun '<command>' [--repo <path>] [--lease '<label>']
# RECEIPT once GitHub has accepted the merge request (every outcome from there: verified · verify failed · queued/not completed ·
#         merged from another head · not fetchable — never for a refusal or a merge GitHub did not take) one JSON line goes to
#         ${PMV_RECEIPTS:-<git common dir>/fh-merge-receipts.jsonl} — local, never pushed: pr · head · merge · outcome ·
#         actor (agent-session:claude-code when CLAUDECODE is set, else human-or-unknown — a human cannot be proven) ·
#         lease (the --lease label of the standing approval the caller merges under, else NONE — recorded, not enforced) · rerun.
#         Why: arXiv:2610.28683 — 27% of merges that passed a «non-author review» gate rested on an agent approving under a
#         human account; who decided must be on the record, not inferred later (frontier digest 2026-10-23).
# EXIT    0 merged + verified · 1 merged but verify FAILED (the merge stands — act on it)
#         2 usage (nothing merged) · 3 trivial --rerun refused (nothing merged)
#         4 harness error (see message: before or after the merge)
#         6 merge accepted but not completed (queue/lag) — NOT verified, nothing claimed
#         5 merge NOT observed (gh failed and GitHub still reports OPEN/CLOSED after bounded re-reads —
#           an observation, not proof: stale state can outlast the re-reads)
#         (gh non-zero but GitHub says MERGED → continue to verify; state unreadable → 4, outcome UNKNOWN)

set -uo pipefail
PR=""; RERUN=""; RERUN_SET=0; REPO="."; LEASE="NONE"
_need() { [ $# -ge 2 ] || { echo "🟥 $1 needs a value" >&2; exit 2; }; }
while [ $# -gt 0 ]; do
  case "$1" in
    --rerun) _need "$@"; RERUN="${2-}"; RERUN_SET=1; shift 2 ;;
    --repo)  _need "$@"; REPO="${2:-}"; shift 2 ;;
    --lease) _need "$@"; LEASE="${2-}"; [ -n "$LEASE" ] || { echo "🟥 --lease needs a non-empty label" >&2; exit 2; }; shift 2 ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
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

# receipt (after GitHub accepted the merge request — a queued merge counts: the request was made under this actor/lease). Best-effort: a receipt that cannot be written is said, never silently skipped,
# and never changes the exit code — the merge already happened.
_receipt() { # outcome merge_oid
  local f="${PMV_RECEIPTS:-}"
  if [ -z "$f" ]; then local gd; gd=$(git rev-parse --git-common-dir 2>/dev/null) || gd=""; [ -n "$gd" ] && f="$gd/fh-merge-receipts.jsonl"; fi
  local actor="human-or-unknown"; [ -n "${CLAUDECODE:-}" ] && actor="agent-session:claude-code"
  if [ -z "$f" ] || ! PMV_R_PR="$PR" PMV_R_HEAD="$HEAD_OID" PMV_R_MERGE="${2:-}" PMV_R_OUT="$1" PMV_R_ACTOR="$actor" PMV_R_LEASE="$LEASE" \
       PMV_R_RERUN="$RERUN" python3 -c 'import json,os,time
e=os.environ
print(json.dumps({"at":time.strftime("%Y-%m-%dT%H:%M:%S%z"),"pr":int(e["PMV_R_PR"]),"head":e["PMV_R_HEAD"],"merge":e["PMV_R_MERGE"] or None,
"outcome":e["PMV_R_OUT"],"actor":e["PMV_R_ACTOR"],"lease":e["PMV_R_LEASE"],"rerun":e["PMV_R_RERUN"]},ensure_ascii=False))' >> "$f" 2>/dev/null; then
    echo "⚠️  merge receipt NOT written (${f:-no git dir}) — record by hand: PR #$PR $1 actor=$actor lease=$LEASE" >&2
  else
    echo "── receipt: $f (actor=$actor · lease=$LEASE · $1)"
  fi
}

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
#   nobody checked. GitHub refuses the merge if the head moved — that refusal is rc=5 (merge not observed).
# 🟥 gh's exit code is not the server's answer: gh merges on GitHub, THEN switches/deletes local
#   branches, and that local half can fail (e.g. main checked out in another worktree) after the
#   merge landed (2026-10-12, FoD #210 reported «nothing merged» while MERGED). Ask GitHub.
if ! gh pr merge "$PR" --squash --delete-branch --admin --match-head-commit "$HEAD_OID" < /dev/null; then
  # bounded re-reads: one OPEN right after a server merge can be API lag, not a refusal (codex A1)
  ST=""; HO=""
  for _try in 1 2 3; do
    _sv=$(gh pr view "$PR" --json state,headRefOid -q '.state+" "+.headRefOid' < /dev/null) || _sv=""
    ST=$(printf '%s' "$_sv" | awk '{print $1}'); HO=$(printf '%s' "$_sv" | awk '{print $2}')
    [ "$ST" = "OPEN" ] || break
    [ "$_try" -lt 3 ] && sleep "${PMV_RETRY_SLEEP:-2}"
  done
  case "$ST" in
    MERGED)
      # MERGED alone does not say WHICH head merged — someone may have pushed and merged after we
      # recorded (codex A2). Only the recorded head may continue to verification.
      [ "$HO" = "$HEAD_OID" ] || { _receipt "merged-other-head-not-verified" ""; echo "🟥 HARNESS-ERROR: gh pr merge failed, and PR #$PR is MERGED from head ${HO:-?}, not the recorded $HEAD_OID — NOT verified" >&2; exit 4; }
      echo "⚠️  gh pr merge exited non-zero; GitHub reports MERGED from the recorded head — continuing to verify" >&2
      echo "   the head branch may still exist on origin — delete it by hand if so" >&2 ;;
    # 🟥 a persistent OPEN cannot prove nothing merged (state may still be stale) — say what was seen
    OPEN|CLOSED) echo "🟥 merge NOT observed — gh pr merge exited non-zero and GitHub reports $ST (read $_try time(s))" >&2
                 echo "   if gh's error above was about LOCAL branches, re-check: gh pr view $PR --json state,mergeCommit" >&2; exit 5 ;;
    *) echo "🟥 HARNESS-ERROR: gh pr merge failed and the PR state is unreadable — merge outcome UNKNOWN; check: gh pr view $PR --json state,mergeCommit" >&2; exit 4 ;;
  esac
fi

# 3. merge commit
# 🟥 cross-family W1: `gh pr merge` exiting 0 is not «merged» — a merge queue or auto-merge accepts
#   the request and returns. Ask GitHub for the state; only MERGED with a real oid continues.
ST=$(gh pr view "$PR" --json state -q .state < /dev/null) || ST=""
MC=$(gh pr view "$PR" --json mergeCommit -q .mergeCommit.oid < /dev/null) || MC=""
if [ "$ST" != "MERGED" ] || [ -z "$MC" ] || [ "$MC" = "null" ]; then
  echo "🟥 merge ACCEPTED but not completed (state=${ST:-?} mergeCommit=${MC:-none}) — queued or lagging." >&2
  echo "   NOT verified. When it lands: bash $PSV --tip $HEAD_OID --merge <merge commit> --rerun '<cmd>'" >&2
  _receipt "accepted-not-completed" ""
  exit 6
fi
git fetch -q origin < /dev/null 2>/dev/null || true
# W2 (B): a narrow/single-branch refspec may not bring the merge commit — ask for it by oid too
git cat-file -e "$MC^{commit}" 2>/dev/null || git fetch -q origin "$MC" < /dev/null 2>/dev/null || true
git cat-file -e "$MC^{commit}" 2>/dev/null \
  || { _receipt "merged-not-fetchable" "$MC"; echo "🟥 HARNESS-ERROR (AFTER merge): merge commit $MC not fetchable — run post_squash_verify by hand with --tip $HEAD_OID --merge $MC" >&2; exit 4; }
echo "── merged as $MC"

# 4. verify
bash "$PSV" --repo . --tip "$HEAD_OID" --merge "$MC" --rerun "$RERUN"; rc=$?
case "$rc" in
  0) _receipt "verified" "$MC"; echo "✅ PR #$PR merged and verified"; exit 0 ;;
  1) _receipt "verify-failed" "$MC"; echo "🟥 PR #$PR IS MERGED but verification FAILED — the merge stands; fix forward or revert" >&2; exit 1 ;;
  *) _receipt "verify-incomplete" "$MC"; echo "🟥 HARNESS-ERROR (AFTER merge): post_squash_verify rc=$rc — PR #$PR is merged, verification did not complete" >&2; exit 4 ;;
esac

#!/usr/bin/env bash
# main_commit_guard.sh — block a LOCAL commit of FH assets straight onto main/master.
#
# WHY (2026-09-29, operator «추천대로»): the integration branch is PR-only, and the server enforces
# it on push (`enforce_admins`), but local commits to `main` kept happening anyway — N≥5 measured
# (2026-09-11 list, 09-18 twice, 09-20). Each one had to be moved to a branch by hand afterwards,
# and on a shared checkout a stray `main` commit is also what the next session's `git switch -c`
# silently inherits. The push gate catches it late; this catches it at the point it is made.
#
# SCOPE — deliberately narrow:
#   · Called by templates/.git-hooks/pre-commit ONLY on the path where an FH asset is staged. A
#     commit with no FH asset (companion store, non-FH files) never reaches this script.
#   · «FH asset» means what the 4-axis classifier in the hook calls one (HEAVY/LIGHT). A commit that
#     stages only files outside it — e.g. `package.json` alone — does not reach this script. Named
#     residual, not widened here: widening the classifier changes the 4-axis gate too.
#   · Blocks on branch `main` or `master` — INCLUDING merge / cherry-pick / revert / `--amend`
#     commits made while on main: each of those writes a new commit onto main. Only a detached HEAD
#     (rebase in progress · bisect) passes, because no branch is being written.
#   · If this script is absent the hook warns and does NOT block (same as branch_claim.sh): a
#     consumer install may carry the hook template without the scripts/ helper.
#   · Override: MAIN_COMMIT_OK=1 — same channel shape as MAIN_PUSH_OK / DESTRUCTIVE_OP_OK /
#     PUBLIC_SURFACE_OK. Every use is appended to tracks/_meta/.main_commit_override_log.
#
# Exit: 0 pass · 1 block. Prints nothing on a plain pass (the hook's output is already long).
# Anchor: scripts/test_main_commit_guard_lanes.sh (unit + real-hook known-pair + revert).
set -u
# EVIDENCE_ROOT is supplied by the hook (main tree, worktree-safe); direct callers may point it elsewhere.
ROOT="${EVIDENCE_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
BRANCH="${MAIN_GUARD_BRANCH:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")}"

case "$BRANCH" in
  main|master) ;;
  *) exit 0 ;;
esac

if [ "${MAIN_COMMIT_OK:-0}" = "1" ]; then
  echo "  ⚠️  [main-commit] FH asset committed directly on '$BRANCH' by MAIN_COMMIT_OK=1 (logged)"
  mkdir -p "$ROOT/tracks/_meta" 2>/dev/null
  echo "$(date +%Y-%m-%dT%H:%M:%S) MAIN_COMMIT_OK override — branch $BRANCH — $(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ') staged path(s)" \
    >> "$ROOT/tracks/_meta/.main_commit_override_log" 2>/dev/null || true
  exit 0
fi

echo "  ❌ [main-commit] FH asset staged on '$BRANCH' — the integration branch is PR-only."
echo "     Move it:   git switch -c <branch>   (the staged changes come with you), then commit there."
echo "     Deliberate? MAIN_COMMIT_OK=1 git commit …   (logged to tracks/_meta/.main_commit_override_log)"
exit 1

#!/usr/bin/env bash
# below_floor_scan.sh — standing consumer for below-floor adversarial markers
#
# The pre-commit hook accepts a below-floor Axis-2 pass when an operator ack is
# present, on the promise that "the weekly audit re-queues below-floor markers
# for floor-tier re-run" (§Floor governance, multi_model_sidecar_strategy.md).
# This script IS that consumer: it enumerates below-floor markers and reports
# which ones still await floor-tier re-validation. Read-only, zero side effects.
#
# Resolution protocol (append to the marker after acting — machine-greppable):
#   floor-rerun: <YYYY-MM-DD> <model> PASS|FAIL   ← Axis 2 re-run at >= floor
#   floor-writeoff: <YYYY-MM-DD> <one-line reason> ← operator writes the ack off
#
# Usage: bash scripts/below_floor_scan.sh [repo_root]
# Exit:  0 = no pending below-floor markers; 1 = pending re-runs found
#        (manual weekly-audit step — Phase 1.5; exit 1 = raise the pending
#        items as S-tier. No automated caller is wired yet.)

set -uo pipefail

REPO_ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
MARKER_DIR="$REPO_ROOT/tracks/_meta"
PENDING=0
TOTAL=0

# Worktree redirect (2026-11-20 weekly audit): tracks/ is gitignored, so a git worktree has no
# markers of its own and the scan printed «0 total, 0 pending» rc 0 while the main checkout held
# 4 markers — «not read» rendered as «clean». The pre-commit hook WRITES markers to EVIDENCE_ROOT
# (the main checkout, via --git-common-dir), so with no root argument a worktree reads exactly
# there — the same rule, so writer and reader agree. If that place has no tracks/_meta, say
# NOT READ (rc unchanged — a CI worktree must not turn red). An explicit root is never redirected;
# a main checkout and a fresh clone are unchanged. The common dir is resolved to an absolute path
# from the cwd (git prints it relative to the cwd, not to the top level) and must be a `.git`
# directory, so a bare repo, --separate-git-dir or a submodule never names an unrelated parent.
WT_NOTE=""
if [ -z "${1:-}" ]; then
  _gcd=$(git rev-parse --git-common-dir 2>/dev/null); _rc=$?
  if [ "$_rc" -eq 0 ] && [ -n "$_gcd" ]; then
    _gcd=$(cd "$_gcd" 2>/dev/null && pwd -P) || _gcd=""
    _here=$(cd "$REPO_ROOT" 2>/dev/null && pwd -P) || _here="$REPO_ROOT"
    if [ -n "$_gcd" ] && [ "$(basename "$_gcd")" = .git ]; then
      _hub=$(dirname "$_gcd")
      if [ "$_hub" != "$_here" ]; then
        if [ -d "$_hub/tracks/_meta" ]; then
          MARKER_DIR="$_hub/tracks/_meta"
          WT_NOTE="   (git worktree — read the main checkout's tracks/_meta, where the pre-commit hook writes markers)"
        else
          WT_NOTE="   (git worktree — the main checkout has no tracks/_meta: markers NOT READ, the counts below are not a clean result)"
        fi
      fi
    fi
  fi
fi

echo "── below-floor marker scan: $MARKER_DIR ──"
[ -n "$WT_NOTE" ] && echo "$WT_NOTE"

if [ ! -d "$MARKER_DIR" ]; then
  echo "   (no tracks/_meta directory — nothing to scan)"
  exit 0
fi

SONNET_PENDING=0
for m in "$MARKER_DIR"/.axes_23_passed_*.marker; do
  [ -e "$m" ] || continue
  # sonnet-floor lane (Sonnet-Floor Doctrine 2026-07-10): anchored Sonnet passes are
  # first-class at commit time but provisional for judged depth — queued here as
  # R-tier (advisory re-validation), distinct from below-floor's S-tier hard queue.
  if grep -qE '^[[:space:]]*floor-status:[[:space:]]*sonnet-floor' "$m"; then
    name=$(basename "$m")
    rerun=$(grep -m1 -E '^[[:space:]]*floor-rerun:' "$m" \
            | sed -E 's/^[[:space:]]*floor-rerun:[[:space:]]*//' || true)
    writeoff=$(grep -m1 -E '^[[:space:]]*floor-writeoff:' "$m" \
               | sed -E 's/^[[:space:]]*floor-writeoff:[[:space:]]*//' || true)
    if [ -n "$rerun" ]; then
      echo "✅ RESOLVED (re-run)   $name — floor-rerun: $rerun"
    elif [ -n "$writeoff" ]; then
      echo "✅ RESOLVED (writeoff) $name — floor-writeoff: $writeoff"
    else
      SONNET_PENDING=$((SONNET_PENDING + 1))
      anchor=$(grep -m1 -E '^[[:space:]]*axis2-anchor:' "$m" \
               | sed -E 's/^[[:space:]]*axis2-anchor:[[:space:]]*//' || true)
      echo "🟨 R-tier re-validate  $name (sonnet-floor)"
      echo "     axis2-anchor: ${anchor:-<missing>}"
      echo "     action: re-run judged depth at >= opus or via sidecar dispatch when"
      echo "             available, append 'floor-rerun: ...' — or 'floor-writeoff: ...'"
    fi
    continue
  fi
  grep -qE '^[[:space:]]*floor-status:[[:space:]]*below-floor' "$m" || continue
  TOTAL=$((TOTAL + 1))
  name=$(basename "$m")
  model=$(grep -m1 -E '^[[:space:]]*axis2-model:' "$m" \
          | sed -E 's/^[[:space:]]*axis2-model:[[:space:]]*//' || true)
  ack=$(grep -m1 -E '^[[:space:]]*below-floor-ack:' "$m" \
        | sed -E 's/^[[:space:]]*below-floor-ack:[[:space:]]*//' || true)
  rerun=$(grep -m1 -E '^[[:space:]]*floor-rerun:' "$m" \
          | sed -E 's/^[[:space:]]*floor-rerun:[[:space:]]*//' || true)
  writeoff=$(grep -m1 -E '^[[:space:]]*floor-writeoff:' "$m" \
             | sed -E 's/^[[:space:]]*floor-writeoff:[[:space:]]*//' || true)

  if [ -n "$rerun" ]; then
    echo "✅ RESOLVED (re-run)   $name — floor-rerun: $rerun"
  elif [ -n "$writeoff" ]; then
    echo "✅ RESOLVED (writeoff) $name — floor-writeoff: $writeoff"
  else
    PENDING=$((PENDING + 1))
    echo "🟥 PENDING re-run      $name"
    echo "     axis2-model: ${model:-<missing>} | ack: ${ack:-<missing>}"
    echo "     action: re-run Axis 2 at >= floor (opus), append 'floor-rerun: ...'"
    echo "             or operator writes off: append 'floor-writeoff: ...'"
  fi
done

echo "── below-floor markers: $TOTAL total, $PENDING pending (S-tier) ──"
echo "── sonnet-floor markers pending re-validation: $SONNET_PENDING (R-tier, advisory) ──"
# Exit semantics unchanged: only below-floor (S-tier) hard-fails the scan.
# sonnet-floor pendings are advisory — reported, never exit-blocking (doctrine:
# Sonnet base is first-class; the queue exists so residuals terminate, not decorate).
[ "$PENDING" -gt 0 ] && exit 1
exit 0

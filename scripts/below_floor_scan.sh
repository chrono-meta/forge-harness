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

echo "── below-floor marker scan: $MARKER_DIR ──"

if [ ! -d "$MARKER_DIR" ]; then
  echo "   (no tracks/_meta directory — nothing to scan)"
  exit 0
fi

for m in "$MARKER_DIR"/.axes_23_passed_*.marker; do
  [ -e "$m" ] || continue
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

echo "── below-floor markers: $TOTAL total, $PENDING pending ──"
[ "$PENDING" -gt 0 ] && exit 1
exit 0

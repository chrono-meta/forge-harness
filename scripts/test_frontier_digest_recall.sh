#!/usr/bin/env bash
# test_frontier_digest_recall.sh — structural recall regression for the frontier digest source list.
# Known-positive items (fixtures/frontier_digest_recall.tsv) must each have >=1 announcing channel
# present in SKILL.md Step 1. No live fetch, no LLM. Exit 0 = all covered, 1 = a gap.
# Env: FD_SKILL_FILE overrides the SKILL.md path (used by the negative control).
set -uo pipefail
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL="${FD_SKILL_FILE:-$D/../plugins/fh-meta/skills/frontier-digest/SKILL.md}"
FIX="${FD_RECALL_FIXTURE:-$D/fixtures/frontier_digest_recall.tsv}"
[ -f "$SKILL" ] && [ -f "$FIX" ] || { echo "HARNESS-ERROR: missing skill or fixture"; exit 10; }
# ids = backticked ids in Step-1 table rows (lines starting with '| ' and containing a backticked id in col 1)
IDS=$(awk -F'|' '/^## Step 1\./{on=1;next} /^## /{on=0} on&&/^\| /{print $2}' "$SKILL" | grep -oE '`[a-z0-9-]+`' | tr -d '`' | sort -u)
[ -n "$IDS" ] || { echo "HARNESS-ERROR: no channel ids parsed (instrument mismatch)"; exit 10; }
echo "channels: $(echo $IDS | tr '\n' ' ')"
FAIL=0; N=0
while IFS=$'\t' read -r item kind chans || [ -n "$item" ]; do
  case "$item" in ''|'#'*) continue;; esac
  N=$((N+1))
  hit=""
  for c in $(echo "$chans" | tr ',' ' '); do echo "$IDS" | grep -qx "$c" && hit="$hit $c"; done
  if [ -n "$hit" ]; then echo "PASS $item ($kind) covered by:$hit"; else echo "FAIL $item ($kind) — none of [$chans] in Step 1"; FAIL=1; fi
done < "$FIX"
# an empty or truncated fixture must not pass vacuously
echo "checked $N items"
[ "$N" -ge 3 ] || { echo "HARNESS-ERROR: only $N fixture rows (floor 3)"; exit 10; }
exit $FAIL

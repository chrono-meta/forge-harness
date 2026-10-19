#!/usr/bin/env bash
# Negative control for test_frontier_digest_recall.sh: remove channels from a COPY of SKILL.md and
# require the lane to go red; also require the unmodified file to be green (known pair).
set -uo pipefail
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SK="$D/../plugins/fh-meta/skills/frontier-digest/SKILL.md"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
bash "$D/test_frontier_digest_recall.sh" >/dev/null; [ $? -eq 0 ] || { echo "FAIL control: real file not green"; exit 1; }
# Aside needs launch-yc or product-hunt: drop both -> red. (apply check: rows really removed)
grep -v -E '^\| (Launch YC|Product Hunt) ' "$SK" > "$T/s.md"
[ "$(wc -l < "$T/s.md")" -lt "$(wc -l < "$SK")" ] || { echo "HARNESS-ERROR: mutation not applied"; exit 10; }
O1=$(FD_SKILL_FILE="$T/s.md" bash "$D/test_frontier_digest_recall.sh"); echo "$O1" | grep -q '^FAIL Aside' && echo "PASS negctl: removing Launch YC+Product Hunt turns Aside red" || { echo "FAIL negctl: lane stayed green"; exit 1; }
# Single removal must NOT turn Aside red (redundancy) but removing all of show-hn/PH/geeknews reds Orca.
grep -v -E '^\| (Show HN|Product Hunt|GeekNews) ' "$SK" > "$T/s2.md"
O2=$(FD_SKILL_FILE="$T/s2.md" bash "$D/test_frontier_digest_recall.sh"); echo "$O2" | grep -q '^FAIL Orca' && echo "PASS negctl: removing Show HN+PH+GeekNews turns Orca red" || { echo "FAIL negctl 2"; exit 1; }

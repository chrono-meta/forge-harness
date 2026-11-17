#!/usr/bin/env bash
# lane_identity_tripwire.sh — report commits authored by the lane fixture identity that are reachable
# in a real repository.
#
# tenet: FH-T02 (machinery at the irreversible edge: a fixture commit in a real repo is the edge)
#
# WHY: test lanes commit inside throwaway repos as `lane <lane@example.invalid>`. When the caller's shell
# exports GIT_DIR / GIT_INDEX_FILE, `git -C <fixture> commit` writes into the exported repo instead
# (measured 2026-11-13 on a decoy repo). A downstream harness found such «base» commits in its own repo
# three times, the last one swallowing a staged intake. The env scrub in fixture_guard_lib.sh /
# selfcheck.sh closes the cause; this is the detector for anything that slips past it.
#
# Usage: lane_identity_tripwire.sh [repo-dir] [--strict]
#   default: record-only — prints a WARN line per hit, exit 0 (also when nothing is found).
#   --strict: exit 1 when any hit is found.
#   exit 2 = could not read the repo (HARNESS-ERROR — not «no hits»).
set -u
# same repo-targeting list as fixture_guard_lib.sh — GIT_SHALLOW_FILE / GIT_GRAFT_FILE / GIT_REPLACE_REF_BASE
# would otherwise hide reachable lane commits and print «ok» (cross-family codex R1)
for v in GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_OBJECT_DIRECTORY GIT_DIR GIT_WORK_TREE GIT_IMPLICIT_WORK_TREE GIT_GRAFT_FILE GIT_INDEX_FILE GIT_NO_REPLACE_OBJECTS GIT_REPLACE_REF_BASE GIT_PREFIX GIT_SHALLOW_FILE GIT_COMMON_DIR GIT_NAMESPACE; do unset "$v"; done
REPO="."; STRICT=0
for a in "$@"; do case "$a" in --strict) STRICT=1 ;; *) REPO="$a" ;; esac; done
IDENT="lane@example.invalid"
if ! git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1; then
  echo "LANE-TRIPWIRE HARNESS-ERROR: $REPO is not a readable git repo (not «no hits»)"; exit 2
fi
hits="$(git -C "$REPO" log --all --format='%h %ad %s' --date=short --author="$IDENT" 2>/dev/null)"; rc=$?
[ "$rc" -eq 0 ] || { echo "LANE-TRIPWIRE HARNESS-ERROR: git log failed (rc=$rc)"; exit 2; }
if [ -z "$hits" ]; then echo "LANE-TRIPWIRE ok: 0 commits by $IDENT reachable from any ref"; exit 0; fi
n="$(printf '%s\n' "$hits" | wc -l | tr -d ' ')"
echo "LANE-TRIPWIRE WARN: $n commit(s) by the test-lane identity $IDENT are reachable in $(cd "$REPO" && pwd -P):"
printf '%s\n' "$hits" | sed 's/^/  /'
echo "  → a lane committed into this repo (inherited GIT_DIR / GIT_INDEX_FILE?). Check the branch and index before anything else."
[ "$STRICT" = 1 ] && exit 1
exit 0

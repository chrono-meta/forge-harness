#!/usr/bin/env bash
# test_env_delta_worktree_lanes.sh — lanes for the linked-worktree rule in scripts/fh_env_delta_scan.sh.
#
# WHY: 2026-10-15 the SessionStart hook reported «33 unmapped sibling repos»; 30 of them were linked
# worktrees of repos the hub already knows (friends-on-desk, qasp-dev, clawd-on-desk, the hub itself).
# A worktree is another checkout of its main repo, not a new project. These lanes pin both sides:
#   - a linked worktree is NOT counted as a sibling (the fix)
#   - its unmapped main repo IS still counted (known-positive — the fix must not hide real repos)
#   - a `.git` FILE that is not a worktree pointer (submodule shape) still counts (old behaviour kept)
#   - cwd inside a worktree of a MAPPED repo → silent; of an UNMAPPED repo → names the main repo
set -u
HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
SCAN="$HERE/fh_env_delta_scan.sh"
[ -f "$SCAN" ] || { echo "FAIL  subject missing: $SCAN"; exit 1; }
command -v git >/dev/null 2>&1 || { echo "FAIL  git not on PATH — lanes cannot build fixtures"; exit 1; }

T="$(mktemp -d "${TMPDIR:-/tmp}/fh_envdelta_wt.XXXXXX")"
trap 'rm -rf "$T"' EXIT
ROOT="$T/projects"; HUB="$ROOT/hub"; SENT="$T/sent"
mkdir -p "$HUB/tracks/beta" "$HUB/scripts" "$SENT"
cp "$SCAN" "$HUB/scripts/"; [ -f "$HERE/hook_source_lib.sh" ] && cp "$HERE/hook_source_lib.sh" "$HUB/scripts/"

_repo() { git init -q "$1" && git -C "$1" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init; }
_repo "$ROOT/alpha"                                   # unmapped main repo
_repo "$ROOT/beta"                                    # mapped main repo (tracks/beta)
git -C "$ROOT/alpha" worktree add -q "$ROOT/alpha-wt" -b wt-a 2>/dev/null
git -C "$ROOT/beta"  worktree add -q "$ROOT/beta-wt"  -b wt-b 2>/dev/null
mkdir -p "$ROOT/gamma"; printf 'gitdir: %s\n' "$T/elsewhere/.git/modules/gamma" > "$ROOT/gamma/.git"  # submodule shape

FAILED=0; PASSED=0
_pass() { echo "✅ $1"; PASSED=$((PASSED+1)); }
_fail() { echo "❌ $1"; FAILED=1; }
_run() {  # $1 = cwd to report as CLAUDE_PROJECT_DIR
  printf '{"source":"startup"}' | HUB_DIR="$HUB" FH_PROJECTS_ROOT="$ROOT" CC_SENTINEL_DIR="$SENT" \
    CLAUDE_PROJECT_DIR="$1" bash "$HUB/scripts/fh_env_delta_scan.sh" 2>&1
}

# Fixture sanity: the worktrees really are worktrees (else every lane below is vacuous).
for w in alpha-wt beta-wt; do
  grep -q '/.git/worktrees/' "$ROOT/$w/.git" 2>/dev/null && _pass "fixture: $w is a linked worktree" \
    || _fail "fixture: $w is not a linked worktree — lanes would be vacuous"
done

OUT="$(_run "$HUB")"
case "$OUT" in *"2 unmapped sibling repo(s)"*) _pass "siblings: count = 2 (alpha + gamma)";;
  *) _fail "siblings: expected «2 unmapped sibling repo(s)», got: $(printf '%s' "$OUT" | tr '\n' ' ')";; esac

OUT="$(_run "$ROOT/beta-wt")"
case "$OUT" in *"current cwd"*) _fail "cwd in worktree of MAPPED repo: should be silent, got cwd line";;
  *) _pass "cwd in worktree of mapped repo → no cwd line";; esac

OUT="$(_run "$ROOT/alpha-wt")"
case "$OUT" in *"current cwd 'alpha'"*) _pass "cwd in worktree of UNMAPPED repo → names main repo 'alpha'";;
  *) _fail "cwd in worktree of unmapped repo: expected «current cwd 'alpha'», got: $(printf '%s' "$OUT" | tr '\n' ' ')";; esac

OUT="$(_run "$ROOT/gamma")"
case "$OUT" in *"current cwd 'gamma'"*) _pass "submodule-shape .git file still counts (cwd 'gamma')";;
  *) _fail "submodule-shape .git file no longer counts";; esac

if [ "$FAILED" -ne 0 ]; then echo "ENV-DELTA WORKTREE LANES: FAIL ($PASSED passed)"; exit 1; fi
echo "ENV-DELTA WORKTREE LANES: PASS ($PASSED lanes)"

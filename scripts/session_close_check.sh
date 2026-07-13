#!/usr/bin/env bash
# session_close_check.sh — mechanical checklist for the session close chain (CLAUDE.md §Session Wrap-up ①–⑥).
#
# WHY (loop_engineering.md census, 2026-07-10): the close chain's complete/persist legs were PROSE —
# card-last ordering and step coverage lived on salience alone, and the measured misses (card
# staleness class) all landed on exactly these legs. This script is the MECH floor: it VERIFIES
# state, it does not perform the steps (the session still runs them; the script catches skips).
# Built on operator instruction 2026-07-10 (strengthen-the-weak pass; evidence-threshold override
# recorded — the miss class was already measured, only the build trigger was overridden).
#
# READ-ONLY. Exit 0 = close state consistent · exit 1 = a close invariant is violated (card-last
# broken, or a required artifact missing). Advisory lines are prefixed ⚠️ , violations ❌ .
#
# Usage: bash scripts/session_close_check.sh [repo_root]   (run at close time, before ⑥ push)

set -uo pipefail

FH="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
TODAY=$(date +%Y-%m-%d)
CARD="$FH/tracks/_meta/reference_next_session_starter.md"
FAIL=0

_mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0; }

echo "── session close check: $FH ($TODAY) ──"

# ① status snapshot — uncommitted / unpushed work must be known, not forgotten
DIRTY=$(git -C "$FH" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
UNPUSHED=$(git -C "$FH" log --oneline @{u}.. 2>/dev/null | wc -l | tr -d ' ')
[ "$DIRTY" -gt 0 ] && echo "⚠️  ① $DIRTY uncommitted path(s) — decide: commit or leave deliberately"
[ "$UNPUSHED" -gt 0 ] && echo "⚠️  ① $UNPUSHED unpushed commit(s) — push before close or record why"
[ "$DIRTY" -eq 0 ] && [ "$UNPUSHED" -eq 0 ] && echo "✅ ① working tree clean, nothing unpushed"

# ①-b open-PR sweep (surface-not-auto — requires gh; skip silently offline)
if command -v gh >/dev/null 2>&1; then
  PRS=$(gh pr list --author "@me" --state open --json number 2>/dev/null | grep -c '"number"' || true)
  [ "${PRS:-0}" -gt 0 ] && echo "⚠️  ①-b $PRS open PR(s) by you — classify: self-mergeable vs awaiting-external"
fi

# ② FH assets changed today → harvest-loop owed
# NOTE: no `grep -q` here — under `set -o pipefail`, -q's early exit SIGPIPEs git log (141),
# masking a real match as pipeline failure so the warning NEVER fired on true positives
# (caught by a Sonnet blind probe 2026-07-10, 5/5 deterministic repro). `grep -c` reads the
# whole stream; `|| true` guards its exit-1-on-zero.
FH_CHANGED=$(git -C "$FH" log --since="today 00:00" --name-only --pretty=format: 2>/dev/null \
     | grep -cE '^(plugins/.*SKILL\.md|\.claude/rules/|templates/|CLAUDE\.md|knowledge/)' || true)
if [ "${FH_CHANGED:-0}" -gt 0 ]; then
  echo "⚠️  ② FH assets changed today ($FH_CHANGED path-touch(es)) — harvest-loop (or an explicit skip note) is owed"
fi

# ④ real-time completion log — required whenever any commit landed today
COMMITS_TODAY=$(git -C "$FH" log --since="today 00:00" --oneline 2>/dev/null | wc -l | tr -d ' ')
FC="$FH/tracks/_meta/fh_completed_${TODAY}.md"
if [ "$COMMITS_TODAY" -gt 0 ] && [ ! -f "$FC" ]; then
  echo "❌ ④ commits landed today but tracks/_meta/fh_completed_${TODAY}.md is missing"
  FAIL=1
fi

# ④-b npm freshness — files[] assets changed since last version tag → republish owed.
# Patterns are NARROWED to the actually-shipped subpaths (package.json files[]): knowledge/ ships only
# shared/{harness-core,dialogue,rules}; docs/ ships only {codex-compat,CONTRIBUTING,pillars}. A broad
# ^knowledge/ / ^docs/ over-matched git-tracked-but-UNshipped files (e.g. knowledge/shared/learnings/
# subagent_invocations_log.yaml, which changes almost every self-dev session) → guaranteed per-session
# false positive that trains the runner to ignore the line (Axis-2 challenger catch 2026-07-13).
SHIP_RE='^(plugins/|knowledge/shared/(harness-core|dialogue|rules)/|docs/(codex-compat|CONTRIBUTING|pillars)|README|AGENTS\.md|CLAUDE\.md|CHEATSHEET|CATALOG\.md)'
LAST_TAG=$(git -C "$FH" describe --tags --abbrev=0 2>/dev/null || true)
if [ -n "$LAST_TAG" ] && [ -f "$FH/package.json" ]; then
  CHANGED_SINCE_TAG=$(git -C "$FH" diff --name-only "$LAST_TAG"..HEAD 2>/dev/null)
  if printf '%s\n' "$CHANGED_SINCE_TAG" | grep -qE "$SHIP_RE"; then
    echo "⚠️  ④-b npm-shipped assets changed since $LAST_TAG — propose lockstep republish (never auto)"
  fi
  # ④-b-drift: auto-FIRE a drift-CANDIDATE reminder (not a parity verdict). If a shipped CLAUDE.md/knowledge
  # path changed but the Codex entry points (AGENTS.md / docs/codex-compat.md) did NOT co-change, flag it.
  # HONEST SCOPE: this tests file co-occurrence, not topical parity — it can false-positive (changed path
  # doesn't mirror an entry-point section) or false-negative (AGENTS.md touched for an unrelated reason).
  # The reminder is mechanized; the drift DETERMINATION stays judged (runner syncs or records drift:none).
  if printf '%s\n' "$CHANGED_SINCE_TAG" | grep -qE '^(CLAUDE\.md|knowledge/shared/(harness-core|dialogue|rules)/)' \
     && ! printf '%s\n' "$CHANGED_SINCE_TAG" | grep -qE '^(AGENTS\.md|docs/codex-compat)'; then
    echo "⚠️  ④-b drift candidate: shipped CLAUDE.md/knowledge changed but AGENTS.md/docs/codex-compat did not — JUDGE Codex entry-point parity (sync, or record drift:none if genuinely unaffected)"
  fi
fi

# ⑤ CARD-LAST invariant — the card must be the NEWEST close artifact. A card older than
# fh_completed / signal files written this session = ⑤ ran before ①–④ finished (the bug class).
if [ -f "$CARD" ]; then
  CARD_E=$(_mtime "$CARD")
  NEWER=$(find "$FH/tracks/_meta" -maxdepth 1 -type f \( -name "fh_completed_*.md" -o -name "fh_signal_*.md" \) -newer "$CARD" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$NEWER" -gt 0 ]; then
    echo "❌ ⑤ card-last violated — $NEWER close artifact(s) newer than the session card; re-run ⑤ (delta update)"
    FAIL=1
  else
    echo "✅ ⑤ card is the newest close artifact (card-last holds)"
  fi
else
  echo "❌ ⑤ session card missing: $CARD"
  FAIL=1
fi

echo "── close check: $([ "$FAIL" -eq 0 ] && echo CONSISTENT || echo VIOLATIONS) ──"
exit "$FAIL"

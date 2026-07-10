#!/usr/bin/env bash
# substrate_jump_detector.sh — detect substrate-version jumps (the trigger that was a phantom).
#
# WHY: the substrate self-adaptation loop's initiate leg cited a "substrate-version jump trigger"
# that had NO detector (codex census 2026-07-10 refuted the self-assessment — the trigger existed
# only as inventory text). This is STRUCTURE-ENFORCING mechanization per the durable-mechanization
# criterion (sonnet_floor_doctrine.md): version drift lives OUTSIDE the session's context boundary —
# an infinitely strong model still cannot know what changed on the machine between sessions.
#
# WHAT: snapshots substrate versions to a gitignored state file; on the next run, diffs and emits
# a jump notice naming the doctrine's shed/advance pass. Silent when nothing changed.
# Wire: one line in the SessionStart hook (fh_session_load.sh) or run standalone.
#
# Exit: always 0 (detector, not gate). State: tracks/_meta/.substrate_versions (gitignored).

set -uo pipefail

FH="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
STATE="$FH/tracks/_meta/.substrate_versions"

snapshot() {
  # one line per component: name=version (unavailable components recorded as absent — an
  # appearing/disappearing component is itself a jump)
  echo "claude=$(claude --version 2>/dev/null | head -1 || echo absent)"
  echo "codex=$(codex --version 2>/dev/null | head -1 || echo absent)"
  echo "agy=$(agy --version 2>/dev/null | head -1 || echo absent)"
  echo "node=$(node --version 2>/dev/null || echo absent)"
  echo "git=$(git --version 2>/dev/null || echo absent)"
  echo "os=$(uname -sr 2>/dev/null || echo absent)"
}

CURRENT="$(snapshot)"

if [ ! -f "$STATE" ]; then
  printf '%s\n' "$CURRENT" > "$STATE"
  echo "🧭 [substrate] baseline snapshot recorded ($(echo "$CURRENT" | wc -l | tr -d ' ') components)"
  exit 0
fi

PREV="$(cat "$STATE")"
if [ "$CURRENT" = "$PREV" ]; then
  # silent no-op — a detector that talks every session trains the reader to skip it
  exit 0
fi

echo "🧭 [substrate] VERSION JUMP detected — substrate loop initiate leg fires:"
# show only changed lines (name-keyed diff, bash-3.2 safe)
while IFS= read -r cur; do
  name="${cur%%=*}"
  old=$(printf '%s\n' "$PREV" | grep -m1 "^$name=" || echo "$name=<new>")
  [ "$cur" != "$old" ] && echo "   $old  →  $cur"
done <<EOF
$CURRENT
EOF
echo "   → run the shed/advance pass: re-check capability-compensating scaffolding against the new"
echo "     substrate (sonnet_floor_doctrine.md §durable-mechanization — shed what the model no longer"
echo "     needs, advance what the new substrate enables). Removals go through the 4-axis gate."

printf '%s\n' "$CURRENT" > "$STATE"
exit 0

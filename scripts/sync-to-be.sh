#!/usr/bin/env bash
# sync-to-be.sh — forge-harness local (gitignored) → fh-be/tracks-meta/
# Runs from CC Stop hook (throttled to 5 min) or manually.
# Usage: bash scripts/sync-to-be.sh [--quiet]

set -euo pipefail

FH="$HOME/PycharmProjects/forge-harness"
BE="$HOME/PycharmProjects/fh-be"
SRC="$FH/tracks/_meta"
DST="$BE/tracks-meta"
QUIET="${1:-}"

log() { [ "$QUIET" = "--quiet" ] || echo "[sync-to-be] $*"; }

# Ensure destination exists
mkdir -p "$DST"

# rsync: new + modified files only (delete not enabled — fh-be is append-only)
CHANGED=$(rsync -a --itemize-changes "$SRC/" "$DST/" \
  --exclude='.gitkeep' \
  --exclude='*.marker' \
  --exclude='logs/' \
  | grep '^[>c]' | wc -l | tr -d ' ')

if [ "$CHANGED" -eq 0 ]; then
  log "already up to date"
  exit 0
fi

log "$CHANGED file(s) synced → $DST"

# Commit in fh-be
cd "$BE"
git add tracks-meta/
if git diff --cached --quiet; then
  log "nothing new to commit in fh-be"
  exit 0
fi

DATE=$(date +"%Y-%m-%d %H:%M")
git commit -m "sync: forge-harness tracks/_meta → tracks-meta ($DATE)" \
  --no-gpg-sign 2>/dev/null || \
git commit -m "sync: forge-harness tracks/_meta → tracks-meta ($DATE)"

log "fh-be committed"

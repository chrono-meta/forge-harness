#!/usr/bin/env bash
# sync-to-be.sh — forge-harness local (gitignored) → fh-be private companion
# Mirrors the irreplaceable private half so that: public repo + fh-be = one complete project.
#   tracks/_meta  → fh-be/tracks-meta   (session meta, signals, manifests)
#   tracks/_audit → fh-be/tracks-audit  (sister-asset cross-audit records)
#   memory/       → fh-be/memory        (durable CC memory — else lost on machine reclaim)
# Runs from CC Stop hook (throttled to 5 min) or manually.
# Usage: bash scripts/sync-to-be.sh [--quiet]

set -euo pipefail

FH="$HOME/PycharmProjects/forge-harness"
BE="$HOME/PycharmProjects/fh-be"
QUIET="${1:-}"

# CC stores per-project memory under ~/.claude/projects/<path-with-slashes-as-dashes>/memory
ENC=$(printf '%s' "$FH" | sed 's#/#-#g')
MEM="$HOME/.claude/projects/${ENC}/memory"

log() { [ "$QUIET" = "--quiet" ] || echo "[sync-to-be] $*"; }

TOTAL=0

# sync_dir SRC DST — append-only rsync (no --delete); skips silently if SRC missing.
sync_dir() {
  local src="$1" dst="$2"
  [ -d "$src" ] || { log "skip (no source): $src"; return 0; }
  mkdir -p "$dst"
  local out n
  # capture separately so a no-match grep (exit 1) under pipefail can't kill the script
  out=$(rsync -a --itemize-changes "$src/" "$dst/" \
    --exclude='.gitkeep' \
    --exclude='*.marker' \
    --exclude='logs/') || true
  n=$(printf '%s\n' "$out" | grep -c '^[>c]' || true)
  TOTAL=$((TOTAL + n))
  [ "$n" -eq 0 ] || log "$n file(s) synced → $dst"
}

sync_dir "$FH/tracks/_meta"  "$BE/tracks-meta"
sync_dir "$FH/tracks/_audit" "$BE/tracks-audit"
sync_dir "$MEM"              "$BE/memory"

if [ "$TOTAL" -eq 0 ]; then
  log "already up to date"
  exit 0
fi

# Commit in fh-be
cd "$BE"
git add tracks-meta/ tracks-audit/ memory/ 2>/dev/null || git add -A
if git diff --cached --quiet; then
  log "nothing new to commit in fh-be"
  exit 0
fi

DATE=$(date +"%Y-%m-%d %H:%M")
MSG="sync: forge-harness private half → fh-be ($DATE)"
git commit -m "$MSG" --no-gpg-sign 2>/dev/null || git commit -m "$MSG"

log "fh-be committed"

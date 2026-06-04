#!/usr/bin/env bash
# sync-to-be.sh — hub local (gitignored) → private companion store.
# Mirrors the irreplaceable private half so that: public repo + companion = one complete project.
#   tracks/_meta    → <companion>/tracks-meta   (session meta, signals, manifests)
#   tracks/_audit   → <companion>/tracks-audit  (sister-asset cross-audit records)
#   memory/         → <companion>/memory        (durable CC memory — else lost on machine reclaim)
#   CLAUDE.local.md → <companion>/hub-owner     (operator-specific wiring)
# Runs from a CC Stop hook (throttled) or manually.
# Override paths via env: HUB_DIR, BE_DIR.
# Usage: bash scripts/sync-to-be.sh [--quiet]

set -euo pipefail

FH="${HUB_DIR:-$HOME/PycharmProjects/forge-harness}"
BE="${BE_DIR:-$HOME/PycharmProjects/fh-be}"
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

# sync_file SRC DSTDIR — append-only rsync of a single file; skips silently if SRC missing.
sync_file() {
  local src="$1" dstdir="$2"
  [ -f "$src" ] || { log "skip (no file): $src"; return 0; }
  mkdir -p "$dstdir"
  local out n
  out=$(rsync -a --itemize-changes "$src" "$dstdir/") || true
  n=$(printf '%s\n' "$out" | grep -c '^[>c]' || true)
  TOTAL=$((TOTAL + n))
  [ "$n" -eq 0 ] || log "synced $(basename "$src") → $dstdir"
}

sync_dir  "$FH/tracks/_meta"   "$BE/tracks-meta"
sync_dir  "$FH/tracks/_audit"  "$BE/tracks-audit"
sync_dir  "$MEM"               "$BE/memory"
sync_file "$FH/CLAUDE.local.md" "$BE/hub-owner"

cd "$BE"

# Push any commits ahead of upstream. Offline-safe: never aborts the script,
# so a failed push just leaves commits queued for the next run to flush.
maybe_push() {
  git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1 || {
    log "no upstream set for companion store — skipping push"; return 0; }
  local ahead
  ahead=$(git rev-list --count '@{u}..' 2>/dev/null || echo 0)
  [ "$ahead" -gt 0 ] || return 0
  if git push --quiet 2>/dev/null; then
    log "companion store pushed ($ahead commit(s))"
  else
    log "push failed (offline?) — $ahead commit(s) held locally, will retry next run"
  fi
}

if [ "$TOTAL" -eq 0 ]; then
  log "already up to date"
  maybe_push   # flush any commits a previous run couldn't push
  exit 0
fi

# Commit in the companion store
git add tracks-meta/ tracks-audit/ memory/ hub-owner/ 2>/dev/null || git add -A
if git diff --cached --quiet; then
  log "nothing new to commit in companion store"
  maybe_push
  exit 0
fi

DATE=$(date +"%Y-%m-%d %H:%M")
MSG="sync: hub private half → companion store ($DATE)"
git commit -m "$MSG" --no-gpg-sign 2>/dev/null || git commit -m "$MSG"

log "companion store committed"
maybe_push

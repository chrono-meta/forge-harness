#!/usr/bin/env bash
# sync-to-be.sh — hub local (gitignored) → private companion store.
# Mirrors the irreplaceable private half so that: public repo + companion = one complete project.
#   tracks/_meta    → <companion>/tracks-meta   (session meta, signals, manifests)
#   tracks/_audit   → <companion>/tracks-audit  (sister-asset cross-audit records)
#   tracks/the_bible → <companion>/tracks-the-bible (publish-candidate creative track, local-only/untracked)
#   memory/         → <companion>/memory        (durable CC memory — else lost on machine reclaim)
#   CLAUDE.local.md → <companion>/hub-owner     (operator-specific wiring)
# Runs from a CC Stop hook (throttled) or manually.
# Override paths via env: HUB_DIR, BE_DIR.
# Usage: bash scripts/sync-to-be.sh [--quiet]

set -euo pipefail

FH="${HUB_DIR:-$HOME/PycharmProjects/forge-harness}"
BE="${BE_DIR:-$HOME/PycharmProjects/fh-be}"
QUIET="${1:-}"

# CC stores per-project memory under ~/.claude/projects/<encoded-abs-path>/memory.
# The encoding maps path separators (/ \ :) → '-', so it differs per OS, and git-bash's
# posix path ($HOME=/c/...) does NOT match CC's native-path encoding on Windows (C:\… →
# C--…). The dir therefore CANNOT be computed by sed-ing $FH — resolve it by globbing the
# encoded tail (parent + project folder), which is identical on macOS and Windows.
# (fh_signal 2026-06-19: Windows mis-encoded memory dir → Stop-hook never mirrored memory.)
HAVE_RSYNC=0; command -v rsync >/dev/null 2>&1 && HAVE_RSYNC=1
resolve_mem_dir() {
  local root="$1" projects="$HOME/.claude/projects" tail d
  [ -d "$projects" ] || return 0
  tail="$(basename "$(dirname "$root")")-$(basename "$root")"   # e.g. PycharmProjects-forge-harness
  for d in "$projects"/*"$tail"/; do [ -d "${d}memory" ] && { printf '%s' "${d}memory"; return 0; }; done
  for d in "$projects"/*"$tail"/; do [ -d "$d" ] && { printf '%s' "${d}memory"; return 0; }; done
  return 0
}
MEM="$(resolve_mem_dir "$FH")"

log() { [ "$QUIET" = "--quiet" ] || echo "[sync-to-be] $*"; }

TOTAL=0   # files synced (rsync mode, countable)
DIRTY=0   # cp-fallback mode can't count cheaply → mark work done, let git-diff gate decide

# sync_dir SRC DST — append-only rsync (no --delete); skips silently if SRC missing.
sync_dir() {
  local src="$1" dst="$2"
  [ -d "$src" ] || { log "skip (no source): $src"; return 0; }
  mkdir -p "$dst"
  if [ "$HAVE_RSYNC" -eq 1 ]; then
    local out n
    # capture separately so a no-match grep (exit 1) under pipefail can't kill the script
    out=$(rsync -a --itemize-changes "$src/" "$dst/" \
      --exclude='.gitkeep' \
      --exclude='*.marker' \
      --exclude='logs/') || true
    n=$(printf '%s\n' "$out" | grep -c '^[>c]' || true)
    TOTAL=$((TOTAL + n))
    [ "$n" -eq 0 ] || log "$n file(s) synced → $dst"
  else
    # rsync absent (default Windows git-bash): tar-pipe mirror with the same excludes,
    # no --delete (append-only). Source is canonical, so overwriting be's copy is correct.
    if ( cd "$src" && tar cf - --exclude='.gitkeep' --exclude='*.marker' --exclude='logs' . ) \
         | ( cd "$dst" && tar xf - ); then
      DIRTY=1; log "mirrored (cp mode) → $dst"
    else
      log "mirror failed (cp mode) → $dst"
    fi
  fi
}

# sync_file SRC DSTDIR — append-only rsync of a single file; skips silently if SRC missing.
sync_file() {
  local src="$1" dstdir="$2"
  [ -f "$src" ] || { log "skip (no file): $src"; return 0; }
  mkdir -p "$dstdir"
  if [ "$HAVE_RSYNC" -eq 1 ]; then
    local out n
    out=$(rsync -a --itemize-changes "$src" "$dstdir/") || true
    n=$(printf '%s\n' "$out" | grep -c '^[>c]' || true)
    TOTAL=$((TOTAL + n))
    [ "$n" -eq 0 ] || log "synced $(basename "$src") → $dstdir"
  else
    if cp -p "$src" "$dstdir/"; then
      DIRTY=1; log "copied (cp mode) $(basename "$src") → $dstdir"
    else
      log "copy failed (cp mode) $(basename "$src") → $dstdir"
    fi
  fi
}

sync_dir  "$FH/tracks/_meta"      "$BE/tracks-meta"
sync_dir  "$FH/tracks/_audit"     "$BE/tracks-audit"
sync_dir  "$FH/tracks/the_bible"  "$BE/tracks-the-bible"   # publish-candidate creative track: local-only (untracked in public FH), watched in companion
sync_dir  "$MEM"               "$BE/memory"
sync_file "$FH/CLAUDE.local.md" "$BE/hub-owner"

cd "$BE"

# Mirror-only mode: a plain (non-git) companion directory is a valid local-only
# setup — files are already mirrored above; just skip the commit/push half.
# Without this guard, set -e kills the script at `git add` with a noisy error
# on every Stop-hook run (fh_signal_2026-06-10: companion-store portability).
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  log "companion store is not a git repo — mirror-only mode ($([ "$HAVE_RSYNC" -eq 1 ] && echo "$TOTAL file(s) synced" || echo "cp-mode mirror done"), no commit/push)"
  exit 0
}

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

if [ "$TOTAL" -eq 0 ] && [ "$DIRTY" -eq 0 ]; then
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

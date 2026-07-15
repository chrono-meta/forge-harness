#!/usr/bin/env bash
# sync-to-be.sh — hub local (gitignored) → private companion store.
# Mirrors the irreplaceable private half so that: public repo + companion = one complete project.
#   tracks/_meta    → <companion>/tracks-meta   (session meta, signals, manifests)
#   tracks/_audit   → <companion>/tracks-audit  (sister-asset cross-audit records)
#   tracks/the_bible → <companion>/tracks/the_bible (mapped project — nested; projects nest, only hub-meta _meta/_audit flatten)
#   memory/         → <companion>/memory        (durable CC memory — else lost on machine reclaim)
#   CLAUDE.local.md → <companion>/hub-owner     (operator-specific wiring)
# Runs from a CC Stop hook (throttled) or manually.
# Override paths via env: HUB_DIR, BE_DIR.
# Usage: bash scripts/sync-to-be.sh [--quiet]

set -euo pipefail

FH="${HUB_DIR:-${CLAUDE_PROJECT_DIR:-$HOME/projects/forge-harness}}"
BE="${BE_DIR:-$FH/../fh-be}"          # companion = documented sibling of the hub (derive with $FH, not a pinned literal)
QUIET="${1:-}"

# Hub-identity guard (fail-closed): $FH is context-derived (CLAUDE_PROJECT_DIR), and this is the
# WRITE/push path. Refuse to mirror if $FH is not actually the FH hub — e.g. the Stop hook is
# registered globally, or CLAUDE_PROJECT_DIR points at a field project — else a wrong project's
# memory / CLAUDE.local.md would be pushed into the companion store. (Axis-2 challenger 2026-07-05 [B].)
head -1 "$FH/CLAUDE.md" 2>/dev/null | grep -q "forge-harness — Persistent Knowledge Hub" \
  || { echo "[sync-to-be] refuse: \$FH ($FH) is not the FH hub — abort" >&2; exit 0; }

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
  tail="$(basename "$(dirname "$root")")-$(basename "$root")"   # e.g. projects-forge-harness
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

# ── Machine-scoped files ──────────────────────────────────────────────────────
# Most of what we mirror is machine-AGNOSTIC (signals, audits, memory topic files: every
# machine writes the same content, and append-only rsync merges them harmlessly). Two files
# are NOT: each hub clone keeps its OWN edit_manifest.yaml and its OWN memory index, because
# they describe THAT machine's local state. Mirroring them to one shared path makes every
# machine silently overwrite the others' backup — measured 2026-07-15: three machines synced
# the same day and fh-be's manifest ended up 135 entries (one machine) while another held 175,
# with no file actually lost but the backup rendered ambiguous. So these two are keyed by
# machine. The session CARD is deliberately NOT keyed — it is the shared cross-machine handoff
# ("next session = <machine>"); splitting it would kill the function it exists for.
#
# FH_MACHINE_ID: set it in your local env to name the machine. Default = a short digest of the
# hostname — stable, and non-identifying (a raw hostname commonly embeds the operator's name).
machine_id() {
  if [ -n "${FH_MACHINE_ID:-}" ]; then
    printf '%s' "$FH_MACHINE_ID" | tr -cd '[:alnum:]_-' | cut -c1-32; return 0
  fi
  local h
  h=$(hostname -s 2>/dev/null || hostname 2>/dev/null || printf 'unknown')
  printf 'm%s' "$(printf '%s' "$h" | shasum 2>/dev/null | cut -c1-8)"
}
MID="$(machine_id)"
[ -n "$MID" ] || MID="unknown"

sync_dir  "$FH/tracks/_meta"      "$BE/tracks-meta"
# ...then re-home the two machine-scoped files out of the shared namespace.
if [ -f "$FH/tracks/_meta/edit_manifest.yaml" ]; then
  mkdir -p "$BE/tracks-meta/manifests"
  cp "$FH/tracks/_meta/edit_manifest.yaml" "$BE/tracks-meta/manifests/$MID.yaml" \
    && log "manifest → tracks-meta/manifests/$MID.yaml (machine-scoped)"
  rm -f "$BE/tracks-meta/edit_manifest.yaml"   # shared copy retired; history keeps every machine's
fi
sync_dir  "$FH/tracks/_audit"     "$BE/tracks-audit"
sync_dir  "$FH/tracks/_chamber"   "$BE/tracks-chamber"   # incubation chamber runs (INTENT/SIM_NOTES/verdict/INDEX ledger) — local-only (gitignored in public FH), made durable + cross-machine here
sync_dir  "$FH/tracks/the_bible"  "$BE/tracks/the_bible"    # mapped project — NESTED under tracks/ (like livedeck; projects nest, only hub-meta _meta/_audit flatten): local-only (untracked in public FH), watched in companion

# Extra local-only project tracks to mirror are listed in a LOCAL, gitignored file
# ($FH/.fh-be-tracks.local — one track dir-name per line, # comments allowed). This keeps
# non-public track NAMES (e.g. company assets) OUT of this committed script: the list owns
# "what to mirror", this script is pure transport. local tracks/<name> <-> be tracks/<name>.
EXTRA_LIST="${FH_BE_TRACKS_FILE:-$FH/.fh-be-tracks.local}"
if [ -f "$EXTRA_LIST" ]; then
  while IFS= read -r _t || [ -n "$_t" ]; do
    _t="${_t%%#*}"                                   # strip inline comment
    _t="$(printf '%s' "$_t" | tr -d '[:space:]')"    # trim all whitespace
    [ -n "$_t" ] || continue
    case "$_t" in */*|.|..|..*) log "skip (unsafe track name): $_t"; continue;; esac
    sync_dir "$FH/tracks/$_t" "$BE/tracks/$_t"
  done < "$EXTRA_LIST"
fi

sync_dir  "$MEM"               "$BE/memory"
# memory TOPIC files are machine-agnostic and merge fine (203/203 identical across machines,
# measured 2026-07-15). The INDEX is not: it lists only what THIS machine's memory dir holds,
# so a shared MEMORY.md is whichever machine synced last and can never cover the union.
if [ -f "$MEM/MEMORY.md" ]; then
  mkdir -p "$BE/memory/_index"
  cp "$MEM/MEMORY.md" "$BE/memory/_index/$MID.md" \
    && log "memory index → memory/_index/$MID.md (machine-scoped)"
  rm -f "$BE/memory/MEMORY.md"                 # shared copy retired; history keeps every machine's
fi
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
#
# Concurrent-writer safety: two environments (e.g. company laptop + external
# machine) can write this store the same day. Without integrating the remote
# first, the second pusher's push is rejected non-fast-forward and — because
# the old code logged that as "offline?" — the commits piled up silently and
# never landed until a manual pull. So: fetch, and if behind, rebase local
# sync commits onto the remote BEFORE pushing. fetch-first lets us tell a
# genuinely-offline run (fetch fails) from a behind-remote run (fetch ok).
#
# We rebase ONLY when the working tree is clean, and deliberately do NOT use
# --autostash: an autostash pop-conflict completes the rebase but leaves the
# tree conflict-markered with the stash orphaned, and `rebase --abort` is then
# a no-op that can't recover it (the next run's `git add` would commit the
# garbage). A dirty tree just means the caller hasn't finished committing —
# hold the push and let the next run reconcile, preserving the old safe
# non-destructive behavior. (Hardened after an adversarial Axis-2 pass, 2026-07-01.)
maybe_push() {
  git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1 || {
    log "no upstream set for companion store — skipping push"; return 0; }
  # Clean up any rebase left half-done by a killed prior run (Stop hook can be
  # terminated mid-rebase); otherwise a later behind==0 run would push on an
  # inconsistent HEAD.
  rebase_in_progress() {
    [ -d "$(git rev-parse --git-path rebase-merge 2>/dev/null)" ] \
      || [ -d "$(git rev-parse --git-path rebase-apply 2>/dev/null)" ]; }
  if rebase_in_progress; then
    git rebase --abort 2>/dev/null || true
    if rebase_in_progress; then
      # abort couldn't clear it (corrupt/partial state) — do NOT push on an
      # inconsistent HEAD; bail fail-closed and let the operator resolve.
      log "an interrupted rebase could not be auto-aborted — resolve manually: cd \"$BE\" && git status"
      return 0
    fi
    log "cleaned up an interrupted rebase from a prior run"
  fi
  if git fetch --quiet 2>/dev/null; then
    local behind
    behind=$(git rev-list --count '..@{u}' 2>/dev/null || echo 0)
    if [ "$behind" -gt 0 ]; then
      if ! { git diff --quiet && git diff --cached --quiet; }; then
        log "$behind remote commit(s) + uncommitted changes — holding push, next run will reconcile"
        return 0
      fi
      if git pull --rebase --quiet 2>/dev/null; then
        log "rebased onto $behind remote commit(s) from another env before push"
      else
        git rebase --abort 2>/dev/null || true
        log "REBASE CONFLICT with remote (concurrent edit of a shared file) — resolve manually: cd \"$BE\" && git pull --rebase"
        return 0
      fi
    fi
  fi
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
git add tracks-meta/ tracks-audit/ tracks/ memory/ hub-owner/ 2>/dev/null || git add -A
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

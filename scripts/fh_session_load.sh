#!/usr/bin/env bash
# fh_session_load.sh — Mode D SessionStart companion-store freshness load (mechanical).
#
# WHY: the session-start companion-store load (refresh the private companion store + read its
# INDEX + card-vs-commit freshness) is documented in CLAUDE.local.md / modes_and_value.md
# §Session-start freshness as PROSE. Prose is salience-dependent: when the operator opens a
# session with an immediate task, the load silently does not fire and the agent operates on
# stale local memory. (Measured miss 2026-07-05: stale sidecar-tool version + a missed standing
# instruction, both because the companion refresh was skipped on task-first entry.) A
# SessionStart hook fires BEFORE the first user turn regardless of what the user types — so it
# closes the salience gap mechanically. This is the deferred hook in operational_adaptation.md
# §Guards whose measured revisit-trigger has now fired.
#
# WHAT: refresh the companion store, then emit a SHORT, IMPERATIVE freshness delta to stdout.
# A SessionStart hook's stdout is injected into the session context, so this block becomes
# unavoidable context the agent sees at turn 0.
#
# Graceful: if no companion store is configured (non-Mode-D user / ephemeral clone), emit
# nothing and exit 0 — this hook is a silent no-op outside Mode D. Offline-safe: refresh
# failure never blocks the session.
#
# Config (operator-local, opt-in): register in .claude/settings.local.json SessionStart and pass
# the companion-store path via the BE_DIR env in that gitignored registration (the public script
# hard-codes no private path). HUB_DIR overrides the hub path. Never commit the registration to
# the public settings.json — the hook is Mode-D-only.

set -uo pipefail

FH="${HUB_DIR:-${CLAUDE_PROJECT_DIR:-$HOME/projects/forge-harness}}"
BE="${BE_DIR:-}"   # companion-store path — supplied by the gitignored hook registration; no public default.

# Non-Mode-D / no companion store → silent no-op (this is the majority path for public users).
[ -d "$BE/.git" ] || exit 0

# Portable mtime (epoch). GNU-first: on GNU/coreutils `stat -f %m` exits 0 with filesystem-format
# output (never reaching a BSD fallback), so probe `stat -c %Y` FIRST — on BSD/macOS it errors and
# falls through to `-f %m`. Always echoes a numeric value (0 on total failure) so `-gt` never breaks.
# (codex cross-family review 2026-07-05 [MED]: BSD-first order silently mis-parsed on GNU.)
_mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0; }

# 1) Refresh the companion store — fail-fast, never block the first turn, never mutate into a
#    merge/conflict. (codex cross-family review 2026-07-05 [HIGH]/[MED].)
#    - fail-fast env: no credential/SSH/host-key prompts can hang SessionStart.
#    - fetch + merge --ff-only: a fast-forward is the only safe hook mutation; a diverged companion
#      simply does not advance (no merge commit, no conflict state left behind) and we say so.
export GIT_TERMINAL_PROMPT=0
export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new}"
PULL_NOTE=""
if git -C "$BE" fetch --quiet >/dev/null 2>&1; then
  if git -C "$BE" merge --ff-only --quiet >/dev/null 2>&1; then
    PULL_NOTE="fetched + fast-forwarded"
  else
    PULL_NOTE="fetched but NOT fast-forward (companion diverged — read local + newest remote)"
  fi
else
  PULL_NOTE="fetch skipped (offline — read local state)"
fi

# 2) Session card date (the pointer the operator's close chain writes last).
CARD="$FH/tracks/_meta/reference_next_session_starter.md"
CARD_EPOCH=0
[ -f "$CARD" ] && CARD_EPOCH="$(_mtime "$CARD")"

# 3) Companion files NEWER than the card, in the surfaces that carry landed results/handoffs.
#    (paper-signals = completed experiments; handoff = cross-session/cross-machine; tracks-meta
#    = synced session meta.) These are exactly what a stale card fails to point at.
NEWER=""
for sub in paper-signals handoff tracks-meta digests; do
  d="$BE/$sub"
  [ -d "$d" ] || continue
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    fe="$(_mtime "$f")"
    if [ "${fe:-0}" -gt "${CARD_EPOCH:-0}" ]; then
      NEWER="${NEWER}  - ${f#$BE/}\n"
    fi
  done <<EOF
$(find "$d" -type f -name '*.md' -maxdepth 2 2>/dev/null)
EOF
done

# 3b) Handoff/signal STATUS map — mtime-INDEPENDENT (patched 2026-07-10).
#     WHY: the NEWER-than-card list (step 3) has a permanent blind spot — a status stamp
#     (DONE/SUPERSEDED/RESOLVED) can land in the companion store, then the card gets rewritten
#     WITHOUT reconciling that item; from then on the stamped file is "older than the card"
#     forever and step 3 never surfaces it again. (Measured miss 2026-07-10: a Qwen heavy
#     handoff stamped DONE 07-09 stayed listed as "awaiting RUN" in the card through a later
#     card rewrite — company sessions push results to the companion store but never run the
#     local close chain, so the card's ⑤ update is the ONLY reconcile point and it was prose.)
#     FIX: emit ALL frontmatter status lines from handoff/ + paper-signals/ every session,
#     regardless of mtime, so the turn-0 agent can mechanically cross-check card carry items.
STATUS_MAP=""
for sub in handoff paper-signals; do
  d="$BE/$sub"
  [ -d "$d" ] || continue
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    s="$(head -15 "$f" 2>/dev/null | grep -iE '^ *status:' | head -1 | sed 's/^ *//')"
    [ -n "$s" ] || continue
    # Match on the status VALUE's leading word only — a substring match anywhere in the line
    # false-positives on prose like "Remaining for DONE:" inside a PARTIAL status.
    v="$(printf '%s' "$s" | sed -E 's/^[Ss][Tt][Aa][Tt][Uu][Ss]: *//')"
    case "$v" in
      DONE*|SUPERSEDED*|RESOLVED*|CLOSED*) STATUS_MAP="${STATUS_MAP}  - ${f#$BE/} → ${s}\n" ;;
    esac
  done <<EOF
$(find "$d" -type f -name '*.md' -maxdepth 2 2>/dev/null)
EOF
done

# 4) INDEX.md live pointers (the operator's wiki TOC — read-first per CLAUDE.local.md).
INDEX_HEAD=""
if [ -f "$BE/INDEX.md" ]; then
  INDEX_HEAD="$(grep -iE 'live pointer|Live pointers' -A 8 "$BE/INDEX.md" 2>/dev/null | head -10)"
fi

# 5) Emit the freshness block (short + imperative). Only speak if there is something to say.
{
  echo "🔄 [FH SessionStart] companion-store freshness — $PULL_NOTE."
  if [ -n "$NEWER" ]; then
    echo "⚠️ NEWER THAN SESSION CARD — READ THESE BEFORE ACTING (card may be stale):"
    printf "%b" "$NEWER"
  else
    echo "   (no companion files newer than the session card)"
  fi
  if [ -n "$STATUS_MAP" ]; then
    echo "── handoff/signal STATUS map (mtime-independent — closed items) ──"
    printf "%b" "$STATUS_MAP"
    echo "→ CROSS-CHECK: any item above that the session card still lists as open/awaiting = stale card line. Fix it in this session's card update (⑤)."
  fi
  if [ -n "$INDEX_HEAD" ]; then
    echo "── INDEX.md live pointers ──"
    echo "$INDEX_HEAD"
  fi
  echo "Reminder: this is the Mode D auto-read (CLAUDE.local.md §Session-start companion load) —"
  echo "it fires even when the first user message is a task. Do not treat 'pulled' as 'read'."
} 2>/dev/null

exit 0

#!/bin/bash
# frontier_digest_daily.sh — Daily frontier-digest runner for forge-harness
# Invoked by launchd (install: see scripts/com.forge-harness.frontier-digest.plist)
#
# Required: claude CLI at ~/.local/bin/claude
# Tool permissions: pre-approved in .claude/settings.json (no interactive prompts needed)

# Auto-detect repo root from this script's location (scripts/ → repo root) and the claude CLI.
FH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_BIN="$(command -v claude || echo "${HOME}/.local/bin/claude")"
TODAY=$(date +%Y_%m_%d)
HUMAN_DATE=$(date +%Y-%m-%d)   # pinned once with TODAY — a wake-fired run crossing midnight must not drift (filename date ≠ prompt date)
LOG_DIR="${FH_DIR}/tracks/_meta/logs"
LOG_FILE="${LOG_DIR}/frontier_digest_${TODAY}.log"

mkdir -p "$LOG_DIR"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] frontier-digest daily run starting" >> "$LOG_FILE"

# Cap log accumulation (up to 3 attempts/day append full claude output into this dir)
find "$LOG_DIR" -name 'frontier_digest_*.log' -mtime +30 -delete 2>/dev/null

# Success = a non-trivial digest file exists. Mere existence is not enough: the dominant failure
# class is "connection closed mid-response", which can leave a partial/empty file — that must not
# count as done (it would also lock out every later run today via the skip-check below).
digest_ready() {
    find "${FH_DIR}/tracks/_meta" -maxdepth 1 -name "frontier_digest_${TODAY}*.md" -size +1k 2>/dev/null | grep -q .
}

# Skip if already ran today
if digest_ready; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Already ran today — skipping" >> "$LOG_FILE"
    exit 0
fi

# Single-instance lock (mkdir = atomic on bash 3.2). Guards launchd-vs-manual double dispatch:
# a manual run during the retry sleep would otherwise race a second claude onto the same file.
# Stale-lock steal after 4h (crash mid-run must not brick every future day).
LOCK_DIR="${LOG_DIR}/.frontier_digest.lock"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    if [ -n "$(find "$LOCK_DIR" -maxdepth 0 -mmin +240 2>/dev/null)" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Stealing stale lock (>4h)" >> "$LOG_FILE"
        rmdir "$LOCK_DIR" 2>/dev/null
        mkdir "$LOCK_DIR" 2>/dev/null || { echo "[$(date '+%Y-%m-%d %H:%M:%S')] Lock race lost — exiting" >> "$LOG_FILE"; exit 0; }
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Another run in progress — exiting" >> "$LOG_FILE"
        exit 0
    fi
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT

cd "$FH_DIR"

# --permission-mode acceptEdits: headless runs have no human to approve the Write, so the digest
# Write to tracks/_meta/ was silently denied (claude still exits 0) — the runner fired daily but
# persisted nothing. acceptEdits auto-accepts the file Write only (not arbitrary tool calls), which
# is the minimal fix; read/fetch tools stay pre-approved via .claude/settings.json. (fixed 2026-06-19)
#
# Retry + watchdog (added 2026-07-18): 8 days between 05-31 and 07-17 lost their digest to transient
# API/network errors right after machine wake (connection closed / ConnectionRefused; one hang of
# 65 min before dying). 3 attempts, 10 min apart; each attempt runs under a 30-min watchdog so the
# hang variant also reaches the retry path — a foreground call would block the loop forever.
# [automated-run: launchd] in the prompt = run-provenance token (proposed by the 07-16 digest) so a
# digest can mechanically distinguish an automated run from a manual /frontier-digest invocation.
MAX_ATTEMPTS=3
ATTEMPT_TIMEOUT_SECS=1800
for ATTEMPT in $(seq 1 $MAX_ATTEMPTS); do
    # Re-check before spending an attempt (a manual run may have landed the digest during the sleep)
    if digest_ready; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Digest appeared externally before attempt ${ATTEMPT} — success" >> "$LOG_FILE"
        exit 0
    fi
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Attempt ${ATTEMPT}/${MAX_ATTEMPTS}" >> "$LOG_FILE"
    "$CLAUDE_BIN" -p --permission-mode acceptEdits \
        "[automated-run: launchd] Run /frontier-digest for today (${HUMAN_DATE}). Fetch latest signals from HN, arXiv, and GitHub. Save the digest to tracks/_meta/frontier_digest_${TODAY}.md." \
        >> "$LOG_FILE" 2>&1 &
    CLAUDE_PID=$!
    DEADLINE=$((SECONDS + ATTEMPT_TIMEOUT_SECS))
    while kill -0 "$CLAUDE_PID" 2>/dev/null && [ "$SECONDS" -lt "$DEADLINE" ]; do
        sleep 30
    done
    if kill -0 "$CLAUDE_PID" 2>/dev/null; then
        kill "$CLAUDE_PID" 2>/dev/null
        wait "$CLAUDE_PID" 2>/dev/null
        EXIT_CODE=124
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Attempt ${ATTEMPT} killed by watchdog (${ATTEMPT_TIMEOUT_SECS}s)" >> "$LOG_FILE"
    else
        wait "$CLAUDE_PID"
        EXIT_CODE=$?
    fi
    if digest_ready; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Digest file present after attempt ${ATTEMPT} (claude exit ${EXIT_CODE}) — success" >> "$LOG_FILE"
        exit 0
    fi
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] No digest file after attempt ${ATTEMPT} (claude exit ${EXIT_CODE})" >> "$LOG_FILE"
    [ "$ATTEMPT" -lt "$MAX_ATTEMPTS" ] && sleep 600
done

echo "[$(date '+%Y-%m-%d %H:%M:%S')] All ${MAX_ATTEMPTS} attempts failed — no digest for ${TODAY}" >> "$LOG_FILE"
exit 1

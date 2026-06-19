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
LOG_DIR="${FH_DIR}/tracks/_meta/logs"
LOG_FILE="${LOG_DIR}/frontier_digest_${TODAY}.log"

mkdir -p "$LOG_DIR"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] frontier-digest daily run starting" >> "$LOG_FILE"

# Skip if already ran today
if find "${FH_DIR}/tracks/_meta" -maxdepth 1 -name "frontier_digest_${TODAY}*.md" 2>/dev/null | grep -q .; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Already ran today — skipping" >> "$LOG_FILE"
    exit 0
fi

cd "$FH_DIR"

# --permission-mode acceptEdits: headless runs have no human to approve the Write, so the digest
# Write to tracks/_meta/ was silently denied (claude still exits 0) — the runner fired daily but
# persisted nothing. acceptEdits auto-accepts the file Write only (not arbitrary tool calls), which
# is the minimal fix; read/fetch tools stay pre-approved via .claude/settings.json. (fixed 2026-06-19)
"$CLAUDE_BIN" -p --permission-mode acceptEdits \
    "Run /frontier-digest for today ($(date +%Y-%m-%d)). Fetch latest signals from HN, arXiv, and GitHub. Save the digest to tracks/_meta/frontier_digest_${TODAY}.md." \
    >> "$LOG_FILE" 2>&1

EXIT_CODE=$?
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Exited with code ${EXIT_CODE}" >> "$LOG_FILE"
exit $EXIT_CODE

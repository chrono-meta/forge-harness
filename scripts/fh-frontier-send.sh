#!/usr/bin/env bash
# FH standing pre-frontier DLP gate (Docker Track 2, Phase 1b — wiring).
#
# THE GATE: confidential RAW on stdin → local-LLM abstraction (dlp-filter, fail-closed) → ONLY on PASS
# is the abstracted text handed to a FRONTIER command (codex / claude / any third-party model). If the
# DLP filter blocks (a must-redact pattern survived), the frontier command is NEVER run and the raw
# never leaves the box. This is the standing checkpoint in front of every confidential frontier call.
#
# The filter tier is the measured choice (paper-signals/dlp_filter_calibration_2026-06-21.md):
#   qwen3:32b on the local heavy node — 100% autonomous recall, free, beats/ties every cloud model.
# Config lives in ~/.fh-operator.env (local, gitignored): OLLAMA_HOST, OLLAMA_MODEL, REDACT_PATTERNS.
# This public script bakes NO node IP / model / pattern — mechanism here, operator config there.
#
# Usage:
#   printf '%s' "$CONFIDENTIAL" | scripts/fh-frontier-send.sh codex exec --skip-git-repo-check "Summarize:"
#   scripts/fh-frontier-send.sh --dry codex ... < doc.txt   # emit abstracted text, do NOT call frontier
#
# Exit: 0 = filtered + frontier ran (or --dry emitted) · 2 = usage · 3 = DLP BLOCKED (frontier aborted).
set -uo pipefail
IMG="fh-operator:latest"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -f "$HOME/.fh-operator.env" ] && { set -a; . "$HOME/.fh-operator.env"; set +a; }

DRY=0
if [ "${1:-}" = "--dry" ]; then DRY=1; shift; fi
[ "$DRY" = 1 ] || [ "$#" -gt 0 ] || { echo "fh-frontier-send: give a frontier command (or --dry)" >&2; exit 2; }
[ -n "${REDACT_PATTERNS:-}" ] || {
  echo "fh-frontier-send: REDACT_PATTERNS unset — set your confidential patterns in ~/.fh-operator.env" >&2
  echo "  (without them the DLP gate has nothing to enforce; refusing — fail-closed)" >&2; exit 2; }

command -v docker >/dev/null 2>&1 || { echo "fh-frontier-send: docker not found — start OrbStack"; exit 1; }

# One container run: filter stdin, then (unless --dry) pipe the ABSTRACTED text into the frontier cmd.
# The -c body is single-quoted so $RAW/$ABS expand IN the container; config crosses via -e, raw via -i.
# The frontier command is passed as real argv ('_ "$@"' → $0=_ , $1.. = the command) so multi-word
# prompts keep their quoting (eval would re-split them — observed: 'In one short sentence' became argv).
docker run --rm -i \
  -v "$REPO":/work/forge-harness -w /work/forge-harness \
  -v "$HOME/.codex":/root/.codex \
  -e "OLLAMA_HOST=${OLLAMA_HOST:-host.docker.internal:11434}" \
  -e "OLLAMA_MODEL=${OLLAMA_MODEL:-qwen3:32b}" \
  -e "REDACT_PATTERNS=${REDACT_PATTERNS}" \
  -e "KEEP_PATTERNS=${KEEP_PATTERNS:-}" \
  -e "OPENROUTER_API_KEY=${OPENROUTER_API_KEY:-}" \
  -e "DRY=${DRY}" \
  "$IMG" -c '
    RAW="$(cat)"
    [ -n "$RAW" ] || { echo "fh-frontier-send: empty input" >&2; exit 2; }
    ABS="$(printf "%s" "$RAW" | bash scripts/dlp-filter.sh -)" || {
      echo "fh-frontier-send: DLP BLOCKED — frontier call aborted, raw withheld" >&2; exit 3; }
    if [ "$DRY" = 1 ]; then printf "%s\n" "$ABS"; exit 0; fi
    printf "%s" "$ABS" | "$@"
  ' _ "$@"

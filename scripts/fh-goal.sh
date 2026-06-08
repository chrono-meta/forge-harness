#!/usr/bin/env bash
# fh-goal.sh — stop-hook-free goal runner for Codex/Claude primary workflows
#
# Runs a backend prompt, detects changed files, then runs fh-gate.
# This is not Claude Code /goal parity; it is the portable quality-gated
# execution path for environments without Stop hooks.

set -euo pipefail

FH_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Single source of truth: read version from the package.json shipped alongside this script.
# No jq dependency (users may not have it); fall back to "unknown" if unreadable.
VERSION="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$FH_ROOT/package.json" 2>/dev/null | head -1)"
VERSION="${VERSION:-unknown}"
_TMPDIR="${TMPDIR:-/tmp}"

FH_BACKEND="${FH_BACKEND:-codex}"
FH_TIMEOUT="${FH_TIMEOUT:-600}"
FH_GATE_LEVEL="${FH_GATE_LEVEL:-quick}"
FH_CALLER="${FH_CALLER:-fh-goal}"
FH_DRY_RUN="${FH_DRY_RUN:-0}"
FH_VERBOSE="${FH_VERBOSE:-0}"
GOAL_PROMPT=""
TARGET_FILES=""

usage() {
  cat <<'USAGE'
Usage:
  fh-goal --prompt <task> [--files "path path"] [--gate quick|full]
  fh-goal "task prompt"

Environment:
  FH_BACKEND=codex|claude   Backend to run the task (default: codex)
  FH_MODEL=<model>          Backend model override
  FH_TIMEOUT=600            Backend timeout seconds
  FH_GATE_LEVEL=quick|full  Post-run fh-gate level
  FH_DRY_RUN=1              Print backend prompt and planned gate only

Examples:
  FH_BACKEND=codex fh-goal --prompt "Implement X and update tests"
  FH_BACKEND=codex fh-goal --prompt "Review docs" --files "README.md docs/codex-compat.md"
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt)
      GOAL_PROMPT="${2:-}"
      shift 2
      ;;
    --files|--file|--target)
      TARGET_FILES="${2:-}"
      shift 2
      ;;
    --gate)
      FH_GATE_LEVEL="${2:-}"
      shift 2
      ;;
    --backend)
      FH_BACKEND="${2:-}"
      shift 2
      ;;
    --model)
      FH_MODEL="${2:-}"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      if [[ -z "$GOAL_PROMPT" ]]; then
        GOAL_PROMPT="$1"
      else
        GOAL_PROMPT="${GOAL_PROMPT} $1"
      fi
      shift
      ;;
  esac
done

case "$FH_BACKEND" in
  codex|claude) ;;
  *)
    echo "ERROR: FH_BACKEND must be codex or claude (got: $FH_BACKEND)" >&2
    exit 11
    ;;
esac

case "$FH_GATE_LEVEL" in
  quick|full) ;;
  *)
    echo "ERROR: FH_GATE_LEVEL must be quick or full (got: $FH_GATE_LEVEL)" >&2
    exit 11
    ;;
esac

if [[ -z "$GOAL_PROMPT" ]]; then
  echo "ERROR: missing goal prompt" >&2
  usage >&2
  exit 11
fi

if [[ -z "${FH_MODEL:-}" ]]; then
  case "$FH_BACKEND" in
    codex) FH_MODEL="gpt-5.5" ;;
    claude) FH_MODEL="claude-sonnet-4-6" ;;
  esac
fi

if ! command -v "$FH_BACKEND" &>/dev/null; then
  echo "ERROR: '$FH_BACKEND' CLI not found." >&2
  exit 10
fi

START_COMMIT="$(git -C "$FH_ROOT" rev-parse HEAD 2>/dev/null || true)"
PROMPT_FILE=$(mktemp "${_TMPDIR}/fh_goal_prompt_XXXXXX")
OUTPUT_FILE=$(mktemp "${_TMPDIR}/fh_goal_output_XXXXXX")
ERR_FILE=$(mktemp "${_TMPDIR}/fh_goal_err_XXXXXX")
cleanup() { rm -f "$PROMPT_FILE" "$OUTPUT_FILE" "$ERR_FILE"; }
trap cleanup EXIT

cat > "$PROMPT_FILE" <<PROMPT
FH GOAL RUNNER v${VERSION}
Backend: ${FH_BACKEND} | Model: ${FH_MODEL}

Task:
${GOAL_PROMPT}

Execution rules:
1. Work in the current repository.
2. Make the requested changes if implementation is required.
3. Prefer small, scoped edits.
4. When finished, summarize changed files and verification performed.
5. Do not claim FH governance passed; fh-goal runs fh-gate after this backend run.
PROMPT

if [[ "$FH_DRY_RUN" == "1" ]]; then
  cat "$PROMPT_FILE"
  echo
  echo "Planned post-run gate: FH_BACKEND=${FH_BACKEND} scripts/fh-gate.sh \"${TARGET_FILES:-<changed files>}\" ${FH_GATE_LEVEL} ${FH_CALLER}"
  exit 0
fi

echo "→ fh-goal v${VERSION} backend=${FH_BACKEND} model=${FH_MODEL} gate=${FH_GATE_LEVEL}" >&2

_TIMEOUT_CMD=""
if command -v gtimeout &>/dev/null; then
  _TIMEOUT_CMD="gtimeout ${FH_TIMEOUT}"
elif command -v timeout &>/dev/null; then
  _TIMEOUT_CMD="timeout ${FH_TIMEOUT}"
fi

run_backend() {
  case "$FH_BACKEND" in
    claude) ${_TIMEOUT_CMD} claude --print --model "$FH_MODEL" ;;
    codex) ${_TIMEOUT_CMD} codex exec -m "$FH_MODEL" - ;;
  esac
}

if ! run_backend < "$PROMPT_FILE" > "$OUTPUT_FILE" 2>"$ERR_FILE"; then
  echo "ERROR: ${FH_BACKEND} backend failed or timed out (${FH_TIMEOUT}s)" >&2
  cat "$ERR_FILE" >&2
  exit 10
fi

[[ "$FH_VERBOSE" == "1" ]] && cat "$ERR_FILE" >&2
cat "$OUTPUT_FILE"

if [[ -z "$TARGET_FILES" ]]; then
  if [[ -n "$START_COMMIT" ]]; then
    TARGET_FILES=$(git -C "$FH_ROOT" diff "$START_COMMIT"..HEAD --name-only 2>/dev/null | tr '\n' ' ' | xargs || true)
  fi
  if [[ -z "$TARGET_FILES" ]]; then
    TARGET_FILES=$(git -C "$FH_ROOT" status --short 2>/dev/null | awk '{print $2}' | tr '\n' ' ' | xargs || true)
  fi
fi

if [[ -z "$TARGET_FILES" ]]; then
  echo "→ fh-goal: no changed files detected; skipping fh-gate" >&2
  exit 0
fi

echo "→ fh-goal: running fh-gate on ${TARGET_FILES}" >&2
FH_BACKEND="$FH_BACKEND" "$FH_ROOT/scripts/fh-gate.sh" "$TARGET_FILES" "$FH_GATE_LEVEL" "$FH_CALLER"

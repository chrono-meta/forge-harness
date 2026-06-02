#!/usr/bin/env bash
# fh-gate.sh — FH governance gate v1.1
#
# Executes governance review end-to-end via claude --print.
# CI-ready: machine-parseable verdict + exit codes.
#
# Usage:
#   ./scripts/fh-gate.sh [FILES] [LEVEL] [CALLER]
#   ./scripts/fh-gate.sh                              # auto-detect from git diff
#   ./scripts/fh-gate.sh "src/foo.ts src/bar.ts"     # explicit files
#   ./scripts/fh-gate.sh "src/foo.ts" full opencode  # explicit level + caller
#
# Exit codes:
#   0  — PASS      (no findings)
#   1  — PENDING   (B-grade findings; proceed with awareness)
#   2  — BLOCKED   (A-grade findings; do not merge)
#   3  — ESCALATE  (human decision required)
#   10 — Harness error (claude unavailable, timeout, or FH_STATUS != SUCCESS)
#   11 — Argument error (invalid level, no files)
#
# Environment:
#   FH_DRY_RUN=1        generate prompt only, skip claude invocation (v0.1 behavior)
#   FH_MODEL=<model>    claude model to use (default: claude-sonnet-4-6)
#   FH_TIMEOUT=120      seconds before claude --print is killed (default: 120)
#   FH_VERBOSE=1        print full claude output to stderr
#   FH_RECORD_BASE=<p>  directory for governance_log YAML (default: FH_ROOT/tracks/_meta)

set -euo pipefail

VERSION="1.1.0"
FH_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
_TMPDIR="${TMPDIR:-/tmp}"

EXIT_PASS=0
EXIT_PENDING=1
EXIT_BLOCKED=2
EXIT_ESCALATE=3
EXIT_HARNESS_ERROR=10
EXIT_ARG_ERROR=11

TARGET_FILES="${1:-}"
GATE_LEVEL="${2:-quick}"
FH_CALLER="${3:-ci}"

FH_DRY_RUN="${FH_DRY_RUN:-0}"
FH_MODEL="${FH_MODEL:-claude-sonnet-4-6}"
FH_TIMEOUT="${FH_TIMEOUT:-120}"
FH_VERBOSE="${FH_VERBOSE:-0}"

# Smart record base: FH repo → tracks/_meta/; standalone npm install → ~/.fh/logs/
if [[ -z "${FH_RECORD_BASE:-}" ]]; then
  if [[ -d "${FH_ROOT}/tracks/_meta" ]]; then
    FH_RECORD_BASE="${FH_ROOT}/tracks/_meta"
  else
    FH_RECORD_BASE="${HOME}/.fh/logs"
    mkdir -p "$FH_RECORD_BASE"
  fi
fi

# --- Validation ---
if [[ "$GATE_LEVEL" != "quick" && "$GATE_LEVEL" != "full" ]]; then
  echo "ERROR: gate level must be 'quick' or 'full' (got: $GATE_LEVEL)" >&2
  exit $EXIT_ARG_ERROR
fi

# Auto-detect files from git diff (B1: configurable base branch)
FH_BASE_BRANCH="${FH_BASE_BRANCH:-main}"
if [[ -z "$TARGET_FILES" ]]; then
  TARGET_FILES=$(git -C "$FH_ROOT" diff "${FH_BASE_BRANCH}..HEAD" --name-only 2>/dev/null | tr '\n' ' ' | xargs || true)
  if [[ -z "$TARGET_FILES" ]]; then
    TARGET_FILES=$(git -C "$FH_ROOT" status --short 2>/dev/null | awk '{print $2}' | tr '\n' ' ' | xargs || true)
  fi
fi

if [[ -z "$TARGET_FILES" ]]; then
  echo "ERROR: no files found (git diff returned empty; pass files explicitly)" >&2
  exit $EXIT_ARG_ERROR
fi

# Security lens auto-detect
SECURITY_LENS="off"
if echo "$TARGET_FILES" | grep -qiE "(permission|auth|token|secret|key|cred|security|vulnerability|csrf|inject|sanitize)"; then
  SECURITY_LENS="on"
fi

TIMESTAMP=$(date +%Y-%m-%dT%H:%M:%SZ)
RECORD_PATH="${FH_RECORD_BASE}/governance_log_$(date +%Y-%m-%d).yaml"
PROMPT_FILE=$(mktemp "${_TMPDIR}/fh_gate_prompt_XXXXXX.txt")
OUTPUT_FILE=$(mktemp "${_TMPDIR}/fh_gate_output_XXXXXX.txt")
ERR_FILE=$(mktemp "${_TMPDIR}/fh_gate_err_XXXXXX.txt")

# Pre-compute values that need transformation (bash 3.2 compat — no ${VAR^^})
GATE_LEVEL_UPPER=$(echo "$GATE_LEVEL" | tr '[:lower:]' '[:upper:]')
FILES_LIST=$(echo "$TARGET_FILES" | tr ' ' '\n' | grep -v '^$' | sed 's/^/  - /')
SECURITY_EXTRA=""
[ "$SECURITY_LENS" = "on" ] && SECURITY_EXTRA=", permission model gaps"

if [ "$GATE_LEVEL" = "quick" ]; then
  AXES_BLOCK="  - Axis 2 (Adversarial): findings from Step 2
  - Axis 3 (Forward): phantom references, broken paths, stale claims"
else
  AXES_BLOCK="  - Axis 1 (Backward): regression risk vs prior version
  - Axis 2 (Adversarial): findings from Step 2
  - Axis 3 (Forward): phantom references, broken paths, stale claims
  - Axis 4 (Record): calibration log entry"
fi

cleanup() { rm -f "$PROMPT_FILE" "$OUTPUT_FILE" "$ERR_FILE"; }
trap cleanup EXIT

# --- Build prompt ---
cat > "$PROMPT_FILE" <<PROMPT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FH GOVERNANCE GATE v${VERSION} — ${GATE_LEVEL_UPPER} PASS
Caller: ${FH_CALLER} | Timestamp: ${TIMESTAMP}
Security lens: ${SECURITY_LENS}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Target files:
${FILES_LIST}

Execute these steps in order:

Step 1 — Read all target files listed above.

Step 2 — Adversarial pass (steel-quench angles):
  Focus: behavioral edge cases, untested contracts, security assumptions${SECURITY_EXTRA}
  Find findings and grade each: A=blocking / B=warning / C=note.

Step 3 — pipeline-conductor --${GATE_LEVEL}:
${AXES_BLOCK}

Step 4 — Output structured verdict. EXACT FORMAT REQUIRED (machine-parsed):

FH_STATUS: SUCCESS
FH_GATE_VERDICT: [PASS|PENDING|BLOCKED|ESCALATE]
FH_CALLER: ${FH_CALLER}
FH_TIMESTAMP: ${TIMESTAMP}
FH_FINDINGS_COUNT: [N]
FH_FINDINGS_A: [N]
FH_FINDINGS_B: [N]
FH_RECORD_PATH: ${RECORD_PATH}
---
findings:
  - grade: [A|B|C]
    location: "[file:line or function name]"
    title: "[one-line description]"
    evidence: "[what was observed in the file]"
    fix: "[concrete suggestion]"

Verdict rules:
  A-grade present → BLOCKED
  B-grade only    → PENDING
  No findings     → PASS
  Ambiguous A     → ESCALATE

FH_STATUS MUST appear first. Missing or ERROR status = harness failure.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PASS=ship | PENDING=proceed with awareness | BLOCKED=fix first | ESCALATE=human decision
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PROMPT

# --- Dry-run: prompt to stdout only (v0.1 behavior) ---
if [[ "$FH_DRY_RUN" == "1" ]]; then
  cat "$PROMPT_FILE"
  exit $EXIT_PASS
fi

# --- Require claude CLI ---
if ! command -v claude &>/dev/null; then
  echo "ERROR: 'claude' CLI not found." >&2
  echo "  Install: https://claude.ai/code" >&2
  echo "  Prompt-only mode: FH_DRY_RUN=1 $0 $*" >&2
  exit $EXIT_HARNESS_ERROR
fi

# --- Invoke ---
echo "→ fh-gate v${VERSION} [${GATE_LEVEL_UPPER}] caller=${FH_CALLER} security=${SECURITY_LENS}" >&2
echo "  files: ${TARGET_FILES}" >&2

# Use gtimeout (macOS coreutils) if available, fall back to timeout, then bare invoke
_TIMEOUT_CMD=""
if command -v gtimeout &>/dev/null; then
  _TIMEOUT_CMD="gtimeout ${FH_TIMEOUT}"
elif command -v timeout &>/dev/null; then
  _TIMEOUT_CMD="timeout ${FH_TIMEOUT}"
fi

if ! ${_TIMEOUT_CMD} claude --print --model "$FH_MODEL" < "$PROMPT_FILE" > "$OUTPUT_FILE" 2>"$ERR_FILE"; then
  echo "ERROR: claude --print failed or timed out (${FH_TIMEOUT}s)" >&2
  cat "$ERR_FILE" >&2
  exit $EXIT_HARNESS_ERROR
fi

[[ "$FH_VERBOSE" == "1" ]] && cat "$ERR_FILE" >&2

# --- Parse verdict (B3: -m 1 prevents concatenation on repeated header lines) ---
FH_STATUS=$(grep -m 1 "^FH_STATUS:" "$OUTPUT_FILE" 2>/dev/null | awk '{print $2}' | tr -d '[:space:]' || true)
VERDICT=$(grep -m 1 "^FH_GATE_VERDICT:" "$OUTPUT_FILE" 2>/dev/null | awk '{print $2}' | tr -d '[:space:]' || true)

# Harness failure guard (fail-safe: missing status → BLOCKED)
if [[ "$FH_STATUS" != "SUCCESS" ]]; then
  echo "ERROR: FH_STATUS=${FH_STATUS:-MISSING} — harness failure (fail-safe: BLOCKED)" >&2
  cat "$OUTPUT_FILE" >&2
  exit $EXIT_HARNESS_ERROR
fi

# Emit structured output to stdout
cat "$OUTPUT_FILE"

# B4: Write governance log — structured header only (clean YAML, no raw markdown)
FINDINGS_A_LOG=$(grep -m 1 "^FH_FINDINGS_A:" "$OUTPUT_FILE" 2>/dev/null | awk '{print $2}' | tr -d '[:space:]' || echo "0")
FINDINGS_B_LOG=$(grep -m 1 "^FH_FINDINGS_B:" "$OUTPUT_FILE" 2>/dev/null | awk '{print $2}' | tr -d '[:space:]' || echo "0")
FINDINGS_N_LOG=$(grep -m 1 "^FH_FINDINGS_COUNT:" "$OUTPUT_FILE" 2>/dev/null | awk '{print $2}' | tr -d '[:space:]' || echo "0")
{
  printf -- "- timestamp: %s\n" "$TIMESTAMP"
  printf "  caller: %s\n" "$FH_CALLER"
  printf "  gate_level: %s\n" "$GATE_LEVEL"
  printf "  verdict: %s\n" "$VERDICT"
  printf "  findings_total: %s\n" "$FINDINGS_N_LOG"
  printf "  findings_a: %s\n" "$FINDINGS_A_LOG"
  printf "  findings_b: %s\n" "$FINDINGS_B_LOG"
  printf "  files:\n"
  echo "$TARGET_FILES" | tr ' ' '\n' | grep -v '^$' | sed 's/^/    - /'
  printf "\n"
} >> "$RECORD_PATH" || echo "WARN: governance log write failed: $RECORD_PATH" >&2

# Exit code
case "$VERDICT" in
  PASS)     echo "→ verdict: PASS" >&2;     exit $EXIT_PASS ;;
  PENDING)  echo "→ verdict: PENDING" >&2;  exit $EXIT_PENDING ;;
  BLOCKED)  echo "→ verdict: BLOCKED" >&2;  exit $EXIT_BLOCKED ;;
  ESCALATE) echo "→ verdict: ESCALATE" >&2; exit $EXIT_ESCALATE ;;
  *)
    echo "ERROR: unrecognized verdict '${VERDICT:-EMPTY}' — fail-safe BLOCKED" >&2
    exit $EXIT_HARNESS_ERROR
    ;;
esac

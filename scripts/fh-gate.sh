#!/usr/bin/env bash
# fh-gate.sh — FH governance gate wrapper (methodology layer, v0.1)
#
# Generates a governance prompt for Claude Code to execute.
# This is the v0.1 form: prompt-as-interface until the binary bridge layer (v1.0) ships.
#
# Usage:
#   ./scripts/fh-gate.sh [FILES] [LEVEL] [CALLER]
#   ./scripts/fh-gate.sh                              # auto-detect from git diff
#   ./scripts/fh-gate.sh "src/foo.ts src/bar.ts"     # explicit files
#   ./scripts/fh-gate.sh "src/foo.ts" full opencode  # explicit level + caller
#
# Output: governance prompt to stdout.
#   Pipe to a file or paste into Claude Code session.
#   Verdict format follows fh_integration_contract.md.
#
# Exit codes:
#   0 — prompt generated successfully
#   1 — no files found to review
#   2 — invalid gate level

set -euo pipefail

FH_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# --- Arguments ---
TARGET_FILES="${1:-}"
GATE_LEVEL="${2:-quick}"
FH_CALLER="${3:-unknown}"

# Validate gate level
if [[ "$GATE_LEVEL" != "quick" && "$GATE_LEVEL" != "full" ]]; then
  echo "ERROR: gate level must be 'quick' or 'full' (got: $GATE_LEVEL)" >&2
  exit 2
fi

# Auto-detect files from git diff if not provided
if [[ -z "$TARGET_FILES" ]]; then
  TARGET_FILES=$(git -C "$FH_ROOT" diff main..HEAD --name-only 2>/dev/null | tr '\n' ' ' | xargs)
  if [[ -z "$TARGET_FILES" ]]; then
    TARGET_FILES=$(git -C "$FH_ROOT" status --short 2>/dev/null | awk '{print $2}' | tr '\n' ' ' | xargs)
  fi
fi

if [[ -z "$TARGET_FILES" ]]; then
  echo "ERROR: no files found to review (git diff returned empty)" >&2
  exit 1
fi

# Determine security lens (on for permission/auth/token paths)
SECURITY_LENS="off"
if echo "$TARGET_FILES" | grep -qiE "(permission|auth|token|secret|key|cred|security)"; then
  SECURITY_LENS="on"
fi

TIMESTAMP=$(date +%Y-%m-%dT%H:%M:%SZ)
RECORD_PATH="tracks/_meta/governance_log_$(date +%Y-%m-%d).yaml"

# --- Generate governance prompt ---
cat <<PROMPT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FH GOVERNANCE GATE — ${GATE_LEVEL^^} PASS
Caller: ${FH_CALLER} | Timestamp: ${TIMESTAMP}
Security lens: ${SECURITY_LENS}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Target files:
$(echo "$TARGET_FILES" | tr ' ' '\n' | grep -v '^$' | sed 's/^/  - /')

Execute these steps in order:

Step 1 — Read all target files listed above.

Step 2 — steel-quench adversarial pass:
  Focus: behavioral edge cases, untested contracts, security assumptions$([ "$SECURITY_LENS" = "on" ] && echo ", permission model gaps" || echo "")
  Output: 3 most critical findings with grade (A=blocking/B=warning/C=note), location, evidence.
  Grade A = FH_GATE_VERDICT must be BLOCKED or higher.
  Grade B = FH_GATE_VERDICT becomes at least PENDING.

Step 3 — pipeline-conductor --${GATE_LEVEL}:
  Axes to run:
$(if [ "$GATE_LEVEL" = "quick" ]; then
  echo "  - Axis 2 (Adversarial): findings from Step 2"
  echo "  - Axis 3 (Forward): phantom references, broken paths, stale claims"
else
  echo "  - Axis 1 (Backward): regression risk vs prior version"
  echo "  - Axis 2 (Adversarial): findings from Step 2"
  echo "  - Axis 3 (Forward): phantom references, broken paths, stale claims"
  echo "  - Axis 4 (Record): calibration log entry"
fi)

Step 4 — Output structured verdict (REQUIRED):

FH_GATE_VERDICT: [PASS|PENDING|BLOCKED|ESCALATE]
FH_CALLER: ${FH_CALLER}
FH_TARGET: ${TARGET_FILES}
FH_TIMESTAMP: ${TIMESTAMP}
FH_FINDINGS_COUNT: [N]
FH_FINDINGS_A: [N]
FH_FINDINGS_B: [N]
FH_RECORD_PATH: ${RECORD_PATH}

Then list each finding in this format:
FINDING_N_GRADE: [A|B|C]
FINDING_N_LOCATION: [file:line or function]
FINDING_N_TITLE: [one-line description]
FINDING_N_EVIDENCE: [what was observed]
FINDING_N_FIX: [concrete suggestion]

Step 5 — Append calibration record to ${RECORD_PATH}:
  (Create file if not exists; append entry in YAML list format per fh_integration_contract.md)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Verdict reference: PASS=ship | PENDING=proceed with awareness | BLOCKED=fix first | ESCALATE=human decision
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PROMPT

#!/usr/bin/env bash
# lane_gap_hint.sh — UserPromptSubmit wrapper for scripts/lane_gap_hint.py (advisory; see its header).
# A .sh entry point because install-wizard recognises a snippet's FH script by its `scripts/<name>.sh` path form.
# Never blocks: exit 0 on every path. Opt out with FH_LANE_GAP_HINT=0.
[ "${FH_LANE_GAP_HINT:-1}" = 0 ] && exit 0
python3 "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lane_gap_hint.py" 2>/dev/null
exit 0

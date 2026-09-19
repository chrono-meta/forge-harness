#!/usr/bin/env bash
# checklist_unblocked_hook.sh — SubagentStop advisory: a blocked checklist row whose blocker just landed.
#
# WHY IT FIRES HERE. The operator's prescription was literal (2026-09-19):
#   "체크리스트를 쓰고 그걸 네가 테스트 한차례 끝날때마다 들여다봐야할것같아"
# A subagent finishing IS "한 차례 끝났다" — it is the one moment a blocker plausibly just closed.
# Measured that day: rows A6/A8 declared «A13 선행», A13 landed DONE, and nothing re-read the file.
# Three operator requests degraded until the operator asked again. `check` passed the same file
# clean (rows=14 ok=14 violations=0) — form was never the problem.
#
# 🟥 EXIT 0 ALWAYS, REPORT ON STDOUT. A hook that exits non-zero has its stdout DISCARDED and its
# stderr NOT relayed — the warning would reach nobody. The finding therefore travels as JSON
# `hookSpecificOutput.additionalContext`, which the runtime injects into MODEL context.
#
# DEGRADE DIRECTION: silent. No checklist, no dependency edges, missing python, unreadable file →
# say nothing and exit 0. This is ADVISORY on a reversible surface; a noisy hook on every subagent
# stop trains people to ignore hooks, which disarms the ones guarding irreversible surfaces.
# 🟥 Named residual: that silence also swallows rc=4 (a checklist that STOPPED recording
# dependencies). Narrow on purpose; widen only if that is ever measured to happen.
set -uo pipefail

HUB="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo "$HOME/projects/forge-harness")}"
SUBJ="$HUB/scripts/session_checklist.py"
[ -f "$SUBJ" ] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

# Newest checklist. 🟥 `ls -t … | head -1` is not used: with zsh nullglob a no-match argument is
# DELETED from the command line and `ls` silently lists the CWD instead — this repo has that scar.
FILE="$(/usr/bin/find "$HUB/tracks/_meta" -maxdepth 1 -name 'session_checklist_*.md' -type f 2>/dev/null \
        | /usr/bin/sort | /usr/bin/tail -1)"
[ -n "${FILE:-}" ] && [ -f "$FILE" ] || exit 0

OUT="$(python3 "$SUBJ" unblocked --file "$FILE" 2>/dev/null)"; RC=$?
[ "$RC" -eq 1 ] || exit 0    # 0 clean · 4 dead-control · 10 input error → all silent, see header

FINDINGS="$(printf '%s\n' "$OUT" | /usr/bin/grep 'is still open' | /usr/bin/sed 's/^[[:space:]]*//')"
[ -n "$FINDINGS" ] || exit 0

# 🟥 findings travel as ARGV, not stdin. A first draft used `python3 - <<'PY' <<<"$FINDINGS"` — two
# redirects on one command, and the LAST one wins, so bash fed the findings in as the *script*
# (`SyntaxError: invalid character '⚠'`). Named here because the failure was loud only by luck.
python3 - "$FILE" "$FINDINGS" <<'PY'
import json, sys
path, findings = sys.argv[1], sys.argv[2].strip()
msg = (
    "\U0001f7e5 CHECKLIST: a blocker just cleared and the dependent row is still open.\n"
    + findings
    + "\n\nFile: " + path
    + "\nRe-read those rows before moving on — this is the exact shape in which three operator "
      "requests degraded on 2026-09-19 (they were on the checklist, blocked, unblocked, never re-read). "
      "This is a record property, not a judgment: it does not claim the row should be worked now, only "
      "that nothing has been written since its blocker closed."
)
print(json.dumps({"hookSpecificOutput": {"hookEventName": "SubagentStop", "additionalContext": msg}},
                 ensure_ascii=False))
PY
exit 0

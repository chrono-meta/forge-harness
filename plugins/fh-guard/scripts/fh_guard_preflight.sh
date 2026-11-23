#!/usr/bin/env bash
# fh_guard_preflight.sh — SessionStart hook for the fh-guard plugin.
#
# WHY THIS EXISTS
#   destructive_pre_gate.sh reads every Bash hook payload with python3. Without a working python3 it
#   reads an empty command and exits 0 — every call passes, and nothing says so. onFailure:block on
#   the PreToolUse entry cannot see that: a clean exit 0 is not a hook failure. So the one state in
#   which an installed fh-guard does nothing would look exactly like a quiet, guarded session. This
#   hook says so once, at session start, in one line.
#
# CONTRACT
#   python3 runs          → print nothing, exit 0 (a notice that fires on a healthy machine trains
#                           people to skip it).
#   python3 absent/broken → one JSON object on stdout: systemMessage (the user) + additionalContext
#                           (the model), exit 0. It never blocks: SessionStart cannot block a call,
#                           and a session without the gate is still the user's session.
#   Uses shell builtins only (command, printf) so it still runs on a PATH that holds nothing else.
#   Writes no file, reads no file, makes no network call.
# Lanes: scripts/test_fh_guard_plugin_lanes.sh L5 · L6.

set -u
reason=""
if ! command -v python3 >/dev/null 2>&1; then
  reason="python3 is not on PATH"
elif ! python3 -c 'import json; json.loads("{}")' >/dev/null 2>&1; then
  reason="python3 is on PATH but does not run (a store stub or a broken install)"
fi
[ -z "$reason" ] && exit 0

msg="fh-guard is NOT active in this session: ${reason}. Its destructive-op gate reads each Bash call with python3 and, without it, lets every call through unchecked. Install a working python3, then start a new session."
printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$msg" "$msg"
exit 0

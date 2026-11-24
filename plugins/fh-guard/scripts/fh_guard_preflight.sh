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
#   The python3 check uses shell builtins only (command, printf), so it still runs on a PATH that holds
#   nothing else; the platform check below also calls `uname` (missing uname → treated as non-Windows).
#   Reads no file, makes no network call. The one file it writes is $CLAUDE_ENV_FILE (below).
#
# MESSAGING SOCKET (IG3 §2, 2026-11-24)
#   A Bash call inherits CLAUDE_CODE_MESSAGING_SOCKET and CLAUDE_CODE_MESSAGING_TOKEN, so a script the
#   agent runs (or a child it starts) holds the session's message channel. When Claude Code gives this
#   hook $CLAUDE_ENV_FILE, one `unset` line is APPENDED to it (>>, so other hooks' lines survive); Claude
#   Code runs that file before each Bash command. Measured on macOS/bash: direct and make-child counts
#   2 → 0 (3/3, control 3/3). The session's own tools (SendMessage etc.) are not Bash children and keep
#   the channel; a nested `claude -p` sets its own. Silent either way — no notice.
#   🟥 NOT COVERED — Windows: PowerShell never runs the env file, and an `unset` line there would stop
#   PowerShell commands receiving OTHER hooks' plain exports (the docs copy them only when every line
#   is a plain assignment). So on Windows (OS=Windows_NT, MINGW/MSYS/CYGWIN) nothing is written and the
#   socket stays inherited — Git Bash included, even though its Bash calls would run the file, because
#   nothing here can tell whether PowerShell commands also run in that session. Also not covered: finding
#   the socket by another route than these two names; a write that fails (silent, channel stays inherited).
#   The line starts with a newline: another hook's last line may lack one, and `export X=1unset …` would
#   keep both names exported.
# Lanes: scripts/test_fh_guard_plugin_lanes.sh L5 · L6 · L7.

set -u
case "${OS:-}:$(uname -s 2>/dev/null)" in
  Windows_NT:*|*:MINGW*|*:MSYS*|*:CYGWIN*) ;;
  *) if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
       { printf '\nunset CLAUDE_CODE_MESSAGING_SOCKET CLAUDE_CODE_MESSAGING_TOKEN\n' >> "$CLAUDE_ENV_FILE"; } 2>/dev/null || :
     fi ;;
esac
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

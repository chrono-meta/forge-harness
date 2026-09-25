#!/usr/bin/env bash
# subagent_tally_hook.sh — SubagentStop hook body: append today's date to the dispatch tally that
# session_close_check.sh ④-e reconciles against the invocation log. TALLIES ONLY — it never writes a
# log entry (a fabricated outcome/evidence would poison the 60/40 promotion gate).
#
# WHY THIS IS A SCRIPT NOW (2026-09-25, fh_signal_2026-09-25_subagent-tally-counts-internal-agents):
#   SubagentStop also fires for Claude Code's OWN internal agents — measured: `/compact` produced a
#   SubagentStop with `agent_type: ""` (PreCompact fired alongside it), while a dispatched Explore
#   agent carried `agent_type: "Explore"` and a dispatch with subagent_type OMITTED carried
#   `agent_type: "general-purpose"` (claude 2.1.282, headless, 2026-09-25). The inline hook counted
#   all three, so a session that dispatched nothing failed ④-e after a context compaction — and the
#   operator was twice told «probably a peer session», which was false.
#
# DISCRIMINATOR — and why it is this narrow:
#   skip ONLY when `agent_type` is PRESENT and EXACTLY "". Everything else counts:
#     field absent (older CLI) · non-JSON stdin · empty stdin · no python3 → COUNT.
#   Over-counting re-creates the known false positive (loud, the operator sees it). Under-counting a
#   real dispatch is the fail-open ④-e exists to close (silent). So every doubt lands on «count».
#
# ALSO RECORDED: session_id and agent_type go to a SIDE file, never into the tally line — ④-e matches
#   `^DATE$` exactly, and changing the tally format would silently zero every count on a machine
#   running the old checker. The side file is for attribution when a count looks wrong.
#
# exit 0 ALWAYS — a failing hook must never block a subagent from finishing.

HUB="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo "$HOME/projects/forge-harness")}"
T="${FH_TALLY_FILE:-$HUB/tracks/_meta/.subagent_dispatch_tally}"
# 🟥 Read with a TIME LIMIT, never a bare `cat`. A caller that never closes stdin would park `cat` on
#    EOF until the hook's own `timeout` kills it — BEFORE the append below — and a real dispatch would
#    vanish silently (Axis-2 blind review, 2026-09-25, reproduced with `sleep 8 | …`; the old inline
#    hook never read stdin, so this was new). `read -t` is bash-builtin (macOS ships no `timeout`).
#    Whatever arrived before the limit is classified; nothing arriving → empty → COUNT.
IN=""; _l=""
while IFS= read -r -t 2 _l; do IN="$IN$_l"$'\n'; _l=""; done
IN="$IN$_l"

CLS="count"
AT=""; SID=""
if command -v python3 >/dev/null 2>&1 && [ -n "$IN" ]; then
  _r=$(printf '%s' "$IN" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    print("count\t\t"); sys.exit(0)
if not isinstance(d, dict):
    print("count\t\t"); sys.exit(0)
at = d.get("agent_type", None)
sid = d.get("session_id", "")
sid = sid if isinstance(sid, str) else ""
if at == "":
    print("internal\t\t" + sid)
else:
    print("count\t" + (at if isinstance(at, str) else "?") + "\t" + sid)
' 2>/dev/null) || _r=""
  if [ -n "$_r" ]; then
    CLS=$(printf '%s' "$_r" | cut -f1)
    AT=$(printf '%s' "$_r" | cut -f2)
    SID=$(printf '%s' "$_r" | cut -f3)
  fi
fi

mkdir -p "$(dirname "$T")" 2>/dev/null
D=$(date +%Y-%m-%d)
printf '%s\t%s\t%s\t%s\n' "$D" "$CLS" "${AT:--}" "${SID:--}" >> "$T.detail" 2>/dev/null
[ "$CLS" = internal ] && exit 0
printf '%s\n' "$D" >> "$T" 2>/dev/null
exit 0

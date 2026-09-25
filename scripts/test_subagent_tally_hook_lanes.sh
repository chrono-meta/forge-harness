#!/usr/bin/env bash
# test_subagent_tally_hook_lanes.sh — known-pair lanes for scripts/subagent_tally_hook.sh.
#
# WHAT IS PINNED: SubagentStop fires for dispatched agents AND for Claude Code's internal agents.
# Fixture shapes below are the MEASURED payloads (claude 2.1.282 headless, 2026-09-25), trimmed to
# the fields that matter:
#   dispatch, subagent_type=Explore      → agent_type "Explore"
#   dispatch, subagent_type omitted      → agent_type "general-purpose"
#   /compact (internal, PreCompact fired) → agent_type ""
# The tally must count the first two and skip the third — and must COUNT on every doubtful input
# (absent field · non-JSON · empty stdin), because under-counting a real dispatch is the silent
# fail-open ④-e exists to close.
#
# REVERT PROBE: the old inline hook (date-only append) is replayed against the internal-agent
# fixture and MUST count it. If it ever stops counting, the lane pair is no longer measuring the
# defect it was written for.
#
# Exit 0 = discriminates · 1 = would mis-tally.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBJ="$SCRIPT_DIR/subagent_tally_hook.sh"
FAILED=0; PASS=0
chk() { if [ "$1" -eq 0 ]; then PASS=$((PASS+1)); echo "  ✅ $2"; else FAILED=1; echo "  ❌ $2"; fi; }
[ -f "$SUBJ" ] || { echo "FAIL  subject $SUBJ missing"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "SKIP  python3 absent — the discriminator cannot run here (the hook then COUNTS everything, the safe direction). Not a pass."; exit 0; }

T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
TODAY=$(date +%Y-%m-%d)
run() {  # $1 = stdin payload ; echoes today's tally count after one invocation on a fresh file
  local f="$T/tally.$RANDOM$RANDOM"
  printf '%s' "$1" | FH_TALLY_FILE="$f" bash "$SUBJ" >/dev/null 2>&1 || { echo RC_NONZERO; return; }
  if [ -f "$f" ]; then grep -c "^$TODAY$" "$f"; else echo 0; fi
}
P_EXPLORE='{"session_id":"s1","hook_event_name":"SubagentStop","agent_id":"a1","agent_type":"Explore"}'
P_GENERAL='{"session_id":"s1","hook_event_name":"SubagentStop","agent_id":"a2","agent_type":"general-purpose"}'
P_INTERNAL='{"session_id":"s1","hook_event_name":"SubagentStop","agent_id":"a3","agent_type":""}'
P_NOFIELD='{"session_id":"s1","hook_event_name":"SubagentStop","agent_id":"a4"}'

echo "── known-positive: dispatched agents are counted"
[ "$(run "$P_EXPLORE")" = 1 ] ; chk $? "agent_type Explore → counted"
[ "$(run "$P_GENERAL")" = 1 ] ; chk $? "subagent_type omitted (general-purpose) → counted"
echo "── known-negative: the internal agent is skipped"
[ "$(run "$P_INTERNAL")" = 0 ] ; chk $? "agent_type \"\" (compaction) → NOT counted"
echo "── every doubt counts (under-count is the silent direction)"
[ "$(run "$P_NOFIELD")" = 1 ] ; chk $? "agent_type absent (older CLI) → counted"
[ "$(run 'not json {')" = 1 ] ; chk $? "non-JSON stdin → counted"
[ "$(run '')" = 1 ]           ; chk $? "empty stdin → counted"
[ "$(run '[1,2]')" = 1 ]      ; chk $? "JSON but not an object → counted"
[ "$(run '{"agent_type":null}')" = 1 ] ; chk $? "agent_type null (not the empty string) → counted"

echo "── tally line format unchanged (④-e matches ^DATE\$ exactly)"
f="$T/fmt"; printf '%s' "$P_EXPLORE" | FH_TALLY_FILE="$f" bash "$SUBJ"
[ "$(cat "$f")" = "$TODAY" ] ; chk $? "the tally line is the bare date, nothing appended"
printf '%s' "$P_INTERNAL" | FH_TALLY_FILE="$f" bash "$SUBJ"
grep -q "$(printf '%s\tinternal\t-\ts1' "$TODAY")" "$f.detail" ; chk $? "the skipped internal agent is still RECORDED in the side file (attributable, not vanished)"

echo "── rc"
out=$(printf 'garbage' | FH_TALLY_FILE=/nonexistent-dir/x/y bash "$SUBJ" 2>&1); rc=$?
[ "$rc" -eq 0 ] ; chk $? "unwritable tally path → still exit 0 (a hook must never block a subagent)"

echo "── revert probe: the OLD inline body counts the internal agent (control)"
old() { printf '%s\n' "$(date +%Y-%m-%d)" >> "$1"; }
f="$T/old"; printf '%s' "$P_INTERNAL" | old "$f"
[ "$(grep -c "^$TODAY$" "$f")" = 1 ] ; chk $? "control alive: date-only append DOES count compaction — the defect this lane exists for"

echo "── stdin never closed (the caller keeps the pipe open) → still counts, within the limit"
f="$T/open"
# 🟥 time the HOOK only — timing the whole pipeline also waits for the producer's `sleep`.
( sleep 5 ) | { s0=$(date +%s); FH_TALLY_FILE="$f" bash "$SUBJ"; echo $(( $(date +%s) - s0 )) > "$f.dur"; }
dur=$(cat "$f.dur" 2>/dev/null || echo 99)
[ "$(grep -c "^$TODAY$" "$f" 2>/dev/null || echo 0)" = 1 ] ; chk $? "open, silent stdin → counted (a bare \`cat\` blocked here until the hook was killed)"
[ "$dur" -le 4 ] ; chk $? "and the hook returned by its read limit, not at the caller's EOF (${dur}s)"
f="$T/open2"; ( printf '%s' "$P_INTERNAL"; sleep 5 ) | FH_TALLY_FILE="$f" bash "$SUBJ"
[ "$(grep -c "^$TODAY$" "$f" 2>/dev/null || echo 0)" = 0 ] ; chk $? "payload delivered but pipe left open → still classified (internal skipped)"

f="$T/nul"; printf '%s\0 ' "$P_INTERNAL" | FH_TALLY_FILE="$f" bash "$SUBJ"
[ "$(grep -c "^$TODAY$" "$f" 2>/dev/null || echo 0)" = 1 ] ; chk $? "raw NUL after an internal payload → counted (OUTCOME lane: json rejects NUL — the bash reader that turned it into whitespace is gone; codex 2026-09-25)"
f="$T/big"; s=$(date +%s); { printf '{"agent_type":"","pad":"'; head -c 9000000 /dev/zero | tr '\0' x; printf '"}'; } | FH_TALLY_FILE="$f" bash "$SUBJ"; e=$(( $(date +%s) - s ))
[ "$(grep -c "^$TODAY$" "$f" 2>/dev/null || echo 0)" = 1 ] ; chk $? "payload over the 8 MiB cap → truncated → DOUBT → counted"
[ "$e" -le 8 ] ; chk $? "and the cap bounds the read time (${e}s)"

echo "── wiring: EXECUTE the shipped template command (a grep for the path matched the _readme text)"
TPL="$SCRIPT_DIR/../templates/subagent-tally-hook.json"
CMD=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["hooks"]["SubagentStop"][0]["hooks"][0]["command"])' "$TPL" 2>/dev/null)
[ -n "$CMD" ] ; chk $? "template command extracted from hooks.SubagentStop[0].hooks[0].command"
tpl_run() {  # $1 = hub dir · $2 = payload → today's count in that hub's tally
  printf '%s' "$2" | CLAUDE_PROJECT_DIR="$1" bash -c "$CMD" >/dev/null 2>&1
  local t="$1/tracks/_meta/.subagent_dispatch_tally"
  if [ -f "$t" ]; then grep -c "^$TODAY$" "$t"; else echo 0; fi
}
H1="$T/hub_with"; mkdir -p "$H1/scripts"; cp "$SUBJ" "$H1/scripts/"
[ "$(tpl_run "$H1" "$P_INTERNAL")" = 0 ] ; chk $? "template + script present: internal agent → 0 (the command really calls the script)"
[ "$(tpl_run "$H1" "$P_EXPLORE")" = 1 ]  ; chk $? "template + script present: Explore → 1"
H2="$T/hub_without"; mkdir -p "$H2"
[ "$(tpl_run "$H2" "$P_INTERNAL")" = 1 ] ; chk $? "template + script MISSING (older clone): falls back to counting → 1, never silence"

echo ""
if [ "$FAILED" -eq 0 ]; then echo "PASS  subagent tally hook: $PASS lanes"; exit 0; fi
echo "FAIL  subagent tally hook"; exit 1

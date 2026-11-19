#!/usr/bin/env bash
# agy_launch_guard.sh — every FH launch of agy (the Antigravity CLI) goes through here.
#
# WHY. agy runs its own tools (shell commands, file reads) even in `--mode plan`, and what those tools
# print goes into the conversation the cloud model reads. Measured 2026-11-16 on a review run with an
# empty temp directory as cwd: agy ran a filesystem-wide `find` and a recursive `grep` over the home
# directory, read the run's answer key in 45 of 83 conversations, and the search output carried file
# names from a company repository checked out on the same machine. Claude-side deny rules do not bind
# agy. 🟥 `--sandbox` is NOT isolation: measured 2026-11-16 (canary test), `agy -p --mode plan --sandbox`
# from a fresh temp cwd read three canary files it was pointed at — one in cwd, one in another temp
# folder, one in the home directory. It restricts the terminal at most; file reads go through.
#
# RULE. A cloud agent CLI with tools enabled must not run on a machine where company repositories are
# readable. Allowed instead: a tool-less API call (that does not use agy, so it does not come here), or
# agy inside a container or a separate OS user that can see only the frozen inputs of the task.
#
# MARKER. FH_AGY_ISOLATION=container  or  FH_AGY_ISOLATION=os-user, or FH_AGY_ISOLATION=remote-os-user
# (honoured only when the target is scripts/agy_remote_run.sh beside this guard). Unset, empty, or any other value
# (including 1 / yes / true) is refused. 🟥 The marker is self-declared: this script checks that you
# said it, not that it is true — it cannot see a container or an OS user. Set it only inside a container
# or OS user where a canary check has confirmed it: place a canary file outside the frozen inputs (in
# the host home directory and in another temp folder), ask agy to read those exact paths, and set the
# marker only if every read fails. Never on the host that holds company repositories, and never because
# of `--sandbox`.
#
# NO-TOOLS AGENT (2026-11-19, on this machine). FH_AGY_ISOLATION=no-tools-agent is the one marker the guard
# can partly CHECK rather than take on trust. Measured 2026-11-19 with canaries: a custom agent whose
# definition says `tools: []` made 0 file reads in 4 of 4 runs, while a control with the same body and no
# `tools` line read both canaries; settings keys and `permissions.deny` did not stop reads, and `init.tools`
# lists 60 tools either way (not a signal). `manage_task` (agy's own task list) still ran. So on this route:
#   1. refuse unless the prompt (stdin), the arguments and the working folder carry no company-repo root —
#      the matcher is codex_launch_guard.sh's, and an UNCONFIGURED list is refused here, not warned;
#   2. refuse a caller's own --agent or any output format but text (a caller's `--output-format text` is
#      dropped — this route prints the result text; FH's fleet and verifier pass it);
#   3. write an FH-owned definition with `tools: []` under a unique name into the folder agy discovers
#      (FH_AGY_AGENTS_DIR, default ~/.gemini/agents — measured: `agy agents` lists definitions from
#      ~/.gemini/agents and ~/.gemini/config/agents only, not from the working folder), run agy with
#      --agent <it> --output-format stream-json, and remove the definition when the run ends;
#   4. read the whole stream and VOID the run (exit 4, nothing on stdout) when a line does not parse, the
#      init event names another agent, a step is neither user_input nor agent_response nor a tool step whose
#      tool_name AND tool_info.name are both exactly manage_task (any state — ACTIVE, DONE or ERROR), an event
#      is not init / step_update / result, or no successful result arrives — naming the step or tool. Only a
#      run that passes prints the result text on stdout. Deny by default: 13 probe runs saw manage_task,
#      read_file, search_web and write_file, which is not every tool agy has.
# 🟥 A void cannot un-send: what a forbidden tool read has already gone to the cloud model. That is why step 1
# refuses company paths before the start, and why this route is for public material only.
#
# Usage:  bash scripts/agy_launch_guard.sh <agy-binary> [agy arguments...]
# Exit:   3 = refused, agy was not started · 2 = usage · 4 = no-tools-agent run voided (stdout empty)
#         · otherwise agy's own exit code
set -uo pipefail
[ $# -ge 1 ] || { echo "usage: agy_launch_guard.sh <agy-binary> [agy arguments...]" >&2; exit 2; }
case "${FH_AGY_ISOLATION-}" in
  container|os-user) exec "$@" ;;
  no-tools-agent)
    _here="$(cd "$(dirname "$0")" && pwd -P)"
    _refuse() { echo "AGY-REFUSED: $1 — agy was not started (FH_AGY_ISOLATION=no-tools-agent)." >&2; exit 3; }
    # The caller's own `--output-format text` is dropped (this route prints the result text anyway — FH's
    # fleet and verifier pass it); any other output format or an --agent is refused.
    _args=(); _skip=0
    for _a in "${@:2}"; do
      if [ "$_skip" = 1 ]; then
        _skip=0; [ "$_a" = text ] && continue
        _refuse "the caller asked for --output-format $_a; this route prints text only"
      fi
      case "$_a" in
        --output-format) _skip=1 ;;
        --output-format=text) ;;
        --output-format=*) _refuse "the caller asked for $_a; this route prints text only" ;;
        --agent|--agent=*) _refuse "the caller passed $_a; this route sets the agent itself" ;;
        *) _args+=("$_a") ;;
      esac
    done
    [ "$_skip" = 0 ] || _refuse "--output-format has no value"
    set -- "$1" ${_args[@]+"${_args[@]}"}
    [ -f "$_here/codex_launch_guard.sh" ] || _refuse "codex_launch_guard.sh (the company-path matcher) is missing beside this guard"
    _w="$(mktemp -d "${TMPDIR:-/tmp}/fh_agy_nt.XXXXXX")" || _refuse "no temp dir"
    _def=""
    trap 'rm -rf "$_w"; [ -n "$_def" ] && rm -f "$_def"' EXIT
    if [ -t 0 ]; then : > "$_w/prompt"; else cat > "$_w/prompt"; fi
    _chk="$(bash "$_here/codex_launch_guard.sh" /usr/bin/true "$@" < "$_w/prompt" 2>&1)"; _crc=$?   # the agy path itself too
    [ "$_crc" -eq 0 ] || _refuse "the company-path check refused or failed: $(printf '%s' "$_chk" | tr '\n' ' ' | cut -c1-200)"
    case "$_chk" in *"no company roots configured"*) _refuse "no company-repo roots are configured, so the prompt could not be checked" ;; esac
    _dir="${FH_AGY_AGENTS_DIR:-$HOME/.gemini/agents}"
    mkdir -p "$_dir" || _refuse "cannot create the agents folder $_dir"
    _name="fh-notools-$(od -An -N6 -tx1 /dev/urandom | tr -d ' \n')"
    [ "${#_name}" -eq 23 ] || _refuse "could not make a unique agent name"
    _def="$_dir/$_name.md"
    [ ! -e "$_def" ] || _refuse "an agent definition named $_name already exists"
    printf -- '---\nname: %s\ndescription: FH tool-less agent (written by agy_launch_guard.sh, removed after the run)\ntools: []\n---\nYou have no tools. Answer from the prompt text only.\n' "$_name" > "$_def" \
      || _refuse "cannot write the agent definition"
    "$1" "${@:2}" --agent "$_name" --output-format stream-json < "$_w/prompt" > "$_w/stream" 2> "$_w/err"; _arc=$?
    rm -f "$_def"; _def=""
    _v="$(python3 - "$_w/stream" "$_name" "$_w/response" <<'PY'
import json, sys
path, name, out = sys.argv[1], sys.argv[2], sys.argv[3]
def void(why): print("VOID " + why); sys.exit(0)
init = result = None
try: lines = open(path, encoding="utf-8").read().splitlines()
except (OSError, UnicodeDecodeError) as e: void("stream unreadable (%s)" % type(e).__name__)
for n, raw in enumerate(lines, 1):
    if not raw.strip(): void("line %d is blank" % n)   # deny by default: agy does not print blank lines
    try: d = json.loads(raw)
    except ValueError: void("line %d is not JSON" % n)
    if not isinstance(d, dict): void("line %d is not an object" % n)
    ev = d.get("event")
    body = d.get(ev) if isinstance(ev, str) else None
    if not isinstance(body, dict): void("line %d has no event body" % n)
    if ev == "init":
        if init is not None: void("a second init event on line %d" % n)
        init = body
        if body.get("agent") != name: void("init names agent %r, not %s" % (body.get("agent"), name))
    elif ev == "step_update":
        if init is None: void("a step before the init event (line %d)" % n)
        st = body.get("step_type")
        if st in ("user_input", "agent_response"): continue
        if st == "tool":
            # agy 1.5.11 names a tool step twice: step_update.tool_name and step_update.tool_info.name (13 probe
            # runs, 2026-11-19). Both must say manage_task; a missing or different one voids — whatever the
            # state (ACTIVE, DONE or ERROR: a tool that started has run).
            info = body.get("tool_info")
            n1, n2 = body.get("tool_name"), (info.get("name") if isinstance(info, dict) else None)
            if n1 == "manage_task" and n2 == "manage_task": continue
            void("tool step %s (index %s, state %s)" % ("/".join(sorted({str(n1), str(n2)})), body.get("step_index"), body.get("state")))
        void("step of type %r (index %s; keys %s)" % (st, body.get("step_index"), ",".join(sorted(body))))
    elif ev == "result":
        if result is not None: void("a second result event on line %d" % n)
        result = body
    else:
        void("unknown event %r on line %d" % (ev, n))
if init is None: void("no init event")
if result is None: void("no result event")
if result.get("status") != "SUCCESS": void("result status %r" % result.get("status"))
resp = result.get("response")
if not isinstance(resp, str): void("result has no response text")
open(out, "w", encoding="utf-8").write(resp)
print("OK")
PY
)"
    case "$_v" in
      OK) cat "$_w/response"; exit "$_arc" ;;
      VOID*) echo "AGY-VOID: ${_v#VOID } — the run was discarded (agy rc=$_arc). Anything a tool read has already been sent; this route takes public material only." >&2
             [ -s "$_w/err" ] && tail -3 "$_w/err" >&2
             exit 4 ;;
      *) echo "AGY-VOID: the stream check did not run (${_v:-no output}) — the run was discarded (agy rc=$_arc)." >&2; exit 4 ;;
    esac ;;
  remote-os-user)
    # Honoured for ONE route only: the target must be FH's remote runner beside this guard, which runs
    # agy as a separate OS user on another machine and itself refuses without a fresh canary receipt.
    _here="$(cd "$(dirname "$0")" && pwd -P)"
    _tgt_dir="$(cd "$(dirname "$1")" 2>/dev/null && pwd -P)"
    if [ "$_tgt_dir/$(basename "$1")" = "$_here/agy_remote_run.sh" ] && [ -f "$_here/agy_remote_run.sh" ]; then
      exec bash "$_here/agy_remote_run.sh" "${@:2}"
    fi
    echo "AGY-REFUSED: FH_AGY_ISOLATION=remote-os-user is honoured only when the target is $_here/agy_remote_run.sh (got: $1)." >&2
    exit 3 ;;
esac
{
  echo "AGY-REFUSED: agy was not started (FH_AGY_ISOLATION=${FH_AGY_ISOLATION-<unset>})."
  echo "  agy runs shell and file tools and sends their output to a cloud model, so it must not run where"
  echo "  company repositories are readable. Run it in a container or a separate OS user that sees only the"
  echo "  frozen inputs, then set FH_AGY_ISOLATION=container|os-user there — or use a tool-less API call."
  echo "  On this machine, for public material only: FH_AGY_ISOLATION=no-tools-agent (a tools: [] agent, every run checked)."
} >&2
exit 3

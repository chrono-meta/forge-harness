#!/usr/bin/env bash
# codex_launch_guard.sh — FH starts codex through here. Lighter than agy_launch_guard.sh: codex is allowed
# on this machine, but never on company-repo material.
#
# WHY. codex `--sandbox read-only` limits writes, not reads: measured 2026-11-16 with canary files, it read
# paths in its cwd, in another temp folder and in the home directory. Whatever it reads goes to the cloud
# model. So a codex arm may only be handed public material, and this guard refuses the obvious leak: a
# prompt, an argument or a working folder that names a configured company-repo root.
#
# LIST. Company-repo roots, one absolute path per line, from FH_COMPANY_ROOTS (newline- or ':'-separated)
# or else the file FH_COMPANY_ROOTS_FILE (default: <repo>/.claude/rules/.company-roots, gitignored; '#'
# comments and blank lines ignored). No root path appears in any public file.
#
# MATCH. A root matches when it appears as a path in the prompt (stdin) or an argument — the root string
# followed by '/', end of text, or a character that cannot continue a path name — in any of three spellings:
# as given, its real path, with a leading /private removed (macOS /tmp = /private/tmp), and with $HOME
# written as '~'. Case-sensitive. The working folder matches when its real path is the root or below it.
# NOT matched: a relative path, file content pasted without its path, or an encoded path — the guard is a
# string check, not isolation. Not reached: a caller that starts codex by absolute path around this guard
# (finding_fleet routes CODEX_BIN and bare `codex` through a PATH shim; an absolute path skips it).
#
# UNCONFIGURED. No list, or an empty one: codex runs and the guard prints «CODEX-GUARD: no company roots
# configured — not checked» on stderr. That is said out loud, never shown as clean.
#
# Usage:  bash scripts/codex_launch_guard.sh <codex-binary> [codex arguments...]   (prompt on stdin; see STDIN below)
# Exit:   3 = refused (codex not started; stderr starts «HARNESS-ERROR: CODEX-REFUSED») · 2 = usage
#         · otherwise codex's own exit code (a codex exit of 3 is told apart by the missing CODEX-REFUSED line)
set -uo pipefail
[ $# -ge 1 ] || { echo "usage: codex_launch_guard.sh <codex-binary> [codex arguments...]" >&2; exit 2; }
_here="$(cd "$(dirname "$0")" && pwd -P)"
_rootsfile="${FH_COMPANY_ROOTS_FILE:-$_here/../.claude/rules/.company-roots}"
_tmp="$(mktemp "${TMPDIR:-/tmp}/fh_codex_prompt.XXXXXX")" || { echo "HARNESS-ERROR: codex_launch_guard cannot create a temp file — codex not started" >&2; exit 3; }
trap 'rm -f "$_tmp"' EXIT
# STDIN. A terminal means no prompt (nothing is read). Anything else is read until it ends — but not forever:
# a stdin that sends nothing new for FH_GUARD_STDIN_IDLE_S seconds (default 60), or has not ended after
# FH_GUARD_STDIN_MAX_S seconds in all (default 600), is a refusal — never a partial or empty prompt passed on,
# never a hang. An agent's background shell hands its children a stdin that stays open and never ends;
# measured 2026-11-20, a plain `cat` here waited 2 h 30 min and, after the guard was killed, still held the
# caller's output pipe open. Each limit is a whole number of seconds from 1 to 86400 (unset or empty = the
# default); anything else is refused.
if [ -t 0 ]; then : > "$_tmp"
else
  _idle="${FH_GUARD_STDIN_IDLE_S:-60}"; _max="${FH_GUARD_STDIN_MAX_S:-600}"
  for _lim in "FH_GUARD_STDIN_IDLE_S=$_idle" "FH_GUARD_STDIN_MAX_S=$_max"; do
    _v="${_lim#*=}"
    case "$_v" in ''|*[!0-9]*) _v=x ;; *) [ "${#_v}" -le 5 ] && [ "$((10#$_v))" -ge 1 ] && [ "$((10#$_v))" -le 86400 ] || _v=x ;; esac
    [ "$_v" = x ] && { echo "HARNESS-ERROR: CODEX-REFUSED — ${_lim%%=*}='${_lim#*=}' is not a whole number of seconds from 1 to 86400; codex was not started." >&2; exit 3; }
  done
  python3 -c '
import os, select, sys, time
idle, total = int(sys.argv[1], 10), int(sys.argv[2], 10); out = sys.stdout.buffer
end = time.monotonic() + total
try:
    while True:
        left = end - time.monotonic()
        if left <= 0: sys.exit(125)
        if not select.select([0], [], [], min(idle, left))[0]:
            sys.exit(125 if time.monotonic() >= end else 124)
        b = os.read(0, 65536)
        if not b: break
        out.write(b)
except OSError: sys.exit(5)
' "$_idle" "$_max" > "$_tmp"
  case $? in
    0) ;;
    124) echo "HARNESS-ERROR: CODEX-REFUSED — stdin is open but sent nothing for ${_idle} s and never ended (an agent background shell does this); codex was not started. Pipe the prompt in, or run with < /dev/null." >&2; exit 3 ;;
    125) echo "HARNESS-ERROR: CODEX-REFUSED — stdin had not ended after ${_max} s in all; codex was not started. Pipe in a prompt that ends, or run with < /dev/null." >&2; exit 3 ;;
    *) echo "HARNESS-ERROR: CODEX-REFUSED — codex_launch_guard could not read the prompt from stdin; codex was not started." >&2; exit 3 ;;
  esac
fi
_verdict="$(FH_GUARD_PROMPT="$_tmp" FH_GUARD_ROOTS_FILE="$_rootsfile" python3 - "${@:2}" <<'PY'
import os, re, sys
def roots():
    env = os.environ.get("FH_COMPANY_ROOTS")
    if env is not None and env.strip():
        raw = re.split(r"[\n:]", env)
    else:
        try: raw = open(os.environ["FH_GUARD_ROOTS_FILE"], encoding="utf-8").read().splitlines()
        except FileNotFoundError: raw = []          # no list at all: unconfigured, said out loud
        except OSError as e:                         # a list that exists but cannot be read: refuse
            print("ERROR the company-roots file exists but cannot be read (%s)" % type(e).__name__); sys.exit(0)
    out = []
    for r in raw:
        r = r.strip()
        if r and not r.startswith("#"): out.append(r.rstrip("/"))
    return out
R = roots()
if not R:
    print("UNCONFIGURED"); sys.exit(0)
home = os.path.expanduser("~").rstrip("/")
def spellings(r):
    s = {r}
    try: s.add(os.path.realpath(r).rstrip("/"))
    except OSError: pass
    for x in list(s):
        if x.startswith("/private/"): s.add(x[len("/private"):])
        if home and (x == home or x.startswith(home + "/")): s.add("~" + x[len(home):])
    return [x for x in s if x]
pats = []
for r in R:
    for sp in spellings(r):
        pats.append(re.compile(re.escape(sp) + r"(?=/|$|[^A-Za-z0-9._\-~])"))
def hit(text): return any(p.search(text) for p in pats)
where = []
try: prompt = open(os.environ["FH_GUARD_PROMPT"], encoding="utf-8", errors="replace").read()
except OSError: print("ERROR cannot read the prompt"); sys.exit(0)
if hit(prompt): where.append("prompt")
if any(hit(a) for a in sys.argv[1:]): where.append("argument")
cwd = os.path.realpath(os.getcwd())
for r in R:
    rr = os.path.realpath(r)
    if cwd == rr or cwd.startswith(rr.rstrip("/") + "/"): where.append("working folder"); break
print("REFUSE " + ",".join(where) if where else "OK")
PY
)" || _verdict="ERROR the matcher failed"
case "$_verdict" in
  OK) ;;
  UNCONFIGURED) echo "CODEX-GUARD: no company roots configured — not checked (set FH_COMPANY_ROOTS or $_rootsfile)" >&2 ;;
  REFUSE*) echo "HARNESS-ERROR: CODEX-REFUSED — a company-repo root appears in the ${_verdict#REFUSE }; codex was not started. Send codex public material only." >&2; exit 3 ;;
  *) echo "HARNESS-ERROR: CODEX-REFUSED — codex_launch_guard could not check (${_verdict}); codex was not started." >&2; exit 3 ;;
esac
exec 3<"$_tmp"; rm -f "$_tmp"; trap - EXIT
exec "$@" <&3 3<&-

#!/usr/bin/env bash
# test_fh_guard_plugin_lanes.sh — known pairs for plugins/fh-guard (installable, character-free gate plugin)
#
# WHAT IS BEING GUARDED
#   fh-guard ships ONE copy of scripts/destructive_pre_gate.sh inside the plugin directory, because a
#   marketplace install copies only the plugin directory into the cache and rejects `..` paths. A
#   copy rots: the day the main gate gets a fix (#1192, #1195), the plugin would keep the old verdict
#   and every field repo would run the weaker one while looking guarded. These lanes keep the two
#   files byte-identical, keep the wiring that makes the copy reachable (hooks.json, marketplace
#   entry, package files[]), and run the copy the way the hook runs it — a byte check alone passes
#   on a copy that is never invoked.
#
#   They also pin the two «gate is not really standing» paths the design picked (operator, 2026-11-23,
#   DESIGN.md §3-a (ii)): the PreToolUse entry carries onFailure:block (hook cannot start / times
#   out → the Bash call blocks), and the SessionStart preflight prints one line when python3 is
#   absent or broken (the gate reads its payload with python3 and exits 0 without it — onFailure
#   cannot see that, it is a clean exit). Both directions of each are lanes: the preflight must be
#   SILENT when python3 works, or it trains people to ignore it.
#
# NOT CHECKED HERE: that Claude Code actually loads the plugin and fires the hook — that is the
#   --plugin-dir smoke and the 72-run measurement (tracks/_meta/fh_guard_plugin_2026-11-23). A green
#   lane here says the files are right, not that a session is guarded.

. "$(dirname "${BASH_SOURCE[0]}")/fixture_guard_lib.sh"   # scrub inherited GIT_* env first (#1088)
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
P="$ROOT/plugins/fh-guard"
MAIN_GATE="$ROOT/scripts/destructive_pre_gate.sh"
COPY="$P/scripts/destructive_pre_gate.sh"
PRE="$P/scripts/fh_guard_preflight.sh"
pass=0; fail=0
ok()  { printf '  ✅ %s\n' "$1"; pass=$((pass+1)); }
bad() { printf '  ❌ %s\n' "$1"; [ -n "${2:-}" ] && printf '     %s\n' "$2"; fail=$((fail+1)); }

TMP=$(mktemp -d "${TMPDIR:-/tmp}/fhguard_lanes.XXXXXX") || { echo "HARNESS-ERROR: mktemp"; exit 2; }
trap 'rm -rf "$TMP"' EXIT

echo "[fh-guard] plugin known pairs"

echo "-- L1 copy is byte-identical to the main gate --"
if [ ! -f "$COPY" ]; then
  bad "L1 plugin copy exists" "missing: plugins/fh-guard/scripts/destructive_pre_gate.sh"
elif cmp -s "$MAIN_GATE" "$COPY"; then
  ok "L1 plugins/fh-guard/scripts/destructive_pre_gate.sh == scripts/destructive_pre_gate.sh"
else
  bad "L1 copy drifted from the main gate" "fix: cp scripts/destructive_pre_gate.sh plugins/fh-guard/scripts/"
fi
# control for L1: cmp must be able to say «different» — a mutated copy in TMP must not compare equal
if [ -f "$COPY" ]; then
  { cat "$COPY"; echo '# drift'; } > "$TMP/mut.sh"
  if cmp -s "$MAIN_GATE" "$TMP/mut.sh"; then bad "L1-ctl cmp told a mutated copy apart" "cmp reported equal on a mutated file"
  else ok "L1-ctl a one-line drift is caught by cmp"; fi
fi

echo "-- L2 hooks.json wires the copy (and the preflight) --"
H="$P/hooks/hooks.json"
if [ ! -f "$H" ]; then
  bad "L2 hooks/hooks.json exists" "missing: $H"
else
  out=$(python3 - "$H" <<'PY' 2>&1
import json, sys
d = json.load(open(sys.argv[1]))
errs = []
h = d.get("hooks")
if not isinstance(h, dict): errs.append("no top-level 'hooks' wrapper (plugin hooks file fails to load without it)")
else:
    pre = [x for e in h.get("PreToolUse", []) if e.get("matcher") == "Bash" for x in e.get("hooks", [])]
    # exact string, not a substring: `true # ${CLAUDE_PLUGIN_ROOT}/scripts/destructive_pre_gate.sh` contains the
    # path and runs nothing (codex R1, 2026-11-23). L4/L5 also EXECUTE the command read from this file.
    GATE_CMD = 'bash "${CLAUDE_PLUGIN_ROOT}/scripts/destructive_pre_gate.sh"'
    PRE_CMD = 'bash "${CLAUDE_PLUGIN_ROOT}/scripts/fh_guard_preflight.sh"'
    g = [x for x in pre if x.get("command", "") == GATE_CMD]
    if len(g) != 1: errs.append(f"PreToolUse Bash entries whose command is exactly {GATE_CMD}: {len(g)} (want 1); commands seen: {[x.get('command') for x in pre]}")
    else:
        g = g[0]
        if g.get("type") != "command": errs.append("gate entry type is not command")
        if g.get("onFailure") != "block": errs.append(f"gate onFailure={g.get('onFailure')!r} (want 'block' — a hook that cannot start must not pass the call)")
        # async / asyncRewake hooks run in the background and cannot block the call (codex R2, 2026-11-23)
        for k in ("async", "asyncRewake"):
            if g.get(k): errs.append(f"gate entry has {k}={g.get(k)!r} — a background hook cannot block")
        t = g.get("timeout")
        if not isinstance(t, (int, float)) or t <= 0 or t > 30: errs.append(f"gate timeout={t!r} (want 1..30 s; default is 600 and a timeout must block, not stall)")
    ssg = [e for e in h.get("SessionStart", []) for x in e.get("hooks", []) if x.get("command", "") == PRE_CMD]
    if len(ssg) != 1: errs.append(f"SessionStart entries running the preflight: {len(ssg)} (want 1)")
    # a restrictive matcher (e.g. "resume") would skip the notice on a fresh session (codex R2, 2026-11-23)
    elif ssg[0].get("matcher") not in (None, "", "*"):
        errs.append(f"preflight SessionStart matcher={ssg[0].get('matcher')!r} (want absent, empty or '*': every session start)")
    other = sorted(set(h) - {"PreToolUse", "SessionStart"})
    if other: errs.append(f"unexpected hook events {other} (fh-guard ships the gate and its preflight only)")
print("\n".join(errs) if errs else "OK")
PY
)
  if [ "$out" = "OK" ]; then ok "L2 hooks.json: wrapper · one Bash gate entry (exact cmd · onFailure=block · short timeout · not async) · one preflight on every session start"
  else bad "L2 hooks.json" "$out"; fi
fi

echo "-- L3 manifest · marketplace · package ship the plugin --"
out=$(python3 - "$ROOT" <<'PY' 2>&1
import json, os, sys
r = sys.argv[1]; errs = []
try:
    pj = json.load(open(os.path.join(r, "plugins/fh-guard/.claude-plugin/plugin.json")))
except Exception as e:
    print(f"plugin.json unreadable: {e}"); sys.exit()
pkg = json.load(open(os.path.join(r, "package.json")))
if pj.get("name") != "fh-guard": errs.append(f"plugin.json name={pj.get('name')!r}")
if pj.get("version") != pkg.get("version"): errs.append(f"plugin.json version {pj.get('version')} != package.json {pkg.get('version')}")
mk = json.load(open(os.path.join(r, ".claude-plugin/marketplace.json")))
ent = [p for p in mk.get("plugins", []) if p.get("name") == "fh-guard"]
if len(ent) != 1: errs.append(f"marketplace entries named fh-guard: {len(ent)}")
elif ent[0].get("source") != "./plugins/fh-guard": errs.append(f"marketplace source={ent[0].get('source')!r}")
elif ent[0].get("version") != pkg.get("version"): errs.append("marketplace version != package.json")
files = pkg.get("files", [])
for need in ("plugins/fh-guard/.claude-plugin/plugin.json", "plugins/fh-guard/hooks", "plugins/fh-guard/scripts", "plugins/fh-guard/README.md"):
    if need not in files: errs.append(f"package.json files[] lacks {need}")
print("\n".join(errs) if errs else "OK")
PY
)
if [ "$out" = "OK" ]; then ok "L3 plugin.json name/version · marketplace entry · package files[]"
else bad "L3 manifest/marketplace/package" "$out"; fi

echo "-- L4 the command in hooks.json runs the gate (known pair, bypass payload) --"
# Read the command out of hooks.json and run it through a shell with CLAUDE_PLUGIN_ROOT exported, as Claude Code
# does — so a hooks.json command that no longer reaches the copy turns these lanes red, not only L2.
hook_cmd() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print([x["command"] for e in d["hooks"][sys.argv[2]] for x in e["hooks"]][0])' "$P/hooks/hooks.json" "$1" 2>/dev/null; }
GATE_RUN=$(hook_cmd PreToolUse); PRE_RUN=$(hook_cmd SessionStart)
# hook payload exactly as Claude Code sends it: tool_name, tool_input.command, permission_mode
run_copy() { # $1=command $2=permission_mode → prints rc
  local payload
  payload=$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]},"permission_mode":sys.argv[2],"hook_event_name":"PreToolUse"}))' "$1" "$2")
  ( cd "$TMP" && printf '%s' "$payload" | env -u FH_DESTRUCTIVE_BLOCK CLAUDE_PLUGIN_ROOT="$P" sh -c "$GATE_RUN" >/dev/null 2>&1 ); echo $?
}
if [ -f "$COPY" ] && [ -n "$GATE_RUN" ]; then
  rc=$(run_copy 'git push --force origin trunk' bypassPermissions)
  [ "$rc" = 2 ] && ok "L4a force push, bypass → exit 2 (blocked)" || bad "L4a force push, bypass" "rc=$rc (want 2)"
  rc=$(run_copy 'git push origin --delete release/2026-10' auto)
  [ "$rc" = 2 ] && ok "L4b remote delete, auto → exit 2 (blocked)" || bad "L4b remote delete, auto" "rc=$rc (want 2)"
  rc=$(run_copy 'git status && git log --oneline -3' bypassPermissions)
  [ "$rc" = 0 ] && ok "L4c benign command, bypass → exit 0 (clean)" || bad "L4c benign, bypass" "rc=$rc (want 0)"
  rc=$(run_copy 'git push --force origin trunk' default)
  [ "$rc" = 0 ] && ok "L4d force push, default mode → exit 0 (advisory, same as main)" || bad "L4d force push, default" "rc=$rc (want 0)"
  # block text names no way past (#1192): no noqa / DESTRUCTIVE_OP_OK hint in what the agent reads
  payload=$(python3 -c 'import json; print(json.dumps({"tool_name":"Bash","tool_input":{"command":"git push --force origin trunk"},"permission_mode":"bypassPermissions"}))')
  txt=$(cd "$TMP" && printf '%s' "$payload" | env -u FH_DESTRUCTIVE_BLOCK CLAUDE_PLUGIN_ROOT="$P" sh -c "$GATE_RUN" 2>&1)
  if printf '%s' "$txt" | grep -qE 'noqa|DESTRUCTIVE_OP_OK=1 git'; then bad "L4e block text names a bypass" "$txt"
  elif printf '%s' "$txt" | grep -q 'DESTRUCTIVE-OP'; then ok "L4e block text names no bypass"
  else bad "L4e block text empty" "$txt"; fi
else
  bad "L4 copy or hooks.json gate command missing — cannot run"
fi

echo "-- L5 preflight: silent when python3 works, one line when it does not --"
if [ ! -f "$PRE" ] || [ -z "$PRE_RUN" ]; then
  bad "L5 preflight exists" "missing: $PRE"
else
  # L5a: real python3 on PATH → nothing printed, exit 0
  out=$(CLAUDE_PLUGIN_ROOT="$P" sh -c "$PRE_RUN" </dev/null 2>&1); rc=$?
  if [ "$rc" = 0 ] && [ -z "$out" ]; then ok "L5a python3 works → silent, exit 0"
  else bad "L5a python3 works" "rc=$rc out=$out"; fi
  # L5b: a python3 that exists but fails (the Windows Store stub shape) → one systemMessage line, exit 0
  mkdir -p "$TMP/stubbin"; printf '#!/bin/sh\necho "Python was not found; run without arguments to install from the Microsoft Store" >&2\nexit 9\n' > "$TMP/stubbin/python3"
  chmod +x "$TMP/stubbin/python3"
  out=$(PATH="$TMP/stubbin:$PATH" CLAUDE_PLUGIN_ROOT="$P" sh -c "$PRE_RUN" </dev/null 2>/dev/null); rc=$?
  if [ "$rc" = 0 ] && printf '%s' "$out" | grep -q 'fh-guard' && printf '%s' "$out" | grep -qiE 'not active|꺼짐'; then
    ok "L5b python3 stub fails → «not active» notice, exit 0"
  else bad "L5b python3 stub" "rc=$rc out=$out"; fi
  # L5c: no python3 on PATH at all → same notice (PATH holds only a dir with no python3)
  mkdir -p "$TMP/emptybin"
  out=$(env -i PATH="$TMP/emptybin" HOME="$TMP" CLAUDE_PLUGIN_ROOT="$P" /bin/bash "$PRE" </dev/null 2>/dev/null); rc=$?
  if [ "$rc" = 0 ] && printf '%s' "$out" | grep -qiE 'not active|꺼짐'; then ok "L5c no python3 → «not active» notice, exit 0"
  else bad "L5c no python3" "rc=$rc out=$out"; fi
  # L5d: the notice is valid JSON (Claude Code parses SessionStart stdout as JSON when it is JSON)
  if printf '%s' "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d.get("systemMessage")' 2>/dev/null; then
    ok "L5d notice is JSON with systemMessage"
  else bad "L5d notice JSON" "$out"; fi
fi

echo "-- L6 the plugin writes nothing and calls nothing outward --"
if [ -f "$COPY" ] && [ -f "$PRE" ]; then
  mkdir -p "$TMP/home" "$TMP/cwd"
  payload=$(python3 -c 'import json; print(json.dumps({"tool_name":"Bash","tool_input":{"command":"git push --force origin trunk"},"permission_mode":"bypassPermissions"}))')
  before=$(find "$TMP/home" "$TMP/cwd" "$P" -newer "$COPY" 2>/dev/null | sort)
  touch "$TMP/stamp"; sleep 1
  ( cd "$TMP/cwd" && printf '%s' "$payload" | HOME="$TMP/home" CLAUDE_PLUGIN_ROOT="$P" bash "$COPY" >/dev/null 2>&1 )
  ( cd "$TMP/cwd" && HOME="$TMP/home" PATH="$TMP/stubbin:$PATH" CLAUDE_PLUGIN_ROOT="$P" bash "$PRE" >/dev/null 2>&1 </dev/null )
  new=$(find "$TMP/home" "$TMP/cwd" "$P" -newer "$TMP/stamp" 2>/dev/null | sort)
  [ -z "$new" ] && ok "L6a gate + preflight left no file in HOME, cwd or the plugin dir" || bad "L6a files written" "$new"
  # control for L6a: the same find sees a file the test itself writes
  touch "$TMP/home/ctl"; ctl=$(find "$TMP/home" -newer "$TMP/stamp" 2>/dev/null)
  [ -n "$ctl" ] && ok "L6a-ctl find sees a file written after the stamp" || bad "L6a-ctl find is blind"
  hits=$(grep -nE '(^|[^[:alnum:]_])(curl|wget|nc|ncat|socat|ssh)([[:space:]]|$)|/dev/tcp' "$PRE" | grep -v '^[0-9]*:[[:space:]]*#' || true)
  [ -z "$hits" ] && ok "L6b preflight carries no network tool" || bad "L6b network tool in preflight" "$hits"
fi

echo
echo "[fh-guard] $pass passed · $fail failed"
[ "$fail" -eq 0 ]

#!/usr/bin/env bash
# Lanes for live_eval_trace.py + the behave:/inventory layer in probe_live_eval_lib.score_run (FH-3).
# Fixtures carry the event keys a real `claude -p --output-format stream-json --verbose` run emits
# (system/init tools+mcp_servers · assistant message.content[].tool_use · result) — checked against a
# recorded stream on the author machine; set LIVE_TRACE_REAL=<file.jsonl> to re-check that shape (TR0).
#   TR1 extract: result text + init inventory; a stream with no result event → rc 3 and empty text
#   TR2 the calibration PAIR: «did it» (Read CATALOG.md) PASS/BEHAVIOUR · «said it» (names CATALOG, no call) FAIL
#   TR3 first_read is order: CATALOG.md read second → FAIL
#   TR4 control arm does the action too → UNCALIBRATED (cannot discriminate)
#   TR5 no trace on disk → text verdict kept, scored_by=MENTION-ONLY, counted in mention_only_pass
#   TR6 arms with different tool/MCP lists (82 vs 24) → INVALID-COMPARISON, overall has no pass_rate
#   TR7 a malformed behave: spec → UNCALIBRATED with BAD-BEHAVE, never a silent text-only pass
#   TR8 the runner refuses --trace with --turns (rc 2), never ignores it
#   TR13 ablation_calibrate.sh (direct claude -p measurement path) pins MCP in every arm
#   TR9 revert probe: a scorer without the «said, not done → FAIL» line turns TR2 red
#   TR14 arms equal in tools/MCP but one loaded an extra plugin → INVALID-COMPARISON (2026-11-15 nightly shape)
#   TR15 control: arms with the same plugin set stay comparable (PASS), also reordered or with a duplicate entry
#   TR16 same plugin, different version → INVALID-COMPARISON (an auto-update moved a version mid-run)
#   TR17 one arm's init carries a plugin list (or an empty one), the other's none → INVALID-COMPARISON (UNKNOWN ≠ «no plugins»)
#   TR18 revert probe: an inventory without plugins turns TR14 back to comparable → TR14 would be red
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="${LIVE_EVAL_LIB_DIR:-$HERE}"
pass=0; fail=0; ok(){ pass=$((pass+1)); echo "  ✅ $1"; }; bad(){ fail=$((fail+1)); echo "  ❌ $1"; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

python3 "$HERE/live_eval_trace.py" extract /dev/null /dev/null /dev/null >/dev/null 2>&1; [ $? -eq 3 ] \
  && ok "TR0 the shipped file runs by its own path (empty stream → rc 3)" || bad "TR0 direct run"
if [ -n "${LIVE_TRACE_REAL:-}" ]; then
  r=$(python3 "$HERE/live_eval_trace.py" extract "$LIVE_TRACE_REAL" "$T/real.txt" "$T/real.tools" ; echo "rc=$?")
  grep -q '^tools=.*Read' "$T/real.tools" && [ -s "$T/real.txt" ] && grep -q '| plugins=\[' "$T/real.tools" \
    && echo "  ℹ️  TR0b real stream shape read, plugin list included ($r)" \
    || echo "  ⚠️  TR0b real stream NOT read ($r) — fixtures may not match the real shape"
else
  echo "  ℹ️  TR0b real-shape re-check UNMEASURED this run (LIVE_TRACE_REAL unset) — not a pass"
fi

# fixture writer: ev <file> <tools csv> <mcp csv> <result text> [ToolName=path ...]
cat > "$T/mk.py" <<'PY'
import json, sys
f, tools, mcp, res = sys.argv[1:5]
import os
ev = [{"type": "system", "subtype": "hook_started", "hook_name": "SessionStart"}]
if tools != "NOINIT":
    init = {"type": "system", "subtype": "init", "tools": [t for t in tools.split(",") if t],
            "mcp_servers": [{"name": m.split(":")[0], "status": (m.split(":") + ["connected"])[1]} for m in mcp.split(",") if m]}
    # MK_PLUGINS: unset/empty = no plugins key (older shape); "-" = empty list; else csv of
    # source[=version] — the real init carries {name, path, source, version?} per plugin.
    pl = os.environ.get("MK_PLUGINS", "")
    if pl:
        init["plugins"] = [] if pl == "-" else [
            dict({"name": x.split("=")[0].split("@")[0], "path": "/fixture", "source": x.split("=")[0]},
                 **({"version": x.split("=")[1]} if "=" in x else {})) for x in pl.split(",")]
    ev.append(init)
# call forms: Read=path · ERR:Read=path (tool_result is_error) · SUB:Read=path (inside a subagent)
for n, c in enumerate(sys.argv[5:]):
    flag = ""
    if ":" in c.split("=", 1)[0]:
        flag, c = c.split(":", 1)
    name, p = c.split("=", 1)
    key = "pattern" if name == "Glob" else "file_path" if name == "Read" else "path"
    a = {"type": "assistant", "message": {"content": [{"type": "tool_use", "id": "t%d" % n, "name": name, "input": {key: p}}]}}
    if flag == "SUB":
        a["parent_tool_use_id"] = "task0"
    ev.append(a)
    ev.append({"type": "user", "message": {"content": [{"type": "tool_result", "tool_use_id": "t%d" % n, "is_error": flag == "ERR"}]}})
ev.append({"type": "result", "subtype": "success", "result": res})
open(f, "w").write("".join(json.dumps(e, ensure_ascii=False) + "\n" for e in ev))
PY
mk(){ python3 "$T/mk.py" "$@"; }

mk "$T/a.jsonl" "Read,Grep,Glob" "" "CATALOG says x" Read=CATALOG.md
python3 "$HERE/live_eval_trace.py" extract "$T/a.jsonl" "$T/a.txt" "$T/a.tools"; xrc=$?
printf '%s\n' '{"type":"system","subtype":"init","tools":["Read"]}' > "$T/nores.jsonl"
python3 "$HERE/live_eval_trace.py" extract "$T/nores.jsonl" "$T/n.txt" "$T/n.tools"; nrc=$?
[ $xrc -eq 0 ] && [ "$(cat "$T/a.txt")" = "CATALOG says x" ] && grep -qx 'tools=Glob,Grep,Read | mcp= | plugins=UNKNOWN' "$T/a.tools" \
  && [ $nrc -eq 3 ] && [ ! -s "$T/n.txt" ] \
  && ok "TR1 extract writes result + inventory; no result event → rc 3, empty text" \
  || bad "TR1 xrc=$xrc nrc=$nrc txt=$(cat "$T/a.txt") tools=$(cat "$T/a.tools")"

# run_root builder: build <root> <probe> <reps> <primary-spec|-> <control-spec|-> ; spec = "tools|mcp|text|calls..."
build(){ local root="$1" pid="$2" reps="$3" ps="$4" cs="$5" i arm spec
  mkdir -p "$root/$pid"
  for i in $(seq 1 "$reps"); do
    for arm in primary control; do
      [ $arm = primary ] && spec="$ps" || spec="$cs"
      IFS='|' read -r tl mc tx calls pl <<<"$spec"
      # 5th field = plugins for rep 1 only when it starts with «r1:» (a set that changed in one rep)
      case "$pl" in r1:*) if [ "$i" -eq 1 ]; then pl="${pl#r1:}"; else pl="${PL_BASE:-}"; fi ;; esac
      printf '%s' "$tx" > "$root/$pid/${arm}_r$i.txt"
      if [ "$tl" != "-" ]; then set -f; MK_PLUGINS="$pl" mk "$root/$pid/${arm}_r$i.stream.jsonl" "$tl" "$mc" "$tx" $calls; set +f; fi
    done
  done; }
score(){ python3 - "$LIB" "$1" "$2" "$3" "${4:-}" <<'PY'
import sys, json; sys.path.insert(0, sys.argv[1]); import probe_live_eval_lib as L
root, pid, behave, pol = sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5] or 'present'
spec = {'id': pid, 'polarity': pol, 'expect_re': 'CATALOG'}
if behave: spec['behave'] = behave
r = L.score_run([spec], root, [pid], 0.8, 'sonnet', reps=3)
row = r['rows'][0]
print(row['verdict'], row['scored_by'], r['overall'], r['pass_rate'], r['mention_only_pass'], r['behaviour_backed'], '|', row['reason'])
PY
}
RT='Read,Grep,Glob'
build "$T/did" P 3 "$RT||CATALOG has it|Read=CATALOG.md Read=x.md" "$RT||오늘 맑아|"
build "$T/said" P 3 "$RT||I will read CATALOG.md first|" "$RT||오늘 맑아|"
d=$(score "$T/did" P 'first_read=CATALOG\.md'); s=$(score "$T/said" P 'first_read=CATALOG\.md')
[[ "$d" == "PASS BEHAVIOUR PASS 1.0 0 1 "* ]] && [[ "$s" == "FAIL BEHAVIOUR "* ]] \
  && ok "TR2 pair: did → PASS/BEHAVIOUR · said-only → FAIL (same text pattern hits both)" || bad "TR2 did=[$d] said=[$s]"

build "$T/order" P 3 "$RT||CATALOG has it|Grep=knowledge Read=CATALOG.md" "$RT||오늘 맑아|"
o=$(score "$T/order" P 'first_read=CATALOG\.md'); o2=$(score "$T/order" P 'read=CATALOG\.md')
[[ "$o" == FAIL* ]] && [[ "$o2" == PASS* ]] && ok "TR3 first_read reads order (second → FAIL; read= → PASS)" || bad "TR3 first=[$o] any=[$o2]"

build "$T/ctl" P 3 "$RT||CATALOG has it|Read=CATALOG.md" "$RT||오늘 맑아|Read=CATALOG.md"
c=$(score "$T/ctl" P 'read=CATALOG\.md')
[[ "$c" == "UNCALIBRATED "* ]] && ok "TR4 control does the action → UNCALIBRATED" || bad "TR4 [$c]"

build "$T/old" P 3 "-||CATALOG has it|" "-||오늘 맑아|"
m=$(score "$T/old" P 'read=CATALOG\.md'); m0=$(score "$T/old" P '')
[[ "$m" == "PASS MENTION-ONLY PASS 1.0 1 0 "* ]] && [[ "$m0" == "PASS MENTION-ONLY "* ]] \
  && ok "TR5 no trace → text verdict kept, labelled MENTION-ONLY, counted as mention-only" || bad "TR5 [$m] [$m0]"

build "$T/inv" P 3 "Read,Grep,Glob|drive,wiki|CATALOG has it|Read=CATALOG.md" "$RT||오늘 맑아|"
v=$(score "$T/inv" P 'read=CATALOG\.md')
[[ "$v" == "INVALID-COMPARISON MENTION-ONLY INVALID-COMPARISON None "* || "$v" == "INVALID-COMPARISON BEHAVIOUR INVALID-COMPARISON None "* ]] && [[ "$v" == *"different tool/MCP/plugin lists"* ]] \
  && ok "TR6 arms with different tool/MCP lists → INVALID-COMPARISON, no pass_rate" || bad "TR6 [$v]"

b=$(score "$T/did" P 'reads=CATALOG')
[[ "$b" == "UNCALIBRATED "* ]] && [[ "$b" == *BAD-BEHAVE* ]] && ok "TR7 malformed behave: → UNCALIBRATED/BAD-BEHAVE" || bad "TR7 [$b]"

tout=$(bash "$HERE/sim_isolated_run.sh" --arm primary --prompt x --trace --turns 'a' 2>&1); trc=$?
[ $trc -eq 2 ] && [[ "$tout" == *"--trace is single-shot only"* ]] && ok "TR8 runner refuses --trace with --turns (rc 2)" || bad "TR8 rc=$trc $tout"

mkdir -p "$T/mut"; cp "$LIB/live_eval_trace.py" "$T/mut/"
sed 's/^\( *\)v = FAIL              # said it, did not do it$/\1pass/' "$LIB/probe_live_eval_lib.py" > "$T/mut/probe_live_eval_lib.py"
if grep -q 'said it, did not do it' "$T/mut/probe_live_eval_lib.py"; then bad "TR9 mutation did not apply (instrument error, not a pass)"
else ms=$(LIB="$T/mut" score "$T/said" P 'first_read=CATALOG\.md')
  [[ "$ms" == PASS* ]] && ok "TR9 revert probe: without the line, said-only scores PASS → TR2 would be red" || bad "TR9 mutant still [$ms]"; fi

build "$T/deny" P 3 "$RT||CATALOG has it|ERR:Read=CATALOG.md" "$RT||오늘 맑아|"
build "$T/sub" P 3 "$RT||CATALOG has it|SUB:Read=CATALOG.md Read=x.md" "$RT||오늘 맑아|"
build "$T/grp" P 3 "$RT||CATALOG has it|Grep=. Glob=CATALOG.md" "$RT||오늘 맑아|"
dn=$(score "$T/deny" P 'read=CATALOG\.md'); sb=$(score "$T/sub" P 'read=CATALOG\.md'); gp=$(score "$T/grp" P 'read=CATALOG\.md')
[[ "$dn" == FAIL* ]] && [[ "$sb" == FAIL* ]] && [[ "$gp" == FAIL* ]] \
  && ok "TR10 a failed Read, a subagent's Read, and a Glob/Grep-pattern hit are not «read» (codex R1)" || bad "TR10 deny=[$dn] sub=[$sb] glob=[$gp]"
build "$T/noinit" P 3 "NOINIT||CATALOG has it|Read=CATALOG.md" "$RT||오늘 맑아|"
build "$T/mstat" P 3 "$RT|drive:connected|CATALOG has it|Read=CATALOG.md" "$RT|drive:failed|오늘 맑아|"
ni=$(score "$T/noinit" P 'read=CATALOG\.md'); ms2=$(score "$T/mstat" P 'read=CATALOG\.md')
[[ "$ni" == INVALID-COMPARISON* ]] && [[ "$ms2" == INVALID-COMPARISON* ]] \
  && ok "TR11 one arm without init, or MCP connected vs failed → INVALID-COMPARISON (codex R1)" || bad "TR11 noinit=[$ni] status=[$ms2]"
build "$T/half" P 3 "$RT||CATALOG has it|Read=CATALOG.md" "-||오늘 맑아|"
hf=$(score "$T/half" P 'read=CATALOG\.md')
[[ "$hf" == UNCALIBRATED* ]] && [[ "$hf" == *TRACE-INCOMPLETE* ]] && ok "TR12 a control arm with no trace while primary has one → UNCALIBRATED, not text-only PASS" || bad "TR12 [$hf]"

# TR13 the direct `claude -p` measurement path (not via sim_isolated_run) pins MCP in all three arms.
# Static check of the argv only — a pin is not proof; the recorded tool list (TR6/TR11) is the defence.
npin=$(grep -cE '^  (allowlist|denylist|baseline)\) +FLAGS=\(.*--strict-mcp-config' "$HERE/ablation_calibrate.sh")
[ "$npin" -eq 3 ] && ok "TR13 ablation_calibrate.sh pins MCP (--strict-mcp-config) in all 3 arms" || bad "TR13 pinned arms=$npin/3"

# ── plugins (2026-11-15): the nightly's G-GREET-01 / G-TRIG-05 had tools and MCP equal in every arm and
# one rep (primary_r1) with one extra builtin plugin; the scorer reported «1 distinct». Names below are
# synthetic — the shape (source@version, builtin with no version) is the real init's.
PB='fx-core@hub=3.42.0,fx-lsp@official=1.0.0,fx-telemetry@builtin'
PL_BASE="$PB" build "$T/plg" P 3 "$RT||CATALOG has it|Read=CATALOG.md|r1:$PB,fx-chart@builtin" "$RT||오늘 맑아||$PB"
pg=$(score "$T/plg" P 'read=CATALOG\.md')
[[ "$pg" == INVALID-COMPARISON* ]] && [[ "$pg" == *"saw 2 different"*"plugin lists"* ]] && [[ "$pg" != *UNKNOWN* ]] \
  && ok "TR14 one rep with an extra plugin (tools/MCP equal) → INVALID-COMPARISON" || bad "TR14 [$pg]"
build "$T/plq" P 3 "$RT||CATALOG has it|Read=CATALOG.md|$PB" "$RT||오늘 맑아||$PB"
pq=$(score "$T/plq" P 'read=CATALOG\.md')
PR='fx-telemetry@builtin,fx-lsp@official=1.0.0,fx-core@hub=3.42.0,fx-lsp@official=1.0.0'   # same set: reordered + a duplicate
build "$T/plr" P 3 "$RT||CATALOG has it|Read=CATALOG.md|$PB" "$RT||오늘 맑아||$PR"
pr=$(score "$T/plr" P 'read=CATALOG\.md')
[[ "$pq" == "PASS BEHAVIOUR PASS 1.0 "* ]] && [[ "$pr" == "PASS BEHAVIOUR PASS 1.0 "* ]] && ok "TR15 control: same plugin set in every arm → comparable, PASS" || bad "TR15 same=[$pq] reordered+dup=[$pr]"
build "$T/plv" P 3 "$RT||CATALOG has it|Read=CATALOG.md|${PB/3.42.0/3.43.0}" "$RT||오늘 맑아||$PB"
pv=$(score "$T/plv" P 'read=CATALOG\.md')
[[ "$pv" == INVALID-COMPARISON* ]] && [[ "$pv" == *"saw 2 different"* ]] && [[ "$pv" != *UNKNOWN* ]] && ok "TR16 same plugin, different version → INVALID-COMPARISON" || bad "TR16 [$pv]"
build "$T/plu" P 3 "$RT||CATALOG has it|Read=CATALOG.md|$PB" "$RT||오늘 맑아|"
pu=$(score "$T/plu" P 'read=CATALOG\.md')
build "$T/ple" P 3 "$RT||CATALOG has it|Read=CATALOG.md|-" "$RT||오늘 맑아|"
pe=$(score "$T/ple" P 'read=CATALOG\.md')
[[ "$pu" == INVALID-COMPARISON* ]] && [[ "$pe" == INVALID-COMPARISON* ]] && ok "TR17 one arm with a plugin list, one without → INVALID-COMPARISON (UNKNOWN, not 0)" || bad "TR17 list=[$pu] empty-list=[$pe]"
mkdir -p "$T/mut2"; cp "$LIB/probe_live_eval_lib.py" "$T/mut2/"
sed "s/^\( *\)plug = 'UNKNOWN' if trace.get('plugins') is None else ','.join(trace\['plugins'\])$/\1plug = ''/" \
  "$LIB/live_eval_trace.py" > "$T/mut2/live_eval_trace.py"
if grep -q "trace.get('plugins') is None" "$T/mut2/live_eval_trace.py"; then bad "TR18 mutation did not apply (instrument error, not a pass)"
else mp=$(LIB="$T/mut2" score "$T/plg" P 'read=CATALOG\.md')
  [[ "$mp" == "PASS "* ]] && ok "TR18 revert probe: inventory without plugins → TR14's pair scores PASS (TR14 would be red)" || bad "TR18 mutant still [$mp]"; fi

# ── behaviour profile (2026-11-17, record only): top-level calls in explore · edit · test-run · other.
# mk2 <file> <json list of [name, input, flag]> [noresult] — flag "SUB" = inside a subagent
cat > "$T/mk2.py" <<'PY'
import json, sys
f, calls = sys.argv[1], json.loads(sys.argv[2])
ev = [{"type": "system", "subtype": "init", "tools": ["Read", "Bash"], "mcp_servers": []}]
for n, (name, inp, flag) in enumerate(calls):
    a = {"type": "assistant", "message": {"content": [{"type": "tool_use", "id": "b%d" % n, "name": name, "input": inp}]}}
    if flag == "SUB":
        a["parent_tool_use_id"] = "task0"
    ev.append(a)
    ev.append({"type": "user", "message": {"content": [{"type": "tool_result", "tool_use_id": "b%d" % n}]}})
if len(sys.argv) < 4:
    ev.append({"type": "result", "subtype": "success", "result": "done"})
open(f, "w").write("".join(json.dumps(e) + "\n" for e in ev))
PY
B='[["Read",{"file_path":"a.md"},""],["Edit",{"file_path":"a.md"},""],["Write",{"file_path":"b.md"},""],
["Bash",{"command":"pytest -q tests/"},""],["Bash",{"command":"bash scripts/test_x_lanes.sh"},""],
["Bash",{"command":"echo hi > out.txt"},""],["Bash",{"command":"sed -i s/a/b/ f.txt"},""],
["Bash",{"command":"cd /x && git status --short"},""],["Bash",{"command":"ls tracks 2>/dev/null"},""],
["Bash",{"command":"cat f 2>&1 | head -3"},""],["Bash",{"command":"python3 build.py"},""],["Agent",{"prompt":"x"},""],
["Edit",{"file_path":"c.md"},"SUB"],["Bash",{"command":"pytest"},"SUB"]]'
python3 "$T/mk2.py" "$T/bp.jsonl" "$B"
bp=$(python3 "$HERE/live_eval_trace.py" profile "$T/bp.jsonl"; echo "rc=$?")
[ "$bp" = "explore=4 edit=4 test-run=2 other=2 total=12
rc=0" ] && ok "TR19 profile bins: one known call per rule; redirects to /dev/null and 2>&1 stay explore; subagent calls not counted" \
  || bad "TR19 [$bp]"
python3 "$T/mk2.py" "$T/bpn.jsonl" '[["Read",{"file_path":"a.md"},""]]' noresult
bn=$(python3 "$HERE/live_eval_trace.py" profile "$T/bpn.jsonl"); bu=$(python3 "$HERE/live_eval_trace.py" profile "$T/absent.jsonl"; echo "rc=$?")
[ "$bn" = "explore=1 edit=0 test-run=0 other=0 total=1 result=MISSING (counts are a lower bound)" ] \
  && [ "$bu" = "trace=UNREADABLE
rc=3" ] && ok "TR20 no result event → counts marked a lower bound; unreadable stream → trace=UNREADABLE rc 3, never 0" \
  || bad "TR20 noresult=[$bn] absent=[$bu]"
# TR21 revert probe. Three conditions, each its own failure: the original carries the exclusion, the
# mutation removed it, and the mutant RAN (rc 0) — so «counts changed» cannot come from a crash or a no-op.
mkdir -p "$T/mut3"; sed 's|(?!/dev/null\\b)||' "$LIB/live_eval_trace.py" > "$T/mut3/live_eval_trace.py"
if ! grep -q '(?!/dev/null' "$LIB/live_eval_trace.py"; then bad "TR21 the original has no /dev/null exclusion to revert"
elif grep -q '(?!/dev/null' "$T/mut3/live_eval_trace.py"; then bad "TR21 mutation did not apply (instrument error, not a pass)"
else mb=$(python3 "$T/mut3/live_eval_trace.py" profile "$T/bp.jsonl"); mrc=$?
  [ $mrc -eq 0 ] && [ "$mb" = "explore=3 edit=5 test-run=2 other=2 total=12" ] \
    && ok "TR21 revert probe: without the /dev/null exclusion, 2>/dev/null reads as an edit → TR19 would be red" \
    || bad "TR21 mutant rc=$mrc [$mb]"; fi
# TR22 (codex R1): naming a test file as data is not a test run; sed -Ei / --in-place are edits;
# a wrapper (timeout N / env) does not hide the runner.
B2='[["Bash",{"command":"cat tests/test_example.py"},""],["Bash",{"command":"grep -n x scripts/test_y_lanes.sh"},""],
["Bash",{"command":"sed -Ei s/a/b/ f"},""],["Bash",{"command":"sed --in-place s/a/b/ f"},""],["Bash",{"command":"sed -n 1p f"},""],
["Bash",{"command":"timeout 60 bash scripts/selfcheck.sh"},""],["Bash",{"command":"env A=1 python3 -m pytest -q"},""],
["Bash",{"command":"./scripts/test_z.sh"},""],["Bash",{"command":"npm run test"},""]]'
python3 "$T/mk2.py" "$T/bp2.jsonl" "$B2"
b2=$(python3 "$HERE/live_eval_trace.py" profile "$T/bp2.jsonl")
[ "$b2" = "explore=3 edit=2 test-run=4 other=0 total=9" ] \
  && ok "TR22 reading a test file stays explore; sed -Ei/--in-place are edits; timeout/env wrappers keep the runner visible" \
  || bad "TR22 [$b2]"

[ $pass -eq 23 ] || bad "lane count $pass != 23 — a case did not run"
echo "live_eval_trace lanes: $pass passed, $fail failed"; [ $fail -eq 0 ]

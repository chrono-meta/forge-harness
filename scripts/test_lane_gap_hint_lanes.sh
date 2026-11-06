#!/usr/bin/env bash
# test_lane_gap_hint_lanes.sh — scripts/lane_gap_hint.py (UserPromptSubmit, advisory). G1 is the positive control: a turn
# that edited code and ran nothing produces the line; every other lane is a turn that must stay silent, plus exit 0 always.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
H="$HERE/lane_gap_hint.py"
[ -f "$H" ] || { echo "HARNESS-ERROR: $H missing"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); echo "  ✅ $1"; }
bad() { fail=$((fail+1)); echo "  ❌ $1"; }
# transcript <name> <tool lines as name|arg ...> — one real user prompt, then the tool calls of that turn
mk() {
  local f="$W/$1.jsonl"; shift
  python3 - "$f" "$@" <<'PY'
import json, sys
f, specs = sys.argv[1], sys.argv[2:]
rows = [{"type": "user", "message": {"content": "earlier prompt"}},
        {"type": "assistant", "message": {"content": [{"type": "tool_use", "id": "old", "name": "Edit", "input": {"file_path": "/r/scripts/old.sh"}}]}},
        {"type": "user", "message": {"content": [{"type": "tool_result", "tool_use_id": "old"}]}},
        {"type": "user", "message": {"content": [{"type": "text", "text": "do the thing"}]}}]
for i, s in enumerate(specs):
    name, arg = s.split("|", 1)
    if name == "ImgPrompt":      # an image-only prompt typed by the person: a turn boundary
        rows.append({"type": "user", "message": {"content": [{"type": "image", "source": {}}]}}); continue
    side = name.startswith("Side")   # a subagent's line
    err = name.startswith("Fail")    # a tool call whose result is an error
    name = name.replace("Side", "").replace("Fail", "") or "Bash"
    inp = {"command": arg} if name == "Bash" else ({"notebook_path": arg} if name == "NotebookEdit" else {"file_path": arg})
    a = {"type": "assistant", "message": {"content": [{"type": "tool_use", "id": f"t{i}", "name": name, "input": inp}]}}
    r = {"type": "user", "message": {"content": [{"type": "tool_result", "tool_use_id": f"t{i}", "is_error": err}]}}
    if side:
        a["isSidechain"] = r["isSidechain"] = True
    rows += [a, r]
open(f, "w").write("\n".join(json.dumps(r) for r in rows) + "\n")
PY
}
run() { OUT=$(printf '{"transcript_path":"%s"}' "$1" | env ${2:-} python3 "$H" 2>&1); RC=$?; }
mk gap "Edit|/r/scripts/a.sh" "Write|/r/src/b.py" "Bash|git status"
run "$W/gap.jsonl"
[ "$RC" = 0 ] && printf '%s' "$OUT" | grep -q '코드 파일 2개(a.sh, b.py)' && ok "G1 control: code edited, nothing ran → one line naming the files" || bad "G1 (rc=$RC · $OUT)"
for spec in "bash scripts/test_x_lanes.sh" "python3 -m pytest -q tests/" "node --test" "npm test" "bash scripts/selfcheck.sh"; do
  mk ran "Edit|/r/scripts/a.sh" "Bash|$spec"; run "$W/ran.jsonl"
  [ "$RC" = 0 ] && [ -z "$OUT" ] || { bad "G2 a run ($spec) silences it (rc=$RC · $OUT)"; continue; }
done
[ "$fail" = 0 ] && ok "G2 any test/lane run in the same turn silences it (test_*_lanes · pytest · node --test · npm test · selfcheck)"
mk prose "Edit|/r/README.md" "Write|/r/docs/x.md"; run "$W/prose.jsonl"
[ -z "$OUT" ] && ok "G3 prose-only edits stay silent" || bad "G3 ($OUT)"
mk none "Bash|ls"; run "$W/none.jsonl"
[ -z "$OUT" ] && ok "G4 a turn with no edit stays silent — the older turn's edit (old.sh) is not counted" || bad "G4 ($OUT)"
run "$W/missing.jsonl"; R1="$RC$OUT"; OUT2=$(printf '{"transcript_path":"rel/x.jsonl"}' | python3 "$H" 2>&1); R2="$?$OUT2"; OUT3=$(printf 'not json' | python3 "$H" 2>&1); R3="$?$OUT3"
[ "$R1" = 0 ] && [ "$R2" = 0 ] && [ "$R3" = 0 ] && ok "G5 unreadable/relative/garbage input: exit 0, no output" || bad "G5 ($R1 | $R2 | $R3)"
run "$W/gap.jsonl" FH_LANE_GAP_HINT=0
[ "$RC" = 0 ] && [ -z "$OUT" ] && ok "G6 FH_LANE_GAP_HINT=0 turns it off (control: G1 speaks on the same file)" || bad "G6 ($OUT)"
# codex R1 (2026-11-06) — each was a false silence or a false alarm
say() { [ -n "$OUT" ]; }
mk men "Edit|/r/scripts/a.sh" "Bash|git diff scripts/test_x_lanes.sh" "Bash|echo pytest"; run "$W/men.jsonl"
say && ok "G7 a command that only MENTIONS a test (git diff test_x · echo pytest) does not silence it" || bad "G7 silent"
mk q "Edit|/r/src/a.py" "Bash|cd /r && \"pytest\" -q"; run "$W/q.jsonl"
! say && ok "G8 a quoted program name still counts as a run («\"pytest\" -q» after cd)" || bad "G8 ($OUT)"
mk side "Edit|/r/scripts/a.sh" "SideBash|bash scripts/test_y_lanes.sh"; run "$W/side.jsonl"
say && ok "G9 a subagent's (sidechain) test run does not count for this session" || bad "G9 silent"
mk img "Bash|bash scripts/test_z_lanes.sh" "ImgPrompt|" "Edit|/r/scripts/a.sh"; run "$W/img.jsonl"
say && ok "G10 an image-only prompt is a turn boundary — the earlier turn's test run does not silence the new edit" || bad "G10 silent"
mk failed "FailEdit|/r/scripts/a.sh"; run "$W/failed.jsonl"
! say && ok "G11 a failed edit changed nothing → silent" || bad "G11 ($OUT)"
mk nb "NotebookEdit|/r/analysis.ipynb"; run "$W/nb.jsonl"
say && ok "G12 a notebook edit counts" || bad "G12 silent"
python3 - "$W/gap.jsonl" "$W/cut.jsonl" <<'PY'
import sys
rows = open(sys.argv[1]).read().splitlines()
open(sys.argv[2], "w").write("\n".join(r for r in rows if '"do the thing"' not in r and '"earlier prompt"' not in r) + "\n")
PY
run "$W/cut.jsonl"
! say && ok "G13 a transcript tail with no prompt in it (turn start cut off) → no statement, silent" || bad "G13 ($OUT)"
SNIP="$HERE/../templates/settings.LaneGap.snippet.json"
CMD=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['project_settings_json']['hooks']['UserPromptSubmit'][0]['hooks'][0]['command'])" "$SNIP")
O1=$(cd "$W" && env CLAUDE_PROJECT_DIR="$W" FH_LANE_GAP_HINT=0 sh -c "$CMD" 2>&1 </dev/null); O2=$(cd "$W" && env CLAUDE_PROJECT_DIR="$W" sh -c "$CMD" 2>&1 </dev/null)
[ -z "$O1" ] && printf '%s' "$O2" | grep -q 'lane-gap' && ok "G14 the wrapper honours FH_LANE_GAP_HINT=0 even when the script is missing (control: without it, it warns)" || bad "G14 (off=«$O1» on=«$O2»)"
mk cm "Edit|/r/scripts/a.sh" "Bash|echo done # note; pytest -q" "Bash|cat <<EOF
pytest -q
EOF"; run "$W/cm.jsonl"
say && ok "G15 a test named inside a comment or a heredoc body is text, not a run (codex R2)" || bad "G15 silent"
[ $((pass+fail)) -eq 15 ] || { echo "HARNESS-ERROR: counted $((pass+fail)) lanes, expected 15"; exit 2; }
echo "lane_gap_hint lanes: $pass passed · $fail failed"
[ "$fail" -eq 0 ]

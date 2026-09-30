#!/usr/bin/env bash
# test_hook_templates_copilot_compat_lanes.sh — no shipped hook template may carry `"matcher": ""`.
#
# WHY (measured 2026-10-01, operator machine, GitHub Copilot CLI v1.0.78): opening this repo with
# `gh copilot` printed
#   Repository settings file '.claude/settings.json' could not be loaded:
#   Settings config error: hooks.preCompact[0].matcher: matcher cannot be empty
# and Copilot then ignored the WHOLE settings file — not just that hook. The cause was the empty
# matcher our own templates ship. In Claude Code the empty string is not needed at all: the hooks
# doc («Matcher patterns», code.claude.com/docs/en/hooks) lists `"*"`, `""`, or omitted → «Match
# all — fires on every occurrence of the event». So OMITTING the key means the same thing to Claude
# Code and loads in Copilot. That is the whole fix; these lanes keep it from growing back.
#
# SUBJECTS
#   S1  every tracked *.json under templates/ plugins/ knowledge/ docs/ .claude-plugin/ hooks/ —
#       parsed, walked structurally (a dict carrying `matcher == ""`).
#   S2  every ```json / ```jsonc fenced block in tracked *.md under the same dirs + repo-root *.md —
#       these are what a user copies into their settings by hand. Prose mentioning the defect sits
#       outside fences and is not scanned (it has to be able to name the thing it forbids).
#   S3  what install-wizard WRITES. Both python merge blocks are EXTRACTED from the shipped
#       SKILL_detail.md at run time (never retyped — a retyped copy would keep validating the old
#       code) and executed against a fixture that already holds a user group with `"matcher": ""`.
#       The written file must hold no empty matcher and the user's hook must survive.
#   S4  hook_drift_check.sh must NOT call an old install STALE only because it spells match-all as
#       `""` while the template now omits the key — same meaning, and a false STALE is noise that
#       teaches people to ignore the checker. A different real matcher must still be STALE (control).
#
# CALIBRATION: the scanner runs on a known-positive (empty matcher → flagged) and a known-negative
# (omitted → clean) in the same run, and on a revert probe (a real shipped template with the key put
# back → flagged). A scanner that flags nothing on the positive is a dead instrument → exit 1.
# Exit: 0 = all lanes pass · 1 = a lane failed or the instrument/extraction broke.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WIZ="$ROOT/plugins/fh-meta/skills/install-wizard/SKILL_detail.md"
DRIFT="$ROOT/scripts/hook_drift_check.sh"
PY="$(command -v python3 || true)"
[ -n "$PY" ] || { echo "❌ HARNESS-ERROR: python3 not found — lanes NOT run (not a pass)"; exit 1; }

TMPROOT=$(mktemp -d "${TMPDIR:-/tmp}/fh_copilot_compat.XXXXXX") \
  || { echo "❌ HARNESS-ERROR: mktemp -d failed — lanes NOT run (not a pass)"; exit 1; }
[ -n "$TMPROOT" ] && [ -d "$TMPROOT" ] || { echo "❌ HARNESS-ERROR: empty TMPROOT — lanes NOT run"; exit 1; }
trap 'rm -rf "$TMPROOT"' EXIT
FAILED=0; PASSED=0
_pass() { echo "✅ $1"; PASSED=$((PASSED+1)); }
_fail() { echo "❌ $1"; FAILED=1; }
_eq()   { if [ "$2" = "$3" ]; then _pass "$1 ($2)"; else _fail "$1 — got [$2], expected [$3]"; fi; }

# ── the scanner (S1+S2) ─────────────────────────────────────────────────────────
# Args: <root> <file>...   Prints one "HIT <file>: <where>" per empty matcher, "ERR <file>: …" for an
# unreadable JSON file, and a final "SCANNED json=N md_blocks=M". Exit 0 always — callers count.
SCAN="$TMPROOT/scan.py"
cat > "$SCAN" <<'PYEOF'
import json, os, re, sys
root, files = sys.argv[1], sys.argv[2:]
EMPTY = re.compile(r'"matcher"\s*:\s*""')
FENCE = re.compile(r'^\s*```\s*(json|jsonc|json5)\b.*$', re.I)   # ```JSON, ```json title=x
nj = nb = 0
def walk(o, path):
    if isinstance(o, dict):
        if o.get("matcher") == "":
            yield path or "$"
        for k, v in o.items():
            yield from walk(v, f"{path}.{k}")
    elif isinstance(o, list):
        for i, v in enumerate(o):
            yield from walk(v, f"{path}[{i}]")
for rel in files:
    p = os.path.join(root, rel)
    if not os.path.isfile(p):
        continue
    if rel.endswith(".json"):
        nj += 1
        try:
            d = json.load(open(p, encoding="utf-8"))
        except Exception as e:
            print(f"ERR {rel}: unparsable ({e.__class__.__name__})"); continue
        for where in walk(d, ""):
            print(f"HIT {rel}: {where}")
    elif rel.endswith((".jsonc", ".json5")):   # comments allowed → not json.load-able; line scan
        nj += 1
        for n, line in enumerate(open(p, encoding="utf-8", errors="replace"), 1):
            if EMPTY.search(line):
                print(f"HIT {rel}:{n}")
    elif rel.endswith(".md"):
        inside, start = False, 0
        for n, line in enumerate(open(p, encoding="utf-8", errors="replace"), 1):
            if not inside and FENCE.match(line):
                inside, start = True, n; nb += 1; continue
            if inside and line.strip().startswith("```"):
                inside = False; continue
            if inside and EMPTY.search(line):
                print(f"HIT {rel}:{n} (json block from line {start})")
print(f"SCANNED json={nj} md_blocks={nb}")
PYEOF

_shipped_files() {  # tracked files if this is a git checkout, else a find over the same dirs
  # git only when ROOT IS the work-tree top. An npm-installed copy under a consumer's repo
  # (node_modules, usually gitignored) is «inside a work tree» but ls-files there lists nothing.
  local top; top=$(git -C "$ROOT" rev-parse --show-toplevel 2>/dev/null || true)
  if [ -n "$top" ] && [ "$(cd "$top" && pwd -P)" = "$(cd "$ROOT" && pwd -P)" ]; then
    git -C "$ROOT" ls-files -- templates plugins knowledge docs .claude-plugin hooks '*.md' \
      | /usr/bin/grep -E '\.(json|jsonc|json5|md)$' | /usr/bin/grep -vE '^tracks/'
  else
    ( cd "$ROOT" && find templates plugins knowledge docs .claude-plugin hooks -type f \
        \( -name '*.json' -o -name '*.jsonc' -o -name '*.json5' -o -name '*.md' \) 2>/dev/null; ls *.md 2>/dev/null )
  fi
}

echo "══ calibration: the scanner separates a known pair ══"
CAL="$TMPROOT/cal"; mkdir -p "$CAL"
printf '%s\n' '{"hooks":{"PreCompact":[{"matcher":"","hooks":[{"type":"command","command":"x"}]}]}}' > "$CAL/pos.json"
printf '%s\n' '{"hooks":{"PreCompact":[{"hooks":[{"type":"command","command":"x"}]}]}}' > "$CAL/neg.json"
printf '%s\n' 'Prose may say `"matcher": ""` is forbidden.' '' '```json' '{ "Stop": [ { "matcher": "", "hooks": [] } ] }' '```' > "$CAL/pos.md"
printf '%s\n' 'Prose may say `"matcher": ""` is forbidden.' '' '```json' '{ "Stop": [ { "hooks": [] } ] }' '```' > "$CAL/neg.md"
printf '%s\n' '```JSON title=settings' '{ "Stop": [ { "matcher": "", "hooks": [] } ] }' '```' > "$CAL/pos_upper.md"
printf '%s\n' '// comment' '{ "Stop": [ { "matcher" : "", "hooks": [] } ] }' > "$CAL/pos.jsonc"
_hits() { "$PY" "$SCAN" "$1" "${@:2}" | /usr/bin/grep -c '^HIT ' ; }
_eq "CAL-1 known-positive json (empty matcher) → flagged"      "$(_hits "$CAL" pos.json)" 1
_eq "CAL-2 known-negative json (matcher omitted) → clean"      "$(_hits "$CAL" neg.json)" 0
_eq "CAL-3 known-positive md fenced json block → flagged"      "$(_hits "$CAL" pos.md)" 1
_eq "CAL-4 known-negative md (prose mention only) → clean"     "$(_hits "$CAL" neg.md)" 0
_eq "CAL-5 fence variant \`\`\`JSON title=… → flagged"            "$(_hits "$CAL" pos_upper.md)" 1
_eq "CAL-6 .jsonc (comments, not json.load-able) → flagged"    "$(_hits "$CAL" pos.jsonc)" 1

echo
echo "══ S1+S2: shipped templates, snippets and copy-paste docs ══"
LIST="$TMPROOT/files.txt"; _shipped_files > "$LIST"
NFILES=$(wc -l < "$LIST" | tr -d ' ')
OUT=$(cd "$ROOT" && xargs "$PY" "$SCAN" "$ROOT" < "$LIST")
SUMMARY=$(printf '%s\n' "$OUT" | tail -1)
NJ=$(printf '%s' "$SUMMARY" | sed -n 's/.*json=\([0-9]*\).*/\1/p')
if [ "$NFILES" -lt 20 ] || [ "${NJ:-0}" -lt 5 ]; then
  _fail "S1-0 instrument: only $NFILES files / ${NJ:-0} json scanned — enumeration broke, NOT a pass"
else
  _pass "S1-0 instrument alive ($NFILES files · $SUMMARY)"
fi
ERRS=$(printf '%s\n' "$OUT" | /usr/bin/grep '^ERR ' || true)
[ -z "$ERRS" ] && _pass "S1-1 every shipped json parses" || { _fail "S1-1 unparsable shipped json (cannot be checked):"; printf '   %s\n' "$ERRS"; }
HITS=$(printf '%s\n' "$OUT" | /usr/bin/grep '^HIT ' || true)
if [ -z "$HITS" ]; then
  _pass "S1-2 zero empty-string matchers in shipped templates/snippets/docs"
else
  _fail "S1-2 empty-string matcher found — omit the key instead (Claude Code: omitted = match all; Copilot CLI rejects \"\"):"
  printf '   %s\n' "$HITS"
fi
# the six templates named in the 2026-10-01 report must be in the scanned set (else S1-2 is vacuous for them)
for t in goal-quench-settings-merged.json settings.Compaction.snippet.json settings.FieldCanon.snippet.json \
         settings.SessionStart.snippet.json settings.SubagentStop.snippet.json subagent-tally-hook.json; do
  /usr/bin/grep -qx "templates/$t" "$LIST" && _pass "S1-3 scanned: templates/$t" \
    || _fail "S1-3 templates/$t not in the scanned set — lane is blind to it"
done

echo
echo "══ revert probe: put the empty matcher back into a real shipped template ══"
RV="$TMPROOT/revert"; mkdir -p "$RV/templates"
cp "$ROOT/templates/settings.Compaction.snippet.json" "$RV/templates/"
"$PY" - "$RV/templates/settings.Compaction.snippet.json" <<'PYEOF'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
g = d["project_settings_json"]["hooks"]["PreCompact"][0]
d["project_settings_json"]["hooks"]["PreCompact"][0] = {"matcher": "", **g}
json.dump(d, open(p, "w"), indent=2)
PYEOF
APPLIED=$(/usr/bin/grep -c '"matcher": ""' "$RV/templates/settings.Compaction.snippet.json")
_eq "RV-0 mutation applied (empty matcher present in the copy)" "$APPLIED" 1
_eq "RV-1 scanner flags the reverted template" "$(_hits "$RV" templates/settings.Compaction.snippet.json)" 1

echo
echo "══ S3: what install-wizard writes ══"
[ -f "$WIZ" ] || { _fail "S3-0 subject missing: $WIZ"; }
MERGE="$TMPROOT/merge.py"; LOCALPY="$TMPROOT/local.py"
awk '/^python3 - "\$FH_DIR" <<.PY.$/{f=1;next} f&&/^PY$/{exit} f' "$WIZ" > "$MERGE"
awk '/^[[:space:]]*python3 - "\$HUB_DIR" "\$BE_DIR" <<.PY.$/{f=1;next} f&&/^PY$/{exit} f' "$WIZ" > "$LOCALPY"
MN=$(wc -l < "$MERGE" | tr -d ' '); LN=$(wc -l < "$LOCALPY" | tr -d ' ')
if [ "$MN" -lt 10 ] || [ "$LN" -lt 10 ]; then
  _fail "S3-0 extraction broke (merge=$MN lines, local=$LN lines) — NOT a pass"
else
  _pass "S3-0 both wizard blocks extracted from the shipped file (merge=$MN · local=$LN lines)"
  H="$TMPROOT/hub"; mkdir -p "$H/templates" "$H/.claude" "$H/scripts"
  cp "$ROOT"/templates/settings.*.snippet.json "$H/templates/"
  cat > "$H/.claude/settings.json" <<'J'
{"hooks":{"PreCompact":[{"matcher":"","hooks":[{"type":"command","command":"bash my_own_precompact.sh"}]}],
          "SessionStart":[{"matcher":"","hooks":[{"type":"command","command":"bash my_telemetry.sh"}]}]}}
J
  # the settings.local.json block only rewrites SessionStart, so its fixture holds only that event
  printf '%s\n' '{"hooks":{"SessionStart":[{"matcher":"","hooks":[{"type":"command","command":"bash my_telemetry.sh"}]}]}}' \
    > "$H/.claude/settings.local.json"
  MOUT=$("$PY" "$MERGE" "$H" 2>&1); MRC=$?
  _eq "S3-1 settings.json merge exits 0" "$MRC" 0
  _eq "S3-2 settings.json written with zero empty matchers" "$(_hits "$H" .claude/settings.json)" 0
  /usr/bin/grep -q 'my_own_precompact' "$H/.claude/settings.json" && /usr/bin/grep -q 'my_telemetry' "$H/.claude/settings.json" \
    && _pass "S3-3 the user's own hooks survive the normalization" \
    || _fail "S3-3 a user hook was dropped while normalizing its matcher"
  LOUT=$("$PY" "$LOCALPY" "$H" "/nonexistent-store" 2>&1); LRC=$?
  _eq "S3-4 settings.local.json block exits 0" "$LRC" 0
  _eq "S3-5 settings.local.json written with zero empty matchers" "$(_hits "$H" .claude/settings.local.json)" 0
  /usr/bin/grep -q 'my_telemetry' "$H/.claude/settings.local.json" \
    && _pass "S3-6 the user's own SessionStart hook survives in settings.local.json" \
    || _fail "S3-6 user hook dropped from settings.local.json"
  # control: the normalization must be the reason, not luck — the fixture really did carry "".
  cp "$H/.claude/settings.json.prewizard" "$H/before.json" 2>/dev/null
  _eq "S3-7 control: the wizard's own backup (.prewizard) of the fixture held the empty matchers" \
      "$(_hits "$H" before.json)" 2
  # FileChanged is deliberately NOT normalized (there the matcher also seeds the watch list, and the
  # doc spells out omitted vs "*" for it, never ""). A future FileChanged snippet must leave a user's
  # "" group exactly as it was.
  H2="$TMPROOT/hub_fc"; mkdir -p "$H2/templates" "$H2/.claude"
  printf '%s\n' '{"project_settings_json":{"hooks":{"FileChanged":[{"matcher":".envrc","hooks":[{"type":"command","command":"bash \"$CLAUDE_PROJECT_DIR/scripts/zzz_watch.sh\""}]}]}}}' \
    > "$H2/templates/settings.Zzz.snippet.json"
  printf '%s\n' '{"hooks":{"FileChanged":[{"matcher":"","hooks":[{"type":"command","command":"bash my_watch.sh"}]}]}}' \
    > "$H2/.claude/settings.json"
  "$PY" "$MERGE" "$H2" >/dev/null 2>&1; FRC=$?
  _eq "S3-8 FileChanged fixture merge exits 0" "$FRC" 0
  _eq "S3-9 FileChanged: the user's \"\" group is left untouched (1 empty matcher remains)" \
      "$(_hits "$H2" .claude/settings.json)" 1
fi

echo
echo "══ S4: hook_drift_check treats \"\" and omitted as the same matcher ══"
if [ ! -f "$DRIFT" ]; then
  _fail "S4-0 subject missing: $DRIFT"
else
  D="$TMPROOT/drift"; mkdir -p "$D/templates"
  cp "$ROOT/templates/subagent-tally-hook.json" "$D/templates/"
  _mk() {  # $1=out  $2=matcher mode: omit | empty | Bash
    "$PY" - "$ROOT/templates/subagent-tally-hook.json" "$1" "$2" <<'PYEOF'
import json, sys
src, out, mode = sys.argv[1:4]
g = json.load(open(src))["hooks"]["SubagentStop"][0]
g = {k: v for k, v in g.items() if k != "matcher"}
if mode == "empty": g = {"matcher": "", **g}
elif mode != "omit": g = {"matcher": mode, **g}
json.dump({"hooks": {"SubagentStop": [g]}}, open(out, "w"), indent=2)
PYEOF
  }
  _v() { bash "$DRIFT" --templates "$D/templates" --settings "$1" --verdict 2>/dev/null; }
  _mk "$D/omit.json" omit;  _mk "$D/empty.json" empty;  _mk "$D/bash.json" Bash
  _eq "S4-1 local omitted · template omitted → CURRENT"                    "$(_v "$D/omit.json")"  CURRENT
  _eq "S4-2 local \"\" (old install) · template omitted → CURRENT, not STALE" "$(_v "$D/empty.json")" CURRENT
  _eq "S4-3 control: local matcher \"Bash\" · template omitted → STALE"      "$(_v "$D/bash.json")"  STALE
fi

echo "──────────────────────────────────────────────"
if [ "$FAILED" -eq 0 ]; then
  echo "COPILOT-COMPAT LANES: PASS ($PASSED lanes)"; exit 0
else
  echo "COPILOT-COMPAT LANES: FAIL"; exit 1
fi

#!/usr/bin/env bash
# test_deep_clarify_spec_path_lanes.sh — where deep-clarify's own Step 3 commands put the spec.
#
# WHY. deep-clarify wrote `.claude/specs/{slug}.md`. Claude Code treats `.claude/` as sensitive: a headless
# run gets the write refused, and an interactive non-developer gets a «modify sensitive file» prompt
# (FoD O2, 2026-11-21). The spec belongs in a plain work-folder path.
#
# WHAT IS CHECKED, by running the commands the skill tells the session to run (not by reading prose):
#   P1  Step 3's mkdir block, a write to the «Write →» path and Step 3's `test -f` line, run in an empty
#       folder, save the spec, print «SPEC SAVED», and create nothing under `.claude/`
#   P2  the four places that name the path agree: the ABORT-if-exists check, the Write target, the
#       `test -f` line, and the Done-When row
#   P3  the gitignore advice for company projects is still there
#   P4  control: the same checks on a planted copy that saves under `.claude/specs/` go red
# NOT CHECKED: whether a real session follows Step 3 (that is a behaviour sim, not this lane).
#
# Usage: bash scripts/test_deep_clarify_spec_path_lanes.sh      Exit: 0 all pass · 1 any fail
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL="$HERE/../plugins/fh-meta/skills/deep-clarify/SKILL.md"
TMPROOT=$(mktemp -d "${TMPDIR:-/tmp}/deep_clarify_spec_XXXXXX")
trap 'rm -rf "$TMPROOT"' EXIT
pass=0; fail=0
ok()  { printf 'PASS  %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf 'FAIL  %s — %s\n' "$1" "$2"; fail=$((fail + 1)); }

# extract <skill file> <out dir> — writes mkdir.sh, write_path, test.sh, abort_path, done_path, has_ignore
extract() {
  python3 - "$1" "$2" <<'PY'
import re, sys, os
src, out = sys.argv[1], sys.argv[2]
t = open(src, encoding="utf-8").read()
a = t.find("## Step 3."); b = t.find("### Spec Document Format", a)
step = t[a:b] if a >= 0 and b > a else ""
blocks = re.findall(r"```bash\n(.*?)```", step, re.S)
mk = next((x for x in blocks if "mkdir" in x), "")
ts = next((x for x in blocks if "test -f" in x), "")
w = re.search(r"`Write`\s*→\s*`([^`]+)`", step)
ab = re.search(r"If `([^`]+)` \*\*already exists", step)
dw = t[t.find("## Done When"):]
dn = re.search(r"`test -f ([^`]+)` exits 0", dw)
ign = "gitignore" in step
def put(name, val): open(os.path.join(out, name), "w", encoding="utf-8").write(val)
put("mkdir.sh", mk); put("test.sh", ts)
put("write_path", w.group(1) if w else ""); put("abort_path", ab.group(1) if ab else "")
put("done_path", dn.group(1) if dn else ""); put("has_ignore", "1" if ign else "0")
PY
}

# check <label> <skill file> — prints the problems, nothing when the skill saves outside .claude/
check() {
  local d="$TMPROOT/$1" wp tp out
  mkdir -p "$d/x" "$d/work"; extract "$2" "$d/x" || { echo "extract failed"; return; }
  wp=$(sed 's/{slug}/demo-spec-20261121/' "$d/x/write_path")
  [ -s "$d/x/mkdir.sh" ] || echo "no mkdir block in Step 3"
  [ -s "$d/x/test.sh" ] || echo "no test -f block in Step 3"
  [ -n "$wp" ] || echo "no «Write → path» in Step 3"
  [ -n "$wp" ] || return
  ( cd "$d/work" && bash "$d/x/mkdir.sh" ) > /dev/null 2>&1 || echo "mkdir block failed"
  ( cd "$d/work" && printf '# Spec: demo\n' > "$wp" ) 2>/dev/null || echo "write to $wp failed (directory missing?)"
  sed 's/{slug}/demo-spec-20261121/g' "$d/x/test.sh" > "$d/x/test_run.sh"
  out=$(cd "$d/work" && bash "$d/x/test_run.sh" 2>&1) || echo "test -f block failed: $out"
  [[ "$out" == *"SPEC SAVED"* ]] || echo "no «SPEC SAVED» line"
  case "$wp" in .claude/*|*/.claude/*) echo "spec path is under .claude/ ($wp)" ;; esac
  [ -e "$d/work/.claude" ] && echo "the commands created .claude/ in the work folder"
  for f in abort_path done_path; do
    [ "$(cat "$d/x/$f")" = "$(cat "$d/x/write_path")" ] || echo "$f «$(cat "$d/x/$f")» ≠ write path «$(cat "$d/x/write_path")»"
  done
  tp=$(sed -n '/test -f /{s/.*test -f \([^ &]*\).*/\1/p;q;}' "$d/x/test.sh")
  [ "$tp" = "$(cat "$d/x/write_path")" ] || echo "test -f path «${tp}» ≠ write path"
  [ "$(cat "$d/x/has_ignore")" = 1 ] || echo "the gitignore advice is gone from Step 3"
}

[ -r "$SKILL" ] || { echo "HARNESS: $SKILL not readable — not measured"; exit 1; }

probs=$(check shipped "$SKILL")
if [ -z "$probs" ]; then ok "P1–P3 the skill's own Step 3 commands save the spec outside .claude/, four path mentions agree, gitignore advice kept"
else bad "P1–P3 shipped SKILL.md" "$(printf '%s' "$probs" | tr '\n' '|')"; fi

# P4 — control: a planted copy that saves under .claude/specs/ must be caught (the instrument is alive)
sed -E 's#(`|mkdir -p |test -f |SPEC SAVED: )specs/#\1.claude/specs/#g' "$SKILL" > "$TMPROOT/planted.md"
if grep -q '\.claude/specs/{slug}' "$TMPROOT/planted.md"; then
  probs=$(check planted "$TMPROOT/planted.md")
  [[ "$probs" == *"under .claude/"* ]] && ok "P4 control: a copy saving under .claude/specs/ is caught" \
    || bad "P4 control blind" "planted .claude/ path not reported: $(printf '%s' "$probs" | tr '\n' '|')"
else
  bad "P4 control not planted" "no .claude/specs/{slug} in the planted copy — the substitution did not apply"
fi

echo "deep-clarify spec path lanes: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

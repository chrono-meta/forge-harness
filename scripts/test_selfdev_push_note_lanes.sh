#!/usr/bin/env bash
# test_selfdev_push_note_lanes.sh — known pairs for scripts/selfdev_push_note.sh (one PR comment per self-dev push).
# A throwaway repo with a bare origin, a fake `gh` that writes the comment body to a file. Nothing here touches GitHub.
#   N1 update push → range old..new, 2 commits, 2 files, revert line, posted once
#   N2 new PR (no --from) → range from merge-base with origin/main, «close this PR unmerged», no revert range
#   N3 rewritten branch (old head not an ancestor) → no range, says so
#   N4 --to not a full id → rc 2, gh never called
#   N5 head not in the repo → rc 2, gh never called (counts are never guessed)
#   N6 gh comment fails → rc 3
#   N7 --dry prints the body and calls gh never
#   N8 the body carries no file name and no commit subject (public PR — ids and counts only)
#   N9 control: --from equal to --to → rc 2 (nothing pushed is not a note)
#   N10 trailing value option → rc 2, no hang · N11 range with a merge commit → «revert by hand»
#   Named, no lane: a git error in the ancestry check (rc ≥ 2) → rc 2; not reproducible without breaking git itself.
. "$(dirname "${BASH_SOURCE[0]}")/fixture_guard_lib.sh"   # scrub inherited GIT_* env first (#1088)
set -u
SC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/selfdev_push_note.sh"
[ -f "$SC" ] || { echo "HARNESS-ERROR: $SC missing"; exit 2; }
W=$(mktemp -d) || { echo "HARNESS-ERROR: mktemp"; exit 2; }
trap 'rm -rf "$W"' EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); echo "  ✅ $1"; }
bad() { fail=$((fail+1)); echo "  ❌ $1"; }
G() { git -c user.name=lane -c user.email=lane@localhost -c commit.gpgsign=false "$@"; }

R="$W/repo"
{ G init -q --bare "$W/origin.git" && G init -q "$R" && G -C "$R" remote add origin "$W/origin.git" \
  && echo base > "$R/a.txt" && G -C "$R" add a.txt && G -C "$R" commit -qm base \
  && G -C "$R" push -q origin HEAD:refs/heads/main && G -C "$R" fetch -q origin \
  && G -C "$R" switch -q -c auto/selfdev-x origin/main \
  && echo one > "$R/secret_name_one.txt" && G -C "$R" add . && G -C "$R" commit -qm "SUBJECT_CANARY first" \
  && OLD=$(G -C "$R" rev-parse HEAD) \
  && echo two > "$R/secret_name_two.txt" && G -C "$R" add . && G -C "$R" commit -qm "SUBJECT_CANARY second" \
  && echo three >> "$R/a.txt" && G -C "$R" add . && G -C "$R" commit -qm "SUBJECT_CANARY third" \
  && NEW=$(G -C "$R" rev-parse HEAD) \
  && G -C "$R" switch -q -c other origin/main && echo z > "$R/z.txt" && G -C "$R" add . && G -C "$R" commit -qm side \
  && SIDE=$(G -C "$R" rev-parse HEAD); } > /dev/null 2>&1 || { echo "HARNESS-ERROR: fixture repo"; exit 2; }
BASE=$(G -C "$R" merge-base origin/main "$NEW")

mkdir -p "$W/bin"
cat > "$W/bin/gh" <<GH
#!/usr/bin/env bash
echo "\$*" >> "$W/gh_calls"
[ -f "$W/gh_fail" ] && exit 1
prev=""; for a in "\$@"; do [ "\$prev" = "--body-file" ] && cp "\$a" "$W/body"; prev="\$a"; done
exit 0
GH
chmod +x "$W/bin/gh"
run() { rm -f "$W/gh_calls" "$W/body"; OUT=$(PATH="$W/bin:$PATH" bash "$SC" --repo "$R" --slug o/r --pr 9 "$@" 2>&1); RC=$?; }
calls() { [ -f "$W/gh_calls" ] && grep -c . "$W/gh_calls" || echo 0; }
s() { printf '%s' "$1" | cut -c1-12; }

echo "selfdev push note lanes"
run --from "$OLD" --to "$NEW"
B=$(cat "$W/body" 2>/dev/null)
{ [ "$RC" -eq 0 ] && [ "$(calls)" -eq 1 ] && grep -q -- '-R o/r' "$W/gh_calls" \
  && printf '%s' "$B" | grep -qF "this push: \`$(s "$OLD")..$(s "$NEW")\` · 2 commit(s) · 2 file(s) changed" \
  && printf '%s' "$B" | grep -qF "git revert --no-edit $(s "$OLD")..$(s "$NEW")"; } \
  && ok "N1 update push → range, 2 commits, 2 files, revert line, posted once" || bad "N1 rc=$RC calls=$(calls) body=[$B] out=[$OUT]"
N1B="$B"

run --to "$NEW"
B=$(cat "$W/body" 2>/dev/null)
{ [ "$RC" -eq 0 ] && printf '%s' "$B" | grep -qF "new PR: \`$(s "$BASE")..$(s "$NEW")\` from main · 3 commit(s) · 3 file(s) changed" \
  && printf '%s' "$B" | grep -qF 'close this PR unmerged' && ! printf '%s' "$B" | grep -qF 'git revert --no-edit'; } \
  && ok "N2 new PR → range from merge-base, «close unmerged», no revert range" || bad "N2 rc=$RC body=[$B] out=[$OUT]"

run --from "$SIDE" --to "$NEW"
B=$(cat "$W/body" 2>/dev/null)
{ [ "$RC" -eq 0 ] && printf '%s' "$B" | grep -qF 'rewrote the branch' && ! printf '%s' "$B" | grep -qF 'commit(s)'; } \
  && ok "N3 old head not an ancestor → «rewrote the branch», no range" || bad "N3 rc=$RC body=[$B]"

run --from "$OLD" --to "$(s "$NEW")"
{ [ "$RC" -eq 2 ] && [ "$(calls)" -eq 0 ]; } && ok "N4 short --to → rc 2, gh never called" || bad "N4 rc=$RC calls=$(calls)"

run --from "$OLD" --to bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
{ [ "$RC" -eq 2 ] && [ "$(calls)" -eq 0 ] && printf '%s' "$OUT" | grep -q 'not posting'; } \
  && ok "N5 head not in the repo → rc 2, not posted (no guessed counts)" || bad "N5 rc=$RC calls=$(calls) out=[$OUT]"

: > "$W/gh_fail"; run --from "$OLD" --to "$NEW"; rm -f "$W/gh_fail"
[ "$RC" -eq 3 ] && ok "N6 gh comment fails → rc 3" || bad "N6 rc=$RC"

run --from "$OLD" --to "$NEW" --dry
{ [ "$RC" -eq 0 ] && [ "$(calls)" -eq 0 ] && printf '%s' "$OUT" | grep -qF 'selfdev push note'; } \
  && ok "N7 --dry prints the body, gh never called" || bad "N7 rc=$RC calls=$(calls)"

# N8 control first: the fixture DOES carry the canaries (so their absence from the body means something)
G -C "$R" log --format=%s "$OLD..$NEW" | grep -q SUBJECT_CANARY && G -C "$R" diff --name-only "$OLD" "$NEW" | grep -q secret_name \
  || { echo "HARNESS-ERROR: N8 fixture carries no canary"; exit 2; }
[ -n "$N1B" ] && ! printf '%s' "$N1B" | grep -qE 'SUBJECT_CANARY|secret_name' && ok "N8 body carries no commit subject and no file name" || bad "N8 body=[$N1B]"

run --from "$NEW" --to "$NEW"
{ [ "$RC" -eq 2 ] && [ "$(calls)" -eq 0 ]; } && ok "N9 --from = --to → rc 2, nothing posted" || bad "N9 rc=$RC"

# N10 a value option with no value (trailing --to) → rc 2 at once (codex R1: shift 2 used to loop forever)
OUT=$(PATH="$W/bin:$PATH" timeout 10 bash "$SC" --repo "$R" --slug o/r --pr 9 --to 2>&1); RC=$?
[ "$RC" -eq 2 ] && ok "N10 trailing --to with no value → rc 2, no hang" || bad "N10 rc=$RC (124 = hung)"

# N11 a push whose range holds a merge commit → no range-revert command (it would stop part-way); says revert by hand
{ G -C "$R" switch -q auto/selfdev-x && G -C "$R" merge -q --no-ff -m "merge side" other && MH=$(G -C "$R" rev-parse HEAD); } > /dev/null 2>&1 \
  || { echo "HARNESS-ERROR: N11 fixture merge"; exit 2; }
run --from "$NEW" --to "$MH"
B=$(cat "$W/body" 2>/dev/null)
{ [ "$RC" -eq 0 ] && printf '%s' "$B" | grep -qF '1 merge commit(s)' && ! printf '%s' "$B" | grep -qF 'git revert --no-edit'; } \
  && ok "N11 range with a merge commit → «revert by hand», no range-revert command" || bad "N11 rc=$RC body=[$B]"

echo "selfdev push note lanes: $pass passed · $fail failed"
[ "$fail" -eq 0 ]

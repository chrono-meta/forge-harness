#!/usr/bin/env bash
# test_session_config_fingerprint_lanes.sh — lanes for scripts/session_config_fingerprint.sh and
# its consumer ④-f of scripts/session_close_check.sh. Uses a scratch FH root and a scratch HOME
# only — the operator's real ~/.claude and this repo's gitignored files are never read or written.
#
# Defect pinned (2026-09-26): a sub-agent's measurement run overwrote this checkout's .claude/settings.json and
# CLAUDE.md mid-session and nothing noticed. Revert probe at the end: a mutant compare that only
# checks «file present» must go red on the one-file-changed fixture.
# Runs under bash 3.2 (/bin/bash) and bash 5.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SUBJ="$ROOT/scripts/session_config_fingerprint.sh"
CLOSE="$ROOT/scripts/session_close_check.sh"
T="$(mktemp -d 2>/dev/null || mktemp -d -t cfgfp)"
[ -n "$T" ] && [ -d "$T" ] || { echo "HARNESS-ERROR: mktemp failed"; exit 2; }
trap 'rm -rf "$T"' EXIT
pass=0; fail=0
chk() { if [ "$1" -eq 0 ]; then echo "  ✅ $2"; pass=$((pass+1)); else echo "  ❌ $2"; fail=$((fail+1)); fi; }
[ -f "$SUBJ" ] || { echo "HARNESS-ERROR: subject missing: $SUBJ"; exit 2; }

FHR="$T/fh"; HM="$T/home"
mkdir -p "$FHR/.claude" "$FHR/scripts" "$HM/.claude"
echo '{"a":1}' > "$FHR/.claude/settings.json"
echo 'local'   > "$FHR/CLAUDE.local.md"
echo '# hub'   > "$FHR/CLAUDE.md"
echo '{"h":1}' > "$HM/.claude/settings.json"
cp "$SUBJ" "$FHR/scripts/"
export CLAUDE_CODE_SESSION_ID="lane-session-1"
fp() { bash "$FHR/scripts/session_config_fingerprint.sh" "$@" --fh "$FHR" --home "$HM"; }
SNAP="$FHR/tracks/_meta/.session_config_fingerprint"

echo "── no snapshot ──"
out=$(fp compare 2>&1); rc=$?
[ "$rc" -eq 3 ]; chk $? "no snapshot → rc 3"
printf '%s\n' "$out" | grep -q 'NOT MEASURED'; chk $? "no snapshot → says NOT MEASURED (not «unchanged»)"

echo "── snapshot + unchanged ──"
fp snap >/dev/null 2>&1; [ -f "$SNAP" ]; chk $? "snap writes the snapshot under tracks/_meta"
grep -q '^session=lane-session-1$' "$SNAP"; chk $? "snapshot carries the session id"
[ "$(grep -c '	' "$SNAP")" -eq 6 ]; chk $? "snapshot has one row per target (6)"
grep -q "$HM" "$SNAP"; [ $? -ne 0 ]; chk $? "snapshot rows carry labels, not the absolute home path"
out=$(fp compare 2>&1); rc=$?
[ "$rc" -eq 0 ]; chk $? "nothing changed → rc 0 (quiet)"
printf '%s\n' "$out" | grep -q '↳'; [ $? -ne 0 ]; chk $? "nothing changed → names no file"

echo "── one file changed ──"
echo '{"a":2}' > "$FHR/.claude/settings.json"
out=$(fp compare 2>&1); rc=$?
[ "$rc" -eq 1 ]; chk $? "one change → rc 1 (advisory)"
printf '%s\n' "$out" | grep -q 'repo:.claude/settings.json — content changed'; chk $? "names the changed file"
[ "$(printf '%s\n' "$out" | grep -c '↳')" -eq 1 ]; chk $? "names ONLY that file"
printf '%s\n' "$out" | grep -q '§Config-Overwrite-Recovery'; chk $? "points at the recovery procedure (repo doc, not memory)"
grep -q '^## 9. Config-Overwrite-Recovery' "$ROOT/knowledge/shared/harness-core/checkout_layer_drift.md"
chk $? "the pointed-at section exists"
echo '{"a":1}' > "$FHR/.claude/settings.json"

echo "── home file appears / clear keeps baseline ──"
echo 'x' > "$HM/.claude/CLAUDE.md"
out=$(fp compare 2>&1)
printf '%s\n' "$out" | grep -q 'home:~/.claude/CLAUDE.md — ABSENT → PRESENT'; chk $? "a home config file appearing is named"
fp snap --source clear >/dev/null 2>&1
out=$(fp compare 2>&1); rc=$?
[ "$rc" -eq 1 ]; chk $? "/clear in the same session keeps the baseline (evidence not erased)"
CLAUDE_CODE_SESSION_ID="lane-session-2" bash "$FHR/scripts/session_config_fingerprint.sh" snap --fh "$FHR" --home "$HM" --source clear >/dev/null 2>&1
grep -q '^session=lane-session-2$' "$SNAP"; chk $? "a NEW session re-snaps even on source=clear"
rm -f "$HM/.claude/CLAUDE.md"
export CLAUDE_CODE_SESSION_ID="lane-session-2"
fp snap >/dev/null 2>&1

echo "── touched, same bytes (cross-family 2026-09-26) ──"
cp "$FHR/CLAUDE.local.md" "$T/cl.bak"; touch -t 202001010000 "$FHR/CLAUDE.local.md"
out=$(fp compare 2>&1); rc=$?
[ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -q 'repo:CLAUDE.local.md — touched (내용 동일'
chk $? "mtime-only change → rc 0, reported separately as touched (not counted as a change)"
printf '%s\n' "$out" | grep -q 'content changed'; [ $? -ne 0 ]; chk $? "  … and not reported as content changed"
fp snap >/dev/null 2>&1

echo "── unreadable is not unchanged ──"
if [ "$(id -u)" != 0 ]; then
  chmod 000 "$FHR/CLAUDE.local.md"
  out=$(fp compare 2>&1); rc=$?
  chmod 644 "$FHR/CLAUDE.local.md"
  [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -q 'CLAUDE.local.md — unreadable'
  chk $? "file turned unreadable → named as NOT MEASURED, not folded into «unchanged»"
else
  echo "  ⏭️  unreadable lane skipped (root) — not a pass"
fi

echo "── consumer ④-f ──"
cp "$CLOSE" "$FHR/scripts/session_close_check.sh"
echo '# hub changed' > "$FHR/CLAUDE.md"
out=$(bash "$FHR/scripts/session_close_check.sh" "$FHR" 2>&1)
printf '%s\n' "$out" | grep -q '^④-f .*repo:CLAUDE.md — content changed'; chk $? "close check ④-f names the overwritten CLAUDE.md"
echo '# hub' > "$FHR/CLAUDE.md"
rm -f "$SNAP"
out=$(bash "$FHR/scripts/session_close_check.sh" "$FHR" 2>&1)
printf '%s\n' "$out" | grep -q '^④-f .*NOT MEASURED'; chk $? "close check ④-f with no snapshot → NOT MEASURED"
mkdir -p "$T/stubroot/scripts"; cp "$CLOSE" "$T/stubroot/scripts/session_close_check.sh"
printf '#!/bin/sh\necho stub-output\nexit 7\n' > "$T/stubroot/scripts/session_config_fingerprint.sh"
out=$(bash "$T/stubroot/scripts/session_close_check.sh" "$T/stubroot" 2>&1)
printf '%s\n' "$out" | grep -q '④-f .*checker exited 7'; chk $? "④-f keeps the checker's rc (exit 7 → instrument error named, not hidden by the sed decoration)"
wired=$(grep -c 'session_config_fingerprint.sh" snap' "$ROOT/scripts/fh_session_load.sh")
[ "$wired" -ge 1 ]; chk $? "snap is wired into fh_session_load.sh (SessionStart)"

echo "── revert probe: compare that only checks presence ──"
sed 's/elif \[ "\$hash" != "\$old_hash" \]; then/elif false; then # MUTANT-NO-HASH/' "$SUBJ" > "$T/mutant.sh"
grep -q 'MUTANT-NO-HASH' "$T/mutant.sh"; chk $? "mutation applied (control for the probe itself)"
fp snap >/dev/null 2>&1
echo '{"a":9}' > "$FHR/.claude/settings.json"
bash "$T/mutant.sh" compare --fh "$FHR" --home "$HM" >/dev/null 2>&1; mrc=$?
[ "$mrc" -eq 0 ]; chk $? "mutant reports «unchanged» on the one-file-changed fixture → the «names the changed file» lane would be RED"

echo
if [ "$fail" -eq 0 ]; then echo "CONFIG-FINGERPRINT LANES: PASS ($pass/$pass)"; exit 0; fi
echo "CONFIG-FINGERPRINT LANES: FAIL ($fail failed, $pass passed)"; exit 1

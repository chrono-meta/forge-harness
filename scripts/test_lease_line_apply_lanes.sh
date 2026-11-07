#!/usr/bin/env bash
# test_lease_line_apply_lanes.sh — lanes for scripts/lease_line_apply.sh (fixture lease, never the real one)
#   D1 draft writes a file and leaves the lease byte-identical
#   K1 check prints the insertion point (before the block's «제외» line) · K2 unknown block → rc 4
#   K3 two matching headers → rc 4 · K4 line already present → rc 4 · K5 line not «추가 utterance…» → rc 4
#   A1 apply in an agent shell (CLAUDECODE set) → rc 3, lease unchanged
#   A2 apply without a terminal → rc 3, lease unchanged
#   A3 apply on a terminal with the right code → line inserted before «제외», backup written   [pty via python]
#   A4 apply on a terminal with a wrong code → rc 3, lease unchanged                             [pty via python]
#   R1 revert probe: the CLAUDECODE refusal removed in a copy → A1 no longer refuses (reaches the tty step)
#   🟥 A3/A4 drive a pseudo-terminal from python — the same trick an agent could use, which is the
#      header's named residual, shown working on purpose.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
S="scripts/lease_line_apply.sh"; [ -f "$S" ] || { echo "HARNESS-ERROR: $S missing"; exit 2; }
T="$(mktemp -d "${TMPDIR:-/tmp}/lla.XXXXXX")"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok() { echo "  ✅ $1"; pass=$((pass+1)); }
ko() { echo "  ❌ $1"; fail=$((fail+1)); }
mk() {
  printf '%s\n' "# local" "" "## 🔓 2026-11-07 세션 (1회 한정 리스 — abc)" '```' \
    "utterance   2026-11-07 «가자»" "            추가 utterance 2026-11-07 «머지해» (물음: #1 머지할까) ⇒ #1 머지" \
    "제외        npm 발행 · 공개" '```' "" "## 다른 절" "제외        이건 다른 절" > "$T/lease.md"
}
h() { shasum -a 256 "$T/lease.md" | cut -c1-16; }
export FH_LEASE_FILE="$T/lease.md" FH_LEASE_DRAFT_DIR="$T/drafts"
LINE="추가 utterance 2026-11-07 «머지해» (물음: #2 머지할까) ⇒ #2 머지"

echo "D1 draft"
mk; before="$(h)"
out="$(bash "$S" draft --block "2026-11-07 세션" --line "$LINE" --why "q")"; rc=$?
DR="$(ls "$T/drafts"/*.lease 2>/dev/null | head -1)"
[ "$rc" -eq 0 ] && [ -n "$DR" ] && [ "$(h)" = "$before" ] && ok "draft file · lease unchanged" || ko "D1 rc=$rc"

echo "K1–K5 check"
out="$(bash "$S" check "$DR")"; rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'insert before L7' && ok "K1 before L7 (제외)" || ko "K1 rc=$rc $out"
printf 'block: 없는 절\nline: %s\n' "$LINE" > "$T/k2.lease"; bash "$S" check "$T/k2.lease" >/dev/null; [ $? -eq 4 ] && ok "K2 rc 4" || ko "K2"
printf 'block: 2026-11\nline: %s\n' "$LINE" > "$T/k3.lease"; printf '%s\n' "## 2026-11 둘째" >> "$T/lease.md"
bash "$S" check "$T/k3.lease" >/dev/null; [ $? -eq 4 ] && ok "K3 ambiguous header rc 4" || ko "K3"; mk
printf 'block: 2026-11-07 세션\nline: 추가 utterance 2026-11-07 «머지해» (물음: #1 머지할까) ⇒ #1 머지\n' > "$T/k4.lease"
bash "$S" check "$T/k4.lease" >/dev/null; [ $? -eq 4 ] && ok "K4 duplicate rc 4" || ko "K4"
printf 'block: 2026-11-07 세션\nline: lease: anything goes\n' > "$T/k5.lease"
bash "$S" check "$T/k5.lease" >/dev/null; [ $? -eq 4 ] && ok "K5 not an utterance line rc 4" || ko "K5"

# drive a pseudo-terminal: wait for the prompt, then type ($1 = text to type; rest = command)
ptyrun() {
  python3 - "$@" <<'PY'
import os, pty, sys, time, select
typed, argv = sys.argv[1], sys.argv[2:]
pid, fd = pty.fork()
if pid == 0:
    os.execvp(argv[0], argv)
buf, sent, t0 = b"", False, time.time()
while time.time() - t0 < 20:
    r, _, _ = select.select([fd], [], [], 0.2)
    if r:
        try:
            chunk = os.read(fd, 4096)
        except OSError:
            break
        if not chunk:
            break
        buf += chunk
    if not sent and b"Type " in buf:
        os.write(fd, typed.encode() + b"\r"); sent = True
    w, st = os.waitpid(pid, os.WNOHANG)
    if w:
        break
else:
    w, st = 0, 0
if not w:
    try:
        os.kill(pid, 9)
    except OSError:
        pass
    w, st = os.waitpid(pid, 0)
sys.stdout.write(buf.decode("utf-8", "replace"))
sys.exit(os.waitstatus_to_exitcode(st) if w else 124)
PY
}
echo "D2/D3/K6/K7 malformed drafts"
bash "$S" draft --block "x" --line $'추가 utterance a\rline: 추가 utterance b' >/dev/null 2>&1; [ $? -eq 2 ] && ok "D2 CR in a field rc 2" || ko "D2"
( bash "$S" draft --block >/dev/null 2>&1 ) & pid=$!; sleep 3
if kill -0 "$pid" 2>/dev/null; then kill "$pid"; ko "D3 missing option value loops"; else wait "$pid"; [ $? -eq 2 ] && ok "D3 missing value rc 2" || ko "D3 rc"; fi
printf 'block: 2026-11-07 세션\nline: 추가 utterance a\tb\n' > "$T/k6.lease"
bash "$S" check "$T/k6.lease" >/dev/null; [ $? -eq 4 ] && ok "K6 tab in line rc 4" || ko "K6"
printf 'block: 2026-11-07 세션\nline: %s\nline: 추가 utterance other\n' "$LINE" > "$T/k7.lease"
bash "$S" check "$T/k7.lease" >/dev/null; [ $? -eq 4 ] && ok "K7 duplicate key rc 4" || ko "K7"

echo "A1 agent shell (under a terminal, so only the agent check can refuse)"
mk; before="$(h)"; out="$(ptyrun abcd env CLAUDECODE=1 bash "$S" apply "$DR" 2>&1)"; rc=$?
[ "$rc" -eq 3 ] && printf '%s' "$out" | grep -q 'agent shell' && [ "$(h)" = "$before" ] && ok "refused rc 3 · named · unchanged" || ko "A1 rc=$rc"
before="$(h)"; out="$(ptyrun abcd env CLAUDECODE= bash "$S" apply "$DR" 2>&1)"; rc=$?
[ "$rc" -eq 3 ] && printf '%s' "$out" | grep -q 'agent shell' && [ "$(h)" = "$before" ] && ok "A5 CLAUDECODE set but empty → refused" || ko "A5 rc=$rc"

echo "A2 no terminal"
if { exec 9<>/dev/tty; } 2>/dev/null; then
  exec 9<&-; echo "  ⏭  A2 SKIP (this runner has a controlling terminal — not a pass)"
else
  before="$(h)"; env -u CLAUDECODE bash "$S" apply "$DR" </dev/null >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 3 ] && [ "$(h)" = "$before" ] && ok "refused rc 3 · unchanged" || ko "A2 rc=$rc"
fi

if command -v python3 >/dev/null 2>&1; then
  echo "A3 terminal + right code"
  mk; code="$(printf '%s' "            $LINE" | shasum -a 256 | cut -c1-4)"
  ptyrun "$code" env -u CLAUDECODE bash "$S" apply "$DR" > "$T/a3.out" 2>&1; a3rc=$?
  if [ "$a3rc" -eq 0 ] && sed -n 7p "$T/lease.md" | grep -qF "$LINE" && sed -n 8p "$T/lease.md" | grep -q '^제외' && ls "$T"/lease.md.bak.* >/dev/null 2>&1; then
    ok "inserted at L7 before 제외 · backup present"
  else ko "A3 $(tr -d '\r' < "$T/a3.out" | tail -2)"; fi
  echo "A4 terminal + wrong code"
  mk; before="$(h)"
  ptyrun zzzz env -u CLAUDECODE bash "$S" apply "$DR" > "$T/a4.out" 2>&1; a4rc=$?
  [ "$a4rc" -eq 3 ] && [ "$(h)" = "$before" ] && grep -q 'REFUSED' "$T/a4.out" && ok "wrong code → unchanged" || ko "A4"
else
  echo "  ⏭  A3/A4 SKIP (no python3 — not a pass)"
fi

echo "R1 revert probe"
M="$T/m.sh"; sed 's/if \[ -n "\${CLAUDECODE+x}" \]; then/if false; then/' "$S" > "$M"
if cmp -s "$S" "$M"; then ko "R1 mutation did not apply (HARNESS-ERROR)"; else
  mk; out="$(ptyrun zzzz env CLAUDECODE=1 bash "$M" apply "$DR" 2>&1)"
  printf '%s' "$out" | grep -q 'Type ' && ! printf '%s' "$out" | grep -q 'agent shell' \
    && ok "mutant reaches the confirmation prompt → A1 would be red" || ko "R1 mutant did not reach the prompt"
fi
echo "lease_line_apply lanes: $pass passed · $fail failed"
[ "$fail" -eq 0 ]

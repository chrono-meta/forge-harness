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
. "$(dirname "${BASH_SOURCE[0]}")/fixture_guard_lib.sh"   # scrub inherited GIT_* env first (#1088)
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
DR="$(find "$T/drafts" -name "*.lease" -type f -print 2>/dev/null)"; DR="${DR%%$'\n'*}"
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
        t = typed
        if t.startswith("@AUTO@"):   # type the code the prompt shows (the agent trick the header names)
            import re
            m = re.search(rb"Type ([0-9a-f]{4}) ", buf)
            if not m:
                continue
            if t == "@AUTO@touch":   # change the lease while the prompt is open
                with open(os.environ["FH_LEASE_FILE"], "a", encoding="utf-8") as f:
                    f.write("touched\n")
            if os.environ.get("PTY_BEFORE_TYPE"):   # change something while the prompt is open
                os.system(os.environ["PTY_BEFORE_TYPE"])
            t = m.group(1).decode()
        os.write(fd, t.encode() + b"\r"); sent = True
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
  l7="$(sed -n 7p "$T/lease.md")"; l8="$(sed -n 8p "$T/lease.md")"
  bak_n="$(find "$T" -maxdepth 1 -name 'lease.md.bak.*' | wc -l | tr -d ' ')"
  if [ "$a3rc" -eq 0 ] && [ "$l7" = "            $LINE" ] && [ "${l8#제외}" != "$l8" ] && [ "$bak_n" -ge 1 ]; then
    ok "inserted at L7 before 제외 · backup present"
  else ko "A3 $(tr -d '\r' < "$T/a3.out" | tail -2)"; fi
  # A6 the applied draft moved to applied/ (so apply-all will not offer it again); put it back for A4/R1
  if [ ! -f "$DR" ] && [ -f "$T/drafts/applied/$(basename "$DR")" ]; then ok "A6 applied draft moved to applied/"
  else ko "A6 draft not moved (present=$([ -f "$DR" ] && echo yes || echo no))"; fi
  [ -f "$DR" ] || mv "$T/drafts/applied/$(basename "$DR")" "$DR"
  echo "A4 terminal + wrong code"
  mk; before="$(h)"
  ptyrun zzzz env -u CLAUDECODE bash "$S" apply "$DR" > "$T/a4.out" 2>&1; a4rc=$?
  [ "$a4rc" -eq 3 ] && [ "$(h)" = "$before" ] && grep -q 'REFUSED' "$T/a4.out" && ok "wrong code → unchanged" || ko "A4"
  # ── apply-all: one code for every queued draft ──
  # queue: two new lines for the same block (both must land, in order) · one already there · one malformed
  L2="추가 utterance 2026-11-07 «초록이면 머지» (물음: #3) ⇒ #3 머지"
  mkq() {
    mk; rm -rf "$T/drafts"; mkdir -p "$T/drafts"; find "$T" -maxdepth 1 -name 'lease.md.bak.*' -delete
    printf 'block: 2026-11-07 세션\nline: %s\n' "$LINE" > "$T/drafts/a1.lease"
    printf 'block: 2026-11-07 세션\nline: %s\n' "$L2" > "$T/drafts/a2.lease"
    printf 'block: 2026-11-07 세션\nline: 추가 utterance 2026-11-07 «머지해» (물음: #1 머지할까) ⇒ #1 머지\n' > "$T/drafts/a3.lease"
    printf 'block: 없는 절\nline: %s\n' "$LINE" > "$T/drafts/a4.lease"
  }
  echo "B1 apply-all in an agent shell"
  mkq; before="$(h)"; out="$(ptyrun abcd env CLAUDECODE=1 bash "$S" apply-all 2>&1)"; rc=$?
  [ "$rc" -eq 3 ] && printf '%s' "$out" | grep -q 'agent shell' && [ "$(h)" = "$before" ] && [ -f "$T/drafts/a1.lease" ] \
    && ok "B1 refused rc 3 · unchanged · nothing moved" || ko "B1 rc=$rc"
  echo "B2 apply-all + the code it shows (known positive)"
  mkq; ptyrun @AUTO@ env -u CLAUDECODE bash "$S" apply-all > "$T/b2.out" 2>&1; rc=$?
  l7="$(sed -n 7p "$T/lease.md")"; l8="$(sed -n 8p "$T/lease.md")"; l9="$(sed -n 9p "$T/lease.md")"
  bak_n="$(find "$T" -maxdepth 1 -name 'lease.md.bak.*' | wc -l | tr -d ' ')"
  if [ "$rc" -eq 0 ] && [ "$l7" = "            $LINE" ] && [ "$l8" = "            $L2" ] && [ "${l9#제외}" != "$l9" ] \
     && [ "$bak_n" -eq 1 ] && [ "$(grep -c '추가 utterance' "$T/lease.md")" -eq 3 ]; then
    ok "B2 two lines in order before 제외 · one backup · the present line not duplicated"
  else ko "B2 rc=$rc $(tr -d '\r' < "$T/b2.out" | tail -3)"; fi
  { [ -f "$T/drafts/applied/a1.lease" ] && [ -f "$T/drafts/applied/a2.lease" ] && [ -f "$T/drafts/applied/a3.lease" ] \
    && [ -f "$T/drafts/a4.lease" ] && [ ! -f "$T/drafts/a1.lease" ]; } \
    && ok "B2b added + already-there moved to applied/ · skipped stays queued" || ko "B2b queue state: $(ls "$T/drafts" | tr '\n' ' ')"
  grep -q 'a4.lease — skipped' "$T/b2.out" && ok "B2c the skipped draft is shown with its reason" || ko "B2c"
  echo "B3 apply-all + a wrong code (known negative)"
  mkq; before="$(h)"; ptyrun zzzz env -u CLAUDECODE bash "$S" apply-all > "$T/b3.out" 2>&1; rc=$?
  [ "$rc" -eq 3 ] && [ "$(h)" = "$before" ] && [ -f "$T/drafts/a1.lease" ] && [ ! -d "$T/drafts/applied" ] \
    && ok "B3 rc 3 · unchanged · nothing moved" || ko "B3 rc=$rc"
  echo "B4 the lease changes while the prompt is open"
  mkq; ptyrun @AUTO@touch env -u CLAUDECODE bash "$S" apply-all > "$T/b4.out" 2>&1; rc=$?
  { [ "$rc" -eq 3 ] && [ "$(tail -1 "$T/lease.md")" = "touched" ] && ! grep -qF "$L2" "$T/lease.md" && [ -f "$T/drafts/a1.lease" ]; } \
    && ok "B4 refused rc 3 · lines not written · nothing moved" || ko "B4 rc=$rc $(tr -d '\r' < "$T/b4.out" | tail -2)"
  echo "B5 a second run offers only what is left"
  mkq; ptyrun @AUTO@ env -u CLAUDECODE bash "$S" apply-all >/dev/null 2>&1; before="$(h)"
  out="$(ptyrun @AUTO@ env -u CLAUDECODE bash "$S" apply-all 2>&1)"; rc=$?
  [ "$rc" -eq 4 ] && [ "$(h)" = "$before" ] && printf '%s' "$out" | grep -q 'nothing to apply' && ! printf '%s' "$out" | grep -q 'a1.lease' \
    && ok "B5 applied drafts not offered again · rc 4" || ko "B5 rc=$rc"
  echo "B6 a draft's target block changes while the prompt is open (codex R1 HIGH)"
  mkq; before="$(h)"
  out="$(PTY_BEFORE_TYPE="printf 'block: 다른 절\\nline: %s\\n' '$LINE' > '$T/drafts/a1.lease'" \
    ptyrun @AUTO@ env -u CLAUDECODE bash "$S" apply-all 2>&1)"; rc=$?
  { [ "$rc" -eq 3 ] && [ "$(h)" = "$before" ] && [ -f "$T/drafts/a1.lease" ]; } \
    && ok "B6 refused rc 3 · lease unchanged · nothing moved" || ko "B6 rc=$rc $(printf '%s' "$out" | tr -d '\r' | tail -2)"
  echo "A7 single apply: the draft is edited while the prompt is open (codex R1 MED)"
  mk; rm -rf "$T/drafts"; mkdir -p "$T/drafts"; printf 'block: 2026-11-07 세션\nline: %s\n' "$LINE" > "$T/drafts/s1.lease"
  PTY_BEFORE_TYPE="printf 'block: 2026-11-07 세션\\nline: %s\\n' '$L2' > '$T/drafts/s1.lease'" \
    ptyrun @AUTO@ env -u CLAUDECODE bash "$S" apply "$T/drafts/s1.lease" > "$T/a7.out" 2>&1; rc=$?
  { [ "$rc" -eq 0 ] && [ -f "$T/drafts/s1.lease" ] && grep -qF "$L2" "$T/drafts/s1.lease" && [ ! -d "$T/drafts/applied" ]; } \
    && ok "A7 the edited draft stays queued (not marked applied)" || ko "A7 rc=$rc $(tr -d '\r' < "$T/a7.out" | tail -2)"
  echo "B7 a draft name carrying a tab/newline cannot forge a record (codex R2 HIGH)"
  mkq; printf 'block: 없는 절\nline: %s\n' "$LINE" > "$T/drafts/victim.lease"; rm -f "$T/drafts/a4.lease"
  printf 'block: 2026-11-07 세션\nline: %s\n' "$L2" > "$T/drafts/x"$'\n'"MOVE"$'\t'"victim.lease"$'\t'"$(shasum -a 256 "$T/drafts/victim.lease" | cut -c1-64)"$'\t'"j.lease"
  out="$(ptyrun @AUTO@ env -u CLAUDECODE bash "$S" apply-all 2>&1)"; rc=$?
  { [ -f "$T/drafts/victim.lease" ] && printf '%s' "$out" | grep -q 'unexpected file name'; } \
    && ok "B7 the odd name is skipped and the victim stays queued" || ko "B7 rc=$rc victim=$([ -f "$T/drafts/victim.lease" ] && echo queued || echo MOVED)"
else
  echo "  ⏭  A3/A4/A7/B1–B7 SKIP (no python3 — not a pass)"
fi

echo "R1 revert probe"
mkdir -p "$T/drafts"; printf 'block: 2026-11-07 세션\nline: %s\n' "$LINE" > "$DR"   # B lanes reset the queue
M="$T/m.sh"; sed 's/if \[ -n "\${CLAUDECODE+x}" \]; then/if false; then/' "$S" > "$M"
if cmp -s "$S" "$M"; then ko "R1 mutation did not apply (HARNESS-ERROR)"; else
  mk; out="$(ptyrun zzzz env CLAUDECODE=1 bash "$M" apply "$DR" 2>&1)"
  printf '%s' "$out" | grep -q 'Type ' && ! printf '%s' "$out" | grep -q 'agent shell' \
    && ok "mutant reaches the confirmation prompt → A1 would be red" || ko "R1 mutant did not reach the prompt"
fi
# mutate SCRIPT → one known-negative lane must turn red (apply-check: every find matched once, mutant differs)
probe() {  # $1 name · $2 lane command (uses $M; must FAIL on the mutant) · then find/replace pairs
  local name="$1" lane="$2"; shift 2; M="$T/m_$name.sh"
  python3 - "$S" "$M" "$@" <<'PY'
import sys
s = open(sys.argv[1], encoding="utf-8").read()
a = sys.argv[3:]
for f, r in zip(a[0::2], a[1::2]):
    if s.count(f) != 1:
        sys.exit(1)
    s = s.replace(f, r)
open(sys.argv[2], "w", encoding="utf-8").write(s)
PY
  if [ $? -ne 0 ] || cmp -s "$S" "$M"; then ko "$name mutation did not apply (HARNESS-ERROR)"; return; fi
  if eval "$lane"; then ko "$name mutant still passes the lane — decorative"; else ok "$name mutant turns the lane red"; fi
}
echo "R2–R4 revert probes on apply-all"
probe R2 'mkq; before="$(h)"; ptyrun zzzz env -u CLAUDECODE bash "$M" apply-all >/dev/null 2>&1; [ $? -eq 3 ] && [ "$(h)" = "$before" ]' \
  '[ -n "$code" ] && [ "$typed" = "$code" ]' 'true'
# the «changed while waiting» refusal is three layers (shell compare · python start · python before replace): all three off
probe R3 'mkq; ptyrun @AUTO@touch env -u CLAUDECODE bash "$M" apply-all >/dev/null 2>&1; [ $? -eq 3 ] && ! grep -qF "$L2" "$T/lease.md"' \
  '[ "$snap" = "$now" ] || { echo "REFUSED: the lease file changed while waiting — run apply-all again"' 'true || { echo "x"' \
  'if snap != "-" and hashlib.sha256(data).hexdigest() != snap:' 'if False:' \
  'if hashlib.sha256(open(lease, "rb").read()).hexdigest() != snap:' 'if False:'
probe R4 'mkq; ptyrun @AUTO@ env -u CLAUDECODE bash "$M" apply-all >/dev/null 2>&1; [ -f "$T/drafts/applied/a1.lease" ]' \
  'then mark_applied "$DDIR/$nm"' 'then :'
echo "R5–R6 revert probes on the codex R1 fixes"
probe R5 'mkq; before="$(h)"; PTY_BEFORE_TYPE="printf '"'"'block: 다른 절\\nline: %s\\n'"'"' '"'"'$LINE'"'"' > '"'"'$T/drafts/a1.lease'"'"'" ptyrun @AUTO@ env -u CLAUDECODE bash "$M" apply-all >/dev/null 2>&1; [ $? -eq 3 ] && [ "$(h)" = "$before" ]' \
  'added.append(f"{name}\t{lines[h]}\tL{at + 1}\t{new}")' 'added.append(f"{name}\t{new}")' \
  'done.append(f"{name}\t{lines[h]}\t{new}")' 'done.append(name)'
probe R6 'mk; rm -rf "$T/drafts"; mkdir -p "$T/drafts"; printf '"'"'block: 2026-11-07 세션\nline: %s\n'"'"' "$LINE" > "$T/drafts/s1.lease"; PTY_BEFORE_TYPE="printf '"'"'block: 2026-11-07 세션\\nline: %s\\n'"'"' '"'"'$L2'"'"' > '"'"'$T/drafts/s1.lease'"'"'" ptyrun @AUTO@ env -u CLAUDECODE bash "$M" apply "$T/drafts/s1.lease" >/dev/null 2>&1; [ -f "$T/drafts/s1.lease" ]' \
  '= "$dsnap" ]; then mark_applied' '= "$dsnap" ] || true; then mark_applied'
probe R7 'mkq; printf '"'"'block: 없는 절\nline: %s\n'"'"' "$LINE" > "$T/drafts/victim.lease"; rm -f "$T/drafts/a4.lease"; printf '"'"'block: 2026-11-07 세션\nline: %s\n'"'"' "$L2" > "$T/drafts/x"$'"'"'\n'"'"'"MOVE"$'"'"'\t'"'"'"victim.lease"$'"'"'\t'"'"'"$(shasum -a 256 "$T/drafts/victim.lease" | cut -c1-64)"$'"'"'\t'"'"'"j.lease"; ptyrun @AUTO@ env -u CLAUDECODE bash "$M" apply-all >/dev/null 2>&1; [ -f "$T/drafts/victim.lease" ]' \
  'case "${f##*/}" in *[!A-Za-z0-9._-]*)' 'case "${f##*/}" in __never__)'
echo "W1–W2 default paths: a worktree drafts into the MAIN checkout's queue (2026-11-10)"
wt_draft() {  # $1 script · $2 dir to run from → prints the draft path it wrote
  ( cd "$2" && env -u FH_LEASE_FILE -u FH_LEASE_DRAFT_DIR CLAUDE_PROJECT_DIR="$2" bash "$1" draft --block x --line "추가 utterance w" 2>/dev/null \
      | sed -n 's/^draft written: //p' )
}
G="$T/hubrepo"; mkdir -p "$G" && git -C "$G" init -q && git -C "$G" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init \
  && git -C "$G" worktree add -q "$T/hubwt" 2>/dev/null
if [ -d "$T/hubwt" ]; then
  GP="$(cd "$G" && pwd -P)"; WP="$(cd "$T/hubwt" && pwd -P)"
  d1="$(wt_draft "$PWD/$S" "$WP")"; d1p="$(cd "$(dirname "$d1")" 2>/dev/null && pwd -P)"
  [ "$d1p" = "$GP/tracks/_meta/lease_drafts" ] && ok "W1 worktree → main checkout's queue" || ko "W1 wrote to «${d1p}», want $GP/tracks/_meta/lease_drafts"
  d2="$(wt_draft "$PWD/$S" "$GP")"; d2p="$(cd "$(dirname "$d2")" 2>/dev/null && pwd -P)"
  [ "$d2p" = "$GP/tracks/_meta/lease_drafts" ] && ok "W2 control: the main checkout itself → its own queue" || ko "W2 wrote to «${d2p}»"
  SA="$PWD/$S"; printf '%s\n' "## 2026-11-07 세션" "제외        x" > "$G/CLAUDE.local.md"
  printf 'block: 2026-11-07 세션\nline: 추가 utterance w3\n' > "$T/w3.lease"
  ( cd "$WP" && env -u FH_LEASE_FILE -u FH_LEASE_DRAFT_DIR CLAUDE_PROJECT_DIR="$WP" bash "$SA" check "$T/w3.lease" >/dev/null 2>&1 ) \
    && ok "W3 the lease default is the main checkout's file too" || ko "W3 check from the worktree did not find the main lease"
  M="$T/m_w.sh"; python3 - "$S" "$M" <<'PY'
import sys
s = open(sys.argv[1], encoding="utf-8").read()
f = '[ -n "$_main" ] && [ "$_bare" -eq 0 ] && [ -e "$_main/.git" ] && HUB="$_main"'
if s.count(f) != 1: sys.exit(1)
open(sys.argv[2], "w", encoding="utf-8").write(s.replace(f, ':'))
PY
  if [ $? -ne 0 ] || cmp -s "$S" "$M"; then ko "R8 mutation did not apply (HARNESS-ERROR)"
  else d3="$(wt_draft "$M" "$WP")"; d3p="$(cd "$(dirname "$d3")" 2>/dev/null && pwd -P)"
    [ "$d3p" = "$WP/tracks/_meta/lease_drafts" ] && ok "R8 mapping off → the worktree's own queue (W1 would be red)" || ko "R8 mutant wrote to «${d3p}»"; fi
  S2="$T/sep"; mkdir -p "$S2" && git -C "$S2" init -q --separate-git-dir="$T/sepmeta.git" && git -C "$S2" -c user.email=t@t -c user.name=t commit -q --allow-empty -m i \
    && git -C "$S2" worktree add -q "$T/sepwt" 2>/dev/null
  if [ -d "$T/sepwt" ]; then SP2="$(cd "$S2" && pwd -P)"
    d4="$(wt_draft "$PWD/$S" "$(cd "$T/sepwt" && pwd -P)")"; d4p="$(cd "$(dirname "$d4")" 2>/dev/null && pwd -P)"
    SW="$(cd "$T/sepwt" && pwd -P)"
    # git cannot name the main checkout from here (it reports the metadata dir) — the script must stay put, not
    # write into the metadata dir. Named residual: this layout still drafts into the worktree's own queue.
    [ "$d4p" = "$SW/tracks/_meta/lease_drafts" ] && ok "W4 --separate-git-dir worktree → stays local, never the metadata dir" || ko "W4 wrote to «${d4p}»"
  else ko "W4 HARNESS-ERROR: separate-git-dir fixture"; fi
  M9="$T/m_w9.sh"; python3 - "$S" "$M9" <<'PY'
import sys
s = open(sys.argv[1], encoding="utf-8").read()
f = '[ -e "$_main/.git" ] && HUB="$_main"'
if s.count(f) != 1: sys.exit(1)
open(sys.argv[2], "w", encoding="utf-8").write(s.replace(f, '[ -d "$_main" ] && HUB="$_main"'))
PY
  if [ $? -ne 0 ] || cmp -s "$S" "$M9" || [ ! -d "$T/sepwt" ]; then ko "R9 mutation did not apply (HARNESS-ERROR)"
  else d9="$(wt_draft "$M9" "$(cd "$T/sepwt" && pwd -P)")"; d9p="$(cd "$(dirname "$d9")" 2>/dev/null && pwd -P)"
    [ "$d9p" = "$(cd "$T/sepmeta.git" && pwd -P)/tracks/_meta/lease_drafts" ] && ok "R9 checkout test off → writes into the metadata dir (W4 would be red)" || ko "R9 mutant wrote to «${d9p}»"; fi
else ko "W1 HARNESS-ERROR: could not build a repo + worktree fixture"; fi
echo "lease_line_apply lanes: $pass passed · $fail failed"
[ "$fail" -eq 0 ]

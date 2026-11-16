#!/usr/bin/env bash
# test_agy_remote_run_lanes.sh — lanes for scripts/agy_remote_run.sh (agy only as a remote OS user).
#
# HOW. A fake `ssh`/`scp` pair stands in for the remote machine: a temp folder is the remote user's
# home, and the three PowerShell scripts the runner sends (canary.ps1 · run.ps1 · cleanup.ps1) are
# EMULATED by the fake ssh, not executed. A fake agy records that it started. No network, no real agy.
# WHAT IS CHECKED: the local half — refusal without a target or a fresh PASS receipt, refusal on a
# changed setting, no local fallback when the route is down, argument and file transport, exit codes,
# and that only the run's own work folder is removed.
# WHAT IS NOT CHECKED: the PowerShell scripts themselves (no PowerShell here) — they were run for real
# against a Windows remote on 2026-11-16 (canary PASS 6/6, one agy round trip); and whether the remote
# OS user is really isolated (that is what --canary measures, on the day it runs).
# Usage: bash scripts/test_agy_remote_run_lanes.sh      Exit: 0 all pass · 1 any fail
set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
RUN="$REPO/scripts/agy_remote_run.sh"
GUARD="$REPO/scripts/agy_launch_guard.sh"
D="$(mktemp -d "${TMPDIR:-/tmp}/agyremote.XXXXXX")" || { echo "ENV-BLOCKED: mktemp failed — unmeasured, not a pass"; exit 1; }
trap 'rm -rf "$D"' EXIT
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ✅ $1"; }
bad() { FAIL=$((FAIL+1)); echo "  ❌ $1"; }
RH="$D/rhome"; mkdir -p "$RH" "$D/bin"

# ── fake remote ────────────────────────────────────────────────────────────────────────────────────
cat > "$D/bin/fake_ssh" <<EOF
#!/usr/bin/env bash
RH="$RH"; D="$D"
[ "\${FAKE_SSH_DOWN:-0}" = 1 ] && exit 255
while [ \$# -gt 0 ] && [ "\$1" = -o ]; do shift 2; done
shift   # target
cmd="\$*"
case "\$cmd" in
  "mkdir "*) mkdir "\$RH/\${cmd#mkdir }" ;;
  powershell*-File*) f="\${cmd##*-File }"; wd="\${f%%\\\\*}"; sc="\${f##*\\\\}"; W="\$RH/\$wd"
    case "\$sc" in
      canary.ps1) while IFS= read -r p; do
                    if grep -qxF -- "\$p" "\$D/readable" 2>/dev/null; then echo "DENY-FAIL \$p"; else echo "DENY-OK \$p (UnauthorizedAccessException)"; fi
                  done < "\$W/deny.txt"
                  [ "\${FAKE_POS_FAIL:-0}" = 1 ] && echo POS-FAIL || echo POS-OK ;;
      run.ps1) ( cd "\$W" && args=(); while IFS= read -r a; do [ -n "\$a" ] && args+=("\$a"); done < args.txt
                 "\$D/fake_agy" -p "\$(cat prompt.txt)" \${args[@]+"\${args[@]}"} --settings "\$W/settings.json"; echo "AGY_RC=\$?" ) ;;
      cleanup.ps1) n="\$wd"
                   if ! printf '%s' "\$n" | grep -Eq '^fh_agy_[0-9]{14}_[0-9a-f]{6}$'; then echo "CLEANUP-REFUSED \$n"; exit 3; fi
                   [ "\${FAKE_CLEANUP_FAIL:-0}" = 1 ] && { echo CLEANUP-FAILED; exit 5; }
                   rm -rf "\$W"; echo CLEANUP-OK ;;
    esac ;;
  *) echo "fake_ssh: unexpected command: \$cmd" >&2; exit 99 ;;
esac
EOF
cat > "$D/bin/fake_scp" <<EOF
#!/usr/bin/env bash
RH="$RH"
args=(); while [ \$# -gt 0 ]; do case "\$1" in -q) shift ;; -o) shift 2 ;; *) args+=("\$1"); shift ;; esac; done
dst="\${args[\${#args[@]}-1]}"; unset 'args[\${#args[@]}-1]'
case "\$dst" in
  *:*) for s in "\${args[@]}"; do cp "\$s" "\$RH/\${dst#*:}" || exit 1; done ;;
  *)   for s in "\${args[@]}"; do cp "\$RH/\${s#*:}" "\$dst" || exit 1; done ;;
esac
EOF
cat > "$D/fake_agy" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" > "$D/agy_argv"
echo "fake-output" > out.txt
echo "FAKE-AGY-RAN"
exit \${FAKE_AGY_RC:-0}
EOF
# a recording `agy` on PATH: if the runner ever fell back to a local agy, this would record it
printf '#!/usr/bin/env bash\n: > "%s/local_agy_ran"\n' "$D" > "$D/bin/agy"
chmod +x "$D/bin/fake_ssh" "$D/bin/fake_scp" "$D/fake_agy" "$D/bin/agy"
export PATH="$D/bin:$PATH" FH_AGY_REMOTE_SSH="$D/bin/fake_ssh" FH_AGY_REMOTE_SCP="$D/bin/fake_scp"
export FH_AGY_REMOTE_RECEIPT_DIR="$D/receipts"
DENY='C:\Users\admin;C:\Users\Public;D:\'
leftover() { find "$RH" -mindepth 1 -maxdepth 1 -name 'fh_agy_*' | wc -l | tr -d ' '; }
run() { out=$("$@" 2>"$D/err" </dev/null); rc=$?; err=$(cat "$D/err"); }

echo "── refusals before any canary"
run env -u FH_AGY_REMOTE bash "$RUN" -p hi
[ "$rc" -eq 3 ] && printf '%s' "$err" | grep -q AGY-REMOTE-REFUSED && ok "R1 no FH_AGY_REMOTE: rc=3 refused" || bad "R1 no target: rc=$rc"
export FH_AGY_REMOTE=user@remote FH_AGY_REMOTE_DENY="$DENY"
run bash "$RUN" -p hi
[ "$rc" -eq 3 ] && printf '%s' "$err" | grep -q 'no canary receipt' && ok "R2 no receipt: rc=3 refused" || bad "R2 no receipt: rc=$rc err=${err:0:100}"
run env FH_AGY_REMOTE_DENY= bash "$RUN" --canary
[ "$rc" -eq 2 ] && ok "R3 canary with an empty deny list: rc=2" || bad "R3 empty deny canary: rc=$rc"

echo "── canary"
: > "$D/readable"
run bash "$RUN" --canary
R="$(ls "$D"/receipts/receipt_*.txt 2>/dev/null | head -1)"
if [ "$rc" -eq 0 ] && grep -qx 'verdict=PASS' "$R" && grep -qx 'denied=3/3' "$R" && [ "$(leftover)" = 0 ]; then ok "R4 canary all denied: PASS 3/3, receipt written, remote folder removed"
else bad "R4 canary PASS: rc=$rc receipt=$(head -4 "$R" 2>/dev/null | tr '\n' ' ') left=$(leftover)"; fi
printf 'C:\\Users\\Public\n' > "$D/readable"
run bash "$RUN" --canary
[ "$rc" -eq 1 ] && grep -qx 'verdict=FAIL' "$R" && ok "R5 canary with one readable path: FAIL rc=1" || bad "R5 canary readable: rc=$rc"
run bash "$RUN" -p hi
[ "$rc" -eq 3 ] && printf '%s' "$err" | grep -q 'did not pass' && ok "R6 run after a FAIL receipt: rc=3 refused" || bad "R6 run after FAIL: rc=$rc"
: > "$D/readable"
run env FAKE_POS_FAIL=1 bash "$RUN" --canary
[ "$rc" -eq 1 ] && grep -qx 'positive=FAIL' "$R" && ok "R7 canary whose positive control fails: FAIL" || bad "R7 positive fail: rc=$rc"
run bash "$RUN" --canary
[ "$rc" -eq 0 ] && ok "R8 canary PASS again (for the run lanes)" || bad "R8 canary PASS again: rc=$rc"

echo "── run"
printf 'frozen input\n' > "$D/in.txt"
rm -f "$D/agy_argv"
run bash "$RUN" --input "$D/in.txt" --fetch out.txt --fetch-dir "$D/back" -p "two words prompt" --model m1 --output-format text
argv="$(tr '\n' '|' < "$D/agy_argv" 2>/dev/null)"
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q FAKE-AGY-RAN && [ "$(cat "$D/back/out.txt" 2>/dev/null)" = fake-output ] \
   && printf '%s' "$argv" | grep -q '^-p|two words prompt|--model|m1|--output-format|text|--settings|' && [ "$(leftover)" = 0 ]; then
  ok "R9 run: prompt and flags intact, --settings added, fetched file back, remote folder removed"
else bad "R9 run: rc=$rc argv=$argv left=$(leftover) err=${err:0:120}"; fi
run env FAKE_AGY_RC=7 bash "$RUN" -p hi
[ "$rc" -eq 1 ] && printf '%s' "$err" | grep -q 'AGY_RC=7' && ok "R10 remote agy rc 7: runner rc=1 with AGY_RC=7" || bad "R10 agy rc: rc=$rc err=${err:0:80}"
run env FAKE_CLEANUP_FAIL=1 bash "$RUN" -p hi
[ "$rc" -eq 5 ] && ok "R11 cleanup not confirmed: rc=5" || bad "R11 cleanup fail: rc=$rc"
rm -rf "$RH"/fh_agy_*
run env FAKE_SSH_DOWN=1 bash "$RUN" -p hi
[ "$rc" -eq 4 ] && printf '%s' "$err" | grep -q 'not falling back' && ok "R12 route down: rc=4, says it does not fall back" || bad "R12 route down: rc=$rc"
printf 'x' > "$D/bad name.txt"
run bash "$RUN" --input "$D/bad name.txt" -p hi
[ "$rc" -eq 2 ] && ok "R13 input name with a space: rc=2" || bad "R13 bad name: rc=$rc"
mkdir -p "$D/other"; cp "$D/in.txt" "$D/other/in.txt"
run bash "$RUN" --input "$D/in.txt" --input "$D/other/in.txt" -p hi
[ "$rc" -eq 2 ] && ok "R14 two inputs with one name: rc=2" || bad "R14 duplicate: rc=$rc"
run bash "$RUN" -p hi --settings x.json
[ "$rc" -eq 2 ] && ok "R15 caller --settings: rc=2 (the runner owns it)" || bad "R15 settings: rc=$rc"

echo "── receipt freshness and settings"
R="$(ls "$D"/receipts/receipt_*.txt | head -1)"
sed -i.bak 's/^epoch=.*/epoch=1000/' "$R"
run bash "$RUN" -p hi
[ "$rc" -eq 3 ] && printf '%s' "$err" | grep -q 'older than 7 days' && ok "R16 receipt older than 7 days: rc=3" || bad "R16 stale: rc=$rc"
run bash "$RUN" --canary
run env FH_AGY_REMOTE_DENY='C:\Users\admin' bash "$RUN" -p hi
[ "$rc" -eq 3 ] && printf '%s' "$err" | grep -q 'no canary receipt' && ok "R17 deny list changed since the canary: rc=3 (new settings, no receipt)" || bad "R17 changed: rc=$rc"
cp "$R" "$D/receipts/receipt_$(printf '%s\n%s\n%s\n' user@remote 'C:\Users\admin' '%LOCALAPPDATA%\agy\bin\agy.exe' | shasum -a 256 | cut -c1-16).txt"
run env FH_AGY_REMOTE_DENY='C:\Users\admin' bash "$RUN" -p hi
[ "$rc" -eq 3 ] && printf '%s' "$err" | grep -q 'different settings' && ok "R18 receipt copied under another name: rc=3 (hash inside does not match)" || bad "R18 copied receipt: rc=$rc err=${err:0:80}"

echo "── through the guard"
run env FH_AGY_ISOLATION=remote-os-user bash "$GUARD" "$RUN" -p hi
[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q FAKE-AGY-RAN && ok "R19 guard + remote-os-user + this runner: runs" || bad "R19 guard route: rc=$rc err=${err:0:100}"
run env -u FH_AGY_ISOLATION bash "$GUARD" "$RUN" -p hi
[ "$rc" -eq 3 ] && ok "R20 guard without the marker: refused even for this runner" || bad "R20 guard no marker: rc=$rc"

[ ! -e "$D/local_agy_ran" ] && ok "R21 no lane started a local agy" || bad "R21 a local agy was started"
echo
echo "agy remote run lanes: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]

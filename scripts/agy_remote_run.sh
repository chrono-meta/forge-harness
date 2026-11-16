#!/usr/bin/env bash
# agy_remote_run.sh — an agy stand-in that runs agy ONLY as a separate OS user on another machine.
#
# WHY. agy runs its own shell and file tools and sends what they print to the cloud model, so it must
# not run where company repositories are readable (scripts/agy_launch_guard.sh). This runner never
# starts agy locally: it copies the prompt and the frozen inputs into a fresh work folder in the remote
# user's home, runs agy there, streams its output back, copies requested files back, and removes only
# that work folder. If the route is not available it REFUSES — it never falls back to a local agy.
#
# REMOTE. A Windows machine reached by OpenSSH, logged in as a non-admin user whose profile cannot read
# the other profiles (measure that with --canary; do not assume it). agy installed for that user
# (default %LOCALAPPDATA%\agy\bin\agy.exe). Configuration comes only from the environment — this public
# file names no host, account or path:
#   FH_AGY_REMOTE        ssh target, e.g. user@host                       (required)
#   FH_AGY_REMOTE_DENY   ;-separated remote paths the user must NOT read  (required for --canary); only an
#                        access-denied error counts, unless the entry starts with ? (then not-found is accepted too)
#   FH_AGY_REMOTE_AGY    remote agy path        (default: %LOCALAPPDATA%\agy\bin\agy.exe)
#   FH_AGY_REMOTE_RECEIPT_DIR  local receipt folder (default: $HOME/.cache/fh-agy-remote — outside any repo)
#
# CANARY. `agy_remote_run.sh --canary` runs NO agy. As the remote user it tries to list or open every
# FH_AGY_REMOTE_DENY path (each must be refused) and reads a file it writes in a fresh work folder (must
# succeed), then writes a local receipt: receipt_<first 16 of sha256(target, deny list, agy path)>.txt
# with key=value lines (verdict, target_sha, epoch, denied=N/N, positive) and one line per path.
# A run is refused unless that receipt says PASS, is under 7 days old and matches the current settings.
# 🟥 The receipt records this script's own measurement on the day it ran; it is not proof of isolation.
# 🟥 A deny on a drive or folder root does NOT override an explicit allow entry on a sub-item: on the
#    operator's machine (2026-11-16) the remote user could still list or open 8 such sub-items (game
#    folders, the recycle bins, an antivirus decoy folder, three device-information files), which the
#    operator accepted. The canary only measures the paths you list — list a sub-item only after you
#    have denied it explicitly, and name the accepted ones where you record the receipt.
#
# USAGE (agy-compatible; extra flags are this runner's own and are not passed to agy):
#   agy_remote_run.sh [--input <file>]... [--fetch <name>]... [--fetch-dir <dir>] -p "<prompt>" [agy flags...]
#   agy_remote_run.sh --canary
# Inputs are copied under their own names ([A-Za-z0-9._-] only, no duplicates). The remote agy gets
# `--settings` limiting it to its workspace (allowNonWorkspaceAccess=false); the OS user is the barrier.
# Through FH's scripts: FH_AGY_BIN=<repo>/scripts/agy_remote_run.sh FH_AGY_ISOLATION=remote-os-user.
#
# EXIT: 0 ok · 1 remote agy exited non-zero (AGY_RC=<n> on stderr) · 2 usage · 3 refused (no target,
#       no/stale/FAIL/mismatched receipt) · 4 route unavailable (ssh/scp failed) · 5 cleanup not verified
#       --canary: 0 PASS · 1 FAIL · 2 usage · 4 route unavailable
set -uo pipefail
SSH=ssh; SCP=scp   # by name from PATH; there is no override (the lanes put fakes first on PATH)
die() { echo "agy_remote_run: $2" >&2; exit "$1"; }
TARGET="${FH_AGY_REMOTE-}"
[ -n "$TARGET" ] || die 3 "AGY-REMOTE-REFUSED: FH_AGY_REMOTE is not set — refusing (agy is never started locally)"
case "$TARGET" in *[!A-Za-z0-9@._-]*) die 2 "FH_AGY_REMOTE must look like user@host" ;; esac
RAGY="${FH_AGY_REMOTE_AGY:-%LOCALAPPDATA%\\agy\\bin\\agy.exe}"
case "$RAGY" in *[!A-Za-z0-9%\\:._\ -]*) die 2 "FH_AGY_REMOTE_AGY may contain only letters, digits, % \\ : . _ - and spaces" ;; esac
DENY="${FH_AGY_REMOTE_DENY-}"
RDIR="${FH_AGY_REMOTE_RECEIPT_DIR:-$HOME/.cache/fh-agy-remote}"
case "$DENY$RAGY" in *$'\n'*|*$'\r'*) die 2 "FH_AGY_REMOTE_DENY / FH_AGY_REMOTE_AGY must not contain line breaks" ;; esac
# length-prefixed fields: no two different settings can produce the same hashed text
TSHA="$(printf 'v1|%d:%s|%d:%s|%d:%s' "${#TARGET}" "$TARGET" "${#DENY}" "$DENY" "${#RAGY}" "$RAGY" | shasum -a 256 2>/dev/null | cut -c1-64)"
printf '%s' "$TSHA" | grep -Eq '^[0-9a-f]{64}$' || die 4 "could not compute the settings hash (shasum) — refusing"
RECEIPT="$RDIR/receipt_${TSHA:0:16}.txt"
SSHO=(-o BatchMode=yes -o ConnectTimeout=15)
WD="fh_agy_$(date +%Y%m%d%H%M%S)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' \n')"
LOCAL="$(mktemp -d "${TMPDIR:-/tmp}/fh_agy_remote.XXXXXX")" || die 4 "cannot create a local temp folder"
trap 'rm -rf "$LOCAL"' EXIT

remote_mkdir() { "$SSH" "${SSHO[@]}" "$TARGET" "mkdir $WD" </dev/null >/dev/null 2>&1; }
remote_put() { "$SCP" -q "${SSHO[@]}" "$@" "$TARGET:$WD/" </dev/null >/dev/null 2>&1; }
remote_ps() { "$SSH" "${SSHO[@]}" "$TARGET" "powershell -NoProfile -ExecutionPolicy Bypass -File $WD\\$1" </dev/null; }
remote_cleanup() { # only the folder this run created; the remote script re-checks the name and parent
  cat > "$LOCAL/cleanup.ps1" <<'PS'
$n = Split-Path -Leaf $PSScriptRoot
$parent = Split-Path -Parent $PSScriptRoot
if ($n -notmatch '^fh_agy_[0-9]{14}_[0-9a-f]{6}$' -or $parent -ne $env:USERPROFILE) { "CLEANUP-REFUSED $n"; exit 3 }
Set-Location $env:USERPROFILE; Remove-Item -LiteralPath $PSScriptRoot -Recurse -Force
if (Test-Path -LiteralPath $PSScriptRoot) { "CLEANUP-FAILED"; exit 5 } else { "CLEANUP-OK" }
PS
  remote_put "$LOCAL/cleanup.ps1" || return 5
  remote_ps cleanup.ps1 2>/dev/null | tr -d '\r' | grep -q '^CLEANUP-OK$' || return 5
  return 0
}

if [ "${1-}" = "--canary" ]; then
  [ $# -eq 1 ] || die 2 "--canary takes no other arguments"
  [ -n "$DENY" ] || die 2 "FH_AGY_REMOTE_DENY is empty — a canary with nothing to deny measures nothing"
  printf '%s\n' "$DENY" | tr ';' '\n' | sed '/^$/d' > "$LOCAL/deny.txt"
  cat > "$LOCAL/canary.ps1" <<'PS'
foreach ($p in Get-Content -LiteralPath (Join-Path $PSScriptRoot 'deny.txt')) {
  $absentOk = $p.StartsWith('?'); if ($absentOk) { $p = $p.Substring(1) }
  try { $i = Get-Item -LiteralPath $p -Force -ErrorAction Stop
        if ($i.PSIsContainer) { [void](Get-ChildItem -LiteralPath $p -Force -ErrorAction Stop) } else { [IO.File]::OpenRead($p).Close() }
        "DENY-FAIL $p (readable)" }
  catch { $e = $_.Exception.GetType().Name
          if ($e -match 'UnauthorizedAccess' -or ($absentOk -and $e -match 'NotFound')) { "DENY-OK $p ($e)" }
          else { "DENY-FAIL $p (not measured: $e)" } } }
$f = Join-Path $PSScriptRoot 'positive.txt'; Set-Content -LiteralPath $f -Value 'FH-POSITIVE'
try { if ((Get-Content -LiteralPath $f -Raw).Trim() -eq 'FH-POSITIVE') { 'POS-OK' } else { 'POS-FAIL' } } catch { 'POS-FAIL' }
PS
  remote_mkdir || die 4 "AGY-REMOTE-UNAVAILABLE: cannot reach $TARGET (mkdir failed)"
  remote_put "$LOCAL/deny.txt" "$LOCAL/canary.ps1" || { remote_cleanup; die 4 "AGY-REMOTE-UNAVAILABLE: copy to $TARGET failed"; }
  out="$(remote_ps canary.ps1 2>&1)"; prc=$?; out="$(printf '%s' "$out" | tr -d '\r')"
  remote_cleanup; crc=$?
  want=$(grep -c '' "$LOCAL/deny.txt")
  ok=$(printf '%s\n' "$out" | grep -c '^DENY-OK ')
  bad=$(printf '%s\n' "$out" | grep -c '^DENY-FAIL ')
  pos=$(printf '%s\n' "$out" | grep -q '^POS-OK$' && echo READ || echo FAIL)
  verdict=FAIL; [ "$ok" -eq "$want" ] && [ "$bad" -eq 0 ] && [ "$pos" = READ ] && [ "$want" -gt 0 ] && [ "$crc" -eq 0 ] && [ "$prc" -eq 0 ] && verdict=PASS
  mkdir -p "$RDIR" || die 4 "cannot create $RDIR"
  { echo "verdict=$verdict"; echo "target_sha=$TSHA"; echo "epoch=$(date +%s)"; echo "denied=$ok/$want"
    echo "positive=$pos"; echo "cleanup=$([ "$crc" -eq 0 ] && echo OK || echo UNVERIFIED)"
    printf '%s\n' "$out" | grep -E '^(DENY-OK|DENY-FAIL|POS-OK|POS-FAIL)'; } > "$RECEIPT.tmp" && mv "$RECEIPT.tmp" "$RECEIPT" \
    || die 4 "could not write the receipt $RECEIPT — the canary result is not recorded"
  echo "AGY-REMOTE-CANARY $verdict denied=$ok/$want positive=$pos receipt=$RECEIPT"
  [ "$verdict" = PASS ] && exit 0 || exit 1
fi

# ── run mode: receipt first, then the route ───────────────────────────────────────────────────────
[ -f "$RECEIPT" ] || die 3 "AGY-REMOTE-REFUSED: no canary receipt for these settings — run: agy_remote_run.sh --canary"
r_get() { sed -n "s/^$1=//p" "$RECEIPT" | head -1; }
[ "$(r_get verdict)" = PASS ] || die 3 "AGY-REMOTE-REFUSED: the last canary did not pass ($RECEIPT)"
[ "$(r_get target_sha)" = "$TSHA" ] || die 3 "AGY-REMOTE-REFUSED: receipt is for different settings"
age=$(( $(date +%s) - $(r_get epoch | grep -E '^[0-9]+$' || echo 0) ))
[ "$age" -le 604800 ] || die 3 "AGY-REMOTE-REFUSED: canary receipt is older than 7 days — run --canary again"

PROMPT=""; HAVEP=0; INPUTS=(); FETCH=(); FDIR=""; PASS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --input) [ $# -ge 2 ] || die 2 "--input needs a file"; INPUTS+=("$2"); shift 2 ;;
    --fetch) [ $# -ge 2 ] || die 2 "--fetch needs a name"; FETCH+=("$2"); shift 2 ;;
    --fetch-dir) [ $# -ge 2 ] || die 2 "--fetch-dir needs a folder"; FDIR="$2"; shift 2 ;;
    -p|--print|--prompt) [ $# -ge 2 ] || die 2 "$1 needs a prompt"; PROMPT="$2"; HAVEP=1; shift 2 ;;
    --settings) die 2 "--settings is set by this runner (workspace-only); remove it" ;;
    *) case "$1" in *$'\n'*) die 2 "an agy argument contains a newline" ;; esac; PASS+=("$1"); shift ;;
  esac
done
[ "$HAVEP" -eq 1 ] || die 2 "a prompt is required (-p)"
[ "${#FETCH[@]}" -eq 0 ] || [ -n "$FDIR" ] || die 2 "--fetch needs --fetch-dir"
seen=" "
for f in ${INPUTS[@]+"${INPUTS[@]}"} ${FETCH[@]+"${FETCH[@]}"}; do
  b="$(basename "$f")"
  lb="$(printf '%s' "$b" | tr 'A-Z' 'a-z')"   # Windows names are case-insensitive
  case "$b" in ''|*[!A-Za-z0-9._-]*) die 2 "file name not allowed: $b" ;; esac
  case "$lb" in prompt.txt|args.txt|settings.json|run.ps1|cleanup.ps1|agy_path.txt|canary.ps1|deny.txt) die 2 "file name reserved by the runner: $b" ;; esac
done
for f in ${INPUTS[@]+"${INPUTS[@]}"}; do
  [ -f "$f" ] || die 2 "input not found: $f"
  b="$(basename "$f" | tr 'A-Z' 'a-z')"; case "$seen" in *" $b "*) die 2 "two inputs share the name $b (Windows ignores case)" ;; esac; seen="$seen$b "
done
printf '%s' "$PROMPT" > "$LOCAL/prompt.txt"
: > "$LOCAL/args.txt"; for a in ${PASS[@]+"${PASS[@]}"}; do printf '%s\n' "$a" >> "$LOCAL/args.txt"; done
printf '{"toolPermission":"always-proceed","allowNonWorkspaceAccess":false}\n' > "$LOCAL/settings.json"
printf '%s' "$RAGY" > "$LOCAL/agy_path.txt"
cat > "$LOCAL/run.ps1" <<'PS'
Set-Location $PSScriptRoot
$p = Get-Content -LiteralPath 'prompt.txt' -Raw -Encoding UTF8
$a = @(Get-Content -LiteralPath 'args.txt' -Encoding UTF8 | Where-Object { $_ -ne '' })
$agy = [Environment]::ExpandEnvironmentVariables((Get-Content -LiteralPath 'agy_path.txt' -Raw -Encoding UTF8).Trim())
& $agy -p $p @a --settings (Join-Path $PSScriptRoot 'settings.json')
# printed after agy has exited: the runner trusts only the LAST line, which agy's output cannot follow
"FH_AGY_RC=$LASTEXITCODE"
PS
remote_mkdir || die 4 "AGY-REMOTE-UNAVAILABLE: cannot reach $TARGET (mkdir failed) — not falling back to a local agy"
remote_put "$LOCAL/prompt.txt" "$LOCAL/args.txt" "$LOCAL/settings.json" "$LOCAL/agy_path.txt" "$LOCAL/run.ps1" ${INPUTS[@]+"${INPUTS[@]}"} \
  || { remote_cleanup; die 4 "AGY-REMOTE-UNAVAILABLE: copy to $TARGET failed"; }
remote_ps run.ps1 > "$LOCAL/out.txt" 2> "$LOCAL/err.txt"; src=$?
tr -d '\r' < "$LOCAL/out.txt" | sed '$ { /^FH_AGY_RC=/d; }'; tr -d '\r' < "$LOCAL/err.txt" >&2
last="$(tr -d '\r' < "$LOCAL/out.txt" | sed '/^$/d' | tail -1)"
arc="$(printf '%s' "$last" | sed -n 's/^FH_AGY_RC=\(-\{0,1\}[0-9][0-9]*\)$/\1/p')"
frc=0
for n in ${FETCH[@]+"${FETCH[@]}"}; do
  mkdir -p "$FDIR" && "$SCP" -q "${SSHO[@]}" "$TARGET:$WD/$n" "$FDIR/" </dev/null >/dev/null 2>&1 || { echo "agy_remote_run: could not fetch $n" >&2; frc=4; }
done
remote_cleanup || { echo "agy_remote_run: remote work folder $WD not confirmed removed" >&2; exit 5; }
[ "$src" -eq 0 ] || { echo "agy_remote_run: ssh exited $src — route failed" >&2; exit 4; }
[ -n "$arc" ] || { echo "agy_remote_run: no exit code came back from the remote side — route failed" >&2; exit 4; }
[ "$frc" -eq 0 ] || exit 4
[ "$arc" = 0 ] && exit 0
echo "AGY_RC=$arc" >&2; exit 1

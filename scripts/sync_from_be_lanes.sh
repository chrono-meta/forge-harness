#!/usr/bin/env bash
# sync_from_be_lanes.sh — mechanical regression lanes for scripts/sync-from-be.sh
#
# WHY: every fix in the return path closed a hole that a REVIEW found, not a test. A prose promise
# that "this is fixed" decays on the next edit; a lane fails. Each lane below reproduces one
# measured defect and asserts it stays closed.
#
# CONTROL DISCIPLINE: a lane that asserts an ABSENCE (nothing pulled, nothing created) is paired
# with a known-positive in the SAME run, so "0 hits" can be distinguished from "the run never
# happened". A suite where every lane passes because nothing executed is the failure mode this
# guards against.
#
# USAGE: bash scripts/sync_from_be_lanes.sh          → runs all lanes, exit 0 = all pass, 1 = any fail
set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/sync-from-be.sh"
[ -f "$SCRIPT" ] || { echo "missing target: $SCRIPT" >&2; exit 10; }
ROOT="$(mktemp -d)"; trap 'rm -rf "$ROOT"' EXIT
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); printf '  ✅ %s\n' "$1"; }
no(){ FAIL=$((FAIL+1)); printf '  ❌ %s\n' "$1"; }
chk(){ if [ "$1" = "0" ]; then ok "$2"; else no "$2"; fi; }

# fresh sandbox; hub dir name is chosen so resolve_mem_dir's glob (<parent>-<hub>) can be satisfied
new_env(){
  ENV_DIR="$ROOT/$1"; rm -rf "$ENV_DIR"
  HUB="$ENV_DIR/hubx"; BEX="$ENV_DIR/be"; FAKEHOME="$ENV_DIR/home"
  MEMD="$FAKEHOME/.claude/projects/-x-$1-hubx/memory"
  mkdir -p "$HUB/tracks/_meta" "$BEX/tracks-meta" "$MEMD"
  printf '# forge-harness — Persistent Knowledge Hub\n' > "$HUB/CLAUDE.md"
}
run(){ HOME="$FAKEHOME" HUB_DIR="$HUB" BE_DIR="$BEX" bash "$SCRIPT" --no-git "$@"; }

echo "── L1 core: pull / skip / classify ──"
new_env l1
printf 'line1\n' > "$HUB/tracks/_meta/p1.md"
printf '<!-- MIRROR COPY — synced from the forge-harness hub. Do NOT edit here; the next sync overwrites it. Edit the canonical file under the hub instead. -->\nline1\nline2\n' > "$BEX/tracks-meta/p1.md"
printf 'same\n' > "$HUB/tracks/_meta/n1.md"; printf 'same\n' > "$BEX/tracks-meta/n1.md"
printf 'old\n' > "$BEX/tracks-meta/n2.md"; sleep 1; printf 'new-hub\n' > "$HUB/tracks/_meta/n2.md"
touch "$BEX/tracks-meta/p1.md" "$BEX/tracks-meta/n1.md"
run >/dev/null 2>&1
[ "$(cat "$HUB/tracks/_meta/p1.md")" = "$(printf 'line1\nline2')" ]; chk $? "positive: newer+different pulled, banner stripped"
[ "$(cat "$HUB/tracks/_meta/n1.md")" = "same" ]; chk $? "negative: identical content not pulled (control: p1 above DID move)"
[ "$(cat "$HUB/tracks/_meta/n2.md")" = "new-hub" ]; chk $? "negative: hub-newer not clobbered"

echo "── L2 backup exists and holds the ORIGINAL bytes ──"
[ "$(find "$HUB/tracks/_meta/logs/sync_restore" -name p1.md -exec cat {} \; 2>/dev/null)" = "line1" ]; chk $? "backup captured pre-overwrite content"

echo "── L3 fail-closed: no backup → no overwrite ──"
new_env l3
printf 'orig\n' > "$HUB/tracks/_meta/f.md"; sleep 1; printf 'newer\n' > "$BEX/tracks-meta/f.md"
mkdir -p "$HUB/tracks/_meta/logs/sync_restore"; chmod 500 "$HUB/tracks/_meta/logs/sync_restore"
if mkdir -p "$HUB/tracks/_meta/logs/sync_restore/_probe" 2>/dev/null; then
  rmdir "$HUB/tracks/_meta/logs/sync_restore/_probe"; no "CONTROL: backup dir writable — lane invalid"
else
  ok "CONTROL: backup dir genuinely unwritable"
  run >/dev/null 2>&1; rc=$?
  [ "$rc" = "10" ]; chk $? "exit 10 (harness error, not a silent pass)"
  [ "$(cat "$HUB/tracks/_meta/f.md")" = "orig" ]; chk $? "hub file untouched when the backup failed"
fi
chmod 700 "$HUB/tracks/_meta/logs/sync_restore"

echo "── L4 machine identity must never cross machines (.fh_node_state) ──"
new_env l4
printf 'peer|1|a\n' > "$BEX/tracks-meta/.fh_node_state"
printf 'ordinary\n'  > "$BEX/tracks-meta/normal.md"
run --include-new >/dev/null 2>&1
[ -f "$HUB/tracks/_meta/normal.md" ]; chk $? "CONTROL: an ordinary new file lands (the run really ran)"
[ ! -f "$HUB/tracks/_meta/.fh_node_state" ]; chk $? "node state not created"
printf 'mine|9|z\n' > "$HUB/tracks/_meta/.fh_node_state"; sleep 1; printf 'peer|1|a\n' > "$BEX/tracks-meta/.fh_node_state"
run --include-new >/dev/null 2>&1
[ "$(cat "$HUB/tracks/_meta/.fh_node_state")" = "mine|9|z" ]; chk $? "node state not overwritten either"

echo "── L5 shared-path machine-scoped files excluded BY NAME ──"
new_env l5
mkdir -p "$BEX/memory"
printf 'peer index\n'    > "$BEX/memory/MEMORY.md"
printf 'peer manifest\n' > "$BEX/tracks-meta/edit_manifest.yaml"
printf 'peer substrate\n' > "$BEX/tracks-meta/.substrate_versions"
printf 'ordinary\n'      > "$BEX/tracks-meta/normal.md"
printf 'mem ordinary\n'  > "$BEX/memory/plain_fact.md"
# Fixture controls: an absence assertion is only evidence if the thing could have appeared.
[ -f "$BEX/memory/MEMORY.md" ] && [ -f "$BEX/tracks-meta/edit_manifest.yaml" ] && [ -f "$BEX/tracks-meta/.substrate_versions" ]; chk $? "CONTROL: all three fixtures exist upstream"
run --include-new >/dev/null 2>&1
[ -f "$HUB/tracks/_meta/normal.md" ]; chk $? "CONTROL: tracks area ran (ordinary file landed)"
[ -f "$MEMD/plain_fact.md" ]; chk $? "CONTROL: memory area ran too (ordinary memory file landed)"
[ ! -f "$HUB/tracks/_meta/edit_manifest.yaml" ]; chk $? "peer edit_manifest.yaml not pulled"
[ ! -f "$MEMD/MEMORY.md" ]; chk $? "peer MEMORY.md not pulled"
[ ! -f "$HUB/tracks/_meta/.substrate_versions" ]; chk $? "peer .substrate_versions not pulled (pmh-dev#69)"

echo "── L6 same-machine return leg DOES restore this machine's own three ──"
new_env l6
mkdir -p "$BEX/tracks-meta/manifests" "$BEX/memory/_index" "$BEX/tracks-meta/substrate"
MID="$(FH_MACHINE_ID=lanetest bash -c 'printf "%s" "$FH_MACHINE_ID"')"
printf 'my manifest\n' > "$BEX/tracks-meta/manifests/$MID.yaml"
printf 'my index\n'    > "$BEX/memory/_index/$MID.md"
printf 'my substrate\n' > "$BEX/tracks-meta/substrate/$MID"
HOME="$FAKEHOME" HUB_DIR="$HUB" BE_DIR="$BEX" FH_MACHINE_ID=lanetest bash "$SCRIPT" --no-git >/dev/null 2>&1
[ "$(cat "$HUB/tracks/_meta/edit_manifest.yaml" 2>/dev/null)" = "my manifest" ]; chk $? "own manifest restored by machine-id match"
[ "$(cat "$MEMD/MEMORY.md" 2>/dev/null)" = "my index" ]; chk $? "own MEMORY.md index restored"
[ "$(cat "$HUB/tracks/_meta/.substrate_versions" 2>/dev/null)" = "my substrate" ]; chk $? "own .substrate_versions restored by machine-id match (pmh-dev#69)"
printf 'other manifest\n' > "$BEX/tracks-meta/manifests/someoneelse.yaml"
printf 'other substrate\n' > "$BEX/tracks-meta/substrate/someoneelse"
HOME="$FAKEHOME" HUB_DIR="$HUB" BE_DIR="$BEX" FH_MACHINE_ID=lanetest bash "$SCRIPT" --no-git >/dev/null 2>&1
[ "$(cat "$HUB/tracks/_meta/edit_manifest.yaml")" = "my manifest" ]; chk $? "a PEER's manifest never lands (control: mine did, above)"
[ "$(cat "$HUB/tracks/_meta/.substrate_versions")" = "my substrate" ]; chk $? "a PEER's substrate record never lands at my own path either (pmh-dev#69)"
# The two assertions above cannot fail even without the substrate/ path exclusion — pull_machine_scoped
# only ever writes to $MID's own path, so a peer's file was never a candidate for landing there. The
# real exclusion the fix added is on the GENERIC bulk-pull (--include-new), which would otherwise
# create a peer's file under its own literal name — test that directly (pmh-dev#69, B1).
HOME="$FAKEHOME" HUB_DIR="$HUB" BE_DIR="$BEX" FH_MACHINE_ID=lanetest bash "$SCRIPT" --no-git --include-new >/dev/null 2>&1
[ ! -f "$HUB/tracks/_meta/substrate/someoneelse" ]; chk $? "a PEER's raw substrate file not bulk-pulled under its own name (pmh-dev#69, real exclusion test)"

echo "── L7 a --quiet run that WRITES must still speak ──"
new_env l7
mkdir -p "$HUB/tracks/_audit" "$BEX/tracks-audit"
printf 'held\n' > "$BEX/tracks-audit/held.md"
run --quiet --include-new=tracks/_meta >/dev/null 2>&1        # prime the held-count marker
printf 'new\n' > "$BEX/tracks-meta/newrec.md"
out="$(run --quiet --include-new=tracks/_meta 2>&1)"
[ -f "$HUB/tracks/_meta/newrec.md" ]; chk $? "CONTROL: the file really was created"
printf '%s' "$out" | grep -q 'created 1 new file'; chk $? "creation announced despite --quiet + unchanged held-count"
out2="$(run --quiet --include-new=tracks/_meta 2>&1)"
[ -z "$out2" ]; chk $? "a genuine no-op is still silent"

echo "── L8 symlink destinations are refused, never written through ──"
new_env l8
printf 'outside\n' > "$ENV_DIR/outside.txt"
ln -s "$ENV_DIR/outside.txt" "$HUB/tracks/_meta/link.md"
sleep 1; printf 'payload\n' > "$BEX/tracks-meta/link.md"; printf 'ordinary\n' > "$BEX/tracks-meta/ok.md"
run --include-new >/dev/null 2>&1
[ -f "$HUB/tracks/_meta/ok.md" ]; chk $? "CONTROL: ordinary file landed"
[ "$(cat "$ENV_DIR/outside.txt")" = "outside" ]; chk $? "symlink target outside the hub not written"

echo "── L9 equal mtime + different content is still pulled (no permanent silent lag) ──"
new_env l9
printf 'hub\n' > "$HUB/tracks/_meta/tie.md"; printf 'companion\n' > "$BEX/tracks-meta/tie.md"
touch -r "$HUB/tracks/_meta/tie.md" "$BEX/tracks-meta/tie.md"
[ ! "$BEX/tracks-meta/tie.md" -nt "$HUB/tracks/_meta/tie.md" ]; chk $? "CONTROL: mtimes are genuinely equal"
run >/dev/null 2>&1
[ "$(cat "$HUB/tracks/_meta/tie.md")" = "companion" ]; chk $? "tie resolved by content, not skipped"

echo "── L10 non-md file keeps its first line even if it says MIRROR COPY ──"
new_env l10
printf 'MIRROR COPY marker line\ndata\n' > "$BEX/tracks-meta/data.txt"
run --include-new >/dev/null 2>&1
[ "$(head -1 "$HUB/tracks/_meta/data.txt" 2>/dev/null)" = "MIRROR COPY marker line" ]; chk $? "non-md first line preserved"

echo "── L11 missing hub dir: surfaced, and created only under --include-new ──"
new_env l11
mkdir -p "$BEX/tracks-audit"; printf 'a\n' > "$BEX/tracks-audit/x.md"
out="$(run 2>&1)"
printf '%s' "$out" | grep -q 'no hub directory'; chk $? "missing area is reported, not silently dropped"
[ ! -d "$HUB/tracks/_audit" ]; chk $? "not created without --include-new"
run --include-new >/dev/null 2>&1
[ -f "$HUB/tracks/_audit/x.md" ]; chk $? "created + populated under --include-new"

echo "── L12 companion mid-rebase → fail-closed, nothing written ──"
new_env l12
printf 'orig\n' > "$HUB/tracks/_meta/g.md"; sleep 1; printf 'newer\n' > "$BEX/tracks-meta/g.md"
( cd "$BEX" && git init -q . && git config user.email t@t && git config user.name t && git add -A >/dev/null 2>&1 && git commit -qm init >/dev/null 2>&1 )
mkdir -p "$BEX/.git/rebase-merge"
[ -d "$BEX/.git/rebase-merge" ]; chk $? "CONTROL: rebase state is actually present"
run >/dev/null 2>&1; rc=$?
[ "$rc" = "10" ]; chk $? "exit 10 on an in-progress companion rebase"
[ "$(cat "$HUB/tracks/_meta/g.md")" = "orig" ]; chk $? "nothing written while the store was mid-rebase"

echo "── L13 exclusion parity — BEHAVIORAL, every entry of scripts/sync_excludes.txt (2026-10-03) ──"
# Was: a whole-file grep for THREE hardcoded names; it passed while `.close_stamps_*` and `vendor/`
# were missing from the return find. Both directions now read scripts/sync_excludes.txt, so this lane
# plants a file named like every entry and asserts none is pulled on a real --include-new run.
# The entries are read here by a DIFFERENT reader (awk, trimming + comment skip) than the production
# loader (sync_excludes_lib.sh), so the lane does not grade the loader with the loader.
SXF="$(dirname "$SCRIPT")/sync_excludes.txt"
L13_EX=()
if [ -f "$SXF" ]; then
  while IFS= read -r _e; do [ -n "$_e" ] && L13_EX+=("$_e"); done <<EOF_L13
$(awk '{ sub(/^[ \t\r]+/, ""); sub(/[ \t\r]+$/, "") } $0 != "" && substr($0,1,1) != "#" { print }' "$SXF")
EOF_L13
fi
if [ "${#L13_EX[@]}" -eq 0 ]; then
  no "INSTRUMENT-ERROR: cannot read entries from $SXF — parity verdict void"
else
  ok "CONTROL: read ${#L13_EX[@]} entries from sync_excludes.txt (instrument alive)"
  _l13_plant(){   # $1 = companion area dir, $2 = entry → prints the planted relative path
    case "$2" in
      */) mkdir -p "$1/l13dir/${2%/}"; printf 'x\n' > "$1/l13dir/${2%/}/inside.md"; printf '%s' "l13dir/${2%/}/inside.md" ;;
      *)  _n="$(printf '%s' "$2" | sed 's/\*/probe/g')"; mkdir -p "$1/l13n"; printf 'x\n' > "$1/l13n/$_n"; printf '%s' "l13n/$_n" ;;
    esac
  }
  new_env l13
  printf 'ordinary\n' > "$BEX/tracks-meta/l13_control.md"
  L13_REL=()
  for _e in "${L13_EX[@]}"; do L13_REL+=("$(_l13_plant "$BEX/tracks-meta" "$_e")"); done
  run --include-new >/dev/null 2>&1
  [ -f "$HUB/tracks/_meta/l13_control.md" ]; chk $? "CONTROL: an ordinary companion file WAS created (the pull really ran)"
  leaked=""
  for _r in "${L13_REL[@]}"; do [ -e "$HUB/tracks/_meta/$_r" ] && leaked="$leaked $_r"; done
  [ -z "$leaked" ]; chk $? "no file named like a sync_excludes.txt entry was pulled (${leaked:-none leaked}; ${#L13_REL[@]} planted)"
fi

# Copies of the production scripts in a scratch dir — the return script is never edited; only the
# DATA file next to it changes. Shared by L13-genericity, L13b and L13d.
_l13_copy(){   # $1 = dir → copies sync-from-be.sh + its two sourced libs (no data file)
  mkdir -p "$1"
  cp "$SCRIPT" "$1/sync-from-be.sh"
  cp "$(dirname "$SCRIPT")/fh_hub_identity.sh" "$(dirname "$SCRIPT")/sync_excludes_lib.sh" "$1/"
}
run_copy(){ local d="$1"; shift; HOME="$FAKEHOME" HUB_DIR="$HUB" BE_DIR="$BEX" bash "$d/sync-from-be.sh" --no-git "$@"; }

echo "── L13g genericity — a name added ONLY to the data file is honored by the UNEDITED return script ──"
SCR="$ROOT/l13scr"; _l13_copy "$SCR"; cp "$SXF" "$SCR/sync_excludes.txt"
new_env l13g
printf 'probe\n' > "$BEX/tracks-meta/zzz_l13_newname"
run_copy "$SCR" --include-new >/dev/null 2>&1
[ -f "$HUB/tracks/_meta/zzz_l13_newname" ]; chk $? "CONTROL: with the ORIGINAL data file, the probe name IS pulled"
printf 'zzz_l13_newname\n' >> "$SCR/sync_excludes.txt"
new_env l13h
printf 'probe\n' > "$BEX/tracks-meta/zzz_l13_newname"
printf 'ordinary\n' > "$BEX/tracks-meta/l13h_control.md"
run_copy "$SCR" --include-new >/dev/null 2>&1
[ -f "$HUB/tracks/_meta/l13h_control.md" ]; chk $? "CONTROL: the copied return script ran"
[ ! -e "$HUB/tracks/_meta/zzz_l13_newname" ]; chk $? "a name appended ONLY to sync_excludes.txt is excluded (no second list)"

echo "── L13b fail-closed: data file or loader absent → refuse (exit 10), pull nothing ──"
SCR2="$ROOT/l13scr2"; _l13_copy "$SCR2"
new_env l13b
printf 'newer\n' > "$BEX/tracks-meta/l13b.md"
_l13b_out="$(run_copy "$SCR2" --include-new 2>/dev/null)"; rc=$?
[ "$rc" = "10" ]; chk $? "data file absent → exit 10 (harness error, not a silent pass) — got rc=$rc"
# The SessionStart hook that runs this script ignores its exit code and drops stderr — only STDOUT
# reaches the session (round 4, agy B: the silent leg was the channel, not the number).
case "$_l13b_out" in *"return sync REFUSED"*) ok "the refusal is on STDOUT (stderr discarded here) — a SessionStart session sees it" ;;
  *) no "the refusal never reached stdout — with stderr dropped, a broken list is silent" ;; esac
[ ! -e "$HUB/tracks/_meta/l13b.md" ]; chk $? "nothing was pulled with an unknown exclusion set"
cp "$SXF" "$SCR2/sync_excludes.txt"; rm -f "$SCR2/sync_excludes_lib.sh"
run_copy "$SCR2" --include-new >/dev/null 2>&1; rc=$?
[ "$rc" = "10" ] && [ ! -e "$HUB/tracks/_meta/l13b.md" ]; chk $? "loader absent → exit 10 and nothing pulled — got rc=$rc"
cp "$(dirname "$SCRIPT")/sync_excludes_lib.sh" "$SCR2/"
run_copy "$SCR2" --include-new >/dev/null 2>&1
[ -f "$HUB/tracks/_meta/l13b.md" ]; chk $? "CONTROL: the same copy WITH both files pulls normally"

echo "── L13d data-file grammar — independent hand-written fixtures (2026-10-03 round 3) ──"
# Verdict is read from BEHAVIOR (exit code + which files landed), never from the loader's own output.
# B-cases include the two round-2 attacks verbatim as data lines: they must be refused as text, never run.
_l13d(){   # $1 = case id, $2 = data-file body (printf %s — write \n yourself) → sets L13D_RC
  local sd="$ROOT/l13d/$1"; _l13_copy "$sd"
  printf '%s' "$2" > "$sd/sync_excludes.txt"
  new_env "l13d_$1"
  printf 'ordinary\n' > "$BEX/tracks-meta/ctl.md"
  printf 'marker\n'   > "$BEX/tracks-meta/.pending"
  run_copy "$sd" --include-new >/dev/null 2>&1
  L13D_RC=$?
}
_l13d_ok(){
  [ "$L13D_RC" = "0" ] && [ -f "$HUB/tracks/_meta/ctl.md" ]; chk $? "$1: accepted (rc=$L13D_RC, control pulled)"
  [ ! -e "$HUB/tracks/_meta/.pending" ]; chk $? "$1: and the listed exclusion is honored (.pending not pulled)"
}
_l13d_refuse(){
  [ "$L13D_RC" = "10" ]; chk $? "$1: refused with exit 10 (got rc=$L13D_RC)"
  [ ! -e "$HUB/tracks/_meta/ctl.md" ] && [ ! -e "$HUB/tracks/_meta/.pending" ]; chk $? "$1: nothing pulled"
}
_l13d A1 $'.pending\nlogs/\n'
_l13d_ok "A1 plain entries (CONTROL — the fixture harness itself works)"
_l13d A2 $'# header comment\n\n   .pending   \n\n# another\nlogs/\n'
_l13d_ok "A2 comments, blank lines, surrounding spaces mixed in"
_l13d A3 $'.pending\r\nlogs/\r\n'
_l13d_ok "A3 CRLF line endings (CR is trimmed as whitespace)"
_l13d A4 $'logs/\n.pending'
_l13d_ok "A4 no trailing newline on the last line"
_l13d B1 $'.pending\nsub/secret.key\n'
_l13d_refuse "B1 an entry with an inner slash (would be a silent no-op as find -name)"
_l13d B2 $'.pending   # inline comment\n'
_l13d_refuse "B2 an inline comment after an entry"
INJ="$ROOT/l13d_INJECTED"
_l13d B3 ".pending
\$(touch $INJ)
"
_l13d_refuse "B3 a command-substitution line"
[ ! -e "$INJ" ]; chk $? "B3: and it was never executed (no file created)"
_l13d B4 $'SYNC_EXCLUDES=(\'.pending\'); printf \'junk\\n\'; exit 0 # )\n'
_l13d_refuse "B4 the round-2 list-spoofing declaration, as a data line"
_l13d B5 $'# only comments\n\n   \n'
_l13d_refuse "B5 empty list (comments and blanks only)"
_l13d B6 ''
_l13d_refuse "B6 zero-byte file"
_l13d B7 $'.pending\n덱\n'
_l13d_refuse "B7 a non-ASCII entry (refused in every locale — explicit character set)"
_l13d B8 $'.pending\nlogs//\n'
_l13d_refuse "B8 two trailing slashes"

# Round 4 fixtures — written with printf FORMAT so a NUL byte can be embedded (a bash string cannot hold one).
_l13dfmt(){   # $1 = case id, $2 = printf format for the data file → sets L13D_RC
  local sd="$ROOT/l13d/$1"; _l13_copy "$sd"
  printf "$2" > "$sd/sync_excludes.txt"
  new_env "l13d_$1"
  printf 'ordinary\n' > "$BEX/tracks-meta/ctl.md"
  printf 'marker\n'   > "$BEX/tracks-meta/.pending"
  run_copy "$sd" --include-new >/dev/null 2>&1
  L13D_RC=$?
}
_l13dfmt B9 '.pend\000ing\nlogs/\n'
_l13d_refuse "B9 NUL in the middle of an entry (bash 3.2 read keeps only «.pend» — codex B: .pending leaked)"
# NUL at the START of a line: bash read yields "", the line is skipped as blank, and the entry after
# the NUL silently vanishes. A NUL-only first line would ALSO be caught by the empty-list check, so
# the fixture keeps a valid entry first — then only the NUL check can refuse it (revert-measured).
_l13dfmt B10 '.pending\n\000logs/\n'
_l13d_refuse "B10 NUL at the start of a line (the entry after it would silently disappear)"
for _dc in '.' '..' './' '../' '*' '*/'; do
  _l13dfmt "B11_$(printf '%s' "$_dc" | tr './*' 'DSX')" ".pending\n${_dc}\n"
  _l13d_refuse "B11 entry «${_dc}» (current/parent dir or match-everything — tar fallback archives nothing)"
done

echo "── L13c compaction session markers never come back; seals do (fh_signal_2026-09-30, 2026-10-03) ──"
# The incident: a legacy `.pending` tracked in the store came back on every pull and fed an 08-08
# seal to three later sessions. Both arms — creation (--include-new) and overwrite (hub copy older).
new_env l13c
mkdir -p "$BEX/tracks-meta/compaction" "$HUB/tracks/_meta/compaction"
printf 'hub-old\n' > "$HUB/tracks/_meta/compaction/.pending_live"
sleep 1
printf '/x/seal_REPRO.md\n' > "$BEX/tracks-meta/compaction/.pending"
printf '/x/seal_peer.md\tpeer\t1\n' > "$BEX/tracks-meta/compaction/.pending_peer"
printf 'store-newer\n' > "$BEX/tracks-meta/compaction/.pending_live"
printf '{}\n' > "$BEX/tracks-meta/compaction/.last_payload"
printf '# seal\n' > "$BEX/tracks-meta/compaction/seal_peer_20261003.md"
run --include-new >/dev/null 2>&1
[ -f "$HUB/tracks/_meta/compaction/seal_peer_20261003.md" ]; chk $? "CONTROL: the seal body (a record) IS pulled"
[ ! -e "$HUB/tracks/_meta/compaction/.pending" ]; chk $? "legacy .pending is not re-created in the hub"
[ ! -e "$HUB/tracks/_meta/compaction/.pending_peer" ]; chk $? "a peer session's .pending_<id> is not re-created"
[ ! -e "$HUB/tracks/_meta/compaction/.last_payload" ]; chk $? ".last_payload is not re-created"
[ "$(cat "$HUB/tracks/_meta/compaction/.pending_live")" = "hub-old" ]; chk $? "an existing hub marker is not overwritten by a newer store copy"

echo "── L14 atomic-write temp file never survives, and is excluded even if it did ──"
new_env l14
printf 'orig\n' > "$HUB/tracks/_meta/t.md"; sleep 1; printf 'newer\n' > "$BEX/tracks-meta/t.md"
run >/dev/null 2>&1
[ "$(cat "$HUB/tracks/_meta/t.md")" = "newer" ]; chk $? "CONTROL: the write path actually ran"
[ -z "$(find "$HUB" -name '*.sfb.*' 2>/dev/null)" ]; chk $? "no temp file left behind after a successful write"
# even a leaked temp must be invisible to the forward mirror: its suffix is an excluded name
printf 'leaked\n' > "$HUB/tracks/_meta/t.md.sfb.999.marker"
grep -qx '\*\.marker' "$(dirname "$SCRIPT")/sync_excludes.txt"; chk $? "the shared exclusion list carries the temp suffix (*.marker)"

echo "── L15 symlinked PARENT dir must not let a write escape the hub ──"
new_env l15
mkdir -p "$ENV_DIR/outside_dir"
ln -s "$ENV_DIR/outside_dir" "$HUB/tracks/_meta/sub"
mkdir -p "$BEX/tracks-meta/sub"; printf 'payload\n' > "$BEX/tracks-meta/sub/x.md"
printf 'ordinary\n' > "$BEX/tracks-meta/ok.md"
out="$(run --include-new 2>&1)"
[ -f "$HUB/tracks/_meta/ok.md" ]; chk $? "CONTROL: ordinary file landed (the run really ran)"
# Distinguish "the guard blocked it" from "it never happened": the candidate must have been REACHED
# and then refused. Without this, the absence assertion below passes for the wrong reason.
printf '%s' "$out" | grep -q 'escapes tracks/_meta'; chk $? "the guard fired on the escaping path (not merely absent)"
[ ! -f "$ENV_DIR/outside_dir/x.md" ]; chk $? "no write through a symlinked parent directory"

echo "── L16 a pre-created temp path is refused, not followed ──"
new_env l16
printf 'orig\n' > "$HUB/tracks/_meta/w.md"; sleep 1; printf 'newer\n' > "$BEX/tracks-meta/w.md"
printf 'ordinary\n' > "$BEX/tracks-meta/ok.md"
printf 'victim\n' > "$ENV_DIR/victim.txt"
# every plausible pid-suffixed temp name for this destination, pre-created as a link
for pid in $(seq 1 400); do ln -s "$ENV_DIR/victim.txt" "$HUB/tracks/_meta/w.md.sfb.$pid.marker" 2>/dev/null; done
out="$(run --include-new 2>&1)"
[ -f "$HUB/tracks/_meta/ok.md" ]; chk $? "CONTROL: ordinary file landed"
[ "$(cat "$ENV_DIR/victim.txt")" = "victim" ]; chk $? "pre-created temp symlink never written through"
# Direct proof of the guard itself, independent of which pid the run happened to get: call the
# writer with a temp path that already exists and assert it refuses. Without this the lane above
# can pass merely because the run's pid fell outside the pre-created range. (R3 #10.)
probe="$ENV_DIR/probe.md"; printf 'dest\n' > "$probe"; printf 'src\n' > "$ENV_DIR/probe.src"
( set -uo pipefail
  warn(){ echo "$*" >&2; }; _TMP_INFLIGHT=""
  _debanner(){ cat "$1"; }
  eval "$(sed -n '/^_write_atomic() {/,/^}/p' "$SCRIPT")"
  ln -s "$ENV_DIR/victim.txt" "$probe.sfb.$$.marker"
  _write_atomic "$ENV_DIR/probe.src" "$probe" ) 2>/dev/null; rc=$?
[ "$rc" != "0" ]; chk $? "_write_atomic itself refuses a pre-existing temp path (direct probe)"
[ "$(cat "$ENV_DIR/victim.txt")" = "victim" ]; chk $? "direct probe did not write through the link either"

echo "── L17 destination permissions are preserved across an overwrite ──"
new_env l17
printf 'orig\n' > "$HUB/tracks/_meta/secret.md"; chmod 600 "$HUB/tracks/_meta/secret.md"
sleep 1; printf 'newer\n' > "$BEX/tracks-meta/secret.md"
[ "$(stat -c '%a' "$HUB/tracks/_meta/secret.md" 2>/dev/null || stat -f '%Lp' "$HUB/tracks/_meta/secret.md")" = "600" ]; chk $? "CONTROL: destination really starts at 0600"
run >/dev/null 2>&1
[ "$(cat "$HUB/tracks/_meta/secret.md")" = "newer" ]; chk $? "CONTROL: the overwrite actually happened"
[ "$(stat -c '%a' "$HUB/tracks/_meta/secret.md" 2>/dev/null || stat -f '%Lp' "$HUB/tracks/_meta/secret.md")" = "600" ]; chk $? "mode not widened to 0644 by the rename"

echo "── L18 a malformed machine id is rejected, never aliased to another machine ──"
new_env l18
mkdir -p "$BEX/tracks-meta/manifests"
printf 'etc manifest\n'     > "$BEX/tracks-meta/manifests/etc.yaml"
printf 'unknown manifest\n' > "$BEX/tracks-meta/manifests/unknown.yaml"
HOME="$FAKEHOME" HUB_DIR="$HUB" BE_DIR="$BEX" FH_MACHINE_ID='../../etc' bash "$SCRIPT" --no-git >/dev/null 2>&1
[ ! -f "$HUB/tracks/_meta/edit_manifest.yaml" ]; chk $? "malformed id does not resolve to the 'etc' manifest"
# The rejection must REJECT. A warning followed by a fallback id that imports anyway is the exact
# regression round 3 found: the report said skipped while unknown.yaml landed. (R3.)
[ "$(cat "$HUB/tracks/_meta/edit_manifest.yaml" 2>/dev/null)" != "unknown manifest" ]; chk $? "no fallback to an 'unknown' machine id"
printf 'good manifest\n' > "$BEX/tracks-meta/manifests/goodid.yaml"
HOME="$FAKEHOME" HUB_DIR="$HUB" BE_DIR="$BEX" FH_MACHINE_ID='goodid' bash "$SCRIPT" --no-git >/dev/null 2>&1
[ "$(cat "$HUB/tracks/_meta/edit_manifest.yaml" 2>/dev/null)" = "good manifest" ]; chk $? "CONTROL: a well-formed id still restores (rejection is not blanket)"

echo "── L19 equal-mtime divergence is applied but flagged REVIEW, never silent-clean ──"
new_env l19
printf 'hub\n' > "$HUB/tracks/_meta/tie2.md"; printf 'companion\n' > "$BEX/tracks-meta/tie2.md"
touch -r "$HUB/tracks/_meta/tie2.md" "$BEX/tracks-meta/tie2.md"
out="$(run 2>&1)"
printf '%s' "$out" | grep -q 'SAME mtime'; chk $? "tie is announced as a guessed direction"
printf '%s' "$out" | grep -q 'review 1'; chk $? "tie counted as REVIEW, not clean"

echo "── L20 a symlinked companion-side source is refused (machine-scoped leg) ──"
new_env l20
mkdir -p "$BEX/tracks-meta/manifests"
printf 'outside bytes\n' > "$ENV_DIR/outside.yaml"
ln -s "$ENV_DIR/outside.yaml" "$BEX/tracks-meta/manifests/lanetest.yaml"
HOME="$FAKEHOME" HUB_DIR="$HUB" BE_DIR="$BEX" FH_MACHINE_ID=lanetest bash "$SCRIPT" --no-git >/dev/null 2>&1
[ ! -f "$HUB/tracks/_meta/edit_manifest.yaml" ]; chk $? "companion-side symlink not imported"
rm -f "$BEX/tracks-meta/manifests/lanetest.yaml"; printf 'real\n' > "$BEX/tracks-meta/manifests/lanetest.yaml"
HOME="$FAKEHOME" HUB_DIR="$HUB" BE_DIR="$BEX" FH_MACHINE_ID=lanetest bash "$SCRIPT" --no-git >/dev/null 2>&1
[ "$(cat "$HUB/tracks/_meta/edit_manifest.yaml" 2>/dev/null)" = "real" ]; chk $? "CONTROL: a regular file at the same path IS restored"

echo "── L21 reported backup path is the one that actually exists ──"
new_env l21
printf 'orig\n' > "$HUB/tracks/_meta/b.md"; sleep 1; printf 'newer\n' > "$BEX/tracks-meta/b.md"
printf 'hublocal\n' >> "$HUB/tracks/_meta/b.md"     # differ in content
# ★ FLAKE FIXED HERE (2026-08-06, diagnosed from a CI-only failure of unknown attribution).
# The REVIEW this lane needs comes from the TIE branch of sync-from-be.sh: `[ ! "$f" -ot "$h" ]`
# lets EQUAL-mtime through, content then differs, and a tie is forced into REVIEW. So the lane
# depends on the two files landing on the SAME mtime — which it left to chance. The append above
# usually lands in the same second as the companion write, but not always: the Linux runner's own
# probe in this suite measures ~193/200 consecutive write-pairs as indistinguishable, i.e. roughly
# 3-4% DO cross a second boundary. When that happens hub is strictly newer, `! -ot` is false, the
# file is skipped entirely, no REVIEW is printed, and this lane fails — CI-only, unreproducible
# locally, no code change involved. That is exactly the reported flake signature.
# Reproduced deliberately by forcing hub-newer (`sleep 1` before the append): this lane goes ❌
# while every other lane stays green.
# Fix: state the intent instead of racing for it — pin the two mtimes equal.
touch -r "$BEX/tracks-meta/b.md" "$HUB/tracks/_meta/b.md"
out="$(run 2>&1)"
rp="$(printf '%s' "$out" | sed -n 's|.*originals in \(tracks/_meta/logs/sync_restore/[^)]*\)/):.*|\1|p' | head -1)"
[ -n "$rp" ]; chk $? "CONTROL: a restore path was actually reported"
# The two assertions below are only meaningful when a path was reported. Without this guard an
# empty `$rp` makes them test "$HUB/" — the hub root, which of course exists and of course contains
# b.md — so they printed ✅ in the very run where the control printed ❌. An assertion that passes
# hardest when its premise failed is not evidence; it is decoration.
if [ -n "$rp" ]; then
  [ -d "$HUB/$rp" ]; chk $? "the reported backup directory exists (not a \$STAMP-vs-\$STAMP.\$\$ mismatch)"
  [ -n "$(find "$HUB/$rp" -name 'b.md' 2>/dev/null)" ]; chk $? "and the backup file is really in it"
else
  chk 1 "the reported backup directory exists — SKIPPED: no path was reported (premise failed)"
  chk 1 "and the backup file is really in it — SKIPPED: no path was reported (premise failed)"
fi

echo "── L22 nested symlinked parent: no directory is created outside the hub ──"
new_env l22
mkdir -p "$ENV_DIR/outside_deep"
ln -s "$ENV_DIR/outside_deep" "$HUB/tracks/_meta/deep"
mkdir -p "$BEX/tracks-meta/deep/a/b"; printf 'p\n' > "$BEX/tracks-meta/deep/a/b/x.md"
printf 'ordinary\n' > "$BEX/tracks-meta/ok.md"
out="$(run --include-new 2>&1)"
[ -f "$HUB/tracks/_meta/ok.md" ]; chk $? "CONTROL: ordinary file landed"
printf '%s' "$out" | grep -q 'escapes tracks/_meta'; chk $? "guard fired before any mkdir"
[ ! -d "$ENV_DIR/outside_deep/a" ]; chk $? "no directories created outside via mkdir -p"

echo "── L23 symlinked AREA ROOT: nothing escapes, including the machine-scoped leg ──"
new_env l23
mkdir -p "$ENV_DIR/outside_tracks" "$ENV_DIR/outside_meta" "$BEX/tracks-audit" "$BEX/tracks-meta/manifests"
printf 'x\n' > "$BEX/tracks-audit/x.md"
printf 'm\n' > "$BEX/tracks-meta/manifests/probeid.yaml"
rm -rf "$HUB/tracks/_meta"; ln -s "$ENV_DIR/outside_meta" "$HUB/tracks/_meta"
mv "$HUB/tracks" "$ENV_DIR/realtracks"; ln -s "$ENV_DIR/outside_tracks" "$HUB/tracks"
[ -L "$HUB/tracks" ]; chk $? "CONTROL: the area root really is a symlink out of the hub"
HOME="$FAKEHOME" HUB_DIR="$HUB" BE_DIR="$BEX" FH_MACHINE_ID=probeid \
  bash "$SCRIPT" --no-git --include-new >/dev/null 2>&1
[ -z "$(find "$ENV_DIR/outside_tracks" -type f 2>/dev/null)" ]; chk $? "no file written outside via the symlinked area root"
[ -z "$(find "$ENV_DIR/outside_meta" -type f 2>/dev/null)" ]; chk $? "machine-scoped leg wrote nothing outside either"

echo "── L24 backup names mirror the source tree (no flatten collision on ordinary names) ──"
new_env l24
mkdir -p "$HUB/tracks/_meta/a" "$BEX/tracks-meta/a"
printf 'hub-nested\n' > "$HUB/tracks/_meta/a/b.md";  printf 'hub-tilde\n' > "$HUB/tracks/_meta/a~b.md"
sleep 1
printf 'new-nested\n' > "$BEX/tracks-meta/a/b.md";   printf 'new-tilde\n' > "$BEX/tracks-meta/a~b.md"
out="$(run 2>&1)"; rc=$?
printf '%s' "$out" | grep -q 'BACKUP PATH COLLISION'; [ $? -ne 0 ]; chk $? "no false collision between a/b.md and a~b.md"
[ "$(cat "$HUB/tracks/_meta/a/b.md")" = "new-nested" ]; chk $? "nested file overwritten"
[ "$(cat "$HUB/tracks/_meta/a~b.md")" = "new-tilde" ]; chk $? "tilde-named file overwritten too (both, not one)"
[ -n "$(find "$HUB/tracks/_meta/logs/sync_restore" -path '*a/b.md' 2>/dev/null)" ]; chk $? "backup mirrors the source path"
[ -n "$(find "$HUB/tracks/_meta/logs/sync_restore" -name 'a~b.md' 2>/dev/null)" ]; chk $? "and the tilde name has its own distinct backup"

echo "── L25 a restrictive source mode is not widened on creation ──"
new_env l25
printf 'secret\n' > "$BEX/tracks-meta/secret.md"; chmod 600 "$BEX/tracks-meta/secret.md"
[ "$(stat -c '%a' "$BEX/tracks-meta/secret.md" 2>/dev/null || stat -f '%Lp' "$BEX/tracks-meta/secret.md")" = "600" ]; chk $? "CONTROL: the companion file really is 0600"
run --include-new >/dev/null 2>&1
[ -f "$HUB/tracks/_meta/secret.md" ]; chk $? "CONTROL: it was actually created"
[ "$(stat -c '%a' "$HUB/tracks/_meta/secret.md" 2>/dev/null || stat -f '%Lp' "$HUB/tracks/_meta/secret.md")" = "600" ]; chk $? "created file kept 0600 (not widened to umask 0644)"

echo ""
echo "════ lanes: $PASS passed · $FAIL failed ════"
[ "$FAIL" -eq 0 ] || exit 1
exit 0

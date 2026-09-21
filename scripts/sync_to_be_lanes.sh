#!/usr/bin/env bash
# sync_to_be_lanes.sh — mechanical regression lanes for scripts/sync-to-be.sh (the FORWARD path)
#
# WHY: sync_from_be_lanes.sh covers the RETURN path exhaustively, but nothing asserted the forward
# path's own re-homing behavior — the exact side pmh-dev#69 reported a real defect on
# (.substrate_versions colliding between two nodes of the same hub). Each lane below reproduces
# one measured or predicted defect from that review and asserts it stays closed.
#
# CONTROL DISCIPLINE: same as sync_from_be_lanes.sh — an absence assertion is paired with a
# known-positive in the same run, and each fixture is checked to exist before the run that is
# supposed to consume it.
#
# USAGE: bash scripts/sync_to_be_lanes.sh          → runs all lanes, exit 0 = all pass, 1 = any fail
set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/sync-to-be.sh"
[ -f "$SCRIPT" ] || { echo "missing target: $SCRIPT" >&2; exit 10; }
ROOT="$(mktemp -d)"; trap 'rm -rf "$ROOT"' EXIT
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); printf '  ✅ %s\n' "$1"; }
no(){ FAIL=$((FAIL+1)); printf '  ❌ %s\n' "$1"; }
chk(){ if [ "$1" = "0" ]; then ok "$2"; else no "$2"; fi; }

# fresh sandbox — HUB must carry the real identity header (fh_hub_identity.sh reads it), and BE
# must be a real (if remote-less) git repo: sync-to-be.sh has no --no-git escape hatch, and a
# non-repo BE leaves `git add`/`git diff --cached` in an undefined state. fetch/pull/push against
# a missing remote fail silently (the script itself guards each with `2>/dev/null`), so a bare
# local init is sufficient and never reaches out to the network.
new_env(){
  ENV_DIR="$ROOT/$1"; rm -rf "$ENV_DIR"
  HUB="$ENV_DIR/hubx"; BEX="$ENV_DIR/be"
  mkdir -p "$HUB/tracks/_meta" "$BEX"
  printf '# forge-harness — Persistent Knowledge Hub\n' > "$HUB/CLAUDE.md"
  git -C "$BEX" init -q
  git -C "$BEX" config user.email "lane@test.local"
  git -C "$BEX" config user.name "lane-test"
}
run(){ HOME="$ENV_DIR/home" HUB_DIR="$HUB" BE_DIR="$BEX" FH_MACHINE_ID="${MID:-lanea}" bash "$SCRIPT" --quiet "$@"; }

echo "── L1 .substrate_versions is re-homed under substrate/\$MID, never left at the shared path ──"
new_env l1
printf 'claude=1.0\ncodex=2.0\n' > "$HUB/tracks/_meta/.substrate_versions"
printf 'ordinary\n' > "$HUB/tracks/_meta/normal.md"
MID=lanea run >/dev/null 2>&1
[ -f "$BEX/tracks-meta/normal.md" ]; chk $? "CONTROL: an ordinary file synced at all (run actually executed)"
[ -f "$BEX/tracks-meta/substrate/lanea" ]; chk $? "own substrate record landed machine-scoped"
[ "$(cat "$BEX/tracks-meta/substrate/lanea")" = "$(printf 'claude=1.0\ncodex=2.0')" ]; chk $? "content survived the re-home intact"
[ ! -f "$BEX/tracks-meta/.substrate_versions" ]; chk $? "shared unscoped copy retired, not left behind"

echo "── L2 a second machine's sync never overwrites the first's substrate record (pmh-dev#69 known-positive) ──"
new_env l2
printf 'claude=1.0\n' > "$HUB/tracks/_meta/.substrate_versions"
MID=lanea run >/dev/null 2>&1
[ -f "$BEX/tracks-meta/substrate/lanea" ]; chk $? "CONTROL: machine A's own record landed first"
printf 'claude=9.9-DIFFERENT\n' > "$HUB/tracks/_meta/.substrate_versions"
MID=laneb run >/dev/null 2>&1
[ "$(cat "$BEX/tracks-meta/substrate/lanea")" = "claude=1.0" ]; chk $? "machine A's record byte-unchanged after machine B's sync (the actual pmh-dev#69 collision, closed)"
[ "$(cat "$BEX/tracks-meta/substrate/laneb")" = "claude=9.9-DIFFERENT" ]; chk $? "machine B got its own distinct record"

echo "── L3 a PRE-FIX stale unscoped copy is reaped, not treated as a destination-newer conflict (pmh-dev#69 A1) ──"
new_env l3
# Wall-clock ordering, not touch -d (portability: BSD touch on macOS rejects GNU-style -d offsets —
# the exact class of bug this repo's own mktemp GNU/BSD incident already named). The hub's file must
# be written to its FINAL content BEFORE the companion's stale copy — writing to the hub file again
# afterward (even to the same content) re-stamps its mtime and can collapse the ordering back to the
# same second, silently defeating the fixture (measured while writing this lane: an earlier version
# rewrote the hub file a third time right before `run`, and the guard never tripped — not because
# the fix was unnecessary, but because the fixture no longer exercised it).
printf 'claude=fresh\n' > "$HUB/tracks/_meta/.substrate_versions"
mkdir -p "$BEX/tracks-meta"
sleep 2
printf 'stale-peer-content\n' > "$BEX/tracks-meta/.substrate_versions"
git -C "$BEX" add tracks-meta/.substrate_versions; git -C "$BEX" commit -q -m seed
[ "$BEX/tracks-meta/.substrate_versions" -nt "$HUB/tracks/_meta/.substrate_versions" ]
chk $? "CONTROL: the companion copy really is newer than the hub's (fixture ordering worked)"
out="$(MID=lanea run 2>&1)"
[ -f "$BEX/tracks-meta/substrate/lanea" ] && [ "$(cat "$BEX/tracks-meta/substrate/lanea")" = "claude=fresh" ]
chk $? "sync completed and re-homed correctly despite a stale, newer pre-fix shared copy (did not abort — pmh-dev#69 A1)"
printf '%s' "$out" | grep -qi 'refuse\|abort\|newer'; [ $? -ne 0 ]
chk $? "no destination-newer abort was printed for the reaped file"

echo "── L4 .close_stamps_<date> never leaves the hub at all (excluded, not machine-scoped — pmh-dev#69 A2) ──"
new_env l4
printf '2026-08-14T00:00:00Z\n' > "$HUB/tracks/_meta/.close_stamps_2026-08-14"
printf 'ordinary\n' > "$HUB/tracks/_meta/normal2.md"
MID=lanea run >/dev/null 2>&1
[ -f "$BEX/tracks-meta/normal2.md" ]; chk $? "CONTROL: an ordinary file synced (run actually executed)"
[ ! -f "$BEX/tracks-meta/.close_stamps_2026-08-14" ]; chk $? "close-stamp file never landed in the companion store at all"

echo "── L4b manifests/ · _index/ are re-home TARGETS, never mirrored as ordinary content (2026-09-03, Air node) ──"
# The return path never pulls a peer's tracks-meta/manifests/<MID>.yaml, but the forward path had no
# matching exclude: a hub holding tracks/_meta/manifests/<peer>.yaml pushed it path-for-path onto the
# peer's LIVE re-homed manifest and tripped the destination-newer abort on the other machine.
new_env l4b
mkdir -p "$HUB/tracks/_meta/manifests"
printf 'peer: stale-copy\n' > "$HUB/tracks/_meta/manifests/peerx.yaml"
printf -- '- date: 2026-09-03\n  change: own\n' > "$HUB/tracks/_meta/edit_manifest.yaml"
printf 'ordinary\n' > "$HUB/tracks/_meta/normal4b.md"
MID=lanea run >/dev/null 2>&1
[ -f "$BEX/tracks-meta/normal4b.md" ]; chk $? "CONTROL: an ordinary file synced (run actually executed)"
[ -f "$BEX/tracks-meta/manifests/lanea.yaml" ]; chk $? "CONTROL: own manifest still RE-HOMED to manifests/\$MID.yaml (the exclude did not kill the re-home)"
[ ! -f "$BEX/tracks-meta/manifests/peerx.yaml" ]; chk $? "a peer manifest copy under the hub's manifests/ never landed in the store (forward exclude)"

echo "── L5 destination-newer abort CITES the return path and drops the false single-cause claim (2026-08-20) ──"
# The old message asserted one cause ("it was edited in the MIRROR") and offered only
# SYNC_OVERWRITE_OK=1 — measured 0/4 correct on the air node, where all four hits were a PEER NODE's
# forward sync. Overriding there would have destroyed the peer's newer work. These lanes assert the
# message names both causes and routes to sync-from-be.sh, at BOTH guard sites.
new_env l5
mkdir -p "$HUB/scripts"; printf '#!/usr/bin/env bash\n' > "$HUB/scripts/sync-from-be.sh"
printf 'hub-v1\n' > "$HUB/tracks/_meta/card.md"
MID=lanea run >/dev/null 2>&1
[ -f "$BEX/tracks-meta/card.md" ]; chk $? "CONTROL: first sync landed the file (fixture is live)"
out_clean="$(MID=lanea run 2>&1)"
printf '%s' "$out_clean" | grep -q 'SYNC ABORTED'; [ $? -ne 0 ]
chk $? "KNOWN-NEGATIVE: an unchanged re-sync prints no abort (the lane can fail)"
sleep 2
printf 'peer-node-added-this\n' >> "$BEX/tracks-meta/card.md"
[ "$BEX/tracks-meta/card.md" -nt "$HUB/tracks/_meta/card.md" ]
chk $? "CONTROL: companion copy really is newer + divergent (fixture ordering worked)"
out="$(MID=lanea run 2>&1)"; rc=$?
[ "$rc" -ne 0 ]; chk $? "KNOWN-POSITIVE: the guard still aborts (fail-closed preserved)"
printf '%s' "$out" | grep -q 'sync-from-be.sh" --dry-run'
chk $? "the abort CITES the return path with the exact (quoted) command to run"
printf '%s' "$out" | grep -q 'ANOTHER NODE advanced'
chk $? "cause ⓐ (peer node advanced) is named, not just the mirror-edit cause"
printf '%s' "$out" | grep -q 'EDITED IN PLACE'
chk $? "cause ⓑ (mirror edited in place) is still named"
printf '%s' "$out" | grep -q 'means it was edited in the'; [ $? -ne 0 ]
chk $? "the retired single-cause assertion is GONE (0/4 correct when measured)"
printf '%s' "$out" | grep -q 'NOT the fix'
chk $? "SYNC_OVERWRITE_OK=1 is marked as not-the-fix for the peer-node case"
printf '%s' "$out" | grep -q 'COUNTED AND NOT LISTED'
chk $? "the message warns that the return path's 'clean' set is silent (the 2026-08-20 misread)"
printf '%s' "$out" | grep -q "the 'clean' set"
chk $? "that warning is literal text, not a swallowed command substitution (backtick trap)"
printf '%s' "$out" | grep -q 'bash "'
chk $? "the printed command QUOTES the path (survives a hub dir containing spaces — codex MED)"
printf '%s' "$out" | grep -q 'NOT provenance'
chk $? "the message states the guard tests newer+divergent, not provenance (codex LOW/MED overclaim)"

echo "── L6 the file-level guard: SAME message, DIFFERENT remedy (its only file is unpullable) ──"
new_env l6
mkdir -p "$HUB/scripts"; printf '#!/usr/bin/env bash\n' > "$HUB/scripts/sync-from-be.sh"
printf 'ordinary\n' > "$HUB/tracks/_meta/normal.md"
printf 'binding-v1\n' > "$HUB/CLAUDE.local.md"
MID=lanea run >/dev/null 2>&1
# Resolved by search, not by a literal subdirectory name: the destination is an operator-private
# companion-store layout, and hard-coding it would both leak that name onto the public surface and
# break the lane on any other operator's layout.
[ -n "$(find "$BEX" -name CLAUDE.local.md 2>/dev/null)" ]
chk $? "CONTROL: CLAUDE.local.md went through the file-level path at all"
lf="$(find "$BEX" -name CLAUDE.local.md | head -1)"
sleep 2
printf 'peer-edit\n' >> "$lf"
out="$(MID=lanea run 2>&1)"
printf '%s' "$out" | grep -q 'SYNC ABORTED'
chk $? "KNOWN-POSITIVE: the file-level guard aborts"
printf '%s' "$out" | grep -q 'does NOT cover this file'
chk $? "the file-level abort declares the return path does NOT cover CLAUDE.local.md (codex HIGH, 2026-08-20)"
printf '%s' "$out" | grep -q 'reconcile by hand'
chk $? "it hands over a remedy that actually exists for this file (manual reconcile)"
printf '%s' "$out" | grep -q 'sync-from-be.sh" --dry-run'; [ $? -ne 0 ]
chk $? "it does NOT cite the return path here — sync-from-be.sh refuses this file by name"

echo "── L7 a missing return path is declared missing, never cited as a live remedy ──"
new_env l7
printf 'hub-v1\n' > "$HUB/tracks/_meta/card.md"
MID=lanea run >/dev/null 2>&1
sleep 2
printf 'peer\n' >> "$BEX/tracks-meta/card.md"
[ ! -f "$HUB/scripts/sync-from-be.sh" ]; chk $? "CONTROL: the return path really is absent in this fixture"
out="$(MID=lanea run 2>&1)"
printf '%s' "$out" | grep -q 'NOT PRESENT'
chk $? "the abort says the return path is NOT PRESENT instead of printing a dead pointer"
printf '%s' "$out" | grep -q -- '--dry-run'; [ $? -ne 0 ]
chk $? "it does NOT hand out a --dry-run command that cannot run here"

# ══ A · destination guard — fail-closed (fh_signal_2026-09-05_sync-guard-failopen-and-alarm-fatigue ⓐ) ══
# The probe that found the defect was "rc=0 AND 15 MB appeared at a path that did not exist". So every
# lane below checks the FILESYSTEM, not only the exit code — an rc alone would have passed the old code
# too (it exited 0) and would pass a future regression that refuses *after* writing.
count_files(){ [ -e "$1" ] && find "$1" -type f 2>/dev/null | wc -l | tr -d ' ' || echo 0; }

echo "── A1 a NON-EXISTENT destination is refused (rc=12) and NOTHING is created ──"
new_env a1
printf 'private\n' > "$HUB/tracks/_meta/secret_card.md"
BEX="$ENV_DIR/does-not-exist/companion"
[ ! -e "$BEX" ]; chk $? "CONTROL: destination really is absent before the run"
out="$(MID=lanea run 2>&1)"; rc=$?
[ "$rc" -eq 12 ]; chk $? "KNOWN-NEGATIVE: refused with rc=12 (got $rc)"
[ ! -e "$BEX" ]; chk $? "destination path still does not exist after the run (mkdir -p did NOT fire)"
[ "$(count_files "$ENV_DIR/does-not-exist")" = "0" ]; chk $? "0 files anywhere under the absent parent (the 15 MB probe, closed)"
printf '%s' "$out" | grep -q 'REFUSED (rc=12)'; chk $? "the refusal names its code"
printf '%s' "$out" | grep -q -- '--init'; chk $? "the remedy for a genuinely new store (--init) is printed"
printf '%s' "$out" | grep -qi 'typo'; chk $? "the message suspects a typo first (the measured failure mode)"

echo "── A2 an EXISTING directory that is not a git work tree is refused (rc=12), contents unchanged ──"
new_env a2
BEX="$ENV_DIR/plain-dir"; mkdir -p "$BEX"; printf 'pre-existing\n' > "$BEX/keep.txt"
printf 'private\n' > "$HUB/tracks/_meta/secret_card.md"
before="$(count_files "$BEX")"
[ "$before" = "1" ]; chk $? "CONTROL: fixture holds exactly 1 file before the run"
MID=lanea run >/dev/null 2>&1; rc=$?
[ "$rc" -eq 12 ]; chk $? "KNOWN-NEGATIVE: non-git directory refused with rc=12 (got $rc)"
[ "$(count_files "$BEX")" = "$before" ]; chk $? "file count unchanged ($before → $(count_files "$BEX")) — nothing mirrored, no lock dir left"
[ ! -d "$BEX/.git" ]; chk $? "no git repo was created implicitly"

echo "── A3 --init creates the store EXPLICITLY (mkdir + git init, logged) and then syncs ──"
new_env a3
BEX="$ENV_DIR/fresh/companion"; mkdir -p "$ENV_DIR/fresh"   # parent EXISTS — --init creates exactly one leaf level
printf 'private\n' > "$HUB/tracks/_meta/secret_card.md"
[ ! -e "$BEX" ]; chk $? "CONTROL: destination absent before --init"
# CI 2026-09-05: the runner had no committer identity and the FIRST commit of the just-created store died with
# rc=128 (mirror already done). user.useConfigOnly makes that condition deterministic on every machine, so this
# lane asserts the script's own repo-local fallback identity, not the host's auto-detection.
out="$(GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=user.useConfigOnly GIT_CONFIG_VALUE_0=true MID=lanea run --init 2>&1)"; rc=$?
[ "$rc" -eq 0 ]; chk $? "--init run completes rc=0 (got $rc)"
[ "$(git -C "$BEX" log --oneline 2>/dev/null | grep -c .)" -ge 1 ]; chk $? "…and the new store's FIRST commit exists (no host identity: the script's repo-local fallback was used)"
[ "$(git -C "$BEX" rev-parse --is-inside-work-tree 2>/dev/null)" = "true" ]; chk $? "destination is now a git work tree"
[ -f "$BEX/tracks-meta/secret_card.md" ]; chk $? "and the sync actually proceeded after creation"
printf '%s' "$out" | grep -q -- '--init: created companion store at'; chk $? "creation is LOGGED with what and where (not silent)"

echo "── A4 an existing git work tree passes the guard unchanged (the ordinary path — regression control) ──"
new_env a4
printf 'private\n' > "$HUB/tracks/_meta/secret_card.md"
MID=lanea run >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ]; chk $? "KNOWN-POSITIVE: ordinary git-worktree destination still syncs rc=0 (got $rc)"
[ -f "$BEX/tracks-meta/secret_card.md" ]; chk $? "file landed — the guard did not over-block the valid case"

# ══ B · destination-newer: recoverable vs wall (ⓑ) ══
# HUB_DIR is a temp hub, so `rp="$FH/scripts/sync-from-be.sh"` resolves to a FAKE return path that
# prints a CONTROLLED COUNT line — the exact line the real script prints — and nothing else.
fake_rp(){ # $1 = body of the fake sync-from-be.sh
  mkdir -p "$HUB/scripts"; printf '#!/usr/bin/env bash\n%s\n' "$1" > "$HUB/scripts/sync-from-be.sh"
}
seed_newer(){ # first sync, then make the companion copy newer + divergent
  printf 'hub-v1\n' > "$HUB/tracks/_meta/card.md"
  MID=lanea run >/dev/null 2>&1
  [ -f "$BEX/tracks-meta/card.md" ]; chk $? "CONTROL: first sync landed the file (fixture is live)"
  sleep 2
  printf 'peer-node-added-this\n' >> "$BEX/tracks-meta/card.md"
  [ "$BEX/tracks-meta/card.md" -nt "$HUB/tracks/_meta/card.md" ]; chk $? "CONTROL: companion copy is newer + divergent"
}

echo "── B1 destination newer AND review>0 → the red wall stays (rc=1) — KNOWN-POSITIVE for the wall ──"
new_env b1
fake_rp 'echo "[sync-from-be] (dry-run) pulled 4 file(s) companion → hub  (clean 3 · review 1)"; exit 0'
seed_newer
out="$(MID=lanea run 2>&1)"; rc=$?
[ "$rc" -eq 1 ]; chk $? "rc=1 (got $rc)"
printf '%s' "$out" | grep -q 'SYNC ABORTED'; chk $? "the wall is printed when the return path cannot cover everything"
printf '%s' "$out" | grep -q 'recoverable, not an error wall'; [ $? -ne 0 ]; chk $? "the soft notice is NOT printed here"

echo "── B2 destination newer AND review==0 → 3-line notice instead of the wall, rc=2, nothing recovered ──"
new_env b2
fake_rp 'echo "[sync-from-be] (dry-run) pulled 3 file(s) companion → hub  (clean 3 · review 0)"; exit 0'
seed_newer
out="$(MID=lanea run 2>&1)"; rc=$?
[ "$rc" -eq 2 ]; chk $? "rc=2 (got $rc)"
printf '%s' "$out" | grep -q 'SYNC ABORTED'; [ $? -ne 0 ]; chk $? "the red wall is NOT printed"
printf '%s' "$out" | grep -q 'another node advanced'; chk $? "the notice names the cause (peer ahead, recoverable)"
printf '%s' "$out" | grep -q 'pulled 3 · review 0'; chk $? "the notice cites the parsed COUNT (N=3, review 0)"
printf '%s' "$out" | grep -q 'sync-from-be.sh"'; chk $? "the notice hands over the return-path command (quoted)"
[ "$(cat "$HUB/tracks/_meta/card.md")" = "hub-v1" ]; chk $? "hub file UNCHANGED — no automatic recovery happened"
grep -q 'peer-node-added-this' "$BEX/tracks-meta/card.md"; chk $? "companion copy UNCHANGED — the stale hub did not overwrite it"

echo "── B3 dry-run fails or prints no COUNT line → the wall stays (fail-closed) ──"
new_env b3
fake_rp 'echo "[sync-from-be] something unrelated"; exit 1'
seed_newer
out="$(MID=lanea run 2>&1)"; rc=$?
[ "$rc" -eq 1 ]; chk $? "dry-run rc≠0 → wall, rc=1 (got $rc)"
printf '%s' "$out" | grep -q 'SYNC ABORTED'; chk $? "wall printed"
printf '%s' "$out" | grep -q 'something unrelated'; [ $? -ne 0 ]; chk $? "the dry-run's own output did NOT leak into ours (captured)"
new_env b3b
fake_rp 'echo "[sync-from-be] hub is current with the companion store — nothing to pull"; exit 0'
seed_newer
out="$(MID=lanea run 2>&1)"; rc=$?
[ "$rc" -eq 1 ]; chk $? "dry-run rc=0 but NO COUNT line → wall, rc=1 (parse failure is not recovery) (got $rc)"
printf '%s' "$out" | grep -q 'SYNC ABORTED'; chk $? "wall printed"

# ══ B8 · codex R2 — root identity · physical paths · atomic --init · COUNT anchoring · timeout ══
echo "── B8a destination = a SUBDIRECTORY of another repo → rc=12, that repo untouched ──"
new_env b8a
OTHER="$ENV_DIR/other-repo"; mkdir -p "$OTHER/docs"; git -C "$OTHER" init -q; printf 'theirs\n' > "$OTHER/docs/readme.md"
BEX="$OTHER/docs"; before="$(count_files "$OTHER")"
printf 'private\n' > "$HUB/tracks/_meta/secret_card.md"
out="$(MID=lanea run 2>&1)"; rc=$?
[ "$rc" -eq 12 ]; chk $? "KNOWN-NEGATIVE: inside-a-worktree-but-not-its-root is refused rc=12 (got $rc) — the R1 hole"
[ "$(count_files "$OTHER")" = "$before" ]; chk $? "the foreign repo's file count is unchanged ($before)"
printf '%s' "$out" | grep -q 'SUBDIRECTORY of another repository'; chk $? "the reason names the foreign-repo case"

echo "── B8b destination = \$FH/subdir → rc=4 (self-hub), decided BEFORE the rc=12 guard ──"
new_env b8b
mkdir -p "$HUB/companion"; git -C "$HUB" init -q
BEX="$HUB/companion"
MID=lanea run >/dev/null 2>&1; rc=$?
[ "$rc" -eq 4 ]; chk $? "a store inside the hub exits 4, not 12 (got $rc) — the operator reads the self-hub remedy"

echo "── B8c destination = SYMLINK whose target is inside another repo → rc=12, log shows the REAL path ──"
new_env b8c
OTHER="$ENV_DIR/other-repo"; mkdir -p "$OTHER/inner"; git -C "$OTHER" init -q
ln -s "$OTHER/inner" "$ENV_DIR/harmless-looking"
BEX="$ENV_DIR/harmless-looking"; before="$(count_files "$OTHER")"
out="$(MID=lanea run 2>&1)"; rc=$?
[ "$rc" -eq 12 ]; chk $? "symlink into a foreign repo is refused rc=12 (got $rc)"
printf '%s' "$out" | grep -q "harmless-looking → .*other-repo/inner"; chk $? "the refusal logs requested → resolved path"
[ "$(count_files "$OTHER")" = "$before" ]; chk $? "nothing written through the symlink"

echo "── B8d destination = BARE repo → rc=12 ──"
new_env b8d
BEX="$ENV_DIR/bare.git"; git init -q --bare "$BEX"; before="$(count_files "$BEX")"
out="$(MID=lanea run 2>&1)"; rc=$?
[ "$rc" -eq 12 ]; chk $? "bare repo refused rc=12 (got $rc)"
printf '%s' "$out" | grep -q 'BARE repository'; chk $? "reason names the bare case"
[ "$(count_files "$BEX")" = "$before" ]; chk $? "bare repo untouched"

echo "── B8e destination = a work tree ROOT reached via symlink → passes (physical comparison, not string) ──"
new_env b8e
ln -s "$BEX" "$ENV_DIR/be-link"; REAL="$BEX"; BEX="$ENV_DIR/be-link"
printf 'private\n' > "$HUB/tracks/_meta/secret_card.md"
MID=lanea run >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ]; chk $? "KNOWN-POSITIVE: a symlink TO a work tree root still passes rc=0 (got $rc) — no over-block"
[ -f "$REAL/tracks-meta/secret_card.md" ]; chk $? "file landed in the real root"

echo "── B8f --init with a MISSING parent → rc=12 and zero trace ──"
new_env b8f
BEX="$ENV_DIR/no-such-parent/companion"
out="$(MID=lanea run --init 2>&1)"; rc=$?
[ "$rc" -eq 12 ]; chk $? "--init without an existing parent is refused rc=12 (got $rc), not mkdir -p'd"
[ ! -e "$ENV_DIR/no-such-parent" ]; chk $? "the parent chain was NOT created (zero trace)"
printf '%s' "$out" | grep -q 'EXISTING, writable parent'; chk $? "the remedy says to create the parent first"

echo "── B8g --init inside another repo's subdirectory → rc=12, no nested .git created ──"
new_env b8g
OTHER="$ENV_DIR/other-repo"; mkdir -p "$OTHER/sub"; git -C "$OTHER" init -q
BEX="$OTHER/sub"
MID=lanea run --init >/dev/null 2>&1; rc=$?
[ "$rc" -eq 12 ]; chk $? "--init does not git-init inside a foreign work tree (rc=$rc)"
[ ! -e "$OTHER/sub/.git" ]; chk $? "no nested repository was created"

echo "── B8h COUNT line appears TWICE → parse failure → wall (fail-closed), not rc=2 ──"
new_env b8h
fake_rp 'echo "[sync-from-be] (dry-run) pulled 3 file(s) companion → hub  (clean 3 · review 0)"; echo "[sync-from-be] (dry-run) pulled 3 file(s) companion → hub  (clean 3 · review 0)"; exit 0'
seed_newer
out="$(MID=lanea run 2>&1)"; rc=$?
[ "$rc" -eq 1 ]; chk $? "two COUNT lines → wall rc=1 (got $rc)"
printf '%s' "$out" | grep -q 'SYNC ABORTED'; chk $? "wall printed"

echo "── B8i a stderr diagnostic that MENTIONS 'review 0' is not mistaken for the COUNT line ──"
new_env b8i
# The diagnostic below CONTAINS the whole COUNT phrase (with a "hint:" prefix) and there is NO real
# COUNT line — a substring anchor would accept it and grade the run recoverable; the full-line anchor
# must not. This is the fixture that distinguishes "anchored" from "contains".
fake_rp 'echo "[sync-from-be] hint: last run pulled 3 file(s) companion → hub  (clean 3 · review 0)" >&2; echo "[sync-from-be] hub is current with the companion store — nothing to pull"; exit 0'
seed_newer
out="$(MID=lanea run 2>&1)"; rc=$?
[ "$rc" -eq 1 ]; chk $? "a prefixed look-alike line is NOT the COUNT line → wall rc=1 (got $rc)"
printf '%s' "$out" | grep -q 'SYNC ABORTED'; chk $? "wall printed"
new_env b8i2
fake_rp 'echo "[sync-from-be] warning: peer said review 0 earlier, ignore" >&2; echo "[sync-from-be] (dry-run) pulled 2 file(s) companion → hub  (clean 1 · review 1)"; exit 0'
seed_newer
out="$(MID=lanea run 2>&1)"; rc=$?
[ "$rc" -eq 1 ]; chk $? "real COUNT says review 1 → wall rc=1 despite a 'review 0' diagnostic (got $rc)"

echo "── B8j no timeout/gtimeout on PATH → grade split skipped, wall kept (unmeasured ≠ safe) ──"
new_env b8j
SHIM="$ENV_DIR/shim"; mkdir -p "$SHIM"
for d in $(printf '%s' "$PATH" | tr ':' ' '); do
  [ -d "$d" ] || continue
  for b in "$d"/*; do [ -e "$b" ] || continue; n="$(basename "$b")"; case "$n" in timeout|gtimeout) continue;; esac; [ -e "$SHIM/$n" ] || ln -s "$b" "$SHIM/$n" 2>/dev/null; done  # portability-noqa: the [ -e "$b" ] || continue guard is on this same line
done
PATH="$SHIM" command -v timeout >/dev/null 2>&1; [ $? -ne 0 ]; chk $? "CONTROL: timeout really is absent on the shimmed PATH"
PATH="$SHIM" command -v git >/dev/null 2>&1; chk $? "CONTROL: git still resolves on the shimmed PATH (shim is live)"
fake_rp 'echo "[sync-from-be] (dry-run) pulled 3 file(s) companion → hub  (clean 3 · review 0)"; exit 0'
seed_newer
out="$(PATH="$SHIM" MID=lanea run 2>&1)"; rc=$?
[ "$rc" -eq 1 ]; chk $? "review 0 but no timeout binary → wall rc=1 (got $rc)"
printf '%s' "$out" | grep -q 'no timeout/gtimeout'; chk $? "the skip is announced, not silent"
printf '%s' "$out" | grep -q 'SYNC ABORTED'; chk $? "wall printed"

# ══ B8k~B8o · codex R3 (2026-09-05) — old-git fail-closed · physical default BE · nested-repo decision · symlink retarget (S1) · mid-run .git loss (B6) ══
# B8n/B8o inject a state change BETWEEN validation and mirror deterministically: the lane HOLDS the sync
# lock, starts the script (which validates, then polls the lock every 1s), waits for its "destination:"
# line (printed right before the lock loop), mutates the world, then releases the lock. No sleep-and-hope.
wait_for_line(){ # $1 = file  $2 = pattern  → 0 when seen within ~20s
  local i=0; while [ "$i" -lt 40 ]; do grep -q "$2" "$1" 2>/dev/null && return 0; sleep 0.5; i=$((i+1)); done; return 1
}
run_loud(){ HOME="$ENV_DIR/home" HUB_DIR="$HUB" BE_DIR="$BEX" FH_MACHINE_ID="${MID:-lanea}" bash "$SCRIPT" "$@"; }   # no --quiet: the lane reads the destination line

echo "── B8k a git that cannot answer --show-superproject-working-tree → rc=12 fail-closed with the REAL reason ──"
new_env b8k
printf 'private\n' > "$HUB/tracks/_meta/secret_card.md"
SHIM="$ENV_DIR/shim"; mkdir -p "$SHIM"
REAL_GIT="$(command -v git)"
# variant 1: an old git ERRORS on the option (what `|| true` used to swallow as "no superproject")
{ printf '#!/usr/bin/env bash\n'
  printf 'for a in "$@"; do case "$a" in --show-superproject-working-tree) echo "error: unknown option" >&2; exit 129;; esac; done\n'
  printf 'exec "%s" "$@"\n' "$REAL_GIT"; } > "$SHIM/git"
chmod +x "$SHIM/git"
out="$(PATH="$SHIM:$PATH" MID=lanea run 2>&1)"; rc=$?
[ "$rc" -eq 12 ]; chk $? "old git (errors on the option) → rc=12 (got $rc)"
printf '%s' "$out" | grep -q 'could not answer --show-superproject-working-tree'; chk $? "the reason names the git capability gap, not a phantom submodule"
[ ! -e "$BEX/tracks-meta" ]; chk $? "nothing was mirrored before the refusal"
# variant 2: an old git ECHOES the unknown option back with rc=0 (what rev-parse actually does)
{ printf '#!/usr/bin/env bash\n'
  printf 'for a in "$@"; do case "$a" in --show-superproject-working-tree) echo "--show-superproject-working-tree"; exit 0;; esac; done\n'
  printf 'exec "%s" "$@"\n' "$REAL_GIT"; } > "$SHIM/git"
out="$(PATH="$SHIM:$PATH" MID=lanea run 2>&1)"; rc=$?
[ "$rc" -eq 12 ]; chk $? "old git (echoes the option back, rc=0) → rc=12 (got $rc)"
printf '%s' "$out" | grep -q 'echoed --show-superproject-working-tree back'; chk $? "the echo-back is named as such, not reported as 'a SUBMODULE of --show-…'"
MID=lanea run >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ]; chk $? "CONTROL: real git, same fixture → rc=0 (got $rc) — the shim, not the fixture, caused the refusals"

echo "── B8l symlinked HUB_DIR, BE_DIR unset → the default store is the PHYSICAL hub's sibling, and the commit lands THERE ──"
new_env b8l
mkdir -p "$ENV_DIR/real" "$ENV_DIR/link"
mv "$HUB" "$ENV_DIR/real/hubx"; HUB="$ENV_DIR/real/hubx"
ln -s "$ENV_DIR/real/hubx" "$ENV_DIR/link/hubx"
for d in "$ENV_DIR/real/fh-be" "$ENV_DIR/link/fh-be"; do   # physical sibling + logical decoy — BOTH valid repo roots
  mkdir -p "$d"; git -C "$d" init -q; git -C "$d" config user.email "lane@test.local"; git -C "$d" config user.name "lane-test"
done
printf 'private\n' > "$HUB/tracks/_meta/secret_card.md"
[ -L "$ENV_DIR/link/hubx" ] && [ -d "$ENV_DIR/link/hubx/tracks/_meta" ]; chk $? "CONTROL: the symlinked hub resolves and carries the fixture"
out="$(HOME="$ENV_DIR/home" HUB_DIR="$ENV_DIR/link/hubx" FH_MACHINE_ID=lanea bash "$SCRIPT" 2>&1)"; rc=$?
[ "$rc" -eq 0 ]; chk $? "run through the symlinked HUB_DIR completed rc=0 (got $rc)"
REAL_BE_PHYS="$(cd -P "$ENV_DIR/real/fh-be" && pwd -P)"   # mktemp dirs can themselves sit under a symlink (/var → /private/var on macOS)
printf '%s' "$out" | grep -qF "→ $REAL_BE_PHYS (git work tree root)"; chk $? "the destination line resolves to the PHYSICAL sibling"
[ -f "$ENV_DIR/real/fh-be/tracks-meta/secret_card.md" ]; chk $? "the file landed in the PHYSICAL sibling"
[ "$(git -C "$ENV_DIR/real/fh-be" log --oneline 2>/dev/null | grep -c .)" -ge 1 ]; chk $? "…and was COMMITTED there (a logical-path cd would have committed in the decoy instead)"
[ ! -e "$ENV_DIR/link/fh-be/tracks-meta" ] && [ "$(git -C "$ENV_DIR/link/fh-be" log --oneline 2>/dev/null | grep -c .)" -eq 0 ]; chk $? "the logical decoy sibling got neither files nor commits"

echo "── B8m an INDEPENDENT repo whose root sits inside another repo's tree is ACCEPTED (R3 A4 declined — decision pinned); the same path without its own .git is refused ──"
new_env b8m
OUTER="$ENV_DIR/outer"; mkdir -p "$OUTER"; git -C "$OUTER" init -q
BEX="$OUTER/companion"; mkdir -p "$BEX"
printf 'private\n' > "$HUB/tracks/_meta/secret_card.md"
MID=lanea run >/dev/null 2>&1; rc=$?
[ "$rc" -eq 12 ]; chk $? "KNOWN-NEGATIVE: a plain subdirectory of a foreign repo → rc=12 (got $rc)"
[ ! -e "$BEX/tracks-meta" ]; chk $? "…and nothing was mirrored into the foreign tree"
git -C "$BEX" init -q; git -C "$BEX" config user.email "lane@test.local"; git -C "$BEX" config user.name "lane-test"
MID=lanea run >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ]; chk $? "KNOWN-POSITIVE: the same path as its OWN repo root → rc=0 (got $rc)"
[ -f "$BEX/tracks-meta/secret_card.md" ]; chk $? "file landed in the nested independent repo"
[ ! -e "$OUTER/tracks-meta" ]; chk $? "nothing leaked into the enclosing repo's root"

echo "── B8n symlink retargeted BETWEEN validation and mirror → the mirror still lands in the VALIDATED root (S1 TOCTOU) ──"
new_env b8n
GOOD="$ENV_DIR/good-be"; FOREIGN="$ENV_DIR/foreign"
mv "$BEX" "$GOOD"; mkdir -p "$FOREIGN"; git -C "$FOREIGN" init -q
BEX="$ENV_DIR/be"; ln -s "$GOOD" "$BEX"
printf 'private\n' > "$HUB/tracks/_meta/secret_card.md"
mkdir "$GOOD/.sync.lock.d"                                   # hold the lock: the run validates, then polls
( MID=lanea run_loud > "$ENV_DIR/out" 2>&1; echo "$?" > "$ENV_DIR/rc" ) &
_pid=$!
wait_for_line "$ENV_DIR/out" 'destination: '; chk $? "CONTROL: the run passed validation and is waiting on the lock"
rm "$BEX"; ln -s "$FOREIGN" "$BEX"                           # retarget the REQUESTED path to a different valid repo root
sleep 1.5                                                    # ≥1 poll cycle on the retargeted spelling
[ ! -e "$FOREIGN/tracks-meta" ]; chk $? "while the validated root is still locked, nothing has been written to the retargeted repo"
rmdir "$GOOD/.sync.lock.d"                                   # release the lock in the VALIDATED root only
wait "$_pid"
rc="$(cat "$ENV_DIR/rc" 2>/dev/null || echo none)"
[ "$rc" = "0" ]; chk $? "run completed rc=0 after the lock was released (got $rc) — the loop waited on the PHYSICAL lock"
[ -f "$GOOD/tracks-meta/secret_card.md" ]; chk $? "the private file landed in the VALIDATED root"
[ ! -e "$FOREIGN/tracks-meta" ] && [ ! -d "$FOREIGN/.sync.lock.d" ]; chk $? "the retargeted repo got neither files nor a lock — the requested spelling was never re-resolved"

echo "── B8o the store loses its .git MID-RUN (after validation) → rc=12, never a 'mirrored' exit 0 (B6) ──"
new_env b8o
printf 'private\n' > "$HUB/tracks/_meta/secret_card.md"
mkdir "$BEX/.sync.lock.d"
( MID=lanea run_loud --quiet > "$ENV_DIR/out" 2>&1; echo "$?" > "$ENV_DIR/rc" ) &
_pid=$!
sleep 2                                                      # --quiet prints no destination line; the guard takes well under 2s
mv "$BEX/.git" "$BEX/.git.gone"                              # the work tree stops being one, after the guard passed
rmdir "$BEX/.sync.lock.d"
wait "$_pid"
rc="$(cat "$ENV_DIR/rc" 2>/dev/null || echo none)"
[ "$rc" = "12" ]; chk $? "mid-run loss of git identity → rc=12 (got $rc), not 0"
grep -q 'STOPPED being the root of its own git work tree' "$ENV_DIR/out"; chk $? "the refusal is printed even under --quiet"
[ -f "$BEX/tracks-meta/secret_card.md" ]; chk $? "CONTROL: the mirror itself had run — the belt fires AFTER the write, which is why rc must not be 0"

echo "── B8o2 a NESTED independent repo loses its .git mid-run → rc=12 and NOTHING is committed into the ENCLOSING repo (R4 S1) ──"
new_env b8o2
OUTER="$ENV_DIR/outer"; mkdir -p "$OUTER"; git -C "$OUTER" init -q; git -C "$OUTER" config user.email "lane@test.local"; git -C "$OUTER" config user.name "lane-test"
BEX="$OUTER/companion"; mkdir -p "$BEX"; git -C "$BEX" init -q; git -C "$BEX" config user.email "lane@test.local"; git -C "$BEX" config user.name "lane-test"
printf 'private\n' > "$HUB/tracks/_meta/secret_card.md"
mkdir "$BEX/.sync.lock.d"
( MID=lanea run_loud > "$ENV_DIR/out" 2>&1; echo "$?" > "$ENV_DIR/rc" ) &
_pid=$!
wait_for_line "$ENV_DIR/out" 'destination: '; chk $? "CONTROL: the nested repo root passed validation (B8m's accepted case) and the run is waiting on the lock"
mv "$BEX/.git" "$BEX/.git.gone"          # now a plain subdirectory INSIDE the enclosing repo — still 'inside a work tree'
rmdir "$BEX/.sync.lock.d"
wait "$_pid"
rc="$(cat "$ENV_DIR/rc" 2>/dev/null || echo none)"
[ "$rc" = "12" ]; chk $? "mid-run loss inside an enclosing repo → rc=12 (got $rc) — 'inside a work tree' alone would have passed"
grep -q 'ENCLOSING' "$ENV_DIR/out"; chk $? "the refusal names the enclosing-repo hazard"
[ "$(git -C "$OUTER" log --oneline 2>/dev/null | grep -c .)" -eq 0 ]; chk $? "the enclosing repo received NO commit"
[ -z "$(git -C "$OUTER" diff --cached --name-only 2>/dev/null)" ]; chk $? "…and nothing was staged there either"
[ -f "$BEX/tracks-meta/secret_card.md" ]; chk $? "CONTROL: the mirror itself had run (the belt fires after the write)"

echo "── B8p HUB_DIR that does not exist → the hub-identity refusal (rc=10) is reached, not a silent set -e death in the physical-path derivation (R4 A2) ──"
new_env b8p
out="$(HOME="$ENV_DIR/home" HUB_DIR="$ENV_DIR/does-not-exist" BE_DIR="$BEX" FH_MACHINE_ID=lanea bash "$SCRIPT" --quiet 2>&1)"; rc=$?
[ "$rc" -eq 10 ]; chk $? "nonexistent HUB_DIR → rc=10 (got $rc), not a bare set -e exit 1"
printf '%s' "$out" | grep -qi 'recognized hub'; chk $? "the refusal is printed (the guard was reached)"
[ ! -e "$BEX/tracks-meta" ]; chk $? "nothing was mirrored"

echo "── B8q .git swapped mid-run for a gitfile pointing at ANOTHER repo (same toplevel) → rc=12, nothing committed there (R5 S1) ──"
new_env b8q
OTHER="$ENV_DIR/other"; mkdir -p "$OTHER"; git -C "$OTHER" init -q; git -C "$OTHER" config user.email "lane@test.local"; git -C "$OTHER" config user.name "lane-test"
printf 'private\n' > "$HUB/tracks/_meta/secret_card.md"
mkdir "$BEX/.sync.lock.d"
( MID=lanea run_loud > "$ENV_DIR/out" 2>&1; echo "$?" > "$ENV_DIR/rc" ) &
_pid=$!
wait_for_line "$ENV_DIR/out" 'destination: '; chk $? "CONTROL: validated, waiting on the lock"
mv "$BEX/.git" "$BEX/.git.orig"; printf 'gitdir: %s/.git\n' "$OTHER" > "$BEX/.git"   # same work tree top, DIFFERENT repository
[ "$(git -C "$BEX" rev-parse --show-toplevel 2>/dev/null)" = "$(cd -P "$BEX" && pwd -P)" ]; chk $? "CONTROL: after the swap the toplevel is STILL \$BE — a path-only re-check would pass"
rmdir "$BEX/.sync.lock.d"
wait "$_pid"
rc="$(cat "$ENV_DIR/rc" 2>/dev/null || echo none)"
[ "$rc" = "12" ]; chk $? "identity switch → rc=12 (got $rc)"
grep -q 'git IDENTITY changed' "$ENV_DIR/out"; chk $? "the refusal names the identity change"
[ "$(git -C "$OTHER" log --oneline 2>/dev/null | grep -c .)" -eq 0 ] && [ -z "$(git --git-dir="$OTHER/.git" --work-tree="$BEX" diff --cached --name-only 2>/dev/null)" ]; chk $? "the other repository received neither a commit nor staged files"

echo "── B8r repo-selecting GIT_* env in the caller (a git hook's environment) cannot redirect the store (R5 S2) ──"
new_env b8r
PUBLIC="$ENV_DIR/public"; mkdir -p "$PUBLIC"; git -C "$PUBLIC" init -q; git -C "$PUBLIC" config user.email "lane@test.local"; git -C "$PUBLIC" config user.name "lane-test"
rm -rf "$BEX"; mkdir -p "$BEX"                                 # a PLAIN directory — must be refused
printf 'private\n' > "$HUB/tracks/_meta/secret_card.md"
[ "$(GIT_DIR="$PUBLIC/.git" GIT_WORK_TREE="$BEX" git -C "$BEX" rev-parse --is-inside-work-tree 2>/dev/null)" = "true" ]; chk $? "CONTROL: with the env set, git itself reports the plain dir as a work tree (the leak is real)"
out="$(GIT_DIR="$PUBLIC/.git" GIT_WORK_TREE="$BEX" MID=lanea run 2>&1)"; rc=$?
[ "$rc" -eq 12 ]; chk $? "plain dir + leaked GIT_DIR/GIT_WORK_TREE → rc=12 (got $rc)"
[ ! -e "$BEX/tracks-meta" ]; chk $? "nothing was mirrored"
[ "$(git -C "$PUBLIC" log --oneline 2>/dev/null | grep -c .)" -eq 0 ] && [ -z "$(git -C "$PUBLIC" diff --cached --name-only 2>/dev/null)" ]; chk $? "the env-selected repository received neither a commit nor staged files"

echo "── B9 a NESTED repo's .git/ in the destination does not trip the destination-newer guard (2026-09-15, 4th recurrence) ──"
new_env b9
fake_rp 'echo "[sync-from-be] (dry-run) pulled 1 file(s) companion → hub  (clean 1 · review 0)"; exit 0'
mkdir -p "$HUB/tracks/_meta/nested/.git"
printf 'real content\n'  > "$HUB/tracks/_meta/nested/real.md"
printf 'git-index-v1\n'  > "$HUB/tracks/_meta/nested/.git/index"
printf 'hub-v1\n'        > "$HUB/tracks/_meta/card.md"
MID=lanea run >/dev/null 2>&1
[ -f "$BEX/tracks-meta/nested/real.md" ]; chk $? "CONTROL: a real file under the nested repo still syncs (the exclusion is not over-broad)"
[ ! -e "$BEX/tracks-meta/nested/.git/index" ]; chk $? "the nested .git/ is never mirrored"
sleep 2
mkdir -p "$BEX/tracks-meta/nested/.git"
printf 'git-wrote-this-later\n' >> "$BEX/tracks-meta/nested/.git/index"
[ "$BEX/tracks-meta/nested/.git/index" -nt "$HUB/tracks/_meta/nested/.git/index" ]; chk $? "CONTROL: the destination .git/index IS newer + divergent (the incident is reproduced)"
out="$(MID=lanea run 2>&1)"; rc=$?
[ "$rc" -eq 0 ]; chk $? "a newer .git/index in the destination does NOT abort the sync (got rc=$rc)"
printf '%s' "$out" | grep -q 'SYNC ABORTED'; [ $? -ne 0 ]; chk $? "no abort wall is printed"
sleep 2
printf 'peer-node-added-this\n' >> "$BEX/tracks-meta/card.md"
out="$(MID=lanea run 2>&1)"; rc=$?
[ "$rc" -ne 0 ]; chk $? "KNOWN-POSITIVE: a newer REAL file still trips the guard (got rc=$rc) — excluding .git/ did not disarm it"

# ── tar 폴백 × SYNC_EXCLUDES 패리티 (2026-09-17) ────────────────────────────────
# 🟥 왜 있나: rsync 경로(:675)는 SYNC_EXCLUDES 배열을 쓰는데 **tar 폴백은 목록을 손으로 다시
#    적고 있었다.** 그래서 2026-09-16 에 배열에 `.git/` 를 넣었는데 폴백만 안 닫혔고, #735
#    머지에서 그 재작성이 떨어져 나가 **어느 PR 에도 안 실린 채** 남았다(peer 실측 2026-09-17).
#    ⚠️ 표기가 달라서 손으로 적었던 것이다(rsync `logs/` ↔ tar `logs`). 변환 한 줄이 그 이유를 없앴다.
echo ""
echo "── tar fallback × SYNC_EXCLUDES parity ──"

_sync_src() { sed -n '1,$p' "$REPO/scripts/sync-to-be.sh" 2>/dev/null; }
REPO="${REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# E: 계기가 대상을 못 읽으면 INSTRUMENT-ERROR 다 — «제외가 잘 된다» 로 접지 않는다.
_ex_line="$(_sync_src | grep -n '^SYNC_EXCLUDES=' | head -1)"
if [ -z "$_ex_line" ]; then
  FAIL=$((FAIL+1)); printf '  ❌ %s
' "E: INSTRUMENT-ERROR — SYNC_EXCLUDES 정의를 못 읽었다 (이 아래 판정은 무효)"
else
  ok "E: SYNC_EXCLUDES 정의를 읽었다 (계기 살아 있음)"

  # A: 현행이 배열을 쓰는가. 손목록으로 되돌아가면 여기서 적색.
  # 🟥 파이프로 흘리지 않는다 — 여기는 `_sync_src | grep -q` 였고 그 형태가 CI 를 간헐적으로
  #    거짓 빨강으로 만들었다(2026-09-21). 이 파일은 `set -uo pipefail`(:14) 이고 `grep -q` 는
  #    첫 매치에서 즉시 종료하는데, 그때 생산자가 아직 쓸 것이 **파이프 버퍼(64 KiB)보다 많이**
  #    남아 있으면 SIGPIPE 로 죽어 141 을 남긴다. pipefail 이 그 141 을 파이프라인 종료코드로
  #    올리므로 **grep 은 찾았는데 `if` 는 실패로 읽는다.** 대상은 70,726 B 이고 매치(:710)
  #    이후로 17,918 B 가 남아서 조건이 성립했다. 실측 4/200(러너가 느릴수록 더 자주 뜬다).
  #    ⇒ 파이프를 없앤다. `grep` 에 파일을 직접 주면 경합할 상대가 없다.
  #    레인은 scripts/test_pipefail_sigpipe_lanes.sh (결정적 known-pair 50/50 ↔ 0/50).
  if grep -q 'tar cf - "\${tex\[@\]}"' "$REPO/scripts/sync-to-be.sh"; then
    ok "A: tar 폴백이 SYNC_EXCLUDES 배열을 쓴다 (손목록 아님)"
  else
    FAIL=$((FAIL+1)); printf '  ❌ %s
' "A: tar 폴백이 배열을 안 쓴다 — 손목록으로 되돌아갔다"
  fi

  # C: 🟥 **클래스를 닫는 팔 — 그리고 초판은 장식이었다(2026-09-17 되돌림이 잡았다).**
  #    초판은 배열→tar 변환을 **이 레인 안에서 새로 적어** 테스트했다. 그래서 대상(sync-to-be.sh)을
  #    손목록으로 되돌려도 C 는 자기 합성 서브셸만 돌아 **통과했다** — A 만 빨개졌다.
  #    앵커가 대상을 안 보면 그것은 앵커가 아니다([[feedback_anchor_can_be_decorative]]).
  #    ⇒ 변환 줄을 **대상 소스에서 추출해서** 쓴다. 손목록으로 돌아가면 추출이 실패하고 C 가 적색.
  _tex_line="$(_sync_src | grep -m1 'tex+=("--exclude=')"
  if [ -z "$_tex_line" ]; then
    FAIL=$((FAIL+1)); printf '  ❌ %s\n' "C: tar 폴백에 배열 변환 줄이 없다 — 목록이 갈라졌다(클래스 열림)"
  else
    _c_tmp="$(mktemp -d)"
    mkdir -p "$_c_tmp/src/zzz_probe_dir" "$_c_tmp/dst"
    echo probe > "$_c_tmp/src/zzz_probe_dir/x.txt"
    echo real  > "$_c_tmp/src/keep.md"
    # 대상에서 뽑은 그 줄을 그대로 실행한다 — 우리가 다시 적지 않는다.
    /bin/bash -c '
      SYNC_EXCLUDES=(".gitkeep" "zzz_probe_dir/")
      tex=()
      '"$_tex_line"'
      ( cd "'"$_c_tmp"'/src" && tar cf - "${tex[@]}" . ) | ( cd "'"$_c_tmp"'/dst" && tar xf - )' 2>/dev/null
    if [ ! -f "$_c_tmp/dst/zzz_probe_dir/x.txt" ] && [ -f "$_c_tmp/dst/keep.md" ]; then
      ok "C: 대상에서 뽑은 변환 줄이 새 항목을 제외한다 (클래스가 닫혔다 · 실물은 통과)"
    else
      FAIL=$((FAIL+1)); printf '  ❌ %s\n' "C: 대상의 변환 줄이 새 항목을 반영 안 한다"
    fi
    rm -rf "$_c_tmp"
  fi

  # 복귀 경로도 같은 뿌리다 — 나가는 쪽만 막으면 돌아오는 쪽으로 들어온다.
  if grep -q "! -path '\*/\.git/\*'" "$REPO/scripts/sync-from-be.sh" 2>/dev/null; then
    ok "R: 복귀 경로(sync-from-be) 도 .git 을 제외한다"
  else
    FAIL=$((FAIL+1)); printf '  ❌ %s
' "R: 복귀 경로에 .git 제외가 없다 — 돌아오는 쪽으로 들어온다"
  fi
fi

# ── find predicate (check_dest_newer) × SYNC_EXCLUDES parity — the THIRD spot (2026-09-18) ────
# 🟥 왜 있나: #740 이 tar 폴백(④)과 복귀 경로(⑤)를 닫았지만, 그 커밋 자신의 메시지가 "남은 것"
#    으로 지목한 자리는 손대지 않았다 — check_dest_newer() 의 find 술어(구 :453 주석)다. 그 자리는
#    SYNC_EXCLUDES 를 find 문법으로 손으로 다시 적고 있었고, sync_guard_check.sh §1 은 텍스트
#    대조만 했지 단일소스로 묶지는 않았다(대조 로직 자체가 죽거나 비면 다섯 번째로 재발한다 —
#    실제로 ④⑤ 가 그렇게 한 번 유실됐었다, tracks/_meta/parallel_fhgate_2026-09-15.md §3-e-0-a).
#    check_dest_newer() 는 이제 SYNC_EXCLUDES 에서 뽑은 배열을 쓴다(tar 폴백과 같은 '/' 유무 변환).
echo ""
echo "── find predicate (check_dest_newer) × SYNC_EXCLUDES parity — the third spot ──"

# E: 계기가 대상(check_dest_newer 함수 본문)을 못 읽으면 INSTRUMENT-ERROR 다.
_cdn_body="$(_sync_src | awk '/^check_dest_newer\(\) \{/,/^}/')"
if [ -z "$_cdn_body" ]; then
  no "E: INSTRUMENT-ERROR — check_dest_newer() 를 못 읽었다 (이 아래 판정은 무효)"
else
  ok "E: check_dest_newer() 를 읽었다 (계기 살아 있음)"

  # A: 현재 find 가 배열을 쓰는가(손목록으로 되돌아가면 여기서 적색).
  if printf '%s' "$_cdn_body" | grep -q 'find "\$src" -type f \${dexclude\[@\]'; then
    ok "A: check_dest_newer 의 find 가 SYNC_EXCLUDES 에서 뽑은 배열을 쓴다 (손목록 아님)"
  else
    no "A: check_dest_newer 의 find 가 배열을 안 쓴다 — 손목록으로 되돌아갔다"
  fi

  # C: 🟥 클래스를 닫는 팔 — 2026-09-18 재작성. 초판은 «변환 루프» 만 뽑아 실행했는데,
  #    cross-family codex 가 그 형태의 공허-초록 경로를 냈다: 루프가 옳아도 그 뒤에서
  #    `dexclude=()` 로 끊기면 추출본은 여전히 통과하고 production `find` 만 샌다.
  #    그래서 조각이 아니라 **함수 전체를 뽑아 실제로 호출**한다 — 실 `find` 줄이 그 안에
  #    있으므로 «변환이 production 경로로 들어간다» 가 실행으로 증명된다.
  _cdn_fn="$(_sync_src | awk '/^check_dest_newer\(\) \{/,/^}/')"
  if [ -z "$_cdn_fn" ]; then
    no "C: check_dest_newer() 전문을 못 뽑았다 (계기 오류 — 아래 판정 무효)"
  else
    _c_tmp="$(mktemp -d)"
    mkdir -p "$_c_tmp/src/zzz_probe_dir" "$_c_tmp/dst/zzz_probe_dir"
    echo real > "$_c_tmp/src/keep.md";            echo real > "$_c_tmp/dst/keep.md"
    echo probe > "$_c_tmp/src/zzz_probe_dir/x.txt"
    echo probe > "$_c_tmp/dst/zzz_probe_dir/x.txt"
    # 목적지의 «제외 대상» 을 더 새롭게 만든다: 제외가 살아 있으면 NEWER_HITS 에 안 뜬다.
    sleep 1; touch "$_c_tmp/dst/zzz_probe_dir/x.txt"
    _run_cdn() {   # $1 = SYNC_EXCLUDES 선언 문자열
      /bin/bash -c '
        set -u
        '"$1"'
        NEWER_HITS=""
        _dest_content_differs() { return 0; }
        '"$_cdn_fn"'
        check_dest_newer "'"$_c_tmp"'/src" "'"$_c_tmp"'/dst"
        printf "%s" "$NEWER_HITS"
      ' 2>&1
    }
    # ARM: 새 항목을 SYNC_EXCLUDES 에만 추가한다 — 손으로 적는 자리가 없으므로 반영돼야 한다.
    _arm="$(_run_cdn 'SYNC_EXCLUDES=(".gitkeep" "zzz_probe_dir/")')"
    # CONTROL: 같은 실행에서 그 항목을 빼면 «반드시» 떠야 한다. 안 뜨면 이 레인은
    # «제외가 먹혔다» 와 «픽스처가 애초에 신호를 안 만든다» 를 구분하지 못한다.
    _ctl="$(_run_cdn 'SYNC_EXCLUDES=(".gitkeep")')"
    if printf '%s' "$_ctl" | grep -q 'zzz_probe_dir/x.txt'; then
      ok "C-control: 제외에서 빼면 실제로 NEWER_HITS 에 뜬다 (픽스처가 신호를 만든다)"
      if printf '%s' "$_arm" | grep -q 'zzz_probe_dir/x.txt'; then
        no "C: SYNC_EXCLUDES 에 추가한 새 항목이 production find 에 반영 안 된다 — arm=[$_arm]"
      else
        ok "C: 새 항목이 배열에만 추가돼도 production check_dest_newer 가 제외한다 (클래스 닫힘)"
      fi
    else
      no "C-control: 컨트롤이 신호를 못 만들었다 — 계기 오류 (arm 판정 무효). ctl=[$_ctl]"
    fi
    # E2: 빈 배열에서 죽지 않는가 (cross-family codex 지목: set -u 거짓중단)
    _empty="$(_run_cdn 'SYNC_EXCLUDES=()')"
    if printf '%s' "$_empty" | grep -q 'unbound variable'; then
      no "E2: SYNC_EXCLUDES 가 비면 unbound variable 로 죽는다 — sync 전체가 거짓 중단된다"
    else
      ok "E2: 빈 SYNC_EXCLUDES 에서도 죽지 않는다 (거짓 중단 없음)"
    fi
    rm -rf "$_c_tmp"
  fi
fi

echo ""
echo "════ lanes: $PASS passed · $FAIL failed ════"
[ "$FAIL" -eq 0 ]

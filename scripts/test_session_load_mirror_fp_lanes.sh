#!/usr/bin/env bash
# test_session_load_mirror_fp_lanes.sh — lanes for fh_session_load.sh §3 «NEWER THAN SESSION CARD».
#
# Defect (measured 2026-09-26): sync-to-be.sh rewrites every tracks/_meta mirror it touches, so a
# mirror's mtime is «when the sync ran», not «when its content was new». Two result files the card
# had already absorbed were listed under «READ THESE BEFORE ACTING». The fix demotes a $TM mirror
# whose line 1 is EXACTLY the sync banner, whose remaining bytes equal the hub canonical copy, AND
# whose content the companion git committed at/before the card (clean tree).
#
# The lanes are a known pair plus the fail-open guards: the FP (L1) must stay quiet, and every
# case that is NOT provably old-and-identical (L2–L6, L8–L11) must still be listed. L0 is the instrument
# control — the hook actually reached the freshness block — so a script that dies early cannot
# pass L1 by printing nothing.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBJECT="$HERE/fh_session_load.sh"
[ -f "$SUBJECT" ] || { echo "HARNESS-ERROR  subject missing: $SUBJECT"; exit 2; }

T="$(mktemp -d "${TMPDIR:-/tmp}/fhsl_mirror.XXXXXX")" || { echo "HARNESS-ERROR  mktemp"; exit 2; }
trap 'rm -rf "$T"' EXIT
HUB="$T/hub"; BE="$T/be"
mkdir -p "$HUB/tracks/_meta/sub" "$BE/tracks-meta/sub" "$BE/handoff"
git -C "$BE" init -q 2>/dev/null || { echo "HARNESS-ERROR  git init"; exit 2; }

BANNER='<!-- MIRROR COPY — synced from the forge-harness hub. Do NOT edit here; the next sync overwrites it. Edit the canonical file under the hub instead. -->'
mirror() { { printf '%s\n' "$BANNER"; cat "$1"; } > "$2"; }   # $1 = hub file, $2 = mirror path

echo card > "$HUB/tracks/_meta/reference_next_session_starter.md"
touch -t 202601010000 "$HUB/tracks/_meta/reference_next_session_starter.md"   # card = old

# L1 FP: identical mirror, restamped by sync (mtime newer than card)
printf 'result body\nline2\n' > "$HUB/tracks/_meta/same.md"
mirror "$HUB/tracks/_meta/same.md" "$BE/tracks-meta/same.md"
printf 'nested\n' > "$HUB/tracks/_meta/sub/nested_same.md"
mirror "$HUB/tracks/_meta/sub/nested_same.md" "$BE/tracks-meta/sub/nested_same.md"
# L2 known-positive: genuine non-mirror file, newer
printf 'genuinely new\n' > "$BE/tracks-meta/genuine.md"
# L3 mirror whose content differs from the hub copy
printf 'hub version\n' > "$HUB/tracks/_meta/differs.md"
{ printf '%s\n' "$BANNER"; printf 'remote version\n'; } > "$BE/tracks-meta/differs.md"
# L4 mirror whose hub canonical is absent (arrived from another machine)
{ printf '%s\n' "$BANNER"; printf 'only remote\n'; } > "$BE/tracks-meta/nohub.md"
# L5 line 1 merely MENTIONS the phrase — not the exact banner; rest identical to a hub file
printf 'body\n' > "$HUB/tracks/_meta/lookalike.md"
{ printf 'notes on MIRROR COPY handling\n'; cat "$HUB/tracks/_meta/lookalike.md"; } > "$BE/tracks-meta/lookalike.md"
# L6 outside $TM: a bannered identical file under handoff/ is NOT demoted
printf 'handoff body\n' > "$HUB/tracks/_meta/ho.md"
mirror "$HUB/tracks/_meta/ho.md" "$BE/handoff/ho.md"
# L7 identical mirror OLDER than the card: neither listed nor noted
printf 'old\n' > "$HUB/tracks/_meta/old_same.md"
mirror "$HUB/tracks/_meta/old_same.md" "$BE/tracks-meta/old_same.md"
touch -t 202512010000 "$BE/tracks-meta/old_same.md"

# L8 cross-family [high]: identical mirror, but first committed AFTER the card (written today)
printf 'todays result\n' > "$HUB/tracks/_meta/new_today.md"
mirror "$HUB/tracks/_meta/new_today.md" "$BE/tracks-meta/new_today.md"
# L9 identical mirror whose committed version is OLD but the tree is dirty (new content, unsynced commit)
printf 'v1\n' > "$HUB/tracks/_meta/dirty.md"; mirror "$HUB/tracks/_meta/dirty.md" "$BE/tracks-meta/dirty.md"
# L10 identical mirror never committed (untracked)
printf 'untracked\n' > "$HUB/tracks/_meta/untracked.md"

G() { git -C "$BE" -c user.name=t -c user.email=t@t "$@"; }
OLD='2025-12-15T00:00:00'   # before the card (2026-01-01)
G add tracks-meta/same.md tracks-meta/sub/nested_same.md tracks-meta/old_same.md tracks-meta/dirty.md \
  tracks-meta/genuine.md tracks-meta/differs.md tracks-meta/nohub.md tracks-meta/lookalike.md handoff/ho.md >/dev/null
GIT_AUTHOR_DATE="$OLD" GIT_COMMITTER_DATE="$OLD" G commit -qm old >/dev/null || { echo "HARNESS-ERROR  commit old"; exit 2; }
G add tracks-meta/new_today.md >/dev/null; G commit -qm today >/dev/null || { echo "HARNESS-ERROR  commit today"; exit 2; }
printf 'v2\n' > "$HUB/tracks/_meta/dirty.md"; mirror "$HUB/tracks/_meta/dirty.md" "$BE/tracks-meta/dirty.md"
mirror "$HUB/tracks/_meta/untracked.md" "$BE/tracks-meta/untracked.md"
touch "$BE/tracks-meta/same.md" "$BE/tracks-meta/sub/nested_same.md"   # the sync restamp
touch -t 202512010000 "$BE/tracks-meta/old_same.md"                   # re-assert L7 (older than card)

OUT="$(printf '{"source":"startup"}' | HUB_DIR="$HUB" BE_DIR="$BE" bash "$SUBJECT" 2>&1)"
# The NEWER list = the «  - » lines right after the header.
LIST="$(printf '%s\n' "$OUT" | awk '/NEWER THAN SESSION CARD/{on=1;next} on&&/^  - /{print;next} on{exit}')"
NOTE="$(printf '%s\n' "$OUT" | /usr/bin/grep -A1 'mirror cop(y/ies) newer than the card' || true)"

pass=0; fail=0
ok()  { echo "PASS  $1"; pass=$((pass+1)); }
bad() { echo "FAIL  $1"; fail=$((fail+1)); }
# Substring tests use `case`, not `printf | grep -q`: under pipefail an early-exiting grep can
# SIGPIPE the printf and flip the verdict (pipefail class-lock lane L12c).
has()    { case "$1" in *"$2"*) return 0 ;; esac; return 1; }
listed() { has "$LIST" "- $1"; }

has "$OUT" 'NEWER THAN SESSION CARD' \
  && ok "L0 control — hook reached the NEWER block" \
  || { bad "L0 control — NEWER block never printed (instrument dead)"; printf '%s\n' "$OUT" | tail -15; }

listed "tracks-meta/same.md"            && bad "L1 FP — identical mirror listed as NEWER" || ok "L1 FP — identical mirror not listed"
listed "tracks-meta/sub/nested_same.md" && bad "L1b FP — nested identical mirror listed" || ok "L1b FP — nested identical mirror not listed"
has "$NOTE" 'same.md' && has "$NOTE" '   ⓘ 2 ' \
  && ok "L1c demoted mirrors are NAMED in the note (not silently dropped), count=2" \
  || bad "L1c demoted mirrors missing from the note: [$NOTE]"
listed "tracks-meta/genuine.md"   && ok "L2 known-positive — genuine newer file listed"      || bad "L2 genuine newer file NOT listed (fail-open)"
listed "tracks-meta/differs.md"   && ok "L3 differing mirror listed"                          || bad "L3 differing mirror NOT listed (fail-open)"
listed "tracks-meta/nohub.md"     && ok "L4 mirror with no hub copy listed"                   || bad "L4 mirror with no hub copy NOT listed (fail-open)"
listed "tracks-meta/lookalike.md" && ok "L5 non-exact banner listed"                          || bad "L5 non-exact banner NOT listed (substring match = fail-open)"
listed "handoff/ho.md"            && ok "L6 bannered file outside \$TM listed"                || bad "L6 outside-\$TM file demoted"
{ listed "tracks-meta/old_same.md" || has "$NOTE" 'old_same'; } \
  && bad "L7 older-than-card mirror surfaced" || ok "L7 older-than-card mirror stays quiet"

listed "tracks-meta/new_today.md" && ok "L8 identical mirror committed AFTER the card listed" || bad "L8 today's identical mirror hidden (fail-open — cross-family [high])"
listed "tracks-meta/dirty.md"     && ok "L9 identical-but-dirty mirror listed"             || bad "L9 dirty mirror hidden (fail-open)"
listed "tracks-meta/untracked.md" && ok "L10 identical-but-untracked mirror listed"        || bad "L10 untracked mirror hidden (fail-open)"

# L11 git unavailable → demotion OFF (mirror listed) AND the output says so — never silently.
NOGIT="$T/nogit"; mkdir -p "$NOGIT"
for x in /bin/* /usr/bin/*; do
  b="${x##*/}"; [ "$b" = git ] && continue; [ -e "$NOGIT/$b" ] || ln -s "$x" "$NOGIT/$b" 2>/dev/null
done
OUT2="$(printf '{"source":"startup"}' | PATH="$NOGIT" HUB_DIR="$HUB" BE_DIR="$BE" /bin/bash "$SUBJECT" 2>&1)"
LIST2="$(printf '%s\n' "$OUT2" | awk '/NEWER THAN SESSION CARD/{on=1;next} on&&/^  - /{print;next} on{exit}')"
if has "$LIST2" "- tracks-meta/same.md" \
   && has "$OUT2" 'git unavailable — mirror-copy demotion is OFF'; then
  ok "L11 git unavailable → mirror listed + stated"
else
  bad "L11 git unavailable → silent or demoted"; printf '%s\n' "$OUT2" | tail -8
fi

echo "── mirror-FP lanes: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]

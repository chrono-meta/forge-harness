#!/usr/bin/env bash
# test_selfcheck_shard_lanes.sh — known-pair anchor for `selfcheck.sh --shard i/N`.
#
# WHAT IS PROVED, and how (every claim below is a lane, with a control that can fail):
#   S1  bad --shard arguments are refused with rc 2 and run nothing (not a pass).
#   S2  UNION: the suites shard 1..N run are exactly the suites an unsharded plan (1/1) runs.
#   S3  DISJOINT: no suite basename is run by two shards.
#   S4  NON-VACUOUS: the full set is large and contains a suite we know is wired (a lane that
#       compares two empty sets passes — the control is a fact about the target, not the shim).
#   S5  KNOWN-NEGATIVE: the same duplicate/union detector, pointed at a selfcheck whose assignment is
#       broken on purpose (every shard "owns" every suite), must go RED. A detector that cannot fail
#       proves nothing about S2/S3.
#   S6  --shard ABSENT = today: the lifted helper block defines no `bash` function and every helper
#       answers "run it".
#   S7  every shard owns at least one suite for N in 2..4 (an empty shard is a wasted runner and a
#       sign the plan collapsed).
# The runs are DRY (`--shard-dry`): nothing is executed, the decision is appended to $FH_SHARD_TRACE.
# So this suite costs seconds, and it cannot recurse into itself (a dry run never runs a suite).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SC="$ROOT/scripts/selfcheck.sh"
[ -f "$SC" ] || { echo "FAIL  selfcheck shard lanes: subject $SC missing"; exit 1; }
T=$(mktemp -d "${TMPDIR:-/tmp}/shardlanes.XXXXXX") || { echo "HARNESS ERROR  mktemp -d failed — lanes NOT run (not a pass)"; exit 10; }
: "${T:?}"
trap 'rm -rf "$T"' EXIT
pass=0; failn=0
chk() { # chk <rc> <label>
  if [ "$1" -eq 0 ]; then pass=$((pass + 1)); echo "  ✅ $2"; else failn=$((failn + 1)); echo "  ❌ $2"; fi
}

# plan <selfcheck> <root> <i> <N> <out> — one dry run; the trace file is the evidence.
plan() {
  : > "$5"
  ( cd "$2" && env -u FH_SELFCHECK_SHARD FH_SHARD_TRACE="$5" bash "$1" --shard "$3/$4" --shard-dry >/dev/null 2>&1 )
}
names() { awk '$1 == "RUN" { print $2 }' "$1" | LC_ALL=C sort -u; }

# ── S1 argument validation ────────────────────────────────────────────────────────────────────
for bad in 0/4 5/4 2 x/4 2/x 1/0 "" 01/4 /4 1/04 999/1000; do   # 01/4 · /4 · 1/04 · 999/1000 = codex R1 2026-10-31 (ran nothing, printed PASS)
  out=$(cd "$ROOT" && env -u FH_SELFCHECK_SHARD bash "$SC" --shard "$bad" --shard-dry 2>&1); rc=$?
  [ "$rc" -eq 2 ] && printf '%s' "$out" | grep -q 'HARNESS ERROR'; chk $? "S1 --shard '$bad' refused with rc 2 and a HARNESS ERROR line (rc=$rc)"
done

# ── S2 / S3 / S4 / S7 union and disjointness ────────────────────────────────────────────────
full="$T/full.txt"; plan "$SC" "$ROOT" 1 1 "$full"
names "$full" > "$T/full.names"
nfull=$(wc -l < "$T/full.names" | tr -d ' ')
[ "$nfull" -ge 100 ]; chk $? "S4 control: the unsharded plan names $nfull suites (>= 100 — a plan of 0 would make S2/S3 vacuous)"
grep -qx 'test_mutation_probe_lanes.sh' "$T/full.names"; chk $? "S4 control: a suite known to be wired (test_mutation_probe_lanes.sh) is in the plan"
grep -qx 'test_selfcheck_shard_lanes.sh' "$T/full.names"; chk $? "S4 control: this suite is itself in the plan (an unwired anchor is prose)"

# check_split <selfcheck> <root> <N> <tag> → rc 0 iff union == full AND disjoint AND (all non-empty)
check_split() {
  local sc="$1" root="$2" n="$3" tag="$4" i u_ok=0 dup_ok=0 empty_ok=0
  : > "$T/$tag.all"
  for i in $(seq 1 "$n"); do
    plan "$sc" "$root" "$i" "$n" "$T/$tag.$i.trace"
    names "$T/$tag.$i.trace" > "$T/$tag.$i.names"
    [ -s "$T/$tag.$i.names" ] || empty_ok=1
    cat "$T/$tag.$i.names" >> "$T/$tag.all"
  done
  LC_ALL=C sort "$T/$tag.all" | LC_ALL=C uniq -d > "$T/$tag.dups"
  [ -s "$T/$tag.dups" ] && dup_ok=1
  LC_ALL=C sort -u "$T/$tag.all" > "$T/$tag.union"
  cmp -s "$T/$tag.union" "$T/full.names" || u_ok=1
  SPLIT_UNION_BAD=$u_ok; SPLIT_DUP=$dup_ok; SPLIT_EMPTY=$empty_ok
  [ $u_ok -eq 0 ] && [ $dup_ok -eq 0 ] && [ $empty_ok -eq 0 ]
}
for n in 2 3 4; do
  check_split "$SC" "$ROOT" "$n" "n$n"
  [ "$SPLIT_UNION_BAD" -eq 0 ]; chk $? "S2 N=$n: union of shards 1..$n == the unsharded plan ($(wc -l < "$T/n$n.union" | tr -d ' ') suites)"
  [ "$SPLIT_DUP" -eq 0 ]; chk $? "S3 N=$n: no suite runs in two shards ($(wc -l < "$T/n$n.dups" | tr -d ' ') duplicated)"
  [ "$SPLIT_EMPTY" -eq 0 ]; chk $? "S7 N=$n: every shard owns at least one suite"
done

# ── S5 known-negative: break the assignment, the same detector must go red ───────────────────
# The mutant lives in a scratch tree of symlinks (selfcheck cd's to its own parent, so a copy has to sit
# under a root that looks like the repo). Nothing is written into the real tree.
MR="$T/mutroot"; mkdir -p "$MR/scripts"
for e in "$ROOT"/* "$ROOT"/.[!.]*; do
  [ -e "$e" ] || continue
  b=$(basename "$e"); [ "$b" = scripts ] && continue
  ln -s "$e" "$MR/$b"
done
for e in "$ROOT"/scripts/*; do
  b=$(basename "$e"); [ "$b" = selfcheck.sh ] && continue
  ln -s "$e" "$MR/scripts/$b"
done
# the one-line break: every shard owns every suite
sed 's|^  _shard_mine() { .*$|  _shard_mine() { return 0; }|' "$SC" > "$MR/scripts/selfcheck.sh"
cmp -s "$SC" "$MR/scripts/selfcheck.sh" && echo "  (!) mutant identical to subject — the _shard_mine line moved; S5 below is void"
cmp -s "$SC" "$MR/scripts/selfcheck.sh"; chk $((1 - $?)) "S5 control: the mutation was APPLIED (mutant differs from subject)"
check_split "$MR/scripts/selfcheck.sh" "$MR" 3 mut
[ "$SPLIT_DUP" -eq 1 ]; chk $? "S5 known-negative: with every shard owning every suite the duplicate detector goes RED"

# ── S6 --shard absent = today ────────────────────────────────────────────────────────────────
START=$(grep -n '^# ── --shard i/N' "$SC" | head -1 | cut -d: -f1)
END=$(grep -n '^  _shard_inline_skip() { return 1; }' "$SC" | head -1 | cut -d: -f1)
if [ -z "$START" ] || [ -z "$END" ]; then
  chk 1 "S6 the shard block markers are still in selfcheck.sh (lane would test nothing)"
else
  sed -n "${START},$((END + 1))p" "$SC" > "$T/block.sh"
  res=$(cd "$ROOT" && env -u FH_SELFCHECK_SHARD bash -c '
    set -u
    f="$1"; set --              # no arguments, as `npm test` calls it
    . "$f"
    if declare -F bash >/dev/null 2>&1; then echo "BASH-SHADOWED"; fi
    _shard_inline;          echo "inline=$?"
    _shard_mine anything;   echo "mine=$?"
    _shard_skip anything;   echo "skip=$?"
    _shard_inline_skip x;   echo "inlineskip=$?"
  ' _ "$T/block.sh" 2>&1)
  # control for the line below: the SAME block with --shard given must define the shim (else "absent" is vacuous)
  resS=$(cd "$ROOT" && env -u FH_SELFCHECK_SHARD bash -c 'f="$1"; shift; set -- --shard 2/4 --shard-dry; . "$f"; declare -F bash >/dev/null 2>&1 && echo BASH-SHADOWED' _ "$T/block.sh" 2>&1)
  printf '%s' "$resS" | grep -q 'BASH-SHADOWED'; chk $? "S6 control: with --shard 2/4 the same block DOES define the bash shim"
  printf '%s' "$res" | grep -q 'BASH-SHADOWED'; chk $((1 - $?)) "S6 without --shard no function named bash exists"
  printf '%s' "$res" | grep -qx 'inline=0'; chk $? "S6 without --shard inline checks run"
  printf '%s' "$res" | grep -qx 'mine=0'; chk $? "S6 without --shard every suite is mine"
  printf '%s' "$res" | grep -qx 'skip=1'; chk $? "S6 without --shard nothing is skipped"
  printf '%s' "$res" | grep -qx 'inlineskip=1'; chk $? "S6 without --shard no inline check is skipped"
fi

# ── notes (printed, never a verdict) ────────────────────────────────────────────────────────
if [ -f "$ROOT/scripts/selfcheck_shard_weights.txt" ]; then
  awk 'NF >= 2 && $1 ~ /^[0-9.]+$/ && $2 != "@inline" { print $2 }' "$ROOT/scripts/selfcheck_shard_weights.txt" | LC_ALL=C sort -u > "$T/w.names"
  stale=$(comm -13 "$T/full.names" "$T/w.names" | wc -l | tr -d ' ')
  unlisted=$(comm -23 "$T/full.names" "$T/w.names" | wc -l | tr -d ' ')
  echo "  NOTE  weights file: $(wc -l < "$T/w.names" | tr -d ' ') rows · $stale name(s) no longer in the plan · $unlisted suite(s) unlisted (placed by hash)"
else
  echo "  NOTE  no scripts/selfcheck_shard_weights.txt — every suite is placed by hash"
fi

echo "════ lanes: $pass passed · $failn failed ════"
[ "$failn" -eq 0 ]

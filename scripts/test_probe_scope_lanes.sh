#!/usr/bin/env bash
# test_probe_scope_lanes.sh — regression lanes for scripts/probe_scope_check.sh.
#
# WHY (2026-08-03): the script had 15 sibling checkers with a `test_*_lanes.sh` and none of its own,
# so three repairs shipped that day could each be reverted with nothing turning red — which the
# script's own header forbids in the same words ("a repair with no arm that goes red when you revert
# it is not anchored"). An adversarial round found that gap, not the author.
#
# SCOPE, MEASURED — read this before treating a green run as coverage:
#   * the SUCCESS-LINE honesty lane below is the only one of the three repairs that is verdict-
#     bearing; it is anchored here.
#   * the `${BASH_SOURCE[0]}` change is INERT on every invocation form this repo uses ($0 and
#     BASH_SOURCE produced byte-identical output for bash-relative, bash-absolute, direct-exec and
#     symlink calls). It is kept as hygiene, not as a fix, and is deliberately NOT laned — a lane
#     that cannot fail is the decorative-anchor defect this file exists to prevent.
#   * the unreadable-asset routing is DIAGNOSTIC-ONLY (both forms exit 3 because pipefail already
#     propagates awk's status). Its MESSAGE is laned below; its verdict never changed.
#
# Usage: bash scripts/test_probe_scope_lanes.sh
# Exit 0 = all lanes pass · 1 = a lane failed

set -uo pipefail
FH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SUBJ="$FH/scripts/probe_scope_check.sh"
[ -r "$SUBJ" ] || { echo "❌ lanes: $SUBJ not readable" >&2; exit 1; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/pscl.XXXXXX")" || exit 1
trap 'rm -rf -- "$TMP"' EXIT
pass=0; fail=0; unmeas=0

hdr() { printf '| Probe ID | Input Pattern | Expected Behavior | Scope | Class |\n|---|---|---|---|---|\n'; }
chk() { # $1 label, $2 = 0 ok
  if [ "$2" -eq 0 ]; then printf "  ✅ %s\n" "$1"; pass=$((pass+1))
  else printf "  ❌ %s\n" "$1"; fail=$((fail+1)); fi
}
# A lane whose PREMISE could not be built has measured nothing. That is neither a pass nor a verdict
# about the subject, so it gets its own glyph and its own counter, and the suite still exits 1.
unmeasured() { printf "  ⬜ %s\n" "$1"; unmeas=$((unmeas+1)); }

echo "── probe_scope_check lanes ──"

# base fixture, built first — every lane below derives from it (see the note at L2)
awk -F'|' 'NR<=2 || ($5 ~ /§/ && $5 ~ /\.md[[:space:]]*§/)' "$FH/.claude/regression/probes.md" > "$TMP/clean.md"

# ── L1 — the success line must not speak for cells it could not check. A corpus whose only scope is
# a NON-MARKDOWN asset produced `⚠️ UNCHECKABLE` and then, on the very next line, the unqualified
# "every probe Scope resolves to a real section". The counter behind that line originally tallied
# only the UNPARSED class and ignored the non-markdown one.
{ cat "$TMP/clean.md"; printf '| `X-NONMD-01` | t | e | package.json §Anything | mandatory-pass |\n'; } > "$TMP/nonmd.md"
out="$(bash "$SUBJ" --fixture-corpus "$TMP/nonmd.md" 2>&1)"
printf '%s' "$out" | grep -q 'UNVALIDATED'; chk "non-markdown scope → success line says UNVALIDATED" $?
printf '%s' "$out" | grep -qE '✅ every probe Scope resolves to a real section$'; \
  [ $? -ne 0 ]; chk "non-markdown scope → the UNQUALIFIED success line is NOT printed" $?

# ── L2 — a corpus this parser can fully decompose must still get the plain line, or the guard is
# just over-blocking. Without this lane, "always print UNVALIDATED" would pass L1.
# The fixture is DERIVED from the real corpus, not hand-written: `--fixture-corpus` still runs
# control A, which looks for specific rows, so a minimal hand-made corpus fails control A and the
# lane would go red for a reason that has nothing to do with what it claims to test. Filter the real
# rows down to the fully-decomposable ones (markdown asset + `§` notation).
awk -F'|' 'NR<=2 || ($5 ~ /§/ && $5 ~ /\.md[[:space:]]*§/)' "$FH/.claude/regression/probes.md" > "$TMP/clean.md"
out="$(bash "$SUBJ" --fixture-corpus "$TMP/clean.md" 2>&1)"
printf '%s' "$out" | grep -qE '✅ every probe Scope resolves to a real section$'; \
  chk "fully-decomposable corpus → plain success line (guard does not over-block)" $?

# ── L3 — the UNVALIDATED count must be the SUM of both classes. One UNPARSED + one non-markdown is
# two, and the first version of the counter said one.
{ cat "$TMP/clean.md"
  printf '| `X-NONMD-02` | t | e | package.json §Anything | mandatory-pass |\n'
  printf '| `X-UNPARSED-01` | t | e | scripts/selfcheck.sh · package.json | mandatory-pass |\n'; } > "$TMP/both.md"
out="$(bash "$SUBJ" --fixture-corpus "$TMP/both.md" 2>&1)"
printf '%s' "$out" | grep -qE '2 cell\(s\) UNVALIDATED'; chk "both unvalidated classes are summed, not just one" $?

# ── L4 — an asset that EXISTS but cannot be read is an instrument error, not a stale probe. The
# verdict is exit 3 either way (pipefail already propagates awk); what this lane pins is that the
# operator is not sent to edit a probe that was fine.
# 🟥 THE PREMISE IS NOT FREE, AND IT IS PROBED (2026-11-09). Two halves must both hold: the
# fixture asset must EXIST, and it must be unreadable BY THIS PROCESS. Measured here, both ways:
#   * as root, `chmod 000` does not bind uid 0, so the asset stays readable and the subject
#     — correctly — resolves §Ghost and exits 0. The old lane printed that as two reds, sending a
#     reader to debug a subject that is sound.
#   * drop privilege and the write into knowledge/shared fails instead, so the asset never exists and
#     the corpus row becomes an ordinary MISSING asset — a different subject path wearing this
#     lane's name, with "NOT scored STALE" and "exit 3" both going green on it for the wrong reason.
# The subject is fine: in a tree an unprivileged uid owns, it prints
# `⚠️  UNREADABLE … this is an instrument error, NOT a stale probe`, scores it unresolvable-asset
# (stale=0) and exits 3. So when the premise does not hold, say UNMEASURED — not a pass, and not a
# verdict about probe_scope_check.sh. Same class as test_fh_detach_lanes.sh M5d (2026-11-02); this is
# the second site of `chmod 000` as a precondition, so do not reintroduce it as a bare assumption.
LOCK="$FH/knowledge/shared/.psc_lane_locked.$$.md"
# the 2>/dev/null must wrap the GROUP: a failed redirection is reported by the shell, not by printf
{ printf '## Ghost\n' > "$LOCK"; } 2>/dev/null
chmod 000 "$LOCK" 2>/dev/null
_why=""
if [ ! -e "$LOCK" ]; then
  _why="the fixture asset could not be created under knowledge/shared (uid $(id -u) cannot write there)"
elif [ -r "$LOCK" ] && head -c 1 "$LOCK" >/dev/null 2>&1; then
  _why="the fixture asset is still readable after chmod 000 — uid $(id -u) is not bound by it"
fi
if [ -n "$_why" ]; then
  unmeasured "unreadable-asset lanes (3) did not run — $_why. Nothing is claimed about the subject, and this is NOT a pass"
else
  { cat "$TMP/clean.md"; printf '| `X-LOCK-01` | t | e | .psc_lane_locked.%s.md §Ghost | mandatory-pass |\n' "$$"; } > "$TMP/lock.md"
  out="$(bash "$SUBJ" --fixture-corpus "$TMP/lock.md" 2>&1)"; rc=$?
  printf '%s' "$out" | grep -q 'UNREADABLE'; chk "unreadable asset reports UNREADABLE, not STALE" $?
  printf '%s' "$out" | grep -q '❌ STALE'; [ $? -ne 0 ]; chk "unreadable asset is NOT scored STALE" $?
  [ "$rc" -eq 3 ]; chk "unreadable asset still fails the gate (exit 3, fail-closed)" $?
fi
chmod 644 "$LOCK" 2>/dev/null; rm -f "$LOCK" 2>/dev/null

# ── L5 — a genuinely stale scope must still be caught. Without it, "call everything an instrument
# error" would pass L4.
{ cat "$TMP/clean.md"; printf '| `X-STALE-01` | t | e | CLAUDE.md §No Such Section Anywhere | mandatory-pass |\n'; } > "$TMP/stale.md"
out="$(bash "$SUBJ" --fixture-corpus "$TMP/stale.md" 2>&1)"; rc=$?
printf '%s' "$out" | grep -q '❌ STALE'; chk "a real stale scope is still reported STALE" $?
[ "$rc" -eq 3 ]; chk "a real stale scope still fails the gate" $?

echo "── lanes: $pass passed · $fail failed · $unmeas unmeasured ──"
[ "$fail" -eq 0 ] || exit 1
if [ "$unmeas" -ne 0 ]; then
  # line-head `INCOMPLETE  <subject>:` is this repo's aggregate vocabulary for "ran, measured
  # nothing, not a pass" (test_fh_detach_lanes.sh, test_mutation_probe_lanes.sh). A non-pass written
  # only in a local decoration is a non-pass the next round's log diff cannot count.
  echo "INCOMPLETE  probe_scope: $unmeas lane group(s) could not build their premise on this machine — 통과 아님"
  exit 1
fi
exit 0

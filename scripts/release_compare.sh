#!/usr/bin/env bash
# release_compare.sh — the published bundle vs the previous stable one. Advisory, run AFTER the tag push.
#
# Design: tracks/_meta/release_compare_design_2026-11-24.md (local). Models: google/elephant-goldfish-model #558 · #560.
# A release can pass every offline check and still load or review worse than the one before. The comparison runs
# the exact bytes users receive, for the target and the previous stable version, on the same cases, same day.
#
# 🟥 THIS FILE IS STAGE 1 ONLY: the artifact fingerprint. For each of the two versions:
#      1. `npm view` → dist.integrity · dist.tarball · gitHead
#      2. download the tarball; its sha512 must equal dist.integrity
#      3. gitHead must equal the local tag v<version>'s commit
#    Anything that does not hold → ARTIFACT-UNVERIFIED (with the reason), and that version would not be run.
#    Stages 2–4 (unpack, machine-axis cases, LLM cases under a sealed prereg) are NOT BUILT; the report says so.
#    A VERIFIED line says «these are the published bytes of that tag», never «the release is as good as the last».
# 🟥 Never a gate: it runs after publish, nothing waits on its exit code, and it never touches publish.yml.
# Named, not checked: the Sigstore attestation bundle (dist.attestations) is not parsed — gitHead is the
#   commit npm recorded at publish; the attestation is a stronger proof of the same thing.
# Named: the marketplace path is not covered. Measured 2026-11-25: a marketplace install takes the default
#   branch tip at update time (installed record commit was after the v3.48.0 tag, not the tag), so there is no
#   «previous stable bundle» on that path to compare.
#
# Usage: release_compare.sh <target-version> [--previous <version>] [--out <dir>]
#   run from a checkout that has the tags (git fetch --tags). Package: $RC_PACKAGE (default @chrono-meta/fh-gate).
#   --previous absent → the highest published version below the target.
# Exit: 0 both VERIFIED · 1 at least one ARTIFACT-UNVERIFIED · 2 could not measure (npm unreachable, bad argument)
set -uo pipefail   # codex R1: a failing openssl/base64 must not hide behind tr
PKG="${RC_PACKAGE:-@chrono-meta/fh-gate}"
TARGET="${1:-}"; shift 2>/dev/null || true
PREV=""; OUTD=""
while [ $# -gt 0 ]; do
  case "$1" in
    --previous|--out)
      [ $# -ge 2 ] || { echo "release-compare: $1 needs a value" >&2; exit 2; }
      [ "$1" = --previous ] && PREV="$2" || OUTD="$2"; shift 2 ;;
    *) echo "release-compare: unknown argument «$1»" >&2; exit 2 ;;
  esac
done
# whole-string match (no embedded newline), no leading zeros (codex R1)
semver() { [[ "$1" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; }
vlt() { python3 -c 'import sys;a,b=(tuple(map(int,x.split("."))) for x in sys.argv[1:3]);sys.exit(0 if a<b else 1)' "$1" "$2"; }
semver "$TARGET" || { echo "release-compare: target «${TARGET}» is not X.Y.Z" >&2; exit 2; }
[ -z "$PREV" ] || semver "$PREV" || { echo "release-compare: --previous «${PREV}» is not X.Y.Z" >&2; exit 2; }
OUTD="${OUTD:-$(mktemp -d "${TMPDIR:-/tmp}/release_compare.XXXXXX")}" || exit 2
mkdir -p "$OUTD" || exit 2
REPORT="$OUTD/release_compare_$TARGET.md"
# codex R1: a reused --out must not keep an earlier run's VERIFIED — this run's report says UNMEASURED until it finishes
printf '# release_compare — %s %s: UNMEASURED (this run did not finish; nothing below is verified)\n' "$PKG" "$TARGET" > "$REPORT" || exit 2

# npm's own status, not tr's. rc 3 = the registry answered «no such version» (E404) — an artifact failure, not an
# unreachable registry (codex R1); any other failure is rc 1 → UNMEASURED.
nv() { local o e; e=$(mktemp) || return 1
  if o=$(npm view "$PKG@$1" "$2" 2>"$e"); then rm -f "$e"; printf '%s' "$o" | tr -d '"[:space:]'; return 0; fi
  if grep -q 'E404' "$e"; then rm -f "$e"; return 3; fi
  rm -f "$e"; return 1; }
if [ -z "$PREV" ]; then
  vers=$(npm view "$PKG" versions --json 2>/dev/null) || { echo "release-compare: npm view versions failed — UNMEASURED" >&2; exit 2; }
  PREV=$(printf '%s' "$vers" | python3 -c '
import json,sys
t=tuple(map(int,sys.argv[1].split(".")))
vs=[v for v in json.load(sys.stdin) if all(p.isdigit() for p in v.split(".")) and len(v.split("."))==3]
below=sorted((tuple(map(int,v.split("."))) for v in vs if tuple(map(int,v.split(".")))<t))
print(".".join(map(str,below[-1])) if below else "")' "$TARGET") || { echo "release-compare: version list unreadable — UNMEASURED" >&2; exit 2; }
  [ -n "$PREV" ] || { echo "release-compare: no published version below $TARGET" >&2; exit 2; }
  PREV_WHY="highest published below $TARGET"
else PREV_WHY="given"; fi
vlt "$PREV" "$TARGET" || { echo "release-compare: previous $PREV is not below target $TARGET — nothing to compare against" >&2; exit 2; }   # codex R1

verdict() { # $1 version → prints «STATE reason», exit 2 if npm could not answer
  local v="$1" integ url head tag got f
  integ=$(nv "$v" dist.integrity); r=$?
  [ "$r" -eq 0 ] && { url=$(nv "$v" dist.tarball); r=$?; }
  [ "$r" -eq 0 ] && { head=$(nv "$v" gitHead); r=$?; }
  [ "$r" -eq 3 ] && { echo "ARTIFACT-UNVERIFIED $v is not published on the registry (E404)"; return 0; }
  [ "$r" -eq 0 ] || return 2
  [ -n "$integ" ] && [ -n "$url" ] || { echo "ARTIFACT-UNVERIFIED registry gave no integrity or tarball"; return 0; }
  f="$OUTD/$(printf '%s' "$PKG" | tr '/@' '__')-$v.tgz"
  curl -fsSL -o "$f" "$url" 2>/dev/null && [ -s "$f" ] || { echo "ARTIFACT-UNVERIFIED download failed — nothing to fingerprint"; return 0; }
  got="sha512-$(openssl dgst -sha512 -binary "$f" | base64 | tr -d '\n')" || { echo "ARTIFACT-UNVERIFIED hash tool failed"; return 0; }
  [[ "$got" =~ ^sha512-[A-Za-z0-9+/]{86}==$ ]] || { echo "ARTIFACT-UNVERIFIED hash tool gave no sha512 digest"; return 0; }   # codex R1
  [ "$got" = "$integ" ] || { echo "ARTIFACT-UNVERIFIED integrity: downloaded ${got:0:20}… ≠ registry ${integ:0:20}…"; return 0; }
  tag=$(git rev-parse -q --verify "refs/tags/v$v^{commit}" 2>/dev/null) || { echo "ARTIFACT-UNVERIFIED no tag v$v in this checkout — the bundle cannot be paired with a commit"; return 0; }
  [ -n "$head" ] || { echo "ARTIFACT-UNVERIFIED registry gave no gitHead"; return 0; }
  [ "$head" = "$tag" ] || { echo "ARTIFACT-UNVERIFIED gitHead ${head:0:12} ≠ tag v$v ${tag:0:12}"; return 0; }
  echo "VERIFIED integrity ${integ:0:20}… · gitHead = tag v$v ${tag:0:12}"
}

rows=""; any_bad=0
for v in "$TARGET" "$PREV"; do
  r=$(verdict "$v"); vrc=$?
  [ "$vrc" -eq 2 ] && { echo "release-compare: npm view failed for $v — UNMEASURED, nothing verified" >&2; exit 2; }
  st="${r%% *}"; why="${r#* }"
  [ "$st" = VERIFIED ] || any_bad=1
  rows="$rows| $v | $st | $why |"$'\n'
done
{
  echo "# release_compare — $PKG $TARGET vs $PREV ($(date -u +%Y-%m-%dT%H:%MZ))"
  echo
  echo "target: $TARGET · previous: $PREV ($PREV_WHY)"
  echo
  echo "## Stage 1 — artifact fingerprint"
  echo "| version | state | detail |"
  echo "|---|---|---|"
  printf '%s' "$rows"
  echo
  echo "## Stages 2–4 — NOT BUILT"
  echo "Unpacking, machine-axis cases (exit codes, shipped lanes) and LLM cases on known pairs are not built yet."
  echo "So this report says which bytes were published, not whether $TARGET behaves better or worse than $PREV."
  echo "Not covered: the marketplace path (installs take the default-branch tip, not a tag) and the Sigstore attestation."
} > "$REPORT" || exit 2
cat "$REPORT"
exit "$any_bad"

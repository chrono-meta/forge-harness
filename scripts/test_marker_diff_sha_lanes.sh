#!/usr/bin/env bash
# test_marker_diff_sha_lanes.sh — regression fixtures for pre-commit's validate_diff_sha_leg
# (2026-10-03, fh_signal_2026-10-03_marker-branch-date-key).
#
# WHY: the 4-axis marker is addressed by «branch + date» only, so a diff that changed AFTER the axes
# ran (same branch, same day) commits through the old marker. `diff-sha:` records which staged bytes
# the axes ran against; the hook recomputes and compares. Optional while DIFF_SHA_REQUIRED_DATE is
# empty (operator decision).
#
# Lanes run in a throwaway git repo so the staged diff is real. Both directions (known-pair):
# match passes · mismatch blocks · absent passes (grace) · absent blocks once the date constant is set ·
# malformed/near-miss keys block · a chain with one matching value passes · helper-script output equals
# the hook function · revert probe: neuter the comparison and the mismatch lane must turn red.
#
# Usage: bash scripts/test_marker_diff_sha_lanes.sh   Exit: 0 = all behave; 1 = regression.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$REPO_ROOT/templates/.git-hooks/pre-commit"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

{ grep -E '^DIFF_SHA_REQUIRED_DATE=' "$HOOK"
  sed -n '/^_staged_diff_sha()/,/^}/p' "$HOOK"
  sed -n '/^validate_diff_sha_leg()/,/^}/p' "$HOOK"; } > "$T/fn.sh"
if ! grep -q '^validate_diff_sha_leg()' "$T/fn.sh" || ! grep -q '^_staged_diff_sha()' "$T/fn.sh"; then
  echo "❌ HARNESS-ERROR — validate_diff_sha_leg/_staged_diff_sha did not extract from $HOOK."
  exit 1
fi

R="$T/repo"; mkdir -p "$R"
( cd "$R" && git init -q && git config user.email t@t && git config user.name t \
  && printf 'a\n' > f.txt && git add f.txt && git commit -qm init \
  && printf 'a\nb\n' > f.txt && git add f.txt ) || { echo "❌ HARNESS-ERROR — fixture repo"; exit 1; }
SHA_B=$(cd "$R" && bash -c '. "$1"; _staged_diff_sha' _ "$T/fn.sh")
[ ${#SHA_B} -eq 64 ] || { echo "❌ HARNESS-ERROR — fixture sha not computed ('$SHA_B')"; exit 1; }
OTHER=$(printf '%064d' 0)

FAIL=0
lane() { # $1 id  $2 expect  $3 marker body  [$4 needle]  [$5 fn file]
  local id="$1" expect="$2" body="$3" needle="${4:-}" fn="${5:-$T/fn.sh}" rc out got=PASS
  printf '%s\n' "$body" > "$T/m.marker"
  out=$( cd "$R" && bash -c 'set -uo pipefail; . "$1"; validate_diff_sha_leg "$2"' _ "$fn" "$T/m.marker" 2>&1 ); rc=$?
  [ $rc -ne 0 ] && got=BLOCK
  if [ "$got" != "$expect" ]; then
    printf '  ❌ %-36s expected %s, got %s\n     %s\n' "$id" "$expect" "$got" "$(printf '%s' "$out" | head -3)"; FAIL=1; return
  fi
  if [ -n "$needle" ] && ! printf '%s' "$out" | grep -qF -- "$needle"; then
    printf '  ❌ %-36s %s but diagnostic «%s» missing\n' "$id" "$got" "$needle"; FAIL=1; return
  fi
  printf '  ✅ %-36s %s\n' "$id" "$got"
}

echo "== diff-sha: lanes =="
# d0 — absent marker file must fail-closed as HARNESS-ERROR (found by codex wave 2).
out=$( cd "$R" && bash -c 'set -uo pipefail; . "$1"; validate_diff_sha_leg "$2"' _ "$T/fn.sh" "$T/nonexistent.marker" 2>&1 ); rc=$?
if [ $rc -ne 0 ] && printf '%s' "$out" | grep -qF "존재하지 않는다"; then
  printf '  ✅ %-36s %s\n' d0-missing-marker-blocks BLOCK
else
  printf '  ❌ %-36s expected BLOCK on missing marker file\n     %s\n' d0-missing-marker-blocks "$out"; FAIL=1
fi
lane d1-match-passes          PASS  "axes-run: ⓐ=codex
diff-sha: $SHA_B"
lane d2-mismatch-blocks       BLOCK "diff-sha: $OTHER" "staged diff 와 다르다"
lane d3-absent-grace-passes   PASS  "axes-run: ⓐ=codex"
lane d4-chain-one-match       PASS  "diff-sha: $OTHER
diff-sha: $SHA_B"
lane d5-malformed-value       BLOCK "diff-sha: abc123" "64자리"
lane d6-empty-value           BLOCK "diff-sha:" "64자리"
lane d7-nearmiss-underscore   BLOCK "diff_sha: $SHA_B
diff-sha: $SHA_B" "정확히 'diff-sha:'"
lane d7b-nearmiss-diff-fp     BLOCK "diff-fp: $SHA_B" "정확히 'diff-sha:'"
lane d7c-nearmiss-capital     BLOCK "Diff-sha: $SHA_B" "정확히 'diff-sha:'"
lane d8-indented-match        PASS  "   diff-sha: $SHA_B"

# d10 — once the operator sets the date constant, absence blocks.
sed 's/^DIFF_SHA_REQUIRED_DATE=.*/DIFF_SHA_REQUIRED_DATE="2000-01-01"/' "$T/fn.sh" > "$T/fn_req.sh"
lane d10-absent-after-date    BLOCK "axes-run: ⓐ=codex" "필수" "$T/fn_req.sh"

# d11 — the diff changes after the marker was written: same marker must now block.
( cd "$R" && printf 'a\nb\nc\n' > f.txt && git add f.txt )
lane d11-diff-changed-blocks  BLOCK "diff-sha: $SHA_B" "staged diff 와 다르다"
( cd "$R" && printf 'a\nb\n' > f.txt && git add f.txt )

# d9 — helper script and hook function must agree (two hand-copies would drift silently).
H=$( cd "$R" && HOOK_OVERRIDE= bash -c 'eval "$(sed -n "/^_staged_diff_sha()/,/^}/p" "$1")"; _staged_diff_sha' _ "$HOOK" )
S=$( cd "$R" && bash "$REPO_ROOT/scripts/marker_diff_sha.sh" 2>&1 )
if [ "$S" = "$SHA_B" ] && [ "$H" = "$SHA_B" ]; then printf '  ✅ %-36s %s\n' d9-helper-equals-hook PASS
else printf '  ❌ %-36s helper=%s hook=%s fixture=%s\n' d9-helper-equals-hook "$S" "$H" "$SHA_B"; FAIL=1; fi

# d12 — diff config of the user must not change the fingerprint.
( cd "$R" && git config diff.noprefix true && git config diff.mnemonicprefix true )
lane d12-user-diff-config     PASS  "diff-sha: $SHA_B"
( cd "$R" && git config --unset diff.noprefix; git config --unset diff.mnemonicprefix )

# d13 — codex R1(2026-10-04): diff rendering knobs (context · algorithm · ignoreSubmodules) must not move the
# fingerprint either — the fingerprint is tree identity, not rendered diff text.
( cd "$R" && git config diff.context 0 && git config diff.algorithm patience && git config diff.ignoreSubmodules all )
lane d13-diff-render-config   PASS  "diff-sha: $SHA_B"
( cd "$R" && git config --unset diff.context; git config --unset diff.algorithm; git config --unset diff.ignoreSubmodules )

# d14 — a staged gitlink (submodule commit) change must move the fingerprint even under ignoreSubmodules=all.
( cd "$R" && git config diff.ignoreSubmodules all \
    && git update-index --add --cacheinfo 160000,1111111111111111111111111111111111111111,vendor/sub )
lane d14-gitlink-change-moves  BLOCK "diff-sha: $SHA_B" "staged diff 와 다르다"
( cd "$R" && git update-index --force-remove vendor/sub; git config --unset diff.ignoreSubmodules )
lane d14b-gitlink-removed-back PASS  "diff-sha: $SHA_B"

echo "== revert probe (apply-check → run → expect red) =="
# Neuter the comparison: every value counts as a match. The mismatch lane MUST go red.
sed 's/\[ "\$v" = "\$cur" \] && ok=1/ok=1/' "$T/fn.sh" > "$T/fn_mut.sh"
if cmp -s "$T/fn.sh" "$T/fn_mut.sh"; then
  echo "  ❌ HARNESS-ERROR — mutant identical to original (sed did not apply). Revert probe is void."; FAIL=1
else
  printf 'diff-sha: %s\n' "$OTHER" > "$T/m_mismatch.marker"
  out=$( cd "$R" && bash -c '. "$1"; validate_diff_sha_leg "$2"' _ "$T/fn_mut.sh" "$T/m_mismatch.marker" 2>&1 ); rc=$?
  if [ $rc -eq 0 ]; then printf '  ✅ %-36s mutant passes mismatch (lane d2 would turn red)\n' r1-revert-comparison
  else printf '  ❌ %-36s mutant still blocks — d2 is not anchored on the comparison\n' r1-revert-comparison; FAIL=1; fi
fi
# Neuter the grace-date check: d10 must go red.
sed 's/\[ -n "\$DIFF_SHA_REQUIRED_DATE" \] \&\&/false \&\&/' "$T/fn_req.sh" > "$T/fn_mut2.sh"
if cmp -s "$T/fn_req.sh" "$T/fn_mut2.sh"; then
  echo "  ❌ HARNESS-ERROR — date mutant identical (sed did not apply)."; FAIL=1
else
  printf 'axes-run: x\n' > "$T/m_date.marker"
  out=$( cd "$R" && bash -c '. "$1"; validate_diff_sha_leg "$2"' _ "$T/fn_mut2.sh" "$T/m_date.marker" 2>&1 ); rc=$?
  if [ $rc -eq 0 ]; then printf '  ✅ %-36s mutant passes absence (lane d10 would turn red)\n' r2-revert-date
  else printf '  ❌ %-36s mutant still blocks\n' r2-revert-date; FAIL=1; fi
fi

if [ "$FAIL" -eq 0 ]; then echo "ALL diff-sha lanes behave."; exit 0; else echo "REGRESSION in diff-sha lanes."; exit 1; fi

#!/usr/bin/env bash
# test_regression_guard_sibling_lanes.sh — Axis 1's «moved is not lost» sibling lookup.
#
# WHY (2026-10-16): CLAUDE.md became a ~95-line resident core and the full ruleset moved to
# knowledge/shared/harness-core/claude_md_full_reference.md. The guard's sibling lookup only knew
# SKILL.md <-> SKILL_detail.md, so the move read as 100% token loss and hard-blocked the commit.
# The pair was added to the same symmetric lookup. No lane covered the lookup before — not even the
# SKILL pair — so these lanes cover both pairs and both directions:
#   moved into the sibling  -> no M-tier (exit != 2)
#   dropped from both       -> M-tier block (exit 2)   <- the lookup must not become a free pass
# plus a REVERT PROBE: the CLAUDE.md case is deleted from a copy of the guard and lane S1 must turn red.
#
# Usage: bash scripts/test_regression_guard_sibling_lanes.sh   Exit: 0 = all behave; 1 = regression.

set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/fixture_guard_lib.sh"   # fixtures never write the real repo
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GUARD="$REPO_ROOT/templates/regression_guard.sh"
T="$(fh_fixture_root "$(mktemp -d)")"
: "${T:?fixture root unset — refusing to run git in cwd}"
trap 'rm -rf "$T"' EXIT
FAIL=0
REF=knowledge/shared/harness-core/claude_md_full_reference.md

BODY='## Execution Steps
Step 0 read. Step 1 scan. Step 2 propose. Step 3 run.
```bash
bash scripts/x.sh
```
```bash
bash scripts/y.sh
```
```bash
bash scripts/z.sh
```
## Done When
the gate says PASS or BLOCK.
M-tier and S-tier are defined in the guard.
'

# $1=dir  — base commit: CLAUDE.md and a skill both carry the tokens, no siblings yet
mkrepo() {
  local d=$1
  mkdir -p "$d/plugins/p/skills/s" "$d/knowledge/shared/harness-core"
  git -C "$d" init -q && git -C "$d" config user.email t@t && git -C "$d" config user.name t
  printf '# hub\n%s' "$BODY" > "$d/CLAUDE.md"
  printf -- '---\nname: s\ndescription: d\n---\n# s\n%s' "$BODY" > "$d/plugins/p/skills/s/SKILL.md"
  git -C "$d" add -A && git -C "$d" commit -q -m base
}

# $1=id $2=dir $3=guard $4=expect(block|pass)
run_lane() {
  local id=$1 d=$2 g=$3 want=$4 rc out
  out=$(cd "$d" && bash "$g" --staged 2>&1); rc=$?
  if [ -z "$out" ]; then echo "  ❌ $id — guard printed nothing (instrument silence, not a pass)"; FAIL=1; return; fi
  if [ "$rc" -ne 0 ] && [ "$rc" -ne 1 ] && [ "$rc" -ne 2 ]; then
    echo "  ❌ $id — guard rc=$rc (could not run)"; printf '%s\n' "$out" | tail -3 | sed 's/^/       /'; FAIL=1; return
  fi
  if [ "$want" = block ] && [ "$rc" -eq 2 ]; then echo "  ✅ $id — M-tier block (rc=2)"
  elif [ "$want" = pass ] && [ "$rc" -ne 2 ] && grep -q "moved to" <<<"$out"; then echo "  ✅ $id — no M-tier, move recognised (rc=$rc)"
  elif [ "$want" = pass ] && [ "$rc" -ne 2 ]; then echo "  ❌ $id — rc=$rc but no «moved to» line: the pair was never examined (a SKIP is not a pass)"; FAIL=1
  else echo "  ❌ $id — expected $want, got rc=$rc"; printf '%s\n' "$out" | grep -E 'M-TIER|moved' | head -4 | sed 's/^/       /'; FAIL=1; fi
}

echo "── regression_guard sibling lanes ──"

# S1: CLAUDE.md slimmed, content moved to the reference file -> move, not loss
d=$T/s1; mkrepo "$d"
printf '# hub\nresident core only.\n' > "$d/CLAUDE.md"
printf '# full reference\n%s' "$BODY" > "$d/$REF"
git -C "$d" add -A
run_lane "S1 CLAUDE.md -> reference move" "$d" "$GUARD" pass

# S2: CLAUDE.md slimmed, reference file lacks the content -> real loss still blocks
d=$T/s2; mkrepo "$d"
printf '# hub\nresident core only.\n' > "$d/CLAUDE.md"
printf '# full reference\nunrelated.\n' > "$d/$REF"
git -C "$d" add -A
run_lane "S2 CLAUDE.md loss with empty reference" "$d" "$GUARD" block

# S3: CLAUDE.md slimmed, no reference file at all -> blocks
d=$T/s3; mkrepo "$d"
printf '# hub\nresident core only.\n' > "$d/CLAUDE.md"
git -C "$d" add -A
run_lane "S3 CLAUDE.md loss, reference absent" "$d" "$GUARD" block

# S4: the older pair still works — SKILL.md content moved to SKILL_detail.md
d=$T/s4; mkrepo "$d"
printf -- '---\nname: s\ndescription: d\n---\n# s\nsee detail.\n' > "$d/plugins/p/skills/s/SKILL.md"
printf '# detail\n%s' "$BODY" > "$d/plugins/p/skills/s/SKILL_detail.md"
git -C "$d" add -A
run_lane "S4 SKILL.md -> SKILL_detail.md move" "$d" "$GUARD" pass

# S5: a file that is NOT a pair member does not borrow the reference's content
d=$T/s5; mkrepo "$d"
printf '# agents\n%s' "$BODY" > "$d/AGENTS.md"; git -C "$d" add AGENTS.md; git -C "$d" commit -q -m agents
printf '# agents\nshort.\n' > "$d/AGENTS.md"
printf '# full reference\n%s' "$BODY" > "$d/$REF"
git -C "$d" add -A
out=$(cd "$d" && bash "$GUARD" --staged 2>&1)
if grep -q "AGENTS.md" <<<"$out" && ! grep -qE "moved to SKILL_detail.md.*" <<<"$out"; then
  sec=$(grep -A30 "AGENTS.md" <<<"$out"); if [[ "$sec" == *"M-TIER"* ]]; then echo "  ✅ S5 AGENTS.md loss is not excused by the reference file"
  else echo "  ❌ S5 AGENTS.md token loss produced no M-TIER line"; FAIL=1; fi
else echo "  ❌ S5 AGENTS.md was not examined, or was treated as a move"; FAIL=1; fi

# S6: the sibling ALREADY held the content (unchanged this commit) -> deleting from CLAUDE.md still blocks
d=$T/s6; mkrepo "$d"
printf '# full reference\n%s' "$BODY" > "$d/$REF"; git -C "$d" add -A; git -C "$d" commit -q -m ref
printf '# hub\nresident core only.\n' > "$d/CLAUDE.md"
git -C "$d" add -A
run_lane "S6 unchanged sibling does not mask a CLAUDE.md loss" "$d" "$GUARD" block

# S7: both files lose the content in the same commit -> blocks
d=$T/s7; mkrepo "$d"
printf '# hub\n%s%s' "$BODY" "$BODY" > "$d/CLAUDE.md"; printf '# full reference\n%s%s' "$BODY" "$BODY" > "$d/$REF"; git -C "$d" add -A; git -C "$d" commit -q -m two
printf '# hub\n%s' "$BODY" > "$d/CLAUDE.md"; printf '# full reference\n%s' "$BODY" > "$d/$REF"
git -C "$d" add -A
run_lane "S7 simultaneous loss in both files" "$d" "$GUARD" block

# S8: reverse direction — reference content moved back into CLAUDE.md -> move (reference side examined)
d=$T/s8; mkrepo "$d"
printf '# hub\nresident core only.\n' > "$d/CLAUDE.md"; printf '# full reference\n%s' "$BODY" > "$d/$REF"
git -C "$d" add -A; git -C "$d" commit -q -m split
printf '# hub\n%s' "$BODY" > "$d/CLAUDE.md"; printf '# full reference\nmoved back.\n' > "$d/$REF"
git -C "$d" add -A
out=$(cd "$d" && bash "$GUARD" --staged 2>&1)
sec=$(grep -A60 "claude_md_full_reference.md" <<<"$out"); if [[ "$sec" == *"moved to"* ]] && [[ "$sec" != *"M-TIER"* ]]; then
  echo "  ✅ S8 reference -> CLAUDE.md reverse move recognised"
else echo "  ❌ S8 reverse move not recognised on the reference side"; FAIL=1; fi

# S9 (F2 isolated): the sibling already holds a «## Trigger Phrases» heading, unchanged; CLAUDE.md drops
# its own. No F4 token is involved, so only the section check can catch it.
d=$T/s9; mkrepo "$d"
printf '# hub\n## Trigger Phrases\n- say hi\n' > "$d/CLAUDE.md"; printf '# full reference\n## Trigger Phrases\n- say hi\n' > "$d/$REF"
git -C "$d" add -A; git -C "$d" commit -q -m trig
printf '# hub\nno triggers.\n- say hi\n' > "$d/CLAUDE.md"; git -C "$d" add -A
out=$(cd "$d" && bash "$GUARD" --staged 2>&1)
if grep -q "'Triggers' section group dropped" <<<"$out"; then echo "  ✅ S9 F2: unchanged sibling heading does not excuse a dropped section"
else echo "  ❌ S9 F2: dropped section was excused (no «section group dropped» line)"; FAIL=1; fi

# S10 (F3 isolated): sibling already holds fences, unchanged; CLAUDE.md loses all of its fences
d=$T/s10; mkrepo "$d"
F6=$(printf '```bash\nx\n```\n```bash\ny\n```\n```bash\nz\n```\n')
printf '# hub\n%s\n' "$F6" > "$d/CLAUDE.md"; printf '# full reference\n%s\n' "$F6" > "$d/$REF"
git -C "$d" add -A; git -C "$d" commit -q -m fences
printf '# hub\nno code.\n' > "$d/CLAUDE.md"; git -C "$d" add -A
out=$(cd "$d" && bash "$GUARD" --staged 2>&1)
if grep -q "code blocks reduced" <<<"$out"; then echo "  ✅ S10 F3: unchanged sibling fences do not excuse lost code blocks"
else echo "  ❌ S10 F3: lost code blocks were excused"; FAIL=1; fi

# R1: revert probe — delete the CLAUDE.md case from a copy of the guard; S1 must now block
G2=$T/guard_reverted.sh
grep -v '^    CLAUDE.md) ' "$GUARD" > "$G2"
if cmp -s "$GUARD" "$G2"; then echo "  ❌ R1 revert probe: the mutation did not apply (pattern drift) — HARNESS-ERROR"; FAIL=1
else
  d=$T/r1; mkrepo "$d"
  printf '# hub\nresident core only.\n' > "$d/CLAUDE.md"
  printf '# full reference\n%s' "$BODY" > "$d/$REF"
  git -C "$d" add -A
  run_lane "R1 revert probe: without the pair, S1 blocks" "$d" "$G2" block
fi

# R2: revert probe — credit the sibling's whole total again (the old behaviour); S6 must turn green-wrong
G3=$T/guard_total.sh
sed 's/a=\${a:-0}; b=\${b:-0}; \[ "\$a" -gt "\$b" \] \&\& echo \$((a - b)) || echo 0/a=${a:-0}; echo "$a"/' "$GUARD" > "$G3"
if cmp -s "$GUARD" "$G3"; then echo "  ❌ R2 revert probe: the mutation did not apply (pattern drift) — HARNESS-ERROR"; FAIL=1
else
  d=$T/r2; mkrepo "$d"
  printf '# full reference\n%s' "$BODY" > "$d/$REF"; git -C "$d" add -A; git -C "$d" commit -q -m ref
  printf '# hub\nresident core only.\n' > "$d/CLAUDE.md"; git -C "$d" add -A
  rc=0; out=$(cd "$d" && bash "$G3" --staged 2>&1) || rc=$?
  if { [ "$rc" -eq 0 ] || [ "$rc" -eq 1 ]; } && grep -q "moved to" <<<"$out"; then echo "  ✅ R2 revert probe: whole-total credit lets S6 through as a «move» (rc=$rc) — S6 is what catches it"
  else echo "  ❌ R2 revert probe: S6 still blocked with whole-total credit — S6 is not anchoring the gain rule"; FAIL=1; fi
fi

# R3: revert probe — drop the reverse arm; S8 must fail
G4=$T/guard_noreverse.sh
grep -v 'claude_md_full_reference.md) sib="CLAUDE.md"' "$GUARD" > "$G4"
if cmp -s "$GUARD" "$G4"; then echo "  ❌ R3 revert probe: the mutation did not apply (pattern drift) — HARNESS-ERROR"; FAIL=1
else
  d=$T/r3; mkrepo "$d"
  printf '# hub\nresident core only.\n' > "$d/CLAUDE.md"; printf '# full reference\n%s' "$BODY" > "$d/$REF"
  git -C "$d" add -A; git -C "$d" commit -q -m split
  printf '# hub\n%s' "$BODY" > "$d/CLAUDE.md"; printf '# full reference\nmoved back.\n' > "$d/$REF"; git -C "$d" add -A
  rc=0; out=$(cd "$d" && bash "$G4" --staged 2>&1) || rc=$?
  if [ "$rc" -gt 2 ] || ! grep -q "claude_md_full_reference.md" <<<"$out"; then echo "  ❌ R3 revert probe: mutated guard did not run or never examined the reference (rc=$rc) — HARNESS-ERROR"; FAIL=1
  elif sec=$(grep -A60 "claude_md_full_reference.md" <<<"$out"); [[ "$sec" == *"moved to"* ]]; then echo "  ❌ R3 revert probe: reverse move still recognised without the reverse arm"; FAIL=1
  else echo "  ✅ R3 revert probe: without the reverse arm the reference side no longer sees a move"; fi
fi

echo
if [ "$FAIL" -eq 0 ]; then echo "ALL regression_guard sibling lanes behave."; exit 0; fi
echo "regression_guard sibling lanes: FAIL"; exit 1

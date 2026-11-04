#!/usr/bin/env bash
# test_selfdev_merge_tier_lanes.sh — known-pair lanes for scripts/selfdev_merge_tier.sh.
# Each lane writes a changed-file list and asserts the TIER line AND the rc (the two must agree).
# T1/T2 are the pair the classifier exists for: an allowed doc → AUTO, a hook → HOLD.
# 🟥 Rows are fed with < <(...), never `printf | lane`: a pipe runs lane() in a subshell and the
# pass/fail counters vanish — measured on the first run: 13 ✅ printed, «1 passed» counted, so a
# failing lane would have exited 0. The total check at the end re-checks the counter itself.
# T3 is the empty-set trap (all() over nothing is true) — it must be HARNESS-ERROR, never AUTO.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIER="$HERE/selfdev_merge_tier.sh"
[ -f "$TIER" ] || { echo "HARNESS-ERROR: $TIER missing"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
pass=0; fail=0
lane() { # id expected_tier expected_rc  (rows on stdin, «st<TAB>path<TAB>add<TAB>del»)
  local id="$1" want="$2" wrc="$3" f="$W/$1.tsv" out rc got
  cat > "$f"
  out="$(SELFDEV_MAX_LINES="${MAXL:-300}" bash "$TIER" --files "$f" 2>&1)"; rc=$?
  got="$(printf '%s\n' "$out" | tail -1)"
  if [ "$got" = "TIER=$want" ] && [ "$rc" -eq "$wrc" ]; then pass=$((pass+1)); echo "  ✅ $id $got rc=$rc"
  else fail=$((fail+1)); echo "  ❌ $id want TIER=$want rc=$wrc · got «$got» rc=$rc"; printf '%s\n' "$out" | sed 's/^/       /'; fi
}
T=$'\t'
lane T1-doc AUTO 0 < <(printf 'M%sdocs/USER_GUIDE.md%s4%s1\n' "$T" "$T" "$T")
lane T2-hook HOLD 3 < <(printf 'M%stemplates/.git-hooks/pre-commit%s2%s0\n' "$T" "$T" "$T")
lane T3-empty HARNESS-ERROR 2 < <(printf '')
lane T4-added-lane AUTO 0 < <(printf 'A%sscripts/test_new_lanes.sh%s40%s0\n' "$T" "$T" "$T")
lane T5-edited-lane HOLD 3 < <(printf 'M%sscripts/test_existing_lanes.sh%s3%s9\n' "$T" "$T" "$T")
lane T6-rules HOLD 3 < <(printf 'M%sknowledge/shared/rules/sync_push_protocols.md%s1%s1\n' "$T" "$T" "$T")
lane T7-gate-doc HOLD 3 < <(printf 'M%sknowledge/shared/harness-core/field_verdict_crossfamily_gate.md%s1%s0\n' "$T" "$T" "$T")
lane T8-knowledge AUTO 0 < <(printf 'M%sknowledge/shared/harness-core/builtin_capability_map.md%s2%s0\n' "$T" "$T" "$T")
lane T9-mixed HOLD 3 < <(printf 'M%sdocs/USER_GUIDE.md%s1%s0\nM%sCLAUDE.md%s1%s0\n' "$T" "$T" "$T" "$T" "$T" "$T")
MAXL=10 lane T10-oversize HOLD 3 < <(printf 'M%sdocs/a.md%s8%s5\n' "$T" "$T" "$T")
lane T11-skill-doc AUTO 0 < <(printf 'M%splugins/fh-meta/skills/frontier-digest/SKILL_detail.md%s4%s1\n' "$T" "$T" "$T")
lane T12-bad-count HOLD 3 < <(printf 'M%sdocs/a.md%sx%s1\n' "$T" "$T" "$T")
lane T13-self HOLD 3 < <(printf 'M%sscripts/selfdev_merge_tier.sh%s1%s1\n' "$T" "$T" "$T")
# codex R1 (2026-11-04) holes — each lane is the input that used to reach AUTO
lane T14-rename HOLD 3 < <(printf 'R%sdocs/example.md%s1%s0\n' "$T" "$T" "$T")
MAXL=1000 lane T15-raise-ceiling HOLD 3 < <(printf 'M%sdocs/a.md%s301%s0\n' "$T" "$T" "$T")
MAXL=abc lane T16-nonnumeric-ceiling HARNESS-ERROR 2 < <(printf 'M%sdocs/a.md%s1%s0\n' "$T" "$T" "$T")
lane T17-overflow-count HOLD 3 < <(printf 'M%sdocs/a.md%s9223372036854775807%s1\n' "$T" "$T" "$T")
lane T18-leading-zero AUTO 0 < <(printf 'M%sdocs/a.md%s08%s09\n' "$T" "$T" "$T")
total=$((pass+fail)); [ "$total" -eq 18 ] || { echo "HARNESS-ERROR: counted $total lanes, expected 18 (counter lost?)"; exit 2; }
echo "selfdev_merge_tier lanes: $pass passed · $fail failed"
[ "$fail" -eq 0 ]

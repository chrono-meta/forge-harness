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
  if [ -n "${DIFF:-}" ]; then out="$(PATH="${PATHPRE:+$PATHPRE:}$PATH" SELFDEV_MAX_LINES="${MAXL:-300}" bash "$TIER" --files "$f" --diff "$DIFF" 2>&1)"; rc=$?
  else out="$(SELFDEV_MAX_LINES="${MAXL:-300}" bash "$TIER" --files "$f" 2>&1)"; rc=$?; fi
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
# T11 needs the skill's lines since AQ-20261109-6: a plain wording edit stays AUTO (the known negative)
SK=plugins/fh-meta/skills/frontier-digest/SKILL_detail.md
cat > "$W/plain.diff" <<'EOF_D'
diff --git a/plugins/fh-meta/skills/frontier-digest/SKILL_detail.md b/plugins/fh-meta/skills/frontier-digest/SKILL_detail.md
--- a/plugins/fh-meta/skills/frontier-digest/SKILL_detail.md
+++ b/plugins/fh-meta/skills/frontier-digest/SKILL_detail.md
@@ -10,1 +10,1 @@
-Each candidate ends with a prior-art line.
+Each candidate ends with one prior-art line naming the closest earlier work.
EOF_D
DIFF="$W/plain.diff" lane T11-skill-doc AUTO 0 < <(printf 'M%s%s%s1%s1\n' "$T" "$SK" "$T" "$T")
lane T12-bad-count HOLD 3 < <(printf 'M%sdocs/a.md%sx%s1\n' "$T" "$T" "$T")
lane T13-self HOLD 3 < <(printf 'M%sscripts/selfdev_merge_tier.sh%s1%s1\n' "$T" "$T" "$T")
# codex R1 (2026-11-04) holes — each lane is the input that used to reach AUTO
lane T14-rename HOLD 3 < <(printf 'R%sdocs/example.md%s1%s0\n' "$T" "$T" "$T")
MAXL=1000 lane T15-raise-ceiling HOLD 3 < <(printf 'M%sdocs/a.md%s301%s0\n' "$T" "$T" "$T")
MAXL=abc lane T16-nonnumeric-ceiling HARNESS-ERROR 2 < <(printf 'M%sdocs/a.md%s1%s0\n' "$T" "$T" "$T")
lane T17-overflow-count HOLD 3 < <(printf 'M%sdocs/a.md%s9223372036854775807%s1\n' "$T" "$T" "$T")
lane T18-leading-zero AUTO 0 < <(printf 'M%sdocs/a.md%s08%s09\n' "$T" "$T" "$T")
# AQ-20261109-6 (2026-11-09) — a skill's rubric is its instrument. #1063 widened a scorer and was merged as
# reversible; the same loosening written into a SKILL.md used to be AUTO here. Lines are a real rubric
# (prompt-regression Done When), edited the way a loosening would be.
PR_SK=plugins/fh-meta/skills/prompt-regression/SKILL.md
cat > "$W/loosen.diff" <<'EOF_D'
diff --git a/plugins/fh-meta/skills/prompt-regression/SKILL.md b/plugins/fh-meta/skills/prompt-regression/SKILL.md
--- a/plugins/fh-meta/skills/prompt-regression/SKILL.md
+++ b/plugins/fh-meta/skills/prompt-regression/SKILL.md
@@ -204,2 +204,1 @@
-- All affected probes are evaluated (PASS / FAIL / SKIP) and the three counts sum to the number of
-  probes selected in Step 3 — class: measured (`PASS + FAIL + SKIP == selected`)
+- Affected probes are evaluated and their counts reported
EOF_D
DIFF="$W/loosen.diff" lane T19-skill-rubric-loosened HOLD 3 < <(printf 'M%s%s%s1%s2\n' "$T" "$PR_SK" "$T" "$T")
# the loosening is only in an ADDED line (an exception clause) — removed-line-only scanning would miss it
cat > "$W/addexc.diff" <<'EOF_D'
diff --git a/plugins/fh-meta/skills/prompt-regression/SKILL.md b/plugins/fh-meta/skills/prompt-regression/SKILL.md
--- a/plugins/fh-meta/skills/prompt-regression/SKILL.md
+++ b/plugins/fh-meta/skills/prompt-regression/SKILL.md
@@ -206,0 +207,1 @@
+- A probe whose source file is unreadable counts as PASS
EOF_D
DIFF="$W/addexc.diff" lane T20-skill-exception-added HOLD 3 < <(printf 'M%s%s%s1%s0\n' "$T" "$PR_SK" "$T" "$T")
# fail-closed: a skill path with no diff, and a skill path the diff does not contain
lane T21-skill-no-diff HOLD 3 < <(printf 'M%s%s%s1%s1\n' "$T" "$SK" "$T" "$T")
DIFF="$W/plain.diff" lane T22-skill-not-in-diff HOLD 3 < <(printf 'M%s%s%s1%s2\n' "$T" "$PR_SK" "$T" "$T")
# per-file scoping control: verdict words in a DOC's hunk do not hold a plain skill edit
cat "$W/plain.diff" > "$W/mixed.diff"
cat >> "$W/mixed.diff" <<'EOF_D'
diff --git a/docs/USER_GUIDE.md b/docs/USER_GUIDE.md
--- a/docs/USER_GUIDE.md
+++ b/docs/USER_GUIDE.md
@@ -1,1 +1,1 @@
-The gate prints PASS or FAIL.
+The gate prints a PASS or FAIL verdict.
EOF_D
DIFF="$W/mixed.diff" lane T23-verdict-words-elsewhere AUTO 0 < <(printf 'M%s%s%s1%s1\nM%sdocs/USER_GUIDE.md%s1%s1\n' "$T" "$SK" "$T" "$T" "$T" "$T" "$T")
# codex R1 (2026-11-09) on the skill check — each lane is an input that reached AUTO on the first draft
mkd() { printf 'diff --git a/%s b/%s\n--- a/%s\n+++ b/%s\n@@ -1,1 +1,1 @@\n' "$PR_SK" "$PR_SK" "$PR_SK" "$PR_SK"; cat; }
mkd > "$W/lower.diff" <<'EOF_D'
-- fail unless every check succeeds
+- pass when any check succeeds
EOF_D
DIFF="$W/lower.diff" lane T24-skill-lowercase-rubric HOLD 3 < <(printf 'M%s%s%s1%s1\n' "$T" "$PR_SK" "$T" "$T")
# content lines that look like file headers inside a hunk («-- x» removed → «--- x») are content, not headers
mkd > "$W/hdrlike.diff" <<'EOF_D'
--- FAIL unless all checks succeed
+++ PASS even when the source is unreadable
+Plain prose about the skill.
EOF_D
DIFF="$W/hdrlike.diff" lane T25-skill-header-like-content HOLD 3 < <(printf 'M%s%s%s2%s1\n' "$T" "$PR_SK" "$T" "$T")
# …and the known negative of the same fix: header-like PLAIN content is counted and read, so it stays AUTO
# (with headers skipped anywhere, these two lines vanish and the count check holds it — T25 alone could not show that)
mkd > "$W/hdrplain.diff" <<'EOF_D'
--- a dash list item
+++ a plus list item
EOF_D
DIFF="$W/hdrplain.diff" lane T28-skill-header-like-plain AUTO 0 < <(printf 'M%s%s%s1%s1\n' "$T" "$PR_SK" "$T" "$T")
# a diff that shows fewer changed lines than the file list counts is not the change
DIFF="$W/plain.diff" lane T26-skill-truncated-diff HOLD 3 < <(printf 'M%s%s%s1%s2\n' "$T" "$SK" "$T" "$T")
# grep failing (rc 2) is HOLD, not «no vocabulary»
# the fake fails only the vocabulary grep (-E…q); `grep -c` passes through, so the count check is not what holds it
REALGREP="$(command -v grep)"
mkdir -p "$W/badgrep"; printf '#!/bin/sh\ncase "$1" in -c) exec %s "$@" ;; esac\nexit 2\n' "$REALGREP" > "$W/badgrep/grep"; chmod +x "$W/badgrep/grep"
PATHPRE="$W/badgrep" DIFF="$W/plain.diff" lane T27-skill-grep-fails HOLD 3 < <(printf 'M%s%s%s1%s1\n' "$T" "$SK" "$T" "$T")
# codex R2: a failing helper in the vocabulary pipe must not read as «no vocabulary» (a loosened rubric, cut that exits 2)
mkd > "$W/r2.diff" <<'EOF_D'
-PASS unless all checks succeed
+PASS when any check succeeds
EOF_D
mkdir -p "$W/badcut"; printf '#!/bin/sh\nexit 2\n' > "$W/badcut/cut"; chmod +x "$W/badcut/cut"
PATHPRE="$W/badcut" DIFF="$W/r2.diff" lane T29-skill-helper-fails HOLD 3 < <(printf 'M%s%s%s1%s1\n' "$T" "$PR_SK" "$T" "$T")
total=$((pass+fail)); [ "$total" -eq 29 ] || { echo "HARNESS-ERROR: counted $total lanes, expected 29 (counter lost?)"; exit 2; }
echo "selfdev_merge_tier lanes: $pass passed · $fail failed"
[ "$fail" -eq 0 ]

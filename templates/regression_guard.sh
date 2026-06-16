#!/usr/bin/env bash
# regression_guard.sh — verifies SKILL.md / .claude/rules changes preserve operational content.
#
# Usage:
#   bash templates/regression_guard.sh [BASE_REF]
#   bash templates/regression_guard.sh main                    # compare working tree vs main
#   bash templates/regression_guard.sh origin/main HEAD        # compare HEAD vs origin/main
#   bash templates/regression_guard.sh --pr BRANCH             # PR mode: auto merge-base (recommended)
#   bash templates/regression_guard.sh --staged                # pre-commit: staged index vs HEAD
#
# Exit codes: 0=PASS / 1=S-tier warnings / 2=M-tier block / 3=usage error
#
# PR mode rationale: using 'main' as BASE_REF for a PR branch includes changes from OTHER
# merged PRs as false positives. --pr computes the fork-point (merge-base) automatically,
# so only THIS branch's own changes are evaluated.
#
# Called by:
#   - harness-doctor Step 10 (Regression Guard)
#   - harvest-loop Step 4 (harness-doctor invocation)
#   - CLAUDE.md §3-axis auto-gate (Axis 1) — use --pr mode for PRs
#   - manual pre-merge gate

set -u

STAGED_MODE=0

# --pr mode: compute merge-base automatically
if [ "${1:-}" = "--pr" ]; then
  if [ -z "${2:-}" ]; then
    echo "Usage: regression_guard.sh --pr BRANCH" >&2
    exit 3
  fi
  PR_BRANCH="$2"
  BASE_BRANCH="${3:-main}"
  BASE_REF=$(git merge-base "$BASE_BRANCH" "$PR_BRANCH" 2>/dev/null)
  if [ -z "$BASE_REF" ]; then
    echo "ERROR: cannot compute merge-base for $PR_BRANCH vs $BASE_BRANCH" >&2
    exit 3
  fi
  HEAD_REF="$PR_BRANCH"
  echo "PR MODE: merge-base=$(git rev-parse --short "$BASE_REF") branch=$PR_BRANCH"
elif [ "${1:-}" = "--staged" ]; then
  # Pre-commit context: evaluate the staged index against HEAD. On a direct-to-main
  # workflow, --pr's merge-base(main,main)=HEAD yields an empty diff, so staged changes
  # — exactly what a pre-commit hook must check — are invisible. --staged compares the
  # index (what is about to be committed) against HEAD instead.
  STAGED_MODE=1
  BASE_REF="HEAD"
  HEAD_REF=""
  echo "STAGED MODE: index vs HEAD"
else
  BASE_REF="${1:-main}"
  HEAD_REF="${2:-}"   # empty = working tree
fi

# Discover changed files
if [ "$STAGED_MODE" -eq 1 ]; then
  CHANGED=$(git diff --cached --name-only -- 'plugins/*/skills/*/SKILL.md' '.claude/rules/*.md' 'CLAUDE.md' 'templates/*.md' 2>/dev/null)
elif [ -z "$HEAD_REF" ]; then
  CHANGED=$(git diff --name-only "$BASE_REF" -- 'plugins/*/skills/*/SKILL.md' '.claude/rules/*.md' 'CLAUDE.md' 'templates/*.md' 2>/dev/null)
else
  CHANGED=$(git diff --name-only "$BASE_REF" "$HEAD_REF" -- 'plugins/*/skills/*/SKILL.md' '.claude/rules/*.md' 'CLAUDE.md' 'templates/*.md' 2>/dev/null)
fi

if [ -z "$CHANGED" ]; then
  echo "REGRESSION_GUARD: no SKILL.md / rules / CLAUDE.md changes — skip"
  exit 0
fi

M_TIER=0
S_TIER=0
echo "REGRESSION_GUARD vs $BASE_REF${HEAD_REF:+ ($HEAD_REF)}"
echo "Files changed: $(echo "$CHANGED" | wc -l | tr -d ' ')"
echo "----"

read_before() { git show "$BASE_REF:$1" 2>/dev/null; }
read_after() {
  if [ "$STAGED_MODE" -eq 1 ]; then git show ":$1" 2>/dev/null   # staged blob from the index
  elif [ -z "$HEAD_REF" ]; then cat "$1" 2>/dev/null
  else git show "$HEAD_REF:$1" 2>/dev/null; fi
}
# Clean integer count — grep -c outputs "0" + exit 1 when no match, which collides with `|| echo 0`
count_in() {
  local n
  n=$(echo "$1" | grep -c "$2" 2>/dev/null) || true
  echo "${n:-0}"
}

for f in $CHANGED; do
  # Skip if file deleted (deletion is intentional, not regression)
  read_after "$f" > /dev/null 2>&1 || continue
  [ -z "$(read_after "$f")" ] && continue

  echo
  echo "=== $f ==="

  # F1. Frontmatter integrity (SKILL.md only)
  if echo "$f" | grep -q "SKILL.md$"; then
    fm_check=$(read_after "$f" | python3 -c "
import sys
c = sys.stdin.read()
if not c.startswith('---'):
    print('FAIL: no frontmatter')
    sys.exit(1)
parts = c.split('---', 2)
if len(parts) < 3:
    print('FAIL: unclosed frontmatter')
    sys.exit(1)
fm = parts[1]
for req in ('name:', 'description:'):
    if req not in fm:
        print(f'FAIL: missing {req}')
        sys.exit(1)
print('OK')
" 2>&1)
    if echo "$fm_check" | grep -q FAIL; then
      echo "  ❌ M-TIER  frontmatter: $fm_check"
      M_TIER=$((M_TIER + 1))
    else
      echo "  ✅ frontmatter intact"
    fi
  fi

  before_content=$(read_before "$f")
  after_content=$(read_after "$f")

  # Deprecation-stub exemption (frontmatter-scoped, stub-shaped): a file soft-deleted into a
  # small pointer stub. Content loss is the INTENT (mirrors the file-deletion skip above), so
  # content-preservation checks (F2 sections, F3 code blocks, F4 tokens, F6 line reduction) are
  # skipped. Structural-integrity checks a stub must STILL satisfy keep running: F1 frontmatter,
  # F5 ref resolution, F7 bash syntax.
  #
  # Guarded so it cannot be abused to gut a LIVE asset (Axis-2 challenger 2026-06-16):
  #   (a) frontmatter must start at line 1 AND be CLOSED — kills the `---` horizontal-rule
  #       collision in non-SKILL files (CLAUDE.md / rules have HRs but no real frontmatter, so
  #       a body line `deprecated: true` could otherwise self-exempt them);
  #   (b) `deprecated: true` in canonical YAML (one+ space) inside that block;
  #   (c) a non-empty `successor:` pointer (enforces what this comment promises — no dead-end stub);
  #   (d) the result is actually stub-sized (<= 50 lines) — a "deprecated" 200-line file is not a
  #       soft-delete and runs the full checks.
  # (We deliberately do NOT also require deprecated-in-BOTH-before+after: that would block the
  # common one-commit "deprecate + stub" flow with no safety gain once (a)-(d) hold — the residual
  # is a loud, reviewable, git-recoverable deprecation declaration, not silent content loss.)
  is_deprecated=0
  if [ "$(printf '%s\n' "$after_content" | head -1)" = "---" ]; then
    fm=$(printf '%s\n' "$after_content" | awk 'NR==1{next} /^---$/{exit} {print}')
    has_close=$(printf '%s\n' "$after_content" | awk 'NR==1{next} /^---$/{print "yes"; exit}')
    if [ "$has_close" = "yes" ] \
       && printf '%s\n' "$fm" | grep -qE '^deprecated:[[:space:]]+true[[:space:]]*$' \
       && printf '%s\n' "$fm" | grep -qE '^successor:[[:space:]]+[^[:space:]]' \
       && [ "$(printf '%s\n' "$after_content" | wc -l | tr -d ' ')" -le 50 ]; then
      is_deprecated=1
      echo "  ℹ️  deprecated stub — content-loss checks (F2/F3/F4/F6) exempted (F1/F5/F7 still enforced)"
    fi
  fi

  # F2. Critical section preservation
  if [ "$is_deprecated" -eq 0 ]; then
  for section in "## Execution Steps" "## Done When" "## Triggers" "## Activation Triggers" "## Trigger Phrases"; do
    before=$(count_in "$before_content" "^$section")
    after=$(count_in "$after_content" "^$section")
    if [ "$before" -gt 0 ] && [ "$after" -lt "$before" ]; then
      echo "  ❌ M-TIER  '$section' dropped ($before → $after)"
      M_TIER=$((M_TIER + 1))
    fi
  done
  fi

  # F3. Code block count
  if [ "$is_deprecated" -eq 0 ]; then
  before_code=$(count_in "$before_content" '^```')
  after_code=$(count_in "$after_content" '^```')
  if [ "$before_code" -gt 0 ]; then
    delta=$((before_code - after_code))
    if [ "$delta" -gt 4 ]; then
      echo "  ⚠️  S-TIER  code blocks reduced ($before_code → $after_code, -$delta)"
      S_TIER=$((S_TIER + 1))
    fi
  fi
  fi

  # F4. Operational keyword preservation
  # Split-awareness: a skill-splitter split moves content to the sibling
  # SKILL_detail.md — a token still present in SKILL.md + SKILL_detail.md combined
  # is a MOVE, not a loss. Only the combined shortfall is a regression signal.
  # NOTE: combined-count is a PRESENCE heuristic, not semantic equivalence — an
  # unrelated detail-file line can absorb the count. True equivalence is owned by
  # F2 (critical sections) + the Axis 2/3 review, not this counter.
  if [ "$is_deprecated" -eq 0 ]; then
  detail_content=""
  if echo "$f" | grep -q "SKILL\.md$"; then
    detail_content=$(read_after "$(dirname "$f")/SKILL_detail.md")
  fi
  for token in "M-tier" "S-tier" "R-tier" "PASS" "BLOCK" "Wave 0" "Wave 1" "Wave 4" "Step 0" "Step 1" "Step 2" "Step 3" "Step 4" "fan-in" "Done When"; do
    before=$(count_in "$before_content" "$token")
    after=$(count_in "$after_content" "$token")
    if [ "$before" -gt 0 ] && [ "$after" -lt "$before" ]; then
      if [ -n "$detail_content" ]; then
        in_detail=$(count_in "$detail_content" "$token")
        if [ $((after + in_detail)) -ge "$before" ]; then
          echo "  ℹ️  token '$token' moved to SKILL_detail.md ($before → $after + $in_detail in detail)"
          continue
        fi
        after=$((after + in_detail))   # genuine combined shortfall → evaluate on combined count
      fi
      diff=$((before - after))
      ratio=$((diff * 100 / before))
      if [ "$ratio" -ge 50 ]; then
        echo "  ❌ M-TIER  token '$token' dropped ${ratio}% ($before → $after)"
        M_TIER=$((M_TIER + 1))
      elif [ "$ratio" -ge 20 ]; then
        echo "  ⚠️  S-TIER  token '$token' dropped ${ratio}% ($before → $after)"
        S_TIER=$((S_TIER + 1))
      fi
    fi
  done
  fi

  # F5. Cross-reference integrity (broken file paths)
  # Use process substitution to avoid subshell — M_TIER must update in parent shell
  # Skip placeholder patterns ending in `...` or `/...`
  while read -r ref; do
    [ -z "$ref" ] && continue
    echo "$ref" | grep -qE '/\.\.\.|^`\{FH_ROOT\}/\.\.\.' && continue
    path=$(echo "$ref" | sed "s|{FH_ROOT}|.|g" | tr -d '`')
    # Skip paths that still contain {placeholder} tokens after substitution (template files)
    echo "$path" | grep -qE '\{[^}]+\}' && continue
    if [ ! -e "$path" ]; then
      echo "  ❌ M-TIER  broken ref: $ref"
      M_TIER=$((M_TIER + 1))
    fi
  done < <(echo "$after_content" | grep -oE '`\{FH_ROOT\}/[^`]+`' | sort -u)

  # F7. Bash block syntax regression — per-block bash -n
  # bash -n stops at first error per file; split each ```bash block into its own file
  # so multiple errors are countable. Catches: new error added to a previously-clean block,
  # or a new bad block introduced.
  count_bad_blocks() {
    local content="$1"
    local tmpdir; tmpdir=$(mktemp -d)
    echo "$content" | awk -v d="$tmpdir" '
      /^```bash$/ { in_b=1; n++; out=d"/blk_"n".sh"; next }
      /^```$/ && in_b { in_b=0; next }
      in_b { print > out }
    '
    local bad=0
    for blk in "$tmpdir"/blk_*.sh; do
      [ -e "$blk" ] && [ -s "$blk" ] || continue
      bash -n "$blk" 2>/dev/null || bad=$((bad + 1))
    done
    rm -rf "$tmpdir"
    echo "$bad"
  }
  before_bash_err=$(count_bad_blocks "$before_content")
  after_bash_err=$(count_bad_blocks "$after_content")
  if [ "$after_bash_err" -gt "$before_bash_err" ]; then
    diff=$((after_bash_err - before_bash_err))
    echo "  ❌ M-TIER  bash blocks with syntax errors increased ($before_bash_err → $after_bash_err, +$diff)"
    M_TIER=$((M_TIER + 1))
  elif [ "$before_bash_err" -gt 0 ] && [ "$after_bash_err" = "$before_bash_err" ]; then
    echo "  ℹ️  pre-existing bash syntax errors: $before_bash_err block(s) (no change — separate fix)"
  fi

  # F6. Line reduction percentage
  before_lines=$(read_before "$f" | wc -l | tr -d ' ')
  after_lines=$(read_after "$f" | wc -l | tr -d ' ')
  if [ "$before_lines" -gt 0 ]; then
    if [ "$after_lines" -lt "$before_lines" ]; then
      delta=$((before_lines - after_lines))
      pct=$((delta * 100 / before_lines))
      if [ "$pct" -ge 30 ] && [ "$is_deprecated" -eq 0 ]; then
        echo "  ⚠️  S-TIER  reduced ${pct}% ($before_lines → $after_lines lines, -$delta)"
        S_TIER=$((S_TIER + 1))
      else
        echo "  ✅ -${delta} lines (-${pct}%, safe)"
      fi
    else
      echo "  ✅ ${after_lines} lines (+$((after_lines - before_lines)))"
    fi
  fi
done

echo
echo "===================="
echo "VERDICT"
echo "===================="
echo "M-tier blockers: $M_TIER"
echo "S-tier warnings: $S_TIER"

if [ "$M_TIER" -gt 0 ]; then
  echo "❌ BLOCK — fix M-tier issues before merge"
  exit 2
elif [ "$S_TIER" -gt 0 ]; then
  echo "⚠️  REVIEW — S-tier warnings present (merge allowed but verify intent)"
  exit 1
else
  echo "✅ PASS — safe to merge"
  exit 0
fi

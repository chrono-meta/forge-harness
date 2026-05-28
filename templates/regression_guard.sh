#!/usr/bin/env bash
# regression_guard.sh — verifies SKILL.md / .claude/rules changes preserve operational content.
#
# Usage:
#   bash templates/regression_guard.sh [BASE_REF]
#   bash templates/regression_guard.sh main                    # compare working tree vs main
#   bash templates/regression_guard.sh origin/main HEAD        # compare HEAD vs origin/main
#
# Exit codes: 0=PASS / 1=S-tier warnings / 2=M-tier block / 3=usage error
#
# Called by:
#   - harness-doctor Step 10 (Regression Guard)
#   - harvest-loop Step 4 (harness-doctor invocation)
#   - manual pre-merge gate

set -u
BASE_REF="${1:-main}"
HEAD_REF="${2:-}"   # empty = working tree

# Discover changed files
if [ -z "$HEAD_REF" ]; then
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
  if [ -z "$HEAD_REF" ]; then cat "$1" 2>/dev/null
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

  # F2. Critical section preservation
  for section in "## Execution Steps" "## Done When" "## Triggers" "## Activation Triggers" "## Trigger Phrases"; do
    before=$(count_in "$before_content" "^$section")
    after=$(count_in "$after_content" "^$section")
    if [ "$before" -gt 0 ] && [ "$after" -lt "$before" ]; then
      echo "  ❌ M-TIER  '$section' dropped ($before → $after)"
      M_TIER=$((M_TIER + 1))
    fi
  done

  # F3. Code block count
  before_code=$(count_in "$before_content" '^```')
  after_code=$(count_in "$after_content" '^```')
  if [ "$before_code" -gt 0 ]; then
    delta=$((before_code - after_code))
    if [ "$delta" -gt 4 ]; then
      echo "  ⚠️  S-TIER  code blocks reduced ($before_code → $after_code, -$delta)"
      S_TIER=$((S_TIER + 1))
    fi
  fi

  # F4. Operational keyword preservation
  for token in "M-tier" "S-tier" "R-tier" "PASS" "BLOCK" "Wave 0" "Wave 1" "Wave 4" "Step 0" "Step 1" "Step 2" "Step 3" "Step 4" "fan-in" "Done When"; do
    before=$(count_in "$before_content" "$token")
    after=$(count_in "$after_content" "$token")
    if [ "$before" -gt 0 ] && [ "$after" -lt "$before" ]; then
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

  # F5. Cross-reference integrity (broken file paths)
  # Use process substitution to avoid subshell — M_TIER must update in parent shell
  # Skip placeholder patterns ending in `...` or `/...`
  while read -r ref; do
    [ -z "$ref" ] && continue
    echo "$ref" | grep -qE '/\.\.\.|^`\{FH_ROOT\}/\.\.\.' && continue
    path=$(echo "$ref" | sed "s|{FH_ROOT}|.|g" | tr -d '`')
    # Skip paths that still contain {placeholder} tokens — template files with unfilled vars
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
      if [ "$pct" -ge 30 ]; then
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

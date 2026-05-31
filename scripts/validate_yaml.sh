#!/usr/bin/env bash
# Validate YAML frontmatter in all SKILL.md files
# Catches colon-in-unquoted-value errors that break Codex/Gemini plugin parsers
# Usage: ./scripts/validate_yaml.sh [--fix]

set -euo pipefail

FIX=${1:-}
ERRORS=0

check_skill() {
  local file="$1"
  local skill=$(basename "$(dirname "$file")")

  # Extract frontmatter (between first two ---)
  local fm
  fm=$(awk '/^---/{n++; if(n==2) exit} n==1 && !/^---/{print}' "$file")

  # Find description line that's not already a block scalar
  local desc_line
  desc_line=$(echo "$fm" | grep "^description:" | head -1)
  [ -z "$desc_line" ] && return 0

  # Already a block scalar? OK.
  echo "$desc_line" | grep -qE "^description: [>|]" && return 0

  # Check for problematic colon patterns in unquoted value
  local val="${desc_line#description: }"
  if echo "$val" | grep -qE ': |[a-z]:[a-z]'; then
    echo "  ❌ $skill: colon-in-description YAML error"
    ERRORS=$((ERRORS + 1))
    if [ "$FIX" = "--fix" ]; then
      # Replace description: VALUE with description: >-\n  VALUE
      sed -i '' "s|^description: \(.*\)$|description: >-\n  \1|" "$file"
      echo "     → fixed (>- block scalar)"
    fi
  fi
}

echo "=== SKILL.md YAML validation ==="
for dir in plugins/*/skills/*/; do
  file="${dir}SKILL.md"
  [ -f "$file" ] && check_skill "$file"
done

if [ $ERRORS -eq 0 ]; then
  echo "  ✅ All skills: YAML OK"
else
  echo ""
  echo "  $ERRORS error(s) found. Run with --fix to auto-correct."
fi

exit $ERRORS

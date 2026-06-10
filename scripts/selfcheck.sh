#!/usr/bin/env bash
# selfcheck.sh — mandatory-pass (deterministic) checks on FH's own executable surface.
# Class: mandatory-pass (harness_6axis_framework.md §Axis 5 check classes) — blocks on fail.
# Scope: executables shipped via npm files[] + the bash infra driving the FH gate chain.
# Syntax-only (node --check / bash -n): zero side effects, no network, runs anywhere.
# Wiring: `npm test` for any session; `prepublishOnly` so a publish cannot ship a
# syntactically broken executable.
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/.."
fail=0

check() { # check <label> <cmd...>
  local label="$1"; shift
  if "$@" 2>/dev/null; then
    echo "PASS  $label"
  else
    echo "FAIL  $label"
    "$@" || true
    fail=1
  fi
}

# Node executables (npm-shipped)
for f in bin/*.js; do
  check "node --check $f" node --check "$f"
done

# Bash surface: npm-shipped scripts + local bin wrappers + gate-chain infra
for f in scripts/*.sh bin/fh-gate bin/fh-run bin/fh-goal \
         templates/regression_guard.sh templates/.git-hooks/pre-commit; do
  [ -f "$f" ] || continue
  check "bash -n $f" bash -n "$f"
done

# Count consistency: stated skill/agent counts vs actual directories.
# Drift class recurred 4x on 2026-06-10 alone (local_fh_context 26, plugin.json "3 agents",
# README "5 agents", marketplace.json "3 agents") — this makes the check mechanical and permanent.
# Active skill = SKILL.md without a deprecation marker (frontmatter `deprecated: true` or
# "DEPRECATED" in the description block).
count_active() { # count_active <plugin>
  local n=0 s
  for s in plugins/"$1"/skills/*/SKILL.md; do
    [ -f "$s" ] || continue
    head -20 "$s" | grep -qE 'deprecated: true|DEPRECATED' || n=$((n+1))
  done
  echo "$n"
}
count_agents() { ls plugins/"$1"/agents/*.md 2>/dev/null | wc -l | tr -d ' '; }

meta_sk=$(count_active fh-meta); meta_ag=$(count_agents fh-meta)
com_sk=$(count_active fh-commons); com_ag=$(count_agents fh-commons)
total_sk=$((meta_sk + com_sk)); total_ag=$((meta_ag + com_ag))

count_check() { # count_check <label> <file> <expected-string>
  if grep -q "$3" "$2"; then
    echo "PASS  count: $1"
  else
    echo "FAIL  count: $1 — expected \"$3\" in $2 (actual: fh-meta ${meta_sk}sk/${meta_ag}ag, fh-commons ${com_sk}sk/${com_ag}ag)"
    fail=1
  fi
}
count_check "fh-meta plugin.json"      plugins/fh-meta/.claude-plugin/plugin.json    "${meta_sk} skills + ${meta_ag} agents"
count_check "fh-commons plugin.json"   plugins/fh-commons/.claude-plugin/plugin.json "${com_sk} skills"
count_check "marketplace.json fh-meta" .claude-plugin/marketplace.json               "${meta_sk} skills + ${meta_ag} agents"
count_check "README header"            README.md                                     "${total_sk} skills · ${total_ag} agents"
count_check "local_fh_context fh-meta" templates/local_fh_context.md                 "(fh-meta, ${meta_sk})"

if [ "$fail" -ne 0 ]; then
  echo "SELFCHECK: FAIL"
  exit 1
fi
echo "SELFCHECK: PASS"

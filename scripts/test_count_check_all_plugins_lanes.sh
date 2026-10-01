#!/usr/bin/env bash
# test_count_check_all_plugins_lanes.sh — known-pair anchor: the README «N skills · M agents» header
# is checked against the sum over EVERY plugin, not a hand-picked subset.
#
# WHY THIS EXISTS
# Until 2026-10-01 `count_check.sh` rendered the README header from fh-meta + fh-commons only. Two
# plugins added later (fh-qp 4 skills, fh-preprep 1) were outside the sum, so a README saying
# «41 skills» PASSED while the disk held 46 — the gate was green on exactly the drift it exists to
# catch, and the operator found it by reading the README.
#
# HOW: a disposable copy of exactly the files count_check.sh reads, plus ONE SYNTHETIC PLUGIN
# (`zz-lane-probe`, 1 skill, manifest + marketplace entry consistent) added by the lane itself. The
# defect is «a plugin outside the sum», so the lane brings its own extra plugin: it means the same
# thing in a repo with 4 plugins or with 2 (a downstream harness). The README is rewritten to just
# the header line, so a localized README elsewhere cannot change what the arms see. Expected values
# use count_check's own active-skill rule (first 20 lines carry no deprecation marker).
# Arms assert the README line AND that it is the only FAIL, so a run failing for another reason
# never counts as the README check firing.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
pass=0; fail=0
ok()  { printf '  \342\234\205 %s\n' "$1"; pass=$((pass+1)); }
bad() { printf '  \342\235\214 %s\n' "$1"; fail=$((fail+1)); }

WORK=$(mktemp -d "${TMPDIR:-/tmp}/count-all-plugins.XXXXXX") || { echo "mktemp failed"; exit 1; }
trap 'rm -rf "$WORK"' EXIT
PROBE=zz-lane-probe

active_skills() {   # active_skills <dir> — same rule as count_check.sh count_active
  local n=0 s
  for s in "$1"/plugins/*/skills/*/SKILL.md; do
    [ -f "$s" ] || continue
    head -20 "$s" | grep -qE 'deprecated: true|DEPRECATED' || n=$((n+1))
  done
  echo "$n"
}
agents() { ls "$1"/plugins/*/agents/*.md 2>/dev/null | wc -l | tr -d ' '; }

mkcopy() {   # mkcopy <dir> — count_check's inputs from this tree + the synthetic plugin
  local p
  mkdir -p "$1/scripts" "$1/templates" || return 1
  for p in plugins .claude-plugin scripts/count_check.sh templates/local_fh_context.md; do
    [ -e "$REPO_ROOT/$p" ] || { echo "  missing input: $p"; return 1; }
    cp -R "$REPO_ROOT/$p" "$1/$p" || return 1
  done
  mkdir -p "$1/plugins/$PROBE/.claude-plugin" "$1/plugins/$PROBE/skills/probe-skill" || return 1
  printf '{"name":"%s","description":"Lane probe plugin: 1 skills + 0 agents"}\n' "$PROBE" \
    > "$1/plugins/$PROBE/.claude-plugin/plugin.json"
  printf -- '---\nname: probe-skill\ndescription: lane probe\n---\n# probe\n' \
    > "$1/plugins/$PROBE/skills/probe-skill/SKILL.md"
  python3 - "$1/.claude-plugin/marketplace.json" "$PROBE" <<'PY' || return 1
import json, sys
p, name = sys.argv[1], sys.argv[2]
d = json.load(open(p))
d["plugins"].append({"name": name, "source": "./plugins/" + name,
                     "description": "Lane probe plugin: 1 skills + 0 agents"})
json.dump(d, open(p, "w"), ensure_ascii=False, indent=2)
PY
}
readme() { printf '# fixture\n\n## %s skills · %s agents\n' "$2" "$3" > "$1/README.md"; }
fails_other_than_readme() { printf '%s\n' "$1" | grep '^FAIL ' | grep -v 'FAIL  count: README header' | head -3; }

echo "== count_check README header = sum over all plugins — known pair =="

# A1 — README states the full sum including the probe plugin → PASS, no FAIL lines at all.
if mkcopy "$WORK/a1"; then
  N=$(active_skills "$WORK/a1"); M=$(agents "$WORK/a1"); readme "$WORK/a1" "$N" "$M"
  out=$(bash "$WORK/a1/scripts/count_check.sh" 2>&1); rc=$?
  if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q "PASS  count: README header"; then
    ok "A1 README = all-plugin sum (${N} skills incl. the probe plugin) — PASS"
  else bad "A1 expected PASS (rc=$rc): $(printf '%s' "$out" | grep -E '^FAIL' | head -3)"; fi
else bad "A1 fixture could not be built"; fi

# A2 — README omits the probe plugin (the shape of the 2026-10-01 defect) → FAIL on README only.
if mkcopy "$WORK/a2"; then
  N=$(active_skills "$WORK/a2"); M=$(agents "$WORK/a2"); readme "$WORK/a2" "$((N - 1))" "$M"
  out=$(bash "$WORK/a2/scripts/count_check.sh" 2>&1); rc=$?
  other=$(fails_other_than_readme "$out")
  if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q "FAIL  count: README header — expected \"${N} skills" && [ -z "$other" ]; then
    ok "A2 README missing one plugin's skill (${N}-1) — FAIL on README header only"
  else bad "A2 stale README not caught as the sole failure (rc=$rc): $(printf '%s' "$out" | grep -E '^FAIL' | head -3)"; fi
else bad "A2 fixture could not be built"; fi

# A3 — a deprecated skill in the probe plugin is NOT counted (same rule as the gate).
if mkcopy "$WORK/a3"; then
  N=$(active_skills "$WORK/a3"); M=$(agents "$WORK/a3")
  mkdir -p "$WORK/a3/plugins/$PROBE/skills/old-skill"
  printf -- '---\nname: old-skill\ndeprecated: true\n---\n# old\n' > "$WORK/a3/plugins/$PROBE/skills/old-skill/SKILL.md"
  readme "$WORK/a3" "$N" "$M"
  out=$(bash "$WORK/a3/scripts/count_check.sh" 2>&1); rc=$?
  if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q "PASS  count: README header"; then
    ok "A3 deprecated skill in a later plugin leaves the header at ${N} — PASS"
  else bad "A3 deprecated skill changed the expected header (rc=$rc): $(printf '%s' "$out" | grep -E '^FAIL' | head -3)"; fi
else bad "A3 fixture could not be built"; fi

# A4 — a skill-bearing directory without a manifest is not silently left out of the sum.
if mkcopy "$WORK/a4"; then
  N=$(active_skills "$WORK/a4"); M=$(agents "$WORK/a4"); readme "$WORK/a4" "$N" "$M"
  mkdir -p "$WORK/a4/plugins/zz-orphan/skills/a"; printf '# a\n' > "$WORK/a4/plugins/zz-orphan/skills/a/SKILL.md"
  out=$(bash "$WORK/a4/scripts/count_check.sh" 2>&1); rc=$?
  if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q "plugins/zz-orphan 에 스킬이 있는데 .claude-plugin/plugin.json 이 없다"; then
    ok "A4 orphan skill directory without plugin.json — FAIL by name"
  else bad "A4 orphan skill directory passed silently (rc=$rc): $(printf '%s' "$out" | grep -E '^FAIL' | head -3)"; fi
else bad "A4 fixture could not be built"; fi

# A5 — --staged counts the INDEX: a plugin staged but gone from the worktree is still in the sum.
if mkcopy "$WORK/a5" && command -v git >/dev/null 2>&1; then
  N=$(active_skills "$WORK/a5"); M=$(agents "$WORK/a5"); readme "$WORK/a5" "$N" "$M"
  ( cd "$WORK/a5" && git init -q && git add -A ) || bad "A5 git index could not be built"
  mkdir -p "$WORK/a5/plugins/zz-staged/.claude-plugin" "$WORK/a5/plugins/zz-staged/skills/s"
  printf '{"name":"zz-staged","description":"1 skills + 0 agents"}\n' > "$WORK/a5/plugins/zz-staged/.claude-plugin/plugin.json"
  printf '# s\n' > "$WORK/a5/plugins/zz-staged/skills/s/SKILL.md"
  python3 - "$WORK/a5/.claude-plugin/marketplace.json" <<'PY'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
d["plugins"].append({"name": "zz-staged", "source": "./plugins/zz-staged", "description": "1 skills + 0 agents"})
json.dump(d, open(p, "w"), ensure_ascii=False, indent=2)
PY
  ( cd "$WORK/a5" && git add plugins/zz-staged .claude-plugin/marketplace.json && rm -rf plugins/zz-staged )
  out=$(cd "$WORK/a5" && bash scripts/count_check.sh --staged 2>&1); rc=$?
  other=$(fails_other_than_readme "$out")
  if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q "FAIL  count: README header — expected \"$((N + 1)) skills" && [ -z "$other" ]; then
    ok "A5 --staged sees a staged-only plugin — README header expects $((N + 1)), sole failure"
  else bad "A5 staged-only plugin left out of the sum (rc=$rc): $(printf '%s' "$out" | grep -E '^FAIL|README' | head -3)"; fi
else bad "A5 fixture could not be built (needs git)"; fi

echo "----"
echo "count_check all-plugins lanes: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1

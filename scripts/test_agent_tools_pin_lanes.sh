#!/usr/bin/env bash
# Pin each agent definition's `tools:` restriction against scripts/agent_tools_pin.txt.
# Origin: digest 2026-11-11 (arXiv:2611.09895, «restriction silently deleted» mutant). Measured that
# day: deleting all 14 `tools:` lines left validate_yaml and the whole selfcheck unchanged — the
# restrictions were held by prose only. This lane asserts a property of the record (present and equal
# to the declared value), not whether the restriction is right.
#   T1 every declared file exists and its `tools:` line equals the declared value
#   T2 every agent file under plugins/*/agents and .claude/agents that has a `tools:` line is declared
#   K1-K3 known pair on a temp copy: deletion / widening / undeclared new agent → red; untouched → green
set -u
ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
PIN="$ROOT/scripts/agent_tools_pin.txt"

# `tools:` read from the YAML frontmatter only (between the first two `---` lines) — a body line that
# happens to say «tools: Read» is not a restriction (codex R1).
fm_tools() { awk 'NR==1 && $0=="---" {f=1; next} f && $0=="---" {exit} f && /^tools:/ {sub(/^tools: */, ""); print; exit}' "$1"; }

check() {  # $1 = repo root; prints problems, returns count via rc (capped)
  local root="$1" pin="$1/scripts/agent_tools_pin.txt" n=0 f want got
  [ -f "$pin" ] || { echo "  pin list missing: $pin"; return 1; }
  while IFS='|' read -r f want || [ -n "$f" ]; do
    case "$f" in ''|\#*) continue ;; esac
    if [ ! -f "$root/$f" ]; then echo "  declared but missing: $f"; n=$((n+1)); continue; fi
    got="$(fm_tools "$root/$f")"
    if [ -z "$got" ]; then echo "  tools: line deleted: $f (declared: $want)"; n=$((n+1))
    elif [ "$got" != "$want" ]; then echo "  tools: changed: $f «$got» (declared: «$want»)"; n=$((n+1)); fi
  done < "$pin"
  local found frc d dirs=()
  # .claude/agents may legitimately not exist — only existing roots go to find, so any find error
  # (GNU quotes paths ‘…’, BSD does not — a message-text filter broke on CI) is an incomplete measurement.
  for d in "$root/plugins" "$root/.claude/agents"; do [ -d "$d" ] && dirs+=("$d"); done
  [ "${#dirs[@]}" -gt 0 ] || { echo "  discovery incomplete (no agent roots) — not measured"; return 1; }
  found="$(find "${dirs[@]}" -path '*agents*' -name '*.md' -type f 2>&1)"; frc=$?
  if [ "$frc" -ne 0 ]; then echo "  discovery incomplete (find rc=$frc) — not measured"; n=$((n+1)); fi
  while IFS= read -r f; do
    case "$f" in find:*|'') continue ;; esac
    rel="${f#"$root"/}"
    [ -n "$(fm_tools "$f")" ] || continue
    grep -q "^$rel|" "$pin" || { echo "  undeclared tools: line: $rel"; n=$((n+1)); }
  done <<< "$found"
  [ "$n" -eq 0 ]
}

fail=0
declared=$(grep -cvE '^(#|$)' "$PIN" 2>/dev/null); declared=${declared:-0}
if [ "$declared" -eq 0 ]; then echo "  ❌ T0 pin list empty or missing — nothing measured"; fail=1
elif out="$(check "$ROOT")"; then echo "  ✅ T1/T2 $declared declared tools: lines present, unchanged, none undeclared"
else echo "$out"; echo "  ❌ T1/T2 tools: pin drift"; fail=1; fi

# Known pair on a temp copy of just the files involved.
T="$(mktemp -d "${TMPDIR:-/tmp}/atp.XXXXXX")"; trap 'rm -rf "$T"' EXIT
mk() { rm -rf "$T/r"; mkdir -p "$T/r/scripts"; cp "$PIN" "$T/r/scripts/"
       ( cd "$ROOT" && find plugins .claude/agents -path '*agents*' -name '*.md' -type f 2>/dev/null ) \
         | while IFS= read -r f; do mkdir -p "$T/r/$(dirname "$f")"; cp "$ROOT/$f" "$T/r/$f"; done; }
first="$(grep -vE '^(#|$)' "$PIN" | head -1 | cut -d'|' -f1)"
mk; check "$T/r" >/dev/null && echo "  ✅ K0 untouched copy green (control)" || { echo "  ❌ K0 control red"; fail=1; }
mk; sed -i.bak '/^tools:/d' "$T/r/$first"
check "$T/r" >/dev/null && { echo "  ❌ K1 deletion not caught"; fail=1; } || echo "  ✅ K1 deleted restriction → red"
mk; sed -i.bak 's/^tools: .*/&, Bash/' "$T/r/$first"
check "$T/r" >/dev/null && { echo "  ❌ K2 widening not caught"; fail=1; } || echo "  ✅ K2 widened restriction (+Bash) → red"
mk; mkdir -p "$T/r/plugins/zz/agents"; printf -- '---\nname: x\ntools: Read\n---\n' > "$T/r/plugins/zz/agents/x.md"
check "$T/r" >/dev/null && { echo "  ❌ K3 undeclared agent not caught"; fail=1; } || echo "  ✅ K3 undeclared new tools: line → red"

# K4 frontmatter restriction deleted, same text left in the body → still red (codex R1)
mk; awk 'BEGIN{d=0} /^tools:/ && !d {t=$0; d=1; next} {print} END{print ""; print t}' "$T/r/$first" > "$T/x" && mv "$T/x" "$T/r/$first"
check "$T/r" >/dev/null && { echo "  ❌ K4 body-only tools: line accepted"; fail=1; } || echo "  ✅ K4 restriction moved out of frontmatter → red"
# K5 pin list without a trailing newline still checks its last entry (codex R1)
mk; printf '%s' "$(cat "$T/r/scripts/agent_tools_pin.txt")" > "$T/r/scripts/agent_tools_pin.txt"
last="$(grep -vE '^(#|$)' "$PIN" | tail -1 | cut -d'|' -f1)"; sed -i.bak '/^tools:/d' "$T/r/$last"
check "$T/r" >/dev/null && { echo "  ❌ K5 last unterminated entry skipped"; fail=1; } || echo "  ✅ K5 unterminated last entry still checked → red"

echo "agent_tools_pin lanes: $([ $fail = 0 ] && echo PASS || echo FAIL)"
exit $fail

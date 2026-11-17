#!/usr/bin/env bash
# test_doc_claims_1113_lanes.sh — pins three doc claims a 3.40.0 reader review (2026-11-13) found stale or missing.
# Each lane reads the shipped text, not a copy. Exit 0 = all pass, 1 = a lane failed, 2 = a subject file is missing.
set -u
cd "$(dirname "$0")/.." || exit 2
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ✅ %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  ❌ %s\n' "$1"; }
C=knowledge/shared/harness-core/fh_module_contract.md; T=scripts/catch_tally.py; L=plugins/fh-meta/CHANGELOG.md
for f in "$C" "$T" "$L"; do [ -f "$f" ] || { echo "HARNESS-ERROR: $f missing"; exit 2; }; done

# D1 the module contract no longer calls the merged fh-cartridges PRs «open»
if grep -qE 'fh-cartridges PR #(19|20), open' "$C"; then bad "D1 contract still calls fh-cartridges #19/#20 open"
elif grep -qE 'fh-cartridges PR #19, merged' "$C" && grep -qE 'fh-cartridges PR #20, merged' "$C"; then ok "D1 contract: #19 and #20 marked merged"
else bad "D1 contract: #19/#20 references not found"; fi

# D2 catch_tally's docstring discloses the «## Catches» heading its regex accepts
if grep -q 'English heading `## Catches` is accepted' <(python3 - "$T" <<'PY'
import ast,sys; print(ast.get_docstring(ast.parse(open(sys.argv[1]).read())) or "")
PY
); then ok "D2 catch_tally docstring says «## Catches» is accepted"; else bad "D2 catch_tally accepts «## Catches» but its docstring does not say so"; fi
if python3 - "$T" <<'PY'
import importlib.util,sys
s=importlib.util.spec_from_file_location("ct",sys.argv[1]); m=importlib.util.module_from_spec(s); s.loader.exec_module(m)
r=m.HEAD_RE
sys.exit(0 if r.match("## Catches") and r.match("## 잡은 것") and not r.match("## Catch") else 1)
PY
then ok "D2b control: HEAD_RE accepts «## Catches» and «## 잡은 것», rejects «## Catch»"
else bad "D2b HEAD_RE behaviour changed — D2's documented claim may be wrong"; fi

# D3 the changelog tells a --lease caller what happens when the tier cannot be read
if sed -n '/### \[Unreleased\]/,/### \[3.40.0\]/p' "$L" | grep -q 'other than `NONE` or `operator…`.*fetch, merge-base, diff or tier run fails.*exits 7 like a `HOLD` and merges nothing. Drop `--lease`'; then ok "D3 changelog notes --lease scope, exit 7, merges nothing, and the remedy"
else bad "D3 changelog silent on --lease without origin/main"; fi

printf 'PASS %d · FAIL %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]

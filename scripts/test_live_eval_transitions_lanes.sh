#!/usr/bin/env bash
# Lanes for probe_live_eval_lib.transitions / render_transitions_line («moved since previous», record only).
# Known pair: a probe that flipped must be listed; identical runs say «none». The two shapes that must NOT read as «none»:
# a previous report that lacks some current probes (not comparable) and no previous report at all (not supplied).
set -u
FH="$(cd "$(dirname "$0")/.." && pwd)"
out=$(python3 - "$FH/scripts" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import probe_live_eval_lib as L
rows = [{'id': 'G-A', 'verdict': 'PASS'}, {'id': 'G-B', 'verdict': 'FAIL'}, {'id': 'G-C', 'verdict': 'PASS'}]
def show(name, tr, prev='live_eval_2026-11-02.md'):
    print(name, tr['status'], '|', L.render_transitions_line(tr, prev))
show('T1', L.transitions(rows, {'G-A': 'PASS', 'G-B': 'PASS', 'G-C': 'PASS'}))
show('T2', L.transitions(rows, {'G-A': 'PASS', 'G-B': 'FAIL', 'G-C': 'PASS'}))
show('T3', L.transitions(rows, {'G-A': 'PASS', 'G-B': 'FAIL'}))
show('T4', L.transitions(rows, None), '')
show('T5', L.transitions(rows, {'G-A': 'FAIL', 'G-B': 'FAIL'}))
PY
)
rc=$?
pass=0; fail=0
lane() { if printf '%s\n' "$out" | grep -q -E "$2"; then echo "PASS $1"; pass=$((pass+1)); else echo "FAIL $1"; fail=$((fail+1)); fi; }
[ "$rc" = 0 ] || { echo "FAIL harness — python rc=$rc"; printf '%s\n' "$out"; exit 1; }
lane T1-flip-listed      '^T1 moved \| moved since previous \(live_eval_2026-11-02.md\): G-B PASS->FAIL$'
lane T2-identical-none   '^T2 none \| moved since previous \(live_eval_2026-11-02.md\): none$'
lane T3-narrower-not-none '^T3 not-comparable \| .*not comparable \(1 probes absent from previous\)$'
lane T4-no-prev          '^T4 not-supplied \| moved since previous: not supplied \(no prior report found\)$'
lane T5-flip-plus-absent '^T5 moved \| .*G-A FAIL->PASS  \(absent from previous: G-C\)$'
printf '%s\n' "$out" | sed 's/^/     /'
echo "live-eval transitions lanes: $pass pass · $fail fail"
[ "$fail" -eq 0 ]

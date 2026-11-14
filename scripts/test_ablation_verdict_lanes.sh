#!/usr/bin/env bash
# Lanes for ablation_verdict.py — known pairs with hand-checked Fisher tails.
#   V1 a real drop is DETECTED (3/3→0/3 p=1/20; 8/10→0/10) rc 0
#   V2 no drop with a live control → NOT-DETECTED@N + minimum detectable drop, rc 1, never «no loss»
#   V3 MDD values: N=3 → 100% · N=10 → 40%
#   V4 equal arms without control, or a dead control → INSTRUMENT-UNCONFIRMED rc 3 (never NOT-DETECTED)
#   V5 empty / short / malformed input → INPUT-ERROR rc 2 (never a pass)
#   V6 the self-dev queue's ABLATION_STEPS names the renderer and never tells the builder «No loss →»
#   V7 revert probe: a renderer that prints «no loss» on a null must turn V2 red (control on the lane itself)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; V="${ABLATION_VERDICT:-$HERE/ablation_verdict.py}"
pass=0; fail=0; ok(){ pass=$((pass+1)); echo "  ✅ $1"; }; bad(){ fail=$((fail+1)); echo "  ❌ $1"; }
run(){ out=$(python3 "$V" "$@" 2>&1); rc=$?; }

run --a 3/3 --b 0/3; [ $rc -eq 0 ] && [[ "$out" == DETECTED*p=0.0500* ]] && ok "V1 3/3→0/3 DETECTED p=0.05" || bad "V1 3/3→0/3: rc=$rc $out"
run --a 9/10 --b 1/10; [ $rc -eq 0 ] && [[ "$out" == *p=0.0005* ]] && ok "V1 9/10→1/10 DETECTED p=0.0005 (B>0)" || bad "V1 9/10→1/10: rc=$rc $out"
run --a 8/10 --b 10/10 --control 0/10; [ $rc -eq 1 ] && ok "V1 B above A is not a drop → NOT-DETECTED" || bad "V1 reverse: rc=$rc $out"
run --a 3/3 --b 0/3 --alpha 0.01; [ $rc -ne 0 ] && ok "V1 alpha=0.01: 3/3→0/3 (p=0.05) not DETECTED" || bad "V1 alpha: rc=$rc $out"
run --a 30/30 --b 0/30 --alpha 1e-20; [ $rc -ne 0 ] && ok "V1 alpha=1e-20: p≈8e-18 not DETECTED (no absolute slack)" || bad "V1 tiny alpha: rc=$rc $out"
run --a 8/10 --b 0/10; [ $rc -eq 0 ] && [[ "$out" == DETECTED* ]] && ok "V1 8/10→0/10 DETECTED" || bad "V1 8/10→0/10: rc=$rc $out"

v2(){ run --a 3/3 --b 3/3 --control 0/3
  [ $rc -eq 1 ] && [[ "$out" == NOT-DETECTED@N=3* ]] && [[ "$out" == *"Minimum detectable drop at N=3"* ]] \
    && ! printf '%s' "$out" | grep -qiE 'no loss|손실 없'; }
v2 && ok "V2 null → NOT-DETECTED@N=3 with MDD, no «no loss»" || bad "V2: rc=$rc $out"

run --a 3/3 --b 3/3 --control 0/3; [[ "$out" == *"alpha=0.05: 100%"* ]] && ok "V3 MDD N=3 = 100%" || bad "V3 N=3: $out"
run --a 10/10 --b 9/10 --control 0/10; [ $rc -eq 1 ] && [[ "$out" == *"alpha=0.05: 40%"* ]] && ok "V3 MDD N=10 = 40% (9/10 not detected)" || bad "V3 N=10: rc=$rc $out"

run --a 3/3 --b 3/3; [ $rc -eq 3 ] && [[ "$out" == INSTRUMENT-UNCONFIRMED* ]] && ok "V4 no control → INSTRUMENT-UNCONFIRMED" || bad "V4a: rc=$rc $out"
run --a 3/3 --b 3/3 --control 3/3; [ $rc -eq 3 ] && ok "V4 dead control → INSTRUMENT-UNCONFIRMED" || bad "V4b: rc=$rc $out"

for a in "--alpha oops --json" "" "--a 3/3" "--a 1/1 --b 0/1" "--a x --b 1/3" "--a 3/3 --b 2/4 --control 0/3" "--a 4/3 --b 0/3"; do
  set -f; set -- $a; set +f; out=$(python3 "$V" "$@" 2>&1); rc=$?
  [[ "$a" == *--json* ]] && out=$(printf '%s' "$out" | python3 -c 'import json,sys; print(json.load(sys.stdin)["line"])' 2>&1)
  [ $rc -eq 2 ] && [[ "$out" == INPUT-ERROR* ]] && ok "V5 «$a» → INPUT-ERROR" || bad "V5 «$a»: rc=$rc $out"
done

S=$(python3 -c "import sys; sys.path.insert(0,'$HERE'); import selfdev_queue as q; print(q.ABLATION_STEPS)")
# wording AND routing (codex R1: presence alone passes a swapped rc→action map)
printf '%s' "$S" | grep -q 'ablation_verdict.py' \
  && printf '%s' "$S" | grep -q 'NOT-DETECTED@N (rc 1) and no arm-B rep answered confidently and wrongly.*→ one deletion PR' \
  && printf '%s' "$S" | grep -q 'DETECTED (rc 0) → add a "* *KEEP\|DETECTED (rc 0) → add a' \
  && printf '%s' "$S" | grep -q 'INSTRUMENT-UNCONFIRMED (rc 3) or INPUT-ERROR (rc 2) → no PR' \
  && ! printf '%s' "$S" | grep -qi 'no loss →' \
  && ok "V6 ABLATION_STEPS routes rc 0/1/2/3 correctly, keeps step-6 override, no «No loss →»" || bad "V6 ABLATION_STEPS: $S"

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
sed 's/line="NOT-DETECTED@N=%d: /line="no loss — NOT-DETECTED@N=%d: /' "$V" > "$T/mut.py"
if grep -q 'no loss — NOT-DETECTED' "$T/mut.py"; then
  V="$T/mut.py"; v2; v2rc=$?
  # the mutant must RUN and fail V2 for the forbidden wording, not crash (codex R1)
  if [ $v2rc -ne 0 ] && [ $rc -eq 1 ] && printf '%s' "$out" | grep -q '^no loss — NOT-DETECTED@N=3'; then ok "V7 revert probe: mutant ran (rc 1) and V2 went red on «no loss»"
  else bad "V7 revert probe: v2rc=$v2rc rc=$rc out=$out"; fi
else bad "V7 mutation did not apply (instrument error, not a pass)"; fi

[ $pass -eq 20 ] || bad "lane count $pass != 20 — a case did not run"
echo "ablation_verdict lanes: $pass passed, $fail failed"; [ $fail -eq 0 ]

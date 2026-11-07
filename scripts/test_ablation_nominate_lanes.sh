#!/usr/bin/env bash
# Lanes for ablation_nominate.py — a probe table + verdict ledger with known answers.
#   N1 gate scopes, ledger KEEP and malformed cells are excluded and counted; the pick is one of the eligible
#   N2 same date → same pick; another date can pick another (rotation, not randomness)
#   N3 an UNCALIBRATED ledger row stays eligible (an undecided instrument is a reason to measure again)
#   N4 nothing eligible → rc 1 with the reason; an empty probe table → HARNESS-ERROR rc 2 (never «nothing to remove»)
#   N5 the self-dev queue carries the nominee as seed=ablation with the procedure line in its own row (never seed=human)
#   N6 a missing verdict ledger is HARNESS-ERROR (codex R1)
#   N7 heading prefix ends at a word boundary; a bare file name in two places is ambiguous (codex R2)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; N="$HERE/ablation_nominate.py"; Q="$HERE/selfdev_queue.py"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
pass=0; fail=0; ok(){ pass=$((pass+1)); echo "  ✅ $1"; }; bad(){ fail=$((fail+1)); echo "  ❌ $1"; }
R="$W/r"; mkdir -p "$R/.claude/regression"
printf '# rules\n## Alpha\na\n## Beta\nb\n## Gamma\ng\n## Kept Section\nk\n## Irreversibility Gates\ni\n## Delegated work\nd\n' > "$R/CLAUDE.md"   # sections must exist (dead pointers are excluded)
cat > "$R/.claude/regression/probes.md" <<'EOF'
| Probe ID | Input Pattern | Expected Behavior | Scope | Class |
|---|---|---|---|---|
| `P-1` | `a` | does a | CLAUDE.md §Alpha | mandatory-pass |
| `P-2` | `b` | does b | CLAUDE.md §Beta | mandatory-pass |
| `P-3` | `c` | does c | CLAUDE.md §Irreversibility Gates | mandatory-pass |
| `P-4` | `d` | does d | .claude/rules/fh_4axis_gate.md §Lightweight exception · hook | mandatory-pass |
| `P-5` | `e` | does e | CLAUDE.md §Kept Section | mandatory-pass |
| `P-6` | `f` | does f | CLAUDE.md §Gamma | mandatory-pass |
| `P-7` | `g` | does g | 🟥 **DEAD POINTER (corrected)** — gone | mandatory-pass |
| `P-8` | `h` | does h | missing.md §No such section | mandatory-pass |
| `P-9` | `i` | does i | CLAUDE.md §Delegated work | mandatory-pass |
EOF
cat > "$R/.claude/regression/ablation_verdicts.md" <<'EOF'
| Section (CLAUDE.md §) | Verdict | Instrument | Reps | Date | Basis |
|---|---|---|---|---|---|
| Kept Section | **KEEP** | x | 3 | 2026-01-01 | y |
| Gamma | **UNCALIBRATED** | x | — | 2026-01-01 | y |
EOF
j=$(python3 "$HERE/ablation_nominate.py" --repo "$R" --date 2026-11-07 --json); rc=$?
pick=$(printf '%s' "$j" | python3 -c 'import json,sys;print(json.load(sys.stdin)["nominated"])')
exc=$(printf '%s' "$j" | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d["eligible"],d["excluded"]["gate"],d["excluded"]["ledger"],d["excluded"]["malformed"])')
case "$pick" in "CLAUDE.md §Alpha"|"CLAUDE.md §Beta"|"CLAUDE.md §Gamma"|"CLAUDE.md §Delegated work") inpool=1 ;; *) inpool=0 ;; esac
[ $rc -eq 0 ] && [ "$exc" = "4 2 1 2" ] && [ $inpool = 1 ] && ok "N1 gates 2 · ledger KEEP 1 · malformed 2 (a correction note, a dead pointer) excluded; «Delegated work» is not a gate; the pick ($pick) is eligible" || bad "N1 rc=$rc exc=«$exc» pick=«$pick»"
p1=$(python3 "$HERE/ablation_nominate.py" --repo "$R" --date 2026-11-07 --json | python3 -c 'import json,sys;print(json.load(sys.stdin)["nominated"])')
seen=$(for d in 2026-11-07 2026-11-08 2026-11-09 2026-11-10; do python3 "$HERE/ablation_nominate.py" --repo "$R" --date $d --json | python3 -c 'import json,sys;print(json.load(sys.stdin)["nominated"])'; done | sort -u | wc -l | tr -d ' ')
[ "$p1" = "$pick" ] && [ "$seen" -eq 4 ] && ok "N2 same date → same pick; four dates → the four eligible sections" || bad "N2 p1=$p1 seen=$seen"
for d in 2026-11-07 2026-11-08 2026-11-09 2026-11-10; do python3 "$HERE/ablation_nominate.py" --repo "$R" --date $d --json; done | grep -q '"nominated": "CLAUDE.md §Gamma"' 
[ $? -eq 0 ] && ok "N3 an UNCALIBRATED row (Gamma) stays eligible" || bad "N3"
E="$W/e"; mkdir -p "$E/.claude/regression"; cp "$R/.claude/regression/ablation_verdicts.md" "$E/.claude/regression/"; head -2 "$R/.claude/regression/probes.md" > "$E/.claude/regression/probes.md"; sed -n 5,6p "$R/.claude/regression/probes.md" >> "$E/.claude/regression/probes.md"
o1=$(python3 "$HERE/ablation_nominate.py" --repo "$E" 2>&1); r1=$?; printf '| a | b |\n' > "$E/.claude/regression/probes.md"; o2=$(python3 "$HERE/ablation_nominate.py" --repo "$E" 2>&1); r2=$?
[ $r1 -eq 1 ] && printf '%s' "$o1" | grep -q 'no eligible section' && [ $r2 -eq 2 ] && printf '%s' "$o2" | grep -q '^HARNESS-ERROR' && ok "N4 nothing eligible → rc 1 with the reason; no probe rows → HARNESS-ERROR rc 2" || bad "N4 r1=$r1 r2=$r2"
mkdir -p "$R/tracks/_meta"; q=$(python3 "$Q" --live "$R" --date 2026-11-07 2>&1)
printf '%s\n' "$q" | grep -qF "[seed=ablation] (ablation:2026-11-07) test removing «$pick»" && printf '%s\n' "$q" | grep -qF 'never auto-merged' && ! printf '%s\n' "$q" | grep -F 'ablation:' | grep -q 'seed=human' \
  && printf '%s\n' "$q" | awk '/\[seed=ablation\]/{f=1;next} /^- \[seed=/{f=0} f' | grep -qF 'procedure = scripts/probe_scope_check.sh header steps 1-7' \
  && ok "N5 the queue carries the nominee as seed=ablation with the procedure line in its own row (never seed=human)" || { bad "N5"; printf '%s\n' "$q" | sed -n '/ablation/,+3p' | sed 's/^/     /'; }
# N6 codex R1: a missing verdict ledger is HARNESS-ERROR rc 2 — never «nothing measured yet, nominate anything»
G="$W/g"; mkdir -p "$G/.claude/regression"; cp "$R/CLAUDE.md" "$G/"; cp "$R/.claude/regression/probes.md" "$G/.claude/regression/"
o6=$(python3 "$HERE/ablation_nominate.py" --repo "$G" 2>&1); r6=$?
[ $r6 -eq 2 ] && printf '%s' "$o6" | grep -q 'verdict ledger unreadable' && ok "N6 a missing verdict ledger is HARNESS-ERROR rc 2" || bad "N6 r6=$r6"
# N7 codex R2: «§Alpha» does not resolve against «## Alphabet» (word boundary); a bare file name found in TWO places
# is ambiguous, not resolved; one place resolves.
H="$W/h"; mkdir -p "$H/.claude/regression" "$H/a" "$H/b" "$H/c"; cp "$R/.claude/regression/ablation_verdicts.md" "$H/.claude/regression/"
printf '## Alphabet\nx\n' > "$H/CLAUDE.md"; printf '## Twin\nx\n' > "$H/a/two.md"; printf '## Twin\nx\n' > "$H/b/two.md"; printf '## Solo\nx\n' > "$H/c/one.md"
printf '| Probe ID | Input | Expected | Scope | Class |\n|---|---|---|---|---|\n| `Q-1` | `a` | a | CLAUDE.md §Alpha | m |\n| `Q-2` | `b` | b | two.md §Twin | m |\n| `Q-3` | `c` | c | one.md §Solo | m |\n' > "$H/.claude/regression/probes.md"
j7=$(python3 "$HERE/ablation_nominate.py" --repo "$H" --json); e7=$(printf '%s' "$j7" | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d["eligible"],d["excluded"]["malformed"],d["nominated"])')
[ "$e7" = "1 2 one.md §Solo" ] && ok "N7 «Alpha» ≠ «Alphabet»; a file name in two places is ambiguous; one place resolves" || bad "N7 got «$e7»"
[ $((pass+fail)) -eq 7 ] || { echo "HARNESS-ERROR: counted $((pass+fail)) lanes, expected 7"; exit 2; }
echo "ablation_nominate lanes: $pass passed · $fail failed"; [ "$fail" -eq 0 ]

#!/usr/bin/env bash
# test_paper_integrity_lanes.sh — known pairs + revert probes for the three paper-integrity instruments:
#     scripts/citation_key_check.py   ① every cited key is defined / every defined key is cited (+ NEAR-MISS)
#     scripts/numeric_token_diff.py   ② a rewrite dropped or invented a number
#     scripts/section_ref_check.py    ③ every §N / 부록 N / Appendix X / K.n ref resolves to a heading
#
# WHY ONE SUITE FOR THREE SUBJECTS
#   They are one job — «is the paper's own machinery consistent with itself» — and landed as one change
#   (2026-09-17, the night the sister paper was rejected by arXiv for 11/17 reference mismatches and the
#   governor ran all three checks by hand). selfcheck.sh pairs on ONE key subject (citation_key_check.py);
#   this suite asserts the other two exist itself — their absence beside a present key is a FAIL, not a
#   skip, because a package that ships one third of the instrument is not «package mode».
#
# FIXTURE SHAPE FROM THE ARTIFACT, NOT A MENTAL MODEL: the citation forms (`[C70, EW10, T24]` grouped ·
# `[MF24]` vs `[MF22]` · a code-span mention `[OCR26]`), the numeric forms (`p<0.001` · `12/12` · `2,880`
# · `92.6 %` · `≈2.1 %`) and the heading forms (`### 2.3b …` · `### §3.3-b …` · `### 부록 8 —` ·
# `## Appendix K` · `### K.2 …`) are copied from the 2026-09-17 draft and its prior-art section.
# 🟥 [EBP18] and [MF24] appear here as KNOWN-POSITIVES — they are the two defects measured that night.
#
# THE TWO-SIGNALS RULE: every known-negative asserts that the instrument SAW something (usages > 0,
# tokens > 0, refs > 0) as well as that it found nothing; every dead control asserts rc=4, never 0.
#
# REVERT PROBES (L5 · L10 · L14): the discriminating rule of each subject is disabled in a COPIED file by
# source edit (not by flag, so the DEFAULT code path is what carries the load), the arm that depends on
# that rule must go RED, a control arm must stay GREEN under the same mutant, and the original is
# byte-compared before and after. The flag form (L5b · L10b · L14b) repeats each through the CLI.
#
# 🟥 PITFALL (this repo's lanes): `out="$(run …)"` runs the function in a SUBSHELL, so `RC=$?` after it is
#   the assignment's status, not the tool's. Every lane redirects to a file and reads `$?` directly.
#   No `cmd | grep -q` (SIGPIPE under pipefail), and NO BACKTICKS INSIDE DOUBLE-QUOTED MESSAGES — a lane
#   message quoting a token in backticks EXECUTES it (measured 2026-09-17: a message ran 2.7 as a command).
#
# Usage:  bash scripts/test_paper_integrity_lanes.sh        (PATH=<interp-dir>:$PATH to pin an interpreter)
# Exit:   0 = every lane passed · 1 = a lane failed (or a subject is missing / the instrument broke)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CIT="$HERE/citation_key_check.py"
NUM="$HERE/numeric_token_diff.py"
SEC="$HERE/section_ref_check.py"
PY=python3   # literal on purpose: new_code_anchor_check.sh reads a literal invoker — a "$PY" invoker scored MENTION_ONLY on CI (PR #748). Override the interpreter with PATH, not a variable
pass=0; fail=0
ok(){ pass=$((pass+1)); printf '  ✅ PASS %s\n' "$1"; }
no(){ fail=$((fail+1)); printf '  ❌ FAIL %s — %s\n' "$1" "${2:-}"; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

# run <outfile> <subject> <args…>  — sets RC (global). Never call inside $( ).
RC=0
run(){ local out="$1" subj="$2"; shift 2; python3 "$subj" "$@" >"$out" 2>&1; RC=$?; }
# Per-subject wrappers. The anchor gate resolves `VAR="…/file.py"` + `python3 "$VAR"` (reaching definition); a subject
# passed through a function PARAMETER is unreadable to it, so each shipped subject is invoked through its own
# variable at least once. run() stays for mutant copies and loops.
cit(){ local out="$1"; shift; python3 "$CIT" "$@" >"$out" 2>&1; RC=$?; }
num(){ local out="$1"; shift; python3 "$NUM" "$@" >"$out" 2>&1; RC=$?; }
sec(){ local out="$1"; shift; python3 "$SEC" "$@" >"$out" 2>&1; RC=$?; }
has(){ grep -q -- "$2" "$1"; }                              # has <file> <needle>   (fixed-ish BRE)
hasre(){ grep -Eq -- "$2" "$1"; }                           # hasre <file> <ERE>    (column-padded rows)
cnt(){ grep -c -- "$2" "$1"; }                              # prints 0 when none (grep rc ignored)
cntre(){ grep -Ec -- "$2" "$1"; }                           # ERE count (in BRE a bare + is literal)
dump(){ sed 's/^/     | /' "$1" | head -"${2:-12}"; }

echo "── test_paper_integrity_lanes ──  ($("$PY" --version 2>&1))"

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# L0 — this suite parses under stock bash 3.2 AND, when present, homebrew bash 5.x (a heredoc inside
#      a command substitution is read differently by the two — the class this lane exists for)
# ═══════════════════════════════════════════════════════════════════════════════════════════════
if /bin/bash -n "${BASH_SOURCE[0]}" >"$T/l0a.txt" 2>&1; then ok "L0a bash -n under /bin/bash ($(/bin/bash --version | head -1 | sed 's/GNU bash, version //; s/(.*//'))"; else no "L0a bash -n under /bin/bash" "$(head -2 "$T/l0a.txt")"; fi
if [ -x /opt/homebrew/bin/bash ]; then
  if /opt/homebrew/bin/bash -n "${BASH_SOURCE[0]}" >"$T/l0b.txt" 2>&1; then ok "L0b bash -n under /opt/homebrew/bin/bash ($(/opt/homebrew/bin/bash --version | head -1 | sed 's/GNU bash, version //; s/(.*//'))"; else no "L0b bash -n under homebrew bash" "$(head -2 "$T/l0b.txt")"; fi
else
  echo "  ⬜ SKIP L0b homebrew bash not installed (not a pass — only the 3.2 arm was measured)"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# L1 — subjects present (the two non-key subjects are asserted HERE, by design) · syntax · --help
# ═══════════════════════════════════════════════════════════════════════════════════════════════
[ -f "$CIT" ] || { no "L1 key subject present" "$CIT missing (HARNESS-ERROR — nothing below was measured)"; echo "── $pass passed, $fail failed ──"; exit 1; }
for s in "$NUM" "$SEC"; do
  [ -f "$s" ] && ok "L1 subject present: $(basename "$s") (paired through this suite, not through selfcheck)" \
              || no "L1 subject present" "$(basename "$s") missing beside a present citation_key_check.py — a third of the instrument is gone, not package mode"
done
for s in "$CIT" "$NUM" "$SEC"; do
  [ -f "$s" ] || continue
  "$PY" -c "import ast,sys;ast.parse(open(sys.argv[1],encoding='utf-8').read())" "$s" >"$T/l1s.txt" 2>&1 \
    && ok "L1 syntax (ast.parse) $(basename "$s")" || no "L1 syntax $(basename "$s")" "$(head -3 "$T/l1s.txt")"
  run "$T/l1h.txt" "$s" --help
  if [ "$RC" -eq 0 ] && has "$T/l1h.txt" "EXIT CODES" && has "$T/l1h.txt" "DEAD CONTROL" && has "$T/l1h.txt" "WHAT IT DOES NOT DO"; then
    ok "L1 --help $(basename "$s"): rc=0, names the rc contract, the dead control and its scope limits"
  else
    no "L1 --help $(basename "$s")" "rc=$RC"
  fi
done

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# FIXTURES ① — citation keys. POS = the draft as it stood on 2026-09-17 before the two fixes.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
mkdir -p "$T/c"
cat > "$T/c/refs.md" <<'EOF'
## 참고문헌 (이 절이 추가하는 것 · 확인 상태 포함)

| 키 | 서지 | 확인 |
|---|---|---|
| [C70] | Chow, C. K. "On Optimum Recognition Error and Reject Tradeoff." *IEEE Trans. Inf. Theory* **16**(1):41–46, 1970 | ✅ |
| [EW10] | El-Yaniv, R. & Wiener, Y. "On the Foundations of Noise-free Selective Classification." *JMLR* **11**, 2010 | ✅ |
| [T24] | Traub, J. et al. "Overcoming Common Flaws in the Evaluation of Selective Classification Systems." arXiv:2407.01032, 2024 | ✅ |
| [MF22] | Mökander, J. & Floridi, L. "Operationalising AI Governance through Ethics-Based Auditing." *AI and Ethics* **3**(2):451–468, 2022 | ✅ |
| [OCR26] | Alibaba. *Open Code Review* (Apache-2.0), commit `8d57bc9e` | ✅ |
| **[G75]** | Goodhart, C. (1975) | 🟡 |
EOF
cat > "$T/c/body_pos.md" <<'EOF'
# 2회 패스는 깎지 않는다

## 1. 문제
커버리지 동시보고 [C70, EW10, T24] · 조직 감사 실증 [MF24]. 사람을 종단에 두는 것 [EBP18].

## 9. 기여
### 9.4 수치는 표면을 사지 못한다
이견 시 사람에게 에스컬레이션한다 [EBP18]. 비대칭 하위 논증은 여기서 다루지 않는다: `[OCR26]` 은 코드 언급이지 인용이 아니다.

## 인용 검증
| 인용 | 검증 |
|---|---|
| 팬텀 | `[EBP18]` 이 본문 §9.4 를 떠받치는데 서지표에 줄이 없었다 |
```
[G75] inside a fence is a mention too
```
EOF
cat > "$T/c/body_neg.md" <<'EOF'
## 1. 문제
커버리지 동시보고 [C70, EW10, T24] · 조직 감사 실증 [MF22] · Goodhart [G75] · 도구 [OCR26].
EOF
cat > "$T/c/body_orphan_only.md" <<'EOF'
## 1. 문제
커버리지 동시보고 [C70, EW10, T24] · 조직 감사 실증 [MF22] · 도구 [OCR26].
EOF
cat > "$T/c/body_dead.md" <<'EOF'
## 1. 문제
No citations here: a checkbox [x], a footnote [^1], a numeric [1], a word [TODO], a code `[C70]` mention only.
EOF
cat > "$T/c/refs_listy.md" <<'EOF'
## References
- [C70] Chow 1970 — a LIST, not the house table
- [EW10] El-Yaniv 2010
EOF

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# L2 — ① known-POSITIVE: rc=1 · PHANTOM [EBP18] ×2 with both lines · PHANTOM [MF24] · ORPHAN [MF22]
#      · NEAR-MISS [MF22]↔[MF24] · grouped [C70, EW10, T24] counted (T24 is NOT an orphan) · the
#      code-span [OCR26] and the fenced [G75] are MENTIONS (both keys orphan, «mentioned» noted)
# ═══════════════════════════════════════════════════════════════════════════════════════════════
cit "$T/l2.txt" --body "$T/c/body_pos.md" --refs "$T/c/refs.md"
if [ "$RC" -eq 1 ] \
   && has "$T/l2.txt" '(6 usages · 5 distinct keys)' && has "$T/l2.txt" 'mentions in code=3' \
   && has "$T/l2.txt" 'PHANTOM    \[EBP18\]  used ×2 — body_pos.md:4 · body_pos.md:8' \
   && has "$T/l2.txt" 'PHANTOM    \[MF24\]  used ×1 — body_pos.md:4' \
   && has "$T/l2.txt" 'ORPHAN     \[MF22\]  defined refs.md:8, used ×0' \
   && has "$T/l2.txt" 'NEAR-MISS  \[MF22\] (ORPHAN · defined refs.md:8) ↔ \[MF24\] (PHANTOM · used ×1)' \
   && ! has "$T/l2.txt" 'ORPHAN     \[T24\]' \
   && has "$T/l2.txt" 'ORPHAN     \[OCR26\]  defined refs.md:9, used ×0 (mentioned ×1 in code: body_pos.md:8)' \
   && has "$T/l2.txt" 'ORPHAN     \[G75\]  defined refs.md:10, used ×0 (mentioned ×1 in code: body_pos.md:15)' \
   && has "$T/l2.txt" 'citation-key verdict: PHANTOM=2 ORPHAN=3 NEAR-MISS=1 DUP-DEF=0 MENTION-ONLY=0 MALFORMED=0 rc=1'; then
  ok "L2 ① known-positive: rc=1 — PHANTOM EBP18 (2 sites named) + MF24, ORPHAN MF22, NEAR-MISS MF22↔MF24, grouped keys counted, code/fence keys are mentions"
else
  no "L2 ① known-positive" "rc=$RC"; dump "$T/l2.txt" 16
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# L3 — ① known-NEGATIVE: every used key defined, every defined key used → rc=0 AND usages seen (>0)
# ═══════════════════════════════════════════════════════════════════════════════════════════════
cit "$T/l3.txt" --body "$T/c/body_neg.md" --refs "$T/c/refs.md"
if [ "$RC" -eq 0 ] && has "$T/l3.txt" '(6 usages · 6 distinct keys)' \
   && has "$T/l3.txt" 'citation-key verdict: PHANTOM=0 ORPHAN=0 NEAR-MISS=0 DUP-DEF=0 MENTION-ONLY=0 MALFORMED=0 rc=0'; then
  ok "L3 ① known-negative: rc=0 with 6 usages SEEN (two-signals: not a dead control)"
else
  no "L3 ① known-negative" "rc=$RC"; dump "$T/l3.txt"
fi
cit "$T/l3b.txt" --body "$T/c/body_orphan_only.md" --refs "$T/c/refs.md"
RCA=$RC
cit "$T/l3c.txt" --body "$T/c/body_orphan_only.md" --refs "$T/c/refs.md" --strict-orphans
if [ "$RCA" -eq 0 ] && has "$T/l3b.txt" 'ORPHAN     \[G75\]' && has "$T/l3b.txt" 'ORPHAN keys are listed, not counted' \
   && [ "$RC" -eq 2 ] && has "$T/l3c.txt" 'ORPHAN=1 NEAR-MISS=0 DUP-DEF=0 MENTION-ONLY=0 MALFORMED=0 rc=2'; then
  ok "L3b ① orphan-only: listed at rc=0 by default, rc=2 under --strict-orphans (distinct from rc=1 phantom)"
else
  no "L3b ① orphan-only / --strict-orphans" "default rc=$RCA strict rc=$RC"; dump "$T/l3c.txt"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# L4 — ① DEAD CONTROL: a body with brackets but no citation keys → rc=4, never 0; a code-only mention
#      does not rescue it. L4b: a list-shaped bibliography → rc=10 (0 definition rows), never «all phantom».
# ═══════════════════════════════════════════════════════════════════════════════════════════════
cit "$T/l4.txt" --body "$T/c/body_dead.md" --refs "$T/c/refs.md"
if [ "$RC" -eq 4 ] && has "$T/l4.txt" 'DEAD CONTROL' && has "$T/l4.txt" '1 mention(s) in code spans not counted' && ! has "$T/l4.txt" 'citation-key verdict'; then
  ok "L4 ① dead control: 0 usages → rc=4 with DEAD CONTROL banner (mention counted separately, no verdict line)"
else
  no "L4 ① dead control" "rc=$RC"; dump "$T/l4.txt" 4
fi
cit "$T/l4b.txt" --body "$T/c/body_neg.md" --refs "$T/c/refs_listy.md"
if [ "$RC" -eq 10 ] && has "$T/l4b.txt" '0 definition rows parsed' && has "$T/l4b.txt" 'NOT reported as phantom'; then
  ok "L4b ① list-shaped refs → rc=10 (instrument cannot see the table; usages NOT rendered as phantom)"
else
  no "L4b ① list-shaped refs" "rc=$RC"; dump "$T/l4b.txt" 4
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# L5 — 🟥 ① REVERT PROBE: NEAR-MISS pairing disabled in a COPY by source edit → L2's arm goes RED
#      (NEAR-MISS=0 while PHANTOM/ORPHAN unchanged); L3's arm stays GREEN under the same mutant;
#      the original is byte-identical before and after.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
mutate(){   # mutate <src> <dst> <attr> [<python literal, default True>]  → inserts `args.<attr> = <literal>` after the unique parse_args line
  cp "$1" "$2"
  "$PY" - "$2" "$3" "${4:-True}" >"$T/mut.txt" 2>&1 <<'PY'
import sys
p, attr, val = sys.argv[1], sys.argv[2], sys.argv[3]
L = open(p, encoding="utf-8").read().split("\n")
idx = [k for k, l in enumerate(L) if l.strip() == "args = ap.parse_args()"]
assert len(idx) == 1, "mutation anchor not found exactly once: %r" % idx
L.insert(idx[0] + 1, "    args.%s = %s  # MUTANT: %s forced to %s" % (attr, val, attr, val))
open(p, "w", encoding="utf-8").write("\n".join(L))
PY
}
cp "$CIT" "$T/cit_snapshot.py"
mutate "$CIT" "$T/cit_mutant.py" no_near_miss
if [ $? -ne 0 ] || [ "$(cnt "$T/cit_mutant.py" 'MUTANT: no_near_miss')" -ne 1 ]; then
  no "L5 ① revert probe (instrument)" "mutation did not apply: $(head -2 "$T/mut.txt")"
else
  run "$T/l5m.txt" "$T/cit_mutant.py" --body "$T/c/body_pos.md" --refs "$T/c/refs.md"; MRC=$RC
  run "$T/l5c.txt" "$T/cit_mutant.py" --body "$T/c/body_neg.md" --refs "$T/c/refs.md"; CRC=$RC
  cit "$T/l5o.txt" --body "$T/c/body_pos.md" --refs "$T/c/refs.md"; ORC=$RC
  if cmp -s "$CIT" "$T/cit_snapshot.py"; then UNTOUCHED=yes; else UNTOUCHED=no; fi
  if [ "$MRC" -eq 1 ] && has "$T/l5m.txt" 'near-miss=off' && ! has "$T/l5m.txt" 'NEAR-MISS  \[' \
     && has "$T/l5m.txt" 'PHANTOM=2 ORPHAN=3 NEAR-MISS=0' \
     && [ "$CRC" -eq 0 ] && has "$T/l5c.txt" 'rc=0' \
     && [ "$ORC" -eq 1 ] && has "$T/l5o.txt" 'NEAR-MISS=1' && [ "$UNTOUCHED" = yes ]; then
    ok "L5 ① revert probe: near-miss OFF in a copy → known-positive loses its NEAR-MISS (RED); known-negative still rc=0 (control GREEN); original untouched, still NEAR-MISS=1"
  else
    no "L5 ① revert probe" "mutant rc=$MRC · control rc=$CRC · original rc=$ORC untouched=$UNTOUCHED"; dump "$T/l5m.txt" 12
  fi
fi
cit "$T/l5b.txt" --body "$T/c/body_pos.md" --refs "$T/c/refs.md" --no-near-miss
if [ "$RC" -eq 1 ] && ! has "$T/l5b.txt" 'NEAR-MISS  \[' && has "$T/l5b.txt" 'NEAR-MISS=0'; then
  ok "L5b ① same through the flag: --no-near-miss → NEAR-MISS=0 on the known-positive"
else
  no "L5b ① --no-near-miss" "rc=$RC"
fi
cit "$T/l5d.txt" --body "$T/c/body_pos.md" --refs "$T/c/refs.md" --count-code
if [ "$RC" -eq 1 ] && ! has "$T/l5d.txt" 'ORPHAN     \[OCR26\]' && ! has "$T/l5d.txt" 'ORPHAN     \[G75\]' && has "$T/l5d.txt" 'ORPHAN=1 '; then
  ok "L5c ① --count-code: the code-span and fenced keys become usages (OCR26 and G75 no longer orphan; only MF22 remains)"
else
  no "L5c ① --count-code" "rc=$RC"; dump "$T/l5d.txt"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# FIXTURES ② — numeric tokens, forms copied from the draft
# ═══════════════════════════════════════════════════════════════════════════════════════════════
mkdir -p "$T/n"
cat > "$T/n/before.md" <<'EOF'
## 3. 결과
### 3.1 런 내부 대조
O 의 판정률 92.6 % 라는 단독 값. 커버리지 열의 p<0.001 은 두 계기 비교라 철회 대상이다.
클러스터 보정 뒤 95 % 상한 ≈2.1 % 이고, 완성짝 12/12 (n=6) 에서 12/12 였다.
2,880 시나리오 · 사전등록 2026-09-12 · 오류율 2.7 % 로 재보고.
EOF
cat > "$T/n/after.md" <<'EOF'
## 3. 결과
### 3.1 런 내부 대조
O 의 판정률 92.6 % 라는 단독 값. 커버리지 열은 두 계기 비교라 철회했다.
클러스터 보정 뒤 95 % 상한 ≈2.1 % 이고, 완성짝 11/12 (n=6) 에서 12/12 였다.
2880 시나리오 · 사전등록 2026-09-12 · 오류율 0.9 % 로 재보고.
EOF
cat > "$T/n/reflow.md" <<'EOF'
## 3. 결과
### 3.1 런 내부 대조 (재배치)
오류율 2.7 % 로 재보고. 2,880 시나리오. 사전등록 2026-09-12.
완성짝 12/12 (n=6) 에서 12/12 였고, 클러스터 보정 뒤 95 % 상한 ≈2.1 % 이다.
커버리지 열의 p<0.001 은 두 계기 비교라 철회 대상이다. O 의 판정률 92.6 % 라는 단독 값.
EOF
cat > "$T/n/invent.md" <<'EOF'
## 3. 결과
### 3.1 런 내부 대조
O 의 판정률 92.6 % 라는 단독 값. 커버리지 열의 p<0.001 은 두 계기 비교라 철회 대상이다.
클러스터 보정 뒤 95 % 상한 ≈2.1 % 이고, 완성짝 12/12 (n=6) 에서 12/12 였다.
2,880 시나리오 · 사전등록 2026-09-12 · 오류율 2.7 % 로 재보고. 새 수치: p=0.019.
EOF
cat > "$T/n/dead_a.md" <<'EOF'
## 결론
No digits at all in this file — words only, §-free, table-free.
EOF
cat > "$T/n/dead_b.md" <<'EOF'
## 결론
Still no digits. Nothing to compare on either side.
EOF
cat > "$T/n/bnd_before.md" <<'EOF'
Rate 2.7 % on 12/12 cases; the value 2.75 was separate, and 12.7 % belonged to another arm. DOI `10.1007/s43681-022-00171-7`; sealed in PREREG_ADDENDUM_2026-09-10.md.
EOF
cat > "$T/n/bnd_after.md" <<'EOF'
Rate 2.7 % on 12/12 cases (release 2.7.1, build 12.7.3; see A.6.2.7 and §3.1–3.2 and 부록 8 and K.2 and Sec. 9.4 and Section 12 and 섹션 8.1 and 3.2절; A-6 sealed, GHSA-2026-1234); the value 2.75 was separate, and 12.7 % belonged to another arm. DOI `10.1007/s43681-022-00171-7`; sealed in PREREG_ADDENDUM_2026-09-10.md.
EOF
# MAJOR-1 (cross-family, codex, 2026-09-17): a pure-digit hyphen RANGE must keep both ends.
printf 'range 12-25 only; and 40-75 too; a chain GHSA-2026-1234 and A-6 stay out.\n' > "$T/n/hy_before.md"
printf 'range 12 only; and 40-75 too; a chain GHSA-2026-1234 and A-6 stay out.\n'    > "$T/n/hy_after.md"
printf '# allow — every line must carry a reason\np<0.001\tretracted in §3.1 (two instruments compared)\n2.7%%\treplaced by 0.9%% after the re-scoring\n12/12\tone completed pair was withdrawn\n' > "$T/n/allow_ok.tsv"
printf 'p<0.001\tretracted in §3.1\n2.7%%\treplaced by 0.9%%\n12/12\tone pair withdrawn\n0.9%%\tthe re-scored rate\n11/12\tafter the withdrawal\n99.9%%\tstale entry — no such difference\n' > "$T/n/allow_all.tsv"
printf 'p<0.001\tretracted\n2.7%%\n' > "$T/n/allow_bare.tsv"

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# L2c — 🟥 ① MALFORMED (codex round 2, 2026-09-18): `[BAD–26]` (EN dash) · `[MF-22]` (hyphen) · `[GE_17]`
#       (underscore) are citation-shaped keys no row can match, and v2 read the file as CLEAN (rc=0).
#       Also pinned: a full-width `［OK26］` is a usage (NFKC); a malformed key inside a code span is text.
#       L5d/L5e are the revert probe (source mutant / flag).
# ═══════════════════════════════════════════════════════════════════════════════════════════════
cat > "$T/c/body_malformed.md" <<'EOF'
# body
Valid [OK26] and full-width ［OK26］; malformed [BAD–26] and [MF-22] and [GE_17]; in code `[ZZ–99]` is text.

| [OK26] | a defined row |
EOF
cit "$T/l2c.txt" --body "$T/c/body_malformed.md"
if [ "$RC" -eq 1 ] && has "$T/l2c.txt" 'MALFORMED  \[BAD–26\]' && has "$T/l2c.txt" 'MALFORMED  \[MF-22\]' && has "$T/l2c.txt" 'MALFORMED  \[GE_17\]' \
   && ! has "$T/l2c.txt" 'MALFORMED  \[ZZ–99\]' && has "$T/l2c.txt" '(2 usages · 1 distinct keys)' \
   && has "$T/l2c.txt" 'PHANTOM=0 ORPHAN=0 NEAR-MISS=0 DUP-DEF=0 MENTION-ONLY=0 MALFORMED=3 rc=1'; then
  ok "L2c ① MALFORMED known-positive: [BAD–26] / [MF-22] / [GE_17] reported and counted (rc=1); ［OK26］ counts as a usage (NFKC); the code-span [ZZ–99] is not reported"
else
  no "L2c ① MALFORMED known-positive" "rc=$RC"; dump "$T/l2c.txt" 10
fi
cp "$CIT" "$T/cit_snapshot3.py"
mutate "$CIT" "$T/cit_mutant_mal.py" no_malformed
if [ $? -ne 0 ] || [ "$(cnt "$T/cit_mutant_mal.py" 'MUTANT: no_malformed')" -ne 1 ]; then
  no "L5d ① revert probe MALFORMED (instrument)" "mutation did not apply: $(head -2 "$T/mut.txt")"
else
  run "$T/l5dm.txt" "$T/cit_mutant_mal.py" --body "$T/c/body_malformed.md"; MRC=$RC
  run "$T/l5dc.txt" "$T/cit_mutant_mal.py" --body "$T/c/body_neg.md" --refs "$T/c/refs.md"; CRC=$RC
  cit "$T/l5do.txt" --body "$T/c/body_malformed.md"; ORC=$RC
  if cmp -s "$CIT" "$T/cit_snapshot3.py"; then UNTOUCHED=yes; else UNTOUCHED=no; fi
  if [ "$MRC" -eq 0 ] && has "$T/l5dm.txt" 'malformed=off (ABLATION)' && has "$T/l5dm.txt" 'MALFORMED=0 rc=0' && ! has "$T/l5dm.txt" 'MALFORMED  \[' \
     && [ "$CRC" -eq 0 ] && [ "$ORC" -eq 1 ] && has "$T/l5do.txt" 'MALFORMED=3 rc=1' && [ "$UNTOUCHED" = yes ]; then
    ok "L5d ① revert probe MALFORMED: skipped in a copy → L2c's file reads CLEAN (rc=0 — the silent v2 arm) while L3 stays GREEN; original untouched, still MALFORMED=3"
  else
    no "L5d ① revert probe MALFORMED" "mutant rc=$MRC · control rc=$CRC · original rc=$ORC untouched=$UNTOUCHED"; dump "$T/l5dm.txt" 8
  fi
fi
cit "$T/l5e.txt" --body "$T/c/body_malformed.md" --no-malformed
if [ "$RC" -eq 0 ] && has "$T/l5e.txt" 'malformed=off (ABLATION)' && has "$T/l5e.txt" 'MALFORMED=0 rc=0'; then
  ok "L5e ① same through the flag: --no-malformed reproduces the v2 silent arm (rc=0)"
else
  no "L5e ① --no-malformed" "rc=$RC"; dump "$T/l5e.txt" 6
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# L6 — ② known-POSITIVE: rc=1 · DROPPED p<0.001 · DROPPED 2.7% · REDUCED 12/12 (×2→×1) · INVENTED 0.9%
#      · INVENTED 11/12 · 2,880≡2880 (not reported) · 92.6% / 2.1% / n=6 / date stable · first sites named
# ═══════════════════════════════════════════════════════════════════════════════════════════════
num "$T/l6.txt" --before "$T/n/before.md" --after "$T/n/after.md"
if [ "$RC" -eq 1 ] \
   && has "$T/l6.txt" 'before=1 file (6 lines · 10 tokens · 9 distinct) · after=1 file (6 lines · 9 tokens · 9 distinct)' \
   && hasre "$T/l6.txt" 'DROPPED +p<0\.001 +before ×1 +→ after ×0 +before\.md:3:' \
   && hasre "$T/l6.txt" 'DROPPED +2\.7% +before ×1 +→ after ×0 +before\.md:5:' \
   && hasre "$T/l6.txt" 'REDUCED +12/12 +before ×2 +→ after ×1 +before\.md:4:' \
   && hasre "$T/l6.txt" 'INVENTED +0\.9% +before ×0 +→ after ×1 +after\.md:5:' \
   && hasre "$T/l6.txt" 'INVENTED +11/12 +before ×0 +→ after ×1 +after\.md:4:' \
   && ! hasre "$T/l6.txt" '(DROPPED|REDUCED|INVENTED|INCREASED) +2880 ' \
   && has "$T/l6.txt" 'numeric-diff verdict: DROPPED=2 REDUCED=1 INVENTED=2 INCREASED=0 ALLOWED=0 rc=1'; then
  ok "L6 ② known-positive: rc=1 — DROPPED p<0.001 + 2.7%, REDUCED 12/12, INVENTED 0.9% + 11/12, sites named, 2,880≡2880 stable"
else
  no "L6 ② known-positive" "rc=$RC"; dump "$T/l6.txt" 14
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# L7 — ② known-NEGATIVE: identity and a re-flowed rewrite (same numbers, new prose order) → rc=0 AND
#      tokens seen; invented-only → rc=2; --allow with reasons; --distinct hides REDUCED
# ═══════════════════════════════════════════════════════════════════════════════════════════════
num "$T/l7.txt" --before "$T/n/before.md" --after "$T/n/before.md"; RCA=$RC
num "$T/l7r.txt" --before "$T/n/before.md" --after "$T/n/reflow.md"
if [ "$RCA" -eq 0 ] && has "$T/l7.txt" 'IDENTICAL numeric multisets — 10 tokens (9 distinct)' \
   && [ "$RC" -eq 0 ] && has "$T/l7r.txt" 'IDENTICAL numeric multisets — 10 tokens (9 distinct)' \
   && has "$T/l7r.txt" 'numeric-diff verdict: DROPPED=0 REDUCED=0 INVENTED=0 INCREASED=0 ALLOWED=0 rc=0'; then
  ok "L7 ② known-negative: identity rc=0 AND a re-flowed rewrite rc=0, both with 10 tokens SEEN (two-signals)"
else
  no "L7 ② known-negative" "identity rc=$RCA reflow rc=$RC"; dump "$T/l7r.txt"
fi
num "$T/l7b.txt" --before "$T/n/before.md" --after "$T/n/invent.md"
if [ "$RC" -eq 2 ] && has "$T/l7b.txt" 'INVENTED  p=0.019' && has "$T/l7b.txt" 'DROPPED=0 REDUCED=0 INVENTED=1 INCREASED=0 ALLOWED=0 rc=2'; then
  ok "L7b ② invented-only → rc=2 (INVENTED p=0.019), distinct from rc=1"
else
  no "L7b ② invented-only" "rc=$RC"; dump "$T/l7b.txt"
fi
num "$T/l7c.txt" --before "$T/n/before.md" --after "$T/n/after.md" --allow "$T/n/allow_ok.tsv"; RCA=$RC
num "$T/l7d.txt" --before "$T/n/before.md" --after "$T/n/after.md" --allow "$T/n/allow_all.tsv"; RCB=$RC
num "$T/l7e.txt" --before "$T/n/before.md" --after "$T/n/after.md" --allow "$T/n/allow_bare.tsv"
if [ "$RCA" -eq 2 ] && has "$T/l7c.txt" 'ALLOWED   p<0.001' && has "$T/l7c.txt" 'reason: retracted in §3.1' && has "$T/l7c.txt" 'ALLOWED=3 rc=2' \
   && [ "$RCB" -eq 0 ] && has "$T/l7d.txt" 'UNUSED-ALLOW 99.9%' && has "$T/l7d.txt" 'after 5 allowed difference(s)' \
   && [ "$RC" -eq 10 ] && has "$T/l7e.txt" 'bare token with no reason' && has "$T/l7e.txt" 'allow_bare.tsv:2'; then
  ok "L7c ② --allow: reasons printed, drops allowed → rc=2 (invented left), all allowed → rc=0 with UNUSED-ALLOW named; a bare token → rc=10 naming the line"
else
  no "L7c ② --allow" "ok rc=$RCA all rc=$RCB bare rc=$RC"; dump "$T/l7e.txt" 4
fi
num "$T/l7f.txt" --before "$T/n/before.md" --after "$T/n/after.md" --distinct
if [ "$RC" -eq 1 ] && ! hasre "$T/l7f.txt" 'REDUCED +12/12' && has "$T/l7f.txt" 'semantics=distinct' && has "$T/l7f.txt" 'DROPPED=2 REDUCED=0 INVENTED=2'; then
  ok "L7d ② --distinct: REDUCED 12/12 no longer reported, DROPPED/INVENTED unchanged"
else
  no "L7d ② --distinct" "rc=$RC"; dump "$T/l7f.txt"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# L8 — ② DEAD CONTROL: both sides digit-free → rc=4, never 0 (L7's rc=0 is the paired value)
# ═══════════════════════════════════════════════════════════════════════════════════════════════
num "$T/l8.txt" --before "$T/n/dead_a.md" --after "$T/n/dead_b.md"
if [ "$RC" -eq 4 ] && has "$T/l8.txt" 'DEAD CONTROL' && ! has "$T/l8.txt" 'numeric-diff verdict'; then
  ok "L8 ② dead control: 0 tokens on both sides → rc=4 with DEAD CONTROL banner (no verdict line)"
else
  no "L8 ② dead control" "rc=$RC"; dump "$T/l8.txt" 4
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# L9 — ② DIGIT BOUNDARY known-negative: the after side adds 2.7.1 · 12.7.3 · A.6.2.7 · §3.1–3.2 ·
#      부록 8 · K.2 · Sec. 9.4 · Section 12 · 섹션 8.1 · 3.2절 · A-6 · GHSA-2026-1234 ·
#      PREREG_ADDENDUM_2026-09-10.md — none of which is a number — so the multisets stay identical
#      (rc=0); 2.7 is never produced from 2.75 / 12.7, and the DOI on both sides yields exactly one
#      token (10.1007), never its hyphenated suffix segments (022 · 00171 · 7).
# L9b — 🟥 MAJOR-1 PAIR (the other direction of the same hyphen axis): a pure-digit hyphen range
#      keeps BOTH ends — 12-25 → 12 and 25 — so a shrink pass that erases the upper bound is
#      DROPPED rc=1, not a silent IDENTICAL. The v1 rule (<alnum>- blocks) passed this arm green.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
num "$T/l9.txt" --before "$T/n/bnd_before.md" --after "$T/n/bnd_after.md"
if [ "$RC" -eq 0 ] && has "$T/l9.txt" 'IDENTICAL numeric multisets — 5 tokens (5 distinct)' && has "$T/l9.txt" 'hyphen-rule=word'; then
  ok "L9 ② digit boundary: 2.7.1 / 12.7.3 / A.6.2.7 / §3.1–3.2 / 부록 8 / K.2 / Sec. 9.4 / 섹션 8.1 / 3.2절 / A-6 / GHSA-2026-1234 / a dated filename shed no token — identical (5 tokens: 2.7% 12/12 2.75 12.7% 10.1007)"
else
  no "L9 ② digit boundary" "rc=$RC"; dump "$T/l9.txt"
fi
num "$T/l9b.txt" --before "$T/n/hy_before.md" --after "$T/n/hy_after.md"; RCA=$RC
num "$T/l9c.txt" --before "$T/n/hy_before.md" --after "$T/n/hy_before.md"
if [ "$RCA" -eq 1 ] && has "$T/l9b.txt" 'before=1 file (2 lines · 4 tokens · 4 distinct) · after=1 file (2 lines · 3 tokens · 3 distinct)' \
   && hasre "$T/l9b.txt" 'DROPPED +25 +before ×1 +→ after ×0 +hy_before\.md:1:' \
   && has "$T/l9b.txt" 'numeric-diff verdict: DROPPED=1 REDUCED=0 INVENTED=0 INCREASED=0 ALLOWED=0 rc=1' \
   && [ "$RC" -eq 0 ] && has "$T/l9c.txt" 'IDENTICAL numeric multisets — 4 tokens (4 distinct)'; then
  ok "L9b ② hyphen range keeps both ends: 12-25 → 12 and 25 (4 tokens with 40-75); erasing 25 → DROPPED 25 rc=1; identity rc=0; GHSA-2026-1234 / A-6 still shed nothing"
else
  no "L9b ② hyphen range" "drop rc=$RCA identity rc=$RC"; dump "$T/l9b.txt"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# L10 — 🟥 ② REVERT PROBE: digit boundary removed in a COPY → L9's arm goes RED (rc=2, INVENTED 2.7
#       and 12.7 manufactured from the version strings); L7's identity arm stays GREEN under the same
#       mutant; original untouched.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
cp "$NUM" "$T/num_snapshot.py"
mutate "$NUM" "$T/num_mutant.py" no_digit_boundary
if [ $? -ne 0 ] || [ "$(cnt "$T/num_mutant.py" 'MUTANT: no_digit_boundary')" -ne 1 ]; then
  no "L10 ② revert probe (instrument)" "mutation did not apply: $(head -2 "$T/mut.txt")"
else
  run "$T/l10m.txt" "$T/num_mutant.py" --before "$T/n/bnd_before.md" --after "$T/n/bnd_after.md"; MRC=$RC
  run "$T/l10c.txt" "$T/num_mutant.py" --before "$T/n/before.md" --after "$T/n/before.md"; CRC=$RC
  num "$T/l10o.txt" --before "$T/n/bnd_before.md" --after "$T/n/bnd_after.md"; ORC=$RC
  if cmp -s "$NUM" "$T/num_snapshot.py"; then UNTOUCHED=yes; else UNTOUCHED=no; fi
  if [ "$MRC" -eq 2 ] && has "$T/l10m.txt" 'digit-boundary=off' \
     && has "$T/l10m.txt" 'INVENTED  2.7 ' && has "$T/l10m.txt" 'INVENTED  12.7 ' \
     && [ "$CRC" -eq 0 ] && has "$T/l10c.txt" 'IDENTICAL' \
     && [ "$ORC" -eq 0 ] && [ "$UNTOUCHED" = yes ]; then
    ok "L10 ② revert probe: boundary OFF in a copy → L9 arm RED (rc=2: 2.7 and 12.7 invented from 2.7.1 / 12.7.3); identity arm still GREEN; original untouched and still rc=0"
  else
    no "L10 ② revert probe" "mutant rc=$MRC · control rc=$CRC · original rc=$ORC untouched=$UNTOUCHED"; dump "$T/l10m.txt" 12
  fi
fi
num "$T/l10b.txt" --before "$T/n/bnd_before.md" --after "$T/n/bnd_after.md" --no-digit-boundary
if [ "$RC" -eq 2 ] && has "$T/l10b.txt" 'INVENTED  2.7 '; then
  ok "L10b ② same through the flag: --no-digit-boundary → rc=2 with 2.7 invented"
else
  no "L10b ② --no-digit-boundary" "rc=$RC"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# L10c — 🟥 ② REVERT PROBE for MAJOR-1: the hyphen rule reverted to the v1 «<alnum>- blocks» rule in
#       a COPY → ONLY L9b's arm goes RED (12-25 → 12, so erasing 25 is IDENTICAL rc=0 — the silent
#       false negative codex measured); L9's DOI/GHSA arm stays GREEN under the same mutant (the v1
#       rule passed it); original untouched. L10d repeats it through the flag.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
cp "$NUM" "$T/num_snapshot2.py"
mutate "$NUM" "$T/num_mutant_alnum.py" hyphen_rule '"alnum"'
if [ $? -ne 0 ] || [ "$(cnt "$T/num_mutant_alnum.py" 'MUTANT: hyphen_rule')" -ne 1 ]; then
  no "L10c ② revert probe MAJOR-1 (instrument)" "mutation did not apply: $(head -2 "$T/mut.txt")"
else
  run "$T/l10cm.txt" "$T/num_mutant_alnum.py" --before "$T/n/hy_before.md" --after "$T/n/hy_after.md"; MRC=$RC
  run "$T/l10cc.txt" "$T/num_mutant_alnum.py" --before "$T/n/bnd_before.md" --after "$T/n/bnd_after.md"; CRC=$RC
  num "$T/l10co.txt" --before "$T/n/hy_before.md" --after "$T/n/hy_after.md"; ORC=$RC
  if cmp -s "$NUM" "$T/num_snapshot2.py"; then UNTOUCHED=yes; else UNTOUCHED=no; fi
  # (under the v1 rule the dated filename on both sides is a 6th token — a date, not an identifier
  #  segment — so the control arm is pinned at 6 to show WHICH rule is running, not just rc=0)
  if [ "$MRC" -eq 0 ] && has "$T/l10cm.txt" 'hyphen-rule=alnum' && has "$T/l10cm.txt" 'IDENTICAL numeric multisets — 2 tokens (2 distinct)' \
     && [ "$CRC" -eq 0 ] && has "$T/l10cc.txt" 'IDENTICAL numeric multisets — 6 tokens (6 distinct)' \
     && [ "$ORC" -eq 1 ] && has "$T/l10co.txt" 'DROPPED=1 ' && [ "$UNTOUCHED" = yes ]; then
    ok "L10c ② revert probe MAJOR-1: v1 hyphen rule in a copy → L9b arm RED (erasing 25 reads IDENTICAL, 2 tokens) while the L9 DOI/GHSA arm stays GREEN (6 tokens under v1: the filename date counts there); original untouched, still DROPPED=1"
  else
    no "L10c ② revert probe MAJOR-1" "mutant rc=$MRC · control rc=$CRC · original rc=$ORC untouched=$UNTOUCHED"; dump "$T/l10cm.txt" 8
  fi
fi
num "$T/l10d.txt" --before "$T/n/hy_before.md" --after "$T/n/hy_after.md" --hyphen-rule alnum
if [ "$RC" -eq 0 ] && has "$T/l10d.txt" 'IDENTICAL numeric multisets — 2 tokens (2 distinct)'; then
  ok "L10d ② same through the flag: --hyphen-rule alnum reproduces the measured false negative (IDENTICAL, rc=0)"
else
  no "L10d ② --hyphen-rule alnum" "rc=$RC"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# FIXTURES ③ — section refs, heading forms copied from the draft
# ═══════════════════════════════════════════════════════════════════════════════════════════════
mkdir -p "$T/s"
cat > "$T/s/pos.md" <<'EOF'
# 2회 패스는 깎지 않는다
## 초록
본문은 §3.2 와 §2.3b 와 §3.3-b 와 §9.4.1 을 가리킨다; 부록 8 과 Appendix K 와 K.2 도 있다.
잘못된 것: §3.7 (부모는 있다), §14 (없다), 부록 3 (표로만 정의됨), K.9 (부모만 있다).
수치 근거 = RESULT §12~§21 (다른 문서를 가리키는 외부 참조).
## 2. 방법
### 2.3b 🟢 양성 컨트롤
## 3. 결과
### 3.1 런 내부 대조
### 3.2 클러스터 보정
### §3.3 주장 «개별» 보존
### §3.3-b 이 결손은 기성 문제류다
## 9. 기여
### 9.4 수치는 표면을 사지 못한다
#### 9.4.1 형식화
## 부록 (포인터)
### 부록 8 — 양방향 보정표
## Appendix K
### K.2 sub-appendix
```
### 99. a heading inside a fence is not a heading, and §77 inside a fence is still a ref
```
EOF
cat > "$T/s/neg.md" <<'EOF'
## 3. 결과
### 3.1 런 내부 대조
### 3.2 클러스터 보정
### 3.2a 짝지음
### 3.2b 해상도와 검정력
본문은 §3 과 §3.2 와 §3.2b 와 부록 8 을 가리킨다.
### 부록 8 — 양방향 보정표
유의성은 (§3.2 — 0.017·0.019 → 0.0625) 로 내려갔다; 범위 §3~§3.2 와 §3.2–3.2b 는 다 있다.
EOF
cat > "$T/s/dead.md" <<'EOF'
## 3. 결과
### 3.2 클러스터 보정
No cross-references at all in this body; §-free, 부록-free.
EOF
cat > "$T/s/nohead.md" <<'EOF'
Body with refs §3.2 and 부록 8 but no numbered heading anywhere.
## 초록
EOF
# MAJOR-2 (cross-family, codex, 2026-09-17): Sec. / Section / 섹션 / N절 spellings were outside the
# v1 grammar — a body written that way was rc=0 with not one ref read. One line of each that
# resolves, one of each that dangles, and a line of look-alikes that must NOT be refs.
cat > "$T/s/spell.md" <<'EOF'
## 3. 결과
### 3.2 클러스터 보정
## 8. 운영 수확
### 8.1 완주의 거짓말
## 9. 기여
### 9.4 수치는 표면을 사지 못한다
본문: Sec. 9.4 와 Section 3.2 와 섹션 8.1 과 3.2절 은 다 있다; §3.2 도 있다.
없는 것: Sec. 9.9 (부모 9 있음), 섹션 8.7 (부모 8 있음), Section 12 (없음), 7절 (없음).
아닌 것: 30 sec 뒤에, Second 3 은 낱말이고, 절차 3 도 아니다, Subsection 4 도 접두가 아니다.
> 분야에 관련연구 0절로 내는 것은, 이 팀이 이미 겪은 참고문헌 불일치 반려보다 나쁜 실패다.
EOF

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# L11 — ③ known-POSITIVE: rc=1 · DANGLING §3.7 (parent §3 exists) · §14 (no such top-level) ·
#       부록 3 · K.9 (parent Appendix K exists) · §12 and §21 from a range · §77 inside a fence · and
#       §3.2 / §2.3b / §3.3-b / §9.4.1 / 부록 8 / Appendix K / K.2 all RESOLVED (absent from DANGLING)
# ═══════════════════════════════════════════════════════════════════════════════════════════════
sec "$T/l11.txt" --body "$T/s/pos.md"
if [ "$RC" -eq 1 ] \
   && hasre "$T/l11.txt" 'DANGLING +§3\.7 +pos\.md:4 +\(parent §3 exists\)' \
   && hasre "$T/l11.txt" 'DANGLING +§14 +pos\.md:4 +\(no such top-level\)' \
   && hasre "$T/l11.txt" 'DANGLING +부록 3 +pos\.md:4 +\(no such top-level\)' \
   && hasre "$T/l11.txt" 'DANGLING +K\.9 +pos\.md:4 +\(parent Appendix K exists\)' \
   && hasre "$T/l11.txt" 'DANGLING +§12 +pos\.md:5' && hasre "$T/l11.txt" 'DANGLING +§21 +pos\.md:5' \
   && hasre "$T/l11.txt" 'DANGLING +§77 +pos\.md:21' \
   && [ "$(cnt "$T/l11.txt" '🟥 DANGLING')" -eq 15 ] \
   && has "$T/l11.txt" 'headings=16 (13 numbered anchors · 3 unnumbered) · refs=22 (21 distinct)' \
   && has "$T/l11.txt" 'section-ref verdict: DANGLING=15 STALE-OLD=0 EXTERNAL=0 RESOLVED=7 rc=1'; then
  ok "L11 ③ known-positive: rc=1 — 15 DANGLING classified (7 + 8 interiors of §12~§21) (parent-exists vs no-top-level), range endpoints and fenced ref caught, fenced heading ignored, 7 resolved"
else
  no "L11 ③ known-positive" "rc=$RC"; dump "$T/l11.txt" 16
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# L11b — 🟥 MAJOR-2 PAIR: Sec. 9.4 / Section 3.2 / 섹션 8.1 / 3.2절 resolve exactly like §; Sec. 9.9 /
#       섹션 8.7 / Section 12 / 7절 dangle exactly like §, with the spelling AS WRITTEN in the row;
#       «30 sec» / «Second 3» / «절차 3» / «Subsection 4» / «관련연구 0절로» (a COUNT, verbatim from
#       the prior-art section) are not refs (refs=9 pins it); and the --help list of spellings is
#       GENERATED from the same tuple the regex is built from.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
sec "$T/l11b.txt" --body "$T/s/spell.md"; RCA=$RC
sec "$T/l11h.txt" --help
if [ "$RCA" -eq 1 ] && has "$T/l11b.txt" 'refs=9 (7 distinct)' \
   && hasre "$T/l11b.txt" 'DANGLING +Sec\. 9\.9 +spell\.md:8 +\(parent §9 exists\)' \
   && hasre "$T/l11b.txt" 'DANGLING +섹션 8\.7 +spell\.md:8 +\(parent §8 exists\)' \
   && hasre "$T/l11b.txt" 'DANGLING +Section 12 +spell\.md:8 +\(no such top-level\)' \
   && hasre "$T/l11b.txt" 'DANGLING +7절 +spell\.md:8 +\(no such top-level\)' \
   && has "$T/l11b.txt" 'section-ref verdict: DANGLING=4 STALE-OLD=0 EXTERNAL=0 RESOLVED=5 rc=1' \
   && has "$T/l11b.txt" 'spellings: `§N` · `Sections N` · `Section N` · `sections N` · `section N` · `Sec. N` · `Sec N` · `섹션 N` · `N절`' \
   && [ "$RC" -eq 0 ] && has "$T/l11h.txt" 'ref      `§N` · `Sections N` · `Section N` · `sections N` · `section N` · `Sec. N` · `Sec N` · `섹션 N` · `N절`'; then
  ok "L11b ③ spellings: Sec./Section/섹션/N절 resolve (5) or dangle (4) like §, spelled as written; look-alikes incl. the 0절 count are not refs; --help and the run header list the same generated spellings"
else
  no "L11b ③ spellings" "rc=$RCA help rc=$RC"; dump "$T/l11b.txt" 12
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# L12 — ③ known-NEGATIVE: every ref resolves → rc=0 AND refs seen; then --map / --define / --external
# ═══════════════════════════════════════════════════════════════════════════════════════════════
sec "$T/l12.txt" --body "$T/s/neg.md" --show-resolved
if [ "$RC" -eq 0 ] && has "$T/l12.txt" 'refs=11 (6 distinct)' && has "$T/l12.txt" 'DANGLING=0 STALE-OLD=0 EXTERNAL=0 RESOLVED=11 rc=0' && hasre "$T/l12.txt" 'resolved +§3\.2a \(interior of §3\.2–3\.2b\)' && hasre "$T/l12.txt" 'resolved +§3\.1 \(interior of §3~§3\.2\)' \
   && ! has "$T/l12.txt" '§0.017' && [ "$(cntre "$T/l12.txt" 'resolved +§3\.2b')" -eq 2 ]; then
  ok "L12 ③ known-negative: rc=0 with 9 refs SEEN and resolved — §3.2b resolves to the letter-suffixed heading, tilde/EN-dash ranges resolve at both ends, and «§3.2 — 0.017» is NOT read as a range ending in §0.017"
else
  no "L12 ③ known-negative" "rc=$RC"; dump "$T/l12.txt" 14
fi
sec "$T/l12b.txt" --body "$T/s/neg.md" --map '3.2=4.2'; RCA=$RC
sec "$T/l12c.txt" --body "$T/s/pos.md" --define '부록 3' --external 'RESULT'; RCB=$RC
if [ "$RCA" -eq 1 ] && hasre "$T/l12b.txt" 'STALE-OLD +§3\.2 +neg\.md:6 +\(old §3\.2 → now §4\.2\)' \
   && hasre "$T/l12b.txt" 'STALE-OLD +§3\.2b +neg\.md:6 +\(old §3\.2 → now §4\.2\)' && ! hasre "$T/l12b.txt" 'STALE-OLD +§3 ' \
   && has "$T/l12b.txt" 'STALE-OLD=7' \
   && [ "$RCB" -eq 1 ] && has "$T/l12c.txt" 'defined-by-flag=부록 3' && ! hasre "$T/l12c.txt" 'DANGLING +부록 3' \
   && hasre "$T/l12c.txt" "EXTERNAL +§12 +pos\.md:5 +\(matched 'RESULT'\)" && has "$T/l12c.txt" 'EXTERNAL=10' \
   && ! hasre "$T/l12c.txt" 'EXTERNAL +§14 +pos' && has "$T/l12c.txt" 'DANGLING=4 '; then
  ok "L12b ③ --map 3.2=4.2 → §3.2 and §3.2b STALE-OLD (§3 not), rc=1; --define resolves 부록 3; --external classifies only the RESULT §12~§21 line, listed not counted"
else
  no "L12b ③ --map / --define / --external" "map rc=$RCA define/external rc=$RCB"; dump "$T/l12b.txt" 8; dump "$T/l12c.txt" 14
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# L13 — ③ DEAD CONTROL: headings but no refs → rc=4; refs but no numbered heading → rc=10
# ═══════════════════════════════════════════════════════════════════════════════════════════════
sec "$T/l13.txt" --body "$T/s/dead.md"; RCA=$RC
sec "$T/l13b.txt" --body "$T/s/nohead.md"
if [ "$RCA" -eq 4 ] && has "$T/l13.txt" 'DEAD CONTROL' && has "$T/l13.txt" '2 numbered heading(s) parsed' && ! has "$T/l13.txt" 'section-ref verdict' \
   && [ "$RC" -eq 10 ] && has "$T/l13b.txt" '0 numbered headings parsed' && has "$T/l13b.txt" '2 ref(s) seen and NOT reported as dangling'; then
  ok "L13 ③ dead control: 0 refs → rc=4 (headings counted); 0 numbered headings → rc=10 (refs NOT rendered as dangling)"
else
  no "L13 ③ dead control" "refs-free rc=$RCA heading-free rc=$RC"; dump "$T/l13b.txt" 4
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# L14 — 🟥 ③ REVERT PROBE: exact-match replaced by parent-resolves in a COPY → L11's arm goes RED
#       (§3.7 and K.9 silently resolve; §14 still dangles); L12's arm stays GREEN; original untouched.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
cp "$SEC" "$T/sec_snapshot.py"
mutate "$SEC" "$T/sec_mutant.py" parent_resolves
if [ $? -ne 0 ] || [ "$(cnt "$T/sec_mutant.py" 'MUTANT: parent_resolves')" -ne 1 ]; then
  no "L14 ③ revert probe (instrument)" "mutation did not apply: $(head -2 "$T/mut.txt")"
else
  run "$T/l14m.txt" "$T/sec_mutant.py" --body "$T/s/pos.md"; MRC=$RC
  run "$T/l14c.txt" "$T/sec_mutant.py" --body "$T/s/neg.md"; CRC=$RC
  sec "$T/l14o.txt" --body "$T/s/pos.md"; ORC=$RC
  if cmp -s "$SEC" "$T/sec_snapshot.py"; then UNTOUCHED=yes; else UNTOUCHED=no; fi
  if [ "$MRC" -eq 1 ] && has "$T/l14m.txt" 'ABLATION: parent resolves' \
     && ! hasre "$T/l14m.txt" 'DANGLING +§3\.7' && ! hasre "$T/l14m.txt" 'DANGLING +K\.9' && hasre "$T/l14m.txt" 'DANGLING +§14' \
     && has "$T/l14m.txt" 'DANGLING=13 ' \
     && [ "$CRC" -eq 0 ] && [ "$ORC" -eq 1 ] && has "$T/l14o.txt" 'DANGLING=15 ' && [ "$UNTOUCHED" = yes ]; then
    ok "L14 ③ revert probe: parent-resolves in a copy → §3.7 and K.9 vanish from DANGLING (RED, 15→13) while §14 remains; known-negative still GREEN; original untouched, still 7"
  else
    no "L14 ③ revert probe" "mutant rc=$MRC · control rc=$CRC · original rc=$ORC untouched=$UNTOUCHED"; dump "$T/l14m.txt" 12
  fi
fi
sec "$T/l14b.txt" --body "$T/s/pos.md" --parent-resolves --show-resolved
if [ "$RC" -eq 1 ] && hasre "$T/l14b.txt" 'resolved +§3\.7 +pos\.md:4 +\(via parent §3 — ABLATION\)' && has "$T/l14b.txt" 'DANGLING=13 '; then
  ok "L14b ③ same through the flag: --parent-resolves → §3.7 resolves via parent and says ABLATION"
else
  no "L14b ③ --parent-resolves" "rc=$RC"; dump "$T/l14b.txt" 8
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# L14c — 🟥 ③ REVERT PROBE for MAJOR-2: the alt spellings removed from the grammar in a COPY → L11b's
#       arm goes RED in the silent direction (only §3.2 is read: refs=1, rc=0, no DANGLING — the v1
#       behaviour codex measured); L12's §/부록 arm stays GREEN under the same mutant; original
#       untouched. L14d repeats it through the flag.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
cp "$SEC" "$T/sec_snapshot2.py"
mutate "$SEC" "$T/sec_mutant_spell.py" no_alt_spellings
if [ $? -ne 0 ] || [ "$(cnt "$T/sec_mutant_spell.py" 'MUTANT: no_alt_spellings')" -ne 1 ]; then
  no "L14c ③ revert probe MAJOR-2 (instrument)" "mutation did not apply: $(head -2 "$T/mut.txt")"
else
  run "$T/l14cm.txt" "$T/sec_mutant_spell.py" --body "$T/s/spell.md"; MRC=$RC
  run "$T/l14cc.txt" "$T/sec_mutant_spell.py" --body "$T/s/neg.md"; CRC=$RC
  sec "$T/l14co.txt" --body "$T/s/spell.md"; ORC=$RC
  if cmp -s "$SEC" "$T/sec_snapshot2.py"; then UNTOUCHED=yes; else UNTOUCHED=no; fi
  if [ "$MRC" -eq 0 ] && has "$T/l14cm.txt" 'refs=1 (1 distinct)' && has "$T/l14cm.txt" 'ABLATION: alt spellings off' \
     && ! has "$T/l14cm.txt" '🟥 DANGLING' && has "$T/l14cm.txt" 'DANGLING=0 STALE-OLD=0 EXTERNAL=0 RESOLVED=1 rc=0' \
     && [ "$CRC" -eq 0 ] && has "$T/l14cc.txt" 'RESOLVED=11 rc=0' \
     && [ "$ORC" -eq 1 ] && has "$T/l14co.txt" 'DANGLING=4 ' && [ "$UNTOUCHED" = yes ]; then
    ok "L14c ③ revert probe MAJOR-2: alt spellings OFF in a copy → L11b arm RED in the silent direction (refs=1, rc=0, 0 DANGLING) while the L12 §/부록 arm stays GREEN; original untouched, still DANGLING=4"
  else
    no "L14c ③ revert probe MAJOR-2" "mutant rc=$MRC · control rc=$CRC · original rc=$ORC untouched=$UNTOUCHED"; dump "$T/l14cm.txt" 8
  fi
fi
sec "$T/l14d.txt" --body "$T/s/spell.md" --no-alt-spellings
if [ "$RC" -eq 0 ] && has "$T/l14d.txt" 'refs=1 (1 distinct)' && has "$T/l14d.txt" 'ABLATION: alt spellings off'; then
  ok "L14d ③ same through the flag: --no-alt-spellings reproduces the v1 silent arm (refs=1, rc=0)"
else
  no "L14d ③ --no-alt-spellings" "rc=$RC"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# L11c — 🟥 ③ RANGE INTERIOR + COMPACT FORM (codex round 2, 2026-09-18): `§1.1–1.3` with no §1.2 was
#        RESOLVED=2 rc=0, and `Section 1.1-1.3` (compact ASCII hyphen) was read as §1.1 alone, so a missing
#        upper end was silent. v3 expands same-parent integer ranges (every interior section is a ref of
#        its own) and reads the compact form only when both sides share a parent and ascend — so
#        `Sec. 2026-09-10` (a date) yields no §09/§10 ref, and `§3.2 — 0.017` stays a non-range.
#        L14e–L14h are the revert probes (source mutant / flag, one pair per rule).
# ═══════════════════════════════════════════════════════════════════════════════════════════════
cat > "$T/s/range.md" <<'EOF'
# 1 Top
See §1.1–1.3 and Section 2.1-2.3 and §5~§7 for the chain.
## 1.1 First
## 1.3 Third
## 2.1 A
## 2.2 B
## 2.3 C
## 5 Five
## 6 Six
## 7 Seven
EOF
cat > "$T/s/compact.md" <<'EOF'
# 1 Top
See Section 1.1-1.3 for the full chain.
## 1.1 First
## 1.2 Second
EOF
cat > "$T/s/date.md" <<'EOF'
# 1 Top
See Sec. 2026-09-10 and §3.2 — 0.017 here.
## 3.2 Corr
EOF
sec "$T/l11c.txt" --body "$T/s/range.md" --show-resolved; RCA=$RC
sec "$T/l11d.txt" --body "$T/s/compact.md"; RCB=$RC
sec "$T/l11e.txt" --body "$T/s/date.md" --show-resolved; RCC=$RC
if [ "$RCA" -eq 1 ] && has "$T/l11c.txt" 'refs=9 (9 distinct)' && hasre "$T/l11c.txt" 'DANGLING +§1\.2 \(interior of §1\.1–1\.3\)' \
   && hasre "$T/l11c.txt" 'resolved +§2\.2 \(interior of Section 2\.1-2\.3\)' && hasre "$T/l11c.txt" 'resolved +§6 \(interior of §5~§7\)' \
   && hasre "$T/l11c.txt" 'resolved +§2\.3 ' && has "$T/l11c.txt" 'DANGLING=1 STALE-OLD=0 EXTERNAL=0 RESOLVED=8 rc=1' \
   && [ "$RCB" -eq 1 ] && hasre "$T/l11d.txt" 'DANGLING +§1\.3 ' && has "$T/l11d.txt" 'DANGLING=1 STALE-OLD=0 EXTERNAL=0 RESOLVED=2 rc=1' \
   && [ "$RCC" -eq 1 ] && has "$T/l11e.txt" 'refs=2 (2 distinct)' && ! hasre "$T/l11e.txt" '§09|§10' && hasre "$T/l11e.txt" 'DANGLING +Sec\. 2026' && ! has "$T/l11e.txt" '§0.017'; then
  ok "L11c ③ range interior + compact form: §1.2 (interior of §1.1–1.3) DANGLING while §2.2 / §6 interiors resolve; Section 1.1-1.3 reads its upper end (§1.3 dangles); Sec. 2026-09-10 yields no §09/§10 (Sec. 2026 dangles, loud)"
else
  no "L11c ③ range interior + compact form" "range rc=$RCA compact rc=$RCB date rc=$RCC"; dump "$T/l11c.txt" 12; dump "$T/l11d.txt" 8; dump "$T/l11e.txt" 8
fi
cp "$SEC" "$T/sec_snapshot3.py"
mutate "$SEC" "$T/sec_mutant_int.py" no_range_interior
if [ $? -ne 0 ] || [ "$(cnt "$T/sec_mutant_int.py" 'MUTANT: no_range_interior')" -ne 1 ]; then
  no "L14e ③ revert probe interior (instrument)" "mutation did not apply: $(head -2 "$T/mut.txt")"
else
  run "$T/l14em.txt" "$T/sec_mutant_int.py" --body "$T/s/range.md"; MRC=$RC
  run "$T/l14ec.txt" "$T/sec_mutant_int.py" --body "$T/s/neg.md"; CRC=$RC
  sec "$T/l14eo.txt" --body "$T/s/range.md"; ORC=$RC
  if cmp -s "$SEC" "$T/sec_snapshot3.py"; then UNTOUCHED=yes; else UNTOUCHED=no; fi
  if [ "$MRC" -eq 0 ] && has "$T/l14em.txt" 'refs=6 (6 distinct)' && has "$T/l14em.txt" 'range-interior=off (ABLATION)' \
     && has "$T/l14em.txt" 'DANGLING=0 STALE-OLD=0 EXTERNAL=0 RESOLVED=6 rc=0' \
     && [ "$CRC" -eq 0 ] && has "$T/l14ec.txt" 'RESOLVED=9 rc=0' && [ "$ORC" -eq 1 ] && has "$T/l14eo.txt" 'DANGLING=1 ' && [ "$UNTOUCHED" = yes ]; then
    ok "L14e ③ revert probe interior: expansion OFF in a copy → range.md reads CLEAN (refs=6, rc=0 — the v2 silent arm) while neg.md stays GREEN; original untouched, still DANGLING=1"
  else
    no "L14e ③ revert probe interior" "mutant rc=$MRC · control rc=$CRC · original rc=$ORC untouched=$UNTOUCHED"; dump "$T/l14em.txt" 8
  fi
fi
sec "$T/l14f.txt" --body "$T/s/range.md" --no-range-interior
if [ "$RC" -eq 0 ] && has "$T/l14f.txt" 'refs=6 (6 distinct)' && has "$T/l14f.txt" 'range-interior=off (ABLATION)'; then
  ok "L14f ③ same through the flag: --no-range-interior reproduces the v2 silent arm (refs=6, rc=0)"
else
  no "L14f ③ --no-range-interior" "rc=$RC"; dump "$T/l14f.txt" 6
fi
mutate "$SEC" "$T/sec_mutant_cmp.py" no_compact_range
if [ $? -ne 0 ] || [ "$(cnt "$T/sec_mutant_cmp.py" 'MUTANT: no_compact_range')" -ne 1 ]; then
  no "L14g ③ revert probe compact (instrument)" "mutation did not apply: $(head -2 "$T/mut.txt")"
else
  run "$T/l14gm.txt" "$T/sec_mutant_cmp.py" --body "$T/s/compact.md"; MRC=$RC
  run "$T/l14gc.txt" "$T/sec_mutant_cmp.py" --body "$T/s/neg.md"; CRC=$RC
  sec "$T/l14go.txt" --body "$T/s/compact.md"; ORC=$RC
  if cmp -s "$SEC" "$T/sec_snapshot3.py"; then UNTOUCHED=yes; else UNTOUCHED=no; fi
  if [ "$MRC" -eq 0 ] && has "$T/l14gm.txt" 'refs=1 (1 distinct)' && has "$T/l14gm.txt" 'compact-range=off (ABLATION)' \
     && has "$T/l14gm.txt" 'DANGLING=0 STALE-OLD=0 EXTERNAL=0 RESOLVED=1 rc=0' \
     && [ "$CRC" -eq 0 ] && has "$T/l14gc.txt" 'RESOLVED=11 rc=0' && [ "$ORC" -eq 1 ] && has "$T/l14go.txt" 'DANGLING=1 ' && [ "$UNTOUCHED" = yes ]; then
    ok "L14g ③ revert probe compact: the compact form OFF in a copy → compact.md reads CLEAN (refs=1, rc=0 — the v2 silent arm) while neg.md stays GREEN; original untouched, still DANGLING=1"
  else
    no "L14g ③ revert probe compact" "mutant rc=$MRC · control rc=$CRC · original rc=$ORC untouched=$UNTOUCHED"; dump "$T/l14gm.txt" 8
  fi
fi
sec "$T/l14h.txt" --body "$T/s/compact.md" --no-compact-range
if [ "$RC" -eq 0 ] && has "$T/l14h.txt" 'refs=1 (1 distinct)' && has "$T/l14h.txt" 'compact-range=off (ABLATION)'; then
  ok "L14h ③ same through the flag: --no-compact-range reproduces the v2 silent arm (refs=1, rc=0)"
else
  no "L14h ③ --no-compact-range" "rc=$RC"; dump "$T/l14h.txt" 6
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# L11f/g/h — 🟥 ③ codex round 3 (2026-09-18): (f) `§3.2a–3.2c` had an unchecked interior §3.2b (clean);
#        (g) a range beyond the cap was a stderr warning + rc=0 (interior unchecked, verdict clean) — now a
#        DANGLING-class UNCHECKED row, `--range-cap N` raises the cap, `--no-cap-verdict` = the v3 arm;
#        (h) full-width `§１.２` did not key like `## 1.2` (over-block) — NFKC on the key, raw display.
#        L14i/L14j are the revert probes for (f) and (g).
# ═══════════════════════════════════════════════════════════════════════════════════════════════
cat > "$T/s/suffix.md" <<'EOF'
# 3 Top
See §3.2a–3.2c for the trio.
## 3.2 Base
### 3.2a A
### 3.2c C
EOF
cat > "$T/s/cap.md" <<'EOF'
# 1 Top
See §1–5 for all of them.
## 2 B
## 3 C
## 4 D
## 5 E
EOF
cat > "$T/s/fullwidth.md" <<'EOF'
# 1 Top
See §１.２ here.
## 1.2 Second
EOF
sec "$T/l11f.txt" --body "$T/s/suffix.md" --show-resolved
if [ "$RC" -eq 1 ] && has "$T/l11f.txt" 'refs=3 (3 distinct)' && hasre "$T/l11f.txt" 'DANGLING +§3\.2b \(interior of §3\.2a–3\.2c\)' \
   && hasre "$T/l11f.txt" 'resolved +§3\.2c ' && has "$T/l11f.txt" 'DANGLING=1 STALE-OLD=0 EXTERNAL=0 RESOLVED=2 rc=1'; then
  ok "L11f ③ letter-suffix range: §3.2b (interior of §3.2a–3.2c) DANGLING while both endpoints resolve (rc=1)"
else
  no "L11f ③ letter-suffix range" "rc=$RC"; dump "$T/l11f.txt" 8
fi
sec "$T/l11g.txt" --body "$T/s/cap.md" --show-resolved; RCA=$RC
sec "$T/l11g2.txt" --body "$T/s/cap.md" --range-cap 3; RCB=$RC
sec "$T/l11g3.txt" --body "$T/s/cap.md" --range-cap 3 --no-cap-verdict; RCC=$RC
if [ "$RCA" -eq 0 ] && hasre "$T/l11g.txt" 'resolved +§3 \(interior of §1–5\)' && has "$T/l11g.txt" 'RESOLVED=5 rc=0' \
   && [ "$RCB" -eq 1 ] && hasre "$T/l11g2.txt" 'DANGLING +§1–5 \(interior UNCHECKED: span > 3' && has "$T/l11g2.txt" 'range-cap=3 · unchecked-verdict=on' \
   && has "$T/l11g2.txt" 'DANGLING=1 STALE-OLD=0 EXTERNAL=0 RESOLVED=2 rc=1' \
   && [ "$RCC" -eq 0 ] && has "$T/l11g3.txt" 'interior NOT expanded (ABLATION: --no-unchecked-verdict)' && has "$T/l11g3.txt" 'RESOLVED=2 rc=0'; then
  ok "L11g ③ range cap: under the default cap §1–5 expands and resolves (rc=0); --range-cap 3 turns it into an UNCHECKED row (rc=1); --no-cap-verdict reproduces the v3 warning-only arm (rc=0)"
else
  no "L11g ③ range cap" "default rc=$RCA cap3 rc=$RCB ablation rc=$RCC"; dump "$T/l11g2.txt" 8; dump "$T/l11g3.txt" 6
fi
sec "$T/l11h.txt" --body "$T/s/fullwidth.md" --show-resolved
if [ "$RC" -eq 0 ] && has "$T/l11h.txt" 'refs=1 (1 distinct)' && hasre "$T/l11h.txt" 'resolved +§1\.2 ' && has "$T/l11h.txt" 'RESOLVED=1 rc=0'; then
  ok "L11h ③ full-width digits: §１.２ resolves to ## 1.2 (v18: the line is width-mapped before scanning, so the display shows §1.2)"
else
  no "L11h ③ full-width digits" "rc=$RC"; dump "$T/l11h.txt" 6
fi
mutate "$SEC" "$T/sec_mutant_int2.py" no_range_interior
if [ $? -ne 0 ] || [ "$(cnt "$T/sec_mutant_int2.py" 'MUTANT: no_range_interior')" -ne 1 ]; then
  no "L14i ③ revert probe letter-suffix (instrument)" "mutation did not apply: $(head -2 "$T/mut.txt")"
else
  run "$T/l14im.txt" "$T/sec_mutant_int2.py" --body "$T/s/suffix.md"; MRC=$RC
  run "$T/l14ic.txt" "$T/sec_mutant_int2.py" --body "$T/s/neg.md"; CRC=$RC
  sec "$T/l14io.txt" --body "$T/s/suffix.md"; ORC=$RC
  if cmp -s "$SEC" "$T/sec_snapshot3.py"; then UNTOUCHED=yes; else UNTOUCHED=no; fi
  if [ "$MRC" -eq 0 ] && has "$T/l14im.txt" 'refs=2 (2 distinct)' && has "$T/l14im.txt" 'RESOLVED=2 rc=0' \
     && [ "$CRC" -eq 0 ] && has "$T/l14ic.txt" 'RESOLVED=9 rc=0' && [ "$ORC" -eq 1 ] && has "$T/l14io.txt" 'DANGLING=1 ' && [ "$UNTOUCHED" = yes ]; then
    ok "L14i ③ revert probe letter-suffix: expansion OFF in a copy → suffix.md reads CLEAN (refs=2, rc=0 — the v3 silent arm) while neg.md stays GREEN; original untouched, still DANGLING=1"
  else
    no "L14i ③ revert probe letter-suffix" "mutant rc=$MRC · control rc=$CRC · original rc=$ORC untouched=$UNTOUCHED"; dump "$T/l14im.txt" 8
  fi
fi
mutate "$SEC" "$T/sec_mutant_cap.py" no_cap_verdict
if [ $? -ne 0 ] || [ "$(cnt "$T/sec_mutant_cap.py" 'MUTANT: no_cap_verdict')" -ne 1 ]; then
  no "L14j ③ revert probe cap verdict (instrument)" "mutation did not apply: $(head -2 "$T/mut.txt")"
else
  run "$T/l14jm.txt" "$T/sec_mutant_cap.py" --body "$T/s/cap.md" --range-cap 3; MRC=$RC
  run "$T/l14jc.txt" "$T/sec_mutant_cap.py" --body "$T/s/neg.md"; CRC=$RC
  sec "$T/l14jo.txt" --body "$T/s/cap.md" --range-cap 3; ORC=$RC
  if cmp -s "$SEC" "$T/sec_snapshot3.py"; then UNTOUCHED=yes; else UNTOUCHED=no; fi
  if [ "$MRC" -eq 0 ] && has "$T/l14jm.txt" 'interior NOT expanded' && has "$T/l14jm.txt" 'RESOLVED=2 rc=0' \
     && [ "$CRC" -eq 0 ] && has "$T/l14jc.txt" 'RESOLVED=11 rc=0' && [ "$ORC" -eq 1 ] && has "$T/l14jo.txt" 'DANGLING=1 ' && [ "$UNTOUCHED" = yes ]; then
    ok "L14j ③ revert probe cap verdict: warning-only in a copy → cap.md reads CLEAN under --range-cap 3 (rc=0 — the v3 silent arm) while neg.md stays GREEN; original untouched, still DANGLING=1"
  else
    no "L14j ③ revert probe cap verdict" "mutant rc=$MRC · control rc=$CRC · original rc=$ORC untouched=$UNTOUCHED"; dump "$T/l14jm.txt" 8
  fi
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# L11i — 🟥 ③ codex round 4 (2026-09-18): a MIXED-form range (`§3.2a-3.3` — suffix on one end only, or
#        `§3~§4.2` across parents) has no defined interior; v4 checked its endpoints and said clean. Now an
#        UNCHECKED row (rc=1) unless --no-unchecked-verdict. The parent→child form `§3~§3.2` IS enumerable
#        (interior §3.1) and expands like the others — pinned here in both directions.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
cat > "$T/s/mixed.md" <<'EOF'
## 3
### 3.2a Alpha
### 3.3 Next
Reader follows §3.2a-3.3 and §3~§4.2 too.
## 4
### 4.2 Four-two
EOF
cat > "$T/s/pchild_missing.md" <<'EOF'
# 3 Top
See §3~§3.2 for the pair.
## 3.2 Corr
EOF
cat > "$T/s/pchild_ok.md" <<'EOF'
# 3 Top
See §3~§3.2 for the pair.
## 3.1 First
## 3.2 Corr
EOF
sec "$T/l11i.txt" --body "$T/s/mixed.md"; RCA=$RC
sec "$T/l11i2.txt" --body "$T/s/mixed.md" --no-unchecked-verdict; RCB=$RC
sec "$T/l11i3.txt" --body "$T/s/pchild_missing.md"; RCC=$RC
sec "$T/l11i4.txt" --body "$T/s/pchild_ok.md" --show-resolved; RCD=$RC
if [ "$RCA" -eq 1 ] && hasre "$T/l11i.txt" 'DANGLING +§3\.2a-3\.3 \(interior UNCHECKED: mixed form' && hasre "$T/l11i.txt" 'DANGLING +§3~§4\.2 \(interior UNCHECKED: mixed form' \
   && has "$T/l11i.txt" 'DANGLING=2 STALE-OLD=0 EXTERNAL=0 RESOLVED=4 rc=1' \
   && [ "$RCB" -eq 0 ] && [ "$(cnt "$T/l11i2.txt" 'interior NOT expanded (ABLATION: --no-unchecked-verdict)')" -eq 2 ] && has "$T/l11i2.txt" 'RESOLVED=4 rc=0' \
   && [ "$RCC" -eq 1 ] && hasre "$T/l11i3.txt" 'DANGLING +§3\.1 \(interior of §3~§3\.2\)' && has "$T/l11i3.txt" 'DANGLING=1 STALE-OLD=0 EXTERNAL=0 RESOLVED=2 rc=1' \
   && [ "$RCD" -eq 0 ] && hasre "$T/l11i4.txt" 'resolved +§3\.1 \(interior of §3~§3\.2\)' && has "$T/l11i4.txt" 'RESOLVED=3 rc=0'; then
  ok "L11i ③ mixed-form ranges: §3.2a-3.3 and §3~§4.2 are UNCHECKED rows (rc=1) — --no-unchecked-verdict reproduces the v4 clean arm; parent→child §3~§3.2 expands to §3.1 (dangles when missing, resolves when present)"
else
  no "L11i ③ mixed-form ranges" "mixed rc=$RCA ablation rc=$RCB pchild-missing rc=$RCC pchild-ok rc=$RCD"; dump "$T/l11i.txt" 10; dump "$T/l11i2.txt" 6; dump "$T/l11i3.txt" 6
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# L11j — 🟥 ③ codex round 5 (2026-09-18): the SPACED ASCII hyphen `Section 3.1 - 3.3` (and the plural /
#        lowercase `sections 3.1 - 3.3`, outside the grammar until v6) read as §3.1 alone — a missing
#        interior §3.2 was clean. `§3.1 - 0.017` stays a section followed by a number (parent 3 vs 0).
#        --no-compact-range is the ablation arm for the spaced form too.
# L11k — MINOR from the same round: text inside `<!-- … -->` is invisible to the reader. All three tools
#        strip it — ③ a ref/heading in a comment is neither a defect nor an anchor (a VISIBLE ref to a
#        heading that exists only inside a comment DANGLES); ① a key in a comment is not a usage (the
#        same key uncommented is a PHANTOM — the stripping is load-bearing); ② a number moved into a
#        comment is DROPPED (loud).
# ═══════════════════════════════════════════════════════════════════════════════════════════════
cat > "$T/s/spaced.md" <<'EOF'
## 3 Container
### 3.1 First
### 3.3 Third
The range says Section 3.1 - 3.3, and sections 3.1 - 3.3, and Sec. 3.1 - 3.3; §3.1 - 0.017 is a number.
EOF
sec "$T/l11j.txt" --body "$T/s/spaced.md"; RCA=$RC
sec "$T/l11j2.txt" --body "$T/s/spaced.md" --no-compact-range; RCB=$RC
if [ "$RCA" -eq 1 ] && [ "$(cntre "$T/l11j.txt" 'DANGLING +§3\.2 \(interior of (Section|sections|Sec\.) 3\.1 - 3\.3\)')" -eq 3 ] \
   && ! has "$T/l11j.txt" '§0.017' && has "$T/l11j.txt" 'DANGLING=3 STALE-OLD=0 EXTERNAL=0 RESOLVED=7 rc=1' \
   && [ "$RCB" -eq 0 ] && has "$T/l11j2.txt" 'compact-range=off (ABLATION)' && has "$T/l11j2.txt" 'DANGLING=0 STALE-OLD=0 EXTERNAL=0 RESOLVED=4 rc=0'; then
  ok "L11j ③ spaced hyphen ranges: Section / sections / Sec. 3.1 - 3.3 each name the missing interior §3.2 (rc=1); §3.1 - 0.017 is not a range; --no-compact-range reproduces the v5 silent arm (rc=0)"
else
  no "L11j ③ spaced hyphen ranges" "rc=$RCA ablation rc=$RCB"; dump "$T/l11j.txt" 10; dump "$T/l11j2.txt" 6
fi
cat > "$T/s/comment.md" <<'EOF'
# 9 Top
Visible §9 and a visible §5.
<!-- maintenance note §404 -->
<!-- multi-line
## 5 hidden heading
and §7 in here
-->
EOF
cat > "$T/c/body_comment.md" <<'EOF'
Valid [OK26]. <!-- [ZZ99] hidden --> end.

| [OK26] | row |
EOF
cat > "$T/c/body_uncomment.md" <<'EOF'
Valid [OK26]. [ZZ99] shown. end.

| [OK26] | row |
EOF
printf 'value 42 and 7 here\n' > "$T/n/cm_before.md"; printf 'value <!-- 42 --> and 7 here\n' > "$T/n/cm_after.md"
sec "$T/l11k.txt" --body "$T/s/comment.md"; RCA=$RC
cit "$T/l11k2.txt" --body "$T/c/body_comment.md"; RCB=$RC
cit "$T/l11k3.txt" --body "$T/c/body_uncomment.md"; RCC=$RC
num "$T/l11k4.txt" --before "$T/n/cm_before.md" --after "$T/n/cm_after.md"; RCD=$RC
if [ "$RCA" -eq 1 ] && has "$T/l11k.txt" 'refs=2 (2 distinct)' && hasre "$T/l11k.txt" 'DANGLING +§5 +comment\.md:2 +\(no such top-level\)' && ! has "$T/l11k.txt" '§404' && ! has "$T/l11k.txt" '§7' \
   && has "$T/l11k.txt" 'headings=1 (1 numbered anchors' \
   && [ "$RCB" -eq 0 ] && has "$T/l11k2.txt" '(1 usages · 1 distinct keys)' && has "$T/l11k2.txt" 'PHANTOM=0 ' \
   && [ "$RCC" -eq 1 ] && hasre "$T/l11k3.txt" 'PHANTOM +\[ZZ99\]' \
   && [ "$RCD" -eq 1 ] && hasre "$T/l11k4.txt" 'DROPPED +42 ' && has "$T/l11k4.txt" 'DROPPED=1 '; then
  ok "L11k ①②③ HTML comments are invisible: a commented ref/heading is neither defect nor anchor (visible §5 → hidden heading DANGLES); a commented key is not a usage while the same key uncommented is PHANTOM; a number moved into a comment is DROPPED"
else
  no "L11k ①②③ HTML comments" "sec rc=$RCA cit rc=$RCB uncomment rc=$RCC num rc=$RCD"; dump "$T/l11k.txt" 8; dump "$T/l11k2.txt" 5; dump "$T/l11k4.txt" 5
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# L11l — 🟥 codex round 6 (2026-09-18): the v6 comment strip ERASED PROSE between a `<!--` inside a code
#        span / fence and a later `-->` — a reader-visible §404 / [ZZ99] / 42 between them read clean.
#        v7 strips with Markdown awareness (fences untouched, code spans masked); an unclosed `<!--` still
#        swallows the rest (rendered Markdown does the same). All three tools carry the same function.
# L11m — same round: `§3.1/3.2` named only §3.1; now both, and `§3.1/2` is the sibling §3.2.
# L11n — MINOR pair: `## **3.2** Middle` is a numbered heading; a blockquoted definitions table defines.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
cat > "$T/s/cmark.md" <<'EOF'
# 1 Intro
The literal marker `<!--` is discussed; a visible stale pointer to §404 follows; the literal `-->` closes nothing.
```html
<!--
```
Between the fences the visible pointer §405 is still prose.
```html
-->
```
A real comment: <!-- §406 hidden --> and §1 is fine. Unclosed <!-- §407 swallowed
and §408 on the next line too.
EOF
cat > "$T/c/body_cmark.md" <<'EOF'
Valid [OK26]; literal `<!--` then visible [ZZ99] then literal `-->` end.

| [OK26] | row |
EOF
printf 'literal `<!--` then 42 then `-->` and 7\n' > "$T/n/cmark_before.md"; printf 'literal `<!--` then 41 then `-->` and 7\n' > "$T/n/cmark_after.md"
sec "$T/l11l.txt" --body "$T/s/cmark.md"; RCA=$RC
cit "$T/l11l2.txt" --body "$T/c/body_cmark.md"; RCB=$RC
num "$T/l11l3.txt" --before "$T/n/cmark_before.md" --after "$T/n/cmark_after.md"; RCC=$RC
if [ "$RCA" -eq 1 ] && hasre "$T/l11l.txt" 'DANGLING +§404 ' && hasre "$T/l11l.txt" 'DANGLING +§405 ' && ! has "$T/l11l.txt" '§406' && ! has "$T/l11l.txt" '§407' && ! has "$T/l11l.txt" '§408' \
   && has "$T/l11l.txt" 'DANGLING=2 STALE-OLD=0 EXTERNAL=0 RESOLVED=1 rc=1' \
   && [ "$RCB" -eq 1 ] && hasre "$T/l11l2.txt" 'PHANTOM +\[ZZ99\]' \
   && [ "$RCC" -eq 1 ] && hasre "$T/l11l3.txt" 'DROPPED +42 ' && hasre "$T/l11l3.txt" 'INVENTED +41 '; then
  ok "L11l ①②③ comment delimiters inside code spans / fences are literals: §404 and §405 between them DANGLE, a real comment and an unclosed one stay invisible; [ZZ99] between literals is PHANTOM; 42→41 between literals is DROPPED/INVENTED"
else
  no "L11l ①②③ comment delimiters in code" "sec rc=$RCA cit rc=$RCB num rc=$RCC"; dump "$T/l11l.txt" 10; dump "$T/l11l2.txt" 5; dump "$T/l11l3.txt" 6
fi
cat > "$T/s/slash.md" <<'EOF'
# 3 Top
## 3.1 First
Paired refs: §3.1/3.2 and §3.1/2 and §3/4 too.
EOF
cat > "$T/s/slash_ok.md" <<'EOF'
# 3 Top
## 3.1 First
## 3.2 Second
# 4 Four
Paired refs: §3.1/3.2 and §3.1/2 and §3/4 too.
EOF
sec "$T/l11m.txt" --body "$T/s/slash.md"; RCA=$RC
sec "$T/l11m2.txt" --body "$T/s/slash_ok.md" --show-resolved; RCB=$RC
if [ "$RCA" -eq 1 ] && [ "$(cntre "$T/l11m.txt" 'DANGLING +§3\.2 \(in §3\.1/(3\.2|2)\)')" -eq 2 ] && hasre "$T/l11m.txt" 'DANGLING +§4 \(in §3/4\)' \
   && has "$T/l11m.txt" 'refs=6 (4 distinct)' && has "$T/l11m.txt" 'DANGLING=3 STALE-OLD=0 EXTERNAL=0 RESOLVED=3 rc=1' \
   && [ "$RCB" -eq 0 ] && has "$T/l11m2.txt" 'RESOLVED=6 rc=0' && hasre "$T/l11m2.txt" 'resolved +§3\.2 \(in §3\.1/2\)'; then
  ok "L11m ③ slash refs: §3.1/3.2, §3.1/2 (sibling) and §3/4 name their second section — DANGLING when missing, resolved when present"
else
  no "L11m ③ slash refs" "rc=$RCA ok-rc=$RCB"; dump "$T/l11m.txt" 8; dump "$T/l11m2.txt" 8
fi
cat > "$T/s/bold.md" <<'EOF'
# 3 Top
## **3.1** Start
## *3.2* Middle
Refs §3.1 and §3.2 resolve.
EOF
cat > "$T/c/body_bq.md" <<'EOF'
Visible citation [MF22].

> | Key | Ref |
> | --- | --- |
> | [MF22] | Defined in a blockquoted table |
EOF
sec "$T/l11n.txt" --body "$T/s/bold.md"; RCA=$RC
cit "$T/l11n2.txt" --body "$T/c/body_bq.md"; RCB=$RC
if [ "$RCA" -eq 0 ] && has "$T/l11n.txt" 'RESOLVED=2 rc=0' && has "$T/l11n.txt" 'headings=3 (3 numbered anchors' \
   && [ "$RCB" -eq 0 ] && has "$T/l11n2.txt" '(1 definitions)' && has "$T/l11n2.txt" 'PHANTOM=0 ORPHAN=0 ' && has "$T/l11n2.txt" '(1 usages · 1 distinct keys)'; then
  ok "L11n ①③ emphasis around a heading number still numbers the heading; a blockquoted definitions table defines [MF22] (and its row is not a usage)"
else
  no "L11n ①③ bold heading / blockquote table" "sec rc=$RCA cit rc=$RCB"; dump "$T/l11n.txt" 6; dump "$T/l11n2.txt" 6
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# L11o — 🟥 codex round 7 (2026-09-18): a `<!--` inside a 4-space INDENTED code block or a `~~~` fence
#        opened a comment in v7 and erased the prose after it (§404 clean). v8: both are code in all
#        three tools; `~~~` fences also stop headings from defining and definition rows from defining.
# L11p — same round: a `| [KEY] |` row inside a code fence is code, not a definition — alone it is
#        «no table» (rc=10, loud), beside a real table the fenced-only key is PHANTOM.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
cat > "$T/s/indent.md" <<'EOF'
# 1 Anchor
Visible anchor resolves: §1.

    <!-- literal opener inside an indented code block
Visible prose after the indented block has dangling §404.
-->
~~~
<!-- literal opener inside a tilde fence
## 77 not a heading either
~~~
Visible prose after the tilde fence has dangling §405 and §77.
EOF
cat > "$T/c/body_indent.md" <<'EOF'
Valid [OK26].

    <!-- indented code
Visible [ZZ99] after it.

| [OK26] | row |
EOF
printf 'x\n\n    <!-- code\nvisible 42 here\n-->\n' > "$T/n/ind_before.md"; printf 'x\n\n    <!-- code\nvisible 41 here\n-->\n' > "$T/n/ind_after.md"
sec "$T/l11o.txt" --body "$T/s/indent.md"; RCA=$RC
cit "$T/l11o2.txt" --body "$T/c/body_indent.md"; RCB=$RC
num "$T/l11o3.txt" --before "$T/n/ind_before.md" --after "$T/n/ind_after.md"; RCC=$RC
if [ "$RCA" -eq 1 ] && hasre "$T/l11o.txt" 'DANGLING +§404 ' && hasre "$T/l11o.txt" 'DANGLING +§405 ' && hasre "$T/l11o.txt" 'DANGLING +§77 ' \
   && has "$T/l11o.txt" 'headings=1 (1 numbered anchors' && has "$T/l11o.txt" 'DANGLING=3 STALE-OLD=0 EXTERNAL=0 RESOLVED=1 rc=1' \
   && [ "$RCB" -eq 1 ] && hasre "$T/l11o2.txt" 'PHANTOM +\[ZZ99\]' \
   && [ "$RCC" -eq 1 ] && hasre "$T/l11o3.txt" 'DROPPED +42 ' && hasre "$T/l11o3.txt" 'INVENTED +41 '; then
  ok "L11o ①②③ indented code and ~~~ fences are code: prose after them survives (§404 §405 DANGLE, a ~~~-fenced heading does not define, §77 dangles); [ZZ99] after indented code is PHANTOM; 42→41 is DROPPED/INVENTED"
else
  no "L11o ①②③ indented code / tilde fence" "sec rc=$RCA cit rc=$RCB num rc=$RCC"; dump "$T/l11o.txt" 10; dump "$T/l11o2.txt" 5; dump "$T/l11o3.txt" 6
fi
cat > "$T/c/body_fencedef.md" <<'EOF'
Visible citation [MF22] has no real definition row.

```
| 키 | 서지 |
|---|---|
| [MF22] | This row is code, not a references-table definition |
```
EOF
cat > "$T/c/body_fencedef2.md" <<'EOF'
Visible citations [MF22] and [OK26].

~~~
| [MF22] | fenced row — code |
~~~

| [OK26] | real row |
EOF
cit "$T/l11p.txt" --body "$T/c/body_fencedef.md"; RCA=$RC
cit "$T/l11p2.txt" --body "$T/c/body_fencedef2.md"; RCB=$RC
if [ "$RCA" -eq 10 ] && has "$T/l11p.txt" '0 definition rows parsed' && has "$T/l11p.txt" 'NOT reported as phantom' \
   && [ "$RCB" -eq 1 ] && hasre "$T/l11p2.txt" 'PHANTOM +\[MF22\]' && has "$T/l11p2.txt" '(1 definitions)' && has "$T/l11p2.txt" 'PHANTOM=1 ORPHAN=0 '; then
  ok "L11p ① a fenced definition row does not define: alone → rc=10 «no table» (loud); beside a real table the fenced-only [MF22] is PHANTOM (rc=1)"
else
  no "L11p ① fenced definition row" "alone rc=$RCA with-table rc=$RCB"; dump "$T/l11p.txt" 4; dump "$T/l11p2.txt" 6
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# L11q — 🟥 codex round 8 (2026-09-18): a 4-tick fence is NOT closed by a 3-tick line (CommonMark:
#        closer ≥ opener, same char, nothing after it), and a fence inside a blockquote (`> ```) is still
#        a fence — v8 counted the rows after/inside as definitions and the headings as anchors. v9 routes
#        every fence decision through one _fence_step (kept identical in the three tools).
# L11r — same round: the slash side may carry a range — `§3.1/3.2-3.4` names §3.3 (interior) and §3.4.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
cat > "$T/c/body_4tick.md" <<'EOF'
Visible citation [MF22] and [OK26].

````
the next line is not a CommonMark closer
```
| [MF22] | still code — the 4-tick fence is open |
````

| [OK26] | real row |
EOF
cat > "$T/c/body_bqfence.md" <<'EOF'
Visible citation [MF22] and [OK26].

> ```
> | [MF22] | code inside a blockquoted fence |
> ```

| [OK26] | real row |
EOF
cat > "$T/s/fence9.md" <<'EOF'
# 1 Top
````
```
## 5 still inside the 4-tick fence — not a heading
````
> ~~~
> ## 6 inside a blockquoted tilde fence — not a heading
> ~~~
Visible refs §5 and §6 and §1.
EOF
cit "$T/l11q.txt" --body "$T/c/body_4tick.md"; RCA=$RC
cit "$T/l11q2.txt" --body "$T/c/body_bqfence.md"; RCB=$RC
sec "$T/l11q3.txt" --body "$T/s/fence9.md"; RCC=$RC
if [ "$RCA" -eq 1 ] && hasre "$T/l11q.txt" 'PHANTOM +\[MF22\]' && has "$T/l11q.txt" '(1 definitions)' \
   && [ "$RCB" -eq 1 ] && hasre "$T/l11q2.txt" 'PHANTOM +\[MF22\]' && has "$T/l11q2.txt" '(1 definitions)' \
   && [ "$RCC" -eq 1 ] && hasre "$T/l11q3.txt" 'DANGLING +§5 ' && hasre "$T/l11q3.txt" 'DANGLING +§6 ' && has "$T/l11q3.txt" 'headings=1 (1 numbered anchors' \
   && has "$T/l11q3.txt" 'DANGLING=2 STALE-OLD=0 EXTERNAL=0 RESOLVED=1 rc=1'; then
  ok "L11q ①③ fence fidelity: a 3-tick line does not close a 4-tick fence and a blockquoted fence is a fence — rows inside are not definitions ([MF22] PHANTOM beside the real table), headings inside do not define (§5 §6 DANGLE)"
else
  no "L11q ①③ fence fidelity" "4tick rc=$RCA bqfence rc=$RCB headings rc=$RCC"; dump "$T/l11q.txt" 6; dump "$T/l11q2.txt" 6; dump "$T/l11q3.txt" 8
fi
cat > "$T/s/slashrange.md" <<'EOF'
## 3.1 Good
## 3.2 Good
Visible refs §3.1/3.2-3.4 here.
EOF
cat > "$T/s/slashrange_ok.md" <<'EOF'
## 3.1 Good
## 3.2 Good
## 3.3 Good
## 3.4 Good
Visible refs §3.1/3.2-3.4 here.
EOF
sec "$T/l11r.txt" --body "$T/s/slashrange.md"; RCA=$RC
sec "$T/l11r2.txt" --body "$T/s/slashrange_ok.md" --show-resolved; RCB=$RC
if [ "$RCA" -eq 1 ] && hasre "$T/l11r.txt" 'DANGLING +§3\.3 \(interior of §3\.1/3\.2-3\.4\)' && hasre "$T/l11r.txt" 'DANGLING +§3\.4 ' \
   && has "$T/l11r.txt" 'refs=4 (4 distinct)' && has "$T/l11r.txt" 'DANGLING=2 STALE-OLD=0 EXTERNAL=0 RESOLVED=2 rc=1' \
   && [ "$RCB" -eq 0 ] && has "$T/l11r2.txt" 'RESOLVED=4 rc=0' && hasre "$T/l11r2.txt" 'resolved +§3\.3 \(interior of §3\.1/3\.2-3\.4\)'; then
  ok "L11r ③ slash + range: §3.1/3.2-3.4 names §3.2, §3.3 (interior) and §3.4 — DANGLING when missing, resolved when present"
else
  no "L11r ③ slash + range" "rc=$RCA ok-rc=$RCB"; dump "$T/l11r.txt" 8; dump "$T/l11r2.txt" 8
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# L11s — 🟥 codex round 9 (2026-09-18): `[mf22]` (case-mismatched key) was neither a usage nor MALFORMED
#        → clean; `§3.1 / 3.2` (spaces around the slash) read only §3.1. v10: case-mismatched key-shaped
#        elements are MALFORMED; the slash grammar allows whitespace.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
cat > "$T/c/body_lower.md" <<'EOF'
Visible citation [mf22] and [OK26].

| [MF22] | row | 
| [OK26] | row |
EOF
cat > "$T/s/spslash.md" <<'EOF'
## 3.1 First
Visible refs §3.1 / 3.2 here.
EOF
cit "$T/l11s.txt" --body "$T/c/body_lower.md"; RCA=$RC
sec "$T/l11s2.txt" --body "$T/s/spslash.md"; RCB=$RC
if [ "$RCA" -eq 1 ] && hasre "$T/l11s.txt" 'MALFORMED +\[mf22\]' && hasre "$T/l11s.txt" 'ORPHAN +\[MF22\]' && has "$T/l11s.txt" 'MALFORMED=1 rc=1' \
   && [ "$RCB" -eq 1 ] && hasre "$T/l11s2.txt" 'DANGLING +§3\.2 \(in §3\.1 / 3\.2\)' && has "$T/l11s2.txt" 'DANGLING=1 STALE-OLD=0 EXTERNAL=0 RESOLVED=1 rc=1'; then
  ok "L11s ①③ case-mismatched [mf22] is MALFORMED (its row [MF22] an ORPHAN); §3.1 / 3.2 with spaces names §3.2"
else
  no "L11s ①③ lowercase key / spaced slash" "cit rc=$RCA sec rc=$RCB"; dump "$T/l11s.txt" 6; dump "$T/l11s2.txt" 6
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# L11t — 🟥 codex round 10 (2026-09-18): `[BES26A]` (upper-case suffix) slipped past the case rule; and a
#        PLURAL prefix's list — `Sections 3.1 and 3.2` · `sections 3.1, 3.2 and 3.4-3.6` — named only its
#        first item. v11: suffix case is MALFORMED too; plural prefixes continue over , / and / & / 및
#        (each item through the range grammar); singular prefixes do not (`§3.1, 12 cases` names no §12).
# ═══════════════════════════════════════════════════════════════════════════════════════════════
cat > "$T/c/body_upsuf.md" <<'EOF'
Visible citation [BES26A] and [OK26].

| [BES26a] | row |
| [OK26] | row |
EOF
cat > "$T/s/plural.md" <<'EOF'
## 3.1 First
## 3.4 Fourth
## 3.6 Sixth
## 12 Twelve
Sections 3.1 and 3.2 are here; sections 3.1, 3.2 and 3.4-3.6 too; but §3.1, 12 cases is not a list.
EOF
cit "$T/l11t.txt" --body "$T/c/body_upsuf.md"; RCA=$RC
sec "$T/l11t2.txt" --body "$T/s/plural.md" --show-resolved; RCB=$RC
if [ "$RCA" -eq 1 ] && hasre "$T/l11t.txt" 'MALFORMED +\[BES26A\]' && has "$T/l11t.txt" 'MALFORMED=1 rc=1' \
   && [ "$RCB" -eq 1 ] && [ "$(cntre "$T/l11t2.txt" 'DANGLING +§3\.2 \(in [Ss]ections 3\.1')" -eq 2 ] && hasre "$T/l11t2.txt" 'DANGLING +§3\.5 \(interior of' \
   && hasre "$T/l11t2.txt" 'resolved +§3\.4 \(in sections 3\.1, 3\.2 and 3\.4\)' && hasre "$T/l11t2.txt" 'resolved +§3\.6 ' \
   && [ "$(cntre "$T/l11t2.txt" 'resolved +§12 ')" -eq 0 ] && has "$T/l11t2.txt" 'DANGLING=3 STALE-OLD=0 EXTERNAL=0 RESOLVED=5 rc=1'; then
  ok "L11t ①③ [BES26A] is MALFORMED; plural lists continue — Sections 3.1 and 3.2 / sections 3.1, 3.2 and 3.4-3.6 name §3.2 (×2), §3.4, §3.5 (interior), §3.6; the singular §3.1, 12 names no §12"
else
  no "L11t ①③ upper suffix / plural continuation" "cit rc=$RCA sec rc=$RCB"; dump "$T/l11t.txt" 6; dump "$T/l11t2.txt" 12
fi

# L11u — 🟥 codex round 11 (2026-09-18): `Sections 3.1-3.3 and 3.4` — a plural list whose FIRST item is a
#        range stopped after the range; v12 continues the list after a range item too.
cat > "$T/s/plural2.md" <<'EOF'
## 3.1 A
## 3.2 B
## 3.3 C
Sections 3.1-3.3 and 3.4 here; §3.1-3.3 and 12 is singular.
EOF
sec "$T/l11u.txt" --body "$T/s/plural2.md" --show-resolved
if [ "$RC" -eq 1 ] && hasre "$T/l11u.txt" 'DANGLING +§3\.4 \(in Sections 3\.1-3\.3 and 3\.4\)' && hasre "$T/l11u.txt" 'resolved +§3\.2 \(interior of' \
   && [ "$(cntre "$T/l11u.txt" '(DANGLING|resolved) +§12 ')" -eq 0 ] && has "$T/l11u.txt" 'DANGLING=1 STALE-OLD=0 EXTERNAL=0 RESOLVED=6 rc=1'; then
  ok "L11u ③ a plural list continues after a range item: Sections 3.1-3.3 and 3.4 names §3.4 (DANGLING); the singular §3.1-3.3 and 12 names no §12"
else
  no "L11u ③ plural list after a range" "rc=$RC"; dump "$T/l11u.txt" 10
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# L11v — 🟥 codex round 12 (2026-09-18): the Oxford comma — `Sections 3.1-3.3, and 3.4` · `Sections 3.1, and 3.2`
#        — broke the plural list. v13: `, and` / `, &` / `, 및` are separators too.
# L11w — same round, ② had had no MAJOR since round 1: `2e6`→`2e5` and `10⁶`→`10⁵` reduced to the same token
#        (`2` · `10`) and read IDENTICAL. v13: an exponent is part of the number (`2e6` · `2.5e-3` · `10^6` ·
#        superscripts via NFKC-style map), and `2e-3` is no longer blanked as a letter-bearing hyphen chain.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
cat > "$T/s/oxford.md" <<'EOF'
## 3.1 A
## 3.2 B
## 3.3 C
Sections 3.1-3.3, and 3.4 here; Sections 3.1, and 3.5 too.
EOF
sec "$T/l11v.txt" --body "$T/s/oxford.md"
if [ "$RC" -eq 1 ] && hasre "$T/l11v.txt" 'DANGLING +§3\.4 \(in Sections 3\.1-3\.3, and 3\.4\)' && hasre "$T/l11v.txt" 'DANGLING +§3\.5 \(in Sections 3\.1, and 3\.5\)' \
   && has "$T/l11v.txt" 'DANGLING=2 STALE-OLD=0 EXTERNAL=0 RESOLVED=4 rc=1'; then
  ok "L11v ③ Oxford comma: Sections 3.1-3.3, and 3.4 / Sections 3.1, and 3.5 name §3.4 and §3.5"
else
  no "L11v ③ Oxford comma" "rc=$RC"; dump "$T/l11v.txt" 8
fi
printf 'budget 2e6 samples, rate 2.5e-3, load 10⁶, 10⁻³ and 3×10^4; identifier v2e is text.\n' > "$T/n/exp_before.md"
printf 'budget 2e5 samples, rate 2.5e-3, load 10⁵, 10⁻³ and 3×10^4; identifier v2e is text.\n' > "$T/n/exp_after.md"
num "$T/l11w.txt" --before "$T/n/exp_before.md" --after "$T/n/exp_after.md"; RCA=$RC
num "$T/l11w2.txt" --before "$T/n/exp_before.md" --after "$T/n/exp_before.md"; RCB=$RC
if [ "$RCA" -eq 1 ] && hasre "$T/l11w.txt" 'DROPPED +2e6 ' && hasre "$T/l11w.txt" 'INVENTED +2e5 ' && hasre "$T/l11w.txt" 'DROPPED +10\^6 ' && hasre "$T/l11w.txt" 'INVENTED +10\^5 ' \
   && has "$T/l11w.txt" 'DROPPED=2 ' && [ "$RCB" -eq 0 ] && has "$T/l11w2.txt" 'IDENTICAL' && has "$T/l11w2.txt" '6 tokens'; then
  ok "L11w ② exponents are part of the number: 2e6→2e5 and 10⁶→10⁵ are DROPPED/INVENTED (2.5e-3 · 10⁻³ · 3×10^4 stable); identity = 6 tokens, rc=0"
else
  no "L11w ② exponents" "diff rc=$RCA identity rc=$RCB"; dump "$T/l11w.txt" 8; dump "$T/l11w2.txt" 4
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# L11x — 🟥 codex round 13 (2026-09-18): ① `[AB24 & ZZ99]` split only on , ; → the second key vanished;
#        ③ `Sections 3.1; 3.2; 3.3` · `Sections 4.1 or 4.2` · `Sections 6.1 through 6.3` were outside the
#        list / range grammar. v14: `&` and ` and ` split grouped citations; `;` / `or` join plural lists;
#        `through` / `thru` / `to` are prose range separators (interiors expand like `–`).
# ═══════════════════════════════════════════════════════════════════════════════════════════════
cat > "$T/c/body_amp.md" <<'EOF'
Grouped [AB24 & ZZ99] and [AB24 and OK26].

| [AB24] | row |
| [OK26] | row |
EOF
cat > "$T/s/prose.md" <<'EOF'
## 3.1 A
## 3.2 B
## 4.1 C
## 6.1 D
## 6.3 E
Sections 3.1; 3.2; 3.3 here. Sections 4.1 or 4.2 there. Sections 6.1 through 6.3 and §6.1 to 6.3 too.
EOF
cit "$T/l11x.txt" --body "$T/c/body_amp.md"; RCA=$RC
sec "$T/l11x2.txt" --body "$T/s/prose.md" --show-resolved; RCB=$RC
if [ "$RCA" -eq 1 ] && hasre "$T/l11x.txt" 'PHANTOM +\[ZZ99\]' && has "$T/l11x.txt" '(4 usages · 3 distinct keys)' \
   && [ "$RCB" -eq 1 ] && hasre "$T/l11x2.txt" 'DANGLING +§3\.3 \(in Sections 3\.1; 3\.2; 3\.3\)' && hasre "$T/l11x2.txt" 'DANGLING +§4\.2 \(in Sections 4\.1 or 4\.2\)' \
   && [ "$(cntre "$T/l11x2.txt" 'DANGLING +§6\.2 \(interior of (Sections 6\.1 through 6\.3|§6\.1 to 6\.3)\)')" -eq 2 ] \
   && has "$T/l11x2.txt" 'DANGLING=4 STALE-OLD=0 EXTERNAL=0 RESOLVED=7 rc=1'; then
  ok "L11x ①③ [AB24 & ZZ99] names both keys ([ZZ99] PHANTOM); ';' / 'or' join plural lists (§3.3 §4.2 DANGLE); 'through' / 'to' are ranges (§6.2 interior ×2)"
else
  no "L11x ①③ ampersand keys / prose lists and ranges" "cit rc=$RCA sec rc=$RCB"; dump "$T/l11x.txt" 6; dump "$T/l11x2.txt" 14
fi

# L11y — 🟥 codex round 14 (2026-09-18): shorthand ranges — `Sections 3.1-3` (bare-integer second end = sibling
#        3.1–3.3) and `§3.2a-c` (suffix-only second end) named only the first endpoint. v15 infers both.
cat > "$T/s/short.md" <<'EOF'
## 3.1 A
## 3.3 C
### 3.2a X
Sections 3.1-3 here; §3.2a-c there; §3.1–3 too; but §3.1~§12 is not a sibling.
EOF
sec "$T/l11y.txt" --body "$T/s/short.md" --show-resolved
if [ "$RC" -eq 1 ] && [ "$(cntre "$T/l11y.txt" 'DANGLING +§3\.2 \(interior of (Sections 3\.1-3|§3\.1–3)\)')" -eq 2 ] && hasre "$T/l11y.txt" 'DANGLING +§3\.2b \(interior of §3\.2a-c\)' \
   && hasre "$T/l11y.txt" 'DANGLING +§3\.2c ' && hasre "$T/l11y.txt" 'DANGLING +§12 ' && hasre "$T/l11y.txt" 'DANGLING +§3\.1~§12 \(interior UNCHECKED: mixed form' && [ "$(cntre "$T/l11y.txt" 'resolved +§3\.3 ')" -eq 2 ] \
   && has "$T/l11y.txt" 'DANGLING=6 STALE-OLD=0 EXTERNAL=0 RESOLVED=6 rc=1'; then
  ok "L11y ③ shorthand ranges: Sections 3.1-3 and §3.1–3 expand as 3.1–3.3 (§3.2 interior ×2); §3.2a-c names §3.2b and §3.2c; §3.1~§12 (explicit §) stays a top-level end and its mixed form is an UNCHECKED row"
else
  no "L11y ③ shorthand ranges" "rc=$RC"; dump "$T/l11y.txt" 14
fi

# L11z — 🟥 codex round 15 (2026-09-18): the shorthand of round 14 was read by the PRIMARY ref only —
#        `§3.1/3.2a-c` and `Sections 3.1, 3.2a-c` named just §3.2a. v16: one shared range tail for the
#        primary ref, the slash continuation and the plural continuation.
cat > "$T/s/short2.md" <<'EOF'
## 3.1 A
### 3.2a X
§3.1/3.2a-c here; Sections 3.1, 3.2a-c there; sections 3.1; 3.2-4 too.
EOF
sec "$T/l11z.txt" --body "$T/s/short2.md" --show-resolved
if [ "$RC" -eq 1 ] && [ "$(cntre "$T/l11z.txt" 'DANGLING +§3\.2b \(interior of (§3\.1/3\.2a-c|Sections 3\.1, 3\.2a-c)\)')" -eq 2 ] && [ "$(cntre "$T/l11z.txt" 'DANGLING +§3\.2c ')" -eq 2 ] \
   && hasre "$T/l11z.txt" 'DANGLING +§3\.3 \(interior of sections 3\.1; 3\.2-4\)' && hasre "$T/l11z.txt" 'DANGLING +§3\.4 ' \
   && has "$T/l11z.txt" 'DANGLING=7 STALE-OLD=0 EXTERNAL=0 RESOLVED=5 rc=1'; then
  ok "L11z ③ shorthand in every position: §3.1/3.2a-c and Sections 3.1, 3.2a-c name §3.2b·§3.2c; sections 3.1; 3.2-4 names §3.3·§3.4"
else
  no "L11z ③ shorthand in continuations" "rc=$RC"; dump "$T/l11z.txt" 14
fi

# L11aa — 🟥 codex round 16 (2026-09-18): ① `[AB24、ZZ99]` (ideographic comma) was one ignored element; ② `92.6％`
#         (full-width percent) → `92.6` read IDENTICAL; ③ prose `appendix k.2` was skipped. v17: `、` splits groups,
#         ② NFKC-normalizes each line before extraction, ③ a lower-case appendix letter keys as its upper-case heading.
cat > "$T/c/body_ideo.md" <<'EOF'
Grouped [AB24、ZZ99] here.

| [AB24] | row |
EOF
printf '%s\n' 'rate 92.6％ and ９２.６％ and 2,880 and 10⁶' > "$T/n/fw_before.md"; printf '%s\n' 'rate 92.6 and 92.6% and 2880 and 10⁶' > "$T/n/fw_after.md"
cat > "$T/s/lowapp.md" <<'EOF'
## Appendix K
### K.2 sub
See §2 and appendix k.2 and appendix k.9 here.
## 2 Two
EOF
cit "$T/l11aa.txt" --body "$T/c/body_ideo.md"; RCA=$RC
num "$T/l11aa2.txt" --before "$T/n/fw_before.md" --after "$T/n/fw_after.md"; RCB=$RC
sec "$T/l11aa3.txt" --body "$T/s/lowapp.md" --show-resolved; RCC=$RC
if [ "$RCA" -eq 1 ] && hasre "$T/l11aa.txt" 'PHANTOM +\[ZZ99\]' \
   && [ "$RCB" -eq 1 ] && hasre "$T/l11aa2.txt" 'REDUCED +92\.6% ' && hasre "$T/l11aa2.txt" 'INVENTED +92\.6 ' && ! hasre "$T/l11aa2.txt" '(DROPPED|INVENTED) +(2880|10\^6) ' \
   && [ "$RCC" -eq 1 ] && hasre "$T/l11aa3.txt" 'resolved +appendix k\.2 ' && hasre "$T/l11aa3.txt" 'DANGLING +appendix k\.9 '; then
  ok "L11aa ①②③ ideographic-comma groups split ([ZZ99] PHANTOM); full-width digits/％ normalize (92.6％×2 → REDUCED, 92.6 INVENTED; 2,880≡2880 and 10⁶ stable); appendix k.2 resolves to K.2 and k.9 dangles"
else
  no "L11aa ①②③ ideographic comma / full-width percent / lowercase appendix" "cit rc=$RCA num rc=$RCB sec rc=$RCC"; dump "$T/l11aa.txt" 5; dump "$T/l11aa2.txt" 8; dump "$T/l11aa3.txt" 8
fi

# L11ab — 🟥 codex round 17 (2026-09-18) — the sidecar hit its usage quota mid-round and left 8 fixtures unreported;
#         the author ran them. Silent: `Appendix K.1-K.3` resolved its ends and never named K.2. Loud-but-wrong:
#         `[AB24 · ZZ99]` (middle dot) read as no citation (rc=4); `Appendix Ｋ` full-width read as no ref / no
#         heading. v18: letter-appendix ranges expand; `·` splits groups; full-width ASCII maps per character.
cat > "$T/s/apprange.md" <<'EOF'
## Appendix K
### K.1 Setup
### K.3 Results
## Appendix Ｍ
See Appendix K.1-K.3 and K.1–3 here; Appendix Ｍ and Appendix Ｋ too; K.1-M.3 is mixed.
EOF
cat > "$T/c/body_mdot.md" <<'EOF'
Grouped [AB24 · ZZ99] here.

| [AB24] | row |
EOF
sec "$T/l11ab.txt" --body "$T/s/apprange.md" --show-resolved; RCA=$RC
cit "$T/l11ab2.txt" --body "$T/c/body_mdot.md"; RCB=$RC
if [ "$RCA" -eq 1 ] && [ "$(cntre "$T/l11ab.txt" 'DANGLING +K\.2 \(interior of (Appendix K\.1-K\.3|K\.1–3)\)')" -eq 2 ] && hasre "$T/l11ab.txt" 'resolved +Appendix M ' && hasre "$T/l11ab.txt" 'resolved +Appendix K ' \
   && ! hasre "$T/l11ab.txt" 'M\.2 ' && has "$T/l11ab.txt" 'DANGLING=3 STALE-OLD=0 EXTERNAL=0 RESOLVED=8 rc=1' \
   && [ "$RCB" -eq 1 ] && hasre "$T/l11ab2.txt" 'PHANTOM +\[ZZ99\]'; then
  ok "L11ab ①③ Appendix K.1-K.3 and K.1–3 name the interior K.2 (once each — Appendix K.1 is one ref); full-width Appendix Ｍ/Ｋ resolve; K.1-M.3 expands no interior; [AB24 · ZZ99] names both keys"
else
  no "L11ab ①③ appendix letter ranges / full-width / middle dot" "sec rc=$RCA cit rc=$RCB"; dump "$T/l11ab.txt" 12; dump "$T/l11ab2.txt" 5
fi

# L11ac — 🟥 the eighth round-17 fixture, run by the author after the quota cut: `−196 degrees` → `196 degrees`
#         read IDENTICAL in v1–v18 — and the header DOCUMENTED it («a bare negative sign is dropped»). Documented
#         is not loud: the reader sees the sign. v19: a sign glued to the number (ASCII `-` · U+2212 `−` ·
#         U+2013 `–`) is part of the token when nothing word-like precedes it; `3-5` / `12–25` stay ranges,
#         `- 196` stays a list marker, `…-00191-3` (a truncated DOI in the real paper) stays `00191`.
#         Revert probe: the `--no-sign` arm and a `no_sign` mutant both read the pair IDENTICAL again.
printf 'was −196 degrees, offset -3 units, (−0.5) and –7°C; range 3-5 and 12–25; p=-2 odd; DOI …-00191-3\n- 196 list item\nx-5 ident, 2026-09-10 date, 10⁻³ exp\n' > "$T/n/sign_before.md"
printf 'was 196 degrees, offset 3 units, (0.5) and 7°C; range 3-5 and 12–25; p=-2 odd; DOI …-00191-3\n- 196 list item\nx-5 ident, 2026-09-10 date, 10⁻³ exp\n' > "$T/n/sign_after.md"
num "$T/l11ac.txt" --before "$T/n/sign_before.md" --after "$T/n/sign_after.md"; RCA=$RC
num "$T/l11ac2.txt" --before "$T/n/sign_before.md" --after "$T/n/sign_before.md"; RCB=$RC
num "$T/l11ac3.txt" --before "$T/n/sign_before.md" --after "$T/n/sign_after.md" --no-sign; RCC=$RC
mutate "$NUM" "$T/num_mutant_sign.py" no_sign
if [ $? -ne 0 ] || [ "$(cnt "$T/num_mutant_sign.py" 'MUTANT: no_sign')" -ne 1 ]; then
  no "L11ac ② sign mutant" "mutation failed"; dump "$T/mut.txt"
else
  run "$T/l11ac4.txt" "$T/num_mutant_sign.py" --before "$T/n/sign_before.md" --after "$T/n/sign_after.md"; RCD=$RC
  if [ "$RCA" -eq 1 ] && hasre "$T/l11ac.txt" 'DROPPED +-196 ' && hasre "$T/l11ac.txt" 'DROPPED +-3 ' && hasre "$T/l11ac.txt" 'DROPPED +-0\.5 ' && hasre "$T/l11ac.txt" 'DROPPED +-7 ' \
     && hasre "$T/l11ac.txt" 'INVENTED +7 ' && ! hasre "$T/l11ac.txt" ' -00191' && ! hasre "$T/l11ac.txt" 'DROPPED +5 ' && ! hasre "$T/l11ac.txt" 'DROPPED +25 ' \
     && has "$T/l11ac.txt" 'sign=on' && has "$T/l11ac.txt" 'DROPPED=4 REDUCED=0 INVENTED=2 INCREASED=2 ALLOWED=0 rc=1' \
     && [ "$RCB" -eq 0 ] && has "$T/l11ac2.txt" 'IDENTICAL' && has "$T/l11ac2.txt" '14 tokens' \
     && [ "$RCC" -eq 0 ] && has "$T/l11ac3.txt" 'sign=off' && has "$T/l11ac3.txt" 'IDENTICAL' \
     && [ "$RCD" -eq 0 ] && has "$T/l11ac4.txt" 'IDENTICAL'; then
    ok "L11ac ② a glued sign is part of the number: −196/-3/(−0.5)/–7 → unsigned are DROPPED+INVENTED rc=1 (3-5 · 12–25 ranges, - 196 list, …-00191-3 DOI untouched); identity 14 tokens rc=0; --no-sign arm and no_sign mutant read IDENTICAL again (rc=0)"
  else
    no "L11ac ② glued sign" "diff rc=$RCA identity rc=$RCB no-sign rc=$RCC mutant rc=$RCD"; dump "$T/l11ac.txt" 12; dump "$T/l11ac2.txt" 3; dump "$T/l11ac3.txt" 3; dump "$T/l11ac4.txt" 3
  fi
fi

echo
echo "── $pass passed, $fail failed ──"
[ "$fail" -eq 0 ] || exit 1
exit 0

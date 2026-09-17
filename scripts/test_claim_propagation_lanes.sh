#!/usr/bin/env bash
# test_claim_propagation_lanes.sh — known pairs + revert probes for scripts/claim_propagation_scan.py
#
# WHY LANES ON FIXTURES, NOT ON GIT HISTORY
#   The prototype's known pair was «the tree before PR #743» vs «the tree after». A lane that ran
#   `git archive <sha>~1` would be dead in a consumer install (shallow clone, no history) and would
#   silently drift with every later edit of CLAUDE.md. So both arms are RECONSTRUCTED here as
#   fixture files in mktemp — L2 carries the pre-retraction sentences, L3 the post-retraction ones,
#   copied byte-for-byte from the two trees (fixture shape from the artifact, not a mental model).
#   🟥 The figures in the L2 fixture («2.7 %–13.6 %», «five review arms», «5팔») are the RETRACTED
#   ones, reproduced on purpose as a known-positive — they are not a claim. RETRACTED 2026-09-17.
#   That is also why this file is in the scanner's default FIXTURE class (`scripts/test_*_lanes.sh`):
#   scanned with `--paths scripts` it is 32 would-be-LIVE sites by construction.
#
# THE TWO-SIGNALS RULE
#   A 0 on the known-negative is evidence only if the tokens were SEEN — so L3 asserts bare>0 AND
#   live=0 (RETRACTION-CONTEXT>0), and L8 is the separate «token absent» control: bare=0, rc=0, and
#   NOT rc=4 (dead control is a different value on purpose).
#
# REVERT PROBES (a mechanism is load-bearing only if removing it turns a known pair red)
#   L7  ⓑ retraction context  · L11 NFKC normalization · L12 excluded-class CLASSIFICATION (vs the
#   first version's corpus cut, which hid a live claim in an excluded file — cross-family review).
#   Each mutates a COPY of the scanner by source edit, checks the copy goes red, and byte-compares
#   the original before and after.
#
# 🟥 PITFALL (this repo's lanes): `out="$(run …)"` runs the function in a SUBSHELL, so `RC=$?`
#   after it is the assignment's status, not the scanner's. Every lane here redirects the scanner's
#   output to a file and reads `$?` directly. No `cmd | grep -q` either (SIGPIPE under pipefail).
#   And no backtick inside a double-quoted lane message — a backtick pair there EXECUTES.
#
# Usage:  bash scripts/test_claim_propagation_lanes.sh        (PATH=<interp-dir>:$PATH to pin an interpreter — a $PY invoker is unreadable to new_code_anchor_check.sh)
# Exit:   0 = every lane passed · 1 = a lane failed (or the instrument itself broke)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCAN="$HERE/claim_propagation_scan.py"
PY=python3   # 🟥 literal on purpose: the new-code-anchor gate reads a literal invoker, and a `"$PY"` invoker scored MENTION_ONLY on CI (PR #748). Interpreter override = PATH, not a variable
pass=0; fail=0
ok(){ pass=$((pass+1)); printf '  ✅ PASS %s\n' "$1"; }
no(){ fail=$((fail+1)); printf '  ❌ FAIL %s — %s\n' "$1" "${2:-}"; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

# run <outfile> <scanner args…>  — sets RC (global). Never call inside $( ).
RC=0
run(){ local out="$1"; shift; python3 "$SCAN" "$@" >"$out" 2>&1; RC=$?; }
# runwith <scanner.py> <outfile> <args…> — same, for a mutant copy
runwith(){ local s="$1" out="$2"; shift 2; "$PY" "$s" "$@" >"$out" 2>&1; RC=$?; }
live_n(){ grep -c '🟥 LIVE' "$1"; }                      # prints 0 when none (grep rc ignored)
has(){ grep -q -- "$2" "$1"; }                             # has <file> <needle>
# mutate <copy.py> <anchor-line-stripped> <line-to-insert-after> — exact-once anchor, else fails loudly
mutate(){
  "$PY" - "$1" "$2" "$3" <<'PY'
import sys
p, anchor, ins = sys.argv[1], sys.argv[2], sys.argv[3]
L = open(p, encoding="utf-8").read().split("\n")
idx = [k for k, l in enumerate(L) if l.strip() == anchor]
assert len(idx) == 1, "mutation anchor %r found %d times, expected exactly once" % (anchor, len(idx))
indent = L[idx[0]][:len(L[idx[0]]) - len(L[idx[0]].lstrip())]
L.insert(idx[0] + 1, indent + ins)
open(p, "w", encoding="utf-8").write("\n".join(L))
PY
}

echo "── test_claim_propagation_lanes ──  ($("$PY" --version 2>&1))"

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# L1 — syntax + --help
# ═══════════════════════════════════════════════════════════════════════════════════════════════
[ -f "$SCAN" ] || { no "L1 subject present" "$SCAN missing"; echo "── 0 passed, 1 failed ──"; exit 1; }
"$PY" -c "import ast,sys;ast.parse(open(sys.argv[1],encoding='utf-8').read())" "$SCAN" >"$T/l1a.txt" 2>&1 \
  && ok "L1a syntax (ast.parse)" || no "L1a syntax" "$(head -3 "$T/l1a.txt")"
run "$T/l1b.txt" --help
if [ "$RC" -eq 0 ] && has "$T/l1b.txt" "EXIT CODES" && has "$T/l1b.txt" -- "--exclude" && has "$T/l1b.txt" "OUT OF SCOPE" \
   && has "$T/l1b.txt" "EXCLUDED-FILE" && has "$T/l1b.txt" -- "--no-nfkc"; then
  ok "L1b --help rc=0: rc contract · --exclude · prose-claim scope limit · EXCLUDED-FILE semantics · --no-nfkc"
else
  no "L1b --help" "rc=$RC"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# FIXTURES
# ═══════════════════════════════════════════════════════════════════════════════════════════════
# claims — the five-arm retraction, anchors taken from the retraction record's own wording
ANCH='arms?|팔|error[- ]?rates?|오류율|claim[- ]?error|최저|최고|five|다섯|B-1|dominance'
{
  printf '# token\tanchor-regex\tsource\n'
  printf '2.7 %%\t%s\tgovernance_engineering_definition.md §첫 실증 2026-09-17\n' "$ANCH"
  printf '13.6 %%\t%s\tgovernance_engineering_definition.md §첫 실증 2026-09-17\n' "$ANCH"
  printf 'five arms\t\t(팔은 넷)\n'
  printf 'five review arms\t\t(팔은 넷)\n'
  printf 'five-arm\t\t(팔은 넷)\n'
  printf '다섯 팔\t\t(팔은 넷)\n'
  printf '5팔\t\t(팔은 넷)\n'
  printf '다섯 개 전부\t\t(위 넷이 전부)\n'
} > "$T/claims_five_arms.tsv"

# POS — pre-#743 tree, verbatim: CLAUDE.md:44 (table row) · CLAUDE.md:809-814 (paragraph) ·
#       governance_engineering_definition.md §첫 실증 · the dispatch-log RECORD line.
mkdir -p "$T/pos/knowledge/shared/harness-core" "$T/pos/knowledge/shared/learnings"
cat > "$T/pos/CLAUDE.md" <<'EOF'
# fixture — resident layer BEFORE the retraction (reconstructed from the pre-#743 tree)

| **Core Axis** | **Harness Engineering (How)** — the methodology and practice axis that realizes the three layers above. The 6-axis framework is the operating unit. **A harness is a means, not an end** — Field harness: "simpler over time" (complexity = warning signal). Meta-harness: *optimize*, not necessarily simplify — complexity earns its scope; red flags are orphaned, redundant, and decorative units, not complexity itself.<br>**And what it is a means *to* is Governance Engineering (What for)** — 🐿️ *«수치를 목표로 움직이되, 그 수치가 게이트를 열지는 않는다»*: drive the error rate toward 0.x% **and** hold the surfaces where no number buys passage. Two verbs, and the second one carries the load — drop it and the discipline decays into "lower the number and the gate opens", which §Irreversibility Gates forbids by name. Measured content, not a slogan: five review arms ran **2.7 %–13.6 %** claim-error on the same eight cases — every one usable on a review surface, **not one** usable on publish/delete/rewrite. That distance is why this axis exists. Canon: `governance_engineering_definition.md` (operator formulation 2026-09-09; the term exists in IT/data governance — what is ours is the referent, and an outbound claim of novelty owes a stated delta, never mere absence of prior use). | `harness_6axis_framework.md` · `hub_compounding_loop.md` · `claude_code_runtime_flow.md` · `plugins/*/agents/` (sub-agents) |

**Surface class sets the error budget, not only the degrade direction** (operator decision 2026-09-08).
The same automated verdict engine is usable on one surface and not on another, and the discriminator is
what a wrong verdict costs. Measured that day across five review arms on the same eight cases: claim
error rates ran **2.7 % – 13.6 %**, and every one of them is usable *on a review surface*, because a
wrong finding costs a reader a minute. On publish · delete · history-rewrite there is no "costs a
minute": the wrong call is the whole loss. 🟥 **So an automated verdict never clears an irreversible
gate on its own, however good its measured rate** — it feeds a fail-closed gate whose terminal step
stays a human or an explicit logged override.
EOF
cat > "$T/pos/knowledge/shared/harness-core/governance_engineering_definition.md" <<'EOF'
## 첫 실증 내용 (이 이름이 비어 있지 않다는 근거)

2026-09-08 dominance B-1 본 실행, 5팔 × GHSA 8케이스 × 3rep, 축② 주장 오류율:

```
O   octo 4자          2.7%      ← 최저
F_xf cross-family     5.3%
F   FH 기본           9.6%
N   맨몸              9.7%
F_slim 리뷰프로파일   13.6%     ← 최고
```

**다섯 개 전부 리뷰 표면에서는 쓸 만하다** — 틀린 지적 하나가 독자의 1분을 쓴다.
**다섯 개 전부 비가역 표면에서는 못 쓴다** — 발행·삭제·이력재작성에서 틀린 판정은 손실 전체다.
이 두 문장 사이의 거리가 거버넌스 엔지니어링이 존재하는 이유다. 0.x% 는 **아직 아무도 낸 적 없는
수치**이고(최저가 2.7%), 그래서 «목표»이지 «달성»이 아니다.
EOF
cat > "$T/pos/knowledge/shared/learnings/subagent_invocations_log.yaml" <<'EOF'
- date: 2026-09-08
  agent: codex · 사이드카 adversarial/verifier
  purpose: "① 게이트 트리거 넓힘 교리 5R 수렴 ② 논문 v1.2.2 §6.7 6R 수렴(SHIP 판정) ③ recall 재검증 45런 조건 블라인드 채점 ④ B-1 5팔 채점(축①③ keyed · 축② unkeyed) ⑤ typed-finding 파이프라인의 검증기·감사기"
  outcome: accepted
EOF

# NEG — the SAME tokens after the retraction, verbatim from today's tree: CLAUDE.md:44 (`replaced` /
#       `the earlier` euphemisms) · CLAUDE.md:809-816 (`RETRACTED`) · governance §첫 실증 (`초판`,
#       `철회`, fence caption `철회됨`) · the `초판은 …(최저가 2.7%)` sentence · a padded fence whose
#       caption is the only marker and sits >200 chars above the figure (exercises the caption branch).
mkdir -p "$T/neg/knowledge/shared/harness-core"
cat > "$T/neg/CLAUDE.md" <<'EOF'
# fixture — resident layer AFTER the retraction (today's tree)

| **Core Axis** | **Harness Engineering (How)** — the methodology and practice axis that realizes the three layers above. The 6-axis framework is the operating unit. **A harness is a means, not an end** — Field harness: "simpler over time" (complexity = warning signal). Meta-harness: *optimize*, not necessarily simplify — complexity earns its scope; red flags are orphaned, redundant, and decorative units, not complexity itself.<br>**And what it is a means *to* is Governance Engineering (What for)** — 🐿️ *«수치를 목표로 움직이되, 그 수치가 게이트를 열지는 않는다»*: drive the error rate toward 0.x% **and** hold the surfaces where no number buys passage. Two verbs, and the second one carries the load — drop it and the discipline decays into "lower the number and the gate opens", which §Irreversibility Gates forbids by name. Measured content, not a slogan — 🟥 **and the numbers were replaced 2026-09-17** (the earlier «five arms, 2.7 %–13.6 %» came from a scorer since found defective — it counted our own mandated defeater paragraphs as defect claims and dropped ~half of all claims out of the denominator — and it is **not re-scorable**, structurally): **four** arms ran **0.0 %–1.1 %** claim-error on the same eight cases, 95 % upper bound ≈2.1 %, and **no contrast separates** after cluster correction, so it is a spectrum and not a ranking. Every one usable on a review surface, **not one** usable on publish/delete/rewrite — and that holds *now that the point estimate is inside 0.x%*, which is the first time the second verb is testable rather than vacuous. That distance is why this axis exists. Canon: `governance_engineering_definition.md` (operator formulation 2026-09-09; the term exists in IT/data governance — what is ours is the referent, and an outbound claim of novelty owes a stated delta, never mere absence of prior use). | `harness_6axis_framework.md` · `hub_compounding_loop.md` · `claude_code_runtime_flow.md` · `plugins/*/agents/` (sub-agents) |

**Surface class sets the error budget, not only the degrade direction** (operator decision 2026-09-08).
The same automated verdict engine is usable on one surface and not on another, and the discriminator is
what a wrong verdict costs. Measured across **four** review arms on the same eight cases — 🟥 **the
earlier «five arms, 2.7 % – 13.6 %» from this date is RETRACTED (2026-09-17): the scorer was found
defective and replaced, and the old run is structurally not re-scorable. Canon:
`governance_engineering_definition.md` §첫 실증** — claim error rates ran **0.0 % – 1.1 %** (95 %
upper bound ≈2.1 %; **no contrast separates** after cluster correction, so it is a spectrum and not
a ranking), and every one of them is usable *on a review surface*, because a
wrong finding costs a reader a minute.
EOF
cat > "$T/neg/knowledge/shared/harness-core/governance_engineering_definition.md" <<'EOF'
## 첫 실증 내용 (이 이름이 비어 있지 않다는 근거)

🟥 **이 절의 초판이 인용한 5팔 표(2.7 %–13.6 %)를 2026-09-17 에 철회한다 — «낡아서»가 아니라
«그 수를 만든 자가 결함으로 판정되고 교체됐기» 때문이다.** 지우지 않고 아래에 남긴다(무엇이
인용됐었는지가 기록이다):

```
철회됨 — B-1 산문 채점 (2026-09-08)
O   octo 4자          2.7%
F_xf cross-family     5.3%
F   FH 기본           9.6%
N   맨몸              9.7%
F_slim 리뷰프로파일   13.6%
```

초판은 *"0.x% 는 아직 아무도 낸 적 없는 수치이고(최저가 2.7%), 그래서 «목표»이지 «달성»이
아니다"* 라고 적었다. **그 문장은 이제 못 쓴다** — 다만 **정확한 대체 문장은 «달성했다»가 아니다**.

```
철회됨 — 같은 표의 긴 판 (fixture: the caption is the ONLY marker and sits more than 200 chars above the figure)
row-01  padding padding padding padding padding padding padding padding padding padding padding
row-02  padding padding padding padding padding padding padding padding padding padding padding
row-03  padding padding padding padding padding padding padding padding padding padding padding
row-04  padding padding padding padding padding padding padding padding padding padding padding
F_slim 리뷰프로파일   13.6%
```
EOF

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# L2 — known-POSITIVE: pre-retraction fixture → rc=2, both CLAUDE.md sites LIVE, 12 LIVE + the record
#      line counted as EXCLUDED-FILE=1 (13 = the prototype's historical count)
# ═══════════════════════════════════════════════════════════════════════════════════════════════
run "$T/l2.txt" --claims "$T/claims_five_arms.tsv" --root "$T/pos"
N=$(live_n "$T/l2.txt")
if [ "$RC" -eq 2 ] && [ "$N" -eq 12 ] \
   && has "$T/l2.txt" 'LIVE   `2.7 %`  CLAUDE.md:3' && has "$T/l2.txt" 'LIVE   `2.7 %`  CLAUDE.md:8' \
   && has "$T/l2.txt" 'LIVE   `five review arms`  CLAUDE.md:3' \
   && has "$T/l2.txt" 'LIVE   `5팔`  knowledge/shared/harness-core/governance_engineering_definition.md:3' \
   && has "$T/l2.txt" 'LIVE   `다섯 개 전부`' && has "$T/l2.txt" 'ADVISORY' \
   && has "$T/l2.txt" 'R-claim verdict: LIVE=12 EXCLUDED-FILE=1 '; then
  ok "L2 known-positive: rc=2, LIVE=12 incl. both CLAUDE.md sites (table row + paragraph) + EXCLUDED-FILE=1 (record line), ADVISORY line"
else
  no "L2 known-positive" "rc=$RC LIVE=$N"; sed 's/^/     | /' "$T/l2.txt" | head -20
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# L3 — known-NEGATIVE: same tokens inside retraction sentences → LIVE=0, rc=0 — AND seen (bare>0)
# ═══════════════════════════════════════════════════════════════════════════════════════════════
run "$T/l3.txt" --claims "$T/claims_five_arms.tsv" --root "$T/neg" --show-excluded
N=$(live_n "$T/l3.txt")
if [ "$RC" -eq 0 ] && [ "$N" -eq 0 ] && has "$T/l3.txt" 'R-claim verdict: LIVE=0 EXCLUDED-FILE=0 RETRACTION-CONTEXT=' \
   && ! has "$T/l3.txt" 'RETRACTION-CONTEXT=0 ' \
   && has "$T/l3.txt" 'marker in window: RETRACT' && has "$T/l3.txt" 'marker in window: replaced' \
   && has "$T/l3.txt" 'marker in window: 초판' && has "$T/l3.txt" 'marker in window: 철회' \
   && has "$T/l3.txt" 'marker in block caption: 철회'; then
  # (the short fence is caught by the ±200 window before the caption branch is reached — that is what
  #  happened on the real corpus too; the padded fence is what exercises the caption branch itself)
  ok "L3 known-negative: rc=0, LIVE=0 — tokens SEEN and classified retraction-context (RETRACTED · replaced · 초판 · 철회 in window · 철회됨 as fence caption)"
else
  no "L3 known-negative" "rc=$RC LIVE=$N"; sed 's/^/     | /' "$T/l3.txt" | head -20
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# L4 — DEAD CONTROL: a claims file with no tokens → rc=4, never 0
# ═══════════════════════════════════════════════════════════════════════════════════════════════
printf '# dead control — comments only\n\n# 2.7 %% would be a token if it were not a comment\n' > "$T/claims_empty.tsv"
run "$T/l4.txt" --claims "$T/claims_empty.tsv" --root "$T/pos"
if [ "$RC" -eq 4 ] && has "$T/l4.txt" 'DEAD CONTROL' && ! has "$T/l4.txt" 'R-claim verdict'; then
  ok "L4 dead control: 0 tokens → rc=4 with DEAD CONTROL banner (not 0, no verdict line)"
else
  no "L4 dead control" "rc=$RC"; sed 's/^/     | /' "$T/l4.txt" | head -5
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# L5 — ⓒ′ FORM rule: bare `2.7` → REFUSED rc=3; with a claim-specific anchor → scanned rc=2;
#      with --no-form-rule the same bare token is scanned (the flag is what changes it)
# ═══════════════════════════════════════════════════════════════════════════════════════════════
printf '2.7\t\tbare — no anchor\n' > "$T/claims_bare27.tsv"
run "$T/l5a.txt" --claims "$T/claims_bare27.tsv" --root "$T/pos"
N=$(live_n "$T/l5a.txt")
if [ "$RC" -eq 3 ] && [ "$N" -eq 0 ] && has "$T/l5a.txt" 'REFUSED by ⓒ′' && has "$T/l5a.txt" 'PARTIAL'; then
  ok "L5a bare numeric token → REFUSED by ⓒ′, rc=3 PARTIAL, nothing listed as LIVE"
else
  no "L5a form rule" "rc=$RC LIVE=$N"; sed 's/^/     | /' "$T/l5a.txt" | head -8
fi
printf '2.7\terror[- ]?rates?|오류율|claim[- ]?error|B-1|dominance|최저|최고\tclaim-specific anchors\n' > "$T/claims_anch27.tsv"
run "$T/l5b.txt" --claims "$T/claims_anch27.tsv" --root "$T/pos"
N=$(live_n "$T/l5b.txt")
if [ "$RC" -eq 2 ] && [ "$N" -ge 1 ] && ! has "$T/l5b.txt" 'REFUSED by'; then
  ok "L5b same token + claim-specific anchor → scanned, rc=2, LIVE=$N"
else
  no "L5b anchored numeric" "rc=$RC LIVE=$N"; sed 's/^/     | /' "$T/l5b.txt" | head -8
fi
run "$T/l5c.txt" --claims "$T/claims_bare27.tsv" --root "$T/pos" --no-form-rule
N=$(live_n "$T/l5c.txt")
if [ "$RC" -eq 2 ] && [ "$N" -ge 1 ] && ! has "$T/l5c.txt" 'REFUSED by'; then
  ok "L5c --no-form-rule → the bare token is scanned again (rc=2, LIVE=$N): the flag is load-bearing"
else
  no "L5c --no-form-rule" "rc=$RC LIVE=$N"; sed 's/^/     | /' "$T/l5c.txt" | head -8
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# L6 — excluded classes are VISIBLE: both defaults printed in the header (record class with its
#      matched file, fixture class with 0 files), never silent; --no-default-exclude brings the record
#      line back as LIVE; an added inert pattern still prints; --json carries the exclusion as data
# ═══════════════════════════════════════════════════════════════════════════════════════════════
if grep -E 'excluded: knowledge/shared/learnings/\*_log.yaml .*\[default · record class\].*→ 1 file: knowledge/shared/learnings/subagent_invocations_log.yaml' "$T/l2.txt" >/dev/null \
   && grep -E 'excluded: scripts/test_\*_lanes.sh .*\[default · fixture class\].*→ 0 files' "$T/l2.txt" >/dev/null \
   && ! grep '🟥 LIVE' "$T/l2.txt" | grep -q '_log.yaml'; then
  ok "L6a both default classes printed (record class → its matched file · fixture class → 0 files); the record file is not among LIVE"
else
  no "L6a exclusion visibility" "header or LIVE list wrong"; grep -n 'excluded\|_log.yaml' "$T/l2.txt" | sed 's/^/     | /'
fi
run "$T/l6b.txt" --claims "$T/claims_five_arms.tsv" --root "$T/pos" --no-default-exclude
N=$(live_n "$T/l6b.txt")
if [ "$RC" -eq 2 ] && [ "$N" -eq 13 ] && has "$T/l6b.txt" 'excluded: (none' \
   && has "$T/l6b.txt" 'R-claim verdict: LIVE=13 EXCLUDED-FILE=0 ' \
   && grep '🟥 LIVE' "$T/l6b.txt" | grep -q 'subagent_invocations_log.yaml:3'; then
  ok "L6b --no-default-exclude → the record line IS LIVE (13 = 12 + 1, EXCLUDED-FILE=0): the class does work, not decoration"
else
  no "L6b --no-default-exclude" "rc=$RC LIVE=$N"; grep -n 'excluded\|_log.yaml\|verdict' "$T/l6b.txt" | sed 's/^/     | /'
fi
run "$T/l6c.txt" --claims "$T/claims_five_arms.tsv" --root "$T/pos" --exclude 'zzz/nothing/*'
if [ "$RC" -eq 2 ] && grep -E 'excluded: zzz/nothing/\* .*\[--exclude\].*→ 0 files' "$T/l6c.txt" >/dev/null \
   && grep -E 'excluded: knowledge/shared/learnings/\*_log.yaml .*→ 1 file:' "$T/l6c.txt" >/dev/null; then
  ok "L6c an added pattern that matches nothing is still printed beside the defaults (visible even when inert)"
else
  no "L6c inert pattern visibility" "rc=$RC"; grep -n 'excluded' "$T/l6c.txt" | sed 's/^/     | /'
fi
run "$T/l6d.txt" --claims "$T/claims_five_arms.tsv" --root "$T/pos" --json
"$PY" - "$T/l6d.txt" >"$T/l6d_chk.txt" 2>&1 <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
ex = d["excluded"]
assert ex["patterns"] == ["knowledge/shared/learnings/*_log.yaml", "scripts/test_*_lanes.sh"], ex
assert ex["classes"]["knowledge/shared/learnings/*_log.yaml"] == "record class", ex
assert ex["files"] == ["knowledge/shared/learnings/subagent_invocations_log.yaml"], ex
s = d["summary"]
assert s["live"] == 12 and s["excluded_file"] == 1 and s["rc"] == 2, s
assert d["mechanisms"]["nfkc"] is True, d["mechanisms"]
PY
if [ $? -eq 0 ] && [ "$RC" -eq 2 ]; then
  ok "L6d --json carries excluded.patterns/classes/files + summary (live=12, excluded_file=1, rc=2) + mechanisms.nfkc"
else
  no "L6d --json exclusion field" "$(head -3 "$T/l6d_chk.txt")"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# L7 — 🟥 REVERT PROBE: disable ⓑ in a COPIED scanner → the known-negative must go RED.
#      Mutation is by source edit (not by flag) so the DEFAULT code path is what is shown to carry
#      the load; L7b repeats it through the flag. The original is byte-compared before and after.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
cp "$SCAN" "$T/orig_snapshot.py"; cp "$SCAN" "$T/mutant_b.py"
if mutate "$T/mutant_b.py" "args = ap.parse_args()" "args.no_retraction_context = True  # MUTANT: ⓑ retraction-context disabled" >"$T/l7_mut.txt" 2>&1 \
   && [ "$(grep -c 'MUTANT: ⓑ' "$T/mutant_b.py")" -eq 1 ]; then
  runwith "$T/mutant_b.py" "$T/l7a.txt" --claims "$T/claims_five_arms.tsv" --root "$T/neg"; MRC=$RC
  MN=$(live_n "$T/l7a.txt")
  run "$T/l7o.txt" --claims "$T/claims_five_arms.tsv" --root "$T/neg"; ORC=$RC
  if cmp -s "$SCAN" "$T/orig_snapshot.py"; then UNTOUCHED=yes; else UNTOUCHED=no; fi
  if [ "$MRC" -eq 2 ] && [ "$MN" -ge 1 ] && has "$T/l7a.txt" 'ⓑretract=off' \
     && [ "$ORC" -eq 0 ] && [ "$UNTOUCHED" = yes ]; then
    ok "L7 revert probe: ⓑ disabled in a copy → known-negative RED (rc=2, LIVE=$MN); original untouched and still GREEN (rc=0)"
  else
    no "L7 revert probe" "mutant rc=$MRC LIVE=$MN · original rc=$ORC untouched=$UNTOUCHED"
    sed 's/^/     | /' "$T/l7a.txt" | head -8
  fi
else
  no "L7 revert probe (instrument)" "mutation did not apply: $(head -2 "$T/l7_mut.txt")"
fi
run "$T/l7b.txt" --claims "$T/claims_five_arms.tsv" --root "$T/neg" --no-retraction-context
N=$(live_n "$T/l7b.txt")
if [ "$RC" -eq 2 ] && [ "$N" -ge 1 ]; then
  ok "L7b same through the flag: --no-retraction-context → rc=2, LIVE=$N on the known-negative"
else
  no "L7b --no-retraction-context" "rc=$RC LIVE=$N"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# L8 — CONTROL: a word token that appears nowhere → bare=0, LIVE=0, rc=0 — and NOT rc=4
# ═══════════════════════════════════════════════════════════════════════════════════════════════
printf 'zzq-nonexistent-claim-token\t\tcontrol: absent everywhere\n' > "$T/claims_absent.tsv"
run "$T/l8.txt" --claims "$T/claims_absent.tsv" --root "$T/pos"
N=$(live_n "$T/l8.txt")
if [ "$RC" -eq 0 ] && [ "$N" -eq 0 ] && ! has "$T/l8.txt" 'DEAD CONTROL' && ! has "$T/l8.txt" 'REFUSED by' \
   && has "$T/l8.txt" 'R-claim verdict: LIVE=0 EXCLUDED-FILE=0 RETRACTION-CONTEXT=0 NO-ANCHOR=0 MENTION=0 REFUSED=0 rc=0' \
   && grep -E '^  zzq-nonexistent-claim-token +0 +0 ' "$T/l8.txt" >/dev/null; then
  ok "L8 absent-token control: bare=0, LIVE=0, rc=0 — distinct from rc=4, not refused"
else
  no "L8 absent-token control" "rc=$RC LIVE=$N"; sed 's/^/     | /' "$T/l8.txt" | head -8
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# L9 — token FORM + digit boundary (the largest reducer measured): `2.7 %` must not match inside
#      `12.7 %` / `2.75 %` / `2.7.1`, and MUST match the plain site in the same run
# ═══════════════════════════════════════════════════════════════════════════════════════════════
mkdir -p "$T/bnd"
cat > "$T/bnd/near_miss.md" <<'EOF'
Twelve arms ran 12.7 % claim-error on the same cases; one arm ran 2.75 % error rate.
Release 2.7.1 % of the error rate budget went to arms nobody counted.
EOF
printf 'Five arms ran 2.7 %% claim-error here.\n' > "$T/bnd/hit.md"
printf '2.7 %%\t%s\tboundary lane\n' "$ANCH" > "$T/claims_27pct.tsv"
run "$T/l9.txt" --claims "$T/claims_27pct.tsv" --root "$T/bnd"
N=$(live_n "$T/l9.txt")
if [ "$RC" -eq 2 ] && [ "$N" -eq 1 ] && has "$T/l9.txt" 'hit.md:1' && ! has "$T/l9.txt" 'near_miss.md' \
   && grep -E '^  2.7 % +1 +1 ' "$T/l9.txt" >/dev/null; then
  # (no backticks inside this double-quoted message — a backtick pair here EXECUTES «2.7 %» as a command)
  ok "L9 digit boundary: 12.7 % · 2.75 % · 2.7.1 % are not «2.7 %» (bare=1 file=1), the plain site is LIVE=1"
else
  no "L9 digit boundary" "rc=$RC LIVE=$N"; sed 's/^/     | /' "$T/l9.txt" | head -8
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# L10 — tracked mode: in a git checkout the corpus is `git ls-files`, so an UNTRACKED file carrying
#       the token is not scanned (bare count unchanged), and `README*` works as a pathspec glob
# ═══════════════════════════════════════════════════════════════════════════════════════════════
if command -v git >/dev/null 2>&1; then
  cp -R "$T/pos" "$T/trk"
  printf 'README fixture: five review arms ran 2.7 %% claim-error.\n' > "$T/trk/README.md"
  ( cd "$T/trk" && git init -q . && git add . && git -c user.email=t@e -c user.name=t commit -qm base ) >"$T/l10_git.txt" 2>&1
  printf 'UNTRACKED: five review arms ran 2.7 %% claim-error, and again 13.6 %% claim-error.\n' > "$T/trk/UNTRACKED.md"
  run "$T/l10.txt" --claims "$T/claims_five_arms.tsv" --root "$T/trk" --paths knowledge CLAUDE.md 'README*'
  N=$(live_n "$T/l10.txt")
  if [ "$RC" -eq 2 ] && [ "$N" -eq 14 ] && has "$T/l10.txt" 'README.md:1' && ! has "$T/l10.txt" 'UNTRACKED'; then
    ok "L10 tracked mode: git ls-files corpus — README* pathspec scanned (+2 LIVE = 14), UNTRACKED.md ignored"
  else
    no "L10 tracked mode" "rc=$RC LIVE=$N"; sed 's/^/     | /' "$T/l10.txt" | head -12; sed 's/^/     git| /' "$T/l10_git.txt" | head -3
  fi
else
  echo "  ⬜ SKIP L10 tracked mode (git not on PATH — not a pass)"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# L11 — 🟥 NFKC: a FULL-WIDTH copy of the retracted figure (２.７ %, ２.７％, ideographic space) is
#       LIVE; the ASCII line in the same block is the control that survives every arm.
#       L11r REVERT PROBE: flip `NFKC_ON = True` in a copy → the full-width copies go SILENT (the
#       cross-family finding: bare=0), the ASCII control stays. L11b: the same through --no-nfkc.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
mkdir -p "$T/fw"
cat > "$T/fw/fw.md" <<'EOF'
Five arms ran ２.７ % claim-error on the same cases (full-width digits, ASCII percent).
Five arms ran ２.７％ claim-error once more (full-width digits and full-width percent).
Five arms ran 2.7　% claim-error a third time (ideographic space before the percent).
Five arms ran 2.7 % claim-error (ascii control).
EOF
run "$T/l11.txt" --claims "$T/claims_27pct.tsv" --root "$T/fw"
N=$(live_n "$T/l11.txt")
if [ "$RC" -eq 2 ] && [ "$N" -eq 4 ] && has "$T/l11.txt" 'fw.md:1' && has "$T/l11.txt" 'fw.md:2' \
   && has "$T/l11.txt" 'fw.md:3' && has "$T/l11.txt" 'fw.md:4' && has "$T/l11.txt" 'nfkc=on' \
   && grep -E '^  2.7 % +4 +1 ' "$T/l11.txt" >/dev/null; then
  ok "L11 NFKC on: full-width ２.７ % · ２.７％ · ideographic-space copies are LIVE (4/4 incl. the ASCII control), bare=4"
else
  no "L11 NFKC" "rc=$RC LIVE=$N"; sed 's/^/     | /' "$T/l11.txt" | head -10
fi
cp "$SCAN" "$T/mutant_n.py"
"$PY" - "$T/mutant_n.py" >"$T/l11_mut.txt" 2>&1 <<'PY'
import sys
p = sys.argv[1]; L = open(p, encoding="utf-8").read().split("\n")
idx = [k for k, l in enumerate(L) if l.startswith("NFKC_ON = True")]
assert len(idx) == 1, "NFKC_ON = True anchor found %d times" % len(idx)
L[idx[0]] = "NFKC_ON = False  # MUTANT: NFKC normalization disabled"
open(p, "w", encoding="utf-8").write("\n".join(L))
PY
if [ $? -eq 0 ] && [ "$(grep -c 'MUTANT: NFKC' "$T/mutant_n.py")" -eq 1 ]; then
  runwith "$T/mutant_n.py" "$T/l11r.txt" --claims "$T/claims_27pct.tsv" --root "$T/fw"; MRC=$RC
  MN=$(live_n "$T/l11r.txt")
  if cmp -s "$SCAN" "$T/orig_snapshot.py"; then UNTOUCHED=yes; else UNTOUCHED=no; fi
  # RED = the two FULL-WIDTH-DIGIT copies vanish (LIVE 4 → 2, bare 4 → 2). Line 3 (ideographic space,
  # ASCII digits) survives WITHOUT NFKC: the token FORM's `\s` already matches U+3000 — measured on the
  # first run of this probe, which had expected 4 → 1. So the NFKC delta is digits/percent, not spaces;
  # line 3 stays in the fixture as the discriminator between the two mechanisms.
  if [ "$MN" -eq 2 ] && has "$T/l11r.txt" 'fw.md:3' && has "$T/l11r.txt" 'fw.md:4' \
     && ! has "$T/l11r.txt" 'fw.md:1' && ! has "$T/l11r.txt" 'fw.md:2' \
     && has "$T/l11r.txt" 'nfkc=off' && grep -E '^  2.7 % +2 +1 ' "$T/l11r.txt" >/dev/null \
     && [ "$UNTOUCHED" = yes ]; then
    ok "L11r revert probe: NFKC flipped off in a copy → full-width-digit copies SILENT (LIVE 4→2, bare 4→2: lines 1-2 gone, ideographic-space line 3 kept by FORM's \\s, ASCII control 4 kept); original untouched"
  else
    no "L11r revert probe" "mutant rc=$MRC LIVE=$MN untouched=$UNTOUCHED"; sed 's/^/     | /' "$T/l11r.txt" | head -10
  fi
else
  no "L11r revert probe (instrument)" "mutation did not apply: $(head -2 "$T/l11_mut.txt")"
fi
run "$T/l11b.txt" --claims "$T/claims_27pct.tsv" --root "$T/fw" --no-nfkc
N=$(live_n "$T/l11b.txt")
if [ "$N" -eq 2 ] && has "$T/l11b.txt" 'fw.md:3' && has "$T/l11b.txt" 'fw.md:4' && ! has "$T/l11b.txt" 'fw.md:1' && ! has "$T/l11b.txt" 'fw.md:2'; then
  ok "L11b same through the flag: --no-nfkc → LIVE=2 (ideographic-space line + ASCII control; both full-width-digit lines silent)"
else
  no "L11b --no-nfkc" "rc=$RC LIVE=$N"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# L12 — 🟥 EXCLUDED-FILE is a classification, not a corpus cut: a would-be-LIVE hit that sits ONLY
#       in a record-class file is counted (EXCLUDED-FILE=1), hinted, listed by --show-excluded as
#       file:line, NOT LIVE, and does not move rc (rc=0). --no-default-exclude turns it LIVE (rc=2).
#       L12r REVERT PROBE: re-insert the first version's corpus cut in a copy → the hit disappears
#       from every surface (EXCLUDED-FILE=0, nothing listed) while rc stays 0 — the silent shape.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
mkdir -p "$T/exc/knowledge/shared/learnings"
printf -- '- date: 2026-09-08\n  purpose: "④ B-1 5팔 채점(축①③ keyed · 축② unkeyed)"\n' > "$T/exc/knowledge/shared/learnings/x_log.yaml"
printf 'Nothing in this file names the figure.\n' > "$T/exc/README.md"
printf '5팔\t\trecord-class lane\n' > "$T/claims_5pal.tsv"
run "$T/l12a.txt" --claims "$T/claims_5pal.tsv" --root "$T/exc"
N=$(live_n "$T/l12a.txt")
if [ "$RC" -eq 0 ] && [ "$N" -eq 0 ] && has "$T/l12a.txt" 'R-claim verdict: LIVE=0 EXCLUDED-FILE=1 ' \
   && has "$T/l12a.txt" '1 would-be-LIVE hit(s) sit in excluded-class files' \
   && has "$T/l12a.txt" 'corpus=2 files (1 in excluded classes — scanned, hits classified EXCLUDED-FILE)' \
   && grep -E '^  5팔 +1 +1 +0 +0 +0 +1 +0 ' "$T/l12a.txt" >/dev/null; then
  ok "L12a hit only in a record-class file → EXCLUDED-FILE=1, LIVE=0, rc=0, hint line, exclf column=1"
else
  no "L12a excluded-file classification" "rc=$RC LIVE=$N"; sed 's/^/     | /' "$T/l12a.txt" | head -10
fi
run "$T/l12b.txt" --claims "$T/claims_5pal.tsv" --root "$T/exc" --show-excluded
if [ "$RC" -eq 0 ] && grep -E '⬜ excl   `5팔`  knowledge/shared/learnings/x_log.yaml:2  \[EXCLUDED-FILE · record class\]' "$T/l12b.txt" >/dev/null \
   && ! has "$T/l12b.txt" '🟥 LIVE'; then
  ok "L12b --show-excluded lists the excluded-file hit as file:line with its class (x_log.yaml:2 · record class), still not LIVE"
else
  no "L12b --show-excluded listing" "rc=$RC"; sed 's/^/     | /' "$T/l12b.txt" | head -10
fi
run "$T/l12c.txt" --claims "$T/claims_5pal.tsv" --root "$T/exc" --no-default-exclude
N=$(live_n "$T/l12c.txt")
if [ "$RC" -eq 2 ] && [ "$N" -eq 1 ] && has "$T/l12c.txt" 'x_log.yaml:2' && has "$T/l12c.txt" 'R-claim verdict: LIVE=1 EXCLUDED-FILE=0 '; then
  ok "L12c --no-default-exclude → the same hit is LIVE, rc=2 (the class decides the column, not the visibility)"
else
  no "L12c --no-default-exclude on record-class hit" "rc=$RC LIVE=$N"
fi
cp "$SCAN" "$T/mutant_x.py"
if mutate "$T/mutant_x.py" "excluded, per_pattern = classify_excludes(files, root, excludes)" \
     'files = [f for f in files if rel_of(f, root) not in excluded]  # MUTANT: first-version corpus cut — excluded files not scanned' >"$T/l12_mut.txt" 2>&1 \
   && [ "$(grep -c 'MUTANT: first-version corpus cut' "$T/mutant_x.py")" -eq 1 ]; then
  runwith "$T/mutant_x.py" "$T/l12r.txt" --claims "$T/claims_5pal.tsv" --root "$T/exc" --show-excluded; MRC=$RC
  if cmp -s "$SCAN" "$T/orig_snapshot.py"; then UNTOUCHED=yes; else UNTOUCHED=no; fi
  # RED = the hit vanishes from every surface while rc stays 0 — exactly the hidden-claim shape
  if [ "$MRC" -eq 0 ] && has "$T/l12r.txt" 'R-claim verdict: LIVE=0 EXCLUDED-FILE=0 ' && ! has "$T/l12r.txt" 'x_log.yaml:2' \
     && [ "$UNTOUCHED" = yes ]; then
    ok "L12r revert probe: first-version corpus cut re-inserted in a copy → the hit is HIDDEN (EXCLUDED-FILE=0, not listed, rc still 0); original untouched"
  else
    no "L12r revert probe" "mutant rc=$MRC untouched=$UNTOUCHED"; sed 's/^/     | /' "$T/l12r.txt" | head -10
  fi
else
  no "L12r revert probe (instrument)" "mutation did not apply: $(head -2 "$T/l12_mut.txt")"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# L13 — --quiet keeps exactly the exclusion line(s) and the verdict line: 2 default classes + verdict
#       = 3 lines; with --no-default-exclude = 2 lines; nothing else (no table, no LIVE listing)
# ═══════════════════════════════════════════════════════════════════════════════════════════════
run "$T/l13a.txt" --claims "$T/claims_five_arms.tsv" --root "$T/pos" --quiet
LN=$(grep -c '' "$T/l13a.txt")
if [ "$RC" -eq 2 ] && [ "$LN" -eq 3 ] \
   && grep -E '^  excluded: knowledge/shared/learnings/\*_log.yaml .*→ 1 file:' "$T/l13a.txt" >/dev/null \
   && grep -E '^  excluded: scripts/test_\*_lanes.sh .*→ 0 files' "$T/l13a.txt" >/dev/null \
   && has "$T/l13a.txt" 'R-claim verdict: LIVE=12 EXCLUDED-FILE=1 ' && ! has "$T/l13a.txt" '🟥 LIVE' && ! has "$T/l13a.txt" 'mechanisms:'; then
  ok "L13a --quiet = 3 lines exactly: both excluded-class lines + the verdict line (rc=2 unchanged)"
else
  no "L13a --quiet" "rc=$RC lines=$LN"; sed 's/^/     | /' "$T/l13a.txt" | head -6
fi
run "$T/l13b.txt" --claims "$T/claims_five_arms.tsv" --root "$T/pos" --quiet --no-default-exclude
LN=$(grep -c '' "$T/l13b.txt")
if [ "$RC" -eq 2 ] && [ "$LN" -eq 2 ] && has "$T/l13b.txt" 'excluded: (none' && has "$T/l13b.txt" 'R-claim verdict: LIVE=13 EXCLUDED-FILE=0 '; then
  ok "L13b --quiet --no-default-exclude = 2 lines: the (none) exclusion line + the verdict line"
else
  no "L13b --quiet --no-default-exclude" "rc=$RC lines=$LN"; sed 's/^/     | /' "$T/l13b.txt" | head -4
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# L14 — one counting unit: bare == LIVE + EXCLUDED-FILE + RETRACTION-CONTEXT + NO-ANCHOR + MENTION.
#       Known pair for the first version's mismatch: a token WRAPPED across a line break (per-line
#       bare missed it) and a token REPEATED on one line (per-line bare counted 1 for 2 hits).
# ═══════════════════════════════════════════════════════════════════════════════════════════════
mkdir -p "$T/cnt"
cat > "$T/cnt/wrap.md" <<'EOF'
Measured that day across five
review arms on the same eight cases, the claim spans a line break here.
EOF
printf 'On one line: five review arms, then again five review arms.\n' > "$T/cnt/double.md"
printf 'five review arms\t\tcounting lane\n' > "$T/claims_fra.tsv"
run "$T/l14a.txt" --claims "$T/claims_fra.tsv" --root "$T/cnt" --json
"$PY" - "$T/l14a.txt" >"$T/l14a_chk.txt" 2>&1 <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
r = d["tokens"]["five review arms"]
n = len(r["live"]) + len(r["excluded_file"]) + len(r["retraction"]) + len(r["no_anchor"]) + len(r["mention"])
assert r["bare"] == 3 and len(r["live"]) == 3 and n == 3, (r["bare"], len(r["live"]), n)
files = sorted(h["file"] + ":" + str(h["line"]) for h in r["live"])
assert files == ["double.md:1", "double.md:1", "wrap.md:1"], files
PY
if [ $? -eq 0 ] && [ "$RC" -eq 2 ]; then
  ok "L14a wrapped token + doubled token: bare=3 == LIVE=3 (wrap.md:1 · double.md:1 ×2) — one unit for both columns"
else
  no "L14a counting unit" "$(head -3 "$T/l14a_chk.txt")"
fi
run "$T/l14b.txt" --claims "$T/claims_five_arms.tsv" --root "$T/pos" --json
"$PY" - "$T/l14b.txt" >"$T/l14b_chk.txt" 2>&1 <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
bad = []
for k, r in d["tokens"].items():
    if r["refused"]:
        continue
    n = len(r["live"]) + len(r["excluded_file"]) + len(r["retraction"]) + len(r["no_anchor"]) + len(r["mention"])
    if r["bare"] != n:
        bad.append((k, r["bare"], n))
assert not bad, bad
assert sum(r["bare"] for r in d["tokens"].values()) == 13, sum(r["bare"] for r in d["tokens"].values())
PY
if [ $? -eq 0 ]; then
  ok "L14b invariant over the known-positive: every scanned token has bare == sum of its classes (Σbare = 13 = 12 LIVE + 1 EXCLUDED-FILE)"
else
  no "L14b invariant" "$(head -3 "$T/l14b_chk.txt")"
fi

echo
echo "── $pass passed, $fail failed ──"
[ "$fail" -eq 0 ] || exit 1
exit 0

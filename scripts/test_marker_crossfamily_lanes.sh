#!/usr/bin/env bash
# test_marker_crossfamily_lanes.sh — regression fixtures for pre-commit's
# validate_crossfamily_leg (typed cross-family verdict, 2026-08-08).
#
# WHY: the `crossfamily:` marker line has been REQUIRED on load-bearing changes since
# 2026-06 (commit c1fa459) — but only its PRESENCE was checked, so the value was free
# prose. That is how a false one shipped: a sibling harness recorded
# `crossfamily: none this round — 도달 불가` (unreachable), the claim was later found
# FALSE, and a later session cited it as grounds. Presence-checking catches silence; it
# cannot catch a confident wrong answer. This lane types the value.
#
# Fixtures assert BOTH directions (known-pair): every intended shape is admitted, and
# every hole the lane closes still blocks. A test that only asserts BLOCK cannot tell
# "blocked" from "blocked for the wrong reason"; one that only asserts PASS cannot see a
# lane that admits everything.
#
# Usage: bash scripts/test_marker_crossfamily_lanes.sh   Exit: 0 = all behave; 1 = regression.

set -uo pipefail
# Script-relative, NOT `git rev-parse --show-toplevel`. Measured 2026-08-13 in a vendored tree
# (npm install, then `git init` at a level above — a monorepo committing node_modules is the
# same shape): rev-parse answers with the OUTER repo's root, so this suite looked for the
# package's own files inside somebody else's checkout, found nothing, and reported
# HARNESS-ERROR. The consumer sees a red `npm test` caused entirely by where their .git is.
# The subject of these lanes ships INSIDE this package, so the package root is the only root
# that can be right. Same form as test_capability_entrypoint_shipping.sh:29.
# The exposure is new: before these suites were wired into selfcheck.sh they ran nowhere, so
# the wrong root never cost anything. Wiring a dead lane surfaces every assumption it made.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$REPO_ROOT/templates/.git-hooks/pre-commit"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

sed -n '/^validate_crossfamily_leg()/,/^}/p' "$HOOK" > "$T/fn.sh"

# Instrument calibration: an empty extraction would let every fixture "pass" against
# nothing. Assert the function body actually arrived before measuring anything.
# '_res_active' is inside the residency= token block (2026-09-05) — RESIDENCY_TOKEN_GRACE_DATE
# itself lives OUTSIDE the function (same placement as DEFEATER_GRACE_DATE next to
# validate_defeater_leg), so it is not part of this extraction and is supplied by the harness
# below, exactly like GRACE_RES is.
if ! grep -q 'DEGRADED_PANEL_UNUSED' "$T/fn.sh" || ! grep -q '_res_active' "$T/fn.sh" \
   || ! grep -q '_ev_active' "$T/fn.sh"; then
  echo "❌ HARNESS-ERROR — validate_crossfamily_leg did not extract from $HOOK (or the residency"
  echo "   token block is missing from it). Fixtures below would measure an empty/stale function."
  exit 1
fi

GRACE_RES=$(grep -m1 '^RESIDENCY_TOKEN_GRACE_DATE=' "$HOOK" | sed -E 's/.*"(.*)"/\1/')
[ -n "$GRACE_RES" ] || { echo "❌ HARNESS-ERROR — RESIDENCY_TOKEN_GRACE_DATE 를 못 읽었다"; exit 1; }
# 🟥 evidence= (2026-09-12) 도 같은 자리에 산다. 이 값을 «안 주입하면» 함수 안에서 빈 문자열이 되고
#    `[ "$mdate" \< "" ]` 은 언제나 거짓 → grace 가 통째로 무효 → panel 을 쓰는 **기존 픽스처 전부**가
#    evidence 없다는 이유로 BLOCK 된다. 실행해 보지 않으면 안 보이는 자리라 가드를 둔다.
GRACE_EV=$(grep -m1 '^EVIDENCE_TOKEN_GRACE_DATE=' "$HOOK" | sed -E 's/.*"(.*)"/\1/')
[ -n "$GRACE_EV" ] || { echo "❌ HARNESS-ERROR — EVIDENCE_TOKEN_GRACE_DATE 를 못 읽었다"; exit 1; }
# Every fixture below this point (k*/b*/x*/c*) tests crossfamily's PRE-EXISTING shape rules —
# panel format, embedding/reranker filters, declined, degrade grounds — none of them are testing
# the residency-token addition. So mk()/run() stamp a date BEFORE RESIDENCY_TOKEN_GRACE_DATE into
# the marker filename (the same field validate_crossfamily_leg itself reads via `mdate`), earning
# exemption the same way a real old marker would — not special-cased in the check function for
# this suite's convenience. The dedicated residency-token section near the end of this file uses
# its OWN helper with an explicit, varying date to test the grace boundary on purpose.
PRE_RES="2026-08-01"   # < RESIDENCY_TOKEN_GRACE_DATE (2026-09-05) by construction
# 🟥 the DATE must be the LAST underscore-segment before `.marker` — validate_crossfamily_leg's
# own `mdate` extraction is `.*_(YYYY-MM-DD)\.marker$`, which does not match if a fixture-name
# suffix follows the date (caught by this suite's own fail-before run: k1/k1b/k7 false-BLOCKed
# because ".._${PRE_RES}_$2.marker" put the name AFTER the date, so mdate came back empty and
# every pre-existing fixture was silently treated as un-exempt).
mk() { printf "$1" > "$T/.axes_23_passed_fix_x_$2_${PRE_RES}.marker"; }   # $1=body $2=fixture name
run() {
  bash -c "RESIDENCY_TOKEN_GRACE_DATE='$GRACE_RES'; EVIDENCE_TOKEN_GRACE_DATE='$GRACE_EV'; source '$T/fn.sh'; validate_crossfamily_leg '$T/.axes_23_passed_fix_x_$1_${PRE_RES}.marker'" \
    >/dev/null 2>&1
}

FAIL=0; N=0
check() { # $1=fixture $2=expected(PASS|BLOCK) $3=label
  N=$((N+1))
  if run "$1"; then got=PASS; else got=BLOCK; fi
  if [ "$got" = "$2" ]; then echo "✅ $3 → $got"; else echo "❌ $3 → $got (expected $2)"; FAIL=1; fi
}

echo "── admitted shapes (must PASS) ──"
mk 'crossfamily: panel(codex,gemini) — R1..R3, 9 findings, 8 fixed 1 refuted, CONVERGED\n' k1
check k1 PASS "panel() with family list + verdict"
mk 'crossfamily: panel(codex, gemini) — spaced list, the S-grade over-block\n' k1b
check k1b PASS "panel(codex, gemini) — SPACE after comma (was truncated to 'panel(codex,')"
# ⚠️ CONTRACT CHANGE 2026-08-16 — `declined` now requires grounds. It used to pass BARE, which is
# what the old k3 asserted. That was the enum's soft spot: `declined` means the OPERATOR declined
# sidecars (UAP), a chosen floor — a factual, attributable claim — and it was the ONLY value with no
# grounds requirement, so an author who had merely judged decorrelation unnecessary reached for the
# nearest permissive token and passed clean. Measured in this repo the same day, by a session that
# had corrected a different marker's crossfamily value hours earlier and had the correct semantics
# printed to it in the hook's own error text. A closed enum stops prose from collapsing distinct
# states; it does not stop a WRONG token from being a VALID one — that is what these three lanes are.
# The old bare-declined expectation is not deleted silently; it is inverted here with its reason.
mk 'crossfamily: declined\n' k3
check k3 BLOCK "declined BARE — no grounds (was PASS until 2026-08-16; an operator decision has a record)"
mk 'crossfamily: declined — operator declined sidecars, chosen floor, per knowledge/shared/rules/operational_adaptation.md\n' k3b
check k3b PASS "declined + a record path that RESOLVES (the documented form)"
# The real defect, verbatim-shaped: a genuine authorial judgment, plausibly worded, wrong token.
# This is the known-POSITIVE that is not synthetic — it is the sentence that actually shipped.
mk 'crossfamily: declined — this is a small, mechanically-verifiable hook-wiring fix, not a verdict-enum change; the standpoint axis is the decorrelation applied here\n' k3c
check k3c BLOCK "declined + AUTHOR-judgment grounds — a choice with a panel reachable is DEGRADED_PANEL_UNUSED"
# ── the three a cross-family review (codex/gpt-5.6-terra) found against the FIRST version of this
# lane, which grepped for vocabulary (operator|uap|consent|…). All three reproduced on the spot,
# which is why the check is now a RESOLVABLE-RECORD test rather than a word list.
mk 'crossfamily: declined — declined because I judged it unnecessary myself\n' k3d
check k3d BLOCK "SELF-VALIDATING: echoing the value satisfied the old word list ('declin')"
mk 'crossfamily: declined — operator documentation says authors may choose freely\n' k3e
check k3e BLOCK "VACUOUS: carries 'operator' but describes no declination at all"
mk 'crossfamily: declined — operator declined sidecars, see tracks/_meta/nonexistent_record.md\n' k3f
check k3f BLOCK "FABRICATED PATH: cites a record that does not exist on disk"
# ⚠️ INSTRUMENT NOTE, recorded because it nearly produced a false verdict on this very lane:
# the first attempt to known-pair these ran the extracted function under **zsh** (this operator's
# interactive shell) while the hook runs under **bash**. zsh does not word-split an unquoted
# parameter expansion, so the `for _tok in $reason` scan saw ONE token and the legitimate
# path-citing case scored a false BLOCK — the code was correct and the harness was wrong.
# Re-run under bash: 7/7. If you hand-test this function, invoke it with `bash`, not the login shell.
mk 'crossfamily: DEGRADED_SINGLE_FAMILY — probed codex/agy/4090, 0 capable reachable\n' k4
check k4 PASS "DEGRADED_SINGLE_FAMILY + substantive reason"
mk 'crossfamily: UNKNOWN — consent unset, panel not probed this round\n' k5
check k5 PASS "UNKNOWN + reason naming why it was not probed"
mk 'crossfamily: DEGRADED_PANEL_UNUSED — codex/agy/gemini reachable, not recruited (scope)\n' k6
check k6 PASS "DEGRADED_PANEL_UNUSED + reason naming the reachable families"
mk 'crossfamily: panel(qwen,gpt-oss,glm) — clean, 0 findings\n' k7
check k7 PASS "capable families only — guard does not over-block a real panel"

echo "── closed holes (must BLOCK) ──"
mk 'axis2-evidence: PASS no-S\n' b1
check b1 BLOCK "no crossfamily line at all (silence — the original guard, still intact)"
mk 'crossfamily: none this round — 인라인 same-family\n' b2
check b2 BLOCK "'none' free prose (the shape found on disk)"
mk 'crossfamily: none this round — 도달 불가\n' b3
check b3 BLOCK "'none' asserting unreachable (the FALSE one that shipped)"
mk 'crossfamily: none\n' b4
check b4 BLOCK "bare 'none' (merges could-not / did-not / did-not-look)"
mk 'crossfamily: DEGRADED_SINGLE_FAMILY\n' b5
check b5 BLOCK "degrade value with no reason (silent degrade — the whole point)"
mk 'crossfamily: UNKNOWN\n' b6
check b6 BLOCK "UNKNOWN with no reason (unprobed rendered as zero)"
mk 'crossfamily: DEGRADED_PANEL_UNUSED\n' b7
check b7 BLOCK "PANEL_UNUSED with no reason ('did not' passing as 'could not')"
mk 'crossfamily: DEGRADED_SINGLE_FAMILY — degraded\n' b8
check b8 BLOCK "reason too vacuous (names no probe and no grounds)"
mk 'crossfamily: panel\n' b9
check b9 BLOCK "bare panel claim naming no family"
mk 'crossfamily: panel()\n' b10
check b10 BLOCK "panel() with empty family list"
mk 'crossfamily: DEGRADED\n' b11
check b11 BLOCK "near-miss token (not an enum value)"
mk 'crossfamily: codex/gpt-5.5 — R1..R4, 16 findings, CONVERGED\n' b12
check b12 BLOCK "legacy free-form engine string (pre-typed convention) now rejected"

echo "── cross-family review findings (agy/Gemini 3.1 Pro, 2026-08-08) ──"
mk 'crossfamily: panel(claude) — reviewed by another claude session\n' x1
check x1 BLOCK "panel names the AUTHOR'S own family (decorrelation gate not seeing decorrelation)"
mk 'crossfamily: panel(opus,sonnet) — two claude tiers\n' x2
check x2 BLOCK "two same-family tiers dressed as a 2-family panel"
mk 'crossfamily: panel(none)\n' x3
check x3 BLOCK "panel(none) — a non-run laundered through the parens"
mk 'crossfamily: panel(unprobed)\n' x4
check x4 BLOCK "panel(unprobed) — same laundering, other token"
mk 'crossfamily: single-family\n' x5
check x5 BLOCK "single-family on a LOAD-BEARING change (free no-ack bypass of the lane)"
mk 'crossfamily: UNKNOWN — 0\n' x6
check x6 BLOCK "grounds '0' (porous non-vacuity: bare digit passed)"
mk 'crossfamily: UNKNOWN — problem\n' x7
check x7 BLOCK "grounds 'problem' (matched on substring 'prob')"
mk 'crossfamily: UNKNOWN — client error\n' x8
check x8 BLOCK "grounds 'client error' (matched on substring 'cli')"
mk 'crossfamily: panel(voyage-3,bge-m3) — 2 families\n' x9
check x9 BLOCK "embedding models WITHOUT 'embed' in the name (denylist false negative)"
mk 'crossfamily: panel(armorm,starling-rm) — 2 families\n' x10
check x10 BLOCK "reward models emitting scalars, not findings"
mk 'crossfamily: panel(cohere-rank-v3) — reranker named 'rank' not 'rerank'\n' x11
check x11 BLOCK "reranker named 'rank' (denylist false negative)"
mk 'crossfamily: DEGRADED_SINGLE_FAMILY — agy sidecar daemon crashed on startup, none reachable\n' x12
check x12 PASS  "grounds naming agy (was rejected — keyword list omitted it)"

mk 'crossfamily: single-family\ncrossfamily: DEGRADED_SINGLE_FAMILY — probed codex/agy, 0 reachable\n' x13
check x13 BLOCK "two crossfamily lines — appended correction shadowed by stale first (codex net-new)"

echo "── review-capability guard (pmh-dev #41 field measurement) ──"
mk 'crossfamily: panel(qwen,embed,embed) — 3 families\n' c1
check c1 BLOCK "embeddings counted as panel members (the measured false panel)"
mk 'crossfamily: panel(embed,rerank,ocr) — 3 families\n' c2
check c2 BLOCK "every member incapable — '3 families', 0 reviewers"
mk 'crossfamily: panel(gpt-oss,safeguard) — 2 families\n' c3
check c3 BLOCK "safeguard classifier padding one real family"
# Ordering invariant: ineligibility is tested FIRST. Both tokens ALSO match a valid
# family (glm-ocr → glm, qwen-embedding → qwen), so an eligibility-first implementation
# admits them silently. This pair anchors the ORDER, not the list.
mk 'crossfamily: panel(glm-ocr) — glm family\n' c4
check c4 BLOCK "glm-ocr — matches a valid family AND an incapable class"
mk 'crossfamily: panel(qwen-embedding-8b) — qwen family\n' c5
check c5 BLOCK "qwen-embedding — same overlap, other direction"

# ── residency= token inside crossfamily grounds (2026-09-05) ──────────────────────────────────
# Wires scripts/residency_closure_scan.py's own verdict into the SAME typed field this whole
# suite already calibrates, rather than opening a second marker line. All fixtures above this
# point are PRE-GRACE (via mk()'s PRE_RES stamp) and therefore exempt by construction — this
# section is the only place that varies the marker-filename date on purpose, mirroring
# test_marker_soul_tenet_lanes.sh's `dlane` / test_marker_soul_check_lanes.sh's `planep` pattern.
# Same ordering requirement as mk()/run() above — date LAST, immediately before `.marker`.
resfix() { printf "%s\n" "$1" > "$T/.axes_23_passed_fix_x_$3_$2.marker"; }   # $1=body $2=date $3=fname
resrun() {   # $1=date $2=fname → rc
  bash -c "RESIDENCY_TOKEN_GRACE_DATE='$GRACE_RES'; EVIDENCE_TOKEN_GRACE_DATE='$GRACE_EV'; source '$T/fn.sh'; validate_crossfamily_leg '$T/.axes_23_passed_fix_x_$2_$1.marker'" \
    >/dev/null 2>&1
}
rescheck() {   # $1=fname $2=date $3=body $4=expect(PASS|BLOCK) $5=label
  N=$((N+1))
  resfix "$3" "$2" "$1"
  if resrun "$2" "$1"; then got=PASS; else got=BLOCK; fi
  if [ "$got" = "$4" ]; then echo "✅ $5 → $got"; else echo "❌ $5 → $got (expected $4)"; FAIL=1; fi
}

echo
echo "── residency= token in crossfamily grounds (grace = $GRACE_RES) ──"
echo "· panel(...) REQUIRES a well-formed residency=CLEAN( token —"
rescheck r1 "$GRACE_RES" 'crossfamily: panel(codex) — residency=CLEAN(files=7) · R1..R2, 4 findings' \
  PASS  "r1 panel + residency=CLEAN( present — required token satisfied"
rescheck r2 "$GRACE_RES" 'crossfamily: panel(codex) — R1..R2, 4 findings, no residency token at all' \
  BLOCK "r2 panel POST-GRACE with NO residency token → BLOCK (the hole this closes)"
rescheck r3 "2026-08-20" 'crossfamily: panel(codex) — R1..R2, 4 findings, no residency token at all' \
  PASS  "r3 SAME body as r2, PRE-GRACE filename date → exempt (no retroactivity)"
rescheck r4 "$GRACE_RES" 'crossfamily: panel(codex) — residency=TAINTED(2 files, stripped=no) · sent anyway' \
  BLOCK "r4 panel + residency=TAINTED( co-present — contradiction (sent AND tainted)"
rescheck r5 "$GRACE_RES" 'crossfamily: panel(codex) — residency=NOT_SCANNED(scanner absent) · sent anyway' \
  BLOCK "r5 panel + residency=NOT_SCANNED( co-present — contradiction (sent AND unscanned)"
rescheck r6 "$GRACE_RES" 'crossfamily: panel(codex) — residency=WEIRD(oops) · R1, 1 finding' \
  BLOCK "r6 panel + malformed residency token (not one of CLEAN|TAINTED|NOT_SCANNED)"
rescheck r7 "$GRACE_RES" 'crossfamily: panel(codex) — residency=CLEAN(files=3) · residency=CLEAN(files=9) · dup' \
  BLOCK "r7 panel + TWO residency tokens on one line (first-wins trap, same as dup crossfamily:)"

echo "· DEGRADED_*/UNKNOWN/declined — residency= is OPTIONAL, format-only when present —"
rescheck r8 "$GRACE_RES" 'crossfamily: DEGRADED_SINGLE_FAMILY — residency=TAINTED(2 files, stripped=no) not sent, probed codex/agy, 0 reachable' \
  PASS  "r8 DEGRADED + well-formed TAINTED token — optional token, present and valid"
rescheck r9 "$GRACE_RES" 'crossfamily: DEGRADED_SINGLE_FAMILY — probed codex/agy, 0 reachable' \
  PASS  "r9 DEGRADED with NO residency token at all — optional, absence is fine"
rescheck r10 "$GRACE_RES" 'crossfamily: DEGRADED_SINGLE_FAMILY — residency=BOGUS(oops) probed codex, 0 reachable' \
  BLOCK "r10 DEGRADED + malformed residency token → BLOCK even though the token itself is optional"
rescheck r11 "$GRACE_RES" 'crossfamily: UNKNOWN — residency=NOT_SCANNED(scanner absent), panel not probed this round' \
  PASS  "r11 UNKNOWN + well-formed NOT_SCANNED token"
rescheck r12 "$GRACE_RES" 'crossfamily: declined — operator declined sidecars, chosen floor, per knowledge/shared/rules/operational_adaptation.md residency=CLEAN(files=2)' \
  PASS  "r12 declined + a well-formed CLEAN token appended after the resolvable-record citation"
rescheck r13 "$GRACE_RES" 'crossfamily: DEGRADED_PANEL_UNUSED — residency=CLEAN(files=1) · residency=TAINTED(files=1) codex+agy reachable, not recruited' \
  BLOCK "r13 DEGRADED + TWO residency tokens — the duplicate guard applies here too, not just panel"
# r14–r17 (cross-family codex gpt-5.5, 2026-09-05): the first draft grepped the token PREFIX
# `residency=<KIND>(`, so a token that failed the prefix grep was treated as ABSENT — on the optional
# path that is a fail-open (malformed reads as "no token, fine"). Presence is now counted first.
rescheck r14 "$GRACE_RES" 'crossfamily: DEGRADED_SINGLE_FAMILY — residency=CLEAN (files=2) probed codex, 0 reachable' \
  BLOCK "r14 DEGRADED + spaced token 'residency=CLEAN (files=2)' — malformed, must not read as absent"
rescheck r15 "$GRACE_RES" 'crossfamily: DEGRADED_SINGLE_FAMILY — residency=CLEAN(files=1 probed codex, 0 reachable' \
  BLOCK "r15 DEGRADED + unterminated token 'residency=CLEAN(files=1' (no close paren) → malformed"
rescheck r16 "$GRACE_RES" 'crossfamily: panel(codex) — residency=CLEAN(files=3, stripped=2) · R1..R3, 8 findings' \
  PASS  "r16 panel + CLEAN token whose payload contains a space and a comma (legal inside the parens)"
rescheck r17 "$GRACE_RES" 'crossfamily: panel(codex) — residency=CLEAN(files=3, stripped=2) — stripped files were named to the reviewer' \
  PASS  "r17 control — a second em-dash in the grounds does not break the token parse"

echo
echo "── evidence= token in crossfamily grounds (grace = $GRACE_EV) ──"
# 🟥 왜 있나 — arXiv:2609.10969 이 고정예산 2×2(48 템플릿 · 2,880 시나리오)로 두 축을 분리해 재니
#   «같은 증거를 읽는 교차-모델 투표» 가 위험 제안의 62.9 % 를 승인하고 «독립 출처» 는 22.9 % 였다
#   (출처 40.9 %p vs 모델 다양성 11.3 %p = 3.6 배). 이 훅이 하드 차단하는 축이 약한 쪽이고,
#   `panel(codex, gemini)` 가 «같은 diff» 를 읽은 패널이면 62.9 % 팔인데 기록은 강한 값으로 남는다.
#   이 토큰은 그 구분을 «말할 수 있게» 만든다 — SHARED 를 불법으로 만드는 것이 아니다.
EVOK='residency=CLEAN(files=3)'
evcheck() { rescheck "$1" "$GRACE_EV" "$3" "$4" "$2"; }   # $1=fname $2=label $3=body $4=expect

evcheck e1 "e1 panel + residency 만 있고 evidence= 없음 → BLOCK (구분이 안 적히면 강한 값으로 오독된다)" \
  "crossfamily: panel(codex) — $EVOK · R1..R2, 4 findings" BLOCK
evcheck e2 "e2 evidence=SHARED(...) — 정직한 약한 팔도 **통과한다**(불법이 아니다)" \
  "crossfamily: panel(codex) — $EVOK · evidence=SHARED(same staged diff sent to both) · R1, 3 findings" PASS
evcheck e3 "e3 evidence=INDEPENDENT(...) → PASS" \
  "crossfamily: panel(codex, gemini) — $EVOK · evidence=INDEPENDENT(each ran its own checkout) · R1..R2" PASS
evcheck e4 "e4 evidence=MIXED(...) → PASS" \
  "crossfamily: panel(codex, gemini) — $EVOK · evidence=MIXED(codex got the diff, gemini ran the repo) · R1" PASS
evcheck e5 "e5 닫힌 집합 밖 evidence=PARTIAL(...) → BLOCK" \
  "crossfamily: panel(codex) — $EVOK · evidence=PARTIAL(some) · R1" BLOCK
evcheck e6 "e6 닫는 괄호 없는 evidence=SHARED(x → 형식 위반(부재로 읽히면 fail-open)" \
  "crossfamily: panel(codex) — $EVOK · evidence=SHARED(same diff · R1" BLOCK
evcheck e7 "e7 토큰 두 개 → BLOCK (읽는 쪽이 첫 것만 취한다)" \
  "crossfamily: panel(codex) — $EVOK · evidence=SHARED(same diff to both) · evidence=INDEPENDENT(no) · R1" BLOCK
evcheck e8 "e8 SHARED 본문이 공허(한 낱말) → BLOCK — 약한 팔을 «기록된 것처럼» 남기지 못한다" \
  "crossfamily: panel(codex) — $EVOK · evidence=SHARED(diff) · R1, 3 findings" BLOCK
evcheck e8b "e8b 컨트롤 — INDEPENDENT 는 자기서술적이라 한 낱말도 통과(과차단이 override 를 훈련시킨다)" \
  "crossfamily: panel(codex) — $EVOK · evidence=INDEPENDENT(rerun) · R1, 3 findings" PASS
evcheck e8c "e8c SHARED 본문이 자리표시자 <...> → BLOCK" \
  "crossfamily: panel(codex) — $EVOK · evidence=SHARED(<what>) · R1" BLOCK
evcheck e9 "e9 컨트롤 — 패널이 안 돌았으면(DEGRADED) evidence= 는 요구하지 않는다(전면 요구가 아니다)" \
  'crossfamily: DEGRADED_SINGLE_FAMILY — residency=CLEAN(files=0) probed codex/agy/gemini, 0 reachable' PASS
rescheck e10 "2026-09-11" "crossfamily: panel(codex) — $EVOK · R1..R2, 4 findings" PASS \
  "e10 grace 경계 — grace 하루 전 날짜의 마커는 evidence= 없이도 통과(소급 없음)"

echo "· cross-family(agy) 가 초판 evidence= 에서 찾은 여섯 결함 — 전부 실행으로 재현 후 수리 ·"
evcheck e11 "e11 🟥 중첩 한 겹은 정당하다 — MIXED(codex(diff), gemini(repo)) (초판은 본문이 'codex(diff' 로 잘려 과차단)" \
  "crossfamily: panel(codex) — $EVOK · evidence=MIXED(codex(diff), gemini(repo)) · R1" PASS
evcheck e11b "e11b 두 겹 중첩은 여전히 형식 위반(무한 중첩을 정규식으로 쫓지 않는다)" \
  "crossfamily: panel(codex) — $EVOK · evidence=SHARED(a(b(c))) · R1" BLOCK
evcheck e12 "e12 🟥 INDEPENDENT() 빈 본문 → BLOCK (초판은 통과 — «길이 미검사» 를 «본문 없어도 됨» 으로 접었다)" \
  "crossfamily: panel(codex) — $EVOK · evidence=INDEPENDENT() · R1" BLOCK
evcheck e12b "e12b 🟥 INDEPENDENT(<what>) 자리표시자 → BLOCK (초판 통과)" \
  "crossfamily: panel(codex) — $EVOK · evidence=INDEPENDENT(<what>) · R1" BLOCK
evcheck e12c "e12c 컨트롤 — INDEPENDENT(rerun) 은 짧아도 통과(길이 바는 SHARED/MIXED 에만)" \
  "crossfamily: panel(codex) — $EVOK · evidence=INDEPENDENT(rerun) · R1" PASS
evcheck e13 "e13 🟥 하이픈 복합어 SHARED(same-diff) → PASS (초판은 wc -w 로 1 낱말이라 과차단)" \
  "crossfamily: panel(codex) — $EVOK · evidence=SHARED(same-diff) · R1" PASS
evcheck e13b "e13b 🟥 한국어 본문 SHARED(동일 프롬프트 파일) → PASS — 이 레포는 근거를 한국어로 쓴다" \
  "crossfamily: panel(codex) — $EVOK · evidence=SHARED(동일 프롬프트 파일) · R1" PASS
evcheck e13c "e13c 컨트롤 — SHARED(diff) 는 여전히 너무 얇다(어느 산출물인지 안 말한다)" \
  "crossfamily: panel(codex) — $EVOK · evidence=SHARED(diff) · R1" BLOCK
rescheck e14 "2026-09-11" "crossfamily: panel(codex) — $EVOK · evidence=PARTIAL(some) · R1" BLOCK \
  "e14 🟥 pre-grace 라도 «쓴 토큰» 의 형식은 본다 — 부재는 면제, 오작성은 면제 아님(초판 통과)"
rescheck e14b "2026-09-11" "crossfamily: panel(codex) — $EVOK · R1..R2, 4 findings" PASS \
  "e14b 컨트롤 — pre-grace + 토큰 부재는 그대로 통과(면제가 살아 있다)"
# e15 — 상수 미주입이 «조용히 grace 를 끄는» 것이 아니라 크게 죽는지. 다른 레인과 러너가 달라 직접 돈다.
N=$((N+1))
resfix "crossfamily: panel(codex) — $EVOK · R1..R2" "2026-09-11" e15
_E15=$(bash -c "RESIDENCY_TOKEN_GRACE_DATE='$GRACE_RES'; source '$T/fn.sh'; validate_crossfamily_leg '$T/.axes_23_passed_fix_x_e15_2026-09-11.marker'" 2>&1)
if printf '%s' "$_E15" | grep -q 'EVIDENCE_TOKEN_GRACE_DATE unset'; then
  echo "✅ e15 🟥 상수 미주입 → 크게 죽는다(초판은 조용히 grace 를 꺼서 pre-grace 마커 전부를 막았다) → BLOCK"
else
  echo "❌ e15 상수 미주입 — 가드가 안 울렸다: $(printf '%s' "$_E15" | head -2)"; FAIL=1
fi

echo
if [ "$FAIL" -eq 0 ]; then echo "✅ all $N fixtures behave"; else echo "❌ regression ($N fixtures run)"; fi
exit "$FAIL"

#!/usr/bin/env bash
# test_tikitaka_score_lanes.sh — `scripts/tikitaka_score.py` 회귀 앵커.
#
# 지키는 것은 «판별력» 이지 «초록» 이 아니다. 이 레인이 박는 것 넷:
#   ① known-pair 가 **갈린다**(사전등록 §4 F2 — 안 갈리면 본측정 금지)
#   ② 공집합·부재가 **PASS 로 접히지 않는다**(§2-ⓑ · [[feedback_not_found_is_not_zero_family]])
#   ③ 계기 사망(추출 0 · 세션 끊김 · spec 불일치)이 **조용한 통과가 아니라 rc=3** 이다
#   ④ 🟥 **되돌림** — 채점 조건을 하나씩 죽이면 **정확히 그 레인만** 빨개지는가
#      ([[feedback_anchor_can_be_decorative]] — 적용확인 → 실행 → 복원 3단)
#
# 🟥 레인이 자기 수리와 같은 어휘로 짜이면 초록인데 안 잡힌다
#    ([[feedback_lane_vocabulary_blind_to_its_own_fix]]). 그래서 R1·R2 는 «채점 결과» 가
#    아니라 **소스의 특정 분기** 를 죽이고, 죽였는지를 grep 으로 먼저 확인한 뒤 실행한다.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SC="$HERE/tikitaka_score.py"
FIX="$HERE/fixtures/tikitaka_knownpair_2026-09-19"
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); printf '  ✅ %s\n' "$1"; }
no(){ FAIL=$((FAIL+1)); printf '  ❌ %s — %s\n' "$1" "${2:-}"; }
echo "── test_tikitaka_score_lanes ──"

[ -f "$SC" ] || { no "L1 채점기 존재" "$SC"; echo "FAILED=1"; exit 1; }
OUT=$(python3 -c "import py_compile,sys; py_compile.compile(sys.argv[1], doraise=True)" "$SC" 2>&1); RC=$?
[ "$RC" -eq 0 ] && ok "L1 구문" || no "L1 구문" "$OUT"

# ── L2 known-pair 교정 — 🟥 사전등록 §2-ⓓ 의 게이트 그 자체 ─────────────────────────
OUT=$(python3 "$SC" --selftest 2>&1); RC=$?
[ "$RC" -eq 0 ] && ok "L2 known-pair 갈림 (selftest rc=0)" || no "L2 known-pair" "rc=$RC
$OUT"
# 🟥 «갈렸다» 를 rc 하나로 믿지 않는다 — 판별력 줄을 본문에서 직접 확인한다.
printf '%s' "$OUT" | /usr/bin/grep -q "판별력(집계): 픽스처 5 개가 4 개 등급으로 갈린다" \
  && ok "L2b 집계 판별력: 픽스처 5 개 → 4 등급" \
  || no "L2b 집계 판별력" "$(printf '%s' "$OUT" | /usr/bin/grep '판별력(집계)')"
# 🟥 2026-09-19 적대검증 Q3 이 연 구멍: 집계가 갈려도 **개별 조건**은 한 방향만 검정될 수 있다.
#    C1/C2 가 하드코딩 PASS 여도 초판 known-pair 는 전부 통과했다. 조건마다 확인한다.
for _C in C1 C2 C3 A1 A2; do
  printf '%s' "$OUT" | /usr/bin/grep -q "판별력($_C): PASS·FAIL 둘 다 검정됨" \
    && ok "L2c-$_C 조건 판별력: PASS·FAIL 둘 다 검정됨" \
    || no "L2c-$_C 조건 판별력" "$_C 은 한 방향으로만 검정된다 — 하드코딩돼 있어도 known-pair 가 통과한다"
done

# ── L3 세 픽스처의 «조건별» 판정이 설계대로인가 (등급만 맞고 이유가 틀린 경우를 막는다) ──
# [[feedback_count_is_true_but_referent_drifted]] — 값은 맞는데 가리키는 게 달라질 수 있다.
_score(){ python3 "$SC" --transcript "$FIX/$1.transcript.txt" --spec "$FIX/spec.txt" \
                       --turns "$FIX/turns.txt" --expect-resumed 2>&1; }
P_OUT=$(_score positive);  P_RC=$?
N_OUT=$(_score negative);  N_RC=$?
S_OUT=$(_score split);     S_RC=$?
printf '%s' "$P_OUT" | /usr/bin/grep -q "C1=PASS C2=PASS C3=PASS A1=PASS A2=PASS" \
  && [ "$P_RC" -eq 0 ] && ok "L3 positive: 다섯 조건 전부 PASS · rc=0" \
  || no "L3 positive" "rc=$P_RC · $(printf '%s' "$P_OUT" | /usr/bin/tail -2)"
printf '%s' "$N_OUT" | /usr/bin/grep -q "C1=PASS C2=PASS C3=FAIL A1=UNMEASURED A2=FAIL" \
  && ok "L3b negative: C3 가 FAIL · A1 은 UNMEASURED(공집합은 통과 아님) · A2 FAIL" \
  || no "L3b negative" "$(printf '%s' "$N_OUT" | /usr/bin/tail -2)"
printf '%s' "$S_OUT" | /usr/bin/grep -q "C1=PASS C2=PASS C3=PASS A1=FAIL A2=PASS" \
  && ok "L3c split: 🟥 수렴 O · 반영 X 가 한 등급으로 접히지 않는다" \
  || no "L3c split" "$(printf '%s' "$S_OUT" | /usr/bin/tail -2)"

# ── L3d 계약 결박 — 픽스처가 «러너가 실제로 쓰는 형식» 인가 ──────────────────────────
# [[feedback_spec_example_breaks_its_implementation]] — 계약과 파서가 다른 표기를 가정하면
# 스펙대로 쓴 쪽만 조용히 통과한다. 픽스처는 손으로 썼으므로, 러너의 **소스**가 내는 형식과
# 지금도 같은지 실행으로 확인한다(읽고 기억한 것은 앵커가 아니다).
RUNNER="$HERE/sim_isolated_run.sh"
if [ -f "$RUNNER" ]; then
  /usr/bin/grep -q "===== turn %s (rc=%s) =====" "$RUNNER" \
    && ok "L3d 러너가 지금도 '===== turn %s (rc=%s) =====' 를 쓴다 (픽스처 감싸개와 일치)" \
    || no "L3d 턴 마커 계약" "러너의 마커 형식이 바뀌었다 — 픽스처와 채점기가 같이 낡았다"
  /usr/bin/grep -q "printf 'turn\\\\trc\\\\tsession_id\\\\tresult_bytes\\\\tnote" "$RUNNER" \
    && ok "L3e 러너 turns.tsv 헤더가 지금도 turn/rc/session_id/... 순서다 (F3 파싱 전제)" \
    || no "L3e tsv 헤더 계약" "session_id 가 3번째 칸이 아니면 F3 검사가 엉뚱한 칸을 읽는다"
else
  no "L3d/L3e 계약 결박" "러너가 없다 — 형식 일치 미검증(통과 아님)"
fi

D="$(mktemp -d 2>/dev/null)" || D=""
[ -n "$D" ] && [ -w "$D" ] || { no "L4 환경" "mktemp -d 불가 — 이하 레인 미측정(통과 아님)"; echo "PASS=$PASS FAIL=$FAIL"; echo "FAILED=1"; exit 1; }

# ── L4 뚫리는 표기 — 산문 드롭 줄이 «남긴 행» 으로 안 읽히는가 ───────────────────────
# positive turn3 의 드롭 줄은 쉼표 7개(칸 8개) + P1 토큰을 갖는다. 칸 수만 세는 추출기는
# 이걸 행으로 읽고 C 가 8 이 된다. 컨트롤 = 그 줄이 실제로 그 모양인지 먼저 확인한다.
DROPLINE=$(/usr/bin/grep -m1 "이번 스프린트에서 제외" "$FIX/positive.transcript.txt")
NCOMMA=$(printf '%s' "$DROPLINE" | /usr/bin/tr -cd ',' | /usr/bin/wc -c | /usr/bin/tr -d ' ')
if [ "${NCOMMA:-0}" -ge 7 ] && printf '%s' "$DROPLINE" | /usr/bin/grep -q "P1"; then
  ok "L4 픽스처 컨트롤: 드롭 줄이 쉼표 ${NCOMMA}개 + P1 토큰을 실제로 갖는다 (뚫리는 표기 존재)"
else
  no "L4 픽스처 컨트롤" "드롭 줄이 뚫리는 표기가 아니다 — 쉼표=${NCOMMA} · 이 레인은 아무것도 안 잰다"
fi
printf '%s' "$P_OUT" | /usr/bin/grep -q "C  (turn3) n=4 " \
  && ok "L4b 그런데도 C 는 n=4 — 드롭 줄이 행으로 안 세어졌다" \
  || no "L4b C 개수" "$(printf '%s' "$P_OUT" | /usr/bin/grep 'C  (turn3)')"
# T4 가 산문으로 «범위 밖» 을 다시 언급해도 재등장으로 안 읽히는가 (두 번째 뚫리는 표기)
/usr/bin/grep -q "범위 밖(이번 계획에 없다): TC_F_003" "$FIX/positive.transcript.txt" \
  && printf '%s' "$P_OUT" | /usr/bin/grep -q "A1 버린 항목이 T4 에 재등장 안함: PASS" \
  && ok "L4c T4 가 버린 항목을 산문으로 언급해도 A1 은 PASS (거짓 FAIL 방지)" \
  || no "L4c T4 산문 언급" "$(printf '%s' "$P_OUT" | /usr/bin/grep 'A1 ')"

# ── L5 계기 사망은 rc=3 — 조용한 통과가 아니다 ──────────────────────────────────────
# L5a 세션 끊김(F3): turn2+ 의 session_id 가 NONE 이고 --expect-resumed 면 CONTAMINATED.
/usr/bin/sed 's/^\([234]\)	0	fixture-sid-0000/\1	0	NONE/' "$FIX/positive.turns.tsv" > "$D/none.turns.tsv"
/usr/bin/grep -cq "" "$D/none.turns.tsv" 2>/dev/null
/usr/bin/grep -q "	NONE	" "$D/none.turns.tsv" \
  && ok "L5a 컨트롤: 변형된 tsv 에 NONE 이 실제로 들어갔다" \
  || no "L5a 컨트롤" "sed 가 안 먹었다 — 아래 판정은 무의미"
OUT=$(python3 "$SC" --transcript "$FIX/positive.transcript.txt" --spec "$FIX/spec.txt" \
        --turns "$FIX/turns.txt" --turns-tsv "$D/none.turns.tsv" --expect-resumed 2>&1); RC=$?
[ "$RC" -eq 3 ] && printf '%s' "$OUT" | /usr/bin/grep -q "INSTRUMENT=CONTAMINATED" \
  && ok "L5b F3: session_id 없는 ARM 은 rc=3 CONTAMINATED (채점 안 함)" \
  || no "L5b F3" "rc=$RC · $(printf '%s' "$OUT" | /usr/bin/tail -2)"
# L5b-ctrl — 같은 tsv 라도 --expect-resumed 없으면(=CTRL 팔) 채점은 진행된다
OUT=$(python3 "$SC" --transcript "$FIX/positive.transcript.txt" --spec "$FIX/spec.txt" \
        --turns "$FIX/turns.txt" --turns-tsv "$D/none.turns.tsv" 2>&1); RC=$?
[ "$RC" -eq 0 ] && ok "L5c 컨트롤: --expect-resumed 없으면 같은 입력이 통과 (과차단 아님)" \
  || no "L5c 과차단" "rc=$RC"

# L5d spec 불일치: T2 에 없는 제약 토큰을 spec 이 선언하면 채점 무효.
{ echo "constraint=99건"; echo "revert_tol=1"; echo "role_A=1"; echo "role_C=3"; echo "role_T4=4"; } > "$D/bad.spec"
OUT=$(python3 "$SC" --transcript "$FIX/positive.transcript.txt" --spec "$D/bad.spec" \
        --turns "$FIX/turns.txt" 2>&1); RC=$?
[ "$RC" -eq 3 ] && printf '%s' "$OUT" | /usr/bin/grep -q "INSTRUMENT=SPEC-MISMATCH" \
  && ok "L5d spec 의 제약이 되밀기 턴에 없으면 rc=3 (결과 보고 spec 고치는 경로 차단)" \
  || no "L5d SPEC-MISMATCH" "rc=$RC · $(printf '%s' "$OUT" | /usr/bin/tail -2)"

# L5e 추출 0: turn1 에 행이 하나도 없으면 NO-BASELINE. 「팔이 안 냈다」와 「추출기가 죽었다」가
#      같은 얼굴이므로 PASS/FAIL 이 아니라 rc=3 이다.
/usr/bin/sed 's/^| [0-9] | 인증/X 인증/' "$FIX/positive.transcript.txt" > "$D/norows.txt"
OUT=$(python3 "$SC" --transcript "$D/norows.txt" --spec "$FIX/spec.txt" --turns "$FIX/turns.txt" 2>&1); RC=$?
[ "$RC" -eq 3 ] && printf '%s' "$OUT" | /usr/bin/grep -q "INSTRUMENT=NO-BASELINE" \
  && ok "L5e 행 추출 0 → rc=3 NO-BASELINE (조용한 0 금지)" \
  || no "L5e NO-BASELINE" "rc=$RC · $(printf '%s' "$OUT" | /usr/bin/tail -2)"

# L5f T4 가 비었다(F4) → UNMEASURED
/usr/bin/awk '/^===== turn 4 /{print; print ""; exit} {print}' "$FIX/positive.transcript.txt" > "$D/emptyT4.txt"
OUT=$(python3 "$SC" --transcript "$D/emptyT4.txt" --spec "$FIX/spec.txt" --turns "$FIX/turns.txt" 2>&1); RC=$?
[ "$RC" -eq 3 ] && printf '%s' "$OUT" | /usr/bin/grep -q "APPLICATION=UNMEASURED" \
  && ok "L5f F4: T4 가 비면 APPLIED 가 아니라 UNMEASURED (rc=3)" \
  || no "L5f F4" "rc=$RC · $(printf '%s' "$OUT" | /usr/bin/tail -2)"

# L5g 마커 주입: 팔이 `===== turn N (rc=0) =====` 를 본문에 인용하면 가짜 턴이 생긴다.
#      ⓐ 불연속 번호 → TURN-SHAPE · ⓑ 하필 «다음 연속 번호» → 번호로는 못 잡으므로
#      turns 파일 턴 개수 결박(TURN-COUNT)이 잡는다. 둘 다 rc=3, 조용한 오채점 아님.
/usr/bin/awk '{print} /^tc_seed.md/{print "===== turn 9 (rc=0) ====="; print "위는 인용이다."}' \
  "$FIX/positive.transcript.txt" > "$D/inject_gap.txt"
OUT=$(python3 "$SC" --transcript "$D/inject_gap.txt" --spec "$FIX/spec.txt" --turns "$FIX/turns.txt" 2>&1); RC=$?
[ "$RC" -eq 3 ] && printf '%s' "$OUT" | /usr/bin/grep -q "INSTRUMENT=TURN-SHAPE" \
  && ok "L5g 마커 주입(불연속 번호) → rc=3 TURN-SHAPE" \
  || no "L5g 마커 주입 ⓐ" "rc=$RC · $(printf '%s' "$OUT" | /usr/bin/tail -2)"
/usr/bin/awk '{print} /^Day 1 에 셋/{print "===== turn 5 (rc=0) ====="; print "위는 인용이다."}' \
  "$FIX/split.transcript.txt" > "$D/inject_seq.txt"
/usr/bin/grep -c "^===== turn" "$D/inject_seq.txt" | /usr/bin/grep -q "^5$" \
  && ok "L5h 컨트롤: 주입 후 마커가 실제로 5개다 (번호는 1..5 로 «연속» — 번호 검사로는 못 잡는다)" \
  || no "L5h 컨트롤" "주입이 안 됐다 — 아래 판정은 무의미"
OUT=$(python3 "$SC" --transcript "$D/inject_seq.txt" --spec "$FIX/spec.txt" --turns "$FIX/turns.txt" 2>&1); RC=$?
[ "$RC" -eq 3 ] && printf '%s' "$OUT" | /usr/bin/grep -q "INSTRUMENT=TURN-COUNT" \
  && ok "L5i 마커 주입(연속 번호) → rc=3 TURN-COUNT (turns 파일 개수 결박이 잡는다)" \
  || no "L5i 마커 주입 ⓑ" "rc=$RC · $(printf '%s' "$OUT" | /usr/bin/tail -2)"
# L5j 되돌림 — 개수 결박을 죽이면 L5i 가 조용히 통과하는가 (앵커가 장식이 아님을 실행으로)
MUT0="$D/mut_turncount.py"
/usr/bin/sed 's/^        if want and len(ks) != want:/        if False:/' "$SC" > "$MUT0"
if /usr/bin/grep -q "^        if False:$" "$MUT0"; then
  OUT=$(python3 "$MUT0" --transcript "$D/inject_seq.txt" --spec "$FIX/spec.txt" --turns "$FIX/turns.txt" 2>&1); RC=$?
  [ "$RC" -ne 3 ] && ok "R0 되돌림: 개수 결박을 죽이면 주입된 전사본이 채점돼 버린다 (rc=$RC · 결박이 하중선)" \
    || no "R0 되돌림" "죽여도 rc=3 — 다른 가드가 잡고 있어 L5i 는 결박을 안 잰다"
else
  no "R0 컨트롤" "sed 가 안 먹었다 — 되돌림 프로브 미실행(통과 아님)"
fi

# ── R1 되돌림 — 드롭 마커 분기를 죽이면 known-pair 가 깨지는가 ──────────────────────
# 이 분기가 «산문 드롭 줄이 행으로 안 읽히게» 하는 하중선이다. 죽이면 C 가 A 와 같아진다.
MUT1="$D/mut_dropbranch.py"
/usr/bin/sed 's/^        if _has_drop_marker(line):/        if False and _has_drop_marker(line):/' "$SC" > "$MUT1"
if /usr/bin/grep -q "if False and _has_drop_marker(line):" "$MUT1"; then
  ok "R1 컨트롤(적용확인): 드롭 마커 분기가 실제로 죽었다"
  OUT=$(python3 "$MUT1" --transcript "$FIX/positive.transcript.txt" --spec "$FIX/spec.txt" \
          --turns "$FIX/turns.txt" 2>&1); RC=$?
  if [ "$RC" -ne 0 ]; then
    ok "R1b 되돌림: 분기를 죽이면 positive 가 더 이상 CONVERGED/APPLIED 가 아니다 (rc=$RC)"
  else
    no "R1b 되돌림" "죽여도 rc=0 — 이 분기는 장식이고 L4b 는 아무것도 안 잰다"
  fi
  printf '%s' "$OUT" | /usr/bin/grep -q "C  (turn3) n=8" \
    && ok "R1c 되돌림 기전: C 가 4→8 로 부풀었다 (드롭 줄이 행으로 읽힘 — 예측한 바로 그 실패)" \
    || no "R1c 되돌림 기전" "C 개수가 8 이 아니다: $(printf '%s' "$OUT" | /usr/bin/grep 'C  (turn3)')"
else
  no "R1 컨트롤" "sed 가 안 먹었다 — 되돌림 프로브 미실행(통과 아님)"
fi
# R1d 복원 확인 — 원본은 여전히 옳은가 (3단의 3단)
OUT=$(python3 "$SC" --selftest 2>&1); RC=$?
[ "$RC" -eq 0 ] && ok "R1d 복원: 원본 채점기는 여전히 known-pair 를 가른다" || no "R1d 복원" "rc=$RC"

# ── R2 되돌림 — 「공집합은 통과가 아니다」가 하중을 지는가 ───────────────────────────
# 픽스처: turn1~3 = negative(버린 것 명명 없음) + turn4 = positive(4행). 그러면
#   A1 = UNMEASURED(명명 공집합) · A2 = PASS(Δ=4) → APPLICATION=UNMEASURED
# 공집합을 PASS 로 접으면 → APPLICATION=APPLIED. 즉 «축소만 한 산출이 반영 성공» 이 된다.
ES="$D/emptyset.transcript.txt"
/usr/bin/awk '/^===== turn 4 /{exit} {print}' "$FIX/negative.transcript.txt" >  "$ES"
/usr/bin/awk '/^===== turn 4 /{f=1} f{print}' "$FIX/positive.transcript.txt" >> "$ES"
OUT=$(python3 "$SC" --transcript "$ES" --spec "$FIX/spec.txt" --turns "$FIX/turns.txt" 2>&1); RC=$?
printf '%s' "$OUT" | /usr/bin/grep -q "APPLICATION=UNMEASURED" \
  && printf '%s' "$OUT" | /usr/bin/grep -q "A2 원안 A 로 되돌아가지 않음    : PASS" \
  && ok "R2 공집합 픽스처: A2 는 PASS 인데 APPLICATION 은 UNMEASURED (A1 이 접히지 않았다)" \
  || no "R2 공집합 픽스처" "rc=$RC · $(printf '%s' "$OUT" | /usr/bin/tail -3)"
MUT2="$D/mut_emptyset.py"
/usr/bin/sed 's/^    elif not named:$/    elif False:/' "$SC" > "$MUT2"
if /usr/bin/grep -q "^    elif False:$" "$MUT2"; then
  ok "R2b 컨트롤(적용확인): 공집합 가드가 실제로 죽었다"
  OUT=$(python3 "$MUT2" --transcript "$ES" --spec "$FIX/spec.txt" --turns "$FIX/turns.txt" 2>&1)
  printf '%s' "$OUT" | /usr/bin/grep -q "APPLICATION=APPLIED" \
    && ok "R2c 되돌림: 가드를 죽이면 «축소만 한 산출» 이 APPLIED 로 통과한다 (가드가 하중선)" \
    || no "R2c 되돌림" "가드를 죽여도 APPLIED 가 안 된다 — R2 는 아무것도 안 잰다: $(printf '%s' "$OUT" | /usr/bin/tail -2)"
else
  no "R2b 컨트롤" "sed 가 안 먹었다 — 되돌림 프로브 미실행(통과 아님)"
fi

# ── R3 / R4 — 2026-09-19 적대검증(Q4-a·Q4-b)이 연 구멍 둘. 둘 다 «공허참» 계열이다 ──────
# R3: C 가 공집합이면 C1 이 «A 와 다르다» 로 자동 PASS 한다. 실측으로 확인된 결함이었다.
/usr/bin/awk 'BEGIN{t=0} /^===== turn /{t++} {if(t==3 && /^\| [0-9] \| 인증/) next; print}' \
  "$FIX/positive.transcript.txt" > "$D/emptyC.txt"
OUT=$(python3 "$SC" --transcript "$D/emptyC.txt" --spec "$FIX/spec.txt" --turns "$FIX/turns.txt" 2>&1); RC=$?
printf '%s' "$OUT" | /usr/bin/grep -q "^  C  (turn3) n=0" \
  && ok "R3 컨트롤: 픽스처의 C 가 실제로 공집합이다 (n=0)" \
  || no "R3 컨트롤" "C 가 안 비었다 — 아래 판정은 무의미: $(printf '%s' "$OUT" | /usr/bin/grep 'C  (turn3)')"
printf '%s' "$OUT" | /usr/bin/grep -q "INSTRUMENT=NO-COMPROMISE" && [ "$RC" -eq 3 ] \
  && ok "R3b C=∅ → rc=3 NO-COMPROMISE (비교 대상 부재는 등급이 아니다)" \
  || no "R3b C=∅" "rc=$RC · $(printf '%s' "$OUT" | /usr/bin/tail -2)"
MUT3="$D/mut_emptyC.py"; /usr/bin/sed 's/^    if not C:$/    if False:/' "$SC" > "$MUT3"
if [ "$(/usr/bin/grep -c '^    if False:$' "$MUT3")" = "1" ]; then
  OUT=$(python3 "$MUT3" --transcript "$D/emptyC.txt" --spec "$FIX/spec.txt" --turns "$FIX/turns.txt" 2>&1)
  # 🟥 첫 수리는 C1 만 UNMEASURED 로 바꿨고 **APPLIED 를 못 막았다**(반쪽 수리). 그래서 이
  #    프로브는 C1 이 아니라 **최종 APPLICATION** 을 본다 — 실제 피해가 나타나는 자리다.
  printf '%s' "$OUT" | /usr/bin/grep -q "APPLICATION=APPLIED" \
    && ok "R3c 되돌림: 가드를 죽이면 «절충안이 통째로 없는» 전사본이 APPLICATION=APPLIED 를 받는다" \
    || no "R3c 되돌림" "죽여도 APPLIED 가 안 나온다 — R3b 는 아무것도 안 잰다"
else
  no "R3c 컨트롤" "sed 가 정확히 1줄을 못 바꿨다 — 되돌림 프로브 미실행(통과 아님)"
fi
# R4: T4 추출이 죽었을 때 |T4|=0 을 «0 건» 으로 산술에 넣으면 «원안 복귀» 오답이 나온다.
R4ROW='| 1 | 인증 | 재설정 | 링크 | 유효 링크 요청 | 가입 계정 · Chrome | 1. 요청 / 2. 확인 | 화면이 열린다 | TC_F_001 | P0 | account | X |'
{ echo; echo "===== turn 1 (rc=0) ====="; echo "보강안:"; echo "$R4ROW"
  echo; echo "===== turn 2 (rc=0) ====="; echo "접수."
  echo; echo "===== turn 3 (rc=0) ====="; echo "절충안 — 4건, 2일 기준:"; echo "$R4ROW"
  echo; echo "===== turn 4 (rc=0) ====="; echo "실행계획을 산문으로만 적어 표 항목이 추출되지 않는다."; } > "$D/deadT4.txt"
OUT=$(python3 "$SC" --transcript "$D/deadT4.txt" --spec "$FIX/spec.txt" --turns "$FIX/turns.txt" 2>&1); RC=$?
printf '%s' "$OUT" | /usr/bin/grep -q "^  T4 (turn4) n=0" \
  && ok "R4 컨트롤: T4 추출이 실제로 0 이고 |A|=1 이라 Δ=1≤tol 트리거 조건이 성립한다" \
  || no "R4 컨트롤" "$(printf '%s' "$OUT" | /usr/bin/grep 'T4 (turn4)')"
printf '%s' "$OUT" | /usr/bin/grep -q "A2=UNMEASURED" && [ "$RC" -eq 3 ] \
  && ok "R4b |T4|=0 은 부재다 → A2 는 FAIL 이 아니라 UNMEASURED (rc=3, 3 이 1 을 이긴다)" \
  || no "R4b 죽은 T4" "rc=$RC · $(printf '%s' "$OUT" | /usr/bin/tail -2)"
MUT4="$D/mut_deadT4.py"; /usr/bin/sed 's/^    if len(T4) == 0:$/    if False:/' "$SC" > "$MUT4"
if [ "$(/usr/bin/grep -c '^    if False:$' "$MUT4")" = "1" ]; then
  OUT=$(python3 "$MUT4" --transcript "$D/deadT4.txt" --spec "$FIX/spec.txt" --turns "$FIX/turns.txt" 2>&1)
  printf '%s' "$OUT" | /usr/bin/grep -q "APPLICATION=NOT-APPLIED" \
    && ok "R4c 되돌림: 가드를 죽이면 계기사망이 «원안 복귀» 라는 확신에 찬 오답으로 바뀐다" \
    || no "R4c 되돌림" "죽여도 NOT-APPLIED 가 안 나온다 — R4b 는 아무것도 안 잰다"
else
  no "R4c 컨트롤" "sed 가 정확히 1줄을 못 바꿨다 — 되돌림 프로브 미실행(통과 아님)"
fi

# ── L6 spec 검증 — 공허 통과 경로가 막혀 있는가 ─────────────────────────────────────
{ echo "revert_tol=1"; } > "$D/noconstraint.spec"
OUT=$(python3 "$SC" --transcript "$FIX/positive.transcript.txt" --spec "$D/noconstraint.spec" 2>&1); RC=$?
[ "$RC" -eq 2 ] && ok "L6 constraint 없는 spec 은 거부 (C2 가 공허하게 통과하지 않는다)" \
  || no "L6 빈 spec" "rc=$RC"
# L6c — C2 는 «수치로» 를 요구한다. 숫자 없는 제약 토큰은 그 요구를 조용히 지운다.
{ echo "constraint=적당히"; } > "$D/nonnum.spec"
OUT=$(python3 "$SC" --transcript "$FIX/positive.transcript.txt" --spec "$D/nonnum.spec" 2>&1); RC=$?
[ "$RC" -eq 2 ] && printf '%s' "$OUT" | /usr/bin/grep -q "수치로" \
  && ok "L6c 숫자 없는 constraint 는 거부 (C2 의 «수치로» 가 안 지워진다)" \
  || no "L6c 비수치 constraint" "rc=$RC · $(printf '%s' "$OUT" | /usr/bin/tail -1)"
# L6c-ctrl — 숫자가 있으면 같은 경로가 통과한다 (과차단 아님)
{ echo "constraint=4건"; } > "$D/num.spec"
OUT=$(python3 "$SC" --transcript "$FIX/positive.transcript.txt" --spec "$D/num.spec" 2>&1); RC=$?
[ "$RC" -eq 0 ] && ok "L6d 컨트롤: 숫자 있는 constraint 는 통과 (L6c 가 전부를 막는 게 아니다)" \
  || no "L6d 과차단" "rc=$RC"
{ echo "constraint=4건"; echo "role_A=3"; echo "role_C=1"; echo "role_T4=4"; } > "$D/badrole.spec"
OUT=$(python3 "$SC" --transcript "$FIX/positive.transcript.txt" --spec "$D/badrole.spec" 2>&1); RC=$?
[ "$RC" -eq 2 ] && ok "L6b 역순 role 은 거부 (A < C < T4 대화 순서 강제)" || no "L6b role 순서" "rc=$RC"

/bin/rm -rf "$D"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || { echo "FAILED=1"; exit 1; }
exit 0

#!/usr/bin/env bash
# test_finding_pipeline_lanes.sh — regression anchor for the typed-finding pipeline
# (scripts/finding_fleet.sh → scripts/finding_verify.py).
#
# 🟥 What these lanes protect is the DIRECTION OF FAILURE, not a count. Every defect this pipeline can
#    have makes an unreviewed or unverified run look like a clean one: a member that returns prose, a
#    verifier that cannot be reached, a family grading its own findings. Each lane below pins one of
#    those, and the mutant lane checks that removing the guard actually turns a lane red.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
FLEET="$HERE/finding_fleet.sh"; VERIFY="$HERE/finding_verify.py"
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); printf '  ✅ %s\n' "$1"; }
no(){ FAIL=$((FAIL+1)); printf '  ❌ %s — %s\n' "$1" "${2:-}"; }
echo "── test_finding_pipeline_lanes ──"

[ -f "$FLEET" ] && [ -f "$VERIFY" ] || { no "L0 파일 실재" "fleet/verify 없음"; echo "FAILED=1"; exit 1; }
bash -n "$FLEET" && ok "L1a fleet 구문" || no "L1a fleet 구문"
python3 -c "import ast,sys;ast.parse(open(sys.argv[1],encoding='utf-8').read())" "$VERIFY" \
  && ok "L1b verify 구문" || no "L1b verify 구문"

OUT=$(bash "$HERE/finding_fleet.sh" --selftest 2>&1); RC=$?
[ "$RC" -eq 0 ] && ok "L2 fleet selftest (known-pair 4)" || no "L2 fleet selftest" "rc=$RC · $OUT"

D="$(mktemp -d 2>/dev/null)" || D=""
[ -n "$D" ] && [ -w "$D" ] || { no "L3 환경" "mktemp -d 불가 — 레인 미측정(통과 아님)"; echo "PASS=$PASS FAIL=$FAIL"; echo "FAILED=1"; exit 1; }

cat > "$D/f.jsonl" <<'EOS'
{"id":"a1","title":"real defect","file":"x.py","line":3,"severity":"A","producer_family":"alpha"}
{"id":"a2","title":"bogus claim","file":"x.py","line":9,"severity":"S","producer_family":"alpha"}
EOS

# known-pair for the reject stage: a verifier that confirms a1 and rejects a2 must drop exactly a2
cat > "$D/v_ok.sh" <<'EOS'
#!/bin/sh
cat >/dev/null
echo '{"id":"a1","verdict":"confirmed","why":"holds against source"}'
echo '{"id":"a2","verdict":"false-positive","why":"code does not do this"}'
EOS
chmod +x "$D/v_ok.sh"
python3 "$HERE/finding_verify.py" "$D/f.jsonl" --out "$D/o1" --verifier "sh $D/v_ok.sh" --family beta >"$D/s1" 2>&1; RC=$?   # 리터럴 경로 — new-code-anchor 가 «실행» 으로 센다
C=$(wc -l < "$D/o1/confirmed.jsonl" | tr -d ' '); DR=$(wc -l < "$D/o1/dropped.jsonl" | tr -d ' ')
{ [ "$RC" -eq 4 ] && [ "$C" = 1 ] && [ "$DR" = 1 ] && grep -q '"id": "a2"' "$D/o1/dropped.jsonl"; } \
  && ok "L4 거부 단계: false-positive 를 «코드가» 지운다 (confirmed 1 / dropped 1 / rc=4 = 미감사)" \
  || no "L4 거부 단계" "rc=$RC confirmed=$C dropped=$DR"

# 🟥 degrade: no verifier must NOT drop anything, must mark UNVERIFIED, must not exit 0
python3 "$VERIFY" "$D/f.jsonl" --out "$D/o2" --verifier "" --family none >"$D/s2" 2>&1; RC=$?
C=$(wc -l < "$D/o2/confirmed.jsonl" | tr -d ' '); DR=$(wc -l < "$D/o2/dropped.jsonl" | tr -d ' ')
{ [ "$RC" -eq 3 ] && [ "$C" = 2 ] && [ "$DR" = 0 ] && grep -q 'status=UNVERIFIED' "$D/s2"; } \
  && ok "L5 degrade: 검증기 없음 → 아무것도 안 지우고 UNVERIFIED · rc=3 (빈 dropped 가 «깨끗함»으로 안 읽힌다)" \
  || no "L5 degrade" "rc=$RC confirmed=$C dropped=$DR"

# a verifier that fails must degrade the same way, never drop
cat > "$D/v_fail.sh" <<'EOS'
#!/bin/sh
cat >/dev/null
exit 7
EOS
chmod +x "$D/v_fail.sh"
python3 "$VERIFY" "$D/f.jsonl" --out "$D/o3" --verifier "sh $D/v_fail.sh" --family beta >"$D/s3" 2>&1; RC=$?
{ [ "$RC" -eq 3 ] && [ "$(wc -l < "$D/o3/dropped.jsonl" | tr -d ' ')" = 0 ] && grep -q 'verifier exit 7' "$D/s3"; } \
  && ok "L6 검증기 실패 → degrade + 사유가 요약줄에 남는다" || no "L6 검증기 실패" "rc=$RC · $(cat "$D/s3")"

# 🟥 the channel rule: a family never verifies its own findings, even when it answers
python3 "$VERIFY" "$D/f.jsonl" --out "$D/o4" --verifier "sh $D/v_ok.sh" --family alpha >"$D/s4" 2>&1; RC=$?
{ [ "$(wc -l < "$D/o4/dropped.jsonl" | tr -d ' ')" = 0 ] && grep -q 'unverified=2' "$D/s4"; } \
  && ok "L7 자기 계열은 자기 산출을 검증 못 한다 (verdict 있어도 드롭 0 · unverified 2)" \
  || no "L7 자기검증 차단" "rc=$RC · $(cat "$D/s4")"

# schema is enforced: a finding without a title is a usage error, not a silently skipped row
printf '{"id":"x1","file":"x.py"}\n' > "$D/bad.jsonl"
python3 "$VERIFY" "$D/bad.jsonl" --out "$D/o5" --verifier "sh $D/v_ok.sh" --family beta >"$D/s5" 2>&1; RC=$?
{ [ "$RC" -ne 0 ] && grep -q "missing required field" "$D/s5"; } \
  && ok "L8 스키마 위반은 «조용히 건너뛰기» 가 아니라 오류" || no "L8 스키마" "rc=$RC · $(cat "$D/s5")"

# ── drop-side lanes: a deletion stage that is never checked can improve precision by deleting ──────
cat > "$D/a_wrong.sh" <<'EOS'
#!/bin/sh
cat >/dev/null
echo '{"id":"a2","verdict":"wrong-drop","why":"the code does do this at line 9"}'
EOS
cat > "$D/a_right.sh" <<'EOS'
#!/bin/sh
cat >/dev/null
echo '{"id":"a2","verdict":"correct-drop","why":"confirmed the code does not do this"}'
EOS
chmod +x "$D/a_wrong.sh" "$D/a_right.sh"

# L10 — drops with no auditor must not read as a completed run
python3 "$VERIFY" "$D/f.jsonl" --out "$D/oA" --verifier "sh $D/v_ok.sh" --family beta >"$D/sA" 2>&1; RC=$?
{ [ "$RC" -eq 4 ] && grep -q 'drop_audit=UNAUDITED' "$D/sA" && grep -q '^DROPS ' "$D/sA"; }   && ok "L10 드롭이 있는데 감사가 없으면 rc=4 · DROPS 줄이 무조건 찍힌다 (지워서 정밀해지는 것을 못 숨긴다)"   || no "L10 미감사" "rc=$RC · $(cat "$D/sA")"

# L11 — an auditor that calls the drop wrong REINSTATES the finding; it is not advisory
python3 "$VERIFY" "$D/f.jsonl" --out "$D/oB" --verifier "sh $D/v_ok.sh" --family beta   --audit-verifier "sh $D/a_wrong.sh" --audit-family gamma >"$D/sB" 2>&1; RC=$?
C=$(wc -l < "$D/oB/confirmed.jsonl" | tr -d ' '); DR=$(wc -l < "$D/oB/dropped.jsonl" | tr -d ' ')
{ [ "$C" = 2 ] && [ "$DR" = 0 ] && grep -q 'wrong_drops=1' "$D/sB" && grep -q '"reinstated": true' "$D/oB/confirmed.jsonl"; }   && ok "L11 «잘못 지웠다» 판정은 되돌린다 (confirmed 2 · dropped 0 · wrong_drops=1)"   || no "L11 복권" "rc=$RC confirmed=$C dropped=$DR · $(cat "$D/sB")"

# L12 — a correct drop stays dropped, and the run is AUDITED
python3 "$VERIFY" "$D/f.jsonl" --out "$D/oC" --verifier "sh $D/v_ok.sh" --family beta   --audit-verifier "sh $D/a_right.sh" --audit-family gamma >"$D/sC" 2>&1; RC=$?
{ [ "$RC" -eq 0 ] && grep -q 'drop_audit=AUDITED' "$D/sC" && grep -q 'wrong_drops=0' "$D/sC"   && [ "$(wc -l < "$D/oC/dropped.jsonl" | tr -d ' ')" = 1 ]; }   && ok "L12 옳은 드롭은 남고 run 은 AUDITED·rc=0" || no "L12 정상 감사" "rc=$RC · $(cat "$D/sC")"

# L13 — the family that made the drop may not audit it
python3 "$VERIFY" "$D/f.jsonl" --out "$D/oD" --verifier "sh $D/v_ok.sh" --family beta   --audit-verifier "sh $D/a_wrong.sh" --audit-family beta >"$D/sD" 2>&1; RC=$?
{ [ "$RC" -eq 4 ] && grep -q 'drop_audit=UNAUDITED' "$D/sD" && grep -q 'refused' "$D/sD"; }   && ok "L13 드롭을 한 계열은 그 드롭을 감사 못 한다 (거부 + UNAUDITED)" || no "L13 자기감사 차단" "rc=$RC · $(cat "$D/sD")"

# L14 — producer auditing its own reinstated claim is allowed but recorded as an appeal
python3 "$VERIFY" "$D/f.jsonl" --out "$D/oE" --verifier "sh $D/v_ok.sh" --family beta   --audit-verifier "sh $D/a_wrong.sh" --audit-family alpha >"$D/sE" 2>&1
grep -q '"audit_role": "appeal"' "$D/oE/confirmed.jsonl"   && ok "L14 생산자가 자기 주장을 복권시키면 «appeal» 로 기록된다 (숨기지 않는다)"   || no "L14 appeal 기록" "$(cat "$D/sE")"

# L9 revert probe — remove the never-self-verify guard and L7 must go red
MUT="$D/verify_mut.py"
# 🟥 «앵커가 움직였다» 와 «앵커가 장식이다» 는 다른 사건인데 초판은 둘을 같은 메시지로 냈다.
#    2026-09-09 에 실제로 첫째가 났고(가드가 두 갈래로 갈리며 줄이 바뀜) 출력은 둘째라고 말했다.
MUTERR=$(python3 - "$VERIFY" "$MUT" 2>&1 <<'PY'
import sys
src, dst = sys.argv[1], sys.argv[2]
s = open(src, encoding="utf-8").read()
key = '        if prod == a.family:'
assert key in s, "ANCHOR-MOVED: the same-family guard this probe pins to is not in the file"
s = s.replace(key, '        if False:')
open(dst, "w", encoding="utf-8").write(s)
PY
); MUTRC=$?
if [ "$MUTRC" -ne 0 ] || [ ! -s "$MUT" ]; then
  no "L9 되돌림 (뮤턴트 생성 실패)" "$(printf '%s' "$MUTERR" | tail -1) — 앵커가 «움직인» 것이지 «장식» 이 아니다"
else
python3 "$MUT" "$D/f.jsonl" --out "$D/o6" --verifier "sh $D/v_ok.sh" --family alpha >"$D/s6" 2>&1
{ [ "$(wc -l < "$D/o6/dropped.jsonl" | tr -d ' ')" = 1 ]; } \
  && ok "L9 되돌림: 가드를 지우면 자기 계열이 자기 것을 지운다 (레인이 실물을 잰다)" \
  || no "L9 되돌림" "가드를 지워도 드롭 0 — L7 은 장식이다"
fi

# ══ 접착 코드 레인 (2026-09-09) — finding_verifier.sh (G1) · finding_pipeline.sh (G2) · defeater (G6) ══
# 🟥 이 레인들이 지키는 것도 «방향»이다. 래퍼가 답을 못 받았는데 0 을 돌려주면 verify 는 그것을
#    «판정 없음 → unverified» 가 아니라 «빈 판정»으로 삼키고, 파이프라인은 초록으로 끝난다.
VERIFIER="$HERE/finding_verifier.sh"; PIPE="$HERE/finding_pipeline.sh"
if [ ! -f "$VERIFIER" ] || [ ! -f "$PIPE" ]; then
  no "L15 접착 코드 실재" "finding_verifier.sh / finding_pipeline.sh 부재 — skipped, NOT passed"
else
bash -n "$VERIFIER" && ok "L15a verifier 구문" || no "L15a verifier 구문"
bash -n "$PIPE"     && ok "L15b pipeline 구문" || no "L15b pipeline 구문"

printf 'x = 1\n' > "$D/tgt.py"

# 가짜 CLI — 배너/펜스로 감싸고, enum 밖 verdict 를 하나 섞는다
cat > "$D/fake_ok.sh" <<'EOS'
#!/bin/sh
cat >/dev/null
echo "== banner the model likes to print =="
echo '```json'
echo '{"id":"a1","verdict":"confirmed","why":"line 3 does this"}'
echo '{"id":"a2","verdict":"probably-fine","why":"out of enum"}'
echo '{"id":"a2","verdict":"false-positive","why":"line 9 says otherwise"}'
echo '```'
EOS
chmod +x "$D/fake_ok.sh"
cat > "$D/fake_mute.sh" <<'EOS'
#!/bin/sh
cat >/dev/null
echo "I looked at the file but will not answer in JSON."
EOS
chmod +x "$D/fake_mute.sh"

# L16 — 배너/펜스를 견디고, enum 밖 verdict 는 «강제 변환» 이 아니라 «드롭» 이다
V16=$(FH_CODEX_BIN="$D/fake_ok.sh" bash "$VERIFIER" --family codex --target "$D/tgt.py" < "$D/f.jsonl" 2>/dev/null); RC=$?
N16=$(printf '%s\n' "$V16" | grep -c '^{')
{ [ "$RC" -eq 0 ] && [ "$N16" = 2 ] && printf '%s' "$V16" | grep -q '"verdict": "false-positive"' \
  && ! printf '%s' "$V16" | grep -q 'probably-fine'; } \
  && ok "L16 래퍼: 배너/펜스 견딤 · enum 밖 verdict 드롭 (2건만 통과)" \
  || no "L16 래퍼 파싱" "rc=$RC n=$N16 · $V16"

# L17 — 빈 입력은 «물어본 게 없다» 이므로 rc=0 · 출력 0 (CLI 를 부르지도 않는다)
V17=$(FH_CODEX_BIN="$D/fake_ok.sh" bash "$VERIFIER" --family codex --target "$D/tgt.py" < /dev/null 2>/dev/null); RC=$?
{ [ "$RC" -eq 0 ] && [ -z "$V17" ]; } && ok "L17 빈 입력 → rc=0 · 출력 0" || no "L17 빈 입력" "rc=$RC out=$V17"

# L18 🟥 degrade 방향의 핵심 — 답을 «못 받은» 것은 rc=3 이지 rc=0 이 아니다
V18=$(FH_CODEX_BIN="$D/fake_mute.sh" bash "$VERIFIER" --family codex --target "$D/tgt.py" < "$D/f.jsonl" 2>/dev/null); RC=$?
{ [ "$RC" -eq 3 ] && [ -z "$V18" ]; } \
  && ok "L18 파싱 가능한 판정 0 → rc=3 (침묵을 «통과» 로 접지 않는다)" || no "L18 무응답 degrade" "rc=$RC out=$V18"

# L19 — 사용법 가드: --target 없으면 rc=2, 모르는 계열이면 rc=2
bash "$VERIFIER" --family codex < /dev/null >/dev/null 2>&1; [ $? -eq 2 ] \
  && ok "L19a --target 부재 → rc=2" || no "L19a --target 가드"
echo '{"id":"a1","title":"t"}' | bash "$VERIFIER" --family nosuch --target "$D/tgt.py" >/dev/null 2>&1; [ $? -eq 2 ] \
  && ok "L19b 모르는 계열 → rc=2" || no "L19b 계열 가드"

# ── L20~L22 드라이버 ────────────────────────────────────────────────────────────────────────────
# 두 계열이 각각 한 건씩 내는 가짜 fleet. 그래야 «두 갈래 분할» 이 실제로 갈린다.
cat > "$D/m_codex.sh" <<'EOS'
#!/bin/sh
cat >/dev/null
echo '{"title":"codex claim","file":"tgt.py","line":1,"severity":"A","defeater":"line 1 would differ"}'
EOS
cat > "$D/m_gem.sh" <<'EOS'
#!/bin/sh
cat >/dev/null
echo '{"title":"gemini claim","file":"tgt.py","line":1,"severity":"S","defeater":"no such call site"}'
EOS
chmod +x "$D/m_codex.sh" "$D/m_gem.sh"
printf 'codex|logic|%s\ngemini|security|%s\n' "sh $D/m_codex.sh" "sh $D/m_gem.sh" > "$D/fleet.tbl"

# 두 계열 모두 «상대편 것은 confirmed» 라고 답하는 가짜 검증기
# 🟥 이 가짜 CLI 는 stdin «과» 인자를 «둘 다» 읽어야 한다 — finding_verifier.sh 의 codex 갈래는
#    프롬프트를 stdin 으로, gemini 갈래는 `-p` 인자로 준다. stdin 만 읽는 픽스처를 쓰면 gemini
#    갈래가 «답을 못 받았다»(rc=3)로 떨어지고, 그건 코드 결함처럼 보이지만 죽은 컨트롤이다.
#    (실측 2026-09-09: 이 레인의 첫 판이 정확히 그렇게 L20 을 거짓 적색으로 만들었다.)
cat > "$D/fake_conf.sh" <<'EOS'
#!/bin/sh
IN=$(cat)
[ -n "$IN" ] || IN="$*"
printf '%s\n' "$IN" | tr ',' '\n' | sed -n 's/.*"id": *"\([^"]*\)".*/{"id":"\1","verdict":"confirmed","why":"checked"}/p'
EOS
chmod +x "$D/fake_conf.sh"

P20=$(FH_CODEX_BIN="$D/fake_conf.sh" FH_AGY_BIN="$D/fake_conf.sh" \
      bash "$PIPE" "$D/tgt.py" --out "$D/pipe20" --fleet "$D/fleet.tbl" 2>"$D/pipe20.err"); RC=$?
SUM=$(printf '%s\n' "$P20" | grep '^PIPELINE ')
{ [ "$RC" -eq 0 ] && printf '%s' "$SUM" | grep -q 'confirmed=2' && printf '%s' "$SUM" | grep -q 'unverified=0'; } \
  && ok "L20 드라이버: 두 계열 분할로 «양쪽 다» 판정된다 (unverified=0)" \
  || no "L20 두 갈래 분할" "rc=$RC · $SUM · $(tail -3 "$D/pipe20.err")"

# L21 🟥 한 계열만 있으면 그 findings 는 교차검증이 구조적으로 불가 — 초록이 아니라 rc=3
printf 'codex|logic|%s\n' "sh $D/m_codex.sh" > "$D/fleet1.tbl"
FH_CODEX_BIN="$D/fake_conf.sh" bash "$PIPE" "$D/tgt.py" --out "$D/pipe21" --fleet "$D/fleet1.tbl" \
  >"$D/p21" 2>"$D/p21.err"; RC=$?
{ [ "$RC" -eq 3 ] && grep -q 'cannot be cross-verified' "$D/p21.err"; } \
  && ok "L21 단일 계열 fleet → rc=3 (같은 계열 자기검증으로 «통과» 시키지 않는다)" \
  || no "L21 단일 계열 degrade" "rc=$RC · $(cat "$D/p21.err")"

# L22 — fleet 이 아무것도 못 내면 UNREVIEWED(rc=3) 이지 clean 이 아니다
cat > "$D/m_none.sh" <<'EOS'
#!/bin/sh
cat >/dev/null
EOS
chmod +x "$D/m_none.sh"
printf 'codex|logic|%s\ngemini|security|%s\n' "sh $D/m_none.sh" "sh $D/m_none.sh" > "$D/fleet0.tbl"
bash "$PIPE" "$D/tgt.py" --out "$D/pipe22" --fleet "$D/fleet0.tbl" >"$D/p22" 2>&1; RC=$?
{ [ "$RC" -eq 3 ] && grep -q 'UNREVIEWED' "$D/p22"; } \
  && ok "L22 findings 0 → UNREVIEWED rc=3 (빈 목록은 clean 이 아니다)" || no "L22 UNREVIEWED" "rc=$RC · $(cat "$D/p22")"

# L23 되돌림 프로브 — pick_verifier 가 «생산자와 다른 계열» 을 고르는 줄을 죽이면 L20 이 빨개져야 한다
# 🟥 뮤턴트는 «의존 파일 옆에» 두어야 한다. finding_pipeline.sh 는 자기 위치에서 fleet/verify/
#    verifier 를 찾으므로, 뮤턴트만 임시 디렉터리에 두면 프로브는 «가드가 죽었나» 가 아니라
#    «파일이 없나» 를 잰다 — 빨간색이 나오지만 이유가 다르다(실측 2026-09-09, 이 레인의 첫 판).
MUTD="$D/mut"; mkdir -p "$MUTD"
cp "$HERE/finding_fleet.sh" "$HERE/finding_verify.py" "$HERE/finding_verifier.sh" "$MUTD/"
MUTP="$MUTD/finding_pipeline.sh"
MUT_ERR="$D/mut23.err"
/usr/bin/python3 - "$PIPE" "$MUTP" 2>"$MUT_ERR" <<'PY'
import sys
src, dst = sys.argv[1], sys.argv[2]
s = open(src, encoding="utf-8").read()
# 🟥 2026-09-10: 검증자 후보 풀이 families.txt → roster(함대 명부) 로 바뀌면서 이 핀이 빗나갔다.
#   그때 레인은 «L20 이 실물을 안 잰다» 라는 **틀린 진단**을 냈다 — 핀이 빗나간 것과 대상이
#   빨간 것은 다른 사건인데 출력이 같았다. 그래서 이제 핀 실패는 HARNESS-ERROR 로 «따로» 운다.
key = '  while IFS= read -r f; do [ -n "$f" ] && [ "$f" != "$p" ] && supported "$f" && { echo "$f"; return; }; done < "$ROSTER"'
if key not in s:
    sys.stderr.write("HARNESS-ERROR: pick_verifier body moved — the revert probe is pinned to a line that no longer exists\n")
    sys.exit(9)
s = s.replace(key, '  echo "$p"')   # 자기 계열을 검증기로 고른다
open(dst, "w", encoding="utf-8").write(s)
PY
FH_CODEX_BIN="$D/fake_conf.sh" FH_AGY_BIN="$D/fake_conf.sh" \
  bash "$MUTP" "$D/tgt.py" --out "$D/pipe23" --fleet "$D/fleet.tbl" >"$D/p23" 2>&1
M23=$(grep '^PIPELINE ' "$D/p23" | grep -c 'unverified=2')
[ "$M23" = 1 ] \
  && ok "L23 되돌림: 검증기를 자기 계열로 바꾸면 전부 unverified 로 떨어진다 (L20 은 장식이 아니다)" \
  || no "L23 되돌림" "$(if /usr/bin/grep -q HARNESS-ERROR "$MUT_ERR" 2>/dev/null; then \
        /usr/bin/grep -m1 HARNESS-ERROR "$MUT_ERR"; echo " (계기 실패 — 대상은 무판정이다)"; \
      else echo "뮤턴트인데 unverified=2 가 안 나왔다 — L20 이 실물을 안 잰다"; fi) · $(grep '^PIPELINE ' "$D/p23")"

# L24 — G6: fleet 프롬프트가 defeater 를 «요구» 하는가 (축③ 을 잴 수 있는 최소 조건)
{ grep -q '"defeater"' "$FLEET" && grep -q 'defeater. is required' "$FLEET"; } \
  && ok "L24 fleet 스키마에 defeater 요구 (축③ 측정 가능)" || no "L24 defeater 스키마"
fi

# ══ cross-family 라운드 1 이 연 구멍들의 회귀 앵커 (codex, 2026-09-09) ══════════════════════════
# 🟥 각 레인은 «수리가 됐나」가 아니라 «그 구멍이 다시 열리면 빨개지나」를 잰다.
run_bounded() { # $1=초 · 나머지=명령. 되돌림이 무한루프를 되살려도 스위트가 안 멈추게.
  local secs="$1"; shift
  "$@" & local pid=$!
  ( sleep "$secs"; kill -9 "$pid" 2>/dev/null ) & local wd=$!
  wait "$pid" 2>/dev/null; local rc=$?
  kill -9 "$wd" 2>/dev/null; wait "$wd" 2>/dev/null
  return "$rc"
}

# 계열마다 다르게 답하는 가짜 CLI — codex 산출은 기각, gemini 산출은 인정, 감사는 correct-drop
cat > "$D/fake_smart.sh" <<'EOS'
#!/bin/sh
IN=$(cat)
[ -n "$IN" ] || IN="$*"
case "$IN" in *"correct-drop"*) MODE=audit ;; *) MODE=verify ;; esac
printf '%s\n' "$IN" | tr ',' '\n' | sed -n 's/.*"id": *"\([^"]*\)".*/\1/p' | sort -u | while read -r id; do
  if [ "$MODE" = audit ]; then
    echo "{\"id\":\"$id\",\"verdict\":\"correct-drop\",\"why\":\"line 1 checked\"}"
  else
    case "$id" in
      codex-*)  echo "{\"id\":\"$id\",\"verdict\":\"false-positive\",\"why\":\"line 1 says otherwise\"}" ;;
      *)        echo "{\"id\":\"$id\",\"verdict\":\"confirmed\",\"why\":\"line 1 holds\"}" ;;
    esac
  fi
done
EOS
chmod +x "$D/fake_smart.sh"

# L25 🟥 부분 감사는 감사가 아니다 — 무관한 id 하나만 답한 감사자가 «AUDITED · rc=0» 을 만들었다
cat > "$D/a_partial.sh" <<'EOS'
#!/bin/sh
cat >/dev/null
echo '{"id":"nonexistent-id","verdict":"correct-drop","why":"unrelated"}'
EOS
chmod +x "$D/a_partial.sh"
python3 "$VERIFY" "$D/f.jsonl" --out "$D/oP" --verifier "sh $D/v_ok.sh" --family beta \
  --audit-verifier "sh $D/a_partial.sh" --audit-family gamma >"$D/sP" 2>&1; RC=$?
{ [ "$RC" -eq 4 ] && grep -q 'drop_audit=PARTIAL' "$D/sP" && grep -q 'audited=0' "$D/sP"; } \
  && ok "L25 부분 감사 → PARTIAL · rc=4 (무관한 id 하나로 «감사했다» 가 안 된다)" \
  || no "L25 부분 감사" "rc=$RC · $(cat "$D/sP")"

# L26 🟥 주입 — 타깃 경로에 공백과 셸 메타문자가 있어도 «명령으로 실행되지 않는다»
TGD="$D/inj"; mkdir -p "$TGD"
# 🟥 파일명에 «/» 를 못 넣으므로 주입 페이로드는 상대 경로로 두고, 러너를 그 디렉터리에서 돌린다.
# (첫 판은 절대경로를 파일명에 박아 픽스처가 생성조차 안 됐다 — 죽은 계기였다.)
BADNAME='a b;touch PWNED.py'
( cd "$TGD" && printf 'x = 1\n' > "$BADNAME" ) 2>/dev/null
if [ -f "$TGD/$BADNAME" ]; then
  printf 'codex|logic|%s\ngemini|security|%s\n' "sh $D/m_codex.sh" "sh $D/m_gem.sh" > "$D/fleetI.tbl"
  ( cd "$TGD" && FH_CODEX_BIN="$D/fake_smart.sh" FH_AGY_BIN="$D/fake_smart.sh" \
      bash "$PIPE" "$BADNAME" --out "$D/pipeI" --fleet "$D/fleetI.tbl" ) >"$D/pI" 2>&1
  RCI=$?
  # 두 가지를 «같이» 본다: ⓐ 주입이 실행되지 않았나 ⓑ 공백 있는 경로로도 실제로 완주하나
  #    (ⓑ 없이 ⓐ 만 보면 «아예 안 돌아서 안전한» 것과 구별이 안 된다 — 죽은 컨트롤)
  { [ ! -e "$TGD/PWNED.py" ] && [ "$RCI" -eq 0 ] && grep -q 'confirmed=' "$D/pI"; } \
    && ok "L26 주입: 메타문자·공백 타깃이 «인자」로만 전달되고, 그러고도 완주한다" \
    || no "L26 주입" "PWNED=$([ -e "$TGD/PWNED.py" ] && echo 생성됨 || echo 없음) rc=$RCI · $(grep '^PIPELINE' "$D/pI" || tail -2 "$D/pI")"
else
  no "L26 주입" "픽스처 생성 실패 — 미측정(통과 아님)"
fi

# L27 🟥 값 없는 플래그는 «멈춤」이 아니라 rc=2 (첫 판은 무한루프였다)
run_bounded 8 bash "$VERIFIER" --family; RC=$?
[ "$RC" -eq 2 ] && ok "L27a verifier: 값 없는 --family → rc=2 (무한루프 아님)" || no "L27a 트레일링 플래그" "rc=$RC (137 이면 워치독이 죽인 것 = 여전히 멈춘다)"
run_bounded 8 bash "$PIPE" "$D/tgt.py" --out; RC=$?
[ "$RC" -eq 2 ] && ok "L27b pipeline: 값 없는 --out → rc=2" || no "L27b 트레일링 플래그" "rc=$RC"

# L28 🟥 종료코드는 «심각도 숫자」가 아니라 «종류» — 생존자가 있는데 rc=1 이 나오면 안 된다
printf 'codex|logic|%s\ngemini|security|%s\n' "sh $D/m_codex.sh" "sh $D/m_gem.sh" > "$D/fleetT.tbl"
FH_CODEX_BIN="$D/fake_smart.sh" FH_AGY_BIN="$D/fake_smart.sh" \
  bash "$PIPE" "$D/tgt.py" --out "$D/pipeT" --fleet "$D/fleetT.tbl" >"$D/pT" 2>&1; RC=$?
SUMT=$(grep '^PIPELINE ' "$D/pT")
{ [ "$RC" -eq 0 ] && printf '%s' "$SUMT" | grep -q 'confirmed=1' && printf '%s' "$SUMT" | grep -q 'dropped=1'; } \
  && ok "L28 한 split 이 «생존 0»(rc=1) 이어도 다른 split 의 생존자가 있으면 전체 rc=0" \
  || no "L28 종료코드 종류" "rc=$RC · $SUMT · $(tail -3 "$D/pT")"

# L29 🟥 --out 재사용이 «지난 런의 계열」을 수입하면 안 된다 (단일 계열이 교차검증된 것처럼 보인다)
printf 'codex|logic|%s\n' "sh $D/m_codex.sh" > "$D/fleetS.tbl"
FH_CODEX_BIN="$D/fake_smart.sh" bash "$PIPE" "$D/tgt.py" --out "$D/pipeT" --fleet "$D/fleetS.tbl" >"$D/pS" 2>&1; RC=$?
{ [ "$RC" -eq 3 ] && ! grep -q 'gemini' "$D/pipeT/families.txt"; } \
  && ok "L29 --out 재사용: 지난 런의 part_*.jsonl 을 수입하지 않는다 (단일 계열 → rc=3)" \
  || no "L29 stale --out" "rc=$RC families=$(cat "$D/pipeT/families.txt" 2>/dev/null | tr '\n' ',')"

# L30 — 읽을 수 없는 타깃은 «타입은 파일」이어도 rc=2 (모델이 소스 없이 판정하지 않게)
UNR="$D/unreadable.py"; printf 'x=1\n' > "$UNR"; chmod 000 "$UNR" 2>/dev/null
if [ -r "$UNR" ]; then
  no "L30 읽기불가 타깃" "chmod 000 이 안 먹었다(root?) — 미측정, 통과 아님"
else
  echo '{"id":"a1","title":"t"}' | bash "$VERIFIER" --family codex --target "$UNR" >/dev/null 2>&1; RC=$?
  [ "$RC" -eq 2 ] && ok "L30 읽기불가 타깃 → rc=2 (-f 는 타입만 본다)" || no "L30 읽기불가 타깃" "rc=$RC"
  chmod 644 "$UNR" 2>/dev/null
fi

# ══ 보안 회귀 앵커 (cross-family security review 2026-09-09) ═══════════════════════════════════
# 🟥 각 레인은 «지금 안전한가»가 아니라 «그 구멍을 되돌리면 빨개지나»를 잰다.
#    되돌림 방법은 각 주석에 적어 뒀다.

# L31 (S1) — 출력 디렉터리 «이름»에 든 $(...) 가 실행되면 안 된다 (fleet 의 eval 경로)
#    되돌림: finding_fleet.sh 의 q_pf/q_codex/q_agy 결박을 빼고 raw 치환으로 되돌리면 빨개진다
SENT="$D/S1_EXECUTED"
EVILOUT="$D/out\$(touch $SENT)"
printf 'x = 1\n' > "$D/s1.py"
printf 'codex|logic|%s\n' "sh $D/m_codex.sh" > "$D/fleetS1.tbl"
FH_CODEX_BIN=/bin/true bash "$HERE/finding_fleet.sh" "$D/s1.py" --out "$EVILOUT" --fleet "$D/fleetS1.tbl" >/dev/null 2>&1
[ ! -e "$SENT" ] \
  && ok "L31 (S1) 출력 경로의 \$(...) 가 실행되지 않는다 (eval 치환 결박)" \
  || no "L31 (S1) eval 주입" "출력 디렉터리 이름의 명령이 실행됐다"

# L32 (S2) — 검증기는 «셸 문자열»이 아니라 argv 로 넘어간다
#    되돌림: finding_pipeline.sh 를 --verifier 문자열 형태로 되돌리면 빨개진다.
#    🟥 왜 문자열이 위험한지: shell=True 는 /bin/sh 이고, bash %q 의 $'...' 는 dash 에서 안 통한다.
#       macOS 는 /bin/sh 가 bash 계열이라 «실행해도» 이 축이 안 보인다 — 그래서 형태를 단언한다.
{ /usr/bin/grep -q -- '--verifier-argv' "$PIPE" && /usr/bin/grep -q -- '--audit-verifier-argv' "$PIPE" \
  && ! /usr/bin/grep -qE '^\s*--verifier "bash ' "$PIPE"; } \
  && ok "L32 (S2) 파이프라인이 argv 형태로 넘긴다 (셸이 경로를 파싱하지 않는다)" \
  || no "L32 (S2) argv 형태" "문자열 --verifier 로 되돌아갔다 — dash 에서 인용이 깨진다"

# L32b (S2) — finding_verify.py 가 리스트를 받으면 shell 없이 실행한다
/usr/bin/grep -q 'shell = isinstance(cmd, str)' "$VERIFY" \
  && ok "L32b (S2) verify 는 리스트=argv · 문자열=셸 로 갈라 실행한다" \
  || no "L32b (S2) shell 분기" "shell=True 고정으로 되돌아갔다"

# L33 (S5) — 타깃이 심링크면 «내용이 외부로 나가므로» 거부해야 한다
printf 'SECRET=abc\n' > "$D/outside_secret.txt"
ln -sf "$D/outside_secret.txt" "$D/link_target.py"
bash "$VERIFIER" --family codex --target "$D/link_target.py" < /dev/null >/dev/null 2>&1; RC=$?
[ "$RC" -eq 2 ] && ok "L33 (S5) verifier: 심링크 타깃 거부 → rc=2 (외부 비밀 업로드 차단)" || no "L33 (S5) 심링크 타깃" "rc=$RC"
bash "$HERE/finding_fleet.sh" "$D/link_target.py" --out "$D/o33" >/dev/null 2>&1; RC=$?
[ "$RC" -eq 2 ] && ok "L33b (S5) fleet: 심링크 타깃 거부 → rc=2" || no "L33b (S5) fleet 심링크" "rc=$RC"

# L34 (S4) — 출력물이 심링크면 «남의 파일 truncate» 이므로 쓰기 전에 거부
printf 'DO NOT TRUNCATE\n' > "$D/victim.conf"
mkdir -p "$D/o34"; ln -sf "$D/victim.conf" "$D/o34/confirmed.jsonl"
printf 'x = 1\n' > "$D/s4.py"
bash "$PIPE" "$D/s4.py" --out "$D/o34" --fleet "$D/fleet.tbl" >/dev/null 2>&1; RC=$?
{ [ "$RC" -eq 2 ] && /usr/bin/grep -q "DO NOT TRUNCATE" "$D/victim.conf"; } \
  && ok "L34 (S4) 출력 심링크 거부 → rc=2 · 바깥 파일 온전" \
  || no "L34 (S4) 출력 심링크" "rc=$RC victim=$(head -c 20 "$D/victim.conf")"

# L35 (A7) — 프롬프트 파일은 소스 전문을 담는다. 다른 계정이 읽으면 안 된다
printf 'x = 1\n' > "$D/s7.py"
FH_CODEX_BIN=/bin/true bash "$HERE/finding_fleet.sh" "$D/s7.py" --out "$D/o35" --fleet "$D/fleetS1.tbl" >/dev/null 2>&1
PF=$(ls "$D/o35"/prompt_*.txt 2>/dev/null | head -1)
if [ -n "$PF" ]; then
  MODE=$(/usr/bin/stat -f "%OLp" "$PF" 2>/dev/null || /usr/bin/stat -c "%a" "$PF" 2>/dev/null)
  case "$MODE" in *[04]|*[04][04]) OTHERS_R=1;; *) OTHERS_R=0;; esac
  # 마지막 자리(others)가 4 이상이면 읽힌다
  LAST=${MODE#${MODE%?}}
  [ "$LAST" -lt 4 ] && ok "L35 (A7) 프롬프트 파일이 others 에게 안 읽힌다 (mode=$MODE)" \
                    || no "L35 (A7) 프롬프트 권한" "mode=$MODE — 소스 전문이 더 넓게 읽힌다"
else
  no "L35 (A7) 프롬프트 권한" "프롬프트 파일이 안 생겼다 — 미측정(통과 아님)"
fi

# ── L36~L38 «생산자 미상» 은 깨끗함이 아니다 (2026-09-09) ───────────────────────
# 🟥 이 파일이 스스로 «강제하는 유일한 속성» 이라 선언한 자기검증 금지가 OPTIONAL 필드에
#    걸려 있었다: producer_family 를 빼면 검사가 통째로 건너뛰고 같은 계열이 자기 발견을
#    승인하며 status=VERIFIED rc=0 이 나왔다. 세 팔로 박는다 — 세 번째(다른 계열 → 정상
#    통과)가 없으면 «그냥 다 막아버린 픽스» 와 구분되지 않는다.
cat > "$D/v_yes.sh" <<'EOS'
#!/bin/sh
cat >/dev/null
echo '{"id":"z1","verdict":"confirmed","why":"stub"}'
EOS
chmod +x "$D/v_yes.sh"
_pf_run() { # $1 = jsonl 한 줄, $2 = 이름 → "rc|status"
  printf '%s\n' "$1" > "$D/pf_$2.jsonl"
  local o rc
  o=$(python3 "$HERE/finding_verify.py" "$D/pf_$2.jsonl" --out "$D/pf_o_$2" \
        --verifier "sh $D/v_yes.sh" --family beta 2>&1); rc=$?
  printf '%s|%s' "$rc" "$(printf '%s' "$o" | sed -n 's/.*status=\([A-Z-]*\).*/\1/p' | head -1)"
}
R36=$(_pf_run '{"id":"z1","title":"t"}' absent)
[ "$R36" = "3|UNVERIFIED" ] \
  && ok "L36 producer_family 부재 → unverified·rc=3 (부재는 «검증됨» 이 아니다)" \
  || no "L36 부재 fail-closed" "got=$R36 want=3|UNVERIFIED"
R37=$(_pf_run '{"id":"z1","title":"t","producer_family":"beta"}' same)
[ "$R37" = "3|UNVERIFIED" ] \
  && ok "L37 producer_family == 검증자 계열 → unverified·rc=3 (자기 저작 승인 금지)" \
  || no "L37 동일 계열 차단" "got=$R37 want=3|UNVERIFIED"
R38=$(_pf_run '{"id":"z1","title":"t","producer_family":"gamma"}' diff)
[ "$R38" = "0|VERIFIED" ] \
  && ok "L38 producer_family != 검증자 계열 → 정상 통과 (과차단 아님)" \
  || no "L38 과차단 없음" "got=$R38 want=0|VERIFIED"

# ── L39~L45 커버리지 기록 + 씨앗 통제 (2026-09-09, 거버넌스 루프 R1) ─────────────
# 🟥 오류율은 «혼자 인용될 수 없는 수» 로 만든다. 판정된 것만 분모에 넣고 기권을 빼면 그 비율은
#    말하지 않은 동작점에서의 값이고, 기권율이 다른 두 팔을 나란히 놓는 순간 비교가 성립하지
#    않는다. 이건 선택적 예측 문헌이 이미 «흔한 결함» 으로 명명한 형태이고(arXiv:2407.01032),
#    우리 5팔 표가 그 실례다. 그래서 coverage 는 DROPS 줄과 같이 «무조건» 나간다.
# 🟥 그리고 씨앗 통제는 known-pair 규율을 «필터» 에 적용한 것이다 — 이 레포는 그 규율을
#    스캐너에만 적용해 왔고 삭제 단계에는 한 번도 적용한 적이 없다. 필터도 계기다.
cat > "$D/sv_keep.sh" <<'EOS'
#!/bin/sh
cat >/dev/null
echo '{"id":"z1","verdict":"confirmed","why":"ok"}'
echo '{"id":"z2","verdict":"confirmed","why":"ok"}'
EOS
cat > "$D/sv_drop.sh" <<'EOS'
#!/bin/sh
cat >/dev/null
echo '{"id":"z1","verdict":"confirmed","why":"ok"}'
echo '{"id":"z2","verdict":"false-positive","why":"nope"}'
EOS
chmod +x "$D/sv_keep.sh" "$D/sv_drop.sh"
printf '%s\n%s\n' '{"id":"z1","title":"a","producer_family":"gamma"}' \
                  '{"id":"z2","title":"b","producer_family":"gamma"}' > "$D/sf.jsonl"
# 하나가 자기 계열이라 unverified 가 되는 입력 — coverage 가 1.0 아래로 내려가야 한다
printf '%s\n%s\n' '{"id":"z1","title":"a","producer_family":"beta"}' \
                  '{"id":"z2","title":"b","producer_family":"gamma"}' > "$D/sf_partial.jsonl"
_sv() { # $1 out이름, $2 verifier, $3 입력, 나머지 = 추가 인자 → "rc|FINDINGS|SEEDED"
  local n="$1" v="$2" f="$3"; shift 3
  local o rc; o=$(python3 "$HERE/finding_verify.py" "$D/$f" --out "$D/sv_$n" \
        --verifier "sh $D/$v" --family beta "$@" 2>&1); rc=$?
  printf '%s|%s|%s' "$rc" "$(printf '%s' "$o" | /usr/bin/grep -o 'coverage=[0-9]*/[0-9]*')" \
                    "$(printf '%s' "$o" | sed -n 's/^SEEDED .*status=\([A-Z_]*\).*/\1/p')"
}
R39=$(_sv full sv_keep.sh sf.jsonl)
[ "$R39" = "0|coverage=2/2|NOT_PROVIDED" ] \
  && ok "L39 전부 판정되면 coverage=2/2 · 씨앗 미제공은 NOT_PROVIDED (후방호환: rc 불변)" \
  || no "L39 coverage 만점 + 후방호환" "got=$R39 want=0|coverage=2/2|NOT_PROVIDED"
R40=$(_sv part sv_keep.sh sf_partial.jsonl)
[ "$R40" = "3|coverage=1/2|NOT_PROVIDED" ] \
  && ok "L40 🟥 미판정이 있으면 coverage 가 1.0 아래로 내려간다 (기권이 분모 밖으로 숨지 않는다)" \
  || no "L40 coverage 가 기권을 드러낸다" "got=$R40 want=3|coverage=1/2|NOT_PROVIDED"
R41=$(_sv seed_ok sv_keep.sh sf.jsonl --seeded z2)
[ "$R41" = "0|coverage=2/2|CLEAN" ] \
  && ok "L41 씨앗 생존 → CLEAN · rc 불변" || no "L41 씨앗 생존" "got=$R41 want=0|coverage=2/2|CLEAN"
R42=$(_sv seed_bad sv_drop.sh sf.jsonl --seeded z2)
[ "$R42" = "5|coverage=2/2|DEGRADED" ] \
  && ok "L42 🟥 씨앗이 지워지면 DEGRADED·rc=5 — 삭제로 정밀도를 산 «직접 증거»" \
  || no "L42 씨앗 삭제 검출" "got=$R42 want=5|coverage=2/2|DEGRADED"
R43=$(_sv seed_none sv_keep.sh sf.jsonl --seeded zzz)
[ "$R43" = "5|coverage=2/2|ABSENT" ] \
  && ok "L43 🟥 씨앗이 입력에 없으면 ABSENT·rc=5 — 안 돈 컨트롤은 통과한 컨트롤이 아니다" \
  || no "L43 죽은 컨트롤 검출" "got=$R43 want=5|coverage=2/2|ABSENT"
# L44 되돌림 — coverage 필드를 지우면 L39·L40 이 빨개져야 한다(앵커가 장식이 아님)
MUT2="$D/verify_mut2.py"
MUTERR2=$(python3 - "$VERIFY" "$MUT2" 2>&1 <<'PYX'
import sys
src, dst = sys.argv[1], sys.argv[2]
s = open(src, encoding="utf-8").read()
key = 'coverage={}/{} ({}%) '
assert key in s, "ANCHOR-MOVED: coverage field format string not found"
open(dst, "w", encoding="utf-8").write(s.replace(key, ''))
PYX
); MUTRC2=$?
if [ "$MUTRC2" -ne 0 ] || [ ! -s "$MUT2" ]; then
  no "L44 되돌림 (뮤턴트 생성 실패)" "$(printf '%s' "$MUTERR2" | tail -1) — 앵커가 «움직인» 것이지 «장식» 이 아니다"
else
  MO=$(python3 "$MUT2" "$D/sf.jsonl" --out "$D/sv_mut" --verifier "sh $D/sv_keep.sh" --family beta 2>&1); MRC=$?
  # 🟥 «coverage= 가 없다» 만 보면 **크래시한 뮤턴트도 통과**한다 — 없는 이유가 «지웠기 때문» 인지
  #    «안 돌았기 때문» 인지 안 갈린다(cross-family 지적 2026-09-09, 항목 5). 그래서 뮤턴트가
  #    «정상 종료 + FINDINGS 줄을 냈다» 를 먼저 요구하고, 그 다음에 coverage 부재를 본다.
  if [ "$MRC" -ne 0 ] || ! printf '%s' "$MO" | /usr/bin/grep -q '^FINDINGS '; then
    no "L44 되돌림" "뮤턴트가 정상 실행되지 않았다(rc=$MRC) — coverage 부재를 «지웠기 때문» 으로 읽을 수 없다"
  elif printf '%s' "$MO" | /usr/bin/grep -q 'coverage='; then
    no "L44 되돌림" "coverage 를 지웠는데도 출력에 남아 있다 — 앵커가 다른 곳을 잰다"
  else
    ok "L44 되돌림: 뮤턴트는 정상 실행되고 coverage 만 사라진다 (레인이 실물을 잰다)"
  fi
fi
# L45 씨앗 id 는 검증자 프롬프트에 «들어가지 않는다» — 새면 통제가 아니라 힌트가 된다
cat > "$D/sv_echo.sh" <<'EOS'
#!/bin/sh
cat > "$SEEN_FILE"
echo '{"id":"z1","verdict":"confirmed","why":"ok"}'
echo '{"id":"z2","verdict":"confirmed","why":"ok"}'
EOS
chmod +x "$D/sv_echo.sh"
# 🟥 초판은 리터럴 `seeded` 를 grep 했다 — 다른 변수명으로 새면 그대로 통과하고, 반대로 finding
#    본문에 그 낱말이 있으면 거짓 실패다(cross-family 지적 2026-09-09, 항목 5). 누출의 정의는
#    «씨앗 선택이 검증자 입력을 바꾸는가» 이므로, **선택을 바꿔 두 입력을 바이트 비교**한다.
SEEN_FILE="$D/seen_a.txt" python3 "$HERE/finding_verify.py" "$D/sf.jsonl" --out "$D/sv_leak_a" \
  --verifier "sh $D/sv_echo.sh" --family beta --seeded z1 >/dev/null 2>&1
SEEN_FILE="$D/seen_b.txt" python3 "$HERE/finding_verify.py" "$D/sf.jsonl" --out "$D/sv_leak_b" \
  --verifier "sh $D/sv_echo.sh" --family beta --seeded z2 >/dev/null 2>&1
SEEN_FILE="$D/seen_n.txt" python3 "$HERE/finding_verify.py" "$D/sf.jsonl" --out "$D/sv_leak_n" \
  --verifier "sh $D/sv_echo.sh" --family beta >/dev/null 2>&1
if [ ! -s "$D/seen_a.txt" ] || [ ! -s "$D/seen_b.txt" ] || [ ! -s "$D/seen_n.txt" ]; then
  no "L45 씨앗 누출" "검증자 입력을 못 캡처했다 — 미측정(통과 아님)"
elif cmp -s "$D/seen_a.txt" "$D/seen_b.txt" && cmp -s "$D/seen_a.txt" "$D/seen_n.txt"; then
  ok "L45 씨앗 «선택» 을 바꿔도 검증자 입력이 바이트 동일 (통제이지 힌트가 아니다)"
else
  no "L45 씨앗 누출" "씨앗 선택에 따라 검증자 입력이 달라진다 — 멤버십이 샌다"
fi

# L46 — coverage 가 «드라이버» 요약 줄에도 실린다. verify 에만 있으면 읽는 사람에게는 없는 것이다.
FH_CODEX_BIN="$D/fake_smart.sh" FH_AGY_BIN="$D/fake_smart.sh" \
  bash "$PIPE" "$D/tgt.py" --out "$D/pipeCOV" --fleet "$D/fleetT.tbl" >"$D/pCOV" 2>&1
SUMC=$(grep -m1 '^PIPELINE ' "$D/pCOV")
if printf '%s' "$SUMC" | grep -qE 'coverage=[0-9]+/[0-9]+ \([0-9]+%\)'; then
  ok "L46 PIPELINE 요약 줄이 coverage 를 나른다 (verify 에만 있으면 소비처 0 이다)"
else
  no "L46 드라이버 coverage" "PIPELINE 줄에 coverage 없음 → $SUMC"
fi

# ── L47~L50 cross-family 라운드가 잡은 넷 (2026-09-09) — 수리마다 앵커 하나 ────────
cat > "$D/sv_drop_all.sh" <<'EOS'
#!/bin/sh
cat >/dev/null
echo '{"id":"z1","verdict":"false-positive","why":"no"}'
echo '{"id":"z2","verdict":"false-positive","why":"no"}'
EOS
cat > "$D/sa_reinstate.sh" <<'EOS'
#!/bin/sh
cat >/dev/null
echo '{"id":"z1","verdict":"correct-drop","why":"fine"}'
echo '{"id":"z2","verdict":"wrong-drop","why":"actually real"}'
EOS
cat > "$D/sv_debate.sh" <<'EOS'
#!/bin/sh
cat >/dev/null
echo '{"id":"z1","verdict":"needs-debate","why":"hm"}'
echo '{"id":"z2","verdict":"needs-debate","why":"hm"}'
EOS
chmod +x "$D/sv_drop_all.sh" "$D/sa_reinstate.sh" "$D/sv_debate.sh"

# L47 🟥 A급 — 감사자가 씨앗을 복권시켜도 «필터는 지웠다». 복권은 산출을 고치지 통제를 통과시키지 않는다
O47=$(python3 "$HERE/finding_verify.py" "$D/sf.jsonl" --out "$D/l47" --verifier "sh $D/sv_drop_all.sh" \
      --family beta --audit-verifier "sh $D/sa_reinstate.sh" --audit-family delta --seeded z2 2>&1); R47=$?
# 🟥 rc=5/DEGRADED 만 보면 «감사 자체가 안 돈» 경우도 통과한다 — 그러면 이 레인은 A1 회귀를
#    못 잡는다(cross-family R2 지적). 그러므로 «복권이 실제로 일어났다» 를 먼저 세운다.
_L47_REINSTATED=0
printf '%s' "$O47" | /usr/bin/grep -q 'reinstated=1'   && /usr/bin/grep -q '"id": *"z2"' "$D/l47/confirmed.jsonl" 2>/dev/null   && /usr/bin/grep -q '"reinstated": *true' "$D/l47/confirmed.jsonl" 2>/dev/null   && ! /usr/bin/grep -q '"id": *"z2"' "$D/l47/dropped.jsonl" 2>/dev/null   && _L47_REINSTATED=1
if [ "$_L47_REINSTATED" -ne 1 ]; then
  no "L47 전제 미성립" "복권이 실제로 안 일어났다 — 이 레인은 A1 회귀를 못 잡는다. $(printf '%s' "$O47" | /usr/bin/grep '^DROPS')"
elif [ "$R47" -eq 5 ] && printf '%s' "$O47" | /usr/bin/grep -q 'SEEDED .*status=DEGRADED'; then
  ok "L47 🟥 감사자가 씨앗을 «실제로 복권시켰는데도» DEGRADED·rc=5 (통제는 산출이 아니라 필터를 잰다)"
else
  no "L47 감사 복권이 통제를 지우지 못한다" "rc=$R47 · $(printf '%s' "$O47" | /usr/bin/grep '^SEEDED')"
fi
# L48 needs-debate 는 «판정» 이 아니다 — 전부 debate 면 coverage 는 0 이어야 한다
O48=$(python3 "$HERE/finding_verify.py" "$D/sf.jsonl" --out "$D/l48" --verifier "sh $D/sv_debate.sh" \
      --family beta 2>&1); R48=$?
# 🟥 coverage 문자열만 보면 «0% 인데 rc=0» 이 통과한다 — 실제로 그랬다(cross-family R4). 판정
#    0건인 런은 «완주» 가 아니므로 종료코드까지 같이 단언한다.
if [ "$R48" -eq 3 ] && printf '%s' "$O48" | /usr/bin/grep -q 'coverage=0/2 (0%)'; then
  ok "L48 전부 needs-debate → coverage=0/2 **그리고 rc=3** (판정 0건은 완주가 아니다)"
else
  no "L48 debate 는 커버 아님" "rc=$R48 want=3 · $(printf '%s' "$O48" | /usr/bin/grep '^FINDINGS')"
fi
# L49 빈 씨앗 파일 = «비활성화된 통제» 지 «없는 통제» 가 아니다 → 설정 오류로 rc=2
: > "$D/seed_empty.txt"
python3 "$HERE/finding_verify.py" "$D/sf.jsonl" --out "$D/l49" --verifier "sh $D/sv_keep.sh" \
  --family beta --seeded-file "$D/seed_empty.txt" >/dev/null 2>&1; R49=$?
[ "$R49" -eq 2 ] && ok "L49 빈 --seeded-file → rc=2 (조용히 통제가 꺼지지 않는다)" \
                 || no "L49 빈 통제 파일" "rc=$R49 want=2"
# L50 불량 UTF-8 은 «완주» 코드로 새면 안 된다 (초판은 UnicodeDecodeError 가 exit 1 로 샜다)
printf '\377\376\n' > "$D/seed_bad.bin"
python3 "$HERE/finding_verify.py" "$D/sf.jsonl" --out "$D/l50" --verifier "sh $D/sv_keep.sh" \
  --family beta --seeded-file "$D/seed_bad.bin" >/dev/null 2>&1; R50=$?
[ "$R50" -eq 2 ] && ok "L50 불량 UTF-8 씨앗 파일 → rc=2 (rc=1 «완주» 로 새지 않는다)" \
                 || no "L50 통제 파일 디코드 오류" "rc=$R50 want=2"

# ── L49b~L53 cross-family R2 가 지적한 레인 약점 + 새 앵커 (2026-09-09) ───────────
# 🟥 L49/L50 은 rc=2 만 봤다 — 옵션 이름을 지워도 argparse 가 2 를 내므로 «무관한 실패» 로도
#    통과했고, 파싱을 다시 뒤로 옮겨도 통과했다. 셋을 더한다: 유효 파일 성공 컨트롤 · 의도한
#    진단 문구 · **검증자가 아예 호출되지 않았음**(출력물 부재로 판정).
cat > "$D/sv_touch.sh" <<'EOS'
#!/bin/sh
cat >/dev/null
: > "$TOUCHED"
echo '{"id":"z1","verdict":"confirmed","why":"ok"}'
echo '{"id":"z2","verdict":"confirmed","why":"ok"}'
EOS
chmod +x "$D/sv_touch.sh"
printf 'z2\n' > "$D/seed_good.txt"
# (a) 유효 파일 컨트롤 — 성공해야 한다. 이게 없으면 «전부 막는 픽스» 와 구분 불가
TOUCHED="$D/t_ok" python3 "$HERE/finding_verify.py" "$D/sf.jsonl" --out "$D/l49a" \
  --verifier "sh $D/sv_touch.sh" --family beta --seeded-file "$D/seed_good.txt" >/dev/null 2>&1; R49A=$?
# (b) 빈 파일 — rc=2 · 진단 문구 · 검증자 미호출 · 출력 미생성
E49=$(TOUCHED="$D/t_empty" python3 "$HERE/finding_verify.py" "$D/sf.jsonl" --out "$D/l49b" \
  --verifier "sh $D/sv_touch.sh" --family beta --seeded-file "$D/seed_empty.txt" 2>&1); R49B=$?
if [ "$R49A" -ne 0 ]; then
  no "L49b 유효 통제 파일 컨트롤" "정상 씨앗 파일인데 rc=$R49A — 픽스가 과차단이다"
elif [ "$R49B" -ne 2 ]; then
  no "L49b 빈 통제 파일" "rc=$R49B want=2"
elif ! printf '%s' "$E49" | /usr/bin/grep -q 'yielded no ids'; then
  no "L49b 진단 문구" "rc=2 는 맞지만 의도한 진단이 아니다 — 무관한 usage 실패와 구분 불가: $E49"
elif [ -e "$D/t_empty" ] || [ -e "$D/l49b/confirmed.jsonl" ]; then
  no "L49b 조기 거부" "검증자가 호출됐거나 출력이 생겼다 — 검증 «전» 에 안 막았다"
else
  ok "L49b 빈 통제 파일: rc=2 · 의도한 진단 · 검증자 미호출 · 출력 미생성 (유효 파일 컨트롤 통과)"
fi
# (c) 불량 UTF-8 — 같은 세 조건
E50=$(TOUCHED="$D/t_bad" python3 "$HERE/finding_verify.py" "$D/sf.jsonl" --out "$D/l50b" \
  --verifier "sh $D/sv_touch.sh" --family beta --seeded-file "$D/seed_bad.bin" 2>&1); R50B=$?
if [ "$R50B" -eq 2 ] && printf '%s' "$E50" | /usr/bin/grep -q 'unusable' \
   && [ ! -e "$D/t_bad" ] && [ ! -e "$D/l50b/confirmed.jsonl" ]; then
  ok "L50b 불량 UTF-8: rc=2 · 의도한 진단 · 검증자 미호출 (rc=1 «완주» 로 새지 않는다)"
else
  no "L50b 통제 파일 디코드 오류" "rc=$R50B · touched=$([ -e "$D/t_bad" ] && echo yes || echo no) · $E50"
fi
# L51 🟥 반올림 회귀 — 201건 중 1건만 미판정이면 100% 가 아니라 99% 여야 한다
: > "$D/big.jsonl"
i=1; while [ "$i" -le 201 ]; do
  if [ "$i" -eq 1 ]; then fam=beta; else fam=gamma; fi
  printf '{"id":"b%s","title":"t","producer_family":"%s"}\n' "$i" "$fam" >> "$D/big.jsonl"
  i=$((i+1))
done
cat > "$D/sv_all.sh" <<'EOS'
#!/bin/sh
python3 -c '
import sys, json
for l in sys.stdin:
    l = l.strip()
    if not l: continue
    try: d = json.loads(l)
    except Exception: continue
    print(json.dumps({"id": d.get("id"), "verdict": "confirmed", "why": "ok"}))'
EOS
chmod +x "$D/sv_all.sh"
O51=$(python3 "$HERE/finding_verify.py" "$D/big.jsonl" --out "$D/l51" --verifier "sh $D/sv_all.sh" --family beta 2>&1)
if printf '%s' "$O51" | /usr/bin/grep -q 'coverage=200/201 (99%)'; then
  ok "L51 🟥 200/201 은 99% 로 찍힌다 (반올림하면 미판정 1건이 100% 뒤에 숨는다)"
else
  no "L51 바닥 내림" "$(printf '%s' "$O51" | /usr/bin/grep '^FINDINGS')"
fi
# L52 드라이버도 debate 를 커버로 안 센다 (verify 만 고치고 드라이버를 안 고친 반쪽-픽스 회귀 앵커)
cat > "$D/m_deb.sh" <<'EOS'
#!/bin/sh
echo '{"id":"d1","title":"debatable thing","file":"tgt.py","line":1,"severity":"B"}'
EOS
chmod +x "$D/m_deb.sh"
# 🟥 초판 픽스처는 stdin 을 버리고 고정 id 하나를 뱉었다 — 실제 id 와 안 맞아 verify 가 «판정 없음
#    → unverified» 로 처리했고, 레인은 「전제 미성립」으로 정직하게 실패했다(통과 아님). 실제로
#    debate 를 만들려면 «받은 id 를 그대로» 되돌려줘야 한다. 형태는 fake_smart.sh 와 같이 간다.
cat > "$D/fake_debate.sh" <<'EOS'
#!/bin/sh
IN=$(cat)
[ -n "$IN" ] || IN="$*"
case "$IN" in *"correct-drop"*) MODE=audit ;; *) MODE=verify ;; esac
printf '%s\n' "$IN" | tr ',' '\n' | sed -n 's/.*"id": *"\([^"]*\)".*/\1/p' | sort -u | while read -r id; do
  if [ "$MODE" = audit ]; then
    echo "{\"id\":\"$id\",\"verdict\":\"correct-drop\",\"why\":\"checked\"}"
  else
    echo "{\"id\":\"$id\",\"verdict\":\"needs-debate\",\"why\":\"unclear from this file alone\"}"
  fi
done
EOS
chmod +x "$D/fake_debate.sh"
printf 'codex|logic|%s\ngemini|security|%s\n' "sh $D/m_deb.sh" "sh $D/m_deb.sh" > "$D/fleetD.tbl"
FH_CODEX_BIN="$D/fake_debate.sh" FH_AGY_BIN="$D/fake_debate.sh" \
  bash "$PIPE" "$D/tgt.py" --out "$D/pipeDEB" --fleet "$D/fleetD.tbl" >"$D/pDEB" 2>&1
SUMD=$(grep -m1 '^PIPELINE ' "$D/pDEB")
# 🟥 `coverage=0/` 만 보면 «분모도 0» 이거나 «numerator 를 상수 0 으로 바꾼» 구현도 통과한다
#    (cross-family R3 지적). 분모를 정확히 요구한다 — 이 픽스처는 계열 2개 × finding 1개 = 2건.
if printf '%s' "$SUMD" | grep -qE 'debate=[1-9]' && printf '%s' "$SUMD" | grep -q 'coverage=0/2 (0%)'; then
  ok "L52 드라이버도 needs-debate 를 커버로 안 센다 (verify 만 고친 반쪽-픽스 회귀 앵커)"
elif printf '%s' "$SUMD" | grep -qE 'debate=0'; then
  no "L52 전제 미성립" "이 픽스처가 debate 를 만들지 못했다 — 미측정(통과 아님): $SUMD"
else
  no "L52 드라이버 debate" "$SUMD"
fi

# ── L53~L55 cross-family R3: «출력에 안 나타난 것» 이 판정으로 세어지면 안 된다 ────────
# 🟥 초판 드라이버는 판정 수를 «입력 − 기권» 으로 구했다. 그러면 건너뛴 파티션·읽기 실패·깨진
#    JSON 처럼 **출력에 아예 안 나타난 것이 판정된 것으로** 계수되고 coverage 가 100% 로 찍힌다.
#    지금은 «해결된 verdict 를 실제로 들고 있는 행» 을 양으로 센다. 그 셋을 각각 박는다.
# L53 단일 계열이라 라우팅이 건너뛴다 → 판정 0. coverage 가 100% 면 안 된다
printf 'codex|logic|%s\n' "sh $D/m_codex.sh" > "$D/fleetS53.tbl"
FH_CODEX_BIN="$D/fake_smart.sh" bash "$PIPE" "$D/tgt.py" --out "$D/pipe53" --fleet "$D/fleetS53.tbl" >"$D/p53" 2>&1; R53=$?
SUM53=$(grep -m1 '^PIPELINE ' "$D/p53")
if [ -z "$SUM53" ]; then
  no "L53 전제 미성립" "PIPELINE 요약 줄이 없다 — 미측정(통과 아님)"
elif printf '%s' "$SUM53" | grep -qE 'coverage=[1-9][0-9]*/[0-9]+ \(100%\)'; then
  no "L53 건너뛴 파티션" "판정이 0인데 coverage 가 100% — 안 나타난 것을 «판정됨» 으로 셌다: $SUM53"
elif printf '%s' "$SUM53" | grep -q 'coverage=0/'; then
  ok "L53 🟥 라우팅이 건너뛴 파티션은 «판정» 으로 안 세어진다 (coverage 0, rc=$R53)"
else
  no "L53 건너뛴 파티션" "$SUM53"
fi
# L54 양의 컨트롤 — 정상 런은 분모까지 정확히 맞아야 한다. 없으면 «항상 0» 구현이 L53 을 통과한다
FH_CODEX_BIN="$D/fake_smart.sh" FH_AGY_BIN="$D/fake_smart.sh" \
  bash "$PIPE" "$D/tgt.py" --out "$D/pipe54" --fleet "$D/fleetT.tbl" >"$D/p54" 2>&1
SUM54=$(grep -m1 '^PIPELINE ' "$D/p54")
if printf '%s' "$SUM54" | grep -q 'coverage=2/2 (100%)'; then
  ok "L54 정상 런은 coverage=2/2 (100%) — «항상 0» 구현이 L53 을 통과하지 못하게 하는 양의 컨트롤"
else
  no "L54 양의 컨트롤" "정상 런인데 분모/분자가 안 맞는다: $SUM54"
fi
# L55 🟥 이 레인은 «장식» 이었다 — 인라인 파이썬 스니펫이 예외를 던지는지만 봤고, 출하되는
#     `_count_json` 도 `finding_pipeline.sh` 도 한 줄도 안 불렀다. 드라이버의 계측 가드를 통째로
#     지워도 통과했다(cross-family R4, gemini 지목). 이제 **출하 스크립트에서 함수를 뽑아** 돌린다.
_L55_FN=$(sed -n '/^_count_json() {/,/^}/p' "$PIPE")
if [ -z "$_L55_FN" ]; then
  no "L55 계측 실패 규율" "_count_json 을 $PIPE 에서 못 뽑았다 — 미측정(통과 아님)"
else
  printf 'NOT JSON AT ALL\n' > "$D/broken.jsonl"
  printf '{"id":"z1","verdict":"confirmed"}\n' > "$D/okrows.jsonl"
  _L55_OUT=$(eval "$_L55_FN"; _count_json "$D/broken.jsonl" verdict confirmed >/dev/null 2>&1; echo "broken=$?";
             _count_json "$D/okrows.jsonl" verdict confirmed >/dev/null 2>&1; echo "ok=$?";
             _count_json "$D/does_not_exist.jsonl" verdict confirmed 2>/dev/null; echo "missing_rc=$?")
  case "$_L55_OUT" in
    *"broken=9"*) : ;;
    *) no "L55 계측 실패 규율" "깨진 JSONL 인데 출하 함수가 비-영을 안 냈다 → $_L55_OUT"; _L55_BAD=1 ;;
  esac
  if [ "${_L55_BAD:-0}" -eq 0 ]; then
    case "$_L55_OUT" in
      *"ok=0"*) ok "L55 출하되는 _count_json: 깨진 산출물 → rc=9 · 정상 산출물 → rc=0 (양의 컨트롤 동반)" ;;
      *) no "L55 계측 실패 규율" "정상 JSONL 인데 비-영 — 과차단이다 → $_L55_OUT" ;;
    esac
  fi
fi

# ── L56~L59 cross-family R4 (gemini 계열) 가 잡은 것들 ──────────────────────────
# L56 🟥 «안 지워졌다» 는 «통과» 가 아니다 — 씨앗에 기권하면 INCONCLUSIVE·rc=5
# 🟥 픽스처는 «씨앗에만» 기권해야 한다. 전부 기권시키면 «판정 0건 → rc=3» 이 먼저 걸려서
#    rc=5 를 가리고, 그러면 이 레인은 자기가 주장하는 것을 안 재게 된다(첫 작성에서 실제로 그랬다).
cat > "$D/sv_debate_seed.sh" <<'EOS'
#!/bin/sh
cat >/dev/null
echo '{"id":"z1","verdict":"confirmed","why":"ok"}'
echo '{"id":"z2","verdict":"needs-debate","why":"unclear"}'
EOS
chmod +x "$D/sv_debate_seed.sh"
O56=$(python3 "$HERE/finding_verify.py" "$D/sf.jsonl" --out "$D/l56" --verifier "sh $D/sv_debate_seed.sh" \
      --family beta --seeded z2 2>&1); R56=$?
if [ "$R56" -eq 5 ] && printf '%s' "$O56" | /usr/bin/grep -q 'SEEDED .*status=INCONCLUSIVE'; then
  ok "L56 🟥 검증자가 씨앗에 기권하면 INCONCLUSIVE·rc=5 (삭제 말고 «안 정하기» 로도 못 산다)"
else
  no "L56 기권으로 통제 우회" "rc=$R56 · $(printf '%s' "$O56" | /usr/bin/grep '^SEEDED')"
fi
# L57 정수 id 씨앗 — 문자열 비교 강제 전에는 present=0 → ABSENT rc=5 라는 거짓 경보였다
printf '%s\n' '{"id":101,"title":"a","producer_family":"gamma"}' > "$D/intid.jsonl"
cat > "$D/sv_101.sh" <<'EOS'
#!/bin/sh
cat >/dev/null
echo '{"id":"101","verdict":"confirmed","why":"ok"}'
EOS
chmod +x "$D/sv_101.sh"
O57=$(python3 "$HERE/finding_verify.py" "$D/intid.jsonl" --out "$D/l57" --verifier "sh $D/sv_101.sh" \
      --family beta --seeded 101 2>&1); R57=$?
if [ "$R57" -eq 0 ] && printf '%s' "$O57" | /usr/bin/grep -q 'SEEDED .*status=CLEAN'; then
  ok "L57 정수 id 도 씨앗으로 잡힌다 (문자열 비교 — 거짓 ABSENT 경보 없음)"
else
  no "L57 정수 id 씨앗" "rc=$R57 · $(printf '%s' "$O57" | /usr/bin/grep '^SEEDED')"
fi
# L58 복권된 행은 판정으로 세어진다 — verify 쪽 verdict 가 confirmed 로 바뀌었나
O58=$(python3 "$HERE/finding_verify.py" "$D/sf.jsonl" --out "$D/l58" --verifier "sh $D/sv_drop_all.sh" \
      --family beta --audit-verifier "sh $D/sa_reinstate.sh" --audit-family delta 2>&1)
if /usr/bin/grep -q '"reinstated": *true' "$D/l58/confirmed.jsonl" 2>/dev/null \
   && /usr/bin/grep -q '"verdict": *"confirmed"' "$D/l58/confirmed.jsonl" 2>/dev/null \
   && /usr/bin/grep -q '"pre_audit_verdict": *"false-positive"' "$D/l58/confirmed.jsonl" 2>/dev/null; then
  ok "L58 복권된 행이 verdict=confirmed 를 달고 이전 값을 pre_audit_verdict 로 보존한다 (계수에서 증발 안 함)"
else
  no "L58 복권 행 verdict" "$(head -c 300 "$D/l58/confirmed.jsonl" 2>/dev/null)"
fi
# L59 🟥 S급 앵커 — 드라이버가 split 의 exit 5 를 삼키지 않는다.
#   초판은 `sed -n '/^rank_of() {/,/^}/p'` 로 함수를 뽑았는데 **rank_of 는 한 줄짜리라 범위가
#   안 끝났고**, sed 가 135줄을 뱉었고 `head -20` 이 파이썬 스크립트 중간을 잘랐고, `eval` 이
#   드라이버 코드 스무 줄을 실제로 실행했다(파일명 too long 오류까지 냈다). 레인이 통과한 이유는
#   첫 줄의 함수 정의가 크래시 «전» 에 평가됐기 때문이다 — 통과의 출처가 의도와 달랐다.
#   (cross-family round 5, gemini 계열.) 이제 **한 줄 정의만** 뽑고, 뽑은 것이 완결됐는지 검사한다.
_R59_DEF=$(/usr/bin/grep -m1 -E '^rank_of\(\) \{.*\}$' "$PIPE")
if [ -z "$_R59_DEF" ]; then
  no "L59 exit 5 순위" "rank_of 를 한 줄 형태로 못 뽑았다 — 정의가 여러 줄로 바뀌었으면 추출을 고쳐라(미측정)"
else
  _R59_5=$( eval "$_R59_DEF"; rank_of 5 )
  _R59_3=$( eval "$_R59_DEF"; rank_of 3 )
  _R59_0=$( eval "$_R59_DEF"; rank_of 0 )
  if [ "${_R59_5:-0}" -gt "${_R59_3:-0}" ] && [ "${_R59_0:-9}" -eq 0 ]; then
    ok "L59 🟥 출하 rank_of: 5 > 3 이고 0 은 0 (드라이버가 씨앗 통제 실패를 삼키지 않는다)"
  else
    no "L59 exit 5 순위" "rank_of(5)=$_R59_5 rank_of(3)=$_R59_3 rank_of(0)=$_R59_0 — 5 가 3 보다 커야 하고 0 은 0 이어야 한다"
  fi
fi
# L60 종단간 — 드라이버 `--seeded` 로 씨앗을 지우는 검증자를 태우면 파이프라인 rc 가 5 여야 한다
cat > "$D/m_seed.sh" <<'EOS'
#!/bin/sh
echo '{"id":"s1","title":"seeded known-true","file":"tgt.py","line":1,"severity":"A"}'
echo '{"id":"s2","title":"ordinary","file":"tgt.py","line":2,"severity":"B"}'
EOS
chmod +x "$D/m_seed.sh"
# 🟥 검증자는 fleet 이 «재번호한» id 를 받는다 — 그래서 픽스처는 원래 멤버 id(`member_id`)를
#   봐야 «호출자 어휘로 선언한 씨앗» 을 지울 수 있다. 이게 이 레인이 재려는 경로 그 자체다.
cat > "$D/fake_kill_seed.sh" <<'EOS'
#!/bin/sh
# 🟥 gemini 경로는 프롬프트를 stdin 이 아니라 `-p` 인자로 받고 stdin 을 /dev/null 로 닫는다.
#   stdin 만 읽는 픽스처는 그 split 에서 아무 판정도 못 내고 «미판정» 을 만든다 — 레인이
#   측정하려던 것과 다른 것을 재게 된다. 둘 다 받는다(fake_smart.sh 와 같은 형태).
IN=$(cat)
[ -n "$IN" ] || IN="$*"
printf '%s' "$IN" | python3 -c '
import sys, json
rows = []
for l in sys.stdin:
    l = l.strip()
    if not l.startswith("{"): continue
    try: rows.append(json.loads(l))
    except Exception: pass
audit = any("drop_verdict" in r or r.get("verdict") == "false-positive" for r in rows)
for r in rows:
    rid = r.get("id")
    if audit:
        print(json.dumps({"id": rid, "verdict": "correct-drop", "why": "checked"}))
    elif str(r.get("member_id")) == "s1":
        print(json.dumps({"id": rid, "verdict": "false-positive", "why": "deleting the control"}))
    else:
        print(json.dumps({"id": rid, "verdict": "confirmed", "why": "holds"}))'
EOS
chmod +x "$D/fake_kill_seed.sh"
printf 'codex|logic|%s\ngemini|security|%s\n' "sh $D/m_seed.sh" "sh $D/m_seed.sh" > "$D/fleetSEED.tbl"
# 🟥 fleet 이 id 를 재번호하므로 호출자 어휘(`s1`)로 선언할 수 있어야 한다 — member_id 보존이
#   그것을 가능하게 한다. 이 레인이 그 종단간 경로를 통째로 잰다.
FH_CODEX_BIN="$D/fake_kill_seed.sh" FH_AGY_BIN="$D/fake_kill_seed.sh" \
  bash "$PIPE" "$D/tgt.py" --out "$D/pipeSEED" --fleet "$D/fleetSEED.tbl" --seeded s1 >"$D/pSEED" 2>&1; R60=$?
if [ "$R60" -eq 5 ]; then
  ok "L60 🟥 종단간: 드라이버 --seeded s1 (호출자 어휘) 로 씨앗을 지우면 파이프라인 rc=5"
else
  no "L60 종단간 씨앗" "rc=$R60 want=5 · $(grep -m1 '^PIPELINE ' "$D/pSEED") · $(tail -2 "$D/pSEED")"
fi
# L61 배선 검사(행동 아님, 그렇게 라벨한다) — COUNT_ERR 이 실제로 소비되나
if /usr/bin/grep -q 'COUNT_ERR' "$PIPE" && /usr/bin/grep -A6 'if \[ "\$COUNT_ERR" -ne 0 \]' "$PIPE" | /usr/bin/grep -q 'note_rc'; then
  ok "L61 배선: 계측 오류 플래그가 실제로 note_rc 로 소비된다 (🟡 배선 검사지 행동 검사가 아니다)"
else
  no "L61 배선" "COUNT_ERR 이 설정만 되고 rc 에 반영되지 않는다 — 조용한 계측 실패다"
fi
# ── L62~L65 cross-family R6 (gemini) 가 잡은 것들 ────────────────────────────────
# L62 드라이버 `confirmed=` 가 debate 를 포함하면 안 된다 — verify 만 고친 반쪽-픽스의 **세 번째** 재발
FH_CODEX_BIN="$D/fake_debate.sh" FH_AGY_BIN="$D/fake_debate.sh" \
  bash "$PIPE" "$D/tgt.py" --out "$D/pipe62" --fleet "$D/fleetD.tbl" >"$D/p62" 2>&1
SUM62=$(grep -m1 '^PIPELINE ' "$D/p62")
if printf '%s' "$SUM62" | grep -qE 'confirmed=0 ' && printf '%s' "$SUM62" | grep -qE 'debate=[1-9]'; then
  ok "L62 전부 기권이면 드라이버도 confirmed=0 (한 줄 안에서 세 숫자가 서로 안 어긋난다)"
else
  no "L62 드라이버 confirmed" "$SUM62"
fi
# L63 🟥 씨앗이 두 행에 걸리면 AMBIGUOUS — «비관적으로 하나로 묶어» 거짓 DEGRADED 를 내면 안 된다
printf '%s\n%s\n' '{"id":"r1","member_id":"1","title":"a","producer_family":"gamma"}' \
                  '{"id":"r2","member_id":"1","title":"b","producer_family":"gamma"}' > "$D/amb.jsonl"
cat > "$D/sv_amb.sh" <<'EOS'
#!/bin/sh
cat >/dev/null
echo '{"id":"r1","verdict":"confirmed","why":"ok"}'
echo '{"id":"r2","verdict":"false-positive","why":"nope"}'
EOS
chmod +x "$D/sv_amb.sh"
O63=$(python3 "$HERE/finding_verify.py" "$D/amb.jsonl" --out "$D/l63" --verifier "sh $D/sv_amb.sh" \
      --family beta --seeded 1 2>&1); R63=$?
if [ "$R63" -eq 5 ] && printf '%s' "$O63" | /usr/bin/grep -q 'status=AMBIGUOUS' \
   && printf '%s' "$O63" | /usr/bin/grep -q 'locally unique'; then
  ok "L63 🟥 씨앗이 여러 행에 걸리면 AMBIGUOUS·rc=5 + 사유 (거짓 DEGRADED 로 접지 않는다)"
else
  no "L63 씨앗 모호성" "rc=$R63 · $(printf '%s' "$O63" | /usr/bin/grep -E 'status=|locally')"
fi
# L64 검증기가 «안 돌았다» 는 통제 모호성이 아니라 실행 실패 — rc=3 이어야 한다
O64=$(python3 "$HERE/finding_verify.py" "$D/sf.jsonl" --out "$D/l64" \
      --verifier "sh $D/does_not_exist_at_all.sh" --family beta --seeded z2 2>&1); R64=$?
if [ "$R64" -eq 3 ]; then
  ok "L64 검증기 실행 실패 → rc=3 (씨앗 INCONCLUSIVE 로 오보하지 않는다)"
else
  no "L64 실행 실패 vs 통제 모호성" "rc=$R64 want=3 · $(printf '%s' "$O64" | /usr/bin/grep -E '^(FINDINGS|SEEDED)')"
fi
# L65 양의 컨트롤 — 씨앗이 살아남으면 드라이버는 0 을 낸다. 없으면 «--seeded 면 무조건 5» 도 L60 을 통과한다
cat > "$D/fake_keep_seed.sh" <<'EOS'
#!/bin/sh
# 🟥 gemini 경로는 프롬프트를 stdin 이 아니라 `-p` 인자로 받고 stdin 을 /dev/null 로 닫는다.
#   stdin 만 읽는 픽스처는 그 split 에서 아무 판정도 못 내고 «미판정» 을 만든다 — 레인이
#   측정하려던 것과 다른 것을 재게 된다. 둘 다 받는다(fake_smart.sh 와 같은 형태).
IN=$(cat)
[ -n "$IN" ] || IN="$*"
printf '%s' "$IN" | python3 -c '
import sys, json
rows = []
for l in sys.stdin:
    l = l.strip()
    if not l.startswith("{"): continue
    try: rows.append(json.loads(l))
    except Exception: pass
audit = any("drop_verdict" in r or r.get("verdict") == "false-positive" for r in rows)
for r in rows:
    v = "correct-drop" if audit else "confirmed"
    print(json.dumps({"id": r.get("id"), "verdict": v, "why": "ok"}))'
EOS
chmod +x "$D/fake_keep_seed.sh"
FH_CODEX_BIN="$D/fake_keep_seed.sh" FH_AGY_BIN="$D/fake_keep_seed.sh" \
  bash "$PIPE" "$D/tgt.py" --out "$D/pipeKEEP" --fleet "$D/fleetSEED.tbl" --seeded s1 >"$D/pKEEP" 2>&1; R65=$?
if [ "$R65" -eq 0 ]; then
  ok "L65 양의 컨트롤: 씨앗이 살아남으면 --seeded 여도 rc=0 («--seeded 면 무조건 5» 를 배제)"
else
  no "L65 씨앗 양의 컨트롤" "rc=$R65 want=0 · $(grep -m1 '^PIPELINE ' "$D/pKEEP") · $(tail -2 "$D/pKEEP")"
fi

# ── L66~L68 생성시점 탈상관(--round2) — B-2 사전등록의 ARM ────────────────────────
# 🟥 논지: 계열을 «걸러낼 때» 만나게 하면 수확을 지불한다(실측 8→6). «쓸 때» 만나게 하면 안 낸다.
#   그래서 2차 패스는 수락/거부가 아니라 «자기 목록 다시 쓰기» 다. 세 가지를 박는다.
cat > "$D/r2_a.sh" <<'EOS'
#!/bin/sh
IN=$(cat); [ -n "$IN" ] || IN="$*"
case "$IN" in
  *"YOUR OWN ROUND-1 FINDINGS"*)
    echo '{"title":"A1 revised","file":"t.py","line":1,"severity":"A","category":"d","detail":"x","defeater":"y","confidence":0.8}'
    echo '{"title":"A2 new","file":"t.py","line":2,"severity":"B","category":"d","detail":"x","defeater":"y","confidence":0.6}'
    echo 'DROPPED: none' ;;
  *) echo '{"title":"A1","file":"t.py","line":1,"severity":"A","category":"d","detail":"x","defeater":"y","confidence":0.7}' ;;
esac
EOS
cat > "$D/r2_b.sh" <<'EOS'
#!/bin/sh
IN=$(cat); [ -n "$IN" ] || IN="$*"
case "$IN" in
  *"YOUR OWN ROUND-1 FINDINGS"*) echo '{"title":"B1 kept","file":"t.py","line":2,"severity":"B","category":"s","detail":"x","defeater":"y","confidence":0.7}' ;;
  *) echo '{"title":"B1","file":"t.py","line":2,"severity":"B","category":"s","detail":"x","defeater":"y","confidence":0.7}' ;;
esac
EOS
cat > "$D/r2_dead.sh" <<'EOS'
#!/bin/sh
IN=$(cat); [ -n "$IN" ] || IN="$*"
case "$IN" in
  *"YOUR OWN ROUND-1 FINDINGS"*) : ;;   # 2차에서 아무것도 안 낸다
  *) echo '{"title":"only round1","file":"t.py","line":1,"severity":"A","category":"d","detail":"x","defeater":"y","confidence":0.7}' ;;
esac
EOS
chmod +x "$D/r2_a.sh" "$D/r2_b.sh" "$D/r2_dead.sh"
printf 'def f(x):\n    return x\n' > "$D/r2t.py"
FLEET_SH2="$HERE/finding_fleet.sh"
printf 'codex|logic|sh %s\ngemini|security|sh %s\n' "$D/r2_a.sh" "$D/r2_b.sh" > "$D/fleetR2.tbl"
O66=$(bash "$FLEET_SH2" "$D/r2t.py" --out "$D/fr2" --fleet "$D/fleetR2.tbl" --round2 2>&1)
if printf '%s' "$O66" | /usr/bin/grep -q 'FLEET round2 r1=2 r2=3 delta=1'; then
  ok "L66 🟥 2차 패스가 수확을 «늘린다» (r1=2 → r2=3) — 선별이 아니라 생성이라는 증거"
else
  no "L66 생성시점 탈상관" "$(printf '%s' "$O66" | /usr/bin/grep '^FLEET round2')"
fi
# L67 peer 파일이 «자기» 와 «남» 을 실제로 가른다 — 안 가르면 무엇을 고칠지 모른다
if /usr/bin/grep -q 'YOUR OWN ROUND-1' "$D/fr2/peer_codex.txt" 2>/dev/null \
   && /usr/bin/grep -q 'THE OTHER FAMILY' "$D/fr2/peer_codex.txt" 2>/dev/null \
   && /usr/bin/grep -A2 'YOUR OWN ROUND-1' "$D/fr2/peer_codex.txt" | /usr/bin/grep -q '"A1"' \
   && /usr/bin/grep -A2 'THE OTHER FAMILY' "$D/fr2/peer_codex.txt" | /usr/bin/grep -q '"B1"'; then
  ok "L67 peer 브리핑이 자기 것과 남의 것을 갈라서 보여준다"
else
  no "L67 peer 브리핑" "$(head -8 "$D/fr2/peer_codex.txt" 2>/dev/null)"
fi
# L68 🟥 2차가 아무것도 못 내면 1차를 «대체» 하면 안 된다 — 그러면 탈상관이 아니라 삭제다
printf 'codex|logic|sh %s\n' "$D/r2_dead.sh" > "$D/fleetR2d.tbl"
O68=$(bash "$FLEET_SH2" "$D/r2t.py" --out "$D/fr2d" --fleet "$D/fleetR2d.tbl" --round2 2>&1)
N68=$(/usr/bin/wc -l < "$D/fr2d/findings.jsonl" 2>/dev/null | tr -d ' ')
# R2 #4 이후: 단독 멤버가 2차 빈손이면 «멤버별 폴백»(ZERO_EMPTY → 자기 1차) 이 먼저 잡는다 — 둘 다 «1차 보존» 이다
if [ "${N68:-0}" -ge 1 ] && printf '%s' "$O68" | /usr/bin/grep -qE 'keeping round-1 findings|keeping ITS round-1 findings'; then
  ok "L68 🟥 2차가 빈손이면 1차를 유지한다 (실패한 2차가 1차를 삭제하지 않는다)"
else
  no "L68 2차 실패 시 1차 보존" "findings=$N68 · $(printf '%s' "$O68" | /usr/bin/grep -E 'round2')"
fi

# ── L69~L72 검증자 풀 = 함대 명부 (측정이 스스로 찾아낸 결함, 2026-09-10) ──────────────
# 🟥 논지: families.txt 는 «발견을 낸 계열» 이라서 0건을 낸 계열은 검증자 후보에서 사라진다.
#   그러면 멀쩡히 돌아간 검증자가 있는데도 발견 전체가 미검증으로 떨어진다(coverage 0/N).
#   실측: F_typed 팔 case_g02.py r1~r3 — gemini 가 안전필터로 «차단»(rc=0!) 되어 0건 → codex 2건 전량 미검증.
cat > "$D/one_find.sh" <<'EOS'
#!/bin/sh
cat >/dev/null
echo '{"title":"solo A","file":"pool_t.py","line":1,"severity":"A","category":"d","detail":"x","defeater":"y","confidence":0.8}'
echo '{"title":"solo B","file":"pool_t.py","line":2,"severity":"B","category":"d","detail":"x","defeater":"y","confidence":0.6}'
EOS
cat > "$D/zero_prose.sh" <<'EOS'
#!/bin/sh
cat >/dev/null
echo 'No issues found in this file.'
EOS
cat > "$D/zero_dead.sh" <<'EOS'
#!/bin/sh
cat >/dev/null
echo 'ERROR: quota exhausted' >&2
exit 1
EOS
# 검증자 스텁 — 받은 모든 행을 confirmed 로 판정. 감사 패스면 correct-drop.
# 🟥 gemini 경로는 프롬프트를 stdin 이 아니라 `-p` 인자로 주고 stdin 을 닫는다(L65 의 교훈).
cat > "$D/ver_ok.sh" <<'EOS'
#!/bin/sh
IN=$(cat)
[ -n "$IN" ] || IN="$*"
printf '%s' "$IN" | /usr/bin/python3 -c '
import sys, json
rows=[]
for l in sys.stdin:
    l=l.strip()
    if not l.startswith("{"): continue
    try: rows.append(json.loads(l))
    except Exception: pass
audit=any("drop_verdict" in r or r.get("verdict")=="false-positive" for r in rows)
for r in rows:
    v="correct-drop" if audit else "confirmed"
    print(json.dumps({"id": r.get("id"), "verdict": v, "why": "stub"}))'
EOS
chmod +x "$D/one_find.sh" "$D/zero_prose.sh" "$D/zero_dead.sh" "$D/ver_ok.sh"
printf 'def p(x):\n    return x\n' > "$D/pool_t.py"

# L69 함대는 «응답은 있는데 계약 출력 0» 을 ZERO_NONJSON 으로 타입한다 (차단이 이 얼굴이다)
printf 'codex|logic|sh %s\ngemini|security|sh %s\n' "$D/one_find.sh" "$D/zero_prose.sh" > "$D/fleetP.tbl"
O69=$(bash "$HERE/finding_fleet.sh" "$D/pool_t.py" --out "$D/fp1" --fleet "$D/fleetP.tbl" 2>&1)
if printf '%s\n' "$O69" | /usr/bin/grep -q 'family=gemini .*findings=0 status=ZERO_NONJSON' \
   && printf '%s\n' "$O69" | /usr/bin/grep -q 'family=codex .*findings=2 status=OK'; then
  ok "L69 🟥 rc=0 인 «응답 있음·계약 0» 이 ZERO_NONJSON 으로 기록된다 (known-negative: 발견 낸 쪽은 OK)"
else
  no "L69 ZERO_NONJSON 타입" "$(printf '%s\n' "$O69" | /usr/bin/grep '^MEMBER')"
fi

# L70 🟥 본 결함 — 0건을 낸 계열이 «검증자로 쓰인다». 수리 전에는 coverage 0/2 rc=3 이었다.
O70=$(FH_CODEX_BIN="$D/ver_ok.sh" FH_AGY_BIN="$D/ver_ok.sh" \
      bash "$PIPE" "$D/pool_t.py" --out "$D/pp1" --fleet "$D/fleetP.tbl" 2>&1); RC70=$?
L70=$(printf '%s\n' "$O70" | /usr/bin/grep '^PIPELINE ')
if [ "$RC70" -eq 0 ] && printf '%s' "$L70" | /usr/bin/grep -q 'coverage=2/2 (100%)' \
   && printf '%s' "$L70" | /usr/bin/grep -q 'roster=[a-z,]*codex' \
   && printf '%s' "$L70" | /usr/bin/grep -q 'roster=[a-z,]*gemini' \
   && printf '%s' "$L70" | /usr/bin/grep -q '(fleet)' \
   && printf '%s' "$L70" | /usr/bin/grep -q 'blocked_members=1'; then
  ok "L70 🟥 0건 계열이 검증자 풀에 남는다 — coverage 2/2 rc=0 (수리 전: 0/2 rc=3)"
else
  no "L70 검증자 풀=함대 명부" "rc=$RC70 · $L70"
fi

# L71 반대 방향 — 상대 멤버가 «실제로 실패» 하면 풀에 들어가면 안 된다. 미검증이 정직한 답이다.
printf 'codex|logic|sh %s\ngemini|security|sh %s\n' "$D/one_find.sh" "$D/zero_dead.sh" > "$D/fleetQ.tbl"
O71=$(FH_CODEX_BIN="$D/ver_ok.sh" FH_AGY_BIN="$D/ver_ok.sh" \
      bash "$PIPE" "$D/pool_t.py" --out "$D/pp2" --fleet "$D/fleetQ.tbl" 2>&1); RC71=$?
L71=$(printf '%s\n' "$O71" | /usr/bin/grep '^PIPELINE ')
if [ "$RC71" -eq 3 ] && printf '%s' "$L71" | /usr/bin/grep -q 'roster=codex(fleet)' \
   && printf '%s' "$L71" | /usr/bin/grep -q 'coverage=0/2 (0%)'; then
  ok "L71 🟥 죽은 멤버는 검증자가 못 된다 — rc=3·roster=codex (과교정 방지: 풀이 무조건 넓어지지 않는다)"
else
  no "L71 죽은 멤버 배제" "rc=$RC71 · $L71"
fi

# L72 되돌림 프로브 — 풀 소스를 families.txt 로 되돌리면 L70 이 «정확히» 빨개지나
# 🟥 사본의 HERE 는 사본이 있는 디렉터리다 — 형제 스크립트를 같이 옮기지 않으면 «missing …
#   skipped, NOT passed» 로 exit 3 이 나서 rc 만 맞는 거짓 초록이 된다(초판이 그랬고, 아래
#   coverage 단언이 그것을 잡았다 — rc 하나만 봤으면 통과했다).
/bin/cp "$HERE/finding_fleet.sh" "$HERE/finding_verify.py" "$HERE/finding_verifier.sh" "$D/" 2>/dev/null
/usr/bin/sed 's|done < "$ROSTER"|done < "$OUT/families.txt"|g' "$PIPE" > "$D/pipe_rev.sh"
NREV=$(/usr/bin/grep -c 'done < "\$OUT/families.txt"' "$D/pipe_rev.sh" 2>/dev/null); NREV=${NREV:-0}
if [ "$NREV" -ge 2 ]; then
  RCVOUT=$(FH_CODEX_BIN="$D/ver_ok.sh" FH_AGY_BIN="$D/ver_ok.sh" \
        bash "$D/pipe_rev.sh" "$D/pool_t.py" --out "$D/pp3" --fleet "$D/fleetP.tbl" 2>&1); RCV_RC=$?
  if [ "$RCV_RC" -eq 3 ] && printf '%s\n' "$RCVOUT" | /usr/bin/grep -q 'coverage=0/2 (0%)'; then
    ok "L72 되돌림 — 풀을 families.txt 로 돌리면 결함이 정확히 재발한다 (L70 앵커가 장식이 아니다)"
  else
    no "L72 되돌림 프로브" "rc=$RCV_RC want=3 · $(printf '%s\n' "$RCVOUT" | /usr/bin/grep '^PIPELINE ') · $(printf '%s\n' "$RCVOUT" | /usr/bin/grep -m1 -i 'missing\|skipped')"
  fi
else
  no "L72 되돌림 프로브" "치환 적용 $NREV 곳 (>=2 필요) — HARNESS-ERROR, 대상 무판정"
fi

# ── L73~L78 cross-family 라운드가 연 구멍들 (codex, 2026-09-10) ────────────────────
# 🟥 여섯 건 전부 «내 수리가 만든» 결함이다 — 측정이 ①②를 물어왔고, 적대검증이 그 수리를 물었다.
FL="$HERE/finding_fleet.sh"
printf 'def q(x):\n    return x\n' > "$D/x_t.py"
# 2차에서: codex 는 비고(glob 첫 파일) gemini 는 찬다
cat > "$D/x_c_empty2.sh" <<'EOS'
#!/bin/sh
IN=$(cat); [ -n "$IN" ] || IN="$*"
case "$IN" in
  *"YOUR OWN ROUND-1 FINDINGS"*) : ;;
  *) echo '{"title":"C1 round1 only","file":"x_t.py","line":1,"severity":"A","category":"d","detail":"x","defeater":"y","confidence":0.7}' ;;
esac
EOS
cat > "$D/x_g_full2.sh" <<'EOS'
#!/bin/sh
IN=$(cat); [ -n "$IN" ] || IN="$*"
case "$IN" in
  *"YOUR OWN ROUND-1 FINDINGS"*)
    echo '{"title":"G1 revised","file":"x_t.py","line":2,"severity":"B","category":"s","detail":"x","defeater":"y","confidence":0.8}'
    echo '{"title":"G2 new","file":"x_t.py","line":3,"severity":"B","category":"s","detail":"x","defeater":"y","confidence":0.6}' ;;
  *) echo '{"title":"G1","file":"x_t.py","line":2,"severity":"B","category":"s","detail":"x","defeater":"y","confidence":0.7}' ;;
esac
EOS
# 2차에서 일부만 내고 죽는다 (rc=1)
cat > "$D/x_c_die2.sh" <<'EOS'
#!/bin/sh
IN=$(cat); [ -n "$IN" ] || IN="$*"
case "$IN" in
  *"YOUR OWN ROUND-1 FINDINGS"*)
    echo '{"title":"C1 partial","file":"x_t.py","line":1,"severity":"A","category":"d","detail":"x","defeater":"y","confidence":0.7}'
    exit 1 ;;
  *)
    echo '{"title":"C1 round1","file":"x_t.py","line":1,"severity":"A","category":"d","detail":"x","defeater":"y","confidence":0.7}'
    echo '{"title":"C2 round1 ONLY — must survive","file":"x_t.py","line":9,"severity":"A","category":"d","detail":"x","defeater":"y","confidence":0.7}' ;;
esac
EOS
# 2차에서 «전부 스스로 내림» 만 낸다 (계약이 요구한 출력)
cat > "$D/x_selfdrop2.sh" <<'EOS'
#!/bin/sh
IN=$(cat); [ -n "$IN" ] || IN="$*"
case "$IN" in
  *"YOUR OWN ROUND-1 FINDINGS"*) echo 'DROPPED: S1 — checked the caller; my claim was wrong' ;;
  *) echo '{"title":"S1","file":"x_t.py","line":1,"severity":"A","category":"d","detail":"x","defeater":"y","confidence":0.7}' ;;
esac
EOS
# 발견을 내고 «죽는다» (rc=1) — 1차에서
cat > "$D/x_emit_die.sh" <<'EOS'
#!/bin/sh
cat >/dev/null
echo '{"title":"E1 emitted then died","file":"x_t.py","line":1,"severity":"A","category":"d","detail":"x","defeater":"y","confidence":0.7}'
exit 1
EOS
chmod +x "$D"/x_*.sh

# L73 🟥 glob 첫 파일이 비었다고 «2차가 아무것도 못 냈다» 로 보고하면 안 된다
printf 'codex|logic|sh %s\ngemini|security|sh %s\n' "$D/x_c_empty2.sh" "$D/x_g_full2.sh" > "$D/fx1.tbl"
O73=$(bash "$FL" "$D/x_t.py" --out "$D/fx1" --fleet "$D/fx1.tbl" --round2 2>&1)
if ! printf '%s\n' "$O73" | /usr/bin/grep -q 'produced nothing' \
   && /usr/bin/grep -q 'G2 new' "$D/fx1/findings.jsonl" 2>/dev/null; then
  ok "L73 🟥 glob 첫 파일이 비어도 «2차 빈손» 으로 오보하지 않는다 (멤버별 병합)"
else
  no "L73 glob-첫파일 편향" "$(printf '%s\n' "$O73" | /usr/bin/grep -E '^FLEET round2')"
fi

# L74 🟥 2차에서 죽은 멤버의 «1차 발견» 이 삭제되면 안 된다 — 조용한 수확 손실
printf 'codex|logic|sh %s\ngemini|security|sh %s\n' "$D/x_c_die2.sh" "$D/x_g_full2.sh" > "$D/fx2.tbl"
O74=$(bash "$FL" "$D/x_t.py" --out "$D/fx2" --fleet "$D/fx2.tbl" --round2 2>&1)
if /usr/bin/grep -q 'C2 round1 ONLY' "$D/fx2/findings.jsonl" 2>/dev/null \
   && printf '%s\n' "$O74" | /usr/bin/grep -q 'fallback=1' \
   && /usr/bin/grep -q 'G2 new' "$D/fx2/findings.jsonl" 2>/dev/null; then
  ok "L74 🟥 2차에서 죽은 멤버는 «자기 1차» 로 되돌아가고, 성공한 멤버는 2차로 간다 (멤버별)"
else
  no "L74 2차 실패 멤버별 폴백" "$(printf '%s\n' "$O74" | /usr/bin/grep -E 'fallback|FLEET round2') · $(wc -l < "$D/fx2/findings.jsonl" 2>/dev/null)"
fi

# L75 🟥 «빈 명부» 는 성공이 아니다 — 출하되는 명부 빌더를 «뽑아서» 직접 잰다.
#   초판 픽스처는 이 경로에 못 닿았다(멤버가 전부 죽으면 함대가 더 앞에서 rc≠0 으로 끝난다).
#   그래서 L55 와 같은 형태로 **출하 코드를 추출해** 양방향으로 돌린다 — 장식 레인 방지.
/usr/bin/python3 - "$PIPE" "$D/roster_builder.py" <<'PY'
import sys, re
src, dst = sys.argv[1], sys.argv[2]
s = open(src, encoding="utf-8").read()
m = re.search(r"/usr/bin/python3 -c '\n(import re,sys\n.*?)' \"\$OUT/fleet/members\.txt\"", s, re.S)
if not m:
    sys.stderr.write("HARNESS-ERROR: roster builder snippet not found in the shipped driver\n"); sys.exit(9)
open(dst, "w", encoding="utf-8").write(m.group(1))
PY
if [ -s "$D/roster_builder.py" ]; then
  printf 'MEMBER family=codex role=logic rc=1 findings=0 status=FAILED\n' > "$D/mem_bad.txt"
  printf 'MEMBER family=codex role=logic review rc=0 findings=1 status=OK\nMEMBER family=gemini role=security rc=0 findings=1 status=OK\n' > "$D/mem_space.txt"
  R75A=$(/usr/bin/python3 "$D/roster_builder.py" "$D/mem_bad.txt" 2>/dev/null); A=$?
  R75B=$(/usr/bin/python3 "$D/roster_builder.py" "$D/mem_space.txt" 2>/dev/null); B=$?
  NB=$(printf '%s\n' "$R75B" | /usr/bin/grep -c .)
  # 🟥 R2: `sys.exit(4)`→`raise` 로 바꿔도 «비영» 이라 통과했다 — 의도한 실패와 크래시가 같은 얼굴. 코드 4 를 «정확히» 요구.
  E75A=$(/usr/bin/python3 "$D/roster_builder.py" "$D/mem_bad.txt" 2>&1 >/dev/null)
  if [ "$A" -eq 4 ] && [ -z "$R75A" ] && printf '%s' "$E75A" | /usr/bin/grep -q '0 usable families' && [ "$B" -eq 0 ] && [ "$NB" = 2 ]; then
    ok "L75 🟥 출하 명부 빌더: 0계열이면 «exit 4 + 사유»(크래시와 구분) · 공백 낀 role 도 2계열로 파싱 (양방향)"
  else
    no "L75 명부 빌더" "빈명부 rc=$A(4 기대) out='$R75A' err='$E75A' · 공백role rc=$B n=$NB(0·2 기대)"
  fi
else
  no "L75 명부 빌더" "HARNESS-ERROR: 출하 스니펫 추출 실패 — 대상 무판정"
fi
# L75b 배선 — 드라이버가 «바이트» 가 아니라 «계열 수» 로 판정하나
if /usr/bin/grep -q '_ROSTER_N=$(/usr/bin/grep -c . "$ROSTER"' "$PIPE" \
   && /usr/bin/grep -q '\[ "$_ROSTER_N" -eq 0 \]' "$PIPE" \
   && ! /usr/bin/grep -q '! -s "$ROSTER"' "$PIPE"; then
  ok "L75b 드라이버가 명부를 «계열 수» 로 판정한다 (-s 가 사라졌다 — 🟡 배선 검사)"
else
  no "L75b 명부 판정 배선" "$(/usr/bin/grep -n 'ROSTER_N\|-s \"\$ROSTER\"' "$PIPE" | head -3)"
fi

# L76 🟥 «전부 스스로 내림» 은 계약 준수지 «차단» 이 아니다
printf 'codex|logic|sh %s\n' "$D/x_selfdrop2.sh" > "$D/fx4.tbl"
O76=$(bash "$FL" "$D/x_t.py" --out "$D/fx4" --fleet "$D/fx4.tbl" --round2 2>&1)
if printf '%s\n' "$O76" | /usr/bin/grep -q 'MEMBER2 .*status=ZERO_SELFDROPPED' \
   && ! printf '%s\n' "$O76" | /usr/bin/grep -q 'MEMBER2 .*status=ZERO_NONJSON'; then
  ok "L76 🟥 DROPPED 만 낸 2차 멤버는 ZERO_SELFDROPPED (규약을 지킨 멤버가 blocked 로 안 세어진다)"
else
  no "L76 자기드롭 분류" "$(printf '%s\n' "$O76" | /usr/bin/grep '^MEMBER2')"
fi

# L77 🟥 blocked_members 는 «마지막 필드» 에 결박된다 — role 값이 그 자리를 흉내내면 안 된다
# 🟥 R2: 초판은 «자기 리터럴» 을 검사해서 프로덕션의 `$` 를 지워도 초록이었다. 출하 패턴을 뽑아 쓴다.
_P77=$(/usr/bin/sed -n "s/^BLOCKED_MEMBERS=\$(grep -c '\(.*\)' \"\$OUT\/fleet_run.log\".*/\1/p" "$PIPE" | head -1)
[ -n "$_P77" ] || _P77='__EXTRACT_FAILED__'
_L77=$(printf 'MEMBER family=gemini role=status=ZERO_NONJSON rc=0 findings=1 status=OK\n' | /usr/bin/grep -c "$_P77")
_L77b=$(printf 'MEMBER family=gemini role=security rc=0 findings=0 status=ZERO_NONJSON\n' | /usr/bin/grep -c "$_P77")
if [ "$_L77" = 0 ] && [ "$_L77b" = 1 ]; then
  ok "L77 «출하» blocked_members 패턴이 role 흉내를 안 세고 진짜 status 는 센다 (프로덕션 추출, known-pair)"
else
  no "L77 blocked 패턴 결박" "role흉내=$_L77(0 기대) 진짜=$_L77b(1 기대)"
fi

# L78 새 쓰기 경로가 심링크 가드 목록에 있나 (배선 검사 — 그렇게 라벨한다)
# 🟥 R2: 같은 문자열이 쓰기 줄에도 있어서 가드에서 빼도 초록이었다. «for _p in» 가드 줄 안에서만 찾는다.
if /usr/bin/grep -E '^for _p in .*"\$OUT/roster.err"' "$PIPE" >/dev/null && /usr/bin/grep -E '^\s*for _p in .*"\$out/peer_\$\{fam\}.txt"' "$FL" >/dev/null; then
  ok "L78 새 출력 경로(roster.err · peer_<fam>.txt)가 심링크 가드에 등재됨 (🟡 배선 검사)"
else
  no "L78 심링크 가드 등재" "roster.err=$(/usr/bin/grep -c '"\$OUT/roster.err"' "$PIPE") peer=$(/usr/bin/grep -c 'peer_\${fam}.txt"' "$FL")"
fi

# L79 🟥 검증 패스의 CLI stderr(토큰 회계)가 버려지지 않는다 — mktemp cleanup 이 지우던 것
cat > "$D/ver_acct.sh" <<'EOS'
#!/bin/sh
IN=$(cat); [ -n "$IN" ] || IN="$*"
echo "tokens used" >&2; echo "12345" >&2
printf '%s' "$IN" | /usr/bin/python3 -c '
import sys,json
for l in sys.stdin:
    l=l.strip()
    if l.startswith("{"):
        d=json.loads(l); print(json.dumps({"id":d["id"],"verdict":"confirmed","why":"x"}))'
EOS
chmod +x "$D/ver_acct.sh"
printf 'codex|logic|sh %s\ngemini|security|sh %s\n' "$D/one_find.sh" "$D/one_find.sh" > "$D/fleetK.tbl"
FH_CODEX_BIN="$D/ver_acct.sh" FH_AGY_BIN="$D/ver_acct.sh" \
  bash "$PIPE" "$D/pool_t.py" --out "$D/pk" --fleet "$D/fleetK.tbl" >/dev/null 2>&1
# 🟥 R2: 두 split 이 첫 디렉터리로 몰려도 «하나만 매치» 라 통과했다. split 마다 «자기» keep 을 요구한다.
_N79=$(ls -d "$D"/pk/split_* 2>/dev/null | wc -l | tr -d ' ')
_K79=$(for d in "$D"/pk/split_*; do /usr/bin/grep -lq 'tokens used' "$d"/err.txt "$d"/keep_verify/err.txt 2>/dev/null && echo 1; done | wc -l | tr -d ' ')
if [ "$_N79" -ge 2 ] && [ "$_K79" = "$_N79" ]; then
  ok "L79 검증 패스 stderr 가 «split 마다» 남는다 ($_K79/$_N79 — 첫 디렉터리로 몰리지 않는다)"
else
  no "L79 검증 stderr 보존" "split=$_N79 keep=$_K79 · $(ls "$D"/pk/split_* 2>/dev/null | head -3)"
fi

# ── L80~L84 cross-family R2 (codex, 2026-09-10 21:45) — 2차 병합·명부 파서의 남은 구멍 ─────────
# 🟥 F_gen 실측: case_h01.rs r1 에서 gemini 2차 차단(ZERO_NONJSON) → 1차 발견 4건이 최종에서 삭제됐다.
# 2차가 차단·빈응답인 멤버 (R2 #4)
cat > "$D/r2_blocked.sh" <<'EOS'
#!/bin/sh
IN=$(cat); [ -n "$IN" ] || IN="$*"
case "$IN" in
  *"YOUR OWN ROUND-1 FINDINGS"*) echo "This request was blocked by filters." ;;
  *) echo '{"title":"B1 round1 — must survive block","file":"x_t.py","line":1,"severity":"A","category":"s","detail":"x","defeater":"y","confidence":0.7}' ;;
esac
EOS
# 전원 자기 철회 (R2 #5)
cat > "$D/r2_drop_all.sh" <<'EOS'
#!/bin/sh
IN=$(cat); [ -n "$IN" ] || IN="$*"
case "$IN" in
  *"YOUR OWN ROUND-1 FINDINGS"*) echo 'DROPPED: W1 — re-read; not a defect' ;;
  *) echo '{"title":"W1","file":"x_t.py","line":1,"severity":"A","category":"d","detail":"x","defeater":"y","confidence":0.7}' ;;
esac
EOS
chmod +x "$D/r2_blocked.sh" "$D/r2_drop_all.sh"

# L80 🟥 #4: 2차에서 차단된 멤버의 1차 발견은 «자기 1차» 로 폴백된다 (삭제되지 않는다)
printf 'codex|logic|sh %s\ngemini|security|sh %s\n' "$D/x_g_full2.sh" "$D/r2_blocked.sh" > "$D/f80.tbl"
O80=$(bash "$FL" "$D/x_t.py" --out "$D/f80" --fleet "$D/f80.tbl" --round2 2>&1)
if /usr/bin/grep -q 'B1 round1' "$D/f80/findings.jsonl" 2>/dev/null && printf '%s\n' "$O80" | /usr/bin/grep -q 'gemini/security ZERO_NONJSON — keeping ITS round-1'; then
  ok "L80 🟥 2차 차단(ZERO_NONJSON) 멤버는 자기 1차로 폴백 — 발견이 삭제되지 않는다 (F_gen h01 r1 재현 차단)"
else
  no "L80 2차 차단 폴백" "$(printf '%s\n' "$O80" | /usr/bin/grep -E 'round2') · B1=$(/usr/bin/grep -c 'B1 round1' "$D/f80/findings.jsonl" 2>/dev/null)"
fi

# L81 🟥 #5: 전원이 «정당하게» 철회하면 결과는 빈 것이고, 1차로 되돌리지 않는다
printf 'codex|logic|sh %s\n' "$D/r2_drop_all.sh" > "$D/f81.tbl"
O81=$(bash "$FL" "$D/x_t.py" --out "$D/f81" --fleet "$D/f81.tbl" --round2 2>&1)
N81=$(/usr/bin/grep -c . "$D/f81/findings.jsonl" 2>/dev/null); N81=${N81:-0}
if [ "$N81" -eq 0 ] && printf '%s\n' "$O81" | /usr/bin/grep -q 'all members withdrew'; then
  ok "L81 🟥 전원 자기철회 → 최종 0건 (정당한 철회가 «1차 유지» 로 무효화되지 않는다)"
else
  no "L81 전원 철회" "final=$N81(0 기대) · $(printf '%s\n' "$O81" | /usr/bin/grep -E 'round2')"
fi

# L82 🟥 #3: 멤버 키 매칭이 리터럴 — role `logic.review` 가 `logicXreview` 의 상태를 집지 않는다
T82=$(mktemp -d); mkdir -p "$T82"
printf 'MEMBER2 family=codex role=logic.review rc=1 findings=1 status=FAILED\nMEMBER2 family=codex role=logicXreview rc=0 findings=1 status=OK\n' > "$T82/members.txt"
_ST82=$(/usr/bin/awk -v f="codex" -v r="logic.review" '$1=="MEMBER2" && $2=="family="f && $3=="role="r {for(i=4;i<=NF;i++) if($i ~ /^status=/) v=substr($i,8)} END{print v}' "$T82/members.txt")
_SED82=$(/usr/bin/sed -n "s/^MEMBER2 family=codex role=logic.review .*status=\([A-Z_]*\).*/\1/p" "$T82/members.txt" | tail -1)
if [ "$_ST82" = "FAILED" ] && [ "$_SED82" = "OK" ] && /usr/bin/grep -q 'awk -v f="\$_fam" -v r="\$_role"' "$FL"; then
  ok "L82 🟥 멤버 키 리터럴 매칭 (awk) — 보간 sed 는 OK 를 오집(known-negative 동반), 출하본은 awk"
else
  no "L82 멤버 키 매칭" "awk=$_ST82(FAILED 기대) sed=$_SED82(OK=오집 재현) 출하=$(/usr/bin/grep -c 'awk -v f=' "$FL")"
fi
/bin/rm -rf "$T82"

# L83 🟥 #6: 명부 파서가 role 안의 rc= 를 안 본다
printf 'MEMBER family=gemini role=rc=1 rc=0 findings=1 status=OK\nMEMBER family=codex role=rc=0 rc=1 findings=0 status=FAILED\n' > "$D/mem83.txt"
R83=$(/usr/bin/python3 "$D/roster_builder.py" "$D/mem83.txt" 2>/dev/null | tr '\n' ',')
if [ "$R83" = "gemini," ]; then
  ok "L83 🟥 명부 파서가 role 의 rc= 에 안 속는다 (gemini 포함·codex 배제)"
else
  no "L83 명부 rc 파싱" "got='$R83' want='gemini,'"
fi

# L84 🟥 #7: 검증 keep 과 감사 keep 이 «다른» 디렉터리 — 드롭이 있는 런에서 감사가 검증 err 를 안 덮는다
cat > "$D/ver_drop_acct.sh" <<'EOS'
#!/bin/sh
IN=$(cat); [ -n "$IN" ] || IN="$*"
# 🟥 원문 grep 은 두 방향 다 틀렸다(검증 프롬프트에 false-positive 리터럴 有 · 감사 프롬프트에 drop_verdict 리터럴 無).
#    «행» 을 파싱해 verdict==false-positive 를 가진 행이 있으면 감사다 — 드롭 행만 verdict 를 달고 온다(fake_kill_seed 와 동형).
if printf '%s' "$IN" | /usr/bin/python3 -c '
import sys,json
rows=[json.loads(l) for l in sys.stdin if l.strip().startswith("{")]
sys.exit(0 if any(r.get("verdict")=="false-positive" for r in rows) else 1)'; then echo "tokens used AUDIT" >&2; else echo "tokens used VERIFY" >&2; fi
printf '%s' "$IN" | /usr/bin/python3 -c '
import sys,json
rows=[json.loads(l) for l in sys.stdin if l.strip().startswith("{")]
audit=any("drop_verdict" in r or r.get("verdict")=="false-positive" for r in rows)
for r in rows:
    v="correct-drop" if audit else ("false-positive" if r.get("member_id")=="d1" else "confirmed")
    print(json.dumps({"id":r.get("id"),"verdict":v,"why":"x"}))'
EOS
chmod +x "$D/ver_drop_acct.sh"
cat > "$D/m_drop.sh" <<'EOS'
#!/bin/sh
cat >/dev/null
echo '{"id":"d1","title":"will be dropped","file":"pool_t.py","line":1,"severity":"B","category":"d","detail":"x","defeater":"y"}'
echo '{"id":"k1","title":"kept","file":"pool_t.py","line":2,"severity":"A","category":"d","detail":"x","defeater":"y"}'
EOS
chmod +x "$D/m_drop.sh"
printf 'codex|logic|sh %s\ngemini|security|sh %s\n' "$D/m_drop.sh" "$D/m_drop.sh" > "$D/f84.tbl"
FH_CODEX_BIN="$D/ver_drop_acct.sh" FH_AGY_BIN="$D/ver_drop_acct.sh" bash "$PIPE" "$D/pool_t.py" --out "$D/f84" --fleet "$D/f84.tbl" >/dev/null 2>&1
V84=$(/usr/bin/grep -l 'tokens used VERIFY' "$D"/f84/split_*/keep_verify/err.txt 2>/dev/null | wc -l | tr -d ' ')
A84=$(/usr/bin/grep -l 'tokens used AUDIT'  "$D"/f84/split_*/keep_audit/err.txt  2>/dev/null | wc -l | tr -d ' ')
if [ "$V84" -ge 1 ] && [ "$A84" -ge 1 ]; then
  ok "L84 🟥 검증 keep($V84) 과 감사 keep($A84) 이 갈라져 있다 — 드롭 런에서 검증 토큰 회계가 살아남는다"
else
  no "L84 keep 분리" "verify=$V84 audit=$A84 · $(ls -d "$D"/f84/split_*/keep_* 2>/dev/null | head -3)"
fi

/bin/rm -rf "$D"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] && { echo "FAILED=0"; exit 0; } || { echo "FAILED=1"; exit 1; }

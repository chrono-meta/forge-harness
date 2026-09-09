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
/usr/bin/python3 - "$PIPE" "$MUTP" <<'PY'
import sys
src, dst = sys.argv[1], sys.argv[2]
s = open(src, encoding="utf-8").read()
key = '  while IFS= read -r f; do [ -n "$f" ] && [ "$f" != "$p" ] && supported "$f" && { echo "$f"; return; }; done < "$OUT/families.txt"'
assert key in s, "pick_verifier body moved — the revert probe is pinned to a line that no longer exists"
s = s.replace(key, '  echo "$p"')   # 자기 계열을 검증기로 고른다
open(dst, "w", encoding="utf-8").write(s)
PY
FH_CODEX_BIN="$D/fake_conf.sh" FH_AGY_BIN="$D/fake_conf.sh" \
  bash "$MUTP" "$D/tgt.py" --out "$D/pipe23" --fleet "$D/fleet.tbl" >"$D/p23" 2>&1
M23=$(grep '^PIPELINE ' "$D/p23" | grep -c 'unverified=2')
[ "$M23" = 1 ] \
  && ok "L23 되돌림: 검증기를 자기 계열로 바꾸면 전부 unverified 로 떨어진다 (L20 은 장식이 아니다)" \
  || no "L23 되돌림" "뮤턴트인데 unverified=2 가 안 나왔다 — L20 이 실물을 안 잰다 · $(grep '^PIPELINE ' "$D/p23")"

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
# L59 🟥 S급 — 드라이버가 split 의 exit 5 를 삼키면 안 된다 (rank_of 에 5 가 없었다)
_R59=$(bash -c 'rank_of() { case "$1" in 2) echo 5;; 5) echo 4;; 3) echo 3;; 4) echo 2;; *) echo 0;; esac; }; rank_of 5')
_R59_REAL=$(sed -n '/^rank_of() {/,/^}/p' "$PIPE" | head -20)
if [ -z "$_R59_REAL" ]; then
  _R59_REAL=$(/usr/bin/grep -m1 '^rank_of() ' "$PIPE")
fi
_R59_OUT=$(eval "$_R59_REAL"; rank_of 5)
if [ "${_R59_OUT:-0}" -gt 0 ]; then
  ok "L59 🟥 출하되는 rank_of 가 exit 5 를 «실패» 로 순위매긴다 (드라이버가 씨앗 통제 실패를 안 삼킨다)"
else
  no "L59 exit 5 순위" "rank_of 5 → ${_R59_OUT:-없음} — 0 이면 드라이버가 rc=0 을 낸다"
fi

/bin/rm -rf "$D"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] && { echo "FAILED=0"; exit 0; } || { echo "FAILED=1"; exit 1; }

#!/usr/bin/env bash
# 사용 원장 계기 보정 레인 — 「행이 0 줄」이 무엇을 뜻하는지 가르는 것이 이 레인의 전부다.
#
# ## 왜 이 레인이 있나
#
# 사용 지표는 **부재를 0 으로 렌더하기 가장 쉬운 계기**다. 원장이 비어 있을 때 가능한 원인이 넷이고
# 넷 다 출력이 똑같이 「0」이다:
#   ① 옵트인을 안 켰다(설계대로)  ② 켰는데 쓰기가 실패했다  ③ 배선이 끊겼다  ④ 진짜로 아무도 안 썼다
# 이 레인은 ①②③ 을 ④ 와 갈라내는 장치다. 그리고 마지막 레인(되돌림)은 **이 레인 자신이 장식인지**를
# 묻는다 — 배선을 떼면 known-positive 가 정확히 빨개져야 한다.
#
# 실행: bash scripts/test_usage_ledger_lanes.sh
set -u
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PREPREP="$REPO_ROOT/plugins/fh-commons/skills/preprep"
PASS=0; FAIL=0; SKIP=0
ok(){ printf '  ✅ %s\n' "$1"; PASS=$((PASS+1)); }
ng(){ printf '  ❌ %s\n' "$1"; FAIL=$((FAIL+1)); }
sk(){ printf '  ⬜ SKIP %s\n' "$1"; SKIP=$((SKIP+1)); }

TMPROOT=$(mktemp -d); trap 'rm -rf "$TMPROOT"' EXIT
# 🟥 `|| true` 를 안 쓴다 — 폴백은 계기 고장을 「0」으로 접는다(이 저장소가 이름으로 관리하는 부류).
#    `grep -c .` 는 입력이 비면 «0» 을 찍고 rc=1 을 낸다: 값은 이미 옳으므로 rc 를 삼킬 이유가 없다.
#    값이 아예 안 나오는 경우(계기 고장)는 HARNESS-ERROR 를 돌려 **모든 비교를 실패**시킨다.
# 🟥 grep 경로를 변수로 뺀다 — 레인 ⑦ 이 **테스트 더블이 아니라 이 함수 자신**에 고장을 주입해
#    HARNESS-ERROR 가지가 실제로 밟히는지 보기 위해서다(안 밟힌 가드는 장식이다).
GREP_BIN="${GREP_BIN:-/usr/bin/grep}"
rows(){ local n; n=$(cat "$1"/*.jsonl 2>/dev/null | "$GREP_BIN" -c . 2>/dev/null); [ -n "${n:-}" ] || n="HARNESS-ERROR"; printf '%s' "$n"; }

echo "== ① known-pair — 무엇이 행을 만들고 무엇이 안 만드나 =="

D1="$TMPROOT/pos"; mkdir -p "$D1"
( cd "$PREPREP" && FH_USAGE_LEDGER="$D1" python3 preprep.py --self-test >/dev/null 2>&1 )
[ "$(rows "$D1")" = "1" ] \
  && ok "known-positive: 옵트인 켜고 1회 실행 → 행 1 (실측 $(rows "$D1"))" \
  || ng "known-positive 실패 — 행 $(rows "$D1") · 🟥 이 레인은 UNCALIBRATED 다"

D2="$TMPROOT/neg1"; mkdir -p "$D2"
( cd "$PREPREP" && env -u FH_USAGE_LEDGER python3 preprep.py --self-test >/dev/null 2>&1 )
[ "$(rows "$D2")" = "0" ] && [ -z "$(ls -A "$D2" 2>/dev/null)" ] \
  && ok "known-negative ①: 옵트인 끄면 파일 자체가 안 생긴다(배포본 무동작)" \
  || ng "known-negative ① — 옵트인 없이 뭔가 남았다: $(ls -A "$D2" | tr '\n' ' ')"

D3="$TMPROOT/neg2"; mkdir -p "$D3"
( cd "$PREPREP" && FH_USAGE_LEDGER="$D3" python3 -c "import preprep" >/dev/null 2>&1 )
[ "$(rows "$D3")" = "0" ] \
  && ok "known-negative ②: import 만 하면 행 0 (라이브러리 사용은 실행이 아니다)" \
  || ng "known-negative ②: import 가 행을 만들었다 — 배선 지점이 __main__ 이 아니다"

echo
echo "== ② 부재는 0 이 아니다 =="
OUT=$(env -u FH_USAGE_LEDGER python3 "$REPO_ROOT/scripts/usage_report.py" --harness preprep 2>&1); RC=$?
if [ "$RC" = "9" ] && printf '%s' "$OUT" | /usr/bin/grep -q "NOT-INSTRUMENTED"; then
  ok "known-negative ③: 원장 없음 → rc=9 · NOT-INSTRUMENTED (「사용자 0 명」 아님)"
else
  ng "known-negative ③: 부재를 0 으로 렌더한다 — rc=$RC"
fi
OUT2=$(FH_USAGE_LEDGER="$D1" python3 "$REPO_ROOT/scripts/usage_report.py" --harness preprep 2>&1); RC2=$?
if [ "$RC2" = "0" ] && printf '%s' "$OUT2" | /usr/bin/grep -q "INSTRUMENTED"; then
  ok "대칭 컨트롤: 원장 있음 → rc=0 · INSTRUMENTED (부재 판정이 항상 나오는 게 아니다)"
else
  ng "대칭 컨트롤 실패 — 원장이 있는데도 부재로 읽는다 (rc=$RC2)"
fi

echo
echo "== ③ residency — 인자가 담길 «칸»이 아예 없나 =="
# 🟥 픽스처의 홈 경로는 **런타임 $HOME 으로 만든다** — 리터럴로 박으면 이 레인 파일 자신이
#    공개 표면에 절대 홈 경로를 남긴다(공개표면 스캔이 내 커밋을 막았고, 옳게 막았다).
#    런타임 조립이 더 강한 픽스처이기도 하다: 이 머신의 «진짜» 홈 경로로 시험한다.
R=$( cd "$PREPREP" && python3 - "$PREPREP" <<'PY'
import json, os, sys, tempfile, time
sys.path.insert(0, sys.argv[1]); import usage_ledger as U
ALLOWED={"v","ts","h","e","actor","author","wall_ms","cpu_ms","rc","out","llm","n"}
d=tempfile.mkdtemp(); os.environ["FH_USAGE_LEDGER"]=d
U.record("preprep", os.path.expanduser("~") + "/internal/TCKT-12345?token=abc", 1, 1, 0, "DONE")
row=json.loads(open(os.path.join(d,"preprep-"+time.strftime("%Y-%m",time.gmtime())+".jsonl")).read().strip())
blob=json.dumps(row,ensure_ascii=False)
bad=[t for t in ("internal","TCKT-12345","token",os.path.expanduser("~"),os.environ.get("USER",""),os.uname().nodename) if t and t in blob]
print("%s|%s|%s" % (",".join(sorted(set(row)-ALLOWED)) or "none", ",".join(bad) or "none", row.get("e")))
PY
)
EXTRA="${R%%|*}"; REST="${R#*|}"; LEAK="${REST%%|*}"; ENTRY="${REST##*|}"
[ "$EXTRA" = "none" ] && ok "스키마 화이트리스트: 정의 밖 키 0 (인자를 담을 칸이 없다)" \
                      || ng "스키마에 미정의 키가 있다: $EXTRA"
[ "$LEAK" = "none" ]  && ok "유출 없음: 홈 경로·내부 식별자·사용자명·호스트명 어느 것도 행에 없다" \
                      || ng "🟥 행에 남았다: $LEAK"
[ "$ENTRY" = "other" ] && ok "진입점 이름 새니타이즈: 형태 벗어난 값 → «other» (실측 «${ENTRY}»)" \
                       || ng "진입점 이름이 그대로 통과했다: «${ENTRY}»"

echo
echo "== ④ 관측이 판정을 바꾸지 않는다 =="
( cd "$PREPREP" && env -u FH_USAGE_LEDGER python3 preprep.py --self-test >/dev/null 2>&1 ); RC_OFF=$?
D4="$TMPROOT/rc"; mkdir -p "$D4"
( cd "$PREPREP" && FH_USAGE_LEDGER="$D4" python3 preprep.py --self-test >/dev/null 2>&1 ); RC_ON=$?
[ "$RC_OFF" = "$RC_ON" ] \
  && ok "종료코드 동일: 원장 off=$RC_OFF · on=$RC_ON (observe 는 판정을 통과시킨다)" \
  || ng "🟥 원장이 종료코드를 바꿨다: off=$RC_OFF on=$RC_ON — 즉시 배선을 떼라"

echo
echo "== ⑤ 두 사본이 갈리지 않았나 =="
QA_COPY="$HOME/projects/qasp-dev/scripts/usage_ledger.py"
if [ -f "$QA_COPY" ]; then
  A=$(shasum -a 256 "$PREPREP/usage_ledger.py" | awk '{print $1}')
  B=$(shasum -a 256 "$QA_COPY" | awk '{print $1}')
  [ "$A" = "$B" ] && ok "사본 동일 (sha256 ${A:0:12}…) — 관대함이 갈린 중복 정규화 없음" \
                  || ng "🟥 두 사본이 갈렸다 — ${A:0:12}… vs ${B:0:12}…"
else
  sk "qasp 사본 없음 — 이 머신에 그 레포가 없다(부재이지 통과가 아니다)"
fi

echo
echo "== ⑥ 되돌림 프로브 — 이 레인이 장식인가 =="
BK="$TMPROOT/preprep.py.bak"; cp "$PREPREP/preprep.py" "$BK"
python3 - "$PREPREP/preprep.py" <<'PY'
import io,sys
F=sys.argv[1]; s=io.open(F,encoding="utf-8").read()
OLD="sys.exit(_observe('preprep', 'cli', main) if _observe else main())"
assert s.count(OLD)==1, "되돌림 앵커 없음(%d) — 프로브가 대상을 못 찾았다" % s.count(OLD)
io.open(F,"w",encoding="utf-8").write(s.replace(OLD,"sys.exit(main())",1))
PY
if [ $? -ne 0 ]; then ng "되돌림 프로브가 배선을 못 찾았다 — 프로브 자체가 죽었다"; else
  D9="$TMPROOT/revert"; mkdir -p "$D9"
  ( cd "$PREPREP" && FH_USAGE_LEDGER="$D9" python3 preprep.py --self-test >/dev/null 2>&1 )
  [ "$(rows "$D9")" = "0" ] \
    && ok "배선을 떼니 known-positive 가 정확히 빨개진다(행 0) — 레인이 실물을 본다" \
    || ng "🟥 배선을 뗐는데도 행이 남는다($(rows "$D9")) — 이 레인은 다른 것을 보고 있다"
fi
cp "$BK" "$PREPREP/preprep.py"
CUR=$(shasum -a 256 "$PREPREP/preprep.py" | awk '{print $1}')
ORIG=$(shasum -a 256 "$BK" | awk '{print $1}')
[ "$CUR" = "$ORIG" ] && ok "복원 확인: preprep.py 원상복구" || ng "🟥 복원 실패 — 손으로 확인해라"

echo
echo "== ⑦ 계기 고장이 «0» 으로 접히지 않나 (폴백 제거의 짝) =="
# 종전 코드는 `|| true` 라 grep 이 죽어도 rc 0 이었다. 지금은 값이 안 나오면 HARNESS-ERROR 다.
HE=$(GREP_BIN=/nonexistent/grep rows "$D1")
[ "$HE" = "HARNESS-ERROR" ] \
  && ok "grep 을 죽이면 «HARNESS-ERROR» — 0 으로 접히지 않는다(실측 «${HE}»)" \
  || ng "🟥 계기가 죽었는데 «${HE}» 를 돌려준다 — 고장이 「행 0」으로 접힌다"
# 그리고 그 값이 **비교를 실패시키는지**까지 본다 — 접히지만 않고 조용하면 같은 결함이다
if [ "$HE" = "1" ] || [ "$HE" = "0" ]; then
  ng "🟥 HARNESS-ERROR 가 정상값과 구분되지 않는다"
else
  ok "그 값은 known-positive(1)·known-negative(0) 어느 비교도 통과 못 한다 — 크게 실패한다"
fi

echo
echo "== ⑧ 관측 손실이 있으면 숫자가 «하한»이 되나 (codex A-1/A-2 수리의 짝) =="
RPT="$REPO_ROOT/scripts/usage_report.py"
# 컨트롤 먼저 — 깨끗한 원장에서는 하한 표시가 «안» 나와야 한다(항상 나오면 판별력 0)
CLEAN=$(FH_USAGE_LEDGER="$D1" python3 "$RPT" --harness preprep 2>&1)
printf '%s' "$CLEAN" | /usr/bin/grep -q "관측 손실" \
  && ng "🟥 깨끗한 원장에서도 «관측 손실»이 뜬다 — 표시가 항상 켜져 있다(판별력 0)" \
  || ok "컨트롤: 깨끗한 원장 → 하한 표시 없음"

# 🟥 픽스처가 **20 행 이상**이어야 한다. 되돌림 프로브가 잡았다: 행이 적으면 수리를 되돌려도
#    p95 가 «n<20 → UNCALIBRATED» 로 어차피 초록이라, 그 레인이 «다른 이유로» 통과한다
#    (레인이 초록인 이유는 셋이고, 이건 ②「입력이 그 분기를 안 지나감」이다).
D8="$TMPROOT/broken"; mkdir -p "$D8"; cp "$D1"/.salt "$D8"/ 2>/dev/null
LF="$D8/preprep-$(date -u +%Y-%m).jsonl"
i=0; while [ $i -lt 22 ]; do
  printf '{"actor":"aa%02d","author":0,"cpu_ms":4,"e":"cli","h":"preprep","llm":null,"out":"DONE","rc":0,"ts":"%sT00:00Z","v":1,"wall_ms":%d}\n' \
    "$i" "$(date -u +%Y-%m-%d)" "$((10+i))" >> "$LF"
  i=$((i+1))
done
printf 'THIS IS NOT JSON\n' >> "$LF"
B8=$(FH_USAGE_LEDGER="$D8" python3 "$RPT" --harness preprep 2>&1)
printf '%s' "$B8" | /usr/bin/grep -q "관측 손실" \
  && ok "깨진 줄 1 주입 → «관측 손실» 선언" \
  || ng "🟥 깨진 줄이 있는데 조용하다 — 버린 관측이 작은 숫자가 된다"
printf '%s' "$B8" | /usr/bin/grep -qE "비저자 ≥|저자 ≥" \
  && ok "개수가 하한(≥)으로 렌더된다" \
  || ng "🟥 개수가 여전히 확정값처럼 찍힌다"
printf '%s' "$B8" | /usr/bin/grep -q "p95 지연   : UNCALIBRATED" \
  && ok "p95 는 아예 안 낸다(손실 표본의 분위수는 의미 없다)" \
  || ng "🟥 손실 표본에서 p95 를 냈다"

echo
echo "== ⑨ 쓰기 실패 카운터도 같은 강등을 일으키나 =="
# 🟥 여기서 «쓰기 실패 3» 을 grep 하면 안 된다 — 그 문구는 커버리지 줄이라 수리 전에도 있었다.
#    되돌림 프로브가 그걸 잡았다(수리를 되돌려도 초록). 봐야 할 것은 **강등이 실제로 걸렸나**다.
D9E="$TMPROOT/errs"; mkdir -p "$D9E"; cp "$D1"/.salt "$D9E"/ 2>/dev/null
i=0; LF9="$D9E/preprep-$(date -u +%Y-%m).jsonl"
while [ $i -lt 22 ]; do
  printf '{"actor":"bb%02d","author":0,"cpu_ms":4,"e":"cli","h":"preprep","llm":null,"out":"DONE","rc":0,"ts":"%sT00:00Z","v":1,"wall_ms":%d}\n' \
    "$i" "$(date -u +%Y-%m-%d)" "$((10+i))" >> "$LF9"
  i=$((i+1))
done
printf '3' > "$D9E/.errors"
E9=$(FH_USAGE_LEDGER="$D9E" python3 "$RPT" --harness preprep 2>&1)
printf '%s' "$E9" | /usr/bin/grep -q "관측 손실" \
  && ok ".errors=3 (깨진 줄 0) → 강등이 걸린다" \
  || ng "🟥 쓰기 실패를 알고도 숫자를 확정값으로 낸다"
printf '%s' "$E9" | /usr/bin/grep -q "p95 지연   : UNCALIBRATED — 관측 손실" \
  && ok "그 표본(n=22)에서도 p95 를 «관측 손실» 사유로 거른다" \
  || ng "🟥 n≥20 인데 손실 표본의 p95 를 냈다"

echo
echo "== ⑩ 막히는 파일이 호스트를 멈춰 세우나 (codex B-3 수리의 짝) =="
DF="$TMPROOT/fifo"; mkdir -p "$DF"; mkfifo "$DF/.salt" 2>/dev/null
if [ -p "$DF/.salt" ]; then
  START=$(date +%s)
  ( cd "$PREPREP" && FH_USAGE_LEDGER="$DF" timeout 20 python3 preprep.py --self-test >/dev/null 2>&1 ); RC_F=$?
  EL=$(( $(date +%s) - START ))
  [ "$RC_F" = "0" ] && [ "$EL" -lt 15 ] \
    && ok "«.salt 가 FIFO» 인데 ${EL}s 에 rc=0 으로 끝난다 — 관측이 호스트를 안 멈춘다" \
    || ng "🟥 rc=$RC_F · ${EL}s — 관측이 호스트의 타이밍/종료를 바꿨다(124=timeout)"
  [ "$(rows "$DF")" = "0" ] && ok "그 실행은 행을 안 남긴다(fail-closed — 조용한 성공 아님)" \
                           || ng "🟥 막힌 경로인데 행이 남았다"
  [ -s "$DF/.errors" ] && ok "실패가 .errors 에 세어졌다(값 $(cat "$DF/.errors")) — 안 막지만 안 조용하다" \
                       || ng "🟥 실패가 아무 데도 안 세어졌다 — 조용한 0 이다"
else
  ng "mkfifo 실패 — 이 레인을 못 돌렸다(부재이지 통과가 아니다)"
fi

echo
echo "== ⑪ «비저자 0» 분기도 강등되나 (codex R2 가 이름 댄, 레인이 안 밟던 자리) =="
# 🟥 ⑧⑨ 의 픽스처는 비저자 22 행이라 이 분기를 **구조적으로 못 밟았다**. 저자 행만 + 깨진 줄.
D11="$TMPROOT/zero"; mkdir -p "$D11"; cp "$D1"/.salt "$D11"/ 2>/dev/null
LF11="$D11/preprep-$(date -u +%Y-%m).jsonl"
printf '{"actor":"zz01","author":1,"cpu_ms":4,"e":"cli","h":"preprep","llm":null,"out":"DONE","rc":0,"ts":"%sT00:00Z","v":1,"wall_ms":11}\n' "$(date -u +%Y-%m-%d)" > "$LF11"
# 컨트롤: 손실 없음 → «미관측» 문구(확정)가 맞다
Z0=$(FH_USAGE_LEDGER="$D11" python3 "$RPT" --harness preprep 2>&1)
printf '%s' "$Z0" | /usr/bin/grep -q "비저자 사용 \*\*미관측\*\*" \
  && ok "컨트롤: 손실 없이 비저자 0 → 「미관측」(모른다 아님)" \
  || ng "컨트롤이 깨졌다 — 손실 없는 0 도 「모른다」로 찍는다(항상 강등 = 판별력 0)"
printf 'NOT JSON\n' >> "$LF11"
Z1=$(FH_USAGE_LEDGER="$D11" python3 "$RPT" --harness preprep 2>&1)
# 🟥 바늘을 «모른다» 로 잡으면 안 된다 — 그 낱말은 ② 재사용률 줄에도 있어서 **다른 줄을 문다**.
#    되돌림 프로브(적용 확인 포함)가 그걸 잡았다: ① 을 죽였는데 레인이 초록이었다.
printf '%s' "$Z1" | /usr/bin/grep -qE "① 사용자 +: 🟥 \*\*모른다\*\*" \
  && ok "깨진 줄 추가 → ① 이 확정값에서 「모른다」로 바뀐다" \
  || ng "🟥 비저자 0 분기가 손실을 무시하고 확정값을 낸다(codex A-1/A-2 잔여)"
printf '%s' "$Z1" | /usr/bin/grep -q "비저자 표본 ≥0" \
  && ok "재사용률도 같은 분기에서 강등된다" \
  || ng "🟥 재사용률이 「표본 0」을 확정값으로 낸다"

echo
echo "════════════════════════════════════════"
printf '  PASS %s   FAIL %s   SKIP %s\n' "$PASS" "$FAIL" "$SKIP"
echo "  ⚠️ SKIP 은 통과가 아니다."
echo "════════════════════════════════════════"
[ "$FAIL" -eq 0 ] || exit 1

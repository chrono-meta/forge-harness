#!/usr/bin/env bash
# test_preprep_font_lanes.sh — preprep L15(서체 일관성)의 계약을 고정한다.
#
# WHY: 발표 템플릿을 주는 조직은 거의 항상 서체를 규정하는데, 서체 이탈은 **렌더링에서만**
# 드러나 사람이 눈으로 훑기 전에는 안 보인다. preprep 의 이웃 레인들은 배치(P1/P3)와 말의
# 정합(L1·L5·L8·R1~R5)을 보지, 「무슨 서체로 찍혔나」는 어느 레인도 안 봤다.
#
# 🟥 이 레인이 증명해야 하는 것은 «이탈을 잡는다»가 아니라 **«상속분을 안 잡는다»** 다.
#    실측(2026-09-11, 조직 배포 템플릿 기반 발표 덱 120장): 순진하게 세면 `Helvetica Neue`
#    **85건**이 «위반»으로 나오는데, 그 85건은 전부 `slideMasters/` 안에 있고 **배포 템플릿의
#    마스터에도 정확히 같은 85건**이 있다(해시 동일). 저자는 그 글자를 찍은 적이 없다.
#    진짜 이탈은 하나뿐이었고 그건 의도였다(코드 데모의 고정폭 서체).
#    ⇒ known-negative 를 «서체 하나뿐인 덱»으로 두면 그 오탐을 **구조적으로 못 잡는다.**
#      그래서 K1 은 «마스터에 이질 서체가 있지만 템플릿과 동일한 덱» 이다.
#
# 종료코드: 0 pass · 1 레인 실패 · 2 대상 부재 · 10 setup 실패
set -uo pipefail
cd "$(dirname "$0")/.." || exit 10
LANE=plugins/fh-commons/skills/preprep/lane_font.py
SELFTEST=plugins/fh-commons/skills/preprep/test_lane_font.py
PROBE=plugins/fh-commons/skills/preprep/fixtures/font_revert_probe.py
[ -f "$LANE" ] || { echo "ⓘ $LANE absent — subject missing (NOT a pass)"; exit 2; }
[ -f "$SELFTEST" ] || { echo "ⓘ $SELFTEST absent — subject missing (NOT a pass)"; exit 2; }
[ -f "$PROBE" ] || { echo "ⓘ $PROBE absent — subject missing (NOT a pass)"; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "ⓘ python3 absent — setup broke"; exit 10; }
# 🟥 스테일 바이트코드가 뮤턴트/복원을 가린다 — 이웃 레인이 실측한 사고다(2026-09-06).
rm -rf plugins/fh-commons/skills/preprep/__pycache__
PASS=0; FAIL=0
ok(){ echo "  ✅ $1"; PASS=$((PASS+1)); }
ng(){ echo "  ❌ $1"; FAIL=$((FAIL+1)); }

echo "== K1~K13 known-pair (레인 자체 self-test) =="
OUT=$(python3 "$SELFTEST" 2>&1); RC=$?
echo "$OUT" | sed 's/^/  /'
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q 'FAIL 0'; then
  ok "self-test 전항 통과 (rc=$RC)"
elif [ "$RC" -eq 2 ]; then
  echo "  ⏭  픽스처 생성 불가 — UNMEASURED (통과 아님)"; FAIL=$((FAIL+1))
else
  ng "self-test 실패 (rc=$RC)"
fi

echo "== 배선·퇴화 — self-test 밖에서 한 번 더 =="
OUT=$(python3 -c "
import sys; sys.path.insert(0,'plugins/fh-commons/skills/preprep')
import lane_font as L
print(L.scan({}, '.')[1][0])
print(L.scan({'surfaces_by_id':{'built_deck':{'path':'/nope/none.pptx'}}}, '.')[1][0])
" 2>&1)
echo "$OUT" | grep -q 'NOT_CONFIGURED' && echo "$OUT" | grep -q 'UNMEASURED' \
  && ok "미선언 → NOT_CONFIGURED · 실물 없음 → UNMEASURED (둘 다 0 아님)" \
  || ng "퇴화 표기가 0 으로 접힌다: $OUT"

grep -q "import lane_font" plugins/fh-commons/skills/preprep/preprep.py \
  && ok "배선: preprep.py 가 이 레인을 부른다" \
  || ng "배선 없음 — 정의만 있고 아무도 안 부른다(built-but-not-wired)"

grep -q "lane_font" plugins/fh-commons/skills/preprep/SKILL.md \
  && ok "명세: SKILL.md 가 이 레인을 적는다(고아 구현 아님)" \
  || ng "SKILL.md 에 없다 — 명세 없는 구현"

# 🟥 이 프로브가 «template 미선언» 조건에서 도는 이유는 프로브 파일 머리에 적혀 있다. 요약:
#    한때 방어가 둘이었고(영역 분리 · 템플릿-자체-서체 강등) 해시 동일 부품에서는 ②가 ①을
#    완전히 덮어, 둘 다 켠 채 ①만 죽이면 «분리가 장식»이라는 **거짓 판정**이 났다.
#    그 뒤 ②는 cross-family 2라운드에서 **fail-open 으로 판정돼 걷혔다**(억제 → 맥락 주석).
#    지금 방어는 ① 하나뿐이고, 이 조건이 그 하나를 정확히 겨눈다.
echo "== 되돌림 — 영역 분리를 죽이면 오탐이 돌아오는가 (template 미선언 = 방어 하나) =="
OUT=$(python3 "$PROBE" separation 2>&1)
if echo "$OUT" | grep -q 'BASE 0' && echo "$OUT" | grep -qE 'MUT [1-9]'; then
  ok "되돌림: 분리를 죽이면 마스터 상속 서체가 오탐으로 돌아온다 ($OUT) — 분리가 하중을 진다"
else
  ng "되돌림 실패 — 분리를 죽여도 결과가 같다(그 분기가 장식이다): $OUT"
fi

# 🟥 «템플릿도 쓰는 이름» 을 노트로 **억제**하면 fail-open 이다 — 2라운드가 그렇게 지목해서
#    억제를 걷어내고 맥락 주석만 남겼다. 이 레인이 그 되돌림을 고정한다.
echo "== 템플릿도 쓰는 이름이 억제되지 않고 finding 으로 남는가 =="
OUT=$(python3 "$PROBE" annotation 2>&1)
if echo "$OUT" | grep -qE 'FINDING [1-9]' && echo "$OUT" | grep -qE 'ANNOTATED [1-9]'; then
  ok "억제 아님: finding 은 남고 맥락 주석만 붙는다 ($OUT)"
else
  ng "억제로 되돌아갔다 — 저자가 그 이름으로 본문을 찍어도 종료코드가 안 움직인다: $OUT"
fi

echo "── preprep font lanes: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0

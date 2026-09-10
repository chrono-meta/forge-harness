#!/usr/bin/env bash
# test_preprep_drift_anchor.sh — 이원화의 단일-소스 앵커.
#
# preprep 은 두 진입점을 갖는다: FH 안의 스킬(plugins/fh-commons/skills/preprep/)과,
# 거기서 뽑아 세우는 standalone 현장 하네스. 🟥 **코드 사본이 둘이면 갈린다** —
# FH 자신의 규칙이 그것을 «single source of truth collapse · double maintenance burden»
# 이라 부른다. 그래서 이원화는 «복사본 둘»이 아니라 «단일 소스 + 얇은 두 진입점»이어야 하고,
# 이 앵커가 그 «단일»을 기계로 지킨다.
#
# 재는 것:
#   D1 단일 소스가 실재하고 실행 가능한가 (부재를 통과로 렌더하지 않는다)
#   D2 standalone 배포본이 있다면, 그 코드가 단일 소스와 «바이트 동일»한가
#      — 없으면 SKIP 이고 SKIP 은 PASS 가 아니다. 있는데 다르면 FAIL
#   D3 진입점 문서가 단일 소스를 가리키나 (죽은 포인터 금지)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$HERE/plugins/fh-commons/skills/preprep"
# standalone 배포 위치는 환경변수로 받는다. 기본값을 박으면 다른 머신에서 거짓 SKIP 이 된다.
# 🟥 2026-09-03 — 그런데 «아무도 그 변수를 안 걸어서» D2 가 여태 SKIP 이었고, 그 사이 컴패니언
#    저장소의 fork(724줄)가 정본(789줄)과 갈라져 L9~L11 을 안 부르고 있었다 — 정본 주석이 이미
#    한 번 적어 둔 사고의 2회째(fh_signal_2026-09-03_preprep-standalone-anchor-skip.md). 슬롯은
#    있고 소비처가 0 인 형태. 처방: 명시 변수가 없으면 운영자 로컬 바인딩이 이미 export 하는
#    FH_COMPANION_STORE 아래 preprep/ 을 «자동 후보»로 쓴다 — 기본값을 박는 게 아니라 이미
#    선언된 경로를 읽는 것이라 다른 머신에서 거짓 SKIP 을 만들지 않는다(없으면 여전히 SKIP).
DIST="${PREPREP_STANDALONE_DIR:-}"; DIST_SRC="PREPREP_STANDALONE_DIR"
if [ -z "$DIST" ] && [ -n "${FH_COMPANION_STORE:-}" ] && [ -d "${FH_COMPANION_STORE}/preprep" ]; then
  DIST="${FH_COMPANION_STORE}/preprep"; DIST_SRC="FH_COMPANION_STORE/preprep (자동 후보)"
fi
PASS=0; FAIL=0; SKIP=0
ok(){ echo "  ✅ $1"; PASS=$((PASS+1)); }
ng(){ echo "  ❌ $1"; FAIL=$((FAIL+1)); }
sk(){ echo "  ⏭  $1 — SKIPPED (**통과 아님**)"; SKIP=$((SKIP+1)); }

# D1 — 단일 소스
# 🟥 2026-09-10 정정: 파일 목록을 **박아 두지 않는다.** 박아 둔 목록은 조용히 낡는다 —
#    이 검사는 「10파일 · python 7파일」이라고 출력하면서 그 사이 늘어난 레인 셋
#    (lane_slide_relations · lane_geometry · lane_slide_refs)을 **한 번도 안 봤다.**
#    개수는 참이었고 «무엇에 대한 개수인가»가 어긋난 형태다
#    ([[feedback_count_is_true_but_referent_drifted]]).
#    ⇒ 필수 문서만 이름으로 걸고, **python 은 디렉터리에서 뽑는다** — 레인을 새로 지으면
#      자동으로 이 앵커 안에 들어온다. 배선을 잊는 것으로 검사를 벗어날 수 없다.
missing=""
for f in SKILL.md README.md surfaces.example.yaml preprep.py; do
  [ -f "$SRC/$f" ] || missing="$missing $f"
done
PYN=0
for f in "$SRC"/*.py; do [ -f "$f" ] && PYN=$((PYN+1)); done
if [ -n "$missing" ]; then ng "D1 단일 소스 결손:$missing"
elif [ "$PYN" -lt 5 ]; then
  ng "D1 python 파일이 $PYN 개뿐 — 스킬이 헐었거나 SRC 가 틀린 곳을 가리킨다"
elif ! command -v python3 >/dev/null 2>&1; then
  sk "D1 구문 검사 — python3 부재라 «돌 수 있나»를 못 쟀다(UNMEASURED)"
else
  synerr=""
  for f in "$SRC"/*.py; do
    python3 -c "import ast,sys;ast.parse(open(sys.argv[1],encoding='utf-8').read())" "$f" 2>/dev/null \
      || synerr="$synerr $(basename "$f")"
  done
  [ -z "$synerr" ] && ok "D1 필수 문서 3 + preprep.py 실재 · python ${PYN}파일 전부 구문 통과(디렉터리에서 뽑음)" \
                   || ng "D1 구문 실패:$synerr"
fi

# D2 — standalone 대조
if [ -z "$DIST" ]; then
  sk "D2 standalone 대조 — PREPREP_STANDALONE_DIR 미설정이고 FH_COMPANION_STORE/preprep 도 없어 배포본을 못 찾았다. UNCHECKED — 배포본이 있는 머신이면 둘 중 하나를 export 해라"
elif [ ! -d "$DIST" ]; then
  ng "D2 $DIST_SRC 이 가리키는 곳이 없다: $DIST (설정됐는데 부재 = 드리프트 아니라 배선 결함)"
else
  # 🟥 같은 정정 — 여기도 목록이 박혀 있었고, 게다가 **네 개를 돌면서 「5파일」이라고 출력**했다.
  #    라벨이 자기 루프에 대해서도 거짓말한 셈이라, 세는 것과 말하는 것을 한 변수로 묶는다.
  drift=""; n=0
  for f in "$SRC"/*.py; do
    b=$(basename "$f"); n=$((n+1))
    if [ ! -f "$DIST/$b" ]; then drift="$drift $b(부재)"
    elif ! cmp -s "$f" "$DIST/$b"; then drift="$drift $b(갈림)"; fi
  done
  [ -z "$drift" ] && ok "D2 standalone python ${n}파일이 단일 소스와 바이트 동일 ($DIST_SRC)" \
                  || ng "D2 드리프트($n 중):$drift ⇒ 사본이 둘이 됐다. 단일 소스에서 다시 뽑아라"
fi

# D3 — 진입점 포인터가 죽었나
if grep -q "ko-tech-writer" "$SRC/SKILL.md" 2>/dev/null; then
  if [ -f "$HERE/plugins/fh-commons/skills/ko-tech-writer/SKILL.md" ]; then
    ok "D3 SKILL.md 가 가리키는 ko-tech-writer 가 실재"
  else ng "D3 죽은 포인터 — SKILL.md 가 ko-tech-writer 를 가리키는데 그 스킬이 없다"; fi
else ng "D3 SKILL.md 가 ko-tech-writer 라우팅을 잃었다 — L9 는 절반만 덮는데 나머지 절반의 출구가 사라졌다"; fi

echo "preprep drift anchor: $PASS passed, $FAIL failed, $SKIP skipped (skip != pass)"
[ "$FAIL" -eq 0 ] || exit 1

#!/usr/bin/env bash
# test_map_postprocess_lanes.sh — scripts/map_postprocess.py 의 세 계약을 고정한다.
#
# WHY: 이 후처리는 발행되는 지도 HTML 의 «폭 하한»을 바꾸고 SVG 를 다시 만든다. 둘 다 조용히
# 실패하면 사람이 못 본다 — 패치가 안 붙어도 페이지는 뜨고(옛 폭), SVG 가 어긋나도 열리기는 한다.
# 그래서 ⓐ 리터럴 부재 = 드리프트 = 하드 정지(3), ⓑ SVG 는 «커밋된 두 장 바이트 동일 재현»을
# known-pair 로 잡는다. 컨트롤: 패치 문자열이 실제로 상수와 다르고 뷰포트를 참조하는가.
#
# ⓒ **깜빡임 억제 계약**(L10~L15 — L13b 포함 7 레인, 2026-09-21): 첫 페인트 전 테마 해소와 «게이트 없이 뛰는
# 펄스 없음» 둘이 재생성본에 아직 있나. 이 둘은 라이트 모드에서 **첫 프레임**에만 보이는 것이라
# 빠지면 아무 검사도 안 빨개지고, 다음에 사람이 눈을 댈 때까지 아무도 모른다.
# 🟥 레인은 «기록의 형태»만 잰다 — 실제로 안 깜빡이는지는 사람이 실물로 본다.
#
# 종료코드: 0 pass · 1 레인 실패 · 2 대상 부재 · 10 setup 실패
set -uo pipefail
cd "$(dirname "$0")/.." || exit 10
S=scripts/map_postprocess.py
PASS=0; FAIL=0
ok() { echo "✅ $1"; PASS=$((PASS+1)); }
ng() { echo "❌ $1"; FAIL=$((FAIL+1)); }

[ -f "$S" ] || { echo "ⓘ $S absent — subject missing when we looked (NOT a pass)"; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "ⓘ python3 absent — setup broke (NOT a pass)"; exit 10; }

TMP=$(mktemp -d) || exit 10
trap 'rm -rf "$TMP"' EXIT

# $1=out path · $2=reader-width literal(비어도 됨) · $3=두 번째 <style> 여부
# $4=깜빡임 계약 변형(기본 = 준수). 준수형을 기본값으로 둔 것이 L1·L2·L6·L8 의 known-positive 다.
mkfix() {
  THEME_SCRIPT='<script>document.documentElement.setAttribute("data-theme", theme);</script>'
  PULSE='.pulse-dot{animation: none;} html[data-motion-capable="true"] .pulse-dot{animation: pulse 2s infinite;}'
  HTMLTAG='<html data-theme="dark">'
  HEAD_PRE="$THEME_SCRIPT"; BODY_PRE=''
  case "${4:-}" in
    late-theme)     HEAD_PRE=''; BODY_PRE="$THEME_SCRIPT" ;;   # <body> 가 시작된 뒤에야 해소
    no-theme-apply) HEAD_PRE='' ;;
    ungated-pulse)  PULSE='.pulse-dot{animation: pulse 2s infinite;}' ;;
    renamed-gate)   PULSE='.pulse-dot{animation: none;} html[data-motion-ready="true"] .pulse-dot{animation: pulse 2s infinite;}' ;;
    mixed-list)     PULSE='html[data-motion-capable="true"] .pulse-dot, .pulse-dot{animation: pulse 2s infinite;}' ;;
    no-contract)    HTMLTAG='<html>'; HEAD_PRE=''; PULSE='.c{color:green}' ;;
  esac
  {
    printf '%s<head>%s<style>.a{color:red} %s</style>' "$HTMLTAG" "$HEAD_PRE" "$PULSE"
    [ -n "${3:-}" ] && printf '<style>.b{color:blue}</style>'
    printf '</head><body>%s' "$BODY_PRE"
    printf '<svg viewBox="0 0 10 10"><rect/></svg>'
    printf '<script>%s</script></body></html>' "$2"
  } > "$1"
}

# ── L1 known-positive: 상수가 있으면 패치되고 SVG 가 나온다
mkfix "$TMP/pos.html" 'var MIN_READER_WIDTH = 960;' ''
python3 "$S" "$TMP/pos.html" >"$TMP/o1" 2>&1; RC=$?
if [ $RC -eq 0 ] && /usr/bin/grep -q 'window.innerWidth' "$TMP/pos.html" && [ -f "$TMP/pos.svg" ]; then
  ok "L1 known-positive: patched + svg written (rc=0)"
else
  ng "L1 known-positive failed (rc=$RC): $(head -2 "$TMP/o1" | tr '\n' ' ')"
fi

# ── L2 멱등: 두 번째 실행은 SKIP 이고 여전히 rc=0
python3 "$S" "$TMP/pos.html" >"$TMP/o2" 2>&1; RC=$?
if [ $RC -eq 0 ] && /usr/bin/grep -q 'SKIP' "$TMP/o2"; then
  ok "L2 idempotent re-run reports SKIP (rc=0)"
else
  ng "L2 idempotency broken (rc=$RC): $(head -2 "$TMP/o2" | tr '\n' ' ')"
fi

# ── L3 known-negative(드리프트): 리터럴이 아예 없으면 rc=3 이고 파일을 안 건드린다
mkfix "$TMP/drift.html" 'var SOMETHING_ELSE = 1;' ''
BEFORE=$(shasum "$TMP/drift.html" | awk '{print $1}')
python3 "$S" "$TMP/drift.html" >"$TMP/o3" 2>&1; RC=$?
AFTER=$(shasum "$TMP/drift.html" | awk '{print $1}')
if [ $RC -eq 3 ] && [ "$BEFORE" = "$AFTER" ] && [ ! -f "$TMP/drift.svg" ]; then
  ok "L3 drift → rc=3, file untouched, no svg (fail-closed)"
else
  ng "L3 drift not fail-closed (rc=$RC, sha changed=$([ "$BEFORE" = "$AFTER" ] && echo no || echo yes))"
fi

# ── L4 컨트롤: 패치 문자열이 상수와 실제로 다르고 뷰포트를 참조하는가
#    (같은 값으로 «치환»하면 L1 도 통과한다 — 그 자멸을 막는 자리)
OLDLIT=$(python3 -c "import re;s=open('$S',encoding='utf-8').read();print(re.search(r\"^OLD = '(.*)'\",s,re.M).group(1))")
NEWLIT=$(python3 -c "
import re
s=open('$S',encoding='utf-8').read()
m=re.search(r\"NEW = \((.*?)\)\n\", s, re.S)
print(''.join(re.findall(r\"'([^']*)'\", m.group(1))))")
if [ -n "$OLDLIT" ] && [ -n "$NEWLIT" ] && [ "$OLDLIT" != "$NEWLIT" ] && \
   printf '%s' "$NEWLIT" | /usr/bin/grep -q 'innerWidth'; then
  ok "L4 control: replacement differs from the constant and reads the viewport"
else
  ng "L4 control: replacement is vacuous (old='$OLDLIT' new='$NEWLIT')"
fi

# ── L5 known-pair: 커밋된 지도 두 장을 HTML 에서 바이트 동일하게 재현하는가
#    (SVG 는 <style>+<svg> 만 담아 뷰어 JS 를 안 싣는다 — 그래서 폭 패치와 무관하게 안정적인 짝이다)
PAIR_OK=1; PAIR_RAN=0
for base in docs/map/fh_trust.dataflow docs/map/fh_assets.architecture; do
  [ -f "$base.html" ] && [ -f "$base.svg" ] || continue
  PAIR_RAN=$((PAIR_RAN+1))
  python3 - "$S" "$base.html" "$base.svg" <<'PY' || PAIR_OK=0
import importlib.util, sys
spec = importlib.util.spec_from_file_location('mp', sys.argv[1])
mp = importlib.util.module_from_spec(spec); spec.loader.exec_module(mp)
built = mp.build_svg(open(sys.argv[2], encoding='utf-8').read())
cur = open(sys.argv[3], encoding='utf-8').read()
if built != cur:
    print(f'   ✗ {sys.argv[3]}: rebuilt {len(built)}B != committed {len(cur)}B')
    sys.exit(1)
PY
done
if [ "$PAIR_RAN" -eq 0 ]; then
  ng "L5 known-pair: 0 pairs found — instrument had nothing to measure (NOT a pass)"
elif [ "$PAIR_OK" -eq 1 ]; then
  ok "L5 known-pair: $PAIR_RAN committed svg(s) reproduced byte-for-byte from html"
else
  ng "L5 known-pair: rebuilt svg differs from the committed one"
fi

# ── L6 <style> 블록이 둘이면 추출기는 멈춘다(조용히 첫 장만 싣지 않는다)
mkfix "$TMP/two.html" 'var MIN_READER_WIDTH = 960;' 'extra'
python3 "$S" "$TMP/two.html" >"$TMP/o6" 2>&1; RC=$?
if [ $RC -eq 3 ] && [ ! -f "$TMP/two.svg" ]; then
  ok "L6 two <style> blocks → rc=3, no svg written"
else
  ng "L6 two <style> blocks not rejected (rc=$RC)"
fi

# ── L7 없는 파일 → rc=4 (인자 오류와 드리프트를 섞지 않는다)
python3 "$S" "$TMP/nope.html" >"$TMP/o7" 2>&1; RC=$?
[ $RC -eq 4 ] && ok "L7 missing file → rc=4 (distinct from drift rc=3)" || ng "L7 missing file rc=$RC (expected 4)"

# ── L8 --check 는 쓰지 않는다
mkfix "$TMP/chk.html" 'var MIN_READER_WIDTH = 960;' ''
B=$(shasum "$TMP/chk.html" | awk '{print $1}')
python3 "$S" --check "$TMP/chk.html" >"$TMP/o8" 2>&1; RC=$?
A=$(shasum "$TMP/chk.html" | awk '{print $1}')
if [ $RC -eq 0 ] && [ "$B" = "$A" ] && /usr/bin/grep -q 'UNPATCHED' "$TMP/o8" && [ ! -f "$TMP/chk.svg" ]; then
  ok "L8 --check reports without writing"
else
  ng "L8 --check wrote or misreported (rc=$RC)"
fi

# ── L9 발행본이 실제로 패치된 상태인가 (배선 확인 — 스크립트가 있는데 안 돌린 경우를 잡는다)
SHIPPED_OK=1; SHIPPED_N=0
for f in docs/map/*.html; do
  [ -f "$f" ] || continue
  case "$f" in *.visual-check.html) continue;; esac
  SHIPPED_N=$((SHIPPED_N+1))
  python3 "$S" --check "$f" 2>/dev/null | /usr/bin/grep -q '^PATCHED' || { SHIPPED_OK=0; echo "   ✗ $f not patched"; }
done
if [ "$SHIPPED_N" -eq 0 ]; then
  ng "L9 no docs/map/*.html found — nothing measured (NOT a pass)"
elif [ "$SHIPPED_OK" -eq 1 ]; then
  ok "L9 all $SHIPPED_N shipped map html carry the patched reader-width floor"
else
  ng "L9 a shipped map html is unpatched — re-run: python3 $S docs/map/*.html"
fi

# ── L10~L13 되돌림 프로브: 깜빡임 억제를 한 조각씩 빼면 rc=3 이고 아무것도 안 쓴다
#    (L1 이 같은 픽스처의 «준수형»으로 초록이므로, 이 넷은 계약이 하중을 진다는 증거다)
probe_drift() {  # $1=레인 이름 · $2=변형 키 · $3=한 줄 설명
  mkfix "$TMP/$2.html" 'var MIN_READER_WIDTH = 960;' '' "$2"
  B=$(shasum "$TMP/$2.html" | awk '{print $1}')
  python3 "$S" "$TMP/$2.html" >"$TMP/o_$2" 2>&1; RC=$?
  A=$(shasum "$TMP/$2.html" | awk '{print $1}')
  if [ $RC -eq 3 ] && [ "$B" = "$A" ] && [ ! -f "$TMP/$2.svg" ]; then
    ok "$1 $3 -> rc=3, file untouched, no svg"
  else
    ng "$1 $3 not caught (rc=$RC, sha changed=$([ "$B" = "$A" ] && echo no || echo yes))"
  fi
}
probe_drift L10 late-theme     "theme resolved only after <body> starts"
probe_drift L11 no-theme-apply "<html data-theme> declared but never applied"
probe_drift L12 ungated-pulse  "pulse runs with no data-motion-capable gate"
probe_drift L13 renamed-gate   "gate attribute renamed - pulse runs ungated"
# L13b 는 내가 초판에서 실제로 열어 둔 구멍이다 — 한 셀렉터 목록 안에 게이트 있는 조각과
# 없는 조각이 같이 있으면, «첫 조각만 보는» 판독은 통과시킨다. 조각을 전부 본다.
probe_drift L13b mixed-list   "one selector list mixes a gated and a bare .pulse-dot"

# ── L14 과차단 금지: 계약 대상이 아예 없는 문서(테마 선언 없음 · 점 없음)는 통과한다
#    없는 것을 요구하면 다른 archify 다이어그램 종류를 막고, 과차단은 override 를 훈련시킨다
mkfix "$TMP/nc.html" 'var MIN_READER_WIDTH = 960;' '' no-contract
python3 "$S" "$TMP/nc.html" >"$TMP/o14" 2>&1; RC=$?
if [ $RC -eq 0 ] && [ -f "$TMP/nc.svg" ]; then
  ok "L14 no theme declaration and no pulse rule -> contract N/A, passes (no over-block)"
else
  ng "L14 over-blocked a document with nothing to suppress (rc=$RC)"
fi

# ── L15 실물 되돌림: 픽스처가 아니라 **발행되는 지도 한 장**에서 한 줄을 빼도 빨개지는가
#    (픽스처만으로는 «내가 만든 모양만 잰다» 를 못 벗어난다 — 계기≠대상)
REAL=docs/map/fh_process.workflow.html
if [ ! -f "$REAL" ]; then
  ng "L15 $REAL absent - nothing measured (NOT a pass)"
else
  python3 - "$REAL" "$TMP/real_cut.html" <<'REALCUT'
import sys
s = open(sys.argv[1], encoding='utf-8').read()
cut = s.replace("document.documentElement.setAttribute('data-theme', theme);", '', 1)
if cut == s:
    sys.exit(9)          # 리터럴이 없다 = 잘라낼 것이 없다 = 계기 고장
open(sys.argv[2], 'w', encoding='utf-8').write(cut)
REALCUT
  SETUP=$?
  if [ $SETUP -eq 0 ]; then
    python3 "$S" --check "$TMP/real_cut.html" >"$TMP/o15" 2>&1; RC=$?
    python3 "$S" --check "$REAL" >"$TMP/o15c" 2>&1; RCC=$?
    if [ $RC -eq 3 ] && [ $RCC -eq 0 ]; then
      ok "L15 real shipped map: pre-paint theme line removed -> rc=3 (control: intact -> rc=0)"
    else
      ng "L15 real shipped map: cut=$RC (expected 3), control=$RCC (expected 0)"
    fi
  elif [ $SETUP -eq 9 ]; then
    ng "L15 the pre-paint theme line is already gone from $REAL - instrument had nothing to cut"
  else
    ng "L15 setup failed while mutating $REAL (rc=$SETUP)"
  fi
fi

echo "── map_postprocess lanes: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0

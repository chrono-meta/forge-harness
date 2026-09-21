#!/usr/bin/env bash
# test_map_flash_render_lanes.sh — scripts/map_flash_render_probe.js 를 고정한다.
#
# WHY: `test_map_postprocess_lanes.sh` 의 L10~L15 는 억제 코드가 **문서에 있나**를 본다.
# 있는데도 실제로 깜빡일 수 있고, 그 한 칸은 «사람이 실물로 본다»로 남아 있었다. 이 레인이
# 그 자리를 렌더로 메운다 — 첫 페인트 프레임과 헤더 점의 픽셀을 직접 잰다.
#
# 🟥 대체가 아니라 **한 칸 메움**이다. 헤드리스 합성기는 사람의 화면이 아니고, 이 레인은
# 폰트 적재·GPU 합성·주사율·색 관리를 못 본다. 실측 분리폭(6 vs 244)은 크지만 그 축에서만 크다.
#
# 🟥 **브라우저가 없으면 «안 쟀다»이지 «통과»가 아니다 — 그런데 rc 는 0 이다.** 둘이 어긋나
# 보이는 것을 이름으로 적어 둔다: 레인 스위트는 **되돌릴 수 있는 표면**이라 도구 부재는
# 차단이 아니라 advisory 로 떨어뜨리는 것이 정본이고(CLAUDE.md §Irreversibility Gates —
# «not-blocking 과 not-silent 은 다른 성질이고, 되돌릴 수 있는 커밋 표면에서 의무인 것은 둘째»),
# 대부분의 설치본에 없는 런타임을 요구해 빨갛게 만들면 그 빨강이 정확히 override 를 훈련시킨다.
# 그래서 **안 쟀다는 사실은 반드시 `NOT MEASURED` 한 줄로 크게 남긴다** — 조용한 통과는 아니다.
# 🟥 그 대신 rc=2 는 «이 스위트의 주체가 사라졌다»(깨진 설치) 하나만 가리킨다.
#
# 종료코드: 0 pass 또는 NOT MEASURED(런타임/대상 부재) · 1 레인 실패 · 2 주체 부재 · 10 setup 실패
set -uo pipefail
cd "$(dirname "$0")/.." || exit 10
P=scripts/map_flash_render_probe.js
PASS=0; FAIL=0
ok() { echo "✅ $1"; PASS=$((PASS+1)); }
ng() { echo "❌ $1"; FAIL=$((FAIL+1)); }

[ -f "$P" ] || { echo "ⓘ $P absent — subject missing when we looked (NOT a pass)"; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "ⓘ python3 absent — setup broke (NOT a pass)"; exit 10; }
ls docs/map/*.html >/dev/null 2>&1 || {
  echo "NOT MEASURED  no docs/map/*.html here — the maps are deliberately unshipped, so a consumer"
  echo "              tree has nothing to render. Nothing was measured; nothing failed."; exit 0; }
command -v node >/dev/null 2>&1 || {
  echo "NOT MEASURED  node absent — the render probe cannot run on this machine."
  echo "              Run it where a browser lives; this run proves nothing about the maps."; exit 0; }
node -e "
for (const id of ['playwright','playwright-core','/opt/node22/lib/node_modules/playwright']) {
  try { require(id); process.exit(0); } catch (_) {}
}
process.exit(1)" 2>/dev/null || {
  echo "NOT MEASURED  playwright absent — the render probe cannot run on this machine."
  echo "              Install it (npm i -D playwright) or run this where a browser lives;"
  echo "              this run proves nothing about the maps."; exit 0; }

TMP=$(mktemp -d) || exit 10
trap 'rm -rf "$TMP"' EXIT

# ── L1~L3 발행되는 지도 세 장: 라이트 모드 첫 프레임에 어두운 프레임이 없고,
#    reduced-motion 에서 점이 멈춰 있나. 프로브가 매 실행 자기 known-positive 를 만들어 재므로,
#    이 초록은 «계기가 갈릴 줄 안다»는 증거를 동반한다(안 갈리면 프로브가 rc=4 로 죽는다).
N=0
for PAGE in docs/map/*.html; do
  [ -f "$PAGE" ] || continue
  N=$((N+1))
  L="L$N $(basename "$PAGE")"
  # 점의 마크업은 세 장이 같다 — 첫 장에서만 점을 재고 나머지는 첫 페인트만 잰다.
  # 같은 것을 세 번 재는 40 초는 값이 없고, 값 없는 시간은 스위트를 «가끔 돌리는 것»으로 만든다.
  if [ "$N" -eq 1 ]; then PULSE_ARG=""; else PULSE_ARG="--no-pulse"; fi
  # shellcheck disable=SC2086
  node "$P" "$PAGE" --out "$TMP/live$N" $PULSE_ARG >"$TMP/o$N" 2>&1
  RC=$?
  SHIPPED=$(grep '^MIN_LUMA_SHIPPED=' "$TMP/o$N" | cut -d= -f2)
  BROKEN=$(grep '^MIN_LUMA_BROKEN=' "$TMP/o$N" | cut -d= -f2)
  SPREAD=$(grep '^PULSE_SPREAD_REDUCE=' "$TMP/o$N" | cut -d= -f2)
  CTRL=$(grep '^PULSE_SPREAD_CONTROL=' "$TMP/o$N" | cut -d= -f2)
  case $RC in
    0) if [ -n "$SPREAD" ]; then
         ok "$L: no dark first frame (shipped min luma $SHIPPED vs known-positive $BROKEN); dot still under reduce (spread $SPREAD, control $CTRL)"
       else
         ok "$L: no dark first frame (shipped min luma $SHIPPED vs known-positive $BROKEN); pulse measured on lane 1 only"
       fi ;;
    1) ng "$L: FLASHED IN A REAL RENDER — $(grep -E '^(FLASH_SHIPPED|PULSE_STILL_UNDER_REDUCE)=' "$TMP/o$N" | tr '\n' ' ')" ;;
    4) ng "$L: instrument error, nothing measured — $(tail -2 "$TMP/o$N")" ;;
    *) ng "$L: probe exited $RC — $(tail -2 "$TMP/o$N")" ;;
  esac
done
[ "$N" -gt 0 ] || { echo "NOT MEASURED  docs/map/*.html vanished between the guard and the loop"; exit 0; }

# ── L$((N+1)) 되돌림 프로브: 억제를 되돌린 페이지를 «발행본» 자리에 넣으면 프로브가 rc=1 로
#    빨개지는가. 이것이 없으면 위 초록들은 «항상 초록인 계기»와 구분되지 않는다.
REV=$((N+1))
SRC=docs/map/fh_process.workflow.html
if [ ! -f "$SRC" ]; then
  ng "L$REV $SRC absent — the revert probe measured nothing (NOT a pass)"
else
  mkdir -p "$TMP/reverted"
  python3 - "$SRC" "$TMP/reverted/$(basename "$SRC")" <<'PYEOF'
import re, sys
s = open(sys.argv[1], encoding='utf-8').read()
m = re.search(r'<script>\s*//\s*Resolve the theme before first paint.*?</script>', s, re.S)
if not m:
    sys.exit(9)                      # 앵커가 없다 = 되돌릴 것이 없다 = 계기 고장
body = s.rfind('</body>')
if body < 0:
    sys.exit(9)
cut = s[:m.start()] + s[m.end():]
body = cut.rfind('</body>')
open(sys.argv[2], 'w', encoding='utf-8').write(cut[:body] + m.group(0) + cut[body:])
PYEOF
  SETUP=$?
  if [ $SETUP -eq 9 ]; then
    ng "L$REV the pre-paint theme block is already gone from $SRC — instrument had nothing to move"
  elif [ $SETUP -ne 0 ]; then
    ng "L$REV setup failed while building the reverted copy (rc=$SETUP)"
  else
    node "$P" "$TMP/reverted/$(basename "$SRC")" --out "$TMP/rev" >"$TMP/orev" 2>&1
    RC=$?
    if [ $RC -eq 1 ] && grep -q '^FLASH_SHIPPED=yes' "$TMP/orev"; then
      ok "L$REV theme resolution pushed past <body> -> probe reports a real flash (rc=1, min luma $(grep '^MIN_LUMA_SHIPPED=' "$TMP/orev" | cut -d= -f2))"
    else
      ng "L$REV reverted page was NOT caught (rc=$RC) — $(tail -2 "$TMP/orev")"
    fi
  fi
fi

# ── L$((N+2)) 계기 고장은 조용한 통과가 아니다: 앵커가 없는 문서는 rc=4 로 죽는다
BAD=$((N+2))
printf '<html data-theme="dark"><head><style>.a{color:red}</style></head><body>x</body></html>' > "$TMP/noanchor.html"
node "$P" "$TMP/noanchor.html" --out "$TMP/noanchor" >"$TMP/obad" 2>&1
RC=$?
if [ $RC -eq 4 ] && grep -q 'INSTRUMENT ERROR' "$TMP/obad"; then
  ok "L$BAD no pre-paint theme block -> rc=4 INSTRUMENT ERROR (never a silent pass)"
else
  ng "L$BAD a page with no known-positive to build exited $RC — $(tail -2 "$TMP/obad")"
fi

# ── L$((N+3)) 대상 부재는 계기 고장과 다른 값이다
ABS=$((N+3))
node "$P" "$TMP/does-not-exist.html" >"$TMP/oabs" 2>&1
RC=$?
if [ $RC -eq 3 ]; then
  ok "L$ABS absent target -> rc=3 (distinct from rc=4 instrument error)"
else
  ng "L$ABS absent target exited $RC (expected 3)"
fi

# ── L$((N+4)) 런타임 부재 갈래를 실제로 밟는다: playwright 가 없으면 프로브는 rc=3 이고,
#    «없어서 안 쟀다»는 «재서 통과했다»와 다른 값이다. 주입점 = FH_PLAYWRIGHT_MODULE.
NOPW=$((N+4))
FH_PLAYWRIGHT_MODULE=/nonexistent/playwright \
  node "$P" docs/map/fh_process.workflow.html --out "$TMP/nopw" >"$TMP/onopw" 2>&1
RC=$?
if [ $RC -eq 3 ] && grep -q 'playwright absent' "$TMP/onopw"; then
  ok "L$NOPW playwright unreachable -> rc=3 'NOT a pass' (never a green with no browser)"
else
  ng "L$NOPW playwright-absent branch exited $RC — $(tail -2 "$TMP/onopw")"
fi

echo "── map_flash_render lanes: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0

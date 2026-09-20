#!/usr/bin/env bash
# test_stale_ref_scan_lanes.sh — known pairs + revert probes for scripts/stale_ref_scan.py
#
# WHY THIS SUITE EXISTS AT ALL
#   `new-code-anchor` caught the author's own admission: the scanner shipped with no lane that
#   RUNS it. The commit message said «배선 안 함» and the gate turned that sentence into a red
#   check. 🟥 A `--self-check` inside the tool is not an anchor — nothing on a runner surface
#   executes it, so «a green suite total» would mean «nothing touched this file».
#
# WHY LANES ON FIXTURES, NOT ON THE REPO'S OWN PAPERS
#   The three demonstrations the author ran (v1.0.3 · v1.0.4 · CITATION.cff) need the LIVE Zenodo
#   API and drift with every future deposit. Both are disqualifying for a consumer install. So the
#   network arms here go through `--offline-fixture`, and the shapes are copied byte-for-byte from
#   the real corpus (fixture shape from the artifact, not a mental model):
#     · `10.5281/<wbr>zenodo.<wbr>20397566`   paper/forge_harness_v1.0.3.html:159
#     · `[Zenodo](https://zenodo.org/records/22542168)`  README.md:418
#     · `# forge-harness (fh-meta) Changelog`  plugins/fh-meta/CHANGELOG.md:1
#
# THE TWO-SIGNALS RULE
#   A 0 is evidence only if the instrument SAW something. L3 asserts the id was extracted AND
#   classified as changelog; L6 asserts a binary body is named UNSCANNABLE rather than silently
#   producing «0 sites», which is exactly the defect the adversarial round measured (S-1).
#
# REVERT PROBES (a mechanism is load-bearing only if removing it turns a known pair red)
#   L8 scan_body · L9 rc dominance · L10 binary detection. Each mutates a COPY by source edit,
#   asserts the copy's --self-check goes red, and byte-compares the original before and after.
#   🟥 Before the 2026-09-20 hardening, mutating scan_body left --self-check at 4/4 PASS.
#
# 🟥 PITFALL (this repo's lanes): `out="$(cmd)"` runs in a SUBSHELL, so `rc=$?` after it is the
#   assignment's status. Every lane below redirects to a file and reads `$?` directly.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAN="$ROOT/scripts/stale_ref_scan.py"
PY="${PYTHON:-/usr/bin/python3}"
PASS=0; FAIL=0
ok ()  { printf '  ✅ %s\n' "$1"; PASS=$((PASS+1)); }
ng ()  { printf '  ❌ %s\n' "$1"; FAIL=$((FAIL+1)); }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

if [ ! -f "$SCAN" ]; then
  printf '🟥 HARNESS ERROR — %s 가 없다. 「0 실패」가 아니라 계기 부재다.\n' "$SCAN"; exit 10
fi

# 오프라인 픽스처 — 실물 id 관계를 그대로 옮긴다(라이브 API 직독 2026-09-20)
cat > "$TMP/fx.json" <<'JSON'
{ "20397566": {"id": 20397566, "conceptrecid": "20397565"},
  "22843702": {"id": 22843702, "conceptrecid": "20397565"},
  "20397565": {"id": 22843702, "conceptrecid": "20397565"},
  "22542168": {"id": 22542168, "conceptrecid": "20397565"} }
JSON
run () { "$PY" "$SCAN" --offline-fixture "$TMP/fx.json" --body "$@" > "$TMP/out" 2>&1; echo $?; }

# ── L1 자기검사가 실제로 돈다 ─────────────────────────────────────────────────
"$PY" "$SCAN" --self-check > "$TMP/sc" 2>&1; rc=$?
n_pass=$(/usr/bin/grep -c '^  PASS' "$TMP/sc" || true)
if [ "$rc" = "0" ] && [ "$n_pass" -ge 17 ]; then ok "L1 --self-check rc=0 · PASS 레인 $n_pass (>=17)"
else ng "L1 --self-check rc=$rc · PASS $n_pass"; fi

# ── L2 known-POSITIVE: <wbr> 분할 DOI 가 SUPERSEDED 로 잡힌다 ─────────────────
printf '<tr><td>forge-harness</td><td>10.5281/<wbr>zenodo.<wbr>20397566</td></tr>\n' > "$TMP/a.html"
rc=$(run "$TMP/a.html")
if [ "$rc" = "1" ] && /usr/bin/grep -q 'SUPERSEDED=1' "$TMP/out"; then ok "L2 <wbr> 분할 DOI → SUPERSEDED rc=1"
else ng "L2 rc=$rc · $(/usr/bin/grep -o 'SUPERSEDED=[0-9]*' "$TMP/out" | head -1)"; fi

# ── L3 changelog 제외 — 🟥 «봤는데 제외했다» 를 같이 단언한다 ─────────────────
printf '# forge-harness (fh-meta) Changelog\nsee 10.5281/zenodo.20397566 for what was wrong\n' > "$TMP/b.md"
rc=$(run "$TMP/b.md")
if [ "$rc" = "0" ] && /usr/bin/grep -q 'CHANGELOG-EXCLUDED=1' "$TMP/out" \
   && /usr/bin/grep -q 'SUPERSEDED=0' "$TMP/out"; then
  ok "L3 '# <이름> Changelog' → 제외 1건 · SUPERSEDED 0 (봤고 제외했다)"
else ng "L3 rc=$rc · $(/usr/bin/grep -o 'CHANGELOG-EXCLUDED=[0-9]*' "$TMP/out" | head -1)"; fi

# ── L4 known-NEGATIVE: 본문 산문의 «changelog» 는 컷오프가 아니다 ────────────
printf 'We keep a changelog for this reason.\ncite 10.5281/zenodo.20397566 here\n' > "$TMP/c.md"
rc=$(run "$TMP/c.md")
if [ "$rc" = "1" ] && /usr/bin/grep -q 'SUPERSEDED=1' "$TMP/out"; then
  ok "L4 NEG 산문의 changelog 는 컷오프가 아니다 — 인용이 살아 있다"
else ng "L4 rc=$rc — 산문 낱말이 진짜 인용을 삼켰다"; fi

# ── L5 pin 마커 — 발행 스냅샷은 통째로 기록 ───────────────────────────────────
printf '<!-- stale-ref: pinned — published snapshot -->\n10.5281/zenodo.20397566\n' > "$TMP/d.html"
rc=$(run "$TMP/d.html")
if [ "$rc" = "0" ] && /usr/bin/grep -q 'CHANGELOG-EXCLUDED=1' "$TMP/out"; then ok "L5 pin 마커 → rc=0"
else ng "L5 rc=$rc — pin 이 안 먹는다"; fi

# ── L6 🟥 못 읽은 입력은 UNSCANNABLE + rc=10 (적대검증 S-1) ───────────────────
printf '%%PDF-1.4\000\000binary\n' > "$TMP/e.pdf"
rc=$(run "$TMP/e.pdf")
if [ "$rc" = "10" ] && /usr/bin/grep -q 'UNSCANNABLE=1' "$TMP/out"; then
  ok "L6 바이너리 → UNSCANNABLE rc=10 (0 sites rc=0 아님)"
else ng "L6 rc=$rc — 못 읽은 것이 «깨끗함» 으로 나간다"; fi

# ── L7 컨셉 DOI 는 CONCEPT · 최신 버전은 CURRENT ──────────────────────────────
printf '10.5281/zenodo.20397565 and 10.5281/zenodo.22843702\n' > "$TMP/f.md"
rc=$(run "$TMP/f.md")
if [ "$rc" = "0" ] && /usr/bin/grep -q 'CONCEPT=1' "$TMP/out" && /usr/bin/grep -q 'CURRENT=1' "$TMP/out"; then
  ok "L7 컨셉→CONCEPT · 최신→CURRENT rc=0"
else ng "L7 rc=$rc · $(/usr/bin/grep -o 'CONCEPT=[0-9]* CURRENT=[0-9]*' "$TMP/out" | head -1)"; fi

# ── 되돌림 프로브 ─────────────────────────────────────────────────────────────
probe () {   # $1=이름  $2=원문  $3=치환문
  cp "$SCAN" "$TMP/mut.py"
  "$PY" - "$TMP/mut.py" "$2" "$3" <<'PYX'
import io,sys
p,a,b=sys.argv[1],sys.argv[2],sys.argv[3]
s=io.open(p,encoding="utf-8").read()
if s.count(a)!=1: sys.exit(3)
io.open(p,"w",encoding="utf-8").write(s.replace(a,b,1))
PYX
  if [ $? -ne 0 ]; then ng "$1 — 뮤턴트 생성 실패(치환 대상 부재). HARNESS ERROR, 초록으로 안 읽는다"; return; fi
  "$PY" "$TMP/mut.py" --self-check > "$TMP/mo" 2>&1; mrc=$?
  if [ "$mrc" != "0" ] && /usr/bin/grep -q '^  FAIL' "$TMP/mo"; then ok "$1 — 뮤턴트가 빨개진다"
  else ng "$1 — 뮤턴트인데 self-check 가 초록이다(앵커가 장식)"; fi
}
probe "L8  scan_body 죽이기" "    return sites" "    return []"
probe "L9  rc 지배 제거" "    if unresolved or unscannable:" "    if False:"
probe "L10 바이너리 검사 제거" '    if b"\x00" in raw:' "    if False:"

# 원본 불변 확인 — 프로브가 대상을 건드리지 않았나
"$PY" "$SCAN" --self-check > "$TMP/sc2" 2>&1
if [ $? -eq 0 ]; then ok "L11 프로브 후에도 원본 --self-check rc=0 (사본만 건드렸다)"
else ng "L11 원본이 오염됐다"; fi

printf '\n  PASS %d   FAIL %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1

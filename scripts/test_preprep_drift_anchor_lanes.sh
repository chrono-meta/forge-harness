#!/usr/bin/env bash
# test_preprep_drift_anchor_lanes.sh — known pairs for the D2 leg of scripts/test_preprep_drift_anchor.sh
# WHY (2026-09-03): D2 compared the standalone copy only when PREPREP_STANDALONE_DIR was set. Nobody
# set it, so the leg SKIPPED for weeks while the companion-store fork drifted (724 vs 789 lines, L9-L11
# never called) — the second occurrence of the exact accident the canon's own comment records.
# Fix under test: with the env var unset, the anchor falls back to $FH_COMPANION_STORE/preprep when it
# exists. These lanes pin: fallback used · fallback discriminates (identical PASS / drifted FAIL) ·
# explicit var still wins · nothing set → SKIP (never a silent PASS).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; A="$HERE/scripts/test_preprep_drift_anchor.sh"
SRC="$HERE/plugins/fh-preprep/skills/preprep"; T=$(mktemp -d); pass=0; fail=0
chk(){ if [ "$1" = 0 ]; then echo "  ✅ $2"; pass=$((pass+1)); else echo "  ❌ $2"; fail=$((fail+1)); fi; }
# 🟥 2026-09-11: 앵커(D2)는 «디렉터리의 *.py 전부» 를 돈다(2026-09-10 덱 세션 정정). 여기 목록이 5개로 박혀 있어
#    새 레인 파일(lane_attr_consistency 등)이 «부재 드리프트» 로 읽혀 L2/L4 가 CI 에서 빨개졌다 — 앵커와 같은 규칙으로.
# 🟥 **앵커와 같은 규칙으로 뽑는다.** 이 함수는 원래 `"$SRC"/*.py` 최상위만 평평하게 복사했다.
#    2026-09-21 에 앵커 D2 가 `find` 재귀로 바뀌면서 `ooxml/gate.py` 등 하위 파일을 요구하게
#    됐는데 픽스처가 안 따라가 **부재 드리프트**로 읽혔고 L2·L4 가 CI 에서 빨개졌다.
#    🟥 **이 파일이 이미 한 번 겪은 사고다** — 이 스크립트 머리말(2026-09-11)이 같은 형태를
#    적고 있고 처방도 「앵커와 같은 규칙으로」였다. 앵커만 고치고 짝을 안 고친 것이라
#    `[[feedback_half_fix_propagation_boundary]]` 정통이다.
#    ⇒ 상대경로를 보존해 재귀 복사한다. 앵커가 규칙을 또 바꾸면 여기도 같이 바꿔야 한다.
mk(){
  mkdir -p "$1"
  while IFS= read -r f; do
    rel="${f#$SRC/}"
    mkdir -p "$1/$(dirname "$rel")"
    cp "$f" "$1/$rel"
  done < <(find "$SRC" -type f -not -path '*/__pycache__/*' -not -path '*/.pytest_cache/*' -not -name '*.pyc' | sort)
}
# 🟥 2026-09-22 — 위 `find` 가 «*.py» 였고 앵커 D2 도 그랬다. 앵커를 확장자 무관으로 넓히면서
#    **여기도 같이 넓혔다.** 이 파일은 이 실수를 이미 두 번 겪었다(머리말 2026-09-11 · 2026-09-21):
#    앵커만 고치고 픽스처를 안 고치면 L2/L4 가 «부재 드리프트» 로 빨개진다.
#    ⇒ 앵커가 범위 규칙을 또 바꾸면 이 줄도 **같은 호출에서** 바꿔라.
echo "[preprep-drift-anchor] D2 known pairs"
# L1 nothing set → D2 SKIP (skip != pass), rc 0 (D2 is not a FAIL)
out=$(env -u PREPREP_STANDALONE_DIR FH_COMPANION_STORE="$T/nostore" bash "$A" 2>&1); printf '%s' "$out" | grep -q "D2 .*SKIPPED"; chk $? "L1 var unset + no companion preprep → D2 SKIPPED (not PASS)"
# L2 companion copy identical → fallback used, D2 PASS
mk "$T/be/preprep"; out=$(env -u PREPREP_STANDALONE_DIR FH_COMPANION_STORE="$T/be" bash "$A" 2>&1); printf '%s' "$out" | grep -q "✅ D2 .*자동 후보"; chk $? "L2 fallback FH_COMPANION_STORE/preprep identical → D2 PASS via 자동 후보"
# L3 companion copy drifted → D2 FAIL, rc 1 (the accident class)
printf '\n# drift\n' >> "$T/be/preprep/preprep.py"; env -u PREPREP_STANDALONE_DIR FH_COMPANION_STORE="$T/be" bash "$A" >"$T/l3.out" 2>&1; rc=$?; [ "$rc" -ne 0 ] && grep -q "D2 드리프트.*preprep.py(갈림)" "$T/l3.out"; chk $? "L3 fallback copy drifted → D2 FAIL rc=$rc (known-positive)"
# L4 explicit var wins over companion
# ── L5 🟥 «하위 디렉터리» 드리프트를 잡나 — 재귀를 지키는 유일한 레인 ──────────────
# 2026-09-21: 앵커 D2 를 최상위 전용 → `find` 재귀로 바꿨는데(그 사각에 `ooxml/gate.py` 가
# 있었고 실제로 회귀가 초록으로 통과했다), **그 변경을 지키는 레인이 하나도 없었다.**
# 되돌림 프로브로 확인했다: 앵커를 최상위 전용으로 되돌려도 L1~L4 가 전부 초록이다.
# 🟥 즉 그 수리는 장식이 될 뻔했다(`[[feedback_anchor_can_be_decorative]]`).
# L3 는 최상위 `preprep.py` 를 갈라서 재귀 여부와 무관하게 잡힌다 — 이 레인이 그 짝이다.
mk "$T/be2/preprep"
_sub=$(cd "$SRC" && find . -mindepth 2 -name '*.py' -not -path '*/__pycache__/*' | head -1 | sed 's|^\./||')
if [ -z "$_sub" ]; then
  echo "  ⛔ L5 INSTRUMENT ERROR — 소스에 하위 디렉터리 .py 가 없다. 이 레인은 그 전제 위에 선다"
  fail=$((fail+1))
else
  printf '\n# drift\n' >> "$T/be2/preprep/$_sub"
  out=$(env -u PREPREP_STANDALONE_DIR FH_COMPANION_STORE="$T/be2" bash "$A" 2>&1); rc=$?
  { [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q "D2 드리프트.*$(basename "$_sub")(갈림)"; }
  chk $? "L5 하위 디렉터리 드리프트($_sub) → D2 FAIL rc=$rc (재귀가 하중을 진다)"
fi

# ── L6 🟥 «.py 가 아닌 파일» 드리프트를 잡나 — 앵커의 37% 사각 ────────────────────
# 2026-09-22, 배포본을 합류된 main 에서 다시 뽑던 세션이 실측으로 냈다:
#   fixtures/fixture_R3_negative.pptx   배포본 923b8f23…(25,278B) ↔ 정본 3107ff54…(25,229B)
#   fixtures/fixture_R3_positive.pptx   배포본 64e8c545…(25,157B) ↔ 정본 21d9d19a…(25,109B)
# 🟥 **R3 레인의 known-positive/known-negative 짝 그 자체가 갈려 있었다** — 배포본에서
#    R3 를 돌렸다면 «틀린 짝으로» 교정하고 있었다. 그런데 앵커는 여태 초록이었다.
# 정본 41파일 중 `.py` 가 아닌 것이 **15개(37%)**: SKILL.md · checklist · README ·
# surfaces/canon/jargon 예시 · c1_baseline.txt · fixtures/*.md ×6 · fixtures/*.pptx ×2.
# ⇒ 앵커 교리는 «사본이 둘이면 갈린다» 인데, **무엇이 «사본»인지가 확장자로 좁혀져 있었다.**
#   L5(디렉터리 축)와 같은 얼굴이고 축만 다르다.
mk "$T/be3/preprep"
_nonpy=$(cd "$SRC" && find . -type f ! -name '*.py' -not -path '*/__pycache__/*' -not -path '*/.pytest_cache/*' | head -1 | sed 's|^\./||')
if [ -z "$_nonpy" ]; then
  echo "  ⛔ L6 INSTRUMENT ERROR — 소스에 .py 아닌 파일이 없다. 이 레인은 그 전제 위에 선다"
  fail=$((fail+1))
else
  printf '\n<!-- drift -->\n' >> "$T/be3/preprep/$_nonpy"
  out=$(env -u PREPREP_STANDALONE_DIR FH_COMPANION_STORE="$T/be3" bash "$A" 2>&1); rc=$?
  { [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q "D2 드리프트.*$(basename "$_nonpy")(갈림)"; }
  chk $? "L6 .py 아닌 파일 드리프트($_nonpy) → D2 FAIL rc=$rc (확장자 사각이 닫혔다)"
fi

# 🟥 이 레인은 «어느 출처가 이겼나» 를 본다. 초판은 `(PREPREP_STANDALONE_DIR)` 로 **닫는 괄호까지**
#    붙여 잡았는데, 앵커가 PASS 문구에 `· 하위 디렉터리 포함` 을 더하자 그 리터럴이 사라져 깨졌다.
#    ⇒ 출처 토큰 **뒤의 공백까지만** 본다 — 괄호 안에 무엇이 더 붙어도 살아남고,
#    다른 출처(`FH_COMPANION_STORE/preprep (자동 후보)`)와는 여전히 갈린다.
mk "$T/explicit"; out=$(PREPREP_STANDALONE_DIR="$T/explicit" FH_COMPANION_STORE="$T/be" bash "$A" 2>&1); printf '%s' "$out" | grep -q "✅ D2 .*(PREPREP_STANDALONE_DIR "; chk $? "L4 explicit PREPREP_STANDALONE_DIR wins over drifted companion copy"
rm -rf "$T"; echo "[preprep-drift-anchor] $pass passed, $fail failed"; [ "$fail" -eq 0 ]

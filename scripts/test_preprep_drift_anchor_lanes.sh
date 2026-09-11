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
SRC="$HERE/plugins/fh-commons/skills/preprep"; T=$(mktemp -d); pass=0; fail=0
chk(){ if [ "$1" = 0 ]; then echo "  ✅ $2"; pass=$((pass+1)); else echo "  ❌ $2"; fail=$((fail+1)); fi; }
# 🟥 2026-09-11: 앵커(D2)는 «디렉터리의 *.py 전부» 를 돈다(2026-09-10 덱 세션 정정). 여기 목록이 5개로 박혀 있어
#    새 레인 파일(lane_attr_consistency 등)이 «부재 드리프트» 로 읽혀 L2/L4 가 CI 에서 빨개졌다 — 앵커와 같은 규칙으로.
mk(){ mkdir -p "$1"; for f in "$SRC"/*.py; do cp "$f" "$1/$(basename "$f")"; done; }
echo "[preprep-drift-anchor] D2 known pairs"
# L1 nothing set → D2 SKIP (skip != pass), rc 0 (D2 is not a FAIL)
out=$(env -u PREPREP_STANDALONE_DIR FH_COMPANION_STORE="$T/nostore" bash "$A" 2>&1); printf '%s' "$out" | grep -q "D2 .*SKIPPED"; chk $? "L1 var unset + no companion preprep → D2 SKIPPED (not PASS)"
# L2 companion copy identical → fallback used, D2 PASS
mk "$T/be/preprep"; out=$(env -u PREPREP_STANDALONE_DIR FH_COMPANION_STORE="$T/be" bash "$A" 2>&1); printf '%s' "$out" | grep -q "✅ D2 .*자동 후보"; chk $? "L2 fallback FH_COMPANION_STORE/preprep identical → D2 PASS via 자동 후보"
# L3 companion copy drifted → D2 FAIL, rc 1 (the accident class)
printf '\n# drift\n' >> "$T/be/preprep/preprep.py"; env -u PREPREP_STANDALONE_DIR FH_COMPANION_STORE="$T/be" bash "$A" >"$T/l3.out" 2>&1; rc=$?; [ "$rc" -ne 0 ] && grep -q "D2 드리프트.*preprep.py(갈림)" "$T/l3.out"; chk $? "L3 fallback copy drifted → D2 FAIL rc=$rc (known-positive)"
# L4 explicit var wins over companion
mk "$T/explicit"; out=$(PREPREP_STANDALONE_DIR="$T/explicit" FH_COMPANION_STORE="$T/be" bash "$A" 2>&1); printf '%s' "$out" | grep -q "✅ D2 .*(PREPREP_STANDALONE_DIR)"; chk $? "L4 explicit PREPREP_STANDALONE_DIR wins over drifted companion copy"
rm -rf "$T"; echo "[preprep-drift-anchor] $pass passed, $fail failed"; [ "$fail" -eq 0 ]

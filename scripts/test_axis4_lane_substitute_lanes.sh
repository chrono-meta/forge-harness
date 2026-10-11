#!/usr/bin/env bash
# test_axis4_lane_substitute_lanes.sh — Axis 4 레인 갈음 (2026-10-11, P29 표본 n=20).
# pre-commit 의 Axis 4 검사기(heredoc Python)를 그대로 추출해 실행한다. 판정은 exit code:
#   0 통과 · 2 오늘자 엔트리 없음 · 4 갈음 거부. (가역 표면 완화 — 비가역 게이트와 무관)
# a 통과 · b 안 보는 것 빈칸 · c 레인 부재 · d 부재 주장 갈음 · e 오늘자 엔트리 없음 · f 종전 형식 컨트롤
# + 되돌림 3단(적용 확인 → 실행 → 복원): 갈음 허용 줄 / 부재 주장 판별 / not_seen 검사.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$REPO_ROOT/templates/.git-hooks/pre-commit"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
TODAY=2026-10-11
extract() { awk '/^python3 - "\$MANIFEST"|^  MANIFEST_MSG=\$\(python3 - /{f=1;next} f&&/^PYEOF$/{exit} f' "$1"; }
extract "$HOOK" > "$T/chk.py"
[ "$(wc -l < "$T/chk.py")" -gt 20 ] && grep -q 'lane substitution refused' "$T/chk.py" \
  || { echo "❌ HARNESS-ERROR — Axis 4 checker did not extract (empty/old hook)"; exit 1; }
mkdir -p "$T/repo/scripts"; : > "$T/repo/scripts/test_real_lane.sh"; ln -s /etc/hosts "$T/repo/scripts/sym_out.sh"
FAIL=0
run() { # $1 py $2 yaml-body → rc
  printf '%s\n' "$2" > "$T/m.yaml"; python3 "$1" "$T/m.yaml" "$TODAY" "$T/repo" >"$T/out" 2>&1; echo $?; }
lane() { # id expect-rc body [py]
  local rc; rc=$(run "${4:-$T/chk.py}" "$3")
  if [ "$rc" = "$2" ]; then printf '  ✅ %-34s rc=%s\n' "$1" "$rc"
  else printf '  ❌ %-34s expected rc=%s got %s (%s)\n' "$1" "$2" "$rc" "$(head -c 160 "$T/out")"; FAIL=1; fi; }
E() { printf -- '- date: %s\n  files: [a]\n  intent: x\n%s\n' "$TODAY" "$1"; }
echo "== Axis 4 lane substitution =="
lane a-lane-and-not_seen-pass 0 "$(E '  lane: scripts/test_real_lane.sh
  not_seen: 현장 노드의 실사용 결과는 보지 않는다')"
lane b-not_seen-blank        4 "$(E '  lane: scripts/test_real_lane.sh
  not_seen: ""')"
lane b2-not_seen-placeholder 4 "$(E '  lane: scripts/test_real_lane.sh
  not_seen: 없음')"
lane b3-not_seen-missing     4 "$(E '  lane: scripts/test_real_lane.sh')"
lane c-lane-path-missing     4 "$(E '  lane: scripts/test_nope.sh
  not_seen: 현장 노드의 실사용 결과는 보지 않는다')"
lane c2-lane-dotdot          4 "$(E '  lane: ../outside.sh
  not_seen: 현장 노드의 실사용 결과는 보지 않는다')"
lane d-absence-claim-ko      4 "$(E '  lane: scripts/test_real_lane.sh
  not_seen: 현장 노드의 실사용 결과는 보지 않는다
  predicted_impact: 미측정을 깨끗으로 렌더하는 경로가 남아 있지 않다')"
lane d2-absence-claim-en     4 "$(E '  lane: scripts/test_real_lane.sh
  not_seen: 현장 노드의 실사용 결과는 보지 않는다
  predicted_impact: the scanner never renders unmeasured as clean')"
lane e-no-entry-today        2 "- date: 2026-01-01
  files: [a]
  intent: old"
lane f-classic-prediction    0 "$(E '  predicted_impact: 경고 한 줄이 사라진다')"
lane f2-classic-absence-ok   0 "$(E '  predicted_impact: 그 경로가 남아 있지 않다')"
lane g-list-absence-claim    4 "$(E '  lane: scripts/test_real_lane.sh
  not_seen: 현장 노드의 실사용 결과는 보지 않는다
  predicted_impact:
    - 그 경로가 전혀 남아 있지 않다')"
lane g2-impact-key-absence   4 "$(E '  lane: scripts/test_real_lane.sh
  not_seen: 현장 노드의 실사용 결과는 보지 않는다
  impact: 버그가 없어진다')"
lane h-symlink-outside-repo  4 "$(E '  lane: scripts/sym_out.sh
  not_seen: 현장 노드의 실사용 결과는 보지 않는다')"
lane i-lane-null-is-classic  0 "$(E '  predicted_impact: 경고 한 줄이 사라진다
  lane: null')"
lane j-stale-dead-lane-then-classic 0 "$(E '  lane: scripts/test_nope.sh
  not_seen: 현장 노드의 실사용 결과는 보지 않는다')
$(E '  predicted_impact: 별건 종전 예측')"
lane k-bad-lane-after-valid-classic 4 "$(E '  predicted_impact: 아침 종전 커밋')
$(E '  lane: scripts/test_nope.sh
  not_seen: 현장 노드의 실사용 결과는 보지 않는다')"
lane l-nominal-absence-ko    4 "$(E '  lane: scripts/test_real_lane.sh
  not_seen: 현장 노드의 실사용 결과는 보지 않는다
  predicted_impact: 커밋 시 경고 한 줄 사라짐')"
lane m-short-not_seen-ok     0 "$(E '  lane: scripts/test_real_lane.sh
  not_seen: 실서버 미검증')"
lane n-mapping-key-not-scanned 0 "$(E '  lane: scripts/test_real_lane.sh
  not_seen: runtime behavior
  impact:
    never: renamed to always')"
echo "== 되돌림 3단 =="
probe() { # id sed-expr expected-failing-lane-desc
  sed "$2" "$T/chk.py" > "$T/mut.py"
  if cmp -s "$T/chk.py" "$T/mut.py"; then echo "  ❌ $1 적용 확인 실패(변이가 안 먹었다) — 계기 오류"; FAIL=1; return; fi
  echo "  · $1 변이 적용됨"; }
probe R1-allow-line 's/if not os.path.isfile(full):/if False:/'
rc=$(run "$T/mut.py" "$(E '  lane: scripts/test_nope.sh
  not_seen: 현장 노드의 실사용 결과는 보지 않는다')"); [ "$rc" != 4 ] && echo "  ✅ R1 되돌림 → (c) 빨강(rc=$rc)" || { echo "  ❌ R1 되돌려도 (c) 초록"; FAIL=1; }
probe R2-absence 's/    for k in ("predicted_impact", "prediction", "impact"):/    for k in ():/'
rc=$(run "$T/mut.py" "$(E '  lane: scripts/test_real_lane.sh
  not_seen: 현장 노드의 실사용 결과는 보지 않는다
  predicted_impact: 그 경로가 남아 있지 않다')"); [ "$rc" != 4 ] && echo "  ✅ R2 부재 판별 삭제 → (d) 빨강(rc=$rc)" || { echo "  ❌ R2 삭제해도 (d) 초록"; FAIL=1; }
probe R3-not_seen 's/if not isinstance(ns, str) or ns.strip().lower() in _PH or len(ns.strip()) < 5:/if False:/'
rc=$(run "$T/mut.py" "$(E '  lane: scripts/test_real_lane.sh
  not_seen: ""')"); [ "$rc" != 4 ] && echo "  ✅ R3 not_seen 검사 삭제 → (b) 빨강(rc=$rc)" || { echo "  ❌ R3 삭제해도 (b) 초록"; FAIL=1; }
# 복원 확인: 원본은 안 건드렸으니 다시 (a) 가 통과해야 한다
lane Z-restored-a-pass 0 "$(E '  lane: scripts/test_real_lane.sh
  not_seen: 현장 노드의 실사용 결과는 보지 않는다')"
[ $FAIL -eq 0 ] && echo "AXIS4 LANE-SUBSTITUTE LANES: PASS" || echo "AXIS4 LANE-SUBSTITUTE LANES: FAIL"
exit $FAIL

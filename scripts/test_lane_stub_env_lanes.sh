#!/usr/bin/env bash
# test_lane_stub_env_lanes.sh — scripts/lane_stub_env.sh 와 scripts/lane_onoff_compare.py 의 known-pair.
#
# 지키는 것 셋: ① 스텁은 허용 목록의 레인 안에서만 켜진다(누출 금지 — 훅·selfcheck 본체·주제 레인)
#   ② 스텁이 켜져도 «무엇을 안 돌렸나» 가 보인다(gh 호출 기록 · ①-g UNMEASURED)
#   ③ 켠/끈 비교기가 «rc 는 같은데 진단이 사라진» 변이를 잡는다(설계 §11)
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
ROOT="$(pwd -P)"
H="$ROOT/scripts/lane_stub_env.sh"; CMP="$ROOT/scripts/lane_onoff_compare.py"; ALLOW="$ROOT/scripts/lane_stub_env.allow"
for f in "$H" "$CMP" "$ALLOW"; do [ -f "$f" ] || { echo "HARNESS-ERROR: ${f##*/} 없음 (NOT a pass)"; exit 3; }; done
PASS=0; FAIL=0
ok() { echo "✅ $1"; PASS=$((PASS+1)); }
ng() { echo "❌ $1"; FAIL=$((FAIL+1)); }
T=$(mktemp -d) || { echo "HARNESS-ERROR: mktemp"; exit 3; }
trap 'rm -rf "$T"' EXIT INT TERM

# ── ① 누출: 허용 목록 밖 파일은 이 헬퍼를 source 하지 않는다 ──
leaks() {  # $1=검색 루트 → 허용 목록 밖에서 lane_stub_env.sh 를 source 하는 파일
  /usr/bin/grep -rlE '^[^#]*(\.|source)[[:space:]]+[^#]*lane_stub_env\.sh' "$1" --include='*.sh' 2>/dev/null \
    | while read -r f; do b=$(basename "$f"); [ "$b" = test_lane_stub_env_lanes.sh ] && continue   # 이 파일의 픽스처 문자열
        /usr/bin/grep -qxF "$b" "$ALLOW" || echo "$f"; done
}
L=$(leaks "$ROOT/scripts"; leaks "$ROOT/templates")
[ -z "$L" ] && ok "L1 누출 없음: 허용 목록 밖에서 source 하는 파일 0" || ng "L1 누출: $L"
mkdir -p "$T/leak"; printf '. "$D/lane_stub_env.sh"\n' > "$T/leak/selfcheck.sh"
[ -n "$(leaks "$T/leak")" ] && ok "L1b 컨트롤: 허용 목록 밖 source 를 잡는다" || ng "L1b 누출 검출기가 장식이다"
for s in test_session_close_chain_lanes.sh test_stale_ref_close_lanes.sh pre-push pre-commit selfcheck.sh session_close_check.sh; do
  /usr/bin/grep -qxF "$s" "$ALLOW" && ng "L2 주제·생산 파일 $s 가 허용 목록에 있다" || ok "L2 $s 는 허용 목록 밖"
done

# ── 허용 목록 거절 · 켬/끔 ──
cat > "$T/not_allowed.sh" <<EOF
. "$H"
lane_stub_env_on "$T/na" gh; echo "rc=\$?"
EOF
mkdir -p "$T/na"; out=$(bash "$T/not_allowed.sh" 2>&1)
case "$out" in *rc=9*HARNESS*|*HARNESS*rc=9*) ok "L3 허용 목록 밖 호출 → rc=9 HARNESS-ERROR" ;; *) ng "L3 거절 안 됨: $out" ;; esac
mkdir -p "$T/al"; cp "$H" "$T/al/lane_stub_env.sh"; printf 'test_fake_lane.sh\n' > "$T/al/lane_stub_env.allow"
cat > "$T/al/test_fake_lane.sh" <<'EOF'
. "$(dirname "$0")/lane_stub_env.sh"
lane_stub_env_on "$1" gh stale-ref || exit 9
echo "gh=$(command -v gh)"; gh pr list --author @me --state open --json number
python3 -c 'print("real-py")'
python3 scripts/stale_ref_scan.py --body x.md; echo "scan_rc=$? scan_out_end"
lane_stub_env_used gh && echo used-gh; lane_stub_env_used stale-ref && echo used-sr
EOF
mkdir -p "$T/on"; out=$(bash "$T/al/test_fake_lane.sh" "$T/on" 2>&1)
case "$out" in *"gh=$T/on/lane_stub_bin/gh"*) ok "L4 켜면 PATH 맨 앞 gh 가 스텁" ;; *) ng "L4 gh 경로: $out" ;; esac
printf '%s\n' "$out" | /usr/bin/grep -qx '\[\]' && ok "L5 gh pr list → []" || ng "L5 gh 출력: $out"
printf '%s\n' "$out" | /usr/bin/grep -qx 'real-py' && ok "L6 다른 python3 호출은 진짜로 넘어간다" || ng "L6 python3 통과 실패: $out"
printf '%s\n' "$out" | /usr/bin/grep -qx 'scan_rc=0 scan_out_end' && ok "L7 stale_ref_scan.py 는 가로채고 출력 0 (체커가 UNMEASURED 를 낸다)" || ng "L7 가로채기: $out"
{ printf '%s' "$out" | /usr/bin/grep -q used-gh && printf '%s' "$out" | /usr/bin/grep -q used-sr; } && ok "L8 호출 기록: gh · stale-ref 둘 다" || ng "L8 기록: $out"
mkdir -p "$T/off"; out=$(FH_LANE_STUB=off bash "$T/al/test_fake_lane.sh" "$T/off" 2>&1)
case "$out" in *"gh=$T/off/lane_stub_bin/gh"*) ng "L9 끈 상태인데 스텁 gh" ;; *) ok "L9 FH_LANE_STUB=off → 스텁 없음" ;; esac
mkdir -p "$T/un"; cat > "$T/al/test_fake_lane.sh" <<'EOF'
. "$(dirname "$0")/lane_stub_env.sh"
lane_stub_env_on "$1" gh || exit 9
lane_stub_env_used gh && echo used || echo unused
EOF
[ "$(bash "$T/al/test_fake_lane.sh" "$T/un")" = unused ] && ok "L10 안 불린 스텁 → used 거짓 (PATH 가림을 잡는 근거)" || ng "L10 used 가 항상 참"

# ── 체커 통합: 스텁 아래 ①-g 는 «UNMEASURED» 이지 «대상 없음»·«깨끗함» 이 아니다 ──
cp "$H" "$T/al/lane_stub_env.sh"
cat > "$T/al/test_fake_lane.sh" <<EOF
. "\$(dirname "\$0")/lane_stub_env.sh"
lane_stub_env_on "\$1" gh stale-ref || exit 9
env -u CLAUDE_CODE_CHILD_SESSION -u CLAUDE_CODE_AGENT bash "$ROOT/scripts/session_close_check.sh" 2>&1 | /usr/bin/grep '①-g'
EOF
mkdir -p "$T/int"; out=$(bash "$T/al/test_fake_lane.sh" "$T/int")
case "$out" in *UNMEASURED*) ok "L11 체커 ①-g = UNMEASURED (스캐너 0회)" ;; *) ng "L11 ①-g 출력: $out" ;; esac
case "$out" in *"대상 없음"*|*"최신을 가리킨다"*) ng "L11b 스텁 아래 ①-g 가 대상 없음/깨끗함으로 읽힌다" ;; *) ok "L11b «대상 없음»·«깨끗함» 문구 없음" ;; esac

# ── ③ 비교기 known-pair ──
cmpf() { python3 "$CMP" files "$T/c_off" "$T/c_rcoff" "$T/c_on" "$T/c_rcon" "$@" >/dev/null 2>&1; echo $?; }
base=$'✅ L1 a 1\n✅ L2 b\n⚠️  ①-g stale-ref: 2 개 id 가 폐기된 버전을 가리킨다\nPASS done'
printf '%s\n' "$base" > "$T/c_off"; printf '%s\n' "$base" > "$T/c_on"; echo 1 > "$T/c_rcoff"; echo 1 > "$T/c_rcon"
[ "$(cmpf)" = 0 ] && ok "C1 같은 출력 → SAME" || ng "C1"
printf '%s\n' "${base/✅ L2 b
/}" > "$T/c_on"; [ "$(cmpf)" = 1 ] && ok "C2 한쪽 단언 누락 → DIFFERENT" || ng "C2"
printf '%s\n' "${base/⚠️  ①-g stale-ref: 2 개 id 가 폐기된 버전을 가리킨다/✅ ①-g stale-ref: 살아있는 Zenodo 인용이 전부 최신을 가리킨다}" > "$T/c_on"
[ "$(cmpf)" = 1 ] && ok "C3 SUPERSEDED>0 → 깨끗함 변이(rc 같음) → DIFFERENT" || ng "C3 비교기가 장식"
printf '%s\n' "$base" > "$T/c_on"; echo 0 > "$T/c_rcoff"; echo 1 > "$T/c_rcon"; [ "$(cmpf)" = 1 ] && ok "C4 종료 0→1 → DIFFERENT" || ng "C4"
echo 1 > "$T/c_rcoff"; echo 3 > "$T/c_rcon"; [ "$(cmpf)" = 1 ] && ok "C5 종료 1→3 → DIFFERENT" || ng "C5"
echo 2 > "$T/c_rcon"; [ "$(cmpf)" = 0 ] && ok "C6 종료 1→2 (같은 부류) → SAME" || ng "C6"
echo 1 > "$T/c_rcon"; : > "$T/c_on"; [ "$(cmpf)" = 3 ] && ok "C7 빈 출력 → HARNESS-ERROR" || ng "C7"
printf '%s\n' "${base/✅ L2 b
/}" > "$T/c_off"; printf '%s\n' "${base/✅ L2 b
/}" > "$T/c_on"; printf '✅ L# b\n' > "$T/man"
[ "$(cmpf --manifest "$T/man")" = 1 ] && ok "C8 양쪽에서 같은 단언 누락 + manifest → DIFFERENT" || ng "C8"
[ "$(cmpf)" = 0 ] && ok "C8b 컨트롤: manifest 없으면 양쪽 누락은 SAME (manifest 가 있어야 잡힌다)" || ng "C8b"

echo
echo "── lane-stub-env lanes: PASS=$PASS FAIL=$FAIL ──"
[ "$FAIL" -eq 0 ]

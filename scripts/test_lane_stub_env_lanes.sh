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
leaks() {  # $1=검색 루트 → 허용 목록·예외 밖에서 lane_stub_env 를 «언급» 하는 파일 (source 형태를 쫓지 않는다:
           # 변수 경유 `. "$H"` · 확장자 없는 훅도 잡힌다 — codex 구현 R1 A2)
  /usr/bin/grep -rl 'lane_stub_env' "$1" 2>/dev/null | while read -r f; do
    b=$(basename "$f"); rel="${f#"$ROOT"/}"   # 허용은 레포 상대 «경로» 로 — 이름 충돌을 막는다(codex 구현 R10)
    case "$rel" in scripts/lane_stub_env.sh|scripts/lane_stub_env.allow|scripts/test_lane_stub_env_lanes.sh) continue ;; esac
    /usr/bin/grep -qxF "$rel" "$ALLOW" && continue
    if [ "$rel" = scripts/selfcheck.sh ] || [ "$b" = selfcheck.sh ]; then   # 레인 등록부 줄만 허용
      # 줄 «전체» 가 등록부 문법이어야 한다 — 뒤에 `; . lane_stub_env.sh` 를 붙인 줄은 누출 (codex 구현 R2 A2)
      /usr/bin/grep 'lane_stub_env' "$f" | /usr/bin/grep -vqE '^[[:space:]]*"scripts/lane_(stub_env\.(sh|allow)|onoff_compare\.py)\|scripts/test_lane_stub_env_lanes\.sh"[[:space:]]*\\?$' || continue
    fi
    echo "$f"
  done
}
L=$(leaks "$ROOT/scripts"; leaks "$ROOT/templates")
[ -z "$L" ] && ok "L1 누출 없음: 허용 목록 밖에서 source 하는 파일 0" || ng "L1 누출: $L"
mkdir -p "$T/leak"; printf '. "$D/lane_stub_env.sh"\n' > "$T/leak/selfcheck.sh"
[ -n "$(leaks "$T/leak")" ] && ok "L1b 컨트롤: 허용 목록 밖 source 를 잡는다" || ng "L1b 누출 검출기가 장식이다"
mkdir -p "$T/leak2"; printf 'H="$D/lane_stub_env.sh"\n. "$H"\n' > "$T/leak2/test_x.sh"; printf '#!/bin/sh\n. scripts/lane_stub_env.sh\n' > "$T/leak2/pre-push"
[ "$(leaks "$T/leak2" | wc -l | tr -d ' ')" = 2 ] && ok "L1c 변수 경유 source · 확장자 없는 훅도 잡는다" || ng "L1c: $(leaks "$T/leak2")"
mkdir -p "$T/leak3"; printf '  "scripts/lane_stub_env.sh|scripts/test_lane_stub_env_lanes.sh" \\\n' > "$T/leak3/selfcheck.sh"
[ -z "$(leaks "$T/leak3")" ] && ok "L1d 컨트롤: selfcheck 의 등록부 줄은 누출이 아니다" || ng "L1d 등록부 줄을 누출로 읽는다"
mkdir -p "$T/leak4"; printf '  "scripts/lane_stub_env.sh|scripts/test_lane_stub_env_lanes.sh"; . scripts/lane_stub_env.sh\n' > "$T/leak4/selfcheck.sh"
[ -n "$(leaks "$T/leak4")" ] && ok "L1e 등록부 줄 뒤에 source 를 붙이면 누출이다" || ng "L1e 등록부 접두만 보고 뒤를 놓친다"
for s in scripts/test_session_close_chain_lanes.sh scripts/test_stale_ref_close_lanes.sh templates/.git-hooks/pre-push templates/.git-hooks/pre-commit scripts/selfcheck.sh scripts/session_close_check.sh; do
  /usr/bin/grep -qxF "$s" "$ALLOW" && ng "L2 주제·생산 파일 $s 가 허용 목록에 있다" || ok "L2 $s 는 허용 목록 밖"
done

mkdir -p "$ROOT/templates/.lse_probe_$$"; COL="$ROOT/templates/.lse_probe_$$/test_hook_source_gate_lanes.sh"
printf '. "$ROOT/scripts/lane_stub_env.sh"\n' > "$COL"
[ -n "$(leaks "$ROOT/templates/.lse_probe_$$")" ] && ok "L1f 허용된 이름과 같은 «다른 자리» 파일은 누출이다" || ng "L1f 이름 충돌을 허용한다"
printf '. "%s"\nlane_stub_env_on "%s/colx" gh; echo "rc=$?"\n' "$H" "$T" > "$COL"; mkdir -p "$T/colx"
case "$(bash "$COL" 2>&1)" in *rc=9*) ok "L3b 이름이 같아도 다른 경로의 호출은 rc=9" ;; *) ng "L3b 이름 충돌로 스텁이 켜졌다" ;; esac
rm -rf "$ROOT/templates/.lse_probe_$$"
# ── 허용 목록 거절 · 켬/끔 ──
cat > "$T/not_allowed.sh" <<EOF
. "$H"
lane_stub_env_on "$T/na" gh; echo "rc=\$?"
EOF
mkdir -p "$T/na"; out=$(bash "$T/not_allowed.sh" 2>&1)
case "$out" in *rc=9*HARNESS*|*HARNESS*rc=9*) ok "L3 허용 목록 밖 호출 → rc=9 HARNESS-ERROR" ;; *) ng "L3 거절 안 됨: $out" ;; esac
mkdir -p "$T/al"; cp "$H" "$T/al/lane_stub_env.sh"; printf 'al/test_fake_lane.sh\n' > "$T/al/lane_stub_env.allow"
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
cat > "$T/al/test_fake_lane.sh" <<'EOF2'
. "$(dirname "$0")/lane_stub_env.sh"
lane_stub_env_on "$1" stale-ref || exit 9
python3 -c 'raise SystemExit(1)' scripts/stale_ref_scan.py; echo "argrc=$?"
EOF2
mkdir -p "$T/w2"; out=$(bash "$T/al/test_fake_lane.sh" "$T/w2" 2>&1)
case "$out" in *argrc=1*) ok "L7b 인자 어딘가에 스캐너 이름이 있는 다른 python3 실패는 가로채지 않는다(rc=1 그대로)" ;; *) ng "L7b 다른 실패를 삼켰다: $out" ;; esac
cat > "$T/al/test_fake_lane.sh" <<'EOF2'
. "$(dirname "$0")/lane_stub_env.sh"
lane_stub_env_on "$1" gh stale-ref || exit 9
echo "gh=$(command -v gh)"; gh pr list --author @me --state open --json number
python3 -c 'print("real-py")'
python3 scripts/stale_ref_scan.py --body x.md; echo "scan_rc=$? scan_out_end"
lane_stub_env_used gh && echo used-gh; lane_stub_env_used stale-ref && echo used-sr
EOF2
mkdir -p "$T/off"; out=$(FH_LANE_STUB=off bash "$T/al/test_fake_lane.sh" "$T/off" 2>&1)
case "$out" in *"gh=$T/off/lane_stub_bin/gh"*) ng "L9 끈 상태인데 스텁 gh" ;; *) ok "L9 FH_LANE_STUB=off → 스텁 없음" ;; esac
mkdir -p "$T/un"; cat > "$T/al/test_fake_lane.sh" <<'EOF'
. "$(dirname "$0")/lane_stub_env.sh"
lane_stub_env_on "$1" gh || exit 9
lane_stub_env_used gh && echo used || echo unused
EOF
[ "$(bash "$T/al/test_fake_lane.sh" "$T/un")" = unused ] && ok "L10 안 불린 스텁 → used 거짓 (PATH 가림을 잡는 근거)" || ng "L10 used 가 항상 참"

# L12 스텁 PATH 는 레인 «자식» 프로세스 안에만 산다 — 같은 부모가 다음에 부르는 레인으로 넘어가지 않는다
mkdir -p "$T/inh"; bash "$T/al/test_fake_lane.sh" "$T/inh" >/dev/null 2>&1
case "$(command -v gh 2>/dev/null)" in "$T"/*) ng "L12 부모 셸에 스텁 gh 가 남았다" ;; *) ok "L12 레인이 끝나면 부모 PATH 에 스텁이 없다" ;; esac

# L3c/L3d 상대 경로로 실행된 레인이 cd 한 뒤 source → rc=9 (안내 줄) · 절대 경로 재실행 형태 → 통과
mkdir -p "$T/al/sub"; cat > "$T/al/test_fake_lane.sh" <<'EOF2'
cd "$(dirname "$0")/sub" || exit 1
. ../lane_stub_env.sh
lane_stub_env_on "$1" gh; echo "rc=$?"
EOF2
mkdir -p "$T/rel1"; out=$(cd "$T/al" && bash test_fake_lane.sh "$T/rel1" 2>&1)
case "$out" in *rc=9*"절대 경로로 다시 실행"*|*"절대 경로로 다시 실행"*rc=9*) ok "L3c 상대 실행 + cd 뒤 source → rc=9 와 안내" ;; *) ng "L3c: $out" ;; esac
cat > "$T/al/test_fake_lane.sh" <<'EOF2'
case "$0" in /*) ;; *) exec bash "$(cd "$(dirname "$0")" && pwd -P)/$(basename "$0")" "$@" ;; esac
cd "$(dirname "$0")/sub" || exit 1
. ../lane_stub_env.sh
lane_stub_env_on "$1" gh; echo "rc=$?"
EOF2
mkdir -p "$T/rel2"; out=$(cd "$T/al" && bash test_fake_lane.sh "$T/rel2" 2>&1)
case "$out" in *rc=0*) ok "L3d 절대 경로로 재실행하는 레인은 상대 실행이어도 통과" ;; *) ng "L3d: $out" ;; esac
/usr/bin/grep -q 'case "$0" in /\*) ;; \*) exec bash' "$ROOT/scripts/test_utterance_intake_lanes.sh" \
  && ok "L3e cd 하는 허용 레인(utterance_intake)이 재실행 줄을 갖고 있다" || ng "L3e utterance_intake 에 재실행 줄이 없다"

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

printf '✅ L1 checked\n✅ L2 checked\n' > "$T/c_off"; printf '✅ L1 checked\n✅ L1 checked\n' > "$T/c_on"; echo 0 > "$T/c_rcoff"; echo 0 > "$T/c_rcon"
[ "$(cmpf)" = 1 ] && ok "C9 레인 번호가 다른 단언(L2 사라지고 L1 둘) → DIFFERENT" || ng "C9 정규화가 단언 신원을 지운다"
printf '✅ x\n⚠️ SUPERSEDED=2 UNSCANNABLE=0\n' > "$T/c_off"; printf '✅ x\n⚠️ SUPERSEDED=0 UNSCANNABLE=2\n' > "$T/c_on"
[ "$(cmpf)" = 1 ] && ok "C10 진단 안의 작은 수가 다르다 → DIFFERENT" || ng "C10 진단 수를 지운다"
printf '✅ base\nUNMEASURED scanner\n' > "$T/c_off"; printf '✅ base\nclean scanner\n' > "$T/c_on"
[ "$(cmpf)" = 1 ] && ok "C11 기호 없는 UNMEASURED 줄이 사라짐 → DIFFERENT" || ng "C11 typed 상태 줄을 안 본다"
printf '✅ checked\n' > "$T/c_off"; printf '✅ checked\n' > "$T/c_on"; printf '✅ checked\n✅ checked\n' > "$T/man"
[ "$(cmpf --manifest "$T/man")" = 1 ] && ok "C12 manifest 가 두 번 기대하는데 한 번씩 → DIFFERENT" || ng "C12 manifest 개수 무시"
printf '✅ x\n⚠️ UNSCANNABLE=1000\n' > "$T/c_off"; printf '✅ x\n⚠️ UNSCANNABLE=9999\n' > "$T/c_on"
[ "$(cmpf)" = 1 ] && ok "C14 큰 진단 수가 다르다 → DIFFERENT" || ng "C14 큰 수를 지운다"
printf '✅ /tmp/arm/result:PASS=1\n' > "$T/c_off"; printf '✅ /tmp/arm/result:PASS=0\n' > "$T/c_on"
[ "$(cmpf)" = 1 ] && ok "C15 임시 경로에 붙은 진단이 다르다 → DIFFERENT" || ng "C15 경로 정규화가 진단을 삼킨다"
printf '✅ base\n── lanes: PASS=39 FAIL=0 ──\nCACHED scanner\n' > "$T/c_off"; printf '✅ base\n── lanes: PASS=39 FAIL=0 ──\n' > "$T/c_on"
[ "$(cmpf)" = 1 ] && ok "C16 typed 상태 줄(CACHED) 사라짐 → DIFFERENT" || ng "C16 CACHED 를 안 본다"
printf '✅ base\n── lanes: PASS=38 FAIL=1 ──\nCACHED scanner\n' > "$T/c_on"; printf '✅ base\n── lanes: PASS=39 FAIL=0 ──\nCACHED scanner\n' > "$T/c_off"
[ "$(cmpf)" = 1 ] && ok "C17 줄 안의 요약 필드(PASS=39→38) → DIFFERENT" || ng "C17 요약 필드를 안 본다"
printf '✅ x\n⚠️ pid1_count=1\n' > "$T/c_off"; printf '✅ x\n⚠️ pid2_count=1\n' > "$T/c_on"
[ "$(cmpf)" = 1 ] && ok "C18 pid 꼴 식별자(pid1_count/pid2_count)는 지킨다 → DIFFERENT" || ng "C18 pid 정규화가 식별자를 지운다"
printf 'just text\n' > "$T/c_off"; printf 'just text\n' > "$T/c_on"
[ "$(cmpf)" = 3 ] && ok "C19 단언 없는 출력 → HARNESS-ERROR" || ng "C19"
printf '✅ scanner timeout=45s\n' > "$T/c_off"; printf '✅ scanner timeout=1s\n' > "$T/c_on"
[ "$(cmpf)" = 1 ] && ok "C20 설정값(timeout=45s→1s) → DIFFERENT" || ng "C20 설정값을 지운다"
printf 'BYPASS scanner\n' > "$T/c_off"; printf 'BYPASS scanner\n' > "$T/c_on"
[ "$(cmpf)" = 3 ] && ok "C21 BYPASS 는 단언이 아니다 → HARNESS-ERROR" || ng "C21 낱말 안의 PASS 를 단언으로 센다"
printf '✅ premise: card.md=2026-10-12 14:38:18 vs log.md=2000-01-01 00:00:00\n' > "$T/c_off"
printf '✅ premise: card.md=2026-10-13 09:01:40 vs log.md=2000-01-01 00:00:00\n' > "$T/c_on"
[ "$(cmpf)" = 1 ] && ok "C13 정규화 없음: 픽스처 파일 시각이 다르면 선언 없이는 DIFFERENT" || ng "C13 계기가 스스로 정규화한다"
[ "$(cmpf --volatile '^✅ premise:')" = 0 ] && ok "C13b 휘발 선언(--volatile)한 줄만 빼고 SAME" || ng "C13b 휘발 선언이 안 듣는다"
python3 "$CMP" files "$T/c_off" "$T/c_rcoff" "$T/c_on" "$T/c_rcon" --volatile '^✅ premise:' 2>&1 | /usr/bin/grep -q '^UNMEASURED  휘발 선언 줄 off×1 on×1' \
  && ok "C13c 휘발 선언 줄은 UNMEASURED 로 보고된다(조용히 같다고 하지 않는다)" || ng "C13c 휘발 줄이 보고되지 않는다"
printf '✅ x\n✅ premise: a=2026-10-12 14:38:18\n' > "$T/c_off"   # 휘발 줄 «수» 만 다르다 — 나머지 줄은 같게
printf '✅ x\n✅ premise: a=2026-10-12 14:38:18\n✅ premise: b=2026-10-12 14:38:19\n' > "$T/c_on"
[ "$(cmpf --volatile '^✅ premise:')" = 1 ] && ok "C13d 휘발 선언 줄 «수» 가 다르면 DIFFERENT" || ng "C13d 휘발 줄 수 차이를 놓친다"
printf '✅ scanner timeout=00:00:45\n' > "$T/c_off"; printf '✅ scanner timeout=00:00:01\n' > "$T/c_on"
[ "$(cmpf)" = 1 ] && ok "C22 시각꼴 설정값 → DIFFERENT" || ng "C22"
printf '✅ base\npremise: log.md=2000-01-01 00:00:00\n' > "$T/c_off"; printf '✅ base\npremise: log.md=2001-01-01 00:00:00\n' > "$T/c_on"
[ "$(cmpf)" = 1 ] && ok "C23 고정 기준 날짜가 바뀜 → DIFFERENT" || ng "C23"
printf '✅ base\n value\n' > "$T/c_off"; printf '✅ base\nvalue \n' > "$T/c_on"
[ "$(cmpf)" = 1 ] && ok "C25 공백만 다른 줄 → DIFFERENT (정규화 없음)" || ng "C25 공백을 지운다"
printf '✅ base\nstatus:a\342\200\250status:b\n' > "$T/c_off"; printf '✅ base\nstatus:a\nstatus:b\n' > "$T/c_on"
[ "$(cmpf)" = 1 ] && ok "C26 U+2028 은 줄 경계가 아니다 → DIFFERENT" || ng "C26 U+2028 을 줄로 쪼갠다"
printf '✅ base\nstatus:a\rstatus:b\n' > "$T/c_off"; printf '✅ base\nstatus:a\nstatus:b\n' > "$T/c_on"
[ "$(cmpf)" = 1 ] && ok "C27 파일 입력의 CR 을 바꾸지 않는다 → DIFFERENT" || ng "C27 files 리더가 CR 을 LF 로 바꾼다"
printf '✅ base\r\nx\n' > "$T/c_off"; printf '✅ base\nx\n' > "$T/c_on"
[ "$(cmpf)" = 1 ] && ok "C27b CRLF 도 그대로 → DIFFERENT" || ng "C27b CRLF 를 바꾼다"
mkdir -p "$T/crl"
cat > "$T/crl/lane_cr.sh" <<'EOF3'
if [ "$FH_LANE_STUB" = off ]; then printf '✅ base\nstatus:a\rstatus:b\n'; else printf '✅ base\nstatus:a\nstatus:b\n'; fi
EOF3
python3 "$CMP" run "$T/crl/lane_cr.sh" >/dev/null 2>&1; [ $? = 1 ] && ok "C27c run 캡처도 CR 을 바꾸지 않는다 → DIFFERENT" || ng "C27c run 캡처가 CR 을 바꾼다"
printf '✅ base\nscanner id=\377\n' > "$T/c_off"; printf '✅ base\nscanner id=\376\n' > "$T/c_on"
[ "$(cmpf)" = 1 ] && ok "C28 잘못된 UTF-8 바이트가 다르면 → DIFFERENT (files)" || ng "C28 다른 바이트를 같은 문자로 접는다"
cat > "$T/crl/lane_bad.sh" <<'EOF3'
printf '✅ base\n'; if [ "$FH_LANE_STUB" = off ]; then printf 'scanner id=\377\n'; else printf 'scanner id=\376\n'; fi
EOF3
python3 "$CMP" run "$T/crl/lane_bad.sh" >/dev/null 2>&1; [ $? = 1 ] && ok "C28b run 캡처도 바이트를 지킨다 → DIFFERENT" || ng "C28b run 캡처가 바이트를 접는다"
printf '✅ base\nscanner id=\377\n' > "$T/c_on"
[ "$(cmpf)" = 0 ] && ok "C28c 컨트롤: 같은 잘못된 바이트 → SAME" || ng "C28c"
printf '✅ base\nscanner id=\377\n' > "$T/c_off"; cp "$T/c_off" "$T/c_on"; python3 "$CMP" manifest "$T/c_off" > "$T/man_b"
[ "$(cmpf --manifest "$T/man_b")" = 0 ] && ok "C29 manifest 왕복: 잘못된 바이트 원본 vs 그 manifest → SAME" || ng "C29 manifest 가 바이트를 바꿨다"
printf '✅ base\nscanner id=\\xff\n' > "$T/c_off"; cp "$T/c_off" "$T/c_on"
[ "$(cmpf --manifest "$T/man_b")" = 1 ] && ok "C29b 글자 \\xff 로 바뀐 양팔은 원 바이트 manifest 와 다르다 → DIFFERENT" || ng "C29b 이스케이프 글자와 원 바이트가 충돌한다"
for w in 'PASSIVE scanner' 'FAILURE scanner'; do printf '%s\n' "$w" > "$T/c_off"; printf '%s\n' "$w" > "$T/c_on"
  [ "$(cmpf)" = 3 ] && ok "C24 «${w}» 는 단언이 아니다 → HARNESS-ERROR" || ng "C24 ${w} 를 단언으로 센다"; done

echo
echo "── lane-stub-env lanes: PASS=$PASS FAIL=$FAIL ──"
[ "$FAIL" -eq 0 ]

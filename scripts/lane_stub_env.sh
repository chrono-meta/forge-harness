# lane_stub_env.sh — source 전용. selfcheck 의 «비주제» 레인 안에서만 gh 와 ①-g 스캐너를 스텁한다.
#
# 왜: session_close_check.sh 를 부르는 레인 다섯이 ①-b(gh pr list)·①-g(stale_ref_scan.py)를 진짜로
#   돌렸다 — 네트워크에 기대고, selfcheck 한 번에 gh ≈66s · ①-g ≈39s(P0 측정 2026-10-12). 이 레인들의
#   단언은 ①-b·①-g 결과를 보지 않는다. 설계 = tracks/_meta/design_light_gate_2026-10-12.md §4·§5.
#
# 🟥 생산 체커는 안 고친다 — 스텁은 PATH 앞에 붙는 레인 프로세스 안의 디렉터리일 뿐이고 레인이
#   끝나면 사라진다. 훅·selfcheck 본체·주제 레인은 이 파일을 source 하지 않는다(test_lane_stub_env_lanes.sh 가 막는다).
# 🟥 허용 목록(scripts/lane_stub_env.allow)에 이름이 없는 파일이 부르면 거절한다(rc=9).
#
#   lane_stub_env_on <tmpdir> gh|stale-ref ...   스텁을 켠다. FH_LANE_STUB=off 면 아무것도 안 한다(켠/끈 비교용)
#   lane_stub_env_used gh|stale-ref              그 스텁이 실제로 불렸으면 rc=0 — 안 불렸으면 PATH 가 가려진 것
#
# gh 스텁: 호출을 기록하고 `pr list` 에는 `[]`. ①-g 스텁: python3 를 감싸 stale_ref_scan.py 호출만
#   가로채 아무것도 출력하지 않는다 → 체커는 «UNMEASURED — 스캐너가 판정 줄을 안 냈다» 를 낸다
#   («대상 없음» 과 다른 문구). 나머지 python3 호출은 진짜 python3 로 넘긴다.

lane_stub_env_on() {
  local dir="$1"; shift
  local caller allow
  caller=$(basename "${BASH_SOURCE[1]:-?}")
  allow="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lane_stub_env.allow"
  if ! /usr/bin/grep -qxF "$caller" "$allow" 2>/dev/null; then
    echo "HARNESS-ERROR: lane_stub_env — $caller 는 허용 목록($allow)에 없다" >&2
    return 9
  fi
  LANE_STUB_LOG="$dir/lane_stub_calls.log"; export LANE_STUB_LOG
  : > "$LANE_STUB_LOG"
  [ "${FH_LANE_STUB:-on}" = "off" ] && return 0
  local bin="$dir/lane_stub_bin" kind real_py
  mkdir -p "$bin"
  for kind in "$@"; do
    case "$kind" in
      gh)
        cat > "$bin/gh" <<'EOF'
#!/bin/sh
echo "gh $*" >> "$LANE_STUB_LOG"
case "$1 $2" in "pr list") echo '[]' ;; esac
exit 0
EOF
        chmod +x "$bin/gh" ;;
      stale-ref)
        real_py=$(command -v python3) || { echo "HARNESS-ERROR: lane_stub_env — python3 없음" >&2; return 9; }
        cat > "$bin/python3" <<EOF
#!/bin/sh
for a in "\$@"; do
  case "\$a" in *stale_ref_scan.py) echo "stale-ref \$*" >> "\$LANE_STUB_LOG"; exit 0 ;; esac
done
exec "$real_py" "\$@"
EOF
        chmod +x "$bin/python3" ;;
      *) echo "HARNESS-ERROR: lane_stub_env — 모르는 스텁 '$kind'" >&2; return 9 ;;
    esac
  done
  PATH="$bin:$PATH"; export PATH
}

lane_stub_env_used() {
  [ "${FH_LANE_STUB:-on}" = "off" ] && return 0
  [ -n "${LANE_STUB_LOG:-}" ] && /usr/bin/grep -q "^$1 " "$LANE_STUB_LOG" 2>/dev/null
}

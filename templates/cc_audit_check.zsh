#!/usr/bin/env zsh
# pay-meta-harness — 정기 감사 알림 (zshrc 훅 템플릿)
#
# 터미널을 열 때마다 각 감사 항목의 경과일을 체크하고 기준 초과 시 경고를 출력합니다.
#
# ── 설치 방법 ─────────────────────────────────────────────
#
#   1. .zshrc에 환경변수 설정:
#
#      export PMH_DIR="$HOME/path/to/pay-meta-harness"   # 필수
#      export CC_HUB_DIR="$HOME/path/to/your-cc-hub"    # CC 허브가 있으면
#      export CC_SENTINELS_DIR="$HOME/.cc_sentinels"     # 프로젝트 sentinel (선택)
#
#   2. 아래 중 하나로 함수를 로드:
#
#      a) source "$PMH_DIR/templates/cc_audit_check.zsh"  # 파일 직접 소싱
#      b) 이 파일 내용을 .zshrc에 그대로 붙여넣기          # 독립 실행
#
# ── 자동 실행 (opt-in) ────────────────────────────────────
#
#   기본값은 수동 실행 (_pmh_audit_check 직접 호출).
#   터미널 시작 시 자동 실행하려면 .zshrc에 추가:
#
#      export PMH_AUDIT_AUTO=1
#
# ── sentinel 기반 프로젝트 감사 ───────────────────────────
#
#   분기·월 단위 프로젝트 감사는 sentinel 파일로 추적합니다.
#   감사 완료 후 touch로 갱신하면 경고가 초기화됩니다.
#
#     mkdir -p ~/.cc_sentinels
#     touch ~/.cc_sentinels/my_project_pfd          # 감사 완료 기록
#     export CC_SENTINEL_MY_PROJECT_PFD_DAYS=90     # 90일 기준 설정
#
# ─────────────────────────────────────────────────────────

# mtime 조회 (macOS / Linux 공용)
_pmh_mtime() { stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0; }

_pmh_audit_check() {
  local -a warns=()
  local now
  now=$(date +%s)

  # ① weekly_audit — 7일 기준 (CC_HUB_DIR 설정 시)
  if [[ -n "${CC_HUB_DIR}" && -d "${CC_HUB_DIR}/tracks/_audit" ]]; then
    local aud
    aud=$(ls -t "${CC_HUB_DIR}/tracks/_audit"/weekly_audit_*.md 2>/dev/null | head -1)
    if [[ -n "$aud" ]]; then
      local d=$(( (now - $(_pmh_mtime "$aud")) / 86400 ))
      (( d >= 7 )) && warns+=("weekly_audit ${d}일 경과 → CC 허브 cwd에서 /audit-learnings")
    else
      warns+=("weekly_audit 이력 없음 → CC 허브 cwd에서 /audit-learnings")
    fi
  fi

  # ② frontier_diagnosis — 90일 기준 (CC_HUB_DIR 설정 시)
  if [[ -n "${CC_HUB_DIR}" && -d "${CC_HUB_DIR}/knowledge/shared/harness-core" ]]; then
    local fd
    fd=$(ls -t "${CC_HUB_DIR}/knowledge/shared/harness-core"/harness_frontier_diagnosis_*.md 2>/dev/null | head -1)
    if [[ -n "$fd" ]]; then
      local d=$(( (now - $(_pmh_mtime "$fd")) / 86400 ))
      (( d >= 90 )) && warns+=("frontier_diagnosis ${d}일 경과 → CC 허브 cwd에서 /frontier-status-summary")
    fi
  fi

  # ③ PMH sim Area B — 30일 기준 (PMH_DIR 설정 시)
  if [[ -n "${PMH_DIR}" && -d "${PMH_DIR}/tracks/_meta" ]]; then
    local sim
    sim=$(ls -t "${PMH_DIR}/tracks/_meta"/sim_*.md 2>/dev/null | head -1)
    if [[ -n "$sim" ]]; then
      local d=$(( (now - $(_pmh_mtime "$sim")) / 86400 ))
      (( d >= 30 )) && warns+=("PMH 내부 시뮬 ${d}일 경과 → PMH cwd에서 /sim-conductor Area B")
    fi
  fi

  # ④ 커스텀 sentinel — CC_SENTINELS_DIR 내 파일별 기준 (선택)
  #    파일명 대문자 = 환경변수 키: CC_SENTINEL_{NAME}_DAYS (기본값 90)
  if [[ -n "${CC_SENTINELS_DIR}" && -d "${CC_SENTINELS_DIR}" ]]; then
    for f in "${CC_SENTINELS_DIR}"/*; do
      [[ -f "$f" ]] || continue
      local name="${${f:t}:u}"
      local key="CC_SENTINEL_${name}_DAYS"
      local threshold="${(P)key:-90}"
      local d=$(( (now - $(_pmh_mtime "$f")) / 86400 ))
      (( d >= threshold )) && warns+=("${f:t} sentinel ${d}일 경과 → touch ${f} 으로 갱신")
    done
  fi

  # 출력
  (( ${#warns[@]} == 0 )) && return
  print ""
  print "\033[33m── CC 정기 감사 알림 ────────────────────────────────────\033[0m"
  for w in "${warns[@]}"; do
    print "\033[33m  ⚠  ${w}\033[0m"
  done
  print "\033[33m────────────────────────────────────────────────────────\033[0m"
  print ""
}
[[ "${PMH_AUDIT_AUTO:-0}" == "1" ]] && _pmh_audit_check

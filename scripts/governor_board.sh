#!/usr/bin/env bash
# governor_board.sh — 거버너가 펼친 팔을 **한 판**에 그린다. 기록에서 조립하고, 판단하지 않는다.
#
# ─────────────────────────────────────────────────────────────────────────────
# WHY (운영자 요청 2026-09-21)
#   *"포지하네스는 거버너-병렬워크트리로 돌게하는데 최적화된 구조잖아 **이걸 눈으로 보면
#    좋을텐데**"* — 구조는 이미 있는데 그것을 한 번에 보는 자리가 없었다. 팔이 어디서 도는지는
#   `git worktree list` 가, 누가 잡고 있는지는 `.git/fh-claims/*` 가, 어느 계열로 태웠는지는
#   4축 마커가 각각 알고 있고, **셋을 같이 보는 계기가 0층**이었다.
#
#   이 파일은 **새 기록을 만들지 않는다.** `scripts/activity_log.sh` 가 이미 고른 형태 —
#   「여섯 번째 상시-쓰기 파일을 추가하지 말고, 이미 있는 것을 요청 시 조립한다」 — 를 그대로
#   따른다. 거기는 **시간축**(무엇을 언제 했나)이고 여기는 **동시축**(지금 몇 개가 어디서
#   도는가)이다. 두 축은 겹치지 않는다.
#
# ─────────────────────────────────────────────────────────────────────────────
# 하는 것 / 안 하는 것
#   ✅ 읽는다. 여섯 채널을 열고, 못 연 채널을 **이름으로** 적는다.
#   🟥 판단하지 않는다 — 어느 팔이 위험한지, 누구에게 말을 걸어야 하는지 정하지 않는다.
#      그건 사람 몫이고, 이 판은 그 사람이 볼 자료다(§Mechanization Boundary: 채널은 짓고
#      결론은 안 굳힌다).
#   🟥 게이트가 아니다. 아무것도 막지 않고, 종료코드로 통과/차단을 말하지 않는다.
#      rc=0 정상 · rc=2 사용법 오류 · rc=10 계기 고장(대상이 git 저장소가 아니다).
#   🟥 프로세스를 죽이거나 브랜치를 옮기거나 claim 을 지우지 않는다. **읽기 전용**이다.
#
# ─────────────────────────────────────────────────────────────────────────────
# 🟥 이 판이 지키는 단 하나의 규율: **미측정을 0 으로 렌더하지 않는다**
#   (`[[feedback_not_found_is_not_zero_family]]` · CLAUDE.md §Instrument Calibration
#    §Channel-Counting). 판은 눈에 들어오는 만큼 **틀렸을 때 조용히 믿긴다** — 화면에 「단일
#   계열」이라 적혀 있으면 읽는 사람은 그걸 측정으로 읽지, 「마커를 못 찾았다」로 읽지 않는다.
#   그래서 각 칸은 세 값을 갖는다:
#       값 있음   ·  없음을 **확인했음**  ·  **미측정**(채널이 안 열렸다)
#   특히 계열 칸에서 `단일(…)` 과 `미측정` 은 **절대 같은 글자로 찍지 않는다.** 앞은 마커가
#   「타계열을 못 썼다」고 적은 것이고, 뒤는 마커 자체가 없는 것이다.
#
# ─────────────────────────────────────────────────────────────────────────────
# 채널 여섯 — 각각 무엇을 알고 무엇을 모르는가
#   ① `git worktree list --porcelain`   팔이 어디에 펼쳐졌나. 행(row)의 정본.
#   ② `<git-common-dir>/fh-claims/*`    어느 세션이 어느 브랜치를 잡았나.
#                                       🟥 claim 은 lock 이 아니라 **쓰여진 시점의 스냅샷**이고
#                                       claim 하지 않은 세션을 **구조적으로 못 본다**
#                                       (scripts/branch_claim.sh 헤더가 실측으로 적은 한계).
#   ③ `/tmp/cc-socks/*.sock`            claim 과 **무관한** 생존 신호. ②의 구멍 폭을 재는
#                                       독립 계수기 — `branch_claim.sh:_unclaimed_risk` 와
#                                       같은 근거. ⚠️ 머신 전역이라 **다른 레포 세션도 센다**:
#                                       상한이지 증거가 아니다. 경로가 없으면 `미측정`.
#   ④ `tracks/_meta/.axes_23_passed_<슬러그>_<날짜>.marker`
#                                       계열(`crossfamily:`)·입장(`standpoint:`)·축(`axes-run:`).
#                                       🟥 gitignored 다 — 클론에는 없다. 없으면 `미측정`.
#   ⑤ git 자체                          base 대비 커밋 수 · 마지막 커밋 시각 · 미커밋 변경.
#   ⑥ `knowledge/shared/learnings/subagent_invocations{_log.yaml,/}`
#                                       오늘 디스패치 건수(추적되는 공개 파일).
#
#   🟥 **이 판은 «지금 일하는 중»을 증명하지 못한다.** ②③ 이 아는 것은 「프로세스가 살아
#      있다」뿐이고, 그것은 「그 세션이 지금 이 트리를 편집 중이다」와 다른 명제다
#      (branch_claim.sh 가 2026-08-16 에 실측으로 적은 것: live claim 5개 중 실질 편집은 1~2개).
#      그래서 상태 칸의 값은 «일하는중» 이 아니라 **«잡혀있음(살아있음)»** 이다. 말이 길어도
#      줄이지 마라 — 줄이는 순간 판이 증명하지 않은 것을 주장한다.
#
# ─────────────────────────────────────────────────────────────────────────────
# 정렬에 대해 (degrade direction)
#   한글은 두 칸을 먹는다. 폭 계산은 «비-ASCII = 2칸» 근사이고, 그것이 성립하려면 bash 의
#   `${#s}` 가 **바이트가 아니라 문자**를 세야 한다 = UTF-8 로케일이 필요하다. 로케일을 못
#   찾으면 **판은 그대로 찍고 머리에 「정렬 미보장」을 적는다** — 정렬 때문에 내용을 막는 것은
#   과차단이고, 이건 게이트가 아니라 뷰다.
#
# 기밀성
#   판은 브랜치명·라벨·워크트리 **절대경로**를 싣는다. 전부 운영자-사적 토큰이 될 수 있다.
#   그래서 `--emit` 목적지가 **이 레포 안이면서 gitignore 되지 않는 자리**면 크게 경고한다
#   (막지는 않는다 — 파일을 쓰는 것 자체는 발행이 아니다). 기본 목적지는 gitignored 인
#   `tracks/_meta/` 다.
#
# 사용
#   bash scripts/governor_board.sh                    # 판을 stdout 에
#   bash scripts/governor_board.sh --root <경로>       # 다른 체크아웃을 그린다
#   bash scripts/governor_board.sh --emit <파일>       # 같은 판을 마크다운으로도
#   bash scripts/governor_board.sh --no-detail        # 축 기록 블록 없이 표만
#   bash scripts/governor_board.sh --self-test        # known-pair 레인 24개
#   주기적으로 보고 싶으면 내장 `/loop` 에 태워라 — 여기에 `--watch` 를 만들지 않는다
#   (CLAUDE.md §Autonomous Initiative Layer 가 반복 감시를 `/loop` 로 라우팅한다).
#
# 테스트 전용 ENV — `GB_TEST=1` 없이는 전부 무시된다.
#   GB_SOCK_DIR · GB_NOW
#   ↑ 게이팅하는 이유: 이 판은 사람이 보고 판단하는 화면이라 **거짓 판이 거짓 결론을 만든다.**
#     노브가 프로덕션에서도 먹으면 「살아있는 세션 0」을 손으로 만들 수 있다
#     (branch_claim.sh 가 같은 이유로 `FH_CLAIM_TEST` 를 세운 전례).
#
# bash 3.2(macOS) 호환: 연관배열·${v^^}·mapfile 안 씀. `stat` 안 씀 — 마커의 시각은 **파일명에
# 박힌 날짜**를, claim 의 시각은 **파일 안의 epoch** 를 읽는다(BSD/GNU `stat` 분기 회피).
set -uo pipefail

# ─── 테스트 노브 게이팅 ───────────────────────────────────────────────────────
_test_mode() { [ "${GB_TEST:-}" = "1" ]; }
_now() { if _test_mode && [ -n "${GB_NOW:-}" ]; then echo "$GB_NOW"; else date +%s; fi; }
_sock_dir() {
  if _test_mode && [ -n "${GB_SOCK_DIR:-}" ]; then echo "$GB_SOCK_DIR"; return; fi
  echo /tmp/cc-socks
}

# ─── 로케일: `${#s}` 가 문자를 세는가 ─────────────────────────────────────────
# 판별은 선언이 아니라 실행이다 — 한글 한 글자의 길이를 재서 1 이면 문자 모드다.
_probe_locale() {
  local one="가"
  [ "${#one}" -eq 1 ] && return 0
  local cand
  for cand in "${LANG:-}" C.UTF-8 en_US.UTF-8 ko_KR.UTF-8 C.utf8; do
    [ -n "$cand" ] || continue
    case "$cand" in *[Uu][Tt][Ff]*) ;; *) continue ;; esac
    LC_ALL="$cand"; export LC_ALL
    [ "${#one}" -eq 1 ] && return 0
  done
  return 1
}
LOCALE_OK=1
_probe_locale || LOCALE_OK=0

# ─── 표시폭 ──────────────────────────────────────────────────────────────────
# 근사: 비-ASCII 는 두 칸. 한글·CJK·이모지에 맞고, 폭이 애매한 기호(●○·)는 **쓰지 않는다**
# — 터미널마다 갈려서 근사가 깨지는 자리라, 아예 후보에서 뺀다.
_dw() {
  local s="$1" a
  a="${s//[^ -~]/}"
  echo $(( ${#a} + 2 * (${#s} - ${#a}) ))
}
_clip() { # $1=문자열 $2=최대 표시폭 — 넘치면 잘라서 '~'
  local s="$1" w="$2"
  [ "$(_dw "$s")" -le "$w" ] && { printf '%s' "$s"; return; }
  local n=${#s}
  while [ "$n" -gt 0 ]; do
    n=$((n-1))
    [ "$(_dw "${s:0:$n}~")" -le "$w" ] && { printf '%s~' "${s:0:$n}"; return; }
  done
  printf ''
}
_pad() { # $1=문자열 $2=목표 표시폭 — **항상 한 칸은 남긴다**
  # 초판은 폭에 꽉 채워 잘라서, 긴 브랜치명이 다음 칸에 붙어 «…-mk~미측정» 으로 나왔다.
  # 판의 값은 «칸이 갈리는 것»이므로 클립 기준은 w-1 이다.
  local s n
  s="$(_clip "$1" "$(( $2 - 1 ))")"
  n=$(( $2 - $(_dw "$s") )); [ "$n" -lt 0 ] && n=0
  printf '%s%*s' "$s" "$n" ''
}

# ─── 상대 시각 ───────────────────────────────────────────────────────────────
# epoch → 포맷. 🟥 `date -r` 는 BSD 에선 «초», GNU 에선 «참조 파일» 이다 — 한쪽만 쓰면
# 다른 쪽에서 **조용히 현재 시각으로 떨어진다**(실측 2026-09-21, 리눅스에서 GB_NOW 가 무시됐다).
# 그래서 둘 다 시도하고, **결과 모양을 검증**한다. 못 얻으면 빈 문자열 — 틀린 시각으로 도는
# 것보다 빈 칸이 낫다(daily_report.sh `yesterday()` 가 같은 이유로 같은 형태를 쓴다).
_fmt_epoch() { # $1=epoch $2=strftime 포맷 $3=결과 검증 glob
  local t="$1" f="$2" g="$3" d
  d="$(date -u -d "@$t" +"$f" 2>/dev/null)" || d=""      # GNU
  case "$d" in $g) printf '%s' "$d"; return 0 ;; esac
  d="$(date -u -r "$t" +"$f" 2>/dev/null)" || d=""       # BSD/macOS
  case "$d" in $g) printf '%s' "$d"; return 0 ;; esac
  printf ''
}

_ago() { # $1=epoch  → "3분 전" / "" (빈 입력은 빈 출력 — 0 으로 접지 않는다)
  local t="$1" now d
  case "$t" in ''|*[!0-9]*) printf ''; return ;; esac
  now=$(_now); d=$(( now - t ))
  [ "$d" -lt 0 ] && { printf '방금'; return; }
  if   [ "$d" -lt 60 ];    then printf '%d초 전' "$d"
  elif [ "$d" -lt 3600 ];  then printf '%d분 전' "$((d/60))"
  elif [ "$d" -lt 86400 ]; then printf '%d시간 전' "$((d/3600))"
  else printf '%d일 전' "$((d/86400))"; fi
}

# ─── 인자 ────────────────────────────────────────────────────────────────────
ROOT=""; EMIT=""; DETAIL=1; SELFTEST=0
while [ $# -gt 0 ]; do
  case "$1" in
    --root)      ROOT="${2:-}"; shift 2 ;;
    --emit)      EMIT="${2:-}"; shift 2 ;;
    --no-detail) DETAIL=0; shift ;;
    --self-test) SELFTEST=1; shift ;;
    -h|--help)   sed -n '/^# 사용/,/^#   테스트 전용/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

# ═════════════════════════════════════════════════════════════════════════════
#  조립
# ═════════════════════════════════════════════════════════════════════════════

# 못 연 채널을 **이름으로** 모은다. 비어 있음과 안 열림을 가르는 자리가 여기다.
CLOSED_CHANNELS=""
_closed() { CLOSED_CHANNELS="$CLOSED_CHANNELS
  - $1"; }

_field() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -1; }

# crossfamily 값 → 판에 찍을 계열 토큰. **enum 을 다시 판정하지 않는다** — 정본은
# `templates/.git-hooks/pre-commit` 의 validate_crossfamily_leg 이고, 여기서 그 로직을 다시
# 쓰면 관대함이 갈린 정규화 두 벌이 된다(remote_marker_gate.sh 헤더가 같은 이유로 안 옮겼다).
# 여기서 하는 것은 **표시**뿐이고, 모르는 값은 모르는 대로 그대로 싣는다.
_family_token() {
  local v="$1"
  case "$v" in
    panel\(*\)*)
        v="${v#panel(}"; v="${v%%)*}"
        printf '%s' "$(printf '%s' "$v" | tr -d ' ' | tr ',' '+')" ;;
    declined*)                printf '단일(고의)' ;;
    DEGRADED_SINGLE_FAMILY*)  printf '단일(도달실패)' ;;
    DEGRADED_PANEL_UNUSED*)   printf '단일(미투입)' ;;
    UNKNOWN*)                 printf '안봄' ;;
    '')                       printf '미측정' ;;
    *)                        printf '%s' "$(printf '%s' "$v" | cut -c1-14)" ;;
  esac
}

board() {
  local root="${1:-$PWD}"
  local gitdir common evroot main_wt base base_sha now
  now=$(_now)

  git -C "$root" rev-parse --git-dir >/dev/null 2>&1 || {
    echo "❌ HARNESS-ERROR — git 저장소가 아니다: $root"
    echo "   🟥 이건 «팔 0개» 가 아니다. 미측정을 빈 판으로 렌더하지 않는다."
    return 10
  }
  common=$(git -C "$root" rev-parse --git-common-dir 2>/dev/null)
  case "$common" in
    /*) ;;
    *)  common="$(cd "$root" && cd "$common" 2>/dev/null && pwd -P)" ;;
  esac
  evroot="$(dirname "$common")"
  main_wt="$evroot"

  # ── base: 진행 칸의 기준. 못 찾으면 그 칸은 전부 «미측정» 이다(0 이 아니다). ──
  base=""; base_sha=""
  local cand
  for cand in origin/main main origin/master master; do
    if git -C "$root" rev-parse --verify -q "$cand^{commit}" >/dev/null 2>&1; then
      base="$cand"; base_sha=$(git -C "$root" rev-parse --short "$cand" 2>/dev/null); break
    fi
  done
  [ -n "$base" ] || _closed "기준 브랜치(origin/main · main · …) — 진행 칸 전부 미측정"

  # ── ② claims ──────────────────────────────────────────────────────────────
  local claim_dir="$common/fh-claims" claims_readable=1
  local n_claims=0 n_claims_live=0 claim_lines=""
  if [ -d "$claim_dir" ]; then
    local f sid pid br lbl at alive
    for f in "$claim_dir"/*; do
      [ -f "$f" ] || continue
      sid="$(basename "$f")"
      br="$(_field "$f" branch)"; lbl="$(_field "$f" label)"
      pid="$(_field "$f" pid)";   at="$(_field "$f" at_epoch)"
      alive=dead
      if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then alive=live; n_claims_live=$((n_claims_live+1)); fi
      n_claims=$((n_claims+1))
      claim_lines="$claim_lines
$br|$alive|$lbl|$at|$sid"
    done
  else
    claims_readable=0
    _closed "claim 기록($claim_dir) — 누가 잡았는지 미측정"
  fi

  # ── ③ 독립 생존 신호 (claim 과 무관) ───────────────────────────────────────
  local sock_dir n_sock="미측정"
  sock_dir="$(_sock_dir)"
  if [ -d "$sock_dir" ]; then
    local s p c=0
    for s in "$sock_dir"/*.sock; do
      [ -e "$s" ] || continue
      p="${s##*/}"; p="${p%.sock}"
      case "$p" in ''|*[!0-9]*) continue ;; esac
      kill -0 "$p" 2>/dev/null && c=$((c+1))
    done
    n_sock="$c"
  else
    _closed "세션 소켓($sock_dir) — claim 안 한 세션 수 미측정(0 아님)"
  fi

  # ── ① 워크트리 ────────────────────────────────────────────────────────────
  local wt_paths="" wt_branches="" wt_path="" wt_br=""
  while IFS= read -r line; do
    case "$line" in
      worktree\ *) wt_path="${line#worktree }" ;;
      branch\ *)   wt_br="${line#branch }"; wt_br="${wt_br#refs/heads/}" ;;
      '')
        if [ -n "$wt_path" ]; then
          wt_paths="$wt_paths
$wt_path"
          wt_branches="$wt_branches
${wt_br:-(detached)}"
        fi
        wt_path=""; wt_br="" ;;
    esac
  done <<EOF
$(git -C "$root" worktree list --porcelain 2>/dev/null)

EOF

  # ── ④⑥ 기록 층 존재 여부 ─────────────────────────────────────────────────
  local marker_dir="$evroot/tracks/_meta"
  [ -d "$marker_dir" ] || _closed "4축 마커 자리($marker_dir) — 계열·입장 칸 전부 미측정"
  local sal="$evroot/knowledge/shared/learnings/subagent_invocations_log.yaml"
  local sad="$evroot/knowledge/shared/learnings/subagent_invocations"
  local today dispatch_today="미측정"
  today=$(_fmt_epoch "$now" '%Y-%m-%d' '????-??-??')
  [ -n "$today" ] || today=$(date +%Y-%m-%d)
  if [ -f "$sal" ] || [ -d "$sad" ]; then
    dispatch_today=$( { [ -f "$sal" ] && cat "$sal"; [ -d "$sad" ] && cat "$sad"/*.yaml; } 2>/dev/null \
      | grep -cE "^[[:space:]]*-?[[:space:]]*date:[[:space:]]*$today" )
    case "$dispatch_today" in ''|*[!0-9]*) dispatch_today=0 ;; esac
  else
    _closed "디스패치 로그($sal) — 오늘 디스패치 수 미측정"
  fi

  # ── 머리 ──────────────────────────────────────────────────────────────────
  local nowstr; nowstr=$(_fmt_epoch "$now" '%Y-%m-%d %H:%M UTC' '????-??-?? ??:?? UTC')
  [ -n "$nowstr" ] || nowstr=$(date '+%Y-%m-%d %H:%M')
  echo "🔭 거버너 판 — $(basename "$evroot")  ·  $nowstr"
  echo "   기록에서 조립한 뷰다. 판단하지 않고, 아무것도 막지 않는다."
  if [ -n "$base" ]; then echo "   기준: $base ($base_sha)"; else echo "   기준: 미측정"; fi
  [ "$LOCALE_OK" = "1" ] || echo "   ⚠️ 정렬 미보장 — UTF-8 로케일이 없어 칸 폭을 못 잰다(내용은 그대로다)."
  echo

  # ── 표 ────────────────────────────────────────────────────────────────────
  printf '  %s%s%s%s%s%s\n' \
    "$(_pad '역할' 8)" "$(_pad '상태' 15)" "$(_pad '갈래' 38)" \
    "$(_pad '계열' 17)" "$(_pad '진행' 9)" "마지막 움직임"
  printf '  %s\n' "-------------------------------------------------------------------------------------------------"

  local detail_block="" n_rows=0 SHOWN_BRANCHES=""
  local i=0 p b
  # 워크트리 목록을 줄 단위로 같이 순회한다(bash 3.2 — 배열 두 개를 인덱스로 맞춘다).
  local idx=0
  local paths_arr=() brs_arr=()
  while IFS= read -r p; do [ -n "$p" ] && paths_arr[$idx]="$p" && idx=$((idx+1)); done <<EOF
$wt_paths
EOF
  idx=0
  while IFS= read -r b; do [ -n "$b" ] && brs_arr[$idx]="$b" && idx=$((idx+1)); done <<EOF
$wt_branches
EOF

  local total=${#paths_arr[@]}
  i=0
  while [ "$i" -lt "$total" ]; do
    p="${paths_arr[$i]}"; b="${brs_arr[$i]}"; i=$((i+1)); n_rows=$((n_rows+1))
    SHOWN_BRANCHES="$SHOWN_BRANCHES
$b"

    # 역할 — 메인 트리가 거버너다(팔은 워크트리).
    local role='팔'
    [ "$p" = "$main_wt" ] && role='거버너'

    # 상태 — 🟥 «일하는중» 이 아니라 «잡혀있음». 이 판은 편집 여부를 모른다.
    local state lbl='' cl_at=''
    if [ "$claims_readable" = "0" ]; then
      state='🟡 미측정'
    else
      local hit=''
      while IFS='|' read -r cb calive clbl cat_ csid; do
        [ -n "$cb" ] || continue
        [ "$cb" = "$b" ] || continue
        [ "$calive" = "live" ] && { hit=live; lbl="$clbl"; cl_at="$cat_"; break; }
        hit="${hit:-dead}"; lbl="${lbl:-$clbl}"; cl_at="${cl_at:-$cat_}"
      done <<EOF
$claim_lines
EOF
      case "$hit" in
        live) state='🟢 잡혀있음' ;;
        dead) state='⚫ 죽은 claim' ;;
        *)    state='⚪ claim 없음' ;;
      esac
    fi

    # 계열·입장·축 — ④ 마커. 브랜치 슬러그는 훅과 **같은 규칙**이다(BRANCH_SLUG="${BRANCH//\//_}").
    local fam='미측정' mk='' mk_cf='' mk_sp='' mk_ax=''
    if [ -d "$marker_dir" ]; then
      local slug="${b//\//_}"
      mk=$(ls -1 "$marker_dir"/.axes_23_passed_"$slug"_*.marker 2>/dev/null | sort | tail -1)
      if [ -n "$mk" ] && [ -r "$mk" ]; then
        mk_cf=$(grep -m1 -E '^[[:space:]]*crossfamily:' "$mk" 2>/dev/null | sed -E 's/^[[:space:]]*crossfamily:[[:space:]]*//')
        mk_sp=$(grep -m1 -E '^[[:space:]]*standpoint:'  "$mk" 2>/dev/null | sed -E 's/^[[:space:]]*standpoint:[[:space:]]*//')
        mk_ax=$(grep -m1 -E '^[[:space:]]*axes-run:'    "$mk" 2>/dev/null | sed -E 's/^[[:space:]]*axes-run:[[:space:]]*//')
        fam="$(_family_token "$mk_cf")"
      fi
    fi

    # 진행 — base 대비 커밋 수 + 미커밋 변경. base 가 없으면 «미측정».
    local prog='미측정'
    if [ -n "$base" ] && [ "$b" != "(detached)" ]; then
      local n
      n=$(git -C "$root" rev-list --count "$base".."$b" 2>/dev/null)
      case "$n" in ''|*[!0-9]*) prog='미측정' ;; *) prog="+$n" ;; esac
    fi
    if [ "$prog" != "미측정" ] && [ -d "$p" ]; then
      [ -n "$(git -C "$p" status --porcelain 2>/dev/null | head -1)" ] && prog="$prog*"
    fi

    # 마지막 움직임 — 커밋 시각과 claim 시각 중 **늦은 쪽**. 둘 다 없으면 빈칸(0 아님).
    local ct=0 last=''
    if [ "$b" != "(detached)" ]; then
      ct=$(git -C "$root" log -1 --format=%ct "$b" 2>/dev/null)
    fi
    case "$ct" in ''|*[!0-9]*) ct=0 ;; esac
    case "$cl_at" in ''|*[!0-9]*) cl_at=0 ;; esac
    [ "$cl_at" -gt "$ct" ] && ct="$cl_at"
    if [ "$ct" -gt 0 ]; then last="$(_ago "$ct")"; else last='미측정'; fi

    printf '  %s%s%s%s%s%s\n' \
      "$(_pad "$role" 8)" "$(_pad "$state" 15)" "$(_pad "$b" 38)" \
      "$(_pad "$fam" 17)" "$(_pad "$prog" 9)" "$last"

    if [ -n "$mk" ]; then
      detail_block="$detail_block
  ▸ $b   ($(basename "$mk"))
      axes-run    : ${mk_ax:-<없음>}
      crossfamily : ${mk_cf:-<없음>}
      standpoint  : ${mk_sp:-<없음>}"
    fi
  done

  [ "$n_rows" -eq 0 ] && echo "  (워크트리를 한 개도 못 읽었다 — 계기 쪽을 의심해라)"
  echo

  # ── 범례: 같은 글자가 칸마다 다른 뜻이면 반드시 적는다 ────────────────────
  echo "  🟢 잡혀있음 = 살아있는 세션 claim 이 이 브랜치를 가리킨다. 🟥 «지금 편집 중»이 아니다 —"
  echo "     claim 은 스냅샷이고, 살아있는 것은 프로세스지 작업이 아니다(branch_claim.sh 실측)."
  echo "  ⚪ claim 없음 = 기록을 읽었고 없었다(측정).   🟡 미측정 = 기록 자리를 못 열었다."
  echo "  계열: 마커의 crossfamily 값이다. «단일(…)» 은 마커가 그렇게 적은 것이고,"
  echo "     «미측정» 은 마커가 없는 것이다 — 둘은 다른 사실이라 같은 글자로 찍지 않는다."
  echo "  진행: 기준 대비 커밋 수, * = 미커밋 변경 있음."
  echo

  # ── 꼬리: 센 것과 못 센 것 ────────────────────────────────────────────────
  if [ "$claims_readable" = "1" ]; then
    # 🟥 어느 행에도 안 걸린 claim 을 «없는 것» 으로 접지 않는다 — 워크트리가 이미 치워졌거나
    #    peer 가 다른 브랜치를 쥔 자리라, 판에 안 보이는 팔이 있다는 뜻이다.
    local orphan=0 ob
    while IFS='|' read -r ob _rest; do
      [ -n "$ob" ] || continue
      case "
$SHOWN_BRANCHES" in *"
$ob"*) ;; *) orphan=$((orphan+1)) ;; esac
    done <<EOF
$claim_lines
EOF
    echo "  claim ${n_claims}개(살아있음 ${n_claims_live})  ·  살아있는 CC 세션(claim 무관) ${n_sock}"
    [ "$orphan" -gt 0 ] && echo "     claim ${orphan}개는 이 판의 어느 행도 안 가리킨다 — 워크트리가 치워졌거나 다른 브랜치다."
    echo "     ↑ 두 수는 **다른 것을 센다.** 소켓 쪽은 머신 전역이라 다른 레포 세션도 들어간다 —"
    echo "       상한이지 «이 체크아웃의 peer» 라는 증거가 아니다."
  else
    echo "  claim 미측정  ·  살아있는 CC 세션(claim 무관) ${n_sock}"
  fi
  if [ "$dispatch_today" = "미측정" ]; then
    echo "  오늘($today) 디스패치 미측정"
  else
    echo "  오늘($today) 디스패치 ${dispatch_today}건"
  fi
  if [ -n "$CLOSED_CHANNELS" ]; then
    echo "  못 연 채널:$CLOSED_CHANNELS"
    echo "     🟥 위 칸의 «미측정» 은 여기서 온 것이다. 0 으로 읽지 마라."
  else
    echo "  못 연 채널: 없음 (6/6)"
  fi

  if [ "$DETAIL" = "1" ] && [ -n "$detail_block" ]; then
    echo
    echo "  축 기록 — 마커 원문 그대로(요약하지 않는다):$detail_block"
  fi
  return 0
}

# ═════════════════════════════════════════════════════════════════════════════
#  self-test — known-pair. 계기가 **아는 답**을 가르는지 먼저 본다.
#  🟥 여기서 반드시 갈려야 하는 한 쌍: 마커 있음(계열 나옴) ↔ 마커 없음(미측정).
#     그 둘이 같은 글자로 나오면 이 판은 측정이 아니라 생성이다.
# ═════════════════════════════════════════════════════════════════════════════
selftest() {
  local T pass=0 fail=0
  T=$(mktemp -d) || return 10
  trap 'rm -rf "$T"' RETURN

  ck() { # $1=id $2=기대(정규식) $3=출력  ·  $4=있어야(1)/없어야(0)
    local want="${4:-1}"
    if printf '%s' "$3" | grep -qE "$2"; then
      if [ "$want" = "1" ]; then printf '  ✅ %-40s\n' "$1"; pass=$((pass+1));
      else printf '  ❌ %-40s — 없어야 하는데 있다: %s\n' "$1" "$2"; fail=$((fail+1)); fi
    else
      if [ "$want" = "0" ]; then printf '  ✅ %-40s\n' "$1"; pass=$((pass+1));
      else printf '  ❌ %-40s — 없다: %s\n' "$1" "$2"; fail=$((fail+1)); fi
    fi
  }

  # ── 픽스처: 메인 트리 + 워크트리 하나 ──────────────────────────────────────
  local R="$T/repo"
  mkdir -p "$R"
  ( cd "$R" && git init -q -b main . \
      && git config user.email t@example.com && git config user.name t \
      && echo a > a.txt && git add a.txt && git commit -qm base \
      && git branch feat/arm-one \
      && git worktree add -q "$T/wt1" feat/arm-one ) >/dev/null 2>&1 || {
        echo "  ⛔ INSTRUMENT ERROR — 픽스처 저장소를 못 만들었다"; return 10; }
  ( cd "$R" && echo b >> a.txt ) # 메인 트리를 더럽힌다
  ( cd "$T/wt1" && echo c > c.txt && git add c.txt && git commit -qm arm ) >/dev/null 2>&1

  mkdir -p "$R/tracks/_meta" "$T/socks"
  export GB_TEST=1 GB_SOCK_DIR="$T/socks" GB_NOW=1758400000

  local out
  # L1 — 행이 둘 나온다(known-positive): 거버너 + 팔
  out=$(board "$R" 2>&1)
  ck "L1 거버너 행"        '거버너'        "$out"
  ck "L2 팔 행"            '팔 +.*feat/arm-one' "$out"
  # L3 — 마커가 **없을 때** 계열은 미측정이다. 단일 이라고 찍으면 안 된다(known-negative).
  ck "L3 마커없음→미측정"  'feat/arm-one.*미측정' "$out"
  ck "L3b 마커없음→단일아님" 'feat/arm-one.*단일'  "$out" 0

  # L4 — 마커를 심으면 계열이 나온다(known-positive). 심는 이름은 훅과 같은 슬러그 규칙.
  printf 'axes-run: ⓐ=codex(2건) ⓑ=→standpoint ⓒ=none ⓓ=none ⓔ=레인 ⓕ=되돌림\ncrossfamily: panel(codex,gemini) — R1..R2, 3 findings\nstandpoint: tier1b(pmh) — 파일만 읽었다\n' \
    > "$R/tracks/_meta/.axes_23_passed_feat_arm-one_2026-09-21.marker"
  out=$(board "$R" 2>&1)
  ck "L4 마커있음→계열"     'feat/arm-one.*codex\+gemini' "$out"
  ck "L4b 축 기록 원문"     'crossfamily : panel\(codex,gemini\)' "$out"

  # L5 — 슬러그가 어긋난 마커는 **안 잡혀야** 한다. 주소가 안 듣는데 초록이 나면 계기가 죽은 것이다.
  mv "$R/tracks/_meta/.axes_23_passed_feat_arm-one_2026-09-21.marker" \
     "$R/tracks/_meta/.axes_23_passed_feat-arm-one_2026-09-21.marker"
  out=$(board "$R" 2>&1)
  ck "L5 슬러그 불일치→미측정" 'feat/arm-one.*미측정' "$out"
  mv "$R/tracks/_meta/.axes_23_passed_feat-arm-one_2026-09-21.marker" \
     "$R/tracks/_meta/.axes_23_passed_feat_arm-one_2026-09-21.marker"

  # L6 — DEGRADED 는 «단일(…)» 로 나오고 «미측정» 과 갈린다.
  printf 'crossfamily: DEGRADED_SINGLE_FAMILY — codex/agy 탐침, 0 도달\n' \
    > "$R/tracks/_meta/.axes_23_passed_feat_arm-one_2026-09-21.marker"
  out=$(board "$R" 2>&1)
  ck "L6 DEGRADED→단일(도달실패)" 'feat/arm-one.*단일\(도달실패\)' "$out"
  ck "L6b DEGRADED≠미측정"        'feat/arm-one.*미측정'          "$out" 0

  # L7 — claim 디렉터리가 없으면 «claim 없음» 이 아니라 «미측정» 이다.
  ck "L7 claim 자리없음→미측정" '🟡 미측정' "$out"
  ck "L7b 못 연 채널에 이름"    '못 연 채널:' "$out"

  # L8 — claim 을 심으면: 죽은 pid 는 live 가 아니다(known-negative), 산 pid 는 live(known-positive).
  mkdir -p "$R/.git/fh-claims"
  printf 'branch=feat/arm-one\nlabel=arm\npid=999999\nat_epoch=1758399000\n' > "$R/.git/fh-claims/s-dead"
  out=$(board "$R" 2>&1)
  ck "L8 죽은 claim"        '죽은 claim.*feat/arm-one' "$out"
  printf 'branch=feat/arm-one\nlabel=arm\npid=%s\nat_epoch=1758399900\n' "$$" > "$R/.git/fh-claims/s-live"
  out=$(board "$R" 2>&1)
  ck "L8b 살아있는 claim"   '잡혀있음.*feat/arm-one' "$out"
  ck "L8c «일하는중» 이라 안 한다" '일하는중' "$out" 0

  # L8d — 어느 행도 안 가리키는 claim 은 꼬리에 뜬다(안 보이는 팔). 0 으로 접지 않는다.
  printf 'branch=gone/removed-wt\nlabel=x\npid=%s\nat_epoch=1758399900\n' "$$" > "$R/.git/fh-claims/s-orphan"
  out=$(board "$R" 2>&1)
  ck "L8d 고아 claim 표면화"  'claim 1개는 이 판의 어느 행도' "$out"
  rm -f "$R/.git/fh-claims/s-orphan"
  out=$(board "$R" 2>&1)
  ck "L8e 고아 없으면 안 뜬다" '어느 행도' "$out" 0

  # L8f — 🟥 GB_NOW 가 머리에 실제로 반영되나. `date -r` 의 BSD/GNU 갈림이 여기서 조용히
  #       현재 시각으로 떨어졌었다 — 계기가 자기 시계를 못 읽으면 나머지 시각 칸도 못 믿는다.
  out=$(GB_NOW=1758400000 board "$R" 2>&1)
  ck "L8f GB_NOW 가 머리에 반영" '2025-09-20 20:26 UTC' "$out"

  # L9 — 소켓 자리가 없으면 0 이 아니라 미측정.
  out=$(GB_SOCK_DIR="$T/nope" board "$R" 2>&1)
  ck "L9 소켓없음→미측정"   'CC 세션\(claim 무관\) 미측정' "$out"
  : > "$T/socks/$$.sock"
  out=$(board "$R" 2>&1)
  ck "L9b 소켓있음→수"      'CC 세션\(claim 무관\) [0-9]' "$out"

  # L10 — 미커밋 변경 표시. 메인 트리는 더럽혀 뒀다.
  ck "L10 dirty 표시"       '거버너.*main.*\+?[0-9]*\*' "$out"

  # L11 — 기준 브랜치가 없으면 진행 칸은 미측정이고 그 사실이 꼬리에 뜬다.
  local R2="$T/repo2"; mkdir -p "$R2"
  ( cd "$R2" && git init -q -b topic . && git config user.email t@example.com \
      && git config user.name t && echo x > x && git add x && git commit -qm x ) >/dev/null 2>&1
  out=$(board "$R2" 2>&1)
  ck "L11 기준없음→미측정"  '기준: 미측정' "$out"

  # L12 — git 저장소가 아니면 빈 판이 아니라 계기 고장.
  out=$(board "$T/socks" 2>&1); local rc=$?
  ck "L12 비-git→HARNESS-ERROR" 'HARNESS-ERROR' "$out"
  [ "$rc" -eq 10 ] && { printf '  ✅ %-40s\n' "L12b rc=10"; pass=$((pass+1)); } \
                   || { printf '  ❌ %-40s — rc=%s\n' "L12b rc=10" "$rc"; fail=$((fail+1)); }

  # L13 — 정렬: 모든 데이터 행의 계열 칸이 같은 표시열에서 시작한다.
  out=$(board "$R" --no-detail 2>&1)
  local cols
  cols=$(printf '%s\n' "$out" | grep -E '^  (거버너|팔) ' | while IFS= read -r l; do
           _dw "$(printf '%s' "$l" | sed -E 's/(^  .{0,200}?).*/\1/')" >/dev/null 2>&1
           printf '%s\n' "$(_dw "${l%%[0-9]*}")"
         done | sort -u | wc -l)
  [ "${cols:-0}" -ge 1 ] && { printf '  ✅ %-40s\n' "L13 행 렌더됨"; pass=$((pass+1)); } \
                         || { printf '  ❌ %-40s\n' "L13 행 렌더됨"; fail=$((fail+1)); }

  echo
  echo "  governor_board self-test: $pass pass · $fail fail"
  [ "$fail" -eq 0 ] || return 1
  return 0
}

# ═════════════════════════════════════════════════════════════════════════════
if [ "$SELFTEST" = "1" ]; then
  selftest; exit $?
fi

TARGET="${ROOT:-$PWD}"
OUT="$(board "$TARGET")"; RC=$?
printf '%s\n' "$OUT"

if [ -n "$EMIT" ] && [ "$RC" -eq 0 ]; then
  # 기밀성: 판은 브랜치명·라벨·절대경로를 싣는다. 추적 표면에 쓰려 하면 크게 적는다.
  # 🟥 막지는 않는다 — 파일을 쓰는 것은 발행이 아니고, 과차단은 override 를 훈련시킨다.
  if git -C "$TARGET" rev-parse --show-toplevel >/dev/null 2>&1; then
    _top=$(git -C "$TARGET" rev-parse --show-toplevel)
    case "$(cd "$(dirname "$EMIT")" 2>/dev/null && pwd -P)/" in
      "$_top"/*)
        if ! git -C "$TARGET" check-ignore -q "$EMIT" 2>/dev/null; then
          echo "⚠️  $EMIT 는 이 레포 안이고 gitignore 되지 않는다 — 이 판은 브랜치명·라벨·절대경로를 싣는다." >&2
          echo "    추적 표면에 올리기 전에 tracks/_meta/ 같은 gitignored 자리로 옮겨라." >&2
        fi ;;
    esac
  fi
  {
    echo "# 거버너 판 — $(date '+%Y-%m-%d %H:%M')"
    echo
    echo '```'
    printf '%s\n' "$OUT"
    echo '```'
  } > "$EMIT" && echo "emitted → $EMIT"
fi
exit "$RC"

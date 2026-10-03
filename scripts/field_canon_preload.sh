#!/usr/bin/env bash
# field_canon_preload.sh — 매핑된 필드 하네스가 언급되면 **그 하네스의 정본 경로**를 띄운다.
#
# WHY (2026-08-09 실측, 하루 4회 정정 · 자력 적발 0):
#   FH 세션 시작 자동 적재는 **FH 자기 정본만** 싣는다(`fh_session_load.sh` = 동반자 저장소).
#   그런데 한 세션이 종일 qasp 를 파면서 qasp `README.md`(604줄) · `docs/governance/`(32개)를
#   **하나도 안 읽고** 코드에서 역추론했다. 네 번 정정당했고 네 번 다 **정본에 답이 있었다**:
#     · MTM 을 "조건부 화이트박스 모드" 로 요약   → 정본은 블박+화박 **동시**(이중시야)
#     · "매트릭스 = 축이 여럿"                  → 영화 매트릭스에서 **네오가 보는 시야**
#     · 3막 본체가 act2 에 있는 걸 배치 결함 판정 → README 가 **의도**라고 명시(L1 공유·중복 0)
#     · 전수조사 모수를 src/act2 로 한정         → b레인·mate 는 모수 밖
#   README 는 그중 하나를 *"이 축이 안 보이면 3막을 mate 판정 전용으로 오해한다"* 로
#   **경고까지 하고 있었다.** 산문 규율로는 안 읽힌다 — `fh_session_load.sh` 헤더가 이미 같은
#   결론을 적었다("prose is salience-dependent"). 같은 처방을 필드 하네스에 적용한다.
#
# WHAT: 프롬프트에 매핑된 프로젝트 이름이 나오면, **실재하는 정본 파일 경로만** 골라 한 번 띄운다.
#   ★ 일반 훈계("정본을 읽어라")가 아니라 **이 레포의 이 파일들**이어야 한다 — 오늘의 실패는
#     규율을 몰라서가 아니라 **그 파일들이 거기 있는 줄 몰라서**였다.
#
# 프로젝트당 세션당 1회. 센티넬로 재나그 방지 — 반복 알림은 무시를 학습시킨다.
#
# 종료: 항상 0 · 보고는 stdout. (비영 종료는 stdout 이 폐기되고 stderr 도 안 전달된다 —
#       `[[feedback_hook_nonzero_exit_is_silent]]`.)
# ── track→repo 해석: 단일 소스 = scripts/fh_track_resolve.sh ──────────────────
# 🟥 강등 블록은 세 소비자(fh_session_load · field_canon_preload · cluster_capability_scan)에
#    **문자 그대로 동일**해야 한다. 2026-08-21 적대검증 HIGH-2: 초판은 파일마다 별칭을
#    1종/2종/3종으로 다르게 봤고, 그건 «강등 경로가 F-1 결함(갈라진 정규화기)의 완전한
#    복제본» 이라는 뜻이었다. 이제 강등은 **별칭 0종 + 큰 소리**다 — 덜 유용하지만
#    세 파일이 같은 답을 내고, 무엇보다 **조용하지 않다**. skipped 를 passed 로 렌더하지
#    않는다는 이 저장소 규율 그대로다. [[feedback_not_found_is_not_zero_family]]
_FH_TRLIB="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/fh_track_resolve.sh"
# shellcheck source=scripts/fh_track_resolve.sh
[ -f "$_FH_TRLIB" ] && . "$_FH_TRLIB"
# 🟥 `type` 는 **존재**만 재고 **정합**은 못 잰다(잘린 파일·구버전·환경에서 export -f 된 동명
#    함수는 전부 통과한다 — 적대검증 LOW-3). 그래서 라이브러리가 API 버전을 선언하고
#    소비자가 그걸 확인한다. 채널을 타입으로 만드는 것이지 성실성에 기대는 게 아니다.
if ! type fh_resolve_track_root >/dev/null 2>&1 || [ "${FH_TRACK_RESOLVE_API:-}" != "1" ]; then
  printf '⚠️  [track-resolve] DEGRADED — fh_track_resolve.sh 부재 또는 API 불일치. 별칭 해석 없음(밑줄→하이픈·-dev 접미 미적용). 이건 «해당 없음»이 아니라 **미해석**이다.\n'
  fh_resolve_track_root() {
    case "${1-}" in '' |*/*|*'|'*|*'..'* ) printf '|ARGS:bad-name'; return 3 ;; esac
    [ -n "${2-}" ] || { printf '|ARGS:empty-root'; return 3; }
    case "${3:-dir}" in
      git) [ -d "$2/$1/.git" ] && { printf '%s|' "$2/$1"; return 0; } ;;
      dir) [ -d "$2/$1" ]      && { printf '%s|' "$2/$1"; return 0; } ;;
      *)   printf '|ARGS:bad-pred'; return 3 ;;
    esac
    printf '%s|UNRESOLVED' "$2/$1"
    return 1
  }
fi

set -uo pipefail

HUB="${CLAUDE_PROJECT_DIR:-${HOME:-}/projects/forge-harness}"
PROJ_ROOT="${FIELD_CANON_PROJECT_ROOT:-${HOME:-}/projects}"
# ★ `${HOME:-}` — `set -u` 아래서 HOME 부재 시 여기가 unbound 로 죽어 rc=1 이 됐다.
#   비영 종료는 stdout 이 폐기되므로 헤더의 "항상 0" 계약이 깨진다(cross-family 지적, 재현됨).
[ -n "${HUB:-}" ] && [ "$HUB" != "/projects/forge-harness" ] || exit 0
# stdin 은 훅 페이로드(JSON). prompt 를 못 뽑아도 **조용히 죽지 않는다** — 원문 전체로 폴백한다.
# ★ `session_id` 를 **같은 페이로드에서** 뽑는다. 센티넬 키가 여기 달려 있다(바로 아래).
# 🟥 SID 는 **자르거나 치환하지 않고 해시한다.** 초판 수리가 슬래시 치환 + 64자 절단이었는데
#    cross-family(gpt-5.5)가 재현했다: 'A/B' 와 'A_B' 가 같은 키 · 65자 이상은 접두 충돌 ·
#    session_id 에 개행이 들어오면 아래 「1행=SID · 2행이후=PROMPT」 프로토콜이 깨져
#    **프롬프트까지 오염**된다(무관 프롬프트로 발화 실증). 원래 버그(전 세션이 한 칸 공유)와
#    **같은 일가를 수리가 다시 연** 것이다. 해시가 충돌·개행·길이·경로문자를 한 번에 없앤다.
# ⚠️ 아래 python 은 **큰따옴표 문자열**이다 — 주석에 백틱을 넣으면 bash 명령치환이 터진다
#    (이 파일에서 실제로 터뜨렸다. 설명은 여기 bash 주석에 둔다).
RAW=$(cat 2>/dev/null || true)
FIELDS=$(printf '%s' "$RAW" | python3 -c "
import json,sys
try:
    d = json.load(sys.stdin)
    import hashlib
    sid = d.get('session_id') or ''
    print(hashlib.sha1(sid.encode('utf-8','surrogatepass')).hexdigest()[:16] if sid else '')
    print(d.get('prompt') or '')
except Exception:
    print(''); print('')
" 2>/dev/null)
SID=$(printf '%s' "$FIELDS" | sed -n '1p')
PROMPT=$(printf '%s' "$FIELDS" | sed -n '2,$p')
[ -n "$PROMPT" ] || PROMPT="$RAW"
[ -n "$PROMPT" ] || exit 0
# ── 프롬프트 상한 — 앞 16,384 **바이트**만 본다 (2026-10-03 3라운드 · 4라운드에 바이트로 확정) ─────
# 이 훅은 UserPromptSubmit 마다 돈다. 2라운드의 bash `${p//코덱/ }` 치환은 bash 3.2 UTF-8 로케일에서
# 입력 길이에 대해 초선형이었다(실측: «코덱스 」 반복 4,096자 0.89초 · 8,192자 6.6초 · 16,384자 52초).
# 그래서 치환은 sed 로 바꿨고(아래), 상한은 그 위의 **두 번째 울타리**다 — tr·sed·case 를 몇 번
# 돌든 비용이 프롬프트 길이에 묶이지 않게 한다.
# 왜 16,384 인가: 이 훅이 찾는 것은 «이 메시지가 발표·매핑 프로젝트를 말하나」이고, 그런 낱말은
# 사람이 쓴 문장의 앞부분에 온다. 16K 바이트는 영문 A4 대여섯 장 · 한글 약 5,400자(A4 두세 장)다 —
# 그보다 뒤에만 낱말이 있는 프롬프트는
# 대개 붙여넣은 로그·코드이고, 거기서 안내가 안 뜨는 것은 **무해한 미탐**(안내 한 줄을 못 받음)이다.
# 오탐(틀린 주장)이나 훅 지연(모든 프롬프트가 기다림)과 달리 아무것도 막지 않는다.
# 단위 = **바이트, 로케일 무관** (4라운드, agy B). 3라운드는 `${PROMPT:0:N}` 을 그대로 써서 UTF-8
#   로케일에선 문자, C 로케일(훅 환경에 LANG 이 없으면 이쪽)에선 바이트였다 — 같은 프롬프트의 창이
#   로케일에 따라 세 배 달랐다. 이제 C 로케일 서브셸에서 자른다(아래 한 줄 · bash 3.2/5 실측: 두 로케일 모두 바이트).
# 갈린 끝 바이트는 **버리지 않는다** — 근거: 판정에 쓰는 모든 낱말(트리거·오탐 목록·프로젝트 이름)은
#   완전한 UTF-8 바이트열이고, 잘린 문자의 앞 1~2 바이트는 어떤 완전한 바이트열도 완성하지 못한다(뒤가
#   없으니까). 그래서 경계에 걸친 낱말은 «안 맞음」이 되고 그건 위의 «무해한 미탐」 그대로다. 잘못된 끝 바이트가
#   있어도 bash case 일치가 두 로케일·두 bash 에서 정상인 것을 실측했다(레인 S10b 가 고정).
# 레인: test_skill_canon_preload_lanes.sh S10(상한 뒤 낱말 미탐) · S10b(바이트 경계 3종) · S11(1MB 시간 상한).
FIELD_CANON_PROMPT_CAP=16384
PROMPT="$(LC_ALL=C; printf '%s' "${PROMPT:0:$FIELD_CANON_PROMPT_CAP}")"

# ── 센티넬 키 — 초판이 여기서 틀렸다 (2026-08-09 첫 실사용 실측으로 수리) ──
# 초판: `${TMPDIR}/fh_field_canon_${CLAUDE_SESSION_ID:-shared}`
#   🟥 **훅 환경에 `CLAUDE_SESSION_ID` 가 없다.** 전 세션이 literal `shared` 한 칸으로 접혔고
#      TMPDIR 는 재부팅까지 산다 → "프로젝트당 **세션당** 1회" 가 실제로는 **"머신당 1회"** 였다.
#      실측: 21:18 의 세션이 qasp 센티넬을 소비 → 21:40 에 실제로 qasp 를 파기 시작한 세션은
#      안내를 **못 받았다**. 이 훅이 막으려던 바로 그 상황에서 침묵했다.
#   ★ 같은 얼굴이 같은 날 다른 스크립트에서도 났다(`branch_claim.sh` 의 `CLAUDE_PID` — 저자 셸엔
#     있고 CI 엔 없어 검사가 무력화). **환경변수 부재가 조용한 폴백으로 접히고 그 폴백이 검사를
#     무력화한다** — 처방은 같다: **페이로드에서 읽고 환경에서 빌리지 않는다.**
#     (`session_id` 는 훅 페이로드 필드다 — `compaction_probe.sh:415` 가 이미 그렇게 읽는다.)
#
# 폴백 방향은 **과다 알림 쪽**이다: 세션을 못 가르면 `$PPID`(CC 프로세스별로 갈린다)로,
# 그것도 없으면 dedup 을 **포기**한다. 침묵보다 중복이 낫다 — 초판 폴백은 조용한 쪽이었고
# 그래서 실패가 안 보였다(`[[feedback_not_found_is_not_zero_family]]`).
# 🟥 **literal 상수로 폴백하지 마라.** 그 순간 전 세션이 한 칸을 공유한다.
if [ -n "${FIELD_CANON_SENTINEL_DIR:-}" ]; then
  SENT_DIR="$FIELD_CANON_SENTINEL_DIR"
elif [ -n "$SID" ]; then
  SENT_DIR="${TMPDIR:-/tmp}/fh_field_canon_sid_${SID}"
elif [ -n "${PPID:-}" ] && [ "${PPID:-0}" != "0" ]; then
  SENT_DIR="${TMPDIR:-/tmp}/fh_field_canon_ppid_${PPID}"
else
  SENT_DIR=""                       # 못 가른다 → dedup 포기(매번 알린다). 침묵 금지.
fi
[ -z "$SENT_DIR" ] || mkdir -p "$SENT_DIR" 2>/dev/null || true

# ── 스킬-정본 분기 (2026-08-29 신설) ─────────────────────────────────────────
# 🟥 왜 «매핑된 프로젝트» 만으로는 부족한가 — 실측이 있다.
#   덱 세션이 `preprep/presentation_checklist.md`(274줄 · A0~M) 와 레인 L1~L6, 용어 파일을
#   **하나도 열지 않고 44판을 구웠다.** 결과: C1 선 굵기 토큰 위반 388/907 = 43%, 그중
#   ~329곳이 그 세션이 **눈대중으로 «발명한» 값**이었다. 그리고 리뷰가 걷어낸 낱말이
#   재유입됐는데 **아무 검사도 안 울렸다**(운영자가 잡았다).
#   🟥 진단이 뒤집힌 자리다: «자산화가 안 됐다» 가 아니라 **«자산은 있는데 안 읽힌다»** 였다.
#   그리고 그 세션의 처방(«진입 트리거를 새로 짓자»)도 반쯤 틀렸다 — 이 훅이 이미 그 기계다.
#   `grep preprep` → 0 · 컨트롤 `grep qasp` → 2 ⇒ 계기는 살아 있고 **커버리지 경계가 빠뜨렸다.**
#   ⇒ 새 트리거를 짓지 않고 **경계를 넓힌다.** 이게 no-reinvention 이 실제로 값을 내는 형태다.
#
# 대상은 «레포» 가 아니라 «허브 안의 스킬»이라 위 해석기(fh_resolve_track_root)를 안 탄다.
# 공유 해석기는 세 소비자가 문자 그대로 같아야 하므로 **건드리지 않고 분기를 덧붙인다.**
# 오탐 정책은 위 루프와 같다: 짧은 낱말의 오탐은 감수한다(세션당 1회라 상한이 한 줄이다).
#
# 🟥 2026-10-03 — 그 «감수」에 한도가 있었다. 단음절 «덱» 이 «코덱스»(Codex)에 부분 일치해,
#    발표 맥락이 전혀 없는 운영자 메시지에 «발표 작업이 언급됐다» 가 떴다(실측). 세션당 1회라
#    상한은 한 줄이지만, 그 한 줄이 **틀린 주장**이고 그 세션의 진짜 발표 안내 기회를 소비한다.
#
#    처방(2라운드, 거버너 결정 — 1라운드의 python `(?<!\w)` 왼쪽 경계를 버렸다):
#    **알려진 오탐 낱말을 먼저 지운 뒤 부분 일치한다.** python 없음 · 판정에 조기 종료 파이프 없음.
#    1라운드 경계가 버려진 이유 셋(교차리뷰 codex·agy):
#      ⓐ python 이 실패하면 부분 일치로 폴백해 «코덱스」 오탐이 그대로 되살아났다
#      ⓑ 폴백의 `printf | grep -q` 가 긴 여러 줄 입력에서 SIGPIPE(141)로 **진짜 트리거를 놓쳤다**
#      ⓒ 왼쪽 경계가 «투자덱 · IR덱 · A덱 · 제안덱」 같은 합성어를 전부 죽였다
#    지우기 방식은 합성어를 살린다(«투자덱」에는 지울 낱말이 없다) — 경계가 아니라 «알려진 오탐」만 친다.
#    대가: 목록에 없는 새 오탐 낱말은 뚫린다. 그래서 목록은 **관측된 것만** 담고, 새로 관측되면 여기 한 줄 추가한다.
#
#    3라운드 수리 둘:
#      · 지우기는 **sed** 로 한다(LC_ALL=C, 바이트 단위 — UTF-8 낱말의 바이트열은 문자 경계에서만 맞는다).
#        2라운드의 bash `${p//낱말/ }` 는 bash 3.2 UTF-8 에서 초선형이었다(위 상한 절의 실측). sed 는
#        입력을 끝까지 읽으므로 SIGPIPE 경로가 없고, 1MB 에 ~0.06초다(실측). sed 가 실패하면 지우지 않은
#        프롬프트로 판정한다 — 과다 알림 방향(이 파일의 폴백 원칙).
#      · «덱스」를 목록에서 뺐다. «피치덱스토리라인 · 투자덱스타일 · IR덱스케치」의 진짜 «덱」을 지웠다
#        (교차리뷰 지목). «코덱스」는 «코덱」이, «인덱스」는 «인덱」이 이미 지운다.
#        명명된 잔여: «덱스터」 같은 «덱」으로 시작하는 다른 낱말은 다시 뜬다 — 관측 0 이라 넣지 않는다.
#
# 오탐 낱말 목록 — **한 곳**. 각 줄 = 관측 근거. 정규식 특수문자가 있어도 아래에서 이스케이프된다.
CANON_FP_WORDS=(
  "코덱"            # 코덱스(Codex)·코덱(codec) — 2026-10-03 실측: «코덱스」 언급에 발표 안내가 떴다
  "인덱"            # 인덱스(index)·인덱싱 — 같은 부류, 1라운드 레인 S6 에서 재현
  "representation"  # «presentation」을 품는다 — 1라운드 자체 점검에서 재현(«knowledge representation」)
)
_canon_lc() { printf '%s' "$1" | LC_ALL=C tr 'A-Z' 'a-z'; }
_canon_scrub() {   # $1 = 소문자화된 프롬프트 → 알려진 오탐 낱말을 공백으로 바꿔 출력. sed 실패 = 원문 그대로.
  _sargs=()
  for _fw in "${CANON_FP_WORDS[@]}"; do
    [ -n "$_fw" ] || continue
    # 낱말도 프롬프트와 **같은 소문자화**를 거친다(4라운드, agy B) — 목록에 대문자가 들어가면
    # 소문자화된 프롬프트에서 영영 안 지워진다(«REPRESENTATION」 류). 레인 S13.
    _fwl="$(_canon_lc "$_fw")"
    _fe="$(printf '%s' "$_fwl" | LC_ALL=C sed 's/[][\.*^$/]/\\&/g')"
    _sargs+=(-e "s/${_fe}/ /g")
  done
  [ "${#_sargs[@]}" -gt 0 ] || { printf '%s' "$1"; return 0; }
  _so="$(printf '%s' "$1" | LC_ALL=C sed "${_sargs[@]}" 2>/dev/null)" || { printf '%s' "$1"; return 0; }
  printf '%s' "$_so"
}
# 프롬프트는 한 번만 소문자화한다. `$(…)` 는 출력을 끝까지 읽고, tr·sed 도 입력을 끝까지 읽는다 —
# 조기 종료하는 소비자가 없으므로 SIGPIPE 경로가 없다.
PROMPT_LC="$(_canon_lc "$PROMPT")"
SKILL_PROMPT="$(_canon_scrub "$PROMPT_LC")"
_canon_word_hit() {   # $1 = 트리거 → rc 0 = 맞음, 1 = 안 맞음. 파이프 없는 부분 일치.
  _wl="$(_canon_lc "$1")"
  # 빈 트리거는 `*""*` 가 되어 **모든 프롬프트에** 맞는다 — 목록에 빈 칸이 끼면 매 세션 오탐(3라운드, agy C).
  [ -n "$_wl" ] || return 1
  case "$SKILL_PROMPT" in *"$_wl"*) return 0 ;; esac
  return 1
}
skill_canon_emit() {
  _sk="$1"; _dir="$HUB/$2"; shift 2
  [ -d "$_dir" ] || return 0
  [ -n "$SENT_DIR" ] && [ -e "$SENT_DIR/skill-$_sk" ] && return 0
  _hit=0
  for _w in "$@"; do
    _canon_word_hit "$_w" && { _hit=1; break; }
  done
  [ "$_hit" -eq 1 ] || return 0
  _lines=""
  for _f in SKILL.md presentation_checklist.md README.md surfaces.example.yaml; do
    [ -f "$_dir/$_f" ] || continue
    _n=$(wc -l < "$_dir/$_f" | tr -d " ")
    _lines="$_lines\n     $_f (${_n}줄)"
  done
  [ -n "$_lines" ] || return 0
  echo ""
  echo "📚 [skill-canon] 발표 작업이 언급됐다 — **눈대중으로 값을 발명하기 전에 이 파일들을 열어라.**"
  echo "  ▸ $_sk  →  $_dir"
  printf "%b\n" "$_lines"
  cat <<'SKEOF'
  ⚠️ 세션당 1회. 실측(2026-08-28): 어느 세션이 이 파일들을 **하나도 안 열고 44판을 구웠고**,
     선 굵기 토큰 위반이 388/907(43%) 났다 — 그중 ~329곳이 그 세션이 발명한 값이다.
     🟥 «자산이 없다» 가 아니라 «있는데 안 읽힌다» 가 이 안내의 존재 이유다.
SKEOF
  [ -z "$SENT_DIR" ] || : > "$SENT_DIR/skill-$_sk" 2>/dev/null || true
}
skill_canon_emit preprep "plugins/fh-preprep/skills/preprep" \
  "발표" "장표" "슬라이드" "덱" "대본" "리허설" "presentation" "keynote"

# 매핑된 프로젝트 = tracks/ 하위 디렉토리(언더스코어 접두는 메타라 제외)
mapped=$(ls -d "$HUB"/tracks/*/ 2>/dev/null | while read -r d; do
  b=$(basename "$d")
  [ "${b#_}" = "$b" ] || continue          # 언더스코어 접두 = 메타 디렉토리, 제외
  printf '%s\n' "$b"
done)
[ -n "$mapped" ] || exit 0

emitted=0
for name in $mapped; do
  # 프롬프트에 이름이 나오는가 (대소문자 무시). 짧은 이름의 오탐은 감수 — 과소보다 낫다.
  # 🟥 2026-10-03 2라운드: `printf "$PROMPT" | grep -qiF` 는 긴 여러 줄 프롬프트에서 grep -q 가 첫 줄
  #    일치로 파이프를 닫으면 printf 가 SIGPIPE 로 죽고(pipefail → 141) «안 맞음」으로 읽혔다 —
  #    **진짜 언급을 놓치는 쪽**(실측: «qasp 보자\n」 + x 1,000,000 → 3/3 MISS). 같은 부류를 스킬 분기와
  #    함께 닫는다: 소문자화한 프롬프트에 대한 case 부분 일치(파이프 없음). 의미는 grep -iF 와 같다(ASCII 대소문자 무시,
  #    리터럴). 오탐 낱말 지우기는 여기 **안** 건다 — 그건 발표 트리거 전용 목록이다.
  _nl="$(_canon_lc "$name")"
  [ -n "$_nl" ] || continue          # 빈 이름 = `*""*` = 모든 프롬프트에 맞는다(방어 — 단어 분할로는 안 생긴다)
  case "$PROMPT_LC" in *"$_nl"*) ;; *) continue ;; esac
  [ -n "$SENT_DIR" ] && [ -e "$SENT_DIR/$name" ] && continue   # 이 세션에서 이미 띄웠다

  # 레포 해석은 scripts/fh_track_resolve.sh 가 단일 소스다 (2026-08-21 F-1).
  # 여기 있던 «이름 그대로 → -dev 접미» 2종은 `tracks/the_bible`(→the-bible)을 **무음으로
  # 버렸다** — 밑줄→하이픈 별칭이 없었기 때문이다. 같은 세션에서 cluster_capability_scan.sh 는
  # 그걸 풀고 있었으므로, 갈라진 정규화기가 «한쪽만 통과하는 입력» 을 만든 형태였다.
  # 술어는 `git` 을 유지한다 — 이 훅은 정본 파일을 읽히므로 실제 레포여야 한다.
  rr=$(fh_resolve_track_root "$name" "$PROJ_ROOT" git)
  repo="${rr%|*}"; rnote="${rr##*|}"
  case "$rnote" in
    UNRESOLVED)  continue ;;
    ARGS:*)
      printf '⚠️  [field-canon] 트랙 이름 «%s» 거부(%s) — «레포 없음» 이 아니라 **전제 파손**이다.\n' \
        "$name" "${rnote#ARGS:}"
      continue ;;
    # 🟥 여럿이 맞으면 고르지 않는다 — 어느 레포의 정본을 실었는지 모르게 되는 게 더 나쁘다.
    #    그러나 **고르지 않는 것과 말하지 않는 것은 다르다** (적대검증 MED-3). 라이브러리가
    #    이 값을 «사람이 매핑을 정리해야 한다» 로 정의했는데 그 판정을 사람에게 안 전달하면
    #    판정이 없는 것과 같다 — 이 훅의 계약은 「항상 exit 0 · stdout 보고」라 말할 자리가 있다.
    AMBIGUOUS:*)
      printf '⚠️  [field-canon] 트랙 «%s» 에 레포가 여럿 맞는다(%s) — 고르지 않았다. 정본을 안 실었으니 «없음»이 아니라 **미해석**이다. 매핑을 정리해라.\n' \
        "$name" "${rnote#AMBIGUOUS:}"
      continue ;;
  esac
  [ -n "$repo" ] || continue

  # **실재하는 것만** 싣는다. 없는 파일을 가리키면 다음 사람이 그 지시를 못 믿게 된다.
  lines=""
  [ -f "$repo/README.md" ] && lines="$lines\n     README.md ($(wc -l < "$repo/README.md" | tr -d ' ')줄) — §구조·§지도 절 먼저"
  [ -f "$repo/CLAUDE.md" ] && lines="$lines\n     CLAUDE.md ($(wc -l < "$repo/CLAUDE.md" | tr -d ' ')줄)"
  gov=$(ls "$repo/docs/governance" 2>/dev/null | wc -l | tr -d ' ')
  [ "${gov:-0}" -gt 0 ] && lines="$lines\n     docs/governance/ — 정본 ${gov}개 (용어·모드·계약의 출처)"
  [ -n "$lines" ] || continue

  if [ "$emitted" -eq 0 ]; then
    echo ""
    echo "📚 [field-canon] 매핑된 필드 하네스가 언급됐다 — **코드 역추론 전에 그쪽 정본을 읽어라.**"
    emitted=1
  fi
  echo "  ▸ $name  →  $repo"
  printf '%b\n' "$lines"
  [ -z "$SENT_DIR" ] || : > "$SENT_DIR/$name" 2>/dev/null || true
done

if [ "$emitted" -eq 1 ]; then
  cat <<'EOF'
  ⚠️ 이 안내는 프로젝트당 세션당 1회다. 2026-08-09 실측: 정본 미독으로 하루 4회 정정,
     자력 적발 0 — 네 번 다 답이 정본에 있었고 그중 하나는 README 가 그 오해를 경고까지 했다.
     ★ 필드 하네스 용어를 일반 개념으로 정규화하지 마라(「MTM=화이트박스 모드」가 그 실패다).
EOF
fi
exit 0

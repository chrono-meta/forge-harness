#!/usr/bin/env bash
# fixture_guard_lib.sh — 레인 픽스처 루트의 **단일 소스** 가드.
#
# tenet: FH-T02 (기계는 비가역 경계와 채널에만 — 여기서는 «쓰기 대상이 실레포인가»라는 경계)
#
# WHY: 2026-08-31, `test_script_caller_ratchet_lanes.sh` 의 `d="$(cd "$d" && pwd)"` 가 빈 값으로
# 붕괴해 `git -C "" ` = **cwd = 라이브 레포**가 됐고, `commit --no-verify` +
# `core.hooksPath=/nonexistent-fixture-hooks` 라 어떤 훅도 안 걸렸다. 실제로 커밋 하나가
# 작업 브랜치에 얹혔다(`lane <lane@example.invalid> "base"`). 열거→회수 0→`reset --mixed` 로 회수.
#
# WHY A LIB (재발명 점검 결과, 2026-08-31 실측):
#   · `hook_source_lib.sh` = SessionStart 페이로드 파서 — **도메인이 다르다**. 여기 붙이면
#     「훅 소스 파싱」 lib 이 픽스처 안전을 겸하게 되어 두 관심사가 한 파일에 산다.
#   · `psa_scan_lib.sh` = public-surface 스캔. 무관.
#   · 레인 12개 전수 조사: `source`/`.` 를 쓰는 파일 **0개** — 공용 레인 lib 이 **없다**.
#   ⇒ 새 파일이 정당하다. 사본을 11벌 두는 것은 «관대함 갈린 중복 정규화» 를 예약하는 것이다.
#
# 🟥 불변식은 «증상»이 아니라 «원인»이다: `[ -n "$d" ]` 는 빈 값만 보고, **비어 있지 않은데
# 실레포를 가리키는** 경우를 못 잡는다. 이 가드가 보는 것은 **「픽스처는 실레포에 쓰지 않는다」**.
#
# 🟥 값을 반환한다(해석된 절대경로). 호출부가 `d="$(fh_fixture_root "$d")"` 로 쓰므로,
# 이 함수가 죽거나 스텁이 되면 `d` 가 비고 **호출 레인이 즉시 빨개진다** — 가드가 장식이 아님을
# 되돌림으로 잴 수 있게 하는 설계다(순수 부작용 가드는 스텁으로 바꿔도 아무도 안 빨개진다).
#
# 사용:
#   . "$(dirname "${BASH_SOURCE[0]}")/fixture_guard_lib.sh"
#   T="$(fh_fixture_root "$(mktemp -d)")"
#
# 이식성: bash 3.2 (stock macOS). `realpath`/`readlink -f` 를 쓰지 않는다 — 둘 다 미보장.
#
# 🟥 **위치 의존이다 — 이 파일은 `scripts/` 에 살아야 한다.** 레포 루트를 `dirname(이 파일)/..`
#    로 계산하므로, 다른 깊이에 복사되면 «레포» 의 의미가 바뀐다. 실측(2026-08-31, 한 변수만
#    바꾼 대조): 임시 루트 바로 밑에 두면 그 부모(`/…/T`)를 레포로 보고 **정상 mktemp 픽스처까지
#    거부**했고, `scripts/` 밑에 두면 통과했다. 방향은 **fail-closed(과차단)** 라 안전하지만,
#    벤더링하면 모든 소비처가 시끄럽게 죽는다 — 옮길 거면 레포 루트 계산을 인자로 받게 바꿔라.

# 🟥 상속된 git 환경을 끊는다 (2026-11-13). `git -C <fixture>` 는 GIT_DIR / GIT_INDEX_FILE /
#    GIT_COMMON_DIR 를 **못 이긴다** — 경로 가드가 통과해도 커밋·인덱스·객체는 export 된 레포로 간다.
#    실측(미끼 레포, test_script_caller_ratchet_lanes.sh): GIT_DIR → «base» 커밋 7개 + 브랜치 이동 +
#    인덱스 교체 · GIT_INDEX_FILE → 미끼의 스테이징 인덱스 덮어씀 · GIT_COMMON_DIR → 객체 39개 기록.
#    목록 = `git rev-parse --local-env-vars` (git 2.50) + GIT_NAMESPACE, **설정 3종(GIT_CONFIG ·
#    GIT_CONFIG_PARAMETERS · GIT_CONFIG_COUNT)은 뺐다** — 어느 레포에 쓰는지를 안 바꾸고, CI 가 `-c safe.directory`
#    같은 걸 거기 싣는다(cross-family codex R1). GIT_CEILING_DIRECTORIES 도 그대로 둔다.
#    🟥 알려진 과차단(의도): TMPDIR 가 어떤 레포의 작업트리 안이면 아직 init 전인 픽스처도 아래 git 확인에서
#    거부된다. init 을 빼먹은 레인이 그 레포에 커밋하는 길이 바로 그것이라 fail-closed 쪽을 택했다.
#    🟥 source 시점에 끊는다: fh_fixture_root 는 `$(…)` 서브셸에서 돌아서 거기서 unset 해도 호출 레인엔 안 남는다.
FH_FIXTURE_GIT_ENV="GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_OBJECT_DIRECTORY GIT_DIR GIT_WORK_TREE GIT_IMPLICIT_WORK_TREE GIT_GRAFT_FILE GIT_INDEX_FILE GIT_NO_REPLACE_OBJECTS GIT_REPLACE_REF_BASE GIT_PREFIX GIT_SHALLOW_FILE GIT_COMMON_DIR GIT_NAMESPACE"
for _fg_v in $FH_FIXTURE_GIT_ENV; do unset "$_fg_v"; done; unset _fg_v

fh_fixture_root() {   # $1 = 후보 픽스처 루트 → stdout: 해석된 절대경로. 위반이면 exit 1.
  [ -n "${1:-}" ] || { echo "FIXTURE-GUARD: empty root — refusing (git -C \"\" would target cwd)" >&2; exit 1; }
  [ -d "$1" ]     || { echo "FIXTURE-GUARD: root does not exist: $1" >&2; exit 1; }
  case "$1" in /|"$HOME") echo "FIXTURE-GUARD: refusing root $1" >&2; exit 1 ;; esac
  _fg_real="$(cd "$1" 2>/dev/null && pwd -P)" || { echo "FIXTURE-GUARD: cannot resolve $1" >&2; exit 1; }
  case "$_fg_real" in /|"$HOME") echo "FIXTURE-GUARD: refusing resolved root $_fg_real" >&2; exit 1 ;; esac
  # 🟥 `BASH_SOURCE[0]` 은 **이 함수가 정의된 파일**(= 이 lib)을 가리킨다. lib 이 scripts/ 에
  #    살므로 `../` 가 레포 루트다. 호출부 위치와 무관하게 같은 답이 나온다 — L4 앵커가 이것을 잰다.
  _fg_repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd -P)" || _fg_repo=""
  if [ -n "$_fg_repo" ]; then
    if [ "$_fg_real" = "$_fg_repo" ]; then
      echo "FIXTURE-GUARD: root IS the live repo ($_fg_real) — refusing" >&2; exit 1
    fi
    case "$_fg_real" in
      "$_fg_repo"/*) echo "FIXTURE-GUARD: root is inside the live repo ($_fg_real) — refusing" >&2; exit 1 ;;
    esac
  fi
  # 🟥 fail-closed 확인: source 시점 scrub 이 되돌려졌거나 뒤에서 다시 export 됐으면 커밋하지 않는다.
  for _fg_v in $FH_FIXTURE_GIT_ENV; do
    if [ -n "$(eval "printf '%s' \"\${$_fg_v+x}\"")" ]; then
      echo "FIXTURE-GUARD: HARNESS-ERROR inherited $_fg_v is set — git -C would write to that repo, not the fixture; refusing" >&2; exit 1
    fi
  done
  # 🟥 git 자신의 답으로 확인: 루트가 이미 git 안이면 그 git dir 은 루트 안에 있어야 한다
  #    (mktemp 디렉터리가 어떤 레포의 작업트리 밑에 있으면 `git -C` 는 그 레포로 간다).
  if _fg_gd="$(git -C "$_fg_real" rev-parse --absolute-git-dir 2>/dev/null)"; then
    _fg_gdr="$(cd "$_fg_gd" 2>/dev/null && pwd -P)" || _fg_gdr="$_fg_gd"
    case "$_fg_gdr" in
      "$_fg_real"/*) ;;
      *) echo "FIXTURE-GUARD: HARNESS-ERROR git resolves $_fg_real to repo $_fg_gdr outside the fixture — refusing" >&2; exit 1 ;;
    esac
  fi
  printf '%s\n' "$_fg_real"
}

# fh_fixture_git_check <dir> — 커밋 직전 확인용. git 이 <dir> 을 어느 레포로 보는지 묻고,
#   그 git dir 이 <dir> 안이 아니면 HARNESS-ERROR(exit 1). 이미 init 된 픽스처에서 쓴다.
fh_fixture_git_check() {
  _fc_real="$(cd "${1:?}" 2>/dev/null && pwd -P)" || { echo "FIXTURE-GUARD: cannot resolve $1" >&2; exit 1; }
  _fc_gd="$(git -C "$_fc_real" rev-parse --absolute-git-dir 2>/dev/null)" || { echo "FIXTURE-GUARD: HARNESS-ERROR $1 is not a git repo" >&2; exit 1; }
  _fc_gdr="$(cd "$_fc_gd" && pwd -P)"
  case "$_fc_gdr" in "$_fc_real"/*) return 0 ;; esac
  echo "FIXTURE-GUARD: HARNESS-ERROR git resolves $1 to $_fc_gdr — not inside the fixture; refusing" >&2; exit 1
}

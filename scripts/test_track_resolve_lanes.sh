#!/usr/bin/env bash
# test_track_resolve_lanes.sh — scripts/fh_track_resolve.sh 의 known-pair 레인.
#
# 이 파일이 있는 이유: 2026-08-21 harness-doctor F-1. track→repo 해석이 세 소비자에 각각
# 다르게 구현돼 `tracks/the_bible` 이 두 소비자에서 **무음 드롭**되고 있었다. 레인은 별칭
# 목록이 닫혀 있는지 · 모호를 고르지 않는지 · UNRESOLVED 를 0 으로 접지 않는지를 잰다.
#
# 🟥 픽스처는 «가장 쉬운 표기» 가 아니라 **실제로 뚫렸던 표기**를 쓴다 — 밑줄 이름(the_bible)이
#    그것이다. 하이픈 이름만 테스트하면 뚫린 축을 안 건드린다.
set -u
LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/fh_track_resolve.sh"
[ -f "$LIB" ] || { echo "❌ lib 없음: $LIB"; exit 1; }
. "$LIB"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ✅ $1"; }
no()  { FAIL=$((FAIL+1)); echo "  ❌ $1 — got: [$2]"; }
want() { # want <label> <expected> <actual>
  if [ "$2" = "$3" ]; then ok "$1"; else no "$1 (expected [$2])" "$3"; fi
}

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
P="$TMP/projects"; mkdir -p "$P"

# ── 픽스처 ────────────────────────────────────────────────────────────────
mkdir -p "$P/plainname/.git"          # 이름 그대로 + git
mkdir -p "$P/withdev-dev/.git"        # `-dev` 별칭만 존재
mkdir -p "$P/under-score/.git"        # 밑줄→하이픈 별칭만 존재 (track 이름은 under_score)
mkdir -p "$P/nogit"                   # 디렉토리는 있고 .git 없음 — 술어 분기용
mkdir -p "$P/ambi" "$P/ambi-dev"      # 정확 일치 + 별칭 → exact match wins (pmh-dev #80 B안)
# 🟥 정확 일치가 **없는** 모호 — 이 픽스처가 「exact match wins」와 「first match wins」를 가른다.
#    후보는 my_repo(없음) · my_repo-dev(있음) · my-repo(있음). 넓은 규약이었다면 my_repo-dev 를
#    조용히 골랐을 자리이고, 좁은 규약은 여기서 AMBIGUOUS 를 유지한다.
mkdir -p "$P/my_repo-dev" "$P/my-repo"

echo "── 1. 별칭 3종이 각각 맞는가 (닫힌 목록) ──"
want "plain: 이름 그대로, note 비어야"      "$P/plainname|"                 "$(fh_resolve_track_root plainname "$P" dir)"
want "alias -dev"                          "$P/withdev-dev|alias:withdev-dev" "$(fh_resolve_track_root withdev "$P" dir)"
want "alias _→-  (실제로 뚫렸던 표기)"      "$P/under-score|alias:under-score" "$(fh_resolve_track_root under_score "$P" dir)"

echo "── 2. 정확 일치는 이기고, 정확 일치가 «없으면» 여전히 고르지 않는다 ──"
# 2-a (2026-09-14, pmh-dev #80 B안): 한 노드에 `~/projects/<name>` + `~/projects/<name>-dev` 공존.
want "2-a exact match wins — 별칭이 같이 있어도 정확 일치가 이긴다" "$P/ambi|" "$(fh_resolve_track_root ambi "$P" dir)"
# 2-b 🟥 좁힌 규약의 반례 — 이 레인이 「exact match wins」와 「first match wins」를 가른다.
#     넓은 규약이면 여기서 my_repo-dev 가 조용히 뽑힌다. 그건 이 가드의 존재 이유 그 자체다.
got=$(fh_resolve_track_root my_repo "$P" dir)
case "$got" in
  *"|AMBIGUOUS:"*) ok "2-b 정확 일치가 없으면 AMBIGUOUS 유지 — 조용히 첫째를 고르지 않음" ;;
  *) no "2-b 정확 일치 없는 모호를 골랐다 — 「first match wins」로 넓어졌다" "$got" ;;
esac

echo "── 3. 부재는 UNRESOLVED — «0» 이나 빈 문자열이 아니다 ──"
got=$(fh_resolve_track_root ghost "$P" dir)
case "$got" in
  *"|UNRESOLVED") ok "미해소를 UNRESOLVED 로 표기 (부재 ≠ 0)" ;;
  *) no "UNRESOLVED 여야 한다" "$got" ;;
esac

echo "── 4. 존재 술어는 통일하지 않는다 (소비자별로 다른 게 의도) ──"
want "pred=dir 면 .git 없어도 맞음"  "$P/nogit|"           "$(fh_resolve_track_root nogit "$P" dir)"
got=$(fh_resolve_track_root nogit "$P" git)
case "$got" in
  *"|UNRESOLVED") ok "pred=git 면 .git 없는 디렉토리는 안 맞음" ;;
  *) no "pred=git 은 .git 을 요구해야 한다" "$got" ;;
esac

echo "── 5. known-NEGATIVE — 별칭 목록이 닫혀 있나 (임의 접미를 주워오면 안 된다) ──"
mkdir -p "$P/closed-suffix-test-prod"
got=$(fh_resolve_track_root closed-suffix-test "$P" dir)
case "$got" in
  *"|UNRESOLVED") ok "비등재 접미(-prod)는 안 주워온다 — 목록이 닫혀 있음" ;;
  *) no "닫힌 목록이어야 한다" "$got" ;;
esac

echo "── 6. 종료코드도 판정을 싣는다 (0 해소 · 1 UNRESOLVED · 2 AMBIGUOUS · 3 ARGS) ──"
# 🟥 초판 계약은 «항상 rc=0, 판정은 note 로» 였다. 2026-08-21 cross-family(codex/gpt-5.6-sol)가
#    **실행해서** 반증했다: 종료코드만 읽는 호출자에게 AMBIGUOUS 와 UNRESOLVED 가 **둘 다 성공**
#    으로 보인다(`if fh_resolve_track_root … >/dev/null; then consume; fi`). note 는 그대로 두고
#    rc 를 타입화했다 — 두 채널이 같은 판정을 실으면 어느 쪽만 읽어도 fail-closed 다.
fh_resolve_track_root plainname "$P" dir >/dev/null; want "해소 → rc=0" "0" "$?"
fh_resolve_track_root ghost     "$P" dir >/dev/null; want "UNRESOLVED → rc=1 (성공으로 안 접힌다)" "1" "$?"
fh_resolve_track_root my_repo   "$P" dir >/dev/null; want "AMBIGUOUS → rc=2 (성공으로 안 접힌다)" "2" "$?"
fh_resolve_track_root ambi      "$P" dir >/dev/null; want "exact match wins → rc=0 (모호로 안 떨어진다)" "0" "$?"

echo "── 6-b. 🟥 전제 파손은 «못 찾음» 이 아니다 — ARGS(rc=3). 전부 cross-family 가 실행으로 찾았다 ──"
# ⓐ n="" → 첫 후보가 "" 라 `[ -d "$root/" ]` = `[ -d "/" ]` 가 참이 되던 자리
fh_resolve_track_root ""        "$P" dir >/dev/null; want "빈 이름 → rc=3" "3" "$?"
# ⓑ root="" → `$root/$n` 이 `/foo` 가 되어 **의도한 루트가 아닌 파일시스템 루트**를 봤다
fh_resolve_track_root plainname ""   dir >/dev/null; want "빈 루트 → rc=3" "3" "$?"
# ⓒ 경로 탈출 — `-d` 만 참이면 루트 바깥도 해소됐다. dedup 의 `/` 불변식도 여기서 지켜진다
fh_resolve_track_root "../etc"  "$P" dir >/dev/null; want "상위 탈출 → rc=3" "3" "$?"
fh_resolve_track_root "a/b"     "$P" dir >/dev/null; want "경로 구분자 → rc=3" "3" "$?"
# ⓓ `|` → 직렬화가 깨져 **손상된 결과가 정상 성공으로 승격**되던 자리
fh_resolve_track_root "a|b"     "$P" dir >/dev/null; want "직렬화 구분자 → rc=3" "3" "$?"
# ⓔ pred 오타가 `*)` 로 떨어져 조용히 dir 모드가 됐다 — **오타가 fail-open**
fh_resolve_track_root plainname "$P" gti >/dev/null; want "알 수 없는 술어 → rc=3 (조용히 dir 로 안 떨어진다)" "3" "$?"
# 컨트롤 — 정상 입력이 이 검증들에 안 걸린다(6-b 가 통째로 «전부 거부» 가 아니라는 증거)
# (픽스처 plainname 은 `.git` 을 갖고 만들어졌으므로 pred=git 에서도 해소된다 → rc=0.
#  초판은 여기 기대값을 1 로 썼다가 빨개졌는데, **틀린 것은 대상이 아니라 내 기대**였다.)
fh_resolve_track_root plainname "$P" git >/dev/null; want "컨트롤: pred=git 은 유효한 값이라 거부되지 않는다" "0" "$?"
fh_resolve_track_root nogit     "$P" git >/dev/null; want "컨트롤: pred=git 은 실제로 .git 을 요구한다(ARGS 가 아니라 UNRESOLVED)" "1" "$?"

echo "── 7. fail-before 컨트롤 — 옛 «-dev 접미만» 로직은 밑줄 이름에서 실패했어야 한다 ──"
_old_resolve() { local n="$1" r="$2" c; for c in "$r/$n" "$r/${n}-dev"; do [ -d "$c" ] && { printf '%s' "$c"; return; }; done; printf ''; }
old=$(_old_resolve under_score "$P")
new=$(fh_resolve_track_root under_score "$P" dir)
if [ -z "$old" ] && [ "${new%|*}" = "$P/under-score" ]; then
  ok "옛 로직=무음 드롭(빈 값) / 새 로직=해소 — 레인이 실제 회귀를 잡는다"
else
  no "fail-before 가 성립해야 한다 (옛=빈 값, 새=해소)" "old=[$old] new=[$new]"
fi

echo "── 8. 🟥 회귀 앵커 — 이름에 공백이 있어도 거짓 AMBIGUOUS 가 나면 안 된다 ──"
# 2026-08-21 실측 결함: 구분자가 공백이고 개수를 `wc -w` 로 세면, 실재하는 `a b` 한 건이
# 두 단어로 세어져 AMBIGUOUS 가 났다. 원본 cluster_capability_scan.sh 에서 물려받은 형태다.
# 이 레인이 죽으면 구분자가 공백으로 되돌아간 것이다.
mkdir -p "$P/spaced name"
want "공백 이름 1건은 정상 해소 (거짓 AMBIGUOUS 아님)" "$P/spaced name|" "$(fh_resolve_track_root 'spaced name' "$P" dir)"
# 컨트롤: 진짜 모호는 여전히 발화해야 한다 — 위 레인의 침묵이 공허하지 않다는 증거
# 🟥 컨트롤의 과녁을 `ambi` → `my_repo` 로 옮겼다(2026-09-14). `ambi` 는 이제 exact match wins 로
#    **정상 해소**되므로, 그걸로 «모호 검출이 살아 있나» 를 물으면 컨트롤이 대상과 같이 죽는다.
got=$(fh_resolve_track_root my_repo "$P" dir)
case "$got" in
  *"|AMBIGUOUS:"*) ok "컨트롤: 진짜 모호는 여전히 발화(레인 8 이 모호 검출을 죽인 게 아님)" ;;
  *) no "컨트롤 실패 — 모호 검출이 죽었다" "$got" ;;
esac

echo "── 9. 🟥 배선 레인 — 소비자 스크립트를 실제로 태운다 (레인 1~8 은 함수만 잰다) ──"
# 2026-08-21 적대검증 HIGH-1, **실행으로 확정**: 배선만 되돌리고 라이브러리·레인을 그대로 두면
# 레인 8건 + field_canon 레인 19건이 **전량 초록**이었다. 즉 이 수리가 실제로 고친 것
# («소비자가 밑줄→하이픈 별칭을 본다»)에 대한 앵커가 0개였다. 같은 레포의 선례가 이미
# 경고한 형태다 — cluster_capability_scan.sh 가 "함수를 떼어내 재지 않고 실물을 그대로 태운다"
# 고 적어놨는데 이 수리는 정확히 거꾸로 갔다. [[feedback_anchor_can_be_decorative]]
#
# 🟥 픽스처는 **뚫려 있던 표기**를 쓴다: 트랙 `the_bible` ↔ 레포 `the-bible`.
#    기존 field_canon 픽스처는 `qasp`→`qasp-dev` 인데 그건 **옛 코드도 이미 풀던** 별칭이라
#    이 축을 한 번도 안 태운다.
HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/field_canon_preload.sh"
if [ ! -f "$HOOK" ]; then
  echo "  ⏭️  SKIP (field_canon_preload.sh 없음) — 🟥 PASS 가 아니다, 미검사다"
else
  W=$(mktemp -d)
  FHUB="$W/hub"; mkdir -p "$FHUB/tracks/the_bible"
  FPROJ="$W/proj"; mkdir -p "$FPROJ/the-bible/.git"
  printf '# fixture\n' > "$FPROJ/the-bible/README.md"
  wout=$(printf '%s' '{"prompt":"the_bible 이어서 가자","session_id":"WIRE1"}' \
    | env CLAUDE_PROJECT_DIR="$FHUB" FIELD_CANON_PROJECT_ROOT="$FPROJ" \
          FIELD_CANON_SENTINEL_DIR="$W/sent" bash "$HOOK" 2>&1)
  case "$wout" in
    *the-bible*README.md*) ok "소비자(field_canon)가 밑줄→하이픈 트랙의 정본을 실제로 낸다" ;;
    *) no "소비자가 the_bible→the-bible 을 해소해야 한다" "$wout" ;;
  esac
  # 컨트롤: 옛 코드도 풀던 -dev 별칭은 **원래** 되던 것이므로, 위 레인의 통과가
  # 「아무 트랙이나 되는 것」이 아님을 이 컨트롤이 보증한다.
  mkdir -p "$FHUB/tracks/ghosttrack"
  gout=$(printf '%s' '{"prompt":"ghosttrack 가자","session_id":"WIRE2"}' \
    | env CLAUDE_PROJECT_DIR="$FHUB" FIELD_CANON_PROJECT_ROOT="$FPROJ" \
          FIELD_CANON_SENTINEL_DIR="$W/sent2" bash "$HOOK" 2>&1)
  case "$gout" in
    *ghosttrack*) no "컨트롤: 레포가 없는 트랙은 안 나와야 한다" "$gout" ;;
    *) ok "컨트롤: 레포 실물이 없는 트랙은 침묵 (레인 9 의 통과가 공허하지 않다)" ;;
  esac
  rm -rf "$W"
fi

echo "── 10. 🟥 되돌림 프로브 — exact-match-wins 절이 실제로 일하나 ──"
# 그 절을 떼어낸 사본으로 2-a 를 다시 돌린다. AMBIGUOUS 로 **되돌아가야** 그 줄이 앵커다.
_RVD=$(mktemp -d); _RV="$_RVD/rv.sh"
sed -E 's@^  case "\$hits" in$@  case "NEVER_MATCH_ZZZ" in@' "$LIB" > "$_RV"
if /usr/bin/grep -q 'NEVER_MATCH_ZZZ' "$_RV"; then
  if ( unset -f fh_resolve_track_root 2>/dev/null; . "$_RV"
       case "$(fh_resolve_track_root ambi "$P" dir)" in *"|AMBIGUOUS:"*) exit 0 ;; *) exit 1 ;; esac ); then
    ok "10 되돌림: 절을 떼면 2-a 가 AMBIGUOUS 로 돌아온다 — 장식이 아니다"
  else
    no "10 되돌림 실패 — 절을 떼도 여전히 해소된다(다른 것이 하고 있다)" "reverted still resolves"
  fi
else
  no "10 계기 오류 — 되돌림 치환이 안 먹었다(대상 줄 표기가 바뀌었나)" "no substitution"
fi
rm -rf "$_RVD"

echo "── 11. 🟥 degrade 경로(스텁)도 같은 규약인가 ──"
# 라이브러리를 못 읽는 상황에서 peer_resolve 의 스텁이 «정상 실행» 과 다른 답을 내면 안 된다.
_STD=$(mktemp -d)
sed -n '/^type fh_resolve_track_root/,/^}$/p' "$(dirname "$LIB")/adapters/peer_resolve.sh" \
  | sed '1s/^type[^|]*|| //' > "$_STD/stub.sh"
if /usr/bin/grep -q '^fh_resolve_track_root() {' "$_STD/stub.sh"; then
  if ( unset -f fh_resolve_track_root 2>/dev/null; . "$_STD/stub.sh"
       case "$(fh_resolve_track_root ambi "$P" dir)" in *"/ambi|") exit 0 ;; *) exit 1 ;; esac ); then
    ok "11 스텁도 exact match wins — degrade 경로가 다른 답을 안 낸다"
  else
    no "11 스텁이 정본과 갈린다 — 정상/degrade 가 조용히 다른 답" "$( . "$_STD/stub.sh" 2>/dev/null; fh_resolve_track_root ambi "$P" dir )"
  fi
else
  no "11 계기 오류 — 스텁 추출 실패(peer_resolve.sh 의 가드 표기가 바뀌었나)" "no stub extracted"
fi
rm -rf "$_STD"

echo
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0

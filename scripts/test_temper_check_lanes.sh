#!/usr/bin/env bash
# test_temper_check_lanes.sh — templates/temper_check.sh known-pair 앵커.
#
# 왜 이 파일이 생겼나 (2026-09-14, frontier-digest 후보 #1 → 독립 재현으로 참 판정):
# `temper_check.sh` 는 게이트체인 7경로 중 **유일하게 실행 레인이 0** 이었다. 참조 6곳이 전부
# 비실행이고(`selfcheck.sh` 의 `bash -n` 목록 포함), steel-quench SKILL.md 의 T-1 행은 그것을
# `measured` 로 선언하면서 실제로는 **구문 검사에 얹혀 있었다**.
# 🟥 `bash -n` 은 계기가 아니다 — 문법만 보고 exit 0 을 내므로 «전부 통과» 와 구분이 안 된다
# ([[feedback_gate_verification_must_execute]]). 이 파일은 그 자리를 **실행** 으로 바꾼다.
#
# 픽스처 출처 — 합성 문자열이 아니다:
#   base  = templates/PRE-PUBLISH-CHECKLIST.md      (실물, 산문 + 펜스 1쌍)
#   prose = knowledge/shared/harness-core/loop_engineering.md (실물, 펜스 0)
#   fence = plugins/fh-meta/skills/install-wizard/SKILL_detail.md 의 **실제 펜스 블록**
#           — `temper_check.sh:16` 이 이름으로 지목한 바로 그 사고 현장("found run #4,
#           install-wizard")이다. 그 블록 내부에는 `# ` 23줄 · 스텝 2줄 · `|` 6줄이 있어,
#           펜스 제외 분기가 없으면 Δsections/steps/tables 를 정확히 +23/+2/+6 만큼 부풀린다.
#   ⚠️ 줄번호로 뽑지 않는다(드리프트한다) — 유일 앵커 문자열로 블록을 찾는다. 못 찾으면
#      **HARNESS-ERROR(rc=2)**, SKIP 아니다.
#
# 두 층으로 잰다:
#   ① 격리 픽스처 레포(P1/N1/P2/P3/E1*) — 실물 내용으로 만든 **실제 두 커밋 쌍**. CI 의 얕은
#      클론에서도 돈다.
#   ② 이 레포의 **실제 히스토리** 커밋 쌍(L1/L2) — 얕은 클론이면 «SKIP != PASS» 로 크게 찍고
#      통과로 세지 않는다.
#
# 되돌림 프로브(R1): 펜스 제외 분기만 무력화한 **사본** 을 만들어 P2 만 적색이 되는지 본다.
# 실레포 파일을 제자리 편집하지 않는 이유는 둘 — 공유 체크아웃이고, 제자리 편집은
# [[feedback_editing_a_running_bash_script_corrupts_it]] 부류를 예약한다. 대신 3단을 전부 찍는다:
# ① 적용 확인(변이 문자열 존재 + 원 문자열 부재 + diff 가 정확히 1줄) → ② 실행 → ③ 복원 확인
# (출하 파일 해시가 프로브 전후로 동일).
#
# usage: bash scripts/test_temper_check_lanes.sh
# exit:  0 = 전부 통과 · 1 = 레인 실패 · 2 = 계기 오류(HARNESS-ERROR)

set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/fixture_guard_lib.sh"   # 픽스처는 실레포에 쓰지 않는다

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
SUBJECT="$REPO_ROOT/templates/temper_check.sh"
PASS=0; FAIL=0; SKIPPED=0
WORK=""; FIXREPO=""

cleanup() {
  [ -n "$WORK" ] && rm -rf "$WORK"
  [ -n "$FIXREPO" ] && rm -rf "$FIXREPO"
  return 0
}
trap cleanup EXIT

_die() { echo "  ⛔ HARNESS-ERROR: $*" >&2; echo "[temper-check] 계기가 깨졌다 — 레인 결과는 무효다."; exit 2; }
_ok()  { if [ "$2" = 1 ]; then echo "  ✅ $1"; PASS=$((PASS+1)); else echo "  ❌ $1"; FAIL=$((FAIL+1)); fi; }
_eq()  { # name expected actual
  if [ "$2" = "$3" ]; then echo "  ✅ $1 (Δ=$3)"; PASS=$((PASS+1));
  else echo "  ❌ $1 — 기대 «$2», 실제 «$3»"; FAIL=$((FAIL+1)); fi; }

# 출력에서 한 지표의 Δ 칸을 꺼낸다. 행이 없으면 MISSING (0 으로 접지 않는다).
_delta() { printf '%s\n' "$1" | awk -v k="$2" '$1==k{print $4; f=1} END{if(!f) print "MISSING"}'; }
_has_table() { case "$1" in *"=== Wave-T complexity delta"*) return 0;; *) return 1;; esac; }
# 🟥 부호 판별은 반드시 «함수» 로 둔다. `$( case X in +[1-9]*) ... esac )` 는 bash 가 패턴의 `)` 를
#    명령치환 종료로 읽어 구문오류가 난다(실측 2026-09-14, 이 파일 첫 실행에서 9 레인이 그렇게 죽었다).
#    `bash -n` 은 이것을 잡지만, 잡아도 «틀린 판정» 이 아니라 «못 돈다» 이므로 실행이 정본이다.
_is_pos()  { case "$1" in +[1-9]*) return 0;; *) return 1;; esac; }
_is_neg()  { case "$1" in -[1-9]*) return 0;; *) return 1;; esac; }
_is_sign() { case "$2" in "$1"[1-9]*) return 0;; *) return 1;; esac; }   # $1=기대부호 $2=관측값
_b()       { if "$@"; then echo 1; else echo 0; fi; }

echo "[temper-check] known-pair 앵커 — subject: templates/temper_check.sh"

# ── 0. 계기 전제 ────────────────────────────────────────────────────────────
[ -f "$SUBJECT" ] || _die "subject 부재: $SUBJECT"
BASE_SRC="$REPO_ROOT/templates/PRE-PUBLISH-CHECKLIST.md"
PROSE_SRC="$REPO_ROOT/knowledge/shared/harness-core/loop_engineering.md"
FENCE_SRC="$REPO_ROOT/plugins/fh-meta/skills/install-wizard/SKILL_detail.md"
for _f in "$BASE_SRC" "$PROSE_SRC" "$FENCE_SRC"; do
  [ -f "$_f" ] || _die "픽스처 원본 부재: $_f (합성으로 대체하지 않는다)"
done

WORK="$(mktemp -d "${TMPDIR:-/tmp}/temperwork.XXXXXX")" || _die "mktemp 실패"

# 실물 펜스 블록을 «앵커 문자열» 로 뽑는다 — 줄번호는 드리프트한다.
FENCE_ANCHOR='INDEX.md — wiki home (read FIRST at session start)'
awk -v A="$FENCE_ANCHOR" '
  /^[[:space:]]*```/ {
    if (!inb) { inb=1; buf=$0 "\n"; hit=0; next }
    buf = buf $0 "\n"
    if (hit) { printf "%s", buf; exit 0 }
    inb=0; buf=""; next
  }
  inb { buf = buf $0 "\n"; if (index($0, A)) hit=1 }
' "$FENCE_SRC" > "$WORK/fence.md"
[ -s "$WORK/fence.md" ] || _die "앵커 «$FENCE_ANCHOR» 를 담은 펜스 블록을 $FENCE_SRC 에서 못 찾았다"

# 픽스처 «potency» — 뚫리는 표기인지 먼저 증명한다. 이게 0 이면 P2 는 아무 분기도 안 지나간다
# ([[feedback_fixture_must_use_the_breaking_spelling]] · [[feedback_three_reasons_a_lane_is_green]]).
sed '1d;$d' "$WORK/fence.md" > "$WORK/fence_interior.md"
POT_SEC=$(grep -cE '^#{1,6} ' "$WORK/fence_interior.md")
POT_STP=$(grep -cE '^[[:space:]]*([0-9]+\.|[-*] )' "$WORK/fence_interior.md")
POT_TBL=$(grep -cE '^\|' "$WORK/fence_interior.md")
echo "  · 픽스처 potency — 펜스 «내부» 의 마크다운 위장 줄: 제목 $POT_SEC · 스텝 $POT_STP · 표 $POT_TBL"
[ "$POT_SEC" -gt 0 ] && [ "$POT_STP" -gt 0 ] && [ "$POT_TBL" -gt 0 ] \
  || _die "픽스처가 무력하다(제목/스텝/표 중 0 이 있다) — P2 가 초록이어도 아무 의미 없다"

# ── 0-b. 실제 두 커밋 쌍을 가진 격리 픽스처 레포 ────────────────────────────
FIXREPO="$(fh_fixture_root "$(mktemp -d "${TMPDIR:-/tmp}/temperfix.XXXXXX")")"
: "${FIXREPO:?fixture root unset — refusing to run git in cwd}"
git -C "$FIXREPO" init -q -b main   || _die "git init 실패"
git -C "$FIXREPO" config user.email t@t
git -C "$FIXREPO" config user.name  t

cp "$BASE_SRC" "$FIXREPO/doc_p1.md"
cp "$BASE_SRC" "$FIXREPO/doc_n1.md"
cp "$BASE_SRC" "$FIXREPO/doc_p2.md"
cat "$BASE_SRC" "$PROSE_SRC" > "$FIXREPO/doc_p3.md"
cp "$BASE_SRC" "$FIXREPO/doc_del.md"
git -C "$FIXREPO" add doc_p1.md doc_n1.md doc_p2.md doc_p3.md doc_del.md
git -C "$FIXREPO" commit -qm "c0 — pre-quench baseline" || _die "픽스처 c0 커밋 실패"
C0="$(git -C "$FIXREPO" rev-parse HEAD)"

cat "$BASE_SRC" "$PROSE_SRC"    > "$FIXREPO/doc_p1.md"   # 산문이 늘었다
{ cat "$BASE_SRC"; cat "$WORK/fence.md"; } > "$FIXREPO/doc_p2.md"  # 증가분이 전부 펜스 안
cp  "$BASE_SRC"                   "$FIXREPO/doc_p3.md"   # 줄었다
# doc_n1.md 는 손대지 않는다 — 두 ref 사이 «안 변한» 파일
git -C "$FIXREPO" add doc_p1.md doc_p2.md doc_p3.md
git -C "$FIXREPO" commit -qm "c1 — post-convergence" || _die "픽스처 c1 커밋 실패"
C1="$(git -C "$FIXREPO" rev-parse HEAD)"
[ "$C0" != "$C1" ] || _die "두 커밋이 같다 — 픽스처가 성립하지 않았다"

_run() { # file pre post  → LANE_OUT / LANE_RC
  if [ -n "${3:-}" ]; then LANE_OUT="$(bash "$SUBJECT" "$FIXREPO" "$1" "$2" "$3" 2>&1)"; LANE_RC=$?
  else                     LANE_OUT="$(bash "$SUBJECT" "$FIXREPO" "$1" "$2" 2>&1)";      LANE_RC=$?; fi
}

echo
echo "── ① 격리 픽스처(실물 내용 · 실제 두 커밋) ──"

# ── P1 known-positive: 산문이 늘었다 ───────────────────────────────────────
_run doc_p1.md "$C0" "$C1"
_ok  "P1 rc=0" "$([ "$LANE_RC" = 0 ] && echo 1 || echo 0)"
_ok  "P1 Δ표가 출력된다" "$(_has_table "$LANE_OUT" && echo 1 || echo 0)"
P1_L=$(_delta "$LANE_OUT" lines); P1_S=$(_delta "$LANE_OUT" sections); P1_T=$(_delta "$LANE_OUT" tables)
_ok  "P1 Δlines 가 양수 ($P1_L)"    "$(_b _is_pos "$P1_L")"
_ok  "P1 Δsections 가 양수 ($P1_S)" "$(_b _is_pos "$P1_S")"
_ok  "P1 Δtables 가 양수 ($P1_T)"   "$(_b _is_pos "$P1_T")"

# ── N1 known-negative: 안 변한 파일 → 6지표 전부 +0 ────────────────────────
_run doc_n1.md "$C0" "$C1"
_ok  "N1 rc=0" "$([ "$LANE_RC" = 0 ] && echo 1 || echo 0)"
for m in lines sections steps tables fences cross-refs; do
  _eq "N1 $m" "+0" "$(_delta "$LANE_OUT" "$m")"
done

# ── 🟥 P2 «뚫리는 표기»: 증가분이 전부 코드펜스 안 ─────────────────────────
#    여기가 `bash -n` 이 구조적으로 못 지키는 계산 로직이다. SKILL.md 가 광고하는
#    «fence interiors excluded / bash 주석은 section 아님» 이 정확히 이 칸이고,
#    P1/N1 만으로는 이 분기를 **한 번도 안 지나간다**.
_run doc_p2.md "$C0" "$C1"
_ok  "P2 rc=0" "$([ "$LANE_RC" = 0 ] && echo 1 || echo 0)"
P2_L=$(_delta "$LANE_OUT" lines)
_ok  "P2 Δlines 가 양수 ($P2_L) — 입력이 실제로 커졌다" "$(_b _is_pos "$P2_L")"
_eq  "P2 Δsections — 펜스 안 제목 $POT_SEC 줄이 안 세진다" "+0" "$(_delta "$LANE_OUT" sections)"
_eq  "P2 Δsteps    — 펜스 안 스텝 $POT_STP 줄이 안 세진다" "+0" "$(_delta "$LANE_OUT" steps)"
_eq  "P2 Δtables   — 펜스 안 표 $POT_TBL 줄이 안 세진다"   "+0" "$(_delta "$LANE_OUT" tables)"
_eq  "P2 Δfences   — 펜스 자체는 +1 로 센다"              "+1" "$(_delta "$LANE_OUT" fences)"
P2_OUT_SNAPSHOT="$LANE_OUT"   # 되돌림 프로브가 같은 입력으로 대조한다

# ── 🟥 P3 음의 Δ: 단순화가 벌받지 않는다 ───────────────────────────────────
#    SKILL.md 의 검증 주장이 «simplification un-punished» 다. abs()/클램프가 끼면
#    그 주장이 조용히 거짓이 되는데 P1/N1 은 못 잡는다.
_run doc_p3.md "$C0" "$C1"
_ok  "P3 rc=0" "$([ "$LANE_RC" = 0 ] && echo 1 || echo 0)"
for m in lines sections steps tables; do
  v=$(_delta "$LANE_OUT" "$m")
  _ok "P3 Δ$m 가 «음수로» 보고된다 ($v)" "$(_b _is_neg "$v")"
done
# 대칭 컨트롤: P1 과 P3 는 같은 두 파일을 뒤집은 것이므로 크기가 같아야 한다.
_eq "P3 대칭 컨트롤: |Δlines| 가 P1 과 같다" "${P1_L#+}" "$(_delta "$LANE_OUT" lines | sed 's/^-//')"

# ── E1 계기 오류 채널: «못 쟀다» 가 «Δ=0» 으로 안 읽힌다 ───────────────────
#    🟥 종료코드를 상수로 박지 않는다. 실측(2026-09-14)으로 채널마다 값이 다르다:
#       없는 ref / ref 에 없는 파일 → git 이 새서 128 · 워킹트리 부재 → cat 이 1
#       · 인자 부족 → `${1:?}` 가 1. 128 을 계약으로 굳히면 **git 의 종료코드를 우리
#       계약으로 착각하는 것**이고, 채널이 셋인데 하나만 맞다. 계약은 관측 가능한 둘이다:
#       «rc≠0» 과 «Δ 표 부재». 그 둘이면 «못 쟀다 → 0» 오독이 닫힌다.
#    (`temper_check.sh` 에 전용 종료코드와 «못 쟀다» 라벨을 넣는 것은 **다른 변경**이다 —
#     §Added-Scope Gate Q2. 잔여로 이름을 남긴다.)
_e1() { # name file pre post
  local n="$1"; shift
  _run "$@"
  _ok "$n rc≠0 (관측 rc=$LANE_RC)" "$([ "$LANE_RC" != 0 ] && echo 1 || echo 0)"
  _ok "$n Δ표가 안 나온다"          "$(_has_table "$LANE_OUT" && echo 0 || echo 1)"
}
_e1 "E1a 없는 ref"            doc_p1.md deadbeefdeadbeefdeadbeef "$C1"
_e1 "E1b ref 에 없는 파일"     no_such_file.md "$C0" "$C1"
rm -f "$FIXREPO/doc_del.md"
_e1 "E1c 워킹트리에 파일 부재" doc_del.md "$C0"
LANE_OUT="$(bash "$SUBJECT" 2>&1)"; LANE_RC=$?
_ok "E1d 인자 부족 → rc≠0 (관측 rc=$LANE_RC)" "$([ "$LANE_RC" != 0 ] && echo 1 || echo 0)"
_ok "E1d Δ표가 안 나온다" "$(_has_table "$LANE_OUT" && echo 0 || echo 1)"
# 🟥 E1 의 컨트롤 — «Δ표가 안 나온다» 가 오탐 문자열 때문에 항상 참이면 위 넷은 전부 죽은 단언이다.
_run doc_n1.md "$C0" "$C1"
_ok "E1-control 같은 판별자가 정상 실행에서는 «표 있음» 을 낸다" \
    "$(_has_table "$LANE_OUT" && echo 1 || echo 0)"

# ── 🟥 R1 되돌림 프로브 — 3단(적용확인 / 실행 / 복원) ──────────────────────
echo
echo "── 🟥 R1 되돌림 프로브: 펜스 제외 분기만 무력화 ──"
_sha() { if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}';
         else openssl dgst -sha256 "$1" | awk '{print $NF}'; fi; }
SHA_BEFORE="$(_sha "$SUBJECT")"
MUT="$WORK/temper_check_MUTANT.sh"
sed 's|^  prose=.*|  prose="$t"|' "$SUBJECT" > "$MUT" || _die "변이 생성 실패"

# ① 적용 확인 — 해시 일치만으로는 부족하다. 변이 문자열 존재 + 원 문자열 부재 + diff 1줄.
MUT_HAS=$(grep -c 'prose="\$t"' "$MUT")
MUT_ORIG=$(grep -c 'f=!f' "$MUT")
ORIG_HAS=$(grep -c 'f=!f' "$SUBJECT")
DIFFLINES=$(diff "$SUBJECT" "$MUT" | grep -c '^[<>]')
echo "  ① 적용확인: 변이문자열 $MUT_HAS · 변이본의 원분기 잔존 $MUT_ORIG · 원본의 분기 $ORIG_HAS · diff 줄 $DIFFLINES"
_ok "R1-① 원본에 펜스 제외 분기가 실재한다"          "$([ "$ORIG_HAS" -ge 1 ] && echo 1 || echo 0)"
_ok "R1-① 변이본에서 그 분기가 사라졌다"              "$([ "$MUT_ORIG" = 0 ] && echo 1 || echo 0)"
_ok "R1-① 변이 문자열이 실제로 들어갔다"              "$([ "$MUT_HAS" = 1 ] && echo 1 || echo 0)"
_ok "R1-① 변이는 정확히 한 줄이다(부수변경 없음)"     "$([ "$DIFFLINES" = 2 ] && echo 1 || echo 0)"

# ② 실행 — P2 «만» 적색이어야 한다.
M_OUT="$(bash "$MUT" "$FIXREPO" doc_p2.md "$C0" "$C1" 2>&1)"; M_RC=$?
M_SEC=$(_delta "$M_OUT" sections); M_STP=$(_delta "$M_OUT" steps); M_TBL=$(_delta "$M_OUT" tables)
echo "  ② 실행(변이본, P2): rc=$M_RC  Δsections=$M_SEC Δsteps=$M_STP Δtables=$M_TBL"
_eq "R1-② P2 가 적색 — Δsections 가 펜스 내부 제목 수만큼 샌다" "+$POT_SEC" "$M_SEC"
_eq "R1-② P2 가 적색 — Δsteps"                                  "+$POT_STP" "$M_STP"
_eq "R1-② P2 가 적색 — Δtables"                                 "+$POT_TBL" "$M_TBL"
_ok "R1-② 원본 P2 는 여전히 +0 이다(두 값이 갈린다)" \
    "$([ "$(_delta "$P2_OUT_SNAPSHOT" sections)" = "+0" ] && echo 1 || echo 0)"
# 나머지 레인은 변이에 둔감해야 한다 — 변이가 표적을 벗어나지 않았다는 증거.
for d in doc_n1.md doc_p1.md doc_p3.md; do
  O_OUT="$(bash "$SUBJECT" "$FIXREPO" "$d" "$C0" "$C1" 2>&1)"
  N_OUT="$(bash "$MUT"     "$FIXREPO" "$d" "$C0" "$C1" 2>&1)"
  _ok "R1-② $d 는 변이 전후 Δ 가 동일(표적 이탈 없음)" \
      "$([ "$(_delta "$O_OUT" sections)" = "$(_delta "$N_OUT" sections)" ] && \
         [ "$(_delta "$O_OUT" tables)"   = "$(_delta "$N_OUT" tables)"   ] && echo 1 || echo 0)"
done

# ③ 복원 — 출하 파일은 손대지 않았다. 프로브 전후 해시가 같아야 한다.
SHA_AFTER="$(_sha "$SUBJECT")"
echo "  ③ 복원확인: before=$SHA_BEFORE"
echo "             after =$SHA_AFTER"
_ok "R1-③ 출하 subject 가 프로브로 변경되지 않았다" \
    "$([ "$SHA_BEFORE" = "$SHA_AFTER" ] && [ -n "$SHA_BEFORE" ] && echo 1 || echo 0)"

# ── ② 이 레포의 실제 히스토리 커밋 쌍 ──────────────────────────────────────
echo
echo "── ② 실제 히스토리 커밋 쌍(L1/L2) ──"
BASEREF=""
for r in HEAD~5 HEAD~3 HEAD~1; do
  if git -C "$REPO_ROOT" rev-parse --verify -q "$r^{commit}" >/dev/null 2>&1; then BASEREF="$r"; break; fi
done
if [ -z "$BASEREF" ]; then
  echo "  ⚠️  L1/L2 SKIPPED — 얕은 클론이라 실제 커밋 쌍에 못 닿는다. 🟥 SKIP != PASS"
  SKIPPED=$((SKIPPED+2))
else
  CHANGED="$(git -C "$REPO_ROOT" diff --name-only "$BASEREF" HEAD -- '*.md')"
  # L1 — 그 구간에 «안 변한» 실물 md → 6지표 전부 +0
  UNCH=""
  for f in $(git -C "$REPO_ROOT" ls-tree -r --name-only HEAD | grep '\.md$' | head -60); do
    printf '%s\n' "$CHANGED" | grep -Fxq "$f" && continue
    git -C "$REPO_ROOT" cat-file -e "$BASEREF:$f" 2>/dev/null || continue
    UNCH="$f"; break
  done
  if [ -z "$UNCH" ]; then
    echo "  ⚠️  L1 SKIPPED — $BASEREF..HEAD 구간에 안 변한 md 를 못 찾았다. 🟥 SKIP != PASS"
    SKIPPED=$((SKIPPED+1))
  else
    L_OUT="$(bash "$SUBJECT" "$REPO_ROOT" "$UNCH" "$BASEREF" HEAD 2>&1)"; L_RC=$?
    _ok "L1 실제 히스토리 known-negative: $UNCH ($BASEREF..HEAD) rc=0" "$([ "$L_RC" = 0 ] && echo 1 || echo 0)"
    L1OK=1
    for m in lines sections steps tables fences cross-refs; do
      [ "$(_delta "$L_OUT" "$m")" = "+0" ] || L1OK=0
    done
    _ok "L1 6지표 전부 +0" "$L1OK"
  fi
  # L2 — 그 구간에 «줄 수가 실제로 달라진» 실물 md → 부호가 독립 계산과 일치 (back-to-back)
  CH=""; CH_SIGN=""
  for f in $CHANGED; do
    git -C "$REPO_ROOT" cat-file -e "$BASEREF:$f" 2>/dev/null || continue
    git -C "$REPO_ROOT" cat-file -e "HEAD:$f"     2>/dev/null || continue
    a="$(git -C "$REPO_ROOT" show "$BASEREF:$f" | wc -l | tr -d ' ')"
    b="$(git -C "$REPO_ROOT" show "HEAD:$f"     | wc -l | tr -d ' ')"
    [ "$a" = "$b" ] && continue
    CH="$f"; if [ "$b" -gt "$a" ]; then CH_SIGN="+"; else CH_SIGN="-"; fi; break
  done
  if [ -z "$CH" ]; then
    echo "  ⚠️  L2 SKIPPED — $BASEREF..HEAD 구간에 줄 수가 달라진 md 가 없다. 🟥 SKIP != PASS"
    SKIPPED=$((SKIPPED+1))
  else
    L_OUT="$(bash "$SUBJECT" "$REPO_ROOT" "$CH" "$BASEREF" HEAD 2>&1)"; L_RC=$?
    L_D=$(_delta "$L_OUT" lines)
    _ok "L2 실제 히스토리 known-positive: $CH rc=0" "$([ "$L_RC" = 0 ] && echo 1 || echo 0)"
    # 독립 오라클: `git show | wc -l` 로 따로 센 부호와 일치하나 (크기는 안 건다 —
    # subject 는 후행 개행을 정규화하므로 wc -l 과 «크기» 가 어긋날 수 있다. 명명된 잔여다).
    _ok "L2 Δlines 부호가 독립 계산과 일치 (독립=$CH_SIGN, subject=$L_D)" \
        "$(_b _is_sign "$CH_SIGN" "$L_D")"
  fi
fi

echo
echo "[temper-check] PASS=$PASS  FAIL=$FAIL  SKIPPED=$SKIPPED (🟥 SKIP 은 통과가 아니다)"
[ "$FAIL" -eq 0 ] || exit 1

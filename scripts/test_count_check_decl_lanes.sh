#!/usr/bin/env bash
# test_count_check_decl_lanes.sh — known pairs + revert probes for the COUNT DECLARATION parser
# in `scripts/count_check.sh` (the `_DECL_PY` helper and the sweep's AMBIG branches).
#
# WHY THIS EXISTS
# #768 widened the sweep to every plugin on disk and then wrote its own residual down:
#   «순회는 description 의 **첫** `N skills` 패턴만 읽는다 — 과탐/미탐 방향 미측정»
# Both directions were then measured (2026-09-21) and both were real:
#   · 미탐 / FALSE PASS — a stale declaration ("3 skills", disk 4) goes GREEN when any earlier
#     prose number ("roughly 4 skills worth of") is picked up instead. The same defect the
#     control arm catches as FAIL. This is the #763/#768 substring-collision class, third time.
#   · 과탐 / FALSE FAIL — the pattern `(\d+)\s+skills?` matches the "3 skill" inside
#     `M1/M2/M3 skill tier map`, which is live in `.claude-plugin/marketplace.json` today.
# Fix: count EVERY match, fail on more than one DISTINCT value ("모호≠통과", one step beyond
# #768's "부재≠통과"), and require a non-alphanumeric boundary before the digits.
#
# SCOPE, stated honestly: these lanes run the REAL `count_check.sh` against a REAL tree
# (`git archive HEAD` into a temp dir, with the working-tree script copied over), because the
# sibling README-format suite already recorded what happens when you fixture a skeleton tree:
# every arm fails for the same unrelated reason ("0 active fh-meta skills") and the suite
# certifies nothing. L0 is the dead-control guard for exactly that — if the baseline fixture
# does not come back GREEN, no later verdict in this file means anything.
#
# 🟥 The real repository is never mutated. L8 asserts that.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 10
pass=0; fail=0
ok()  { printf '  \342\234\205 %s\n' "$1"; pass=$((pass+1)); }
bad() { printf '  \342\235\214 %s\n' "$1"; fail=$((fail+1)); }

if [ ! -f scripts/count_check.sh ]; then
  printf '\360\237\237\245 HARNESS ERROR — scripts/count_check.sh 가 없다. 「0 실패」가 아니라 계기 부재다.\n'
  exit 10
fi

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
FX="$TMP/tree"; mkdir -p "$FX"
# containment baseline (L8) — byte snapshots, NOT `git diff`: a consumer install has no history,
# and a containment claim that cannot be evaluated there is a containment claim nobody checks.
mkdir -p "$TMP/base"
cp "$REPO_ROOT/plugins/fh-qp/.claude-plugin/plugin.json" "$TMP/base/qp.json" 2>/dev/null || true
cp "$REPO_ROOT/.claude-plugin/marketplace.json"          "$TMP/base/mp.json" 2>/dev/null || true
# 🟥 **git 에 기대지 않는다.** 초판은 `git archive HEAD` 로 픽스처를 떴는데, 소비자 install 의
#    arm 에서 실측으로 죽었다: npm 으로 푼 패키지에는 히스토리가 없어 `not a valid object name:
#    HEAD` 로 rc=10 이 났다. 무음 초록이 아니었으니 저하 방향은 옳았지만, 레인이 소비자에게
#    **구조적으로 실행 불가**라는 뜻이다(#770 이 네트워크를 뺀 것과 같은 이유). 그래서 워킹
#    트리를 그대로 복사한다 — count_check 는 worktree 모드에서 git 을 안 쓴다(`git ls-files` 는
#    `--staged` 분기 안에만 있다).
if ! ( cd "$REPO_ROOT" && tar cf - --exclude=.git --exclude=node_modules --exclude=tracks . ) \
     | ( cd "$FX" && tar xf - ) 2>/dev/null; then
  printf '\360\237\237\245 HARNESS ERROR — 픽스처 트리 복사 실패. 「0 실패」가 아니라 계기 부재다.\n'
  exit 10
fi
if [ ! -f "$FX/scripts/count_check.sh" ]; then
  printf '\360\237\237\245 HARNESS ERROR — 픽스처에 count_check.sh 가 없다.\n'; exit 10
fi

QP="$FX/plugins/fh-qp/.claude-plugin/plugin.json"
if [ ! -f "$QP" ]; then
  printf '\360\237\237\245 HARNESS ERROR — 픽스처에 fh-qp plugin.json 이 없다.\n'; exit 10
fi
cp "$QP" "$TMP/qp.orig.json"

# set_desc <description> — rewrite ONLY fh-qp's description in the fixture tree
set_desc() {
  python3 - "$QP" "$TMP/qp.orig.json" "$1" <<'PY'
import json,sys
d=json.load(open(sys.argv[2],encoding="utf-8"))
d["description"]=sys.argv[3]
json.dump(d,open(sys.argv[1],"w",encoding="utf-8"),ensure_ascii=False,indent=2)
PY
}
# verdict — echoes the single fh-qp skills sweep line from a real count_check run
verdict() { ( cd "$FX" && bash scripts/count_check.sh 2>&1 ) | grep -E "sweep: fh-qp skills" | head -1; }

DECL_OK="QP (Quality Platform) — 4 skills (qp · qp-plan · qp-run · qp-regress)."
DECL_STALE="QP (Quality Platform) — 3 skills (qp · qp-plan · qp-run · qp-regress)."
DECL_STALE_MASKED="QP — replaces roughly 4 skills worth of hand-rolled tooling. 3 skills (qp · qp-plan · qp-run · qp-regress)."
DECL_TIERMAP="QP (Quality Platform) — 4 skills (qp · qp-plan · qp-run · qp-regress). Reads the M1/M2/M3 skill tier map."
DECL_REPEAT="QP — a 4 skills bundle. 4 skills (qp · qp-plan · qp-run · qp-regress)."

# ── L0 dead-control: the untouched fixture must be GREEN ──────────────────────
base=$( ( cd "$FX" && bash scripts/count_check.sh 2>&1 ) | tail -1 )
case "$base" in
  *"COUNT-CHECK: PASS"*) ok "L0 dead-control — 픽스처 기준선이 초록 ($base)" ;;
  *) bad "L0 dead-control — 기준선이 이미 빨갛다 ($base). 이 아래 판정은 전부 무의미하다"
     echo "----"; echo "count_check declaration lanes: $pass passed, $fail failed"; exit 1 ;;
esac

# ── L1 known-NEG: stale declaration, nothing masking it → FAIL ───────────────
set_desc "$DECL_STALE"; v=$(verdict)
case "$v" in
  FAIL*"선언 3 ≠ 디스크 4"*) ok "L1 known-NEG 낡은 선언을 잡는다 — 계기가 살아 있다" ;;
  *) bad "L1 known-NEG 낡은 선언(3 vs 4)을 못 잡았다: $v" ;;
esac

# ── L2 known-POS: same stale declaration, masked by earlier prose → 모호 FAIL ─
set_desc "$DECL_STALE_MASKED"; v=$(verdict)
case "$v" in
  FAIL*"모호"*) ok "L2 known-POS 산문 숫자에 가려진 낡은 선언 — 모호로 잡는다 (수리 전엔 PASS)" ;;
  PASS*) bad "L2 known-POS 거짓 PASS 가 살아 있다 — 이 레인이 존재하는 이유다: $v" ;;
  *) bad "L2 known-POS 예상 밖 판정: $v" ;;
esac

# ── L3 과탐 control: a correct declaration beside `M3 skill` prose → PASS ─────
set_desc "$DECL_TIERMAP"; v=$(verdict)
case "$v" in
  PASS*) ok "L3 과탐 control — M3 skill tier map 의 \"3 skill\" 은 선언이 아니다, 막지 않는다" ;;
  *) bad "L3 과탐 — 정상 선언을 막았다. 과차단은 --no-verify 를 학습시킨다: $v" ;;
esac

# ── L4 같은 값 반복은 모호가 아니다 → PASS ───────────────────────────────────
set_desc "$DECL_REPEAT"; v=$(verdict)
case "$v" in
  PASS*) ok "L4 같은 값 반복(4 · 4)은 모호가 아니다 — 통과" ;;
  *) bad "L4 같은 값 반복을 모호로 막았다: $v" ;;
esac

# ── L5 부재≠통과 회귀 (#768 이 세운 규칙이 살아 있나) ────────────────────────
set_desc "QP (Quality Platform) — plan, automate, regress. No count declared here."; v=$(verdict)
case "$v" in
  FAIL*"부재≠통과"*) ok "L5 선언 부재는 여전히 FAIL — #768 의 규칙이 살아 있다" ;;
  *) bad "L5 선언 부재를 놓쳤다: $v" ;;
esac

# ── L6 revert probe: AMBIG 분기를 죽이면 L2 가 초록으로 돌아가야 한다 ────────
cp "$FX/scripts/count_check.sh" "$TMP/mut6.sh"
# 🟥 충실한 되돌림은 «첫 매치를 텍스트 순서로» 다 — 정렬 최솟값이 아니다.
#    sorted(set(...)) 를 vals[:1] 로 바꾸면 수리 전 `re.search` 의미가 그대로 복원된다.
if ! sed -i.bak 's/uniq=sorted(set(vals), key=int)/uniq=vals[:1]/' "$TMP/mut6.sh"; then
  bad "L6 HARNESS ERROR — 뮤턴트 생성 실패 (치환 대상 없음). 「안 빨개졌다」와 구별이 안 된다"
elif ! grep -q 'uniq=vals\[:1\]' "$TMP/mut6.sh"; then
  bad "L6 HARNESS ERROR — 뮤턴트에 치환이 반영되지 않았다"
else
  cp "$TMP/mut6.sh" "$FX/scripts/count_check.sh"
  set_desc "$DECL_STALE_MASKED"; v=$(verdict)
  case "$v" in
    PASS*) ok "L6 되돌림 — AMBIG 분기를 죽이자 L2 가 거짓 PASS 로 되돌아갔다 (앵커가 장식이 아니다)" ;;
    *) bad "L6 되돌림 — 뮤턴트가 빨간 채다. L2 는 AMBIG 분기 덕분이 아닐 수 있다: $v" ;;
  esac
  cp scripts/count_check.sh "$FX/scripts/count_check.sh"
fi
rm -f "$TMP/mut6.sh.bak"

# ── L7 revert probe: 경계를 빼면 L3 이 빨개져야 한다 ─────────────────────────
cp "$FX/scripts/count_check.sh" "$TMP/mut7.sh"
if ! sed -i.bak 's/(?<!\[A-Za-z0-9_\/.-\])//' "$TMP/mut7.sh"; then
  bad "L7 HARNESS ERROR — 뮤턴트 생성 실패 (치환 대상 없음)"
elif grep -q '(?<!' "$TMP/mut7.sh"; then
  bad "L7 HARNESS ERROR — 경계가 뮤턴트에 그대로 남아 있다"
else
  cp "$TMP/mut7.sh" "$FX/scripts/count_check.sh"
  set_desc "$DECL_TIERMAP"; v=$(verdict)
  case "$v" in
    FAIL*) ok "L7 되돌림 — 경계를 빼자 M3 의 \"3 skill\" 이 다시 선언으로 읽힌다 (과탐 실재 확인)" ;;
    *) bad "L7 되돌림 — 뮤턴트가 초록이다. L3 은 경계 덕분이 아닐 수 있다: $v" ;;
  esac
  cp scripts/count_check.sh "$FX/scripts/count_check.sh"
fi
rm -f "$TMP/mut7.sh.bak"

# ── L8 containment: 실제 레포는 건드리지 않았다 ──────────────────────────────
if [ ! -s "$TMP/base/qp.json" ] || [ ! -s "$TMP/base/mp.json" ]; then
  bad "L8 containment — 기준 스냅샷을 못 떴다. 격리를 «잰 적이 없다» (UNMEASURED, 통과 아님)"
elif cmp -s "$TMP/base/qp.json" "$REPO_ROOT/plugins/fh-qp/.claude-plugin/plugin.json" \
  && cmp -s "$TMP/base/mp.json" "$REPO_ROOT/.claude-plugin/marketplace.json"; then
  ok "L8 containment — 실제 트리의 plugin/marketplace 선언 byte-identical (사본만 건드렸다)"
else
  bad "L8 containment — 실제 트리가 바뀌었다. 이 런의 격리 주장은 무효다"
fi

echo "----"
echo "count_check declaration lanes: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

#!/usr/bin/env bash
# fh-run 의 «이름 → 스킬 파일» 해석기 앵커.
#
# ## 왜 생겼나 (2026-09-13)
#
# preprep 을 자기 플러그인으로 승격하면서 `--skill preprep` 가 **조용히 깨졌다**.
# 해석기가 `fh-meta` · `fh-commons` 둘만 하드코딩하고 있었기 때문이다. 🟥 그리고 그건
# 새 결함이 아니라 **선재 갭**이었다 — `fh-qp` 의 스킬 4개는 **처음부터** 이름만으로 안 잡혔다
# (`--skill qp` → «unable to resolve»). 레포의 어떤 검사도 이 경로를 안 보고 있었고,
# cross-family(codex) 가 그 이동 리뷰에서 지목했다.
#
# 🟥 이 레인은 **스킬을 실행하지 않는다.** `FH_DRY_RUN=1` 로 조립된 프롬프트만 뽑는다.
#    (옵션 `--dry-run` 은 존재하지 않는다 — 그렇게 부르면 프롬프트로 먹혀 **실제로 돈다**.
#     첫 검증에서 그걸 겪었다.)
#
# 실행: bash scripts/test_fh_run_resolver_lanes.sh
# 🟥 이 파일의 모든 «$VAR» 는 `${VAR}` 로 쓴다 — 변수 뒤에 ASCII 가 아닌 글자(» 등)가 바로
#    붙으면 셸이 그 바이트를 **변수 이름에 먹어** `VAR?: unbound variable` 로 죽는다.
#    이 세션에 같은 결함을 두 번 냈다(한 번 고치고 새 파일에 또 썼다). 중괄호가 그 경계다.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$HERE" || exit 2
PASS=0; FAIL=0
ok(){ printf '  ✅ %s\n' "$1"; PASS=$((PASS+1)); }
ng(){ printf '  ❌ %s\n' "$1"; FAIL=$((FAIL+1)); }

# 해석된 파일 경로만 뽑는다. 못 찾으면 빈 문자열.
# 🟥 `--backend codex` 를 **명시**한다. 안 그러면 `fh-run` 이 해석보다 **먼저** 백엔드를
#    자동탐지하고, `codex`·`claude` 가 없는 환경(=CI 러너)에서 `exit 10` 으로 죽는다.
#    초판 레인이 그걸 빼먹어 **로컬 6/6 · CI 0/6** 이 났다 — 컨트롤(F3)까지 빨개서 «해석 전에
#    죽는다»가 드러났고 그래서 오진하지 않았다. 명시하면 `FH_DRY_RUN=1` 이 실제 호출 전에
#    돌아오므로 바이너리가 없어도 된다.
# ⚠️ 명명된 잔여: 「백엔드 부재」가 「스킬 못 찾음」을 **가린다**(순서상 먼저 죽는다).
#    더 쓸모 있는 순서는 해석이 먼저지만, 그건 이 PR 의 범위가 아니라 별건이다.
resolve(){
  FH_DRY_RUN=1 timeout 60 bash "$HERE/scripts/fh-run.sh" --backend codex --skill "$1" 2>&1 \
    | /usr/bin/grep -oE 'plugins/[A-Za-z0-9_-]+/skills/[A-Za-z0-9_.-]+/SKILL\.md' | head -1
}

echo "== 이름만으로 어느 플러그인이든 닿나 =="
R=$(resolve preprep)
case "$R" in
  plugins/fh-preprep/skills/preprep/SKILL.md) ok "F1 preprep → $R (승격 후에도 이름으로 닿는다)" ;;
  "") ng "F1 preprep 미해결 — 승격이 소비자 표면을 깼다" ;;
  *)  ng "F1 preprep 이 엉뚱한 곳으로: $R" ;;
esac

R=$(resolve qp)
case "$R" in
  plugins/fh-qp/skills/qp/SKILL.md) ok "F2 qp → $R (원래 못 닿던 선재 갭도 같이 닫혔다)" ;;
  "") ng "F2 qp 미해결 — 일반화가 fh-qp 에 안 닿는다" ;;
  *)  ng "F2 qp 가 엉뚱한 곳으로: $R" ;;
esac

echo
echo "== 🟥 컨트롤 — 아무 이름이나 닿으면 위 둘은 아무것도 증명 안 한다 =="
OUT=$(FH_DRY_RUN=1 timeout 60 bash "$HERE/scripts/fh-run.sh" --backend codex --skill zz_no_such_skill_probe 2>&1); RC=$?
if [ "$RC" -ne 0 ] && printf '%s' "$OUT" | /usr/bin/grep -q 'unable to resolve'; then
  ok "F3 없는 이름 → rc=$RC · «unable to resolve» (판별력 있음)"
else
  ng "F3 없는 이름이 통과했다 (rc=$RC) — 해석기가 아무거나 잡는다"
fi

echo
echo "== 우선순위가 안 뒤집혔나 (일반화의 대가) =="
# fh-meta 에 실재하는 이름은 여전히 fh-meta 로 가야 한다.
M=$(ls plugins/fh-meta/skills 2>/dev/null | head -1)
if [ -n "$M" ]; then
  R=$(resolve "$M")
  case "$R" in
    plugins/fh-meta/*) ok "F4 fh-meta 스킬 «${M}» 은 여전히 fh-meta 로 (우선순위 보존)" ;;
    *) ng "F4 «${M}» 이 $R 로 갔다 — 일반화가 해석 순서를 바꿨다" ;;
  esac
else
  ng "F4 fh-meta 스킬을 못 찾았다 — 계기 오류(레포가 헐었거나 경로가 틀렸다)"
fi
C=$(ls plugins/fh-commons/skills 2>/dev/null | head -1)
if [ -n "$C" ]; then
  R=$(resolve "$C")
  case "$R" in
    plugins/fh-commons/*) ok "F5 fh-commons 스킬 «${C}» 은 여전히 fh-commons 로" ;;
    *) ng "F5 «${C}» 이 $R 로 갔다" ;;
  esac
else
  ng "F5 fh-commons 스킬을 못 찾았다 — 계기 오류"
fi

echo
echo "== 명시 지정이 여전히 이긴다 =="
R=$(resolve "fh-preprep:preprep")
case "$R" in
  plugins/fh-preprep/skills/preprep/SKILL.md) ok "F6 plugin:name 형태도 해석된다" ;;
  *) ng "F6 명시 지정 실패: ${R:-(없음)}" ;;
esac

echo
echo "== 백엔드 바이너리가 없는 환경에서도 같은 답인가 (CI 형태) =="
# 🟥 이 레인이 있는 이유: 초판이 로컬에서만 통과하고 CI 에서 6/6 빨갰다. PATH 를 깎아
#    codex·claude 를 **실제로 없앤** 상태에서 재는 것이 그 차이를 로컬에서도 재현한다.
# 🟥 `timeout` 이 `env` «앞»이어야 한다 — GNU coreutils 의 timeout 은 /usr/bin 에 없어서
#    PATH 를 깎은 «뒤»에 찾으면 command-not-found 로 죽는다. 초판이 그렇게 써서 F7 이
#    로컬에서도 빨갰고, 그게 사실은 «이 레인이 계기 고장을 잡았다»는 증거다.
R7=$(timeout 60 env PATH=/usr/bin:/bin FH_DRY_RUN=1 bash "$HERE/scripts/fh-run.sh" \
       --backend codex --skill preprep 2>&1 \
     | /usr/bin/grep -oE 'plugins/[A-Za-z0-9_-]+/skills/[A-Za-z0-9_.-]+/SKILL\.md' | head -1)
case "${R7}" in
  plugins/fh-preprep/skills/preprep/SKILL.md) ok "F7 백엔드 바이너리 0개인 환경에서도 해석된다 (CI 와 같은 답)" ;;
  "") ng "F7 백엔드 없는 환경에서 해석 실패 — 이 레인은 로컬 전용이다(= CI 에서 빨개진다)" ;;
  *)  ng "F7 엉뚱한 곳으로: ${R7}" ;;
esac

echo
echo "════════════════════════════════════════"
printf '  PASS %s   FAIL %s\n' "$PASS" "$FAIL"
echo "════════════════════════════════════════"
[ "$FAIL" -eq 0 ] || exit 1

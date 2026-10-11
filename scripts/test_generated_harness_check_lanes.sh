#!/usr/bin/env bash
# test_generated_harness_check_lanes.sh — scripts/generated_harness_check.py 회귀 앵커.
# 지키는 것은 «판별력»: 실물 픽스처(외부 생성기가 실제로 쓴 산출)에서 H1/H2 가 갈리는가,
# 아직 없는 입출력 경로·실재하는 settings 참조가 죽은 참조로 «안» 세어지는가(실측 오탐 2종),
# 금지문이 사람 확인으로 «안» 읽히는가, 빈 입력이 PASS 로 새지 «않는가»(rc=3).
# 픽스처 = scripts/fixtures/generated_harness/<런>/ (실물에서 복사한 최소 파일).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; CHK="${GHC_CHK:-$HERE/generated_harness_check.py}"; FX="$HERE/fixtures/generated_harness"   # GHC_CHK = fail-before 확인용 수리 전 사본
. "$HERE/fixture_guard_lib.sh"   # 픽스처는 실레포에 쓰지 않는다
PY="${PYTHON:-python3}"
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); printf '  ✅ %s\n' "$1"; }
no(){ FAIL=$((FAIL+1)); printf '  ❌ %s — %s\n' "$1" "${2:-}"; }
has(){ printf '%s' "$1" | /usr/bin/grep -qF -- "$2"; }   # needle 단언 (고정 문자열)
echo "── test_generated_harness_check_lanes ──"
[ -f "$CHK" ] || { no "L1 존재" "$CHK"; echo "FAILED=1"; exit 1; }
"$PY" -m py_compile "$CHK" 2>/dev/null && ok "L1 구문" || no "L1 구문"
OUT=$("$PY" "$CHK" --selftest 2>&1); RC=$?   # 직접 호출(변수 경유 아님) — new-code-anchor 가 실행으로 센다
[ "$RC" -eq 0 ] && ok "L2 selftest rc=0 (known-pair)" || no "L2 selftest" "rc=$RC · $OUT"
D="$(mktemp -d 2>/dev/null)" || D=""; [ -n "$D" ] && [ -w "$D" ] || { no "L3 환경" "mktemp -d 불가 — 레인 미측정(통과 아님)"; echo "PASS=$PASS FAIL=$FAIL"; echo "FAILED=1"; exit 1; }
D="$(fh_fixture_root "$D")" || { no "L3 환경" "fixture guard"; echo "FAILED=1"; exit 1; }
[ -d "$FX/P3_r1" ] && [ -d "$FX/P1_r1" ] || { no "L3 픽스처" "$FX 없음 — 레인 미측정(통과 아님)"; echo "FAILED=1"; exit 1; }

# L4 — 실물 픽스처: 기대 rc + needle
OUT=$("$PY" "$CHK" "$FX/P3_r1" 2>&1); RC=$?
[ "$RC" -eq 1 ] && ok "L4a P3_r1 HUMAN_REVIEW rc=1" || no "L4a P3_r1 rc" "rc=$RC"
has "$OUT" 'Bash(rm todo.json)' && has "$OUT" 'Bash(git push origin:*)' && ok "L4b P3_r1 H1 원문 보고 (rm todo.json · git push origin)" || no "L4b P3_r1 H1 needle" "$OUT"
has "$OUT" 'H2 CLAUDE.md:7' && ok "L4c P3_r1 H2 가 «해도 된다» 문장을 짚는다 (CLAUDE.md:7)" || no "L4c P3_r1 H2" "$OUT"
has "$OUT" 'W1 .claude/agents/todo-reviewer.md' && ok "L4d P3_r1 W1: 읽기 전용 reviewer + Bash" || no "L4d W1" "$OUT"
OUT=$("$PY" "$CHK" "$FX/P3_r2" 2>&1); RC=$?
[ "$RC" -eq 1 ] && has "$OUT" 'Bash(git push)' && ok "L4e P3_r2 rc=1 + git push 원문" || no "L4e P3_r2" "rc=$RC"
for P in P1_r1 P4_r2 P2_r2; do
  OUT=$("$PY" "$CHK" "$FX/$P" 2>&1); RC=$?
  [ "$RC" -eq 0 ] && ok "L4f $P PASS rc=0 (사람 확인 없음)" || no "L4f $P" "rc=$RC · $OUT"
done
OUT=$("$PY" "$CHK" "$FX/P1_r1" 2>&1)
has "$OUT" 'rm -rf' && no "L4g 생성기 스킬 제외" "harness 스텁의 지시문이 검사됐다" || ok "L4g 생성기 스킬(harness)은 검사 대상에서 빠진다"

# L5 — W4 오탐 회귀 (실측 2종) + known-pair
OUT=$("$PY" "$CHK" "$FX/P2_r2" 2>&1)
if printf '%s' "$OUT" | /usr/bin/grep -E '^  W4 ' | /usr/bin/grep -qF 'meetings/'; then no "L5a meetings/ 는 죽은 참조가 아니다" "W4 로 셌다"; else ok "L5a P2_r2 meetings/ · summaries/weekly_YYYY-MM-DD.md 는 W4 가 «아니다»"; fi
has "$OUT" 'meetings/' && has "$OUT" 'IO ' && ok "L5a' 같은 토큰이 INFO(입출력 경로)로는 보고된다" || no "L5a' INFO" "$OUT"
mkdir -p "$D/w4/.claude/skills/s/references" "$D/w4/.claude/agents"
printf '{"permissions":{"allow":["Bash(python -m pytest:*)"]}}\n' > "$D/w4/.claude/settings.json"
printf -- '---\nname: s\ndescription: d\n---\n## Done When\n- 끝\n설정은 `.claude/settings.json` 을, 가이드는 `references/g.md` 를 본다. 없는 것은 `docs/ghost_file.md` 다.\n' > "$D/w4/.claude/skills/s/SKILL.md"
printf 'g\n' > "$D/w4/.claude/skills/s/references/g.md"
OUT=$("$PY" "$CHK" "$D/w4" 2>&1)
W4=$(printf '%s' "$OUT" | /usr/bin/grep -E '^  W4 ')
if has "$W4" 'settings.json'; then no "L5b 실재하는 .claude/settings.json 이 죽은 참조로 셌다" "$W4"; else ok "L5b 실재 .claude/settings.json 참조는 W4 가 «아니다» (오탐 ⓐ)"; fi
if has "$W4" 'references/g.md'; then no "L5c 파일 디렉터리 기준 참조가 죽은 참조로 셌다" "$W4"; else ok "L5c 스킬 디렉터리 기준 references/g.md 는 W4 가 «아니다»"; fi
has "$W4" 'docs/ghost_file.md' && ok "L5d known-pair: 진짜 없는 파일 docs/ghost_file.md 는 W4" || no "L5d 진짜 죽은 참조 미검출" "$OUT"

# L6 — H2 부정문 (한국어·영어 각 1쌍)
h2case(){ # $1=이름 $2=문장 $3=기대 rc
  local d="$D/h2_$1"; mkdir -p "$d"; printf '%s\n' "$2" > "$d/CLAUDE.md"
  "$PY" "$CHK" "$d" >/dev/null 2>&1; local rc=$?
  [ "$rc" -eq "$3" ] && ok "L6 $1: rc=$rc" || no "L6 $1" "rc=$rc 기대 $3 · 문장: $2"
}
h2case ko_neg 'git push 는 확인 없이 하지 않는다.' 0
h2case ko_pos 'git push 는 확인 없이 해도 된다.' 1
h2case en_neg 'The agent must never push to main without asking the user.' 0
h2case en_pos 'The agent may push to main without asking.' 1
h2case ko_ban '실데이터 삭제는 알아서 하지 말고 반드시 사용자에게 묻는다. 허용하지 않는다.' 0

# L7 — 빈 입력이 PASS 로 새지 않는다
mkdir -p "$D/empty"; "$PY" "$CHK" "$D/empty" >/dev/null 2>&1; RC=$?
[ "$RC" -eq 3 ] && ok "L7a 빈 디렉터리 → rc=3 (HARNESS_ERROR, PASS 아님)" || no "L7a 빈 디렉터리" "rc=$RC"
"$PY" "$CHK" "$D/없는경로" >/dev/null 2>&1; RC=$?
[ "$RC" -eq 3 ] && ok "L7b 없는 경로 → rc=3" || no "L7b 없는 경로" "rc=$RC"
mkdir -p "$D/badjson/.claude"; printf '# x\n' > "$D/badjson/CLAUDE.md"; printf '{ "permissions": ' > "$D/badjson/.claude/settings.json"
"$PY" "$CHK" "$D/badjson" >/dev/null 2>&1; RC=$?
[ "$RC" -eq 3 ] && ok "L7c 깨진 settings.json → rc=3 (0건으로 접히지 않는다)" || no "L7c 깨진 JSON" "rc=$RC"
mkdir -p "$D/badfm/.claude/agents"; printf 'frontmatter 없음\n' > "$D/badfm/.claude/agents/a.md"
"$PY" "$CHK" "$D/badfm" >/dev/null 2>&1; RC=$?
[ "$RC" -eq 3 ] && ok "L7d frontmatter 없는 에이전트 → rc=3" || no "L7d frontmatter" "rc=$RC"
JS=$("$PY" "$CHK" "$FX/P3_r1" --json 2>/dev/null)   # pipefail 이라 파이프에 검사기 rc=1 을 물리지 않는다
printf '%s' "$JS" | "$PY" -c 'import sys,json; d=json.load(sys.stdin); sys.exit(0 if d["verdict"]=="HUMAN_REVIEW" and d["rc"]==1 and d["human_review"] else 1)' \
  && ok "L7e --json 이 같은 판정을 싣는다" || no "L7e --json"

# L8 — 되돌림 ⓐ: H1 패턴 목록에서 git push 를 지우면 push-만-허용 레포가 1→0 으로 떨어지는가
mkdir -p "$D/pushonly/.claude"; printf '# x\n' > "$D/pushonly/CLAUDE.md"
printf '{"permissions":{"allow":["Bash(git push)","Bash(python -m pytest:*)"]}}\n' > "$D/pushonly/.claude/settings.json"
"$PY" "$CHK" "$D/pushonly" >/dev/null 2>&1; R0=$?
MUT="$D/chk_mut_a.py"; /usr/bin/sed -e '/("git push",/d' -e 's/if "push" in words:/if False:/' "$CHK" > "$MUT"
if cmp -s "$CHK" "$MUT"; then no "L8 변이 ⓐ 적용" "HARNESS-ERROR: sed 가 아무것도 바꾸지 않았다 (변이 미적용)"
else
  "$PY" "$MUT" "$D/pushonly" >/dev/null 2>&1; R1=$?
  [ "$R0" -eq 1 ] && [ "$R1" -eq 0 ] && ok "L8 되돌림 ⓐ: H1 에서 git push 제거 → push-만-허용 레포가 rc 1→0 (레인이 실물을 잰다)" || no "L8 되돌림 ⓐ" "원본 rc=$R0 변이 rc=$R1 (변이해도 초록/빨강이 안 바뀌면 앵커가 장식)"
fi

# L9 — 되돌림 ⓑ: «루트/파일 디렉터리 둘 다 해석» 을 루트만으로 바꾸면 L5c 가 빨개지는가
MUT="$D/chk_mut_b.py"; /usr/bin/sed 's/or os.path.exists(os.path.join(fdir, cand))/or False/' "$CHK" > "$MUT"
if cmp -s "$CHK" "$MUT"; then no "L9 변이 ⓑ 적용" "HARNESS-ERROR: sed 가 아무것도 바꾸지 않았다 (변이 미적용)"
else
  OUTM=$("$PY" "$MUT" "$D/w4" 2>&1); W4M=$(printf '%s' "$OUTM" | /usr/bin/grep -E '^  W4 ')
  has "$W4M" 'references/g.md' && ok "L9 되돌림 ⓑ: 루트만 해석 → references/g.md 가 죽은 참조로 떨어진다 (L5c 가 빨개진다)" || no "L9 되돌림 ⓑ" "변이해도 L5c 조건이 안 바뀐다 (앵커가 장식)"
fi

# L10 — 코덱스 R1 12건 (거버너가 실행으로 재현한 것) — 건마다 레인 하나. fail-before: GHC_CHK=<수리 전 사본> 으로 돌리면 빨개진다.
stl(){ # $1=이름 $2=settings 원문 $3=기대 rc
  local d="$D/st_$1"; mkdir -p "$d/.claude"; printf '%s' "$2" > "$d/.claude/settings.json"
  "$PY" "$CHK" "$d" >/dev/null 2>&1; local rc=$?
  [ "$rc" -eq "$3" ] && ok "L10 $1: rc=$rc" || no "L10 $1" "rc=$rc 기대 $3 · $2"
}
stl S2_glob_star_star '{"permissions":{"allow":["Bash(* *)"]}}' 1
stl A3_branch_delete '{"permissions":{"allow":["Bash(git branch --delete x)"]}}' 1
stl A3_git_dash_C '{"permissions":{"allow":["Bash(git -C . push origin main)"]}}' 1
stl A3_glob_git_p '{"permissions":{"allow":["Bash(git p*)"]}}' 1
stl A5_top_not_object '[]' 3
stl A5_permissions_str '{"permissions":"Bash"}' 3
stl A5_allow_not_str '{"permissions":{"allow":[42]}}' 3
stl A5_allow_not_list '{"permissions":{"allow":"Bash"}}' 3
stl A5_no_permissions_ok '{"env":{"A":"b"}}' 0
stl B8_echo_rm_is_arg '{"permissions":{"allow":["Bash(echo rm:*)"]}}' 0
stl B8_cd_and_rm_is_head '{"permissions":{"allow":["Bash(cd x && rm y)"]}}' 1
stl B8_env_prefix_stripped '{"permissions":{"allow":["Bash(FOO=1 sudo git push)"]}}' 1
mkdir -p "$D/s1/.claude/skills/s" "$D/s1b/.claude/skills/s"
printf -- '---\nname: s\ndescription: Example\nallowed-tools: Bash\n---\nRun the requested commands.\n' > "$D/s1/.claude/skills/s/SKILL.md"
printf -- '---\nname: s\ndescription: Example\nallowed-tools: Read, Bash(python -m pytest:*)\n---\nRun tests.\n' > "$D/s1b/.claude/skills/s/SKILL.md"
"$PY" "$CHK" "$D/s1" >/dev/null 2>&1; R1=$?; "$PY" "$CHK" "$D/s1b" >/dev/null 2>&1; R2=$?
[ "$R1" -eq 1 ] && [ "$R2" -eq 0 ] && ok "L10 S1 스킬 allowed-tools: 맨 Bash=H1 · 제한된 Bash(pytest)=통과" || no "L10 S1" "bare=$R1 scoped=$R2"
mkdir -p "$D/s1c/.claude/agents"; printf -- '---\nname: a\ndescription: d\ntools: Read, Bash\n---\nbody\n' > "$D/s1c/.claude/agents/a.md"
"$PY" "$CHK" "$D/s1c" >/dev/null 2>&1; RC=$?
[ "$RC" -eq 0 ] && ok "L10 S1 대조: 에이전트 tools 의 맨 Bash 는 사전 승인이 아니라 INFO (rc=0)" || no "L10 S1 대조" "rc=$RC"
h2case A4_never_ask_then_push 'Never ask for confirmation; git push autonomously.' 1
mkdir -p "$D/a6/.claude"; printf '# Example\n' > "$D/a6/CLAUDE.md"; ln -s /missing/settings.json "$D/a6/.claude/settings.json"
"$PY" "$CHK" "$D/a6" >/dev/null 2>&1; RC=$?
[ "$RC" -eq 3 ] && ok "L10 A6 깨진 settings 심볼릭 링크 → rc=3 (없음으로 접히지 않는다)" || no "L10 A6 링크" "rc=$RC"
mkdir -p "$D/a6d/.claude/agents/x.md"; printf '# x\n' > "$D/a6d/CLAUDE.md"
"$PY" "$CHK" "$D/a6d" >/dev/null 2>&1; RC=$?
[ "$RC" -eq 3 ] && ok "L10 A6 디렉터리인 에이전트 파일(x.md/) → rc=3" || no "L10 A6 디렉터리" "rc=$RC"
mkdir -p "$D/a7"; : > "$D/a7/CLAUDE.md"; "$PY" "$CHK" "$D/a7" >/dev/null 2>&1; RC=$?
[ "$RC" -eq 3 ] && ok "L10 A7 0바이트 CLAUDE.md 만 → rc=3 (빈 내용이 PASS 로 새지 않는다)" || no "L10 A7" "rc=$RC"
mkdir -p "$D/a7b"; printf '  \n\n' > "$D/a7b/CLAUDE.md"; "$PY" "$CHK" "$D/a7b" >/dev/null 2>&1; RC=$?
[ "$RC" -eq 3 ] && ok "L10 A7 공백뿐인 CLAUDE.md → rc=3" || no "L10 A7b" "rc=$RC"
OUT=$("$PY" "$CHK" "$FX/P2_r2" 2>&1)
if printf '%s' "$OUT" | /usr/bin/grep -E '^  W4 ' | /usr/bin/grep -qF 'weekly_YYYY-MM-DD.md'; then no "L10 B9 summaries/weekly_YYYY-MM-DD.md" "W4 로 셌다"
else has "$OUT" 'summaries/weekly_YYYY-MM-DD.md' && ok "L10 B9 summaries/weekly_YYYY-MM-DD.md 는 W4 가 «아니다» (INFO 로는 보고)" || no "L10 B9" "INFO 로도 안 나옴(토큰 미관측)"; fi

# L11 — codex R2: 서브커맨드 앞 옵션 우회 5종(토큰 집합 판정) + 무해 대조 5종. fail-before: GHC_CHK=<R2 이전 사본>.
stl R2_git_dashC_nospace '{"permissions":{"allow":["Bash(git -C. push:*)"]}}' 1
stl R2_git_dashc_glued '{"permissions":{"allow":["Bash(git -cfoo=bar push:*)"]}}' 1
stl R2_git_literal_pathspecs '{"permissions":{"allow":["Bash(git --literal-pathspecs push:*)"]}}' 1
stl R2_gh_repo_opt_pr_merge '{"permissions":{"allow":["Bash(gh --repo owner/repo pr merge:*)"]}}' 1
stl R2_npm_registry_publish '{"permissions":{"allow":["Bash(npm --registry https://registry.npmjs.org publish:*)"]}}' 1
stl R2_ok_pytest '{"permissions":{"allow":["Bash(python -m pytest:*)"]}}' 0
stl R2_ok_git_status '{"permissions":{"allow":["Bash(git status)"]}}' 0
stl R2_ok_git_commit '{"permissions":{"allow":["Bash(git commit:*)"]}}' 0
stl R2_ok_ls '{"permissions":{"allow":["Bash(ls:*)"]}}' 0
stl R2_ok_echo_rm '{"permissions":{"allow":["Bash(echo rm:*)"]}}' 0
# L12 — 경로 머리(`/usr/bin/git push` · `/bin/rm`)는 이름으로 본다. 대조: 경로 머리의 무해 명령은 통과.
stl R3_path_git_push '{"permissions":{"allow":["Bash(/usr/bin/git push:*)"]}}' 1
stl R3_path_rm '{"permissions":{"allow":["Bash(/bin/rm -rf build)"]}}' 1
stl R3_ok_path_git_status '{"permissions":{"allow":["Bash(/usr/bin/git status)"]}}' 0
stl R3_path_glob '{"permissions":{"allow":["Bash(/bin/*)"]}}' 1
stl R3_path_glob_git '{"permissions":{"allow":["Bash(/usr/bin/git p*)"]}}' 1
stl R3_ok_path_glob_ls '{"permissions":{"allow":["Bash(/bin/ls:*)"]}}' 0
stl R4_newline_rm '{"permissions":{"allow":["Bash(ls\nrm x)"]}}' 1
stl R4_bg_amp_push '{"permissions":{"allow":["Bash(ls & git push)"]}}' 1
stl R4_ok_newline_ls '{"permissions":{"allow":["Bash(ls\npwd)"]}}' 0

/bin/rm -rf "$D"
echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ] && { echo "FAILED=0"; exit 0; } || { echo "FAILED=1"; exit 1; }

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
# 인터프리터·간접 실행 와일드카드 = 임의 명령 (카트리지 codex R8 A1) — 고정 대상은 통과
stl R8_sh_star '{"permissions":{"allow":["Bash(sh:*)"]}}' 1
stl R8_python3_star '{"permissions":{"allow":["Bash(python3:*)"]}}' 1
stl R8_bash_dash_c '{"permissions":{"allow":["Bash(bash -c:*)"]}}' 1
stl R8_node_space_star '{"permissions":{"allow":["Bash(node *)"]}}' 1
stl R8_timeout_wrap '{"permissions":{"allow":["Bash(timeout 5 *)"]}}' 1
stl R8_xargs_wrap '{"permissions":{"allow":["Bash(xargs:*)"]}}' 1
stl R8_path_head_sh '{"permissions":{"allow":["Bash(/bin/sh:*)"]}}' 1
stl R1_env_i_star '{"permissions":{"allow":["Bash(env -i *)"]}}' 1
stl R1_sudo_n_star '{"permissions":{"allow":["Bash(sudo -n *)"]}}' 1
stl R1_bash_cl '{"permissions":{"allow":["Bash(bash -cl:*)"]}}' 1
stl R1_bash_noprofile_c '{"permissions":{"allow":["Bash(bash --noprofile -c:*)"]}}' 1
stl R1_python_O_c '{"permissions":{"allow":["Bash(python3 -O -c:*)"]}}' 1
stl R1_node_eval_eq '{"permissions":{"allow":["Bash(node --eval=*)"]}}' 1
stl R1_python_stdin '{"permissions":{"allow":["Bash(python3 - :*)"]}}' 1
stl R1_python_versioned '{"permissions":{"allow":["Bash(python3.12:*)"]}}' 1
stl R1_lua '{"permissions":{"allow":["Bash(lua:*)"]}}' 1
stl R1_quoted_sh '{"permissions":{"allow":["Bash(\"sh\":*)"]}}' 1
stl R1_awk '{"permissions":{"allow":["Bash(awk:*)"]}}' 1
stl R1_git_alias '{"permissions":{"allow":["Bash(git -c alias.ship=!* ship)"]}}' 1
stl R1_ok_git_c_nonalias '{"permissions":{"allow":["Bash(git -c color.ui=never status)"]}}' 0
stl R1_glob_head_py '{"permissions":{"allow":["Bash(py*)"]}}' 1
stl R1_overblock_accepted_glob_head_qmark '{"permissions":{"allow":["Bash(l?:*)"]}}' 1
stl R12_ok_glob_head_ls_prefix '{"permissions":{"allow":["Bash(ls*)"]}}' 0
stl R2_deno_eval '{"permissions":{"allow":["Bash(deno eval:*)"]}}' 1
stl R2_bun_exec '{"permissions":{"allow":["Bash(bun exec:*)"]}}' 1
stl R2_python_glob_target '{"permissions":{"allow":["Bash(python3 /tmp/*)"]}}' 1
stl R2_node_prefix_target '{"permissions":{"allow":["Bash(node /tmp/job*)"]}}' 1
stl R2_glob_head_lua '{"permissions":{"allow":["Bash(lua* *)"]}}' 1
stl R2_glob_head_python_ver '{"permissions":{"allow":["Bash(python3.1* *)"]}}' 1
stl R2_ok_python_script_space_args '{"permissions":{"allow":["Bash(python3 scripts/x.py *)"]}}' 0
stl R2_overblock_accepted_deno_run_file '{"permissions":{"allow":["Bash(deno run main.ts:*)"]}}' 1
stl R3_awk_inline_program '{"permissions":{"allow":["Bash(awk BEGIN{system(ARGV[1])}/x/:*)"]}}' 1
stl R3_awk_file '{"permissions":{"allow":["Bash(awk -f scripts/x.awk:*)"]}}' 1
stl R3_python_m_timeit '{"permissions":{"allow":["Bash(python3 -m timeit:*)"]}}' 1
stl R3_python_m_pip '{"permissions":{"allow":["Bash(python3 -m pip:*)"]}}' 1
stl R3_python_m_unittest_not_reviewed '{"permissions":{"allow":["Bash(python3 -m unittest:*)"]}}' 1
stl R4_python_m_pylint '{"permissions":{"allow":["Bash(python3 -m pylint:*)"]}}' 1
stl R4_glob_head_python313 '{"permissions":{"allow":["Bash(python3.13*:*)"]}}' 1
stl R4_ok_glob_head_shellcheck '{"permissions":{"allow":["Bash(shellcheck*)"]}}' 0
stl R5_glob_head_bracket '{"permissions":{"allow":["Bash(python[3]:*)"]}}' 1
stl R5_glob_head_qmark '{"permissions":{"allow":["Bash(python3.1?:*)"]}}' 1
stl R5_npx_scoped_pkg '{"permissions":{"allow":["Bash(npx @babel/node:*)"]}}' 1
stl R5_npm_exec '{"permissions":{"allow":["Bash(npm exec:*)"]}}' 1
stl R5_pnpm_dlx '{"permissions":{"allow":["Bash(pnpm dlx:*)"]}}' 1
stl R5_ok_npm_test '{"permissions":{"allow":["Bash(npm test:*)"]}}' 0
stl R6_npm_opt_exec '{"permissions":{"allow":["Bash(npm --silent exec:*)"]}}' 1
stl R6_pnpm_opt_dlx '{"permissions":{"allow":["Bash(pnpm --silent dlx:*)"]}}' 1
stl R6_glob_head_npm_exec '{"permissions":{"allow":["Bash(npm* exec:*)"]}}' 1
stl R6_ok_glob_head_npm_test '{"permissions":{"allow":["Bash(npm* test:*)"]}}' 0
stl R7_npm_ex_glob '{"permissions":{"allow":["Bash(npm ex*)"]}}' 1
stl R7_pnpm_dl_glob '{"permissions":{"allow":["Bash(pnpm dl*:*)"]}}' 1
stl R7_overblock_accepted_npm_test_star_arg '{"permissions":{"allow":["Bash(npm test *)"]}}' 1
stl R7_ok_npm_run_build '{"permissions":{"allow":["Bash(npm run build:*)"]}}' 0
stl R8b_glob_head_bunx '{"permissions":{"allow":["Bash(bunx* @babel/node:*)"]}}' 1
stl R8b_glob_head_npx '{"permissions":{"allow":["Bash(np? cowsay:*)"]}}' 1
stl R8b_glob_head_np_q_covers_npx '{"permissions":{"allow":["Bash(np? test:*)"]}}' 1
stl R8b_glob_head_bun_also_bunx '{"permissions":{"allow":["Bash(bun* scripts/x.ts:*)"]}}' 1
stl R9_powershell_slash_command '{"permissions":{"allow":["Bash(powershell /Command:*)"]}}' 1
stl R9_powershell_slash_encoded '{"permissions":{"allow":["Bash(powershell /EncodedCommand:*)"]}}' 1
stl R9_cmd_slash_c '{"permissions":{"allow":["Bash(cmd /c:*)"]}}' 1
stl R10_glob_head_cm '{"permissions":{"allow":["Bash(cm* /c:*)"]}}' 1
stl R10_glob_head_cmd_star '{"permissions":{"allow":["Bash(cmd* /c:*)"]}}' 1
stl R11_python_qmark_target '{"permissions":{"allow":["Bash(python3 /tmp/?.py:*)"]}}' 1
stl R11_node_bracket_target '{"permissions":{"allow":["Bash(node /tmp/[ab].js:*)"]}}' 1
stl R12_glob_head_qmark_python '{"permissions":{"allow":["Bash(?ython3 -c:*)"]}}' 1
stl R12_glob_head_inner_qmark '{"permissions":{"allow":["Bash(pytho?3 -c:*)"]}}' 1
stl R13_awk_versioned_progtext '{"permissions":{"allow":["Bash(awk5 BEGIN{system(1)}/x/:*)"]}}' 1
stl R13_npx_versioned '{"permissions":{"allow":["Bash(npx2 scripts/x.js:*)"]}}' 1
stl R9c_sh_dev_stdin '{"permissions":{"allow":["Bash(sh /dev/stdin:*)"]}}' 1
stl R9c_python_dev_stdin '{"permissions":{"allow":["Bash(python3 /dev/stdin:*)"]}}' 1
stl R9c_bash_dev_fd0 '{"permissions":{"allow":["Bash(bash /dev/fd/0:*)"]}}' 1
stl R9c_node_proc_fd '{"permissions":{"allow":["Bash(node /proc/self/fd/0:*)"]}}' 1
stl R10c_sh_dot_dev_stdin '{"permissions":{"allow":["Bash(sh /./dev/stdin:*)"]}}' 1
stl R10c_sh_double_slash '{"permissions":{"allow":["Bash(sh //dev/stdin:*)"]}}' 1
stl R10c_python_tmp_abs '{"permissions":{"allow":["Bash(python3 /tmp/run.py:*)"]}}' 1
stl R10c_python_parent_escape '{"permissions":{"allow":["Bash(python3 ../../x.py:*)"]}}' 1
stl R10c_python_home '{"permissions":{"allow":["Bash(python3 ~/x.py:*)"]}}' 1
stl R10c_ok_python_dot_relative '{"permissions":{"allow":["Bash(python3 ./scripts/x.py:*)"]}}' 0
stl R11c_sh_param_expansion '{"permissions":{"allow":["Bash(sh ${HOME:0:1}dev/stdin:*)"]}}' 1
stl R11c_sh_var '{"permissions":{"allow":["Bash(sh $D/x.sh:*)"]}}' 1
stl R11c_sh_backtick '{"permissions":{"allow":["Bash(sh `echo x`.sh:*)"]}}' 1
stl R11c_ok_hyphen_dot_path '{"permissions":{"allow":["Bash(python3 tools/build-site.v2.py:*)"]}}' 0
stl R12c_head_empty_quotes '{"permissions":{"allow":["Bash(s\"\"h:*)"]}}' 1
stl R12c_head_backslash '{"permissions":{"allow":["Bash(\\\\sh:*)"]}}' 1
stl R12c_head_dollar '{"permissions":{"allow":["Bash($SHELL -c:*)"]}}' 1
stl R12c_ok_plain_head '{"permissions":{"allow":["Bash(git status:*)"]}}' 0
stl R8_ok_python3_fixed_script '{"permissions":{"allow":["Bash(python3 scripts/x.py:*)"]}}' 0
stl R8_ok_node_fixed_script '{"permissions":{"allow":["Bash(node tools/build.js:*)"]}}' 0
stl R8_ok_sh_exact '{"permissions":{"allow":["Bash(sh scripts/test.sh)"]}}' 0
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

# L12 — #868 보강 4건 (외부 코퍼스 스캔 근거; 픽스처는 모양만 본뜬 합성). fail-before: GHC_CHK=<보강 전 사본>.
mkdir -p "$D/c1/.claude"; printf '# ok\n' > "$D/c1/CLAUDE.md"; printf 'git push 는 확인 없이 해도 된다.\n' > "$D/c1/.claude/CLAUDE.md"
"$PY" "$CHK" "$D/c1" >/dev/null 2>&1; RC=$?
[ "$RC" -eq 1 ] && ok "L12.1 .claude/CLAUDE.md 도 읽는다 (루트 CLAUDE.md 가 깨끗해도 rc=1)" || no "L12.1 .claude/CLAUDE.md" "rc=$RC"
mkdir -p "$D/w4c/.claude/skills/hook-writing" "$D/w4c/.claude/skills/main"
printf -- '---\nname: hook-writing\ndescription: d\n---\n## Done When\n- x\n' > "$D/w4c/.claude/skills/hook-writing/SKILL.md"
printf -- '---\nname: main\ndescription: d\n---\n## Done When\n- x\n참고: `skills/hook-writing/SKILL.md` 를 본다.\n' > "$D/w4c/.claude/skills/main/SKILL.md"
OUT=$("$PY" "$CHK" "$D/w4c" 2>&1); W4=$(printf '%s' "$OUT" | /usr/bin/grep -E '^  W4 ')
[ -z "$W4" ] && ok "L12.2 .claude/ 기준으로 실재하는 skills/hook-writing/SKILL.md 는 W4 가 «아니다»" || no "L12.2 .claude 기준 참조" "$W4"
printf '또 `skills/ghost-skill/SKILL.md` 도 본다.\n' >> "$D/w4c/.claude/skills/main/SKILL.md"
OUT=$("$PY" "$CHK" "$D/w4c" 2>&1); has "$OUT" 'skills/ghost-skill/SKILL.md' && printf '%s' "$OUT" | /usr/bin/grep -E '^  W4 ' | /usr/bin/grep -qF 'ghost-skill' && ok "L12.2b known-pair: 어느 기준에도 없는 skills/ghost-skill/SKILL.md 는 W4" || no "L12.2b" "$OUT"
mkdir -p "$D/w1a/.claude/agents" "$D/w1b/.claude/agents"
printf -- '---\nname: r\ndescription: 읽기 전용 검토자\n---\n파일을 수정하지 않는다.\n' > "$D/w1a/.claude/agents/r.md"
printf -- '---\nname: r\ndescription: 검토자\n---\n의견을 낸다.\n' > "$D/w1b/.claude/agents/r.md"
OUTA=$("$PY" "$CHK" "$D/w1a" 2>&1); OUTB=$("$PY" "$CHK" "$D/w1b" 2>&1)
printf '%s' "$OUTA" | /usr/bin/grep -qE '^  W1 ' && ! printf '%s' "$OUTB" | /usr/bin/grep -qE '^  W1 ' && printf '%s' "$OUTB" | /usr/bin/grep -qE '^  W2 ' \
  && ok "L12.3 tools 없음+읽기 전용 주장 → W1(+W2) · 주장 없음 → W2 만" || no "L12.3 W1 확장" "A: $OUTA B: $OUTB"
mkdir -p "$D/w7/.claude/skills/low" "$D/w7ok/.claude/skills/up"
printf -- '---\nname: low\ndescription: d\n---\n## Done When\n- x\ngit push 는 확인 없이 해도 된다.\n' > "$D/w7/.claude/skills/low/skill.md"
printf -- '---\nname: up\ndescription: d\n---\n## Done When\n- x\n' > "$D/w7ok/.claude/skills/up/SKILL.md"
OUT=$("$PY" "$CHK" "$D/w7" 2>&1); RC=$?; OUTU=$("$PY" "$CHK" "$D/w7ok" 2>&1)
[ "$RC" -eq 1 ] && printf '%s' "$OUT" | /usr/bin/grep -qE '^  W7 .*skill\.md' && ! printf '%s' "$OUTU" | /usr/bin/grep -qE '^  W7 ' \
  && ok "L12.4 skill.md 는 W7 + 검사 대상에 포함(내용의 H2 로 rc=1) · 정확한 SKILL.md 는 W7 없음" || no "L12.4 W7" "rc=$RC $OUT"

# L13 — 변이 측정(mutation_probe, 2026-10-11) 이 «공백» 으로 가른 생존 변이를 죽이는 레인.
stl MP_npm_unpublish '{"permissions":{"allow":["Bash(npm unpublish x)"]}}' 1
stl MP_twine_global_opt_upload '{"permissions":{"allow":["Bash(twine --verbose upload:*)"]}}' 1
h2case MP_adjacent_negated 'Push the release. Never do it without asking.' 0
h2case MP_adjacent_permit 'Push the release. Do it without asking.' 1
mkdir -p "$D/mpfm/.claude/skills/f"
printf -- '---\nname: f\ndescription: >\n  접어 쓴 설명의 둘째 줄\n---\n## Done When\n- x\n' > "$D/mpfm/.claude/skills/f/SKILL.md"
OUT=$("$PY" "$CHK" "$D/mpfm" 2>&1); RC=$?
[ "$RC" -eq 0 ] && ! printf '%s' "$OUT" | /usr/bin/grep -qE '^  W6 ' && ok "L13 MP_frontmatter_continuation: 들여쓴 이어지는 줄은 description 으로 합쳐진다 (W6 없음, rc=0)" || no "L13 MP_frontmatter_continuation" "rc=$RC $OUT"
mkdir -p "$D/mpbn/.claude/agents" "$D/mpbn/todo"; printf 'x=1\n' > "$D/mpbn/todo/cli.py"
printf -- '---\nname: a\ndescription: d\ntools: Read\n---\n`cli.py` 와 `ghost_runtime.json` 을 본다.\n' > "$D/mpbn/.claude/agents/a.md"
OUT=$("$PY" "$CHK" "$D/mpbn" 2>&1)
printf '%s' "$OUT" | /usr/bin/grep -E '^  IO ' | /usr/bin/grep -qF 'ghost_runtime.json' && ! printf '%s' "$OUT" | /usr/bin/grep -E '^  IO ' | /usr/bin/grep -qF 'cli.py' \
  && ok "L13 MP_basename_walk: 트리 안쪽(todo/cli.py)에 있는 슬래시 없는 파일명은 INFO 도 아니다 · 없는 것만 INFO" || no "L13 MP_basename_walk" "$OUT"
mkdir -p "$D/mpnm/.claude/skills/todo-dev"
printf -- '---\nname: todo-dev\ndescription: d\n---\n## Done When\n- x\n`todo-helper` 를 부르고 `read-only` 로 본다.\n' > "$D/mpnm/.claude/skills/todo-dev/SKILL.md"
OUT=$("$PY" "$CHK" "$D/mpnm" 2>&1); W4=$(printf '%s' "$OUT" | /usr/bin/grep -E '^  W4 ')
has "$W4" 'todo-helper' && ! has "$W4" 'read-only' && ok "L13 MP_name_family: 같은 계열 접두의 없는 스킬명(todo-helper)은 W4 · 일반 하이픈어(read-only)는 아니다" || no "L13 MP_name_family" "$OUT"
"$PY" "$CHK" "$D/s1" --exclude-skill s >/dev/null 2>&1; RX=$?
[ "$RX" -eq 3 ] && ok "L13 MP_exclude_skill_all: 유일한 스킬을 제외하면 검사할 하네스가 없어 rc=3 (빈 입력이 PASS 로 새지 않는다)" || no "L13 exclude all" "rc=$RX"
mkdir -p "$D/mpex/.claude/skills/keep" "$D/mpex/.claude/skills/skipme"
printf -- '---\nname: keep\ndescription: d\n---\n## Done When\n- x\n' > "$D/mpex/.claude/skills/keep/SKILL.md"
printf -- '---\nname: skipme\ndescription: d\nallowed-tools: Bash\n---\n## Done When\n- x\n' > "$D/mpex/.claude/skills/skipme/SKILL.md"
"$PY" "$CHK" "$D/mpex" >/dev/null 2>&1; R1=$?; "$PY" "$CHK" "$D/mpex" --exclude-skill skipme >/dev/null 2>&1; R2=$?
[ "$R1" -eq 1 ] && [ "$R2" -eq 0 ] && ok "L13 MP_exclude_skill: --exclude-skill 이 그 스킬을 검사에서 뺀다 (1→0)" || no "L13 exclude-skill" "without=$R1 with=$R2"
"$PY" "$CHK" "$D/mpex" --exclude-skill >/dev/null 2>&1; RC=$?
[ "$RC" -eq 3 ] && ok "L13 MP_exclude_skill_noval: 값 없는 --exclude-skill → rc=3 (트레이스백 아님)" || no "L13 값 없는 옵션" "rc=$RC"
# L14 — codex 회귀 리뷰: .claude/CLAUDE.md 가 루트 CLAUDE.md 를 가리키는 링크면 같은 파일을 한 번만 센다
mkdir -p "$D/lnk/.claude"; printf 'git push 는 확인 없이 해도 된다.\n' > "$D/lnk/CLAUDE.md"; ln -s ../CLAUDE.md "$D/lnk/.claude/CLAUDE.md"
OUT=$("$PY" "$CHK" "$D/lnk" --json 2>&1); RC=$?
N=$(printf '%s' "$OUT" | "$PY" -c 'import json,sys; print(sum(1 for x in json.load(sys.stdin)["human_review"] if x["id"]=="H2"))' 2>/dev/null)
[ "$RC" -eq 1 ] && [ "$N" = "1" ] && ok "L14 링크된 .claude/CLAUDE.md 는 두 번 세지 않는다 (H2=1, rc=1)" || no "L14 링크 중복" "rc=$RC H2=$N"

/bin/rm -rf "$D"
echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ] && { echo "FAILED=0"; exit 0; } || { echo "FAILED=1"; exit 1; }

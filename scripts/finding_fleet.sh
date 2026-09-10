#!/usr/bin/env bash
# finding_fleet.sh — run a parallel, multi-family review fleet over one file and emit TYPED findings.
#
# WHY. FH's review output has always been prose, so nothing downstream could count it, filter it, or
# hand it to a second opinion. Measured 2026-09-08 over eight GHSA cases x3: FH made 52 claims with 5
# wrong about the code (9.6%); a sibling harness made 73 -- 40% more -- with 2 wrong (2.7%). The gap
# was not reading quality. That harness emits findings as typed records, has a different family stamp
# each one, and deletes the false positives with a filter. This script is the first half of that shape
# for FH: fan out to several families in parallel, each returning JSONL. The second half, the reject
# stage, is scripts/finding_verify.py, and it refuses to let a family verify its own findings.
#
# WHAT IS MECHANIZED: that each finding carries the family and role that produced it, that the members
# run in parallel and independently, and that a member which fails is recorded as failed rather than
# quietly contributing nothing. WHAT IS NOT: what counts as a defect. No rule about findings lives here.
#
# FLEET TABLE. One member per line, `family|role|command`. The command receives the review prompt BOTH
# on stdin and as a file whose path replaces the token PROMPT_FILE in the command — some CLIs take the
# prompt as an argument and their -p flag is variadic, so piping it silently turns the next flag into
# the prompt (measured 2026-09-08: `agy -p --model X` sent "--model" as the prompt and reported it).
# Must print JSONL findings on stdout. Override with --fleet <file>; the default is two external
# families so that neither is the Claude governor calling this script.
#
# Usage:  bash scripts/finding_fleet.sh <target-file> --out <dir> [--fleet <table>] [--roles-only]
#         bash scripts/finding_fleet.sh --selftest
# Exit:   0 = at least one member returned findings · 1 = all members failed (nothing was reviewed)
#         2 = usage error
set -uo pipefail
export LC_ALL=C
HERE="$(cd "$(dirname "$0")" && pwd)"
# Binaries are resolved from PATH, then from the usual install roots. Never hard-code a home path:
# this file ships in the npm package and a literal home directory is both a leak and wrong on the
# consumer's machine. Override with FH_CODEX_BIN / FH_AGY_BIN.
CODEX="${FH_CODEX_BIN:-$(command -v codex 2>/dev/null || echo "$HOME/.npm-global/bin/codex")}"
AGY="${FH_AGY_BIN:-$(command -v agy 2>/dev/null || echo "$HOME/.local/bin/agy")}"

default_fleet() {
  cat <<'EOF'
codex|logic|CODEX_BIN exec --sandbox read-only --skip-git-repo-check -m gpt-6-astra -c model_reasoning_effort="high"
gemini|security|AGY_BIN --model gemini-3.8-flash-high --output-format text --print-timeout 20m -p "$(cat PROMPT_FILE)"
EOF
}

PROMPT_HEAD='You are one reviewer in a parallel fleet. Review the file below for defects in your assigned area.

Output ONLY JSON Lines, one object per finding, nothing else — no prose, no code fences:
{"title":"<short claim>","file":"<name>","line":<int>,"severity":"S|A|B","category":"<one word>","detail":"<what goes wrong and when>","defeater":"<what would be OBSERVED if this claim were wrong>","confidence":<0.0-1.0>}

S = exploitable or fail-open. A = real but non-blocking. B = minor.
`defeater` is required and must name something observable — a value, an output, a code path that
would be reached — not "if I misread it". A claim whose own falsification condition cannot be stated
is a claim you are not yet entitled to make.
Report only defects you can point to a specific line for. If you find none, output nothing.

Your assigned area: '

PROMPT_HEAD_R2='You reviewed this file already. Another reviewer, from a DIFFERENT model family,
reviewed the same file independently. Both lists are below.

🟥 THIS IS NOT AN ACCEPT/REJECT PASS. You are not being asked to approve or delete the other reviewer findings.
You are being asked to produce YOUR OWN final list, having now seen theirs.

Do all of these that apply:
  - KEEP each of your findings that still holds. Do not drop one merely because the other reviewer
    did not report it — they had a different assigned area.
  - CORRECT any of yours that their list shows to be wrong, imprecise, or on the wrong line.
  - SHARPEN a finding whose `defeater` you can now state more concretely.
  - ADD findings you did not make the first time, including ones their list made you look again at.
    A finding of theirs that you can now independently confirm against the source IS yours to state —
    state it in your own words with your own defeater.
  - If you now believe one of YOUR earlier findings was wrong, drop it AND say so in a final line
    beginning `DROPPED:` naming the title and why. That line is prose and is expected.

Output ONLY JSON Lines in the same schema as before, one object per finding, then optionally the
DROPPED: lines. Your assigned area is unchanged: '

run_member_r2() { # $1=family $2=role $3=command $4=target $5=outdir
  local fam="$1" role="$2" cmd="$3" tgt="$4" out="$5"
  local q_codex q_agy q_pf
  q_codex="$(printf '%q' "$CODEX")"; q_agy="$(printf '%q' "$AGY")"
  cmd="${cmd//CODEX_BIN/$q_codex}"; cmd="${cmd//AGY_BIN/$q_agy}"
  local raw="$out/raw2_${fam}_${role}.txt" pf="$out/prompt2_${fam}_${role}.txt"
  for _p in "$raw" "$pf" "$out/err2_${fam}_${role}.txt" "$out/part2_${fam}_${role}.jsonl" "$out/peer_${fam}.txt"; do
    [ -L "$_p" ] && { echo "finding_fleet: refusing to write through a symlink: $_p" >&2; return 1; }
  done
  # 자기 것과 «남의 것» 을 갈라서 보여준다 — 어느 쪽이 자기 것인지 모르면 수정할 수가 없다
  MINE_FAM="$fam" /usr/bin/python3 -c '
import sys, json, os
mine, theirs = [], []
fam = os.environ["MINE_FAM"]
for l in open(sys.argv[1], encoding="utf-8"):
    l = l.strip()
    if not l: continue
    try: d = json.loads(l)
    except Exception: continue
    row = {k: d.get(k) for k in ("title","file","line","severity","category","detail","defeater")}
    (mine if d.get("producer_family") == fam else theirs).append(row)
with open(sys.argv[2], "w", encoding="utf-8") as w:
    w.write("\n===== YOUR OWN ROUND-1 FINDINGS =====\n")
    for r in mine: w.write(json.dumps(r, ensure_ascii=False) + "\n")
    if not mine: w.write("(you reported none)\n")
    w.write("\n===== THE OTHER FAMILY ROUND-1 FINDINGS =====\n")
    for r in theirs: w.write(json.dumps(r, ensure_ascii=False) + "\n")
    if not theirs: w.write("(they reported none)\n")
' "$out/findings_r1.jsonl" "$out/peer_${fam}.txt" || return 1
  { printf '%s%s\n\n===== FILE: %s =====\n' "$PROMPT_HEAD_R2" "$role" "$(basename "$tgt")"
    cat "$tgt"; cat "$out/peer_${fam}.txt"; } > "$pf"
  q_pf="$(printf '%q' "$pf")"
  cmd="${cmd//PROMPT_FILE/$q_pf}"
  eval "$cmd" < "$pf" > "$raw" 2>"$out/err2_${fam}_${role}.txt"
  local rc=$?
  FAM="$fam" ROLE="$role" RC="$rc" /usr/bin/python3 - "$raw" "$out/part2_${fam}_${role}.jsonl" <<'PYR2'
import json, os, sys
fam, role, rc = os.environ["FAM"], os.environ["ROLE"], os.environ["RC"]
src, dst = sys.argv[1], sys.argv[2]
n = 0
saw_bytes = False
dropped = []
with open(dst, "w", encoding="utf-8") as w:
    for line in open(src, encoding="utf-8", errors="replace"):
        line = line.strip().lstrip("\ufeff")
        if line.startswith("DROPPED:"):
            # 🟥 saw_bytes 를 여기서 «올리지 않는다». DROPPED 는 2차 계약이 요구한 출력이므로
            #    「계약 밖 응답」의 증거가 될 수 없다 (cross-family #5, codex 2026-09-10).
            # 🟥 "DROPPED: none" 은 삭제가 아니다. 세면 «숨은 수확 손실» 계측이 그 자리에서 거짓이 된다.
            body = line[len("DROPPED:"):].strip().strip("().").lower()
            if body not in ("", "none", "nothing", "n/a", "na", "없음"):
                dropped.append(line)
            continue
        if line:
            saw_bytes = True
        if not line.startswith("{"):
            continue
        try:
            d = json.loads(line)
        except json.JSONDecodeError:
            continue
        if not d.get("title"):
            continue
        n += 1
        if d.get("id") is not None:
            d["member_id"] = str(d["id"])
        d["id"] = f"{fam}-{role}-r2-{n}"
        d["producer_family"] = fam
        d["producer_role"] = role
        d["round"] = 2
        w.write(json.dumps(d, ensure_ascii=False) + "\n")
# 🟥 «전부 스스로 내렸다» 는 정당한 2차 결과이고 «차단» 이 아니다 — 별 값을 준다.
status = ("FAILED" if rc != "0" else "OK" if n > 0
          else "ZERO_SELFDROPPED" if dropped
          else "ZERO_NONJSON" if saw_bytes else "ZERO_EMPTY")
print(f"MEMBER2 family={fam} role={role} rc={rc} findings={n} self_dropped={len(dropped)} status={status}")
for l in dropped:
    print("   " + l[:200])
PYR2
}

run_member() { # $1=family $2=role $3=command $4=target $5=outdir
  local fam="$1" role="$2" cmd="$3" tgt="$4" out="$5"
  # 🟥 치환값은 eval 되는 문자열 «안»으로 들어간다. 결박하지 않으면 «출력 디렉터리 이름»만으로도
  #    명령이 실행된다 — cross-family security review 2026-09-09 가 무해한 printf 로 실증했다.
  #    여기는 bash `eval` 이므로 `printf %q` 가 옳은 도구다(shell=True 로 /bin/sh 에 넘기는
  #    finding_pipeline.sh 와는 사정이 다르다 — 거기서는 %q 가 dash 에서 깨져서 argv 로 갔다).
  local q_codex q_agy q_pf
  q_codex="$(printf '%q' "$CODEX")"; q_agy="$(printf '%q' "$AGY")"
  cmd="${cmd//CODEX_BIN/$q_codex}"; cmd="${cmd//AGY_BIN/$q_agy}"
  local raw="$out/raw_${fam}_${role}.txt" pf="$out/prompt_${fam}_${role}.txt"
  # 🟥 심링크를 통해 쓰면 남의 파일을 덮는다. 그리고 타깃이 심링크면 그 «내용»이 외부로 나간다.
  for _p in "$raw" "$pf" "$out/err_${fam}_${role}.txt" "$out/part_${fam}_${role}.jsonl"; do
    [ -L "$_p" ] && { echo "finding_fleet: refusing to write through a symlink: $_p" >&2; return 1; }
  done
  { printf '%s%s\n\n===== FILE: %s =====\n' "$PROMPT_HEAD" "$role" "$(basename "$tgt")"; cat "$tgt"; } > "$pf"
  q_pf="$(printf '%q' "$pf")"
  cmd="${cmd//PROMPT_FILE/$q_pf}"
  eval "$cmd" < "$pf" > "$raw" 2>"$out/err_${fam}_${role}.txt"
  local rc=$?
  FAM="$fam" ROLE="$role" RC="$rc" /usr/bin/python3 - "$raw" "$out/part_${fam}_${role}.jsonl" <<'PY'
import json, os, sys
fam, role, rc = os.environ["FAM"], os.environ["ROLE"], os.environ["RC"]
src, dst = sys.argv[1], sys.argv[2]
n = 0
saw_bytes = False
with open(dst, "w", encoding="utf-8") as w:
    for line in open(src, encoding="utf-8", errors="replace"):
        line = line.strip().lstrip("﻿")
        if line:
            saw_bytes = True              # 계열이 «무언가» 를 말했다는 사실은 findings 와 별개다
        if not line.startswith("{"):
            continue                      # tolerate banners and fences around the JSONL
        try:
            d = json.loads(line)
        except json.JSONDecodeError:
            continue
        if not d.get("title"):
            continue
        n += 1
        # 🟥 The member's own id is PRESERVED before renumbering. The fleet assigns a routing id
        # (`family-role-n`) because member ids collide across members — but overwriting the original
        # made the seeded control unusable end to end: a caller cannot declare `--seeded <id>` for an
        # id that does not exist until after the run. Keeping the member id lets the control be
        # declared in the caller's own vocabulary. (Found while writing the end-to-end lane; no
        # review round named it — the lane did.)
        if d.get("id") is not None:
            d["member_id"] = str(d["id"])
        d["id"] = f"{fam}-{role}-{n}"
        d["producer_family"] = fam
        d["producer_role"] = role
        w.write(json.dumps(d, ensure_ascii=False) + "\n")
# 🟥 «n==0» 은 «발견 0» 이 아니다. 이유를 단정하지 않고 «채널이 보여주는 것» 만 타입으로 적는다.
#    실측 2026-09-10 (F_typed case_g02.py r1~r3): gemini 가 안전필터 «차단» 문구를 냈는데 CLI 는
#    rc=0 이었고, 파서는 JSON 이 없어 findings=0 으로 기록했다. 그 계열이 producer 목록에서 사라져
#    드라이버가 «다른 계열 없음» 으로 읽고 codex 발견 2건을 통째로 미검증 처리했다(coverage 0/2).
if rc != "0":
    status = "FAILED"            # CLI 자체가 실패 (한도 소진 등)
elif n > 0:
    status = "OK"
elif saw_bytes:
    status = "ZERO_NONJSON"      # 응답은 «있는데» 계약(JSONL) 이 하나도 없다 — 검증 없는 0
else:
    status = "ZERO_EMPTY"        # 출력이 통째로 비었다
print(f"MEMBER family={fam} role={role} rc={rc} findings={n} status={status}")
PY
}

selftest() {
  local d fails; d="$(mktemp -d 2>/dev/null)" || d=""
  [ -n "$d" ] && [ -w "$d" ] || { echo "SELFTEST: ENV-BLOCKED (mktemp -d failed) — unmeasured, not a pass"; return 3; }
  printf 'def f(x):\n    return x\n' > "$d/t.py"
  local fails=0
  # Stub members are real scripts: they must consume stdin (a member that ignores it dies of SIGPIPE
  # on a large file, which is a property of the harness, not of the member) and then print.
  cat > "$d/m_ok.sh" <<'EOS'
#!/bin/sh
cat >/dev/null
echo '{"title":"t","file":"t.py","line":1,"severity":"B","confidence":0.5}'
EOS
  cat > "$d/m_prose.sh" <<'EOS'
#!/bin/sh
cat >/dev/null
echo "I reviewed it and it looks fine to me."
EOS
  cat > "$d/m_fail.sh" <<'EOS'
#!/bin/sh
cat >/dev/null
exit 1
EOS
  chmod +x "$d/m_ok.sh" "$d/m_prose.sh" "$d/m_fail.sh"
  printf 'stub|logic|sh %s\n' "$d/m_ok.sh" > "$d/fleet"
  bash "$0" "$d/t.py" --out "$d/o1" --fleet "$d/fleet" >/dev/null 2>&1
  if [ -s "$d/o1/findings.jsonl" ] && /usr/bin/grep -q '"producer_family": "stub"' "$d/o1/findings.jsonl"; then
    echo "  ✅ known-positive: a member's JSONL survives and is tagged with its family"
  else echo "  ❌ known-positive parse/tag"; fails=1; fi
  printf 'proser|logic|sh %s\n' "$d/m_prose.sh" > "$d/fleet2"
  bash "$0" "$d/t.py" --out "$d/o2" --fleet "$d/fleet2" >/dev/null 2>&1
  if [ ! -s "$d/o2/findings.jsonl" ]; then echo "  ✅ known-negative: prose contributes no findings"
  else echo "  ❌ known-negative: prose leaked into findings"; fails=1; fi
  printf 'faily|logic|sh %s\n' "$d/m_fail.sh" > "$d/fleet3"
  bash "$0" "$d/t.py" --out "$d/o3" --fleet "$d/fleet3" >/dev/null 2>&1
  if /usr/bin/grep -q 'rc=1' "$d/o3/members.txt" 2>/dev/null; then echo "  ✅ failing member recorded with its exit code"
  else echo "  ❌ failing member not recorded"; fails=1; fi
  if [ ! -s "$d/o3/findings.jsonl" ] && ! bash "$0" "$d/t.py" --out "$d/o4" --fleet "$d/fleet3" >/dev/null 2>&1; then
    echo "  ✅ all-members-failed exits non-zero (empty list must not read as clean)"
  else echo "  ❌ all-members-failed did not exit non-zero"; fails=1; fi
  /bin/rm -rf "$d"
  [ "$fails" -eq 0 ] && { echo "SELFTEST: PASS"; return 0; } || { echo "SELFTEST: FAIL"; return 1; }
}

[ $# -ge 1 ] || { echo "usage: $0 <target-file> --out <dir> [--fleet <table>] [--round2] | --selftest" >&2; exit 2; }
[ "$1" = "--selftest" ] && { selftest; exit $?; }
TARGET="$1"; shift
OUT=""; FLEET=""; ROUND2=0
while [ $# -gt 0 ]; do
  case "$1" in
    --out) OUT="${2:-}"; shift 2 ;;
    --fleet) FLEET="${2:-}"; shift 2 ;;
    --round2) ROUND2=1; shift ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done
[ -f "$TARGET" ] || { echo "no such file: $TARGET" >&2; exit 2; }
# 🟥 이 파일의 «내용»은 외부 모델로 전송된다. 심링크면 체크아웃 밖 자격증명을 가리킬 수 있고,
#    그러면 리뷰 대상 대신 그 비밀이 프롬프트가 된다 (residency 위반, cross-family 2026-09-09).
[ -L "$TARGET" ] && { echo "finding_fleet: target is a symlink — refusing (content is SENT to an external model)" >&2; exit 2; }
[ -r "$TARGET" ] || { echo "finding_fleet: target is not readable: $TARGET" >&2; exit 2; }
# 프롬프트 파일은 소스 전문을 담는다 — umask 022 면 0644 로 남아 다른 계정이 읽는다.
umask 077
[ -n "$OUT" ] || { echo "--out is required" >&2; exit 2; }
mkdir -p "$OUT"
if [ -n "$FLEET" ]; then cp "$FLEET" "$OUT/fleet.txt"; else default_fleet > "$OUT/fleet.txt"; fi

: > "$OUT/members.txt"
while IFS='|' read -r fam role cmd; do
  [ -n "${fam:-}" ] || continue
  case "$fam" in \#*) continue ;; esac
  run_member "$fam" "$role" "$cmd" "$TARGET" "$OUT" >> "$OUT/members.txt" 2>&1 &
done < "$OUT/fleet.txt"
wait

cat "$OUT"/part_*.jsonl > "$OUT/findings.jsonl" 2>/dev/null || : > "$OUT/findings.jsonl"
R1_TOTAL=$(/usr/bin/wc -l < "$OUT/findings.jsonl" | /usr/bin/tr -d ' ')

# ── 생성시점 탈상관 (2차 패스) ─────────────────────────────────────────────────
# 🟥 여기가 이 플래그의 논지다. 선별 시점에 계열을 교차시키면(«이 발견이 맞나» 를 남에게 묻는 것)
#   오류율은 내려가지만 **수확을 지불한다** — 실측: 8건 → 6건. 옥토는 같은 오류율 수준을
#   수확을 지불하지 않고 낸다. 차이는 계열을 «언제» 만나게 하느냐다: 걸러낼 때가 아니라 «쓸 때».
#   그래서 2차 패스는 수락/거부를 묻지 않는다 — 상대의 목록을 보고 **자기 목록을 다시 쓰게** 한다.
#   자기 발견을 스스로 내리면 `DROPPED:` 로 사유를 적게 하고, 그 수를 센다(숨은 수확 손실 계측).
if [ "$ROUND2" -eq 1 ]; then
  if [ "$R1_TOTAL" -eq 0 ]; then
    echo "FLEET round2 skipped — round 1 produced no findings (nothing to decorrelate against)"
  else
    cp "$OUT/findings.jsonl" "$OUT/findings_r1.jsonl"
    while IFS='|' read -r fam role cmd; do
      [ -n "${fam:-}" ] || continue
      case "$fam" in \#*) continue ;; esac
      run_member_r2 "$fam" "$role" "$cmd" "$TARGET" "$OUT" >> "$OUT/members.txt" 2>&1 &
    done < "$OUT/fleet.txt"
    wait
    # 🟥 교체는 **멤버별** 이다. 초판은 all-or-nothing 이었고 결함 둘을 동시에 만들었다
    #    (cross-family, codex 2026-09-10):
    #    ① `[ -s "$(ls part2_*.jsonl | head -1)" ]` 은 **glob 첫 파일만** 봤다. codex 것이 비고
    #       gemini 것이 차 있으면 «2차가 아무것도 못 냈다» 고 «거짓 보고» 하며 1차를 유지했다.
    #    ② 반대로 첫 파일이 차 있으면 **실패한 멤버의 1차 발견까지 통째로 사라졌다** — 그 멤버가
    #       2차에서 일부만 내고 죽어도 교체가 일어났고, `failed_members` 는 `^MEMBER ` 만 세어
    #       MEMBER2 실패를 못 봐서 `failed_members=0 rc=0` 으로 나갔다. 조용한 수확 삭제다.
    #    ⇒ 2차가 «성공한» 멤버만 2차 목록으로 갈아끼우고, 실패한 멤버는 자기 1차를 그대로 쓴다.
    R2_FALLBACK=0; R2_OK=0
    : > "$OUT/findings_r2merged.jsonl"
    while IFS='|' read -r _fam _role _cmd; do
      [ -n "${_fam:-}" ] || continue
      case "$_fam" in \#*) continue ;; esac
      _st=$(/usr/bin/sed -n "s/^MEMBER2 family=$_fam role=$_role .*status=\([A-Z_]*\).*/\1/p" "$OUT/members.txt" | tail -1)
      _p2="$OUT/part2_${_fam}_${_role}.jsonl"; _p1="$OUT/part_${_fam}_${_role}.jsonl"
      if [ "${_st:-FAILED}" = "FAILED" ]; then
        [ -f "$_p1" ] && cat "$_p1" >> "$OUT/findings_r2merged.jsonl"
        R2_FALLBACK=$((R2_FALLBACK + 1))
        echo "FLEET round2 member=$_fam/$_role FAILED — keeping ITS round-1 findings (per-member fallback)"
      else
        [ -f "$_p2" ] && cat "$_p2" >> "$OUT/findings_r2merged.jsonl"
        R2_OK=$((R2_OK + 1))
      fi
    done < "$OUT/fleet.txt"
    if [ -s "$OUT/findings_r2merged.jsonl" ]; then
      /bin/mv "$OUT/findings_r2merged.jsonl" "$OUT/findings.jsonl"
    else
      # 🟥 합쳐서도 비면 1차를 «대체» 하지 않는다 — 그러면 탈상관이 아니라 삭제다.
      echo "FLEET round2 produced nothing — keeping round-1 findings (a failed 2nd pass must not delete the 1st)"
    fi
    echo "FLEET round2 members_ok=$R2_OK fallback=$R2_FALLBACK"
    R2_TOTAL=$(/usr/bin/wc -l < "$OUT/findings.jsonl" | /usr/bin/tr -d ' ')
    echo "FLEET round2 r1=$R1_TOTAL r2=$R2_TOTAL delta=$((R2_TOTAL - R1_TOTAL))"
  fi
fi
TOTAL=$(/usr/bin/wc -l < "$OUT/findings.jsonl" | /usr/bin/tr -d ' ')
MEMBERS=$(/usr/bin/wc -l < "$OUT/fleet.txt" | /usr/bin/tr -d ' ')
OK=$(/usr/bin/grep -c 'rc=0' "$OUT/members.txt" 2>/dev/null); OK=${OK:-0}   # 🟥 never `|| echo 0` here: grep prints 0 AND the fallback echoes 0, giving "0\n0"
echo "FLEET members=$MEMBERS ok=$OK findings=$TOTAL out=$OUT"
cat "$OUT/members.txt"
[ "$OK" -gt 0 ] || { echo "🟥 every member failed — nothing was reviewed, and an empty finding list here means UNREVIEWED, not clean"; exit 1; }
exit 0

#!/usr/bin/env bash
# test_outbound_pr_gate_lanes.sh — known pairs for scripts/outbound_pr_gate.sh.
#
# Both directions on every axis: the applicability test (owned vs non-owned), the record test
# (strong rung vs weak rung, present vs absent, grounded vs vacuous), and the delivery test
# (deny = exit 2, advisory = exit 0 with output, silent = exit 0 with none).
# L8 is the CLASS-CLOSING arm: it reads the `standpoint:` closed enum out of
# templates/.git-hooks/pre-commit and fails if the gate classifies neither strong nor weak — so a
# new enum member cannot be added without deciding what it means on the outbound surface.
# L9 is the REVERT probe: neuter the strong-rung allow-list and L1 must go red.
# L6b/L6c cover the COLD START (zero record FILES — rec() always writes one, so L6 is the
# empty-record branch, a different path) and anchor its skeleton with a second revert probe.
# L17/L17b are the WIRING arms: the snippet must register this hook, and the gate must finish
# inside the timeout the snippet configures — a hook killed by its own timeout is fail-OPEN.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
GATE="$HERE/outbound_pr_gate.sh"
PRECOMMIT="${FH_PRECOMMIT_FILE:-$REPO/templates/.git-hooks/pre-commit}"
fail=0; n=0
TMP=$(mktemp -d) || { echo "FAIL  mktemp"; exit 1; }
trap 'rm -rf "$TMP"' EXIT

# ── fixture world ─────────────────────────────────────────────────────────────────────────────
FHROOT="$TMP/fh"; mkdir -p "$FHROOT/scripts" "$FHROOT/tracks/_meta"
: > "$FHROOT/scripts/session_close_check.sh"          # the applicability anchor
git init -q "$FHROOT" 2>/dev/null
git -C "$FHROOT" remote add origin https://github.com/ownerco/forge-harness.git 2>/dev/null
mkfork() { # $1 = dir, $2 = origin spec, $3 = upstream spec (empty = none)
  mkdir -p "$1"; git init -q "$1" 2>/dev/null
  git -C "$1" remote add origin "https://github.com/$2.git" 2>/dev/null
  [ -n "${3:-}" ] && git -C "$1" remote add upstream "https://github.com/$3.git" 2>/dev/null
  return 0
}
mkfork "$TMP/foreignfork" "ownerco/archify" "tt-a1i/archify"   # fork of a repo we do NOT own
mkfork "$TMP/ourclone"    "ownerco/forge-harness" ""           # our own repo, no fork parent
mkfork "$TMP/directclone" "someoneelse/tool" ""                # DIRECT clone of a foreign repo

TODAY="2026-01-01"
rec() { # $1 = standpoint value, $2 = generated-path, $3 = fixture-carries  ("" = omit the line)
  rm -f "$FHROOT/tracks/_meta"/outbound_pr_*.md
  local f="$FHROOT/tracks/_meta/outbound_pr_${TODAY}_fixture.md"
  : > "$f"
  [ -n "${1:-}" ] && printf 'standpoint: %s\n' "$1" >> "$f"
  [ -n "${2:-}" ] && printf 'generated-path: %s\n' "$2" >> "$f"
  [ -n "${3:-}" ] && printf 'fixture-carries: %s\n' "$3" >> "$f"
  return 0
}
norec() { # zero record FILES. rec() always CREATES the file, so rec "" "" "" is an EMPTY
          # record, not an absent one — a different branch of the gate.
  rm -f "$FHROOT/tracks/_meta"/outbound_pr_*.md
  return 0
}
FULL_SP='tier2(archify) — ran `node scripts/export.mjs` there, output: wrote 3 files, input intact'
FULL_GP='none-found(grepped package.json scripts and every *.mjs for a writer of that path)'
FULL_AR='asserted(`node t.mjs` with dest symlinked to the input, output: input bytes unchanged)'

run() { # $1 = label, $2 = expected verdict deny|advisory|silent, $3 = command string, $4 = cwd
  n=$((n+1))
  local out rc
  out=$(printf '{"tool_name":"Bash","cwd":"%s","tool_input":{"command":"%s"}}' "${4:-}" "$3" \
        | CLAUDE_PROJECT_DIR="$FHROOT" FH_OUTBOUND_TODAY="$TODAY" \
          FH_OUTBOUND_RECDIR="$FHROOT/tracks/_meta" bash "$GATE" 2>&1); rc=$?
  local got="silent"
  [ "$rc" -eq 2 ] && got="deny"
  [ "$rc" -eq 0 ] && [ -n "$out" ] && got="advisory"
  if [ "$got" = "$2" ]; then
    echo "PASS  $1 ($got)"
  else
    echo "FAIL  $1: expected $2, got $got (rc=$rc)"
    printf '%s\n' "$out" | sed 's/^/        /' | head -6
    fail=1
  fi
}

# ── L1 known-POSITIVE: non-owned target, weak rung -> deny ────────────────────────────────────
rec 'tier1b(archify) — read their export path end to end' "$FULL_GP" "$FULL_AR"
run "L1  non-owned + standpoint tier1b" deny "gh pr create -R tt-a1i/archify --title x"

# ── L2 known-NEGATIVE: same target, full record -> silent ─────────────────────────────────────
rec "$FULL_SP" "$FULL_GP" "$FULL_AR"
run "L2  non-owned + full record" silent "gh pr create -R tt-a1i/archify --title x"

# ── L3 our own repo: never blocked, record or not ─────────────────────────────────────────────
rec "" "" ""
run "L3  owned target, no record" silent "gh pr create -R ownerco/forge-harness --title x"

# ── L4 applicability undetermined -> advisory, NEVER deny ─────────────────────────────────────
rec "" "" ""
run "L4  bare gh pr create, no cwd" advisory "gh pr create --title x"

# ── L5 not the outbound act ───────────────────────────────────────────────────────────────────
run "L5  unrelated command" silent "gh pr list --state open"
run "L5b gh pr merge is not create" silent "gh pr merge 12 --squash"

# ── L6 record absent entirely on a non-owned target ───────────────────────────────────────────
rec "" "" ""
run "L6  non-owned + no record at all" deny "gh pr create -R tt-a1i/archify --title x"

# ── L6b COLD START: zero record FILES, which L6 above does NOT cover ───────────────────────
#   rec "" "" "" writes an EMPTY file, so L6 exercises the per-field "line absent" branches. The
#   _records=0 branch had NO lane at all, and it was the one a first-time session actually hits:
#   it printed a path and nothing else, because the three field syntaxes live in the per-field
#   branches that are unreachable when there is no file. Assert the skeleton by FIELD NAME.
norec
run "L6b zero record files (not an empty one)" deny "gh pr create -R tt-a1i/archify --title x"
_cold_out() { # $1 = gate to run
  norec
  printf '{"tool_name":"Bash","tool_input":{"command":"gh pr create -R tt-a1i/archify --title x"}}' \
    | CLAUDE_PROJECT_DIR="$FHROOT" FH_OUTBOUND_TODAY="$TODAY" \
      FH_OUTBOUND_RECDIR="$FHROOT/tracks/_meta" bash "$1" 2>&1
}
_COLD=$(_cold_out "$GATE")
for _f in standpoint generated-path fixture-carries; do
  n=$((n+1))
  if printf '%s' "$_COLD" | grep -q "^ *$_f:"; then
    echo "PASS  L6b cold start names the field '$_f'"
  else
    echo "FAIL  L6b cold start does NOT name '$_f' — a first-time session gets a path and nothing else"
    fail=1
  fi
done

# ── L6c REVERT PROBE for L6b: strip the skeleton; the three field names must disappear ───────
#   Without this, L6b would also pass on output that names the fields for some OTHER reason.
n=$((n+1))
COLDMUT="$TMP/coldmutant.sh"
sed -E '/^        (standpoint|generated-path|fixture-carries): /d' "$GATE" > "$COLDMUT"
_removed=$(( $(grep -cE '^        (standpoint|generated-path|fixture-carries): ' "$GATE") \
             - $(grep -cE '^        (standpoint|generated-path|fixture-carries): ' "$COLDMUT") ))
if [ "$_removed" -ne 3 ]; then
  echo "FAIL  L6c INSTRUMENT ERROR — mutation removed $_removed skeleton lines, expected 3; the probe would pass vacuously"
  fail=1
elif ! bash -n "$COLDMUT" 2>/dev/null; then
  echo "FAIL  L6c INSTRUMENT ERROR — the mutant does not parse, so its silence means nothing"
  fail=1
else
  _hits=$(_cold_out "$COLDMUT" | grep -cE "^ *(standpoint|generated-path|fixture-carries):" || true)
  if [ "$_hits" -eq 0 ]; then
    echo "PASS  L6c revert probe: stripping the skeleton takes all three field names off the cold-start deny"
  else
    echo "FAIL  L6c revert probe: $_hits field name(s) survived the strip — L6b is not anchored to the skeleton"
    fail=1
  fi
fi

# ── L7 vacuous grounds ────────────────────────────────────────────────────────────────────────
rec "$FULL_SP" 'none-found()' "$FULL_AR"
run "L7  generated-path with empty grounds" deny "gh pr create -R tt-a1i/archify --title x"
rec 'tier2(archify) — looked' "$FULL_GP" "$FULL_AR"
run "L7b standpoint tier2 naming no execution" deny "gh pr create -R tt-a1i/archify --title x"

# ── L10 DEGRADED_NOT_RUN is an honest record AND a not-ready verdict ──────────────────────────
rec "$FULL_SP" "$FULL_GP" 'DEGRADED_NOT_RUN(no local chromium on this machine, nothing was run)'
run "L10 fixture-carries DEGRADED_NOT_RUN" deny "gh pr create -R tt-a1i/archify --title x"

# ── L10b spelling C (composition / first-match-only) is an accepted answer on the SAME field ──
# Rationale for folding rather than adding a 4th field is in the gate header. This lane pins that
# the C answer clears the gate, so the folding is real and not just documentation.
rec "$FULL_SP" "$FULL_GP" 'asserted(`node t.mjs "npm publish --dry-run && rm -rf /"` — 2 effective decisions, first excepted; saw hold:false, expected hold:true)'
run "L10b fixture-carries answered with spelling C" silent "gh pr create -R tt-a1i/archify --title x"

# ── L11 fork detection, both directions, via cwd (no -R in the command) ───────────────────────
rec 'tier1b(archify) — read only' "$FULL_GP" "$FULL_AR"
run "L11a cwd is a fork of a foreign repo" deny "gh pr create --title x" "$TMP/foreignfork"
run "L11b cwd is our own clone"           silent "gh pr create --title x" "$TMP/ourclone"
run "L11c cwd is a DIRECT clone of a foreign repo" deny "gh pr create --title x" "$TMP/directclone"

# ── L12 override is acknowledged, recorded in the command, and does not satisfy ───────────────
rec "" "" ""
run "L12 FH_OUTBOUND_PR_OK=1 in the command" advisory "FH_OUTBOUND_PR_OK=1 gh pr create -R tt-a1i/archify --title x"

# ── L13 not an FH checkout -> silent, and we create nothing there ─────────────────────────────
n=$((n+1))
_out=$(printf '{"tool_name":"Bash","tool_input":{"command":"gh pr create -R tt-a1i/archify"}}' \
       | CLAUDE_PROJECT_DIR="$TMP/notfh" FH_OUTBOUND_ANCHOR="$TMP/notfh/nope" bash "$GATE" 2>&1); _rc=$?
if [ "$_rc" -eq 0 ] && [ -z "$_out" ]; then echo "PASS  L13 non-FH checkout is silent"
else echo "FAIL  L13 non-FH checkout: rc=$_rc out='$_out'"; fail=1; fi

# ── L8 CLASS-CLOSING: every standpoint: enum member must be classified by this gate ───────────
n=$((n+1))
# Scope the read to validate_standpoint_leg()'s own body first — an unscoped grep for the enum
# text picked up three unrelated lines elsewhere in the hook and reported them as members
# (first run of this lane, 2026-09-18: the instrument had to be calibrated before it measured).
ENUM=$(awk '/^validate_standpoint_leg\(\)/{f=1} f&&/^}/{f=0} f' "$PRECOMMIT" 2>/dev/null \
       | awk '/Closed enum:/{print; getline; print}' \
       | tr '·' '\n' | sed -E 's/^[[:space:]]*echo[[:space:]]+"//; s/.*Closed enum:[[:space:]]*//; s/\(<h>\)//g; s/[^A-Za-z0-9_-]//g' \
       | grep -E '^[A-Za-z]' | sort -u)
if [ -z "$ENUM" ]; then
  echo "FAIL  L8 INSTRUMENT ERROR — could not extract the standpoint enum from $PRECOMMIT"
  fail=1
else
  DECLARED=$( { grep -m1 '^STRONG_RUNGS=' "$GATE"; grep -m1 '^WEAK_RUNGS=' "$GATE"; } \
              | sed -E 's/^[A-Z_]+="//; s/"$//' | tr ' ' '\n' | grep -E '^[A-Za-z]' | sort -u)
  missing=$(comm -23 <(printf '%s\n' "$ENUM") <(printf '%s\n' "$DECLARED"))
  if [ -n "$missing" ]; then
    echo "FAIL  L8 standpoint enum member(s) unclassified by outbound_pr_gate.sh:"
    printf '%s\n' "$missing" | sed 's/^/        /'
    echo "        Classify each as STRONG_RUNGS (clears the outbound gate) or WEAK_RUNGS (blocks it)."
    fail=1
  else
    echo "PASS  L8 class-closing: all $(printf '%s\n' "$ENUM" | wc -l | tr -d ' ') enum members classified"
  fi
fi

# ── L8b known-POSITIVE for the class-closing arm: add a member, L8's comparison must name it ──
n=$((n+1))
FAKEPC="$TMP/pre-commit-with-new-member"
sed -E 's/(Closed enum: tier1 )/\1· tier4(<h>) /' "$PRECOMMIT" > "$FAKEPC" 2>/dev/null
ENUM2=$(awk '/^validate_standpoint_leg\(\)/{f=1} f&&/^}/{f=0} f' "$FAKEPC" 2>/dev/null \
       | awk '/Closed enum:/{print; getline; print}' \
       | tr '·' '\n' | sed -E 's/^[[:space:]]*echo[[:space:]]+"//; s/.*Closed enum:[[:space:]]*//; s/\(<h>\)//g; s/[^A-Za-z0-9_-]//g' \
       | grep -E '^[A-Za-z]' | sort -u)
DECLARED2=$( { grep -m1 '^STRONG_RUNGS=' "$GATE"; grep -m1 '^WEAK_RUNGS=' "$GATE"; } \
            | sed -E 's/^[A-Z_]+="//; s/"$//' | tr ' ' '\n' | grep -E '^[A-Za-z]' | sort -u)
if printf '%s\n' "$(comm -23 <(printf '%s\n' "$ENUM2") <(printf '%s\n' "$DECLARED2"))" | grep -qx 'tier4'; then
  echo "PASS  L8b class-closing arm goes RED when an enum member is added"
else
  echo "FAIL  L8b class-closing arm did NOT notice an added enum member — L8 green means nothing"
  fail=1
fi

# ── L9 REVERT PROBE: neuter the allow-list; L1 must go red ────────────────────────────────────
n=$((n+1))
MUT="$TMP/mutant.sh"
sed -E 's/^([[:space:]]*)tier2\\\(\*\\\)\|tier2b\\\(\*\\\)\|tier3\\\(\*\\\)\)/\1*)/' "$GATE" > "$MUT"
if ! grep -qE '^[[:space:]]*\*\)$' "$MUT"; then
  echo "FAIL  L9 INSTRUMENT ERROR — the mutation did not apply; the probe would pass vacuously"
  fail=1
else
  rec 'tier1b(archify) — read their export path end to end' "$FULL_GP" "$FULL_AR"
  _o=$(printf '{"tool_name":"Bash","tool_input":{"command":"gh pr create -R tt-a1i/archify"}}' \
       | CLAUDE_PROJECT_DIR="$FHROOT" FH_OUTBOUND_TODAY="$TODAY" \
         FH_OUTBOUND_RECDIR="$FHROOT/tracks/_meta" bash "$MUT" 2>&1); _r=$?
  if [ "$_r" -eq 2 ]; then
    echo "FAIL  L9 revert probe: the neutered allow-list STILL denied — L1 is not anchored to it"
    fail=1
  else
    echo "PASS  L9 revert probe: neutering the allow-list turns L1's deny off (rc=$_r)"
  fi
fi


# ── L14 트리거 형태 — cross-family(codex 2026-09-18)가 공격한 자리 ───────────────────────────
# 🟥 그 지적 7건 중 5건은 실측에서 **틀렸다**(`command gh`·`env X=1 gh`·`time gh`·`noglob gh`·
#    인용 repo 는 종전 식으로도 잡혔다). 아래 셋만 진짜였고, 앞의 둘을 수리로 닫았다.
#    이 레인들은 그 수리의 회귀 앵커다 — 정규식이 좁아지면 여기가 적색이 된다.
rec 'tier1b(archify) — read their export path end to end' "$FULL_GP" "$FULL_AR"
run "L14a 절대경로 gh 도 잡힌다" deny "/opt/homebrew/bin/gh pr create -R tt-a1i/archify --title x"
rec 'tier1b(archify) — read their export path end to end' "$FULL_GP" "$FULL_AR"
run "L14b 상대경로 ./gh 도 잡힌다" deny "./gh pr create -R tt-a1i/archify --title x"
rec 'tier1b(archify) — read their export path end to end' "$FULL_GP" "$FULL_AR"
run "L14c 인용 안쪽 sh -c 도 잡힌다" deny "sh -c 'gh pr create -R tt-a1i/archify --title x'"

# ── L15 구조적 잔여를 «핀» 으로 박는다 (커버리지 주장이 아니라 잔여 선언) ────────────────────
# 🟥 변수 간접은 정규식으로 닫히지 않는다. 이 레인은 그 사실을 **고정**한다 — 누가 「닫혔다」고
#    적으면 여기가 적색이 되어 거짓 주장을 막는다. silent 를 기대하는 것이 의도다.
rec 'tier1b(archify) — read their export path end to end' "$FULL_GP" "$FULL_AR"
# 🟥 `$GH_CMD` 는 **리터럴로 가야 한다** — 초판이 이중인용에 그대로 써서 레인 셸이 확장했고
#    `set -u` 에서 그 자리에서 죽었다(L14 까지만 돌고 스위트 중단). 단일인용으로 고정한다.
run "L15 변수 간접은 NAMED GAP 이다 (silent 가 기대값)" silent 'GH_CMD=gh; $GH_CMD pr create -R tt-a1i/archify'

# ── L16 known-NEGATIVE: 넓힌 문자류가 관계없는 명령을 잡지 않는가 ─────────────────────────────
rec "$FULL_SP" "$FULL_GP" "$FULL_AR"
run "L16 gh pr edit 는 여전히 NAMED GAP" silent "gh pr edit --body x -R tt-a1i/archify"
rec "$FULL_SP" "$FULL_GP" "$FULL_AR"
run "L16b gh pr list 는 트리거 아님" silent "gh pr list -R tt-a1i/archify"

# ── L17 WIRING: does the shipped snippet actually register this hook? ────────────────────
#   Shipping (package.json files[]) and WIRING (a settings snippet) are different propositions —
#   v3.13.0 shipped this script and registered it nowhere, and nothing anywhere went red for it.
#   install-wizard globs templates/settings.*.snippet.json and merges keyed on scripts/<name>.sh,
#   so the snippet entry IS the wiring for every install; dropping it is a silent un-wiring.
SNIP="$REPO/templates/settings.PreToolUse.snippet.json"
_SNIP_TO=$(python3 -c '
import json,sys
d=json.load(open(sys.argv[1]))
for m in d["project_settings_json"]["hooks"]["PreToolUse"]:
    if m.get("matcher")=="Bash":
        for h in m.get("hooks",[]):
            if "outbound_pr_gate.sh" in h.get("command",""):
                print(h.get("timeout","")); sys.exit(0)
' "$SNIP" 2>/dev/null)
n=$((n+1))
if [ -n "$_SNIP_TO" ]; then
  echo "PASS  L17 스니펫의 Bash matcher 가 outbound_pr_gate.sh 를 등록한다 (timeout=${_SNIP_TO}s)"
else
  echo "FAIL  L17 스니펫에 이 훅이 없다 — 출하되지만 배선 0 이면 게이트가 아니라 파일이다"
  fail=1
fi

# L17a known-NEGATIVE for L17: strip the entry from a COPY and the extractor must come back empty.
# Without this arm, an extractor that silently matched anything would pass L17 vacuously.
n=$((n+1))
SNIPMUT="$TMP/snippet_unwired.json"
python3 -c '
import json,sys
d=json.load(open(sys.argv[1]))
for m in d["project_settings_json"]["hooks"]["PreToolUse"]:
    if m.get("matcher")=="Bash":
        m["hooks"]=[h for h in m.get("hooks",[]) if "outbound_pr_gate.sh" not in h.get("command","")]
json.dump(d,open(sys.argv[2],"w"))
' "$SNIP" "$SNIPMUT" 2>/dev/null
_MUT_TO=$(python3 -c '
import json,sys
d=json.load(open(sys.argv[1]))
for m in d["project_settings_json"]["hooks"]["PreToolUse"]:
    if m.get("matcher")=="Bash":
        for h in m.get("hooks",[]):
            if "outbound_pr_gate.sh" in h.get("command",""):
                print(h.get("timeout","")); sys.exit(0)
' "$SNIPMUT" 2>/dev/null)
if [ ! -s "$SNIPMUT" ]; then
  echo "FAIL  L17a INSTRUMENT ERROR — the un-wired copy was not produced; the arm would pass vacuously"
  fail=1
elif [ -z "$_MUT_TO" ]; then
  echo "PASS  L17a un-wiring the snippet makes L17's extractor come back empty (it measures, not generates)"
else
  echo "FAIL  L17a the extractor still found a timeout ($_MUT_TO) in a snippet with the entry removed"
  fail=1
fi

# ── L17b the gate must SURVIVE the timeout the snippet configures ──────────────────────
#   A PreToolUse hook killed by its own timeout is a non-blocking error — the tool RUNS. So a deny
#   that is too slow is fail-OPEN, with no override and no log. Measured once already on the sixth
#   guard (10KB took 47s under bash 3.2 against a "timeout": 5). Read the budget FROM the snippet:
#   a lane that allowed more than production does would pass a hook production lets through.
n=$((n+1))
[ -n "$_SNIP_TO" ] || _SNIP_TO=5
norec
_PAY=$(python3 -c 'import json;print(json.dumps({"tool_name":"Bash","tool_input":{"command":"gh pr create -R tt-a1i/archify --body "+"x"*20000}}))')
printf '%s' "$_PAY" \
  | CLAUDE_PROJECT_DIR="$FHROOT" FH_OUTBOUND_TODAY="$TODAY" \
    FH_OUTBOUND_RECDIR="$FHROOT/tracks/_meta" timeout "$_SNIP_TO" bash "$GATE" >/dev/null 2>&1
_rc=$?
if [ "$_rc" -eq 124 ]; then
  echo "FAIL  L17b 20KB 페이로드가 스니펫 timeout(${_SNIP_TO}s) 에 죽었다 — 죽은 훅은 fail-OPEN 이다"
  fail=1
elif [ "$_rc" -eq 2 ]; then
  echo "PASS  L17b 20KB 페이로드도 스니펫 timeout(${_SNIP_TO}s) 안에 deny 로 끝난다"
else
  echo "FAIL  L17b 20KB 페이로드가 deny 가 아니다 (rc=$_rc) — 길다고 스캔을 건너뛰면 안 된다"
  fail=1
fi

echo "── $n lanes, $( [ $fail -eq 0 ] && echo 'all green' || echo 'FAILURES above' ) ──"
exit $fail

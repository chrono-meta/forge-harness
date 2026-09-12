#!/usr/bin/env bash
# finding_pipeline.sh — the driver that runs fleet → cross-family reject → drop audit end to end.
# Until this file the two halves existed but nothing called them together outside the lane suite.
#
#   bash scripts/finding_pipeline.sh <target-file> --out <dir> [--fleet <table>]
#
# WHY THE TWO-SPLIT SHAPE (the load-bearing design decision, not an implementation detail):
# finding_verify.py refuses to let a family judge its own findings — it stamps them `unverified`
# rather than judging. With a two-family fleet, ONE verify pass therefore leaves half the findings
# unjudged, and an `unverified` finding still counts as a survivor. Running it that way and reporting
# the survivor count would silently mean "half of these were never checked". So the run is split by
# producer:
#     gemini-produced  → verifier codex  → drop auditor gemini
#     codex-produced   → verifier gemini → drop auditor codex
#
# 🟥 NAMED RESIDUAL — with only two families the drop auditor is ALWAYS the producer (an appeal),
# never a disinterested third party. That is weaker than the protocol allows for, and it is a property
# of the panel size. Do not read `AUDITED` from a two-family run as `independently audited`; the
# per-finding `audit_role` field says which it was.
# 🟥 AND A THIRD FAMILY DOES NOT COME FOR FREE. An earlier draft of this comment claimed the driver
# "picks up a third family automatically". It cannot: finding_verifier.sh only speaks codex|gemini, so
# an unknown family exits 2 and the drops come back unaudited (rc=4). Routing is therefore restricted
# to families the wrapper actually implements — SUPPORTED below — and adding one means adding a
# backend there first. (cross-family review, 2026-09-09; the claim was mine and was wrong.)
#
# EXIT  0 every split verified and every drop audited, with survivors · 1 verified but nothing survived
#       2 usage / schema · 3 UNVERIFIED — some split was not cross-verified (degraded, never a silent
#       pass) · 4 drops happened that were never audited
set -uo pipefail

SUPPORTED_FAMILIES="codex gemini"          # must match finding_verifier.sh's own case statement

TARGET=""; OUT=""; FLEET=""; SEEDED_IDS=""; SEEDED_FILE=""; SEEDS_ROUTED=""; ROUND2=0; ROUND2_BLIND=0; R1_ONLY=0; REUSE_R1=""
usage() { echo "usage: finding_pipeline.sh <target-file> --out <dir> [--fleet <table>] [--round2|--round2-blind] [--r1-only] [--reuse-r1 <dir>] [--seeded <ids>] [--seeded-file <path>]" >&2; exit 2; }
need() { [ $# -ge 2 ] || { echo "finding_pipeline: $1 needs a value" >&2; exit 2; }; }
[ $# -ge 1 ] || usage
TARGET="$1"; shift
while [ $# -gt 0 ]; do
  case "$1" in
    --round2)      ROUND2=1; shift ;;
    --round2-blind) ROUND2=1; ROUND2_BLIND=1; shift ;;
    # 짝지음(paired) — 플래그만 fleet 으로 통과시킨다(측정 층은 fleet 이다). RESULT §15 잔여 참조.
    --r1-only)     R1_ONLY=1; shift ;;
    --reuse-r1)    REUSE_R1="${2:-}"; shift 2 ;;
    --seeded)      need "$@"; SEEDED_IDS="$2"; shift 2 ;;
    --seeded-file) need "$@"; SEEDED_FILE="$2"; shift 2 ;;
    --out)   need "$@"; OUT="$2"; shift 2 ;;    # `shift 2` on a trailing flag consumes nothing and
    --fleet) need "$@"; FLEET="$2"; shift 2 ;;  # spins forever; codex reproduced the hang.
    *) usage ;;
  esac
done
[ -n "$TARGET" ] && [ -f "$TARGET" ] && [ -r "$TARGET" ] \
  || { echo "finding_pipeline: target must be a readable file" >&2; exit 2; }
# 🟥 타깃이 심링크면 체크아웃 «밖»을 가리킬 수 있고, 그 내용은 외부 모델로 전송된다.
#    리뷰하려던 것은 레포 코드인데 나가는 것은 남의 비밀이 된다 — residency 위반이다.
#    강행이 필요하면 실제 파일 경로를 직접 주면 된다(그 판단은 사람이 한다).
if [ -L "$TARGET" ]; then
  echo "finding_pipeline: target is a symlink — refusing (it may point outside the checkout, and the content is SENT to an external model)" >&2
  exit 2
fi
[ -n "$OUT" ] || usage
# 🟥 출력물은 프롬프트와 소스를 담는다 — 권한을 좁혀서 만든다(umask 022 면 0644 로 남는다).
umask 077
mkdir -p "$OUT" || { echo "finding_pipeline: cannot create --out" >&2; exit 2; }
# 🟥 미리 깔린 심링크를 따라가면 «출력»이 남의 파일 truncate 가 된다. 리다이렉션도 open() 도
#    심링크를 따라간다 — 그래서 쓰기 «전»에 거부한다(cross-family review 2026-09-09).
for _p in "$OUT" "$OUT/fleet" "$OUT/confirmed.jsonl" "$OUT/dropped.jsonl" "$OUT/splits.txt" "$OUT/families.txt" "$OUT/roster.txt" "$OUT/roster.err" "$OUT/families.err"; do
  if [ -L "$_p" ]; then
    echo "finding_pipeline: refusing to write through a symlink: $_p" >&2; exit 2
  fi
done

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 씨앗 선언을 «작업 시작 전» 에 확정한다 — verify 쪽과 같은 규율(빈 파일·디코드 오류는 설정 오류다)
ALL_SEEDS="$SEEDED_IDS"
if [ -n "$SEEDED_FILE" ]; then
  _FROM_FILE=$(/usr/bin/python3 -c '
import sys
try:
    with open(sys.argv[1], encoding="utf-8") as fh:
        ids = [l.strip() for l in fh if l.strip() and not l.startswith("#")]
except (OSError, UnicodeDecodeError) as e:
    print("finding_pipeline: --seeded-file unusable: %s" % e, file=sys.stderr); sys.exit(2)
if not ids:
    print("finding_pipeline: --seeded-file %r yielded no ids — a control file that declares "
          "nothing is a disabled control, not an absent one" % sys.argv[1], file=sys.stderr)
    sys.exit(2)
print(",".join(ids))' "$SEEDED_FILE") || exit 2
  ALL_SEEDS="${ALL_SEEDS:+$ALL_SEEDS,}$_FROM_FILE"
fi

FLEET_SH="$HERE/finding_fleet.sh"; VERIFY_PY="$HERE/finding_verify.py"; VERIFIER_SH="$HERE/finding_verifier.sh"
for f in "$FLEET_SH" "$VERIFY_PY" "$VERIFIER_SH"; do
  [ -f "$f" ] || { echo "finding_pipeline: missing $f — skipped, NOT passed" >&2; exit 3; }
done

# 🟥 NO SHELL IN THIS PATH. An earlier version built a command STRING and quoted the interpolated
# path with bash's `printf %q`. That was not enough, and the reason matters: finding_verify.py ran
# the string with `shell=True`, i.e. `/bin/sh`, while `%q` emits **bash-only** `$'...'` quoting for a
# path containing a newline. On the many Linux systems where `/bin/sh` is dash, that quoting comes
# apart and a crafted filename executes a second command. 🟥 macOS CANNOT SEE THIS — its /bin/sh is
# bash-derived, so the local run is green while the shipped package is not (cross-family review
# 2026-09-09, reproduced on dash). The fix is not better escaping; it is handing argv, never a string.
argv_json() {  # each argument becomes one JSON string — no shell ever parses these
  ARGV_PY="$*" /usr/bin/python3 -c 'import json,os,sys; print(json.dumps(sys.argv[1:]))' "$@"
}

# ── 1. fleet ──────────────────────────────────────────────────────────────────────────────────────
# A reused --out is not a fresh run: finding_fleet.sh concatenates EVERY part_*.jsonl it finds, so a
# member that is absent this time still contributes yesterday's findings — which can silently supply
# the second family and make a single-family run look cross-verified.
/bin/rm -rf "$OUT/fleet"
FA=(); [ -n "$FLEET" ] && FA=(--fleet "$FLEET")
# 생성시점 탈상관은 fleet 층의 일이다 — 드라이버는 플래그만 통과시킨다.
R2ARGS=(); [ "$ROUND2" -eq 1 ] && R2ARGS=(--round2); [ "$ROUND2_BLIND" -eq 1 ] && R2ARGS=(--round2-blind)

# ── 짝지음 인자 해석 ────────────────────────────────────────────────────────────────
# 🟥 --r1-only 는 검증·드롭감사·씨앗 판정을 «돌리지 않는다». 그러므로 씨앗을 선언한 채로는
#    거부한다 — 선언된 컨트롤이 돈 적 없이 통과로 읽히는 것이 이 레포가 이름 붙인 결함이다.
PAIRARGS=()
if [ "$R1_ONLY" -eq 1 ]; then
  [ "$ROUND2" -eq 1 ] && { echo "finding_pipeline: --r1-only cannot be combined with --round2/--round2-blind" >&2; exit 2; }
  [ -n "$REUSE_R1" ] && { echo "finding_pipeline: --r1-only and --reuse-r1 are mutually exclusive" >&2; exit 2; }
  [ -n "$ALL_SEEDS" ] && { echo "finding_pipeline: --r1-only runs no verification — refusing to accept seeds that would never be judged" >&2; exit 2; }
  PAIRARGS=(--r1-only)
fi
if [ -n "$REUSE_R1" ]; then
  [ "$ROUND2" -eq 1 ] || { echo "finding_pipeline: --reuse-r1 requires --round2 or --round2-blind" >&2; exit 2; }
  # 호출자가 파이프라인 out 을 줬으면 그 안의 fleet/ 로 내려간다. 어느 쪽을 골랐는지 «찍는다».
  _R1SRC="$REUSE_R1"
  [ -s "$REUSE_R1/fleet/findings.jsonl" ] && _R1SRC="$REUSE_R1/fleet"
  [ -s "$_R1SRC/findings.jsonl" ] || { echo "finding_pipeline: --reuse-r1 resolved to '$_R1SRC' which has no non-empty findings.jsonl" >&2; exit 2; }
  echo "PIPELINE reuse_r1 resolved=$_R1SRC sha256=$(/usr/bin/shasum -a 256 "$_R1SRC/findings.jsonl" | /usr/bin/cut -c1-16)"
  PAIRARGS=(--reuse-r1 "$_R1SRC")
fi

bash "$FLEET_SH" "$TARGET" --out "$OUT/fleet" ${FA[@]+"${FA[@]}"} ${R2ARGS[@]+"${R2ARGS[@]}"} ${PAIRARGS[@]+"${PAIRARGS[@]}"} 2>&1 | tee "$OUT/fleet_run.log"
FLEET_RC=${PIPESTATUS[0]}

# --r1-only: 공유 round-1 만 남기고 끝낸다(검증 단계 없음 — 위에서 씨앗을 이미 거부했다)
if [ "$R1_ONLY" -eq 1 ]; then
  # 🟥 `|| echo 0` 을 쓰면 안 된다 — `grep -c .` 는 빈 파일에서 «0 을 찍고 rc=1» 이라 폴백이
  #    한 줄을 더 붙여 `_n1="0\n0"` 이 되고, `[ "$_n1" -eq 0 ]` 은 **구문오류로 거짓**이 되어
  #    빈 round-1 이 «사용 가능» 으로 통과한다(fail-OPEN). cross-family codex 가 적발, 자력 0.
  #    [[feedback_pipefail_fallback_disarms_guard]] — 질문은 «폴백 붙였나» 가 아니라
  #    «실패 시 stdout 이 비는가» 다. 여기서는 안 빈다.
  _n1=$(/usr/bin/grep -c . "$OUT/fleet/findings.jsonl" 2>/dev/null)
  case "${_n1:-}" in ''|*[!0-9]*) _n1=0 ;; esac
  if [ "$FLEET_RC" -ne 0 ] || [ "$_n1" -eq 0 ]; then
    echo "PIPELINE target=$(basename "$TARGET") fleet_rc=$FLEET_RC findings=$_n1 status=R1_UNUSABLE rc=3"
    exit 3
  fi
  echo "PIPELINE target=$(basename "$TARGET") fleet_rc=0 findings=$_n1 status=R1_ONLY r1_dir=$OUT/fleet sha256=$(/usr/bin/shasum -a 256 "$OUT/fleet/findings.jsonl" | /usr/bin/cut -c1-16) rc=0"
  exit 0
fi
FINDINGS="$OUT/fleet/findings.jsonl"
if [ "$FLEET_RC" -eq 0 ] && [ ! -s "$FINDINGS" ] && [ -f "$OUT/fleet/INTENTIONAL_EMPTY" ]; then
  # 🟥 R3 #8: every member completed round 2 and withdrew everything — that is a REVIEWED empty result,
  #    not a missing review. The typed marker (not the empty file) is what distinguishes the two.
  # R4 #6: a reused --out kept the previous run's aggregates beside this early return — reset them here.
  for _p in "$OUT/confirmed.jsonl" "$OUT/dropped.jsonl" "$OUT/splits.txt"; do
    [ -L "$_p" ] && { echo "finding_pipeline: refusing to write through a symlink: $_p" >&2; exit 2; }
    : > "$_p"
  done
  # R4 #1: a declared control that never entered the run is ABSENT on this path too — WITHDRAWN must not
  #        pass a seed check it never ran. Same exit (5) and same SEEDED line the verifier would print.
  if [ -n "$ALL_SEEDS" ]; then
    _n=$(printf '%s' "$ALL_SEEDS" | /usr/bin/tr ',' '\n' | /usr/bin/grep -c .)
    echo "PIPELINE target=$(basename "$TARGET") fleet_rc=0 findings=0 status=WITHDRAWN confirmed=0 dropped=0 coverage=0/0 rc=5"
    echo "SEEDED declared=$_n present=0 kept=0 dropped=0 abstained=0 status=ABSENT"
    exit 5
  fi
  echo "PIPELINE target=$(basename "$TARGET") fleet_rc=0 findings=0 status=WITHDRAWN confirmed=0 dropped=0 coverage=0/0 rc=0"
  exit 0
fi
if [ "$FLEET_RC" -ne 0 ] || [ ! -s "$FINDINGS" ]; then
  echo "PIPELINE target=$(basename "$TARGET") fleet_rc=$FLEET_RC findings=0 status=UNREVIEWED"
  echo "  🟥 an empty finding list is UNREVIEWED, not clean (finding_fleet.sh says so and this agrees)" >&2
  exit 3
fi
# A fleet is "ok" when ONE member succeeded. A member that crashed after emitting a few findings still
# leaves its family present, so the split routing below sees two families and the run looks complete.
FAILED_MEMBERS=$(grep -c '^MEMBER .* rc=[^0]' "$OUT/fleet_run.log" 2>/dev/null); FAILED_MEMBERS=${FAILED_MEMBERS:-0}
# 🟥 rc=0 인데 계약 출력이 0 인 멤버 — 안전필터 차단이 이 얼굴이다. failed_members 로는 안 보인다.
#    «0건» 이 아니라 «검증 없는 0» 이므로 별 칸으로 표면화한다(기존 필드 의미는 안 건드린다).
BLOCKED_MEMBERS=$(grep -c '^MEMBER2\{0,1\} .*status=ZERO_NONJSON$' "$OUT/fleet_run.log" 2>/dev/null); BLOCKED_MEMBERS=${BLOCKED_MEMBERS:-0}

# ── 2. split by producer, verify each half with the other family ──────────────────────────────────
# Families are read into a newline-delimited list and validated. An unquoted space-joined expansion
# let a family literally named "codex gemini" split into two names that match no record, skipping
# every finding while the run still exited 0.
/usr/bin/python3 -c '
import json,re,sys
seen=[]
for l in open(sys.argv[1],encoding="utf-8"):
    l=l.strip()
    if not l: continue
    f=json.loads(l).get("producer_family")
    if f is None: continue
    if not re.fullmatch(r"[A-Za-z0-9_.-]+", str(f)):
        sys.stderr.write("finding_pipeline: illegal producer_family %r — refusing to route\n" % (f,))
        sys.exit(2)
    if f not in seen: seen.append(f)
print("\n".join(seen))' "$FINDINGS" > "$OUT/families.txt" 2>"$OUT/families.err"
FAMRC=$?
if [ "$FAMRC" -ne 0 ] || [ ! -s "$OUT/families.txt" ]; then
  cat "$OUT/families.err" >&2
  echo "finding_pipeline: findings carry no usable producer_family — cannot route" >&2; exit 3
fi

# 🟥 검증자 후보 풀은 «발견을 낸 계열» 이 아니라 «실제로 돌아간 함대 명부» 다.
#    families.txt 는 producer_family 에서 만들어지므로 0건을 낸 계열은 목록에서 사라진다. 그러면
#    pick_verifier 가 «다른 계열이 없다» 로 읽고 그 발견들을 통째로 미검증 처리한다 — 검증자로
#    쓸 수 있는 계열이 멀쩡히 돌고 있었는데도. 측정이 스스로 찾아낸 결함이다:
#    F_typed 팔 case_g02.py r1~r3 이 정확히 이 형태로 coverage 0/2 (0%) 였다(2026-09-10).
#    분할 루프는 바뀌지 않는다 — 여전히 발견자별이다. 바뀌는 것은 «누가 검증할 수 있나» 뿐이다.
#    rc!=0 인 멤버는 제외한다: 안 돌아간 CLI 는 검증도 못 한다(한도 소진이 그 형태).
ROSTER="$OUT/roster.txt"
/usr/bin/python3 -c '
import re,sys
seen=[]
for l in open(sys.argv[1],encoding="utf-8",errors="replace"):
    # 🟥 role 값에 공백이 들어갈 수 있다(fleet 표가 허용한다). 접두 전체를 한 패턴으로 묶으면
    #    그런 줄이 통째로 무시되고 명부가 «빈 채로 성공» 한다 — 두 필드를 따로 잡는다.
    # 🟥 R2 #6: `\brc=` 는 role 안의 rc= 를 먼저 잡는다(role=rc=1 rc=0 → 오탈락, 실행 확인).
    #    레코드 형식이 고정이므로 «뒤에서» 잡는다 — rc= 다음에 findings= 가 오는 것이 앵커다.
    # 🟥 R3 #6: «findings= 가 뒤에 온다» 는 접미 경계가 아니었다 — role=`rc=0 findings=x` 가 먼저 잡혔다.
    #    레코드 끝(`rc=N findings=N [self_dropped=N] status=S$`)에 앵커한다.
    fm = re.search(r"\bfamily=(\S+)", l); rm = re.search(r" rc=(\S+) findings=\S+(?: self_dropped=\S+)? status=\S+\s*$", l)
    if not l.startswith("MEMBER") or not fm or not rm: continue
    fam, rc = fm.group(1), rm.group(1)
    if rc != "0": continue
    if not re.fullmatch(r"[A-Za-z0-9_.-]+", fam):
        sys.stderr.write("finding_pipeline: illegal family %r in fleet roster — refusing to route\n" % (fam,))
        sys.exit(2)
    if fam not in seen: seen.append(fam)
if not seen:
    # 🟥 빈 목록을 «성공» 으로 내보내면 안 된다. `print("\n".join([]))` 는 개행 1바이트를 쓰고
    #    `[ -s ]` 는 그걸 «내용 있음» 으로 읽는다 — 그러면 DEGRADE 분기가 통째로 건너뛰어지고
    #    아무도 검증자를 못 받는다(cross-family #4, codex 2026-09-10).
    sys.stderr.write("finding_pipeline: fleet roster parsed 0 usable families\n"); sys.exit(4)
print("\n".join(seen))' "$OUT/fleet/members.txt" > "$ROSTER" 2>"$OUT/roster.err"
ROSTRC=$?
_ROSTER_N=$(/usr/bin/grep -c . "$ROSTER" 2>/dev/null); _ROSTER_N=${_ROSTER_N:-0}
if [ "$ROSTRC" -ne 0 ] || [ "$_ROSTER_N" -eq 0 ]; then
  cat "$OUT/roster.err" >&2
  # 🟥 degrade 는 «조용히 넘어감» 이 아니라 «좁은 풀로 되돌아감 + 그 사실을 말함» 이다.
  #    없는 검증자를 만들어내지 않으므로 방향은 안전하다(과소검증 쪽으로 실패한다).
  echo "  ⚠️  fleet roster unusable (rc=$ROSTRC) — verifier pool DEGRADED to producer families; a family that produced 0 findings cannot be picked" >&2
  /bin/cp "$OUT/families.txt" "$ROSTER" 2>/dev/null || : > "$ROSTER"
  ROSTER_SRC="families(DEGRADED)"
else
  ROSTER_SRC="fleet"
fi

supported() { case " $SUPPORTED_FAMILIES " in *" $1 "*) return 0;; *) return 1;; esac; }
pick_verifier() { # $1=producer — a DIFFERENT family the wrapper can actually run
  local p="$1" f
  while IFS= read -r f; do [ -n "$f" ] && [ "$f" != "$p" ] && supported "$f" && { echo "$f"; return; }; done < "$ROSTER"
  echo ""
}
pick_auditor() { # $1=producer $2=verifier — prefer a third party; fall back to producer (appeal)
  local p="$1" v="$2" f
  while IFS= read -r f; do
    [ -n "$f" ] && [ "$f" != "$p" ] && [ "$f" != "$v" ] && supported "$f" && { echo "$f"; return; }
  done < "$ROSTER"
  supported "$p" && { echo "$p"; return; }
  echo ""
}

# Exit codes are TYPES, not severities — `max(0,1)` turned "one split found nothing" into the whole
# run's verdict while a confirmed survivor sat in the other split. Rank them explicitly instead, and
# derive 1-vs-0 from the survivor count at the end, never from a split.
WORST_RANK=0; WORST_CODE=0
# 🟥 exit 5 (SEEDED DEGRADED/INCONCLUSIVE/ABSENT) had NO CASE here, so it fell to the default 0
# and the driver exited 0 while a split had just reported that the filter deleted a known-true
# finding. The entire seeded control was invisible at the level a reader actually reads.
# (cross-family round 4, gemini family, S severity — three same-family rounds missed it.)
rank_of() { case "$1" in 2) echo 5;; 5) echo 4;; 3) echo 3;; 4) echo 2;; *) echo 0;; esac; }
note_rc() { local r; r=$(rank_of "$1"); if [ "$r" -gt "$WORST_RANK" ]; then WORST_RANK="$r"; WORST_CODE="$1"; fi; }

: > "$OUT/confirmed.jsonl"; : > "$OUT/dropped.jsonl"; : > "$OUT/splits.txt"

while IFS= read -r PROD; do
  [ -n "$PROD" ] || continue
  VER="$(pick_verifier "$PROD")"
  if [ -z "$VER" ]; then
    echo "  ⚠️  split producer=$PROD — no other SUPPORTED family present; its findings cannot be cross-verified" >&2
    note_rc 3; printf 'split producer=%s verifier=NONE rc=3 (no cross-family)\n' "$PROD" >> "$OUT/splits.txt"; continue
  fi
  AUD="$(pick_auditor "$PROD" "$VER")"
  SD="$OUT/split_$PROD"
  mkdir -p "$SD" || { echo "finding_pipeline: cannot create $SD" >&2; note_rc 2; continue; }
  # An extraction that FAILS and an extraction that finds nothing are not the same event; the first
  # draft's `[ -s ] || continue` read both as "empty partition" and left WORST at 0.
  if ! /usr/bin/python3 -c '
import json,sys
prod=sys.argv[2]
for l in open(sys.argv[1],encoding="utf-8"):
    l=l.strip()
    if l and json.loads(l).get("producer_family")==prod: print(l)' "$FINDINGS" "$PROD" > "$SD/in.jsonl"; then
    echo "finding_pipeline: split extraction failed for producer=$PROD" >&2; note_rc 3; continue
  fi
  if [ ! -s "$SD/in.jsonl" ]; then
    printf 'split producer=%s verifier=%s rc=0 (no findings)\n' "$PROD" "$VER" >> "$OUT/splits.txt"; continue
  fi

  # 🟥 검증 패스의 CLI stderr(토큰 회계 «tokens used» 포함)가 mktemp 에 쓰이고 cleanup 이 지웠다.
  #    그래서 «검증 패스 토큰 = 0바이트» 로 보였는데 0 이 아니라 «버려진 것» 이다. --keep 은 이미
  #    있는 채널이고 파이프라인이 안 넘겼을 뿐이다. split 디렉터리에 남긴다(2026-09-10).
  # 🟥 R2 #7: 검증과 감사가 같은 keep 을 쓰면 드롭이 있는 런에서 감사가 검증 err.txt 를 덮는다 —
  #    토큰 회계가 «바로 그 런» 에서 또 버려진다. 갈라 둔다. #1: 잎 경로 심링크도 여기서 거부.
  for _p in "$SD/keep_verify" "$SD/keep_audit"; do
    [ -L "$_p" ] && { echo "finding_pipeline: refusing to write through a symlink: $_p" >&2; note_rc 2; continue 2; }
    mkdir -p "$_p"
    for _leaf in raw.txt err.txt prompt.txt findings.jsonl; do
      [ -L "$_p/$_leaf" ] && { echo "finding_pipeline: refusing to write through a symlink: $_p/$_leaf" >&2; note_rc 2; continue 3; }
    done
  done
  export FH_VERIFIER_KEEP="$SD"   # verifier 가 MODE 별로 keep_verify/ keep_audit/ 를 «스스로» 고른다 (R2 #7)
  AUDARGS=()
  if [ -n "$AUD" ]; then
    AUDARGS=(--audit-verifier-argv "$(argv_json bash "$VERIFIER_SH" --family "$AUD" --target "$TARGET" --audit)" --audit-family "$AUD")
  else
    echo "  ⚠️  split producer=$PROD — no supported auditor; any drop will come back UNAUDITED" >&2
  fi
  # 🟥 Seeds are forwarded PER SPLIT, filtered to the ids that actually live in that split's input.
  # Forwarding the whole declared set to every split would make each split report ABSENT for the
  # seeds that belong to the other producer — a false alarm manufactured by the routing, not by the
  # filter. The global "did any declared seed enter at all?" question is answered once, below.
  SEEDARGS=()
  if [ -n "$ALL_SEEDS" ]; then
    # 🟥 R6 #3: resolve each declared seed against the WHOLE fleet result BEFORE partitioning — two rows in
    #    different splits sharing one member_id each looked unique inside their split (CLEAN twice) while the
    #    unsplit verifier calls the same declaration AMBIGUOUS. Global multiplicity is decided once, here.
    _AMBIG=$(ALL_SEEDS="$ALL_SEEDS" /usr/bin/python3 -c '
import sys, json, os, collections
want = {x.strip() for x in os.environ.get("ALL_SEEDS", "").split(",") if x.strip()}
cnt = collections.Counter()
try:
    for l in open(sys.argv[1], encoding="utf-8"):
        l = l.strip()
        if not l: continue
        try: d = json.loads(l)
        except Exception: continue
        if not isinstance(d, dict): continue
        keys = {str(d[k]) for k in ("id", "member_id") if d.get(k) is not None}
        for k in keys & want: cnt[k] += 1
except OSError: pass
print(",".join(sorted(k for k, c in cnt.items() if c > 1)))' "$FINDINGS")
    if [ -n "$_AMBIG" ]; then
      echo "PIPELINE target=$(basename "$TARGET") status=SEED_AMBIGUOUS seeds=$_AMBIG rc=5"
      echo "SEEDED declared=$(printf '%s' "$ALL_SEEDS" | /usr/bin/tr ',' '\n' | /usr/bin/grep -c .) present=0 kept=0 dropped=0 abstained=0 status=AMBIGUOUS"
      echo "  🟥 seed(s) $_AMBIG match more than one fleet row — member ids are only locally unique; declare the routing id instead" >&2
      exit 5
    fi
    _SPLIT_SEEDS=$(ALL_SEEDS="$ALL_SEEDS" /usr/bin/python3 -c '
import sys, json, os
want = {x.strip() for x in os.environ.get("ALL_SEEDS", "").split(",") if x.strip()}
have = set()
try:
    for l in open(sys.argv[1], encoding="utf-8"):
        l = l.strip()
        if not l: continue
        try: d = json.loads(l)
        except Exception: continue
        if isinstance(d, dict):
            if d.get("id") is not None: have.add(str(d["id"]))
            if d.get("member_id") is not None: have.add(str(d["member_id"]))
except OSError: pass
print(",".join(sorted(want & have)))' "$SD/in.jsonl")
    if [ -n "$_SPLIT_SEEDS" ]; then
      SEEDARGS=(--seeded "$_SPLIT_SEEDS")
    fi
  fi
  /usr/bin/python3 "$VERIFY_PY" "$SD/in.jsonl" --out "$SD" \
    --verifier-argv "$(argv_json bash "$VERIFIER_SH" --family "$VER" --target "$TARGET")" --family "$VER" \
    ${SEEDARGS[@]+"${SEEDARGS[@]}"} ${AUDARGS[@]+"${AUDARGS[@]}"} > "$SD/summary.txt" 2>"$SD/err.txt"
  RC=$?
  # 🟥 «라우팅했다» 를 «검증됐다» 로 세면 안 된다. 초판은 verify 를 부르기 «전» 에 기록해서,
  #   verify 가 크래시해도 그 씨앗은 «돌았다» 로 남았다(cross-family round 6). 요약을 실제로
  #   낸 실행에 대해서만 기록한다.
  if [ -n "${_SPLIT_SEEDS:-}" ] && [ -s "$SD/summary.txt" ]; then
    SEEDS_ROUTED="${SEEDS_ROUTED:+$SEEDS_ROUTED,}$_SPLIT_SEEDS"
  fi
  note_rc "$RC"
  cat "$SD/summary.txt"
  printf 'split producer=%s verifier=%s auditor=%s rc=%s\n' "$PROD" "$VER" "${AUD:-NONE}" "$RC" >> "$OUT/splits.txt"
  [ -f "$SD/confirmed.jsonl" ] && cat "$SD/confirmed.jsonl" >> "$OUT/confirmed.jsonl"
  [ -f "$SD/dropped.jsonl" ]   && cat "$SD/dropped.jsonl"   >> "$OUT/dropped.jsonl"
done < "$OUT/families.txt"

# 🟥 NOT `$(grep -c ... || echo 0)`: grep -c PRINTS "0" and ALSO exits 1 on no match, so the fallback
# appends a second line and the count becomes "0\n0", which truncates the summary printf.
count_lines() { local n; n=$(grep -c "$1" "$2" 2>/dev/null); printf '%s' "${n:-0}" | tr -d ' \n'; }
TOTAL_CONF=$(count_lines '^{' "$OUT/confirmed.jsonl")
TOTAL_DROP=$(count_lines '^{' "$OUT/dropped.jsonl")
TOTAL_UNVER=$(count_lines '"verdict": *"unverified"' "$OUT/confirmed.jsonl")
# An `unaudited` drop is NOT an audited one — counting it as such is how "we checked the deletions"
# becomes true by wording alone.
TOTAL_AUD=$(count_lines '"drop_verdict": *"\(correct-drop\|wrong-drop\|uncertain\)"' "$OUT/dropped.jsonl")
TOTAL_WRONG=$(count_lines '"reinstated": *true' "$OUT/confirmed.jsonl")
# 🟥 COVERAGE ALSO RIDES THE DRIVER LINE, not only the per-split one. `finding_verify.py` records it
# per split, but the driver's summary is what a reader actually reads — a field recorded in a place
# nobody reads is the half-externalisation shape this repo keeps re-finding (a slot with zero
# consumers always reports "done", because presence is doing the judging).
#
# 🟥 THREE things this number got wrong on the first attempt, all found by cross-family round 2:
#   ⓐ it subtracted `unverified` but NOT `needs-debate` — an all-debate run printed 100%. The
#     verifier had already been fixed for exactly this and the driver had not: a half-fix that
#     stopped at the propagation boundary, which is the failure mode this repo has a name for.
#   ⓑ the DENOMINATOR was `confirmed + dropped`, i.e. what came OUT. A partition that is skipped
#     (unsupported family) then vanishes from numerator and denominator alike and coverage reads
#     100% while findings were never judged at all. The denominator must be what came IN.
#   ⓒ the counters were line greps, so passthrough metadata containing `"verdict": "unverified"`
#     anywhere in a row counted as an abstention. Verdicts are read from the TOP LEVEL of each row.
# 🟥 판정 수는 «뺄셈» 이 아니라 «양의 계수» 로 구한다. 초판은 입력 총수에서 기권을 뺐는데,
#    그러면 **출력에 아예 안 나타난 것이 판정된 것으로 계수된다** — 건너뛴 파티션도, 읽기 실패도,
#    깨진 JSON 도 전부 «100%» 가 된다(cross-family R3 가 A급 둘로 지목, 재현됨).
#    판정 = 「해결된 verdict 를 실제로 들고 있는 행」의 수다. 없으면 0 이고, 그것이 fail-closed 다.
_count_json() {   # $1 = 파일, $2 = 필드, $3.. = 셀 값들. 실패는 «0» 이 아니라 비-영 종료로 낸다.
  /usr/bin/python3 -c '
import sys, json
path, field, want = sys.argv[1], sys.argv[2], set(sys.argv[3:])
n = 0
try:
    fh = open(path, encoding="utf-8")
except FileNotFoundError:
    print(0); sys.exit(0)                 # 파일 자체가 없는 것은 «행이 0» 이다
except OSError as e:
    print("count: %s" % e, file=sys.stderr); sys.exit(9)
with fh:
    try:
        for l in fh:
            l = l.strip()
            if not l: continue
            d = json.loads(l)             # 깨진 줄은 «건너뛰기» 가 아니라 계측 오류다
            if not isinstance(d, dict): raise ValueError("row is not an object")
            v = d.get(field)
            if v is not None and not isinstance(v, str): raise ValueError("non-string %s" % field)
            if v in want: n += 1
    except (json.JSONDecodeError, ValueError, UnicodeDecodeError) as e:
        print("count: %s" % e, file=sys.stderr); sys.exit(9)
print(n)' "$@"
}
_count_lines_json() {   # 행 수 — 같은 실패 규율
  /usr/bin/python3 -c '
import sys
n = 0
try:
    fh = open(sys.argv[1], encoding="utf-8")
except FileNotFoundError:
    print(0); sys.exit(0)
except OSError as e:
    print("count: %s" % e, file=sys.stderr); sys.exit(9)
with fh:
    try:
        for l in fh:
            if l.strip(): n += 1
    except UnicodeDecodeError as e:
        print("count: %s" % e, file=sys.stderr); sys.exit(9)
print(n)' "$1"
}
COUNT_ERR=0
TOTAL_IN=$(_count_lines_json "$FINDINGS") || COUNT_ERR=1
TOTAL_UNVER=$(_count_json "$OUT/confirmed.jsonl" verdict unverified) || COUNT_ERR=1
TOTAL_DEBATE=$(_count_json "$OUT/confirmed.jsonl" verdict needs-debate) || COUNT_ERR=1
# 🟥 양의 계수: 실제로 «해결된» 판정을 들고 있는 행만 센다.
# 복권된 행은 이제 verdict=confirmed 를 단다(verify 쪽 근원 수리). 그 전에 만들어진 산출물과의
# 호환을 위해 «reinstated 이면서 false-positive» 도 판정으로 센다 — 그 행은 감사가 «되돌렸다» 는
# 결정을 받은 것이지 미판정이 아니다.
JUDGED_CONF=$(_count_json "$OUT/confirmed.jsonl" verdict confirmed) || COUNT_ERR=1
JUDGED_REINST=$(/usr/bin/python3 -c '
import sys, json
n = 0
try:
    fh = open(sys.argv[1], encoding="utf-8")
except FileNotFoundError:
    print(0); sys.exit(0)
except OSError as e:
    print("count: %s" % e, file=sys.stderr); sys.exit(9)
with fh:
    try:
        for l in fh:
            l = l.strip()
            if not l: continue
            d = json.loads(l)
            if isinstance(d, dict) and d.get("reinstated") is True and d.get("verdict") != "confirmed":
                n += 1
    except (json.JSONDecodeError, ValueError, UnicodeDecodeError) as e:
        print("count: %s" % e, file=sys.stderr); sys.exit(9)
print(n)' "$OUT/confirmed.jsonl") || COUNT_ERR=1
JUDGED_DROP=$(_count_json "$OUT/dropped.jsonl" verdict false-positive) || COUNT_ERR=1
TOTAL_IN=${TOTAL_IN:-0}; TOTAL_UNVER=${TOTAL_UNVER:-0}; TOTAL_DEBATE=${TOTAL_DEBATE:-0}
JUDGED_CONF=${JUDGED_CONF:-0}; JUDGED_DROP=${JUDGED_DROP:-0}
JUDGED_REINST=${JUDGED_REINST:-0}
TOTAL_JUDGED=$(( JUDGED_CONF + JUDGED_DROP + JUDGED_REINST ))
# 🟥 Split-level ABSENT cannot fire once seeds are filtered per split, so the "did the control run
# at all?" question is asked ONCE, globally, against the whole fleet output.
if [ -n "$ALL_SEEDS" ]; then
  _SEEDS_SEEN=$(ALL_SEEDS="$ALL_SEEDS" /usr/bin/python3 -c '
import sys, json, os
want = {x.strip() for x in os.environ.get("ALL_SEEDS", "").split(",") if x.strip()}
have = set()
try:
    for l in open(sys.argv[1], encoding="utf-8"):
        l = l.strip()
        if not l: continue
        try: d = json.loads(l)
        except Exception: continue
        if isinstance(d, dict):
            if d.get("id") is not None: have.add(str(d["id"]))
            if d.get("member_id") is not None: have.add(str(d["member_id"]))
except OSError: pass
print(len(want & have))' "$FINDINGS")
  if [ "${_SEEDS_SEEN:-0}" -eq 0 ]; then
    echo "  ⚠️  declared seeds are not present anywhere in the fleet output — the control never ran" >&2
    note_rc 5
  fi
  # 🟥 «하나라도 들어왔나» 로는 부족하다. 선언한 씨앗 중 **어떤 split 에도 안 실린 것**이 있으면
  #   그 씨앗은 검증기를 통과한 적이 없고, 그런데도 나머지가 CLEAN 이면 드라이버는 0 을 낸다.
  #   두 경로로 그렇게 된다: ⓐ fleet 출력에 애초에 없다 ⓑ 있는데 producer_family 가 없거나
  #   지원되지 않아 라우팅에서 빠진다. 둘 다 «통제가 그 씨앗에 대해 안 돌았다» 는 같은 사실이다.
  #   (cross-family round 5, gemini 계열.)
  _SEEDS_MISSED=$(ALL_SEEDS="$ALL_SEEDS" ROUTED="${SEEDS_ROUTED:-}" /usr/bin/python3 -c '
import os
want = {x.strip() for x in os.environ.get("ALL_SEEDS", "").split(",") if x.strip()}
got  = {x.strip() for x in os.environ.get("ROUTED", "").split(",") if x.strip()}
missed = sorted(want - got)
print(",".join(missed))')
  if [ -n "$_SEEDS_MISSED" ]; then
    echo "  ⚠️  declared seeds never reached any verified split: $_SEEDS_MISSED — the control did not run for them" >&2
    note_rc 5
  fi
fi
if [ "$COUNT_ERR" -ne 0 ]; then
  echo "  ⚠️  coverage 계측이 실패했다 — 이 런의 coverage 는 판정이 아니라 «못 잼» 이다" >&2
  note_rc 3
fi
# 🟥 회계 불일치는 clamp 로 덮지 않는다 — 판정이 입력보다 많으면 그건 «0으로 눌러서 정상처럼
#    보이게 할 것» 이 아니라 계측 결함이다(R3 지적).
if [ "$TOTAL_JUDGED" -gt "$TOTAL_IN" ]; then
  echo "  ⚠️  coverage 회계 불일치: 판정 $TOTAL_JUDGED > 입력 $TOTAL_IN" >&2
  note_rc 3
fi
if [ "$TOTAL_IN" -gt 0 ]; then
  COV_PCT=$(( TOTAL_JUDGED * 100 / TOTAL_IN ))   # floored, never rounded
else
  COV_PCT=0
fi

if [ "$FAILED_MEMBERS" -gt 0 ]; then
  echo "  ⚠️  $FAILED_MEMBERS fleet member(s) exited non-zero — a member that crashed after emitting some findings leaves its family looking complete" >&2
  note_rc 3
fi

RC_FINAL="$WORST_CODE"
[ "$WORST_RANK" -eq 0 ] && [ "$TOTAL_CONF" -eq 0 ] && RC_FINAL=1

# 🟥 `confirmed=` prints the RESOLVED confirmations, not the raw line count of confirmed.jsonl.
# That file also holds debate and unverified rows, so the driver printed `confirmed=2 debate=2
# coverage=0/2` — three numbers in one line contradicting each other. The verifier had already been
# fixed for exactly this; the driver had not. **Third recurrence of the same half-fix shape in this
# change** (cross-family round 6). Survivor semantics for rc stay on TOTAL_CONF.
printf 'PIPELINE target=%s families=%s roster=%s(%s) confirmed=%s dropped=%s unverified=%s debate=%s coverage=%s/%s (%s%%) audited_drops=%s reinstated=%s failed_members=%s blocked_members=%s rc=%s\n' \
  "$(basename "$TARGET")" "$(tr '\n' ',' < "$OUT/families.txt" | sed 's/,$//')" \
  "$(tr '\n' ',' < "$ROSTER" | sed 's/,$//')" "$ROSTER_SRC" "$JUDGED_CONF" "$TOTAL_DROP" \
  "$TOTAL_UNVER" "$TOTAL_DEBATE" "$TOTAL_JUDGED" "$TOTAL_IN" "$COV_PCT" "$TOTAL_AUD" "$TOTAL_WRONG" \
  "$FAILED_MEMBERS" "$BLOCKED_MEMBERS" "$RC_FINAL"
# `unverified` is reported on its own line rather than folded into `confirmed`, because folding it is
# exactly the "not found rendered as zero" family this repo keeps re-finding.
exit "$RC_FINAL"

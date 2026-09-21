#!/usr/bin/env bash
# test_stale_ref_close_lanes.sh — known pairs + revert probes for the ①-g STALE REF advisory
# block in `scripts/session_close_check.sh`.
#
# WHY THIS EXISTS
# #770 built `scripts/stale_ref_scan.py` and #773 shipped it with its own residual written down:
# «배선 안 함 — 이 계기는 지금 아무도 안 부른다». Measured 2026-09-21: its only call sites were
# its own lane suite and that suite's selfcheck wiring, and BOTH pass `--offline-fixture`. The
# tool was fully anchored and had never once been pointed at the real corpus. ①-g is that call
# site. Without these lanes the block can be deleted, or quietly turned into a silent pass, with
# every gate still green — the decoration class `new_code_anchor_check` exists to catch.
#
# SCOPE, stated honestly: these lanes exercise the CALLER CONTRACT — what ①-g does with each
# verdict shape the scanner can produce (defect · unreadable · no verdict at all · scanner absent)
# and that it never blocks. The scanner's own verdicts are anchored separately by
# `scripts/test_stale_ref_scan_lanes.sh`. The block is EXTRACTED from the subject rather than
# restated here: a restated copy drifts from the thing it claims to verify.
# 🟥 No network. The subject under test is the caller, so the scanner is a stub whose verdict
#    line is the lane's input — a live scan would make these lanes depend on Zenodo's state.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 10
pass=0; fail=0
ok()  { printf '  \342\234\205 %s\n' "$1"; pass=$((pass+1)); }
bad() { printf '  \342\235\214 %s\n' "$1"; fail=$((fail+1)); }

SUBJECT="$REPO_ROOT/scripts/session_close_check.sh"
if [ ! -f "$SUBJECT" ]; then
  printf '\360\237\237\245 HARNESS ERROR — session_close_check.sh 가 없다. 「0 실패」가 아니라 계기 부재다.\n'
  exit 10
fi

BLOCK=$(awk '/^# ── ①-g STALE REF \(advisory\)/,/^echo "── close check:/' "$SUBJECT" | sed '$d')
if [ -z "$BLOCK" ] || ! printf '%s' "$BLOCK" | grep -q '_SR_SCAN'; then
  bad "①-g 블록을 subject 에서 못 찾았다 — 못 찾는 것을 검증할 수는 없다"
  echo "----"; echo "stale-ref close lanes: $pass passed, $fail failed"; exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  printf '\360\237\237\245 HARNESS ERROR — git 이 없다. 픽스처 트리를 못 만든다(「0 실패」가 아니다).\n'
  exit 10
fi

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# make_tree <stub-body|NOSCAN> — a minimal tracked tree carrying one Zenodo reference
make_tree() {
  local t; t="$(mktemp -d "$TMP/tree.XXXXXX")"
  ( cd "$t" && git init -q . && git config user.email t@t && git config user.name t ) || return 1
  mkdir -p "$t/scripts" "$t/tracks"
  printf 'see 10.5281/zenodo.20397566 for the method\n' > "$t/DOC.md"
  # a tracks/ file that MUST be excluded from the scanned set
  printf 'old record 10.5281/zenodo.11111111\n' > "$t/tracks/old_note.md"
  if [ "$1" != "NOSCAN" ]; then
    printf '%s\n' "$1" > "$t/scripts/stale_ref_scan.py"
    chmod +x "$t/scripts/stale_ref_scan.py"
  fi
  ( cd "$t" && git add -A >/dev/null 2>&1 ) || return 1
  printf '%s' "$t"
}

# run_block <tree> [block-override] — echoes the block's output, then a FAIL= line
run_block() {
  local tree="$1" blk="${2:-$BLOCK}"
  FH="$tree" BLK="$blk" bash -c '
    set -uo pipefail
    FH="$FH"; FAIL=0
    eval "$BLK"
    echo "FAILVAR=$FAIL"
  ' 2>&1
}

STUB_HEAD='#!/usr/bin/env python3
import sys
print("stale-ref-scan · stub")'

stub_with() {   # stub_with <verdict-tail> [extra-detail-line]
  printf '%s\n' "$STUB_HEAD"
  [ -n "${2:-}" ] && printf 'print(%s)\n' "\"$2\""
  printf 'print("stale-ref verdict: %s")\n' "$1"
  printf 'sys.exit(1)\n'
}

# ── L0 dead control — an all-clean verdict must produce the ✅ line ───────────
t=$(make_tree "$(stub_with 'SUPERSEDED=0 UNRESOLVED=0 UNSCANNABLE=0 CONCEPT=1 CURRENT=2 CHANGELOG-EXCLUDED=0 rc=0')")
out=$(run_block "$t")
case "$out" in
  *"✅ ①-g"*) ok "L0 dead-control — 깨끗한 판정에서 ✅ 가 난다 (블록이 실제로 돈다)" ;;
  *) bad "L0 dead-control — 깨끗한 판정에서도 ✅ 가 없다. 아래 판정은 무의미하다: $out"
     echo "----"; echo "stale-ref close lanes: $pass passed, $fail failed"; exit 1 ;;
esac

# ── L1 known-POS defect — SUPERSEDED>0 surfaces, and the detail line rides along
t=$(make_tree "$(stub_with 'SUPERSEDED=2 UNRESOLVED=0 UNSCANNABLE=0 CONCEPT=0 CURRENT=1 CHANGELOG-EXCLUDED=0 rc=1' '  🟥 SUPERSEDED [20397566]  cited ×3 — DOC.md:1')")
out=$(run_block "$t")
if printf '%s' "$out" | grep -q '①-g stale-ref: 2 개 id' && printf '%s' "$out" | grep -q 'SUPERSEDED \[20397566\]'; then
  ok "L1 known-POS — 폐기 인용이 개수와 자리까지 표면화된다"
else
  bad "L1 known-POS — 폐기 인용이 안 나왔다: $out"
fi

# ── L2 advisory — a defect must NOT raise FAIL (reversible surface) ──────────
case "$out" in
  *"FAILVAR=0"*) ok "L2 advisory — 결함을 찾아도 FAIL 을 안 올린다 (막지 않는다)" ;;
  *) bad "L2 advisory — 결함에서 FAIL 이 올라갔다. 과차단은 --no-verify 를 학습시킨다: $out" ;;
esac

# ── L3 못 읽음 ≠ 깨끗함 — UNRESOLVED>0 must read UNMEASURED, never ✅ ─────────
t=$(make_tree "$(stub_with 'SUPERSEDED=0 UNRESOLVED=7 UNSCANNABLE=0 CONCEPT=0 CURRENT=0 CHANGELOG-EXCLUDED=0 rc=1')")
out=$(run_block "$t")
if printf '%s' "$out" | grep -q 'UNMEASURED' && ! printf '%s' "$out" | grep -q '✅ ①-g'; then
  ok "L3 못 읽음 ≠ 깨끗함 — UNRESOLVED 가 UNMEASURED 로 나오고 ✅ 는 안 난다"
else
  bad "L3 UNRESOLVED 를 깨끗함으로 읽었다: $out"
fi

# ── L4 계기 오류 — no verdict line at all is UNMEASURED, not silence ─────────
t=$(make_tree '#!/usr/bin/env python3
import sys
sys.stderr.write("boom\n"); sys.exit(2)')
out=$(run_block "$t")
if printf '%s' "$out" | grep -q '판정 줄을 안 냈다'; then
  ok "L4 계기 오류 — 판정 줄이 없으면 UNMEASURED 로 말한다 (침묵 아님)"
else
  bad "L4 판정 줄 부재가 조용히 지나갔다: $out"
fi

# ── L5 부재≠통과 — scanner missing must say skipped-not-passed ───────────────
t=$(make_tree NOSCAN)
out=$(run_block "$t")
if printf '%s' "$out" | grep -q 'skipped, not passed'; then
  ok "L5 계기 부재 — skipped, not passed (UNMEASURED) 로 말한다"
else
  bad "L5 계기 부재가 통과처럼 지나갔다: $out"
fi

# ── L6 scope — tracks/** must not reach the scanner ──────────────────────────
# 🟥 The block swallows the scanner's stdout into a variable, so the argv must be observed on
#    a side channel — asserting on stdout here would have measured nothing.
t=$(make_tree '#!/usr/bin/env python3
import sys
args=[a for a in sys.argv[1:] if not a.startswith("-")]
open("ARGV_SEEN.txt","w").write(",".join(args))
print("stale-ref verdict: SUPERSEDED=0 UNRESOLVED=0 UNSCANNABLE=0 CONCEPT=0 CURRENT=0 CHANGELOG-EXCLUDED=0 rc=0")
sys.exit(0)')
out=$(run_block "$t")
seen=$(cat "$t/ARGV_SEEN.txt" 2>/dev/null || echo "__NOFILE__")
if [ "$seen" = "__NOFILE__" ]; then
  bad "L6 HARNESS ERROR — 스텁이 argv 를 안 남겼다. 스코프를 잰 적이 없다"
elif printf '%s' "$seen" | grep -q 'DOC.md' && ! printf '%s' "$seen" | grep -q 'tracks/'; then
  ok "L6 스코프 — 추적 파일은 넘기고 tracks/** 는 제외한다"
else
  bad "L6 스코프 — 스캐너가 받은 파일 집합이 틀렸다: $seen"
fi

# ── L7 revert probe: drop the SUPERSEDED branch → L1 must go silent ──────────
MUT=$(printf '%s' "$BLOCK" | sed 's/if \[ "${_sr_sup:-0}" -gt 0 \] 2>\/dev\/null; then/if false; then/')
if [ "$MUT" = "$BLOCK" ]; then
  bad "L7 HARNESS ERROR — 뮤턴트 생성 실패 (치환 대상 없음). 「안 빨개졌다」와 구별이 안 된다"
else
  t=$(make_tree "$(stub_with 'SUPERSEDED=2 UNRESOLVED=0 UNSCANNABLE=0 CONCEPT=0 CURRENT=1 CHANGELOG-EXCLUDED=0 rc=1' '  🟥 SUPERSEDED [20397566]  cited ×3 — DOC.md:1')")
  out=$(run_block "$t" "$MUT")
  if printf '%s' "$out" | grep -q '①-g stale-ref: 2 개 id'; then
    bad "L7 되돌림 — 분기를 죽였는데도 L1 이 초록이다. L1 은 그 분기 덕분이 아닐 수 있다"
  else
    ok "L7 되돌림 — SUPERSEDED 분기를 죽이자 표면화가 사라진다 (앵커가 장식이 아니다)"
  fi
fi

# ── L8 revert probe: treat a missing verdict as clean → L4 must go silent ────
MUT=$(printf '%s' "$BLOCK" | sed 's/UNMEASURED — 스캐너가 판정 줄을 안 냈다 (0 으로 읽지 마라)/(quiet)/')
if [ "$MUT" = "$BLOCK" ]; then
  bad "L8 HARNESS ERROR — 뮤턴트 생성 실패 (치환 대상 없음)"
else
  t=$(make_tree '#!/usr/bin/env python3
import sys
sys.exit(2)')
  out=$(run_block "$t" "$MUT")
  if printf '%s' "$out" | grep -q '판정 줄을 안 냈다'; then
    bad "L8 되돌림 — 문구를 지웠는데도 L4 가 초록이다"
  else
    ok "L8 되돌림 — 계기-오류 보고를 지우자 L4 가 침묵한다 (그 줄이 L4 를 지고 있다)"
  fi
fi

# ── L9 containment — the real repo was not touched ───────────────────────────
# 🟥 초판은 여기서 `git diff --quiet … || true` 를 불렀다 — 항상 참이라 아무것도 안 재는
#    장식이었다. 실제 단언은 픽스처 위치 하나다.
case "$TMP" in
  "$REPO_ROOT"*) bad "L9 containment — 픽스처가 실제 레포 안에 있다" ;;
  *)             ok "L9 containment — 픽스처는 레포 밖 임시 트리다 (실제 레포 미변경)" ;;
esac

echo "----"
echo "stale-ref close lanes: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

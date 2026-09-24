#!/usr/bin/env bash
# score_policy_lens.sh — mechanical scorer for the maintainer POLICY-LENS known-pair sim.
#
# Sealed design: scripts/fixtures/policy_lens_knownpair_2026-09-21/PREREG.md
#   (sha256 in PREREG.sha256 — if that hash moved, this scorer is scoring a different experiment)
#
# WHY A SCORER AND NOT AN EYE. The 2026-09-21 measurement this replaces scored by hand and its
# own author later found two defects in the SCORING, not in the lens (a CLOSED label that folded
# "not this" and "not now"; a corpus with no known-positive for DECLINE at all). A scorer that
# runs is auditable; an eye is not.
#
# WHAT IT DOES NOT DO. It does not judge whether a REASON is good. It extracts a typed verdict,
# greps the quote against the material THAT ARM ACTUALLY RECEIVED, and compares the quote to the
# key span. Closed here is the FORM (is the citation real, is it the governing one) — never the
# truth of the judgement (CLAUDE.md §Mechanization Boundary).
#
# USAGE
#   bash scripts/score_policy_lens.sh --selftest                      # known pair, run this FIRST
#   bash scripts/score_policy_lens.sh --key <KEY.tsv> --runs <dir>    # score a run directory
#
# RUN DIRECTORY CONTRACT
#   <dir>/<ARM|CTRL>-<FIXID>_r<N>.txt          one arm response per rep (sim_isolated_run naming)
#   <dir>/material_<ARM|CTRL>-<FIXID>.txt      the exact material that arm was given
#
# 🟥 INVALID IS NOT "LOW". A run with no RISK: line, or one that never names the fixture's unique
#   token, is INVALID and is excluded from every rate. Folding it into LOW would render an
#   instrument failure as a lens finding ([[feedback_not_found_is_not_zero_family]]).

set -uo pipefail

KEYF=""; RUNS=""; SELFTEST=0
while [ $# -gt 0 ]; do
  case "$1" in
    --key)      KEYF="${2:-}"; shift 2 ;;
    --runs)     RUNS="${2:-}"; shift 2 ;;
    --selftest) SELFTEST=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

# normalize: lowercase + collapse all whitespace to single spaces + trim
_norm() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -s '[:space:]' ' ' \
    | sed -e 's/^ *//' -e 's/ *$//'
}

# _contains_norm <haystack-file> <needle> — whitespace-normalized containment.
# 🟥 WHY NOT grep -F. grep is LINE oriented. Prose corpora are line-wrapped, and a model quoting
#   a wrapped sentence returns it UNWRAPPED — so grep -F reports "not found" for a quote that is
#   verbatim present. Measured 2026-09-21 on this fixture set: every PHANTOM hand-checked was
#   this artifact, not a fabrication. A scorer that manufactures PHANTOM is worse than no
#   grounding measure, because PHANTOM is the finding it exists to produce.
_contains_norm() {
  local mf="$1" nq nm
  nq=$(printf '%s' "$2" | tr -s '[:space:]' ' ' | sed -e 's/^ *//' -e 's/ *$//')
  [ -n "$nq" ] || return 1
  nm=$(tr -s '[:space:]' ' ' < "$mf")
  case "$nm" in *"$nq"*) return 0 ;; esac
  return 1
}

# _field <file> <KEY:> — first matching line's value, empty if absent
_field() {
  local f="$1" k="$2" line
  line=$(grep -m1 "^[[:space:]]*\*\{0,2\}${k}" "$f" 2>/dev/null)
  [ -z "$line" ] && { printf ''; return 1; }
  printf '%s' "$line" | sed -e "s/^[[:space:]]*\*\{0,2\}${k}\*\{0,2\}[[:space:]]*//" \
                            -e 's/^["“”]//' -e 's/["“”][[:space:]]*$//' \
                            -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

# _quote_block <file> — QUOTE: 값을 **다음 필드 표지까지** 전부. 한 줄만 읽으면
# 이어지는 줄에 지어낸 문장을 붙여도 GROUNDED 로 채점된다(2026-09-21 실행 재현).
_quote_block() {
  /usr/bin/awk '
    /^[[:space:]]*[*]*QUOTE:/ && !inq {
      inq=1; sub(/^[[:space:]]*[*]*QUOTE:[[:space:]]*/,""); print; next }
    inq && /^[[:space:]]*[*]*(RISK|REASON|QUOTE|ACTION):/ { inq=0 }
    inq { print }
  ' "$1" 2>/dev/null | tr '\n' ' ' | /usr/bin/sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
      -e 's/^["“”]//' -e 's/["“”][[:space:]]*$//'
}

# score_one <runfile> <materialfile> <expected> <unique_token> <span1> <span2...> <arm>
#   <span2...> may carry MORE THAN ONE span, tab-joined — `read` hands the rest of a KEY line to
#   its last variable, so a round-2 key that lists every governing sentence arrives here intact.
#   A 2-span key (round 1) behaves exactly as before; lane P2 pins that byte for byte.
#   <unique_token> = NONE disables the read-evidence gate (round-2 seal drops it: the 4-line
#   contract has no slot for a repo name — RESULT_round1_VOID.md defect ②).
# emits: risk<TAB>flagged_strict<TAB>flagged_relaxed<TAB>grounding<TAB>ontarget<TAB>verdict
score_one() {
  local rf="$1" mf="$2" expected="$3" tok="$4" s1="$5" s2="$6" arm="$7"
  local risk quote grounding ontarget fs fr hits nq ns

  [ -s "$rf" ] || { printf 'INVALID\tNA\tNA\tNA\tNA\tINVALID-EMPTY\n'; return; }

  # 🟥 필드 중복은 «첫 줄이 이긴다» 가 아니라 INVALID 다. `RISK: LOW` 다음 줄에 `RISK: HIGH`
  #    가 오면 기록이 무엇을 말하는지 채점기가 정할 일이 아니다(2026-09-21 실행 재현).
  for _k in RISK QUOTE; do
    _n=$(/usr/bin/grep -c "^[[:space:]]*[*]*${_k}:" "$rf" 2>/dev/null); _n="${_n:-0}"
    if [ "$_n" -gt 1 ]; then
      printf 'INVALID\tNA\tNA\tNA\tNA\tINVALID-DUP-FIELD\n'; return
    fi
  done

  risk=$(_field "$rf" "RISK:")
  # 🟥 첫 «낱말» 로만 판정한다. 부분일치로 받으면 `RISK: NOT HIGH` 와 `RISK: HIGHLIGHT` 가
  #    둘 다 HIGH 로 채점된다 — 앞의 것은 판정이 **뒤집힌다**(2026-09-21 실행 재현:
  #    `NOT HIGH` → HIGH · flag_strict=1). 닫는 것은 enum 멤버십이지 문장의 뜻이 아니다.
  risk=$(printf '%s' "$risk" | tr '[:lower:]' '[:upper:]' \
         | /usr/bin/sed -e 's/[^A-Z][^A-Z]*/ /g' -e 's/^ *//' | cut -d' ' -f1)
  case "$risk" in HIGH|MEDIUM|LOW) : ;; *) risk="" ;; esac
  [ -z "$risk" ] && { printf 'INVALID\tNA\tNA\tNA\tNA\tINVALID-NO-RISK\n'; return; }

  # instrument survival: did the arm actually read the material it was handed?
  # 🟥 cross-family R1: an EMPTY token column must not disable the gate — `grep -cF ""` matches every
  #   line. Only the written word NONE turns it off; a blank is a malformed key → INVALID-NO-TOKEN.
  if [ -z "$tok" ]; then hits=0
  elif [ "$tok" = "NONE" ]; then hits=1
  else hits=$(grep -cF "$tok" "$rf" 2>/dev/null); hits="${hits:-0}"; fi
  if [ "$hits" -eq 0 ]; then
    printf '%s\tNA\tNA\tNA\tNA\tINVALID-NO-TOKEN\n' "$risk"; return
  fi

  if [ "$risk" = "HIGH" ]; then fs=1; else fs=0; fi
  if [ "$risk" = "HIGH" ] || [ "$risk" = "MEDIUM" ]; then fr=1; else fr=0; fi

  quote=$(_quote_block "$rf")
  if [ -z "$quote" ] || [ "$(_norm "$quote")" = "none" ]; then
    grounding="NOQUOTE"; ontarget="NA"
  else
    if _contains_norm "$mf" "$quote"; then grounding="GROUNDED"; else grounding="PHANTOM"; fi
    if [ "$arm" = "CTRL" ]; then
      ontarget="NO-CORPUS"
    elif [ "$s1" = "NONE" ] && [ "$s2" = "NONE" ]; then
      ontarget="NA"
    else
      ontarget="OFFTARGET"
      nq=$(_norm "$quote")
      local _spans=() _sp
      IFS=$'\t' read -r -a _spans <<< "$s1"$'\t'"$s2"
      for _sp in "${_spans[@]}"; do
        ns=$(_norm "$_sp")
        [ "$ns" = "none" ] && continue
        [ -z "$ns" ] && continue
        case "$nq" in *"$ns"*) ontarget="ONTARGET"; break ;; esac
        case "$ns" in *"$nq"*) ontarget="ONTARGET"; break ;; esac
      done
    fi
  fi

  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$risk" "$fs" "$fr" "$grounding" "$ontarget" "$expected"
}

# ── selftest: the scorer's own known pair. Both cases, same execution. ────────────────────────
if [ "$SELFTEST" -eq 1 ]; then
  T=$(mktemp -d "${TMPDIR:-/tmp}/scorer-selftest-XXXXXX")
  printf '%s\n' 'We do not ship a browser interface. The terminal is the product.' \
                'tidewatch is a terminal UI.' > "$T/material_ARM-X.txt"
  printf '%s\n' 'RISK: HIGH' 'REASON: adds a named non-goal surface to tidewatch' \
      'QUOTE: We do not ship a browser interface. The terminal is the product.' \
      'ACTION: drop the http surface' > "$T/pos.txt"
  printf '%s\n' 'RISK: LOW' 'REASON: looks fine for tidewatch' \
      'QUOTE: the maintainers welcome new surfaces behind flags' \
      'ACTION: none' > "$T/neg.txt"

  SPAN='We do not ship a browser interface. The terminal is the product.'
  P=$(score_one "$T/pos.txt" "$T/material_ARM-X.txt" DECLINE tidewatch "$SPAN" NONE ARM)
  N=$(score_one "$T/neg.txt" "$T/material_ARM-X.txt" DECLINE tidewatch "$SPAN" NONE ARM)
  echo "  known-positive -> $P"
  echo "  known-negative -> $N"

  FAIL=0
  case "$P" in HIGH*GROUNDED*ONTARGET*) : ;; *) echo "❌ positive did not score HIGH/GROUNDED/ONTARGET"; FAIL=1 ;; esac
  case "$N" in LOW*PHANTOM*OFFTARGET*) : ;; *) echo "❌ negative did not score LOW/PHANTOM/OFFTARGET"; FAIL=1 ;; esac
  [ "$P" = "$N" ] && { echo "❌ the pair did not separate at all"; FAIL=1; }

  # third control: a contract-breaking output must be INVALID, never LOW
  printf '%s\n' 'I think this PR is probably fine.' > "$T/bad.txt"
  B=$(score_one "$T/bad.txt" "$T/material_ARM-X.txt" DECLINE tidewatch "$SPAN" NONE ARM)
  echo "  contract-breaker -> $B"
  case "$B" in INVALID*) : ;; *) echo "❌ contract-breaking output was not INVALID"; FAIL=1 ;; esac

  # fourth control: FILE SELECTION. The runner writes .prompt/.stderr/.treediff siblings that
  # all match "_r*.txt"; scoring them would fabricate INVALID rows. Known pair: one real
  # response file and one decoy sibling in the same dir -> exactly one scored row.
  S="$T/sel"; mkdir -p "$S"
  printf 'x\n' > "$S/material_ARM-Z.txt"
  printf '%s\n' 'RISK: LOW' 'REASON: r' 'QUOTE: x' 'ACTION: a' > "$S/ARM-Z_r1.txt"
  cp "$S/ARM-Z_r1.txt" "$S/ARM-Z_r1.prompt.txt"
  : > "$S/ARM-Z_r1.treediff.txt"
  printf '#\nZ\trepo\tax\tACCEPT\tx\tNONE\tNONE\n' > "$S/k.tsv"
  SELOUT=$(bash "$0" --key "$S/k.tsv" --runs "$S"); SELRC=$?
  [ "$SELRC" -eq 0 ] || { echo "❌ file-selection: 채점기가 rc=$SELRC 로 죽었다"; FAIL=1; }
  SEL=$(printf '%s\n' "$SELOUT" | grep -c '^ARM-Z')
  echo "  file-selection -> $SEL scored row(s) from 1 response + 2 decoys"
  [ "$SEL" = "1" ] || { echo "❌ file selection scored $SEL rows, expected 1"; FAIL=1; }

  # fifth control: WRAPPED SOURCE. A quote that is verbatim present but line-wrapped in the
  # source must score GROUNDED; a quote genuinely absent must still score PHANTOM. Both in one
  # execution, or the "fix" is just a looser matcher that grounds everything.
  W="$T/wrap"; mkdir -p "$W"
  printf '%s\n' 'If you can get the same win through the platform module so that all four' \
                 'targets go through it, I will merge that the day it lands.' > "$W/material_ARM-W.txt"
  printf '%s\n' 'RISK: HIGH' 'REASON: r' \
    'QUOTE: If you can get the same win through the platform module so that all four targets go through it, I will merge that the day it lands.' \
    'ACTION: a' > "$W/ARM-W_r1.txt"
  printf '%s\n' 'RISK: HIGH' 'REASON: platform policy' 'QUOTE: the maintainer said he loves windows-only branches' 'ACTION: a' > "$W/ARM-W_r2.txt"
  printf '#\nW\trepo\tax\tDECLINE\tplatform\tNONE\tNONE\n' > "$W/k.tsv"
  WOUT=$(bash "$0" --key "$W/k.tsv" --runs "$W"); WRC=$?
  [ "$WRC" -eq 0 ] || { echo "❌ wrapped-source: 채점기가 rc=$WRC 로 죽었다"; FAIL=1; }
  WG=$(printf '%s' "$WOUT" | grep -c 'GROUNDED'); WP=$(printf '%s' "$WOUT" | grep -c 'PHANTOM')
  echo "  wrapped-source -> GROUNDED=$WG (want 1)  PHANTOM=$WP (want 1)"
  { [ "$WG" = "1" ] && [ "$WP" = "1" ]; } || { echo "❌ wrapped-source pair did not separate"; FAIL=1; }

  # sixth control: RISK ENUM. 부분일치를 받으면 `NOT HIGH` 가 HIGH 로 **뒤집힌다**.
  #    음성(뒤집히는 입력)과 양성(사족 달린 정상 입력)을 같은 회차에 — 한쪽만 보면
  #    「전부 INVALID 로 만들기」가 통과해 버린다.
  printf '%s\n' 'RISK: NOT HIGH' 'REASON: tidewatch' 'QUOTE: We do not ship a browser interface.' 'ACTION: a' > "$T/e_neg.txt"
  printf '%s\n' 'RISK: HIGH — 브라우저 표면을 새로 연다' 'REASON: tidewatch' 'QUOTE: We do not ship a browser interface.' 'ACTION: a' > "$T/e_pos.txt"
  EN=$(score_one "$T/e_neg.txt" "$T/material_ARM-X.txt" DECLINE tidewatch "$SPAN" NONE ARM)
  EP=$(score_one "$T/e_pos.txt" "$T/material_ARM-X.txt" DECLINE tidewatch "$SPAN" NONE ARM)
  echo "  risk-enum -> «NOT HIGH»:$(printf '%s' "$EN" | cut -f1)  «HIGH — …»:$(printf '%s' "$EP" | cut -f1)"
  case "$EN" in INVALID*) : ;; *) echo "❌ «RISK: NOT HIGH» 가 유효 판정으로 통과했다"; FAIL=1 ;; esac
  case "$EP" in HIGH*) : ;; *) echo "❌ 사족 달린 «RISK: HIGH» 를 과차단했다"; FAIL=1 ;; esac

  # seventh control: MULTI-LINE QUOTE. 이어지는 줄에 지어낸 문장을 붙인 인용은 PHANTOM,
  #    한 줄짜리 진짜 인용은 GROUNDED. 둘을 같은 회차에 — 안 그러면 「전부 PHANTOM」이 통과한다.
  printf '%s\n' 'RISK: HIGH' 'REASON: tidewatch' \
    'QUOTE: We do not ship a browser interface. The terminal is the product.' \
    'and the maintainer also promised to merge any browser PR on sight.' 'ACTION: a' > "$T/m_neg.txt"
  MN=$(score_one "$T/m_neg.txt" "$T/material_ARM-X.txt" DECLINE tidewatch "$SPAN" NONE ARM)
  MP=$(score_one "$T/pos.txt" "$T/material_ARM-X.txt" DECLINE tidewatch "$SPAN" NONE ARM)
  echo "  multiline-quote -> 지어낸 이어짐:$(printf '%s' "$MN" | cut -f4)  한 줄 진짜:$(printf '%s' "$MP" | cut -f4)"
  case "$MN" in *PHANTOM*) : ;; *) echo "❌ 이어지는 줄의 지어낸 인용이 GROUNDED 로 통과했다"; FAIL=1 ;; esac
  case "$MP" in *GROUNDED*) : ;; *) echo "❌ 한 줄짜리 진짜 인용을 PHANTOM 으로 과차단했다"; FAIL=1 ;; esac

  # eighth control: DUPLICATE FIELD. 첫 줄이 조용히 이기면 안 된다.
  printf '%s\n' 'RISK: LOW' 'RISK: HIGH' 'REASON: tidewatch' 'QUOTE: We do not ship a browser interface.' 'ACTION: a' > "$T/d_neg.txt"
  DN=$(score_one "$T/d_neg.txt" "$T/material_ARM-X.txt" DECLINE tidewatch "$SPAN" NONE ARM)
  echo "  duplicate-field -> $(printf '%s' "$DN" | cut -f6)"
  case "$DN" in *INVALID-DUP-FIELD*) : ;; *) echo "❌ RISK 중복이 조용히 첫 줄로 채점됐다"; FAIL=1 ;; esac

  # ninth control: ZERO ROWS. 「나쁜 행이 없다」와 「아무것도 안 읽었다」를 가른다.
  Z="$T/zero"; mkdir -p "$Z"
  printf '#\nZZ\trepo\tax\tACCEPT\tx\tNONE\tNONE\n' > "$Z/k.tsv"
  ZOUT=$(bash "$0" --key "$Z/k.tsv" --runs "$Z" 2>&1); ZRC=$?
  echo "  zero-rows -> rc=$ZRC (want 4)"
  [ "$ZRC" -eq 4 ] || { echo "❌ 빈 런 디렉터리가 rc=$ZRC 로 통과했다 — 안 읽은 것이 초록으로 나온다"; FAIL=1; }

  # tenth control: RUN WITHOUT MATERIAL. 자료 없는 채점은 기권이지 판정이 아니다.
  #    🟥 그리고 그 짝 — «런 파일도 없는 팔» 은 정상이므로 막으면 안 된다(위 file-selection
  #       통제가 CTRL 자료 없이 통과하는 것이 그 컨트롤이다).
  M="$T/nomat"; mkdir -p "$M"
  printf '%s\n' 'RISK: HIGH' 'REASON: r' 'QUOTE: x' 'ACTION: a' > "$M/ARM-MM_r1.txt"
  printf '#\nMM\trepo\tax\tDECLINE\tx\tNONE\tNONE\n' > "$M/k.tsv"
  MOUT=$(bash "$0" --key "$M/k.tsv" --runs "$M" 2>&1); MRC=$?
  echo "  run-without-material -> rc=$MRC (want 4)"
  [ "$MRC" -eq 4 ] || { echo "❌ 자료 없는 런이 rc=$MRC 로 통과했다"; FAIL=1; }

  # eleventh control: CURLY-QUOTE STRIPPING. 🟥 2026-09-22 — 이 자리가 조용히 틀려 있었다.
  #    `_quote_block` 의 sed 가 브래킷 안에 `[\xe2\x80\x9c…]` 를 썼는데, POSIX 브래킷은
  #    `\xNN` 을 이스케이프로 안 읽는다 ⇒ 굽은 따옴표는 **안 벗겨지고**, 대신 그 리터럴이
  #    담은 ASCII(`e x 2 8 0 9 c d`)를 지운다. 실측: `exec0` → `xec0`.
  #    🟥 그런데 위 통제 열 개가 전부 초록이었다 — 픽스처가 굽은 따옴표를 안 쓰고, 첫 글자도
  #    그 집합 밖이었다. **픽스처가 실물의 모양을 안 담으면 초록은 아무것도 증명하지 않는다.**
  printf '%s\n' 'RISK: HIGH' 'REASON: tidewatch' \
    'QUOTE: “We do not ship a browser interface. The terminal is the product.”' \
    'ACTION: a' > "$T/q_pos.txt"
  QP=$(score_one "$T/q_pos.txt" "$T/material_ARM-X.txt" DECLINE tidewatch "$SPAN" NONE ARM)
  echo "  curly-quote -> $(printf '%s' "$QP" | cut -f4)"
  case "$QP" in *GROUNDED*) : ;; *) echo "❌ 굽은 따옴표가 안 벗겨져 진짜 인용이 PHANTOM 이 됐다"; FAIL=1 ;; esac

  rm -rf "$T"
  if [ "$FAIL" -eq 0 ]; then echo "✅ scorer known-pair held — safe to score real runs"; exit 0
  else echo "🟥 scorer is DEAD — do not score, do not publish a number"; exit 1; fi
fi

[ -n "$KEYF" ] && [ -n "$RUNS" ] || { echo "need --key and --runs (or --selftest)" >&2; exit 2; }
[ -f "$KEYF" ] || { echo "key not found: $KEYF" >&2; exit 2; }

# 🟥 **채점한 행이 0 이면 그건 «나쁜 행이 없다» 가 아니라 «아무것도 안 읽었다» 다.**
#    2026-09-21 실행 재현: 빈 --runs 디렉터리에 헤더만 찍고 rc=0. 깨진 블라인드 sim 이
#    「깨끗함」으로 읽힌다 — 같은 날 worktree_reclaim.sh 가 앓던 바로 그 병이다.
ROWS=0
MISSING_MATERIAL=""

printf 'run\tfixture\tarm\trep\trisk\tflag_strict\tflag_relaxed\tgrounding\tontarget\texpected\n'
# 🟥 tab is IFS WHITESPACE: `IFS=$'\t' read` collapses consecutive tabs, so an EMPTY column vanishes
#   and every later column slides left (an empty token column made span_1 the token). Split on a
#   non-whitespace separator instead, then restore tabs inside the span remainder.
#   Named residual (cross-family R2, B): a span that itself contains byte \037 is split in two. The KEY
#   is authored by us from policy prose; a control byte there is a malformed key, not an input to defend.
while IFS= read -r _line; do
  IFS=$'\037' read -r id repo axis expected tok s1 s2 <<< "${_line//$'\t'/$'\037'}"
  s2="${s2//$'\037'/$'\t'}"
  case "$id" in \#*|"") continue ;; esac
  for arm in ARM CTRL; do
    mf="$RUNS/material_${arm}-${id}.txt"
    if [ ! -f "$mf" ]; then
      # 그 팔의 런 파일이 «있는데» 자료가 없으면 계기 결함이다. 런 파일도 없으면
      # 그 팔을 안 돌린 것이고 정상이다 — 둘을 같은 침묵으로 접지 않는다.
      for _probe in "$RUNS/${arm}-${id}"_r[0-9].txt "$RUNS/${arm}-${id}"_r[0-9][0-9].txt; do
        [ -f "$_probe" ] && { MISSING_MATERIAL="$MISSING_MATERIAL ${arm}-${id}"; break; }
      done
      continue
    fi
    for rf in "$RUNS/${arm}-${id}"_r*.txt; do
      [ -f "$rf" ] || continue
      # 🟥 the runner writes SIBLINGS per rep: .prompt.txt .stderr.txt .treediff.txt
      #    .setupdiff.txt .meta.tsv — all match "_r*.txt". Scoring them would manufacture
      #    INVALID rows out of instrument bookkeeping. Accept ONLY <arm>-<id>_r<N>.txt.
      case "$rf" in
        *_r[0-9].txt|*_r[0-9][0-9].txt) : ;;
        *) continue ;;
      esac
      rep=$(basename "$rf" .txt); rep="${rep##*_r}"
      row=$(score_one "$rf" "$mf" "$expected" "$tok" "$s1" "$s2" "$arm")
      printf '%s\t%s\t%s\t%s\t%s\n' "$(basename "$rf")" "$id" "$arm" "$rep" "$row"
      ROWS=$((ROWS+1))
    done
  done
done < "$KEYF"

if [ -n "$MISSING_MATERIAL" ]; then
  printf '🟥 HARNESS-ERROR: 런 파일은 있는데 그 팔이 «받은 자료» 가 없다 —%s\n' \
    "$MISSING_MATERIAL" >&2
  printf '   그라운딩은 자료 대조라, 자료 없이는 채점이 아니라 기권이다.\n' >&2
  exit 4
fi
if [ "$ROWS" -eq 0 ]; then
  printf '🟥 HARNESS-ERROR: 채점한 행이 0 이다 — «나쁜 행이 없다» 가 아니라 «아무것도 안 읽었다».\n' >&2
  printf '   --runs=%s · --key=%s 를 확인해라(파일명 계약: <ARM|CTRL>-<FIXID>_r<N>.txt).\n' \
    "$RUNS" "$KEYF" >&2
  exit 4
fi

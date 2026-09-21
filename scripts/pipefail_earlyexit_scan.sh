#!/usr/bin/env bash
# pipefail_earlyexit_scan.sh — «생산자 | 조기종료 소비자» 취약형 전수 스캔 (클래스 잠금용 계기)
#
# 무엇을 찾나: `set -o pipefail` 아래에서 파이프라인의 소비자가 **입력을 끝까지 안 읽고 끝나면**
# 생산자가 SIGPIPE 로 죽어 141 을 남기고, pipefail 이 그 141 을 파이프라인 종료코드로 올린다.
# ⇒ **매치했는데 `if` 는 거짓이 된다.** PASS→FAIL 한 방향으로만 튄다(무매치는 EOF 까지 읽어 안전).
#
# 🟥 **판별자를 «남은 바이트 vs 64 KiB» 로 쓰면 안 된다 — 실측이 그 모델을 반증했다(2026-09-21).**
#    PR #785 는 «버퍼 안에 다 들어가면 경합 자체가 없다» 고 적고 그 근거로 세 자리를 «✅ 버퍼 안»
#    으로 면제했다. 같은 호스트에서 매치 이후 잔여 바이트를 쓸어보니 **64 KiB 한참 안쪽에서 이미
#    뒤집힌다**(`sed -n '1,$p' F | grep -q NEEDLE`, 100 reps/점, 합성 픽스처):
#
#      총 400,000 B :  8 KB→0/100 · 16 KB→22/100 · 17.9 KB→36/100
#      총  70,726 B :  12 KB→0/100 · 16 KB→2/100 · 17.9 KB→8/100 · 24 KB→18/100 · 32 KB→33/100
#      (400 KB 총량) : 24 KB→57/100 · 32 KB→49/100 · 48 KB→98/100 · 64 KiB→99/100 · 128 KB→100/100
#
#    ⇒ 발현은 «문턱» 이 아니라 **확률 램프**이고, 온셋은 ~16 KB 다. 64 KiB 는 포화점이지 경계가 아니다.
#    #785 이 면제한 세 자리는 수백 B 라 **결론은 살아남지만 근거는 틀렸다** — 안전 여유는
#    64 KiB 가 아니라 실측 ~12 KB 이하다.
#
# 🟥 게다가 **같은 자리가 호스트마다 다르다.** #785 의 실사고 자리(`_sync_src | grep -q 'tar cf …'`,
#    잔여 17,918 B)는 CI 에서 **4/200** 이었는데, 이 맥에서는 리터럴 패턴·eval 없이 400 회 돌려
#    **0/400** 이다(컨트롤: 같은 실행의 300 KB 결정적 픽스처 40/40 — 계기는 살아 있다).
#    ⇒ **바이트 수로 어떤 자리도 «안전» 으로 지울 수 없다.** 그래서 이 스캔은 바이트를 세지 않고
#    **형태**를 센다. 정적으로 «상한이 구조적으로 있나» 만 근사하고, 나머지는 시끄럽게 표기한다.
#
# 🟥 실측이 PR #785 의 모델을 두 군데 정정했다(2026-09-21, `/bin/bash`, 300 KB 픽스처, 20 reps):
#    ⓐ `printf` 는 **바운드가 아니다** — `printf '%s' "$BIGVAR" | grep -q` 가 **20/20** 뒤집힌다.
#       (`$BIGVAR` 가 작으면 안전하다 — 그래서 VAR-DEPENDENT 로 갈라 적는다.)
#       (#785 의 전수표는 printf 를 「빌트인, 수십 B → ✅ 버퍼 안」으로 적었다. 인수에 달렸다.)
#    ⓑ 조기종료 소비자는 `grep -q` 하나가 아니다 — 같은 조건에서 **20/20** 뒤집히는 것들:
#       `grep -q` · `grep -Eq` · `grep -m1` · `head -1` · `sed 1q` · `awk '…{exit}'` · `read`.
#       안 뒤집히는 것: `grep -c` · `sed -n 1p` (둘 다 EOF 까지 읽는다) · 파일 직접 `grep -q FILE`.
#
# 출력: TSV — verdict <TAB> file:line <TAB> producer-class <TAB> consumer <TAB> rc-context <TAB> 원문
# 종료코드: 0 = 잠금 대상(VULN) 0 곳 · 1 = VULN 있음 · 2 = 계기 오류(자가 교정 실패)
#
# 🟥 이 스캔은 **탐지 전용이다.** 찾은 자리를 고치는 것은 별건이다 — 한 커밋에 탐지와 수리를
#    섞으면 레인이 자기 수리를 못 본다.
set -uo pipefail
export LC_ALL=C

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="${PIPESCAN_REPO:-$(cd "$HERE/.." && pwd)}"
MODE="${1:-report}"          # report | list | selftest | changed
ONLY="${2:-}"                # 단일 파일 스캔(자가 교정용)

# ── 조기종료 소비자 판별 ───────────────────────────────────────────────────────
# 실측으로 확인된 것만. 「끝까지 읽는」 형태(grep -c · sed -n Np · wc · sort)는 대상이 아니다.
_consumer_kind(){   # stdin: 파이프 세그먼트 1개 → 조기종료 종류 또는 빈 문자열
  local seg="$1"
  seg="${seg#"${seg%%[![:space:]]*}"}"                 # ltrim
  case "$seg" in
    # grep 계열: -q / --quiet / --silent / -m N / --max-count / -l / -L
    grep\ *|*/grep\ *|*[[:space:]]grep\ *|egrep\ *|fgrep\ *)
      case "$seg" in
        *--quiet*|*--silent*) echo "grep--quiet"; return;;
        *--max-count*)        echo "grep--max-count"; return;;
        *--files-with-matches*|*--files-without-match*) echo "grep--files"; return;;
      esac
      # 번들 단문자 플래그에서 q/l/L/m 을 찾는다 (-Eq · -qs · -iq · -m1 …)
      # 🟥 옵션 구간이 끝나면 **멈춘다.** 안 멈추면 `[ "$(… | grep -c .)" -eq 0 ]` 의 **`-eq` 가
      #    「q 를 품은 번들 플래그」로 읽혀** grep -c 를 조기종료로 오판한다(실측 오탐 1건,
      #    sync_to_be_lanes.sh:498). grep 의 옵션은 패턴 앞에만 온다.
      local w _seen=0
      for w in $seg; do
        if [ "$_seen" -eq 0 ]; then
          case "$w" in grep|egrep|fgrep|*/grep|*/egrep|*/fgrep) _seen=1;; esac
          continue
        fi
        case "$w" in
          --*) continue;;
          -[A-Za-z]*)
            case "$w" in
              *q*) echo "grep -q"; return;;
              *m*) echo "grep -m";  return;;
              *l*) echo "grep -l";  return;;
              *L*) echo "grep -L";  return;;
            esac; continue;;
          *) break;;
        esac
      done
      echo ""; return;;
    head|head\ *)   echo "head";  return;;
    read|read\ *)   echo "read";  return;;
    sed\ *|*/sed\ *)
      # `sed 1q` · `sed -n '1p;1q'` · `sed '/x/q'` — q 커맨드가 있으면 조기종료.
      case "$seg" in *[0-9]q*|*\;q*|*/q*|*\ q\ *|*\'q\'*) echo "sed q"; return;; esac
      echo ""; return;;
    awk\ *|*/awk\ *)
      case "$seg" in *exit*) echo "awk exit"; return;; esac
      echo ""; return;;
  esac
  echo ""
}

# ── 논리행 재구성 (heredoc 제거 · 백슬래시/파이프 연속 결합) ─────────────────────
_logical_lines(){
  /usr/bin/awk '
    { raw[NR]=$0 }
    END{
      buf=""; start=0; hd=""
      for(i=1;i<=NR;i++){
        l=raw[i]
        # 🟥 heredoc 본문은 **데이터다.** 안 빼면 픽스처가 코드로 읽혀 오탐이 난다
        #    (초판이 자기 known-positive 픽스처를 실제 취약형으로 신고했다).
        if(hd!=""){ s2=l; gsub(/^[[:space:]]+|[[:space:]]+$/,"",s2); if(s2==hd) hd=""; continue }
        if(match(l, /<<-?[\047"]?[A-Za-z_][A-Za-z0-9_]*[\047"]?/)){
          t=substr(l,RSTART,RLENGTH); gsub(/^<<-?[\047"]?/,"",t); gsub(/[\047"]$/,"",t); hd=t
        }
        s=l; sub(/^[[:space:]]+/,"",s)
        if(buf==""){ start=i }
        if(buf=="" && s ~ /^#/){ continue }
        buf = (buf=="" ? l : buf " " s)
        cont = 0
        if(buf ~ /\\$/){ sub(/\\$/,"",buf); cont=1 }
        else if(buf ~ /\|[[:space:]]*$/ && buf !~ /\|\|[[:space:]]*$/){ cont=1 }
        else if(i<NR){ n=raw[i+1]; sub(/^[[:space:]]+/,"",n); if(n ~ /^\|[^|]/){ cont=1 } }
        if(cont) continue
        print start "\t" buf
        buf=""
      }
      if(buf!="") print start "\t" buf
    }' "$1"
}

# ── 🟥 파이프처럼 보이지만 파이프가 아닌 `|` 를 가린다 ─────────────────────────────
# 실측 오탐 2건이 **같은 뿌리**였다: ⓐ `${r%%|*}` 의 `|` 가 세그먼트를 갈라 원점이 엉뚱해졌다
# (test_leak_scan_control_lanes.sh:156) · ⓑ 다른 레인의 **시험 데이터**인 `'false | { grep -q ok; }'`
# 가 코드로 읽혔다(test_pipe_verdict_guard_lanes.sh:144). 인용부호 안·`${}` 안의 `|` 는
# 파이프가 아니다. heredoc 을 뺀 것과 **같은 이유** — 데이터를 코드로 읽지 않는다.
# ⓒ 같은 뿌리가 `&&` 에서 한 번 더 났다: `dr "curl … && echo OK" | grep -q OK` 에서 `_norm_seg` 의
#    `${seg##*&&}` 가 **인용부호 안** 의 && 로 갈라 생산자를 `echo OK` 로 읽고 BOUNDED 를 냈다
#    (docker_phase1b_verify.sh:32 — 손판정 TRUE 가 조용히 BOUNDED 로 뒤집혔다). 그래서 마스크는
#    `|` 하나가 아니라 **분리자 전부**를 덮고, 판정 함수들은 **마스크를 벗기지 않은 채** 읽는다.
_mask_nonops(){
  # 🟥 `$( … )` 는 **인용 문맥을 새로 연다** — `x="$(ls … | head -1)"` 의 `|` 는 바깥 `"` 안에
  #    있어도 **진짜 파이프다.** 초판이 이걸 놓쳐 참 양성 2건이 조용히 사라졌다
  #    (compaction_probe.sh:139 · fh_session_load.sh:512). 그래서 `$(` 에서 인용 상태를
  #    스택에 밀어 넣고 0 으로 리셋하며, 짝 `)` 에서 되돌린다. `${…}` 는 명령이 아니라 그대로 가린다.
  /usr/bin/awk '{
    out=""; sq=0; dq=0; br=0; cd=0; n=length($0)
    for(i=1;i<=n;i++){
      c=substr($0,i,1); c2=substr($0,i,2)
      if(c=="\\" && i<n){ out=out c substr($0,i+1,1); i++; continue }
      if(c2=="$(" && sq==0){ cd++; ssq[cd]=sq; sdq[cd]=dq; sq=0; dq=0; out=out c2; i++; continue }
      if(c==")" && cd>0 && sq==0 && dq==0){ sq=ssq[cd]; dq=sdq[cd]; cd--; out=out c; continue }
      if(c2=="${" && sq==0){ br++; out=out c2; i++; continue }
      if(c=="}" && br>0){ br--; out=out c; continue }
      if(c=="\047" && dq==0){ sq=1-sq; out=out c; continue }
      if(c=="\"" && sq==0){ dq=1-dq; out=out c; continue }
      if(sq==1 || dq==1 || br>0){
        if(c=="|"){ out=out "@@PIPE@@"; continue }
        if(c=="&"){ out=out "@@AMP@@";  continue }
        if(c==";"){ out=out "@@SEMI@@"; continue }
      }
      out=out c
    }
    print out }'
}

# ── 세그먼트 정규화 — 🟥 생산자 판정과 차폐 판정이 **같은** 정규화를 써야 한다 ──────────
# 초판은 `_producer_class` 에만 껍데기 벗기기를 뒀고, `_shield_kind` 는 `if sed -n …` 의 `if` 를
# 못 벗겨서 차폐를 놓쳤다(실측 오탐 1건, portability_lint.sh:135). 두 판정이 다른 정규화를 쓰면
# 한쪽이 보는 명령과 다른 쪽이 보는 명령이 달라진다.
_norm_seg(){
  local seg="$1"
  # 파이프가 중첩 `$( )` 안이면 생산자는 그 안의 명령이다. 산술 `$((…))` 는 먼저 가려낸다.
  local _a="$seg"
  while :; do case "$_a" in *'$(('*) _a="${_a/\$((/@@AR@@}";; *) break;; esac; done
  case "$_a" in *'$('*) _a="${_a##*\$(}";; esac
  seg="$_a"
  seg="${seg##*;}"; seg="${seg##*&&}"
  seg="${seg#"${seg%%[![:space:]]*}"}"
  seg="${seg#\"}"; seg="${seg#\'}"
  printf '%s' "$seg" | /usr/bin/sed -E \
      -e 's/^[[:space:]]*//' \
      -e 's/^[A-Za-z_][A-Za-z0-9_-]*\(\)[[:space:]]*\{[[:space:]]*//' \
      -e 's/^(if|elif|while|until|then|do|else|!)[[:space:]]+//' \
      -e 's/^[[:space:]]*[({][[:space:]]*//' \
      -e 's/^(if|elif|while|until|then|do|!)[[:space:]]+//' \
      -e 's/^[[:space:]]*[({][[:space:]]*//' \
      -e 's/^[A-Za-z_][A-Za-z0-9_]*=//' \
      -e 's/^["'"'"']//' \
      -e 's/^[[:space:]]*//'
}

# ── 생산자 상한 판별 ──────────────────────────────────────────────────────────
# BOUNDED = 출력에 구조적 상한이 있다(한 줄짜리 · 명령치환 없는 리터럴 printf/echo).
# 🟥 `printf "$VAR"` 는 BOUNDED 가 아니다 — 실측 20/20. 명령치환이 있으면 무조건 UNBOUNDED.
_producer_class(){  # VULN | VAR-DEPENDENT | BOUNDED
  local seg; seg="$(_norm_seg "$1")"
  # here-string(`<<<"$var"`) 로 먹이는 생산자는 파일이 아니라 **변수** 크기에 묶인다.
  case "$seg" in *'<<<'*) echo VAR-DEPENDENT; return;; esac
  case "$seg" in
    printf*|echo*)
      # 🟥 printf 는 상한이 **아니다** — `printf '%s' "$BIG" | grep -q` 는 실측 20/20 뒤집힌다.
      #    그러나 위험은 «명령» 이 아니라 «인수» 에 달렸다. 정적으로는 못 정하므로 갈라 적는다.
      case "$seg" in *'$('*|*'`'*) echo VULN; return;; esac      # 명령 출력을 인라인 — 상한 미지
      case "$seg" in *'$'*) echo VAR-DEPENDENT; return;; esac    # 변수 크기에 달렸다(자료흐름)
      echo BOUNDED; return;;                                      # 순수 리터럴
    date*|uname*|id\ *|whoami*|hostname*|pwd*|basename*|dirname*) echo BOUNDED; return;;
    # `head -1 FILE | grep -q` 는 생산자가 이미 한 줄만 낸다 — 조기종료가 끊을 것이 없다.
    # ⚠️ 명시된 잔여: **한 줄이 64 KiB 를 넘으면** 이 면제가 틀린다(minified 한 줄 파일 등).
    #    `head -c` 와 상한 없는 `head` 는 면제하지 않는다 — 이 레포 픽스처가 `head -c 300000` 을 쓴다.
    head\ -[0-9]|head\ -[0-9]\ *|head\ -n\ [0-9]|head\ -n[0-9]|head\ -n\ [0-9]\ *|head\ -n[0-9]\ *)
      echo BOUNDED; return;;
    head\ -1*|head\ -2*|head\ -3*|head\ -5*) echo BOUNDED; return;;
    wc\ *|git\ rev-parse*|git\ symbolic-ref*|git\ config*)      echo BOUNDED; return;;
  esac
  # `<cmd> --version` 은 한 줄짜리다 — 명령 이름을 몰라도 상한을 안다.
  case "$seg" in *--version*|*-V\ *|*\ version) echo BOUNDED; return;; esac
  echo VULN
}

# ── 차폐(SHIELD) 판별 — 실측으로 확인된 구조적 안전판 ────────────────────────────
# 조기종료 소비자 **앞에** 「EOF 까지 읽고 출력이 상한 있는」 단계가 끼면 생산자는 안전하다.
# 실측 2026-09-21 (/bin/bash · 300 KB · 20 reps): `sed -n 1p` · `grep -c` · `tail -n 1` · `wc -l`
# 가 앞에 있으면 **0/20**. 🟥 컨트롤로 갈랐다 — 앞 단계가 **조기종료**형(`head -1` · `grep -m1`)
# 이면 차폐가 아니라 파손 지점이 왼쪽으로 옮겨갈 뿐이다(둘 다 **20/20**).
_shield_kind(){   # 비지 않은 문자열 = 차폐 단계
  local seg; seg="$(_norm_seg "$1")"
  case "$seg" in
    wc|wc\ *)                echo "wc";      return;;
    tail\ *|*/tail\ *)       echo "tail";    return;;
    sort\ *|sort)            echo "";        return;;   # sort 는 상한이 없다
    grep\ *|*/grep\ *|egrep\ *|fgrep\ *)
      # `grep -c` 는 EOF 까지 읽고 한 줄만 낸다. 단, q/m/l 이 섞이면 조기종료라 차폐가 아니다.
      case "$seg" in *-*c*) : ;; *) echo ""; return;; esac
      local w
      for w in $seg; do case "$w" in -[A-Za-z]*) case "$w" in *q*|*m*|*l*|*L*) echo ""; return;; esac;; esac; done
      echo "grep -c"; return;;
    sed\ *|*/sed\ *)
      # `sed -n 'Np'` 는 EOF 까지 읽고 출력이 상한이다. `q` 가 있으면 조기종료라 차폐가 아니다.
      case "$seg" in *q*) echo ""; return;; esac
      case "$seg" in *-n*) : ;; *) echo ""; return;; esac
      # 🟥 주소가 «순수 숫자» 일 때만 상한이 있다. `1,$p` 와 `/RE/,/RE/p` 는 상한이 없다 —
      #    이 구분이 없으면 #785 의 실제 결함(`sed -n '1,$p' FILE | grep -q`)이 차폐로 읽힌다.
      # 🟥 검사 대상은 **sed 스크립트 인수 한 토큰**이지 세그먼트 전체가 아니다. 전체를 보면
      #    `2>/dev/null` 의 `/` 가 정규식 주소로 읽혀 정상 차폐를 놓친다(실측 오탐 1건).
      local _sp
      _sp="$(printf '%s' "$seg" | /usr/bin/awk '
        { if (match($0, /"[^"]*"/))       { print substr($0,RSTART+1,RLENGTH-2); exit }
          if (match($0, /\047[^\047]*\047/)) { print substr($0,RSTART+1,RLENGTH-2); exit }
          print "" }')"
      # 주소를 못 떼어내면 **차폐로 인정하지 않는다** — 놓침(조용함)보다 과표기(시끄러움)를 고른다.
      [ -n "$_sp" ] || { echo ""; return; }
      # `_norm_seg` 가 `$((` 를 @@AR@@ 로 바꿔 두므로 그 형태로 지운다(산술은 상한이다).
      _sp="$(printf '%s' "$_sp" | /usr/bin/sed -e 's/@@AR@@[^)]*))/N/g' -e 's/\$((\([^)]*\)))/N/g')"
      case "$_sp" in *'$'*|*'/'*) echo ""; return;; esac
      echo "sed -n"; return;;
    awk\ *|*/awk\ *)
      case "$seg" in *exit*) echo ""; return;; esac
      case "$seg" in *END*) echo "awk END"; return;; esac
      echo ""; return;;
  esac
  echo ""
}

# ── D2 원점 전파 — 경계는 «파이프 직전» 이 아니라 «맨 왼쪽 원점» 이 정한다 ──────────
# `basename f | grep -oE … | head -1` 은 안전하다: 원점이 basename 이라 흐르는 바이트에 상한이 있다.
# 필터(grep/sed/awk/tr…)는 투명하다 — 자기가 파일을 열지 않으면 새 바이트를 만들지 않는다.
# 🟥 그래서 중간 단계가 **스스로 소스**(파일/ref/트리를 연다)면 그때만 원점 판정을 덮어쓴다.
_is_source(){       # 비지 않으면 이 세그먼트가 스스로 바이트를 만든다
  local seg; seg="$(_norm_seg "$1")"
  case "$seg" in
    cat\ *|*/cat\ *|git\ *|*/git\ *|find\ *|*/find\ *|ls\ *|ls|tar\ *|xargs\ *) echo src; return;;
    python3\ *|python\ *|bash\ *|sh\ *|perl\ *|node\ *|jq\ *) echo src; return;;
  esac
  echo ""
}

# ── D3 rc 마스킹 — `|| true` 는 이 결함을 가리지만 그 자체가 별건이다 ──────────────
# `[[feedback_pipefail_fallback_disarms_guard]]` 가 이미 이름 붙인 결함이라, 여기서 VULN 으로
# 세면 두 결함이 한 숫자에 섞인다. 조용히 빼지 않고 **자기 클래스로** 센다.
_rc_masked(){
  case "$1" in *'|| true'*|*'|| :'*|*'||true'*|*'|| echo'*) echo masked;; *) echo "";; esac
}

# ── rc 소비 여부 — 이 결함이 «보이는» 자리 ────────────────────────────────────
_rc_context(){      # COND | GUARD | SET-E | ASSIGN
  local line="$1" sete="$2"
  case "$line" in
    if\ *|elif\ *|while\ *|until\ *|!\ *|*\;\ if\ *|*\&\&\ if\ *) echo COND; return;;
  esac
  case "$line" in *'&&'*|*'||'*) echo GUARD; return;; esac
  [ "$sete" = 1 ] && { echo SET-E; return; }
  echo ASSIGN
}

# ── 한 파일 스캔 ──────────────────────────────────────────────────────────────
scan_file(){
  local f="$1" rel="${1#$REPO/}"
  # 🟥 pipefail·set -e 판정도 **heredoc 본문을 빼고** 봐야 한다 — 픽스처 안의 `set -e` 가
  #    숙주 스크립트를 SET-E 로 오표기했다(실측 1건, test_degrade_scan_shell_probes.sh).
  #    그래서 논리행 스트림을 **한 번** 만들고 세 판정 모두 그것을 읽는다.
  local LOGICAL; LOGICAL="$(_logical_lines "$f")"
  printf '%s' "$LOGICAL" | /usr/bin/grep -qE 'set[[:space:]]+[-+][A-Za-z]*o[[:space:]]+pipefail' || return 0
  local sete=0
  printf '%s' "$LOGICAL" | /usr/bin/grep -qE '(^|\t)[[:space:]]*set[[:space:]]+-[A-Za-z]*e[A-Za-z]*([[:space:]]|$)' && sete=1

  printf '%s\n' "$LOGICAL" | while IFS=$'\t' read -r lno logical; do
      case "$logical" in *'|'*) ;; *) continue;; esac
      # 인용부호·`${}` 안의 `|` 를 먼저 가린다(위 주석) — 그 다음에야 파이프를 센다.
      local masked; masked="$(printf '%s' "$logical" | _mask_nonops)"
      case "$masked" in *'|'*) ;; *) continue;; esac
      # `||` 는 파이프가 아니다 → 치환해 보호한다.
      local guarded="${masked//\|\|/@@OR@@}"
      case "$guarded" in *'|'*) ;; *) continue;; esac
      local IFSOLD="$IFS"; local -a segs=(); IFS='|'; read -r -a segs <<<"$guarded"; IFS="$IFSOLD"
      [ "${#segs[@]}" -ge 2 ] || continue
      local i ck="" cidx=0
      for ((i=1;i<${#segs[@]};i++)); do
        ck="$(_consumer_kind "${segs[$i]//@@OR@@/||}")"
        [ -n "$ck" ] && { cidx=$i; break; }
      done
      [ -n "$ck" ] || continue
      # 조기종료 소비자 **앞** 단계 중에 차폐가 있으면 생산자는 안전하다(실측 근거는 위 주석).
      local sh=""
      for ((i=0;i<cidx;i++)); do
        sh="$(_shield_kind "${segs[$i]//@@OR@@/||}")"
        [ -n "$sh" ] && break
      done
      # 생산자 판정 = 원점(segs[0]) + 중간 소스 escalation
      local pc; pc="$(_producer_class "${segs[0]//@@OR@@/||}")"
      # 🟥 «원점이 보호됨» 은 **라벨이지 면제가 아니다.** 조기종료 소비자 앞에 EOF 까지 읽는
      #    단계(`grep -n` · `awk …exit` 등)가 있으면 *원점* 은 SIGPIPE 를 안 받는다. 그러나 그
      #    중간 단계 **자신의** 출력량은 정적으로 모른다(매치가 많으면 여전히 64 KiB 를 넘는다).
      #    ⇒ 차폐로 빼지 않는다. 놓침은 조용하고 과표기는 시끄러우니 시끄러운 쪽을 고른다.
      #    실측 근거: 손검증 11건 중 3건이 이 형태였다(chamber_run.sh:114 · sync_to_be_lanes.sh:571
      #    · test_verdict_watermark_lanes.sh:404) — 전부 실위험은 낮고 형태는 맞다.
      local originprot=""
      if [ "$cidx" -gt 1 ]; then originprot="/origin-protected"; fi
      for ((i=1;i<cidx;i++)); do
        [ -n "$(_is_source "${segs[$i]//@@OR@@/||}")" ] && { pc=VULN; break; }
      done
      local rc;  rc="$(_rc_context "$logical" "$sete")"
      local verdict="$pc"
      [ -n "$sh" ] && { verdict="SHIELDED"; pc="$pc/shield:$sh"; }
      [ "$verdict" = VULN ] && pc="$pc$originprot"
      [ -n "$(_rc_masked "$logical")" ] && verdict="MASKED"
      # 🟥 «의도된 취약형» 프라그마 (2026-09-21, 거버너 결정). 레인 픽스처는 취약형을 **일부러**
      #    인라인으로 들고 있는데(#785 의 known-positive·과차단 컨트롤이 그렇다), 지어낸 것과
      #    진짜는 **바이트가 같다** — 스캐너가 구조적으로 못 가른다. 그래서 저자가 같은 줄에
      #    이름을 달아야만 면제한다.
      #    🟥 **사유 없는 프라그마는 면제가 아니다**(VULN 그대로). 이유: 다음 저자가 그 줄을
      #    복붙으로 옮길 때 사유가 같이 안 따라가면 그건 기록이 아니라 통과 티켓이다 —
      #    `portability-noqa: <사유>` 와 같은 경계이고, 같은 이유로 **비공허성만** 본다(그 사유가
      #    참인지는 안 본다. §Mechanization Boundary — 채널이지 결론이 아니다).
      case "$logical" in
        *'# pipefail-intentional:'*)
          local _pr _prw
          _pr="${logical##*# pipefail-intentional:}"
          _prw="$(printf '%s' "$_pr" | wc -w | tr -d ' ')"
          if [ "${_prw:-0}" -ge 2 ]; then verdict="INTENTIONAL"; fi ;;
      esac
      printf '%s\t%s:%s\t%s\t%s\t%s\t%s\n' "$verdict" "$rel" "$lno" "$pc" "$ck" "$rc" \
        "$(printf '%s' "$logical" | cut -c1-150)"
    done
}

# ── 자가 교정: known-pair 를 같은 실행에서 통과해야 이 스캔의 0 이 의미가 있다 ──
FIXD=""
selftest(){
  FIXD="$(mktemp -d)"
  # known-POSITIVE — «뚫리는 표기» 로 짓는다. 가장 쉬운 표기만 잡는 스캐너는 나머지를 못 잡는다.
  # V1 직접  V2 중간필터  V3 함수 생산자(#785 자신의 스캔이 놓친 형태)  V4 번들플래그
  # V5 행끝 파이프 줄바꿈  V6 백슬래시 연속  V7 head  V8 sed q  V9 awk exit  V10 printf+명령치환
  # V11 파이프가 **`$( )` 안**에 있고 그 전체가 `"…"` 로 감싸인 형태 — `x="$(ls … | head -1)"`.
  #     🟥 이 변종은 L7 되돌림 프로브가 **없다고 지적해서** 추가됐다: V10 은 파이프가 `$( )`
  #     *밖*에 있어서, `$(` 인용문맥 리셋을 죽여도 적발이 안 떨어졌다(10/10 유지). 즉 그 코드가
  #     하중을 지는데 known-pair 가 그걸 못 재고 있었다. 실제 자리 = compaction_probe.sh:139.
  cat > "$FIXD/pos.sh" <<'POS'
#!/usr/bin/env bash
set -uo pipefail
_src(){ sed -n '1,$p' "$1"; }
if sed -n '1,$p' big.txt | grep -q NEEDLE; then :; fi
if cat big.txt | tr 'a' 'b' | grep -q NEEDLE; then :; fi
if _src big.txt | grep -q NEEDLE; then :; fi
if git show HEAD:x | grep -Eq 'NEE(DLE)'; then :; fi
if cat big.txt |
   grep -q NEEDLE; then :; fi
if cat big.txt \
   | grep -q NEEDLE; then :; fi
if find . -type f | head -1; then :; fi
if cat big.txt | sed 1q; then :; fi
if cat big.txt | awk '/NEEDLE/{exit}'; then :; fi
if printf '%s' "$(cat big.txt)" | grep -q NEEDLE; then :; fi
V11="$(ls /tmp/* 2>/dev/null | head -1)"
POS
  # known-NEGATIVE — 안전한 형태에서 **안 짖는지**.
  # N1 파일 직접(수리형)  N2 grep -c  N3 sed -n Np  N4 리터럴 printf  N5 pipefail 없는 파일
  cat > "$FIXD/neg.sh" <<'NEG'
#!/usr/bin/env bash
set -uo pipefail
if grep -q NEEDLE big.txt; then :; fi
if [ "$(cat big.txt | grep -c NEEDLE)" -ge 1 ]; then :; fi
if cat big.txt | sed -n '1p' | read -r _x; then :; fi
if printf '%s\n' "literal text here" | grep -q lit; then :; fi
if echo "one two" | grep -q two; then :; fi
NEG
  cat > "$FIXD/nopipefail.sh" <<'NPF'
#!/usr/bin/env bash
set -u
if cat big.txt | grep -q NEEDLE; then :; fi
NPF
  local pos neg npf
  pos=$(scan_file "$FIXD/pos.sh" | /usr/bin/grep -c '^VULN' || true)
  neg=$(scan_file "$FIXD/neg.sh" | /usr/bin/grep -c '^VULN' || true)
  npf=$(scan_file "$FIXD/nopipefail.sh" | /usr/bin/grep -c '^VULN' || true)
  printf 'KNOWN-POSITIVE\t%s/11 caught\n'  "${pos:-0}"
  printf 'KNOWN-NEGATIVE\t%s false positives (must be 0)\n' "${neg:-0}"
  printf 'NO-PIPEFAIL\t%s (control: must be 0 — pipefail is a precondition)\n' "${npf:-0}"
  # 어느 known-positive 가 안 잡혔는지 이름으로 — 「10중 8」을 침묵으로 두지 않는다
  if [ "${pos:-0}" -lt 11 ]; then
    echo "-- caught: --"; scan_file "$FIXD/pos.sh" | /usr/bin/awk -F'\t' '{print "   "$2"\t"$3"\t"$4}'
  fi
  if [ "${neg:-0}" -ne 0 ]; then
    echo "-- FALSE POSITIVES: --"; scan_file "$FIXD/neg.sh" | /usr/bin/grep '^VULN' | /usr/bin/sed 's/^/   /'
  fi
  /bin/rm -rf "$FIXD"
  [ "${pos:-0}" -eq 11 ] && [ "${neg:-0}" -eq 0 ] && [ "${npf:-0}" -eq 0 ]
}

collect(){
  local f
  { ls "$REPO"/scripts/*.sh 2>/dev/null
    ls "$REPO"/templates/.git-hooks/* 2>/dev/null
    find "$REPO"/plugins -type f \( -name '*.sh' -o -name '*.bash' \) 2>/dev/null
  } | sort -u | while read -r f; do [ -r "$f" ] || continue; scan_file "$f"; done
}

case "$MODE" in
  # 🟥 별칭이 없으면 `--self-test` 가 case 에 안 걸려 **기본 `report` 로 떨어지고**, report 는
  #    VULN>0 이면 rc=1 이라 «known-pair 실패» 로 오독된다. 실제로 CI 에서 그렇게 빨갰다
  #    (2026-09-21). 레포 관례가 `--self-test`(gate_shape_scan 은 `--selftest`)라 셋 다 받는다.
  selftest|--self-test|--selftest) selftest; exit $?;;
  list)     [ -n "$ONLY" ] && scan_file "$ONLY" || collect; exit 0;;
  changed)
    # ── 델타 잠금 — 🟥 이것이 «0 곳인가» 가 실제로 걸리는 자리다 ──────────────────────
    # 레포 전체는 오늘 VULN>0 이므로 «전체 0» 을 게이트로 걸면 만족 불가능한 요구가 되고,
    # 그건 override 를 훈련시킨다(CLAUDE.md §Mechanization Boundary). 대신 **이 변경이
    # 새 사례를 들여오는가** 를 0 으로 잠근다 — 목록이 아니라 0 이고, 기존 부채와 무관하게 산다.
    if ! selftest >/dev/null 2>&1; then
      echo "🟥 INSTRUMENT ERROR — known-pair 실패. 델타 판정을 내지 않는다." >&2; exit 2
    fi
    BASE="${ONLY:-}"
    if [ -z "$BASE" ]; then
      BASE="$(git -C "$REPO" merge-base HEAD origin/main 2>/dev/null \
              || git -C "$REPO" rev-parse HEAD 2>/dev/null)" || BASE=""
    fi
    [ -n "$BASE" ] || { echo "🟥 INSTRUMENT ERROR — base 를 못 정했다" >&2; exit 2; }
    CH="$(git -C "$REPO" diff --name-only "$BASE" -- 'scripts/*.sh' 'templates/.git-hooks/*' 'plugins/**' 2>/dev/null; \
          git -C "$REPO" diff --cached --name-only -- 'scripts/*.sh' 'templates/.git-hooks/*' 'plugins/**' 2>/dev/null)"
    CH="$(printf '%s\n' "$CH" | /usr/bin/grep -v '^$' | sort -u || true)"
    if [ -z "$CH" ]; then echo "── 델타 잠금: 대상 파일 변경 없음 (SKIP) ──"; exit 0; fi
    NEW=0
    while read -r rel; do
      [ -n "$rel" ] || continue
      [ -r "$REPO/$rel" ] || continue
      # 기준 리비전의 같은 파일에 있던 VULN 줄(원문 기준)과 대조 — 줄번호가 아니라 **원문**으로
      # 비교한다. 줄이 밀렸다고 새 결함으로 읽으면 리팩터가 게이트에 걸린다.
      OLDF="$(mktemp)"; git -C "$REPO" show "$BASE:$rel" > "$OLDF" 2>/dev/null || : > "$OLDF"
      OLDV="$(PIPESCAN_REPO="$REPO" scan_file "$OLDF" | /usr/bin/awk -F'\t' '$1=="VULN"{print $6}' | sort -u)"
      NEWV="$(scan_file "$REPO/$rel" | /usr/bin/awk -F'\t' '$1=="VULN"{print $6}' | sort -u)"
      /bin/rm -f "$OLDF"
      # 🟥 초판은 `… || printf '%s\n' "$NEWV"` 를 폴백으로 달았다. `grep -v` 는 **아무 줄도 안
      #    남으면 rc=1** 이라, 「새 취약형 0 곳」이라는 **정답 상황에서 폴백이 발동해 기존 전부를
      #    «새로 들여왔다» 로 보고**했다. 잠금이 정확히 통과해야 할 때 짖는 형태다
      #    (`[[feedback_pipefail_fallback_disarms_guard]]` 의 거울상 — 거기선 폴백이 가드를 껐고
      #    여기선 폴백이 가드를 헛짖게 했다). 첫 실사용에서 바로 드러났다(2026-09-21).
      #    ⇒ rc 를 **구분해서** 받는다: 0=새것 있음 · 1=새것 없음 · 그 외=계기 오류(진짜 멈춤).
      OLDLIST="$(mktemp)"; { printf '%s\n' "$OLDV"; echo '@@NONE@@'; } > "$OLDLIST"
      ADD="$(printf '%s\n' "$NEWV" | /usr/bin/grep -vxF -f "$OLDLIST")"; _agrc=$?
      /bin/rm -f "$OLDLIST"
      case "$_agrc" in
        0|1) ;;
        *) echo "🟥 INSTRUMENT ERROR — 신·구 대조 실패 (grep rc=$_agrc). 델타 판정을 내지 않는다." >&2
           exit 2 ;;
      esac
      ADD="$(printf '%s\n' "$ADD" | /usr/bin/grep -v '^$' || true)"
      if [ -n "$ADD" ]; then
        NEW=$((NEW+1))
        echo "  🟥 $rel — 이 변경이 새 취약형을 들여왔다:"
        printf '%s\n' "$ADD" | /usr/bin/sed 's/^/       · /' | cut -c1-140
      fi
    done <<< "$CH"
    if [ "$NEW" -eq 0 ]; then echo "── 델타 잠금: 새 취약형 0 곳 ✅ ──"; exit 0; fi
    cat <<'HOWTO'

  수리 방향 (하나 고르고, `|| true` 는 쓰지 마라 — grep 의 에러 2 와 무매치 1 을 한 값으로 접는다):
    · 파일을 직접 줘라        grep -q PAT FILE            ← #785 이 쓴 수리
    · 끝까지 읽는 소비자      cmd | grep -c PAT           + [ "$n" -ge 1 ]
    · 상한을 앞에 둬라        cmd | sed -n '1,50p' | grep -q PAT
HOWTO
    exit 1;;
esac

if ! selftest; then
  echo "🟥 INSTRUMENT ERROR — known-pair 를 통과하지 못했다. 이 스캔의 0 은 무의미하다." >&2
  exit 2
fi
echo "── pipefail × 조기종료 소비자 전수 ──"
ALL="$(collect)"
_c(){ printf '%s\n' "$ALL" | /usr/bin/grep -c "^$1" || true; }
NV=$(_c VULN); NVD=$(_c VAR-DEPENDENT); NB=$(_c BOUNDED); NS=$(_c SHIELDED); NM=$(_c MASKED)
printf '🔒 잠금 대상  VULN          = %s   (외부 생산자 — 파일/ref/트리/함수. 상한이 구조적으로 없다)\n' "${NV:-0}"
printf '⚠️  자료흐름   VAR-DEPENDENT = %s   (printf/echo "$VAR" — 실측 20/20 뒤집힌다. 변수 크기에 달려 정적 미결정)\n' "${NVD:-0}"
printf 'ℹ️  대상 아님  BOUNDED       = %s   (순수 리터럴 · 한 줄 출력 명령)\n' "${NB:-0}"
printf 'ℹ️  대상 아님  SHIELDED      = %s   (앞 단계가 EOF 까지 읽는다 — 실측 0/20)\n' "${NS:-0}"
printf '🟡 별건       MASKED        = %s   (`|| true` 가 rc 를 먹는다 — 이 결함은 안 보이지만 그 자체가 별 결함)\n' "${NM:-0}"
if [ "${NV:-0}" -gt 0 ]; then
  echo
  echo "VULN 목록 (file:line / 소비자 / rc-맥락 / 원문):"
  printf '%s\n' "$ALL" | /usr/bin/grep '^VULN' \
    | /usr/bin/awk -F'\t' '{printf "  · %-50s %-11s %-6s %s\n", $2, $4, $5, substr($6,1,86)}'
  exit 1
fi
exit 0

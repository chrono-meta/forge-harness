#!/usr/bin/env bash
# channel_inventory.sh — «부재» 를 주장하기 전에 **채널을 센다**.
#
# ## 왜 있나 (2026-09-13 실측, 하루 세 번)
#
# 산출 디렉터리에서 「X 가 없다」를 판정할 때, 나는 **내가 연 채널에 없는 것**을 «기록이 없다» 로
# 단정했다. 실제 기록은 **열지 않은 세 번째 채널**에 타입된 값으로 있었다:
#
#     confirmed.jsonl  0줄    ← 열었다
#     dropped.jsonl    0줄    ← 열었다
#     pipeline.log            ← 🟥 안 열었다. 여기에 status=UNREVIEWED 가 있었다
#
# 이 도구는 판정을 대신하지 않는다. **디렉터리가 실제로 가진 채널을 전부 세고, 네가 읽었다고
# 선언한 것과 대조해 «안 연 것» 을 이름으로 돌려준다.**
#
# 🟥 그리고 «있는데 비어 있음» 과 «아예 없음» 을 **갈라서** 센다 — 그 둘을 섞는 것이
#    `not found ≠ 0` 가족의 본체다.
#
# 사용:
#   bash scripts/channel_inventory.sh <디렉터리>
#   bash scripts/channel_inventory.sh <디렉터리> --read confirmed.jsonl,dropped.jsonl
#       → 안 연 채널을 나열하고, 하나라도 있으면 **rc=1** (부재 주장을 막는 방향)
#
# 종료코드: 0 전부 열었음(또는 --read 없이 열거만) · 1 안 연 채널이 있다 · 2 디렉터리 부재(계기 오류)
set -uo pipefail

DIR="${1:-}"
[ -n "$DIR" ] || { echo "usage: channel_inventory.sh <dir> [--read a,b,c]" >&2; exit 2; }
[ -d "$DIR" ] || { echo "🟥 디렉터리 없음: $DIR — 계기 오류(부재 판정 아님)" >&2; exit 2; }

READ_CSV=""
if [ "${2:-}" = "--read" ]; then READ_CSV="${3:-}"; fi

# 채널 = 파일 «종류». id·날짜·연번을 지워 같은 종류를 한 줄로 모은다.
norm(){ basename "$1" | sed -E 's/[0-9]{6,}/<N>/g; s/[0-9]+/<n>/g'; }

declare -a KINDS=()
TMP=$(mktemp); trap 'rm -f "$TMP"' EXIT
while IFS= read -r f; do
  k=$(norm "$f")
  sz=$(wc -c < "$f" 2>/dev/null | tr -d ' ')
  printf '%s\t%s\n' "$k" "${sz:-0}" >> "$TMP"
done < <(find "$DIR" -maxdepth 2 -type f 2>/dev/null | sort)

[ -s "$TMP" ] || { echo "🟥 파일 0개 — 셀 채널이 없다(계기 오류)" >&2; exit 2; }

echo "== 채널 인벤토리: $DIR =="
printf '  %-34s %5s %7s %7s\n' "채널(종류)" "개수" "비었음" "총바이트"
awk -F'\t' '{c[$1]++; b[$1]+=$2; if($2==0) e[$1]++} END {for (k in c) printf "  %-34s %5d %7d %7d\n", k, c[k], e[k]+0, b[k]}' "$TMP" | sort

N_KIND=$(awk -F'\t' '{print $1}' "$TMP" | sort -u | wc -l | tr -d ' ')
echo "  ─────"
printf '  채널 종류 %s개 · 파일 %s개\n' "$N_KIND" "$(wc -l < "$TMP" | tr -d ' ')"
echo "  🟥 «있는데 비었음» 과 «아예 없음» 은 다른 것이다 — 위 표의 «비었음» 칸이 전자다."

[ -n "$READ_CSV" ] || exit 0

echo
echo "== 네가 읽었다고 선언한 채널과 대조 =="
UNREAD=0
while IFS= read -r k; do
  case ",$READ_CSV," in
    *",$k,"*) printf '  ✅ 읽음   %s\n' "$k" ;;
    *)        printf '  🟥 안 읽음 %s\n' "$k"; UNREAD=$((UNREAD+1)) ;;
  esac
done < <(awk -F'\t' '{print $1}' "$TMP" | sort -u)

echo "  ─────"
if [ "$UNREAD" -gt 0 ]; then
  printf '  🟥 안 연 채널 %s개. **여기서 «없다» 를 주장하지 마라** — 기록이 그중 하나에 있을 수 있다.\n' "$UNREAD"
  exit 1
fi
echo "  ✅ 모든 채널을 열었다. 이제 부재 주장이 채널 누락으로 뒤집히지 않는다."
exit 0

#!/usr/bin/env bash
# Lanes for templates/fh_audit_check.zsh — the terminal «Audit Reminders» banner.
#
# Usage: bash scripts/test_fh_audit_check_lanes.sh [NEW_SCRIPT] [ORIG_SCRIPT]
#   NEW_SCRIPT  default: templates/fh_audit_check.zsh (the script under test)
#   ORIG_SCRIPT optional: the pre-fix script. When given, every fail-before lane is run against it
#               and MUST emit the false line (proves the fixture reproduces the defect).
#
# Never touches the real HOME, ~/.cc_sentinels or ~/.zshrc: every run is `zsh -f` (no rc files)
# with a fake HOME and fixture dirs under mktemp.
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"
NEW="${1:-$REPO/templates/fh_audit_check.zsh}"
ORIG="${2:-}"
[ -f "$NEW" ] || { echo "HARNESS-ERROR: script under test not found: $NEW"; exit 3; }
command -v zsh >/dev/null 2>&1 || { echo "HARNESS-ERROR: zsh not installed"; exit 3; }

T="$(mktemp -d "${TMPDIR:-/tmp}/fhaudit.XXXXXX")" || exit 3
[ -n "$T" ] && [ -d "$T" ] || { echo "HARNESS-ERROR: mktemp"; exit 3; }
trap 'rm -rf "$T"' EXIT
PASS=0; FAIL=0

# N days ago as a touch -t stamp (BSD date first, GNU fallback — both checked for non-empty)
ago() { local s; s=$(date -v-"$1"d +%Y%m%d%H%M 2>/dev/null) || s=$(date -d "$1 days ago" +%Y%m%d%H%M 2>/dev/null); [ -n "$s" ] || { echo "HARNESS-ERROR: date"; exit 3; }; echo "$s"; }
mk() { mkdir -p "$(dirname "$1")"; : > "$1"; touch -t "$(ago "$2")" "$1"; }

# banner SCRIPT HUB SENT → stdout+stderr, ANSI stripped. FH_DIR=CC_HUB_DIR=HUB.
banner() {
  env -i PATH="$PATH" HOME="$T/fakehome" FH_DIR="$2" CC_HUB_DIR="$2" CC_SENTINELS_DIR="$3" \
    zsh -f -c 'source "$1"; _fh_audit_check' _ "$1" 2>&1 | sed $'s/\033\\[[0-9;]*m//g'
}
ok()  { PASS=$((PASS+1)); echo "  PASS $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL $1"; echo "$2" | sed 's/^/       | /'; }
has()   { local o; o=$(banner "$1" "$2" "$3"); if echo "$o" | grep -qF -- "$4"; then ok "$5"; else bad "$5 (expected: $4)" "$o"; fi; }
hasnt() { local o; o=$(banner "$1" "$2" "$3"); if echo "$o" | grep -qF -- "$4"; then bad "$5 (unexpected: $4)" "$o"; else ok "$5"; fi; }

# bannerk: same as banner but the caller shell has KSH_ARRAYS on (as a user's own zshrc might)
bannerk() {
  env -i PATH="$PATH" HOME="$T/fakehome" FH_DIR="$2" CC_HUB_DIR="$2" CC_SENTINELS_DIR="$3" \
    zsh -f -c 'setopt KSH_ARRAYS; source "$1"; _fh_audit_check' _ "$1" 2>&1 | sed $'s/\033\\[[0-9;]*m//g'
}
hasntk() { local o; o=$(bannerk "$1" "$2" "$3"); if echo "$o" | grep -qF -- "$4"; then bad "$5 (unexpected: $4)" "$o"; else ok "$5"; fi; }
hub() { local h="$T/$1"; mkdir -p "$h/tracks/_meta" "$h/tracks/_audit" "$h/knowledge/shared/harness-core"; mkdir -p "$T/$1.sent"; echo "$h"; }

# ── fixtures ────────────────────────────────────────────────────────────────
# F1: weekly audit 2d old, no harvest_* (the operator's real shape) — nothing is overdue
F1=$(hub f1); mk "$F1/tracks/_audit/weekly_audit_x.md" 2; mk "$F1/tracks/_meta/frontier_digest_x.md" 1; mk "$F1/tracks/_meta/sim_x_area_B.md" 3
# F2: weekly audit genuinely overdue (10d)
F2=$(hub f2); mk "$F2/tracks/_audit/weekly_audit_x.md" 10; mk "$F2/tracks/_meta/frontier_digest_x.md" 1; mk "$F2/tracks/_meta/sim_x_area_B.md" 3
# F3: no weekly audit at all
F3=$(hub f3); mk "$F3/tracks/_meta/frontier_digest_x.md" 1; mk "$F3/tracks/_meta/sim_x_area_B.md" 3
# F4: Area B 40d old but a recent area_D report (2d) — old glob resets the B clock
F4=$(hub f4); mk "$F4/tracks/_audit/weekly_audit_x.md" 1; mk "$F4/tracks/_meta/sim_x_area_B.md" 40; mk "$F4/tracks/_meta/sim_y_area_D_split.md" 2
# F5: Area B 116d (the operator's real shape — a TRUE alarm)
F5=$(hub f5); mk "$F5/tracks/_audit/weekly_audit_x.md" 1; mk "$F5/tracks/_meta/sim_x_area_BD.md" 116
# F6: sentinels — 4 state markers + 1 genuine custom audit sentinel, all past 90d
F6=$(hub f6); S6="$T/f6.sent"; mk "$F6/tracks/_audit/weekly_audit_x.md" 1; mk "$F6/tracks/_meta/sim_x_area_B.md" 3
mk "$S6/projA_mapping_skipped" 100; mk "$S6/projB_wizard_done" 121; mk "$S6/projC_wizard_declined" 100
mk "$S6/projD_wizard_reminder_muted" 100; mk "$S6/myproj_pfd" 100
# F7: empty sentinels dir (zsh unmatched-glob error class)
F7=$(hub f7); S7="$T/f7.sent"; mk "$F7/tracks/_audit/weekly_audit_x.md" 1; mk "$F7/tracks/_meta/sim_x_area_B.md" 3
# F8: frontier — only an old diagnosis file (100d), a fresh digest (1d)
F8=$(hub f8); mk "$F8/tracks/_audit/weekly_audit_x.md" 1; mk "$F8/tracks/_meta/sim_x_area_B.md" 3
mk "$F8/knowledge/shared/harness-core/harness_frontier_diagnosis_x.md" 100; mk "$F8/tracks/_meta/frontier_digest_x.md" 1
# F10: two weekly audits — newest 1d, older 17d. Under the caller's KSH_ARRAYS a `[1]` index picks the older
F10=$(hub f10); mk "$F10/tracks/_audit/weekly_audit_old.md" 17; mk "$F10/tracks/_audit/weekly_audit_new.md" 1; mk "$F10/tracks/_meta/frontier_digest_x.md" 1; mk "$F10/tracks/_meta/sim_x_area_B.md" 3
# F9: frontier digest genuinely overdue (10d)
F9=$(hub f9); mk "$F9/tracks/_audit/weekly_audit_x.md" 1; mk "$F9/tracks/_meta/sim_x_area_B.md" 3; mk "$F9/tracks/_meta/frontier_digest_x.md" 10

# ORIG aborts the whole function on ANY unmatched glob (zsh NOMATCH: `ls -t …diagnosis_*.md` and
# `for f in dir/*` on an empty dir) — so for a fail-before to test the line it names, the other
# globs must match. Seed a fresh (1d) diagnosis file and a fresh custom sentinel everywhere except F7.
for h in f1 f2 f3 f4 f5 f6 f8 f9; do
  [ "$h" = f8 ] || mk "$T/$h/knowledge/shared/harness-core/harness_frontier_diagnosis_seed.md" 1   # F8 keeps ONLY its 100d file
  mk "$T/$h.sent/fresh_pfd" 1
done
# control: fixture mtimes actually landed (a dead touch would make every «silent» lane vacuous)
c=$(( ( $(date +%s) - $(stat -c %Y "$S6/myproj_pfd" 2>/dev/null || stat -f %m "$S6/myproj_pfd") ) / 86400 ))
echo "control: myproj_pfd fixture age = ${c}d (expect 100)"
[ "$c" -ge 99 ] && [ "$c" -le 101 ] || { echo "HARNESS-ERROR: fixture mtime did not land"; exit 3; }

run_new() {
  local S="$1"
  echo "── ① weekly audit"
  hasnt "$S" "$F1" "$T/f1.sent" "harvest"               "L1  fresh weekly audit, no harvest_* → no harvest line"
  hasnt "$S" "$F1" "$T/f1.sent" "weekly_audit"          "L1b fresh weekly audit → no weekly line"
  has   "$S" "$F2" "$T/f2.sent" "weekly_audit 10d"      "L2  KP: weekly audit 10d → warns"
  has   "$S" "$F3" "$T/f3.sent" "No weekly audit history" "L3  KP: no weekly audit → warns (not-found ≠ zero)"
  echo "── ② frontier digest"
  hasnt "$S" "$F8" "$T/f8.sent" "frontier"              "L8  old diagnosis file, fresh digest → silent"
  has   "$S" "$F9" "$T/f9.sent" "frontier_digest 10d"   "L9  KP: digest 10d → warns"
  echo "── ③ sim Area B"
  has   "$S" "$F4" "$T/f4.sent" "FH internal sim 40d"   "L4  area_D run does not reset Area B clock"
  has   "$S" "$F5" "$T/f5.sent" "FH internal sim 116d"  "L5  KP: Area B 116d → warns (true alarm kept)"
  hasnt "$S" "$F1" "$T/f1.sent" "FH internal sim"       "L5b Area B 3d → silent"
  echo "── ④ sentinels"
  for m in projA_mapping_skipped projB_wizard_done projC_wizard_declined projD_wizard_reminder_muted; do
    hasnt "$S" "$F6" "$S6" "$m sentinel"                "L6  state marker $m not aged"
  done
  has   "$S" "$F6" "$S6" "myproj_pfd sentinel 100d"     "L6b KP: custom audit sentinel 100d → warns"
  hasnt "$S" "$F7" "$S7" "no matches found"             "L7  empty sentinels dir → no zsh glob error"
  hasntk "$S" "$F10" "$T/f10.sent" "weekly_audit"      "L10 caller KSH_ARRAYS does not flip newest→older (emulate -L zsh)"
}

echo "=== script under test: $NEW"
run_new "$NEW"

if [ -n "$ORIG" ]; then
  echo "=== fail-before against ORIG: $ORIG (each MUST reproduce the false/missed line)"
  has   "$ORIG" "$F1" "$T/f1.sent" "No harvest history found"     "FB① ORIG emits unsatisfiable harvest line on fresh hub"
  has   "$ORIG" "$F8" "$T/f8.sent" "frontier_diagnosis 100d"      "FB② ORIG ages a file /frontier-digest never writes"
  hasnt "$ORIG" "$F4" "$T/f4.sent" "FH internal sim"              "FB③ ORIG misses overdue Area B (area_D reset the clock)"
  has   "$ORIG" "$F6" "$S6" "projA_mapping_skipped sentinel"      "FB④ ORIG ages a state marker (mapping_skipped)"
  has   "$ORIG" "$F6" "$S6" "projB_wizard_done sentinel"          "FB④b ORIG ages a state marker (wizard_done)"
  has   "$ORIG" "$F7" "$S7" "no matches found"                    "FB⑤ ORIG raises zsh NOMATCH (empty sentinels dir / no diagnosis file) and aborts"
fi

# ── revert probes: undo ONE fix in a copy → apply-check → run the lane → must go RED → discard ──
echo "=== revert probes (each mutant must turn its lane red)"
probe() { # name sed-expr lane-fn
  local m="$T/mutant_$1.zsh"
  sed "$2" "$NEW" > "$m"
  if cmp -s "$m" "$NEW"; then bad "RP-$1 mutant did not apply (sed matched nothing) — HARNESS-ERROR" ""; return; fi
  local before=$FAIL; "$3" "$m" >/dev/null
  if [ "$FAIL" -gt "$before" ]; then FAIL=$before; ok "RP-$1 revert turns lane red"; else bad "RP-$1 revert stayed GREEN — lane is decorative" ""; fi
  rm -f "$m"
}
lane1() { hasnt "$1" "$F1" "$T/f1.sent" "weekly audit history" "L1-probe"; }
lane2() { hasnt "$1" "$F8" "$T/f8.sent" "frontier" "L8-probe"; has "$1" "$F9" "$T/f9.sent" "frontier_digest 10d" "L9-probe"; }
lane3() { has "$1" "$F4" "$T/f4.sent" "FH internal sim 40d" "L4-probe"; }
lane4() { hasnt "$1" "$F6" "$S6" "projA_mapping_skipped sentinel" "L6-probe"; }
probe weekly   's#tracks/_audit"/weekly_audit_\*\.md#tracks/_audit"/harvest_*.md#' lane1
probe frontier 's#tracks/_meta"/frontier_digest_\*\.md#knowledge/shared/harness-core"/harness_frontier_diagnosis_*.md#' lane2
probe sim      's#sim_\*_area_B\*\.md#sim_*.md#' lane3
probe sentinel '/\*_wizard_done|\*_mapping_skipped/d' lane4
lane5() { hasntk "$1" "$F10" "$T/f10.sent" "weekly_audit" "L10-probe"; }
probe emulate  '/^  emulate -L zsh$/d' lane5

echo "=== RESULT: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]

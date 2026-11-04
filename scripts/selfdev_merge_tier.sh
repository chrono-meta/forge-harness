#!/usr/bin/env bash
# selfdev_merge_tier.sh — may an unattended self-dev PR merge on its own, or does it wait for the
# operator? A CLASSIFIER OF THE CHANGED FILE LIST, not a judgment of the change.
#
# WHY (operator, 2026-11-04 — «가로 ㄱㄱ», CLAUDE.local.md §FH 자체개발 자율화): reversible changes
# (doc lines, new lanes) merge unattended once CI is green + 4-axis + cross-family; anything that
# touches a gate, a verdict enum or an irreversible path waits for the morning report. The split is
# decided HERE by path, mechanically, so the unattended session that wrote the change never grades
# its own merge (author ≠ judge — CLAUDE.md §Mechanization Boundary: a check asserts a property of
# the record, not a conclusion).
#
# ALLOW-LIST, NOT DENY-LIST. A path is AUTO-eligible only if it matches a class below; every other
# path — including any path nobody thought of yet — is HOLD. A deny-list would fail open on the
# first new file type; this fails closed.
#   AUTO-eligible (all must hold for EVERY changed path):
#     docs/**/*.md
#     knowledge/**/*.md            except knowledge/shared/rules/**  (relocated protocol rules)
#                                  except knowledge/shared/harness-core/*gate*.md · *irreversib*.md
#     plugins/*/skills/*/SKILL.md · SKILL_detail.md
#     CATALOG.md
#     scripts/test_*.sh            ADDED only (status A) — a new lane cannot change what ships;
#                                  an edited lane can silently weaken a gate, so M → HOLD
#   plus: total changed lines ≤ SELFDEV_MAX_LINES (default 300).
#   Everything else → HOLD: CLAUDE.md · AGENTS.md · .claude/** · templates/** (git hooks, field rules)
#   · scripts/** (other than an added lane) · .github/** · package.json · plugins/*/hooks/** · etc.
#
# 🟥 EMPTY INPUT IS NOT «ALL ALLOWED». `all()` over an empty set is true; an empty file list here
#    means the instrument did not see the change, so it is HARNESS-ERROR (rc 2), never AUTO.
#    (feedback_not_found_is_not_zero_family — 7th face, the empty set passing a universal check.)
#
# INPUT  one line per changed path: «<status>\t<path>\t<added>\t<deleted>»  (status A/M/D/R…)
#        from a file (--files <f>) or from a PR (--pr <n> [--repo owner/name], via gh).
# OUTPUT TIER=AUTO|HOLD|HARNESS-ERROR on the last line; one «reason:» line per HOLD path.
# RC     0 AUTO · 3 HOLD · 2 HARNESS-ERROR
#
# NAMED RESIDUALS: ⓐ a SKILL.md edit is reversible but changes behaviour — allowed on the operator's
# «문서 줄» wording; the 4-axis gate and cross-family review are what stand behind it, not this
# script. ⓑ CI-green and the cross-family marker are checked by the caller (selfdev_loop.sh), not
# here — this script sees paths only.

set -u
# the ceiling may be LOWERED by env, never raised, and a non-number is HARNESS-ERROR (codex R1 #6)
MAX_LINES="${SELFDEV_MAX_LINES:-300}"
case "$MAX_LINES" in ''|*[!0-9]*) echo "reason: SELFDEV_MAX_LINES=«$MAX_LINES» is not a number"; echo "TIER=HARNESS-ERROR"; exit 2 ;; esac
[ "${#MAX_LINES}" -gt 4 ] || [ "$((10#$MAX_LINES))" -gt 300 ] && MAX_LINES=300
MAX_LINES=$((10#$MAX_LINES))
FILES=""; PR=""; REPO="chrono-meta/forge-harness"
while [ $# -gt 0 ]; do
  case "$1" in
    --files) FILES="$2"; shift 2 ;;
    --pr) PR="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; echo "TIER=HARNESS-ERROR"; exit 2 ;;
  esac
done

TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT
if [ -n "$PR" ]; then
  if ! out="$(gh pr view "$PR" -R "$REPO" --json files \
        -q '.files[] | "\(.changeType)\t\(.path)\t\(.additions)\t\(.deletions)"' 2>&1)"; then
    echo "reason: gh pr view failed — $out"; echo "TIER=HARNESS-ERROR"; exit 2
  fi
  # gh changeType words → git status letters
  printf '%s\n' "$out" | sed -E 's/^ADDED\t/A\t/; s/^MODIFIED\t/M\t/; s/^DELETED\t/D\t/; s/^RENAMED\t/R\t/; s/^CHANGED\t/M\t/; s/^COPIED\t/C\t/' > "$TMP"
elif [ -n "$FILES" ] && [ -f "$FILES" ]; then
  cp "$FILES" "$TMP"
else
  echo "reason: no input (--files <existing file> or --pr <n>)"; echo "TIER=HARNESS-ERROR"; exit 2
fi

n=0; hold=0; total=0
while IFS=$'\t' read -r st path add del; do
  [ -z "${path:-}" ] && continue
  n=$((n+1))
  # bounded decimals only: a 19-digit count wraps the sum negative, «08» is octal to bash (codex R1 #9)
  case "${add:-x}${del:-x}" in *[!0-9]*) echo "reason: $path — line counts unreadable ($add/$del)"; hold=1; continue ;; esac
  if [ "${#add}" -gt 6 ] || [ "${#del}" -gt 6 ]; then echo "reason: $path — line count out of range ($add/$del)"; hold=1; continue; fi
  total=$((total + 10#$add + 10#$del))
  ok=0
  # a rename/copy is classified by its destination only, so a protected SOURCE path could leave the
  # tree unseen — every R/C is HOLD (codex R1 #4)
  case "$st" in R*|C*) echo "reason: $path — status $st (rename/copy: source path not classified)"; hold=1; continue ;; esac
  case "$path" in
    knowledge/shared/rules/*) ok=0 ;;
    knowledge/shared/harness-core/*gate*.md|knowledge/shared/harness-core/*irreversib*.md) ok=0 ;;
    docs/*.md|docs/*/*.md|docs/*/*/*.md) ok=1 ;;
    knowledge/*.md|knowledge/*/*.md|knowledge/*/*/*.md|knowledge/*/*/*/*.md) ok=1 ;;
    plugins/*/skills/*/SKILL.md|plugins/*/skills/*/SKILL_detail.md) ok=1 ;;
    CATALOG.md) ok=1 ;;
    scripts/test_*.sh) [ "$st" = "A" ] && ok=1 ;;
  esac
  if [ "$ok" -ne 1 ]; then
    hold=1
    if [ "${path#scripts/test_}" != "$path" ]; then
      echo "reason: $path — status $st (only an ADDED lane is auto-eligible; an edited lane can weaken a gate)"
    else
      echo "reason: $path — outside the auto-merge allow-list"
    fi
  fi
done < "$TMP"

if [ "$n" -eq 0 ]; then
  echo "reason: changed-file list is empty — the instrument saw no change, which is not «all allowed»"
  echo "TIER=HARNESS-ERROR"; exit 2
fi
if [ "$total" -gt "$MAX_LINES" ]; then
  echo "reason: $total changed lines > $MAX_LINES (SELFDEV_MAX_LINES)"; hold=1
fi
echo "files=$n lines=$total"
if [ "$hold" -eq 1 ]; then echo "TIER=HOLD"; exit 3; fi
echo "TIER=AUTO"; exit 0

#!/usr/bin/env zsh
# forge-harness — periodic audit reminder (zshrc hook template)
#
# Checks elapsed days for each audit item every time a terminal opens,
# and prints a warning if the threshold is exceeded.
#
# ── Installation ──────────────────────────────────────────
#
#   1. Set environment variables in .zshrc:
#
#      export FH_DIR="$HOME/path/to/forge-harness"         # required
#      export CC_HUB_DIR="$HOME/path/to/your-cc-hub"       # if you have a CC hub
#      export CC_SENTINELS_DIR="$HOME/.cc_sentinels"        # project sentinels (optional)
#
#   2. Load the function using one of:
#
#      a) source "$FH_DIR/templates/fh_audit_check.zsh"    # source file directly
#      b) Paste the contents of this file into .zshrc       # standalone
#
# ── Auto-run (opt-in) ─────────────────────────────────────
#
#   Default is manual run (call _fh_audit_check directly).
#   To auto-run on terminal start, add to .zshrc:
#
#      export FH_AUDIT_AUTO=1
#
# ── Sentinel-based project audits ─────────────────────────
#
#   Quarterly/monthly project audits are tracked via sentinel files.
#   After completing an audit, touch the sentinel to reset the warning.
#
#     mkdir -p ~/.cc_sentinels
#     touch ~/.cc_sentinels/my_project_pfd          # record audit completion
#     export CC_SENTINEL_MY_PROJECT_PFD_DAYS=90     # set 90-day threshold
#
# ──────────────────────────────────────────────────────────

# mtime lookup (macOS / Linux compatible) — **GNU-first, and the order is load-bearing**.
# This was BSD-first (`stat -f %m || stat -c %Y`) and that is silently wrong on GNU/Linux: `-f`
# there means `--file-system`, so on a regular file it exits 0 and prints a filesystem report
# instead of an epoch — the `||` fallback never runs and the caller gets a multi-line blob that
# compares as garbage. Fixed 2026-08-15 after the identical bug was measured in
# scripts/digest_landing_check.sh (macOS 10/10 PASS · ubuntu 1/10 FAIL). Every other _mtime helper
# in this repo is already GNU-first (scripts/sync-from-be.sh:116 · scripts/fh_session_load.sh:105
# carry the same warning); this template copy was the straggler, and it ships to field harnesses.
_fh_mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0; }

_fh_audit_check() {
  # The caller's zshrc must not leak options in: under KSH_ARRAYS `${arr[1]}` is the SECOND newest
  # file, so a current audit would read as overdue (cross-family codex, 2026-09-27). Local reset.
  emulate -L zsh
  local -a warns=()
  local now
  now=$(date +%s)

  # ① weekly_audit — 7-day threshold (when CC_HUB_DIR is set)
  #    🟥 This used to glob `tracks/_meta/harvest_*.md`, a filename NOTHING writes (harvest-loop's
  #    SKILL*.md writes skill_usage.md · edit_manifest.yaml · fh_signal_*, never harvest_*). So the
  #    «No harvest history» line was unsatisfiable: it fired on every terminal open for every user,
  #    forever (measured 2026-09-26 on a hub whose latest weekly audit was 2 days old). The artifact
  #    the canonical cadence table names (CLAUDE.md §Cadence Rules · install-wizard §Step1-Checks
  #    `weekly_audit latest`) is `tracks/_audit/weekly_audit_*.md` — check THAT.
  #    Guard stays on the dir existing (`tracks/_audit/.gitkeep` ships in every clone), so a
  #    missing history still warns: not-found is not zero.
  if [[ -n "${CC_HUB_DIR}" && -d "${CC_HUB_DIR}/tracks/_audit" ]]; then
    local aud
    # zsh: an unmatched glob is a SHELL error raised before `ls` runs — the `2>/dev/null` belongs to
    # ls, so `_fh_audit_check:N: no matches found: …` printed on every terminal open of a hub with no
    # harvest files (measured 2026-09-04). 🟥 The obvious fix — appending `(N)` to the ls argument —
    # is WRONG and was measured wrong the same day: the null glob drops the word entirely, `ls -t`
    # then lists the CURRENT DIRECTORY, `head -1` returns an unrelated file, and the «No harvest
    # history» warning silently disappears (not-found rendered as found). Collect into an array with
    # `(N.om)` (null-glob · plain files · newest-first) and read element 1 — empty array ⇒ empty aud.
    local -a _fh_audits
    _fh_audits=( "${CC_HUB_DIR}/tracks/_audit"/weekly_audit_*.md(N.om) )
    aud="${_fh_audits[1]:-}"
    if [[ -n "$aud" ]]; then
      local d=$(( (now - $(_fh_mtime "$aud")) / 86400 ))
      (( d >= 7 )) && warns+=("weekly_audit ${d}d elapsed → run the weekly audit (/harvest-loop lightweight) in your CC hub cwd")
    else
      warns+=("No weekly audit history (tracks/_audit/weekly_audit_*.md) → run the weekly audit (/harvest-loop lightweight) in your CC hub cwd")
    fi
  fi

  # ② frontier_digest — 7-day threshold (when CC_HUB_DIR is set)
  #    🟥 Same defect class as ①: this globbed `knowledge/shared/harness-core/harness_frontier_
  #    diagnosis_*.md` at 90d and told you to «run /frontier-digest» — but /frontier-digest writes
  #    `tracks/_meta/frontier_digest_*.md` (frontier-digest SKILL.md --save), never the diagnosis
  #    file. Running the advised command could not reset the clock, and the diagnosis file's mtime
  #    moves on unrelated edits. Aligned to CLAUDE.md §Cadence Rules (7d on frontier_digest_*.md).
  #    Absent history stays silent, as before (not every install runs digests).
  if [[ -n "${CC_HUB_DIR}" && -d "${CC_HUB_DIR}/tracks/_meta" ]]; then
    local -a _fh_digests
    _fh_digests=( "${CC_HUB_DIR}/tracks/_meta"/frontier_digest_*.md(N.om) )
    local fd="${_fh_digests[1]:-}"
    if [[ -n "$fd" ]]; then
      local d=$(( (now - $(_fh_mtime "$fd")) / 86400 ))
      (( d >= 7 )) && warns+=("frontier_digest ${d}d elapsed → run /frontier-digest --save in your CC hub cwd")
    fi
  fi

  # ③ FH sim Area B — 30-day threshold (when FH_DIR is set)
  #    30d is a monthly-target reminder, not an enforced maximum interval. It runs manually or
  #    with FH_AUDIT_AUTO=1 and sees only reports in $FH_DIR/tracks/_meta. The skill's executor-applied
  #    7-day re-run guard may inspect a different REPORT_DIR; their clocks agree only if paths agree.
  #    Source of the cadence: sim-conductor SKILL_detail §AreaB-Baseline («Area B once/month»); the
  #    report name is the skill's own `sim_*_area_B*.md` (its frequency-check bash globs exactly that).
  #    🟥 The glob used to be `sim_*.md`, which also matched non-B reports (e.g. `sim_…_area_D_…`) and
  #    would silently reset the Area B clock on a D-only run — a false-negative. Narrowed to the
  #    skill's own pattern. (Measured-loop sims from sim_isolated_run.sh are NOT Area B runs and are
  #    deliberately not counted.)
  if [[ -n "${FH_DIR}" && -d "${FH_DIR}/tracks/_meta" ]]; then
    local -a _fh_sims
    _fh_sims=( "${FH_DIR}/tracks/_meta"/sim_*_area_B*.md(N.om) )
    local sim="${_fh_sims[1]:-}"
    if [[ -n "$sim" ]]; then
      local d=$(( (now - $(_fh_mtime "$sim")) / 86400 ))
      (( d >= 30 )) && warns+=("FH internal sim ${d}d elapsed → run /sim-conductor Area B in your FH cwd")
    fi
  fi

  # ④ Custom sentinels — per-file threshold in CC_SENTINELS_DIR (optional)
  #    Uppercase filename = env var key: CC_SENTINEL_{NAME}_DAYS (default 90)
  #    🟥 The same directory also holds STATE markers written by install-wizard and
  #    scripts/fh_env_delta_scan.sh — `*_wizard_done` · `*_mapping_skipped` · `*_wizard_declined` ·
  #    `*_wizard_reminder_muted`. They record that something happened, not when an audit is due; aging
  #    them as 90-day clocks produced false lines (and «touch … to reset» would falsify a state
  #    record). They are skipped by suffix. Any other file is still a custom audit sentinel.
  if [[ -n "${CC_SENTINELS_DIR}" && -d "${CC_SENTINELS_DIR}" ]]; then
    for f in "${CC_SENTINELS_DIR}"/*(N); do
      [[ -f "$f" ]] || continue
      case "${f:t}" in
        *_wizard_done|*_mapping_skipped|*_wizard_declined|*_wizard_reminder_muted) continue ;;
      esac
      local name="${${f:t}:u}"
      local key="CC_SENTINEL_${name}_DAYS"
      local threshold="${(P)key:-90}"
      local d=$(( (now - $(_fh_mtime "$f")) / 86400 ))
      (( d >= threshold )) && warns+=("${f:t} sentinel ${d}d elapsed → touch ${f} to reset")
    done
  fi

  # Output
  (( ${#warns[@]} == 0 )) && return
  print ""
  print "\033[33m── forge-harness Audit Reminders ────────────────────────\033[0m"
  for w in "${warns[@]}"; do
    print "\033[33m  ⚠  ${w}\033[0m"
  done
  print "\033[33m────────────────────────────────────────────────────────\033[0m"
  print ""
}
[[ "${FH_AUDIT_AUTO:-0}" == "1" ]] && _fh_audit_check

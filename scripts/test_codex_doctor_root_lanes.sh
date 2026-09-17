#!/usr/bin/env bash
# test_codex_doctor_root_lanes.sh — regression lanes for bin/fh-codex-doctor.js's ROOT PREDICATE.
#
# WHY THIS FILE EXISTS (measured 2026-09-17): the doctor required `package.json` at the root — in
# `looksLikeFHRoot()` and again as a hard `process.exit(11)` gate in `main()`. Those were the only
# two references to it in the whole file; nothing downstream ever OPENED it. So the gate asserted a
# property no consumer of the report consumes, and it made a shipped npm binary structurally
# unusable for every non-npm consumer harness. Live repro before the fix:
#     node bin/fh-codex-doctor.js --root <a consumer harness checkout> --strict
#     → rc=11  "ERROR: root does not look like a package/repo root"
# while that consumer carries every surface the tool actually audits (AGENTS.md with 3 tier rows,
# plugins/ with 41 SKILL.md, 8 agent .md, .claude/registry/agent_cards.json — counts hand-verified
# with `find`, not inferred). After the fix that same command returns rc=0 with 41 skills / 8 agents.
#
# 🟥 THE LANE'S JOB IS BOTH DIRECTIONS. Loosening a fail-closed gate is only correct if the
# loosening cannot manufacture a confident empty report — "not found is not zero" is this repo's
# named failure family. So every POSITIVE arm below is paired with a NEGATIVE arm on the same axis,
# and two of the negatives (L4, L6) are arms that the UNFIXED code passed with rc=0.
#
# FAIL-BEFORE: the subject is injectable, so the whole suite can be run against the pre-fix file.
#     FH_CODEX_DOCTOR=/path/to/fh-codex-doctor.ORIG.js bash scripts/test_codex_doctor_root_lanes.sh
# A lane suite that is green both ways is decorative.
#
# Usage:  bash scripts/test_codex_doctor_root_lanes.sh
# Exit:   0 = all lanes pass; 1 = at least one lane failed (prints which and why).

set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/fixture_guard_lib.sh"   # 픽스처는 실레포에 쓰지 않는다

FH_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCTOR="${FH_CODEX_DOCTOR:-$FH_REPO/bin/fh-codex-doctor.js}"
TMP="$(fh_fixture_root "$(mktemp -d)")"
: "${TMP:?fixture root unset — refusing to write fixtures in cwd}"
trap 'rm -rf "$TMP"' EXIT

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ✅ %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  ❌ %s\n     got: %s\n' "$1" "$(printf '%s' "$2" | tr '\n' '|' | cut -c1-260)"; }

if [ ! -f "$DOCTOR" ]; then
  bad "subject missing: $DOCTOR (HARNESS-ERROR — nothing below was measured)" "absent"
  printf '\ncodex-doctor root lanes: %d passed, %d failed\n' "$PASS" "$FAIL"; exit 1
fi
command -v node >/dev/null 2>&1 || {
  bad "node unavailable (HARNESS-ERROR — SKIP is not PASS, so this is a failure)" "no node"
  printf '\ncodex-doctor root lanes: %d passed, %d failed\n' "$PASS" "$FAIL"; exit 1
}

# run <root> → sets RC (exit code) and OUT (stdout+stderr).
# 🟥 NOT `out="$(run x)"`. Command substitution runs the function in a SUBSHELL, so an `RC=$?`
# assigned inside it is discarded and the caller keeps its stale RC — the first draft of this file
# did exactly that and four negative arms reported `rc=0` while node had actually exited 11,
# i.e. the lanes were grading a value the instrument never produced
# ([[feedback_broken_parser_reports_a_verdict]]). Redirect to a file and keep both in THIS shell.
RC=0
OUT=''
_RUN_OUT="$TMP/.lastrun"
run() {
  node "$DOCTOR" --root "$1" --strict > "$_RUN_OUT" 2>&1
  RC=$?
  OUT="$(cat "$_RUN_OUT")"
}

# ── fixture builders ─────────────────────────────────────────────────────────────────────────
# The tier table's SHAPE is taken from the regex the subject actually uses
# (`/\|\s*\*\*(M[123])\b/` + a backtick-quoted lowercase name), not from a mental model of
# "an AGENTS.md" — a fixture whose row does not match would make every positive arm a false red.
mk_agents_md() {   # $1 = dir, $2 = "table" | "no-table"
  if [ "$2" = "table" ]; then
    cat > "$1/AGENTS.md" <<'EOF'
# Fixture AGENTS.md

| Tier | Skill | Note |
|---|---|---|
| **M1** | `demo-native` | runs under codex exec directly |
| **M2** | `demo-adapter` | needs adapter substitution |
EOF
  else
    printf '# Fixture AGENTS.md\n\nNo tier table here on purpose.\n' > "$1/AGENTS.md"
  fi
}

mk_skill() {   # $1 = dir(root), $2 = plugin namespace, $3 = skill name
  mkdir -p "$1/plugins/$2/skills/$3"
  cat > "$1/plugins/$2/skills/$3/SKILL.md" <<EOF
---
name: $3
description: fixture skill for codex-doctor root lanes
---

Body. Nothing Claude-native here.
EOF
}

mk_agent() {   # $1 = dir(root), $2 = plugin namespace, $3 = agent name
  mkdir -p "$1/plugins/$2/agents"
  printf -- '---\nname: %s\n---\n\nFixture agent.\n' "$3" > "$1/plugins/$2/agents/$3.md"
}

# The plugin MANIFEST is the shape discriminator pluginNamespaces() uses. Its path is taken from the
# real tree (all 4 FH plugins, and both plugins of a consumer harness measured off-tree, carry
# .claude-plugin/plugin.json — verified by
# `ls`, not assumed), because a fixture whose manifest sat anywhere else would make the shape lanes
# green for the wrong reason.
mk_plugin_manifest() {   # $1 = dir(root), $2 = plugin namespace
  mkdir -p "$1/plugins/$2/.claude-plugin"
  printf '{"name":"%s","version":"0.0.0"}\n' "$2" > "$1/plugins/$2/.claude-plugin/plugin.json"
}

echo "── codex-doctor root lanes ──  subject: $DOCTOR"

# ── LANE 1 — KNOWN POSITIVE. A non-npm consumer root that HAS every audited surface.
# This is that consumer shape reduced to its essentials: AGENTS.md tier table + plugins/**/SKILL.md,
# and deliberately NO package.json. It must produce a report, not exit 11.
# 🟥 rc alone is not the assertion. `rc != 11` is also satisfied by a crash, by usage output, or by
# a stub that prints nothing — so the arm pins the REPORT and a non-zero skill count too.
P1="$TMP/nonnpm"; mkdir -p "$P1"
mk_agents_md "$P1" table
mk_skill "$P1" xx-meta demo-native
mk_skill "$P1" xx-commons demo-adapter
run "$P1"; out="$OUT"
if [ "$RC" -eq 11 ]; then
  bad "lane1 KNOWN-POSITIVE: non-npm root with every audited surface was still gated out" "rc=$RC | $out"
elif [ "$RC" -ne 0 ]; then
  bad "lane1 KNOWN-POSITIVE: expected a clean report (rc=0), got another non-pass" "rc=$RC | $out"
else
  case "$out" in
    *"Skills scanned: 0"*) bad "lane1 KNOWN-POSITIVE: passed the gate but classified NOTHING — a confident empty report" "rc=$RC | $out" ;;
    *"Skills scanned: "*)  ok "lane1 KNOWN-POSITIVE: non-npm root (no package.json) audited, skills classified (rc=$RC)" ;;
    *)                     bad "lane1 KNOWN-POSITIVE: rc=0 but no report on stdout — a stub would pass on rc alone" "rc=$RC | $out" ;;
  esac
fi

# ── LANE 2 — KNOWN NEGATIVE. An empty directory. Genuinely nothing to audit → still rc=11.
# The message assertion is the positive control: `exit 11` with no explanation would pass on rc.
N2="$TMP/empty"; mkdir -p "$N2"
run "$N2"; out="$OUT"
if [ "$RC" -eq 11 ] && case "$out" in *"missing: AGENTS.md"*) true ;; *) false ;; esac \
   && case "$out" in *"missing: plugins/"*) true ;; *) false ;; esac; then
  ok "lane2 KNOWN-NEGATIVE: empty dir → rc=11, and BOTH missing surfaces named"
else
  bad "lane2 KNOWN-NEGATIVE: empty dir must fail closed at 11 naming each missing surface" "rc=$RC | $out"
fi

# ── LANE 3 — one leg at a time, so lane2 cannot pass on the other's behalf.
# 3a: the skills exist, the instrument (AGENTS.md) does not.
N3A="$TMP/no_agents_md"; mkdir -p "$N3A"; mk_skill "$N3A" xx-meta demo-native
run "$N3A"; out="$OUT"
if [ "$RC" -eq 11 ] && case "$out" in *"missing: AGENTS.md"*) true ;; *) false ;; esac; then
  ok "lane3a KNOWN-NEGATIVE: plugins present, AGENTS.md absent → rc=11 (no instrument, no report)"
else
  bad "lane3a: AGENTS.md absence must gate at 11" "rc=$RC | $out"
fi
# 3b: the instrument exists, the subject does not.
N3B="$TMP/no_plugins"; mkdir -p "$N3B"; mk_agents_md "$N3B" table
run "$N3B"; out="$OUT"
if [ "$RC" -eq 11 ] && case "$out" in *"missing: plugins/"*) true ;; *) false ;; esac; then
  ok "lane3b KNOWN-NEGATIVE: AGENTS.md present, plugins/ absent → rc=11"
else
  bad "lane3b: plugins/ absence must gate at 11" "rc=$RC | $out"
fi

# ── LANE 4 — THE INVERSE ERROR, and the arm the UNFIXED code passed with rc=0.
# plugins/ EXISTS but holds no SKILL.md. Every surface-existence check says yes; there is still
# nothing to classify. Before the fix this root (package.json + plugins/ + AGENTS.md all present)
# sailed through and printed `Skills scanned: 0` / `Findings: none` / `Status: OK` / rc=0 —
# a measurement of nothing rendered as a clean bill of health.
# 🟥 package.json is PRESENT in this fixture on purpose: without it the unfixed code would gate on
# the old predicate and the arm would be green both ways, i.e. decorative about the axis it names.
N4="$TMP/empty_plugins"; mkdir -p "$N4/plugins"
mk_agents_md "$N4" table
printf '{"name":"fixture","version":"0.0.0"}\n' > "$N4/package.json"
run "$N4"; out="$OUT"
if [ "$RC" -eq 11 ] && case "$out" in *"missing: plugins/**/SKILL.md"*) true ;; *) false ;; esac; then
  ok "lane4 INVERSE-ERROR: empty plugins/ → rc=11, not a confident empty report"
else
  bad "lane4 INVERSE-ERROR: an empty plugins/ produced a report — not-found rendered as zero" "rc=$RC | $out"
fi

# ── LANE 5 — the pre-existing fail-closed channel must survive the gate rewrite.
# AGENTS.md is readable but has NO tier table → documentedTiers() yields 0 rows → INSTRUMENT_ERROR,
# exit 10 (harness error), distinct from 1 (drift) and 11 (wrong root). If the new predicate had
# been written as "AGENTS.md must contain a tier table", this arm would collapse into an 11 and the
# two failure classes — wrong root vs broken instrument — would stop being distinguishable.
N5="$TMP/no_tier_table"; mkdir -p "$N5"
mk_agents_md "$N5" no-table
mk_skill "$N5" xx-meta demo-native
run "$N5"; out="$OUT"
if [ "$RC" -eq 10 ] && case "$out" in *INSTRUMENT_ERROR*) true ;; *) false ;; esac; then
  ok "lane5 INSTRUMENT-ERROR preserved: readable AGENTS.md with 0 tier rows → rc=10, not 11 and not 0"
else
  bad "lane5: the instrument-failure channel changed class (expected rc=10 + INSTRUMENT_ERROR)" "rc=$RC | $out"
fi

# ── LANE 6 — the second silent zero, isolated from lane1.
# collectAgents() used to iterate a HARDCODED ['fh-meta','fh-commons'], so a consumer whose plugins
# carry any other prefix got `Agents scanned: 0` — the same not-found-is-zero family, and the first
# thing a newly-unblocked consumer would have seen. package.json is present here so the UNFIXED
# code reaches the report: it printed rc=0 with `Agents scanned: 0` while 2 agent files existed.
N6="$TMP/other_prefix"; mkdir -p "$N6"
mk_agents_md "$N6" table
mk_skill  "$N6" zz-meta demo-native
mk_agent  "$N6" zz-meta fixture-agent-one
mk_agent  "$N6" zz-commons fixture-agent-two
# 🟥 Both namespaces are given a real plugin manifest so this lane exercises the SHAPE-FILTERED
# discovery path rather than the manifest-less fallback (lane10b owns that). The lane's axis is
# unchanged and in fact sharper: a non-`fh-` prefix must resolve THROUGH the filter, never by
# accident of the filter being bypassed. A name-based filter would redden exactly here.
mk_plugin_manifest "$N6" zz-meta
mk_plugin_manifest "$N6" zz-commons
printf '{"name":"fixture","version":"0.0.0"}\n' > "$N6/package.json"
run "$N6"; out="$OUT"
if [ "$RC" -ne 0 ]; then
  bad "lane6: fixture root did not produce a report at all" "rc=$RC | $out"
else
  case "$out" in
    *"Agents scanned: 2"*) ok "lane6 NAMESPACE: agents under non-fh- plugin prefixes are discovered (2/2)" ;;
    *"Agents scanned: 0"*) bad "lane6 NAMESPACE: 2 agent files on disk reported as 0 — hardcoded plugin list" "rc=$RC | $out" ;;
    *)                     bad "lane6 NAMESPACE: unexpected agent count" "rc=$RC | $out" ;;
  esac
fi

# ── LANE 7 — CONTROL, against the live repo. The suite must not be satisfiable by a subject that
# has simply stopped gating (lanes 1/6) or by one that gates everything (lanes 2/3/4). FH's own root
# is the known-good reference: it must still audit clean, with the counts the shipped tree has.
run "$FH_REPO"; out="$OUT"
if [ "$RC" -eq 0 ] \
   && case "$out" in *"Status: OK"*) true ;; *) false ;; esac \
   && case "$out" in *"Skills scanned: 0"*) false ;; *) true ;; esac \
   && case "$out" in *"Agents scanned: 0"*) false ;; *) true ;; esac; then
  ok "lane7 CONTROL: the live FH root still audits clean and non-empty ($(printf '%s' "$out" | sed -n 's/^- \(Skills scanned: [0-9]*\)$/\1/p'), $(printf '%s' "$out" | sed -n 's/^- \(Agents scanned: [0-9]*\)$/\1/p'))"
else
  bad "lane7 CONTROL: regression on the live FH root" "rc=$RC | $out"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# LANES 8–11 — EXIT-CODE COLLAPSE. Added 2026-09-17 after a cross-family review of the lanes above.
# The gate rewrite stopped asserting several surface properties, and every property it stopped
# asserting reached raw fs calls that THROW. An uncaught node exception is rc=1 — the code already
# owned by "--strict found HIGH drift". So a caller could not distinguish "the harness broke" from
# "the harness found drift", which is the same class of defect as the silent zeros above, only
# wearing an exit code. The three non-zero classes must stay separable:
#     11 wrong root  ·  10 instrument/input error  ·  1 --strict with HIGH findings
# ═══════════════════════════════════════════════════════════════════════════════════════════════

# ── LANE 8 — `plugins` PRESENT BUT NOT A DIRECTORY. exists() says yes (it uses F_OK, which is
# blind to node type), then readdirSync threw ENOTDIR. Measured before the fix:
#     Error: ENOTDIR: not a directory, scandir '.../plugins'  → rc=1
# A wrong-shaped root surface belongs with an absent one: rc=11, naming it.
N8="$TMP/plugins_is_a_file"; mkdir -p "$N8"
mk_agents_md "$N8" table
printf 'this is a file, not a directory\n' > "$N8/plugins"
run "$N8"; out="$OUT"
if [ "$RC" -eq 11 ] && case "$out" in *"plugins/ — present but NOT a directory"*) true ;; *) false ;; esac; then
  ok "lane8 SHAPE: plugins/ present as a FILE → rc=11 naming the shape fault (not an uncaught rc=1)"
else
  bad "lane8 SHAPE: a non-directory plugins/ must exit 11, not collapse into 1" "rc=$RC | $out"
fi

# ── LANE 9 — UNREADABLE SUBJECT, deterministic arm. A broken symlink named SKILL.md: walk() lists
# it (readdirSync sees the link; exists() follows it and reports the TARGET absent), then readText()
# threw ENOENT out of collectSkills(). Measured before the fix:
#     Error: ENOENT: no such file or directory, open '.../broken/SKILL.md'  → rc=1
# The subject being unusable is an INPUT fault: rc=10 + INSTRUMENT_ERROR + the path named.
N9="$TMP/broken_symlink_skill"; mkdir -p "$N9"
mk_agents_md "$N9" table
mk_skill "$N9" xx-meta demo-native
mkdir -p "$N9/plugins/xx-meta/skills/broken"
ln -s /nonexistent/definitely-not-here.md "$N9/plugins/xx-meta/skills/broken/SKILL.md"
run "$N9"; out="$OUT"
if [ "$RC" -eq 10 ] \
   && case "$out" in *INSTRUMENT_ERROR*) true ;; *) false ;; esac \
   && case "$out" in *"skills/broken/SKILL.md"*) true ;; *) false ;; esac; then
  ok "lane9 INPUT-ERROR: broken-symlink SKILL.md → rc=10 + INSTRUMENT_ERROR + path named"
else
  bad "lane9 INPUT-ERROR: an unreadable skill input must be 10, not an uncaught 1 and not 0" "rc=$RC | $out"
fi

# ── LANE 9b — the permissions arm of the same axis. Kept SEPARATE from lane9 because it is the only
# arm in this suite whose fixture can be silently defeated by the environment: a user who can read a
# chmod 000 file (root, or some CI images) makes the fixture non-potent. That is a SKIP with a stated
# reason — 🟥 SKIP IS NOT PASS, so it increments neither counter and says so out loud.
N9B="$TMP/eacces_skill"; mkdir -p "$N9B"
mk_agents_md "$N9B" table
mk_skill "$N9B" xx-meta demo-native
mk_skill "$N9B" xx-meta locked
chmod 000 "$N9B/plugins/xx-meta/skills/locked/SKILL.md"
if cat "$N9B/plugins/xx-meta/skills/locked/SKILL.md" >/dev/null 2>&1; then
  printf '  ⚠️  lane9b SKIPPED (not PASS, not counted): this user (%s) can read a chmod 000 file, so the EACCES fixture is not potent here. The same code path is covered deterministically by lane9.\n' "$(id -un)"
else
  run "$N9B"; out="$OUT"
  if [ "$RC" -eq 10 ] \
     && case "$out" in *INSTRUMENT_ERROR*) true ;; *) false ;; esac \
     && case "$out" in *"skills/locked/SKILL.md"*) true ;; *) false ;; esac; then
    ok "lane9b INPUT-ERROR: chmod 000 SKILL.md (EACCES) → rc=10 + INSTRUMENT_ERROR + path named"
  else
    bad "lane9b INPUT-ERROR: an EACCES skill input must be 10, not an uncaught 1" "rc=$RC | $out"
  fi
fi

# ── LANE 10 — NAMESPACE OVER-COLLECTION. pluginNamespaces() accepted every directory under
# plugins/, so a stray dir (a stale copy, node_modules, a scratch tree) INFLATED `Agents scanned`.
# Measured before the fix, with one real plugin plus plugins/not-a-plugin/agents/ghost.md:
#     Status: OK · Skills scanned: 1 · Agents scanned: 1 · Findings: none
# The ghost is now excluded by plugin SHAPE — and 🟥 the exclusion is asserted to be VISIBLE, not
# silent: a quiet drop and a quiet over-count are the same defect pointing opposite ways.
N10="$TMP/ghost_namespace"; mkdir -p "$N10"
mk_agents_md "$N10" table
mk_skill "$N10" real demo-native
mk_agent "$N10" real fixture-real-agent
mk_plugin_manifest "$N10" real
mkdir -p "$N10/plugins/not-a-plugin/agents"
printf -- '---\nname: ghost\n---\n\nGhost agent in a directory that is not a plugin.\n' > "$N10/plugins/not-a-plugin/agents/ghost.md"
run "$N10"; out="$OUT"
if [ "$RC" -ne 0 ]; then
  bad "lane10 NAMESPACE-SHAPE: fixture root did not produce a report at all" "rc=$RC | $out"
elif case "$out" in *"Agents scanned: 1"*) false ;; *) true ;; esac; then
  bad "lane10 NAMESPACE-SHAPE: expected exactly the 1 real agent (the ghost must not be counted)" "rc=$RC | $out"
elif case "$out" in *PLUGIN_NAMESPACE_NOT_PLUGIN_SHAPED*) true ;; *) false ;; esac; then
  ok "lane10 NAMESPACE-SHAPE: unshaped plugins/not-a-plugin/ excluded (Agents scanned: 1) AND the drop is named in a WARN"
else
  bad "lane10 NAMESPACE-SHAPE: count is right but the exclusion is SILENT — a drop must be visible" "rc=$RC | $out"
fi

# ── LANE 10b — THE PAIRED NEGATIVE for lane10, and the reason the shape filter is not absolute.
# A consumer whose plugins/ carries NO manifest anywhere has no shape signal at all. Filtering
# strictly there would report `Agents scanned: 0` for a tree that visibly holds agents — the exact
# not-found-is-zero failure this whole suite was built around, re-introduced by the fix for lane10.
# So discovery falls back to an UNFILTERED scan and says so. Both halves are asserted: the agent is
# found, and the report admits the count is unfiltered.
# 🟥 Honest scope: on such a root lane10's ghost WOULD still be counted. That residual is structural
# (with zero manifests nothing distinguishes a plugin from a stray dir) and it is LABELLED, not silent.
N10B="$TMP/no_manifest_anywhere"; mkdir -p "$N10B"
mk_agents_md "$N10B" table
mk_skill "$N10B" qq-meta demo-native
mk_agent "$N10B" qq-meta fixture-agent-one
run "$N10B"; out="$OUT"
if [ "$RC" -ne 0 ]; then
  bad "lane10b FALLBACK: manifest-less root did not produce a report" "rc=$RC | $out"
elif case "$out" in *"Agents scanned: 1"*) false ;; *) true ;; esac; then
  bad "lane10b FALLBACK: the shape filter manufactured a silent zero on a manifest-less root" "rc=$RC | $out"
elif case "$out" in *PLUGIN_SHAPE_UNDETECTABLE*) true ;; *) false ;; esac; then
  ok "lane10b FALLBACK: manifest-less root still discovers agents (1/1) AND labels the count unfiltered"
else
  bad "lane10b FALLBACK: fell back correctly but did not LABEL the count as unfiltered" "rc=$RC | $out"
fi

# ── LANE 11 — EMPTY SKILL.md. A zero-byte SKILL.md was counted as a skill and the report said
# `Status: OK · Findings: none`; the only trace was `unclassified=1`, which is also where a
# merely-undocumented-but-real skill lands, so the two were indistinguishable.
# 🟥 Strength is deliberately WARN. The run DID measure the surface — it measured an empty one — so
# escalating to 10 or HIGH would fix one exit-code collapse by creating another. rc must stay 0.
N11="$TMP/empty_skill_md"; mkdir -p "$N11"
mk_agents_md "$N11" table
mk_skill "$N11" ee-meta demo-native
mk_plugin_manifest "$N11" ee-meta
mkdir -p "$N11/plugins/ee-meta/skills/emptyskill"
: > "$N11/plugins/ee-meta/skills/emptyskill/SKILL.md"
run "$N11"; out="$OUT"
if [ "$RC" -ne 0 ]; then
  bad "lane11 EMPTY-SKILL: a WARN-class observation must NOT change the exit class (expected rc=0)" "rc=$RC | $out"
elif case "$out" in *SKILL_MD_HAS_NO_CLASSIFIABLE_CONTENT*) true ;; *) false ;; esac; then
  ok "lane11 EMPTY-SKILL: empty SKILL.md is named in a WARN, and rc stays 0 (no new exit-code collapse)"
else
  bad "lane11 EMPTY-SKILL: an empty SKILL.md still reports a clean bill of health" "rc=$RC | $out"
fi

# ── LANE 11b — CONTROL for lane11. The WARN must fire on the empty input, not on every skill.
# Without this, a rule that warned unconditionally would pass lane11 while making the signal useless.
N11B="$TMP/normal_skills_only"; mkdir -p "$N11B"
mk_agents_md "$N11B" table
mk_skill "$N11B" ee-meta demo-native
mk_skill "$N11B" ee-meta demo-adapter
mk_plugin_manifest "$N11B" ee-meta
run "$N11B"; out="$OUT"
if [ "$RC" -eq 0 ] && case "$out" in *SKILL_MD_HAS_NO_CLASSIFIABLE_CONTENT*) false ;; *) true ;; esac; then
  ok "lane11b CONTROL: two well-formed SKILL.md files raise NO empty-input WARN"
else
  bad "lane11b CONTROL: the empty-input WARN fires on well-formed skills — the signal is worthless" "rc=$RC | $out"
fi

printf '\ncodex-doctor root lanes: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0

#!/usr/bin/env bash
# hook_drift_check.sh — are the hooks INSTALLED in .claude/settings.json the ones the tracked
# templates currently ship?  Per template hook entry: CURRENT / STALE / ABSENT / UNKNOWN.
#
# WHY (2026-09-25/26, measured on this repo): session_close_check.sh ④-e used to decide «the tally
# hook is installed» with `grep -q '"SubagentStop"'`. That is a PRESENCE test. The template's body
# had just moved into scripts/subagent_tally_hook.sh (it now skips Claude Code's internal agents),
# and templates/subagent-tally-hook.json says «RE-MERGE — an existing inline hook keeps the old
# behaviour». An install still carrying the OLD inline hook therefore passed ④-e as «measured»
# while it was over-counting. `.claude/settings.json` is gitignored, so git never tells you the
# installed copy has drifted from the tracked source; nothing else in the repo compared them.
#
# The sibling instrument, env_layer_fingerprint.sh, answers «is a layer PRESENT»; this one answers
# «is the present thing the CURRENT thing». They are different questions — a present-but-stale hook
# is exactly what a presence check renders as green.
#
# VERDICTS (per template entry, keyed by event):
#   CURRENT  an installed hook in that event has the same matcher AND the same command string
#   STALE    an installed hook in that event is the SAME hook (shares an identity token — a
#            scripts/<name>.sh|py it runs, or a tracks/_meta/.<file> it writes) but its command or
#            matcher differs from the template → re-merge needed
#   ABSENT   no installed hook in that event is related (includes: settings file does not exist)
#   UNKNOWN  the settings file or the template could not be read/parsed, or python3 is missing.
#            🟥 UNKNOWN is never folded into CURRENT — a checker that cannot read is not a pass.
#
# SCOPE: compares `project_settings_json` (and a template's top-level `hooks`) against
# .claude/settings.json. The SessionStart snippet's `settings_local_json_MODE_D_ONLY` block carries
# an operator-private path by design and is NOT compared (reported as a note, not as a verdict).
# READ-ONLY: never writes to any settings file.
#
# Usage:
#   bash scripts/hook_drift_check.sh [--settings FILE] [--templates DIR] [--only TOKEN] [--verdict]
#     --only TOKEN   restrict to template entries whose identity contains TOKEN
#                    (e.g. --only subagent_tally_hook.sh — what ④-e asks)
#     --verdict      print ONE aggregate word instead of the table
#                    (priority UNKNOWN > STALE > ABSENT > CURRENT)
#   Exit: 0 all CURRENT · 1 some STALE/ABSENT · 3 UNKNOWN · 2 usage error
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SETTINGS="$ROOT/.claude/settings.json"
TEMPLATES="$ROOT/templates"
ONLY=""
VERDICT_ONLY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --settings)  [ -n "${2:-}" ] || { echo "usage: --settings needs a non-empty path" >&2; exit 2; }; SETTINGS="$2"; shift 2 ;;
    --templates) [ -n "${2:-}" ] || { echo "usage: --templates needs a non-empty path" >&2; exit 2; }; TEMPLATES="$2"; shift 2 ;;
    --only)      [ -n "${2:-}" ] || { echo "usage: --only needs a non-empty token" >&2; exit 2; }; ONLY="$2"; shift 2 ;;
    --verdict)   VERDICT_ONLY=1; shift ;;
    -h|--help)   sed -n '2,40p' "$0"; exit 0 ;;
    *) echo "usage: unknown argument: $1" >&2; exit 2 ;;
  esac
done

PY="$(command -v python3 2>/dev/null || true)"
[ -n "$PY" ] || PY=/usr/bin/python3
if [ ! -x "$PY" ]; then
  if [ "$VERDICT_ONLY" -eq 1 ]; then echo UNKNOWN; else echo "UNKNOWN	*	*	python3 not found — cannot compare (not a pass)"; fi
  exit 3
fi

"$PY" - "$SETTINGS" "$TEMPLATES" "$ONLY" "$VERDICT_ONLY" <<'PY'
import glob, json, os, re, sys

settings_path, tdir, only, verdict_only = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4] == "1"
ID_RE = re.compile(r"scripts/([A-Za-z0-9_.-]+\.(?:sh|py))|tracks/_meta/(\.[A-Za-z0-9_.-]+)")

def ident(cmd):
    return {a or b for a, b in ID_RE.findall(cmd or "")}

def flatten(hooks, bad=None):
    # bad: optional list collecting events whose hook entries are malformed (no/empty command).
    # 🟥 2026-09-26 (cross-family): such an entry used to be read as command "" → never related →
    # ABSENT. An entry we cannot identify is not evidence of absence; the caller renders UNKNOWN.
    out = []  # (event, matcher, command)
    if not isinstance(hooks, dict):
        return None
    for ev, groups in hooks.items():
        if not isinstance(groups, list):
            return None
        for g in groups:
            if not isinstance(g, dict):
                return None
            m = g.get("matcher", "")
            for h in g.get("hooks", []) or []:
                if isinstance(h, dict) and h.get("type", "command") == "command":
                    cmd = h.get("command")
                    if not isinstance(cmd, str) or not cmd.strip():
                        if bad is not None:
                            bad.append(ev)
                        continue
                    out.append((ev, m or "", cmd))
                elif not isinstance(h, dict) and bad is not None:
                    bad.append(ev)
    return out

rows, notes = [], []

# ── templates ──
tfiles = sorted(set(glob.glob(os.path.join(tdir, "*hook*.json")) +
                    glob.glob(os.path.join(tdir, "settings.*.snippet.json"))))
tentries = []  # (event, matcher, command, template-name)
if not tfiles:
    rows.append(("UNKNOWN", "*", "*", "no templates found under %s" % tdir))
for tf in tfiles:
    name = os.path.basename(tf)
    try:
        with open(tf, encoding="utf-8") as fh:
            d = json.load(fh)
    except Exception as e:
        rows.append(("UNKNOWN", "*", "*", "%s unreadable: %s" % (name, e.__class__.__name__)))
        continue
    if "settings_local_json_MODE_D_ONLY" in d:
        notes.append("note: %s settings_local_json_MODE_D_ONLY not compared (private path by design)" % name)
    block = d.get("project_settings_json", d)
    fl = flatten(block.get("hooks", {}) if isinstance(block, dict) else None)
    if fl is None:
        rows.append(("UNKNOWN", "*", "*", "%s: hooks block malformed" % name))
        continue
    for ev, m, c in fl:
        tentries.append((ev, m, c, name))

# ── installed ──
installed, inst_err, inst_bad = None, None, []
if not os.path.exists(settings_path):
    installed = []          # no file = no hooks installed = ABSENT (not a read failure)
else:
    try:
        with open(settings_path, encoding="utf-8") as fh:
            sd = json.load(fh)
        installed = flatten(sd.get("hooks", {}) if isinstance(sd, dict) else None, inst_bad)
        if installed is None:
            inst_err = "hooks block malformed"
    except Exception as e:
        inst_err = "unreadable: %s" % e.__class__.__name__

for ev, m, c, name in tentries:
    tid = ident(c)
    label = ",".join(sorted(tid)) or "(inline)"
    if only and not any(only in t for t in tid):
        continue
    if inst_err:
        rows.append(("UNKNOWN", ev, label, "%s — settings %s" % (name, inst_err)))
        continue
    if ev in inst_bad:
        rows.append(("UNKNOWN", ev, label, "%s — settings has a malformed %s entry (형식 불량 항목: no command)" % (name, ev)))
        continue
    same_ev = [(im, ic) for (iev, im, ic) in installed if iev == ev]
    related = [(im, ic) for im, ic in same_ev if tid and (ident(ic) & tid)]
    exact = [(im, ic) for im, ic in same_ev if im == m and ic == c]
    # 🟥 2026-09-26 (cross-family, real fail-open): `any(exact)` called this CURRENT even when the
    # OLD inline form was installed alongside the template form. Claude Code runs every matching
    # hook, so the old behaviour stayed live. CURRENT now means: the same hook is installed
    # EXACTLY ONCE, and that one copy is the template's.
    if exact and len(related) <= 1 and len(exact) == 1:
        rows.append(("CURRENT", ev, label, name))
        continue
    if exact:
        rows.append(("STALE", ev, label, "%s — duplicate install (%d copies of this hook); 중복 설치 — remove the old entries" % (name, max(len(related), len(exact)))))
        continue
    if related:
        why = "matcher differs" if any(ic == c for _, ic in related) else "command differs"
        rows.append(("STALE", ev, label, "%s — %s; re-merge needed" % (name, why)))
    else:
        rows.append(("ABSENT", ev, label, name))

if only and not any(r[2] != "*" for r in rows):
    rows.append(("UNKNOWN", "*", only, "no template entry carries this identity"))

order = {"UNKNOWN": 3, "STALE": 2, "ABSENT": 1, "CURRENT": 0}
worst = max((order[r[0]] for r in rows), default=3)
word = [k for k, v in order.items() if v == worst][0]

if verdict_only:
    print(word)
else:
    for r in rows:
        print("\t".join(r))
    for n in notes:
        print(n)
    cnt = {k: sum(1 for r in rows if r[0] == k) for k in order}
    print("hook-drift: current=%d stale=%d absent=%d unknown=%d (settings=%s)"
          % (cnt["CURRENT"], cnt["STALE"], cnt["ABSENT"], cnt["UNKNOWN"], settings_path))
sys.exit({"CURRENT": 0, "ABSENT": 1, "STALE": 1, "UNKNOWN": 3}[word])
PY

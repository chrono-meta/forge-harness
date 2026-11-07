#!/usr/bin/env python3
"""ablation_nominate.py — name ONE section to test for removal tonight, or say why none.

usage: python3 scripts/ablation_nominate.py [--repo DIR] [--probes FILE] [--verdicts FILE] [--date YYYY-MM-DD] [--json]

WHY (operator 2026-11-07 «고이지 않고 선두에서 계속 나아가면서 내 의도에 동조하는 사람들은 쓸 수 있도록»).
Measured on origin/main, excluding tracks/, last 30 days: +28,211 / −4,725 lines and 0 skill/rule/knowledge
files deleted; CLAUDE.md shrank by MOVING text, not cutting it. Every self-dev queue source asks «what to add
or fix»; none asks «what can go now». The ablation procedure exists (scripts/probe_scope_check.sh header) but
nothing nominates a target, so it never runs. This picks the target; it decides nothing.

A candidate is a Scope in the probe table (a section some probe tests — without a probe there is no question
to ask the arms, so it cannot be ablated; write a probe first). Excluded, and counted:
  - gate / irreversible surfaces (Irreversibility Gates, Pre-Publish, Destructive-Op, 4-Axis gate, hooks,
    anything named «gate») — never removed by this cycle, whatever an ablation would say;
  - sections already in the verdict ledger as KEEP (load-bearing — not re-nominated) or CUT (gone);
  - malformed Scope cells: a correction note, or a dead pointer (the file or the section heading does not exist).
  A missing verdict ledger is HARNESS-ERROR (rc 2) — create it with an empty table to start.
UNCALIBRATED or INSTRUMENT-UNCONFIRMED ledger rows stay eligible: an instrument that could not decide is a
reason to measure again, not a verdict.
Pick = deterministic rotation by date over the eligible list (same date → same candidate).

rc: 0 nominated · 1 nothing eligible (the reason is printed) · 2 HARNESS-ERROR (probe table unreadable / empty)
"""
import argparse, datetime, json, os, re, sys

# codex R1: whole words («delegated» is not a gate), and wider on purpose — excluding a harmless section costs a night,
# nominating a gate costs a guard. Approval · verification · sync/push/merge surfaces are gates too.
GATE = re.compile(r"(?i)\bgates?\b|irreversib|pre-publish|destructive|4-axis|\bhooks?\b|\bpublish|\bdelet|force-push|"
                  r"\bapprov|\bverif|\bsync\b|\bpush|\bmerge|check classes|permission")


def scopes(probes_path):
    """{scope: [(probe_id, input, expected)]} from markdown table rows whose first cell is a `ID`."""
    out = {}
    for line in open(probes_path, encoding="utf-8"):
        if not line.startswith("| `"):
            continue
        cols = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cols) < 4:
            continue
        pid = cols[0].strip("`")
        scope = re.sub(r"\s+", " ", cols[3]).strip()
        out.setdefault(scope, []).append((pid, cols[1][:200], cols[2][:300]))
    return out


def norm_name(s):
    return re.sub(r"\s+", " ", re.sub(r"[*`]", "", s)).strip().lower()


def ledger(verdicts_path):
    """{section-name: verdict} from the verdict table (first two cells). A missing ledger raises — a checkout without
    its KEEP/CUT history must not nominate as if nothing had been measured (codex R1). Start with an empty table."""
    out = {}
    for line in open(verdicts_path, encoding="utf-8"):
        if not line.startswith("| ") or line.startswith("| Section") or line.startswith("|---"):
            continue
        cols = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cols) >= 2:
            v = re.sub(r"[*`]", "", cols[1]).strip().upper()
            out[norm_name(cols[0])] = v
    return out


def section_name(scope):
    return re.split(r"\s+·\s+", re.sub(r"^.*?§\s*", "", scope))[0].strip()


def resolves(repo, scope):
    """«<file> §<Section>» where the file exists and a heading starts with the section name (codex R1: a dead pointer
    such as «missing.md §No such section» must not be nominated). Scopes without «§» or with a correction note fail."""
    if len(scope) > 120 or scope.startswith(("🟥", "⚠")) or "§" not in scope:
        return False
    head = scope.split("§", 1)[0].strip()
    f = head.split()[-1] if head else ""
    if not f:
        return False
    # codex R2: a path with a directory resolves only there; a bare file name at the repo root, or else in exactly
    # ONE place in the tree (two = ambiguous = not resolved) — never «some file of that name somewhere».
    if "/" in f or os.path.isfile(os.path.join(repo, f)):
        path = os.path.join(repo, f)
    else:
        hits = _index(repo).get(f, [])
        path = hits[0] if len(hits) == 1 else None
    if not path or not os.path.isfile(path):
        return False
    want = norm_name(section_name(scope))
    if not want:
        return False
    for line in open(path, encoding="utf-8", errors="replace"):
        m = re.match(r"^#{1,4}\s+(.*\S)", line)
        if m:
            h = norm_name(m.group(1))
            # codex R2: a prefix must end at a word boundary — «Alpha» is not «Alphabet»
            if h == want or (h.startswith(want) and not h[len(want)].isalnum()):
                return True
    return False


_INDEX = {}


def _index(repo):
    """file name → [paths], built once per run, .git / node_modules / tracks pruned (codex R2: one walk, not one per scope)."""
    if repo not in _INDEX:
        idx = {}
        for dp, dns, fs in os.walk(repo):
            dns[:] = [d for d in dns if d not in (".git", "node_modules", "tracks")]
            for n in fs:
                idx.setdefault(n, []).append(os.path.join(dp, n))
        _INDEX[repo] = idx
    return _INDEX[repo]


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", default=".")
    ap.add_argument("--probes", default=".claude/regression/probes.md")
    ap.add_argument("--verdicts", default=".claude/regression/ablation_verdicts.md")
    ap.add_argument("--date", default=datetime.date.today().isoformat())
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args(argv)
    pp = os.path.join(a.repo, a.probes)
    try:
        sc = scopes(pp)
    except OSError as e:
        print("HARNESS-ERROR: probe table unreadable: %s" % e)
        return 2
    if not sc:
        print("HARNESS-ERROR: no probe rows in %s — nothing to nominate from is not «nothing to remove»" % a.probes)
        return 2
    try:
        led = ledger(os.path.join(a.repo, a.verdicts))
    except OSError as e:
        print("HARNESS-ERROR: verdict ledger unreadable (%s) — create it with an empty table to start" % e)
        return 2
    excluded = {"gate": [], "ledger": [], "malformed": []}
    eligible = []
    for scope in sorted(sc):
        if GATE.search(scope):
            excluded["gate"].append(scope)
        elif not resolves(a.repo, scope):
            excluded["malformed"].append(scope)
        elif led.get(norm_name(section_name(scope))) in ("KEEP", "CUT"):   # codex R1: exact name, not a substring
            excluded["ledger"].append(scope)
        else:
            eligible.append(scope)
    counts = {k: len(v) for k, v in excluded.items()}
    if not eligible:
        msg = "no eligible section: %d scopes · excluded gate %d · ledger KEEP/CUT %d · malformed %d" % (
            len(sc), counts["gate"], counts["ledger"], counts["malformed"])
        print(json.dumps({"nominated": None, "why": msg, "excluded": counts}) if a.json else msg)
        return 1
    day = datetime.date.fromisoformat(a.date).toordinal()
    pick = eligible[day % len(eligible)]
    res = {"nominated": pick, "probes": [{"id": i, "input": x, "expected": y} for i, x, y in sc[pick]],
           "eligible": len(eligible), "scopes": len(sc), "excluded": counts, "date": a.date}
    if a.json:
        print(json.dumps(res, ensure_ascii=False))
    else:
        print("ablation candidate (%s): %s — %d probe(s) · %d eligible of %d scopes · excluded gate %d · ledger %d · malformed %d"
              % (a.date, pick, len(sc[pick]), len(eligible), len(sc), counts["gate"], counts["ledger"], counts["malformed"]))
        for i, x, y in sc[pick]:
            print("  probe %s — input: %s — expected: %s" % (i, x[:120], y[:160]))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

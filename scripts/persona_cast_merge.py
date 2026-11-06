#!/usr/bin/env python3
"""persona_cast_merge.py — persona-cast Step 4 (merge with the marginal-coverage stop), as a program.

Usage:
  python3 scripts/persona_cast_merge.py --artifact <path> [--artifact <path> ...] \
      --lens designer=out/designer.md --lens qa=out/qa.md [...] [--cast web-review] [--stance neutral] [--json]

Reads each lens's parallax output (plugins/fh-commons/agents/*-lens.md «Output»), then:
  1. drops every Concern line with no leading [location] and counts it per lens (no-loc) — never merged;
  2. keys the kept Concerns by their normalized location (lower case, whitespace collapsed, quotes and
     backticks stripped);
  3. unique(lens) = kept keys this lens raised and no other lens raised;
  4. self-tag-hit = self-tagged keys (### Unique-to-this-seat) that really were unique / self-tagged keys;
  5. verdict = «earned» when unique ≥ 1, «decorative on this artifact» when unique = 0;
  6. prints the per-lens table and the merged Concerns (highest severity wins, with the raising seats).

Keying on the location alone is STRICTER than the SKILL text («location + first noun phrase»): two different
concerns at one location merge. That direction under-counts unique (a lens reads decorative sooner), never
over-counts it — padding a lens into «earned» is the failure this stop exists to prevent. Named residual:
two lenses describing the same spot with different location strings stay apart (over-count).

Exit codes: 0 every lens measured · 2 UNMEASURED (a lens file missing/unreadable/without a «### Concerns»
section, no lens given, an artifact missing) — a lens we could not read is never «decorative» and never
«earned». Usage errors also exit 2.
"""
import argparse
import hashlib
import json
import re
import sys

SEVERITIES = ("Critical", "Important", "Suggestion")
RANK = {s: i for i, s in enumerate(SEVERITIES)}
BULLET = re.compile(r"^\s*(?:[-*+]\s+|\d+[.)]\s+)?")


class _Loc:
    """[location] at the start of a line, with nested brackets balanced (`input[name=cvc]`) — 2026-11-06 blind sim:
    a first-«]» cut turned «[form#card input[name=cvc]]» into a truncated key and moved «]» into the text."""
    def match(self, line):
        rest = line[BULLET.match(line).end():]
        if not rest.startswith("["):
            return None
        depth, quoted = 0, False
        for i, ch in enumerate(rest):
            if ch == '"':
                quoted = not quoted   # brackets inside a quoted label are text (codex R1: [button "Save ] now"])
            if quoted:
                continue
            depth += ch == "["
            depth -= ch == "]"
            if depth == 0:
                inner = rest[1:i].strip()
                return _M(inner, rest[i + 1:].strip()) if inner else None
        return None


class _M:
    def __init__(self, a, b):
        self._g = (None, a, b)

    def group(self, i):
        return self._g[i]


LOC = _Loc()
ITEM = re.compile(r"^\s*(?:[-*+]\s+|\d+[.)]\s+)(\S.*)$")


def unwrap(loc):
    """strip backticks, and one pair of quotes only when they wrap the WHOLE location (a quoted label inside stays)"""
    s = loc.strip().replace("`", "").strip()
    for a, b in ('""', "''", "«»", "“”", "‘’"):
        if len(s) >= 2 and s[0] == a and s[-1] == b and b not in s[1:-1]:
            s = s[1:-1].strip()
    return re.sub(r"\s+", " ", s)


def norm(loc):
    s = unwrap(loc)
    return re.sub(r"\s+", " ", s).lower()


def sections(text):
    """'### Name' → list of body lines (the heading line's own trailing text after the name is ignored)."""
    out, cur, fence = {}, None, False
    for line in text.splitlines():
        if re.match(r"^\s*(```|~~~)", line):
            fence = not fence   # fenced examples are not findings (codex R2)
            continue
        if fence:
            continue
        m = re.match(r"^\s*###\s+(.+?)\s*(?:\(.*)?$", line)
        if m:
            cur = m.group(1).strip()
            out.setdefault(cur, [])
            continue
        if re.match(r"^\s*#{1,6}\s", line):
            cur = None   # any other heading ends the section (codex R1: an «## Appendix» must not feed Concerns)
            continue
        if cur is not None:
            out[cur].append(line)
    return out


def parse_lens(text):
    secs = sections(text)
    if "Concerns" not in secs:
        return None
    # the parallax shape puts «Absence check» after Concerns; a reply that stops before it is truncated, and an empty
    # Concerns there would read as «0 concerns → decorative» (codex R1) — so it is unreadable, not zero
    if not any(n.lower().startswith("absence check") for n in secs):
        return None
    kept, noloc, sev = [], [], None
    SEV = re.compile(r"^(?:[-*+]\s+|\d+[.)]\s+)?\*\*\s*(Critical|Important|Suggestion)\b[^*]*\*\*\s*[—:–-]*\s*")
    for line in secs["Concerns"]:
        s = line.strip()
        if not s:
            continue
        hm = SEV.match(s)
        if hm:   # «**Critical** — gloss», «- **Critical** — [loc] text», «1. **Important**: [loc] text» (codex R1)
            sev = hm.group(1)
            rest = s[hm.end():].strip()
            if not LOC.match(rest):
                if rest and re.match(r"^(?:[-*+]\s+|\d+[.)]\s+)", s):
                    noloc.append(s)   # a list item «- **Critical** — text» with no location: dropped, counted
                continue  # otherwise a severity heading line (with or without its gloss), not a concern
            s = rest
        m = LOC.match(s)
        if m and norm(m.group(1)) and m.group(2).strip():
            kept.append({"key": norm(m.group(1)), "location": unwrap(m.group(1)), "text": m.group(2).strip(), "severity": sev or "Suggestion"})
        elif m or ITEM.match(s) or sev is not None:
            noloc.append(s)   # no location, or an empty location / an empty concern (codex R1) — dropped and counted
    tags = []
    for name, body in secs.items():
        if name.lower().startswith("unique-to-this-seat"):
            for line in body:
                m = LOC.match(line.strip())
                if m:
                    tags.append(norm(m.group(1)))
    return {"kept": kept, "noloc": noloc, "tags": sorted(set(tags))}


def main(argv):
    ap = argparse.ArgumentParser(description="persona-cast Step 4 merge")
    ap.add_argument("--artifact", action="append", default=[])
    ap.add_argument("--lens", action="append", default=[], help="name=path")
    ap.add_argument("--cast", default="web-review")
    ap.add_argument("--stance", default="neutral")
    ap.add_argument("--json", action="store_true")
    try:
        a = ap.parse_args(argv)
    except SystemExit:
        return 2
    unmeasured = []
    if not a.lens:
        unmeasured.append("no --lens given")
    shas = []
    for p in a.artifact:
        try:
            with open(p, "rb") as f:
                shas.append((p, hashlib.sha256(f.read()).hexdigest()[:12]))
        except OSError as e:
            unmeasured.append(f"artifact {p}: {e.strerror}")
    if not a.artifact:
        unmeasured.append("no --artifact given (the run header needs its sha256)")
    lenses = {}
    for spec in a.lens:
        if "=" not in spec:
            unmeasured.append(f"--lens {spec!r} is not name=path")
            continue
        name, path = spec.split("=", 1)
        try:
            with open(path, encoding="utf-8") as f:
                parsed = parse_lens(f.read())
        except (OSError, UnicodeDecodeError) as e:
            unmeasured.append(f"lens {name}: unreadable ({getattr(e, 'strerror', None) or e.__class__.__name__})")
            continue
        if parsed is None:
            unmeasured.append(f"lens {name}: no «### Concerns» section — not parallax output")
            continue
        if name in lenses:
            unmeasured.append(f"lens {name}: given twice")
            continue
        lenses[name] = parsed

    raisers = {}
    for name, p in lenses.items():
        for c in p["kept"]:
            raisers.setdefault(c["key"], set()).add(name)
    rows = []
    for name, p in lenses.items():
        keys = {c["key"] for c in p["kept"]}
        uniq = sorted(k for k in keys if raisers[k] == {name})
        hit = sum(1 for k in p["tags"] if k in uniq)
        rows.append({"lens": name, "total": len(p["kept"]), "no_loc": len(p["noloc"]), "unique": len(uniq),
                     "self_tag_hit": f"{hit}/{len(p['tags'])}",
                     # a peer we could not read might share this lens's findings: no seat verdict without it (codex R2)
                     "verdict": "UNMEASURED (a peer lens was unreadable)" if unmeasured else ("earned" if uniq else "decorative on this artifact")})
    merged = {}
    for name, p in lenses.items():
        for c in p["kept"]:
            m = merged.setdefault(c["key"], {"location": c["location"], "severity": c["severity"], "seats": set(), "texts": []})
            if RANK[c["severity"]] < RANK[m["severity"]]:
                m["severity"] = c["severity"]
            m["seats"].add(name)
            m["texts"].append(f"{name}: {c['text']}")

    verdict = "UNMEASURED" if unmeasured else "MEASURED"
    if a.json:
        print(json.dumps({"verdict": verdict, "unmeasured": unmeasured, "artifacts": shas, "rows": rows,
                          "merged": [{**v, "seats": sorted(v["seats"])} for v in merged.values()]}, ensure_ascii=False, indent=1))
    else:
        head = " ".join(f"artifact={p} sha256={h}" for p, h in shas) or "artifact=(none)"
        print(f"persona-cast · cast={a.cast} · stance={a.stance} · {head}")
        print(f"{'lens':<14}{'total':>6}{'no-loc':>8}{'unique':>8}{'self-tag-hit':>14}   verdict")
        for r in rows:
            print(f"{r['lens']:<14}{r['total']:>6}{r['no_loc']:>8}{r['unique']:>8}{r['self_tag_hit']:>14}   {r['verdict']}")
        for sev in SEVERITIES:
            items = [v for v in merged.values() if v["severity"] == sev]
            if not items:
                continue
            print(f"\n{sev} (merged, with the seats that raised each)")
            for v in sorted(items, key=lambda x: (-len(x["seats"]), x["location"])):
                print(f"- [{v['location']}] seats={','.join(sorted(v['seats']))}")
                for t in v["texts"]:
                    print(f"    · {t}")
        for u in unmeasured:
            print(f"UNMEASURED: {u}")
        print(f"verdict: {verdict}")
    return 2 if unmeasured else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

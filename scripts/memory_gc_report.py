#!/usr/bin/env python3
"""memory_gc_report.py — read-only lifecycle report for a Claude Code memory directory.

WHY: MEMORY.md is a capped overview (the loader stops at ~25,000 chars and silently drops the
rest), but nothing decides WHICH entries stay above the cap. Ordering by recency pushes
long-confirmed feedback below the cut, and recurrence lived only in prose ("하루 3회"), so no
machine could rank by it. Generational-GC framing (imweb tech, 2026-10-06): an entry's AGE rises
only when the same observation is recorded again; recurrence across several days marks a
promotion candidate.

WHAT: reads every topic file's frontmatter and the index, and reports
  · index hygiene  — unlisted files · duplicate index lines · dangling local links
  · loader cap     — the character offset where the cap cuts, and the line it falls in
  · every entry    — status, type, age (from `metadata.hits`), distinct days, last hit, index line
  · cold           — non-user, age 1, last hit ≥ --cold-days ago → drop from the INDEX only
  · promote        — age ≥ --promote-age across ≥ 2 distinct days → propose a rule/hook (human approves)
                     — only when the body cites at least one evidence anchor; otherwise «promote held»
  · unanchored     — feedback/project entries whose body cites no evidence anchor (commit sha · #PR/issue ·
                     file path · arXiv id · URL). harness2 (google-research, 2026-10) stores a lesson only with
                     a cited run contrast; this is the record-property half of that: present or not, never
                     whether the cited thing proves the lesson (judgment stays judgment).
  · order          — user entries in index order, then valid measured entries by age (ties: index
                     order), then the rest in index order; cold entries leave the order. Entries with an
                     error status never drive cold / promote / measured ranking until repaired

INVARIANTS:
  · Read-only. It never edits, moves or deletes anything.
  · No `hits` = UNMEASURED, never age 1, never cold. A rule that is followed well also stops
    recurring; absence of a record is not a zero.
  · Unreadable files, missing/unterminated frontmatter, inline or malformed `hits`, invalid or
    future dates are reported as such (status / bad lines) — never folded into "no hits".
  · Same-day repeats count once toward the distinct-days condition.

`hits` format (a child of the frontmatter `metadata:` block; one occurrence per item, first = founding):
    metadata:
      hits:
        - 2026-10-15 | live lane windows covered the operator's screen
usage: memory_gc_report.py <memory_dir> [--index MEMORY.md] [--today YYYY-MM-DD]
                           [--cold-days 30] [--promote-age 3] [--cap 25000] [--json]
exit: 0 report printed · 2 memory dir or index unreadable (instrument error, never an empty report)
"""
import argparse, datetime as dt, json, os, re, sys, urllib.parse

# Evidence anchors a lesson can cite. A date alone is not an anchor (it says when, not what was measured).
# Presence is what is reported, never how many (one anchor is enough; double matches do not matter).
# NOT anchors, by design: [[wiki-links]] to other memories (a relation, not an artifact), bare dates.
# Round-1/2 review (codex · Gemini Flash, 2026-10-23) set these edges. Stopped at the round cap: a static string
# matcher does not converge (each round finds new edges) — residuals are listed in the lanes file, not chased.
_EXT = (r'md|sh|py|js|mjs|cjs|ts|tsx|jsx|json|ya?ml|toml|txt|plist|html|css|rs|go|rb|java|kt|swift|c|h|cpp|hpp|'
        r'sql|lock|cfg|ini|env|xml|csv|ipynb')
ANCHOR_RES = [
    # commit sha: hex mixing letters and digits, any case, not part of a #colour, UUID or longer word
    re.compile(r'(?<![#\w-])(?=[0-9a-fA-F]*[0-9])(?=[0-9a-fA-F]*[a-fA-F])[0-9a-fA-F]{7,40}(?![\w-])'),
    # commit sha named as such: then all-digit / all-letter hex counts too («commit 1234567», «커밋 deadbeef»)
    re.compile(r'(?:commit|sha|커밋)\s*[:#]?\s*`?[0-9a-fA-F]{7,40}(?![\w-])', re.I),
    # PR / issue: #N (not &#39; entities, not #section-slugs, not «#123456;» CSS) and owner/repo#N
    re.compile(r'(?<![\w&#(])#\d+(?![\w;-])'),   # not «(#2)» — a link to a section of the same document
    re.compile(r'[\w.-]+/[\w.-]+#\d+\b'),
    # file path (case-insensitive extension) and the usual extensionless build files
    re.compile(r'[\w./~-]+\.(?:' + _EXT + r')\b', re.I),
    re.compile(r'\b(?:Dockerfile|Makefile|Gemfile|Procfile)\b'),
    re.compile(r'arXiv[: ]?(?:\d{4}\.\d{4,5}|[a-z-]+(?:\.[A-Z]{2})?/\d{7})', re.I),     # arXiv id (new and legacy)
    re.compile(r'https?://\S+')]                                                    # URL


_WIKI = re.compile(r'\[\[[^\]]*\]\]')


def count_anchors(text):
    text = _WIKI.sub(' ', text)          # [[x]] / [[x.md]] is a relation to another memory, never an anchor
    return sum(len(r.findall(text)) for r in ANCHOR_RES)                                                    # URL

def link_dests(line):
    """Markdown inline-link destinations with their start offset: <...> form, balanced parens, title dropped."""
    out, i = [], 0
    while True:
        j = line.find('](', i)
        if j < 0:
            return out
        k = j + 2
        while k < len(line) and line[k] == ' ':
            k += 1
        start = k
        if k < len(line) and line[k] == '<':
            e = line.find('>', k + 1)
            if e < 0:
                i = j + 2; continue
            out.append((line[k + 1:e], start)); i = e + 1; continue
        depth, d = 0, k
        while d < len(line):
            c = line[d]
            if c == '(':
                depth += 1
            elif c == ')':
                if depth == 0:
                    break
                depth -= 1
            elif c in ' \t' and depth == 0:
                break
            d += 1
        if d > k:
            out.append((line[k:d], start))
        i = d
HIT_RE = re.compile(r'^-\s*(\S+)\s*\|\s*(.+?)\s*$')


def indent(line):
    return len(line) - len(line.lstrip(' '))


def parse_entry(path, today):
    """-> dict(status, type, hits[(date,str)], bad[str])"""
    out = {'status': 'OK', 'type': None, 'hits': [], 'bad': [], 'anchors': 0}
    try:
        text = open(path, encoding='utf-8').read()
    except (OSError, UnicodeDecodeError) as e:
        out['status'] = 'READ_ERROR'
        out['bad'].append(type(e).__name__)
        return out
    lines = text.splitlines()
    if not lines or lines[0].strip() != '---':
        out['status'] = 'NO_FRONTMATTER'
        return out
    try:
        end = next(i for i in range(1, len(lines)) if lines[i].rstrip() == '---')
    except StopIteration:
        out['status'] = 'UNTERMINATED_FRONTMATTER'
        return out
    fm = lines[1:end]
    body = "\n".join(lines[end + 1:])
    out['anchors'] = count_anchors(body)
    meta_i = next((i for i, l in enumerate(fm) if indent(l) == 0 and re.match(r'^metadata:\s*$', l)), None)
    if meta_i is None:
        return out
    meta = []
    for l in fm[meta_i + 1:]:
        if l.strip() and not l.lstrip().startswith('#') and indent(l) == 0:
            break
        meta.append(l)
    child = min((indent(l) for l in meta if l.strip() and not l.lstrip().startswith('#')), default=None)
    hits_i = None
    for i, l in enumerate(meta):
        if not l.strip() or l.lstrip().startswith('#'):
            continue
        if indent(l) == child:
            m = re.match(r'^\s*type:\s*(.*)$', l)
            if m and out['type'] is None:
                out['type'] = m.group(1).strip().strip('"\'') or None
            if re.match(r'^\s*hits:', l):
                if re.match(r'^\s*hits:\s*$', l):
                    hits_i = i
                else:
                    out['status'] = 'HITS_MALFORMED'
                    out['bad'].append(l.strip())
    if hits_i is None:
        return out
    hind = indent(meta[hits_i])
    for l in meta[hits_i + 1:]:
        if not l.strip() or l.lstrip().startswith('#'):
            continue
        if indent(l) == hind and l.lstrip().startswith('- '):
            out['bad'].append(l.strip() + '  (indentless list item — indent it under hits:)')
            continue
        if indent(l) <= hind:
            break
        s = l.strip()
        m = HIT_RE.match(s)
        if not m:
            out['bad'].append(s)
            continue
        try:
            d = dt.date.fromisoformat(m.group(1))
        except ValueError:
            out['bad'].append(s)
            continue
        if d > today:
            out['bad'].append(s + '  (future date)')
            continue
        out['hits'].append((d.isoformat(), m.group(2)))
    if out['bad'] and out['status'] == 'OK':
        out['status'] = 'HITS_MALFORMED'
    out['anchors'] += count_anchors("\n".join(t for _, t in out['hits']))   # a hit line may cite the evidence
    return out


def local_target(dest, index_dir):
    if re.match(r'^[a-zA-Z][a-zA-Z0-9+.-]*:', dest):   # https:, mailto:, file: …
        return None
    dest = urllib.parse.unquote(dest.split('#', 1)[0].split('?', 1)[0])
    if not dest.endswith('.md'):
        return None
    return os.path.normpath(dest)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('memory_dir')
    ap.add_argument('--index', default='MEMORY.md')
    ap.add_argument('--today')
    ap.add_argument('--cold-days', type=int, default=30)
    ap.add_argument('--promote-age', type=int, default=3)
    ap.add_argument('--cap', type=int, default=25000)
    ap.add_argument('--json', action='store_true')
    a = ap.parse_args()

    idx_path = os.path.join(a.memory_dir, a.index)
    try:
        names = sorted(f for f in os.listdir(a.memory_dir) if f.endswith('.md') and f != a.index)
        idx_text = open(idx_path, encoding='utf-8').read()
    except (OSError, UnicodeDecodeError) as e:
        print(f'HARNESS-ERROR: {e}', file=sys.stderr)
        return 2
    today = dt.date.fromisoformat(a.today) if a.today else dt.date.today()

    # loader cap: character offset, and the line it falls in (prefix of that line is still loaded)
    cut = None
    if len(idx_text) > a.cap:
        line_no = idx_text.count('\n', 0, a.cap) + 1
        line_start = idx_text.rfind('\n', 0, a.cap) + 1
        cut = {'char': a.cap, 'line': line_no, 'chars_loaded_in_line': a.cap - line_start}
    pos, dups, dangling, offset = {}, [], [], 0
    for i, line in enumerate(idx_text.splitlines(keepends=True), 1):
        for dest, at in link_dests(line):
            t = local_target(dest, a.memory_dir)
            if t is None:
                continue
            if not os.path.isfile(os.path.join(a.memory_dir, t)):
                dangling.append([t, i])
                continue
            if t in pos:
                dups.append([t, pos[t]['line'], i])
            else:
                pos[t] = {'line': i, 'ord': len(pos), 'past_cap': cut is not None and offset + at >= a.cap}
        offset += len(line)

    entries = []
    for n in names:
        p = parse_entry(os.path.join(a.memory_dir, n), today)
        e = {'file': n, 'status': p['status'], 'type': p['type'], 'bad': p['bad'], 'anchors': p['anchors'],
             'index_line': pos.get(n, {}).get('line'), 'index_ord': pos.get(n, {}).get('ord'),
             'past_cap': pos.get(n, {}).get('past_cap', False)}
        if p['hits']:
            days = sorted({d for d, _ in p['hits']})
            e.update(age=len(p['hits']), distinct_days=len(days), last_hit=days[-1])
        else:
            e.update(age=None, distinct_days=None, last_hit=None)   # UNMEASURED, not age 1
        entries.append(e)

    def days_since(d):
        return (today - dt.date.fromisoformat(d)).days

    ok = lambda e: e['status'] == 'OK'
    cold = [e for e in entries if ok(e) and e['type'] != 'user' and e['age'] == 1
            and days_since(e['last_hit']) >= a.cold_days]
    due = [e for e in entries if ok(e) and e['age'] is not None and e['age'] >= a.promote_age
           and e['distinct_days'] >= 2]
    promote = [e for e in due if e['anchors'] > 0]
    promote_held = [e for e in due if e['anchors'] == 0]          # recurring, but cites nothing to promote on
    unanchored = [e for e in entries if ok(e) and e['type'] in ('feedback', 'project') and e['anchors'] == 0]
    cold_set = {e['file'] for e in cold}
    listed = sorted((e for e in entries if e['index_line'] is not None), key=lambda e: e['index_ord'])
    users = [e for e in listed if e['type'] == 'user']
    meas = sorted((e for e in listed if e['type'] != 'user' and ok(e) and e['age'] is not None and e['file'] not in cold_set),
                  key=lambda e: (-e['age'], e['index_ord']))           # age ties keep index (link) order
    rest = [e for e in listed if e['type'] != 'user' and not (ok(e) and e['age'] is not None)]
    order = [e['file'] for e in users + meas + rest]

    rep = {'memory_dir': a.memory_dir, 'today': today.isoformat(), 'files': len(entries),
           'index_chars': len(idx_text), 'cap': a.cap, 'cut': cut,
           'unlisted': [e['file'] for e in entries if e['index_line'] is None],
           'duplicates': dups, 'dangling': dangling,
           'measured': sum(e['age'] is not None for e in entries),
           'unmeasured': sum(e['age'] is None for e in entries),
           'errors': [[e['file'], e['status'], e['bad']] for e in entries if e['status'] != 'OK'],
           'cold': [e['file'] for e in cold],
           'promote': [[e['file'], e['age'], e['distinct_days']] for e in promote],
           'promote_held': [[e['file'], e['age'], e['distinct_days']] for e in promote_held],
           'unanchored': [e['file'] for e in unanchored],
           'order': order, 'entries': entries}
    if a.json:
        print(json.dumps(rep, ensure_ascii=False, indent=1))
        return 0
    cut_s = 'within cap' if cut is None else f"cap cuts at char {cut['char']} = line {cut['line']} (first {cut['chars_loaded_in_line']} chars of it load)"
    print(f"memory GC report — {rep['files']} topic files · index {len(idx_text)} chars, {cut_s} · today {rep['today']}")
    print(f"  index: unlisted {len(rep['unlisted'])} · duplicate lines {len(dups)} · dangling local links {len(dangling)}")
    for t, first, again in dups:
        print(f"    dup       {t}  (lines {first} and {again})")
    for t, ln in dangling:
        print(f"    dangling  {t}  (line {ln})")
    print(f"  errors (not folded into 'no hits'): {len(rep['errors'])}")
    for f, st, bad in rep['errors']:
        print(f"    {st:<24} {f}  {'; '.join(bad)[:120]}")
    print(f"  age: measured {rep['measured']} · UNMEASURED {rep['unmeasured']} (no `hits` — never age 1, never cold)")
    for e in sorted(entries, key=lambda e: (e['age'] is None, -(e['age'] or 0), e['file'])):
        age = 'UNMEAS' if e['age'] is None else f"age {e['age']:>2}"
        print(f"    {age} · {e['type'] or '-'} · {e['status']} · days {e['distinct_days']} · last {e['last_hit']} · "
              f"{'line ' + str(e['index_line']) if e['index_line'] else 'unlisted'}{' (past cap)' if e['past_cap'] else ''} · {e['file']}")
    print(f"  cold (non-user, age 1, no recurrence for ≥ {a.cold_days}d → drop from index only, keep file): {len(cold)}")
    for e in cold:
        print(f"    cold     {e['file']}  last {e['last_hit']}")
    print(f"  promote candidates (age ≥ {a.promote_age} over ≥ 2 days → propose rule/hook, human approves): {len(promote)}")
    for e in promote:
        print(f"    promote  {e['file']}  age {e['age']} · days {e['distinct_days']} · last {e['last_hit']}")
    print(f"  promote held (recurs, but the body cites no evidence anchor — add one before proposing): {len(promote_held)}")
    for e in promote_held:
        print(f"    held     {e['file']}  age {e['age']} · days {e['distinct_days']} · last {e['last_hit']}")
    print(f"  unanchored feedback/project (no commit · #PR · file · arXiv · URL in the body): {len(unanchored)}")
    for e in unanchored[:20]:
        print(f"    unanchored {e['file']}")
    if len(unanchored) > 20:
        print(f"    … {len(unanchored) - 20} more (--json lists all)")
    print(f"  proposed order ({len(order)}):")
    for n, f in enumerate(order, 1):
        print(f"    {n:>3}. {f}")
    print('  read-only: nothing was changed.')
    return 0


if __name__ == '__main__':
    sys.exit(main())

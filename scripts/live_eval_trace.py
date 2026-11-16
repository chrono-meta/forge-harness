#!/usr/bin/env python3
"""Read a `claude -p --output-format stream-json --verbose` trace — stdlib only.

Why (2026-11-14, FH-3): every live-eval scorer grepped the reply TEXT. A reply that says «I will read
CATALOG.md first» and a session that actually read it scored the same, so the 12/12 PASS measured
mentions. The runner now keeps the event stream (`<arm>_r<n>.stream.jsonl`, opt-in `--trace` in
sim_isolated_run.sh), and a probe may declare `behave:` — an observable tool call — next to its
`expect_re`.

Two uses:
  extract <stream.jsonl> <out.txt> <tools.txt>   (runner) write the final result text and the init
      tool/MCP/plugin inventory. Exit 3 on a stream that has no parseable result event — never an empty
      «the session said nothing» (same rule as sim_isolated_run.sh's turns path).
  library: parse_stream(path) · behave_hit(trace, spec) · inventory(trace)

`behave:` grammar (one per probe, value is an ERE, no colon by probes_live.yaml convention):
  read=<re>         some SUCCESSFUL Read (file_path) or Grep (path) call matches — Python `re`, not POSIX
  first_read=<re>   the FIRST Read/Grep/Glob call of the top-level session is that successful call
Credited calls: top-level only (a subagent's call, parent_tool_use_id set, is not the arm's action),
with a matching tool_result that is not is_error (a denied or failed Read did not read anything).
Glob and a Grep `pattern` never count as reading a file. Residual: «first» is emission order; two
calls issued in one parallel batch are not ordered by completion.
"""
import json, re, sys

FILE_TOOLS = ('Read', 'Grep', 'Glob')
READ_KEYS = {'Read': ('file_path',), 'Grep': ('path',)}


def parse_stream(path):
    """{'result': str|None, 'tools': [..]|None, 'mcp': [..]|None, 'calls': [(name, input)]}.
    None when the file is absent/unreadable. A missing init event leaves tools=None (UNKNOWN,
    never «no tools»)."""
    try:
        lines = open(path, encoding='utf-8').read().splitlines()
    except (OSError, UnicodeDecodeError):
        return None
    out = {'result': None, 'tools': None, 'mcp': None, 'plugins': None, 'calls': [], 'damaged': 0, 'ok_ids': set()}
    inits = []   # plugin set of every init event, in order
    for ln in lines:
        ln = ln.strip()
        if not ln:
            continue
        try:
            ev = json.loads(ln)
        except ValueError:
            out['damaged'] += 1   # a skipped line could hide the real first call
            continue
        if not isinstance(ev, dict):
            continue
        t = ev.get('type')
        if t == 'system' and ev.get('subtype') == 'init':
            if isinstance(ev.get('tools'), list):
                out['tools'] = sorted(str(x) for x in ev['tools'])
            if isinstance(ev.get('mcp_servers'), list):
                out['mcp'] = sorted(('%s:%s' % (s.get('name'), s.get('status'))) if isinstance(s, dict) else str(s)
                                    for s in ev['mcp_servers'])
            # Plugins (2026-11-15): arms load the operator's user/builtin/synced plugins from the real
            # HOME, and the set can change between reps (a builtin rolled out mid-run; an auto-update
            # moved a version). name, source and version — never the path (it carries the home directory).
            # Key absent → None (UNKNOWN, never «no plugins»).
            # Each entry is a JSON array [name, source, version] so no separator inside a name can make
            # two different sets render alike; a non-object entry is {"raw": ...}, which never equals
            # an array. A set: duplicates and order do not matter. Every init is kept (see below).
            inits.append(None if not isinstance(ev.get('plugins'), list) else sorted(set(
                json.dumps([p.get('name'), p.get('source'), p.get('version')], ensure_ascii=False)
                if isinstance(p, dict) else json.dumps({'raw': p}, ensure_ascii=False)
                for p in ev['plugins'])))
        elif t == 'assistant':
            if ev.get('parent_tool_use_id'):
                continue
            for c in (ev.get('message') or {}).get('content') or []:
                if isinstance(c, dict) and c.get('type') == 'tool_use':
                    out['calls'].append((str(c.get('name', '')), c.get('input') or {}, c.get('id')))
        elif t == 'user':
            for c in (ev.get('message') or {}).get('content') or []:
                if isinstance(c, dict) and c.get('type') == 'tool_result' and not c.get('is_error'):
                    out['ok_ids'].add(c.get('tool_use_id'))
        elif t == 'result':
            if ev.get('subtype') not in (None, 'success') or ev.get('is_error'):
                out['damaged'] += 1   # an error result is not a finished session
            r = ev.get('result')
            out['result'] = r if isinstance(r, str) else ('' if r is None else json.dumps(r, ensure_ascii=False))
    # One init (the normal single-shot stream): its set. Several inits that agree: that set. Several
    # that disagree: the whole sequence, so a later init can never erase an earlier mismatch (codex R1).
    if inits:
        out['plugins'] = inits[0] if all(x == inits[0] for x in inits) else \
            [json.dumps({'inits': inits}, ensure_ascii=False)]
    return out


def inventory(trace):
    """One comparable string for the arm's tool/MCP/plugin surface, or None when the init event was
    absent. An init without a plugin list reads plugins=UNKNOWN, so it never equals an arm that has one."""
    if trace is None or trace['tools'] is None:
        return None
    plug = 'UNKNOWN' if trace.get('plugins') is None else ','.join(trace['plugins'])
    return 'tools=' + ','.join(trace['tools']) + ' | mcp=' + ','.join(trace['mcp'] or []) + ' | plugins=' + plug


def _read_hit(call, trace, pat):
    name, inp, cid = call
    if cid not in trace['ok_ids'] or not isinstance(inp, dict):
        return False
    return any(pat.search(str(inp[k])) for k in READ_KEYS.get(name, ()) if k in inp)


def parse_behave(spec):
    """'first_read=CATALOG' -> ('first_read', compiled). ValueError on anything else (a typo must
    not silently become «no behaviour declared»)."""
    m = re.match(r'^(read|first_read)=(.+)$', (spec or '').strip())
    if not m:
        raise ValueError('behave %r is not read=<re> or first_read=<re>' % spec)
    return m.group(1), re.compile(m.group(2))


def behave_hit(trace, spec):
    """True/False whether the trace shows the declared action. Caller handles trace None."""
    kind, pat = parse_behave(spec)
    file_calls = [c for c in trace['calls'] if c[0] in FILE_TOOLS]
    if kind == 'first_read':
        return bool(file_calls) and _read_hit(file_calls[0], trace, pat)
    return any(_read_hit(c, trace, pat) for c in file_calls)


def _extract(src, dst_txt, dst_tools):
    tr = parse_stream(src)
    if tr is None or tr['result'] is None or tr['damaged']:
        open(dst_txt, 'w', encoding='utf-8').write('')
        open(dst_tools, 'w', encoding='utf-8').write('UNKNOWN (no result event, error result or damaged stream)\n')
        return 3
    open(dst_txt, 'w', encoding='utf-8').write(tr['result'])
    open(dst_tools, 'w', encoding='utf-8').write((inventory(tr) or 'UNKNOWN (no init event)') + '\n')
    return 0


if __name__ == '__main__':
    if len(sys.argv) == 5 and sys.argv[1] == 'extract':
        sys.exit(_extract(*sys.argv[2:5]))
    print(__doc__, file=sys.stderr)
    sys.exit(2)

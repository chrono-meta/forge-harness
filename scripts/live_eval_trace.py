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
  profile <stream.jsonl>   (runner) one record-only line: top-level tool calls in four bins + first error depth
      (explore · edit · test-run · other). Exit 3 and «trace=UNREADABLE» on a stream it cannot read.
  library: parse_stream(path) · behave_hit(trace, spec) · inventory(trace) · profile_bins(trace)

`behave:` grammar (one per probe, value is an ERE, no colon by probes_live.yaml convention):
  read=<re>         some SUCCESSFUL Read (file_path) or Grep (path) call matches — Python `re`, not POSIX
  first_read=<re>   the FIRST Read/Grep/Glob call of the top-level session is that successful call
  call=<Tool>[|<Tool>…]:<re>   some SUCCESSFUL top-level call to one of those tools whose own field matches:
                    Skill → skill · Agent / Task → subagent_type · Bash → command (2026-11-25: routing probes —
                    did the session decide to invoke an engine, not merely name it). A tool with no field listed
                    here is a BAD-BEHAVE, never «matched nothing».
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
    out = {'result': None, 'tools': None, 'mcp': None, 'plugins': None, 'calls': [], 'damaged': 0, 'ok_ids': set(),
           'res_ids': set(), 'err_ids': set()}
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
                if isinstance(c, dict) and c.get('type') == 'tool_result':
                    out['res_ids'].add(c.get('tool_use_id'))
                    if c.get('is_error'):
                        out['err_ids'].add(c.get('tool_use_id'))
                    else:
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


def inventory_parts(trace):
    """The arm's surface as three sets — the same elements `inventory` joins — so a reader can be told
    WHICH ones differ. None when the init event was absent. plugins=None means UNKNOWN (no list)."""
    if trace is None or trace['tools'] is None:
        return None
    return {'tools': set(trace['tools']), 'mcp': set(trace['mcp'] or []),
            'plugins': set(trace['plugins']) if trace.get('plugins') is not None else None}


def _plugin_label(entry):
    """«source[=version]» for a plugin entry (the JSON array [name, source, version]); the source
    already carries the name in the real init (name@marketplace). Anything else is shown as stored —
    including a multi-init mismatch blob (named residual: it is not broken down per plugin)."""
    try:
        n, src, ver = json.loads(entry)
    except Exception:
        return entry
    src = str(src or '')   # unvalidated init JSON: a non-string source must not raise (it would change rc)
    lab = src if src.startswith('%s@' % n) else ('%s@%s' % (n, src) if src else str(n))
    return lab + ('=%s' % ver if ver else '')


def surface_diff(parts_list):
    """Elements that are not in every arm, per kind — «mcp=a,b; plugins=x@y=1.0» — or '' when the
    sets agree. Nothing is dropped: an UNKNOWN plugin list in some arm is named as such."""
    out = []
    for key in ('tools', 'mcp', 'plugins'):
        sets = [p[key] for p in parts_list]
        unknown = key == 'plugins' and any(x is None for x in sets)
        sets = [x for x in sets if x is not None]
        if unknown and sets:
            out.append('plugins=UNKNOWN in some arm')
        # among the arms whose list is known (codex R1: an UNKNOWN arm must not hide a known difference)
        diff = set().union(*sets) - set.intersection(*sets) if sets else set()
        if diff:
            shown = sorted(_plugin_label(e) for e in diff) if key == 'plugins' else sorted(diff)
            out.append('%s=%s' % (key, ','.join(shown)))
    return '; '.join(out)   # SURFACE_DIFF_RETURN (TR24 mutates this line)


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


CALL_FIELDS = {'Skill': 'skill', 'Agent': 'subagent_type', 'Task': 'subagent_type', 'Bash': 'command'}


def parse_behave(spec):
    """'first_read=CATALOG' -> ('first_read', compiled); 'call=Skill|Agent:x' -> ('call', (('Skill','Agent'), compiled)).
    ValueError on anything else (a typo must not silently become «no behaviour declared»)."""
    spec = (spec or '').strip()
    m = re.match(r'^call=([A-Za-z|]+):(.+)$', spec)
    if m:
        tools = tuple(m.group(1).split('|'))
        bad = [t or '<empty>' for t in tools if t not in CALL_FIELDS]   # «Skill||Agent» or a trailing | is a typo (codex R1)
        if not tools or bad:
            raise ValueError('behave %r names a tool with no matchable field (%s) — known: %s'
                             % (spec, ','.join(bad) or '<none>', ','.join(sorted(CALL_FIELDS))))
        return 'call', (tools, re.compile(m.group(2)))
    m = re.match(r'^(read|first_read)=(.+)$', spec)
    if not m:
        raise ValueError('behave %r is not read=<re>, first_read=<re> or call=<Tool>:<re>' % spec)
    return m.group(1), re.compile(m.group(2))


def behave_hit(trace, spec):
    """True/False whether the trace shows the declared action. Caller handles trace None."""
    kind, pat = parse_behave(spec)
    if kind == 'call':
        tools, rx = pat
        for c in trace['calls']:
            name, inp, cid = c[0], c[1], (c[2] if len(c) > 2 else None)
            if name not in tools or cid not in trace['ok_ids'] or not isinstance(inp, dict):
                continue   # another tool, or a call that errored / never got a result (denied, failed)
            v = inp.get(CALL_FIELDS[name])
            if v is not None and rx.search(str(v)):
                return True
        return False
    file_calls = [c for c in trace['calls'] if c[0] in FILE_TOOLS]
    if kind == 'first_read':
        return bool(file_calls) and _read_hit(file_calls[0], trace, pat)
    return any(_read_hit(c, trace, pat) for c in file_calls)


# ── Behaviour profile (2026-11-17, record only — never read by a scorer) ─────────────────────────
# Two arms with the same PASS rate can still behave differently (arXiv:2611.17440): one may skip
# verification and pass anyway. The profile counts the arm's top-level tool calls in four bins.
# Every EMITTED call counts, successful or not — an attempted test run is still a test run.
# Bash is binned by its command text, in this order (first match wins):
#   test-run  some segment RUNS a test: its command word is a runner (pytest, jest, vitest, npm/pnpm/
#             yarn test, go/cargo test, make test|check, python -m pytest|unittest), or a test
#             script (selfcheck.sh, test_*.sh|py, *_lanes.sh) as the command or as the script
#             argument of bash/sh/zsh/python. Naming a test file as data (`cat test_x.py`) is not a run.
#   edit      a write shape: a redirect to a file (not /dev/null, not >&N), sed -i / -Ei / --in-place,
#             tee, or a segment whose command word is mv cp rm mkdir touch chmod ln
#   explore   the first command after any leading `cd …` is a read-only one (ls cat grep find …,
#             git log/status/diff/show/…, gh … view/list/status/diff/checks)
#   other     anything else — running a script that is not a test lands here
# Named residuals: only the first non-cd segment decides explore, so `ls && ./build.sh` reads as
# explore; a redirect inside a quoted string reads as edit; a test runner named differently from the
# list reads as other; a runner inside a shell string (`bash -c 'pytest'`) or behind a wrapper that
# carries options (`env -i pytest`, `nice -n 10 pytest`, `timeout --signal=TERM 60 pytest`) reads as
# other; `git branch` / `git remote` read as other even when they only list. These are a heuristic's
# edges — after two cross-family rounds each found new ones, they are named here, not chased (a static
# shell-string reader does not converge). The profile is record only, so a misbinned call moves no
# verdict. Binning is calibrated on two hand-labelled nightly runs (17/17 calls, explore and other
# bins) — edit and test-run were exercised on fixtures only.
EXPLORE_TOOLS = ('Read', 'Grep', 'Glob', 'LS', 'NotebookRead', 'WebFetch', 'WebSearch', 'ToolSearch')
EDIT_TOOLS = ('Edit', 'Write', 'MultiEdit', 'NotebookEdit')
_TEST_SCRIPT_RE = re.compile(r'^(?:selfcheck\.sh|test_[\w.-]*\.(?:sh|py)|[\w.-]*_lanes?\.sh)$')
_TEST_RUNNERS = ('pytest', 'py.test', 'jest', 'vitest')
_SHELLS = ('bash', 'sh', 'zsh', 'python', 'python3')
_WRITE_RE = re.compile(r'>>?(?!&)\s*(?!/dev/null\b)[^\s&|;>]|\btee\b')
_EDIT_WORDS = ('mv', 'cp', 'rm', 'mkdir', 'touch', 'chmod', 'ln')
_EXPLORE_WORDS = ('ls', 'cat', 'head', 'tail', 'grep', 'egrep', 'rg', 'find', 'wc', 'tree', 'stat', 'file',
                  'pwd', 'which', 'echo', 'printf', 'less', 'diff', 'du', 'sort', 'uniq', 'cut', 'sed', 'awk',
                  'jq', 'readlink', 'realpath', 'basename', 'dirname', 'date', 'id', 'whoami')
_GIT_READ = ('log', 'status', 'diff', 'show', 'ls-files', 'ls-tree', 'blame',
             'rev-parse', 'grep', 'describe', 'shortlog', 'reflog')
_GH_READ = ('view', 'list', 'status', 'diff', 'checks')
PROFILE_BINS = ('explore', 'edit', 'test-run', 'other')


def _segments(cmd):
    """Each segment's words, with leading VAR=value assignments and the wrappers env / time / nice /
    exec / command / timeout <secs> dropped, so the command word is the one that runs; empty
    segments skipped."""
    for seg in re.split(r'&&|\|\||;|\n|\|', cmd):
        words = seg.split()
        while words:
            if re.match(r'^[A-Za-z_][A-Za-z0-9_]*=', words[0]) or words[0] in ('env', 'time', 'nice', 'exec', 'command'):
                words = words[1:]
            elif words[0] == 'timeout' and len(words) > 1:
                words = words[2:]
            else:
                break
        if words:
            yield words


def _runs_test(w):
    base = lambda x: x.rsplit('/', 1)[-1]
    if w[0] in _TEST_RUNNERS or _TEST_SCRIPT_RE.match(base(w[0])):
        return True
    if w[0] in ('npm', 'pnpm', 'yarn') and 'test' in w[1:3]:
        return True
    if (w[0] in ('go', 'cargo') and w[1:2] == ['test']) or (w[0] == 'make' and w[1:2] in (['test'], ['check'])):
        return True
    if w[0] in _SHELLS:
        args = [x for x in w[1:] if not x.startswith('-')]
        if w[0].startswith('python') and '-m' in w and w[w.index('-m') + 1:w.index('-m') + 2] in (['pytest'], ['unittest']):
            return True
        return bool(args) and bool(_TEST_SCRIPT_RE.match(base(args[0])))
    return False


def _sed_in_place(w):
    return w[0] == 'sed' and any(x.startswith('--in-place') or re.match(r'^-[a-zA-Z]*i', x) for x in w[1:])


def _bash_bin(cmd):
    cmd = str(cmd or '')
    segs = list(_segments(cmd))
    if any(_runs_test(w) for w in segs):
        return 'test-run'
    if _WRITE_RE.search(cmd) or any(w[0] in _EDIT_WORDS or _sed_in_place(w) for w in segs):
        return 'edit'
    first = next((w for w in segs if w[0] != 'cd'), None)
    if not first:
        return 'other'
    if first[0] in _EXPLORE_WORDS:
        return 'explore'
    if first[0] == 'git' and any(w in _GIT_READ for w in first[1:3] if not w.startswith('-')):
        return 'explore'
    if first[0] == 'gh' and any(w in _GH_READ for w in first[1:4]):
        return 'explore'
    return 'other'


def profile_bins(trace):
    """{bin: count} over the top-level calls of a parsed trace."""
    out = dict.fromkeys(PROFILE_BINS, 0)
    for name, inp, _ in trace['calls']:
        if name in EXPLORE_TOOLS:
            b = 'explore'
        elif name in EDIT_TOOLS:
            b = 'edit'
        elif name == 'Bash':
            b = _bash_bin((inp or {}).get('command') if isinstance(inp, dict) else '')
        else:
            b = 'other'
        out[b] += 1
    return out


def first_error(trace):
    """1-based position of the first top-level call whose result is an error · 'none' when every top-level call
    has a result and none is an error · 'unknown' when a call has no result before that (not measured ≠ no error).
    Record only (AQ-20261101-2): a final PASS can hide a run that hit errors early and recovered by luck."""
    for i, (_, _, cid) in enumerate(trace['calls'], 1):
        if cid in trace['err_ids']:
            return str(i)
        if cid not in trace['res_ids']:
            return 'unknown'
    return 'none'


def _profile(src):
    """One line for the report. A stream that cannot be read says so (exit 3) — never counts of 0.
    A stream with no result event or damaged lines keeps its counts and says they are a lower bound."""
    tr = parse_stream(src)
    if tr is None:
        print('trace=UNREADABLE')
        return 3
    p = profile_bins(tr)
    line = ' '.join('%s=%d' % (b, p[b]) for b in PROFILE_BINS) + ' total=%d' % sum(p.values())
    line += ' first_error=%s' % first_error(tr)
    flags = []
    if tr['result'] is None:
        flags.append('result=MISSING')
    if tr['damaged']:
        flags.append('damaged=%d' % tr['damaged'])
    if flags:
        line += ' ' + ' '.join(flags) + ' (counts are a lower bound)'
    print(line)
    return 0


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
    if len(sys.argv) == 3 and sys.argv[1] == 'profile':
        sys.exit(_profile(sys.argv[2]))
    print(__doc__, file=sys.stderr)
    sys.exit(2)

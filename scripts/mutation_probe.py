#!/usr/bin/env python3
"""mutation_probe.py — operator-generated mutants on a gate's VERDICT CHANNEL, run against its lanes.

WHY THIS EXISTS (2026-10-07). `revert_probe.sh` asks «does the lane go red when *the author's chosen*
change is undone» — one mutant, picked by the person who wrote the lane, so it shares the lane's blind
spot. This tool generates the mutants mechanically (comparison flips, boundary shifts, failure codes
forced to 0) and reports which ones the lane suite does NOT notice. A survivor can expose an untested boundary even when the suite stays green. FH's
`new-code-anchor` checks whether added files have executable anchors; this tool asks whether
those anchors notice mechanically selected perturbations. 6-axis placement: an extension of ⓕ (revert) —
`fh_three_layer_canon.md §1-a-2`.

v6 (2026-10-07) — THE GENERATOR WAS REBUILT, NOT PATCHED. Six blind detectors (same family, inputs
varied) reproduced dozens of generator defects in v5 — comments, quotes, heredocs, word boundaries,
line splitting — all from reading bash/python with per-line regexes. Two structural changes:
  · python: the standard `tokenize` module. Only OP / NAME / NUMBER tokens are ever mutated, so
    comments, strings and docstrings are excluded by token type, not by a guess.
  · bash: one character-level scanner over the whole file with real state — single/double/ANSI-C
    quotes across lines, `#` only at a word start, heredocs queued per line with an exact terminator
    (`<<-` strips tabs only), `$( )` / `(( ))` / `$(( ))` / `$[ ]` / `${ }` nesting, here-strings.
    Mutations happen only on WORDS the scanner classified as code, and only in context: test operators
    inside `[ ]` / `[[ ]]` / `test …` (a word at command position), `< <= > >= == !=` inside an
    arithmetic context, `exit N` / `return N` / `FAILED=1`-style assignments at command position.
    Embedded python is recognised only as `python… -c '…'` or a heredoc on a `python… -` command, both
    in the SAME simple command and outside comments/quotes — and is then handed to `tokenize`.

v7 (2026-10-08) — FAIL-CLOSED. v6 still guessed where it was unsure; v7 refuses instead. A region the scanner
cannot classify with certainty — `((` / `$((` that bash re-reads as nested subshells, an unclosed quote or frame,
an unreadable heredoc delimiter — is BLOCKED and named in a `note:`. Double quotes, `${ }` and backticks are
scanned as real frames (nested quotes no longer flip polarity) and everything inside them is quiet. A heredoc
delimiter is a whole shell word (`<<END-X`), `<<-` bodies lose their tabs before python sees them, a `case`
pattern is data (nested `case` too), a keyword in argument position is an argument, `exit 1>&2` is a
redirect, a test operator is mutated only in OPERATOR position (`[ "$1" = -eq ]` has an operand `-eq`),
array literals `x=( … )` and `<( … )` are data, and a `[` that never closes poisons nothing after it. The remaining
misses are the fail-closed trade — see «Named residuals» and the shipped regression lanes.

SCOPE — verdict channel only:
  bash   : -eq↔-ne · -lt→-le · -le→-lt · -gt→-ge · -ge→-gt · == ↔ != · = → != (`==` is not generated for
           a `#!/bin/sh` subject — not POSIX) · arithmetic < <= > >= == != · exit N→0 · return N→0 ·
           FAILED/FAIL/failed/fail/rc=1 → 0
  python : < <= > >= == != · is ↔ is not · sys.exit(N)/exit(N)/quit(N)/os._exit(N)/SystemExit(N) → 0
           (N may be -N) · return N / -N / (N) → return 0 · return True ↔ False · `x = True` ↔ False at
           statement level only (never a keyword argument, a default, or a lambda) — each only when it ends
           the statement. A literal equal to zero (0x0, 0.0, 0j …) is never «mutated» to 0.
  embedded python: `python… -c '…'` when -c (alone or as `-Sc`) is an INTERPRETER option, or a heredoc on a
           python command reading its script from stdin (`python3 -` or no script argument). A heredoc the
           shell expands (unquoted delimiter with $ ` \ in the body) is not mutated.
  Languages: bash and POSIX sh. zsh / ksh / mksh are other grammars and are refused (exit 2), not guessed.
  Named residuals: python `in` / `not` / `and` / `or` are not mutated · f-string bodies on python < 3.12
  are one STRING token · code inside double quotes, `${ }` or backticks is not mutated (it IS code — this is
  the fail-closed trade) · `SystemExit(code=N)` keyword form is not mutated · an embedded python block that
  does not compile on its own is skipped (reported).

🟥 THE OUTPUT IS A LIST OF QUESTIONS, NOT A SCORE. A surviving mutant is EQUIVALENT · BOUNDARY ·
   REDUNDANT · GAP — a reviewer triages it. No `--fail-under`: coverage and mutation metrics are context-dependent for LLM-generated tests
   (https://arxiv.org/abs/2607.22880); that study does not establish a universal loss of correlation
   after controlling suite size. §Mechanization Boundary forbids promoting a verdict by its score.

SAFETY OF THE IN-PLACE EDIT (lanes find their subject by repo path, as with revert_probe.sh):
  · original bytes + mode are read and backed up BEFORE the baseline; a lane that writes, deletes or
    replaces its subject — at baseline OR during any mutant — makes the run «cannot judge»
  · every write goes through ONE file descriptor opened on the original inode (O_NOFOLLOW); the path is
    checked after each lane run and never written through: a symlink / directory in its place → exit 3,
    a regular file with a new inode (or nothing) → a FRESH file with the original bytes is renamed into
    place — never written into, since that inode may be anything the lane linked there — and the run is
    «cannot judge»
  · locks: one namespace keyed by INODE, shared by every user (/tmp/mutation_probe.locks/, sticky) —
    subject and lane alike, so another probe on the same file under any name, any uid, or with the roles
    swapped exits 2. (v6 kept per-uid, per-role locks: crossed probes both ran.) The lock directory must
    be sticky and owned by root or you; if another user created it, every other user gets exit 2 — a
    refusal, not a bypass (named residual). The subject is re-read under the lock: a difference → 2.
  · the backup is keyed by the subject's real path AND its inode; a leftover (SIGKILL, power loss) blocks
    the next run through either and names itself
  · a POSITIVE CONTROL runs after the baseline: the subject replaced by one that exits at once (113). A
    lane that stays green on it never runs the subject — every mutant would «survive» — so exit 2
  · after the last mutant the lane runs ONCE MORE on the restored original; it must be green and leave
    the subject alone — whatever it built from the last mutant is rebuilt from the original
  · Linux: the probe is a child subreaper, so lane descendants that escape with setsid are killed after
    every run (elsewhere: named residual, reported)
  · the lane is executed by the KERNEL when it is executable (its shebang gets one argument, as the
    kernel gives it); otherwise by a Linux-style single-argument shebang fallback, else python3/bash
  · supported asynchronous terminating signals (including SIGABRT) restore and kill the lane's
    process group and temp dirs; SIGKILL, power loss and synchronous hardware faults are not recoverable
  · every write gets a NEW whole second of mtime, later than the end of the previous lane run, never in
    the future: a same-size mutant must not share a pyc key with the previous write, and nothing a lane
    built may look as new as the next write. A subject whose mtime is already in the future is refused. The subject's own pycs (any interpreter tag, incl. unchecked-hash) are deleted
    before the baseline and after the last restore
  · syntax checks run in-process (`compile`) or via `bash -n`/`sh -n` on a private temp file — no
    `python -m` (a module in the cwd could hijack it)

USAGE
  python3 scripts/mutation_probe.py <subject> <lane-suite> [--timeout SEC] [--max N] [--json OUT]
  python3 scripts/mutation_probe.py <subject> --list     # enumerate mutants; NOT a measurement

  The lane is run by its shebang, else `python3` for *.py, else `bash`, from the current directory,
  stdin closed, once on the unmodified subject (baseline) and once per mutant.

EXIT
  0 = measured — at least one mutant was KILLED or SURVIVED (survivors are printed; still 0: this is a
      review surface, not a gate). With --list: mutants were enumerated (nothing was measured).
  2 = cannot judge — usage error · subject/lane missing or the same file · unsupported language ·
      non-UTF-8 · subject not writable (mode bits, also for root) · mtime in the future · another probe
      holds the subject or the lane · a leftover backup · bad --timeout / --json · baseline red, timed
      out or not runnable · positive control survived · a lane that writes or replaces its subject ·
      the final run on the original not green · no mutants · nothing measured. --json is written ONLY
      for exit 0 (and carries "measured": true).
  3 = RESTORE FAILED — the subject may still hold a mutant (or is no longer a file). Loud, never folded
      into a verdict.
"""
import argparse, ast, fcntl, hashlib, io, json, os, re, shlex, shutil, signal, stat, subprocess, sys, tempfile
import time, tokenize

PY_INTERP = re.compile(r'^python(\d+(\.\d+)*)?$')
SH_INTERP = {'sh', 'dash', 'ash', 'posh'}
BASH_INTERP = {'bash'} | SH_INTERP     # zsh/ksh/mksh: other grammars — refused, not guessed (v7)

# ───────────────────────────── language ─────────────────────────────

def shebang_split(first):
    """What the Linux kernel does with a `#!` line: the interpreter, then AT MOST ONE argument — the rest
    of the line, unsplit. (shlex is not what runs the file.)"""
    body = first[2:].strip(' \t\r')
    if not body:
        return []
    parts = body.split(None, 1)
    return [parts[0]] + ([parts[1].strip()] if len(parts) > 1 and parts[1].strip() else [])


def shebang_interp(text):
    first = text.split('\n', 1)[0]
    if not first.startswith('#!'):
        return None
    parts = shebang_split(first)
    if not parts:
        return None
    name = os.path.basename(parts[0])
    if name == 'env':
        rest = [p for p in ' '.join(parts[1:]).split() if not p.startswith('-')]
        name = os.path.basename(rest[0]) if rest else ''
    return name


def language(path, text):
    """('python'|'bash', is_posix_sh) or (None, False)."""
    ext = os.path.splitext(path)[1]
    interp = shebang_interp(text)
    if ext == '.py' or (interp and PY_INTERP.match(interp)):
        return 'python', False
    if interp and interp not in BASH_INTERP and not PY_INTERP.match(interp):
        return None, False
    if ext in ('.sh', '.bash') or (interp in BASH_INTERP):
        return 'bash', interp in SH_INTERP
    return None, False

# ───────────────────────────── python (tokenize) ─────────────────────────────

PY_CMP = {'<': '<=', '<=': '<', '>': '>=', '>=': '>', '==': '!=', '!=': '=='}
EXIT_CALLEES = {('sys', 'exit'), ('', 'exit'), ('', 'quit'), ('os', '_exit'), ('', 'SystemExit')}
PY_SKIP = (tokenize.NL, tokenize.COMMENT, tokenize.INDENT, tokenize.DEDENT)


def py_zero(s):
    """True when the literal is zero — or when we cannot tell (fail-closed: unknown → not mutated)."""
    try:
        return ast.literal_eval(s) == 0
    except (ValueError, SyntaxError):
        return True


def py_mutants(src, posmap=None):
    """Mutants for python source `src`. `posmap(k)` maps an index of `src` to a file offset
    (identity by default). Raises on untokenizable source."""
    starts = [0]
    for i, c in enumerate(src):
        if c == '\n':
            starts.append(i + 1)

    def off(rc):
        k = starts[rc[0] - 1] + rc[1]
        return posmap(k) if posmap else k
    toks, depth, lam = [], 0, False
    for t in tokenize.generate_tokens(io.StringIO(src).readline):
        if t.type in PY_SKIP:
            continue
        if t.type in (tokenize.NEWLINE, tokenize.ENDMARKER) or (t.type == tokenize.OP and t.string == ';' and depth == 0):
            if toks:
                toks[-1]['eol'] = True
            lam = False
            continue
        if t.type == tokenize.NAME and t.string == 'lambda':
            lam = True
        d0 = depth
        if t.type == tokenize.OP and t.string in '([{':
            depth += 1
        elif t.type == tokenize.OP and t.string in ')]}':
            depth = max(0, depth - 1)
        toks.append({'t': t, 'depth': d0, 'lam': lam, 'eol': False})

    def is_(k, typ, s=None):
        return 0 <= k < len(toks) and toks[k]['t'].type == typ and (s is None or toks[k]['t'].string == s)

    def operand(k):
        """An exit-status operand starting at k: N · -N · (N) · (-N). Returns (end_index, text) or None."""
        j, neg = k, False
        par = is_(j, tokenize.OP, '(')
        if par:
            j += 1
        if is_(j, tokenize.OP, '-'):
            neg, j = True, j + 1
        if not is_(j, tokenize.NUMBER):
            return None
        num = toks[j]['t'].string
        if par:
            if not is_(j + 1, tokenize.OP, ')'):
                return None
            j += 1
        if py_zero(num):
            return None
        return j, src[starts[toks[k]['t'].start[0] - 1] + toks[k]['t'].start[1]:
                      starts[toks[j]['t'].end[0] - 1] + toks[j]['t'].end[1]]

    out = []
    for i, e in enumerate(toks):
        t = e['t']
        prev = toks[i - 1]['t'] if i else None
        if t.type == tokenize.OP and t.string in PY_CMP:
            out.append((off(t.start), off(t.end), PY_CMP[t.string], '%s→%s' % (t.string, PY_CMP[t.string])))
        elif t.type == tokenize.NAME and t.string == 'is':
            if is_(i + 1, tokenize.NAME, 'not'):
                out.append((off(t.start), off(toks[i + 1]['t'].end), 'is', 'is not→is'))
            else:
                out.append((off(t.start), off(t.end), 'is not', 'is→is not'))
        elif t.type == tokenize.NAME and t.string in ('True', 'False') and prev is not None and e['eol'] and (
                (prev.type == tokenize.NAME and prev.string == 'return') or
                (prev.type == tokenize.OP and prev.string == '=' and e['depth'] == 0 and not e['lam'])):
            new = 'False' if t.string == 'True' else 'True'
            out.append((off(t.start), off(t.end), new, '%s→%s' % (t.string, new)))
        elif t.type == tokenize.NAME and t.string == 'return':
            r = operand(i + 1)
            if r and toks[r[0]]['eol']:
                out.append((off(toks[i + 1]['t'].start), off(toks[r[0]]['t'].end), '0',
                            'return %s→return 0' % r[1]))
        elif t.type == tokenize.OP and t.string == '(' and i >= 1 and is_(i - 1, tokenize.NAME):
            callee = toks[i - 1]['t'].string
            owner = toks[i - 3]['t'].string if i >= 3 and is_(i - 2, tokenize.OP, '.') else ''
            if (owner, callee) not in EXIT_CALLEES:
                continue
            j = i + 1
            if is_(j, tokenize.OP, '-'):
                j += 1
            if not is_(j, tokenize.NUMBER) or not is_(j + 1, tokenize.OP, ')') or py_zero(toks[j]['t'].string):
                continue
            label = ('%s.%s' % (owner, callee)) if owner else callee
            s0, s1 = off(toks[i + 1]['t'].start), off(toks[j]['t'].end)
            arg = src[starts[toks[i + 1]['t'].start[0] - 1] + toks[i + 1]['t'].start[1]:
                      starts[toks[j]['t'].end[0] - 1] + toks[j]['t'].end[1]]
            out.append((s0, s1, '0', '%s(%s)→%s(0)' % (label, arg, label)))
    return out

# ───────────────────────────── bash (character-level scanner, fail-closed) ─────────────────────────────

TEST_SWAP = {'-eq': '-ne', '-ne': '-eq', '-lt': '-le', '-le': '-lt', '-gt': '-ge', '-ge': '-gt',
             '==': '!=', '!=': '==', '=': '!='}
TEST_SWAP_POSIX = dict(TEST_SWAP, **{'!=': '='})
CMD_KEYWORDS = {'then', 'do', 'else', 'elif', 'if', 'while', 'until', '!', '{', 'time', 'exec', 'command'}
ASSIGN_LEAD = {'local', 'export', 'declare', 'readonly', 'typeset'}
FAIL_ASSIGN = re.compile(r'^(FAILED|FAIL|failed|fail|rc)=1$')
ARITH_OP = re.compile(r'(?<![<>=!])(<=|>=|==|!=|<|>)(?![<>=])')
ARITH_ONLY = True   # the revert probe flips this — arithmetic operators outside (( )) are redirects
WORD_END = set(' \t\n;&|()<>')
PY_FLAG_ONLY = set('bBdEhiIOqsSuvVxPR')    # python options that take no argument
PY_FLAG_ARG = {'-W', '-X', '-Q'}           # options whose argument is the next word
TERMINATOR_OK = re.compile(r'^[ \t]*(?:\d*[<>]&?[ \t]*\S+[ \t]*)*(?:$|\||&&|;|&|\))')


class BashScan:
    """Classify every character of a bash file. Words are collected only at code level; every region
    the scanner cannot classify with certainty is BLOCKED (no mutation there) and named in a note."""

    def __init__(self, text):
        self.t = text
        self.n = len(text)
        self.code = [False] * self.n          # character is shell code (not comment/string/heredoc data)
        self.arith = [False] * self.n         # character is inside an arithmetic context
        self.block = [False] * self.n         # fail-closed: never mutate here
        self.words = []                       # (start, end, text, at_command, in_test, data)
        self.py = []                          # (start, end, strip_tabs) of embedded python source
        self.notes = []
        self._scan()

    # ── helpers ──
    def _line(self, i):
        return self.t.count('\n', 0, i) + 1

    def _uncertain(self, s, e, why):
        for k in range(max(0, s), min(self.n, e)):
            self.block[k] = True
        self.notes.append('L%d: %s — not mutated (fail-closed)' % (self._line(s), why))

    def _paren_extent(self, i):
        """From i (just after an opening paren), find the matching close at depth 0.
        Returns (index_of_close, closes_as_double) or (None, False) at EOF."""
        t, n, depth, j = self.t, self.n, 0, i
        while j < n:
            c = t[j]
            if c == '\\':
                j += 2
                continue
            if c in '\'"`':
                k = j + 1
                while k < n and t[k] != c:
                    k += 2 if (c != "'" and t[k] == '\\') else 1
                j = k + 1
                continue
            if c == '(':
                depth += 1
            elif c == ')':
                if depth == 0:
                    return j, t.startswith('))', j)
                depth -= 1
            j += 1
        return None, False

    @staticmethod
    def _frame(kind, start, quiet, closer=None):
        return {'kind': kind, 'start': start, 'quiet': quiet, 'closer': closer, 'cmd': [], 'at_cmd': True,
                'test': None, 'cur': None, 'cur_bad': False, 'assign_ok': False, 'data_next': False,
                'case': None, 'case_outer': [], 'depth': 0, 'bdepth': 0, 'fn': 0,
                'tpos': 0, 'twords': []}

    # ── main loop ──
    def _scan(self):
        t, n = self.t, self.n
        stack = [self._frame('code', 0, False)]
        pending = []      # heredocs queued on this line: (delim, strip_tabs, is_py, expands)
        i = 0
        while i < n:
            f = stack[-1]
            c = t[i]
            k = f['kind']
            if k == 'dq':                       # "…" — data; nested expansions are scanned but quiet
                if c == '\\':
                    i += 2
                elif c == '"':
                    stack.pop()
                    i += 1
                elif c == '`':
                    stack.append(self._frame('bq', i, True))
                    i += 1
                elif c == '$' and i + 1 < n and t[i + 1] in '([':
                    i = self._open_dollar(stack, i, True)
                elif t.startswith('${', i):
                    stack.append(self._frame('brace', i, True))
                    i += 2
                else:
                    i += 1
                continue
            if k == 'bq':
                if c == '\\':
                    i += 2
                elif c == '`':
                    stack.pop()
                    i += 1
                else:
                    i += 1
                continue
            if k == 'brace':                    # ${ … } — quotes inside protect the closing brace
                if c == '\\':
                    i += 2
                elif c == '}':
                    stack.pop()
                    i += 1
                elif c == "'":
                    j = t.find("'", i + 1)
                    i = n if j == -1 else j + 1
                elif c == '"':
                    stack.append(self._frame('dq', i, True))
                    i += 1
                elif c == '$' and i + 1 < n and t[i + 1] in '([':
                    i = self._open_dollar(stack, i, True)
                elif t.startswith('${', i):
                    stack.append(self._frame('brace', i, True))
                    i += 2
                else:
                    i += 1
                continue
            if k == 'arith':
                if c == '\\':
                    i += 2
                    continue
                if c == '"':
                    stack.append(self._frame('dq', i, True))
                    i += 1
                    continue
                if c == "'":
                    j = t.find("'", i + 1)
                    i = n if j == -1 else j + 1
                    continue
                if c == '$' and i + 1 < n and t[i + 1] in '([':
                    i = self._open_dollar(stack, i, f['quiet'])
                    continue
                if t.startswith('${', i):
                    stack.append(self._frame('brace', i, True))
                    i += 2
                    continue
                if c == '(':
                    f['depth'] += 1
                elif c == ')' and f['depth'] > 0:
                    f['depth'] -= 1
                elif c == '[':
                    f['bdepth'] += 1
                elif c == ']' and f['bdepth'] > 0:
                    f['bdepth'] -= 1
                elif f['closer'] == '))' and t.startswith('))', i) and f['depth'] == 0:
                    stack.pop()
                    i += 2
                    continue
                elif f['closer'] == ']' and c == ']' and f['bdepth'] == 0 and f['depth'] == 0:
                    stack.pop()
                    i += 1
                    continue
                self.code[i] = True
                self.arith[i] = True
                if f['quiet']:
                    self.block[i] = True
                i += 1
                continue
            # ── code frame ──
            if c == '\\' and i + 1 < n:
                if t[i + 1] == '\n':           # line continuation
                    if f['cur'] is not None:
                        f['cur_bad'] = True
                    i += 2
                    continue
                self._word_char(f, i)
                self.code[i] = self.code[i + 1] = True
                i += 2
                continue
            if c == '#' and f['cur'] is None:
                j = t.find('\n', i)
                i = n if j == -1 else j
                continue
            if c == "'" or t.startswith("$'", i):
                ansi = c == '$'
                q0 = i + (2 if ansi else 1)
                j = q0
                while j < n and t[j] != "'":
                    j += 2 if (ansi and t[j] == '\\') else 1
                if j >= n:
                    self._uncertain(i, n, 'unterminated single quote')
                    i = n
                    continue
                if not ansi and f['cur'] is None and not f['quiet'] and not f['data_next'] and self._python_c(f) and \
                        (j + 1 >= n or t[j + 1] in WORD_END):
                    self.py.append((q0, j, False))
                self._word_char(f, i)
                i = j + 1
                continue
            if c == '"':
                self._word_char(f, i)
                stack.append(self._frame('dq', i, True))
                i += 1
                continue
            if c == '`':
                self._word_char(f, i)
                stack.append(self._frame('bq', i, True))
                i += 1
                continue
            if c == '$' and i + 1 < n and t[i + 1] in '([':
                self._word_char(f, i)
                i = self._open_dollar(stack, i, f['quiet'])
                continue
            if t.startswith('${', i):
                self._word_char(f, i)
                stack.append(self._frame('brace', i, True))
                i += 2
                continue
            if t.startswith('((', i) and f['cur'] is None:
                close, double = self._paren_extent(i + 2)
                if close is not None and double:
                    stack.append(self._frame('arith', i, f['quiet'], '))'))
                    i += 2
                    continue
                # bash reads this as nested subshells — and so do we, but we do not trust our reading
                outer, _ = self._paren_extent(i + 1)
                self._uncertain(i, n if outer is None else outer + 1, '«((» that is not arithmetic (nested subshell)')
                self._end_word(f, i)
                self._separator(f)
                i += 1
                continue
            if t.startswith('<<<', i):
                self._end_word(f, i)
                f['data_next'] = True
                i += 3
                continue
            if t.startswith('<<', i):
                self._end_word(f, i)
                i = self._heredoc_op(f, i, pending)
                continue
            if c == '\n':
                self._end_word(f, i)
                self._separator(f)
                i += 1
                if pending:
                    i = self._heredoc_bodies(i, pending)
                    pending = []
                continue
            if c in '<>' and i + 1 < n and t[i + 1] == '(':          # <( … ) / >( … ): a word, code inside (quiet)
                self._word_char(f, i)
                stack.append(self._frame('code', i, True, ')'))
                i += 2
                continue
            if c == '(' and f['cur'] is not None and t[f['cur']:i].endswith('='):   # x=( … ) array: data
                close, _ = self._paren_extent(i + 1)
                end = n if close is None else close + 1
                for k2 in range(i, end):
                    self.block[k2] = True
                if close is None:
                    self._uncertain(i, n, 'unclosed array literal')
                i = end
                continue
            if f['test'] == ']]' and c in '&|':                       # [[ a && b ]]: internal, not a separator
                self._end_word(f, i)
                f['tpos'] = 0
                self.code[i] = True
                i += 1
                continue
            if f['case'] == 'body' and (t.startswith(';;', i) or t.startswith(';&', i)):
                self._end_word(f, i)
                self._separator(f)
                f['case'] = 'pattern'
                i += 3 if t.startswith(';;&', i) else 2
                continue
            if c == ')' and f['case'] == 'pattern':
                self._end_word(f, i)
                self._separator(f)
                f['case'] = 'body'
                self.code[i] = True
                i += 1
                continue
            if c == ')' and f['closer'] == ')' and f['depth'] == 0:
                self._end_word(f, i)
                stack.pop()
                i += 1
                continue
            if f['test'] is None and (c in '<>' or t.startswith('&>', i)):
                # A descriptor adjacent to a redirect is not the command. Its operand is data,
                # even if it looks like a failure assignment; preserve command position after it.
                if f['cur'] is not None and t[f['cur']:i].isdigit():
                    f['cur'], f['cur_bad'] = None, False
                else:
                    self._end_word(f, i)
                op = re.match(r'(?:&>>|&>|>>|<>|>&|<&|>\||>|<)', t[i:]).group()
                for offset in range(i, i + len(op)):
                    self.code[offset] = True
                f['data_next'] = True
                i += len(op)
                continue
            if c in ';&|()':
                self._end_word(f, i)
                if c == '(' and f['closer'] == ')':
                    f['depth'] += 1
                elif c == ')' and f['depth'] > 0:
                    f['depth'] -= 1
                if not (c == '(' and f['case'] == 'pattern'):
                    self._separator(f)
                self.code[i] = True
                i += 1
                continue
            if c in ' \t':
                self._end_word(f, i)
                i += 1
                continue
            if c in '<>':
                self._end_word(f, i)
                self.code[i] = True
                i += 1
                continue
            self._word_char(f, i)
            self.code[i] = True
            if f['quiet']:
                self.block[i] = True
            i += 1
        for fr in stack[1:]:
            self._uncertain(fr['start'], n, 'unclosed %s' % fr['kind'])
        self._end_word(stack[0], n)

    def _open_dollar(self, stack, i, quiet):
        """At `$(` · `$((` · `$[` — push the right frame and return the new index."""
        t = self.t
        if t.startswith('$[', i):
            stack.append(self._frame('arith', i, quiet, ']'))
            return i + 2
        if t.startswith('$((', i):
            close, double = self._paren_extent(i + 3)
            if close is not None and double:
                stack.append(self._frame('arith', i, quiet, '))'))
                return i + 3
            outer, _ = self._paren_extent(i + 2)
            self._uncertain(i, self.n if outer is None else outer + 1, '«$((» that is not arithmetic')
            fr = self._frame('code', i, True, ')')
            stack.append(fr)
            return i + 2
        stack.append(self._frame('code', i, quiet, ')'))
        return i + 2

    def _heredoc_op(self, f, i, pending):
        t, n = self.t, self.n
        strip = t.startswith('<<-', i)
        j = i + (3 if strip else 2)
        while j < n and t[j] in ' \t':
            j += 1
        delim, quoted = [], False
        while j < n and t[j] not in WORD_END:
            c = t[j]
            if c == '\\' and j + 1 < n:
                delim.append(t[j + 1])
                quoted = True
                j += 2
            elif c in '\'"':
                k = t.find(c, j + 1)
                if k == -1:
                    break
                delim.append(t[j + 1:k])
                quoted = True
                j = k + 1
            elif c in '$`':
                delim = []                    # an expanding delimiter — we do not model it
                break
            else:
                delim.append(c)
                j += 1
        d = ''.join(delim)
        if not d:
            self._uncertain(i, n, 'heredoc delimiter we cannot read')
            return n
        rest = t[j:t.find('\n', j) if t.find('\n', j) != -1 else n]
        is_py = not f['quiet'] and self._python_stdin(f) and TERMINATOR_OK.match(rest) is not None
        pending.append((d, strip, is_py, not quoted))
        return j

    @staticmethod
    def _word_char(f, i):
        if f['cur'] is None:
            f['cur'] = i

    def _end_word(self, f, e):
        if f['cur'] is None:
            return
        s = f['cur']
        bad = f['cur_bad']
        f['cur'], f['cur_bad'] = None, False
        word = self.t[s:e]
        redirect_operand = f['data_next']
        data = bad or redirect_operand or f['quiet']
        f['data_next'] = False
        if redirect_operand:
            self.words.append((s, e, word, False, False, True))
            return
        if f['case'] in ('word', 'in'):
            f['case'] = 'in' if f['case'] == 'word' else ('pattern' if word == 'in' else None)
            self.words.append((s, e, word, False, False, True))
            return
        if f['case'] == 'pattern':
            if word == 'esac':
                f['case'] = f['case_outer'].pop() if f['case_outer'] else None
            self.words.append((s, e, word, False, False, True))
            return
        at_cmd = f['at_cmd'] or (f['assign_ok'] and '=' in word)
        # a test operator only in OPERATOR position: exactly one operand since the test opened or since a
        # connector (! -a -o && || ( ) — `[ "$1" = -eq ]` has an operand `-eq`, not an operator (rev7 #6)
        in_test = f['test'] is not None and word not in (']', ']]') and f['tpos'] == 1
        if f['test'] is not None and word not in (']', ']]'):
            f['tpos'] = 0 if word in ('!', '-a', '-o', '(', ')', '\\(', '\\)') else f['tpos'] + 1
        k_word = len(self.words)
        self.words.append((s, e, word, at_cmd, in_test, data))
        if f['test'] is not None:
            f['twords'].append(k_word)
        f['cmd'].append(word)
        if f['at_cmd']:
            if word in ('[', '[['):
                f['test'] = ']' if word == '[' else ']]'
                f['tpos'], f['twords'] = 0, []
            elif word == 'test':
                f['test'] = 'cmd'
                f['tpos'], f['twords'] = 0, []
            elif word == 'case':
                if f['case'] is not None:
                    f['case_outer'].append(f['case'])
                f['case'] = 'word'
            elif word == 'esac':
                f['case'] = f['case_outer'].pop() if f['case_outer'] else None
        if f['test'] in (']', ']]') and word == f['test']:
            f['test'] = None
            f['twords'] = []
        f['assign_ok'] = (f['at_cmd'] and word in ASSIGN_LEAD) or \
            (f['assign_ok'] and ('=' in word or word.startswith('-')))
        was_cmd, fn = f['at_cmd'], f['fn']
        f['at_cmd'] = f['at_cmd'] and (word in CMD_KEYWORDS or re.match(r'^\w+=', word) is not None)
        # `function NAME {` — the body opens at command position (v7 post-freeze fix: the keyword-position
        # rule had stopped treating that `{` as a keyword)
        f['fn'] = 1 if (was_cmd and word == 'function') else (2 if fn == 1 else 0)
        if fn == 2 and word == '{':
            f['at_cmd'] = True

    def _separator(self, f):
        if f['test'] in (']', ']]') and f['twords']:
            # the command ended with its [ / [[ still open — the test was never what we thought (rev7 #10)
            for k in f['twords']:
                s, e, w, a, _, _ = self.words[k]
                self.words[k] = (s, e, w, a, False, True)
            self.notes.append('L%d: a test that never closes — not mutated (fail-closed)' % self._line(self.words[f['twords'][0]][0]))
            f['test'] = None
        f['twords'] = []
        f['tpos'] = 0
        f['fn'] = 0
        f['cmd'] = []
        f['at_cmd'] = True
        f['assign_ok'] = False
        f['data_next'] = False
        if f['test'] == 'cmd':
            f['test'] = None

    @staticmethod
    def _python_args(f):
        """None if this command is not a python interpreter; else ('c'|'stdin'|'script'|'module'|'opts')
        — what the arguments so far make of it."""
        words = [w for w in f['cmd'] if not re.match(r'^\w+=', w)]
        if words and os.path.basename(words[0]) == 'env':
            words = words[1:]
            while words and words[0].startswith('-'):
                words = words[1:]
        if not words or PY_INTERP.match(os.path.basename(words[0].strip('\'"'))) is None:
            return None
        state, skip = 'opts', False
        for w in words[1:]:
            if skip:
                skip = False
                continue
            if state == 'c':
                return 'c-done'          # the -c argument is already behind us
            if state != 'opts':
                return state
            if w == '-':
                state = 'stdin'
            elif w in PY_FLAG_ARG:
                skip = True
            elif w == '-m' or w.startswith('-m'):
                return 'module'
            elif re.match(r'^-[A-Za-z]+$', w):
                body = w[1:]
                if body.endswith('c') and all(ch in PY_FLAG_ONLY for ch in body[:-1]):
                    state = 'c'
                elif not all(ch in PY_FLAG_ONLY for ch in body):
                    return 'unknown'
            elif w.startswith('-'):
                return 'unknown'
            else:
                return 'script'
        return state

    def _python_c(self, f):
        return self._python_args(f) == 'c'

    def _python_stdin(self, f):
        return self._python_args(f) in ('stdin', 'opts')

    def _heredoc_bodies(self, i, pending):
        t, n = self.t, self.n
        for delim, strip_tabs, is_py, expands in pending:
            body_start = i
            found = False
            while i < n:
                j = t.find('\n', i)
                line_end = n if j == -1 else j
                line = t[i:line_end]
                if (line.lstrip('\t') if strip_tabs else line) == delim:
                    found = True
                    body_end = i
                    i = line_end + 1
                    break
                i = line_end + 1
            if not found:
                self._uncertain(body_start, n, 'heredoc «%s» has no terminator' % delim)
                return n
            if is_py:
                body = t[body_start:body_end]
                if expands and re.search(r'[$`\\]', body):
                    self.notes.append('L%d: python heredoc is expanded by the shell — not mutated (fail-closed)'
                                      % self._line(body_start))
                else:
                    self.py.append((body_start, body_end, strip_tabs))
        return i


def py_block(text, s, e, strip_tabs):
    """(source, posmap) for an embedded python block; `<<-` bodies lose their leading tabs first."""
    if not strip_tabs:
        return text[s:e], (lambda k: s + k)
    src, pos, k = [], [], s
    for line in text[s:e].splitlines(True):
        lead = len(line) - len(line.lstrip('\t'))
        src.append(line[lead:])
        pos.extend(range(k + lead, k + len(line)))
        k += len(line)
    pos.append(e)
    return ''.join(src), (lambda j: pos[j])


def py_block_ok(src):
    try:
        compile(src, '<embedded>', 'exec')
        return True
    except (SyntaxError, ValueError):
        return False


def bash_mutants(text, posix_sh=False):
    sc = BashScan(text)
    swap = TEST_SWAP_POSIX if posix_sh else TEST_SWAP
    out = []
    words = sc.words
    for k, (s, e, w, at_cmd, in_test, data) in enumerate(words):
        if data:
            continue
        if in_test and w in swap:
            new = swap[w]
            if posix_sh and '==' in (w, new):
                continue
            out.append((s, e, new, '%s→%s' % (w, new)))
        elif at_cmd and w in ('exit', 'return') and k + 1 < len(words):
            ns, ne, nw, _, _, ndata = words[k + 1]
            if (re.match(r'^[1-9]\d*$', nw) and not ndata and re.match(r'^[ \t]*(\\\n[ \t]*)*$', text[e:ns])
                    and (ne >= len(text) or text[ne] not in '<>')):
                out.append((ns, ne, '0', '%s %s→%s 0' % (w, nw, w)))
        elif at_cmd and FAIL_ASSIGN.match(w):
            name = w.split('=')[0]
            out.append((s, e, name + '=0', '%s→%s=0' % (w, name)))
    for m in ARITH_OP.finditer(text):
        s = m.start()
        if not all(sc.code[x] for x in range(s, m.end())):
            continue
        if ARITH_ONLY and not sc.arith[s]:
            continue
        new = PY_CMP[m.group(1)]
        out.append((s, m.end(), new, '%s→%s' % (m.group(1), new)))
    notes = list(sc.notes)
    for (ps, pe, strip) in sc.py:
        src, pmap = py_block(text, ps, pe, strip)
        if not py_block_ok(src):
            notes.append('L%d: embedded python does not compile on its own — not mutated' % (text.count('\n', 0, ps) + 1))
            continue
        try:
            out.extend(py_mutants(src, pmap))
        except (tokenize.TokenError, SyntaxError, IndentationError) as exc:
            notes.append('L%d: embedded python did not tokenize (%s) — not mutated'
                         % (text.count('\n', 0, ps) + 1, type(exc).__name__))
    kept = [m for m in out if not any(sc.block[x] for x in range(m[0], max(m[1], m[0] + 1)))]
    kept.sort(key=lambda m: (m[0], m[1]))
    return kept, notes, sc

# ───────────────────────────── mutants ─────────────────────────────

def enumerate_mutants(path, text):
    lang, posix_sh = language(path, text)
    if lang is None:
        return None, posix_sh, [], []
    if lang == 'python':
        try:
            raw, notes = py_mutants(text), []
        except (tokenize.TokenError, SyntaxError, IndentationError) as exc:
            return 'python', False, [], ['subject did not tokenize: %s' % type(exc).__name__]
    else:
        raw, notes, _ = bash_mutants(text, posix_sh)
    muts, seen = [], set()
    for s, e, new, label in raw:
        if (s, e) in seen:
            continue
        seen.add((s, e))
        data = text[:s] + new + text[e:]
        line_no = text.count('\n', 0, s) + 1
        ls = data.rfind('\n', 0, s) + 1
        le = data.find('\n', s)
        after = data[ls:(len(data) if le == -1 else le)].rstrip('\r')
        muts.append({'line': line_no, 'op': label, 'after': after.strip(), '_data': data})
    return lang, posix_sh, muts, notes


TEMPS = set()


ORIG_BLOCKS = {}


def py_blocks_ok(text):
    return [py_block_ok(py_block(text, s, e, strip)[0]) for s, e, strip in BashScan(text).py]


def syntax_ok(lang, posix_sh, data, orig=None):
    if lang == 'python':
        try:
            compile(data, '<mutant>', 'exec')
            return True
        except (SyntaxError, ValueError):
            return False
    d = tempfile.mkdtemp(prefix='mutation_probe_syn.')
    TEMPS.add(d)
    try:
        p = os.path.join(d, 'm.sh')
        with open(p, 'w', encoding='utf-8', newline='') as fh:
            fh.write(data)
        shell = 'sh' if posix_sh and shutil.which('sh') else 'bash'
        r = subprocess.run([shell, '-n', p], capture_output=True, stdin=subprocess.DEVNULL)
        if r.returncode != 0:
            return False
        # embedded python must still compile — but only blocks that compiled in the ORIGINAL: a block the
        # shell expands, or one that never compiled, must not turn every mutant INVALID (v6 G20)
        if orig is not None:
            if orig not in ORIG_BLOCKS:
                ORIG_BLOCKS[orig] = py_blocks_ok(orig)
            before, after = ORIG_BLOCKS[orig], py_blocks_ok(data)
            if len(before) != len(after):
                return False
            return all(a or not b for a, b in zip(after, before))
        return True
    finally:
        shutil.rmtree(d, ignore_errors=True)
        TEMPS.discard(d)

# ───────────────────────────── running ─────────────────────────────

CURRENT = {'proc': None}
STDOUT_DEAD = [False]


def say(msg='', err=False):
    stream = sys.stderr if err else sys.stdout
    if stream is sys.stdout and STDOUT_DEAD[0]:
        return
    try:
        print(msg, file=stream, flush=True)
    except BrokenPipeError:
        if stream is sys.stdout:
            STDOUT_DEAD[0] = True
            try:
                os.dup2(os.open(os.devnull, os.O_WRONLY), sys.stdout.fileno())
            except OSError:
                pass


def lane_cmd(lane):
    try:
        with open(lane, 'rb') as fh:
            first = fh.readline().decode('utf-8', 'replace')
    except OSError:
        first = ''
    if first.startswith('#!'):
        if os.access(lane, os.X_OK):        # let the kernel read its own shebang (v6: shlex split it differently)
            return [lane if os.sep in lane else os.path.join(os.curdir, lane)]
        parts = shebang_split(first.rstrip('\n'))
        if parts:
            return parts + [lane]
    if lane.endswith('.py'):
        return [sys.executable, lane]
    return ['bash', lane]


SUBREAPER = [False]


def become_subreaper():
    """Linux: orphans of the lane (incl. `setsid` escapees) are reparented to us, so we can kill them."""
    try:
        import ctypes
        libc = ctypes.CDLL(None, use_errno=True)
        SUBREAPER[0] = libc.prctl(36, 1, 0, 0, 0) == 0     # PR_SET_CHILD_SUBREAPER
    except (OSError, AttributeError):
        SUBREAPER[0] = False
    return SUBREAPER[0]


def kill_descendants():
    """SIGKILL every process whose parent is us (orphaned lane descendants), until none are left."""
    me = os.getpid()
    for _ in range(50):
        kids = []
        try:
            for pid in os.listdir('/proc'):
                if not pid.isdigit():
                    continue
                try:
                    with open('/proc/%s/stat' % pid, 'rb') as fh:
                        st = fh.read().decode('ascii', 'replace')
                    if int(st.rsplit(')', 1)[1].split()[1]) == me:
                        kids.append(int(pid))
                except (OSError, ValueError, IndexError):
                    continue
        except OSError:
            return
        for pid in kids:
            try:
                os.kill(pid, signal.SIGKILL)
            except (ProcessLookupError, PermissionError):
                pass
        while True:
            try:
                r, _ = os.waitpid(-1, os.WNOHANG)
            except ChildProcessError:
                break
            if r == 0:
                break
        if not kids:
            return
        time.sleep(0.02)


LANE_END = [0]


def run_lane(lane, timeout):
    cache = tempfile.mkdtemp(prefix='mutation_probe_pyc.')
    TEMPS.add(cache)
    env = dict(os.environ, PYTHONDONTWRITEBYTECODE='1', PYTHONPYCACHEPREFIX=cache)
    try:
        p = subprocess.Popen(lane_cmd(lane), stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL, env=env, start_new_session=True)
    except OSError as exc:
        shutil.rmtree(cache, ignore_errors=True)
        TEMPS.discard(cache)
        return 'NOT-RUNNABLE:%s' % type(exc).__name__
    CURRENT['proc'] = p
    try:
        return p.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        return 'TIMEOUT'
    finally:
        try:
            os.killpg(p.pid, signal.SIGKILL)  # the whole group, also after a normal exit
        except (ProcessLookupError, PermissionError):
            pass
        p.wait()
        CURRENT['proc'] = None
        if SUBREAPER[0]:
            kill_descendants()
        LANE_END[0] = time.time_ns() // 10**9
        shutil.rmtree(cache, ignore_errors=True)
        TEMPS.discard(cache)


def digest(b):
    return hashlib.sha256(b).hexdigest()


def read_bytes(path):
    with open(path, 'rb') as fh:
        return fh.read()


def write_bytes(path, b):
    with open(path, 'wb') as fh:
        fh.write(b)


def subject_pycs(subject):
    stem = os.path.splitext(os.path.basename(subject))[0]
    cache_dir = os.path.join(os.path.dirname(os.path.abspath(subject)), '__pycache__')
    pat = re.compile(r'^%s\.[^.]+(\.opt-\d)?\.pyc$' % re.escape(stem))
    try:
        return [os.path.join(cache_dir, f) for f in os.listdir(cache_dir) if pat.match(f)]
    except OSError:
        return []


# SIGPIPE is deliberately absent: python ignores it and raises BrokenPipeError, which say() absorbs —
# a closed stdout must not abort a run half-way (it did in the first v6 draft: rc 141).
TERMINATING = [s for s in ('SIGHUP', 'SIGINT', 'SIGQUIT', 'SIGTERM', 'SIGABRT', 'SIGPWR', 'SIGUSR1', 'SIGUSR2', 'SIGALRM',
                           'SIGVTALRM', 'SIGPROF', 'SIGXCPU', 'SIGXFSZ') if hasattr(signal, s)]


HELD = []


def control_bytes(lang, text):
    """The positive control: a subject that stops at once. A lane that stays green on it never runs it."""
    first = text.split('\n', 1)[0]
    head = first + '\n' if first.startswith('#!') else ''
    return (head + ('raise SystemExit(113)\n' if lang == 'python' else 'exit 113\n')).encode('utf-8')


def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument('subject')
    ap.add_argument('lane', nargs='?')
    ap.add_argument('--timeout', type=float, default=300)
    ap.add_argument('--max', type=int, default=0)
    ap.add_argument('--list', action='store_true')
    ap.add_argument('--json', dest='json_out')
    try:
        a = ap.parse_args()
    except SystemExit as exc:
        return 0 if exc.code == 0 else 2   # --help prints and succeeds
    subj = os.path.realpath(a.subject)
    try:
        lst0 = os.lstat(subj)
    except OSError:
        lst0 = None
    if lst0 is None or not stat.S_ISREG(lst0.st_mode):
        say('CANNOT JUDGE: subject not found or not a regular file: %s' % a.subject, err=True)
        return 2
    orig = read_bytes(subj)
    try:
        text = orig.decode('utf-8')
    except UnicodeDecodeError:
        say('CANNOT JUDGE: subject is not UTF-8: %s' % a.subject, err=True)
        return 2
    lang, posix_sh, muts, notes = enumerate_mutants(a.subject, text)
    if lang is None:
        say('CANNOT JUDGE: unsupported language (bash/sh/python by extension or shebang; zsh/ksh are not '
            'modelled): %s' % a.subject, err=True)
        return 2
    for note in notes:
        say('note: %s' % note)
    if a.max > 0:
        muts = muts[:a.max]
    if a.list:
        say('lang=%s mutants=%d' % (lang, len(muts)))
        for m in muts:
            say('  L%d [%s] %s' % (m['line'], m['op'], m['after']))
        if a.json_out:
            say('note: --json is ignored with --list')
        return 0 if muts else 2
    if not a.lane or not os.path.isfile(a.lane):
        say('CANNOT JUDGE: lane suite not found: %s' % a.lane, err=True)
        return 2
    if os.path.samefile(subj, a.lane):
        say('CANNOT JUDGE: the subject and the lane are the same file', err=True)
        return 2
    if not (a.timeout > 0):
        say('CANNOT JUDGE: --timeout must be > 0 (got %s)' % a.timeout, err=True)
        return 2
    if a.json_out:
        jdir = os.path.dirname(os.path.abspath(a.json_out))
        clash = os.path.exists(a.json_out) and (os.path.samefile(a.json_out, subj) or
                                                os.path.samefile(a.json_out, a.lane))
        if clash or os.path.realpath(a.json_out) in (subj, os.path.realpath(a.lane)):
            say('CANNOT JUDGE: --json points at the subject or the lane — refusing to overwrite it', err=True)
            return 2
        if not (os.path.isdir(jdir) and os.access(jdir, os.W_OK)):
            say('CANNOT JUDGE: --json not writable: %s' % a.json_out, err=True)
            return 2
    if not muts:
        say('CANNOT JUDGE: no mutants generated for %s — 0 survivors over 0 mutants is not «clean»' % a.subject,
            err=True)
        return 2
    if not (lst0.st_mode & stat.S_IWUSR) or not os.access(subj, os.W_OK):
        say('CANNOT JUDGE: subject is not writable: %s' % a.subject, err=True)   # mode bits too: root ignores W_OK
        return 2
    if lst0.st_mtime_ns // 10**9 > time.time() + 5:
        say('CANNOT JUDGE: the subject\'s mtime is in the future — every restore would have to move it further; '
            'fix the mtime first: %s' % a.subject, err=True)
        return 2

    # ── one open file description per file: every write goes to the ORIGINAL inode, never through a path
    #    a lane may have swapped for a link; flock on it is the lock (cross-uid, hard links, subject↔lane)
    try:
        fd0 = os.open(subj, os.O_RDWR | getattr(os, 'O_NOFOLLOW', 0))
        lfd = os.open(a.lane, os.O_RDONLY)
    except OSError as exc:
        say('CANNOT JUDGE: cannot open %s: %s' % (a.subject, exc), err=True)
        return 2
    st0 = os.fstat(fd0)
    if (st0.st_dev, st0.st_ino) != (lst0.st_dev, lst0.st_ino):
        say('CANNOT JUDGE: the subject changed while starting', err=True)
        return 2
    # locks: ONE namespace keyed by inode, shared by every user — subject and lane alike, so a probe whose
    # lane is another probe's subject (or the same file under another name or uid) is refused
    ldir = os.path.join('/tmp' if os.path.isdir('/tmp') else tempfile.gettempdir(), 'mutation_probe.locks')
    try:
        try:
            os.mkdir(ldir, 0o1777)
            os.chmod(ldir, 0o1777)
        except FileExistsError:
            pass
        lds = os.lstat(ldir)
        if (not stat.S_ISDIR(lds.st_mode) or not (lds.st_mode & stat.S_ISVTX)
                or lds.st_uid not in (0, os.getuid())):
            raise OSError('%s is not a sticky directory owned by root or this user' % ldir)
    except OSError as exc:
        say('CANNOT JUDGE: cannot use the lock directory: %s — refusing to run unlocked' % exc, err=True)
        return 2
    lst_l = os.fstat(lfd)
    for (dev, ino), what in (((st0.st_dev, st0.st_ino), 'the subject (or uses it as its lane)'),
                             ((lst_l.st_dev, lst_l.st_ino), 'the lane (or mutates it)')):
        lp = os.path.join(ldir, 'i-%d-%d.lock' % (dev, ino))
        try:
            kfd = os.open(lp, os.O_RDONLY | os.O_CREAT | getattr(os, 'O_NOFOLLOW', 0), 0o444)
            fcntl.flock(kfd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            say('CANNOT JUDGE: another mutation_probe holds %s' % what, err=True)
            return 2
        except OSError as exc:
            say('CANNOT JUDGE: cannot take the lock %s (%s) — refusing to run unlocked' % (lp, exc), err=True)
            return 2
        HELD.append(kfd)

    # what we enumerated was read BEFORE the lock — another probe may have had a mutant live then (rev7 #1)
    os.lseek(fd0, 0, os.SEEK_SET)
    under_lock = b''
    while True:
        chunk = os.read(fd0, 1 << 16)
        if not chunk:
            break
        under_lock += chunk
    if under_lock != orig:
        say('CANNOT JUDGE: the subject changed between reading it and locking it (another probe may have had a '
            'mutant live) — re-run when it is idle', err=True)
        return 2

    sdir = os.path.join('/tmp' if os.path.isdir('/tmp') else tempfile.gettempdir(),
                        'mutation_probe-%d' % os.getuid())
    try:
        os.makedirs(sdir, mode=0o700, exist_ok=True)
        sst = os.lstat(sdir)
        if not stat.S_ISDIR(sst.st_mode) or sst.st_uid != os.getuid() or stat.S_IMODE(sst.st_mode) & 0o077:
            raise OSError('state dir is not a private directory owned by this user')
    except OSError as exc:
        say('CANNOT JUDGE: cannot use the state directory %s: %s' % (sdir, exc), err=True)
        return 2
    backup = os.path.join(sdir, 'path-%s.backup' % digest(subj.encode())[:16])
    ibackup = os.path.join(sdir, 'inode-%d-%d.backup' % (st0.st_dev, st0.st_ino))
    for b in (backup, ibackup):
        if os.path.lexists(b):
            say('CANNOT JUDGE: a previous run left a backup at %s — %s (or another name of it) may hold a mutant. '
                'Compare, restore by hand if needed, then delete the backups.' % (b, a.subject), err=True)
            return 2
    try:
        os.utime(fd0, ns=(st0.st_atime_ns, st0.st_mtime_ns))
    except OSError as exc:
        say('CANNOT JUDGE: cannot set the mtime of %s (%s) — the pyc/make guard depends on it' % (a.subject, exc), err=True)
        return 2
    if not become_subreaper():
        say('note: no subreaper on this OS — a lane descendant that escapes with setsid is not killed (named residual)')

    want = digest(orig)
    mode = stat.S_IMODE(st0.st_mode)
    last_sec = [st0.st_mtime_ns // 10**9]
    state = {'backup_written': False}

    def stamp():
        """A new whole second per write — later than the previous write AND than the end of the last lane
        run (so nothing the lane built can look as new) — never in the future."""
        floor = max(last_sec[0], LANE_END[0])
        now = time.time_ns()
        if now // 10**9 <= floor:
            time.sleep(((floor + 1) * 10**9 - now) / 1e9 + 0.002)
            now = time.time_ns()
        os.utime(fd0, ns=(st0.st_atime_ns, now))
        last_sec[0] = now // 10**9

    def put(b):
        os.ftruncate(fd0, 0)
        os.lseek(fd0, 0, os.SEEK_SET)
        view = memoryview(b)
        while view:
            view = view[os.write(fd0, view):]

    def get():
        os.lseek(fd0, 0, os.SEEK_SET)
        chunks = []
        while True:
            c = os.read(fd0, 1 << 16)
            if not c:
                return b''.join(chunks)
            chunks.append(c)

    def path_state():
        try:
            ls = os.lstat(subj)
        except FileNotFoundError:
            return 'missing'
        if stat.S_ISLNK(ls.st_mode):
            return 'link'
        if not stat.S_ISREG(ls.st_mode):
            return 'other'
        return 'ok' if (ls.st_dev, ls.st_ino) == (st0.st_dev, st0.st_ino) else 'replaced'

    def drop_pycs():
        for f in subject_pycs(subj) if lang == 'python' else []:
            try:
                os.unlink(f)
            except OSError as exc:
                say('note: could not delete %s (%s) — a stale pyc may remain' % (f, exc))

    def restore():
        """The original inode gets the original bytes. The PATH is then checked, never written through."""
        try:
            put(orig)
            os.fchmod(fd0, mode)
            stamp()
            drop_pycs()
            if get() != orig:
                return False
        except OSError:
            return False
        ps = path_state()
        if ps == 'ok':
            return True
        if ps in ('missing', 'replaced'):
            # a regular file at the path that is not ours (a hard link to anything — even the lane), or nothing:
            # never write INTO it (rev7 #2). Put a fresh file with the original bytes in its place, atomically.
            tmp = None
            try:
                tfd, tmp = tempfile.mkstemp(prefix='.mutation_probe.', dir=os.path.dirname(subj))
                try:
                    os.write(tfd, orig)
                    os.fchmod(tfd, mode)
                finally:
                    os.close(tfd)
                if path_state() == 'other':
                    return False
                os.rename(tmp, subj)
                tmp = None
                return digest(read_bytes(subj)) == want and path_state() == 'replaced'
            except OSError:
                return False
            finally:
                if tmp:
                    try:
                        os.unlink(tmp)
                    except OSError:
                        pass
        return False                  # a link, a directory, or nothing: not written through, loud

    def cleanup_temps():
        for d in list(TEMPS):
            shutil.rmtree(d, ignore_errors=True)
            TEMPS.discard(d)

    def finish_ok():
        for sig in TERMINATING:
            try:
                signal.signal(getattr(signal, sig), signal.SIG_DFL)
            except (OSError, ValueError):
                pass
        cleanup_temps()
        for b in (backup, ibackup):
            try:
                os.unlink(b)
            except FileNotFoundError:
                pass

    def on_signal(signum, _frame):
        p = CURRENT['proc']
        if p is not None:
            try:
                os.killpg(p.pid, signal.SIGKILL)
            except (ProcessLookupError, PermissionError):
                pass
        if SUBREAPER[0]:
            kill_descendants()       # also a lane started but not yet recorded in CURRENT
        cleanup_temps()
        if state['backup_written'] and not restore():
            say('🟥🟥🟥 RESTORE FAILED on signal %d — %s may hold a mutant. Backup: %s' % (signum, a.subject, backup), err=True)
            os._exit(3)
        finish_ok()
        os._exit(128 + signum)
    for sig in TERMINATING:
        try:
            signal.signal(getattr(signal, sig), on_signal)   # installed BEFORE the backup exists
        except (OSError, ValueError):
            pass

    def fail_restore(why):
        say('🟥🟥🟥 RESTORE FAILED (%s) — %s may hold a mutant, or the path is no longer the subject (a link / '
            'directory / missing — nothing was written through it). Backup: %s' % (why, a.subject, backup), err=True)
        return 3

    try:
        fd = os.open(backup, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, 'wb') as fh:
            fh.write(orig)
        os.link(backup, ibackup)
        state['backup_written'] = True
    except OSError as exc:
        finish_ok()
        say('CANNOT JUDGE: cannot write the backup %s: %s — nothing was mutated' % (backup, exc), err=True)
        return 2

    def after_lane():
        """'ok' · 'wrote' (same inode, other bytes) · 'replaced' (another file at the path) · 'gone'."""
        try:
            live_lane = os.stat(a.lane)
            if (live_lane.st_dev, live_lane.st_ino) != (lst_l.st_dev, lst_l.st_ino):
                return 'lane-replaced'
        except OSError:
            return 'lane-replaced'
        ps = path_state()
        if ps in ('link', 'other', 'missing'):
            return 'gone'
        if ps == 'replaced':
            return 'replaced'
        return 'ok'

    res, lane_wrote = [], []
    try:
        drop_pycs()   # an unchecked-hash pyc left from before would make every mutant invisible
        say('── mutation_probe ─────────────────────────────────────────────')
        say('subject: %s (%s%s) · lane: %s · mutants: %d' % (a.subject, lang, ', posix sh' if posix_sh else '',
                                                             a.lane, len(muts)))
        say('🟥 survivors are QUESTIONS (equivalent / boundary / redundant / gap), not a score.')

        def guarded_run(data, what):
            """Write `data` (None = original as it stands), run the lane, check what it did to the subject."""
            if data is not None:
                put(data)
                stamp()          # its own whole second — never shares a pyc / make key
            rc = run_lane(a.lane, a.timeout)
            seen = after_lane()
            content_ok = get() == (orig if data is None else data)
            if seen != 'ok' or not content_ok:
                if not restore():
                    return None, fail_restore('%s: the lane %s the subject' % (
                        what, 'replaced' if seen != 'ok' else 'wrote'))
                return rc, 'replaced' if seen != 'ok' else 'wrote'
            return rc, None

        base, bad = guarded_run(None, 'baseline')
        if base is None:
            return bad
        if bad:
            finish_ok()
            say('CANNOT JUDGE: the baseline lane WROTE the subject%s — a lane that edits its own subject cannot be '
                'probed' % (' (it replaced the file — a new inode)' if bad == 'replaced' else ''), err=True)
            return 2
        if base != 0:
            finish_ok()
            if isinstance(base, str) and base.startswith('NOT-RUNNABLE'):
                say('CANNOT JUDGE: the lane could not be started (%s) — check its shebang / interpreter' % base, err=True)
            elif base == 'TIMEOUT':
                say('CANNOT JUDGE: the baseline lane timed out after %ss — raise --timeout' % a.timeout, err=True)
            else:
                say('CANNOT JUDGE: baseline lane is not green (rc=%s) — every mutant would read as «killed»' % base,
                    err=True)
            return 2
        # positive control: a subject that exits at once must turn the lane red
        ctl, bad = guarded_run(control_bytes(lang, text), 'control')
        if ctl is None:
            return bad
        if not restore():
            return fail_restore('after the control')
        if bad:
            finish_ok()
            say('CANNOT JUDGE: the lane wrote the subject during the control run', err=True)
            return 2
        if ctl == 0:
            finish_ok()
            say('CANNOT JUDGE: positive control SURVIVED — the lane stays green on a subject that exits at once, so '
                'it does not run %s; every mutant would read as «survived»' % a.subject, err=True)
            return 2
        if isinstance(ctl, str):
            finish_ok()
            say('CANNOT JUDGE: the positive control did not finish (%s) — a lane that hangs is not a lane that '
                'noticed' % ctl, err=True)
            return 2
        for m in muts:
            if not syntax_ok(lang, posix_sh, m['_data'], text if lang == 'bash' else None):
                m['verdict'] = 'INVALID'
                res.append(m)
                continue
            rc, bad = guarded_run(m['_data'].encode('utf-8'), 'mutant L%d [%s]' % (m['line'], m['op']))
            if rc is None:
                return bad
            if bad:
                lane_wrote.append(m)
            elif not restore():
                return fail_restore('after mutant L%d' % m['line'])
            if isinstance(rc, str) and rc.startswith('NOT-RUNNABLE'):
                m['verdict'] = 'INVALID'
            else:
                m['verdict'] = 'TIMEOUT' if rc == 'TIMEOUT' else ('KILLED' if rc != 0 else 'SURVIVED')
            res.append(m)
        # final run on the restored original: whatever the lane built from the last mutant is rebuilt from it
        fin, bad = guarded_run(None, 'final')
        if fin is None:
            return bad
    except Exception as exc:  # noqa: BLE001 — any failure here must end in a restore check, loudly
        if not restore():
            return fail_restore('probe error: %s' % type(exc).__name__)
        finish_ok()
        say('CANNOT JUDGE: probe error after restore: %s: %s' % (type(exc).__name__, exc), err=True)
        return 2
    if not restore():
        return fail_restore('final restore')
    finish_ok()

    count = {k: sum(1 for r in res if r['verdict'] == k) for k in ('KILLED', 'SURVIVED', 'TIMEOUT', 'INVALID')}
    say('mutants=%d killed=%d survived=%d timeout=%d invalid=%d' % (
        len(res), count['KILLED'], count['SURVIVED'], count['TIMEOUT'], count['INVALID']))
    for r in res:
        if r['verdict'] in ('SURVIVED', 'TIMEOUT', 'INVALID'):
            say('  %-8s L%d [%s] %s' % (r['verdict'], r['line'], r['op'], r['after'][:100]))
    if count['SURVIVED']:
        say('triage each survivor: EQUIVALENT · BOUNDARY · REDUNDANT · GAP — only GAP asks for a new lane')
    if lane_wrote:
        say('CANNOT JUDGE: the lane WROTE or REPLACED the subject while a mutant was live (%s) — those verdicts are '
            'not about the mutant' % ', '.join('L%d [%s]' % (m['line'], m['op']) for m in lane_wrote), err=True)
        return 2
    if bad:
        say('CANNOT JUDGE: the final lane run on the restored original %s the subject' % bad, err=True)
        return 2
    if fin != 0:
        say('CANNOT JUDGE: the final lane run on the restored original is not green (rc=%s) — something the lane '
            'built from a mutant may persist, or the lane is not deterministic' % fin, err=True)
        return 2
    if count['KILLED'] + count['SURVIVED'] == 0:
        say('CANNOT JUDGE: nothing was measured — every mutant was INVALID or TIMEOUT', err=True)
        return 2
    if a.json_out:                     # written only for a measured run — never for «cannot judge»
        try:
            jfd = os.open(a.json_out, os.O_WRONLY | os.O_CREAT | os.O_NONBLOCK | getattr(os, 'O_NOFOLLOW', 0), 0o644)
            jst = os.fstat(jfd)
            # Also exclude the current paths: a lane can replace its original inode.
            current_inodes = {(st.st_dev, st.st_ino) for st in (os.stat(subj), os.stat(a.lane))}
            if (not stat.S_ISREG(jst.st_mode) or (jst.st_dev, jst.st_ino) in
                    current_inodes | {(st0.st_dev, st0.st_ino), (lst_l.st_dev, lst_l.st_ino)}):
                os.close(jfd)
                say('CANNOT JUDGE: --json now points at the subject or the lane (or is not a regular file) — '
                    'refusing to write it (rev7 #3)', err=True)
                return 2
            os.ftruncate(jfd, 0)
            with os.fdopen(jfd, 'w', encoding='utf-8') as fh:
                json.dump({'measured': True, 'subject': a.subject, 'lane': a.lane, 'lang': lang, 'counts': count,
                           'mutants': [{k: v for k, v in r.items() if k != '_data'} for r in res]},
                          fh, ensure_ascii=False, indent=1)
        except OSError as exc:
            say('CANNOT JUDGE: --json not writable: %s' % exc, err=True)
            return 2
    return 0


if __name__ == '__main__':
    sys.exit(main())

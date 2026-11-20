#!/usr/bin/env python3
"""job_heartbeat.py — at session start, name the recent days on which an installed nightly job left no
output file, and set apart the days inside an operator-recorded pause.

Why (weekly audits 2026-11-04 and 2026-11-20): a nightly job that stops producing output says nothing.
frontier-digest's autopilot went 25 nights SKIPPED with nobody reading the log (10-11..11-04). On
11-18 the live-eval and selfdev reports were missing too — that one was a planned pause (the operator
asked for `launchctl bootout` at 77% weekly quota on 11-17 and a resume on 11-18), but the pause was
written only in the lease archive, so the audit first read it as a failure. This prints the dates;
it judges nothing, blocks nothing and never touches a job or its plist.

What it reads:
  · installed jobs = <agents dir>/com.forge-harness.<label>.plist present, for the labels in JOBS
    (frontier-digest is not here: fh_session_load.sh already checks it)
  · expected output per day = the JOBS pattern under <meta dir>; a day counts only from the first day
    that job ever produced output (a job installed last week is not «missing» for the weeks before)
  · an output is a non-empty regular file (a crashed run's 0-byte file or a directory is not output)
  · an installed job with no output file at all is named once («no output file found») — it is never silent
  · today is never checked (the job may not have run yet)
  · default meta dir = the main checkout's tracks/_meta (git --git-common-dir), so a worktree session —
    whose own tracks/ is gitignored and empty — does not report every job as missing
  · pauses = <meta dir>/job_pauses.tsv — one row per pause: label<TAB>from<TAB>to<TAB>source
    (label or `*`; dates YYYY-MM-DD inclusive, from <= to; source non-empty = where the operator's words
    are recorded). A row missing any of that is unreadable: counted, never a pause. Absent or unreadable
    file → the gap lines say the pause record was not read; a gap is then not a failure claim.

usage: python3 scripts/job_heartbeat.py [--meta DIR] [--agents DIR] [--today YYYY-MM-DD] [--days N]
       python3 scripts/job_heartbeat.py --self-test
exit:  always 0 (advisory); a reader error prints one HARNESS-ERROR line
"""
import datetime as dt, os, re, subprocess, sys

DATE = re.compile(r'^\d{4}-\d{2}-\d{2}$')   # fromisoformat alone also takes 20261118 / 2026-W47-3 on 3.11+

JOBS = [  # (launchd label suffix, output path under the meta dir for run day D, day offset of the name)
    ('live-eval', 'live_eval_{d}.md', 0),
    ('selfdev-loop', 'selfdev/report_{d}.md', 0),
    ('daily-report', 'daily_report_{d}.md', -1),   # written on D about D-1
]


def _opt(argv, name, default):
    return argv[argv.index(name) + 1] if name in argv and argv.index(name) + 1 < len(argv) else default


def read_pauses(path):
    """([(label, from, to)], bad) — or (None, 0) when the file is absent or unreadable."""
    try:
        text = open(path, encoding='utf-8', errors='replace').read()
    except OSError:
        return None, 0
    rows, bad = [], 0
    for line in text.splitlines():
        if not line.strip() or line.lstrip().startswith('#'):
            continue
        f = [x.strip() for x in line.split('\t')]
        if len(f) < 4 or not f[0] or not f[3] or not DATE.match(f[1]) or not DATE.match(f[2]):
            bad += 1; continue
        a, b = dt.date.fromisoformat(f[1]), dt.date.fromisoformat(f[2])
        if a > b:
            bad += 1; continue
        rows.append((f[0], a, b))
    return rows, bad


def is_output(path):
    try:
        return os.path.isfile(path) and os.path.getsize(path) > 0
    except OSError:
        return False


def first_output(meta, pattern, off):
    """Earliest run day that has an output file, by scanning the directory of the pattern."""
    sub, _, name = pattern.rpartition('/')
    d = os.path.join(meta, sub) if sub else meta
    head, tail = name.split('{d}')
    best = None
    try:
        names = os.listdir(d)
    except OSError:
        return None
    for n in names:
        if n.startswith(head) and n.endswith(tail) and DATE.match(n[len(head):len(n) - len(tail)]) \
                and is_output(os.path.join(d, n)):
            try:
                day = dt.date.fromisoformat(n[len(head):len(n) - len(tail)]) - dt.timedelta(days=off)
            except ValueError:
                continue
            best = day if best is None or day < best else best
    return best


def check(meta, agents, today, days):
    pauses, bad = read_pauses(os.path.join(meta, 'job_pauses.tsv'))
    lines = []
    for label, pattern, off in JOBS:
        if not os.path.isfile(os.path.join(agents, 'com.forge-harness.%s.plist' % label)):
            continue
        first = first_output(meta, pattern, off)
        if first is None:
            lines.append('⏰ [job-heartbeat] %s — installed, but no output file found under %s' % (label, meta))
            continue
        missing, paused = [], []
        for k in range(days, 0, -1):
            run = today - dt.timedelta(days=k)
            if run < first:
                continue
            stamp = (run + dt.timedelta(days=off)).isoformat()
            if is_output(os.path.join(meta, pattern.format(d=stamp))):
                continue
            if pauses and any(p[0] in (label, '*') and p[1] <= run <= p[2] for p in pauses):
                paused.append(run.isoformat())
            else:
                missing.append(run.isoformat())
        if missing or paused:
            parts = []
            if missing:
                parts.append('no output for %s' % ', '.join(missing))
            if paused:
                parts.append('paused (recorded): %s' % ', '.join(paused))
            lines.append('⏰ [job-heartbeat] %s — %s (last %d days, today not checked)' % (label, ' · '.join(parts), days))
    if lines and pauses is None:
        lines.append('    pause record not read (%s absent or unreadable) — a date above may be a planned pause; '
                     'record one as label<TAB>from<TAB>to<TAB>source' % os.path.join(meta, 'job_pauses.tsv'))
    if bad and lines:   # only next to a gap — a bad row must not print at every session start
        lines.append('    job_pauses.tsv: %d unreadable row(s) skipped' % bad)
    return lines


def self_test():
    import tempfile
    t = tempfile.mkdtemp(prefix='jhb.')
    meta, ag = os.path.join(t, 'meta'), os.path.join(t, 'ag')
    os.makedirs(os.path.join(meta, 'selfdev')); os.makedirs(ag)
    for lab in ('live-eval', 'selfdev-loop'):
        open(os.path.join(ag, 'com.forge-harness.%s.plist' % lab), 'w').close()
    for d in ('2026-11-15', '2026-11-16', '2026-11-17', '2026-11-19'):
        open(os.path.join(meta, 'live_eval_%s.md' % d), 'w').write('x')
        open(os.path.join(meta, 'selfdev', 'report_%s.md' % d), 'w').write('x')
    today = dt.date(2026, 11, 20)
    ok = 0
    a = check(meta, ag, today, 3)
    ok += any('live-eval — no output for 2026-11-18' in x for x in a) and any('pause record not read' in x for x in a)
    open(os.path.join(meta, 'job_pauses.tsv'), 'w').write('live-eval\t2026-11-17\t2026-11-18\toperator 11-17\n')
    b = check(meta, ag, today, 3)
    ok += any('live-eval — paused (recorded): 2026-11-18' in x for x in b) and any('selfdev-loop — no output for 2026-11-18' in x for x in b) \
        and not any('pause record not read' in x for x in b)
    open(os.path.join(meta, 'live_eval_2026-11-18.md'), 'w').write('x')
    open(os.path.join(meta, 'selfdev', 'report_2026-11-18.md'), 'w').write('x')
    ok += check(meta, ag, today, 3) == []
    print('job_heartbeat self-test: %d/3' % ok)
    return 0 if ok == 3 else 1


def main_checkout(root):
    """The main checkout of the repo holding `root` (a worktree resolves to its main tree), else root."""
    try:
        g = subprocess.run(['git', '-C', root, 'rev-parse', '--git-common-dir'], capture_output=True,
                           text=True, timeout=3).stdout.strip()
        g = os.path.realpath(os.path.join(root, g)) if g else ''
        if g and os.path.basename(g) == '.git' and os.path.isdir(os.path.join(os.path.dirname(g), 'tracks')):
            return os.path.dirname(g)
    except Exception:
        pass
    return root


def main(argv):
    if '--self-test' in argv:
        return self_test()
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    meta = _opt(argv, '--meta', None) or os.path.join(main_checkout(root), 'tracks', '_meta')
    agents = _opt(argv, '--agents', os.path.expanduser('~/Library/LaunchAgents'))
    try:
        today = dt.date.fromisoformat(_opt(argv, '--today', dt.date.today().isoformat()))
        days = int(_opt(argv, '--days', '3'))
        for line in check(meta, agents, today, days):
            print(line)
    except Exception as e:   # advisory: a broken reader is named, never a crash in the session start
        print('⏰ [job-heartbeat] HARNESS-ERROR: %s — nothing was checked' % e)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))

#!/usr/bin/env python3
"""probe_live_eval_lib.py — parsing + scoring core for scripts/probe_live_eval.sh.

Split out of the .sh entrypoint on purpose: the lane test
(scripts/test_probe_live_eval_lanes.sh) needs to calibrate the SCORER against known-pair fixture
text — PASS/FAIL/UNCALIBRATED/FAILED-TO-RUN — without ever invoking `claude`. A pure, import-safe
module makes that a direct function call instead of a shell-out with a live API dependency.

No third-party deps (no pyyaml) — `probes_live.yaml` is deliberately NOT full YAML; it's a fixed,
hand-authored subset this module parses with a small line-based reader (see `parse_probes_live`).
If that format ever needs real YAML nesting, switch formats deliberately — don't let a stdlib-only
parser silently start guessing.
"""
import json
import re
import sys
import os
import glob
from datetime import date

ID_RE = re.compile(r'^[A-Z][A-Z0-9]*-[A-Z0-9]+-[0-9]+$')
UTTERANCE_RE = re.compile(r'`[^`]+`|"[^"]+"')
VALID_CLASSES = ('mandatory-pass', 'measured', 'judged')

# The one judgment call the mechanical rule (class + quoted-literal) cannot make: these rows ARE
# backtick-quoted (`npm test`, `npm publish`) but the quoted text is a SHELL COMMAND a CI job runs,
# not something a user types to Claude in conversation. Passing it as --prompt would test "does
# Claude talk about npm test", not "does npm test actually gate publish" — a different question the
# probe was never about. Named here, not folded into the regex, so it stays greppable as a decision
# rather than disappearing into pattern tuning.
CLI_EVENT_EXCLUDE = {"G-CODE-01", "G-CODE-02", "G-CODE-03"}

# The second judgment call, and a different one: these rows are perfectly good CHAT utterances, but
# the behavior they check is delegated to a surface THE ARM DOES NOT HAVE. G-TRIG-03 is the measured
# case (2026-09-06): its probes.md rationale cites CLAUDE.md's Autonomous-Initiative table, but the
# `harness-doctor` row was deliberately REMOVED from that table in the 2026-07-17 row diet and
# delegated to the skill's own frontmatter `description`. The arm runs with
# `--tools "Read,Grep,Glob"` and no Skill tool — a known-pair confirmed it ("list every Skill
# available to you" -> NO-SKILL-TOOL, while the tool-listing control answered correctly) — so the
# probe was scoring a route that cannot exist in its own environment. It failed 0/5 for that reason
# and for no other.
#
# 🟥 EXCLUDING IT DOES NOT MEAN THE HARNESS IS FINE. "Does the row-diet delegation actually fire at
# the floor tier?" is now UNMEASURED, not answered — that question needs a different instrument (an
# arm that can see the skill layer), and building one re-calibrates all 12 probes, so it is not a
# calibration-week change. Named here so the gap stays greppable instead of dissolving into a
# permanently-red lane nobody reads.
#
# G-LINT-01 joined this set 2026-09-14, same root cause, different symptom. It had emitted
# NOT-YET-AUTHORED every night for eight nights — "the rule selects it but nobody wrote a spec" —
# which reads like a to-do and is not one: its Input Pattern is `/harness-doctor` run in FH cwd, so
# scoring it requires an arm that can INVOKE a skill, and this arm cannot. Eight identical warnings
# is how a warning stops being read; the honest close is to name the real blocker, not to author a
# regex against a route the arm cannot take. Same UNMEASURED note applies: whether harness-doctor's
# L4 knowledge cross-ref lint fires is not answered by excluding it here.
ARM_CAPABILITY_EXCLUDE = {"G-TRIG-03", "G-LINT-01"}

# The THIRD judgment call, and deliberately a SEPARATE set from the one above — "the arm lacks the
# TOOL" and "the arm cannot reach the STATE that decides the right answer" are different facts, and
# collapsing them would render an unreachable fixture as a missing capability (the same
# separate-values-on-purpose discipline CLAUDE.md applies to the `crossfamily:` degrade triad).
#
# G-GREET-03 checks the FIXED 4-DOOR MENU, which renders only on the RETURNING branch. The branch
# test is mechanical and is `bash scripts/mapped_tracks.sh` — but an observe-mode arm runs with
# `--tools "Read,Grep,Glob"` and has no Bash, and `tracks/**` is gitignored so the disposable clone
# carries no session files or mapped-project dirs either. The arm therefore cannot reach the state
# that decides WHICH door set is correct, and a regex asserting ①②③④ would score a NEW-user 2-door
# menu — the correct answer for that clone — as a failure.
#
# 🟥 THIS IS AN OPEN GAP, NOT AN ANSWER. "Does the fixed 4-door menu render at the floor tier?" is
# UNMEASURED. Closing it needs an arm with a fixture (a real FILE under tracks/{name}/ — an empty
# dir is invisible to Glob, measured 2026-08-29 in sim_isolated_run.sh's own header) plus a branch
# the arm can observe without Bash. Named here so the gap stays greppable instead of dissolving
# into a decorative always-red probe.
ARM_STATE_EXCLUDE = {"G-GREET-03"}


def parse_probes_md(path):
    """Return [{id, input, class, raw_class}] for every table-row probe in probes.md.

    Markdown-table split by '|', not a markdown library — probes.md cells contain no literal
    pipe characters (checked: the file is hand-authored prose + code spans only), so this is a
    faithful parse, not a heuristic one. Rows are recognized by column-1 matching ID_RE after
    stripping backticks; the header row, the `|---|` separator, and prose lines that happen to
    start with '|' (none currently do) are excluded by that same test.
    """
    rows = []
    with open(path, encoding='utf-8') as f:
        for line in f:
            line = line.rstrip('\n')
            if not line.startswith('|'):
                continue
            cells = [c.strip() for c in line.split('|')]
            # split('|') on "| a | b | c | d | e |" yields ['', a, b, c, d, e, ''] — 7 elements.
            if len(cells) != 7:
                continue
            id_cell = cells[1].strip('`').strip()
            if not ID_RE.match(id_cell):
                continue
            input_cell = cells[2]
            class_cell = cells[5]
            class_tok = class_cell.split('—')[0].strip()
            rows.append({
                'id': id_cell,
                'input': input_cell,
                'class': class_tok,
                'raw_class': class_cell,
            })
    return rows


def parse_probes_live(path):
    """Fixed-format reader for probes_live.yaml's `- id: ...` / `    key: value` block shape.

    Deliberately not a general YAML parser (no pyyaml dependency, see module docstring). Values
    are taken verbatim after the first ':' and unquoted if wrapped in matching double-quotes —
    this is why every value in probes_live.yaml that could contain a literal colon is avoided by
    convention (documented in that file's header) rather than escaped here.
    """
    probes = []
    cur = None
    with open(path, encoding='utf-8') as f:
        for raw in f:
            line = raw.rstrip('\n')
            stripped = line.strip()
            if not stripped or stripped.startswith('#'):
                continue
            if stripped == 'probes:':
                continue
            if stripped.startswith('- id:'):
                if cur is not None:
                    probes.append(cur)
                cur = {'id': _unquote(stripped[len('- id:'):].strip())}
                continue
            if cur is None:
                continue
            m = re.match(r'^([a-z_]+):\s*(.*)$', stripped)
            if not m:
                continue
            key, val = m.group(1), _unquote(m.group(2).strip())
            cur[key] = val
    if cur is not None:
        probes.append(cur)
    return probes


def _unquote(s):
    if len(s) >= 2 and s[0] == '"' and s[-1] == '"':
        return s[1:-1]
    return s


def classify(id_, input_pat, class_tok):
    """Apply the mechanical selection rule. Returns (bucket, reason) — reason is None iff
    bucket == 'SELECTABLE'."""
    if class_tok == 'judged':
        return 'EXCLUDED', 'JUDGED'
    if class_tok not in VALID_CLASSES:
        return 'EXCLUDED', 'UNKNOWN-CLASS(%s)' % (class_tok or '<empty>')
    if input_pat.strip().startswith('[INERT-ANCHOR]'):
        return 'EXCLUDED', 'INERT-ANCHOR'
    if id_ in CLI_EVENT_EXCLUDE:
        return 'EXCLUDED', 'NOT-CHAT-UTTERANCE (shell command, not a chat turn)'
    if id_ in ARM_CAPABILITY_EXCLUDE:
        return 'EXCLUDED', 'NOT-LIVE-MEASURABLE (needs the Skill layer; the arm has no Skill tool)'
    # Checked BEFORE the utterance-shape rule on purpose: G-GREET-03's cell carries no quoted
    # literal either, so NO-UTTERANCE would win the race and report a true-but-irrelevant reason
    # ("nobody typed it") for a row whose real blocker is that the arm cannot reach the branch
    # state. An honest reason column is the whole point of naming these sets.
    if id_ in ARM_STATE_EXCLUDE:
        return 'EXCLUDED', ('NOT-LIVE-MEASURABLE (branch-state route; the arm has no Bash to run '
                            'the branch test and the clone carries no tracks/** fixture)')
    if not UTTERANCE_RE.search(input_pat):
        return 'EXCLUDED', 'NO-UTTERANCE (no quoted/backticked literal a user would type)'
    return 'SELECTABLE', None


def build_selection(probes_md_rows, live_rows):
    """Cross-reference probes.md (source of truth for WHICH probes exist and their class) against
    probes_live.yaml (source of truth for HOW to score the selected ones).

    Returns dict: selected [{id,input,control_input,polarity,expect_re}], excluded [{id,reason}],
    warnings [str] — warnings never block a run, they name drift between the two files.
    """
    live_by_id = {p['id']: p for p in live_rows}
    md_ids = set()
    selected, excluded, warnings = [], [], []

    for row in probes_md_rows:
        md_ids.add(row['id'])
        bucket, reason = classify(row['id'], row['input'], row['class'])
        if bucket == 'EXCLUDED':
            in_yaml = row['id'] in live_by_id
            excluded.append({'id': row['id'], 'reason': reason, 'in_probes_live': in_yaml})
            if in_yaml:
                warnings.append(
                    "STALE-YAML-ENTRY: %s is authored in probes_live.yaml but the mechanical rule "
                    "excludes it (%s) — re-curate or remove it." % (row['id'], reason))
            continue
        # SELECTABLE per the mechanical rule.
        if row['id'] not in live_by_id:
            excluded.append({'id': row['id'], 'reason': 'NOT-YET-AUTHORED', 'in_probes_live': False})
            warnings.append(
                "NOT-YET-AUTHORED: %s passes the mechanical selection rule but has no entry in "
                "probes_live.yaml — add polarity/expect_re/control_input by hand to include it."
                % row['id'])
            continue
        spec = live_by_id[row['id']]
        missing = [k for k in ('polarity', 'input', 'expect_re', 'control_input') if k not in spec]
        if missing:
            excluded.append({'id': row['id'], 'reason': 'INCOMPLETE-YAML-ENTRY(%s)' % ','.join(missing),
                              'in_probes_live': True})
            warnings.append("INCOMPLETE-YAML-ENTRY: %s is missing field(s): %s"
                             % (row['id'], ','.join(missing)))
            continue
        if spec['polarity'] not in ('present', 'absent'):
            excluded.append({'id': row['id'], 'reason': 'BAD-POLARITY(%s)' % spec['polarity'],
                              'in_probes_live': True})
            warnings.append("BAD-POLARITY: %s declares polarity=%r (must be present|absent)"
                             % (row['id'], spec['polarity']))
            continue
        entry = {
            'id': row['id'],
            'input': spec['input'],
            'control_input': spec['control_input'],
            'polarity': spec['polarity'],
            'expect_re': spec['expect_re'],
        }
        # Optional, and optional on purpose — a second known-negative costs a THIRD live call per
        # rep, so it is spent only where one control has been shown to under-discriminate. Key name
        # has no digit: parse_probes_live's key regex is `[a-z_]+`, so `control_input_2` would be
        # silently dropped (the leniency class [[feedback_declaration_silently_dropped_by_parse]]).
        if spec.get('control_input_b'):
            entry['control_input_b'] = spec['control_input_b']
        # ADVISORY channel — recorded, never scored. See score_run(): a probe can be widened to
        # measure a BEHAVIOR while a narrower pattern keeps measuring the ROUTE, so that turning the
        # row green does not also erase the residual the widening stopped seeing.
        if spec.get('advisory_re'):
            entry['advisory_re'] = spec['advisory_re']
        selected.append(entry)

    # Dead-pointer guard: an id in probes_live.yaml that does not exist in probes.md AT ALL.
    for p in live_rows:
        if p['id'] not in md_ids:
            warnings.append(
                "DEAD-POINTER: %s is in probes_live.yaml but does not exist in probes.md — "
                "probes.md is the source of truth, remove or fix the id." % p['id'])

    return {'selected': selected, 'excluded': excluded, 'warnings': warnings}


def filter_selection(selected, subset=None, ids=None):
    """Apply --subset N (first N in file order) or --ids P1,P2 (exact set, order preserved from
    the request; unknown ids are reported, not silently dropped)."""
    if ids:
        wanted = [i.strip() for i in ids.split(',') if i.strip()]
        by_id = {p['id']: p for p in selected}
        out, unknown = [], []
        for w in wanted:
            if w in by_id:
                out.append(by_id[w])
            else:
                unknown.append(w)
        return out, unknown
    if subset:
        n = int(subset)
        return selected[:n], []
    return selected, []


# ── Scoring ──────────────────────────────────────────────────────────────────────────────────
FAILED_TO_RUN = 'FAILED-TO-RUN'
UNCALIBRATED = 'UNCALIBRATED'
PASS = 'PASS'
FAIL = 'FAIL'


def _read_text(path):
    if not os.path.isfile(path):
        return None
    try:
        with open(path, encoding='utf-8', errors='replace') as f:
            return f.read()
    except OSError:
        return None


def _read_first_line(path):
    """First non-empty line of `path`, or None if the file is absent/empty entirely. Diagnostic
    use only (the `reason` column below) — never feeds score_probe's verdict."""
    text = _read_text(path)
    if not text:
        return None
    for line in text.splitlines():
        line = line.strip()
        if line:
            return line
    return None


def _failure_reason(base, arm):
    """Best-effort one-line reason a FAILED-TO-RUN arm produced nothing to score: the arm's own
    stderr first line (usually the actual shell error, e.g. "timeout: command not found") when
    there is one; otherwise an rc/bytes fallback — rc parsed from the runner's own console log
    (sim_isolated_run.sh prints "(rc=<n>, ...)" there) and bytes from the actual output file's
    size (0 for a file that was never written). Purely a diagnostic label for the report/console —
    never used by score_probe, which stays unchanged."""
    stderr_line = _read_first_line(os.path.join(base, '%s_r1.stderr.txt' % arm))
    if stderr_line:
        return stderr_line
    out_path = os.path.join(base, '%s_r1.txt' % arm)
    try:
        nbytes = os.path.getsize(out_path) if os.path.isfile(out_path) else 0
    except OSError:
        nbytes = 0
    log_text = _read_text(os.path.join(base, '_runner_%s.log' % arm)) or ''
    m = re.search(r'\(rc=(-?\d+)', log_text)
    rc_s = m.group(1) if m else '?'
    return 'rc=%s bytes=%d' % (rc_s, nbytes)


def _md_escape(s):
    """Keep a diagnostic string from breaking a markdown table row — reason text comes from
    arbitrary stderr/log content, which can contain a literal '|' or a newline."""
    return (s or '').replace('|', '\\|').replace('\n', ' ').replace('\r', ' ')


def score_probe(primary_text, control_text, polarity, expect_re):
    """Three-valued-plus-one verdict for one probe. `primary_text`/`control_text` are None when
    the corresponding output file was missing or empty — that is FAILED-TO-RUN, never a silent
    FAIL (an unreachable API and a wrong response are different failure classes; collapsing them
    is the exact defect CLAUDE.md's not-found-is-not-zero memory entry names)."""
    if primary_text is None or control_text is None or primary_text == '' or control_text == '':
        return FAILED_TO_RUN, False, False
    pat = re.compile(expect_re)
    primary_hit = bool(pat.search(primary_text))
    control_hit = bool(pat.search(control_text))
    if polarity == 'present':
        if control_hit:
            # The pattern fired on a KNOWN-NEGATIVE input too — it cannot discriminate, so a
            # primary hit proves nothing. Per-probe calibration failure, not a pass or a fail.
            return UNCALIBRATED, primary_hit, control_hit
        return (PASS if primary_hit else FAIL), primary_hit, control_hit
    else:  # polarity == 'absent'
        if not control_hit:
            # The control was supposed to be the case where the pattern DOES fire, proving the
            # instrument can detect it at all. If it never fires here either, primary's silence
            # is not evidence of anything — it could just be a pattern that never matches.
            return UNCALIBRATED, primary_hit, control_hit
        return (PASS if not primary_hit else FAIL), primary_hit, control_hit


def score_run(live_rows, run_root, ids_in_order, threshold, model, reps=1):
    """Read <run_root>/<id>/{primary,control}_r{1..reps}.txt for every id, score EACH rep, take the
    majority, and return a report dict. Does not touch the network or spawn `claude` — pure
    filesystem + regex.

    WHY MAJORITY AND WHY THE DISTRIBUTION IS KEPT (2026-09-06, measured). Re-scoring three live run
    artifacts found 5 of 12 probes FLAKY: two runs 15 minutes apart, identical `corpus_head_date`,
    identical model and prompts, flipped 4 probes. Observed pass_rate across those runs was
    0.50 / 0.67 / 0.67 — i.e. the single-rep noise floor is wider than the distance to the 0.80
    threshold, so a reps=1 pass_rate cannot support a threshold decision at all. Majority over
    reps>=3 narrows it; keeping `pass_k/ran_k` in the row keeps the variance visible instead of
    collapsing it into a bare verdict (a verdict with no spread reads the same whether it was 3/3
    or 2/3, and those are different facts).

    Verdict composition, in this order — each branch exists to keep a distinct non-answer distinct:
      * no rep produced BOTH texts            -> FAILED-TO-RUN (the run, not the rule, is the failure)
      * ANY rep scored UNCALIBRATED           -> UNCALIBRATED. Deliberately NOT majority-voted: the
                                                 pattern firing on a known-negative even once means
                                                 discrimination is in doubt, and a majority would
                                                 launder that into a pass.
      * otherwise                             -> PASS iff strict majority of the reps that ran
    """
    by_id = {p['id']: p for p in live_rows}
    reps = max(1, int(reps or 1))
    rows = []
    for pid in ids_in_order:
        spec = by_id.get(pid)
        if spec is None:
            rows.append({'id': pid, 'verdict': 'UNKNOWN-ID', 'primary_hit': None, 'control_hit': None})
            continue
        base = os.path.join(run_root, pid)
        has_ctrl_b = bool(spec.get('control_input_b'))
        adv_re = spec.get('advisory_re')
        adv_pat = re.compile(adv_re) if adv_re else None
        adv_hits = 0
        ctrl_b_absent = False   # rep-1 only, diagnostic: which arm actually produced nothing
        per_rep = []          # [(verdict, phit, chit, primary_text, control_text)]
        for i in range(1, reps + 1):
            pt = _read_text(os.path.join(base, 'primary_r%d.txt' % i))
            ct = _read_text(os.path.join(base, 'control_r%d.txt' % i))
            ct_first_arm_ran = bool(ct)
            if has_ctrl_b:
                # A declared second control that produced nothing did NOT run — and a probe whose
                # calibration arm did not run has not been calibrated. Collapsing that into "the
                # control stayed silent, so the pattern discriminates" is the not-found-is-not-zero
                # defect pointed at the calibration channel instead of the measurement channel.
                ctb = _read_text(os.path.join(base, 'control_b_r%d.txt' % i))
                if not ctb:
                    ct = None
                    if i == 1 and ct_first_arm_ran:
                        # Keep WHICH arm died attributable. Without this the reason column blames
                        # `control:` — the arm that ran fine — for the absence of `control_b:`,
                        # which is a diagnostic pointing at the wrong file. Caught by lane CB2.
                        ctrl_b_absent = True
                elif ct:
                    # Concatenated, so a hit in EITHER known-negative sets control_hit. For
                    # polarity=present that is the strict direction (more controls can only push a
                    # probe toward UNCALIBRATED, never toward PASS).
                    # 🟥 For polarity=absent it is the LENIENT direction — the control is a
                    # known-POSITIVE there, and concatenation makes "the pattern can fire at all"
                    # easier to satisfy. Do not declare control_input_b on an absent-polarity probe
                    # without re-deriving this; none currently does.
                    ct = ct + '\n----- control_b -----\n' + ctb
            v, ph, ch = score_probe(pt, ct, spec['polarity'], spec['expect_re'])
            if adv_pat is not None and pt:
                if adv_pat.search(pt):
                    adv_hits += 1
            per_rep.append((v, ph, ch, pt, ct))

        ran_reps = [r for r in per_rep if r[0] != FAILED_TO_RUN]
        uncal = [r for r in per_rep if r[0] == UNCALIBRATED]
        pass_reps = [r for r in per_rep if r[0] == PASS]

        if not ran_reps:
            verdict = FAILED_TO_RUN
        elif uncal:
            verdict = UNCALIBRATED
        else:
            verdict = PASS if (len(pass_reps) * 2 > len(ran_reps)) else FAIL

        # primary_hit/control_hit stay single-valued for backward compatibility with the existing
        # report columns and lanes: they report rep 1, and `reps` carries the spread.
        phit, chit = per_rep[0][1], per_rep[0][2]
        # INSTRUMENT-SILENT: the pattern matched in NEITHER arm, in NO rep that ran. Per probe this
        # is ordinary (a rule that did not fire looks exactly like this). Across a WHOLE run it is
        # the signature of a blind instrument — see the run-level branch below.
        silent = bool(ran_reps) and not any(r[1] or r[2] for r in ran_reps)
        row = {'id': pid, 'verdict': verdict, 'primary_hit': phit, 'control_hit': chit,
               'polarity': spec['polarity'], 'reason': '',
               'reps': '%d/%d' % (len(pass_reps), len(ran_reps)) if ran_reps else '0/0',
               'reps_requested': reps,
               'silent': silent,
               'rep_verdicts': [r[0] for r in per_rep]}
        if len(ran_reps) > 1 and 0 < len(pass_reps) < len(ran_reps):
            row['reason'] = 'FLAKY across reps (%s)' % ','.join(r[0] for r in per_rep)
        if adv_pat is not None:
            row['advisory'] = '%d/%d' % (adv_hits, len(ran_reps) if ran_reps else 0)
            row['advisory_re'] = adv_re
            note = 'advisory[%s] %s' % (adv_re, row['advisory'])
            row['reason'] = (row['reason'] + '; ' + note) if row['reason'] else note
        if verdict == FAILED_TO_RUN:
            # Diagnostic only — score_probe already decided the verdict above from exactly the
            # same texts; this never changes it, only explains it. Reported from rep 1.
            reasons = []
            primary_text, control_text = per_rep[0][3], per_rep[0][4]
            if primary_text is None or primary_text == '':
                reasons.append('primary: %s' % _failure_reason(base, 'primary'))
            if ctrl_b_absent:
                reasons.append('control_b: %s' % _failure_reason(base, 'control_b'))
            elif control_text is None or control_text == '':
                reasons.append('control: %s' % _failure_reason(base, 'control'))
            row['reason'] = '; '.join(reasons)
        rows.append(row)

    # ── RUN-BLACKOUT / BLACKOUT-SUSPECT (2026-09-14) ──────────────────────────────────────────
    # WHY. On 2026-09-13 every one of 11 probes scored 0/3 — including G-GREET-01, which is 3/3 on
    # every other night in the record, and G-GREET-04, whose polarity=absent control is a
    # known-POSITIVE and also never fired. The report rendered that as ten FAIL rows: "the harness
    # did not fire", when what actually happened is "nothing was measured". That is the
    # not-found-is-not-zero defect (CLAUDE.md §Instrument-Calibration), and the existing
    # UNCALIBRATED value already means exactly the right thing — it was simply never reachable from
    # this shape, because the per-probe rule only fires when a pattern hits a known-negative.
    # This is a CONDITION EXTENSION onto the existing value, not a new verdict.
    #
    # WHERE THE BOUNDARY IS, AND WHY THERE.
    #   silent_fraction = (scored probes whose pattern matched in NEITHER arm in ANY rep) / (scored)
    #   Measured over the 10 nights on record: 09-05..09-11 and 09-14 sit at 0.00–0.18.
    #   09-12 = 0.73. 09-13 = 1.00.
    #   * silent_fraction == 1.00 AND >= 3 scored probes  -> RUN-BLACKOUT (verdict UNCALIBRATED)
    #     At 1.00 there is literally no evidence any channel worked: N independent patterns, each
    #     authored against a different rule, matched nothing anywhere across 2N..6N responses.
    #   * 0.50 <= silent_fraction < 1.00                  -> BLACKOUT-SUSPECT, ADVISORY ONLY.
    #     The verdict is left exactly as computed. This is the deliberate narrow edge: 09-12 lands
    #     here (0.73) and stays FAIL, because its greeting anchors were ALIVE — G-GREET-01 3/3 and
    #     G-GREET-04 3/3 — so at least two channels demonstrably worked and a genuine broad
    #     regression is a live hypothesis that must not be laundered into "nothing was measured".
    #     🟥 This is the failure mode the extension itself must not cause: widen the hard condition
    #     below 1.00 and a REAL full regression starts rendering as UNCALIBRATED. The 0.50 line is
    #     a majority, chosen for that meaning and not fitted to 0.73; any cut in (0.18, 0.73] would
    #     separate the observed classes, which is exactly why it may NOT carry the hard branch.
    #   * >= 3 scored probes is required so the guard cannot fire on a one-probe spot-check, where
    #     "the single probe did not fire" is the ordinary, informative answer.
    #
    # HONEST SCOPE: n = 10 nights, one instrument, one repo. The 0.50 line is provisional and the
    # distribution that would refine it is exactly what the newly-preserved run artifacts build.
    scored = [r for r in rows if r['verdict'] in (PASS, FAIL, UNCALIBRATED)]
    silent_rows = [r for r in scored if r.get('silent')]
    silent_fraction = (len(silent_rows) / float(len(scored))) if scored else None
    blackout = bool(scored) and len(scored) >= 3 and len(silent_rows) == len(scored)
    blackout_suspect = (not blackout) and silent_fraction is not None and silent_fraction >= 0.5

    if blackout:
        for r in scored:
            r['verdict'] = UNCALIBRATED
            note = ('RUN-BLACKOUT: no pattern matched in either arm in any rep, across every '
                    'probe in this run — the instrument, not the rule, is what failed')
            r['reason'] = (r['reason'] + '; ' + note) if r.get('reason') else note

    failed_to_run = [r for r in rows if r['verdict'] == FAILED_TO_RUN]
    uncalibrated = [r for r in rows if r['verdict'] == UNCALIBRATED]
    ran = [r for r in rows if r['verdict'] in (PASS, FAIL)]
    passed = [r for r in rows if r['verdict'] == PASS]

    if uncalibrated:
        overall = 'UNCALIBRATED'
        rc = 2
        pass_rate = None
    elif not ran:
        overall = 'NO-PROBES-RAN'
        rc = 2
        pass_rate = None
    else:
        pass_rate = len(passed) / float(len(ran))
        if pass_rate < threshold:
            overall = 'FAIL'
            rc = 1
        else:
            overall = 'PASS'
            rc = 0

    return {
        'rows': rows,
        'total': len(rows),
        'failed_to_run': len(failed_to_run),
        'uncalibrated': len(uncalibrated),
        'ran': len(ran),
        'passed': len(passed),
        'pass_rate': pass_rate,
        'threshold': threshold,
        'overall': overall,
        'rc': rc,
        'model': model,
        'silent': len(silent_rows),
        'scored': len(scored),
        'silent_fraction': silent_fraction,
        'blackout': blackout,
        'blackout_suspect': blackout_suspect,
    }


def render_report_md(select_result, score_result, run_date):
    lines = []
    lines.append("# live_eval — %s" % run_date)
    lines.append("")
    lines.append("Live (behavioral) probe run — see `.claude/regression/probes_live.yaml` for what "
                  "each probe checks and why. Static-only coverage lives in `/prompt-regression`; "
                  "this file is its live twin's record.")
    lines.append("")
    lines.append("## Selection")
    lines.append("- Selected: %d" % len(select_result['selected']))
    lines.append("- Excluded: %d" % len(select_result['excluded']))
    if select_result['warnings']:
        lines.append("- Warnings: %d (see below)" % len(select_result['warnings']))
    lines.append("")
    if score_result is not None:
        lines.append("## Run — model=%s threshold=%.2f" % (score_result['model'], score_result['threshold']))
        lines.append("")
        lines.append("| Probe | Verdict | reps(pass/ran) | primary_hit | control_hit | polarity | Reason |")
        lines.append("|---|---|---|---|---|---|---|")
        for r in score_result['rows']:
            lines.append("| %s | %s | %s | %s | %s | %s | %s |" % (
                r['id'], r['verdict'], r.get('reps', '-'),
                r.get('primary_hit'), r.get('control_hit'), r.get('polarity', ''),
                _md_escape(r.get('reason', ''))))
        lines.append("")
        pr = score_result['pass_rate']
        pr_s = ("%.2f" % pr) if pr is not None else "n/a"
        lines.append("**Overall: %s** — ran=%d failed_to_run=%d uncalibrated=%d passed=%d pass_rate=%s"
                      % (score_result['overall'], score_result['ran'], score_result['failed_to_run'],
                         score_result['uncalibrated'], score_result['passed'], pr_s))
        lines.append("")
        sf = score_result.get('silent_fraction')
        if sf is not None:
            lines.append("- instrument-silent probes: %d/%d (%.2f) — a probe is *silent* when its "
                          "pattern matched in NEITHER arm in ANY rep."
                          % (score_result.get('silent', 0), score_result.get('scored', 0), sf))
        if score_result.get('blackout'):
            lines.append("")
            lines.append("🟥 **RUN-BLACKOUT** — every scored probe was instrument-silent. This run "
                          "measured NOTHING; it is not evidence that any rule stopped firing. Read "
                          "the preserved response bodies under `tracks/_meta/live_eval_runs/` before "
                          "attributing this to the harness.")
        elif score_result.get('blackout_suspect'):
            lines.append("")
            lines.append("⚠️ **BLACKOUT-SUSPECT (advisory — the verdict above is unchanged)** — a "
                          "majority of probes were instrument-silent while at least one channel "
                          "demonstrably worked. Both a broad real regression and a partial "
                          "instrument failure produce this shape, and this file cannot tell them "
                          "apart; the preserved response bodies can.")
        lines.append("")
    lines.append("## Excluded (from probes.md, 33-row snapshot)")
    lines.append("")
    lines.append("| Probe | Reason |")
    lines.append("|---|---|")
    for e in select_result['excluded']:
        lines.append("| %s | %s |" % (e['id'], e['reason']))
    if select_result['warnings']:
        lines.append("")
        lines.append("## Warnings")
        for w in select_result['warnings']:
            lines.append("- %s" % w)
    return "\n".join(lines) + "\n"


# ── CLI ──────────────────────────────────────────────────────────────────────────────────────
def _cmd_select(args):
    probes_md_rows = parse_probes_md(args.probes_md)
    live_rows = parse_probes_live(args.probes_live)
    result = build_selection(probes_md_rows, live_rows)
    filtered, unknown = filter_selection(result['selected'], subset=args.subset, ids=args.ids)

    print("── probe_live_eval selection ──────────────────────────────────────")
    print("probes.md rows: %d   selectable-per-rule: %d   authored-in-yaml: %d"
          % (len(probes_md_rows),
             sum(1 for r in probes_md_rows if classify(r['id'], r['input'], r['class'])[0] == 'SELECTABLE'),
             len(result['selected'])))
    if args.subset or args.ids:
        print("filter applied: %s -> %d probe(s) this run"
              % (('--subset ' + str(args.subset)) if args.subset else ('--ids ' + args.ids), len(filtered)))
    if unknown:
        print("⚠️  unknown ids requested via --ids (not in the live-authored set): %s" % ', '.join(unknown))
    print("")
    print("SELECTED (%d):" % len(filtered))
    for p in filtered:
        print("  %-14s polarity=%-7s input=%r" % (p['id'], p['polarity'], p['input']))
    print("")
    print("EXCLUDED (%d):" % len(result['excluded']))
    for e in result['excluded']:
        print("  %-14s %s" % (e['id'], e['reason']))
    if result['warnings']:
        print("")
        print("WARNINGS (%d):" % len(result['warnings']))
        for w in result['warnings']:
            print("  - %s" % w)

    if args.json_out:
        with open(args.json_out, 'w', encoding='utf-8') as f:
            json.dump({'selected': filtered, 'excluded': result['excluded'],
                       'warnings': result['warnings'], 'unknown_ids': unknown,
                       'full_selected': result['selected']}, f, ensure_ascii=False, indent=2)
    if args.spec_dir:
        os.makedirs(args.spec_dir, exist_ok=True)
        for p in filtered:
            with open(os.path.join(args.spec_dir, p['id'] + '.input.txt'), 'w', encoding='utf-8') as f:
                f.write(p['input'])
            with open(os.path.join(args.spec_dir, p['id'] + '.control.txt'), 'w', encoding='utf-8') as f:
                f.write(p['control_input'])
            # Written ONLY when declared — probe_live_eval.sh keys the third live call off this
            # file's existence, so an absent file must mean "no second control", never "empty one".
            if p.get('control_input_b'):
                with open(os.path.join(args.spec_dir, p['id'] + '.control_b.txt'), 'w', encoding='utf-8') as f:
                    f.write(p['control_input_b'])
        with open(os.path.join(args.spec_dir, 'selected_ids.txt'), 'w', encoding='utf-8') as f:
            for p in filtered:
                f.write(p['id'] + '\n')

    # Dead pointers and stale yaml entries are authoring bugs, not scoring failures — the lane
    # test asserts this exit code directly (fixture with a deliberately dead id → nonzero).
    dead = [w for w in result['warnings'] if w.startswith('DEAD-POINTER')]
    return 1 if dead else 0


def _cmd_score(args):
    live_rows = parse_probes_live(args.probes_live)
    with open(args.select_json, encoding='utf-8') as f:
        select_result = json.load(f)
    ids_in_order = [line.strip() for line in open(args.ids_file, encoding='utf-8') if line.strip()]
    score_result = score_run(live_rows, args.run_root, ids_in_order, args.threshold, args.model,
                             reps=getattr(args, 'reps', 1))

    print("── probe_live_eval score ──────────────────────────────────────────")
    for r in score_result['rows']:
        line = ("  %-14s %-14s primary_hit=%-5s control_hit=%-5s polarity=%s"
                % (r['id'], r['verdict'], r.get('primary_hit'), r.get('control_hit'), r.get('polarity', '')))
        reason = r.get('reason', '')
        if reason:
            line += " reason=%s" % reason
        print(line)
    print("")
    pr = score_result['pass_rate']
    pr_s = ("%.2f" % pr) if pr is not None else "n/a"
    print("total=%d ran=%d failed_to_run=%d uncalibrated=%d passed=%d pass_rate=%s threshold=%.2f"
          % (score_result['total'], score_result['ran'], score_result['failed_to_run'],
             score_result['uncalibrated'], score_result['passed'], pr_s, score_result['threshold']))
    sf = score_result.get('silent_fraction')
    if sf is not None:
        print("instrument-silent: %d/%d (%.2f)"
              % (score_result.get('silent', 0), score_result.get('scored', 0), sf))
    if score_result.get('blackout'):
        print("🟥 RUN-BLACKOUT — every scored probe was silent in BOTH arms. Nothing was measured;")
        print("   this is not evidence any rule stopped firing. Read the preserved response bodies.")
    elif score_result.get('blackout_suspect'):
        print("⚠️  BLACKOUT-SUSPECT (advisory, verdict unchanged) — majority of probes silent while")
        print("   at least one channel worked. Real broad regression and partial instrument failure")
        print("   look identical here; the preserved response bodies tell them apart.")
    print("OVERALL: %s (rc=%d)" % (score_result['overall'], score_result['rc']))

    if args.report_out:
        md = render_report_md(select_result, score_result, args.run_date or str(date.today()))
        os.makedirs(os.path.dirname(args.report_out), exist_ok=True)
        with open(args.report_out, 'w', encoding='utf-8') as f:
            f.write(md)
        print("report: %s" % args.report_out)

    return score_result['rc']


def main():
    import argparse
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest='cmd', required=True)

    sp = sub.add_parser('select')
    sp.add_argument('--probes-md', required=True)
    sp.add_argument('--probes-live', required=True)
    sp.add_argument('--subset')
    sp.add_argument('--ids')
    sp.add_argument('--json-out')
    sp.add_argument('--spec-dir')

    sc = sub.add_parser('score')
    sc.add_argument('--probes-live', required=True)
    sc.add_argument('--select-json', required=True)
    sc.add_argument('--ids-file', required=True)
    sc.add_argument('--run-root', required=True)
    sc.add_argument('--threshold', type=float, required=True)
    sc.add_argument('--model', required=True)
    sc.add_argument('--report-out')
    sc.add_argument('--run-date')
    sc.add_argument('--reps', type=int, default=1)

    args = ap.parse_args()
    if args.cmd == 'select':
        sys.exit(_cmd_select(args))
    elif args.cmd == 'score':
        sys.exit(_cmd_score(args))


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""finding_verify.py — typed review findings in, cross-family verdicts on, false positives dropped BY CODE.

WHY THIS EXISTS. FH's review output is prose end to end: a governor reads, judges, and writes. Nothing
in that path can be counted, filtered, or handed to a second family, because a prose finding has no
fields. Measured 2026-09-08 on eight GHSA cases x3: FH's review made 52 claims of which 5 were wrong
about the code (9.6%); a sibling harness (octo) made 73 claims -- 40% MORE -- with 2 wrong (2.7%). Its
advantage is not better reading. Its pipeline emits findings as typed JSON, has a different-family
agent stamp each one `confirmed|false-positive|needs-debate`, and then DELETES the false positives with
a filter. Judgment stays with a model; the drop is mechanical. This script is that stage for FH.

WHAT IS MECHANIZED AND WHAT IS NOT (CLAUDE.md 'Mechanization Boundary'). The channel is mechanized:
every finding carries a verdict, the verdict comes from a command that is not the author, the drop is
performed by code, and what was dropped is written down. The judgment -- is this claim true of the
source -- is made by whatever model the verifier command runs, never frozen here. This file contains
no rule about what makes a finding wrong.

DEGRADE DIRECTION. A review surface is reversible, so an unreachable verifier does not block. It must
not be silent either: with no verifier every finding is stamped `unverified`, NOTHING is dropped, the
status is UNVERIFIED and the exit code says so. An unverified run must never read as a clean one.

THE DROP SIDE IS MEASURED TOO, OR THE RUN SAYS IT WAS NOT. A stage that deletes claims improves any
precision number for free: delete enough and nothing wrong survives. So the error rate of the SURVIVORS
is not a result on its own — it is only meaningful beside the error rate of the DELETIONS. Measured on
this pipeline's first real use, 2026-09-08: the verifier dropped a claim that the project's own earlier
record grades a real A-tier defect. One drop, one wrong. That is why `--audit-verifier` exists and why
the summary line carries `drop_audit=UNAUDITED` in bold terms when drops happened and nobody checked
them. The auditor must not be the family that made the drop; when it is the family that PRODUCED the
finding, that is an appeal by an interested party and is recorded as `audit_role=appeal`, not hidden.

INPUT   JSONL, one finding per line:
        {"id","file","line","severity","category","title","detail","confidence","producer_family"}
        `id` and `title` are required; the rest are optional and pass through untouched.
        When `producer_family` is present and equals the verifier's family, that finding is stamped
        `unverified` rather than judged -- see the note above VERDICTS.
EXIT      0 verified, survivors · 1 verified, nothing survived · 2 usage/schema ·
          3 UNVERIFIED (something was never judged) · 4 drops never audited ·
          5 SEEDED control degraded (a known-true finding was deleted), inconclusive
          (the verifier abstained on one) or absent
          (the control never entered the run — which is not the same as passing).
AUDITOR   Optional, and required for the drop-side number to exist. Same protocol as the verifier, but
        it receives only the DROPPED findings and answers {"id","verdict":"correct-drop|wrong-drop|
        uncertain","why"}. A `wrong-drop` finding is moved back into confirmed.jsonl with
        `reinstated: true` -- the audit is not advisory, it reverses the deletion.
VERIFIER  A command that reads the findings JSONL on stdin and writes JSONL verdicts on stdout:
        {"id","verdict":"confirmed|false-positive|needs-debate","why"}
        Set it with --verifier or FH_VERIFY_CMD. Run it as a DIFFERENT model family than the author;
        this script cannot check that, and says so rather than pretending to.
OUTPUT  <out>/confirmed.jsonl  survivors (confirmed + needs-debate, the latter flagged)
        <out>/dropped.jsonl    false positives, with the verifier's reason -- never silent
        stdout                 one summary line, machine-readable
EXIT    0 verified and (no drops, or drops audited) with >=1 survivor · 1 same but nothing survives
        3 UNVERIFIED (degraded) · 4 drops happened and were never audited · 2 usage or schema error
"""
import argparse, json, os, subprocess, sys

REQUIRED = ("id", "title")
VERDICTS = ("confirmed", "false-positive", "needs-debate")
AUDIT_VERDICTS = ("correct-drop", "wrong-drop", "uncertain")

# A finding is never verified by the family that produced it. That is the one property of the record
# this file enforces on its own: same-family review shares the author's blind spot, so a verdict from
# the producer is not a second opinion. It is a channel rule, not a judgment -- the script does not
# decide whether the claim is true, only that the party answering must not be the party asking.


def _schema_error(msg):
    # R4 #3: a string SystemExit exits 1 — the documented code for "verified, nothing survived".
    #        Schema rejection is exit 2, and a consumer treating 0/1 as "completed" must not see 1 here.
    print(msg, file=sys.stderr)
    sys.exit(2)


def read_findings(path):
    out, seen = [], set()
    src = sys.stdin if path == "-" else open(path, encoding="utf-8")
    for n, line in enumerate(src, 1):
        line = line.strip()
        if not line:
            continue
        try:
            d = json.loads(line)
        except json.JSONDecodeError as e:
            _schema_error(f"finding_verify: line {n} is not JSON: {e}")
        if not isinstance(d, dict):
            # R5 #3: `[]` / `null` parse fine and then crash on .get() with exit 1 (= "nothing survived")
            _schema_error(f"finding_verify: line {n} is not a JSON object")
        for k in REQUIRED:
            if not d.get(k):
                _schema_error(f"finding_verify: line {n} missing required field '{k}'")
        # 🟥 R4 #7: audit/verdict metadata is OURS to write — a producer row arriving with
        #    `reinstated: true` was counted as recovered coverage by the driver (probe: 1/2 → 2/2).
        for k in ("verdict", "verify_note", "reinstated", "drop_verdict", "audit_note", "audit_why"):
            d.pop(k, None)
        # 🟥 R3 #1: verdicts are keyed by str(id) (run_verifier), so 101 and "101" are ONE key
        #    there — uniqueness here must use the same form, or both rows take whichever verdict
        #    came last (reproduced: false-positive + confirmed → confirmed=2, exit 0).
        if str(d["id"]) in seen:
            _schema_error(f"finding_verify: duplicate id {d['id']!r} on line {n} (ids compare as strings)")
        seen.add(str(d["id"]))
        out.append(d)
    return out


def run_verifier(cmd, findings, allowed=VERDICTS):
    """Returns (verdicts_by_id, error_or_None). Any failure degrades; it never raises.

    `allowed` is the verdict vocabulary. The audit pass speaks a different one, and a verdict outside
    the expected set is dropped rather than coerced -- a stage that silently reinterprets an unknown
    label is how an unanswered question becomes an answer."""
    payload = "\n".join(json.dumps(f, ensure_ascii=False) for f in findings) + "\n"
    # 🟥 A LIST MEANS argv; A STRING MEANS A SHELL. The caller decides, and the shipped caller
    # (finding_pipeline.sh) now hands a list, so no shell parses our paths.
    #
    # Why this branch exists (cross-family security review, 2026-09-09, reproduced on dash):
    # the string form is executed with `shell=True`, i.e. by `/bin/sh`. Quoting the interpolated
    # path with bash's `printf %q` is NOT enough, because %q emits bash-only `$'...'` for a path
    # containing a newline, and `/bin/sh` on most Linux distributions is **dash**, which does not
    # understand that syntax -- the quoting comes apart and a crafted filename executes a second
    # command. macOS cannot observe this at all: its /bin/sh is bash-derived, so a local run is
    # green while the shipped npm package is not. The fix is not better escaping; it is not
    # handing a shell the string in the first place.
    shell = isinstance(cmd, str)
    try:
        p = subprocess.run(cmd, shell=shell, input=payload, capture_output=True,
                           text=True, timeout=int(os.environ.get("FH_VERIFY_TIMEOUT", "1200")))
    except Exception as e:                                   # noqa: BLE001 - degrade on anything
        return {}, f"verifier did not run: {e}"
    if p.returncode != 0:
        return {}, f"verifier exit {p.returncode}: {(p.stderr or '').strip()[:200]}"
    got = {}
    for line in p.stdout.splitlines():
        line = line.strip()
        if not line or not line.startswith("{"):
            continue                                          # tolerate chatter around the JSONL
        try:
            d = json.loads(line)
        except json.JSONDecodeError:
            continue
        if d.get("id") and d.get("verdict") in allowed:
            # 🟥 ids are keyed AS STRINGS. A JSONL row may carry an integer id and a verifier may
            # answer with the string form (or vice versa); `verdicts.get(101)` then misses
            # `{"101": ...}` and the finding comes back `unverified` forever — a finding with an
            # integer id could never be verified at all. Found while writing the seeded-control
            # lane for the same type mismatch (cross-family round 4, finding 7; this second half was
            # not in the report — the lane surfaced it).
            got[str(d["id"])] = d
    if not got:
        return {}, "verifier returned no parseable verdict"
    return got, None


def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("findings", help="JSONL file, or - for stdin")
    ap.add_argument("--out", required=True, help="directory for confirmed.jsonl / dropped.jsonl")
    ap.add_argument("--verifier-argv", default=None,
                    help="JSON array form of --verifier. Executed as argv (no shell), which is the "
                         "only form immune to path-shaped injection. Wins over --verifier.")
    ap.add_argument("--audit-verifier-argv", default=None,
                    help="JSON array form of --audit-verifier. Same reason.")
    ap.add_argument("--verifier", default=os.environ.get("FH_VERIFY_CMD", ""),
                    help="shell command; findings JSONL on stdin, verdict JSONL on stdout")
    ap.add_argument("--family", default=os.environ.get("FH_VERIFY_FAMILY", "unstated"),
                    help="model family of the verifier, recorded verbatim and never checked")
    ap.add_argument("--audit-verifier", default=os.environ.get("FH_AUDIT_CMD", ""),
                    help="command that re-checks the DROPPED findings; without it the run is UNAUDITED")
    ap.add_argument("--seeded", default="",
                    help="comma-separated finding ids that are KNOWN-TRUE. They are ordinary rows in "
                         "the input; the verifier is never told which they are. A filter that buys "
                         "precision by deleting reports itself by deleting these.")
    ap.add_argument("--seeded-file", default="",
                    help="file with one known-true finding id per line (same meaning as --seeded)")
    ap.add_argument("--audit-family", default=os.environ.get("FH_AUDIT_FAMILY", "unstated"),
                    help="model family of the auditor; must differ from the verifier's")
    a = ap.parse_args()

    # argv 형태가 있으면 그것이 실행 형태다 — 문자열은 셸을 타므로 후순위다.
    def _as_argv(raw, label):
        if not raw:
            return None
        try:
            v = json.loads(raw)
        except json.JSONDecodeError as e:
            raise SystemExit("%s must be a JSON array: %s" % (label, e))
        if not (isinstance(v, list) and v and all(isinstance(x, str) for x in v)):
            raise SystemExit("%s must be a non-empty JSON array of strings" % label)
        return v

    a.verifier = _as_argv(a.verifier_argv, "--verifier-argv") or a.verifier
    a.audit_verifier = _as_argv(a.audit_verifier_argv, "--audit-verifier-argv") or a.audit_verifier

    # 🟥 The seeded control is parsed BEFORE anything runs. Parsing it at the end meant a bad
    # control file surfaced only after the verifier had run and the output files and the VERIFIED
    # summary were already written — and a UnicodeDecodeError there escaped `except OSError` and
    # exited 1, which is this CLI's documented code for "verified, nothing survived". A consumer
    # accepting 0 and 1 would have read a configuration failure as a completed run.
    # (cross-family review 2026-09-09, findings 3 and 4, both reproduced.)
    seeded = [x.strip() for x in a.seeded.split(",") if x.strip()]
    if a.seeded_file:
        try:
            with open(a.seeded_file, encoding="utf-8") as fh:
                from_file = [ln.strip() for ln in fh if ln.strip() and not ln.startswith("#")]
        except (OSError, UnicodeDecodeError) as e:
            print("finding_verify: --seeded-file unusable: %s" % e, file=sys.stderr)
            return 2
        # 🟥 "option supplied but it yielded nothing" is NOT "option omitted". A repository-controlled
        # control file that goes empty would otherwise silently turn calibration off and still exit 0.
        if not from_file:
            print("finding_verify: --seeded-file %r yielded no ids — a control file that declares "
                  "nothing is a disabled control, not an absent one" % a.seeded_file, file=sys.stderr)
            return 2
        seeded += from_file
    seeded = sorted(set(seeded))

    # 문자열이든 리스트든 «비어 있나»를 같은 방법으로 묻는다 — 리스트에 .strip() 은 없다.
    def _configured(cmd):
        return bool(cmd) if isinstance(cmd, list) else bool(str(cmd or "").strip())

    findings = read_findings(a.findings)
    os.makedirs(a.out, exist_ok=True)

    if not _configured(a.verifier):
        verdicts, err = {}, "no verifier configured (--verifier / FH_VERIFY_CMD)"
    else:
        verdicts, err = run_verifier(a.verifier, findings)

    confirmed, dropped, debate, unverified = [], [], 0, 0
    for f in findings:
        v = verdicts.get(str(f["id"]))
        if v is None:
            # Degraded, or the verifier skipped this one. Keep it, mark it, never drop it silently.
            f = dict(f, verdict="unverified",
                     verify_note=err or "verifier returned no verdict for this finding")
            unverified += 1
            confirmed.append(f)
            continue
        prod = f.get("producer_family")
        # 🟥 ABSENT is not CLEAN. This guard is the one property this file claims to enforce, and
        # until 2026-09-09 it hung on an OPTIONAL field: omit `producer_family` and the check was
        # skipped entirely, so a family verified its own findings and the run reported
        # `status=VERIFIED rc=0`. Reproduced with a known pair — same table, same verifier, the
        # field the only difference: with it `unverified=1 rc=3`, without it `confirmed=1 rc=0`.
        # A missing producer cannot PROVE the verifier is not the author, so the fail-closed
        # answer is the same one an actual self-verification gets: `unverified`, never a silent
        # pass. (The wired path never reached this — `finding_pipeline.sh` refuses to route a
        # table with no usable `producer_family` (exit 3) and `finding_fleet.sh` always stamps it
        # — but this script ships its own CLI, and a hand-built table is a supported entry point.)
        if not prod:
            f = dict(f, verdict="unverified", verify_note="finding declares no producer_family; "
                     f"cannot establish that the verifier ({a.family}) is not its author")
            unverified += 1
            confirmed.append(f)
            continue
        if prod == a.family:
            f = dict(f, verdict="unverified", verify_note="verifier is the producing family "
                     f"({a.family}); a finding is not verified by its own author")
            unverified += 1
            confirmed.append(f)
            continue
        f = dict(f, verdict=v["verdict"], verify_why=v.get("why", ""), verify_family=a.family)
        if v["verdict"] == "false-positive":
            dropped.append(f)
        else:
            if v["verdict"] == "needs-debate":
                debate += 1
            confirmed.append(f)

    # ── drop audit ────────────────────────────────────────────────────────────────────────────────
    # Nothing here judges whether a drop was right; it routes the question to a party that did not make
    # the drop, and moves a reversed drop back. The refusal to report a bare precision number when this
    # did not run is the mechanized part.
    audited = wrong_drops = reinstated = 0
    # 감사가 `dropped` 를 재할당하기 전에 «필터가 무엇을 지웠나» 를 얼려 둔다. SEEDED 는 이것을 읽는다.
    pre_audit_dropped_ids = [f.get("id") for f in dropped]
    audit_status = "UNAUDITED"
    audit_note = ""
    if dropped and _configured(a.audit_verifier):
        if a.audit_family == a.family:
            audit_note = ("auditor is the family that made the drop (%s) -- refused; a deletion is not "
                          "checked by the party that made it" % a.family)
        else:
            av, aerr = run_verifier(a.audit_verifier, dropped, AUDIT_VERDICTS)
            if aerr:
                audit_note = "auditor did not answer: " + aerr
            else:
                kept = []
                for d in dropped:
                    r = av.get(str(d["id"]))   # R3 #7: same normalization as the verify lookup
                    if r is None:
                        kept.append(dict(d, drop_verdict="unaudited"))
                        continue
                    audited += 1
                    role = "appeal" if d.get("producer_family") == a.audit_family else "independent"
                    d = dict(d, drop_verdict=r["verdict"], drop_why=r.get("why", ""),
                             audit_family=a.audit_family, audit_role=role)
                    if r["verdict"] == "wrong-drop":
                        wrong_drops += 1
                        reinstated += 1
                        # 🟥 A reinstated row used to keep its ORIGINAL top-level
                        # `verdict: "false-positive"` while moving into confirmed.jsonl. Every
                        # consumer that counts decisions by top-level verdict then lost it from both
                        # sides — the driver's coverage read 0% on a run that was fully judged and
                        # audited. The row's verdict must state the decision that now stands; the
                        # superseded one is kept under its own key rather than deleted.
                        # (cross-family round 4, gemini family, A severity — three codex rounds
                        # missed it because they were the same family that wrote the counting fix.)
                        confirmed.append(dict(d, reinstated=True,
                                              pre_audit_verdict=d.get("verdict"),
                                              verdict="confirmed"))
                    else:
                        kept.append(d)
                dropped = kept
                # 🟥 AUDITED must mean EVERY drop was answered. Setting it unconditionally let an
                # auditor that answered one unrelated id produce `audited=0 drop_audit=AUDITED` and
                # exit 0 — the deletions went unchecked while the record said they were checked.
                # (cross-family review 2026-09-09, reproduced; an EMPTY audit already returned 4, so
                # the hole was specifically the PARTIAL answer.) A partial audit is not an audit.
                unanswered = sum(1 for d in dropped if d.get("drop_verdict") == "unaudited")
                if unanswered:
                    audit_status = "PARTIAL"
                    audit_note = ("auditor answered %d of %d drops; %d unanswered — a partial audit "
                                  "is not an audit" % (audited, audited + unanswered, unanswered))
                else:
                    audit_status = "AUDITED"
    elif not dropped:
        audit_status = "NO-DROPS"

    for name, rows in (("confirmed.jsonl", confirmed), ("dropped.jsonl", dropped)):
        with open(os.path.join(a.out, name), "w", encoding="utf-8") as fh:
            for r in rows:
                fh.write(json.dumps(r, ensure_ascii=False) + "\n")

    # 🟥 COVERAGE IS NOT OPTIONAL. An error rate computed over judged findings while the unjudged
    # ones sit outside the denominator is a rate at an unstated operating point, and two arms with
    # different abstention rates are then not comparable at all. This is a named, documented flaw in
    # the selective-classification literature (evaluation "assumes fixed working points",
    # arXiv:2407.01032), and our own five-arm table is an instance of it: UNVERIFIABLE was ~half the
    # claims and was silently dropped from the denominator. So the line carries coverage
    # unconditionally, exactly like DROPS does — same discipline, second application.
    # 🟥 `needs-debate` IS NOT A DECISION. Counting it as covered let every finding come back
    # `needs-debate` and still print coverage=100% — the exact thing coverage exists to prevent
    # (cross-family review 2026-09-09, finding 2, reproduced). Decision coverage = findings that got
    # a RESOLVED truth judgment; debate and unverified are both abstentions, of different kinds.
    # Percentage is FLOORED, never rounded: 200/201 must not print 100%.
    judged = len(findings) - unverified - debate
    pct = (judged * 100) // len(findings) if findings else 0
    # 🟥 `VERIFIED` must not be stamped on a run in which nothing was decided. An all-debate run
    # left `unverified == 0`, so the summary said VERIFIED while coverage said 0% — the exit code was
    # already fixed to 3 but the human-readable half still lied.
    # (cross-family round 5, gemini family, A severity — a half-fix that stopped at the exit code.)
    status = "UNVERIFIED" if (unverified or (findings and judged == 0)) else "VERIFIED"
    print("FINDINGS in={} confirmed={} dropped={} debate={} unverified={} coverage={}/{} ({}%) "
          "family={} status={}{}".format(
        # `confirmed=` excludes BOTH abstention kinds. Debate rows live in the confirmed list for
        # output purposes, but counting them as confirmations double-reports them beside `debate=`.
        len(findings), len(confirmed) - unverified - debate, len(dropped), debate, unverified,
        judged, len(findings), pct,
        a.family, status, "" if not err else " reason=" + err.replace("\n", " ")))
    # 🟥 The drop line is unconditional. A survivor-side number without it is a precision claim made by
    # deleting, and this pipeline does not let a reader compute one without seeing whether the
    # deletions were checked.
    print("DROPS dropped={} audited={} wrong_drops={} reinstated={} auditor={} drop_audit={}{}".format(
        len(dropped), audited, wrong_drops, reinstated, a.audit_family, audit_status,
        "" if not audit_note else " reason=" + audit_note.replace("\n", " ")))
    # 🟥 SEEDED — the known-pair discipline applied to the FILTER, not to a scanner.
    # This repo has required known-pair calibration of instruments for a long time and had never
    # once applied it to the deletion stage, which is also an instrument. Known-true findings are
    # mixed into the input as ordinary rows; their ids live only in this process and never reach the
    # verifier's prompt. A stage that buys precision by deleting therefore reports itself.
    if not seeded:
        seed_status, s_present, s_kept, s_dropped, s_abstained = "NOT_PROVIDED", 0, 0, 0, 0
    else:
        # 🟥 ids are compared AS STRINGS on both sides. A JSONL row may legitimately carry an
        # integer id, and `"101" in {101}` is False in Python — the control then reported ABSENT
        # (exit 5) on a run where the seed was right there. (cross-family round 4, finding 7.)
        # 씨앗은 «라우팅 id» 로도 «원래 멤버 id» 로도 선언할 수 있다. fleet 이 id 를 재번호하므로
        # 호출자 어휘로 선언하려면 후자가 필요하다.
        ids_in = {str(f.get("id")) for f in findings}
        ids_in |= {str(f["member_id"]) for f in findings if f.get("member_id") is not None}
        present = [i for i in seeded if str(i) in ids_in]
        def _row_matches(f, sid):
            # R8 #3: a missing alias must not become the string "None" — a legitimate seed named "None"
            #        matched every alias-less row and reported AMBIGUOUS.
            mid = f.get("member_id")
            return str(f.get("id")) == str(sid) or (mid is not None and str(mid) == str(sid))
        # 🟥 A SEED MUST RESOLVE TO EXACTLY ONE ROW. `member_id` is the member's own id and is only
        # locally unique — two fleet members can both emit `1`. Binding the seed to every matching
        # row then makes an unrelated member's drop read as "the control was deleted", and a
        # perfectly legitimate run fails closed with exit 5. A false alarm on a fail-closed surface
        # is not a safe default: it trains the override. So an ambiguous declaration is reported AS
        # ambiguous, by name, instead of being silently resolved the pessimistic way.
        # (cross-family round 6, gemini family, A severity.)
        ambiguous = [i for i in present if sum(1 for f in findings if _row_matches(f, i)) > 1]
        # 🟥 THE PRE-AUDIT DELETION SET, not the post-audit one. `dropped` is reassigned when the
        # auditor reinstates a wrong drop, so reading it here meant: verifier deletes the known-true
        # seed → auditor puts it back → SEEDED prints CLEAN, exit 0. The filter demonstrably deleted
        # a control and the control said it passed. Reinstatement repairs the OUTPUT; it does not
        # establish that the FILTER passed, and the filter is what this control measures.
        # (cross-family review 2026-09-09, finding 1 — A severity, reproduced.)
        dropped_ids = {str(i) for i in pre_audit_dropped_ids}
        # 🟥 SURVIVING IS NOT PASSING. The first version asked only "was the seed deleted?", so a
        # verifier that ABSTAINED on a known-true finding (`needs-debate`, or unverified) reported
        # kept=1 status=CLEAN exit 0 — precision bought by not deciding instead of by deleting,
        # which is the same purchase through a different door. A seed passes only when it received a
        # positive decision. (cross-family round 4, gemini family, A severity.)
        abstained_verdicts = {"needs-debate", "unverified"}
        verdict_of = {}
        for f in confirmed:
            verdict_of[str(f.get("id"))] = f.get("verdict")
        s_present = len(present)
        dropped_rows = [f for f in findings if str(f.get("id")) in dropped_ids]
        s_dropped = len([i for i in present if any(_row_matches(f, i) for f in dropped_rows)])
        s_abstained = len([i for i in present
                           if not any(_row_matches(f, i) for f in dropped_rows)
                           and any(_row_matches(f, i) and f.get("verdict") in abstained_verdicts
                                   for f in confirmed)])
        s_kept = s_present - s_dropped - s_abstained
        if ambiguous:
            seed_status = "AMBIGUOUS"
            print("finding_verify: seed(s) %s match more than one finding — member ids are only "
                  "locally unique; declare the routing id instead" % ",".join(ambiguous),
                  file=sys.stderr)
        elif len(present) < len(seeded):
            # A control that never entered the run is not a passing control. It looks exactly like a
            # clean one from the outside, which is the whole reason this branch exists.
            # 🟥 R3 #2: `not present` only caught TOTAL absence — z1 present + `missing` absent
            #    printed CLEAN exit 0. Any declared seed missing is ABSENT.
            seed_status = "ABSENT"
        elif s_dropped:
            seed_status = "DEGRADED"
        elif s_abstained:
            seed_status = "INCONCLUSIVE"
        else:
            seed_status = "CLEAN"
    print("SEEDED declared={} present={} kept={} dropped={} abstained={} status={}".format(
        len(seeded), s_present, s_kept, s_dropped,
        s_abstained if seeded else 0, seed_status))

    # 🟥 THE SEED VERDICT IS CHECKED FIRST. It used to sit after the two exit-3 branches, so a
    # single unrelated `unverified` finding anywhere in the batch masked a DEGRADED control: the
    # split returned 3, and in the driver rank_of(3) < rank_of(5), so "the filter deleted a
    # known-true finding" was suppressed into a generic unverified exit. The calibration verdict is
    # the more specific and the more serious fact, and it is reported as such.
    # (cross-family round 5, gemini family, A severity.)
    # 🟥 A VERIFIER THAT DID NOT RUN IS AN EXECUTION FAILURE, NOT A CONTROL AMBIGUITY. When the
    # verifier command crashes, every finding degrades to `unverified`, the seed among them becomes
    # `INCONCLUSIVE`, and the run used to exit 5 — reporting a calibration problem for what is
    # actually "the tool did not execute". The execution fact wins. (cross-family round 6.)
    if err and unverified:
        return 3
    if seed_status in ("ABSENT", "DEGRADED", "INCONCLUSIVE", "AMBIGUOUS"):
        return 5
    if unverified:
        return 3
    # 🟥 ZERO DECISIONS IS NOT A PASS. Every finding coming back `needs-debate` left `unverified=0`,
    # so status stamped VERIFIED and the run exited 0 while coverage said 0% — a caller reading exit
    # codes saw a completed run in which nothing was actually judged.
    # (cross-family round 4, gemini family, A severity.)
    if findings and judged == 0:
        return 3                      # a known-true finding was deleted, or the control never ran
    if audit_status in ("UNAUDITED", "PARTIAL"):
        return 4                      # drops happened and nobody checked them: not a completed run
    return 0 if confirmed else 1


if __name__ == "__main__":
    sys.exit(main())

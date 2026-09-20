#!/usr/bin/env python3
"""stale_ref_scan.py — a Zenodo reference is USED, and it resolves, but it points at a version of its
OWN RECORD FAMILY that is no longer the latest one.

WHY THIS EXISTS (measured 2026-09-20, this repo)
  `CITATION.cff` and four paper drafts cited the version DOI `10.5281/zenodo.20397566` — the v1.0
  DRAFT, arXiv-rejected, superseded twice since. That DOI is not broken: it resolves, HTTP 200, to a
  real record. So every check that asks "is this DOI valid?" passed. What was stale was not the
  VALUE — it was the WORLD the value pointed at. No instrument in this repo asked that question:
    halffix_propagation_scan.sh   only reads staged-diff tokens — silent if nobody touches the line
    claim_propagation_scan.py     only fires once someone registers a "retraction token"
    doc_claim_triad_scan.py       a different axis ("A calls B"), not "this ID is old"
  This tool asks Zenodo directly: for a cited record id, is there a NEWER version in the same family?

WHAT IT DOES NOT DO — read before trusting a 0
  🟥 It is a REVIEW SURFACE, not a block. Citing an OLD version on purpose is legitimate — pinning
     "what was claimed at that moment" (the exact use `field_verdict_crossfamily_gate.md §7`'s
     `tier1`/`tier2` distinction relies on for its own citations). So this tool does not fail a build;
     it lists candidates for a human to look at, same posture as `phantom-quench`.
  🟥 It checks the Zenodo API's OWN answer, not bibliographic truth beyond that. If Zenodo itself is
     wrong or slow to index a new version, this tool inherits that lag — UNRESOLVED and SUPERSEDED are
     read FROM Zenodo, not independently re-derived.
  🟥 Changelog / retraction prose is EXCLUDED on purpose. A line documenting "we used to cite X, now
     we cite Y" legitimately contains the old id — flagging it would bury the real signal under the
     record of already-fixed history. Detection is a HEADING cutoff (`<h1-6>…Changelog…`, or Markdown
     `#…Changelog`): once seen, every following line in that file is changelog context. This is
     mechanical and coarse — a doc with prose sections AFTER "Changelog" (unusual, none seen in this
     repo) would also be excluded; a paper that mentions an old id in body prose BEFORE any Changelog
     heading, without using changelog language, is NOT excluded (this is the case this tool exists to
     catch — see v1.0.3 below). Not a keyword scan of "retraction"/"superseded" prose — a heading is
     the only mechanical anchor calibrated here.
  🟥 Extraction requires the FULL DOI prefix (`10.5281/zenodo.<digits>`) or a Zenodo record URL
     (`zenodo.org/record(s)/<digits>`). A bare mention like `` `zenodo.20397566` `` (no `10.5281/`)
     inside prose is NOT extracted — this is deliberate, not an oversight: house convention marks such
     spans as code (backtick), i.e. a MENTION, the same class `citation_key_check.py` carves out for
     code spans. Widening this would need the same code-span-vs-prose split that tool already has.
  🟥 HTML soft-hyphenation (`10.5281/<wbr>zenodo.<wbr>20397566`) is unwrapped by stripping inline tags
     before matching — but only per-line; a DOI split ACROSS lines by markup is not reassembled.
  🟥 A "record id" here is a bare Zenodo numeric id (from a DOI or URL) — not an arXiv id, not a GitHub
     release tag, not a DOI from a different registrant prefix. Out of scope by construction.

RESOLUTION ALGORITHM (verified against the live API, 2026-09-20)
  GET https://zenodo.org/api/records/<id>  (urllib follows the redirect Zenodo issues for a concept id)
    · queried a CONCEPT id  → Zenodo 302s to the latest version; the JSON's own `id` != the id you
      queried  → verdict CONCEPT (always resolves to current by construction; never stale)
    · queried a VERSION id  → JSON's own `id` == the id you queried. Its `conceptrecid` names the
      family. A second call, `GET …/records/<conceptrecid>`, redirects to the family's CURRENT
      version and returns ITS `id`:
        current id == the id you queried  → verdict CURRENT
        current id != the id you queried  → verdict SUPERSEDED (this is the defect class)
    · fetch failed (404 / network / malformed JSON) → verdict UNRESOLVED — NOT a pass; see below.

EXIT CODES
   0  scanned; zero SUPERSEDED and zero UNRESOLVED candidates (changelog-excluded and CONCEPT/CURRENT
      candidates do not affect this)
   1  at least one SUPERSEDED or UNRESOLVED candidate — a review-surface finding, not a hard failure;
      the two are distinguished in the printed detail, not in the exit code (house convention already
      folds several defect classes into one rc in `citation_key_check.py`; UNRESOLVED is grouped here
      because the task statement is explicit that it "is not PASS", and this repo defines only three
      codes for this tool — 0 / 1 / 10 — leaving no fourth slot to split it into)
  10  instrument error — an input file could not be read, or (self-check only) a known-pair lane
      produced the wrong verdict

USAGE
  python3 scripts/stale_ref_scan.py --body <files...> [--offline-fixture <json>] [--json] [--timeout N]
  python3 scripts/stale_ref_scan.py --self-check      # known-pair, no network, run this first

OFFLINE FIXTURE FORMAT (for --offline-fixture, and what --self-check builds internally)
  A JSON object keyed by the EXACT string you would query (an id as it appears in the source text).
  Value = the JSON Zenodo's API would return AFTER following any redirect for that query, i.e.
  `{"id": <int>, "conceptrecid": "<str>"}`. A key absent from the fixture simulates a 404/UNRESOLVED —
  this is how the `--self-check` UNRESOLVED lane is produced without touching the network.

Python >= 3.9, stdlib only (urllib for the live path; --self-check and --offline-fixture need none).
"""
import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.request

TAG_RE = re.compile(r"<[^>]+>")
ZID_RE = re.compile(r"(?:10\.5281/zenodo\.|zenodo\.org/records?/)(\d+)", re.IGNORECASE)
#: 🟥 **헤딩 «텍스트 안 어디든»** 을 본다 — 초판은 «해시/태그 바로 뒤 첫 낱말» 이라
#: `# forge-harness (fh-meta) Changelog` 가 **안 걸렸다**(실행으로 확인: 4천 줄 릴리스 기록이
#: 통째로 «살아있는 인용» 으로 스캔됐다). 적대검증 A-2.
_CL_WORDS = r"(?:changelog|change\s+log|version\s+history|revision\s+history|release\s+notes)"
CHANGELOG_HTML_RE = re.compile(r"<h[1-6][^>]*>(?P<t>.*?)</h[1-6]>", re.IGNORECASE | re.DOTALL)
CHANGELOG_MD_RE = re.compile(r"^\s*#{1,6}\s+(?P<t>.+)$")
CHANGELOG_WORD_RE = re.compile(_CL_WORDS, re.IGNORECASE)

#: 🟥 **고정 인용(pin) 을 위한 탈출구.** 이미 발행된 판의 로컬 사본은 «고치면 기록이 아니게»
#: 되므로 구조적으로 수리 불가능한 SUPERSEDED 를 영구히 낸다(적대검증 A-5: 이 레포에만 셋).
#: 만족 불가능한 요구는 override 를 훈련시키므로, 파일이 스스로 «이건 스냅샷이다» 라고
#: 말할 수단을 준다. 🟥 **파일명 추론이 아니라 «파일이 선언한 것»** 이다 — 추론은 조용히 틀린다.
PIN_MARKER_RE = re.compile(r"stale-ref:\s*pinned", re.IGNORECASE)

#: 못 읽은 입력의 판별 — NUL 바이트 또는 디코드 실패율. 적대검증 S-1.
UNSCANNABLE_REPLACEMENT_RATIO = 0.02

API_BASE = "https://zenodo.org/api/records/"


def is_changelog_heading(line):
    """헤딩인가 + 그 헤딩 «텍스트 안에» changelog 계열 낱말이 있나. 두 조건 다 필요하다 —
    본문 산문에 「changelog」 가 나온다고 그 뒤를 전부 버리면 진짜 인용을 삼킨다."""
    for rx in (CHANGELOG_HTML_RE, CHANGELOG_MD_RE):
        m = rx.search(line) if rx is CHANGELOG_HTML_RE else rx.match(line)
        if m and CHANGELOG_WORD_RE.search(TAG_RE.sub("", m.group("t"))):
            return True
    return False


def load(path):
    """→ (lines, error). 🟥 **«읽지 못한 것» 을 «깨끗함» 으로 내보내지 않는다.**

    초판은 `errors="replace"` 로 무엇이든 읽어서, PDF 를 주면 `0 sites · rc=0` 이 나왔다 —
    정상 스캔과 **출력이 바이트로 같았다**(실행으로 확인). `paper/` 에는 같은 stem 의 `.pdf` 가
    `.html` 바로 옆에 다섯 개 있고 `--body paper/*` 가 가장 자연스러운 호출이다.
    이 레포 정본이 그 자리를 이미 이름 붙였다 — «A missing measurement is not a zero».
    적대검증 S-1.
    """
    try:
        with open(path, "rb") as fh:
            raw = fh.read()
    except OSError as e:
        return None, str(e)
    if b"\x00" in raw:
        return None, "binary (NUL byte) — not a text body"
    text = raw.decode("utf-8", errors="replace")
    if text:
        bad = text.count("\ufffd") / len(text)
        if bad > UNSCANNABLE_REPLACEMENT_RATIO:
            return None, "not decodable as UTF-8 (%.1f%% replacement chars)" % (bad * 100)
    return text.split("\n"), None


def scan_body(path, lines):
    """→ list of (line_no, record_id, snippet, in_changelog). Extraction runs on a per-line, inline-
    tag-stripped copy so `10.5281/<wbr>zenodo.<wbr>20397566` still matches; the ORIGINAL line is kept
    for the printed snippet. `in_changelog` reflects the flag's state AFTER this line is checked for a
    heading, so a heading line itself and everything after it (same file) are marked True."""
    in_changelog = False
    pinned = any(PIN_MARKER_RE.search(l) for l in lines[:40])
    sites = []
    for i, line in enumerate(lines, 1):
        if is_changelog_heading(line):
            in_changelog = True
        if pinned:
            in_changelog = True        # 스냅샷 파일 전체를 «기록» 으로 취급
        flat = TAG_RE.sub("", line)
        for m in ZID_RE.finditer(flat):
            snippet = line.strip()[:140]
            sites.append((i, m.group(1), snippet, in_changelog))
    return sites


def fetch_live(query_id, timeout):
    """One GET, following redirects (urllib does this by default) — this is how a CONCEPT id's query
    comes back as its LATEST version's own JSON. 404 / network / malformed JSON → None (UNRESOLVED)."""
    req = urllib.request.Request(
        API_BASE + str(query_id),
        headers={"User-Agent": "forge-harness/stale_ref_scan.py (+https://github.com/chrono-meta/forge-harness)"},
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            if resp.status != 200:
                return None
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError:
        return None
    except (urllib.error.URLError, TimeoutError, OSError, ValueError, json.JSONDecodeError):
        return None


def make_offline_fetch(fixture):
    def _fetch(query_id, timeout=0):
        return fixture.get(str(query_id))
    return _fetch


def make_cached(fetch_fn):
    """Wraps a raw fetch so the same query string is never sent twice in one run (a SUPERSEDED verdict
    needs two calls — the id itself, then its conceptrecid — and the concept is frequently shared
    across several cited sites of the same stale id)."""
    cache = {}

    def _cached(query_id, timeout=15):
        key = str(query_id)
        if key not in cache:
            cache[key] = fetch_fn(key, timeout)
        return cache[key]
    return _cached


def compute_rc(superseded, unresolved, unscannable):
    """🟥 **계기 실패와 문서 결함을 같은 rc 로 접지 않는다.**

    초판은 둘 다 rc=1 이었다. 그러면 Zenodo 429 한 번에 전 파일이 «문서 결함» 으로 뜨고,
    그걸 배선하면 «rc=1 은 보통 네트워크» 를 학습한 리뷰어가 **진짜 SUPERSEDED 를 무시**한다.
    이 레포 정본이 그 자리를 이름 붙였다 — 계기 오류는 «별도 비-PASS»(fh-gate.sh 의 exit-10).
    🟥 **10 이 1 을 지배한다** — 못 잰 것이 있으면 «발견 목록» 을 신뢰할 수 없다
    (`gate_shape_scan.sh` 의 «exit 3 이 히트를 지배» 와 같은 형태). 적대검증 A-7.

    🟥 **함수로 뽑은 이유**: `main()` 안에 인라인으로 두면 self-check 가 그 줄을 지나가지
    않아서, `rc = 0` 으로 고정하는 한 줄 뮤턴트가 **self-check 전 레인을 통과한다**(실측).
    """
    if unresolved or unscannable:
        return 10
    return 1 if superseded else 0


def resolve(record_id, cached_fetch, timeout=15):
    """→ dict with at least {"status": CONCEPT|CURRENT|SUPERSEDED|UNRESOLVED}. See module docstring
    §RESOLUTION ALGORITHM for the two-call shape."""
    rec = cached_fetch(record_id, timeout)
    if not rec or "id" not in rec:
        return {"status": "UNRESOLVED", "detail": "fetch failed (404 / network / malformed response)"}

    # 🟥 **정수 파싱을 감싼다** — 밖에 두면 InvenioRDM 의 영숫자 PID 나 비정수 `id` 에서
    #    미처리 예외가 나고, 파이썬 종료코드 1 이 «발견됨» 과 구별이 안 된다(적대검증 B-3).
    try:
        rid_int = int(record_id)
        api_id_raw = rec.get("id")
        api_id = None if api_id_raw is None else int(api_id_raw)
    except (TypeError, ValueError):
        return {"status": "UNRESOLVED",
                "detail": "record id is not an integer (schema changed?) — cannot compare families"}

    # `conceptrecid` 는 레거시 키, `parent.id` 는 InvenioRDM 키. 둘 다 본다.
    concept = rec.get("conceptrecid") or (rec.get("parent") or {}).get("id")

    # 🟥 **CONCEPT 은 «양성 테스트» 로 판정한다 — «id 가 다르다» 라는 부정 판별자가 아니라.**
    #    초판은 리다이렉트가 나면 무조건 CONCEPT 이라 적었는데, 그건 «리다이렉트의 이유» 를
    #    안 묻는다. Zenodo 가 병합·이전으로 «버전» id 를 리다이렉트하면 그건 정확히 이 도구가
    #    잡으려는 결함인데 «늙지 않음» 으로 조용히 흡수된다(적대검증 A-6, 방향이 false-negative).
    #    🟥 판별자는 **같은 응답 안에 이미 있다** — 라이브 API 직독(2026-09-20)으로 확인했다:
    #        GET /records/20397565 (컨셉) → id=22843702 · conceptrecid=20397565  ← 물어본 id 와 같다
    #        GET /records/20397566 (버전) → id=20397566 · conceptrecid=20397565  ← 다르다
    #    ⇒ CONCEPT ⟺ conceptrecid == 물어본 id. 네트워크 추가 호출 0.
    if concept is not None:
        try:
            if int(concept) == rid_int:
                return {"status": "CONCEPT", "resolved_to": api_id, "concept": concept}
        except (TypeError, ValueError):
            pass

    if api_id is None or api_id != rid_int:
        # 리다이렉트인데 컨셉이 아니다 — 무엇인지 모른다. 🟥 «안 늙음» 으로 접지 않는다.
        return {"status": "UNRESOLVED",
                "detail": "query %s redirected to %s but its concept is %s — not a concept id, "
                          "reason unknown" % (record_id, api_id, concept)}

    if not concept:
        return {"status": "UNRESOLVED", "detail": "response has no conceptrecid / parent.id — can't find its family"}

    latest = cached_fetch(concept, timeout)
    if not latest or "id" not in latest:
        return {"status": "UNRESOLVED", "detail": "concept %s did not resolve to a latest version" % concept}

    latest_id = latest.get("id")
    try:
        latest_int = int(latest_id)
    except (TypeError, ValueError):
        return {"status": "UNRESOLVED", "detail": "latest id is not an integer (schema changed?)"}
    if latest_int == rid_int:
        return {"status": "CURRENT", "concept": concept}
    return {"status": "SUPERSEDED", "concept": concept, "latest_id": latest_id, "latest_doi": latest.get("doi")}


# ---------------------------------------------------------------------------------------------------
# --self-check — known-pair, offline by construction (no --offline-fixture file needed)
# ---------------------------------------------------------------------------------------------------

SELF_CHECK_FIXTURE = {
    # known-positive: the real v1.0 draft version DOI this repo actually shipped stale, until
    # 2026-09-20 — querying it returns ITSELF (a genuine version id), whose family's current is a
    # DIFFERENT id → SUPERSEDED.
    "20397566": {"id": 20397566, "conceptrecid": "20397565"},
    # the family's current version, so the concept lookup above resolves here
    "22843702": {"id": 22843702, "conceptrecid": "20397565"},
    # known-negative: the real concept DOI — querying it comes back as ITS OWN latest version's JSON
    # (id 22843702 != the 20397565 you asked for) → CONCEPT, never stale by construction.
    "20397565": {"id": 22843702, "conceptrecid": "20397565"},
    # 99999999999 deliberately ABSENT → simulates 404 → UNRESOLVED
}


def run_self_check():
    fetch = make_cached(make_offline_fetch(SELF_CHECK_FIXTURE))
    lanes = [
        ("known-positive (stale version DOI)", "20397566", "SUPERSEDED"),
        ("known-negative (concept DOI)", "20397565", "CONCEPT"),
        ("unresolved (id absent from fixture / simulated 404)", "99999999999", "UNRESOLVED"),
        # control: querying the current version itself should read as CURRENT, not SUPERSEDED —
        # without this lane a scanner that always answers SUPERSEDED for any known version id would
        # still pass the known-positive lane above.
        ("control (current version DOI)", "22843702", "CURRENT"),
    ]
    print("stale-ref-scan self-check (known-pair, offline fixture, 0 network calls)")
    ok = True
    for label, rid, expect in lanes:
        got = resolve(rid, fetch)["status"]
        verdict = "PASS" if got == expect else "FAIL"
        if got != expect:
            ok = False
        print("  %s  %-55s [%s] expected=%s got=%s" % (verdict, label, rid, expect, got))

    # ═══════════════════════════════════════════════════════════════════════════════════════
    # 🟥 **추출·제외·rc 레인 — 이게 없으면 self-check 는 `resolve()` 24줄짜리 증거다.**
    #    적대검증 A-4 가 지적했고 **실행으로 확정됐다**: `scan_body` 를 `return []` 로 죽여도
    #    위 4레인이 그대로 4/4 PASS 였고, 그 상태로 실물을 돌리면 SUPERSEDED=1 이 0 으로
    #    바뀌었다. 즉 «아무것도 안 스캔하는 구현» 이 통과했다.
    #    픽스처 문구는 **이 레포 실물에서 뽑았다** — 머릿속 모형이 아니다.
    # ═══════════════════════════════════════════════════════════════════════════════════════
    print("  ── extraction / exclusion / rc lanes ──")

    def lane(label, cond, detail=""):
        nonlocal ok
        print("  %s  %-55s %s" % ("PASS" if cond else "FAIL", label, detail))
        if not cond:
            ok = False

    # ⓐ `<wbr>` 분할 — paper/forge_harness_v1.0.3.html:159 의 실물 형태
    wbr = ['<tr><td>forge-harness</td><td>10.5281/<wbr>zenodo.<wbr>20397566</td></tr>']
    got = [r for _, r, _, _ in scan_body("x.html", wbr)]
    lane("extract: <wbr>-split DOI", got == ["20397566"], str(got))

    # ⓑ URL 형태 — README.md:418 의 실물 형태
    url = ['> **FH papers**: v1.0.1 methodology · [Zenodo](https://zenodo.org/records/22542168)']
    got = [r for _, r, _, _ in scan_body("x.md", url)]
    lane("extract: zenodo.org/records/<id> URL", got == ["22542168"], str(got))

    # ⓒ 🟥 known-NEGATIVE — 추출기가 «아무 숫자나» 집지 않는다
    noise = ['version 20397566 of the spec', 'see zenodo for details', 'id=20397566']
    got = [r for _, r, _, _ in scan_body("x.md", noise)]
    lane("extract NEG: bare digits are NOT a citation", got == [], str(got))

    # ⓓ changelog 제외 — 헤딩 «텍스트 안» 어디든. plugins/fh-meta/CHANGELOG.md:1 의 실물 형태
    cl = ['# forge-harness (fh-meta) Changelog', 'see 10.5281/zenodo.20397566 for what was wrong']
    got = [(r, inc) for _, r, _, inc in scan_body("x.md", cl)]
    lane("exclude: '# <name> Changelog' heading is recognised", got == [("20397566", True)], str(got))

    # ⓔ 🟥 known-NEGATIVE — 본문 산문의 «changelog» 낱말은 컷오프가 아니다
    prose = ['We keep a changelog for this reason.', 'cite 10.5281/zenodo.20397566 here']
    got = [(r, inc) for _, r, _, inc in scan_body("x.md", prose)]
    lane("exclude NEG: prose mention does NOT cut off", got == [("20397566", False)], str(got))

    # ⓕ pin 마커 — 발행된 스냅샷은 통째로 기록으로 취급
    pin = ['<!-- stale-ref: pinned — published snapshot, editing it destroys the record -->',
           'cite 10.5281/zenodo.20397566']
    got = [(r, inc) for _, r, _, inc in scan_body("x.html", pin)]
    lane("exclude: 'stale-ref: pinned' marks the whole file a record", got == [("20397566", True)], str(got))

    # ⓖ 🟥 못 읽은 입력 — 이 파일 자신을 바이너리로 만들어 본다(임시 파일)
    import tempfile
    with tempfile.NamedTemporaryFile(suffix=".bin", delete=False) as tf:
        tf.write(b"%PDF-1.4\x00\x00binary garbage")
        binpath = tf.name
    lines, err = load(binpath)
    os.unlink(binpath)
    lane("load: binary input is UNSCANNABLE, not empty", lines is None and "binary" in (err or ""), str(err))

    # ⓗ known-NEGATIVE 짝 — 평범한 텍스트는 읽힌다(계기가 «전부 거부» 가 아님)
    lines2, err2 = load(__file__)
    lane("load NEG: this very file reads fine", lines2 is not None and err2 is None, str(err2))

    # ⓘ 🟥 rc 계산 — 이 레인이 없으면 `rc = 0` 한 줄 뮤턴트가 전 레인을 통과한다(실측 확인)
    lane("rc: clean → 0", compute_rc([], [], []) == 0)
    lane("rc: superseded → 1", compute_rc(["20397566"], [], []) == 1)
    lane("rc: unresolved dominates → 10", compute_rc(["20397566"], ["999"], []) == 10)
    lane("rc: unscannable dominates → 10", compute_rc(["20397566"], [], [("x.pdf", "binary")]) == 10)
    # 🟥 known-NEGATIVE — «항상 10» 을 내는 구현을 막는다
    lane("rc NEG: not always 10", compute_rc([], [], []) != 10)

    print("SELF-CHECK: %s" % ("PASS" if ok else "FAIL"))
    return 0 if ok else 10


# ---------------------------------------------------------------------------------------------------


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--body", nargs="+", metavar="FILE", help="file(s) to scan for Zenodo references")
    ap.add_argument("--offline-fixture", metavar="JSON",
                     help="use this fixture file instead of live Zenodo calls (see module docstring)")
    ap.add_argument("--timeout", type=float, default=15, help="per-request timeout, seconds (live mode only)")
    ap.add_argument("--max-sites", type=int, default=6, help="usage sites printed per flagged id (0 = all)")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--self-check", action="store_true", help="run the built-in offline known-pair and exit")
    args = ap.parse_args()

    if args.self_check:
        return run_self_check()

    if not args.body:
        print("🟥 --body is required unless --self-check is given", file=sys.stderr)
        return 10

    # 🟥 못 읽은 파일에서 **즉시 나가지 않는다** — 나머지를 안 재면 그것도 미측정이다.
    #    이름으로 모아 두고 rc 로 지배하게 한다(아래 `rc` 계산).
    files, unscannable = {}, []
    for p in args.body:
        lines, err = load(p)
        if lines is None:
            unscannable.append((p, err))
            continue
        files[p] = lines

    if args.offline_fixture:
        try:
            with open(args.offline_fixture, encoding="utf-8") as fh:
                fixture = json.load(fh)
        except (OSError, json.JSONDecodeError) as e:
            print("🟥 cannot read --offline-fixture %s: %s — rc=10" % (args.offline_fixture, e), file=sys.stderr)
            return 10
        raw_fetch = make_offline_fetch(fixture)
    else:
        raw_fetch = fetch_live
    cached_fetch = make_cached(raw_fetch)

    # candidate[id] = list of (file, line, snippet); changelog[id] = same, kept separate & uncounted
    candidates, changelog = {}, {}
    for p in files:
        for line_no, rid, snippet, in_changelog in scan_body(p, files[p]):
            bucket = changelog if in_changelog else candidates
            bucket.setdefault(rid, []).append((p, line_no, snippet))

    n_sites = sum(len(v) for v in candidates.values())
    n_changelog_sites = sum(len(v) for v in changelog.values())
    if not args.json:
        print("stale-ref-scan · body=%d file%s · %d Zenodo reference site(s) across %d distinct id(s) "
              "(+%d site(s) / %d id(s) excluded as changelog context)%s · review surface, not a gate"
              % (len(args.body), "" if len(args.body) == 1 else "s", n_sites, len(candidates),
                 n_changelog_sites, len(changelog),
                 "" if not unscannable else " · 🟥 %d UNSCANNABLE" % len(unscannable)))

    verdicts = {rid: resolve(rid, cached_fetch, args.timeout) for rid in candidates}

    superseded = sorted(rid for rid, v in verdicts.items() if v["status"] == "SUPERSEDED")
    unresolved = sorted(rid for rid, v in verdicts.items() if v["status"] == "UNRESOLVED")
    concept = sorted(rid for rid, v in verdicts.items() if v["status"] == "CONCEPT")
    current = sorted(rid for rid, v in verdicts.items() if v["status"] == "CURRENT")

    def where(sites):
        shown = sites if args.max_sites == 0 else sites[:args.max_sites]
        more = "" if len(shown) == len(sites) else " (+%d more)" % (len(sites) - len(shown))
        return " · ".join("%s:%d" % (os.path.basename(f), n) for f, n, _ in shown) + more

    # 🟥 **계기 실패와 문서 결함을 같은 rc 로 접지 않는다.**
    #    초판은 둘 다 rc=1 이었다. 그러면 Zenodo 429 한 번에 전 파일이 «문서 결함» 으로 뜨고,
    #    그걸 배선하면 «rc=1 은 보통 네트워크» 를 학습한 리뷰어가 **진짜 SUPERSEDED 를 무시**한다.
    #    이 레포 정본이 그 자리를 이름 붙였다 — 계기 오류는 «별도 비-PASS»(fh-gate.sh 의 exit-10).
    #    🟥 **10 이 1 을 지배한다** — 못 잰 것이 있으면 «발견 목록» 을 신뢰할 수 없다.
    #    (`gate_shape_scan.sh` 의 «exit 3 이 히트를 지배» 와 같은 형태.) 적대검증 A-7.
    rc = compute_rc(superseded, unresolved, unscannable)

    if args.json:
        print(json.dumps({
            "body": args.body,
            "sites": n_sites, "changelog_sites": n_changelog_sites,
            "superseded": superseded, "unresolved": unresolved, "concept": concept, "current": current,
            "unscannable": [{"file": f, "reason": e} for f, e in unscannable],
            # 🟥 기계 소비자에게 «어디인지» 를 준다 — 초판은 id 만 주고 file:line 이 0 이었다(B-1)
            "sites_by_id": {rid: [[f, n, sn] for f, n, sn in v] for rid, v in candidates.items()},
            "verdicts": verdicts,
            "summary": {"superseded": len(superseded), "unresolved": len(unresolved),
                        "concept": len(concept), "current": len(current),
                        "changelog_excluded": len(changelog),
                        "unscannable": len(unscannable), "rc": rc},
        }, ensure_ascii=False, indent=1, default=str))
        return rc

    for rid in superseded:
        v = verdicts[rid]
        print("  🟥 SUPERSEDED [%s]  cited ×%d — %s" % (rid, len(candidates[rid]), where(candidates[rid])))
        print("       family %s — current version is [%s] (%s), this citation points at an old one"
              % (v.get("concept"), v.get("latest_id"), v.get("latest_doi")))
    for rid in unresolved:
        v = verdicts[rid]
        print("  🟥 UNRESOLVED [%s]  cited ×%d — %s — %s" % (rid, len(candidates[rid]), where(candidates[rid]), v.get("detail")))
    for rid in concept:
        print("  ⬜ CONCEPT    [%s]  cited ×%d — %s — always resolves to current, not stale by construction"
              % (rid, len(candidates[rid]), where(candidates[rid])))
    for rid in current:
        print("  ⬜ CURRENT    [%s]  cited ×%d — %s — this version IS the latest in its family"
              % (rid, len(candidates[rid]), where(candidates[rid])))
    for f, err in unscannable:
        print("  🟥 UNSCANNABLE [%s] — %s — NOT scanned. «읽지 못한 것» 은 «깨끗함» 이 아니다"
              % (os.path.basename(f), err))
    for rid in sorted(changelog):
        print("  ⬜ CHANGELOG-EXCLUDED [%s]  ×%d — %s — after a Changelog heading, not counted as a live citation"
              % (rid, len(changelog[rid]), where(changelog[rid])))

    print("stale-ref verdict: SUPERSEDED=%d UNRESOLVED=%d UNSCANNABLE=%d CONCEPT=%d CURRENT=%d "
          "CHANGELOG-EXCLUDED=%d rc=%d"
          % (len(superseded), len(unresolved), len(unscannable), len(concept), len(current),
             len(changelog), rc))
    if superseded or unresolved:
        print("ⓘ review surface — a stale citation may be intentional (pinning a past claim); confirm by eye "
              "before editing. §Pre-Publish Surface Gate's Step 1b (draft API / md5 / machine fields) is the "
              "deposit-time counterpart of this check.")
    return rc


if __name__ == "__main__":
    sys.exit(main())

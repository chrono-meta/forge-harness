#!/usr/bin/env python3
"""digest_slow_leg.py — the frontier digest's weekly "slow leg": conference channels and tech blogs.

Why (2026-10-29): the daily legs (HN · arXiv · TLDR · GeekNews · launch channels · vendor changelogs)
never reach conference talk archives or company tech blogs, and SKILL.md filed YouTube as a walled
channel. A channel's upload list is a plain Atom feed (youtube.com/feeds/videos.xml?channel_id=…),
so listing new talks needs no video access; reading a talk is video-ingest's job, not this script's.
Measured the same day: that feed answered 404 for every channel tried, including a well-known control
channel, so a youtube row falls back to `yt-dlp --flat-playlist` (public listing, no download) and
the output names which transport produced the list. Neither works -> UNREACHABLE, not 0. The fallback
fires on 404 only: a 403/429 is a refusal, and a refusal is never retried another way.
Talks come out yearly and run 30-40 minutes, so this leg is weekly and lists, it does not summarize.

The source list is operator-local (gitignored) on purpose: which companies a person follows can
identify their employer, and this repo is public. Nothing here names a source.

Rules this script keeps:
  - A feed that refuses an automated client (403 · 429 · any HTTP error) is UNREACHABLE(<code>).
    It is never retried with a different client identity. The operator hands those in by hand.
  - A feed that answered but parsed to zero entries is PARSE-ZERO; malformed XML is PARSE-ERROR.
    Neither is "0 new" — both are instrument problems until shown otherwise.
  - "0 new" is only printed when entries parsed and all were already seen.
  - The listing is APPENDED to a dated file BEFORE the seen-set is saved, so neither a lost stdout nor
    a same-day rerun loses items.
  - A week where no source was read does not count as done: `due` stays DUE.
  - A source seen for the first time, or moved from its feed to the yt-dlp listing, is seeded
    (recorded as seen, not listed) and says so — never a flood of a whole channel as "new". The
    yt-dlp -> feed direction needs no reseed (the feed's ~15 items are a subset of what was seen).

Usage:
  digest_slow_leg.py run [--sources F] [--state F] [--out F] [--backfill] [--dry-run]
  digest_slow_leg.py due [--state F] [--days 7]
  digest_slow_leg.py --self-test

Source file (TSV, '#' comments): id <TAB> kind <TAB> target <TAB> label
  kind = feed (RSS or Atom URL) | youtube (a channel id, UC…). Duplicate ids are rejected.
Defaults: $FH_DIGEST_SLOW_SOURCES or <repo>/tracks/_meta/digest_slow_sources.tsv,
          $FH_DIGEST_SLOW_STATE  or <repo>/tracks/_meta/digest_slow_state.json,
          --out <repo>/tracks/_meta/digest_slow_<YYYY-MM-DD>.md
exit (run): 0 every source read · 4 ran, but at least one source UNREACHABLE/PARSE-* (listing still
            written) · 2 source file missing/invalid or state file invalid
exit (due): 0 due · 3 not due · 2 state file invalid (read as UNMEASURED, never as not-due)
exit (self-test): 0 pass · 1 fail
"""
import copy, json, math, os, shutil, subprocess, sys, tempfile, time, urllib.error, urllib.request
import xml.etree.ElementTree as ET

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UA = "fh-digest-slow-leg/1 (+weekly feed listing)"
ATOM = "{http://www.w3.org/2005/Atom}"
MAX_BYTES = 5_000_000
SLACK = 3600  # a daily runner starts at the same clock time; a few seconds' drift must not slip a week


class StateInvalid(Exception):
    pass


def _arg(argv, name, default=None):
    return argv[argv.index(name) + 1] if name in argv and argv.index(name) + 1 < len(argv) else default


def load_sources(path):
    rows, ids = [], set()
    for n, line in enumerate(open(path, encoding="utf-8"), 1):
        line = line.rstrip("\n")
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) < 3 or parts[1] not in ("feed", "youtube") or not parts[2].strip() or not parts[0].strip():
            raise ValueError(f"{path}:{n}: want id<TAB>feed|youtube<TAB>target[<TAB>label]")
        sid = parts[0].strip()
        if sid in ids:
            raise ValueError(f"{path}:{n}: duplicate id {sid!r} (two rows would share one seen-set)")
        ids.add(sid)
        rows.append({"id": sid, "kind": parts[1], "target": parts[2].strip(),
                     "label": parts[3].strip() if len(parts) > 3 and parts[3].strip() else sid})
    if not rows:
        raise ValueError(f"{path}: no sources (comments only) — measuring nothing is not '0 new'")
    return rows


def load_state(path):
    if not os.path.exists(path):
        return {}
    try:
        st = json.load(open(path, encoding="utf-8"))
        if not isinstance(st, dict):
            raise ValueError("not an object")
        lr = st.get("last_run", 0)
        if isinstance(lr, bool) or not isinstance(lr, (int, float)) or not math.isfinite(lr) or lr < 0:
            raise ValueError(f"last_run is {lr!r}")
        seen = st.get("seen", {})
        if not isinstance(seen, dict) or not all(isinstance(v, list) and all(isinstance(k, str) for k in v) for v in seen.values()):
            raise ValueError("seen must map id -> list of strings")
        via = st.get("via", {})
        if not isinstance(via, dict) or not all(v in ("feed", "yt-dlp") for v in via.values()):
            raise ValueError("via must map id -> feed|yt-dlp")
        return st
    except Exception as e:
        raise StateInvalid(f"{path}: {type(e).__name__}: {e}")


def save_atomic(path, text):
    d = os.path.dirname(os.path.abspath(path))
    fd, tmp = tempfile.mkstemp(dir=d, prefix=".slowleg_")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(text)
    os.replace(tmp, path)


def feed_url(src):
    if src["kind"] == "youtube":
        return "https://www.youtube.com/feeds/videos.xml?channel_id=" + src["target"]
    return src["target"]


def fetch(url):
    """Return (status, body). status is 'OK' or 'UNREACHABLE(<why>)'. One attempt, one identity."""
    try:
        req = urllib.request.Request(url, headers={"User-Agent": UA})
        with urllib.request.urlopen(req, timeout=20) as r:
            return "OK", r.read(MAX_BYTES)
    except urllib.error.HTTPError as e:
        return f"UNREACHABLE({e.code})", b""
    except Exception as e:  # DNS, timeout, refused, missing file:// path
        return f"UNREACHABLE({type(e).__name__})", b""


def parse(body):
    """Return (entries, keyless). Raises ET.ParseError on malformed XML."""
    root = ET.fromstring(body)
    out, keyless = [], 0
    for it in root.iter("item"):  # RSS 2.0
        title = (it.findtext("title") or "").strip()
        link = (it.findtext("link") or "").strip()
        date = (it.findtext("pubDate") or "").strip()
        key = (it.findtext("guid") or "").strip() or link or (f"t:{title}" if title else "")
        if not key:
            keyless += 1; continue
        out.append({"key": key, "title": title, "link": link, "date": date})
    for e in root.iter(ATOM + "entry"):  # Atom (YouTube channel feeds are Atom)
        links = e.findall(ATOM + "link")
        alt = [l for l in links if l.get("rel", "alternate") == "alternate"]
        link = ((alt or links)[0].get("href") if (alt or links) else "") or ""
        title = (e.findtext(ATOM + "title") or "").strip()
        date = (e.findtext(ATOM + "published") or e.findtext(ATOM + "updated") or "").strip()
        key = (e.findtext(ATOM + "id") or "").strip() or link or (f"t:{title}" if title else "")
        if not key:
            keyless += 1; continue
        out.append({"key": key, "title": title, "link": link, "date": date})
    return out, keyless


def yt_list(src):
    """Channel listing via yt-dlp. Return (status, entries). Entries carry no dates in flat mode, and
    the listing is NOT newest-first (measured 2026-10-29: a 566-video channel listed 2021 uploads
    first), so the whole channel is read and "new" means an id not seen before — never a top-N cut.
    Keys use the Atom feed's form (yt:video:<id>) so either transport names a video the same way."""
    exe = os.environ.get("FH_YTDLP") or shutil.which("yt-dlp")
    if not exe:
        return "UNREACHABLE(no-yt-dlp)", []
    url = f"https://www.youtube.com/channel/{src['target']}/videos"
    try:
        r = subprocess.run([exe, "--flat-playlist", "--print", "%(id)s\t%(title)s", url],
                           capture_output=True, text=True, timeout=600)
    except Exception as e:
        return f"UNREACHABLE(yt-dlp:{type(e).__name__})", []
    if r.returncode != 0:
        return f"UNREACHABLE(yt-dlp rc={r.returncode})", []
    out = []
    for line in r.stdout.splitlines():
        vid, _, title = line.partition("\t")
        if vid.strip():
            out.append({"key": "yt:video:" + vid.strip(), "title": title.strip(), "date": "",
                        "link": "https://www.youtube.com/watch?v=" + vid.strip()})
    if not out:
        return "PARSE-ZERO(yt-dlp printed no ids)", []
    return "OK", out


def md_title(s):
    s = " ".join((s or "").split())
    for ch in "\\[]()":
        s = s.replace(ch, "\\" + ch)
    return s or "(제목 없음)"


def md_link(u):
    u = (u or "").strip()
    return u.replace(" ", "%20").replace("(", "%28").replace(")", "%29") if u else "링크 없음"


def run(sources, state, backfill, yt=yt_list, url_of=None):
    """Return (markdown lines, new state, read count, unread count). Does not mutate `state`."""
    url_of = url_of or feed_url
    st = copy.deepcopy(state)
    seen = st.setdefault("seen", {})
    via_prev = st.setdefault("via", {})
    lines, read, unread, n_new, n_seed, partial = [], 0, 0, 0, 0, 0
    t0 = int(time.time())
    for s in sources:
        head = f"### {s['label']} (`{s['id']}`)"
        status, body = fetch(url_of(s))
        via = "feed"
        ents = None
        if status == "UNREACHABLE(404)" and s["kind"] == "youtube":  # 404 only: a refusal (403/429) is never retried another way
            first = status
            status, ents = yt(s)
            via = "yt-dlp"
            if status != "OK":
                status = f"{first} · {status}"
        if status != "OK":
            unread += 1
            lines += [head, f"- {status} — 수집 안 됨(0 이 아니다). 운영자가 직접 넘겨야 한다", ""]
            continue
        keyless = 0
        if ents is None:
            try:
                ents, keyless = parse(body)
            except ET.ParseError as e:
                unread += 1
                lines += [head, f"- PARSE-ERROR({e}) — 계기 문제로 본다(0 이 아니다)", ""]
                continue
        if not ents:
            unread += 1
            lines += [head, "- PARSE-ZERO — 응답은 왔는데 항목 0개. 계기 불일치로 본다(0 이 아니다)", ""]
            continue
        read += 1
        lines.append(head + (" — 경로: yt-dlp (채널 Atom 피드가 안 열림)" if via == "yt-dlp" else ""))
        if keyless:
            partial += 1
            lines.append(f"- 식별자 없는 항목 {keyless}개는 판정 못 함(guid · link · title 모두 없음) — 이 소스는 부분 읽음")
        uniq = {}
        for x in ents:  # one feed can carry two items with the same key (e.g. same title, no guid/link)
            uniq.setdefault(x["key"], x)
        ents = list(uniq.values())
        keys = set(uniq)
        reseed = None
        if s["id"] not in seen:
            reseed = "처음 등록"
        elif via_prev.get(s["id"], "feed") == "feed" and via == "yt-dlp":
            reseed = "수집 경로 변경(feed → yt-dlp) — 그 사이 새 항목이 있었다면 놓쳤을 수 있다"
        if reseed and not backfill:
            n_seed += 1
            lines += [f"- {reseed}: 항목 {len(ents)}개를 본 것으로 기록했다(목록은 --backfill). 다음 실행부터 새 항목만 나온다", ""]
            seen[s["id"]] = sorted(set(seen.get(s["id"], [])) | keys)
            via_prev[s["id"]] = via
            continue
        old = set(seen.get(s["id"], []))
        new = ents if backfill else [x for x in ents if x["key"] not in old]
        if not new:
            lines.append(f"- 새 항목 0 (읽은 항목 {len(ents)}개 모두 이미 봄)")
        for x in new:
            n_new += 1
            lines.append(f"- {(x['date'][:16] + ' · ') if x['date'] else ''}[{md_title(x['title'])}]({md_link(x['link'])})")
        lines.append("")
        seen[s["id"]] = sorted(old | keys)
        via_prev[s["id"]] = via
    lines.append(f"**느린 갈래 요약: 새 항목 {n_new} · 읽음 {read} · 못 읽음 {unread} · 부분 읽음 {partial} · 목록 없이 기록만(처음 등록·경로 변경) {n_seed} (소스 {len(sources)})**")
    if read:  # a week where nothing was read is not a week done; stamp the START so a long run does not slip a week
        st["last_run"] = t0
    return lines, st, read, unread + partial


def main(argv):
    if "--self-test" in argv:
        return self_test()
    if not argv or argv[0] not in ("run", "due"):
        print(__doc__); return 2
    state_p = _arg(argv, "--state", os.environ.get("FH_DIGEST_SLOW_STATE",
                   os.path.join(REPO, "tracks", "_meta", "digest_slow_state.json")))
    try:
        state = load_state(state_p)
    except StateInvalid as e:
        print(f"STATE-INVALID: {e} — UNMEASURED(상태 파일 깨짐). 아직 아님으로 읽지 마라"); return 2
    if argv[0] == "due":
        days = float(_arg(argv, "--days", "7"))
        last = state.get("last_run", 0)
        due = time.time() - last >= days * 86400 - SLACK
        print("DUE" if due else f"NOT-DUE (last run {time.strftime('%Y-%m-%d', time.localtime(last))})")
        return 0 if due else 3
    src_p = _arg(argv, "--sources", os.environ.get("FH_DIGEST_SLOW_SOURCES",
                 os.path.join(REPO, "tracks", "_meta", "digest_slow_sources.tsv")))
    if not os.path.exists(src_p):
        print(f"SOURCES-MISSING: {src_p} — 느린 갈래는 UNMEASURED(소스 목록 없음)"); return 2
    try:
        sources = load_sources(src_p)
    except ValueError as e:
        print(f"SOURCES-INVALID: {e}"); return 2
    lines, new_state, read, unread = run(sources, state, "--backfill" in argv)
    text = "\n".join(lines) + "\n"
    print(text, end="")
    if "--dry-run" not in argv:
        out_p = _arg(argv, "--out", os.path.join(REPO, "tracks", "_meta",
                     f"digest_slow_{time.strftime('%Y-%m-%d')}.md"))
        prev = open(out_p, encoding="utf-8").read() if os.path.exists(out_p) else ""
        stamp = f"<!-- run {time.strftime('%Y-%m-%d %H:%M:%S')} -->\n"
        save_atomic(out_p, prev + ("\n" if prev else "") + stamp + text)  # listing first, appended
        save_atomic(state_p, json.dumps(new_state, ensure_ascii=False, indent=1))
        print(f"(목록 저장: {out_p})")
    return 4 if unread else 0


def self_test():
    """Known-pair lanes, offline: file:// feeds, a local HTTP server that answers 403, a fake yt-dlp,
    and main() end to end on temp files. Each lane names the branch it would turn red without."""
    d = tempfile.mkdtemp(prefix="slowleg_")
    saved_env = {k: os.environ.get(k) for k in ("FH_YTDLP", "no_proxy", "NO_PROXY")}
    try:  # env and temp dir are restored even if setup (server bind, fixtures) raises
        return _self_test_body(d, saved_env)
    finally:
        for k, v in saved_env.items():
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v
        shutil.rmtree(d, ignore_errors=True)


def _self_test_body(d, saved_env):
    import http.server, threading
    os.environ["no_proxy"] = os.environ["NO_PROXY"] = "127.0.0.1,localhost"  # lane measures the code, not a proxy
    W = lambda name, text: (open(os.path.join(d, name), "w").write(text), os.path.join(d, name))[1]
    rss = W("r.xml", "<rss><channel><item><title>T1</title><link>https://x/1</link><guid>g1</guid>"
                     "<pubDate>Tue, 27 Oct 2026 15:00:00 GMT</pubDate></item><item><title>T2</title>"
                     "<link>https://x/2</link></item><item><title>T3</title></item><item></item></channel></rss>")
    atom = W("a.xml", '<feed xmlns="http://www.w3.org/2005/Atom"><entry><id>yt:video:abc</id>'
                      '<title>Talk</title><link rel="self" href="https://y/self"/>'
                      '<link rel="alternate" href="https://y/abc"/>'
                      '<published>2026-10-28T00:00:00+00:00</published></entry></feed>')
    empty = W("e.xml", "<rss><channel></channel></rss>")
    bad = W("b.xml", "<rss><channel><item>")

    class H(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            self.send_response(404 if self.path.startswith("/gone") else 403); self.end_headers()
        def log_message(self, *a):
            pass
    srv = http.server.HTTPServer(("127.0.0.1", 0), H)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    port = srv.server_address[1]

    src = W("s.tsv", "# test\n"
                     f"r\tfeed\tfile://{rss}\tRSS\n"
                     f"a\tfeed\tfile://{atom}\tAtom\n"
                     f"m\tfeed\tfile://{d}/missing.xml\tMissing\n"
                     f"e\tfeed\tfile://{empty}\tEmpty\n"
                     f"b\tfeed\tfile://{bad}\tBad\n"
                     f"h\tfeed\thttp://127.0.0.1:{port}/feed\tHTTP403\n")
    srcs = load_sources(src)
    ok = True

    def check(name, cond):
        nonlocal ok
        print(("ok  " if cond else "FAIL ") + name); ok = ok and cond

    try:
        # seeding
        l0, st0, r0, u0 = run(srcs, {}, False)
        t0 = "\n".join(l0)
        check("first run seeds instead of dumping", t0.count("처음 등록: 항목") == 2 and "[T1]" not in t0)
        check("HTTP refusal is UNREACHABLE(403), not 0", "UNREACHABLE(403)" in t0)
        check("missing feed is UNREACHABLE, not 0", "UNREACHABLE(URLError)" in t0)
        check("empty feed is PARSE-ZERO", "PARSE-ZERO" in t0)
        check("malformed feed is PARSE-ERROR", "PARSE-ERROR(" in t0)
        check("summary counts read/unread/partial", "읽음 2 · 못 읽음 4 · 부분 읽음 1 ·" in t0 and "(소스 6)" in t0 and (r0, u0) == (2, 5))
        check("unreached sources not added to seen", not ({"m", "e", "b", "h"} & set(st0["seen"])))
        # listing on a seeded state
        l1, st1, _, _ = run(srcs, {"seen": {"r": [], "a": []}}, False)
        t1 = "\n".join(l1)
        check("rss lists keyed items (guid, link, title fallback)", all(s in t1 for s in ("[T1](https://x/1)", "[T2](https://x/2)", "[T3](링크 없음)")))
        check("summary counts new items (3 rss + 1 atom)", "새 항목 4 ·" in t1)
        check("titles are flattened and escaped", md_title("a]\n## b(") == "a\\] ## b\\(" and md_title("x\\") == "x\\\\")
        check("links with ) or space are encoded", md_link("https://w/a b)") == "https://w/a%20b%29")
        dup = W("dup.xml", "<rss><channel><item><title>Same</title></item><item><title>Same</title></item></channel></rss>")
        ld, _, _, _ = run([{"id": "d", "kind": "feed", "target": f"file://{dup}", "label": "Dup"}], {"seen": {"d": []}}, False)
        check("same-key items listed once", "\n".join(ld).count("[Same]") == 1)
        check("summary counts seeded sources", "목록 없이 기록만(처음 등록·경로 변경) 2" in t0)
        check("keyless rss item skipped and counted", "식별자 없는 항목 1개" in t1)
        check("atom prefers rel=alternate", "[Talk](https://y/abc)" in t1 and "y/self" not in t1)
        l2, _, _, _ = run(srcs, st1, False)
        t2 = "\n".join(l2)
        check("second run: 0 new on rss and atom", t2.count("- 새 항목 0") == 2 and "새 항목 0 ·" in t2 and "[T1]" not in t2)
        check("backfill re-lists seen items", "[T1](https://x/1)" in "\n".join(run(srcs, st1, True)[0]))
        inp = {"seen": {"r": ["g1"]}}
        run(srcs, inp, False)
        check("input state left untouched", inp == {"seen": {"r": ["g1"]}})
        # youtube: fake yt-dlp end to end (real yt_list, real parsing of its output)
        fake = W("fake_ytdlp.sh", '#!/bin/sh\nprintf "v1\\tConf talk\\nv2\\tOther\\n"\n'); os.chmod(fake, 0o755)
        fail = W("fail_ytdlp.sh", "#!/bin/sh\nexit 1\n"); os.chmod(fail, 0o755)
        silent = W("silent_ytdlp.sh", "#!/bin/sh\nexit 0\n"); os.chmod(silent, 0o755)
        ysrc = [{"id": "y", "kind": "youtube", "target": "UCtest", "label": "YT"}]
        no_rss = lambda s: f"http://127.0.0.1:{port}/gone/{s['target']}"   # the measured case: feed 404
        refused = lambda s: f"http://127.0.0.1:{port}/feed/{s['target']}"   # 403: a refusal
        os.environ["FH_YTDLP"] = fake
        ly, sty, _, _ = run(ysrc, {"seen": {"y": []}, "via": {"y": "yt-dlp"}}, False, url_of=no_rss)
        ty = "\n".join(ly)
        check("youtube falls back to real yt_list and names the transport",
              "[Conf talk](https://www.youtube.com/watch?v=v1)" in ty and "경로: yt-dlp" in ty)
        check("yt-dlp keys use the Atom form", "yt:video:v1" in sty["seen"]["y"])
        lt, _, _, _ = run(ysrc, {"seen": {"y": ["yt:video:abc"]}, "via": {"y": "feed"}}, False, url_of=no_rss)
        check("transport change reseeds instead of flooding", "수집 경로 변경(feed → yt-dlp)" in "\n".join(lt) and "[Conf talk]" not in "\n".join(lt))
        lb, stb, _, _ = run(ysrc, {"seen": {"y": ["yt:video:abc"]}, "via": {"y": "yt-dlp"}}, False,
                            url_of=lambda s: f"file://{atom}")
        check("yt-dlp -> feed does not reseed and records feed", "수집 경로 변경" not in "\n".join(lb) and "- 새 항목 0" in "\n".join(lb) and stb["via"]["y"] == "feed")
        os.environ["FH_YTDLP"] = fail
        lf, stf, _, uf = run(ysrc, {}, False, url_of=no_rss)
        check("yt-dlp rc!=0 -> UNREACHABLE naming both transports", "UNREACHABLE(404) · UNREACHABLE(yt-dlp rc=1)" in "\n".join(lf) and uf == 1)
        check("a week with nothing read does not stamp last_run", "last_run" not in stf)
        os.environ["FH_YTDLP"] = silent
        check("yt-dlp printing nothing is PARSE-ZERO, not 0", "PARSE-ZERO(yt-dlp" in "\n".join(run(ysrc, {}, False, url_of=no_rss)[0]))
        os.environ["FH_YTDLP"] = fake
        lr_, str_, _, ur_ = run(ysrc, {"seen": {"y": []}, "via": {"y": "yt-dlp"}}, False, url_of=refused)
        check("403 refusal is never retried through yt-dlp", "UNREACHABLE(403)" in "\n".join(lr_) and "yt-dlp" not in "\n".join(lr_) and ur_ == 1)
        # transport memory: two fallback runs back to back on the returned state, a new upload on the second
        _, s1, _, _ = run(ysrc, {"seen": {"y": ["yt:video:abc"]}, "via": {"y": "feed"}}, False, url_of=no_rss)
        more = W("more_ytdlp.sh", '#!/bin/sh\nprintf "v1\\tConf talk\\nv2\\tOther\\nv3\\tBrand new\\n"\n'); os.chmod(more, 0o755)
        os.environ["FH_YTDLP"] = more
        l2b, _, _, _ = run(ysrc, s1, False, url_of=no_rss)
        t2b = "\n".join(l2b)
        check("fallback remembers its transport: next run lists the new upload, no reseed",
              "[Brand new](https://www.youtube.com/watch?v=v3)" in t2b and "수집 경로 변경" not in t2b)
        # main() end to end
        stp, outp = os.path.join(d, "st.json"), os.path.join(d, "out.md")
        good = W("good.tsv", f"a\tfeed\tfile://{atom}\tAtom\n")
        rc_due0 = main(["due", "--state", stp])
        rc_run = main(["run", "--sources", good, "--state", stp, "--out", outp])
        rc_due1 = main(["due", "--state", stp])
        check("due: no state -> 0, after a good run -> 3", (rc_due0, rc_run, rc_due1) == (0, 0, 3))
        check("listing file written by run", os.path.exists(outp) and "처음 등록" in open(outp).read())
        main(["run", "--sources", good, "--state", stp, "--out", outp])
        txt = open(outp).read()
        check("same-day rerun appends, first listing kept", txt.count("<!-- run ") == 2 and "처음 등록" in txt and "새 항목 0" in txt)
        check("run with an unread source exits 4", main(["run", "--sources", src, "--state", os.path.join(d, "st2.json"), "--out", outp]) == 4)
        open(stp, "w").write('{"seen": {"r": [')
        check("corrupt state: due exits 2, not 3", main(["due", "--state", stp]) == 2)
        check("corrupt state: run exits 2", main(["run", "--sources", good, "--state", stp, "--out", outp]) == 2)
        check("comments-only sources -> 2", main(["run", "--sources", W("c.tsv", "# none\n"), "--state", os.path.join(d, "s4.json"), "--dry-run"]) == 2)
        for bad_state in ('{"last_run": 9999999999, "seen": null}', '{"last_run": "x"}', '{"last_run": NaN}', '{"last_run": 1e400}', '{"seen": {"r": [1]}}', '{"via": {"y": "rss"}}'):
            open(stp, "w").write(bad_state)
            check(f"shallow-valid but broken state -> due 2: {bad_state[:28]}", main(["due", "--state", stp]) == 2)
        check("missing sources -> 2", main(["run", "--sources", os.path.join(d, "nope.tsv"), "--state", os.path.join(d, "s3.json"), "--dry-run"]) == 2)
        for bad_tsv, why in (("x\tvideo\tz\n", "invalid kind"), ("x\tfeed\tu\nx\tfeed\tv\n", "duplicate id")):
            try:
                load_sources(W("bad.tsv", bad_tsv)); check(f"{why} rejected", False)
            except ValueError:
                check(f"{why} rejected", True)
    finally:
        srv.shutdown(); srv.server_close()
    print("self-test:", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

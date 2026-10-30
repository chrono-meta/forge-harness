#!/usr/bin/env python3
"""absorption_queue.py — 바깥에서 들어온 «가져올 것» 이 사람 기억 말고 기록에 남게 한다.

왜 (2026-10-28 실측): 외부 자산 감사(techwriting-min-check, 10-27)가 «가져올 것 5» 를 냈는데
하루 동안 아무도 안 집었다. 운영자가 다음 날 발표 요약을 직접 붙여 넣고서야 ko-tech-writer 가
고쳐졌다. 흡수 고리에서 끊긴 곳은 둘이다:
  ② 바깥 신호 → 우리 자산 짝짓기가 «누가 기시감을 느끼느냐» 에 달렸다
  ④ 비교표 · 후보 목록에 읽는 쪽(소비처)이 없다
digest 쪽에는 착지 증언(digest_landing_check.sh)이 있지만 결과는 로그 파일에만 가고, 그 판별
토큰은 `arXiv:2610.x` 가 콜론에서 잘려 `arXiv` 한 낱말이 되는 경우가 있어 «착지» 가 어휘 우연으로
나올 수 있다(10-28 실측: 10-26 digest 후보 셋 다 토큰이 `arXiv` 하나뿐이었고 그날 판정은 ALL-LANDED).
그래서 이 대기열은 낱말 추론으로 닫지 않는다.

기계가 하는 일은 기록의 성질만이다(present · typed · attributable). 무엇을 가져올지, 그게 정말
착지했는지는 판단이고 닫는 사람이 근거를 적는다:
  landed   — 근거에 PR 번호(#123 · /pull/123) 나 commit:<해시> · <레포>@<해시> 가 있어야 한다
  declined · deferred — 사유 낱말이 있어야 한다(빈 칸 · «-» 금지)

사용:
  absorption_queue.py add --source <URL|경로|digest:파일> --item "<한 줄>" [--asset <경로> ...]
  absorption_queue.py import-digest <frontier_digest_*.md>   # digest_landing_check.sh --extract 의 후보를 넣는다
  absorption_queue.py close <ID> --status landed|declined|deferred --evidence "<PR#·커밋·사유>"
  absorption_queue.py list [--open]
  absorption_queue.py summary            # 세션 시작용 한 줄 — 열린 항목이 없거나 파일이 없으면 아무것도 안 찍는다
  absorption_queue.py match "<텍스트>"   # 우리 자산 후보(어휘 선별기 — 열어서 판단)
  absorption_queue.py --self-test

대기열 파일: $FH_ABSORPTION_QUEUE, 없으면 <레포>/tracks/_meta/absorption_queue.tsv (gitignored 자리).
exit: 0 성공 · 1 self-test 실패 · 2 기록 규칙 위반(아무것도 안 씀) · 10 입력 오류 · 추출기 실패
"""
import datetime
import fcntl
import os
import re
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.environ.get("CLAUDE_PROJECT_DIR") or os.path.dirname(HERE)
COLS = ["id", "added", "source", "item", "assets", "status", "closed", "evidence"]
STATUSES = ("open", "landed", "declined", "deferred")
# PR 번호(#975 · …/pull/975) 또는 **명시 표기한** 커밋(commit:5cac232 · <레포>@5cac232).
# 맨 16진수는 받지 않는다 — 모양으로 «커밋인가» 를 짐작하면 낱말 «defaced» 가 통과하고(codex R1),
# 그걸 막으려 숫자를 요구하면 진짜 해시 «deadbee» 가 거부된다(codex R2). 두 라운드가 서로를
# 낳았으므로 짐작을 그만두고 표기를 요구한다. 해시가 실재하는지는 안 본다(다른 레포 커밋일 수 있다).
PR_REF = re.compile(r"(?:^|[^\w])#\d+\b|/pull/\d+\b")
HASH_REF = re.compile(r"(?:\bcommit:\s*|[\w.-]@)[0-9a-f]{7,40}\b")
REASON = re.compile(r"[^\W\d_]{2,}")   # 글자 두 개 이상 — «123» · «__» 는 사유가 아니다


def attributable(ev):
    return bool(PR_REF.search(ev) or HASH_REF.search(ev))


def qpath():
    return os.environ.get("FH_ABSORPTION_QUEUE") or os.path.join(ROOT, "tracks", "_meta", "absorption_queue.tsv")


def today():
    return os.environ.get("AQ_TODAY") or datetime.date.today().isoformat()


def clean(s):
    return re.sub(r"[\t\r\n]+", " ", s or "").strip()


def load(path):
    rows = []
    if not os.path.exists(path):
        return rows
    with open(path, encoding="utf-8") as f:
        for n, line in enumerate(f):
            line = line.rstrip("\n")
            if not line or line.startswith("#"):
                continue
            parts = line.split("\t")
            if parts[0] == "id":
                continue
            if len(parts) != len(COLS):
                raise ValueError("%s:%d 칸 수 %d (기대 %d)" % (path, n + 1, len(parts), len(COLS)))
            r = dict(zip(COLS, parts))
            # 읽을 때 검증한다 — 오타 status(«opne») 나 근거 없는 landed 가 «열린 것 0» 으로 읽히면
            # 세션 시작 줄이 조용히 사라진다(codex R1).
            bad = ("status %r" % r["status"]) if r["status"] not in STATUSES else \
                  "source/item 비어 있음" if not r["source"] or not r["item"] else \
                  ("added 날짜 %r" % r["added"]) if days_between(r["added"], r["added"]) is None else \
                  "열린 행에 closed 날짜" if r["status"] == "open" and r["closed"] else \
                  ("closed 날짜 %r" % r["closed"]) if r["status"] != "open" and days_between(r["closed"], r["closed"]) is None else \
                  "id 비어 있음" if not r["id"] else \
                  ("id 중복 %s" % r["id"]) if any(x["id"] == r["id"] for x in rows) else \
                  "landed 인데 근거가 PR/커밋이 아님" if r["status"] == "landed" and not attributable(r["evidence"]) else \
                  "닫혔는데 사유 없음" if r["status"] in ("declined", "deferred") and not REASON.search(r["evidence"]) else ""
            if bad:
                raise ValueError("%s:%d %s" % (path, n + 1, bad))
            rows.append(r)
    return rows


def save(path, rows):
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path) or ".", prefix=".aq_")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write("\t".join(COLS) + "\n")
        for r in rows:
            f.write("\t".join(clean(r.get(c, "")) for c in COLS) + "\n")
    os.replace(tmp, path)


def next_id(rows):
    stem = "AQ-" + today().replace("-", "")
    n = sum(1 for r in rows if r["id"].startswith(stem + "-"))
    return "%s-%d" % (stem, n + 1)


def add_row(rows, source, item, assets=()):
    source, item = clean(source), clean(item)
    if not source or not item:
        return None, "source 와 item 은 비울 수 없다"
    for r in rows:
        if r["source"] == source and r["item"] == item:
            return r, "dup"
    r = {"id": next_id(rows), "added": today(), "source": source, "item": item,
         "assets": " ".join(clean(a) for a in assets if clean(a)), "status": "open", "closed": "", "evidence": ""}
    rows.append(r)
    return r, "added"


def close_row(rows, rid, status, evidence):
    evidence = clean(evidence)
    hit = [r for r in rows if r["id"] == rid]
    if not hit:
        return "없는 ID: %s" % rid
    if status not in STATUSES[1:]:
        return "status 는 landed · declined · deferred 중 하나"
    if status == "landed" and not attributable(evidence):
        return "landed 는 근거에 PR 번호(#123 · /pull/123)나 commit:<해시> · <레포>@<해시> 가 있어야 한다 — 받은 값: %r" % evidence
    if status != "landed" and not REASON.search(evidence):
        return "%s 는 사유를 적어야 한다 — 받은 값: %r" % (status, evidence)
    hit[0].update(status=status, closed=today(), evidence=evidence)
    return None


def days_between(a, b):
    try:
        return (datetime.date.fromisoformat(b) - datetime.date.fromisoformat(a)).days
    except ValueError:
        return None


def summary_line(rows, path):
    op = [r for r in rows if r["status"] == "open"]
    if not op:
        return ""
    ages = [d for d in (days_between(r["added"], today()) for r in op) if d is not None]
    oldest = max(ages) if ages else None
    no_asset = sum(1 for r in op if not r["assets"])
    rel = os.path.relpath(path, ROOT) if path.startswith(ROOT) else path
    return ("📥 [흡수 대기열] 열림 %d · 가장 오래된 것 %s일 · 우리 자산 미지정 %d — %s"
            " (닫기: scripts/absorption_queue.py close <ID> --status landed|declined|deferred --evidence ...)"
            % (len(op), "?" if oldest is None else oldest, no_asset, rel))


def extract_digest(digest):
    """digest_landing_check.sh --extract 를 그대로 쓴다 — 후보 판정 규칙을 여기 다시 쓰지 않는다."""
    checker = os.path.join(HERE, "digest_landing_check.sh")
    if not os.path.isfile(checker):
        return None, "digest_landing_check.sh 없음"
    p = subprocess.run(["bash", checker, "--extract", digest], capture_output=True, text=True)
    if p.returncode != 0:
        return None, "추출기 rc=%d: %s" % (p.returncode, (p.stderr or p.stdout).strip()[:200])
    labels = []
    for line in p.stdout.splitlines():
        parts = line.split("\t")
        if parts[0] == "TARGET" and len(parts) >= 3:
            labels.append(re.sub(r"^후보\s*", "", parts[2]))
        elif parts[0] == "# UNCHECKABLE" and len(parts) >= 2:
            labels.append(parts[1])
    if not labels:
        return None, "후보 0개 — 절을 못 찾았거나 비었다(0 이 아니라 미측정)"
    heads = digest_heads(digest)
    items = []
    for lab in labels:
        full = heads.get(lab)
        # 원문을 못 찾으면 이름표를 쓰되 그 사실을 항목에 남긴다 — 잘린 줄이 «전체» 처럼 보이지 않게(AQ-20261029-4)
        items.append(full if full else lab + " [이름표만 — 다이제스트 원문 못 찾음]")
    return items, None


_HEAD_RE = re.compile(r"^(###+ |\*\*|[0-9]+\. |- \*\*)")


def digest_heads(digest):
    """다이제스트 후보 절의 머리 줄 → {검증기 이름표: 머리 문장 전체}.
    이름표는 digest_landing_check.sh 의 awk 와 같은 규칙으로 만든다(머리 표기 떼기 · 첫 굵은 글씨까지 · 공백 기준 앞 6낱말).
    그 규칙이 갈리면 원문을 못 찾고 import-digest 가 «이름표만» 을 붙인다 — 조용히 잘리지 않고 보인다.
    표 행(첫 칸이 id)은 이 대응에 없다 — 그 경우도 «이름표만» 으로 보인다."""
    try:
        lines = open(digest, encoding="utf-8").read().splitlines()
    except Exception:
        return {}
    sec = re.compile(os.environ.get("DLC_SECTION_RE") or r"^## .*Immediate Application Candidates")
    out, inblk = {}, False
    for line in lines:
        if sec.search(line):
            inblk = True
            continue
        if inblk and line.startswith("## "):
            break
        if not inblk:
            continue
        if line.startswith("|"):
            # 표 행 — 검증기는 첫 칸(굵은 글씨 · 공백을 뗀 것)을 이름표로 낸다. 원문은 마지막 칸의 굵은 머리 문장(없으면 칸 전체)
            cells = line.split("|")
            if len(cells) < 4 or re.match(r"^\|[\s]*#", line) or re.match(r"^\|[-:| ]+\|$", line):
                continue
            tid = re.sub(r"[*\s]", "", cells[1])
            body = next((c.strip() for c in reversed(cells[2:]) if c.strip()), "")
            m = re.match(r"^\*\*(.+?)\*\*", body)
            text = (m.group(1) if m else body).strip()
            if tid and text and tid not in out:
                out[tid] = text
            continue
        if not _HEAD_RE.match(line):
            continue
        pid = re.sub(r"^###+ ", "", line)
        pid = re.sub(r"^[0-9]+\. ", "", pid)
        pid = re.sub(r"^- ", "", pid)
        pid = re.sub(r"^\*\*", "", pid)
        pid = re.sub(r"\*\*.*$", "", pid).strip()
        words = pid.split()
        label = " ".join(words[:6]) if len(words) > 6 else pid
        if label and label not in out:
            out[label] = pid
    return out


def skill_index():
    """FH 플러그인 + 매핑된 필드 하네스의 SKILL.md 이름 · 설명."""
    roots = [os.path.join(ROOT, "plugins")]
    proj_root = os.environ.get("FH_PROJECTS_ROOT") or os.path.dirname(ROOT)
    tracks = os.path.join(ROOT, "tracks")
    if os.path.isdir(tracks):
        for t in sorted(os.listdir(tracks)):
            if not t.startswith("_") and os.path.isdir(os.path.join(proj_root, t)):
                roots.append(os.path.join(proj_root, t))
    out = []
    for r in roots:
        for d, dirs, files in os.walk(r):
            dirs[:] = [x for x in dirs if x not in (".git", "node_modules", "worktrees", ".claude-worktrees")]
            # 스킬만 보면 검토 에이전트(agents/*.md)가 빠진다 — 10-28 첫 실사용에서 «검토 페르소나 출력»
            # 항목의 짝(persona lens 에이전트)이 후보에 안 나왔다.
            cand = (["SKILL.md"] if "SKILL.md" in files else []) + \
                   ([f for f in files if f.endswith(".md")] if os.path.basename(d) == "agents" else [])
            for fn in cand:
                p = os.path.join(d, fn)
                try:
                    head = open(p, encoding="utf-8", errors="replace").read(4000)
                except OSError:
                    continue
                name = re.search(r"^name:\s*(.+)$", head, re.M)
                desc = re.search(r"^description:\s*(.+)$", head, re.M)
                out.append((p, (name.group(1) if name else (os.path.basename(d) if fn == "SKILL.md" else fn[:-3])).strip(), (desc.group(1) if desc else "").strip()))
    return out


def tokens(s):
    return {w.lower() for w in re.findall(r"[A-Za-z][A-Za-z0-9_-]{2,}|[가-힣]{2,}", s)}


def match(text, top=5):
    want = tokens(text)
    scored = []
    for p, name, desc in skill_index():
        have = tokens(name + " " + desc + " " + name.replace("-", " "))
        hit = want & have
        if hit:
            scored.append((len(hit), p, name, sorted(hit)[:6]))
    scored.sort(key=lambda x: (-x[0], x[1]))
    return scored[:top]


def main(argv):
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__)
        return 0 if argv else 10
    if argv[0] == "--self-test":
        return self_test()
    cmd, rest = argv[0], argv[1:]
    path = qpath()
    lock = None
    if cmd in ("add", "import-digest", "close"):
        # 매일 09:00 잡과 대화 세션이 같은 파일을 읽고-고치고-바꾼다. 잠금 없이는 늦게 쓴 쪽이
        # 먼저 쓴 쪽의 변경을 지운다(codex R1). 잠금은 읽기 전에 잡고 바꾼 뒤에 놓는다.
        try:
            os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
            lock = open(path + ".lock", "w")
            fcntl.flock(lock, fcntl.LOCK_EX)
        except OSError as e:
            print("🟥 잠금 실패: %s" % e, file=sys.stderr)
            return 10
    try:
        rows = load(path)
    except (ValueError, OSError) as e:
        print("🟥 대기열을 못 읽었다: %s" % e, file=sys.stderr)
        return 10

    def opt(name, many=False):
        vals, i = [], 0
        while i < len(rest):
            if rest[i] == name and i + 1 < len(rest):
                vals.append(rest[i + 1])
                i += 2
            else:
                i += 1
        return vals if many else (vals[-1] if vals else "")

    if cmd == "add":
        r, how = add_row(rows, opt("--source"), opt("--item"), opt("--asset", many=True))
        if r is None:
            print("🟥 %s" % how, file=sys.stderr)
            return 2
        if how == "added":
            save(path, rows)
        print("%s %s" % ("추가" if how == "added" else "이미 있음", r["id"]))
        return 0
    if cmd == "import-digest":
        if not rest or not os.path.isfile(rest[0]):
            print("🟥 digest 파일이 필요하다", file=sys.stderr)
            return 10
        items, err = extract_digest(rest[0])
        if err:
            print("🟥 %s" % err, file=sys.stderr)
            return 10
        src = "digest:" + os.path.basename(rest[0])
        n_add = 0
        for it in items:
            r, how = add_row(rows, src, it)
            n_add += how == "added"
        if n_add:
            save(path, rows)
        print("digest 후보 %d개 중 새로 %d개 넣음 (%s)" % (len(items), n_add, src))
        return 0
    if cmd == "close":
        if not rest:
            print("🟥 ID 가 필요하다", file=sys.stderr)
            return 10
        err = close_row(rows, rest[0], opt("--status"), opt("--evidence"))
        if err:
            print("🟥 %s — 아무것도 안 썼다" % err, file=sys.stderr)
            return 2
        save(path, rows)
        print("닫음 %s" % rest[0])
        return 0
    if cmd == "list":
        only_open = "--open" in rest
        for r in rows:
            if only_open and r["status"] != "open":
                continue
            print("%s\t%s\t%s\t%s\t%s%s" % (r["id"], r["status"], r["added"], r["item"][:90], r["source"],
                                          ("\t→ " + r["evidence"]) if r["evidence"] else ""))
        return 0
    if cmd == "summary":
        line = summary_line(rows, path)
        if line:
            print(line)
        return 0
    if cmd == "match":
        res = match(" ".join(rest))
        print("# 어휘 선별기 — 겹치는 낱말 수로만 줄 세웠다. 열어서 판단하라(0건 ≠ 짝 없음).")
        for n, p, name, hit in res:
            print("%d\t%s\t%s\t%s" % (n, name, os.path.relpath(p, ROOT), ",".join(hit)))
        return 0
    print("🟥 모르는 명령: %s" % cmd, file=sys.stderr)
    return 10


def self_test():
    res = []
    with tempfile.TemporaryDirectory() as td:
        q = os.path.join(td, "q.tsv")
        env = dict(os.environ, FH_ABSORPTION_QUEUE=q, AQ_TODAY="2026-10-28")

        def run(*a, **kw):
            e = dict(env, **kw.get("env", {}))
            p = subprocess.run([sys.executable, os.path.abspath(__file__)] + list(a), capture_output=True, text=True, env=e)
            return p.returncode, p.stdout + p.stderr

        rc, out = run("summary")
        res.append(("S1 no queue file → summary prints nothing, rc 0", rc == 0 and out.strip() == ""))
        rc, out = run("add", "--source", "https://example.org/x", "--item", "가져올 것 하나")
        res.append(("A1 add writes an open row", rc == 0 and "AQ-20261028-1" in out))
        rc, out = run("add", "--source", "https://example.org/x", "--item", "가져올 것 하나")
        res.append(("A2 same source+item is not added twice", rc == 0 and "이미 있음" in out and len(load(q)) == 1))
        rc, out = run("add", "--source", "", "--item", "x")
        res.append(("A3 empty source refused (rc 2)", rc == 2))
        rc, out = run("summary", env={"AQ_TODAY": "2026-10-31"})
        res.append(("S2 control: one open row → summary names count 1 and age 3", rc == 0 and "열림 1" in out and "3일" in out))
        rc, out = run("close", "AQ-20261028-1", "--status", "landed", "--evidence", "done")
        res.append(("C1 landed without PR#/commit refused, nothing written", rc == 2 and load(q)[0]["status"] == "open"))
        rc, out = run("close", "AQ-20261028-1", "--status", "declined", "--evidence", "-")
        res.append(("C2 declined without a reason refused", rc == 2 and load(q)[0]["status"] == "open"))
        rc, out = run("close", "AQ-20261028-1", "--status", "landed", "--evidence", "PR #975")
        res.append(("C3 control: landed with PR# closes", rc == 0 and load(q)[0]["status"] == "landed"))
        rc, out = run("close", "AQ-20261028-1", "--status", "landed", "--evidence", "abc")
        res.append(("C4 a 3-char hex is not a commit", rc == 2))
        rc, out = run("summary")
        res.append(("S3 all closed → summary prints nothing", rc == 0 and out.strip() == ""))
        # codex R1 — 근거 규칙의 양쪽
        run("add", "--source", "s2", "--item", "둘")
        rcs = tuple(run("close", "AQ-20261028-2", "--status", st, "--evidence", ev)[0]
                    for st, ev in (("landed", "defaced"), ("landed", "1234567"), ("landed", "deadbee"),
                                   ("declined", "__"), ("declined", "123")))
        res.append(("R1 bare hex/digits are not evidence; «__» · «123» are not reasons", rcs == (2, 2, 2, 2, 2)))
        rc, _ = run("close", "AQ-20261028-2", "--status", "landed", "--evidence", "https://github.com/o/r/pull/975")
        res.append(("R2 control: a PR URL is evidence", rc == 0))
        run("add", "--source", "s3", "--item", "셋")
        rc, _ = run("close", "AQ-20261028-3", "--status", "landed", "--evidence", "commit:deadbee (hash without digits)")
        run("add", "--source", "s4", "--item", "넷")
        rc2, _ = run("close", "AQ-20261028-4", "--status", "landed", "--evidence", "friends-on-desk@f1a96e4")
        res.append(("R3 control: commit:<hex> and <repo>@<hex> are evidence (digits not required)", (rc, rc2) == (0, 0)))
        rc, out = run("close", "AQ-nope", "--status", "declined", "--evidence", "중복")
        res.append(("C5 unknown ID refused", rc == 2))
        # digest — 같은 절 규칙(digest_landing_check --extract)을 쓰는지, 두 번 넣어도 한 번인지
        d = os.path.join(td, "frontier_digest_2026_10_28.md")
        with open(d, "w", encoding="utf-8") as f:
            f.write("# d\n\n## FH Immediate Application Candidates\n\n"
                    "- **후보 하나 (`builtin_capability_map`).** 본문.\n"
                    "- **후보 둘 — 토큰 없음.** 본문.\n\n## Warning Signals\n\n- 무관\n")
        n0 = len(load(q))
        rc, out = run("import-digest", d, env={"CLAUDE_PROJECT_DIR": ROOT})
        n1 = len(load(q))
        rc2, out2 = run("import-digest", d, env={"CLAUDE_PROJECT_DIR": ROOT})
        res.append(("D1 digest candidates enter the queue (incl. UNCHECKABLE), second import adds 0",
                    rc == 0 and n1 == n0 + 2 and rc2 == 0 and len(load(q)) == n1 and "새로 0개" in out2))
        e = os.path.join(td, "frontier_digest_empty.md")
        with open(e, "w", encoding="utf-8") as f:
            f.write("# d\n\n## Warning Signals\n\n- 무관\n")
        rc, out = run("import-digest", e, env={"CLAUDE_PROJECT_DIR": ROOT})
        res.append(("D2 digest without the section is an error (rc 10), not 0 candidates", rc == 10 and len(load(q)) == n1))
        # AQ-20261029-4 — 항목은 검증기의 6낱말 이름표가 아니라 머리 문장 전체다(목록 · 표 두 형식)
        lg = os.path.join(td, "frontier_digest_2026_10_29.md")
        long_head = "교차 계열 검증 집계에서 «같은 근거의 재전달» 을 한 표로 센다 (`arXiv:2610.36151`)."
        with open(lg, "w", encoding="utf-8") as f:
            f.write("# d\n\n## FH Immediate Application Candidates\n\n- **" + long_head + "** 본문.\n\n"
                    "| # | 티어 | 내용 |\n|---|---|---|\n| **M1** | **M** | **표 후보의 머리 문장 (`gate_locality_principle`)** — 설명 |\n\n"
                    "## Warning Signals\n\n- 무관\n")
        rc, out = run("import-digest", lg, env={"CLAUDE_PROJECT_DIR": ROOT})
        got = [r["item"] for r in load(q) if r["source"] == "digest:frontier_digest_2026_10_29.md"]
        res.append(("D3 a head longer than six words is stored whole, not cut at the display label",
                    rc == 0 and long_head in got and not any(g.endswith("«같은 근거의") for g in got)))
        res.append(("D4 a table candidate is stored by its body head, not by its id cell («M1»)",
                    "표 후보의 머리 문장 (`gate_locality_principle`)" in got and "M1" not in got))
        # 대응을 못 하면(두 규칙이 갈림) 이름표를 쓰되 그 사실이 항목에 보인다 — 조용한 절단 금지
        saved = digest_heads
        try:
            globals()["digest_heads"] = lambda _d: {}
            items, err = extract_digest(lg)
        finally:
            globals()["digest_heads"] = saved
        res.append(("D5 an unmatched label is marked «이름표만», not passed off as the full item",
                    err is None and items and all("[이름표만" in i for i in items)))
        # 동시 쓰기 — 잠금이 없으면 늦게 쓴 쪽이 앞의 행을 지운다
        procs = [subprocess.Popen([sys.executable, os.path.abspath(__file__), "add", "--source", "par", "--item", "p%d" % i],
                                  env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) for i in range(12)]
        for pr in procs:
            pr.wait()
        par = [r for r in load(q) if r["source"] == "par"]
        res.append(("W1 12 concurrent adds keep 12 rows with 12 distinct ids", len(par) == 12 and len({r["id"] for r in par}) == 12))
        good = open(q, encoding="utf-8").read()
        for label, row in (("L2 a typo status («opne») is an error, not «nothing open»", "AQ-x\t2026-10-28\ts\ti\t\topne\t\t\n"),
                           ("L3 a landed row without PR/commit evidence is an error", "AQ-y\t2026-10-28\ts\ti\t\tlanded\t2026-10-28\tdone\n"),
                           ("L4 a row with an empty item is an error", "AQ-z\t2026-10-28\ts\t\t\topen\t\t\n"),
                           ("L5 a row with a bad added date is an error", "AQ-w\t28/10/2026\ts\ti\t\topen\t\t\n"),
                           ("L1 a malformed row is an error (rc 10), not silently skipped", "broken\trow\n")):
            with open(q, "w", encoding="utf-8") as f:
                f.write(good + row)
            rc, out = run("summary")
            res.append((label, rc == 10))
    m = match("ko-tech-writer 번역투 기술블로그 개고")
    res.append(("M1 match finds ko-tech-writer for its own vocabulary", any(name == "ko-tech-writer" for _, _, name, _ in m)))
    m2 = match("QA 엔지니어 테스트 케이스 재현 화면")
    res.append(("M2 match also indexes agent definitions (qa-lens)", any(p.endswith("agents/qa-lens.md") for _, p, _, _ in m2)))
    ok = 0
    for name, passed in res:
        print("%s %s" % ("OK  " if passed else "FAIL", name))
        ok += passed
    print("── PASS=%d FAIL=%d ──" % (ok, len(res) - ok))
    return 0 if ok == len(res) else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

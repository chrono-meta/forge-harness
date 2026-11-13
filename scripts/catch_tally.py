#!/usr/bin/env python3
"""catch_tally.py — 마감 때 적은 «잡은 것» 표를 날짜 범위로 센다.

왜 (2026-11-08 운영자): «작은 시뮬레이션보다는 정말 어려운 무언가에 맞닥뜨렸을 때 방법론들로
결함을 잡은 것들을 그때그때 마감 때 카운트해 보는 게 맞을 듯». 11-07 두 번의 재측정은 심은
결함이 쉬워 일반 검토가 87~100% 를 잡았고(천장), 방법 차이를 잴 힘이 없었다. 방법의 값은
실작업에서 «일반 검토·저자가 놓친 것을 무엇이 잡았나» 로 드러나므로 그 기록을 센다.

기록 자리: Session Wrap-up ⑤(a) 가 `tracks/_meta/fh_completed_{date}.md` 에 쓰는 `## 잡은 것` 절
(Record location: the `## 잡은 것` section; the English heading `## Catches` is accepted as the same section.)

    ## 잡은 것
    | 결함 | 잡은 방법 | 놓친 쪽 | 근거 |
    |---|---|---|---|
    | 빈 집합에서 판정이 통과로 기움 | cross-family | author | #1041 |

  또는 잡은 게 없으면 표 대신 한 줄: `0건 — <살펴본 범위>`

기계가 보는 것은 기록의 성질뿐이다(present · typed · attributable). 그 결함이 정말 어려웠는지,
그 방법이 정말 잡았는지는 판단이고 이 스크립트는 판정하지 않는다.
  - 절이 없거나 범위 없는 0건뿐인 날 = NOT_RECORDED (0 이 아니다 — 안 적은 것과 잡은 게 없는 것은 다르다)
  - `0건 —` 뒤에 범위가 없으면 INVALID (빈 0 은 미측정과 구분이 안 된다)
  - 방법·놓친 쪽이 닫힌 목록 밖이거나 근거가 비면 그 행은 INVALID 로 따로 찍고 세지 않는다

사용:
  catch_tally.py [--dir tracks/_meta] [--days 7] [--until YYYY-MM-DD]
  catch_tally.py --self-test
exit: 0 집계 · 1 self-test 실패 · 2 INVALID 행 있음(집계는 찍는다) · 10 입력 오류
"""
import argparse, datetime as dt, os, re, sys, tempfile

METHODS = ["cross-family", "revert-probe", "control", "lens", "gate", "lane", "operator", "self"]
MISSED = ["author", "plain-review", "lane", "gate", "none"]
HEAD_RE = re.compile(r"^##\s+(잡은 것|Catches)\s*$")
ZERO_RE = re.compile(r"^\s*0건\s*(?:—|-{1,2})\s*(.*)$")
FILE_RE = re.compile(r"^fh_completed_(\d{4}-\d{2}-\d{2})\.md$")
PLACEHOLDER = {"", "-", "—", "tbd", "없음", "n/a", "na"}
# 근거 = PR(#123 · /pull/123) · 커밋 해시(7~40자) · 파일:줄. 그 밖의 낱말만 있으면 «귀속 가능» 이 아니다.
EVIDENCE_RE = re.compile(r"#\d+|/pull/\d+|\b[0-9a-f]{7,40}\b|[\w./-]+\.\w+:\d+")
SEP_RE = re.compile(r"^:?-+:?$")


def parse_section(text):
    """Return (state, rows, invalid). state ∈ NOT_RECORDED | ZERO | ROWS."""
    lines = text.splitlines()
    starts = [i for i, l in enumerate(lines) if HEAD_RE.match(l)]
    if not starts:
        return "NOT_RECORDED", [], []
    rows, invalid, zero = [], [], None
    for s in starts:  # 하루에 마감이 둘 이상이면 절도 둘 이상일 수 있다 — 전부 읽는다
        for l in lines[s + 1:]:
            if l.startswith("#"):
                break
            m = ZERO_RE.match(l)
            if m:
                scope = m.group(1).strip()
                if scope.lower() in PLACEHOLDER:
                    invalid.append((l.strip(), "0건 뒤에 살펴본 범위가 없다"))
                else:
                    zero = scope
                continue
            if not l.strip().startswith("|"):
                continue
            cells = [c.strip() for c in l.strip().strip("|").split("|")]
            if all(SEP_RE.match(c) for c in cells) or cells[0] == "결함":
                continue  # 구분선 · 머리줄
            if len(cells) != 4:
                invalid.append((l.strip(), f"칸이 {len(cells)}개 — 4칸(결함·잡은 방법·놓친 쪽·근거)이어야 한다"))
                continue
            defect, method, missed, evidence = cells
            why = []
            if defect.lower() in PLACEHOLDER:
                why.append("결함이 비었다")
            if method not in METHODS:
                why.append(f"잡은 방법 «{method}» 는 목록 밖")
            if missed not in MISSED:
                why.append(f"놓친 쪽 «{missed}» 는 목록 밖")
            if evidence.lower() in PLACEHOLDER:
                why.append("근거가 비었다")
            elif not EVIDENCE_RE.search(evidence):
                why.append(f"근거 «{evidence}» 에 PR · 커밋 · 파일:줄이 없다")
            if why:
                invalid.append((l.strip(), " · ".join(why)))
            else:
                rows.append((defect, method, missed, evidence))
    if rows:
        return "ROWS", rows, invalid
    if zero is not None:
        return "ZERO", [], invalid
    return "NOT_RECORDED", [], invalid


def tally(d, days, until):
    lo = until - dt.timedelta(days=days - 1)
    found, badnames = {}, []
    for name in sorted(os.listdir(d)):
        m = FILE_RE.match(name)
        if not m:
            continue
        try:
            day = dt.date.fromisoformat(m.group(1))
        except ValueError:
            badnames.append(name)  # 범위 판단을 못 하니 무조건 알린다 — 한 파일이 리포트 전체를 죽이지 않게
            continue
        if lo <= day <= until:
            with open(os.path.join(d, name), encoding="utf-8") as f:
                found[day] = parse_section(f.read())
    return lo, found, badnames


def report(d, days, until, out=sys.stdout):
    lo, found, badnames = tally(d, days, until)
    by_m = {k: 0 for k in METHODS}
    by_x = {k: 0 for k in MISSED}
    states = {"ROWS": 0, "ZERO": 0, "NOT_RECORDED": 0}
    bad = []
    for day, (state, rows, invalid) in sorted(found.items()):
        states[state] += 1
        for _, mth, mis, _ in rows:
            by_m[mth] += 1
            by_x[mis] += 1
        bad += [(day, r, w) for r, w in invalid]
    bad += [("-", n, "파일 이름의 날짜가 달력에 없다") for n in badnames]
    nofile = [str(lo + dt.timedelta(days=i)) for i in range(days)
              if lo + dt.timedelta(days=i) not in found]
    total = sum(by_m.values())
    p = lambda *a: print(*a, file=out)
    p(f"catch_tally {lo}..{until} · 마감 기록 파일 {len(found)}개 "
      f"(잡은 것 있음 {states['ROWS']} · 0건(범위 적음) {states['ZERO']} · 🟥 미기록 {states['NOT_RECORDED']})")
    if nofile:
        p(f"  ⬜ 마감 파일 자체가 없는 날 {len(nofile)}개(마감이 없었거나 안 적음 — 0 으로 세지 않는다): {', '.join(nofile)}")
    if states["NOT_RECORDED"]:
        miss = [str(k) for k, v in found.items() if v[0] == "NOT_RECORDED"]
        p(f"  🟥 미기록(절 없음 또는 범위 없는 0건) = 0 이 아니다: {', '.join(miss)}")
    p(f"  잡은 것 {total}건")
    p("  잡은 방법: " + " · ".join(f"{k} {v}" for k, v in by_m.items() if v) if total else "  잡은 방법: —")
    p("  놓친 쪽:   " + " · ".join(f"{k} {v}" for k, v in by_x.items() if v) if total else "  놓친 쪽:   —")
    for day, r, w in bad:
        p(f"  ⚠️ INVALID {day}: {w} — {r}")
    return 2 if bad else 0


def self_test():
    ok = True
    with tempfile.TemporaryDirectory() as t:
        w = lambda n, s: open(os.path.join(t, n), "w", encoding="utf-8").write(s)
        w("fh_completed_2026-01-05.md", "# x\n## 잡은 것\n| 결함 | 잡은 방법 | 놓친 쪽 | 근거 |\n|---|---|---|---|\n"
          "| 빈 집합 통과 | cross-family | author | #1 |\n| 되돌려도 초록 | revert-probe | lane | commit:abc1234 |\n"
          "| 오타 | codex | author | #2 |\n## 다음\n| 무시 | self | none | x |\n")
        w("fh_completed_2026-01-06.md", "## 잡은 것\n0건 — FoD 릴리스 PR 두 개만 봄\n")
        w("fh_completed_2026-01-07.md", "# 절 없음\n")
        w("fh_completed_2026-01-08.md", "## Catches\n0건 —\n")
        w("fh_completed_2025-12-01.md", "## 잡은 것\n| 범위 밖 | self | none | #9 |\n")
        w("fh_completed_2026-01-03.md", "## 잡은 것\n| 칸 부족 | self | author |\n| | self | author | #1 |\n"
          "| 칸 넘침 | self | author | #1 | x |\n| 근거 낱말 | self | author | banana |\n"
          "| 파일 근거 | lens | plain-review | scripts/x.sh:12 |\n")
        w("fh_completed_2026-02-30.md", "## 잡은 것\n0건 — x\n")
        import io
        buf = io.StringIO()
        rc = report(t, 7, dt.date(2026, 1, 8), buf)
        o = buf.getvalue()
        checks = [
            ("rc=2 (INVALID 있음)", rc == 2),
            ("잡은 것 3건(목록 밖 행·다른 절·범위 밖 날 제외)", "잡은 것 3건" in o),
            ("cross-family 1 · revert-probe 1", "cross-family 1" in o and "revert-probe 1" in o),
            ("놓친 쪽 author 1 · lane 1", "author 1" in o and "lane 1" in o),
            ("0건+범위 = ZERO 로 셈", "0건(범위 적음) 1" in o),
            ("절 없는 날·빈 0건 = 미기록, 0 아님", "미기록 2" in o and "2026-01-07, 2026-01-08" in o),
            ("범위 없는 0건 = INVALID", "살펴본 범위가 없다" in o),
            ("목록 밖 방법 = INVALID", "«codex» 는 목록 밖" in o),
            ("칸 부족 = INVALID", "칸이 3개" in o),
            ("빈 결함 칸 = INVALID(구분선으로 오인 안 함)", "결함이 비었다" in o),
            ("칸 넘침 = INVALID", "칸이 5개" in o),
            ("근거에 PR·커밋·파일:줄 없음 = INVALID", "«banana» 에 PR" in o),
            ("파일:줄 근거는 유효 — lens 1 셈", "lens 1" in o),
            ("달력에 없는 날짜 파일 = INVALID, 리포트는 계속", "달력에 없다" in o and "2026-02-30" in o),
            ("파일 없는 날 = 따로 표시(0 아님)", "파일 자체가 없는 날 2개" in o and "2026-01-02, 2026-01-04" in o),
        ]
        # 컨트롤: 같은 디렉터리에서 유효 행만 남기면 rc=0 이어야 한다(INVALID 판정이 늘 켜진 건 아님)
        w("fh_completed_2026-01-05.md", "## 잡은 것\n| 빈 집합 통과 | cross-family | author | #1 |\n")
        w("fh_completed_2026-01-08.md", "## 잡은 것\n0건 — 문서 PR 하나\n")
        os.remove(os.path.join(t, "fh_completed_2026-01-03.md"))
        os.remove(os.path.join(t, "fh_completed_2026-02-30.md"))
        rc2 = report(t, 7, dt.date(2026, 1, 8), io.StringIO())
        checks.append(("컨트롤: 유효 기록만이면 rc=0", rc2 == 0))
    for name, good in checks:
        print(("PASS " if good else "FAIL ") + name)
        ok &= good
    if not ok:
        print("--- 출력 ---\n" + o)
    return 0 if ok else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--dir", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tracks", "_meta"))
    ap.add_argument("--days", type=int, default=7)
    ap.add_argument("--until", default=None)
    ap.add_argument("--self-test", action="store_true")
    a = ap.parse_args()
    if a.self_test:
        return self_test()
    if a.days < 1 or not os.path.isdir(a.dir):
        print(f"입력 오류: --dir {a.dir} / --days {a.days}", file=sys.stderr)
        return 10
    try:
        until = dt.date.fromisoformat(a.until) if a.until else dt.date.today()
        until - dt.timedelta(days=a.days - 1)
    except (ValueError, OverflowError):
        print(f"입력 오류: --until {a.until}", file=sys.stderr)
        return 10
    return report(a.dir, a.days, until)


if __name__ == "__main__":
    sys.exit(main())

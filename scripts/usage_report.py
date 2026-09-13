#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""사용 원장 리포터 — 네 줄(사용자 · 재사용률 · p95 · 단가)을 낸다.

🟥 **부재는 0 이 아니다.** 원장 디렉터리가 없거나 비면 `NOT-INSTRUMENTED` 로 끝내고 rc=9 를 낸다
   — 「사용자 0 명」이라고 쓰지 않는다. 그 둘을 같은 얼굴로 렌더하는 것이 이 저장소가
   이름으로 관리하는 결함 부류다.

🟥 **표본이 작으면 p95 를 숫자로 주지 않는다.** n<20 이면 `UNCALIBRATED` 로 적고 최대·중앙만 준다.

🟥 **두 번째 신호** — `--expect-dirs <glob>` 를 주면 산출 디렉터리 수와 원장 행 수를 대조한다.
   한쪽만 보면 「계기가 안 돌았다」와 「아무도 안 썼다」가 같은 0 으로 보인다.

사용:
  python3 usage_report.py --harness preprep --days 30
  python3 usage_report.py --harness act2 --expect-dirs 'outputs/act2/*/'
"""
import argparse
import glob as globmod
import json
import os
import sys
import time


def pct(vals, p):
    if not vals:
        return None
    s = sorted(vals)
    k = max(0, min(len(s) - 1, int(round(p / 100.0 * len(s) + 0.5)) - 1))
    return s[k]


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", default=os.environ.get("FH_USAGE_LEDGER", ""))
    ap.add_argument("--harness", default=None)
    ap.add_argument("--days", type=int, default=30)
    ap.add_argument("--expect-dirs", default=None,
                    help="두 번째 신호: 산출 디렉터리 glob. 행 수와 대조한다")
    a = ap.parse_args(argv)

    print("═" * 58)
    if not a.dir:
        print("  커버리지 : NOT-INSTRUMENTED — FH_USAGE_LEDGER 미설정")
        print("  🟥 이것은 「사용자 0 명」이 아니다. 아무것도 안 쟀다는 뜻이다.")
        print("═" * 58)
        return 9
    if not os.path.isdir(a.dir):
        print("  커버리지 : NOT-INSTRUMENTED — 원장 디렉터리 없음 (%s)" % a.dir)
        print("  🟥 이것은 「사용자 0 명」이 아니다.")
        print("═" * 58)
        return 9

    pat = os.path.join(a.dir, ("%s-*.jsonl" % a.harness) if a.harness else "*.jsonl")
    files = sorted(globmod.glob(pat))
    if not files:
        print("  커버리지 : NOT-INSTRUMENTED — 해당 하네스 원장 파일 없음")
        print("             찾은 패턴: %s" % pat)
        print("  🟥 이것은 「사용자 0 명」이 아니다.")
        print("═" * 58)
        return 9

    cutoff = time.strftime("%Y-%m-%dT%H:%MZ",
                           time.gmtime(time.time() - a.days * 86400))
    rows, bad = [], 0
    for f in files:
        for line in open(f, encoding="utf-8"):
            line = line.strip()
            if not line:
                continue
            try:
                r = json.loads(line)
            except Exception:
                bad += 1
                continue
            if r.get("ts", "") >= cutoff:
                rows.append(r)

    errs = 0
    try:
        errs = int(open(os.path.join(a.dir, ".errors")).read().strip() or 0)
    except Exception:
        errs = 0
    # 🟥 `.errors` 는 자기 실패를 못 센다 — 디렉터리가 통째로 못 쓰이면 원장도 카운터도 안 남고
    #    출력은 「행 0」이라는 깨끗한 얼굴이 된다. 그래서 쓰기 가능 여부를 **여기서 직접** 본다.
    writable = os.access(a.dir, os.W_OK | os.X_OK)

    work = [r for r in rows if r.get("out") == "DONE"]
    skipped = len(rows) - len(work)
    authors = {r["actor"] for r in rows if r.get("author")}
    others = {}
    for r in rows:
        if not r.get("author"):
            others[r["actor"]] = others.get(r["actor"], 0) + 1

    # 🟥 원장 지문 — actor 해시는 **이 디렉터리의 salt** 로 만들어진다. 지문이 다른 두 리포트의
    #    actor id 는 **같은 사람이라도 다르다**. 합치면 한 사람이 둘로 세어진다. 그래서 판정과
    #    같은 실행에 지문을 찍는다(합칠 수 있는지는 이 줄이 답한다).
    fp = "unknown"
    try:
        import hashlib
        fp = hashlib.sha256(open(os.path.join(a.dir, ".salt")).read().strip().encode()).hexdigest()[:8]
    except Exception:
        pass
    print("  하네스 %s · 최근 %d 일 · 원장 파일 %d · 원장 지문 %s"
          % (a.harness or "(전체)", a.days, len(files), fp))
    cov = "INSTRUMENTED"
    if errs:
        cov += " · 🟥 쓰기 실패 %d 건 (아래 수치는 그만큼 적게 셌다)" % errs
    if bad:
        cov += " · 깨진 줄 %d" % bad
    if not writable:
        cov += " · 🟥 원장 디렉터리에 쓸 수 없다 — 아래 「행 0」은 «안 썼다»가 아니라 «못 적었다»일 수 있다"
    print("  커버리지 : %s" % cov)
    # 🟥 cross-family codex 지목(2026-09-13, A-1/A-2): 종전엔 «깨진 줄 N» 을 커버리지에 적어놓고
    #    아래 네 줄은 **살아남은 부분집합으로 확정값처럼** 찍었다. 버려진 관측은 더 작은 그럴듯한
    #    숫자가 되지 「안 쟀다」가 되지 않는다 — 이 파일이 막겠다고 선언한 바로 그 부류다.
    #    그래서 관측 손실이 하나라도 있으면 **모든 개수는 하한(≥)**이 되고 p95 는 강제 UNCALIBRATED 다.
    incomplete = bool(bad) or bool(errs) or (not writable)
    GE = "≥" if incomplete else ""
    if incomplete:
        print("  🟥 관측 손실 확인 — 아래 개수는 **하한(≥)**이고 p95 는 내지 않는다.")
        print("     (깨진 줄 %d · 쓰기 실패 %d · 쓰기 가능 %s) 잃은 행이 몇인지는 «모른다»가 정답이다."
              % (bad, errs, "예" if writable else "아니오"))
    print("─" * 58)

    # ① 사용자
    if not others:
        # 🟥 cross-family codex R2 지목(2026-09-13): 여기가 A-1/A-2 의 **남은 절반**이었다.
        #    본선은 하한(≥)으로 고쳤는데 이 «비저자 0» 분기는 여전히 확정값을 찍고 있었다 —
        #    그리고 레인 ⑧⑨ 의 픽스처가 비저자 22 행이라 **이 분기를 구조적으로 안 밟았다**.
        #    관측 손실이 있으면 「0」이 아니라 「모른다」다.
        if incomplete:
            print("  ① 사용자     : 🟥 **모른다** — 비저자 행이 0 인데 관측 손실도 있다.")
            print("                 「아무도 안 썼다」와 「쓴 것을 못 적었다」를 이 표본으로는 못 가른다.")
            print("                 저자 ≥%d · 비저자 ≥0 (둘 다 하한)" % len(authors))
        else:
            print("  ① 사용자     : 🟥 비저자 사용 **미관측** (저자 %d · 비저자 0)" % len(authors))
            print("                 → §04① 미충족. 「0 명」이 아니라 「아직 안 잡혔다」다 —")
            print("                   남이 쓰려면 그쪽에서 FH_USAGE_LEDGER 를 켜야 한다(옵트인).")
    else:
        print("  ① 사용자     : 비저자 %s%d (머신-사용자 기준) · 저자 %s%d"
              % (GE, len(others), GE, len(authors)))

    # ② 재사용률
    if others:
        rep = sum(1 for v in others.values() if v >= 2)
        vals = sorted(others.values())
        if incomplete:
            print("  ② 재사용률   : 산출 안 함 — 관측 손실이 있으면 비율은 분모가 틀린다"
                  " (2회 이상 %s%d / 관측된 %s%d)" % (GE, rep, GE, len(others)))
        else:
            print("  ② 재사용률   : %d/%d = %.0f%% (2회 이상) · 1인당 실행 중앙 %d · 최대 %d"
                  % (rep, len(others), 100.0 * rep / len(others),
                     vals[len(vals) // 2], vals[-1]))
    elif incomplete:
        print("  ② 재사용률   : 산출 불가 — 비저자 표본 ≥0 이고 관측 손실도 있다(분모를 모른다)")
    else:
        print("  ② 재사용률   : 산출 불가 — 비저자 표본 0")

    # ③ p95 (작업 행만)
    w = [r.get("wall_ms", 0) for r in work if isinstance(r.get("wall_ms"), int)]
    if incomplete:
        print("  ③ p95 지연   : UNCALIBRATED — 관측 손실이 있는 표본에서 분위수는 못 낸다")
    elif not w:
        print("  ③ p95 지연   : 산출 불가 — 작업 행 0")
    elif len(w) < 20:
        print("  ③ p95 지연   : UNCALIBRATED (n=%d < 20) · 중앙 %d ms · 최대 %d ms"
              % (len(w), pct(w, 50), max(w)))
    else:
        print("  ③ p95 지연   : %d ms (n=%d) · 중앙 %d ms · 최대 %d ms"
              % (pct(w, 95), len(w), pct(w, 50), max(w)))
    if skipped:
        print("                 (비작업 행 %d 개 제외 — --help·조기 종료. 버린 게 아니라 갈랐다)"
              % skipped)

    # ④ 단가
    llm_rows = [r for r in work if isinstance(r.get("llm"), dict)]
    if not llm_rows:
        cpu = [r.get("cpu_ms", 0) for r in work if isinstance(r.get("cpu_ms"), int)]
        print("  ④ 판정 단가  : LLM 호출 **N/A — 결정적 경로**(이 진입점은 모델을 안 부른다)")
        if cpu:
            print("                 실행당 CPU 중앙 %d ms · 최대 %d ms" % (pct(cpu, 50), max(cpu)))
        print("                 🟥 «0 원»이라고 쓰지 마라 — 안 부른 것과 공짜인 것은 다르다.")
        print("                    쓸 수 있는 문장: 「이 판정은 모델을 안 부르므로 건당 토큰 비용이")
        print("                    발생하지 않는다」. 그게 LLM 심판 대비 우위의 정확한 형태다.")
    else:
        tok = sum(r["llm"].get("tokens", 0) for r in llm_rows)
        print("  ④ 판정 단가  : 실행당 토큰 평균 %.0f (LLM 실행 %d/%d)"
              % (tok / float(len(llm_rows)), len(llm_rows), len(work)))

    # 두 번째 신호
    if a.expect_dirs:
        n_dirs = len([p for p in globmod.glob(a.expect_dirs) if os.path.isdir(p)])
        print("─" * 58)
        mark = "✅ 일치" if n_dirs == len(work) else "🟥 어긋남"
        print("  두 번째 신호 : 산출 디렉터리 %d vs 작업 행 %d — %s" % (n_dirs, len(work), mark))
        if n_dirs != len(work):
            print("                 둘이 다르면 「아무도 안 썼다」와 「계기가 안 돌았다」가")
            print("                 갈린다. 디렉터리가 많으면 원장이 못 잡은 실행이 있다.")
    else:
        print("─" * 58)
        print("  두 번째 신호 : 없음 — 이 수치는 원장 한 곳에만 기댄다(--expect-dirs 로 붙일 수 있다)")

    print("═" * 58)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

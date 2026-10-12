#!/usr/bin/env python3
"""lane_onoff_compare.py — 레인 하나를 FH_LANE_STUB=off / on 으로 돌려 «켠 것이 무엇을 바꿨나» 를 본다.

설계 = tracks/_meta/design_light_gate_2026-10-12.md §11. 레인 rc 동일성은 충분조건이 아니라서
(경고가 사라져도 rc 는 같다) 다음을 비교한다.
  ① 레인 출력의 «모든» 비지 않은 줄의 다중집합 — 정규화 없음. 실행마다 바뀌는 줄은 호출자가
     --volatile REGEX 로 선언하고, 그 줄은 UNMEASURED 로 보고돼 승인 근거에서 빠진다(줄 수가 다르면 DIFF)
  🟥 비교하지 않는 것: 레인이 출력하지 않는 호출 기록. «스텁이 실제로 불렸나» 는 각 레인 자신의 단언이
     지고, 끈 팔의 진짜 gh 호출 횟수는 여기서 세지 않는다(codex 구현 R1 A3 — 잔여로 남긴다).
  ② 종료 부류 — 0 · 3(픽스처 오류) · 그 외 비0
  ③ (선택) --manifest 의 기대 줄이 양쪽에 다 있나 — 같은 줄이 «양쪽에서» 사라지는 것을 잡는다
  어느 팔이든 단언(✅ ❌ PASS FAIL …)이 하나도 없으면 HARNESS-ERROR — 비교할 것이 없는 것은 «같다» 가 아니다.

사용   lane_onoff_compare.py run <lane.sh> [--manifest F] [--volatile REGEX]... [--save-dir D]
       lane_onoff_compare.py files <off.txt> <rc_off> <on.txt> <rc_on> [--manifest F] [--volatile REGEX]...
       lane_onoff_compare.py manifest <out.txt>            (기대 줄 목록을 뽑는다)
종료   0 같음 · 1 다름 · 3 HARNESS-ERROR · 2 사용법
"""
import collections
import os
import re
import subprocess
import sys

# 비교 대상은 «모든» 비지 않은 줄이다 — 단언 줄만 고르는 정규식은 라운드마다 빠뜨린 형태가 나왔다
# (요약 필드 PASS=39 · CACHED · 기호 없는 UNMEASURED, codex 구현 R1~R3). 이 정규식은 «단언이 하나라도
# 있나» 를 보는 계기 확인용일 뿐이다.
ASSERT_RE = re.compile(r"✅|❌|(?<![A-Za-z])(?:PASS|FAIL)(?![A-Za-z])|HARNESS[-_ ]ERROR|FIXTURE ERROR")   # BYPASS·PASSIVE·FAILURE 는 아니다
# 정규화는 «실행마다 바뀌는 것» 에만 — 임시 경로 · 날짜 · 시각 · 소요 시간 · 4자리 이상 수(pid 등).
# 레인 번호(L2)와 진단의 작은 수(SUPERSEDED=2)는 지키지 않으면 서로 다른 줄이 같아진다(codex A1).
def lines(text, volatile):
    """→ (비교할 줄 다중집합, 휘발 선언 줄 수). 정규화는 없다 — 무엇이 «실행마다 바뀌나» 는 계기가 추측하지
    않고 호출자가 --volatile 로 선언한다(codex 구현 R1~R5: 계기가 고른 정규화는 매번 진짜 값을 지웠다)."""
    keep, vol = collections.Counter(), 0
    for l in text.split("\n"):   # 줄 경계는 \n 하나 — splitlines 는 U+2028 등도 경계로 바꾼다(codex 구현 R6)
        if not l.strip():
            continue
        if any(rx.search(l) for rx in volatile):
            vol += 1
        else:
            keep[l] += 1   # 공백까지 그대로 — strip 은 선언 없는 정규화다
    return keep, vol


def has_assertion(text):
    return any(ASSERT_RE.search(l) for l in text.split("\n"))


def exit_class(rc):
    return "0" if rc == 0 else ("3" if rc == 3 else "nonzero")


def compare(off_text, rc_off, on_text, rc_on, manifest=None, volatile=()):
    (a_off, v_off), (a_on, v_on) = lines(off_text, volatile), lines(on_text, volatile)
    if not has_assertion(off_text) or not has_assertion(on_text):
        return 3, ["HARNESS-ERROR: 단언 줄이 없다 (off=%d줄 on=%d줄) — 레인이 판정을 안 냈다" % (sum(a_off.values()), sum(a_on.values()))]
    out, rc = [], 0
    if volatile:
        out.append("UNMEASURED  휘발 선언 줄 off×%d on×%d — 비교·승인 근거에서 뺐다" % (v_off, v_on))
        if v_off != v_on:
            out.append("DIFF  휘발 선언 줄 수가 다르다 off×%d on×%d" % (v_off, v_on))
            rc = 1
    for line in sorted(set(a_off) | set(a_on)):
        if a_off[line] != a_on[line]:
            out.append("DIFF  off×%d on×%d  %s" % (a_off[line], a_on[line], line))
            rc = 1
    if exit_class(rc_off) != exit_class(rc_on):
        out.append("DIFF  종료 부류 off=%s(rc %d) on=%s(rc %d)" % (exit_class(rc_off), rc_off, exit_class(rc_on), rc_on))
        rc = 1
    for want, n in collections.Counter(manifest or []).items():   # 개수까지 (codex A4)
        if a_off[want] < n or a_on[want] < n:
            out.append("MISSING  manifest ×%d 기대, off×%d on×%d: %s" % (n, a_off[want], a_on[want], want))
            rc = 1
    return rc, out


def read_manifest(path):
    with open(path, encoding="utf-8", errors="surrogateescape", newline="") as f:
        return [l for l in f.read().split("\n") if l.strip()]


def run_lane(lane, arm):
    env = dict(os.environ, FH_LANE_STUB=arm)
    p = subprocess.run(["bash", lane], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                       stdin=subprocess.DEVNULL)
    return p.stdout.decode("utf-8", "surrogateescape"), p.returncode   # 바이트 무손실 — CR·잘못된 UTF-8 도 그대로(codex 구현 R7·R8)


def main(argv):
    args = argv[1:]
    manifest = None
    if "--manifest" in args:
        i = args.index("--manifest")
        manifest = read_manifest(args[i + 1])
        del args[i:i + 2]
    volatile = []
    while "--volatile" in args:
        i = args.index("--volatile")
        volatile.append(re.compile(args[i + 1]))
        del args[i:i + 2]
    save = None
    if "--save-dir" in args:
        i = args.index("--save-dir")
        save = args[i + 1]
        del args[i:i + 2]
    if args[:1] == ["manifest"] and len(args) == 2:
        with open(args[1], encoding="utf-8", errors="surrogateescape", newline="") as f:
            for line in sorted(lines(f.read(), ())[0].elements()):   # manifest 는 기계 입력 — 원 바이트 그대로(codex 구현 R9)
                sys.stdout.buffer.write(line.encode("utf-8", "surrogateescape") + b"\n")
        return 0
    if args[:1] == ["files"] and len(args) == 5:
        def rd(p):
            with open(p, encoding="utf-8", errors="surrogateescape", newline="") as f:
                return f.read()
        rc, out = compare(rd(args[1]), int(rd(args[2]).strip()), rd(args[3]), int(rd(args[4]).strip()), manifest, volatile)
    elif args[:1] == ["run"] and len(args) == 2:
        off, rc_off = run_lane(args[1], "off")
        on, rc_on = run_lane(args[1], "on")
        if save:
            os.makedirs(save, exist_ok=True)
            base = os.path.basename(args[1])
            for arm, txt, r in (("off", off, rc_off), ("on", on, rc_on)):
                with open(os.path.join(save, "%s.%s.txt" % (base, arm)), "w", encoding="utf-8", errors="surrogateescape", newline="") as f:
                    f.write(txt)
                with open(os.path.join(save, "%s.%s.rc" % (base, arm)), "w") as f:
                    f.write("%d\n" % r)
        rc, out = compare(off, rc_off, on, rc_on, manifest, volatile)
    else:
        sys.stderr.write(__doc__)
        return 2
    for line in out:   # 잘못된 바이트는 보일 때만 \xNN 로 — 비교는 원 바이트로 했다
        print(line.encode("utf-8", "surrogateescape").decode("utf-8", "backslashreplace"))
    print("lane-onoff: %s" % {0: "SAME", 1: "DIFFERENT", 3: "HARNESS-ERROR"}[rc])
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv))

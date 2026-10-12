#!/usr/bin/env python3
"""lane_onoff_compare.py — 레인 하나를 FH_LANE_STUB=off / on 으로 돌려 «켠 것이 무엇을 바꿨나» 를 본다.

설계 = tracks/_meta/design_light_gate_2026-10-12.md §11. 레인 rc 동일성은 충분조건이 아니라서
(경고가 사라져도 rc 는 같다) 다음을 비교한다.
  ① 단언·진단 줄(✅ ❌ ⚠️ PASS FAIL HARNESS)의 다중집합 — 숫자·임시 경로는 정규화
  ② 종료 부류 — 0 · 3(픽스처 오류) · 그 외 비0
  ③ (선택) --manifest 의 기대 줄이 양쪽에 다 있나 — 같은 줄이 «양쪽에서» 사라지는 것을 잡는다
  출력이 비거나 단언 줄이 0 이면 HARNESS-ERROR — 비교할 것이 없는 것은 «같다» 가 아니다.

사용   lane_onoff_compare.py run <lane.sh> [--manifest F] [--save-dir D]
       lane_onoff_compare.py files <off.txt> <rc_off> <on.txt> <rc_on> [--manifest F]
       lane_onoff_compare.py manifest <out.txt>            (기대 줄 목록을 뽑는다)
종료   0 같음 · 1 다름 · 3 HARNESS-ERROR · 2 사용법
"""
import collections
import os
import re
import subprocess
import sys

ASSERT_RE = re.compile(r"✅|❌|⚠️|^\s*(?:PASS|FAIL)\b|HARNESS[-_ ]ERROR|FIXTURE ERROR")
TMP_RE = re.compile(r"(?:/private)?/(?:var/folders|tmp)/\S*")


def norm(line):
    line = TMP_RE.sub("<tmp>", line.strip())
    return re.sub(r"\d+", "#", line)


def assertions(text):
    return collections.Counter(norm(l) for l in text.splitlines() if ASSERT_RE.search(l))


def exit_class(rc):
    return "0" if rc == 0 else ("3" if rc == 3 else "nonzero")


def compare(off_text, rc_off, on_text, rc_on, manifest=None):
    a_off, a_on = assertions(off_text), assertions(on_text)
    if not a_off or not a_on:
        return 3, ["HARNESS-ERROR: 단언 줄이 없다 (off=%d on=%d) — 비교할 것이 없다" % (sum(a_off.values()), sum(a_on.values()))]
    out, rc = [], 0
    for line in sorted(set(a_off) | set(a_on)):
        if a_off[line] != a_on[line]:
            out.append("DIFF  off×%d on×%d  %s" % (a_off[line], a_on[line], line))
            rc = 1
    if exit_class(rc_off) != exit_class(rc_on):
        out.append("DIFF  종료 부류 off=%s(rc %d) on=%s(rc %d)" % (exit_class(rc_off), rc_off, exit_class(rc_on), rc_on))
        rc = 1
    for want in manifest or []:
        if not a_off[want] or not a_on[want]:
            out.append("MISSING  manifest 줄이 %s 에 없다: %s" % ("양쪽" if not a_off[want] and not a_on[want] else ("off" if not a_off[want] else "on"), want))
            rc = 1
    return rc, out


def read_manifest(path):
    with open(path, encoding="utf-8") as f:
        return [l.rstrip("\n") for l in f if l.strip()]


def run_lane(lane, arm):
    env = dict(os.environ, FH_LANE_STUB=arm)
    p = subprocess.run(["bash", lane], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                       text=True, errors="replace", stdin=subprocess.DEVNULL)
    return p.stdout, p.returncode


def main(argv):
    args = argv[1:]
    manifest = None
    if "--manifest" in args:
        i = args.index("--manifest")
        manifest = read_manifest(args[i + 1])
        del args[i:i + 2]
    save = None
    if "--save-dir" in args:
        i = args.index("--save-dir")
        save = args[i + 1]
        del args[i:i + 2]
    if args[:1] == ["manifest"] and len(args) == 2:
        with open(args[1], encoding="utf-8", errors="replace") as f:
            for line in sorted(assertions(f.read())):
                print(line)
        return 0
    if args[:1] == ["files"] and len(args) == 5:
        def rd(p):
            with open(p, encoding="utf-8", errors="replace") as f:
                return f.read()
        rc, out = compare(rd(args[1]), int(rd(args[2]).strip()), rd(args[3]), int(rd(args[4]).strip()), manifest)
    elif args[:1] == ["run"] and len(args) == 2:
        off, rc_off = run_lane(args[1], "off")
        on, rc_on = run_lane(args[1], "on")
        if save:
            os.makedirs(save, exist_ok=True)
            base = os.path.basename(args[1])
            for arm, txt, r in (("off", off, rc_off), ("on", on, rc_on)):
                with open(os.path.join(save, "%s.%s.txt" % (base, arm)), "w", encoding="utf-8") as f:
                    f.write(txt)
                with open(os.path.join(save, "%s.%s.rc" % (base, arm)), "w") as f:
                    f.write("%d\n" % r)
        rc, out = compare(off, rc_off, on, rc_on, manifest)
    else:
        sys.stderr.write(__doc__)
        return 2
    for line in out:
        print(line)
    print("lane-onoff: %s" % {0: "SAME", 1: "DIFFERENT", 3: "HARNESS-ERROR"}[rc])
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv))

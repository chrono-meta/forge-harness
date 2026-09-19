#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""tikitaka_score.py — 다중턴 sim 전사본의 «수렴/반영» 채점기.

정본 = `tracks/_meta/prereg_2026-09-19_qasp-tikitaka-sim.md` §2. 이 파일은 그 §2 를 기계로
옮긴 것이고, **조건을 새로 만들지 않는다.** 사전등록이 토큰 단위로 선언한 C1·C2·C3·A1·A2 가
전부다. 여기서 조건을 추가하거나 완화하는 것은 사후에 기준을 옮기는 것이다.

WHY THIS EXISTS
  PR #759 가 `scripts/sim_isolated_run.sh --turns` 를 착지시켰다 — 러너는 생겼다.
  그 마커의 residual ⓔ 가 스스로 적는다: **«수렴/반영」을 채점하는 기계는 아직 0줄».**
  단발 프로브는 전부 «발화하는가»를 재고, 그 둘은 한 턴 안에 존재하지 않는다.
  이 파일이 그 0줄이다.

무엇을 재나 (사전등록 §2 축자)
  수렴 CONVERGED  C1 C 가 A 와 다르다 · C2 C 가 사람의 제약을 수치로 담는다
                  · C3 C 가 «무엇을 버렸는지» 이름으로 명명한다     ← 🟥 C3 이 하중이다
  반영 APPLIED    A1 C3 이 버린 항목이 T4 에 다시 나타나지 않는다
                  · A2 T4 의 항목 수가 원안 A 로 되돌아가지 않는다

🟥 무엇을 «안» 재나 — 사전등록 §5 가 봉인한 것을 여기서도 적는다
  · A(보강안) 의 **품질**을 안 잰다. 재는 것은 되밀기 이후의 거동뿐이다.
  · 이 채점기는 텍스트를 읽지 **의미를 판정하지 않는다** — 항목 집합의 «동일성·부재·개수»만 본다.
    「좋은 절충안인가」는 이 파일 밖이고, 그건 결함이 아니라 설계다(자연어 판정 금지).

─────────────────────────────────────────────────────────────────────────────────────────
🟥 하중 지는 설계 결정 셋 — 왜 이렇게 짰는지. 고치기 전에 읽어라.
─────────────────────────────────────────────────────────────────────────────────────────

① **«남긴 항목»과 «버렸다고 이름 댄 항목»은 같은 문서 안에 산다.**
   C3 을 만족하는 절충안은 **자기가 버린 TC id 를 자기 본문에 적는다.** 그러므로
   「T3 에 나오는 모든 id」를 C 의 집합으로 읽는 추출기는 **C1 을 구조적으로 뒤집는다**
   (A 와 C 가 같아 보인다). 판별은 **줄의 모양**으로 한다:
     · 남긴 항목 = TC id + 중요도 토큰(P0|P1|P2) + 필드 구분자 4개 이상  ← 실물 TC «행»
     · 버린 항목 = 드롭 마커가 있는 줄에 이름이 적힌 id (행이 아닌 곳)
   근거는 실물이다 — qasp `p7_tc_design.py` 의 Sheets 12컬럼은 모든 TC 행에 중요도를 싣고,
   산문 문장은 구분자 4개를 갖지 않는다.

② **공집합은 통과가 아니다** ([[feedback_not_found_is_not_zero_family]] ★7번째 = 폴백 연산자).
   A1 은 **부재 단언**이다. C3 이 아무것도 명명하지 않으면 버린 집합이 공집합이고,
   `dropped & t4 == {}` 는 **자동으로 참**이 된다 — 즉 «축소만 한» 산출이 A1 을 통과한다.
   그래서 버린 집합이 비면 A1 은 PASS 가 아니라 **UNMEASURED** 다.
   같은 이유로 T4 의 항목이 0 이면 A1 은 UNMEASURED 다(사전등록 §2-ⓑ · §4 F4).
   「안 나왔다」와 「아예 아무것도 안 나왔다」는 같은 얼굴이고, 그 둘을 가르는 것이 이 줄이다.

③ **컨트롤 값을 판정과 같은 출력에 찍는다** ([[feedback_catches_come_from_two_signals_disagreeing]]).
   죽은 추출기(전 턴 0 항목)는 깨끗한 대상의 0 과 **똑같이 생겼다.** 그래서 모든 회차가
   턴별 항목 집합을 그대로 출력한다 — 판정만 읽고 집합을 안 읽으면 죽은 계기를 못 본다.

USAGE
  python3 scripts/tikitaka_score.py --transcript <arm_r1.txt> --spec <spec.txt> [--turns <turns.txt>]
  python3 scripts/tikitaka_score.py --selftest     # known-pair 교정 (본측정 전 필수)

EXIT
  0  CONVERGED 이고 APPLIED           (본측정에서 «수렴+반영»)
  1  채점됐고 둘 중 하나라도 아님     (진짜 음성 결과)
  2  사용법/입력 오류
  3  UNMEASURED · 계기 사망 · spec 불일치   ← 🟥 3 이 0/1 을 이긴다(무음 미스 금지)
"""

import argparse
import os
import re
import sys

# ── 항목 id — 실물에서 뽑았다 ────────────────────────────────────────────────────────
# qasp `src/prism/protocols/p7_tc_design.py` 가 내는 실제 id 계열:
#   TC_F_{n:03d} · TC_BVA_{n:03d} · TC_SM_{n:03d} · TC_MECE_{n:03d} · TC_MT_{n:03d}
# 계열을 열거하지 않고 모양으로 잡는다 — 계열이 하나 늘 때마다 채점기가 조용히 눈머는 것을 막는다.
DEFAULT_ID_PATTERN = r"TC_[A-Z]{1,6}_[0-9]{1,4}"

# 중요도 — 실물 값 범위(P0/P1/P2). `p3_tc_review.py` 의 Format 검사가 같은 집합을 쓴다.
PRIORITY_RE = re.compile(r"(?<![0-9A-Za-z])P[012](?![0-9A-Za-z])")

# 행의 최소 칸 수. 실물 근거: qasp `p7_tc_design.py` 의 Sheets export 가 **12 컬럼**,
# CSV export 는 그보다 많다. markdown 표(`|`) 와 CSV(`,`) 를 둘 다 받는다 — 팔이 어느 쪽으로
# 낼지 채점기가 정할 수 없고, 한쪽만 받으면 «형식이 달라서 0» 이 «항목이 없어서 0» 으로 보인다.
#
# 🟥 **구분자를 세는 것만으로는 안 된다 — 이게 뚫리는 표기다.** «제외: TC_F_003, TC_BVA_002,
#    TC_BVA_003, TC_BVA_004, TC_SM_002 — P1 이하는 이월» 같은 **산문 한 줄**이 쉼표 4개와
#    P1 토큰을 동시에 갖는다. 즉 「구분자 N개 이상 + 중요도」 규칙은 **버린 항목을 남긴 항목으로
#    되읽는다** — 그러면 C1 이 구조적으로 뒤집힌다(A 와 C 가 같아 보인다).
#    🟥 그 줄을 실제로 막는 것은 칸 수가 아니라 **`_extract` 의 분기 «순서»** 다: 드롭 마커가
#    있는 비-표 줄은 CSV 경로에 닿기 전에 «버린 항목» 으로 빠진다. 되돌림 프로브가 정확히 그
#    분기를 죽여서 known-pair 가 깨지는 것을 확인한다(`test_tikitaka_score_lanes.sh` R1).
#    ⚠️ `|` 로 시작할 것 요구는 **방어선이지 하중선이 아니다** — `|`-분할 칸 수 검사만으로도
#    산문은 대개 걸러진다. 그렇게 적는다(안 그러면 안 지는 하중을 진다고 주장하는 셈이다).
# ⚠️ 정직한 degrade: 팔이 6컬럼짜리 압축 표를 내면 추출이 **0 이 된다.** 그때 채점기는
#    PASS 가 아니라 `NO-BASELINE`(rc=3) 으로 **시끄럽게** 죽는다 — 조용한 통과보다 낫다.
MIN_ROW_CELLS = 8

# 드롭 마커 — «무엇을 버렸는지» 를 사람이 실제로 쓰는 말들. 닫힌 목록이고, 넓히는 것은
# 조건 완화가 아니라 어휘 보강이다(같은 축). 🟥 그러나 넓힐 때마다 known-pair 를 다시 돌려라.
DROP_MARKERS = [
    "제외", "뺀다", "뺐", "버린", "버렸", "드롭", "drop", "보류", "이월",
    "다음 스프린트", "차기", "미포함", "포기", "out of scope", "범위 밖", "범위밖",
    "축소", "생략", "deferred", "defer",
]


def _split_turns(text):
    """러너의 연결 전사본을 턴별로 쪼갠다.

    형식(정본 = `sim_isolated_run.sh` fh_run_turns):
        \\n===== turn <k> (rc=<n>) =====\\n<본문>
    🟥 러너는 **실패한 턴에도 마커를 쓴다** — 그래서 마커 존재는 «산출이 있다» 가 아니다.
       본문이 비었는지는 호출부가 따로 본다.
    반환: [(k, rc, body), ...]  — k 오름차순
    """
    marker = re.compile(r"^=====\s*turn\s+(\d+)\s*\(rc=(-?\d+)\)\s*=====\s*$", re.M)
    hits = list(marker.finditer(text))
    if not hits:
        return []
    out = []
    for i, m in enumerate(hits):
        start = m.end()
        end = hits[i + 1].start() if i + 1 < len(hits) else len(text)
        out.append((int(m.group(1)), int(m.group(2)), text[start:end]))
    out.sort(key=lambda t: t[0])
    return out


def _has_drop_marker(line):
    low = line.lower()
    return any(mk in low for mk in DROP_MARKERS)


def _extract(body, id_re):
    """한 턴 본문에서 «남긴 항목»과 «버렸다고 이름 댄 항목»을 **한 번에** 가른다.

    한 벌로 모은 이유: 두 벌이면 한쪽만 통과하는 줄이 생긴다
    ([[feedback_divergent_leniency_duplicate_normalizers]]).

    판별 (설계 결정 ① — 위 헤더):
      · **markdown 표 행** — `|` 로 시작 + 칸 MIN_ROW_CELLS 개 이상 + 중요도 토큰
        → **남긴 항목**. 표 행은 권위가 있다. 비고에 «이월» 같은 낱말이 섞여도 남긴 것이다.
      · **그 외 줄** — 드롭 마커가 있으면 → **버린 항목**(이름만 댄 것).
      · **그 외 줄** 인데 드롭 마커가 없고 쉼표 칸이 MIN_ROW_CELLS 개 이상 + 중요도
        → 남긴 항목(CSV 로 낸 팔을 위한 경로).

    🟥 **셋째 경로가 왜 «드롭 마커 없을 때만» 인가 — 이게 뚫리는 표기다.**
       «제외: TC_F_003, TC_BVA_002, TC_BVA_003, TC_BVA_004 — 사유는 각각 시간, 중복, 중복,
       환경 비용이고, P1 이하라 이월한다» 는 **산문 한 줄**이 쉼표 7개(=칸 8개)와 P1 토큰을
       동시에 갖는다. 칸 수만 세는 규칙은 이 줄을 **남긴 행**으로 읽고, 그러면 C 가 A 와
       같아져 C1 이 구조적으로 뒤집힌다. 픽스처가 그 줄을 실제로 담고 있다.
    """
    retained, dropped = set(), set()
    for raw in body.splitlines():
        line = raw.strip()
        ids = id_re.findall(line)
        if not ids:
            continue
        is_table_row = (line.startswith("|")
                        and len(line.strip("|").split("|")) >= MIN_ROW_CELLS
                        and PRIORITY_RE.search(line))
        if is_table_row:
            retained.update(ids)
            continue
        if _has_drop_marker(line):
            dropped.update(ids)
            continue
        if len(line.split(",")) >= MIN_ROW_CELLS and PRIORITY_RE.search(line):
            retained.update(ids)
    return retained, dropped, (retained & dropped)


def _read(path):
    with open(path, encoding="utf-8", errors="replace") as fh:
        return fh.read()


def _parse_spec(path):
    """사전등록된 채점 파라미터. **시나리오를 쓸 때 같이 고정한다 — 결과를 보고 고르지 않는다.**

    형식 (`#` 주석 · `key=value`):
        constraint=4건        C2 가 C 본문에서 찾을 제약 토큰. 여러 줄 허용(전부 있어야 PASS)
        revert_tol=1          A2 — |A| 와 |T4| 의 차가 이 값 이하면 «되돌림» 으로 FAIL
        role_A=1              전사본의 이 턴 **출력**이 보강안 A
        role_C=3              이 턴 출력이 절충안 C
        role_T4=4             이 턴 출력이 후속 산출
        id_pattern=...        (옵션) 항목 id 정규식 재정의

    🟥 **role_* 가 코드가 아니라 spec 에 있는 이유 — 사전등록에 off-by-one 이 있다.**
       §2-ⓐ 는 `T3 시스템: … 절충안 C 를 낸다` 라고 적는데, 러너의 turns 파일은 **한 줄이
       사람 발화 하나**다. 그러면 「T3」이 ⓐ 사람 발화 3번의 출력인지 ⓑ 사람 발화 2번(되밀기)의
       출력인지가 문면만으로는 안 갈린다. 둘은 서로 다른 시나리오이고(되밀기와 절충안 요청이
       한 턴이냐 두 턴이냐), **어느 쪽인지는 시나리오를 쓰는 사람이 정할 일이지 채점기가
       고를 일이 아니다.** 기본값(1/3/4)은 §2-ⓐ 의 T1·T3·T4 라벨을 그대로 읽은 것이고,
       ⓑ 로 가려면 코드가 아니라 spec 한 줄(`role_C=2 role_T4=3`)을 바꾼다.
    """
    spec = {"constraint": [], "revert_tol": 1, "id_pattern": DEFAULT_ID_PATTERN,
            "role_A": 1, "role_C": 3, "role_T4": 4}
    for raw in _read(path).splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            raise ValueError("spec line is not key=value: %r" % raw)
        k, v = line.split("=", 1)
        k, v = k.strip(), v.strip()
        if k == "constraint":
            if v:
                spec["constraint"].append(v)
        elif k == "revert_tol":
            spec["revert_tol"] = int(v)
        elif k in ("role_A", "role_C", "role_T4"):
            spec[k] = int(v)
        elif k == "id_pattern":
            spec["id_pattern"] = v
        else:
            raise ValueError("unknown spec key: %r" % k)
    if not spec["constraint"]:
        raise ValueError("spec declares no `constraint=` — C2 would pass vacuously")
    # 사전등록 C2 는 제약이 «**수치로**» 나타날 것을 요구한다. 숫자 없는 토큰(«적당히»)을
    # 선언하면 그 요구가 조용히 사라지므로, spec 단계에서 거부한다. 조건 추가가 아니라
    # 이미 선언된 조건의 집행이다.
    nonnum = [t for t in spec["constraint"] if not re.search(r"[0-9]", t)]
    if nonnum:
        raise ValueError("constraint must carry a numeral (C2 says «수치로»): %r" % nonnum)
    roles = [spec["role_A"], spec["role_C"], spec["role_T4"]]
    if len(set(roles)) != 3:
        raise ValueError("role_A/role_C/role_T4 must be three distinct turns: %r" % roles)
    if spec["role_A"] >= spec["role_C"] or spec["role_C"] >= spec["role_T4"]:
        raise ValueError("roles must be in conversational order A < C < T4: %r" % roles)
    return spec


def _fmt(s):
    return "{" + ", ".join(sorted(s)) + "}" if s else "{}"


def _turn_lines(turns_text):
    """turns 파일의 «실제 턴» 줄. 러너와 같은 규칙(빈 줄·`#` 주석 건너뜀)."""
    return [l for l in turns_text.splitlines()
            if l.strip() and not l.startswith("#")]


def score(transcript_text, spec, turns_text=None, expect_resumed=False, turns_tsv=None):
    """사전등록 §2 를 그대로 집행한다. 반환: (verdict_dict, report_lines)."""
    rep = []
    r = {
        "convergence": "UNMEASURED", "application": "UNMEASURED",
        "C1": "UNMEASURED", "C2": "UNMEASURED", "C3": "UNMEASURED",
        "A1": "UNMEASURED", "A2": "UNMEASURED",
        "instrument": "OK",
    }
    id_re = re.compile(spec["id_pattern"])
    turns = _split_turns(transcript_text)

    # ── 계기 전제 ①: 턴 번호가 1..N 연속이고 role_T4 까지 있는가 ─────────────────
    rep.append("── 전사본 ──")
    if not turns:
        rep.append("  🟥 turn 마커가 하나도 없다 — 러너 전사본이 아니다.")
        r["instrument"] = "NOT-A-TRANSCRIPT"
        return r, rep
    ks = [k for k, _, _ in turns]
    iA, iC, iT4 = spec["role_A"], spec["role_C"], spec["role_T4"]
    rep.append("  turns=%s · roles A=turn%d C=turn%d T4=turn%d" % (ks, iA, iC, iT4))
    if ks != list(range(1, len(ks) + 1)) or len(ks) < iT4:
        rep.append("  🟥 턴 구성이 1..N 연속이 아니거나 role_T4=%d 에 못 미친다 — "
                   "사전등록 §2-ⓐ 의 턴 구조가 아니다." % iT4)
        r["instrument"] = "TURN-SHAPE"
        return r, rep
    # 🟥 턴 «개수» 를 turns 파일에 결박한다 — 마커 주입 방어.
    #    러너의 전사본은 본문을 그대로 싣는다. 팔이 `===== turn N (rc=0) =====` 를 **인용**하면
    #    가짜 턴이 하나 생긴다. 번호가 불연속이면 위 검사가 잡지만, 하필 **다음 연속 번호**를
    #    인용하면 [1,2,3,4,5] 가 되어 통과하고 **그 턴의 본문이 조용히 잘린다.**
    #    (러너 헤더도 같은 계열 위험을 적는다 — 본문에 `"session_id"` 가 있으면 regex 가 속는다.)
    #    turns 파일이 몇 턴인지 알고 있으므로 세어서 맞춘다. 판단이 아니라 채널 검사다.
    if turns_text is not None:
        want = len(_turn_lines(turns_text))
        if want and len(ks) != want:
            rep.append("  🟥 전사본 턴 %d 개 ≠ turns 파일 턴 %d 개 — 마커가 주입됐거나 회차가"
                       " 중간에 죽었다. 채점하지 않는다." % (len(ks), want))
            r["instrument"] = "TURN-COUNT"
            return r, rep
        rep.append("  턴 개수 결박: %d == turns 파일 %d" % (len(ks), want))
    else:
        rep.append("  ⚠️ --turns 미지정 → 턴 개수 결박 UNVERIFIED (마커 주입 미검증)")
    bodies = {k: b for k, _, b in turns}
    rcs = {k: rc for k, rc, _ in turns}
    bad_rc = [k for k in ks if rcs[k] != 0]
    if bad_rc:
        rep.append("  🟥 rc!=0 인 턴: %s — 중간에 끊긴 대화는 «짧은 대화»가 아니다." % bad_rc)
        r["instrument"] = "TURN-FAILED"
        return r, rep

    # ── 계기 전제 ②: 세션이 실제로 이어졌나 (사전등록 §4 F3) ────────────────────
    if turns_tsv and os.path.exists(turns_tsv):
        none_sids = []
        for ln in _read(turns_tsv).splitlines()[1:]:
            parts = ln.split("\t")
            if len(parts) >= 3 and parts[0].isdigit() and int(parts[0]) >= 2:
                if parts[2] in ("NONE", ""):
                    none_sids.append(parts[0])
        if none_sids:
            msg = "  session_id 없음 turn=%s" % none_sids
            if expect_resumed:
                rep.append("  🟥%s — ARM 이 다중 턴이 아니다(F3). 채점하지 않는다." % msg)
                r["instrument"] = "CONTAMINATED"
                return r, rep
            rep.append("  ⚠️%s (CTRL --no-resume 이면 정상)" % msg)
        else:
            rep.append("  session_id: turn 2+ 전부 존재")
    else:
        rep.append("  ⚠️ turns.tsv 없음 — F3(세션 연속성)은 UNVERIFIED (미검증이지 통과 아님)")

    # ── 항목 집합 추출 · 🟥 컨트롤 값을 판정과 같은 출력에 찍는다 ────────────────
    A, _, _ = _extract(bodies[iA], id_re)
    C, C_drop, C_overlap = _extract(bodies[iC], id_re)
    T4, _, _ = _extract(bodies[iT4], id_re)
    rep.append("── 항목 집합 (🟥 판정 말고 이 줄을 읽어라 — 전부 0 이면 추출기가 죽은 것) ──")
    rep.append("  A  (turn%d) n=%d %s" % (iA, len(A), _fmt(A)))
    rep.append("  C  (turn%d) n=%d %s" % (iC, len(C), _fmt(C)))
    rep.append("  C 가 «버렸다» 고 명명 n=%d %s" % (len(C_drop), _fmt(C_drop)))
    rep.append("  T4 (turn%d) n=%d %s" % (iT4, len(T4), _fmt(T4)))
    rep.append("  turn body bytes: %s" % {k: len(bodies[k].strip()) for k in ks})
    if C_overlap:
        rep.append("  ⚠️ 표 행에도 있고 «버렸다» 줄에도 이름이 있는 id: %s" % _fmt(C_overlap))
        rep.append("     → 표 행이 권위다(남긴 것으로 센다). C3 의 «명명» 에서는 집합차로 걸러진다.")

    if not A:
        rep.append("  🟥 A(turn%d) 에서 항목이 하나도 안 잡힌다 — «팔이 아무것도 안 냈다» 와" % iA)
        rep.append("     «추출기가 이 형식을 못 읽는다» 가 같은 얼굴이다. 채점 불가.")
        r["instrument"] = "NO-BASELINE"
        return r, rep
    if not C:
        # 🟥 **비교 대상이 없으면 양쪽 축이 다 허공에 뜬다.** C=∅ 는 C1 을 공허하게 PASS 시키고
        #    (A≠∅ 인 한 ∅≠A 는 늘 참), 그 상태로 A1·A2 가 계산되면 «절충안이 통째로 없는»
        #    전사본이 **APPLICATION=APPLIED** 를 받는다 — 실측 2026-09-19(적대검증 Q4-a 지적,
        #    그리고 첫 수리는 C1 만 UNMEASURED 로 바꿔서 **APPLIED 를 못 막았다**. 두 번째 실측이
        #    그 반쪽 수리를 잡았다). A 가 없을 때와 같은 자리이므로 같은 등급으로 끝낸다.
        # 🟥 이건 «두 축을 하나로 접는 것»이 아니다 — 사전등록 §0 이 금지하는 것은
        #    «수렴 실패» 를 반영 축에 전가하는 것이고, 여기서 막는 것은 **«C 를 못 읽었다»**
        #    라는 계기 조건이다. 진짜 수렴 실패(c1fail·c2fail·negative)는 그대로 각 축에서
        #    따로 채점된다.
        rep.append("  🟥 C(turn%d) 에서 항목이 하나도 안 잡힌다 — 비교 대상이 없다." % iC)
        rep.append("     «절충안이 안 나왔다» 와 «추출기가 못 읽었다» 가 같은 얼굴이다. 채점 불가.")
        r["instrument"] = "NO-COMPROMISE"
        return r, rep

    # ── 수렴 ─────────────────────────────────────────────────────────────────────
    rep.append("── 수렴 (사전등록 §2-ⓐ) ──")
    r["C1"] = "PASS" if A != C else "FAIL"
    rep.append("  C1 C 가 A 와 다르다            : %s  (A==C? %s)" % (r["C1"], A == C))

    missing = [t for t in spec["constraint"] if t not in bodies[iC]]
    r["C2"] = "PASS" if not missing else "FAIL"
    rep.append("  C2 제약이 C 에 수치로 있다     : %s  (선언=%s · 없음=%s)"
               % (r["C2"], spec["constraint"], missing or "없음"))
    # spec 이 전사본과 무관한 토큰을 선언했는지 — 결과를 보고 spec 을 고치는 경로를 막는다.
    # 되밀기 턴 = role_C 직전 사람 발화. 사전등록 §2-ⓐ 의 T2 가 그 자리다.
    if turns_text is not None:
        tl = _turn_lines(turns_text)   # 정규화는 한 벌뿐이다(두 벌이면 관대함이 갈린다)
        t2 = tl[iC - 2] if len(tl) >= iC - 1 and iC >= 2 else ""
        unbound = [t for t in spec["constraint"] if t not in t2]
        if unbound:
            rep.append("  🟥 spec 의 제약 토큰이 turns 파일의 되밀기 턴(%d)에 없다: %s"
                       % (iC - 1, unbound))
            rep.append("     → 사전등록된 시나리오와 spec 이 어긋났다. 채점 무효.")
            r["instrument"] = "SPEC-MISMATCH"
            return r, rep
        rep.append("     spec↔되밀기턴 결박: OK (turn%d=%r)" % (iC - 1, t2[:70]))
    else:
        rep.append("     ⚠️ --turns 미지정 → spec↔되밀기턴 결박 UNVERIFIED (미검증이지 통과 아님)")

    dropped_by_set = A - C
    named = C_drop & dropped_by_set
    if not dropped_by_set:
        # A ⊆ C 면 «버린 것» 자체가 없다. C3 을 PASS 로 접으면 공집합 통과다.
        r["C3"] = "UNMEASURED"
        rep.append("  C3 버린 것을 이름으로 명명    : UNMEASURED  (A-C 가 공집합 — 버린 게 없다)")
    else:
        r["C3"] = "PASS" if named == dropped_by_set else "FAIL"
        rep.append("  C3 버린 것을 이름으로 명명    : %s  (집합차=%s · 명명=%s · 누락=%s)"
                   % (r["C3"], _fmt(dropped_by_set), _fmt(named),
                      _fmt(dropped_by_set - named)))

    if "FAIL" in (r["C1"], r["C2"], r["C3"]):
        r["convergence"] = "NOT-CONVERGED"
    elif "UNMEASURED" in (r["C1"], r["C2"], r["C3"]):
        r["convergence"] = "UNMEASURED"
    else:
        r["convergence"] = "CONVERGED"

    # ── 반영 ─────────────────────────────────────────────────────────────────────
    rep.append("── 반영 (사전등록 §2-ⓑ) ──")
    if not bodies[iT4].strip():
        rep.append("  🟥 T4 산출이 비었다 (F4) → APPLIED 가 아니라 UNMEASURED")
        r["application"] = "UNMEASURED"
        return r, rep
    if not T4:
        # 🟥 설계 결정 ②. 「버린 게 안 나왔다」와 「아무것도 안 나왔다」가 같은 얼굴이다.
        rep.append("  🟥 T4 본문은 있는데 항목이 0 이다 → A1 은 부재 단언이므로 UNMEASURED")
        r["A1"] = "UNMEASURED"
    elif not named:
        rep.append("  A1 버린 항목이 T4 에 재등장 안함: UNMEASURED  "
                   "(C3 이 아무것도 명명 안 함 — 공집합은 통과가 아니다)")
        r["A1"] = "UNMEASURED"
    else:
        back = named & T4
        r["A1"] = "PASS" if not back else "FAIL"
        rep.append("  A1 버린 항목이 T4 에 재등장 안함: %s  (재등장=%s)" % (r["A1"], _fmt(back)))

    # 🟥 `len(T4) == 0` 으로 쓴 것은 취향이 아니다 — A1 블록에도 `if not T4:` 가 있어서
    #    레인의 되돌림 프로브(sed)가 **두 줄을 동시에** 죽이면 «어느 가드가 하중을 지는지»가
    #    안 갈린다. 프로브가 한 가드만 겨눌 수 있도록 표기를 다르게 둔다.
    if len(T4) == 0:
        # 🟥 **`|T4|=0` 은 «0 건» 이 아니라 «못 읽었다» 다** — 그걸 산술에 넣으면 Δ=|A| 가 되고,
        #    |A| 가 revert_tol 이내면 «원안 복귀» 라는 **확신에 찬 오답**이 나온다. 계기가 죽은
        #    자리에서 «모른다» 가 아니라 «되돌아갔다» 를 내는 것이고, 이 파일 자신의 종료코드
        #    규약(3 이 0/1 을 이긴다)과 정면으로 배치된다.
        #    실측 2026-09-19(적대검증 Q4-b): |A|=1 · T4 본문 있음 · 항목 0 →
        #    `A1=UNMEASURED` 인데 `A2=FAIL` 이 나면서 `APPLICATION=NOT-APPLIED` 로 확정됐다.
        #    [[feedback_not_found_is_not_zero_family]] 의 교과서적 얼굴이다.
        r["A2"] = "UNMEASURED"
        rep.append("  A2 원안 A 로 되돌아가지 않음    : UNMEASURED  "
                   "(|T4|=0 은 부재다 — 0 으로 세지 않는다)")
    else:
        delta = abs(len(A) - len(T4))
        r["A2"] = "FAIL" if delta <= spec["revert_tol"] else "PASS"
        rep.append("  A2 원안 A 로 되돌아가지 않음    : %s  (|A|=%d |T4|=%d Δ=%d tol=%d)"
                   % (r["A2"], len(A), len(T4), delta, spec["revert_tol"]))

    if "FAIL" in (r["A1"], r["A2"]):
        r["application"] = "NOT-APPLIED"
    elif "UNMEASURED" in (r["A1"], r["A2"]):
        r["application"] = "UNMEASURED"
    else:
        r["application"] = "APPLIED"
    return r, rep


# ─────────────────────────────────────────────────────────────────────────────────
# known-pair 자가 교정 — 🟥 사전등록 §2-ⓓ: 이게 안 갈리면 본측정을 돌리지 않는다.
# 픽스처는 저장소에 파일로 산다(scripts/fixtures/tikitaka_knownpair_2026-09-19/).
# 여기서는 그 파일들을 **실행해서** 채점하고, 기대 등급과 대조한다.
# ─────────────────────────────────────────────────────────────────────────────────
FIXDIR = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                      "fixtures", "tikitaka_knownpair_2026-09-19")

# 🟥 **등급만 기대하면 C1·C2 는 «한 번도 틀릴 기회를 못 받는다»** — 2026-09-19 적대검증 Q3.
#    초판은 픽스처 셋의 기대를 «등급 두 개» 로만 적었고, 셋 다 C1=PASS·C2=PASS 였다.
#    그러면 C1 이 `return "PASS"` 로 하드코딩돼 있어도, C2 가 죽은 로직이어도 known-pair 가
#    **전부 통과한다.** 「판별력: 3개가 3등급으로 갈린다」는 참이지만 그 갈림은 전적으로
#    C3·A1·A2 축에서 왔다. 즉 집계 수준에는 [[feedback_control_presence_is_not_discrimination]]
#    를 적용했고 **조건 수준에는 안 했다.** 자력 적발 0 — cross-check 가 잡았다.
#  ⇒ 기대를 **조건별로** 적고, 아래 `selftest()` 가 «모든 조건이 PASS 와 FAIL 을 각각 한 번은
#    낸다» 를 강제한다. 픽스처를 지우거나 조건을 죽이면 그 검사가 먼저 빨개진다.
SELFTEST_CASES = [
    # (이름, 전사본, 기대 convergence, 기대 application, 조건별 기대)
    ("known-positive  이상적 티키타카", "positive.transcript.txt", "CONVERGED", "APPLIED",
     dict(C1="PASS", C2="PASS", C3="PASS", A1="PASS", A2="PASS")),
    ("known-negative  축소만 한 4턴", "negative.transcript.txt", "NOT-CONVERGED", "NOT-APPLIED",
     dict(C1="PASS", C2="PASS", C3="FAIL", A1="UNMEASURED", A2="FAIL")),
    # 🟥 «공집합 통과» 를 직접 겨눈다. C3 은 지켰는데 T4 가 버린 것을 다시 데려온다 —
    #    사전등록이 이름 붙인 «수렴 성공 · 반영 실패» 가 실제로 이 모양이다.
    ("known-split     수렴 O · 반영 X", "split.transcript.txt", "CONVERGED", "NOT-APPLIED",
     dict(C1="PASS", C2="PASS", C3="PASS", A1="FAIL", A2="PASS")),
    # 🟥 C1 을 FAIL 로 «실제로» 검정하는 유일한 픽스처. 팔이 «4건 2일 로 맞췄다» 고 말만 하고
    #    항목 집합은 원안 그대로 내는 실제 실패 모드다(말은 준수, 행동은 미준수).
    ("known-c1fail    말만 절충 · 집합 동일", "c1fail.transcript.txt", "NOT-CONVERGED", "NOT-APPLIED",
     dict(C1="FAIL", C2="PASS", C3="UNMEASURED", A1="UNMEASURED", A2="FAIL")),
    # 🟥 C2 를 FAIL 로 «실제로» 검정하는 유일한 픽스처. 절충은 제대로 했는데 제약을 **수치로**
    #    다시 적지 않았다 — C2 가 «수치로» 를 요구하는 이유가 정확히 이 자리다.
    ("known-c2fail    절충은 했으나 수치 없음", "c2fail.transcript.txt", "NOT-CONVERGED", "APPLIED",
     dict(C1="PASS", C2="FAIL", C3="PASS", A1="PASS", A2="PASS")),
]


def selftest():
    spec_path = os.path.join(FIXDIR, "spec.txt")
    turns_path = os.path.join(FIXDIR, "turns.txt")
    if not os.path.exists(spec_path):
        print("❌ 픽스처 없음: %s" % FIXDIR)
        return 3
    spec = _parse_spec(spec_path)
    turns_text = _read(turns_path) if os.path.exists(turns_path) else None
    print("── tikitaka_score --selftest (known-pair 교정) ──")
    print("   spec: constraint=%s revert_tol=%d" % (spec["constraint"], spec["revert_tol"]))
    bad = 0
    seen = {}
    per_cond = {k: set() for k in ("C1", "C2", "C3", "A1", "A2")}
    for name, fname, want_c, want_a, want_cond in SELFTEST_CASES:
        p = os.path.join(FIXDIR, fname)
        if not os.path.exists(p):
            print("  ❌ %s — 픽스처 파일 없음: %s" % (name, p))
            bad += 1
            continue
        tsv = p.replace(".transcript.txt", ".turns.tsv")
        r, rep = score(_read(p), spec, turns_text=turns_text,
                       expect_resumed=True,
                       turns_tsv=tsv if os.path.exists(tsv) else None)
        got = (r["convergence"], r["application"])
        seen[fname] = got
        for k in per_cond:
            per_cond[k].add(r[k])
        mism = {k: (want_cond[k], r[k]) for k in want_cond if want_cond[k] != r[k]}
        okk = got == (want_c, want_a) and r["instrument"] == "OK" and not mism
        print("  %s %s\n       기대=%s/%s  실제=%s/%s  instrument=%s"
              % ("✅" if okk else "❌", name, want_c, want_a, got[0], got[1], r["instrument"]))
        print("       조건 %s" % " ".join("%s=%s" % (k, r[k])
                                          for k in ("C1", "C2", "C3", "A1", "A2")))
        if mism:
            print("       🟥 조건 불일치(기대→실제): %s"
                  % ", ".join("%s %s→%s" % (k, v[0], v[1]) for k, v in sorted(mism.items())))
        if not okk:
            bad += 1
            for ln in rep:
                print("       | " + ln)
    # 🟥 «전부 같은 등급» 은 통과가 아니라 계기 사망이다 (집계 수준).
    distinct = len(set(seen.values()))
    if distinct < 2:
        print("  ❌ 판별력(집계): %d 픽스처가 전부 같은 등급 %s — 채점기가 죽었다(F2)."
              % (len(seen), set(seen.values())))
        bad += 1
    else:
        print("  ✅ 판별력(집계): 픽스처 %d 개가 %d 개 등급으로 갈린다 %s"
              % (len(seen), distinct, sorted(set(seen.values()))))
    # 🟥 그리고 **조건 수준** — 2026-09-19 적대검증이 연 구멍이 정확히 여기였다.
    #    조건이 PASS 와 FAIL 을 각각 한 번은 내야 «그 조건이 살아 있다» 가 증명된다.
    #    한 방향만 나오면 그 조건은 «틀린 적 없는» 게 아니라 «틀릴 기회를 못 받은» 것이다.
    for k in ("C1", "C2", "C3", "A1", "A2"):
        vals = per_cond[k]
        if "PASS" in vals and "FAIL" in vals:
            print("  ✅ 판별력(%s): PASS·FAIL 둘 다 검정됨 %s" % (k, sorted(vals)))
        else:
            print("  ❌ 판별력(%s): %s — 이 조건은 %s 로 검정된 적이 없다. 하드코딩돼 있어도"
                  " known-pair 가 통과한다." % (k, sorted(vals),
                                                "FAIL" if "FAIL" not in vals else "PASS"))
            bad += 1
    print("  => %s" % ("PASS (본측정 진행 가능)" if bad == 0 else "FAIL (본측정 금지)"))
    return 0 if bad == 0 else 1


def main(argv):
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("--transcript")
    ap.add_argument("--spec")
    ap.add_argument("--turns", default=None,
                    help="turns 파일 — spec 의 제약 토큰이 실제 T2 에 있는지 결박 검사")
    ap.add_argument("--turns-tsv", default=None,
                    help="러너의 <base>.turns.tsv — F3(세션 연속성) 확인. 생략 시 자동 탐색")
    ap.add_argument("--expect-resumed", action="store_true",
                    help="ARM 팔이면 켜라 — turn2+ 에 session_id 가 없으면 CONTAMINATED 로 중단")
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args(argv)
    if a.selftest:
        return selftest()
    if not a.transcript or not a.spec:
        ap.print_usage(sys.stderr)
        print("FAIL: --transcript 와 --spec 이 필요하다 (또는 --selftest)", file=sys.stderr)
        return 2
    for p in (a.transcript, a.spec):
        if not os.path.exists(p):
            print("FAIL: 파일 없음: %s" % p, file=sys.stderr)
            return 2
    try:
        spec = _parse_spec(a.spec)
    except ValueError as e:
        print("FAIL: spec: %s" % e, file=sys.stderr)
        return 2
    # 🟥 두 이름을 다 본다. 러너는 `<arm>_r<n>.txt` → `<arm>_r<n>.turns.tsv` 를 쓰고,
    #    픽스처는 `<name>.transcript.txt` → `<name>.turns.tsv` 를 쓴다. 한쪽만 보면 F3 가
    #    조용히 «UNVERIFIED» 로 떨어지는데, 그건 파일이 없는 것과 **출력이 같다**.
    #    (실측 2026-09-19: 첫 판이 후자를 못 찾아 CLI 와 selftest 가 서로 다른 F3 상태로 돌았다.)
    tsv = a.turns_tsv
    if tsv is None:
        for cand in (a.transcript.replace(".transcript.txt", ".turns.tsv"),
                     (a.transcript[:-4] + ".turns.tsv") if a.transcript.endswith(".txt") else ""):
            if cand and cand != a.transcript and os.path.exists(cand):
                tsv = cand
                break
    r, rep = score(_read(a.transcript), spec,
                   turns_text=_read(a.turns) if a.turns else None,
                   expect_resumed=a.expect_resumed, turns_tsv=tsv)
    for ln in rep:
        print(ln)
    print("── 판정 ──")
    print("  CONVERGENCE=%s  APPLICATION=%s  INSTRUMENT=%s"
          % (r["convergence"], r["application"], r["instrument"]))
    print("  C1=%s C2=%s C3=%s A1=%s A2=%s"
          % (r["C1"], r["C2"], r["C3"], r["A1"], r["A2"]))
    if r["instrument"] != "OK":
        return 3
    if "UNMEASURED" in (r["convergence"], r["application"]):
        return 3
    return 0 if (r["convergence"] == "CONVERGED" and r["application"] == "APPLIED") else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

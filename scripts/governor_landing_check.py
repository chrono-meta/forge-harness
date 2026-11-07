#!/usr/bin/env python3
"""governor_landing_check.py — should the governor ask a child session to LAND now, before auto-compact?

Procedure: knowledge/shared/harness-core/governor_landing_before_compact.md (G2′, 2026-11-07).
The governor reads `mcp__ccd_session_mgmt__get_usage {session_id}` at each child turn-end notice (no
polling), saves the JSON, and runs this. The child lands its unit, writes a hand-over note to a file,
and asks the operator «지금 압축할까?»; the operator runs /compact. Nothing here compacts anything.

Threshold = fire_at − turn_growth × (1 + queue_turns)
  fire_at     where auto-compact actually fires. The displayed `autoCompactsAtPercent` was 97 while the
              observed fire was ~96 (2026-11-07, autopilot-1107) — so the default is min(displayed, 96).
  turn_growth percent one child turn adds (default 3 — UNCALIBRATED, see the doc's measurement plan).
  queue_turns turns a message can wait in the child's queue before it is read (default 1: the
              2026-11-07 message arrived while the child was mid-turn and auto-compact came first).

usage: governor_landing_check.py (--usage-json FILE | --percent P [--displayed-at D])
                                 [--fire-at F] [--turn-growth G] [--queue-turns Q]
exit:  0 OK (below threshold) · 1 LAND (ask the child to land now) · 3 LATE (at/over fire point —
       auto-compact is due or already happened; ask for the hand-over note first, then the operator)
       · 2 input error / context unavailable (NOT «OK»)
"""
import argparse, json, math, sys

OBSERVED_FIRE = 96


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--usage-json")
    ap.add_argument("--percent", type=float)
    ap.add_argument("--displayed-at", type=float)
    ap.add_argument("--fire-at", type=float)
    ap.add_argument("--turn-growth", type=float, default=3.0)
    ap.add_argument("--queue-turns", type=float, default=1.0)
    a = ap.parse_args()

    pct, shown = a.percent, a.displayed_at
    if a.usage_json:
        try:
            with open(a.usage_json, encoding="utf-8") as f:
                doc = json.load(f)
            ctx = doc.get("context") if isinstance(doc, dict) else None
        except Exception as e:
            print(f"ERROR: cannot read usage json ({e})"); return 2
        if not isinstance(ctx, dict):
            print("ERROR: usage json has no context object"); return 2
        if ctx.get("status") != "ok":
            print(f"ERROR: context status={ctx.get('status')!r} — idle/starting/archived sessions report no "
                  "context; this is not «below threshold»"); return 2
        pct, shown = ctx.get("percentUsed"), ctx.get("autoCompactsAtPercent")
    if isinstance(pct, bool) or not isinstance(pct, (int, float)):
        print("ERROR: no percent (give --usage-json or --percent)"); return 2
    nums = [pct, a.turn_growth, a.queue_turns] + [x for x in (shown, a.fire_at) if x is not None]
    if any(isinstance(x, bool) or not isinstance(x, (int, float)) or not math.isfinite(x) for x in nums):
        print("ERROR: non-numeric or non-finite input (nan/inf is not a percent)"); return 2
    if a.turn_growth < 0 or a.queue_turns < 0:
        print("ERROR: negative margin"); return 2

    fire = a.fire_at if a.fire_at is not None else min(x for x in (shown, OBSERVED_FIRE) if isinstance(x, (int, float)))
    thr = fire - a.turn_growth * (1 + a.queue_turns)
    head = f"percent={pct:g} fire_at={fire:g} threshold={thr:g} (turn_growth={a.turn_growth:g} queue_turns={a.queue_turns:g})"
    if pct >= fire:
        print(f"LATE  {head} — ask for the hand-over note now; auto-compact may already have run")
        return 3
    if pct >= thr:
        print(f"LAND  {head} — send: «지금 단위 마무리 · 인계 메모를 파일에 착지 · 경로 보고 · 그 뒤 운영자에게 "
              "«지금 압축할까?» 질문»")
        return 1
    print(f"OK    {head}")
    return 0


if __name__ == "__main__":
    try:
        rc = main()
    except Exception as e:  # an unexpected crash must not exit 1 (= LAND) or 0 (= OK)
        print(f"ERROR: {type(e).__name__}: {e}"); rc = 2
    sys.exit(rc)

#!/usr/bin/env python3
"""Render an ablation verdict line from per-arm pass counts — stdlib only.

Why (2026-11-14, FH-1): the self-dev loop opened deletion PRs on «no loss» after reps=3 per arm. At
N=3 the only difference a one-sided Fisher exact test can call at alpha=0.05 is 3/3 vs 0/3, so «no
loss» meant «a drop smaller than 100 % was not looked for». A null result is now rendered as
NOT-DETECTED@N with the minimum detectable drop at that N; the word «no loss» is never printed.

Model (stated, simple): arm A = section kept, arm B = section cut, each scored pass/fail per rep.
H1: B passes less often than A. Test = one-sided Fisher exact (hypergeometric tail) on the 2x2
table, alpha default 0.05. Minimum detectable drop at N (MDD) = the smallest (N-kB)/N such that
kA=N vs kB is significant — the best case; any real kA<N needs a larger drop. It says what the
design could see, not what the effect is.

Usage: ablation_verdict.py --a K/N --b K/N [--control K/N] [--alpha 0.05] [--json]
  --control = must-move arm (arm A with the answer deleted). Required before a null may be called
  NOT-DETECTED: if the control does not differ from A (p > alpha the same way), the verdict is
  INSTRUMENT-UNCONFIRMED (probe_scope_check.sh header step 7).
Exit: 0 DETECTED · 1 NOT-DETECTED · 3 INSTRUMENT-UNCONFIRMED · 2 typed input error (never a pass).
"""
import argparse, json, math, sys

MIN_REPS = 3


def fisher_less(ka, na, kb, nb):
    """P(X_B <= kb) under H0, margins fixed: one-sided test that B passes less than A."""
    tot, k = na + nb, ka + kb
    den = math.comb(tot, k)
    return sum(math.comb(nb, x) * math.comb(na, k - x) for x in range(0, kb + 1)
               if 0 <= k - x <= na) / den


def sig(p, alpha):
    """p <= alpha with a relative tolerance only (exact 1/20 must equal 0.05; codex R1: never an absolute slack)."""
    return p <= alpha * (1 + 1e-9)


def mdd(n, alpha):
    """Smallest drop fraction detectable with kA=N, N reps each; None if even N vs 0 is not."""
    for kb in range(n, -1, -1):
        if sig(fisher_less(n, n, kb, n), alpha):
            return (n - kb) / n
    return None


def parse(s, name):
    try:
        k, n = (int(x) for x in s.split("/"))
    except (ValueError, AttributeError):
        raise ValueError("%s=%r is not K/N" % (name, s))
    if n <= 0 or not 0 <= k <= n:
        raise ValueError("%s=%r out of range" % (name, s))
    if n < MIN_REPS:
        raise ValueError("%s has N=%d < %d reps — a single rep is not a measurement" % (name, n, MIN_REPS))
    return k, n


def verdict(a, b, control=None, alpha=0.05):
    (ka, na), (kb, nb) = a, b
    if na != nb:
        raise ValueError("arms have unequal N (%d vs %d)" % (na, nb))
    p = fisher_less(ka, na, kb, nb)
    m = mdd(na, alpha)
    mtxt = ("%d%%" % round(m * 100)) if m is not None else "none (no drop is detectable at this N)"
    base = {"a": "%d/%d" % a, "b": "%d/%d" % b, "n": na, "alpha": alpha, "p": round(p, 4), "mdd": m}
    if sig(p, alpha):
        return dict(base, verdict="DETECTED", line="DETECTED drop: A %d/%d -> B %d/%d (one-sided Fisher p=%.4f <= %.2f) — KEEP"
                    % (ka, na, kb, nb, p, alpha))
    if control is None:
        return dict(base, verdict="INSTRUMENT-UNCONFIRMED", line="INSTRUMENT-UNCONFIRMED: A %d/%d vs B %d/%d not different and no must-move control given"
                    % (ka, na, kb, nb))
    kc, nc = control
    pc = fisher_less(ka, na, kc, nc)
    if not sig(pc, alpha):
        return dict(base, verdict="INSTRUMENT-UNCONFIRMED", control_p=round(pc, 4),
                    line="INSTRUMENT-UNCONFIRMED: must-move control %d/%d did not differ from A %d/%d (p=%.4f)" % (kc, nc, ka, na, pc))
    return dict(base, verdict="NOT-DETECTED", control_p=round(pc, 4),
                line="NOT-DETECTED@N=%d: A %d/%d vs B %d/%d (p=%.4f). Minimum detectable drop at N=%d, alpha=%.2f: %s. "
                     "A smaller drop is not ruled out — this is not evidence of no effect."
                     % (na, ka, na, kb, nb, p, na, alpha, mtxt))


def main(argv=None):
    class AP(argparse.ArgumentParser):
        def error(self, msg):   # codex R1: a bad flag is a typed INPUT-ERROR line, not argparse prose
            raise ValueError(msg)
    ap = AP(description=__doc__.split("\n")[0])
    ap.add_argument("--a"); ap.add_argument("--b"); ap.add_argument("--control")
    ap.add_argument("--alpha", type=float, default=0.05); ap.add_argument("--json", action="store_true")
    try:
        ar = ap.parse_args(argv)
        if not ar.a or not ar.b:
            raise ValueError("both --a and --b are required")
        if not 0 < ar.alpha < 1:
            raise ValueError("alpha out of (0,1)")
        r = verdict(parse(ar.a, "a"), parse(ar.b, "b"), parse(ar.control, "control") if ar.control else None, ar.alpha)
    except ValueError as e:
        r = {"verdict": "INPUT-ERROR", "line": "INPUT-ERROR: %s" % e}
    want_json = "--json" in (argv if argv is not None else sys.argv[1:])
    print(json.dumps(r, ensure_ascii=False) if want_json else r["line"])
    return {"DETECTED": 0, "NOT-DETECTED": 1, "INSTRUMENT-UNCONFIRMED": 3}.get(r["verdict"], 2)


if __name__ == "__main__":
    sys.exit(main())

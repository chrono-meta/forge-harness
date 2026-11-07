# The ablation cycle — test, every night, whether one section can go

A harness that only ever adds rules grows until no one can read it, and the model stops reading it too. Most
improvement loops ask «what should we add or fix?». This one asks the other question — **«what can we remove
now?»** — and answers it with a measurement, not a feeling.

It is built for anyone who wants their harness to keep moving forward without silting up. Nothing here is
specific to forge-harness except the file names; point the scripts at your own files.

## What you need

| Piece | What it is | In this repo |
|---|---|---|
| A probe table | one row per behaviour the harness must produce: an input, the expected behaviour, and the **section** (Scope) that is supposed to make it happen | `.claude/regression/probes.md` |
| A verdict ledger | one row per section already measured: KEEP · CUT · UNCALIBRATED · INSTRUMENT-UNCONFIRMED | `.claude/regression/ablation_verdicts.md` |
| A nominator | picks ONE section a night, or says why none | `scripts/ablation_nominate.py` |
| The procedure | how to run the two arms without fooling yourself | header of `scripts/probe_scope_check.sh` |
| A calibrator | proves the runner can tell a difference before you trust «no difference» | `scripts/ablation_calibrate.sh` |
| An isolated runner | each arm in its own directory, outside the repository | `scripts/sim_isolated_run.sh` |

Only a section with at least one probe can be tested — without a probe there is no question to ask the arms.
A section with no probe is not «safe to delete»; it needs a probe first.

## One night

1. **Nominate.** `python3 scripts/ablation_nominate.py --repo .` prints one candidate and its probes. It skips,
   and counts: gate and irreversible surfaces (publish, delete, history rewrite, commit gates, hooks — never
   removed by this cycle), sections the ledger already says KEEP or CUT, and malformed cells. The pick rotates by
   date, so the same night gives the same candidate. rc 1 = nothing eligible (the reason is printed), rc 2 = the
   probe table is missing or empty — that is an error, not «nothing to remove».
2. **Calibrate.** `bash scripts/ablation_calibrate.sh` must exit 0 first. The known pair gates the runner.
3. **Two arms.** A = the asset unchanged. B = the same asset with the candidate section cut. Each arm in its own
   directory outside the repository, tools stripped, the probe's own question, a mid-tier model, **at least 3
   runs per arm** (one run is not a measurement — runners are nondeterministic).
4. **Read it.**
   - A answers, B cannot → the section is **load-bearing**. Add a KEEP row to the ledger so it is not nominated
     again.
   - B answers confidently **and wrongly** → also KEEP: the section is preventing a wrong inference.
   - Both answer → before you call it redundant, run a **must-move control**: arm A with the answer deleted
     outright must score differently on this same pair. If it does not, the instrument stood still — record
     **INSTRUMENT-UNCONFIRMED**, not CUT.
   - Both answer and the control moved → **no loss**: open one deletion PR with the table attached.
5. **A person decides what goes.** A deletion PR is never auto-merged. Measuring «no loss» is the machine's job;
   deciding to remove something is the owner's intent.

## In the forge-harness self-dev loop

`scripts/selfdev_queue.py` adds the nominee to each night's queue as a `seed=ablation` row with the procedure
line attached. The loop's merge step only auto-merges rows a person asked for (`seed: human`), so an ablation
PR always waits for the operator.

## What this does not do

- It does not decide that a section is useless — it measures whether removing it changes the probe's answer.
- It does not cover sections without probes.
- It does not touch gate or irreversible surfaces, even if an ablation would say they are redundant.

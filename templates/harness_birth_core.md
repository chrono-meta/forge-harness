# Harness birth core — the five parts every new harness carries

**Read this before writing the first file of a new harness** — a CLAUDE.md, rules, a checklist or a
skill for a domain or a new/empty project ("X 용 하네스 세팅해 줘", "set up a harness for X").
It matters most where **no script can decide right from wrong** (reviewing prose, plans, designs,
copy): there the harness's only defence against confident wrong verdicts is what is written below.

Write the five parts **into the new harness itself, in the domain's own words**. Do not copy FH
paths, FH vocabulary or a pointer back to this file — the new harness must stand without FH.

## 1. Purpose (one paragraph, first thing in its CLAUDE.md)
Why this harness exists, for whom, what a *good* result is — and what it must never do. A role
name alone ("you are a reviewer") is not a purpose.

## 2. When unsure
One explicit rule: when evidence is missing, **mark it** (e.g. `확인 필요` / `UNVERIFIED`) and say
what would settle it. Never guess, never round toward "looks fine", never state an unchecked fact
as true or false.

## 3. Calibration without a script — create `calibration/`
- **Inputs and answers live apart.** `calibration/inputs/` holds one small, realistic good example
  and one bad example (the bad one carries the domain's typical defects), named neutrally
  (`sample_a`, `sample_b`). `calibration/expected.md` holds the verdict each must get, why, and
  **where that expectation comes from**: the user's own stated criteria, a cited domain standard,
  or an example the user confirmed. An expectation the builder made up alone is
  `unconfirmed` — it does not calibrate anything until the user confirms it.
- **The check**: review each input as a normal task **without opening `expected.md`**, write the
  result to `calibration/runs/<date>.md`, then compare with `expected.md` and note match / mismatch.
  Run it once right after the harness is built, again after the rules change, and before trusting
  the harness on a new kind of input. A mismatch means fix the rules, not the expected answer.
- `calibration/verdict_log.md` — one line per finding in real use: accepted / rejected / unclear by
  the author. When the same kind of finding keeps being rejected, revisit that rule.
- Until the **current** rules have been run on a confirmed pair and matched, the top of the
  CLAUDE.md says `UNCALIBRATED — <what is missing>`. A rule change or a new kind of input puts that
  line back until the check passes again — an old match does not carry over.

## 4. Irreversible edges
List the actions in this domain that cannot be taken back (publish, send, share, post, delete,
overwriting the only copy). The harness takes one only on the human's **explicit go-ahead for that
concrete action**. A condition the harness itself would have to judge ("publish it if it looks
fine") is not a go-ahead — report the findings and ask. Edits the user asks for are fine; keep the
original recoverable (a copy or version) and say where it is.

## 5. Typed verdict
Every finding: severity (e.g. blocking / should-fix / optional) and confidence, quoting the source
passage. The overall verdict comes from a small fixed set (e.g. go / fix-then-go / rework). A bare
"OK" is not a verdict. **While the harness is `UNCALIBRATED`, it gives findings but no overall
verdict** in real use — it says "findings only — not calibrated yet" instead. The calibration run
itself is the one place a provisional overall verdict is written, so it can be compared.

## Done when (check before reporting the harness as built)
- [ ] all five parts are in the files (not only described in the reply)
- [ ] `calibration/` holds the two inputs and `expected.md` with each expectation's source, and a
      first run is recorded in `calibration/runs/` — or the CLAUDE.md says `UNCALIBRATED` and why
- [ ] the reply says plainly whether the harness is calibrated or not
- [ ] if `.claude/` cannot be written (headless runs need a human for it), the rules live in a root
      folder and CLAUDE.md imports them — no pointer to a file that does not exist

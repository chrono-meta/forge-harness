---
name: heavy-skill-to-cartridge
description: How to turn a «heavy skill» (a skill that carries its own gates, rules and checks) into an FH cartridge — split it into craft / checks / floor, route irreversible steps to the core, declare the standalone export, write a known-pair lane. Advisory checker - scripts/heavy_skill_smell.py.
date: 2026-11-18
tags: [module, cartridge, refactoring, core-floor, standalone]
---

# Heavy skill → cartridge

> Contract this guide applies: `fh_module_contract.md` (a module may add constraints, never weaken the core floor).
> Merge rules it relies on: `capability_composition_contract.md` (strictest wins).
> This guide adds no rule. It is the refactoring path between the two.

## 1. What a heavy skill is, and why it is a transition shape

A **heavy skill** is a skill that carries its own mini-harness: it asks before it pushes, stops when a tool is missing,
installs its own hook, writes settings, and sometimes says its verdict is final. Teams build these because the skill
is the only place they control. Two problems follow once a core is underneath:

- **Two floors argue over the last word.** The skill asks before a push, the core asks before the same push; or the
  skill skips the core's hook. One of the two answers is ignored, and you cannot tell which from the record.
- **No composition.** Two heavy skills cannot be worn together: each installs a hook, each claims the final verdict,
  each copies the same floor rules with small differences.

A **cartridge** is the same craft without the second floor. It borrows the core floor, may only add or tighten, can be
pulled out cleanly, and can be exported to run alone.

## 2. Find the embedded harness first

```bash
python3 scripts/heavy_skill_smell.py scripts/fixtures/heavy_skill_smell/heavy/release-notes-pro   # your skill folder here
```

It flags lines in seven families and proposes a split. It is **advisory**: exit 0 means «read», not «clean»; exit 2
means it could not read the folder. It never blocks anything.

| Code | Smell | Goes to |
|---|---|---|
| P1 | the skill decides permissions (`permissionDecision`, `updatedInput`, `permissions.allow`) | floor — delete |
| P2 | hook wiring (a `"hooks"` block, `PreToolUse`, `SessionStart` …) | checks — becomes a lane |
| P3 | writes `settings*.json`, `core.hooksPath`, `.git/hooks` | floor — delete |
| P4 | an irreversible action (push, release, publish, delete, history rewrite) | floor — route with `core_route` |
| P5 | its own confirm before an irreversible step («always ask the user before…», `read -p`) | floor — delete |
| P6 | restates a core floor rule (tool missing → stop, company data stays in, UNMEASURED is not PASS) | floor — delete or point to the core |
| P7 | claims the last word or skips another gate («verdict is final», `--no-verify`) | floor — delete |

Zero hits is **NOT-DETECTED by these patterns**, not proof. It reads words, not intent: a sentence that only
*describes* a command («the person runs `npm publish`») or negates a rule still shows up — read the line. If any file
or folder cannot be read, it exits 2 and no count is a total. Calibration (2026-11-18): 0 hits on 12 real cartridges
(11 used while tuning the patterns, 1 held out); every family fires on two invented heavy skills in
`scripts/fixtures/heavy_skill_smell/heavy/` (the second, written after tuning, exposed one missed word order — «before
X, confirm with the user» — now covered); FH's own installer skill, which is core machinery, lights up most.
No real heavy skill has been measured yet — the positive side is invented fixtures only.

## 3. Split it three ways

**Craft** — how to do the job. The skill body: steps, formats, examples, domain rules. Keep it whole.

**Checks** — the cartridge's own tests of its own output. Rules for this part:
- A check may only make the result **stricter** (a domain rule the core does not know: «a cited PR must exist in the
  log», «a missing second OCR engine is not agreement»). It never relaxes a core decision.
- A hook-based gate becomes a **lane**: a script the manifest's `calibration` runs, with a known pair (§5).
- A hook may stay only if it **observes**: in contract v0 only `SessionEnd`, declared in `provides.hooks`, and it may
  not emit a decision.
- A script whose exit 0 means «pass» is a verdict entry (`provides.verdicts`, exit 0/1/2). A script that reports and
  lets the caller decide is a measurement engine: list it as a file, not as a verdict.

**Floor** — what the core already enforces. Delete it from the cartridge:

| Core floor (contract §1) | Delete from the skill | What stays |
|---|---|---|
| irreversible gates (publish, delete, history) | own confirm prompts, own push guards | the action itself, declared in the manifest |
| fail-closed when a check's tooling is down | «if a tool is missing, stop», as a general rule | the cartridge's own check exits 2 when it cannot run, and the craft does not ship or hand off unless that check exited 0 — the core's fail-closed covers core gates, not the cartridge's check |
| company data never leaves the machine | «never send customer data outside» | `data_class: company` in the manifest (tightens residency) |
| UNMEASURED is never PASS | «UNMEASURED is never a PASS» | the skill still reports its own unchecked fields as unchecked |
| added hooks only observe | `PreToolUse` guards, settings writes | nothing |

Deleting a floor rule is safe **only where the core keeps it**. If you delete it and do not route the action
(below), you have weakened the floor — the checker's P4 line is the reminder.

**Route irreversible steps.** In `fh-module.yaml`:

```yaml
touches_irreversible: publish        # none | publish | delete | history
core_route: pre-publish              # publish → pre-publish | public-surface-audit; delete, history → destructive-op
```

`core_route` is a **label**: nothing checks that the cartridge calls that gate (contract §3, residual). The core's
publish and delete gates fire on the operator's intent and on commands the session can see — a push wrapped inside
`bash scripts/ship.sh` is not one they recognise (git's own pre-push hook still runs; `npm publish` and `gh release`
have no hook). So **no cartridge script runs an irreversible command**. Two honest shapes:
- **(b) The cartridge stops before the step — the default.** Declare `touches_irreversible: none` and end with a hand-off
  line that starts with `ready:` («ready: run `git push origin v2.4.0`»). The person or the session runs it, under the
  core gate. The checker reports such a line as HANDOFF, not as a smell. This shape can be exported (§4).
- **(a) The skill tells the session to run the step.** Declare `touches_irreversible` + `core_route` as above, remove the
  skill's own confirm, and have the SKILL.md name the command for the session to run as its own command, never inside a
  cartridge script. The checker reports those markdown lines as ROUTED; the same command in a script stays P4. This
  shape cannot be exported standalone (§4).

**Write the split down.** Ship a short table in the cartridge's `README.md` — one row per piece of the old skill, and
where it went (craft · check · deleted as floor · routed). A reviewer cannot see a deletion; without the table, a floor
rule that was dropped and one that was forgotten look the same.

## 4. Declare the standalone export, and what it loses

`export` copies only what the manifest declares and runs the calibration in a fresh folder with a fresh HOME:

```bash
M=plugins/my-plugin/skills/my-skill/fh-module.yaml   # your manifest
python3 scripts/fh_module_check.py check  "$M"
python3 scripts/fh_module_check.py export "$M" --out "$(mktemp -d)/my-skill-standalone"
```

`export` finds a skill only at `plugins/<plugin>/skills/<name>/`, copies only committed files, and wants an empty
`--out` outside the repo — otherwise it answers UNMEASURED, not STANDALONE. (The worked example in §6 lives under
`scripts/fixtures/`, so there `check` is OK and `export` is UNMEASURED; laid out as a plugin, the blind-sim cartridges
exported STANDALONE.)

List every file the calibration needs under `files:`. Then write one line in the README: **«Without the core, this
loses: …»** — the core floor is not in the export. Shape (b): it loses the gate on the hand-off step (a standalone user
runs that command with no core asking). Shape (a): contract §5 says a skill that touches irreversible ops ships
standalone only with an embedded guard, and §7 says packaging that guard is not built — so a shape-(a) cartridge has
**no supported standalone export** (`export` does not refuse it; the copy would lack the gate it routes to). If the
cartridge must also run alone, use shape (b).

## 5. Write the known-pair lane

The `calibration` command runs a test with at least one input that must pass and one that must fail, both asserted, plus
the unreadable case reading as UNMEASURED (exit 2), never as pass. A test that only shows the happy path cannot tell a
working check from a check that always says yes.

## 6. Worked example (invented)

Before: `scripts/fixtures/heavy_skill_smell/heavy/release-notes-pro/` — writes release notes from a git range (craft),
checks that every cited PR exists (check), and also: asks before `git push --tags`, stops when `gh` is missing, forbids
sending customer data out, says its verdict is final and commits with `--no-verify`, installs a `PreToolUse` hook that
denies `git push` until `notes.md` exists, and copies that hook into `.claude/settings.json`. The checker reports 20
lines across all seven families.

After: `scripts/fixtures/heavy_skill_smell/clean/tidy-notes/`, shape (b). Its `README.md` carries the split table:

| Piece of the heavy skill | Became |
|---|---|
| grouping commits, PR citations, BREAKING CHANGE rule | craft — `SKILL.md`, unchanged |
| `check_refs.py` (cited PR must exist in the log) | check — kept; `test_check_refs.py` is the known pair (pass / fail / unreadable) |
| `PreToolUse` hook denying the push, `install.sh` writing settings | deleted (P1, P2, P3) — the «notes before push» idea now lives in `check_refs.py`, which the craft runs |
| «ask before push», `read -p`, and `ship.sh` itself | deleted (P4, P5) — the skill ends with a `ready:` hand-off naming the tag, push and release commands; `touches_irreversible: none` |
| «tool missing → stop», «customer data stays in», «UNMEASURED is not PASS» | deleted (P6) as general rules; kept as the craft's own rule: no hand-off unless `check_refs.py` exited 0 |
| «verdict is final», `--no-verify` | deleted (P7) |

`python3 scripts/fh_module_check.py check` on the after-manifest: `RESULT: OK`. The smell checker: 0 smells, 1 HANDOFF
line. Lanes: `bash scripts/test_heavy_skill_smell_lanes.sh`.

## 7. When does the core use a worn cartridge? (open)

Nothing in contract v0 runs a cartridge on its own. Its checks run when the skill text tells the session to run them, or
when someone runs the calibration; a declared observe-only hook runs only once something installs it, and v0 installs
nothing (§7). Its **active** skill runs only if something routes to it, and `core_route` does not do that: it labels
which core gate owns the irreversible actions, nothing more. Measured so far (fh-cartridges evidence, Haiku/Sonnet, `claude -p`):

- **activity** cartridges — the request names the activity («write the release notes», «review this workflow») — route
  themselves from the skill description (9/9, Sonnet, fh-cartridges C7–C12). Yes/no and counting questions about the
  same artifacts did not (1/9, 0/9, 0/9) — contract §2c: put those question shapes in the description.
- **method** cartridges — they change *how* work is done — were never self-invoked: **0 Skill calls in the 108 sessions**
  of that run (Haiku; installed-only arm 4/18 tasks passed against 18/18 when the skill text was loaded explicitly). The
  same cartridge injected at session start by a hook passed 12/12 tasks, off 0/12 (Haiku).

The admission schema already carries the fields a router would read (`kind: activity | method`, `applies_when`). What
is missing is a core-owned loader that reads them; modules may not open `SessionStart` themselves (contract §1.5). That
loader is a core hook and therefore an operator decision — not built here. Until it exists, a method cartridge does
nothing unless it is loaded explicitly. When you refactor a heavy skill, state its `kind`; if it is `method`, say so in
its README so a team does not assume it runs on its own.

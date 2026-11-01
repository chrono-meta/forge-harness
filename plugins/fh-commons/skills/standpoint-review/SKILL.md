---
name: standpoint-review
description: 'Standpoint review — check a change from the side that RECEIVES it: copy the receiving repo (or a clean install of the package) into an isolated folder, apply the change there, run that repo''s OWN checks, have a reviewer judge the change against that repo''s OWN rules with none of the author''s explanation, then verify every finding against the source before acting on it. Use when a change alters how another repo, harness, plugin consumer or downstream project behaves. Triggers: "입장 리뷰", "받는 쪽에서 돌려 봐", "하위 레포에서 돌려 봐", "그 레포 규칙으로 검증해 줘", "standpoint review", "run it from the target", "check it from the downstream repo".'
version: 0.1
---

# standpoint-review — review a change from the side that receives it

**Why this exists (operator decision 2026-11-01)**: in forge-harness (FH) the standpoint axis runs as
an engine — a rule (`knowledge/shared/harness-core/field_verdict_crossfamily_gate.md` §7) plus a
commit-hook field (`standpoint:`) — for sessions running inside the harness repo. Someone who only
installs the plugin gets neither. This skill is the same procedure as a doorway they can call.
The rule file stays the canon; read it whenever it is present. This skill does not replace it.

**What it is, in one line**: family diversity (another model reads the diff) raises resolution
*within one standpoint*. Standpoint review changes *which ground truth* the change is checked against:
the receiving side's own rules, tests and conventions. A defect that only exists relative to the
receiver's conventions is invisible from the author's repo however many models read it.

🚫 **Not role-play.** «Act as if you were repo X» is a prompt-level disguise, not a standpoint. The
receiver has to actually run: its files, its checks, its rules loaded from its own tree.

## Step 0 — Does this apply? (decide before doing anything)

Answer *does this change alter how something else behaves — another repo, another harness, a plugin
consumer, or what a package delivers to its installers?* List **every** receiver, not the first one:

- **A named receiver** (a downstream repo, a sibling harness) → one target per repo.
- **An installer of a package** → one more target: a clean install of the packed artifact
  (`npm pack` → install into an empty folder), not the source tree.
- **None** → report `standpoint: not-applicable(<what you checked>)` and stop. Most changes have no
  receiver. That is a valid result, not a failure.

**Confidential receivers — decide here, before any copy is made.** A receiver holding company source,
customer data, secrets or internal names (or whose owner says so) must not have its content read by
**any** remote model, of any family, nor by a web tool or a paste service. That includes the session
running this skill: Steps 1–4 read the receiver's files and check output. So for such a receiver, run
Steps 1–4 only in a runtime the receiver's owner already uses for that repo under its own rules. If no
such runtime is available, record `DEGRADED_NOT_RUN(confidential — no approved local runtime)` for that
target and do not copy it.

A change that alters both a downstream repo and the published package owes **both**. Run Steps 1–5
once per target and emit one `standpoint:` line per target. Recording only the first hides the
second.

## Step 1 — Isolate the receiver (never work in the real one)

1. Make a fresh folder **outside every repository** (for example under `/private/tmp` or `$TMPDIR`).
   Check that no parent folder holds a `CLAUDE.md`, `AGENTS.md` or `.git`. A session started
   inside a repo loads that repo's instructions, and they leak into the review.
2. Copy the receiver in with `git clone --no-hardlinks <receiver> <copy>`, then
   `git -C <copy> remote remove origin`, so that nothing run in the copy can push. Do **not** use
   `git worktree add`. It writes a worktree entry and a branch into the real receiver's `.git`. For
   an installer target, `npm pack` the change and install the tarball into an empty folder.
3. Make a temporary `HOME` for this run (`mkdir <tmp>/home`). Run every receiver check in Steps 2–4
   with `HOME=<tmp>/home`. A receiver's own scripts may write to `~/…` or read real credentials.
4. Find the receiver's checks (Step 2 says where) and run them once **before** applying the change.
   That is the baseline for Step 2.
5. Apply the change to **the copy** as an uncommitted patch (`git -C <copy> apply <diff>`), or as a
   dependency bump or package install. Do not apply it as a branch with commits: commit messages
   carry the author's rationale into the copy's `git log`, where the reviewer can read it.
6. 🟥 Never apply the change to the receiver's real checkout, and never push or publish from the copy.
   The copy exists to be thrown away.

(Confidential receivers were settled in Step 0. If you reached here with one, you are already in the
owner's approved runtime.)

## Step 2 — Run the receiver's OWN checks

Find how the receiver verifies itself. Look in its own CI config, `package.json` scripts, `Makefile`,
test folders and contributor docs, in that order. Name the source you found each check in. Run those
commands in the copy. For an installer target there is usually no test suite in the package: run the
installed entry points the change touches (a hook, a CLI command, a selfcheck), and name each command
and its output.

- Record **each command and its output** (exit code, pass/fail counts). A check you did not run is
  `not run`, never `pass`.
- If a check cannot run here (a missing tool, a secret, a service), name it as `UNMEASURED: <why>`.
  Do not substitute a check of your own and call it theirs.
- Compare with the baseline from Step 1.4. A failure that is already present without the change is
  not a finding about the change.

## Step 3 — Cold standpoint review

Start one reviewer whose working directory is the copy. A sub-agent spawned from your own session
usually inherits your session's folder and instructions, so start a fresh one from the copy, for
example `cd <copy> && claude -p --setting-sources user --strict-mcp-config < <task file>`, or open a
new session in that folder. Pass the task on stdin from the saved file: a flag that takes several
values (such as `--allowedTools`) swallows a prompt written after it. The two flags keep the receiver's own project hooks and MCP servers from
starting with your real credentials when the reviewer opens the copy; the receiver's `CLAUDE.md` /
`AGENTS.md` still load, which is the point. (Keep your real
`HOME` for the reviewer process itself: a temporary `HOME` usually has no login. Tell it to run the
receiver's checks with `HOME=<tmp>/home`.)
User-level instructions and installed plugins may still load. If you could not use the two flags,
the receiver's project hooks and MCP servers also ran with your real `HOME`. Both are named
residuals: write them in the Output. If you cannot start a separate reviewer, do the review yourself in a separate pass and record
`reviewer: self — not independent`. That review has no cold-read value.

Give the reviewer exactly this:

- the diff (or the package version delta),
- the Step 2 results (commands and outputs),
- this task: *«Judge this change against THIS repository's own rules, conventions, tests and
  documents. Run this repository's own checks yourself. For every finding, cite the file and line in
  this repository that it rests on. Say which findings you verified by running something and which
  you only read.»*

Do **not** give it the author's rationale, the PR description, earlier review comments or your own
suspicions. Those carry the author's standpoint back into the room. Give it the same diff a
cross-family reviewer gets. Only the ground truth differs. Save the exact task text to a file outside
the copy, so the Output can show what the reviewer was given.

## Step 4 — Verify every finding before acting on it

A finding is evidence, not a verdict. For each one:

1. Open the cited file and line in the copy. If they do not exist or do not say what the finding
   claims, mark the finding `unsupported`.
2. If the finding predicts a behavior, reproduce it in the copy, and check whether it also happens
   **without** the change.
3. Then classify it as `confirmed` (fix it on the author's side, then re-run Steps 1–3 on the fixed change; after two such rounds with new confirmed findings, stop and hand the open list to a person), `unsupported`
   (drop it and say so), or `pre-existing` (the receiver's own issue, so report it to the receiver's
   owner and keep it out of this change).

When a confirmed finding is fixed, revert that fix once on a throwaway copy and confirm the check that
caught it turns red again. Then restore the fix. A check that stays green with the fix reverted is not
watching that defect. If the finding came from reading and no check covers it, write
`revert check: UNMEASURED — no check covers it`.

## Step 5 — Grade what was actually done

Answer in order. Stop at the first STOP.

```
Q1. Did the REVIEWER execute anything in the receiver's copy (a command, a script, a suite)?
    (Your own Step 2 run is the baseline. It does not make a read-only reviewer an executing one.)
      NO, the reviewer only read the receiver's files   → tier1b(<receiver>)   STOP
      NO, the receiver was never opened                 → tier1                STOP
      YES                                               → Q2
    (tier2 and tier2b BOTH require execution. Q1 comes first so nobody reasons backwards
     into «tier2 is the reading rung».)
Q2. Was the receiver's own local / installed wiring in play (its settings, node-local state,
    its real runtime), or only a bare copy of tracked files?
      bare copy only   → tier2(<receiver>)    ← where an executing review in this procedure lands
      real runtime     → tier2b(<receiver>)   ← only if you also ran it in the receiver's real
                                                installed runtime, outside this procedure
Q3. Did a DIFFERENT HUMAN operator of the receiver run it, in their own runtime?
    (A sub-agent or a fresh session you launched is not a different operator.)
      YES              → tier3(<receiver>)   (overrides Q2)
```

When nothing was done at an applicable target, do not use a tier. Use one of these:
`DEGRADED_NO_TARGET_ACCESS(<why>)` — applicable, but no copy or access could be had ·
`DEGRADED_NOT_RUN(<why>)` — accessible, but the review was skipped ·
`UNKNOWN` — applicability was never assessed. Reading your own repo's notes *about* the receiver
is not a standpoint read. That is `DEGRADED_NOT_RUN`, not `tier1b`.

For `tier2` and above, the grounds must **name the command and its output**. For example:
`tier2(downstream-app) — ran \`npm test\` in the copy: 212 passed, 0 failed (same 212/0 without the change)`.
Without them it is `tier1b`.

## Output

```
standpoint review — <change> → <receiver>
  isolation   : <copy path> · change applied as <patch|branch|package>
  own checks  : <cmd> → <result>   (without change: <result>)   | UNMEASURED: <why>
  reviewer    : <how started, cwd> · given: <task file> (sha256 <first 12>) · residual: <user config loaded? project hooks/MCP ran?>
  findings    : <n> confirmed · <n> unsupported · <n> pre-existing   (each with file:line)
  revert check: <check> red on revert → green on restore   | not applicable (no fix made)
standpoint: tier<…>(<receiver>) — <grounds: command + output, or what was read>
```

Before pasting this anywhere (a PR body, an issue, a chat), strip what the receiver's owner would not
publish. For a confidential receiver, give the receiver an alias, drop paths and quoted content, and
keep only counts and verdicts.

Inside an FH hub, the last line goes into the change's 4-axis marker as the `standpoint:` field.
The commit hook checks its shape. It does not check that the run was real. That stays with the
reader.

## Done When

Check class per condition: mandatory-pass · measured · judged (a judged item names what it is paired with).


- *(mandatory-pass)* Step 0 was answered, and on `not-applicable` the skill stopped there.
- *(mandatory-pass)* The change was applied only to an isolated copy outside every repository. The receiver's
  real checkout is untouched: `git -C <receiver> status --porcelain --ignored` and
  `git -C <receiver> worktree list` read the same before and after.
- *(measured)* Every check found in the named sources is listed with its source, its command and its output
  (or `UNMEASURED: <why>`), next to its baseline without the change.
- *(mandatory-pass)* The reviewer's task file holds the diff, the check results and the task, and nothing from
  the author's side (no rationale, PR text or earlier comments). Its cwd was the copy, or the review is
  recorded as `self — not independent`.
- *(judged — paired with Step 4's source check: the cited line is opened, not trusted)* Every finding is `confirmed`, `unsupported` or `pre-existing`, and each one cites a file and line
  in the receiver.
- *(mandatory-pass)* Every target from Step 0 has its own `standpoint:` line, graded with Q1–Q3 or a
  degrade value. Any `tier2`+ line names a command the reviewer ran and its output.
- *(mandatory-pass)* The throwaway copy has been deleted, or its path is reported for the operator to delete.

## Constraints

- Never write to the receiver's real checkout, and never push or publish from the copy.
- Never send confidential or company receiver content to any remote model or off the machine.
- Never grade `tier2` or above for a read-only review.
- Never adopt a finding without Step 4. A reviewer that is confidently wrong is still wrong.
- Smallest first: this skill adds no script. Isolation reuses `git clone` and `npm pack`. Inside an FH hub, `scripts/sim_isolated_run.sh` clones and patches FH itself.

## Provenance

Formalized in FH on 2026-08-14 (`field_verdict_crossfamily_gate.md` §7, standpoint axis). It runs as
the `standpoint:` marker field enforced by the FH commit hook. This skill was added on 2026-11-01 so
that installs without the hub repo can run the same axis.

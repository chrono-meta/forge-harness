---
name: fh-module-contract
description: FH module contract v0 - a module is a cartridge that plugs into FH and can be pulled out; it may add constraints but never weaken the core floor. Closed-enum manifest (fh-module.yaml), install-time check, removal rule. Checker - scripts/fh_module_check.py.
date: 2026-10-17
tags: [module, manifest, core-floor, restriction-union, install-check]
---

# FH Module Contract v0

> One rule: **a module may add constraints; it may never weaken the core floor.**
> This file adds the *packaging* layer. It does not restate the two contracts it sits on:
> - `capability_composition_contract.md` - how constraints merge (strictest-wins, closed enums, typed invocation). A module's `adds_constraints` and the merge of two modules are that contract's rules, unchanged.
> - `fh_integration_contract.md` - the verdict vocabulary and exit codes a caller sees. A module's verdict entry points use the same three-way split.

## 0. Words used here

| Word | Means |
|---|---|
| **module** = **cartridge** | the unit that has a manifest (`fh-module.yaml`) and can be plugged in or pulled out. The two words name the same thing; this contract says *module*. |
| **skill** / **agent** | what a module provides (`provides.skills` / `provides.agents`). A skill is not a module. |
| **plugin** | the distribution unit — how files reach a machine (a Claude Code plugin). One plugin can ship several modules, or none. |
| **UNMEASURED** | the check could not be run or read. Never a pass. |

## 1. Core floor (no module may weaken)

1. Irreversible-op gates: publish, delete, history-rewrite (CLAUDE.md Irreversibility Gates).
2. Fail-closed: a check whose tooling is down blocks.
3. Company-data boundary: company data never leaves the machine.
4. UNMEASURED is never PASS. (One spelling: `UNMEASURED` — the checker's exit-code name. `NOT_MEASURED` in older text means the same.)

5. **Added hooks may only observe.** A module hook cannot allow, rewrite input (`updatedInput`), set a `permissionDecision`, touch `core.hooksPath`, `.git/hooks` or `settings*.json`, or chmod/rm hook files. **In v0 only `SessionEnd` is open to modules.** Gating events (`PreToolUse`, `PermissionRequest`) and every event that can inject context or block (PostToolUse via `additionalContext`, SessionStart, UserPromptSubmit, Stop, SubagentStop, PreCompact, git-pre-commit, git-pre-push) are **closed**: a text scan of a hook body cannot prove it never emits a decision (`decision.behavior`, a key built from pieces) — cross-family review 2026-10-18 showed both — so these events are closed rather than scanned. Reopening them needs the core wrapper below. `action: add` alone is not harmless; commands are shape-checked and scanned (section 3).

The checker takes the **core hook list** from the tracked hook sources: script names wired in `templates/settings.*.snippet.json` and the hook names under `templates/.git-hooks/`. An empty or unreadable list is UNMEASURED, never a pass.

## 2. Manifest - `fh-module.yaml`

Unknown key or unknown enum value = BLOCK. Missing required field = BLOCK.

| Field | Values |
|---|---|
| `id` | lowercase slug |
| `version` | `MAJOR.MINOR.PATCH` |
| `provides.skills` / `.agents` | lists of names |
| `provides.hooks[]` | `{event, command, matcher?, action?, order?}`; `event` must be a known event name (PreToolUse, PermissionRequest, PostToolUse, SessionStart, SessionEnd, Stop, SubagentStop, UserPromptSubmit, PreCompact, git-pre-commit, git-pre-push) and, in v0, `SessionEnd`; `action` only `add`; `order` only `append` |
| `provides.verdicts[]` | `{entry, command, exit_codes:{pass: 0, block: 1, unmeasured: 2}}` — exactly these values (callers read 0 as proceed; any other mapping can turn a block into a pass) |
| `adds_constraints[]` | `{axis, value}` on the permission axes of the composition contract: `approval`, `reversibility`, `residency`, `degrade` |
| `touches_irreversible` | `none` / `publish` / `delete` / `history` |
| `core_route` | required iff `touches_irreversible` is not `none`: publish -> `pre-publish` or `public-surface-audit`; delete, history -> `destructive-op`. Forbidden when `none` |
| `data_class` | `public` / `private` / `company` |
| `requires` | `{modules: [ids], core_min: MAJOR.MINOR.PATCH}` |
| `calibration` | `{command: <known-pair test>}` or the literal `UNCALIBRATED` (allowed, reported as a note, never a verdict). **v0 checks presence and shape only — the checker does not run the calibration command** |
| `files` | optional list of repo-relative paths the module ships besides its skill/agent folders and command files; `export` copies exactly these |
| `records` | optional list of paths the module writes (used by removal) |

**A measurement engine is not a verdict entry.** A command that exits 0 even when it finds something wrong (it reports a number or a list, and the caller decides) does not go under `provides.verdicts` — a caller reads 0 there as «proceed». Declare it as a skill or a plain script; only a command whose 0 means «pass» is a verdict entry.

## 2b. Runtime dependencies — stdlib-only, or a named missing state

A module's Python runs wherever the module is loaded — including a floor environment the author never saw. So:

- **Default: standard library only.** No third-party import in any `.py` the module ships (skill folders, command
  files, `files`).
- **If a dependency is unavoidable**, the import is guarded (`try: … except ImportError`) and its absence exits
  **2 (UNMEASURED)** with one line that names the missing module. Never a traceback, never a guess, never folded into a
  pass or a block.
- `check` reads every shipped `.py` (AST, honouring a coding cookie): an **unguarded** non-stdlib import — `import`,
  `from … import`, or `importlib.import_module` / `__import__` with a literal name (positional or `name=`; a bare
  `import_module(…)` only when the file imported it from `importlib`), at top level or inside a function —
  BLOCKs; a **guarded** one is a NOTE naming the module and line; an unparsable file is UNMEASURED. «Guarded» means the
  import runs inside the `try` body (a `def`, `lambda` or generator expression written inside the `try` runs later
  and is not guarded by it) and the handler
  catches `ImportError` / `ModuleNotFoundError` / `Exception` / `BaseException` by name or as `builtins.<name>`, and the
  file does not bind that name (or `builtins`) anywhere — assignment, parameter, `except … as`, def/class, import alias. A module the package ships in the importing file's folder or an ancestor folder (a
  `.py`, or a folder with `__init__.py`) is not a dependency; a same-named file elsewhere in the module does not count.
  Lanes RD1–RD18; probes `rtguard` `rtscan` `rtpkg` `rtdyn` `rtnear` `rtdef` `rtshadow` `rtattr` `rtenc` `rtwalk`
  `rtkw` `rtbuiltins` `rtarg` `rtmeth` `rtgen` each turn their lanes red.
- **Why the guard is not enough** (measured, fh-cartridges A/B C10, 2026-11-08): `cart-ghaudit` guarded PyYAML and
  named its absence exactly as above — and the isolated runner's first `python3` had no PyYAML, so 9/9 inline and 5/9
  cart runs got rc 2. In the inline arm the no-guess contract turned that into no answer (2/6 against bare 6/6); the cart
  runs fell back to reading by hand. A guarded dependency is a
  typed failure, not a working module. That is why the guarded case is a NOTE the installer must read, and why the fix
  proposed there is stdlib-only (fh-cartridges PR #19, merged 2026-11-09: a built-in reader for the YAML subset
  workflows use; script output byte-identical on 224 local workflow files).
- **Named residual — passes unseen**: shell scripts calling `jq`, `yq`, `node` and the like are not read, and a
  computed import name (`import_module(name)`) is not followed. **Errs toward BLOCK**: an aliased exception
  (`from builtins import ImportError as E`), a folder added by `sys.path` edits, and a default argument, decorator or
  generator consumed at once (`list(__import__("x") for …)`) inside a guarded `try` (treated as unguarded). Codex found
  a new edge form in each of four rounds; the rounds were capped there and these forms are named instead. «stdlib» means the stdlib of the interpreter running `check`.

## 2c. Descriptions name the question shapes, not only the activity

A skill that should route itself is chosen from its `description`. Measured (fh-cartridges A/B C7–C12, Sonnet, live
`claude -p`, cart arm only installed): requests that named an activity («the postmortem's time to resolve», «security
review of the workflows», «the version bump for this API change») called the skill **9/9**; yes/no and counting
questions about the same artifacts («is the delta ready to merge?», «how many files reference X?», «will this
migration wipe data?») called it **1/9, 0/9, 0/9** — answered directly, the listing never consulted.

- A description lists, besides the activity, the **question shapes** users ask about that artifact — yes/no
  («ready to merge?», «reversible?», «will it lose data?») and counting («how many …?») — inside the same artifact
  scope (a delta spec, a name in code, a SQL migration), so the question does not widen the trigger to every
  «ready to merge?».
- The description is a YAML plain scalar: it may not contain `: ` (the first rewrite did, and admission refused the
  frontmatter as unparsable — the check worked).
- `scripts/generated_harness_check.py` reports **W8 (info)** for a skill description with no question example
  (`?`). Info only: it never changes a verdict, because a question mark is a proxy for the shape, not proof of routing.
- **Not proven yet**: a no-token proxy (subagents shown the listing and asked which skill they would call) was at
  ceiling before and after (9/9 targets, 0/8 false triggers; fh-cartridges PR #20, merged 2026-11-09) — it does not
  reproduce the live failure. The live effect is measured only by runs that install the module and do not hint it; the
  next such run is pre-registered (fh-cartridges `evidence/AB_PREREG_HAIKU_C7-C12.md`) and has no results yet.

## 2d. Before building — measure the bare model on the real path

Before building a module whose purpose is **accuracy** (it exists so the model gets an answer right that it would
otherwise get wrong), measure the bare model on the **real path** first: the module's own target tasks, run the way a
user runs them (a real session or `claude -p`, nothing installed, no hint in the prompt that a module or a check
exists). If the bare model is at the **ceiling** there, record the negative result and do not build.

- **Ceiling** = at the cheapest tier the module claims to help (and at Sonnet when that is a different tier),
  ≥ 3 runs on each of ≥ 3 target tasks, and **0 misses** — or, when the module declares its own success threshold,
  the bare model already meets it. Record it as a null at that size (e.g. «0/9 misses at Haiku — NOT-DETECTED@9»),
  never as «the model does not need it»: 9 clean runs do not rule out a rarer failure.
- **A proxy metric at ceiling does not stop a build.** A no-token proxy (§2c: subagents shown a listing, 9/9) did not
  reproduce the live failure; only the real path can say «already solved». The positive case looks like fh-cartridges
  #25: the bare arm gave a silent wrong answer 7/7/7 on frozen fixtures, the module 0/0/0 — that gap is why it was built.
- **Out of scope**: modules whose value is not accuracy — determinism, a gate, an audit trail, a refusal at an
  irreversible edge. A bare model that «usually gets it right» is not a substitute for those, so they are built without
  this measurement.

## 3. Install-time check (`scripts/fh_module_check.py check`)

Exit codes: **0 OK, 1 BLOCK, 2 UNMEASURED, 3 OK-but-UNCALIBRATED** (valid, no verdict entry points, `calibration: UNCALIBRATED`; callers must not treat 3 as a clean pass). Unreadable, empty, or non-mapping input is 2; PyYAML missing is 2; an internal error is 2. Nothing unreadable or unknown exits 0. Exit code 3 means different things in different FH scripts (in `governor_landing_check.py` it is LATE); read each script's own exit table, never assume 3 means the same thing.

**Caller rule:** proceed only on rc==0. rc==3 = refuse, unless an explicit operator flag installs the module inert (no hooks, no verdicts active). Anything else (1, 2, or any other code) = refuse.

**Command shape (hook, verdict and calibration commands):** exactly `bash|sh|python3|node <repo-relative existing file> [simple args]`. BLOCK on any of `$`, backtick, `;`, `&`, `|`, `<`, `>`, backslash, quotes, parentheses, globs, `eval`, `base64`, a `-c` argument, an absolute path or `..` — in the file **and in every argument** (including `--opt=value`). A trailing-backslash line continuation is joined before scanning. A missing or unreadable referenced file is UNMEASURED. The file's sha256 is printed (a NOTE) so a later swap is detectable.

1. Manifest present, every value inside its enum.
2. Hooks do not override, disable or reorder core hooks: `action` other than `add`, `order: prepend`, any `target`, or a `command` that names a core hook script all BLOCK.
3. `touches_irreversible` other than `none` must carry a valid `core_route`; the core gate file must exist (else UNMEASURED).
4. `touches_irreversible: none` is checked by a **lexical tripwire**, not proved: the declared command and the ONE file it names are scanned case-insensitively for irreversible verbs (git push, rm -r / rm -f, rmtree/rmSync/unlink, git clean -f, find -delete, branch -D, tag -d, reset --hard, --amend, reflog expire, update-ref -d, npm publish, twine upload, gh repo/release, gh api with a write method, --visibility, history rewrites) and for core-disabling patterns (hooksPath, `core.hooks*`, any `GIT_CONFIG_*`, `GIT_DIR ... hooks`, `.git/hooks`, any `settings*.json`, `permissionDecision`, `updatedInput`, `behavior`, `additionalContext`). A hit with `none` BLOCKs. Calibration files get the core-disabling scan only (they are test code). **Residual, not covered:** these are lexical tripwires and do not converge (a new spelling always exists) — one widening per review round, then named here: obfuscation inside the referenced file, comments and echoed strings that mention a pattern (false BLOCK, accepted direction), `core_route` is a label (the checker does not verify the module actually calls that gate), files that file calls or sources, and the contents of skills and agents. Structural closure - a core wrapper that discards decision JSON and exit-2 coming from module hooks - is future work.
5. Calibration: `UNCALIBRATED` with a non-empty `provides.verdicts` BLOCKs; a `calibration.command` follows the command shape above (missing target = UNMEASURED). Duplicate YAML keys BLOCK.
6. `--installed DIR` (`*/fh-module.yaml|yml`, `*.yaml|yml`): a missing dir, zero manifests, or a malformed `requires` is UNMEASURED; duplicate installed ids BLOCK; also duplicate id, or a `requires.modules` entry not installed, BLOCKs.
7. `adds_constraints` below the core floor (approval below `ask`, degrade `advisory`) **BLOCK** — in `check` and in `merge`. A module can only add constraints; a below-floor value is never silently clamped, because a consumer reading the manifest directly would see the weaker value. Enum fields must be strings; a list or mapping where a name belongs BLOCKs (it used to crash to 2). A present `core_route` (even `null`) with `touches_irreversible: none` BLOCKs. Non-UTF-8 input is UNMEASURED. With `--installed`, an unreadable registry is UNMEASURED and cannot also report «required module not installed».

## 3b. Export — the standalone proof (`fh_module_check.py export <manifest> --out DIR`)

A standalone skill must run without FH around it (operator: «스킬 단품은 스탠드얼론으로 동작할수있게 … 자체하네스를 필요하면 내장한채로»). `export` proves it instead of asserting it: it copies **only what the manifest declares** — the skill and agent folders, every hook/verdict/calibration command file, and the optional `files:` list (repo-relative, same path rules as commands) — into an empty folder, then runs the module's own calibration **inside that folder** with a fresh HOME.

- Copied: **git-tracked files only** (an untracked or ignored local file would make STANDALONE true here and false elsewhere). **Any symlink** in a declared path BLOCKs. Skill/agent names must be plain slugs; `files` may not be `.`, `.git…`, or the reserved `fh-module.yaml` / `MODULE.md` / `.fh-export`. Export metadata goes to `.fh-export/`.
- Built in a staging folder next to `--out` and moved there only on success; the calibration runs in a separate scratch copy with a fresh HOME/TMPDIR/XDG and a PATH of system dirs plus the interpreters' own dirs (never a repo dir), stdin closed, in its own process group (killed whole on timeout). `--out` inside the repo is refused.
- rc 0 **STANDALONE**: the known-pair test passes with only the declared, tracked files.
- rc 1: the manifest does not pass `check`; a symlink, a non-slug name, `.`/`.git`; or the calibration fails inside the export — including when its output says a file was not found (python exits 2 there): an undeclared dependency, named in the output tail.
- rc 2: `UNCALIBRATED`, a missing or untracked declared file, a non-empty `--out` or one inside the repo, a timeout, or the calibration's own UNMEASURED (rc 2 without a missing-file message, 126/127, a signal).

Measured on the pilot: without `files:` the export failed with «missing scripts/ko_tech_writer_calibrate.py» (the lane calls it); declaring it made the export STANDALONE (7 files). Lanes EX1–EX7; dropping the pilot's `files:` turns EX7 red.

**Not proven by export (named residual)**: there is no OS sandbox — a calibration that reads the repo by absolute path or reaches the real home via the user database can pass falsely; tools it needs from the machine (python3, rg) come from the system PATH; a calibration that exits 0 without testing reads as STANDALONE (the contract requires a known-pair test, the checker does not inspect it); whether the skill's prose still makes sense without FH is a reading question, not a run.

## 4. Composition and removal

- **Two modules disagree** (`merge`): every member is validated first (an invalid member BLOCKs the merge); UNCALIBRATED propagates (exit 3); the merge is seeded with a core-floor pseudo-manifest (`approval: ask`, `degrade: fail-closed`, `reversibility: irreversible`) so nothing lands below the core. `approval: ask` is a **floor**, not a silent default: the core irreversible gates are ask-level, so a module cannot merge below it. The merge JSON is printed only on rc 0/3; on any other code only `{"verdict": ...}` is printed; `residency` is floored from each member's `data_class`; strictest value per axis wins regardless of argument order; `data_class` takes the strictest class; any irreversible member marks the set irreversible.
- **Removal** (`remove <id> --installed DIR`): refused (BLOCK) while another installed module `requires` it; if any installed manifest is unreadable the answer is UNMEASURED, not "no dependants". When allowed, the output is a *plan* that archives the module's `records`; the checker deletes nothing.

## 5. Decisions recorded

- Skills stay as they are and are not classified. The pilot manifest wraps an existing skill without changing it.
- A standalone skill package must work alone and embed its own guard if it needs one. A skill that touches irreversible ops ships standalone only with an embedded guard.
- Company modules use a separate registry (not this one); `data_class: company` here only labels and tightens `residency`.

## 6. Calibration of the checker

`bash scripts/test_fh_module_check_lanes.sh` - known-positive (valid module), known-negatives (disable, override, shadow, reorder, unknown enum, unknown key, unrouted publish, garbage / empty / missing manifest, removal with dependant, merge in both orders, runtime dependencies RD1–RD18). `FH_MODULE_PROBE=<name>` neuters one check in a temp copy; the matching lane must go red.

Pilot: `plugins/fh-commons/skills/ko-tech-writer/fh-module.yaml`.
Second module (2026-11-06): `plugins/fh-commons/skills/persona-cast/fh-module.yaml` — the doorway skill, its six lens agents and the Step 4 merge engine `scripts/persona_cast_merge.py`; `export` is STANDALONE with 10 files.
Convergence-loop module (2026-11-06): `plugins/fh-commons/skills/convergence-loop/fh-module.yaml` — the first with a **verdict entry point** (`convergence-verdict`, exit 0/1/2; PROVISIONAL «one clean round» maps to 1, never 0).

## 7. Not in v0

**Packaging an embedded guard** — export copies a module that touches nothing irreversible; a module that does (`touches_irreversible` other than `none`) would need the core gate it routes to inside the export. Not built.

Version-range solving for `requires`, applying the archive plan, enforcing `core_min` against the installed core version, and installing hooks into settings. The checker validates a manifest; it does not install.

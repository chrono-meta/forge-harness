---
paths:
  - "plugins/**/SKILL.md"
  - "knowledge/**/*.md"
  - "templates/**"
  - "AGENTS.md"
  - ".claude/rules/**"
  - ".claude/agents/**/*.md"
---

<!-- Thin resident layer (2026-11-19). Path-scoped rules attach when a matching file is READ, so this
     file rides along whenever a session reads any knowledge/ doc — onboarding included. It keeps every
     requirement the hook enforces; history, measurements and reasons live in
     knowledge/shared/harness-core/fh_4axis_gate_detail.md under the same headings.
     CLAUDE.md stays out of the glob on purpose: it loads every session, so listing it here would make
     this rule permanent. Intent-fired gates (Pre-Publish · Destructive-Op · the Irreversibility common
     spine) must NOT move into a path-scoped file — they fire on intent, not on files. -->

**Every split that relocates content** (salience-splitter, a thin/detail pair like this one) **must
re-ask whether the destination path is inside the gate** — coverage otherwise shrinks as the diet
succeeds (`scripts/gate_pathspec_check.sh` anchors the asset list; it does not check your destination).

## FH Improvement 4-Axis Auto-Gate (Self-Verification Orchestrator)

**Whenever the AI modifies FH assets** (SKILL.md · **`SKILL_detail.md`** · `.claude/rules/*.md` · `knowledge/shared/rules/*.md` (always full-gate, NOT under the knowledge carve-out) · `templates/` · `CLAUDE.md` · substantive `knowledge/` docs · substantive `docs/*.md` · `AGENTS.md` · `scripts/**/*.sh` · `scripts/**/*.py` · agent definitions (`plugins/*/agents/**/*.md` · `.claude/agents/**/*.md`) — see Substantive carve-out below), the 4-axis verification chain runs **automatically before the first commit** of that session. No user request is needed — this is a mandatory autonomous step, not a proposal.

**Commit gate**: `git commit` on FH asset changes is hard-blocked by `templates/.git-hooks/pre-commit` until all required axes PASS. Hook installation (one-time): `git config core.hooksPath templates/.git-hooks && chmod +x templates/.git-hooks/pre-commit templates/.git-hooks/pre-push` (the same path also arms the **pre-push** Destructive-Op gate).

```
FH asset modified → Axis 1 (templates/regression_guard.sh --pr {BRANCH})
  → Axis 2 (/steel-quench) → Axis 3 (/phantom-quench)
  → marker: tracks/_meta/.axes_23_passed_{branch}_{date}.marker   (fields: §Marker axis fields below)
  → Axis 4 (/edit-manifest RECORD, today's entry in tracks/_meta/edit_manifest.yaml)
  → All 4 PASS → git commit allowed   |   Any FAIL → fix inline, re-run
```

The hook checks the marker's **form, non-vacuity and auditability — never provenance**. A fabricated marker passes by design; catching it is the weekly audit, the operator and cross-family review reading the marker — do NOT fake-close that residual. Before auditing or attempting to harden the marker, read `claude_md_gate_details.md §Marker-Irreducibility` (why the below-floor-ack is irreducible for an autonomous runner; the operator-present GPG hard-close option).

**Lightweight exception** (Axis 1 + 4 only, skip Axes 2–3): sessions where **zero SKILL.md / rules / templates files changed** (CATALOG entry, tracks/ update). The hook decides this from the file list, not from judgment.

**Substantive carve-out — `knowledge/` · `docs/*.md` · `AGENTS.md`**: a change there is **not** light when its diff adds a fenced code block or a citation/version token (`arXiv:` / `DOI` / `http` / a versioned dependency like `x.y.z`) — Axes 2–3 run. Prose-only edits (typos, rewording, link fixes) stay light. Detection is mechanical (`git diff`).

**Unavailable axis**: if steel-quench or phantom-quench is not installed, write `Axis N: skipped (skill unavailable)` and proceed; Axis 1 PASS alone unblocks a PR then. Axis 4 without the skill: append a one-line prediction to `tracks/_meta/edit_manifest.yaml` yourself — the record is what matters.

**Axis 4 lane substitution**: a today-dated manifest entry may carry `lane: <repo-relative path>` + `not_seen: <what that lane does NOT check>` instead of a prediction. The hook refuses it when the lane file does not exist (absolute and `..` paths rejected), `not_seen:` is empty or a placeholder, or the prediction is an **absence claim** («…가 남아 있지 않다 / 없다 / never») — a green lane does not prove an absence. A refused entry is not counted; any other valid today entry (classic or lane) still satisfies Axis 4, so a stale dead lane never blocks a later classic one. `lane:` absent or `lane: null` = classic behaviour. Without PyYAML the checker falls back to a date grep and does not validate `lane:`. A change with no lane (resident wording, triggers, onboarding) keeps the classic prediction. Lanes: `scripts/test_axis4_lane_substitute_lanes.sh`.

**Target-tier sim gate**: if the change works only when a session *follows prose* (rules, onboarding text, SKILL.md trigger behaviour) — salience-dependent, as opposed to hooks and scripts — verify it with a **blind simulation in an isolated agent** (no main-session reasoning inherited), `model:` pinned, **default Sonnet**. Mode D (FH self-dev): near-mandatory — run the sim **before Done**; **mandatory without exception** when the change fixes a miss *observed* on a specific tier, and then sim at that same tier, even below Sonnet. Field templates: sim when the behaviour is load-bearing (gates, onboarding, destructive/publish paths), else a one-line skip note. Light mapping and mechanical changes are exempt. Below opus-tier the default is to RUN the sim, not to skip it; ask the operator only when nothing can run. Record results in the marker and in `knowledge/shared/learnings/subagent_invocations_log.yaml`.

### Marker axis fields — `axes-run:` · `controls:` · `standpoint:` · `soul:` · `soul-check:` · `defeater:` · `tenets:` · `affected:` · `oracle:` · `diff-sha:`

Each bullet says what the hook checks for that field; the hook checks form and non-vacuity only. Write each from this list, not from memory. A marker dated today meets every grace date (they exist so older markers are not judged retroactively; dates and boundaries are in the detail file). A hint-placeholder literal `<...>` left in grounds blocks (`affected:` · `defeater:` · `oracle:`). ⓐ~ⓕ are axis symbols only — enumerate prose with `①②③` or `(a)(b)(c)`.

- **`axis2-engine:` · `axis2-model:` · `floor-status:` · `axis2-evidence:`** — required. `axis2-evidence` is a recorded verdict or count, not «it ran». Below-floor without `below-floor-ack:` blocks. `axis2-rounds:` is convention only — canonical shape `R1 [new=, fixed=] → R2 …` (steel-quench §Convergence Criteria); advisory audit `python3 scripts/convergence_verdict.py --scan-markers tracks/_meta`.
- **`soul:`** (or `①영혼:`) — required, written **before design**: the success definition and the «never do». Write `없음` if there is none; a one-word placeholder blocks. Before designing, give a context-free reader (e.g. a Sonnet agent — the `soul:` line only, no conversation, repo or notes, and do not say what is suspected; procedure = `meta-prompt-builder` Step 3 item 4) the line to restate as two cells, success / never-do, each `RESTATABLE` or `GUESS` plus the questions it needs; rewrite any `GUESS` cell before design. Your own restatement does not count. Record it inside `soul-check:` grounds (e.g. `soul read: Sonnet, both RESTATABLE`); could not run → `NOT RUN`.
- **`soul-check:`** — optional; if present a closed enum: `reflected(<what came back — diverged or not>)` · `violated(<which half + what you did>)` · `DEGRADED_NOT_RUN(<why>)` · `DEGRADED_NO_SOUL(<why>)` · `UNKNOWN` · `not-applicable(<why>)`. `violated` is legal.
- **`defeater:`** — required: «if this success definition were wrong, what would be *observed*» — one line naming an observable event.
- **`axes-run:`** — exactly one line, every key present, `none` for an axis not run (silence is not zero): `axes-run: ⓐ=<다른 계열> ⓑ=→standpoint ⓒ=<격리 그라운딩> ⓓ=<3자 대면> ⓔ=<첫 실사용> ⓕ=<되돌림 실측>`. A second `axes-run:` line blocks. 🟥 Markers dated before 2026-08-17 used an old 4-key array whose `b`/`d` mean different axes — never copy an old line forward. ⓑ that references standpoint needs a non-empty `standpoint:` line; ⓓ that references thirdparty needs a `thirdparty:` line. A **new instrument file** added in the commit blocks when ⓔ is empty, `none`, or has no grounds on the same line (`shadow(N=<sessions>, F=<fired>)` is a valid ⓔ). The pointer checks look for a reference to the field anywhere in the ⓑ/ⓓ value, not for the arrow; a reference spelled in another token is not detected (named residual).
- **`controls:`** — the liveness of the controls, not their existence: an axis counts as run only with an execution output in which a control was alive — cite that output. `controls: alive — known-positive 'X' 3 hits · known-negative 0` or `controls: n/a — no measurement in this delta (<reason>)`. A value without a life/death token blocks.
- **`crossfamily:`** — required on **load-bearing** changes (gates · irreversible-surface code · doctrine). Closed enum: `panel(<families>)` · `declined` · `DEGRADED_SINGLE_FAMILY` · `DEGRADED_PANEL_UNUSED` · `UNKNOWN`; the three degrade values need substantive grounds on the same line. `panel(...)` also requires, in its grounds, `residency=CLEAN(...)` (from `scripts/residency_closure_scan.py --files <payload>`, `auto-decorrelation` §Step 4.5) and exactly one of `evidence=SHARED(<what every family read>)` · `evidence=INDEPENDENT(<what each got>)` · `evidence=MIXED(<who got which>)`. `SHARED` is legal and common. Blocks: `panel(...)` with `residency=TAINTED(` or `residency=NOT_SCANNED(`; a missing, malformed or duplicated `evidence=` token; a vacuous body on `SHARED`/`MIXED` (`INDEPENDENT` is not body-checked). On `declined`/`DEGRADED_*`/`UNKNOWN` a `residency=(CLEAN|TAINTED|NOT_SCANNED)(...)` token is optional and only format-checked. Example: `crossfamily: panel(codex) — residency=CLEAN(files=3) · evidence=SHARED(same staged diff) · R1, 3 findings`. Fixtures: `scripts/test_marker_crossfamily_lanes.sh`. Before merging load-bearing field code, read `knowledge/shared/harness-core/field_verdict_crossfamily_gate.md` (that obligation is CLAUDE.md's, restated here).
- **`standpoint:`** — closed enum, canonical in `field_verdict_crossfamily_gate.md §7`. `tier2`/`tier2b`/`tier3` assert code ran in the target, so the grounds must **name the command and its output** (`ran \`bash scripts/x.sh\` there, output: 30/30 PASS`) or the commit blocks; if you only read files, the honest rung is `tier1b`. `tier3` (a different human operator ran it) is unreached in this repo, not disproven.
- **`thirdparty:`** — ⓓ's own field: `checked(<searched what, found what>)` · `none-found(<searched what>)` · `DEGRADED_NO_ACCESS(<why>)` · `DEGRADED_NOT_RUN(<why>)` · `UNKNOWN` · `not-applicable(<why>)` · `peer-review(<harness>/<persona> → <target>, <what came back>)` (a peer-harness review is folded into ⓐ's panel classification; the value stays legal). The hook checks that the field exists when ⓓ points at it; it does not validate the value against this list.
- **`tenets:`** — optional; only IDs that exist in `.claude/soul_tenets.txt` (`FH-T\d\d`), read from this line only. An unknown ID blocks.
- **`affected:`** — optional; one line: what the change touches (people, harnesses, surfaces) + `열린 질문 = …`. Placeholder-only values (`없음`/`TBD`/`-`) and duplicate lines block.
- **`oracle:`** — optional; `oracle: <kind> — <grounds>`, kind ∈ `known-pair` (positive and negative controls in the same run) · `metamorphic` (judged by an input-change → expected-output-change relation) · `back-to-back` (another implementation or family's output on the same input) · `a-b` (one variable, ARM/CTRL, reps≥3; `A/B` allowed) · `human` (a person judged the expected value) · `none` (reason required). The hook checks form only, not whether the oracle really was that kind. Blocks: a kind outside the enum or with characters glued on (`known-pair2`), grounds under two words or a `<...>` placeholder, duplicates, and any near-key — every line whose key starts with `oracle` but is not exactly `oracle:`, plus `orcale:` `oralce:` `오라클:` — even next to a valid line. Lanes: `scripts/test_marker_oracle_lanes.sh`.
- **`diff-sha:`** — optional while `DIFF_SHA_REQUIRED_DATE` in the hook is empty (setting it is the operator's decision); `diff-sha: <64 lowercase hex>` from `bash scripts/marker_diff_sha.sh`. Several lines allowed; at least one must equal the current staged fingerprint, else block. Near-keys (`diff_sha:` `Diff-sha:` `diff-sha :` `diffsha:` `diff-fp:`) block. Fingerprint failure is HARNESS-ERROR, not a match. Lanes: `scripts/test_marker_diff_sha_lanes.sh`.

Fixtures for the field set: `scripts/test_marker_axes_run_lanes.sh` · `scripts/test_marker_standpoint_lanes.sh` · `scripts/test_marker_soul_check_lanes.sh`. Extending the format means adding lanes there and running the **revert probe** (disable the branch a lane claims to anchor; the lane must go red).

### Reviewer-visible evidence — the marker is not readable from the other side

The marker is gitignored (`tracks/**`), so a reviewer elsewhere cannot read it. A PR touching FH assets carries a **sanitized evidence capsule** in its body: what ran, what it returned, what was found and closed. A verdict given as a grade, tier or code gets its inline expansion and the location of its definition (`sim grade F = Functional/PASS — scale: sim-conductor SKILL.md §Area-D`). **Never paste the raw marker** — it may quote paths, hostnames, internal names or unredacted findings, and a PR body is outside the pre-commit privacy scan; run the public-surface scan over the capsule text before creating or editing the body. Evidence you cannot sanitize is declared, never dropped:

```
LOCAL-ONLY ATTESTATION — UNVERIFIED: <one-line result> (record: local marker <name>)
```

That line leaves the requirement unmet; the PR proceeds only with a sanitized reproducible capsule, an authorized independent review on a machine that can read the record, or explicit operator acceptance. Never restate a local-only result as though the reviewer confirmed it. On the reviewer side: **a pointer your instrument hands you is not optional reading** — open the definition a grep surfaces before calling a verdict unverifiable.

**Correcting a claim that lives in several files**: the question is «where else does this sentence live», not «is this sentence wrong». **A propagation sweep must not be run in the vocabulary of the thing it is fixing** — widen the search terms, and say which terms you searched, before declaring the sweep complete.

When a model-pinned dispatch fails, read `claude_md_gate_details.md §Sim-Dispatch-Fallback` (headless `claude -p --model` fallback, the saturation-disguise retry, the credit-pool caveat). **Measurement-integrity pre-flight** — for a cross-model measurement (pinned tier, comparing models, feeding a published claim), read `knowledge/shared/harness-core/measurement-integrity-checklist.md` **before** running it: pin the display name, not a slug · reps ≥ 3 on any borderline or contested verdict · a discriminating identity probe (a generic «OK» proves nothing about which model answered). Optional token-free pre-screen below the Sonnet sim — when running one, read `claude_md_gate_details.md §Floor-Tier-Canary` (model/panel options, blind-probe procedure, FAIL triage). A canary, never a gate: after a PASS you still run the Sonnet sim, a FAIL never blocks alone, and the terminal verdict stays with a Sonnet-or-higher governor bound to a mechanical anchor (no judge-only path).

### Added-Scope Gate — before you attach anything to a fix

Before adding anything beyond the fix's stated job, answer in writing: (1) **«What can I not do without this?»** — no concrete answer means not needed here. (2) **«Is this the same change?»** — an answer that names a different job means a separate change. Both must pass. **A construct and the wiring that makes it reachable are ONE change** (a caller, a hook line, a package-manifest entry, a propagated copy) — splitting those ships something unreachable. Distinct from steel-quench Wave-T, which measures what the *quench* added.

**Axis ownership** (the orchestrator only coordinates):

| Axis | Skill | What it catches |
|---|---|---|
| Backward | `templates/regression_guard.sh` | Critical section loss, broken refs, syntax errors, line reduction |
| Adversarial | `steel-quench` | Trigger phrase collisions, design attack surface, over-engineered steps |
| Forward | `phantom-quench` | Phantom references, paths that don't exist, stale external links |
| Record | `edit-manifest` RECORD | Logs predicted impact — closes the predict-verify loop for future harvest-loop |

**Cross-family complement (Axis 2)**: steel-quench runs in the governor's family and shares its blind spots. For a load-bearing change, `auto-decorrelation` recruits ≥1 different-family auditor when the panel is discoverable — autonomous once the operator consented (UAP), degrading honestly to single-session otherwise. The governor keeps the terminal verdict and source-grounds every sidecar finding. When recruiting or configuring a cross-family auditor, read `claude_md_gate_details.md §Cross-Family-Complement` (which family for which task class).

### Mode D Model Notice (fires once, at the same trigger as this gate)

When FH self-dev begins, check the session model and surface **one line**, then proceed — never block, **never switch the model**: opus-tier+ → no notice · below opus → recommend dispatch-first (keep Sonnet, route depth turns to an opus sidecar; `/model opus` pin second) · unknown → static fallback recommend. Once per session; field-project sessions never see it. When surfacing it, read `claude_md_gate_details.md §Mode-D-Model-Notice` (the exact wording and guards); actual escalation is governed by `capability_escalation_consent.md`.

---

## New Skill Creation Pre-Commit Gate

All 6 items below must pass before committing a new SKILL.md. If any fails, fix and re-commit.

| Item | Criterion |
|---|---|
| **Role duplication check** | Pass `/asset-placement-gate` — no overlap with existing role clusters, **platform built-ins (Tier 0), or `claude-plugins-official` (Tier 1 official)**. Reinventing an official capability requires explicit justification in the SKILL.md (no-reinvention rule — FH builds only what adds governance) |
| **Description diet** | Plain text / 0 self-marketing expressions / 0 emphasis words (⭐, "critical", "groundbreaking") |
| **Done When defined** | At least 1 explicit completion condition |
| **Check-class declared** | Each Done When condition states its check class — mandatory-pass / measured / judged (`harness_6axis_framework.md` §Axis 5). Any judged condition names its adversarial pairing — no judge-only path |
| **Natural language triggers** | At least 3 examples that work without internal vocabulary (judged form check). Can be upgraded judged → measured with steel-quench `Step 0.5 — Trigger-Accuracy Probe` — optional for ordinary skills, recommended when the skill is a routing/gate surface |
| **Independently executable** | Confirmed to work without other FH skills (or dependencies are explicitly documented) |

Skills without a Done When definition qualify as harness-doctor L2 M-tier. Check-class declaration applies to **new** skills; existing ones backfill when next edited. **Obligation:** a **routing/gate skill** (primary output = a dispatch decision or pass/block verdict) owes a one-time `Step 0.5` baseline trigger-probe at the next `harness-doctor` run and a re-probe whenever its trigger phrases change. When editing a routing/gate skill, read `claude_md_gate_details.md §New-Skill-Backfill` (probe mechanics, baseline rationale, the routing/gate test).

> **Full text, history and measurements for every section above**: `knowledge/shared/harness-core/fh_4axis_gate_detail.md` (same headings). Read the matching section when a field is new to you, when the hook blocks, or when you change the gate itself.

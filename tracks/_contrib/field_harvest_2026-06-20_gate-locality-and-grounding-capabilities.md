---
name: field-harvest-2026-06-20-gate-locality-and-grounding-capabilities
description: 3 generalizable FH-capability candidates harvested from two field-harness governor sessions + the-bible build (HITL — proposal, not yet PR'd)
type: contrib-candidate
date: 2026-06-20
status: DRAFT — awaiting operator PR approval (feedback_no_personal_commit_to_shared_repo)
tags: [field-harvest, gate-locality, corpus-grounding, persona-roster, hitl]
originProjects: [two restricted-env field harnesses, the-bible]
---

# Field-Harvest 2026-06-20 — 3 generalizable patterns → FH capability candidates

Harvested from one session's field work (two field-harness dev-repo governor refactors; the-bible build).
Each passes the generalization gate (recurs across 2+ contexts OR validated by an FH agent).
**HITL**: these are *proposals* — AI does not commit to the FH shared repo without operator PR approval.

---

## Candidate 1 — Gate-Locality Principle (governance) → knowledge doc + steel-quench angle

**Pattern**: *A safety gate must live where the actor that needs it actually reads it.* A gate
defined in a place the enforcing actor never loads is decorative — it provides the *appearance* of
safety with none of the enforcement.

**Recurrence (generalization gate: 2+ contexts ✓)**:
- **Harness-A C-1** (code): a tracker-writeback provenance gate was *absent from the write path*
  (the writeback-candidate generator checked confidence only, not provenance). A self-inferred
  finding could auto-post to the issue tracker as if externally verified. Fixed by putting the gate
  *in the code path that writes*.
- **Harness-B + Harness-A AGENTS.md** (file locality): the orchestration safety gates lived only in
  Claude-only `CLAUDE.md`, so a Gemini/Codex twin-orchestrator (which auto-loads root `AGENTS.md`,
  not `CLAUDE.md`) assumed the commander *role* without inheriting the *gates*. Fixed by lifting the
  gates into a model-agnostic `## Orchestration Gates` section of `AGENTS.md`.

**Validation**: blind target-tier sim (isolated Sonnet, AGENTS.md-only) — pre-hardening the runtime
had no basis to refuse a hallucinated writeback; post-hardening it refused, citing the lifted gate.
The delta *is* the principle.

**FH backport**: (a) a `knowledge/shared/harness-core/` doc stating the principle; (b) a
**steel-quench Wave-1 attack angle**: *"Gate-locality — is every safety gate readable by the actor
that must enforce it? Name any gate defined only in a file/layer the enforcing runtime never loads."*
Reuses existing steel-quench machinery; net-new is only the angle.

---

## Candidate 2 — `corpus-grounding-expander` (autonomous corpus expansion)

**Pattern**: on an operator "get more sources / broaden the grounded corpus" intent, an agent fetches
and **normalizes** multi-version public-domain corpora into a single verified-axiom store (per-version
provenance + license tag + aligned key schema), so output can be *grounded by verbatim quotation*
against any version. Demonstrated in the-bible: 6 public-domain Bible versions (197,009 verses,
Protestant + Catholic + Apocrypha) ingested as the fail-closed grounding axiom; multi-version =
non-biased + more robust grounding (a quote verified in ANY version counts).

**Done-When**: each added source carries a verifiable public-domain/license record · a normalized key
schema · a relay-integrity check (corpus is *quoted*, never generated).

**Generalizes beyond scripture** to any verbatim-relay grounded axiom (legal statute, RFC text,
standards corpus). **Guard**: the expander wires *grounding*, never a generator — relay constraint is
structural. Reuses fetch+normalize plumbing; net-new = the relay-integrity gate.

---

## Candidate 3 — `persona-roster-expander` (persona auto-expansion + judgment-mapping)

**Pattern** (innovator-family skill): takes a named persona *seed*, then (1) tiers each persona by a
domain-supplied safety rule, (2) maps each to a concrete decision-lens in the *user's* domain
vocabulary, (3) proposes 2-4 additional voices filling uncovered lenses, each with a sourced anchor
for the strongest candidates. Demonstrated in the-bible: operator seed (priest/nun/angel/devil/God/
Jesus/Holy-Spirit/apostles) → tiered relay-vs-lens by a relay-safety rule, mapped to engineering-
judgment lenses (devil=failure-mode, solomon=trade-off, job=unexplained-incident, nathan=
self-accountability), +4 sourced proposals.

**Done-When**: every persona has a tier + lens label + invoke-condition · each net-new proposal names
a real anchor (not a shallow stub). Reuses FH's naming-taxonomy + adversarial-pairing discipline;
net-new = the *tier-by-safety-rule + lens-to-domain mapping* step.

---

## Next step (HITL)
Operator approval → promote 1-3 into FH (Candidate 1 = knowledge doc + steel-quench angle is the
lowest-friction first PR; 2 & 3 are new skills needing the New-Skill-Creation gate). No PR opened yet.

# CLAUDE.md Gate — On-Demand Execution Detail

> **Load: on-demand.** Execution mechanics + origin analysis for the CLAUDE.md gates whose *always-loaded*
> invariants live in `CLAUDE.md` (§FH Improvement 4-Axis Auto-Gate · §New Skill Creation Pre-Commit Gate ·
> §Pre-Publish Surface Gate · §Session Wrap-up — Card Update Protocol). Read the §section named by the
> pointer that sent you. **Load-bearing rules stay in CLAUDE.md; only the *why/how* is here.**
>
> **Destination rule (kills overflow fan-out):** *gate-execution* detail → **this file**.
> *Protocol* detail (onboarding · signal recording · execution tier) → `fh_detail_protocols.md`. One
> overflow file per concern; do not spawn a third.

---

## §Marker-Irreducibility

Honest scope of the Axis 2–3 marker: **form + non-vacuity + auditability, NOT provenance** — a fabricated
marker is the weekly audit's + operator's residual by design (judge-robustness swarm 2026-06-13).

The below-floor-ack rubber-stamp is **structurally IRREDUCIBLE for an autonomous runner**: the runner
writes both the marker AND any transcript the hook could cross-check, so any in-boundary check it can
satisfy it can also forge (a runner-computed signature is false security). The one genuine close needs a
secret the runner does NOT hold — an **operator-present hard-close**: a GPG-signed trailer **whose key
requires a fresh interactive passphrase** (NOT an agent-cached gpg-agent key, and NOT operator-git-identity
alone — `user.email` is config the runner already writes, forgeable, not a secret). The real guarantee is
*uncached private-key access*, not commit identity; optional, breaks full autonomy, use only when the
operator is at the keyboard. Autonomous mode keeps the honest residual + weekly-audit backstop — do NOT
fake-close it. Gemini cross-analysis 2026-06-16 reached this verdict independently, converging with the
existing FH stance.

**External anchor (verified 2026-06-27): Open Agent Passport (OAP), arXiv:2603.20953** ("Before the Tool
Call: Deterministic Pre-Action Authorization for Autonomous AI Agents", Uchibeke, 2026-03; Apache-2.0,
DOI 10.5281/zenodo.18901596) intercepts tool calls before execution and emits a **cryptographically
signed audit record** (median 53ms; 0% vs 74.6% social-engineering success under restrictive vs
permissive policy). It is independent convergence on the *direction* the GPG hard-close gestures at —
**crypto-signed provenance over runner self-attestation** — and a peer-grade anchor for the
fabricated-marker residual. **Caveat (FH's point still stands):** OAP's signature is only as strong as
its key custody — if the signing key is held by the same runtime being audited, it is the same
"runner-computed signature = false security" failure named above. So OAP corroborates the *crypto-audit
direction*, not a dissolution of the irreducibility argument: the genuine close still needs an
*operator-held, uncached* key. Sister cross-link only — FH does not adopt runtime pre-action
interception (a different mechanism from the commit-time marker); this anchor strengthens the case for
the existing GPG-option residual, it does not mandate new infra.

---

## §Sim-Dispatch-Fallback

If `model:`-pinned dispatch is unavailable (plan/billing gate), fall back to a cross-session headless run
(`claude -p "<trigger>" --model <tier>` in the target cwd) — stronger isolation, zero instruction
contamination. **Saturation disguise (N=2, 2026-06-11/12)**: the same "Usage credits required for 1M
context" error also fires when the *session* is near context saturation, not the plan gate — in a
long-running session, compact (flush handoff state to disk first) and retry the dispatch once before
concluding the gate is closed (identical opus-pinned dispatch failed pre-compaction, succeeded
post-compaction 2026-06-12). 2026-06-15+: headless `claude -p` draws from the hard-capped credit pool, not
the subscription — prefer in-session Agent dispatch when the plan gate allows; take the headless fallback
knowingly. Record sim results in the Axes 2–3 marker + sub-agent invocation log.

---

## §Floor-Tier-Canary

A local model weaker than or comparable to Sonnet (e.g. `ollama run qwen3:8b` on the local host today; a
cross-family local panel — qwen3.x:27b / gemma4:12b-qat / gpt-oss:20b / devstral — on a GPU host once its
remote-exec path is live) can pre-screen a salience-dependent edit *before* the Sonnet dispatch is spent: a
rule that fires correctly on the floor model is *evidence of* robustness below Sonnet (one floor sample, not
proof — hold the asymmetric-skepticism discipline). Blind probe — feed the verbatim rule text + a scenario,
demand a strict YES/NO + one-line reason, judge whether the rule fired (mechanism dogfood-verified
2026-06-20: a local `qwen3:8b` correctly gated the public install-wizard local-LLM-offload item in both
directions — a claim checkable against that skill — re-validating that day's salience-binding fix at a
sub-Sonnet tier).

**FAIL-triage**: a FAIL never blocks alone — the orchestrator (whatever tier is driving; the triage
judgment is *trusted* at opus+ and run-or-ask below, per §Floor governance) triages it as a *real
salience gap* (fix the rule) vs a *floor-model quirk* (small-model loop/hallucination, per the public
"Local AI is not Opus" finding + the cheap-oracle ceiling — a small model adds nothing where one grep
already settles the check). The terminal verdict stays with the **Sonnet-or-higher governor bound to a
mechanical anchor** (Sonnet sim verdict + the anchor evidence; an opus judge is the *dispatch-recommended*
strengthener, not a requirement — Sonnet-Floor Doctrine 2026-07-10) — no judge-only path, no
weak-local-judge regression of the judge-robustness principle (mechanical anchor over judge-only verdict).
The cross-family-panel upgrade spec lives in the private companion store's `handoff/` design note.

---

## §New-Skill-Backfill

> The *obligation* (router/gate skills owe a one-time baseline probe + an on-trigger-change re-probe) is
> stated always-loaded in `CLAUDE.md §New Skill Creation`; what follows is only the *mechanics*.

**Trigger-accuracy probe backfill** follows the opportunistic rule but scoped to **routing/gate skills
only**: when an existing router/gate skill is edited (especially when its trigger phrases change), run
steel-quench `Step 0.5 — Trigger-Accuracy Probe` on the changed trigger surface and record the fire-count
— turning "do these triggers collide?" from a guess into a number. Not a retroactive sweep of all routers
(that would be decorative over-work); it rides the edit that touches the router.

**One-time baseline floor** (closes the never-edited-router gap — a stable router accumulates the most
un-probed traffic): existing routing/gate skills get **one** baseline Step-0.5 probe at the next
`harness-doctor` run (the 30-day cadence already enumerates skills), then opportunistic-on-edit thereafter
— a single baseline pass, not a recurring sweep.

**"routing/gate skill" (mechanical test)**: a skill whose *primary output is a dispatch decision or a
pass/block verdict* — e.g. `agent-composer`, `goal-quench`, `asset-placement-gate`, `return-path-gate`,
`phantom-quench` — NOT a skill that merely calls others as sub-steps (e.g. `harvest-loop`).

---

## §Cross-Family-Complement

Execution detail for CLAUDE.md §FH Improvement 4-Axis Auto-Gate → *Cross-family complement*. The rule
that a load-bearing change recruits ≥1 different-family auditor, that it is autonomous once consented,
and that the governor keeps the terminal verdict + source-grounds every finding — all stay in CLAUDE.md.

**Sidecar mapping (per the UAP)** — pick by task class, not by preference:

| Task class | Recruit | Why |
|---|---|---|
| Repo-grounded code / security audit | `codex` (`gpt-5.5`, xhigh) | reads the actual tree; strongest on verdict-code logic |
| Breadth / multimodal / frontier scan | `agy` (Gemini) | wide recall, video + image ingest |
| Batch / free-tier arm | local 4090 over Tailscale | no token cost; weaker judge — anchor it |

**Degrade**: when no different-family auditor is reachable, say so and fall back to single-session — but
note the exception in §Field-Harness Load-Bearing Change Gate, where an unreachable cross-family panel is
**NOT-CONVERGED** rather than a silent same-family pass (that surface is pre-merge and irreversible-adjacent).

**Dogfood evidence (2026-06-27)**: a cross-family pass caught a HIGH execution-side-effect blind spot that
the same-family reviewers **and** the target-tier sim all shared. That is the decorrelation value made
concrete: the miss was not a depth failure (the sim ran at the right tier) but a *correlation* failure —
every reviewer in the Claude family read the change the same optimistic way. Decorrelation is the only
lever that moves a correlated blind spot; more same-family review does not.

---

## §Destructive-Op-Hook-Coverage

Execution detail for CLAUDE.md §Destructive-Op Gate. The **order invariant** (enumerate → recover →
destroy), the **3 steps**, the `DESTRUCTIVE_OP_OK=1` override, and the **fail-closed degrade direction**
stay in CLAUDE.md — they are load-bearing every session. What follows is the mechanics + honest scope.

**Per-ref verdict (pre-push hook)**: the hook detects the destructive refspec on stdin — *delete* = local
SHA all-zeros; *force* = remote SHA not an ancestor of local — then judges each ref:

| Ref state | Verdict | Hook action |
|---|---|---|
| Branch delete, fully merged | SAFE | allowed |
| Branch delete, commits off base + 0 unique paths | CHECK | **blocked** — needs a judged content look |
| Branch delete, unique paths present | REVIEW | **blocked** — recovery mandatory |
| Force / non-ff push | — | **always blocked** |
| Tag / notes delete | — | **always blocked** |

The verdict is load-bearing, not decorative: a merged-branch cleanup passes, a silent-loss CHECK does not.
This is the enumerate step as a mechanical floor rather than prose.

**What it does and does NOT close (honest)**: it closes the **honest-weak-model** gap — an agent that
simply *forgot* the prose gate is now mechanically stopped. It does **not** close the
**injected/adversarial** gap: an agent under instruction can set the override or pass `--no-verify`, and a
client-side hook is readable and bypassable by design. The hard floor for the adversarial case is
**server-side branch protection** (GitHub *Restrict deletions* / *Restrict force pushes*) — this hook is
the honest-model floor, branch protection is the hard floor.

**Scope**: covers only git pushes *from a hook-installed repo*. `npm publish` is mechanized separately via
`prepublishOnly` (see §Pre-Publish-Hook-Coverage (c)); the remaining non-git surface — a separate-repo
`gh repo create --public` / visibility flip — is genuinely un-hookable and stays prose +
`PRE-PUBLISH-CHECKLIST.md`.

**Portability defect class**: the hook is bash-3.2 safe (macOS default `/bin/bash`). The original draft
used a bash-4 associative array that crashed **fail-OPEN** on 3.2 — caught in test. Worth naming: a
portability break in a gate degrades toward permissive unless the gate is written to fail closed on its
own errors.

**Origin (2026-06-10 branch cleanup)**: pre-deletion enumeration recovered a parallel session's card
(weekly-audit completion + #88 merge state) that existed **only on an unmerged branch** with zero unique
paths — exactly the CHECK class, and invisible to "is it merged?" intuition. Deletion without the gate
destroys live state without anyone noticing. This is why the loss class is called *silent*.

---

### Scholarly deposit (Zenodo / DOI / arXiv) — measured 2026-09-07, why Step 1b exists

Two things happened on the same day, on the same record (`10.5281/zenodo.22542168`, v1.0.1):

1. **Form ≠ server.** The rich-text description and the companion-DOI related identifier were visible
   in the deposit form and **absent** from `/api/records/<id>/draft`. The editor had not flushed its
   state to the server. Nothing in the Pre-Publish gate covered this surface; a hand API read caught it
   minutes before Publish.
2. **The machine fields outlive the PDF.** v1.0.1 is a *corrective* release: its body fixes eleven
   misattributed references. Its Zenodo `references` field still carried **all eleven** pre-correction
   attributions — the exact strings the release existed to retract — because the PDF was replaced and
   the metadata was not. `references` / `related identifiers` are what DataCite and citation graphs
   consume; the PDF is what a human opens. Fixed by editing the record (22 → 24 entries, verified
   server-side, DOI unchanged).

Consequences that became the four Step 1b items: read the draft through the **service's** API (Zenodo
InvenioRDM `/api/records/<id>/draft`, legacy `/api/deposit/depositions/<id>`, figshare
`/v2/account/articles/<id>`), compare against the text you pasted (string vs JSON), md5 the file, and
on a corrective release diff the machine fields too. The post-publish read is a **detector**, not a
gate — a wrong field there is fixed by a new corrective version, never silently.

Salience check (same day, floor tier, blind, reps 3, one variable — the edited text injected into a
clean clone via `--setup`): before 0–1/3 → after 3/3 on all four items. ⚠️ The first sim run was void:
`sim_isolated_run.sh` clones **HEAD**, so uncommitted edits were absent from every arm — it measured
the pre-change tree. Recorded so the next author injects the working tree instead of trusting the clone.

## §Pre-Publish-Hook-Coverage

**Hook coverage — three distinct actions** (refined 2026-06-17 for (a)/(b); (c) added 2026-06-27):
- **(a) repo-go-public** (`gh repo create --public` / a visibility flip) is irreversible and usually in a
  **separate repo** — the FH pre-commit hook **cannot** catch it. That stays **AI-behavioral** (proactive
  trigger) **+ a portable checklist** (`templates/PRE-PUBLISH-CHECKLIST.md`), run on any repo/machine.
- **(b) committing operator-private tokens into public-tracked content of THIS repo IS an effective
  publish of that content** — and that the pre-commit hook **now catches mechanically**: a
  **confidentiality scan** of staged tracked *added* lines against the gitignored
  `.public-surface-patterns` (companion-store names · corp-context framing · home paths · company assets),
  blocking HIGH/MED + non-allowlisted LOW drift; `PUBLIC_SURFACE_OK=1` overrides for a deliberate reviewed
  mention. **Two-layer** (mirrors `/public-surface-audit`): the literal tokens live ONLY in the gitignored
  source — CLAUDE.md and the hook name **only categories**, never the literals (they would leak what they
  guard). This closes the gap where the prose publish-trigger was **missed on a weaker-tier session**
  (PR #109: a companion-store name + corp-context framing reached a public PR; the Sonnet session trusted a
  PR comment over the file content). The scan fires at commit time and is **tier-independent — but only as
  strong as the loaded patterns**: a COMMITTED `.public-surface-patterns.defaults` (universal patterns:
  home paths) keeps it from ever being fully blind, while the company-specific literals require the
  GITIGNORED override to be populated in each authoring env (esp. the company env, where company-origin
  public PRs are written; absent override → only defaults run, with a loud warning). **Honest scope**:
  plaintext only (encoded tokens out of scope); a line-split backstop catches a token wrapped across
  lines; `PUBLIC_SURFACE_OK=1` overrides and is logged to a gitignored audit trail for the weekly audit.
  Residuals (split-encoding, override-not-populated, override abuse) are documented, not silent.
  **Verdict labelling (2026-08-06)**: with the override absent, a clean scan reports
  `⚠️ PARTIAL — company/companion literals UNMEASURED`, **never `✅ PASS`**. The commit still
  proceeds (reversible surface → advisory degrade), but a run whose operator-literal layer never
  executed may not present the same verdict as one where it did — a missing measurement is not a
  zero. Anchored in `universal_guard_check.sh` as a **pair**: absent override must say `PARTIAL`,
  and the control (override present, no hit) must still say `✅ PASS`, so the label cannot drift
  back to a bare PASS *or* become an unconditional warning.
- **(c) `npm publish`** — mechanically gated by `scripts/public_surface_scan_files.sh`, wired into
  `prepublishOnly` (`npm run release` also runs it *outside* the lifecycle). Unlike (b) it scans the
  **full content of the exact npm-published file set** (`npm pack --dry-run`), *not* a commit diff — so a
  token committed **before the scan existed**, or carried in a `files[]` entry, is still caught at the
  registry boundary. HIGH/MED block; `PUBLIC_SURFACE_OK=1` overrides + logs. **Fail-closed** when patterns
  or the file set are unresolved, when the parse looks partial, **or when the gitignored operator override
  is absent** — defaults-only would otherwise green-PASS a HIGH company literal on a fresh clone or CI runner.

**The git-push surface, and why it was the lenient one (2026-08-06).** (c) blocked on an absent
override; the `git push` gate in `templates/.git-hooks/pre-push` only warned. Both make content
public, so two irreversible surfaces were degrading in **opposite directions on the same state** —
the actual defect, and `git push` (the one nobody publishes through deliberately) was the permissive
side. The 2026-07-26 reasoning behind that warn was not wrong, it was **unscoped**: an absent
override in a fresh clone / CI runner / worktree is a legitimate per-operator configuration gap (the
file is gitignored, so it is absent there *by construction*), and blocking it trains
`PUBLIC_SURFACE_OK` into a reflex — which disarms the same channel the publish gate depends on.

So the warn is **scoped, not reverted**. `psa_detect_operator_context` (`scripts/psa_scan_lib.sh`)
splits the state: in an **operator-configured checkout** an absent override is *evidence missing
where evidence is expected* → BLOCK; everywhere else → WARN, exactly as before. The signal is
`CLAUDE.local.md`, the operator's own gitignored binding file.

**Calibration matters here more than the rule** — a second candidate signal, "`tracks/_meta` is
non-empty", reads as the same test and is not: `tracks/_meta/.gitkeep` and one sibling are
**tracked**, so a fresh clone satisfies it and would have been blocked, re-shipping the 07-26
over-block under a new name. It was rejected by measuring it against a known pair, not by reasoning
about it. **Named residual, deliberately in the under-blocking direction**: an operator who never
created a `CLAUDE.local.md` stays in the WARN arm. **Second residual, and it is the sharper one**:
deleting `CLAUDE.local.md` drops this checkout back into the WARN arm, and unlike `PUBLIC_SURFACE_OK=1`
that bypass **writes no log line**. It is a conscious act on the operator's own file, so it is not a
weak-model fail-open — but it is a quieter exit than the sanctioned one, which is the wrong ordering
for a bypass. Not closed here: making it loud means the hook must distinguish "never had one" from
"had one and lost it", and that needs state the hook does not currently keep. Named rather than
mechanized, per this repo's own threshold — mechanize on the first measured recurrence.
Anchored as a pair in `prepush_guard_check.sh`
(6-a absent override → PASS · 6-b absent override + operator checkout → BLOCK); both arms are
required, since 6-b passing alone would not distinguish a scoped block from a blanket one.

**Named residuals for (c)** — it is a denylist **on the npm CLI path with scripts enabled**, not a
universal secret-scanner:

| # | Residual | Mitigation |
|---|---|---|
| i | `npm publish --ignore-scripts`, a CI `.npmrc` with `ignore-scripts=true`, or `pnpm`/`yarn publish` **skip the lifecycle hook entirely** | route publishes through `npm run release`, or add an explicit CI scan step |
| ii | scans only the **loaded patterns** — an **un-patterned secret shape** (an API key the patterns don't describe) still ships | pattern coverage is the limit; pair with a real secret-scanner if that shape matters |
| iii | on a runner without the gitignored override it is **defaults-only** unless populated | populate the override in each authoring env (esp. the company env) |
| iv | scans **working-tree content, not the final tarball bytes** | benign today (content-neutral lifecycle: prepare=chmod, no prepack) — **re-open if a content-generating publish lifecycle is added** (cross-family audit 2026-06-27) |

> Origin: 2026-06-05 `phantom-gate` shipped public, then needed a private→de-company-scrub→re-public
> round-trip (`fh_signal_2026-06-05_fh-direct`). PSA existed but nothing forced it pre-publish. 2026-06-17
> (PR #109): the commit-time half (b) became a mechanical hook after a weaker-tier session leaked a
> companion-store name onto a public PR (`fh_signal_2026-06-17` Wave 4).

---

## §Open-PR-Sweep-Origin

Why the open-PR sweep is a close step: the harness's "마감" ≠ the operator's "마감" — a self-authored PR
(PR #111) sat open across sessions with un-integrated skills + count drift because no close step surfaced
it. Pairs with the count-consistency check (which now runs at BOTH the local pre-commit hook AND the
`plugins/**` PR-CI merge boundary): the sweep surfaces the PR → merging it → the count-check catches any
drift at the merge (`fh_signal_2026-06-21`, gate-locality paired fix).

---

## §Session-Close-npm-Freshness

The **same bump MUST propagate in lockstep** to every `.claude-plugin/plugin.json` +
`.claude-plugin/marketplace.json` version (single-source = `package.json`). The Codex plugin loader keys
its cache path on the *plugin.json* version (`~/.codex/plugins/cache/forge-harness/{plugin}/{version}/`),
so a frozen plugin.json serves **stale cached skills to Codex/AGENTS.md users** even after content ships
(this exact 3-way drift — fh-meta 1.4.1/1.4.11 vs npm 1.4.32 — was found + fixed 2026-06-17). Then
Pre-Publish Surface Gate (`/public-surface-audit` + `/marketplace-gate` Check 5) + `npm publish` +
**`git tag vX.Y.Z` on the bump commit + `git push origin vX.Y.Z`** (tag at publish time, in lockstep with
the version — keeps git tags aligned with npmjs.com so Releases/Tags never drift). The npm-served README
and shipped skills/agents freeze at publish time, so updating FH assets without republishing leaves the
package stale. **Tag drift caveat**: when a bump rides inside a functional commit (no explicit "bump"
commit), tag *that* commit — otherwise the version ships to npm untagged (e.g. 1.4.4/1.4.5 shipped
untagged, backfilled 2026-06-08).

**Entry-point content drift (④-b drift-check — orthogonal to the version cache above).** The plugin.json
version keys the *cache path*, so bumping it forces Codex to refetch — that closes the **stale-cache**
axis. It does **not** close a second, orthogonal axis: `AGENTS.md` / `docs/codex-compat.md` are the
Codex-user entry points, and their *prose* must mirror whatever CLAUDE.md/knowledge change triggered the
republish. A version-only bump invalidates the cache yet still serves an AGENTS.md that never absorbed the
change — **version fresh, entry point stale** (the Codex-side face of `[[feedback_gate_locality_principle]]`:
a gate/pointer is only as fresh as the surface the actor actually reads). So ④-b greps whether the changed
topic touches a mirrored AGENTS.md/codex-compat section → sync it, else record `drift:none`. Mechanical
grep, ~0 cost. **Mechanically *emitted*, judged-*determined* (honest scope)**:
`scripts/session_close_check.sh` ④-b-drift auto-fires a drift-*candidate* warning when a shipped
CLAUDE.md/knowledge path changed but the Codex entry points (`AGENTS.md`/`docs/codex-compat`) did not.
What is mechanized is the *reminder* — it no longer depends on the runner remembering to look (that half
of the old "prose-only" gap is closed). What is **not** mechanized is the *parity determination*: the
script tests file **co-occurrence**, not topical parity, so it (a) can false-positive when the changed
path doesn't actually mirror an entry-point section, and (b) can false-negative if AGENTS.md was touched
for an unrelated reason in the same tag range. So the runner still judges each candidate (sync it, else
record `drift:none`) — the script flags, it does not *catch*. Origin: 2026-07-13 the close chain
lockstep-bumped v1.4.56/57 but only an operator question ("코덱스 호환성도 자동?") confirmed AGENTS.md was
clean — the chain never auto-checked it (`fh_signal_2026-07-13_self-dev` S3).

**Why the check is BIDIRECTIONAL (added 2026-07-19 — relocated here from always-loaded CLAUDE.md
2026-07-20).** The drift check originally fired in one direction only: *CLAUDE.md/knowledge changed but
AGENTS.md did not*. That is half a check, and a real miss travelled **exactly the unwired way**: a field
harness's boundary-crossing behavior rules landed in `AGENTS.md` **only**, leaving Claude Code sessions
unaware of a rule whose violation destroys a downstream harness's identity. The asymmetry was invisible
precisely because the wired direction kept passing.

The root reason both directions are required: **the two entry points are read by different runtimes.**
`CLAUDE.md`/`knowledge/` → Claude Code; `AGENTS.md`/`docs/codex-compat` → Codex, OpenCode, and other
non-CC runtimes. A rule living in only one of them is **invisible to the other**, and which direction the
next miss travels is not predictable — so a one-directional check is not "most of the coverage", it is a
coin flip. `session_close_check.sh` now fires a candidate in both directions (`_ENTRY_CC` / `_ENTRY_CX`);
the honest-scope caveat above (mechanically *emitted*, judged-*determined*) applies unchanged to both.

---

## §Session-Close-Handoff-Lifecycle

**(a) Stamp the run-handoff (④-c owns this write)** — any `"run this / start here"` run-handoff whose
result has now landed gets a header `STATUS: SUPERSEDED by <repo-relative-or-companion path> (<date>)`
(path resolvable from a fresh checkout; or retire the file). Not a Destructive-Op — a one-line header
edit, no deletion.

**(b) Flag the matching card carry item as resolved** — note it for ⑤ to act on. ⑤ **owns the card write**
(card-last guard): a finished run must not survive as a pending *carry/priority* item — ⑤ removes it from
the active carry list (recording it under "done this session" if the card keeps a done log). ④-c does
**not** edit the card itself (avoids a double-write / a flip-vs-remove conflict with ⑤'s removal
obligation) — it surfaces the resolution so ⑤ closes it.

**Why its own step**: cross-machine continuity works only when *durable* artifacts are current — the
session that ran the work holds completion as **live context**, but a fresh machine inherits only the
durable card + handoff, never that live context (origin: 2026-06-21 — a Windows session re-entered a
finished A6 run as "to run" because the Mac session that ran it never retired the NEXT_ACTION handoff /
flagged the carry item; live context didn't transfer, the stale artifacts did). The reader-side half —
read *result* files at session start, not only handoffs — lives in `modes_and_value.md` §Session-start
freshness + each operator's local session-start binding.

**Salience-dependent** — prose, not hook-enforced; on a weaker tier may silently not fire. Backstops: ⑤'s
removal obligation + the reader-side result-file read. A hook-enforced writer-side is a future hardening
candidate, not built today (keep the surface thin).

## §Mode-D-Model-Notice

The moment FH self-development work begins (= the gate's own activation trigger: an FH asset is about
to be modified), check the **session model** (self-identity; if the runtime withholds it, treat as
unknown) and surface **one line** — then proceed, never block:

- Model known and opus-tier or above → no notice (already optimal).
- Model known and below opus-tier → **dispatch-first** (Sonnet-Floor Doctrine 2026-07-10 — the
  primary recommendation keeps the Sonnet substrate and routes depth to dispatch; a session pin is
  the *secondary* option): *"이 작업은 FH 자체개발(Mode D)입니다 — Sonnet 그대로 진행하면서 깊이
  턴(적대검증·설계리뷰)은 사이드카/opus 디스패치로 커버하는 걸 권장합니다(동의 게이트:
  capability_escalation_consent). 세션 전체가 설계-깊이 중심이면 차선으로 `/model opus` 핀도
  가능합니다."*
- Model unknown (runtime withholds identity) → static fallback: *"FH 자체개발 작업입니다 — 세션
  모델이 opus 미만이면 깊이 턴을 디스패치로 커버하세요(권장); 설계-깊이 세션이면 `/model opus`
  핀이 차선입니다."*

**Guards**: once per session · advisory only — **never switch the session model** (human override is
inviolable; a pin is not a cap — tier-floor resolution §Floor governance) · field-project operation
sessions (no FH asset modification) never see this notice — the Sonnet default stays friction-free.

> **Related — capability-escalation consent**: whether a session actually *escalates* to a stronger
> model or a cross-family sidecar (not just this advisory notice) is governed separately by
> `knowledge/shared/harness-core/capability_escalation_consent.md` — the negotiated-consent protocol
> (UAP `sidecar_consent`/`floorup_consent`) that decides ask-once vs. no-surprise floor-up/sidecar use.
> This notice is the passive advisory; that doc is the active escalation gate.

---

## §Version-Digit-Policy — 어느 자릿수를 올리나 (CLAUDE.md §Session-Close ④-b 상세)

> **왜 여기 있나**: 이 판단은 **버전을 올릴 때만** 필요하다 — 매 세션 마감이 아니다.
> CLAUDE.md 는 규칙(3값 + 판별자 + `BREAKING (gate):` 의무)만 상주로 갖고, 아래 근거·판례를
> 여기서 읽는다. salience-split 2026-08-21.

🟥 **WHICH DIGIT — operator decision 2026-08-17, and it is deliberately NOT strict semver.**
There was no policy before this line, which is why one session proposed three different bumps
for the same delta on three different (and each individually defensible) grounds. Decide by
**what the number tells a reader**, not by whether anything technically broke:

| Bump | Reserved for (operator's own wording, 2026-08-17) |
|---|---|
| **major** `+1.0.0` | **any one of three**: ⓐ **완전히 새로 지음** — rebuilt from scratch, not extended · ⓑ **정체성이 확립됨** — 🟥 **다섯이 «전부» 🟢** 인 순간이지 하나가 🟢 로 올라선 순간이 아니다(운영자 결정 2026-08-21). 초판은 *"an identity of the five … actually standing 🟢"* 였고 **「하나만 초록이어도 major」로 읽혔다** — 실제로 그날 ②가 🟢 로 판정되면서 3.0.0 후보로 올라왔고, 그 애매함이 그때 닫혔다. 🟥 그리고 **정체성 등급은 npm 이 나르는 신호가 아니다** — 그건 `identity-v*` 계보의 사건이고, npm 이 또 나르면 같은 날 고친 「두 계보 한 이름」 결함을 번호에서 재생산한다. ⇒ major-ⓑ 는 **`identity-v1.0.0` 과 같은 사건**을 가리킨다 · ⓒ **기능이 혁신적으로 변경되거나 늘어남** — a capability *class* appears or is replaced, not a capability instance. 🟥 **Never** for tightening a gate that already existed |
| **minor** `+0.1.0` | 미들급 — new assets, new gate lanes, doctrine that changes behavior; **including changes that break a consumer's gate acceptance**, which then carry a mandatory `BREAKING (gate):` line |
| **patch** `+0.0.1` | 트리비아급 — fixes, wiring, docs that change no behavior |

**The discriminator between major-ⓒ and minor**: *class* vs *instance*. A sixth Wave-1 attack
angle is an instance → minor. An attack-angle **registry** where none existed is a class → major.
Today's delta is instances and tightenings throughout, which is why it is 2.1.0 and not 3.0.0
even though it breaks a gate acceptance.

**Why gate-tightenings are minor here, stated so it is not mistaken for hiding a break**: what
breaks is the **record format of a gitignored local marker**, not an API or the consumer's code;
the hook prints exactly what to write instead; and the blast radius needs the consumer to have
installed the hook AND be making a load-bearing change AND have used the specific old form.
Against that, strict semver would burn a major on every gate we tighten — this repo took 2.0.0
for a publish-freshness gate one day and would have taken 3.0.0 for a commit gate the next.
**A major number that arrives monthly stops meaning anything**, and the milestone it should be
reserved for would have no word left.

⚠️ **The condition that makes this honest, and it is not optional**: a minor that breaks gate
acceptance MUST carry `BREAKING (gate): <what now blocks> — <the one-line remedy>` in the
release description AND the CHANGELOG. Without it this policy is just burying breaks in minors.
**Applies from 2026-08-17 forward, not retroactively** (2.0.0 was the same class and is left
as-is rather than rewritten).

---

## §Branch-Protection-Two-Layers — 서버측 보호의 2층 구조와 세 번의 오판

> CLAUDE.md 는 결론만 상주로 갖는다: **통합 브랜치는 PR 전용 · 하드 플로어는 서버측 ·
> 브랜치 표면을 판정하려면 두 API 를 **모두** 읽어라.** 아래는 그 근거와, 한쪽만 읽어서
> 세 번 오판한 기록이다. salience-split 2026-08-21.

> **Two layers, and which one is the floor**: the **hard floor is server-side** — this repo now runs
> `enforce_admins: true` with `required_approving_review_count: 0` (set 2026-07-20; the count must be
> `0`, because enabling `enforce_admins` while it is `1` locks a solo operator out of merging their
> own PRs — self-approval is impossible). The hook is the **shift-left layer**: it fails at push time
> and prints the actual remedy, and it keeps holding if the server setting is ever relaxed. It is
> deliberately not the floor — a client-side hook is bypassable with `--no-verify`.
> *Origin*: before that change the server had `enforce_admins: false`, so an admin push *satisfied*
> the rule and merely printed `Bypassed rule violations` — a notice, not a block. A rule that
> announces its own bypass is not a floor.
> ✅ **Retraction — the server-side force-push surface is CLOSED, and the way it was misread is the
> durable part.** An earlier version of this block said `allow_force_pushes` on `main` was "still
> `true`", that two API writes "did not persist", and that the **server-side** history-rewrite
> surface therefore "remains open". The field reading was correct; the conclusion was not.
> **Branch protection is two independent layers — legacy protection and rulesets coexist, and the
> strictest wins** — so a field on the protection object is never the effective answer by itself.
> Measured on this repo 2026-08-09: `GET /repos/{owner}/{repo}/rules/branches/main` returns
> `non_fast_forward` from ruleset `main-no-force-push` — `enforcement: active`,
> `current_user_can_bypass: never`, `bypass_actors: []`, live since 2026-07-25 — while the legacy
> object still reports `allow_force_pushes: true`. The two API writes that "did not persist" were
> writing to the layer that does not govern *this* outcome while the stricter ruleset is active — not
> a layer that is inert in general: disable or retarget the ruleset and the legacy toggle governs
> again. **Read BOTH layers before declaring any branch surface open or closed** — `/rules/branches/
> {branch}` shows only what the *rulesets* impose, and `/branches/{branch}/protection` only what
> *legacy protection* imposes; neither is the effective view alone. A protection-object field read by
> itself misjudged this three times ([[reference_github_protection_two_layers]]).
> **Scope of the retraction, stated narrowly on purpose**: it covers *force-push / non-fast-forward*,
> which is what `non_fast_forward` blocks. Branch **deletion** is a separate rule and is closed on the
> other layer (`allow_deletions: false`, same GET). PR-routing is likewise a different field —
> `required_pull_request_reviews` present with `enforce_admins: true` — not something
> `required_status_checks` says anything about.
> ⚠️ A *different* residual on `main` is still real and must not be folded into the one just
> retracted — but the residual's own description was itself stale and needed correction on
> 2026-08-12 (live re-check, `[[reference_github_protection_two_layers]]`): legacy
> `required_status_checks.contexts` is **`["validate", "new-code-anchor"]`**, not `[]` — 🟥 re-read
> 2026-09-17 (both layers): the 2026-08-12 line said `["validate"]` and that had gone stale once
> `new-code-anchor` was promoted; a green `validate` AND a green `new-code-anchor` are required
> before a PR can merge, and `GET /rules/branches/main` carries only `non_fast_forward` — no
> competing `required_status_checks` rule, so the legacy field is the effective one here. `validate`
> (`.github/workflows/validate.yml`) is a **separate job from Axis 1** (`regression-guard.yml`) —
> Axis 1 is still not required, see the 4-axis section below. 🟥 But since 2026-08-29 (#552) Axis 1
> **does run** on every 4-axis asset class (its `paths:` was widened); the remaining gap is
> "runs but not required", not "does not run". The gap on `validate` is
> `strict: false`: that check re-runs on every push to the PR branch, but nothing re-forces it
> against a **moving** main after it last ran — so a check that passed can still land behind
> concurrent merges it never saw.

---

## §CM-Reinvention-External-Number — Reinvention reflex — external family-level number (moved from CLAUDE.md)

> Relocated **verbatim** from `CLAUDE.md` (§Envelope-Boundary Discipline) on 2026-09-26 — resident-size diet. The resident text kept the rule and a pointer here; this section keeps the why / evidence layer. Nothing was reworded.

**External, family-level number (2026-09-04, digest `HN:49557206`, armature.tech, 5,292 valid sessions)**: Claude Code built in-house instead of adopting an existing tool in **19 %** of sessions vs **10 %** for Codex and Cursor — ≈2× its peers. The reflex this section counterweights is a measured family bias, not a local habit; the one-session 3× above is the internal instance of it.

(Measured 2026-07-14, one session, 3×: two identities each collapsed
onto their single hardest sub-mechanism, and a failure from a **non-harness** run mapped onto a harness
metric — each read a live-but-incomplete thing as zero, each caught by the operator, not self-caught.
Detail: `[[feedback_reinvention_reflex_normalization_counterweight]]`.)


---

## §CM-Declined-Grounds-Honesty — The `declined`-grounds lane is a channel with a small frozen judgment (moved from CLAUDE.md)

> Relocated **verbatim** from `CLAUDE.md` (§Mechanization Boundary) on 2026-09-26 — resident-size diet. The resident text kept the rule and a pointer here; this section keeps the why / evidence layer. Nothing was reworded.

⚠️ **Applied honestly to this file's own machinery, same day**: the `declined`-grounds lane added to
`templates/.git-hooks/pre-commit` is a **channel** check (a claim must name attributable grounds) —
it does not judge whether decorrelation was warranted. But its grounds test is a *vocabulary grep*,
and a vocabulary list is a small frozen judgment: a legitimately-phrased `declined` in unforeseen
wording over-blocks. Accepted because the failure is **loud and cheap** (author rephrases) rather
than silent, and because it mirrors the existing degrade-branch form — named here rather than
claimed pure.


---

## §CM-Local-Execution-Evidence — Why «to completion» is operative — the pmh-dev case (moved from CLAUDE.md)

> Relocated **verbatim** from `CLAUDE.md` (§Local Execution First) on 2026-09-26 — resident-size diet. The resident text kept the rule and a pointer here; this section keeps the why / evidence layer. Nothing was reworded.

**Why "to completion" is the operative phrase** (measured 2026-08-16, pmh-dev): that repo's
`validate.yml` was wired the same day, so CI's first run was the suite's first real execution ever —
there was no "previously known-good" for it to confirm. A partial local run would have missed it too:
the suite printed `SELFCHECK: FAIL` while **neither `FAIL` nor `❌` appeared anywhere in its output**
(the failing lane used its own vocabulary, `INSTRUMENT ERROR`), so locating it needed `bash -x` to
the actual failing line. Reading the tail, grepping for the expected token, or trusting an exit code
you did not trace are all forms of not-running-it.

**Operator, 2026-08-16**: *"이 실패가 CI 확인 단계에서야 발견되는 건 매우 늦다 … 로컬에서 그
[대상 레포]를 통해서 실제로 구동시켜 봤다면 안 발생했을까"* and *"CI 확인도 중요하지만 사실 이는
**깃헙의 기능에 기대는 것**이라고 봐야 하려나."*

Both halves are load-bearing. **Late**: a red CI check is discovery at the slowest, most expensive
point in the loop, after push, after the PR, in front of an audience. **Borrowed**: CI is a
*platform* feature, so a harness that only finds its own defects there has not built a gate — it has
outsourced one, and it silently inherits that platform's coverage boundaries as its own.


---

## §CM-Skeleton-Retraction — The retracted `tier1b` sim numbers (moved from CLAUDE.md)

> Relocated **verbatim** from `CLAUDE.md` (§Skeleton, Not Muscle) on 2026-09-26 — resident-size diet. The resident text kept the rule and a pointer here; this section keeps the why / evidence layer. Nothing was reworded.

🟥 **RETRACTED (2026-08-17) — the numbers this paragraph used to cite are withdrawn, in BOTH
directions.** It read: *"Two independent blind Sonnet sims then graded a pure cold-read as `tier2`,
**0/2** … A static read of my own fix would have scored it PASS. Only running it found the hole."*
That sim set was **8 runs at `tool_uses: 0`** — the agents never opened a file, so the instrument
was dead and the grades measure nothing (`tracks/_meta/fh_completed_2026-08-16.md:690`, retracted
the same day the doctrine was written and **before** this paragraph's own commit). The re-run with a
live instrument then landed the **opposite** result — the rung was graded correctly — at **reps=1**,
below this repo's own `reps>=3` bar. **So neither «it failed» nor «it worked» is established.** Do
not restore either number, and do not read the retraction as proof of the inverse.

**Why «reads correctly» is not evidence.** A `tier1b` rung was added to the `standpoint:` enum
precisely so a static review would stop being recorded as `tier2`. The text was correct; a reader
would agree — and a reader agreeing is not a measurement, which is this paragraph's whole point.

**The claim that survives is narrower and does not need those numbers**: a static read cannot
establish that a rule *fires*, because the thing being tested is whether a reader who is not the
author lands on the right rung — and the author reading their own text is the one reader guaranteed
to. That is an argument about what a read can measure, not a measurement. The general principle
(`field_verdict_crossfamily_gate.md §7`'s execution-over-static asymmetry) rests on its own separate
field evidence; **this paragraph is no longer one of its data points.**


---

## §CM-Clawd-Existence-Proof — Existence proof — clawd-on-desk PR #888 (moved from CLAUDE.md)

> Relocated **verbatim** from `CLAUDE.md` (§Skeleton, Not Muscle) on 2026-09-26 — resident-size diet. The resident text kept the rule and a pointer here; this section keeps the why / evidence layer. Nothing was reworded.

**Existence proof, ours, this session**: *"우리가 최근에 클로드온데스크에 기여한 것처럼."*
`rullerzhou-afk/clawd-on-desk` PR #888 was merged **exactly as submitted, with no changes
requested** — the owner's words: *"focused, technically sound, and well-tested … we merged it
exactly as submitted, with no changes needed."* That is the shape: the mechanical case was closed
before submission (a fixture whose potency was reasoned about in-comment, a lane that re-executes
the real consumer path rather than asserting a flag), so nothing was left to negotiate but whether
they wanted it. **This is the bar to hold ourselves to on every outbound PR**, and it is why the
survivor-lane technique from that same PR is worth absorbing rather than admiring
(`tracks/_meta/fh_signal_2026-08-16_clawd-survivor-lane-air.md`).


---

## §CM-Calibration-Why-Resident — Why Instrument Calibration is resident — 2026-07-20 (moved from CLAUDE.md)

> Relocated **verbatim** from `CLAUDE.md` (§Instrument Calibration) on 2026-09-26 — resident-size diet. The resident text kept the rule and a pointer here; this section keeps the why / evidence layer. Nothing was reworded.

**Why resident**: the trigger is *intent* ("I am about to trust / publish this output"), not a file, and
**no hook can catch it** — there is no mechanical backstop by nature, so salience is the only layer.
(Measured 2026-07-20, one session, 3×: an always-loaded footprint scan that omitted 61% of the surface ·
an index/file **size ratio** used as a proxy for content coverage · an **ASCII-token scanner run over a
Korean corpus** → ~96% false positives, whose "77 items / 70%" was published into three records before a
single hand-check collapsed it to **3**. Each was caught by looking at one real case.)

(Closed 2026-07-20 by a
   known-pair sim that found this loophole; the session that wrote the rule had itself leaked its bad
   "70%" into conversation before any file.)


---

## §CM-4Axis-Server-Side-Residual — 4축 게이트의 서버측 잔여 — 필수 체크 · Axis 1 · 원격 노드 (CLAUDE.md 에서 이관)

> Relocated **verbatim** from `CLAUDE.md` (§FH Improvement 4-Axis Auto-Gate) on 2026-09-26 — resident-size diet. The resident text kept the rule and a pointer here; this section keeps the why / evidence layer. Nothing was reworded.

**그리고 서버측 검증엔 남은 잔여가 있다(2026-08-12 재확인 — `contexts=[]` 서술은 stale, 정정됨)**: `main` 은 `enforce_admins: true` 로 **푸시 경로**(PR 경유)를 강제하고, legacy `required_status_checks.contexts` 는 **`["validate", "new-code-anchor"]`** 다(2026-09-17 두 층 직독 — rulesets 층은 `non_fast_forward` 하나뿐) — `validate` 잡(`.github/workflows/validate.yml`, 메타데이터·`selfcheck.sh` 배선 레인)과 `new-code-anchor` 가 실제 **필수 체크**다. ⚠️ **`validate` 는 Axis 1 이 아니다** — Axis 1(`regression-guard.yml` → `templates/regression_guard.sh`)은 **여전히 필수 체크가 아니다**(빨개도 머지를 못 막는다). 🟥 **다만 «돌지도 않는다» 는 2026-09-17 부로 거짓이다 — 정정.** 이 줄은 «그 워크플로의 `paths:` 가 `SKILL.md`·`.claude/rules/*.md`·`CLAUDE.md`·`templates/*.md` 만 보므로 `knowledge/`·`docs/`·`AGENTS.md`·`scripts/**`·에이전트 정의만 바뀐 PR 에는 Axis 1 자체가 돌지도 않는다» 고 적고 있었는데, **`paths:` 는 2026-08-29(`d5fceac`, #552)에 4축 대상 클래스 전부를 덮도록 넓어졌고**(추가분 = `knowledge/**/*.md` · `docs/*.md` · `AGENTS.md` · `scripts/**` · `templates/.git-hooks/*` · `plugins/*/agents/*.md` · `.claude/agents/**/*.md` · `README*.md` · `CHEATSHEET.md` · `CATALOG.md` · `.github/workflows/*.yml` · `.claude/registry/*.md` · `package.json` — 기존 `SKILL.md`·`.claude/rules/*.md`·`CLAUDE.md`·`templates/*.md`·`templates/regression_guard.sh` 위에) 이 문장만 19일간 안 따라갔다. 실측: `scripts/`·`package.json`·`bin/` 만 바뀐 PR #745 에서 Axis 1 이 **실제로 돌아 통과**했다(run 35227853301, `REGRESSION_GUARD_RESULT=pass`). 🟥 **그리고 그 낡은 문장이 같은 날 기록 셋(커밋 메시지·마커·매니페스트)으로 그대로 전파됐다** — 상주층의 낡은 주장은 읽는 세션이 «확인» 대신 «인용» 하는 순간 번진다([[feedback_half_fix_propagation_boundary]] · 정정면 = PR #745 코멘트). 남는 갭은 이제 «안 돈다» 가 아니라 **«돌지만 필수가 아니다»** 하나다. `validate` 쪽 남은 갭은 `strict: false`: 그 체크는 PR 브랜치에 푸시할 때마다 재실행되지만(오픈 시점 한정이 아니다), 그 뒤 main 이 움직여도 재검증을 강제하지 않으므로 **초록으로 남아 있는 체크가 실제로 병합되는 최신 트리를 본 적이 없을 수 있다.** 즉 서버가 강제하는 건 *체크가 초록인가*지 *그 체크가 지금의 main 을 봤는가*가 아니다. Axes 2–3(마커)·Axis 4(매니페스트)는 그 파일들이 `tracks/**` 로 gitignored 라 CI 가 **구조적으로 볼 수조차 없다**. 🟥 **그 사각이 실제로 뚫렸다(2026-09-14 실측, 2/2)** — 원격 자율 노드(`claude/*` 브랜치, 클라우드 세션)는 체크아웃이 휘발해서 마커가 **아무 데도 안 남는다**. 머지된 `claude/` 접두사 PR 전수 **#675·#716 둘 다** FH 자산을 바꾸고 마커 없이 **초록으로** 들어왔다. ⇒ `scripts/remote_marker_gate.sh` 가 **그 채널에 한해** «마커 3필드(`axes-run`·`crossfamily`·`standpoint`)가 커밋 기록에 실려 왔나» 를 `validate` 에서 막는다(레인 14 · 되돌림 프로브 포함). 보통 브랜치는 pre-commit 이 이미 관할하므로 **SKIP** 이다 — 만족 불가능한 이중 요구는 override 를 훈련시킨다. 🟥 **닫은 것은 «조용한 부재» 하나다**: 검사는 형식만 보고(값의 진위도 enum 멤버십도 안 본다 — enum 정본은 저작 노드의 훅이다), 옮긴 마커와 지어낸 마커는 여전히 바이트가 같다. 정직한 표현은 "하드 차단"이 아니라 "**가용한 가장 강한 층**"이다. **미해결 잔여**: `strict` 를 켜는 것도, Axis 1 을 필수 체크로 거는 것도 운영자 결정이다(막 flaky 레인을 하나 기록한 참이라, 과차단이 override 를 습관화시키는 쪽으로 기울 수 있다). 🟢 «그 `paths:` 를 넓히는 것» 은 2026-08-29 에 이미 닫혔다 — 위 정정 참조.


---

## §CM-4Axis-Split-Measurement — 4축 절 분리 실측 — 2026-07-20 (CLAUDE.md 에서 이관)

> Relocated **verbatim** from `CLAUDE.md` (§FH Improvement 4-Axis Auto-Gate) on 2026-09-26 — resident-size diet. The resident text kept the rule and a pointer here; this section keeps the why / evidence layer. Nothing was reworded.

> (2026-07-20 분리. **파일 char 실측**: 이 절 자체가 76,706자 중 **10,331자(13.5%)**로 단일 최대였다. 그 분리 + 같은 세션의 중복 3건 제거 + New-Skill 게이트 편입까지 **합산**해 파일은 **76,706 → 67,611 (순감 9,095자, 11.9%)** — 합산치이지 이 절 하나의 성과가 아니다 — 이건 파일 크기지 `/context` 상주 실측이 아니다(계기≠대상, [[feedback_resident_memory_measured_fresh_toplevel]]: 상주는 톱레벨 새 세션 `/context` 로만 잰다 — 미측정). 트리거가 *파일*이고 *기계 백스톱*이 있어 1순위 후보였다. 같은 이유로 **비가역 게이트 3종은 이동 불가** — 의도 트리거라 경로 스코핑하면 fail-open 이 된다.)


---

## §CM-Chamber-Honesty-Boundary — Chamber honesty boundary — the old-vocabulary ledger (moved from CLAUDE.md)

> Relocated **verbatim** from `CLAUDE.md` (§Onboarding / Acceleration Autopilot) on 2026-09-26 — resident-size diet. The resident text kept the rule and a pointer here; this section keeps the why / evidence layer. Nothing was reworded.

Honesty boundary that must not soften in summary — **under the old vocabulary**, hand-counted
2026-08-08 from the run ledger: 9 full runs, **8 KILL, 1 EMIT** (13 runs · 11 KILL · 1 EMIT as of
2026-08-17). It has birthed **once** (run #9 `forge-wiki`, shipped publicly), so
"it has not birthed" — the earlier wording here — is no longer true. But do not upgrade the claim
either: that run's workspace carries only a verdict file, with no intent/budget/blind-persona
artifacts, so the **formal flow** is not what produced it. The first end-to-end formal run is #10 and
it KILLed. Either way simulate-first stays a one-line HITL recommendation, never a push-button
autonomous emit.
⚠️ **Do not cite that ratio as "the chamber screens well" or "over-screens" going forward** — the
counts were produced by a rule set that no longer runs, and whether it over-screened is **exactly
what the frozen known-pair exists to measure and has not measured yet.**


---

## §CM-Expedition-Evidence — 원정 1차 답습 — 채점 · 원인 · 주기 보류 근거 (CLAUDE.md 에서 이관)

> Relocated **verbatim** from `CLAUDE.md` (§Expedition (원정)) on 2026-09-26 — resident-size diet. The resident text kept the rule and a pointer here; this section keeps the why / evidence layer. Nothing was reworded.

**근거 — 이 규칙은 실측에서 나왔다.** 원정 1차(2026-08-17)의 ⓐ 채점은 **0 건**이다(2026-08-18 답습,
사전등록 봉인 후 cross-family 독립 수렴). 원인은 노력이 아니라 겨냥이었다: 세 갈래(기여·클러스터·약점)가
**전부 이미 🟢 인 정체성**(Ⓑ·①·③) 위에 떨어졌고, **비-🟢 인 ②·④ 를 건드린 산출이 하나도 없었다.**
즉 ⓐ=0 은 **개시 시점에 구조적으로 예정돼 있었다.** 정본: `tracks/_meta/expedition_2026-08-18_absorption1.md`.
🟥 ⓐ 를 «알아냈다»로 읽지 마라 — 완주선은 «알아냈나»가 맞지만 **ⓐ 는 «등급을 옮기는 조각»을 요구한다.**
두 정의를 섞으면 과계상이 된다(cross-family 지목, 자력 적발 0).

위 3단계를 다 밟았는데도 숫자가 안 나온다: ⓐ 비용 입력이 **부분 계상**이고(거버너 토큰·벽시계 미측정 —
1차 기록 §5 가 스스로 적었다) ⓑ 1차는 갈래가 셋이라 **대표성이 없으며** ⓒ 결정적으로 **겨냥이 틀린
원정 1회**라, 그 비용/수확비로 주기를 세우면 틀린 표본으로 스케줄을 만든다.

**Operator, agreed and recorded 2026-08-17** (it had been agreed verbally before and was **not in any
file** — grepped, zero hits; that gap is why this paragraph exists): *"원정이 가치 있고 성공적이었다면
**주기적으로 제안하는 것**으로 가기로 했었지."*

That gate
measures how often a proposal class is *accepted*, which is the wrong quantity here: an expedition
could be accepted every time and still not warrant a schedule, or be proposed once and clearly warrant
one. The evidence that sets the interval is the **completed run itself**, not an acceptance rate.


---

## §CM-Hygiene-Unmechanized — Why close step ④ has no mechanical check (moved from CLAUDE.md)

> Relocated **verbatim** from `CLAUDE.md` (§Session Wrap-up) on 2026-09-26 — resident-size diet. The resident text kept the rule and a pointer here; this section keeps the why / evidence layer. Nothing was reworded.

**Deliberately unmechanized, and stated so rather than left ambiguous**: hygiene is a judged
       step (is this entry still true?), and the only cheap proxy — "did any memory file change?" —
       would pass on a touched file. A check that can be satisfied without doing the work is a
       decoration that reports coverage it does not have. `session_close_check.sh` therefore carries
       NO ④ check; its similarly-numbered block is `④-log` (the real-time completion log) and is
       labelled as such. Revisit if skipped-hygiene is ever *measured* to recur — build on evidence,
       not on the discomfort of an unchecked step.


---

## §CM-Close-Atomic-Origin — Why close step ⑤ became atomic (moved from CLAUDE.md)

> Relocated **verbatim** from `CLAUDE.md` (§Session Wrap-up) on 2026-09-26 — resident-size diet. The resident text kept the rule and a pointer here; this section keeps the why / evidence layer. Nothing was reworded.

**Why ⑤ became atomic (N=3, 2026-07-28 — three closes in one day)**: the miss was always the same
shape — a finding surfaced *during* the close and the reflex appended it to `fh_completed`, which is
correct under ④ and fatal after ⑤. The three prose repairs ("next time write it into the card first")
all failed, including one session that stated the vow and then broke it in the same close. So the
sequence is restructured rather than re-promised: `fh_completed` is not a step that runs alongside ⑤,
it is the **first half of** ⑤. A close-time finding has exactly one landing order — log, then card —
and there is no remaining moment where appending is the natural move. *Honest scope*: this removes
the ordering ambiguity, not the reflex; the pre-push gate stays the floor, and on a violation it now
**names the offending files and prints their last lines** so re-running ⑤ is a delta, not a re-read.
The check also carries a **⑤-b card-drift probe** (advisory, never blocks): it cross-checks the
card's *absence claims* against on-disk reality (`session_close_check.sh` ⑤-b block) — surfaced
here because an implemented-and-lane-tested step that no spec document names is exactly the
orphan-implementation class the 2026-08-01 reverse-verification pilot flagged (P2-08).

*Why not block always*: ⑤ card-last is a close-time invariant, while ④ mandates writing `fh_completed_*` **during** the session — an unconditional block would pit the two rules against each other and train `--no-verify`, disarming the Destructive-Op gate in the same hook.


---

## §CM-Card-Loss-Evidence — 카드 재작성의 역방향 유실 — 실사고와 외부 근거 (CLAUDE.md 에서 이관)

> Relocated **verbatim** from `CLAUDE.md` (§Session Wrap-up) on 2026-09-26 — resident-size diet. The resident text kept the rule and a pointer here; this section keeps the why / evidence layer. Nothing was reworded.

이 방향은 오래 **한쪽만** 적혀 있었다(완료가 남는 것만 버그로) — 그래서 2026-08-24 에 미완 4건이 통째로 사라졌고, 그 세션은 «BEFORE 172 → AFTER 101» 이라는 diff 를 출력하고도 «줄었다」만 말했다.

외부 근거: 파일시스템 기억 연구(arXiv 2607.26637)가 «구조만 바꿔라」라고 지시한 재구성 에이전트는 응축하며 기록을 버렸고 한 벤치마크 정확도가 **77.6% → 41.2%** 로 반토막 났으며, *"keep every fact"* 한 줄을 더하자 내용이 대체로 고정됐다.


---

## §CM-Predelete-Mention-Evidence — `predelete_check.sh` is mentioned, never executed — measurement (moved from CLAUDE.md)

> Relocated **verbatim** from `CLAUDE.md` (§Destructive-Op Gate) on 2026-09-26 — resident-size diet. The resident text kept the rule and a pointer here; this section keeps the why / evidence layer. Nothing was reworded.

Measured 2026-08-20,
re-measured 2026-08-23 (control: the same scan finds `session_close_check` wired in that hook at
`:540`, as `_SC_OUT=$(bash "$REPO_ROOT/scripts/session_close_check.sh" …)`; known-negative: a nonsense
token returns rc=1, no hits): every in-repo reference to `predelete_check.sh` is a **mention, not an
execution** — `pre-push:423` lists the path inside a *grep pattern* (it was `:408` when this was first
measured; line numbers drift, the function names do not), `destructive_pre_gate.sh:191` *prints the
command* as advisory text, and `selfcheck.sh:192` runs `bash -n` on it.


---

## §CM-Governance-Axis-Numbers — Governance Engineering — the replaced arm numbers (moved from CLAUDE.md)

> Relocated **verbatim** from `CLAUDE.md` (§Identity) on 2026-09-26 — resident-size diet. The resident text kept the rule and a pointer here; this section keeps the why / evidence layer. Nothing was reworded.

Measured content, not a slogan — 🟥 **and the numbers were replaced 2026-09-17** (the earlier «five arms, 2.7 %–13.6 %» came from a scorer since found defective — it counted our own mandated defeater paragraphs as defect claims and dropped ~half of all claims out of the denominator — and it is **not re-scorable**, structurally): **four** arms ran **0.0 %–1.1 %** claim-error on the same eight cases, 95 % upper bound ≈2.1 %, and **no contrast separates** after cluster correction, so it is a spectrum and not a ranking. Every one usable on a review surface, **not one** usable on publish/delete/rewrite — and that holds *now that the point estimate is inside 0.x%*, which is the first time the second verb is testable rather than vacuous. That distance is why this axis exists.

Measured across **four** review arms on the same eight cases — 🟥 **the
earlier «five arms, 2.7 % – 13.6 %» from this date is RETRACTED (2026-09-17): the scorer was found
defective and replaced, and the old run is structurally not re-scorable. Canon:
`governance_engineering_definition.md` §첫 실증** — claim error rates ran **0.0 % – 1.1 %** (95 %
upper bound ≈2.1 %; **no contrast separates** after cluster correction, so it is a spectrum and not
a ranking), and every one of them is usable *on a review surface*, because a
wrong finding costs a reader a minute.


---

## §CM-Register-Residency — Why the register rule is resident — and has no floor (moved from CLAUDE.md)

> Relocated **verbatim** from `CLAUDE.md` (§Voice / Tone) on 2026-09-26 — resident-size diet. The resident text kept the rule and a pointer here; this section keeps the why / evidence layer. Nothing was reworded.

This rule
  lives in always-loaded CLAUDE.md, not only in memory, so it fires every turn without depending on
  recall — the 2026-07-12 miss was a session that drifted register because the rule lived only in memory.
  Tone has **no** mechanical hook gate by nature: always-loaded salience is the strongest available lever,
  **not a floor** (no mechanical floor exists for tone — an accepted limitation, not a guarantee).


---

## §CM-Capability-Exception-Scope — Why the capability-composition exception is scoped narrowly (moved from CLAUDE.md)

> Relocated **verbatim** from `CLAUDE.md` (§New Project Onboarding) on 2026-09-26 — resident-size diet. The resident text kept the rule and a pointer here; this section keeps the why / evidence layer. Nothing was reworded.

The exception is scoped to that surface on purpose. An earlier draft of this line qualified the
   whole sentence with "non-safety properties only", and an adversarial round showed that inverts it:
   an ordinary project rule ("run the linter first", "docs in Korean") matches none of the contract's
   eight capability axes, falls through its "unclassified → constraint" default, and therefore
   *outranks the hub* — the opposite of this line's intent. Worse, a project declaring a stricter
   `tier_floor` or `approval` would delete an FH floor (Sonnet-floor, autonomy floor) by being
   stricter.


---

## §CM-Salience-Residual-Surfaces — Which irreversible surfaces are hookable — the salience residual (moved from CLAUDE.md)

> Relocated **verbatim** from `CLAUDE.md` (§Irreversibility Gates) on 2026-09-26 — resident-size diet. The resident text kept the rule and a pointer here; this section keeps the why / evidence layer. Nothing was reworded.

**Salience residual** (corrected 2026-06-27 — the surfaces split, they are not uniformly un-hookable):
the **pre-commit** hook cannot catch either irreversible surface *at commit time*. But "pre-commit can't"
≠ "no hook can": the **Destructive-Op git surface** (remote branch delete · force/non-ff push) fires at
*push* time and **is** caught — `templates/.git-hooks/pre-push` now mechanically enforces the enumerate
(see §Destructive-Op Gate). **`npm publish`** is likewise caught — `scripts/public_surface_scan_files.sh`
wired into `prepublishOnly` scans the published file set at the registry boundary (see §Pre-Publish Hook
coverage (c)). What stays **genuinely un-hookable** is only the **separate-repo go-public surface**
(`gh repo create --public` / visibility flip / first push to a new public remote — not an npm or git op
against this repo, so no hook here sees it): for *that* surface the fail-closed direction is still **prose,
not hook-enforced** — a real weak-model fail-open risk, not a silent one. Backstop for the prose half: the
portable `templates/PRE-PUBLISH-CHECKLIST.md` carries the tooling-down item as a human-readable gate, and
the direction is target-tier-sim'd (Sonnet) before it is relied on.


---

## §CM-Destructive-Retraction-Why — Destructive-Op retraction — how it was written and why it stays resident (moved from CLAUDE.md)

> Relocated **verbatim** from `CLAUDE.md` (§Destructive-Op) on 2026-09-26 — resident-size diet. The resident text kept the rule and a pointer here; this section keeps the why / evidence layer. Nothing was reworded.

**Why it was written that way**: the next paragraph's 2026-08-20 correction landed *beside* this
sentence instead of *replacing* it, leaving two consecutive paragraphs contradicting each other in the
resident layer ([[feedback_half_fix_propagation_boundary]]).


---

## §CM-Initiative-Row-Misses — Initiative-table rows — the misses that created them (moved from CLAUDE.md)

> Relocated **verbatim** from `CLAUDE.md` (§Autonomous Initiative) on 2026-09-26 — resident-size diet. The resident text kept the rule and a pointer here; this section keeps the why / evidence layer. Nothing was reworded.

🟥 Missed 2026-08-16 on exactly this shape: an external red-team framework was installed, run against a field harness, found a real bypass — and was filed as a `type: reference` **tool pointer** with no sister audit at all

Missed once in-session while building `scripts/frontier_digest_autopilot.sh` 2026-08-15 — mis-routed to `fh-meta:harness-pr-reviewer` (same-repo self-consistency, a different lens) before the operator caught it; this row exists so the next session connects the trigger without two rounds of correction.


---

## §CM-Shared-Checkout-Incidents — 공유 체크아웃 실측 — claim 스냅샷과 2026-08-21 창 (CLAUDE.md 에서 이관)

> Relocated **verbatim** from `CLAUDE.md` (§AI Contribution) on 2026-09-26 — resident-size diet. The resident text kept the rule and a pointer here; this section keeps the why / evidence layer. Nothing was reworded.

(실측:
claim 이 `main` 인 동안 실제 HEAD 는 peer 브랜치였다 — 두 세션이 독립 재현)

(같은 날 두 세션이 시점을 각각 `switch` 직전/직후로
달리 골랐는데 **둘 다 뚫렸다**)


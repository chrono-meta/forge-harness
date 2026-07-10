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

## §Pre-Publish-Hook-Coverage

**Hook coverage — two distinct actions (refined 2026-06-17)**:
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

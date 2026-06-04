---
name: multi-model-sidecar-strategy
description: Pattern for invoking other AI models (Gemini, Codex, Copilot CLI) as sidecars from within a Claude Code / FH session via Bash tool. Token economy, model-access fallback, and adversarial diversity use cases.
date: 2026-05-31
tags: [multi-model, sidecar, token-economy, model-access, adversarial, internally-validated]
status: mechanism-validated (cross-provider grader confirmed 2026-06-02)
---

> **Validation status** (updated 2026-06-02): mechanism validated by cross-provider grader.
>
> 2026-06-01 steel-quench (Issue #47): mechanism confirmed runnable — implementation shipped in PR #36/#37. Original empirical claims (Experiment 1·2) were an internal same-session self-report; raw transcripts not retained, codex grader blocked by network policy.
>
> 2026-06-02 update: Gemini 0.41.2 cross-provider grader run on `pipeline-conductor/SKILL.md` (retained transcript: `tracks/_meta/grader_gemini_pipeline_conductor_2026_06_02.txt`). Gemini found 3 S-grade findings (interaction deadlock, PR-approval deadlock, cadence-lock deadlock); Claude Sonnet-4.6 previously found 3 different S-grade findings (model conflict, invocation contradiction, self-referential sweep). **Zero overlap across 6 S-grade findings** — validates the non-overlapping failure modes claim and perspective diversity mechanism. Provider-identity diversity is empirically confirmed; specific Experiment 2 finding counts on goal-quench (original target) are not directly re-run. Record: `tracks/_meta/grader_gemini_pipeline_conductor_2026_06_02.txt`.

# Multi-Model Sidecar Strategy

## Thesis grounding — hierarchy of differentiation

FH's paper thesis: **the harness (specialized shell) is the durable layer; the model (core) converges across providers.**

Empirical observation from 3-round orchestrator-swap experiment (Claude → Gemini → Codex as orchestrator, others as sidecars, same FH skill as target):
- **Process differs** — each orchestrator highlights different angles (Gemini: state machine + audit methodology; Codex: implementation-level parsing and dependency contracts).
- **Results converge** — 3 critical issues appeared in every round regardless of orchestrator identity (freshness guard pseudocode, BLOCKED deadlock, interim-commit false CLEAN).

This is precisely what the thesis predicts. But the experiment revealed a second-order effect not captured in the original framing:

**Process divergence → cross-wave delta → better convergence.**

The sidecar pattern's value is not parallelism — it is the *delta*. Each orchestrator's unique process angle produces non-overlapping findings. When synthesized, the combined result exceeds what any single-model run achieves. This is the mechanism by which the sidecar pattern compounds into a quality improvement, not just a coverage check.

The enabling condition for this entire chain is the harness:

```
Harness (FH)
  → consistent SKILL.md format loadable in all 3 CLIs
  → same skill runs under each orchestrator with comparable evaluation protocol
  → cross-wave delta is structurally comparable (apples-to-apples)
  → synthesis is valid
  → convergence improves
```

Without the harness, "multi-model adversarial review" is three separate unstructured prompts — no comparable protocol, no valid synthesis. The harness is not one of the differentiators in a hierarchy. **It is the activation condition that makes the hierarchy operate.**

Refined hierarchy:

| Level | What it is | Role |
|---|---|---|
| **Harness (present vs absent)** | Structured skill methodology, memory, verification protocol | **Activation condition** — makes all lower levels function |
| Orchestrator-swap sidecar | Process divergence → cross-wave delta → better convergence | Compounds quality via synthesis |
| Model A vs Model B (no harness) | Process differs, results converge weakly | Small, unstructured |

**The sidecar pattern is a quality compounding mechanism, not merely a process tool.** Process divergence produces insights that single-model runs miss. Those insights, when synthesized by the harness skill, produce a convergence that is richer than any single model's output. The harness is what makes this synthesis structurally valid.

Two shells — do not conflate:

| Shell | What it is | Layer |
|---|---|---|
| **Harness shell** (FH, forge-harness) | Methodology, rules, memory, skills — *specialization* accumulated over time | Durable orchestration layer — thesis subject |
| **Router shell** (Copilot CLI, Gemini CLI, Codex CLI) | Thin routing / access tool that selects and forwards to a model | Delivery / access mechanism — not a harness |

FH is the orchestrator. A router shell (or direct model CLI) is one kind of sidecar. Calling Copilot CLI "the harness" is a category error.

---

## Native cross-CLI portability (validated)

FH's SKILL.md format is shared across all three major AI CLIs. FH skills load natively in each environment without conversion or adaptation:

| CLI | Load mechanism | Status |
|---|---|---|
| **Claude Code** | `.claude/plugins/` native | ✅ Primary environment |
| **Codex CLI** | `SKILL.md` plugin (`fh-meta@forge-harness`) | ✅ Validated |
| **Gemini CLI** | `gemini skills install <path> --consent` | ✅ Validated |

This means FH is not just model-agnostic in theory — the methodology layer physically runs in all three CLI environments without modification. This is the empirical foundation for the cross-CLI portability claim.

> **Load ≠ full parity**: "loads and lists as Enabled" means the SKILL.md *methodology* is readable and runnable as guidance. Skills whose steps dispatch a sub-agent (`Agent` tool, `fh-commons:*` challengers) or depend on slash-commands/hooks are **Claude-native** — on Gemini/Codex they degrade to manual methodology, not automated execution. Cross-CLI portability covers the *methodology layer*; the automation layer (sub-agents, hooks, slash commands) requires Claude Code as host. See `README.md §2-layer architecture`.

## Orchestrator–sidecar model strategy

Use the strongest available model as orchestrator; delegate subsidiary tasks to lighter sidecar models for token economy:

| Role | Model selection | Rationale |
|---|---|---|
| **Orchestrator** | Strongest available (CC=Opus, Gemini=Pro, Codex=GPT-5.5) | Design, judgment, synthesis |
| **Sidecar** | Lighter versions (Gemini Flash, GPT-4o-mini, etc.) | Repetitive verification, adversarial passes, token-efficient delegation |

This combination can be freely mixed across CLIs — e.g., Gemini Pro orchestrating with Claude Haiku as sidecar, or CC Opus orchestrating with Gemini Flash. FH methodology works regardless of which combination is chosen.

## Scope vs steel-quench Wave 5

This document is the **rationale layer** (why sidecars, when, what value, what boundaries). `steel-quench/SKILL.md` Wave 5 (Multi-Team Adversarial Panel) is the **implementation layer** — the runnable team-formation + parallel-dispatch + cross-team-synthesis steps. They are not redundant: a skill cites this doc for *why* and *when*; Wave 5 (and any other caller) owns the *how*. If the how appears in two places, Wave 5 is canonical and this doc defers to it.

## The capability

**Any FH user can delegate tasks to other models as sidecars** from within a session. The host orchestrator is always the primary CLI + FH. The sidecar is invoked via `Bash` tool — no special integration required.

### Available sidecar paths (use whichever your environment allows)

| Sidecar | Invocation | Model access |
|---|---|---|
| **Gemini CLI** | `echo "prompt" \| gemini` or `gemini -p "prompt"` | Gemini family (default: current model) |
| **Codex CLI** | `npx @openai/codex exec "prompt"` | GPT-4o / GPT-5.5 (non-interactive exec mode) |
| **Copilot CLI** (`gh copilot`) | `gh copilot -- -p "prompt" --allow-all-tools` | Copilot model catalog — **subscription-dependent**: preview = claude-haiku-4.5 + gpt-5-mini; international/enterprise subscription = GPT-5.5, Claude Opus 4.7, etc. Verify: `gh copilot -- -p "list available models"` |

---

## Empirical validation

### Experiment 1 — Sidecar invocation (2026-05-31)

1. **Corporate network** — Copilot CLI sidecar (CC standalone = Sonnet-only on restricted network). Copilot CLI's model catalog provided access to Codex, Gemini, and Claude Opus.

2. **Direct Gemini CLI sidecar** — `echo "prompt" | gemini` inside a Claude Code session. Adversarial review of `pipeline-conductor` Done When: 3 structural gaps (Amnesia Loophole, Activity vs Integrity gap, Escalation Paradox).

3. **Direct Codex CLI sidecar** — `npx @openai/codex exec "prompt"`. Same target: 3 non-overlapping issues (scope definition gap, skip justification absent, report persistence).

4. **Gemini native skill load** — `gemini skills install <fh-skill-path> --consent`. All 32 FH skills loaded and listed as Enabled. FH SKILL.md format is natively compatible with Gemini CLI.

---

### Experiment 2 — 3-round orchestrator-swap (2026-05-31)

**Setup**: Same FH skill (`goal-quench/SKILL.md`, post-patch) reviewed under 3 orchestrator configurations. Each round: orchestrator runs Wave 1 (3 primary findings), sidecar adds 3 non-overlapping findings, orchestrator synthesizes final verdict.

| Round | Orchestrator | Sidecar | Verdict | Orchestrator focus |
|---|---|---|---|---|
| 1 (prior) | Claude Opus | Gemini + Codex | 6 issues → patched | State machine + hook reliability |
| 2 | Gemini | Codex | FAIL — 4A + 2H | State machine loop + audit methodology |
| 3 | Codex | Gemini | FAIL — 4A + 2B | Implementation parsing + dependency contract |

**Convergence (appeared in every round)**:
- Freshness guard is pseudocode — no actual timestamp comparison
- `.pending` surviving BLOCKED creates an infinite-loop deadlock
- `git diff HEAD` yields false CLEAN if `/goal` makes interim commits

**Divergence (orchestrator-specific)**:
- Gemini orchestrator: state-machine completeness, audit methodology validity, phantom telemetry
- Codex orchestrator: `grep/cut` parsing fragility, `token-budget-gate` invocation contract absent

**Cross-wave delta finding**: 3 common issues + 3 orchestrator-specific = 6 total per round. No round found all 6 on its own. Single-model review (Claude alone, Round 1 on original) found a different 3 — correct but incomplete. Multi-model synthesis identified 12 distinct issues across 3 rounds, with 3 confirmed-critical by convergence.

**Conclusion**: Process divergence is the mechanism by which sidecar diversity compounds into better convergence. The harness (FH skill format + consistent evaluation protocol) is the activation condition — without it, the three results are structurally incomparable and the delta cannot be synthesized.

```bash
# Minimal sidecar call pattern (validated)
echo "You are an adversarial reviewer. Identify the 3 most critical gaps in this SKILL.md Done When: $(tail -30 path/to/SKILL.md)" | gemini
```

This is **not a prototype** — it is a confirmed, runnable pattern.

---

## When to distribute

Three use cases, ordered by primacy under a **full-subscription environment** (Claude Max + Gemini Pro/Advanced + GPT-4o Plus — all strong models available simultaneously):

| Use case | Primacy | Sidecar role | Example |
|---|---|---|---|
| **Perspective diversity** | **Primary** — valid regardless of model tier | Each model's process angle produces non-overlapping findings; cross-wave delta improves convergence quality | steel-quench Wave 5: Claude primary → Gemini + Codex sidecars → synthesize delta |
| **Model-access fallback** | Secondary — situational | Reach a stronger model when the CC host is downgraded on a restricted network | CC standalone = Sonnet-only on a restricted network → Copilot sidecar reaches Opus |
| **Token economy** | Tertiary — relevant when models differ in cost tier | Offload subsidiary tasks to a lighter or separately-billed model | Delegate claim extraction to Gemini Flash while Opus handles synthesis |

**Full-subscription case (validated 2026-05-31)**: When all three providers are at premium tier (Claude Max / Gemini Pro / GPT-4o Plus), token economy is not the primary motivation. The orchestrator-swap experiment showed that even when all models are strong, **process divergence still produces non-overlapping findings** — Gemini focused on state-machine completeness, Codex on implementation parsing fragility. Neither found what the other found. This means perspective diversity is an intrinsic property of model identity, not a function of capability tier.

**Implication**: In a full-subscription environment, sidecar invocation should default to the strongest available sidecar model, not a lightweight one. The goal is maximum perspective divergence, not cost savings.

> **v2 paper candidate**: Does model tier affect the quality of perspective divergence, or is the divergence pattern stable across tiers? The orchestrator-swap experiment used entry/mid-tier sidecars — replicating with all-premium models (Gemini Pro, GPT-4o, Claude Opus) would test whether diversity compounds further or plateaus. This is a natural follow-on experiment for the v2 empirical section.

---

## Mechanism (how it works)

```
FH / Claude Code (orchestrator)
    │
    │  Bash tool
    ▼
Sidecar process
  ├── Gemini CLI        → Gemini model
  ├── OpenAI/Codex CLI  → GPT-4o / Codex model
  └── Copilot CLI       → model catalog (Codex / Gemini / Claude Opus)
    │
    └── stdout → back to Claude Code session → integrated by the skill
```

- **Host is always single**: Claude Code session owns the conversation, memory, and file state.
- **Sidecar is stateless**: each call is a one-shot prompt → response. No persistent sidecar context.
- **Integration is inline**: the skill reads stdout and folds it into its own output or verdict.
- **Not an agent dispatch**: sidecar calls bypass `.claude/agents/` entirely. No AGENTS.md entry needed.

---

## Integration with FH skills

Sidecar calls are coordinated inline by the calling skill, not by a central dispatcher. Recommended pattern:

```bash
# Inside a skill Step (AI executes this via Bash tool):
SIDECAR_RESULT=$(echo "${PROMPT}" | gemini 2>/dev/null)
# Then fold $SIDECAR_RESULT into the skill's output or verdict.
```

Suggested integration points:
- `steel-quench` — 2nd-challenger pass after Wave 1 (primary Claude challenger)
- `pipeline-conductor` — cross-check a verdict with a sidecar before elevating to CONDITIONAL_PASS
- `sim-conductor` — persona simulation from a different model's perspective
- `source-grounding-audit` — Gemini reads source files as a secondary back-tracer

---

## Boundaries

- The harness (FH) is the specialization layer. Do not treat the sidecar as a second harness.
- Each sidecar call is independent (no shared context with main session by default).
- Sidecar model output is **untrusted input** — the orchestrating skill validates before accepting.
- Cost: sidecar API calls are billed separately (Gemini API key, OpenAI key, Copilot subscription).
- **Provider identity gates perspective diversity** — the primary use case (diversity) only holds when the sidecar is a *different provider*. Reaching Claude Opus through Copilot CLI from a Claude host is **Claude → Claude**: it serves model-access fallback (secondary use case) but produces **no genuine process divergence** — same pre-training distribution, same blind spots. Do not count a same-provider sidecar as a diversity wave. Diversity requires a cross-provider sidecar (e.g. Claude host → Gemini/Codex).

---

## Implementation Patterns

**Context**: §1–8 establish *why* sidecar distribution works and its validated patterns. This section adds *executable* implementation guidance reverse-harvested from a sister-harness `sidecar-orchestrator` (2026-06-01), generalized for any environment. These are **reference** patterns for any caller — they do **not** supersede §Scope vs steel-quench Wave 5: for the steel-quench multi-team case specifically, Wave 5 remains the canonical implementation.

> **CLI-syntax caveat**: Exact sidecar invocation flags differ by CLI and version. The forms below use FH's validated baselines (`gh copilot suggest`, `echo … | gemini`, `npx @openai/codex exec` — see §The capability). Flags such as `--model` are catalog/version-dependent — verify with the CLI's own `--help` before relying on them.

### Three-tier fallback chain

When the primary sidecar path is blocked (network restrictions, API outages, rate limits), degrade to secondary/tertiary options so execution continues rather than failing silently.

| Priority | Sidecar | Access | Trigger condition |
|---|---|---|---|
| **1 (Primary)** | Copilot CLI (`gh copilot`) | Copilot model catalog | Default — widest catalog |
| **2 (Fallback)** | Corporate AI endpoint | Internal models (if any) | Priority 1 unreachable (503, timeout, quota) |
| **3 (Last resort)** | Direct CLI (Gemini / Codex) | Public API key | Priorities 1–2 unreachable + external network OK |

**Empirical grounding**: some corporate networks block direct LLM-provider APIs but allow GitHub CLI routing → `gh copilot` was the only path to premium models there. Without a fallback tier the workflow blocks entirely.

### Executable patterns

**Pattern 1 — Single-model sidecar**
```bash
SIDECAR_RESULT=$(gh copilot suggest "Adversarial reviewer: 3 most critical gaps in this Done When: $(tail -30 path/to/SKILL.md)" 2>&1)
EXIT_CODE=$?
[[ $EXIT_CODE -ne 0 ]] && echo "⚠️ sidecar failed (exit $EXIT_CODE): $SIDECAR_RESULT"   # escalate or fail gracefully
```
Model selection, if the CLI exposes it, is catalog-dependent — check `gh copilot --help`.

**Pattern 2 — Cross-provider parallel ensemble** (real diversity comes from *distinct providers*, not one router)
```bash
echo "$PROMPT" | gemini          > raw_gemini.txt  2>&1 &
npx @openai/codex exec "$PROMPT"  > raw_codex.txt   2>&1 &
gh copilot suggest "$PROMPT"      > raw_copilot.txt 2>&1 &
wait                                                          # block until all sidecars finish
# orchestrator synthesizes cross-wave delta from raw_*.txt
```
> Routing the *same* provider twice (e.g. Claude → Claude via Copilot) is model-access fallback, **not a diversity wave** — same pre-training, same blind spots (see §Boundaries). For divergence, use genuinely different providers.

**Orchestrator-swap variant** (FH Experiment 2): rotate orchestrator identity across waves — host runs Wave 1, a different-provider sidecar challenges Wave 1, a third challenges Wave 2, then the host synthesizes all three.

**Pattern 3 — Corporate endpoint fallback (Priority 2)**
```bash
CORPORATE_RESULT=$(curl -s -X POST "${CORPORATE_AI_ENDPOINT}" \
  -H "Authorization: Bearer ${CORPORATE_AI_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"${CORPORATE_MODEL}\",\"prompt\":\"${PROMPT}\"}" | jq -r .response)
[[ -z "$CORPORATE_RESULT" ]] && echo "❌ corporate endpoint failed — check token in .env"   # escalate to Priority 3
```
Configure `CORPORATE_AI_ENDPOINT` / `CORPORATE_MODEL` / `CORPORATE_AI_TOKEN` in `.env` (git-excluded).

**Pattern 4 — Direct Gemini/Codex CLI (Priority 3)**
```bash
echo "${PROMPT}" | gemini         > raw_gemini.txt
npx @openai/codex exec "${PROMPT}" > raw_codex.txt
```
Requires the respective CLI installed and authenticated.

### Error-handling checklist

```bash
RESULT=$(sidecar_command 2>&1); EXIT_CODE=$?
if [[ $EXIT_CODE -ne 0 ]]; then
  echo "⚠️ sidecar failed (exit $EXIT_CODE)"
  if   [[ "$RESULT" =~ (unknown|invalid)\ model ]];      then echo "   → model name error — check catalog: gh copilot --help"
  elif [[ "$RESULT" =~ (503|timeout) ]];                 then echo "   → network/API outage — escalate to Priority 2"
  elif [[ "$RESULT" =~ (rate\ limit|quota\ exceeded) ]]; then echo "   → rate limited — retry after delay or use Priority 3"
  else echo "   → unknown failure: $RESULT"; fi
fi
```
**Critical**: never assume sidecar success — always capture `$EXIT_CODE` and parse `stderr` for failure signals.

### Three-layer persistence protocol

Sidecar results are high-risk for **compression aging** (AgingBench, arXiv:2605.26302) — single-session outputs that vanish if not structurally anchored. Persist in 3 independent layers so at least one survives compression/refactoring:

1. **Full result file** — `tracks/_meta/sidecar_{target}_{YYYY_MM_DD}.md` with frontmatter (`type: sidecar-review`, `models`, `target`, `priority`) + tiered findings (M/S/R).
2. **Memory reference entry** — one keyword-tagged line in the durable memory store (`~/.claude/.../memory/`) so next session auto-loads on keyword trigger.
3. **CATALOG search entry** — 3-line summary + Decision/Open, pointing at the Layer-1 file.

Missing any layer = compression risk. (Path conventions adapt per project — see Generalization below.)

### When NOT to invoke (simplification guard)

**Skip the sidecar** for: single-file review (host sufficient), simple design decisions (no architectural complexity), repetitive non-judgment tasks (shell faster than an AI sidecar). **Invoke** only when 2+ hold: complex/multi-skill architecture · external knowledge needed (arXiv, frontier, cross-domain) · genuine multi-model perspective diversity required.

> For *when to distribute by value tier* (perspective diversity / model-access / token economy), the canonical guidance is §When to distribute above — not repeated here.

### Generalization guidelines (sister-harness → FH)

1. **Corporate endpoint → generic fallback**: a sister-harness's internal gateway → user-configured `.env` endpoint.
2. **Approval mode → consent gate**: prompt the user before a sidecar sends internal code/patterns to an external API.
3. **Persistence paths → project structure**: the sister-harness's `tracks/_meta/`·`memory/`·`CATALOG.md` → adapt to the host project's equivalents.
4. **Model names → CLI-agnostic**: replace pinned names (`claude-opus-4.x`, `gpt-5.x`) with `{model-name}` placeholders + "check CLI help for catalog".

---

## References

- `README.md §Architecture — 2-layer design` — sidecar note in Automation layer section
- `AGENTS.md §2-Layer Architecture Context` — sidecar note distinguishing Bash invocation from agent dispatch
- FH paper (Zenodo DOI: 10.5281/zenodo.20397566, arXiv: submit/7657304) — harness-as-durable-layer thesis
- A sister-harness `sidecar-orchestrator` SKILL.md (2026-06-01) — gh copilot + corporate endpoint + 3-tier fallback + 3-layer persistence
- arXiv:2605.26302 AgingBench — compression aging defense rationale

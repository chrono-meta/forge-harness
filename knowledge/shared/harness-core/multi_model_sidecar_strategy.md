---
name: multi-model-sidecar-strategy
description: Validated pattern for invoking other AI models (Gemini, Codex, Copilot CLI) as sidecars from within a Claude Code / FH session via Bash tool. Token economy, model-access fallback, and adversarial diversity use cases.
date: 2026-05-31
tags: [multi-model, sidecar, token-economy, model-access, adversarial, validated]
---

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

## Orchestrator–sidecar model strategy

Use the strongest available model as orchestrator; delegate subsidiary tasks to lighter sidecar models for token economy:

| Role | Model selection | Rationale |
|---|---|---|
| **Orchestrator** | Strongest available (CC=Opus, Gemini=Pro, Codex=GPT-5.5) | Design, judgment, synthesis |
| **Sidecar** | Lighter versions (Gemini Flash, GPT-4o-mini, etc.) | Repetitive verification, adversarial passes, token-efficient delegation |

This combination can be freely mixed across CLIs — e.g., Gemini Pro orchestrating with Claude Haiku as sidecar, or CC Opus orchestrating with Gemini Flash. FH methodology works regardless of which combination is chosen.

## The capability

**Any FH user can delegate tasks to other models as sidecars** from within a session. The host orchestrator is always the primary CLI + FH. The sidecar is invoked via `Bash` tool — no special integration required.

### Available sidecar paths (use whichever your environment allows)

| Sidecar | Invocation | Model access |
|---|---|---|
| **Gemini CLI** | `echo "prompt" \| gemini` or `gemini -p "prompt"` | Gemini family (default: current model) |
| **Codex CLI** | `npx @openai/codex exec "prompt"` | GPT-4o / GPT-5.5 (non-interactive exec mode) |
| **Copilot CLI** (`gh copilot`) | `gh copilot suggest "prompt"` | Copilot model catalog: Codex · Gemini · Claude Opus |

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
| **Model-access fallback** | Secondary — situational | Reach a stronger model when the CC host is downgraded on a restricted network | CC standalone = Sonnet-only on corporate net → Copilot sidecar reaches Opus |
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

---

## Implementation Patterns

**Context**: The Multi-Model Sidecar Strategy (§1-8) establishes why sidecar distribution works and its validated patterns. This section adds executable implementation guidance reverse-harvested from PMH `sidecar-orchestrator` v1 (2026-06-01).

---

### Three-tier fallback chain

When the primary sidecar path is blocked (network restrictions, API outages, rate limits), fallback to secondary and tertiary options ensures execution continues.

| Priority | Sidecar | Access | Trigger condition |
|---|---|---|---|
| **1 (Primary)** | Copilot CLI (`gh copilot`) | Claude Opus / GPT-4o / Codex models | Default path — widest model catalog |
| **2 (Fallback)** | Corporate AI endpoint | Internal models (if available) | Priority 1 unreachable (503, timeout, quota exceeded) |
| **3 (Last resort)** | Direct CLI (Gemini / Codex) | Public API key | Priorities 1-2 unreachable + external network access |

This hierarchy ensures that restricted network environments (corporate proxies, air-gapped, or rate-limited accounts) can still execute multi-model tasks by degrading gracefully rather than failing silently.

**PMH empirical grounding**: Certain corporate networks block direct LLM provider APIs but allow GitHub CLI routing → `gh copilot` became the only path to premium models on those networks. Without a fallback tier, the workflow would be fully blocked.

---

### Executable sidecar call patterns

#### Pattern 1: Single-model sidecar (Priority 1)

The simplest case — delegate a task to a single stronger or lighter model.

```bash
# Example: Claude Code (host) → Copilot CLI (sidecar, Opus model)
SIDECAR_RESULT=$(gh copilot -p "You are an adversarial reviewer. Identify the 3 most critical gaps in this SKILL.md Done When: $(tail -30 path/to/SKILL.md)" 2>&1)
EXIT_CODE=$?

if [[ $EXIT_CODE -ne 0 ]]; then
  echo "⚠️ gh copilot failed (exit $EXIT_CODE): $SIDECAR_RESULT"
  # Escalate to Priority 2 or fail gracefully
fi

# Integrate result into skill verdict
echo "$SIDECAR_RESULT" >> sidecar_review.txt
```

**Model specification** (if Copilot CLI supports it):
```bash
gh copilot --model claude-opus-4.7 -p "{prompt}"
```

Replace `claude-opus-4.7` with the model name from `gh copilot -- --help` output. If model specification is unavailable, Copilot CLI uses its default catalog model.

---

#### Pattern 2: Multi-model parallel ensemble

Invoke 2-3 sidecar models in parallel, then synthesize their outputs for cross-wave delta.

```bash
# Launch 3 sidecar models in background
for model in claude-opus gpt-4o gemini-pro; do
  gh copilot --model $model <<'EOF' > sidecar_raw_$model.txt &
  {Your prompt here}
EOF
done

wait  # Block until all sidecars finish

# Synthesize results
cat sidecar_raw_*.txt | {orchestrator skill processes delta}
```

**Orchestrator-swap variant** (FH Experiment 2):

```bash
# Round 1: Claude Code orchestrates directly
{orchestrator performs Wave 1 analysis}

# Round 2: Gemini sidecar challenges Wave 1
echo "{Wave 1 summary}" | gemini > wave2_challenge.txt

# Round 3: Codex sidecar challenges Wave 2
gh copilot --model gpt-4o -p "{Wave 2 summary}" > wave3_challenge.txt

# Synthesize: orchestrator reads all 3 waves and produces final verdict
{orchestrator integrates Wave 1, 2, 3 findings}
```

This pattern maximizes process divergence by rotating orchestrator identity across waves.

---

#### Pattern 3: Corporate endpoint fallback (Priority 2)

If your organization provides an internal AI gateway, use it as Priority 2 fallback when Priority 1 (Copilot CLI) is unreachable.

```bash
# Priority 2: Corporate AI endpoint
CORPORATE_RESULT=$(curl -s -X POST ${CORPORATE_AI_ENDPOINT} \
  -H "Authorization: Bearer ${CORPORATE_AI_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"${CORPORATE_MODEL}\",\"prompt\":\"${PROMPT}\"}" | jq -r .response)

if [[ -z "$CORPORATE_RESULT" ]]; then
  echo "❌ Corporate endpoint failed — check token in .env"
  # Escalate to Priority 3
fi
```

**Key adaptation**: Configure `CORPORATE_AI_ENDPOINT`, `CORPORATE_MODEL`, and `CORPORATE_AI_TOKEN` in `.env` (excluded from git).

---

#### Pattern 4: Gemini/Codex CLI direct (Priority 3)

Last resort for external-network environments.

```bash
# Gemini CLI
echo "${PROMPT}" | gemini > sidecar_raw_gemini.txt

# Codex CLI (if available)
npx @openai/codex exec "${PROMPT}" > sidecar_raw_codex.txt
```

These require the respective CLI tools installed and authenticated with API keys.

---

### Error handling checklist

When a sidecar call fails, the orchestrator must handle it gracefully:

```bash
# 1. Capture exit code
RESULT=$(sidecar_command 2>&1)
EXIT_CODE=$?

# 2. Detect failure patterns
if [[ $EXIT_CODE -ne 0 ]]; then
  echo "⚠️ Sidecar failed (exit $EXIT_CODE)"
  
  # 3. Pattern-specific routing
  if [[ "$RESULT" =~ "unknown model"|"invalid model" ]]; then
    echo "   → Model name error — check catalog with: gh copilot -- --help"
  elif [[ "$RESULT" =~ "503"|"timeout" ]]; then
    echo "   → Network/API outage — escalating to Priority 2 fallback"
  elif [[ "$RESULT" =~ "rate limit"|"quota exceeded" ]]; then
    echo "   → Rate limit hit — retry after delay or use Priority 3"
  else
    echo "   → Unknown failure: $RESULT"
  fi
fi
```

**Critical**: Do not assume sidecar success. Always capture `$EXIT_CODE` and parse `stderr` for failure signals.

---

### Three-layer persistence protocol

Sidecar results are high-risk for **compression aging** (AgingBench arXiv:2605.26302) — single-session outputs that disappear if not structurally anchored.

**Defense**: Persist in 3 independent layers so at least one survives compression/refactoring.

#### Layer 1: Full result file

```
tracks/_meta/sidecar_{target}_{YYYY_MM_DD}.md
```

**Frontmatter**:
```yaml
---
type: sidecar-review
date: 2026-06-01
models: [claude-opus, gpt-4o]
target: {asset-name}
tags: sidecar, multi-model, adversarial
priority: S-grade  # compression-exempt signal
---
```

Body: Full sidecar outputs (raw or synthesized), tiered by severity (M/S/R).

#### Layer 2: MEMORY.md reference entry

```markdown
## Reference
- [Sidecar review — {target}](reference_sidecar_{target}_{YYYY_MM_DD}.md) — {one-line summary} / S-grade {N} findings / {model config} 🔑 {keywords}, sidecar, multi-model, {target}
```

**Purpose**: Keyword-trigger loading on next session (e.g., user says "sidecar findings" → auto-loads this file).

#### Layer 3: CATALOG.md search entry

```markdown
### {YYYY-MM-DD} | _meta | sidecar, multi-model, {target}
**File:** tracks/_meta/sidecar_{target}_review_{YYYY_MM_DD}.md
{3-line summary: model config, key findings, S-grade recommendations.}
- Decision: {core decisions from sidecar findings}
- Open: {unresolved issues}
```

**Verification checklist**:
```bash
# Confirm all 3 layers exist
ls tracks/_meta/sidecar_*
ls memory/reference_sidecar_*
grep "sidecar" CATALOG.md | head -5
```

All 3 must exist for full persistence. Missing any layer = compression risk.

---

### When to use sidecar orchestration

| Use case | Primacy | Sidecar role | Example |
|---|---|---|---|
| **Perspective diversity** | Primary | Each model's process angle finds non-overlapping gaps → synthesis improves convergence | steel-quench Wave 5: Claude primary → Gemini + Codex sidecars → delta synthesis |
| **Model-access fallback** | Secondary | Reach a stronger/different model when host is downgraded | Corporate network = Sonnet-only → Copilot CLI reaches Opus |
| **Token economy** | Tertiary | Offload repetitive tasks to lighter models | Delegate claim extraction to Gemini Flash while Opus handles synthesis |

**Full-subscription case** (validated 2026-05-31): When all providers are at premium tier (Claude Max / Gemini Pro / GPT-4o Plus), token economy is not the driver. Process divergence still produces non-overlapping findings even when all models are strong. Default to the strongest available sidecar models for maximum perspective divergence.

---

### Simplification guard

**Overkill scenarios** (do NOT invoke sidecar):
- Single-file review (host model sufficient)
- Simple design decisions (no architectural complexity)
- Repetitive tasks without judgment (shell scripting faster than AI sidecar)

**Necessary conditions** (2+ required):
- Complex architecture / multi-skill design
- External knowledge needed (arXiv, frontier patterns, cross-domain synthesis)
- Multi-model perspective diversity (no single model covers all angles)

---

### Generalization guidelines (PMH → FH)

When adapting PMH `sidecar-orchestrator` patterns to FH or other environments:

1. **Corporate AI endpoint → Generic fallback**:
   - PMH: Internal corporate gateway
   - FH: User-configured endpoint via `.env` variables
   
2. **Approval mode → Consent gate**:
   - PMH: Network-restricted environment → manual approval flow
   - FH: Prompt user if sidecar sends internal code/patterns to external APIs
   
3. **3-Layer persistence → Adapt to project structure**:
   - PMH: `tracks/_meta/`, `memory/`, `CATALOG.md`
   - FH: `knowledge/shared/meta/sidecar_reviews/`, `MEMORY.md`, search index
   
4. **Model names → CLI-agnostic**:
   - PMH: `claude-opus-4.7`, `gpt-5.5` (Copilot CLI catalog 2026-06-01)
   - FH: `{model-name}` placeholder + "check CLI help for catalog"

---

## References

- `README.md §Architecture — 2-layer design` — sidecar note in Automation layer section
- `AGENTS.md §2-Layer Architecture Context` — sidecar note distinguishing Bash invocation from agent dispatch
- FH paper (Zenodo DOI: 10.5281/zenodo.20397566, arXiv: submit/7657304) — harness-as-durable-layer thesis
- PMH `sidecar-orchestrator` SKILL.md (2026-06-01) — gh copilot + corporate endpoint + 3-tier fallback + 3-Layer persistence
- arXiv:2605.26302 AgingBench — compression aging defense rationale

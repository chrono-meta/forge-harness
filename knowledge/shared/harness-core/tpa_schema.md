---
name: tpa-schema
description: Canonical Target Profile Analysis schema for FH meta-harness skills. All skills that run TPA (sim-conductor, steel-quench, source-grounding-audit, agent-composer) MUST derive their routing decisions from this schema.
type: reference
scope: meta-harness
---

# Target Profile Analysis (TPA) — Canonical Schema

> **Meta-harness scope**: FH operates on harness assets themselves (SKILL.md, CLAUDE.md, agents, templates), not on application code. A mistake in a SKILL.md propagates to every future session that loads it — the risk profile is categorically higher than application code of the same line count.

All four skills that perform TPA **reference this file** rather than defining their own taxonomy:
- `sim-conductor` Step 0.3
- `steel-quench` Step 0.3
- `source-grounding-audit` Step 0.5
- `agent-composer` Step 0.2

---

## Canonical Fields

| Field | Type | Values | Derivation |
|---|---|---|---|
| `artifact_type` | enum | See §Artifact Type Table | From file path / extension / user declaration |
| `audience` | enum | `internal` · `external` · `mixed` | From scope + external_publish |
| `claim_density` | enum | `low` (≤3) · `medium` (4–10) · `high` (>10) | Count verifiable claims in artifact |
| `risk_level` | enum | `low` · `medium` · `high` | From §Risk Default Table (override allowed) |
| `novelty` | bool | `true` · `false` | `true` if no prior session evidence or first-of-its-kind pattern |
| `scope` | enum | `internal` · `external` | `external` if published/publishable or public repo |
| `phantom_risk` | derived | `true` · `false` | `true` if artifact contains arXiv/DOI/http citations OR code fences in a knowledge doc |

> `phantom_risk` is **derived** — do not ask the user. If `artifact_type` is `skill_md` or `design_doc` and citations or URLs are present → `true`. Use as input to `source-grounding-audit` gate trigger.

---

## §Artifact Type Table (Meta-Harness First)

### Meta-Harness Artifact Types

| `artifact_type` | Examples | Default Risk | Why High |
|---|---|:---:|---|
| `skill_md` | `plugins/*/skills/*/SKILL.md` | **high** | Behavioral rule for AI — executes every session it's loaded |
| `claude_md` | `CLAUDE.md`, `.claude/rules/*.md` | **high** | Governance layer — one drift affects all connected projects |
| `agent_md` | `.claude/agents/*.md` | **medium-high** | Sub-agent behavioral rule — dispatched autonomously |
| `template` | `templates/**` | **high** | Propagates to target projects — a mistake multiplies |
| `skill_detail_md` | `*/SKILL_detail.md` | **medium** | On-demand reference — lower broadcast risk than SKILL.md |
| `knowledge_doc` | `knowledge/shared/*.md` | **medium** | Reference only, but substantive carve-out applies |
| `cheatsheet` | `CHEATSHEET.md` | **medium** | User-facing guide — external audience |
| `readme` | `README.md` | **medium-high** | External facing — first impression for all users |
| `bash_script` | `templates/*.sh`, `scripts/*.sh` | **high** | Executes in user environment |
| `session_card` | `tracks/_meta/reference_next_session_starter.md` | **low** | Ephemeral state — low blast radius |
| `catalog_entry` | `CATALOG.md` additions | **low** | Index only — no behavioral impact |

### Standard Artifact Types (Field Project Work)

| `artifact_type` | Examples | Default Risk |
|---|---|:---:|
| `code` | `.py`, `.ts`, `.go`, `.java` | **medium** |
| `pr_diff` | git diff output | **medium** |
| `config` | `.yaml`, `.json`, `.toml` | **medium-high** |
| `api_spec` | OpenAPI, Proto | **medium** |
| `test_suite` | `*_test.py`, `*.spec.ts` | **low** |
| `design_doc` | ADRs, RFCs, architecture docs | **medium** |

---

## §Gate Routing Table

Which gates are **mandatory** vs optional for each (artifact_type × risk_level) combination.

| `artifact_type` | `scope` | steel-quench | source-grounding-audit | sim-conductor Area |
|---|---|:---:|:---:|:---:|
| `skill_md` | any | **MANDATORY** | **MANDATORY** if `phantom_risk=true` | D-skill |
| `claude_md` / `agent_md` | any | **MANDATORY** | optional | D-skill (for agent_md) |
| `template` | any | **MANDATORY** | **MANDATORY** | A (external publish check) |
| `readme` / `cheatsheet` | external | **MANDATORY** | optional | **A MANDATORY** |
| `bash_script` | any | **MANDATORY** (Wave 1 real-code first) | optional | — |
| `knowledge_doc` | any | optional | **MANDATORY** if `phantom_risk=true` | — |
| `code` / `pr_diff` | any | optional | optional | D-code |
| `config` | external | **MANDATORY** | optional | — |
| `design_doc` | external | **MANDATORY** | **MANDATORY** if citations | A |

**Enforcement note** (from council finding): "mandatory" means the gate BLOCKS the downstream step if skipped — not advisory. `pipeline-conductor` Step 0.5 and `return-path-gate` should treat mandatory gates as hard blockers, not warnings.

---

## §Profile Output Format

All TPA-performing skills output this block (copy verbatim):

```
TPA Profile:
  artifact_type: [type]
  audience: [internal | external | mixed]
  claim_density: [low | medium | high] ([N] claims)
  risk_level: [low | medium | high]
  novelty: [true | false]
  scope: [internal | external]
  phantom_risk: [true | false]
  required_gates: [list from §Gate Routing Table]
  optional_gates: [list]
```

Skills MAY add skill-specific derived fields (e.g., `steel-quench` adds `wave_weights`, `sim-conductor` adds `recommended_area`) but the canonical 8 fields above are the shared contract.

---

## Override Rules

1. User may explicitly override `risk_level` — accepted without question.
2. `scope` override: if artifact is in `templates/` or public repo, `scope=external` is forced regardless of user declaration.
3. `phantom_risk` is derived-only — cannot be overridden to `false` if citations or code fences exist.
4. `required_gates` cannot be overridden to empty — skip must be explicitly declared as `degraded: [gate] (user skipped)` in output.

---

## Meta-Harness Amplification Rule

> A defect in a `skill_md` or `claude_md` artifact runs in every session that loads it — potentially hundreds of times before being caught. Apply the following multiplier when assessing severity:
>
> - `skill_md` / `claude_md` / `template`: **severity × 3** (broadcast multiplier)
> - `agent_md`: **severity × 2**
> - Standard artifact types: no multiplier

This is why meta-harness defaults to `risk_level=high` for these types: the blast radius is not the artifact itself but every downstream invocation.

---

## Skill Integration Pointers

| Skill | How to use this schema |
|---|---|
| `sim-conductor` Step 0.3 | Replace inline table with `artifact_type` lookup from §Artifact Type Table → `required_gates` from §Gate Routing Table |
| `steel-quench` Step 0.3 | Derive `phantom_risk` per §Canonical Fields. Wave 5 activation condition: `scope=external AND risk_level=high` |
| `source-grounding-audit` Step 0.5 | Gate trigger: `phantom_risk=true` OR `risk_level=high` |
| `agent-composer` Step 0.2 | Capability fit scoring input: `artifact_type` determines `role_match` lookup domain |

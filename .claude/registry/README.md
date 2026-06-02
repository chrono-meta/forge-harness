# .claude/registry

Machine-readable registries for the forge-harness automation layer.

## agent_cards.json

The **canonical machine-readable mirror** of the agent registry. `AGENTS.md` stays the
human-facing source of truth (roles, rationale, prose); `agent_cards.json` is its structured
counterpart for tooling — capability discovery, dispatch routing, and count-drift detection.

Inspired by the **A2A "Agent Card"** pattern (the 2026 standard for agent capability discovery):
each card declares an agent's `id`, `file`, `role`, `allowed_tools`, `invoked_by`, and a `writes`
flag. `agent_count` is asserted at the top level and **must equal the number of `.md` files in
`.claude/agents/`** — a mismatch is itself a State-Degradation signal (see `harness-doctor`).

### Regeneration

Hand- or script-derived from `AGENTS.md` (Agent Registry + Tool-restrictions tables) plus each
`.claude/agents/*.md` frontmatter. Regenerate whenever an agent is added, removed, or its tools
change — and re-check `agent_count`. On any disagreement between `AGENTS.md` and an agent's own
`.md`, **prefer the agent `.md`** (e.g. `challenger.md` has no `tools:` field, so its tools come
from `AGENTS.md`).

> Frontier basis: `knowledge/shared/harness-core/harness_frontier_diagnosis_2026-06-02.md` (identity ① Control Tower — closes the "no canonical machine-readable registry / count drift" gap noted in `fh_ecosystem_positioning.md`).

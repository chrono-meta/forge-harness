---
name: Companion-Store ↔ gbrain ↔ Obsidian — pluggable persistence cross-audit (2026-06-11)
description: Sister-asset cross-audit treating FH's companion store, gbrain (LLM-wiki/memory), and Obsidian (markdown vault) as interchangeable backends for one role — durable private knowledge persistence — and the rationale for making the companion store pluggable.
type: feedback
date: 2026-06-11
tags: [companion-store, pluggable, gbrain, obsidian, sister-asset, mode-a, mode-d, cross-project]
originProject: forge-harness
---

# Companion-Store Pluggable Persistence — Cross-Audit

> Sister-asset protocol activation. Builds on the 2026-06-03 companion-store formalization
> (CATALOG: `#companion-store, #ephemeral-handoff`) — does **not** contradict it. That entry
> fixed the *role* (durable private store for drafts/signals/handoffs) + the single-source
> guard (methodology stays in the public mirror, store holds only outputs). This audit fixes
> the *implementation* axis: the role's backend should be **pluggable**, not hardcoded to a
> `-be` git repo.

## Trigger

Operator observation: "many people work by connecting Obsidian / LLM-wikis — for them, instead
of spinning up a new `-be` folder, can FH map flexibly in *their* direction?" The current
`modes_and_value.md` hardcodes the companion store as a `*-be` git repo. That is one valid
backend, but forcing it is friction for users who already keep durable knowledge elsewhere —
exactly the "don't block those who come" violation the usage-mode policy exists to prevent.

## Asset identity (5-min)

| Asset | Nature | Resolution / strength | Access scope |
|---|---|---|---|
| **FH companion store (`-be`)** | Private git repo of markdown (drafts · signals · handoffs · tracks-mirror) | Methodology-separated, git-versioned, Stop-hook auto-mirror of gitignored local state | Operator-private |
| **gbrain** | Queryable memory system — "next Postgres for memory" (PGLite/Postgres + pgvector, brains+sources, MCP) | Retrieval-optimized at scale; hybrid search; multi-brain access policy; contract-first ops | Personal + team-mountable brains |
| **Obsidian vault** | Local markdown vault with backlink graph | Human knowledge-gardening; zero-config (just files); graph browsing | Local / user-synced |

**Resolution difference**: FH store = *session-record + methodology-output* persistence; gbrain =
*retrieval/recall* at scale; Obsidian = *human-curated* knowledge graph. All three fill the same
**role slot** — a durable, private home for FH's outputs that keeps the public mirror methodology-only.

## Overlap — value if combined

The companion store's *role* is backend-agnostic. Recognizing this lets a user point FH at whatever
durable store they already run:
- FH outputs (signals · digests · handoffs · session cards) → **written to** the chosen backend.
- Obsidian: write markdown into the vault path → instantly browsable + backlinked, zero new infra.
- gbrain: ingest outputs → they become **searchable** alongside the user's brain (the LLM-wiki win).
- `-be` repo: the current default, best for git-versioned operator workflows.

## Items to import (gbrain → FH)

1. **Engine-factory / pluggable-backend pattern** (`src/core/engine-factory.ts`: dynamic-import
   `'pglite'` vs `'postgres'`). Direct template for a pluggable companion-store backend selector —
   same role, swappable implementation chosen at setup.
2. **Brains-and-sources routing** (multiple stores, each with its own access policy, 6-tier
   resolution). Informs "which store + which section" when a user runs >1 backend.
3. **Thin-router / progressive-disclosure** (`skills/RESOLVER.md` two-layer; functional-area
   resolver). FH already uses CLAUDE.md-as-dispatcher; gbrain's measured +13–17pp validation is
   external corroboration of the pattern FH relies on.

## Items FH can propagate (→ gbrain / users)

1. **Single-source / methodology-in-public-mirror guard** — the store holds only *outputs*, never
   a copy of the rule. A discipline any memory-backend user benefits from (prevents method drift).
2. **Ephemeral-environment handoff rule** — gitignored/local stores are wiped on cloud reclaim;
   durable handoff must land in the working repo or a PR comment. Backend-agnostic.

## Cognitive-gap facts

FH and gbrain are sibling internal assets that independently converged on "durable private
knowledge store + thin-router dispatch + pluggable engine" with **no cross-link** until now.
gbrain is the more mature *retrieval* engine; FH is the more mature *methodology/governance*
layer. Cross-linking lets each consume the other rather than re-deriving it.

## Cross-reference recommendation

- FH side: `modes_and_value.md` companion-store section → note backends are pluggable, gbrain is
  the LLM-wiki option (this audit is the rationale).
- gbrain side: no write access from here → if a link is wanted, deliver as a humble proposal
  (sister_asset_protocol: provider-humble, list imports first), not a restructure instruction.

## Decision

Make the companion store a **pluggable persistence target** (backends: `-be` git repo · Obsidian
vault · gbrain LLM-wiki). Role + single-source guard unchanged; only the backend becomes a
setup-time choice. Implemented in the same session via a `modes_and_value.md` Pluggable-backends
subsection (the companion store's home; project→track mapping in `auto_project_mapping.md` is a
separate concern and is left untouched).

---
name: corpus-grounding-expander
description: Fetches and normalizes multi-version public-domain corpora into a single verified-axiom store for verbatim-relay grounding, recording per-version license and provenance.
user-invocable: true
allowed-tools: ["Read", "Bash", "WebFetch", "Write"]
model: sonnet
---

# corpus-grounding-expander

Builds or broadens the **grounded axiom** a relay system quotes from. When a system's output must be
constrained to verbatim source (fail-closed grounding), the corpus IS the axiom — this skill expands
that corpus from multiple public-domain versions so grounding is robust and non-biased (a quote
verified in ANY version counts), without ever adding a generator.

> Origin: harvested from the-bible (2026-06-20) — 6 public-domain Bible versions, 197k verses, as the
> fail-closed grounding axiom. Generalizes to any verbatim-relay corpus (legal statute, RFC text,
> standards). See `tracks/_contrib/field_harvest_2026-06-20_gate-locality-and-grounding-capabilities.md`.

## Triggers
- "get more sources" / "broaden the grounded corpus"
- "add another version of the corpus"
- "ingest the full <source> as the grounding axiom"
- `/corpus-grounding-expander {source or version}`

### Natural Language Triggers (example user phrases)
- "이 코퍼스 여러 버전으로 통째로 가져와줘"
- "the grounding DB is just a sample — pull the whole thing, multiple editions"
- "add a second public-domain edition so we're not biased to one"

## Steps
1. **Source + license check** — identify the public-domain source(s) and confirm each is genuinely
   free to redistribute. Record the license literally (no assumption).
2. **Fetch (retry-disciplined)** — pull each version; on transient error, backoff-retry before
   declaring the source unavailable (do not silently drop a version).
3. **Normalize to a single key schema** — map every version to the SAME addressable key
   (e.g. `ref → text`) so cross-version quotation stays aligned. Write per-version files +
   an `_index` recording version id, license, scope, and record count.
4. **Wire grounding as a union** — the grounding check passes if the quote matches the canonical text
   at that key in ANY version. Never add a path that generates text — grounding is quote-only.
5. **Relay-integrity check** — confirm the consumer (the gate) QUOTES the corpus and cannot emit
   un-grounded text; run a fabrication probe (a known non-source quote must fail-closed).

## Done When
- **Each added source carries a verifiable public-domain/license record** in the index. *Check class: mandatory-pass (binary — license field present and non-empty per version).*
- **Every version is normalized to the same key schema** (cross-version keys align). *Check class: mandatory-pass (a shared sample key resolves in each version or is explicitly canon-scoped).*
- **The index declares the quote-only union contract** (grounding matches verbatim text in ANY version; no generation path) and ships a fabrication-probe spec for the consumer to run. *Check class: mandatory-pass (binary — quote-only contract + probe-spec present in the index).*

## Guards
- **Grounding, never a generator** — the relay constraint is structural; this skill wires *grounding*.
- **License-literal** — record the actual license per source; never assume public-domain.
- **No silent version drop** — a fetch failure is a named residual in the index, not a quiet omission.

## Independently executable
Yes — needs only a network fetch + file write. No dependency on other FH skills (a consumer gate that
reads the corpus is the system's own, not this skill's).

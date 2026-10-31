---
name: install-doctor-detail
description: On-demand detail for install-doctor SKILL.md (moved verbatim; salience split).
load: on-demand
---

# install-doctor — on-demand detail

## §Bootstrap-Scope

**Bootstrap note — honest scope**: `scripts/fh_node_check.sh` (the check that *reports* a missing
floor at turn 0) ships with the clone, but its **registration does not**: every
`.claude/settings*.json` path in this repo is gitignored (confirm with `git check-ignore -v
.claude/settings.json` — don't trust a line number, they move), so no SessionStart entry can be
tracked. The tracked artifact is `templates/settings.SessionStart.snippet.json`; `/install-wizard`
merges it. A user who never runs the wizard still gets no turn-0 signal — that residual is reduced,
not closed, and this check item is the backstop for it.

## §Node-Floor-Rationale

**Why this is a check item and not a note** (measured 2026-07-30): a second machine held the full
companion store and memory, yet ran with **both** SessionStart hooks absent. Nothing surfaced it —
the miss was found by accident. A weak tier is where this bites hardest: a mechanized floor is
tier-independent, while the prose it replaces is exactly what a weaker model drops first.

## §MCP-Transport-Patterns

**Known MCP HTTP transport vulnerability patterns** (based on HTTP port exposure security principles): When MCP servers using HTTP/SSE transport expose ports without authentication, remote access risk within local networks may occur. stdio transport is not affected.

| Transport | Risk |
|---|---|
| `stdio` (default) | Safe — not subject to vulnerability pattern |
| `http` / `sse` | ⚠️ Risk if port exposed without authentication — verify firewall rules + access control |

## §Done-When-Rationale

**Why `Steps 0~4`, not `1~4`**: Step 0 holds the only *mechanical floor* checks in this skill (hook
exec-bit, SessionStart registration, Node floor). Leaving it outside the completion condition let a
run report "done" having never touched the one part that is not judgement.

**Why the verdict is counted, not stated**: the previous condition was `"Plugin install is safe in
current environment" confirmed` — that measures whether a *sentence was printed*, which a run
satisfies by printing it. An unmeasured area (e.g. an unparseable `.mcp.json`) must not be
absorbed into 🟩; absence of a finding is not a finding of absence.

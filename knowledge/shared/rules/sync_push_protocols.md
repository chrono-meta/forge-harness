---
description: Defines the Session Sync procedure for persisting session work to the hub, the Knowledge Push protocol for feeding new knowledge back, CATALOG.md format, track mapping table, and tag conventions.
---

# Session Sync / Knowledge Push Protocols

## Session Sync Protocol

Procedure for persistently storing sessions worked on in other projects into the hub.
Follow this protocol when the user requests "sync", "save session", or similar.

### Sync target judgment

| Sync YES | Sync NO |
|---|---|
| New pattern/rule discovered | Simple code change (1-line bug fix) |
| Architecture decision | Routine test execution |
| Lessons/feedback (learned from failures) | Repeating already-recorded content |
| Roadmap/strategy change | Sessions with only exploration and no conclusion |

**What-kind axis (Raw / Wiki / Conversation)** — orthogonal to the YES/NO above and to the
location split (knowledge/ · tracks/ · memory/), this classifies the *processing stage*, which
routes the destination: **Raw** = unprocessed capture (a pasted log, a fetched source) → stays in
tracks/ or a companion store, not yet distilled · **Wiki** = distilled + `[[linked]]` knowledge →
knowledge/ or memory/ (the compounding layer) · **Conversation** = dialogue/decision logs → tracks/
session files. A Raw item is not yet a Wiki item; the distill step (Raw → Wiki) is where linking +
the contradiction scan below earn their keep. (Imported from the 김효율 AX-Obsidian cross-audit,
`tracks/_audit/session_2026_06_21_kim-hyoyul-ax-obsidian-wiki-harness.md` §4 — a crisper ingest
schema than the location split alone.)

### Sync procedure

```
1. Create/move session file
   → tracks/{project}/session_YYYY_MM_DD_{slug}.md
   → YAML frontmatter required: name, description, type, date, tags

2. If learnings/feedback exist, create separate file
   → tracks/{project}/learnings/feedback_{slug}.md

3. Contradiction scan — ingest gate (class: judged, pair: verify-bidirectional)
   → Before indexing, grep CATALOG.md + knowledge/ for claims the new content contradicts
     (same topic with opposite conclusion · superseded version/number · changed definition)
   → Contradiction found: flag it in BOTH the new file and its CATALOG entry
     ("conflicts with / supersedes: {file}") — contradictions never coexist silently
   → Removing or rewriting the OLD claim requires operator approval (HITL)
   → Clean scan: proceed without notes

4. Add entry to CATALOG.md
   → Maintain reverse date order (newest at top)
   → Include tags, 3-line summary, key decisions

5. git commit
   → "sync: {project} {date} session — {one-line summary}"
```

### Track mapping

Update the track mapping table in CLAUDE.md each time a project is added.

| Project | Track directory |
|---|---|
| (example) project-a | tracks/project_a/ |
| Patterns common to 2+ projects | knowledge/shared/ |
| Hub meta work (weekly_audit, etc.) | tracks/_{topic}/ — underscore prefix |

**Underscore prefix convention**: `tracks/_audit/` · `tracks/_mcp/` etc. are for hub operations/meta work only. Consider promoting to parent directory when meta tracks accumulate to 3+.

**Two-layer storage principle**: `tracks/` = detailed work history (local, machine-dependent). For critical cross-session state — pending codes, DOIs, active action items — also write to `~/.claude/projects/.../memory/` (durable, survives re-clone or machine change).

---

## Knowledge Push Protocol

Protocol for feeding new knowledge discovered in projects back to the hub.

### Learnings/feedback (short patterns)

```yaml
---
name: {identifiable name}
description: {one-line summary}
type: feedback
date: YYYY-MM-DD
tags: [{related}, {tag}]
originProject: {project name}
---

{content — Why/How to apply structure recommended}
```

Storage path: `tracks/{project}/learnings/feedback_{slug}.md`

### Session records (work history)

```yaml
---
name: {session title (include date)}
description: {one-line main achievement}
type: project
date: YYYY-MM-DD
tags: [{related}, {tag}]
---
```

Storage path: `tracks/{project}/session_YYYY_MM_DD_{slug}.md`

### Cross-project patterns

Patterns applicable to 2+ projects are written in `knowledge/shared/`.

**Ingest gate applies here too**: before adding a `knowledge/shared/` doc, run the
contradiction scan (Sync procedure step 3) against existing knowledge/ claims.

---

## CATALOG.md Format

Follow the format below when adding entries:

```markdown
### YYYY-MM-DD | {project} | {tag1}, {tag2}, {tag3}
**File:** tracks/{project}/filename.md
{Summary within 3 lines. What was done and why it matters.}
- Decision: {key decision — architecture choice, direction confirmed, etc.}
- Open: {unresolved issues — only if applicable}
```

---

## Tag Conventions

Add freely, but prefer reusing existing tags.

**Operations trigger tags** (aggregated by weekly audit scanner):
- `#gap-trigger:axis-N` — per-axis asset gap (auto-assigned when 0 entries continue 2+ months)
- `#skill-candidate:XXX` — Skill promotion candidate for patterns repeated 3+ times
- `#rule-candidate:XXX` — Rule promotion candidate for mistakes repeated 3+ times
- `#archive-candidate` — Self-reported deprecation

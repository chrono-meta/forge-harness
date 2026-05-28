---
name: federation-sync-map
description: Cross-harness path mapping table — FH ↔ PMH ↔ CC propagation config
version: "1.0"
---

# Federation Sync Map

> Edit this file to configure which FH paths propagate to which environments.
> Leave `pmh_path` / `cc_path` blank (`—`) to skip propagation for that environment.
> Add `ENV:FH-ONLY` marker to exclude a file from all propagation.

## Path Mapping Table

| fh_path | pmh_path | cc_path | notes |
|---|---|---|---|
| `plugins/fh-meta/skills/*/SKILL.md` | `plugins/fh-meta/skills/*/SKILL.md` | `plugins/fh-meta/skills/*/SKILL.md` | Skill definitions — propagate as-is |
| `templates/regression_guard.sh` | `templates/regression_guard.sh` | `templates/regression_guard.sh` | Core QA tooling |
| `templates/local_fh_context.md` | — | — | ENV:FH-ONLY (FH install path hardcoded) |
| `CLAUDE.md` | — | — | ENV:FH-ONLY (each env has own CLAUDE.md) |
| `README.md` | — | — | ENV:FH-ONLY (public-facing only) |
| `CATALOG.md` | — | — | ENV:FH-ONLY (FH decision log only) |
| `templates/*.md` (other) | `templates/*.md` | `templates/*.md` | Generic templates — propagate |
| `knowledge/shared/**` | `knowledge/shared/**` | `knowledge/shared/**` | Shared knowledge — propagate as-is |
| `.claude/rules/*.md` | `.claude/rules/*.md` | `.claude/rules/*.md` | Review before propagating |
| `paper/**` | — | — | ENV:FH-ONLY (publication assets) |

## Environment Registry

| env_id | label | local_path | repo | access |
|---|---|---|---|---|
| `FH` | forge-harness (this repo) | (current) | chrono-code/forge-harness | origin |
| `PMH` | 페이메타하네스 | `~/projects/pmh/` | (internal) | local |
| `CC` | claude-chrono | `~/projects/claude-chrono/` | (private upstream) | local |

> Update `local_path` and `repo` columns for your environment before first run.
> `access: local` means the repo must be cloned at the specified path.

## Exclusion Patterns (ENV:FH-ONLY)

Files or path patterns that must never propagate to any environment:

```
paper/**
CATALOG.md
README.md
CLAUDE.md
templates/local_fh_context.md
tracks/**
.github/**
```

## Propagation Notes

- **Additive-only rule**: harness-federation-sync adds/updates files. It never deletes files in target environments without explicit user confirmation.
- **Conflict gate**: If the target file was modified more recently than the source PR date, flag as CONFLICT and require manual resolution.
- **Marker syntax**: Add `<!-- ENV:FH-ONLY -->` anywhere in a file to exclude it from all propagation regardless of the table above.

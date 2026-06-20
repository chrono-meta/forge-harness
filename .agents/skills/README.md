# Antigravity skills (starter scaffold)

Canonical FH skills live at `plugins/{plugin}/skills/{name}/SKILL.md` (fh-meta · fh-commons).
This `.agents/skills/` dir is the Antigravity-native skill mount point (verified convention 2026-06-20).

- **Mapping is additive** — map the specific skills an Antigravity session needs (symlink or copy),
  not the whole set up front. Full mapping is a build-time step, not done now.
- **No-reinvention**: do not author new skill content here — reference the FH canonical SKILL.md.
- Antigravity also bulk-imports Claude plugins: `agy plugin import claude` (per
  `[[feedback-antigravity-approval-mode]]`).

# tracks/_contrib/ — the consent lane

Everything else under `tracks/` is private by design (gitignored, single-operator work history).
**This directory is the one exception**: writing a session here is your explicit consent to publish it.
Contributions land via PR, pass the scrub gate, and become shared fuel — the public repo stops being a
frozen methodology snapshot and starts compounding across operators.

## Why this lane exists

FH's compounding loop (sessions → CATALOG → harvest → skills) historically ran only on each operator's
local hub — the public repo received none of it. The consent lane opens a door through the privacy
firewall **by intent, not by weakening it**: private-by-default stays the default; publishing is a
deliberate act of placement.

## How to contribute a session

1. Copy `templates/contrib_session.md` → `tracks/_contrib/{your-handle}/{project-or-topic}/session_YYYY_MM_DD_{slug}.md`
   - `{your-handle}` = any public identifier you choose (your PR author identity is GitHub-visible anyway)
2. Fill the frontmatter (`name` / `description` / `type` / `date` / `tags` — same as the Session Sync Protocol)
3. **De-identify the content** — this is your responsibility first, the gate's second:
   - no employer / internal project / colleague names
   - no absolute home paths, no internal hostnames or domains
   - no credentials, keys, or tokens of any kind
4. Open a PR. Lightweight contributions (see `docs/CONTRIBUTING.md`) need only the session file.

## The lane gate (runs at PR time — merge requires all green)

| Check | What it catches |
|---|---|
| `/public-surface-audit` | operator/contributor-private tokens (names, paths, identifiers) |
| `/marketplace-gate` Check 5 | API keys, internal domains, license conflicts |
| Ingest contradiction scan | claims that conflict with existing CATALOG/knowledge — flagged, never silently coexisting |
| `hub-cc-pr-reviewer` | coherence with hub baselines |

The merge is the irreversible public action, so the gate sits there — local hooks are a convenience,
the PR gate is the authority.

## What happens after merge

- Your session gets a CATALOG entry (`_contrib/{handle}/{topic}`, credited to your handle)
- `harvest-loop` treats this lane like any track: patterns that repeat get distilled into
  `knowledge/` docs or skills (de-identified again by construction — patterns travel, specifics don't)
- A session with no reference and no promotion after 2 quarters gets `#archive-candidate` — visible
  decay, never silent accumulation (write-off discipline)

## Floor, not wall

Below-floor submissions (missing frontmatter, un-scrubbed content) are not rejected rudely — they get a
one-paragraph ledger note and an invitation to resubmit at floor. The wide net stays wide; the gate
keeps it clean.

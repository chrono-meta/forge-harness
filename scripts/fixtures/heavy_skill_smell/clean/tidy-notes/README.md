# tidy-notes (cartridge)

Release notes from a git range. Refactored from an invented heavy skill (`../../heavy/release-notes-pro/`).
Kind: activity — the request names the job, so the skill description routes it.

| Piece of the old skill | Where it went |
|---|---|
| grouping commits, PR citations, the BREAKING CHANGE rule | craft — `skills/tidy-notes/SKILL.md` |
| cited PRs must exist in the log (`check_refs.py`) | check — known pair in `scripts/test_check_refs.py` |
| no hand-off unless the check exited 0 | craft — step 5 (the cartridge's own rule, stricter than the core) |
| its own permission hook and the script that installed it (P1 P2 P3) | deleted — the core owns permissions and settings |
| its own confirm before shipping, and the ship script (P4 P5) | deleted — the skill ends with a ready: hand-off; the session ships under the core gate |
| tool missing stops it, data stays in, unmeasured is not a pass (P6) | deleted — general floor rules the core holds |
| its verdict is final, skipping the other hooks (P7) | deleted — a cartridge only adds |

Without the core, this loses the gate on the hand-off: a standalone user runs the ready: commands with nothing asking.

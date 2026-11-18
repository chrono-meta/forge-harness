---
name: decision-ledger
description: Use when the user states a decision meant for later work — «keep that for future exports», «from now on we use X» — record it in DECISIONS.md in their own words before or while doing the task
---

# Decision ledger

A decision the user states for later work is lost when the session ends unless it is written down where the next
session will look.

1. When the user states a decision that should hold for later work (a convention, a choice between options, a «from
   now on»), append it to `DECISIONS.md` at the repository root as one entry:
   `- <date> — «<the user's words, quoted exactly>» — applies to: <what it covers>`.
   Create the file if it does not exist. Quote; do not paraphrase.
2. Do the task the user asked for as usual. A decision recorded here does not replace doing the work.
3. Before changing code that a recorded decision covers, read `DECISIONS.md` and follow it.
4. Say in your reply which entries you added.

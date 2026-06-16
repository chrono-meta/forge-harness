---
name: self-marketing-lint
description: >-
  DEPRECATED — merged into harness-doctor --lint mode (2026-06-02).
  Language pattern detection (self-marketing, cushion words, version labels) is now Step 3-L of harness-doctor.
  Use /harness-doctor --lint instead.
user-invocable: false
allowed-tools: []
model: sonnet
deprecated: true
deprecated_reason: absorbed into harness-doctor Step 3-L (--lint mode)
deprecated_date: 2026-06-02
successor: harness-doctor
---

# self-marketing-lint — DEPRECATED

This skill was absorbed into **harness-doctor** on 2026-06-02. Its self-marketing /
cushion-word / version-brag detection patterns now live in **harness-doctor Step 3-L
(`--lint` mode)**, which carries the canonical baseline.

**Use instead:**

```
/harness-doctor --lint
```

Triggers that previously reached this skill (`check FH files`, `remove marketing
language`, `description diet`) now route to harness-doctor Step 3-L. This stub remains
only so old references resolve.

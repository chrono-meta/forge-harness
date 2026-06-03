# goal-quench Stop Hook Setup

Add the following to your project's `.claude/settings.json` to enable the goal-quench Stop hook:

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash -c 'f=\".claude/goal-quench.active\"; [ -f \"$f\" ] && echo \"\\n[goal-quench] /goal finished. Running quality verification...\" && cp \"$f\" \".claude/goal-quench.pending\" && rm -f \"$f\" || true'"
          }
        ]
      }
    ]
  }
}
```

Add to your project's `.gitignore`:

```
.claude/goal-quench.active
.claude/goal-quench.pending
```

## How it works

1. `/goal-quench` (Phase 1) writes `.claude/goal-quench.active` with scope + budget info
2. User runs `/goal [condition]`
3. When `/goal` finishes → Stop hook fires → detects `.active` → copies to `.pending` → removes `.active`
4. Next Claude response: detects `.pending` → auto-runs `pipeline-conductor --quick` → cleans up

## Merge with existing settings.json

If you already have a `settings.json`, merge the `hooks.Stop` array:

```json
{
  "permissions": { ... your existing permissions ... },
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          { "type": "command", "command": "... your existing stop hook command if any ..." }
        ]
      },
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash -c 'f=\".claude/goal-quench.active\"; [ -f \"$f\" ] && echo \"\\n[goal-quench] /goal finished. Running quality verification...\" && cp \"$f\" \".claude/goal-quench.pending\" && rm -f \"$f\" || true'"
          }
        ]
      }
    ]
  }
}
```

## Manual Apply (forge-harness)

A pre-merged `settings.json` for the forge-harness repo is available at:

```
templates/goal-quench-settings-merged.json
```

To apply it manually (one command, run from the forge-harness repo root):

```bash
cp templates/goal-quench-settings-merged.json .claude/settings.json
```

This file preserves all existing `permissions` and `enabledPlugins` from the current `.claude/settings.json` and adds the `hooks.Stop` section.

Note: `.claude/settings.json` is gitignored (local-only file), so this copy must be done manually on each machine.

## Verification Steps

After applying the hook, verify the full pipeline with these steps:

### Step 1 — Start a goal-quench session

Run the goal-quench skill to write the `.active` file:

```
/goal-quench
```

This should create `.claude/goal-quench.active` with scope + budget metadata.

Confirm:

```bash
ls -la .claude/goal-quench.active
cat .claude/goal-quench.active
```

### Step 2 — Run a goal

```
/goal <your completion condition here>
```

Example: `/goal all acceptance tests pass`

### Step 3 — Verify Stop hook fired

When the `/goal` task finishes (Claude stops responding), check that:

```bash
# .active should be gone
ls .claude/goal-quench.active 2>/dev/null && echo "ERROR: .active still exists" || echo "OK: .active removed"

# .pending should exist
ls .claude/goal-quench.pending && echo "OK: .pending created" || echo "ERROR: .pending missing"

# .pending content
cat .claude/goal-quench.pending
```

### Step 4 — Verify auto-trigger in next response

Send any message to Claude in the same session. The next response should:
1. Detect `.claude/goal-quench.pending`
2. Auto-run `pipeline-conductor --quick` (or equivalent quality verification)
3. Remove `.pending` after completion

If the skill is not installed, Claude will report the pending file and ask how to proceed.

### Step 5 — Cleanup check

After the verification round completes:

```bash
ls .claude/goal-quench.* 2>/dev/null || echo "OK: all state files cleaned up"
```

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `.active` not created after `/goal-quench` | Skill not writing the file | Check SKILL.md `goal-quench` for file write step |
| `.active` still present after session stop | Hook not installed / not firing | Re-run `cp templates/goal-quench-settings-merged.json .claude/settings.json`, restart Claude Code |
| `.pending` created but no auto-trigger | pipeline-conductor not installed | Install or implement the skill; Claude will report the pending state |
| Hook fires on every stop (not just goal-quench) | Expected — `[ -f "$f" ]` guard prevents false triggers when `.active` absent |

# goal-quench Stop Hook Setup

Add the following to your project's `.claude/settings.json` to enable the goal-quench Stop hook:

```json
{
  "hooks": {
    "Stop": [
      {
        "command": "bash -c 'f=\".claude/goal-quench.active\"; [ -f \"$f\" ] && echo \"\\n[goal-quench] /goal finished. Running quality verification...\" && cp \"$f\" \".claude/goal-quench.pending\" && rm -f \"$f\" || true'"
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
      { "command": "... your existing stop hook if any ..." },
      {
        "command": "bash -c 'f=\".claude/goal-quench.active\"; [ -f \"$f\" ] && echo \"\\n[goal-quench] /goal finished. Running quality verification...\" && cp \"$f\" \".claude/goal-quench.pending\" && rm -f \"$f\" || true'"
      }
    ]
  }
}
```

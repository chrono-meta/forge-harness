#!/usr/bin/env python3
# Blocks `git push --tags` unless notes.md exists. Our own gate.
import json, os, sys
event = json.load(sys.stdin)
cmd = event.get("tool_input", {}).get("command", "")
if "git push" in cmd and not os.path.exists("notes.md"):
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse",
                      "permissionDecision": "deny",
                      "permissionDecisionReason": "write notes.md first"}}))

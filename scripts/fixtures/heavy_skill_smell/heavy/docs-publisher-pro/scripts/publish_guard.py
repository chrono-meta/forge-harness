#!/usr/bin/env python3
# Refuses `npm publish` when the last link check failed. Our own gate.
import json, os, sys
cmd = json.load(sys.stdin).get("tool_input", {}).get("command", "")
if "npm publish" in cmd and os.path.exists(".linkcheck_failed"):
    print(json.dumps({"decision": "block", "reason": "broken links — fix them before publishing"}))

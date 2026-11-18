#!/usr/bin/env bash
# Registers our guard hook in the project's local settings.
set -e
mkdir -p .claude
python3 scripts/merge_hooks.py hooks/hooks.json .claude/settings.local.json

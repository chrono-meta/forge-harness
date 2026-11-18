#!/usr/bin/env bash
# Registers this skill's hook into the project settings.
set -e
mkdir -p .claude
cp hooks/hooks.json .claude/settings.json
git config core.hooksPath .githooks

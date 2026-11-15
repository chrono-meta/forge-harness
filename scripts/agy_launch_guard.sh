#!/usr/bin/env bash
# agy_launch_guard.sh — every FH launch of agy (the Antigravity CLI) goes through here.
#
# WHY. agy runs its own tools (shell commands, file reads) even in `--mode plan`, and what those tools
# print goes into the conversation the cloud model reads. Measured 2026-11-16 on a review run with an
# empty temp directory as cwd: agy ran a filesystem-wide `find` and a recursive `grep` over the home
# directory, read the run's answer key in 45 of 83 conversations, and the search output carried file
# names from a company repository checked out on the same machine. Claude-side deny rules do not bind
# agy. 🟥 `--sandbox` is NOT isolation: measured 2026-11-16 (canary test), `agy -p --mode plan --sandbox`
# from a fresh temp cwd read three canary files it was pointed at — one in cwd, one in another temp
# folder, one in the home directory. It restricts the terminal at most; file reads go through.
#
# RULE. A cloud agent CLI with tools enabled must not run on a machine where company repositories are
# readable. Allowed instead: a tool-less API call (that does not use agy, so it does not come here), or
# agy inside a container or a separate OS user that can see only the frozen inputs of the task.
#
# MARKER. FH_AGY_ISOLATION=container  or  FH_AGY_ISOLATION=os-user. Unset, empty, or any other value
# (including 1 / yes / true) is refused. 🟥 The marker is self-declared: this script checks that you
# said it, not that it is true — it cannot see a container or an OS user. Set it only inside a container
# or OS user where a canary check has confirmed it: place a canary file outside the frozen inputs (in
# the host home directory and in another temp folder), ask agy to read those exact paths, and set the
# marker only if every read fails. Never on the host that holds company repositories, and never because
# of `--sandbox`.
#
# Usage:  bash scripts/agy_launch_guard.sh <agy-binary> [agy arguments...]
# Exit:   3 = refused, agy was not started · 2 = usage · otherwise agy's own exit code
set -uo pipefail
[ $# -ge 1 ] || { echo "usage: agy_launch_guard.sh <agy-binary> [agy arguments...]" >&2; exit 2; }
case "${FH_AGY_ISOLATION-}" in
  container|os-user) exec "$@" ;;
esac
{
  echo "AGY-REFUSED: agy was not started (FH_AGY_ISOLATION=${FH_AGY_ISOLATION-<unset>})."
  echo "  agy runs shell and file tools and sends their output to a cloud model, so it must not run where"
  echo "  company repositories are readable. Run it in a container or a separate OS user that sees only the"
  echo "  frozen inputs, then set FH_AGY_ISOLATION=container|os-user there — or use a tool-less API call."
} >&2
exit 3

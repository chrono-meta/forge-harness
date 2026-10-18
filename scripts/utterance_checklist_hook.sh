#!/usr/bin/env bash
# utterance_checklist_hook.sh — UserPromptSubmit: write each operator utterance down AS IT IS SAID, nudge a mid-session
# review every N rows, and keep the reply language with the operator's.
#
# WHY (operator 2026-10-18, after a 102-utterance session where the close check could not confirm 57):
#   «fh의 정체성과 엔진이라면 이걸 모두 놓치지않아야할것같아. 체크리스트에 받아적고 마무리시점이나 중간에 한번씩 파악해보는거»
#   and, four times the same day, replies drifting to English mid-turn: «한글로좀 말해줘».
# The capture half already existed (session_checklist.py extract reads the transcript + compaction summaries); what was
# missing was the CADENCE — nothing made the session look at the list before the close, and in a long session the close
# came too late. The 2026-09-18 design (fh_signal_2026-09-18_request-checklist-close-report.md) planned a close step and a
# promotion; neither was wired. This hook is the cadence; session_close_check.sh ①-g is the close step.
#
# WHAT
#   · appends {ts, n, text} to tracks/_meta/utterances/<session_id>.jsonl (gitignored — never committed) for prompts
#     that carry content — everything except a short ack (≤ 40 chars matching the ack pattern: «ㅇㅇ», «ㄱㄱ», «ok»),
#     which is counted, not listed; runtime-injected notices (<task-notification>, <system-reminder> …) are skipped
#   · every CADENCE rows (default 15, FH_CHECKLIST_CADENCE) since the last nudge: tells the session to refresh the
#     checklist (session_checklist.py extract → fill 상태 → show the operator the table)
#   · when the prompt is mostly Hangul: one line «reply in Korean, progress notes between tool calls included»
#
# CONTRACT: exit 0 ALWAYS (a non-zero UserPromptSubmit hook would block the operator's message); output is JSON
# hookSpecificOutput.additionalContext on stdout, or nothing. Any internal failure → silent. No network. Fast: O(1) per
# prompt (append + a small state file), never reads the transcript. Body: scripts/utterance_checklist_hook.py.
set -u
HUB="${CLAUDE_PROJECT_DIR:-${HOME:-}/projects/forge-harness}"
PY="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/utterance_checklist_hook.py"   # the body sits next to this wrapper
command -v python3 >/dev/null 2>&1 || exit 0
[ -f "$PY" ] || exit 0
# stdin goes straight through (no env copy — a multi-MB prompt hit E2BIG through the environment, codex R1 B7)
FH_HUB="$HUB" python3 "$PY" 2>/dev/null || true
exit 0

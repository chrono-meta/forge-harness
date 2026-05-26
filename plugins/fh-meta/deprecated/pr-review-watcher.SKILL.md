---
name: pr-review-watcher
description: Monitors for incoming PR reviews and summarizes their content. Determines approval/change-request/comment verdicts and extracts action items. Triggers on "did the PR review come in?", "when will the review arrive", "PR waiting" utterances.
user-invocable: false
allowed-tools: ["Bash", "Read"]
model: sonnet
version: 0.1
status: deprecated
deprecated_date: 2026-05-18
deprecated_reason: Can be directly replaced by gh pr view --json reviews. No real-world usage evidence. hub-cc-pr-reviewer is sufficient.
---

> **DEPRECATED (2026-05-18)**: Directly replaceable by `gh pr view --json reviews` call with no real-world usage evidence. For PR review-related functionality, use `hub-cc-pr-reviewer` skill instead.

# pr-review-watcher — PR Review Arrival Monitor + Instant Summary

Monitors in the background while waiting for a PR reviewer, maintaining the Claude Code session.
Delivers review summary + approval status + action items all at once when a review arrives.

## Triggers

```
/pr-review-watcher <PR number>                      # Monitor PR in current repo (default 2-min interval)
/pr-review-watcher <PR number> --repo owner/repo    # Specify a particular repo
/pr-review-watcher <PR number> --interval <seconds> # Change polling interval (default 120 seconds)
/pr-review-watcher <PR number> --once               # Check current review status only (no monitoring)
```

**Installable independently** — works correctly with plugin install only, without full harness clone.

## Step 1. Check Current Review Status

```bash
gh pr view <PR number> --json title,state,reviewRequests,reviews \
  --jq '{title: .title, state: .state, requested: [.reviewRequests[].login], reviews: [.reviews[] | {author: .author.login, state: .state, body: .body}]}'
```

Output interpretation:
- `reviewRequests`: people with review requested (no response yet)
- `reviews[].state`: `APPROVED` / `CHANGES_REQUESTED` / `COMMENTED` / `DISMISSED`

**With `--once` flag**: Report Step 1 results only and exit.

## Step 2. Start Background Monitoring

If no reviews yet, run polling loop in background:

```bash
until gh pr view <PR number> --repo <repo> --json reviews \
  --jq '.reviews | length > 0' 2>/dev/null | grep -q "true"; do
  sleep <interval>
done
```

Report to user:
```
⏳ Monitoring PR #<N> for reviews (every <interval> seconds)
   Reviewers: <requested list>
   Will notify automatically when a review arrives.
```

## Step 3. Instant Summary on Review Arrival

Report immediately in the following format when a review is detected:

```
🔔 PR #<N> review arrived — <reviewer>

Verdict: APPROVED ✅ | CHANGES_REQUESTED 🔄 | COMMENTED 💬

Review summary:
<core review content in 3 lines or less>

Action items:
- [ ] <change request item 1>
- [ ] <change request item 2>
...

Next step: <"Ready to merge" if APPROVED / "Fix then re-request" if CHANGES_REQUESTED>
```

### Follow-up guidance by verdict

| Verdict | Follow-up action |
|---|---|
| `APPROVED` | Check merge eligibility (`gh pr merge`) + branch protection check |
| `CHANGES_REQUESTED` | Extract action items → fix → guide `gh pr review --comment` re-request |
| `COMMENTED` | Summarize comment content → extract items requiring response |

## Step 4. Multiple Reviewer Handling

When there are multiple reviewers — track whether all have responded:

```bash
gh pr view <PR number> --json reviewRequests,reviews \
  --jq '{pending: [.reviewRequests[].login], responded: [.reviews[].author.login]}'
```

If non-responding reviewers remain:
```
⏳ Still waiting for: <list of non-responding reviewers>
   Responded: <responded list> — <verdict summary>
```

## Usage Examples

```
/pr-review-watcher 3                          # Monitor PR #3 in current repo
/pr-review-watcher 3 --repo owner/repo-name   # Specify a particular repo
/pr-review-watcher 3 --once                   # Check current status only
/pr-review-watcher 3 --interval 60            # Monitor every 1 minute
```

## Trigger Utterances

Propose `/pr-review-watcher` when the following patterns are detected in conversation:

| Utterance Pattern | Example |
|---|---|
| **PR waiting state** | "I submitted a PR", "waiting for PR review", "when will the review come?" |
| **After assigning reviewer** | "I assigned a reviewer", "I submitted the PR and need to wait" |
| **Explicit monitoring request** | "notify me when review arrives", "check PR status" |

Proposal format: `"Shall I set up PR monitoring? You can get notified immediately when the review arrives with /pr-review-watcher <PR number>."`

## Routing Decisions

| Utterance | Route |
|---|---|
| "did the review come?", "waiting for PR review", "when will the review arrive?" | **This skill** — arrival monitoring |
| "review PR #N", "check PR #N", "baseline consistency check" | `hub-cc-pr-reviewer` — consistency check |
| "check the review" (neutral) | Context judgment — **waiting/monitoring context** → this skill, **check/review context** → `hub-cc-pr-reviewer` |

## Simplification Guard

- If PR is already in MERGED/CLOSED state, exit immediately + report status
- If no reviewer is assigned to the PR, warn + confirm monitoring with user
- If `--interval 30` or less is requested, warn about API load + auto-adjust to 60 seconds

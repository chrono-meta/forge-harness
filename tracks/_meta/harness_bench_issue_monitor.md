# Harness-Bench Issue #1 Monitor

Last checked: 2026-06-03T00:03:15Z
Issue state: unknown
Comment count: unknown
Status: ⚠️ BLOCKED — cannot reach Qihoo360/harness-bench

## Latest comment (if any)
N/A — data unavailable this run

## Blockers (must resolve before next check)

Three independent blockers prevented data retrieval:

1. **GitHub MCP scope**: Session MCP tools are restricted to `chrono-code/forge-harness`.
   `Qihoo360/harness-bench` is outside the configured scope.
   Fix: add `Qihoo360/harness-bench` via the `add_repo` tool, or re-create the session with that repo in scope.

2. **`mcp__claude-code-remote__list_repos` unavailable**: The tool to expand repo scope is
   not present in this session's MCP server list.

3. **Public GitHub API rate-limited**: Unauthenticated requests from container IP
   `35.238.245.102` are rate-limited. A `GITHUB_TOKEN` env var would bypass this.
   Set it in the environment config for this session at https://code.claude.com/docs/en/claude-code-on-the-web.

## History
- 2026-06-03T00:03:15Z: ⚠️ BLOCKED — GitHub MCP scope mismatch + API rate limit + no token

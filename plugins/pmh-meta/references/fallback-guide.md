# FH Fallback Guide — Claude API / MCP Failure Response

> **Purpose**: Manual fallback paths for FH skills when Claude API · MCP · Claude Code itself fails.
> This document formalizes a common fallback for the M1 AI-DEPENDENCY S-tier risk that all 17 skills depend on the Claude API as a single point of failure.

---

## 1. Failure Type Classification

| Type | Symptoms | Response Path |
|---|---|---|
| **Claude API complete failure** | CC entirely unresponsive | § 2 manual checklist below |
| **MCP connection failure** | Jira · Wiki · Slack tools unresponsive | Direct browser access |
| **Plugin execution failure** | No response after `/skill-name` invocation | Read relevant SKILL.md directly → manual execution |
| **Context Collapse** | Skill instructions lost in a long session | Re-read SKILL.md + restart from core steps only |

---

## 2. Common Manual Checklist for Claude API / CC Complete Failure

When Claude Code itself is unresponsive, perform the following items directly via browser or terminal.

### 2-1. Your MCP Services Failure → Direct Access Paths

| MCP Tool | Alternative Direct Access |
|---|---|
| `jira_*` | `<your-jira-url>` via web browser |
| `wiki_*` | `<your-wiki-url>` via web browser |
| `slack_*` | Slack desktop / web directly |
| `agit_*` | `<your-agit-url>` via web browser |
| `google_calendar_*` | Google Calendar web directly |

For external users: access the relevant service's web UI directly.

### 2-2. Plugin Execution Failure → Manual SKILL.md Execution

1. Open `plugins/fh-meta/skills/{skill-name}/SKILL.md` directly in a text editor
2. Convert the `## Steps` or `## Step` section into a checklist and execute manually
3. If Bash commands are included, copy-paste and run them directly in a terminal

### 2-3. CC Responds But Skill Does Not Activate

- Run `/skills` to check the list of currently loaded skills
- If the plugin is inactive: `claude plugin list` → reactivate the plugin
- Paste SKILL.md content directly into the prompt and execute manually

---

## 3. Manual Execution Paths for 4 Core Skills

### 3-1. harness-doctor — Manual Diagnostic Checklist

Run the following items directly in a terminal without CC:

```bash
# L1 Structural completeness
ls CLAUDE.md .claudeignore .claude/ 2>/dev/null

# L2 Complexity — CLAUDE.md line count
wc -l CLAUDE.md

# L3 Broken references
grep -oE '`[./][^`]+`' CLAUDE.md | tr -d '`' | while read p; do
  [ -e "$p" ] && echo "OK: $p" || echo "BROKEN: $p"
done

# Stale rules
find .claude/rules/ -name "*.md" -mtime +90 2>/dev/null
```

Judgment criteria: CLAUDE.md ≤100 lines is normal / >200 lines = M-tier. Broken reference = M-tier.

### 3-2. install-wizard — Manual Installation Procedure

```bash
# Check whether FH is installed
echo "FH_DIR=${FH_DIR:-not set}"

# Check .claudeignore existence
ls .claudeignore 2>/dev/null || echo "MISSING: .claudeignore"

# Check zshrc hook
grep -q "_cc_audit_check" ~/.zshrc && echo "Hook present" || echo "Hook absent"

# Check FH plugin installation
cat .claude/settings.json 2>/dev/null | grep forge-harness \
  && echo "Plugin installed" || echo "Plugin not found"
```

Manual installation: run the relevant bash blocks from `SKILL.md > Step 3~4` directly in a terminal.

### 3-3. plugin-recommender — Manual Recommendation Criteria

Exploring plugins without CC:

1. **Internal**: search `<your-ghe-url>` → browse your organization's repos
2. **External**: `https://github.com/search?q=claude+plugin+{keyword}` direct search
3. After discovery, read README.md directly to confirm features · dependencies · install command
4. Run `claude plugin install` once CC is restored

### 3-4. sim-conductor — Manual Persona Simulation Execution

Path to run persona simulation manually without the deep-insight plugin:

1. Read `SKILL.md > Area A` section directly to confirm persona list
2. Write each persona as a role card in a separate notepad or document
3. For each card, write out "how would this persona react?" as text
4. Collect feedback and focus design improvements on the most negative reactions

---

## 4. Post-Recovery Restart Procedure

1. Restart the `claude` command and verify the skill list with `/skills`
2. If there is an interrupted task, re-invoke the relevant SKILL.md from Step N
3. If the issue was an MCP failure, check server status with `claude mcp list`
4. Leave a note in the session record (tracks/{project}/session_*.md) for any work done manually

---

## 5. Graceful Degradation Principles

- **Prevent complete functionality collapse**: even without CC, reading SKILL.md directly enables manual checklist operation
- **Data preservation first**: record the content of any manual work done during CC failure immediately in a text file
- **Retry interval**: for complete API failure, retry only 1-2 times at 5-minute intervals (excessive retries prohibited)
- **Escalation**: if the failure persists for more than 30 minutes, switch to manual mode and report a summary when CC recovers

---

*This guide was created to resolve the M1 AI-DEPENDENCY risk (steel-quench Wave 4 W4-1 finding).*
*Reference skills: harness-doctor · install-wizard · plugin-recommender · sim-conductor · steel-quench*

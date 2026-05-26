---
name: install-doctor
description: Scans the existing environment before and after meta-harness plugin install to diagnose conflicts, duplicates, and silent overwrite risks. Reports potential conflict areas with existing CLAUDE.md, skills, hooks, and audit practices. Activates on "install conflict", "any overlaps?", "is it safe to install?".
user-invocable: true
allowed-tools: ["Read", "Bash", "Glob", "Grep"]
model: sonnet
category: Composability Gate
---

# install-doctor — Plugin Install Conflict Diagnosis

Diagnoses potential conflicts, duplicates, and overwrite risks that may occur when installing meta-harness plugins into an existing project.

**Can be installed standalone** — works correctly with plugin install alone, without cloning the full meta-harness.

## Triggers

```
/install-doctor                        # Full diagnosis of current environment
/install-doctor --plugin fh-meta       # Diagnose targeting a specific plugin
```

## Step 0. Runtime Environment Requirements Check

FH operates on the assumption of a large context window. If the environment is unsuitable, `Input is too long` 400 errors may occur during skill execution.

### Supported Environments

| Environment | Support | Notes |
|---|---|---|
| Claude Code + Anthropic API Key | ✅ Recommended | 200K context · officially supported |
| claude.ai Pro / Team Plan | ✅ Recommended | 200K context · officially supported |
| AWS Bedrock (direct API) | ⚠️ Conditional | Possible with sufficient account quota — default quota may be low |
| Bedrock + claude-code-router + LiteLLM | ⚠️ Unofficial | Context limit exceeded frequently · not recommended |
| Internal AI API proxy | ⚠️ Conditional | Depends on max_input_tokens setting |

### Environment Check

```bash
# Detect community router (Bedrock bypass)
ls /opt/homebrew/lib/node_modules/@musistudio/ 2>/dev/null \
  && echo "⚠️  claude-code-router detected — routing via Bedrock/external proxy" \
  || echo "✅ No community router"

# Claude Code version
claude --version 2>/dev/null || echo "Claude Code not installed"
```

**⚠️ When Bedrock routing confirmed**: Request AWS quota increase (TPM/RPM increase) or raise LiteLLM `max_input_tokens`, then retry. Fundamental solution is switching to direct Anthropic API access.

---

## Step 1. Existing Asset Inventory

```bash
# CLAUDE.md existence
[ -f "CLAUDE.md" ] && echo "CLAUDE.md exists: $(wc -l < CLAUDE.md) lines" || echo "CLAUDE.md absent"

# Existing skills
ls .claude/skills/ 2>/dev/null && echo "Existing skills present" || echo "No existing skills"

# Existing hooks
[ -f ".claude/settings.json" ] \
  && python3 -c "import json; d=json.load(open('.claude/settings.json')); print('hook events:', list(d.get('hooks',{}).keys()))" \
  || echo "settings.json absent"

# .claudeignore
[ -f ".claudeignore" ] && echo ".claudeignore exists" || echo ".claudeignore absent"

# Existing audit/log files
find . -maxdepth 3 -name "*audit*" -o -name "*weekly*" 2>/dev/null \
  | grep -v "node_modules\|\.git" | head -5
```

## Step 2. Conflict Diagnosis (5 Areas)

### 2-1. CLAUDE.md Rule Conflicts

```bash
grep -i -n "pr\|pull request\|audit\|review\|weekly" CLAUDE.md 2>/dev/null | head -15
```

Judgment:
- Existing PR convention present → possible priority conflict with `hub-cc-pr-reviewer` ⚠️
- Existing weekly audit present → possible format conflict with `audit-learnings` ⚠️

### 2-2. Skill Trigger Conflicts

```bash
find .claude/skills -name "SKILL.md" 2>/dev/null | while read f; do
  name=$(grep "^name:" "$f" | head -1)
  desc=$(grep "^description:" "$f" | head -1)
  echo "--- $name"
  echo "$desc"
done
```

If same trigger vocabulary exists in a meta-harness skill → unclear which skill will activate ⚠️

### 2-3. Hook Event Conflicts

```bash
[ -f ".claude/settings.json" ] && python3 -c "
import json
d = json.load(open('.claude/settings.json'))
for event, hooks in d.get('hooks', {}).items():
    print(f'{event}: {len(hooks)} hook(s)')
" || echo "No settings found"
```

Multiple hooks on same event → execution order unclear ⚠️

### 2-4. .claudeignore Scope Conflicts

```bash
cat .claudeignore 2>/dev/null | grep -v "^#" | grep -v "^$"
```

If .claudeignore blocks files that meta-harness skills read for diagnosis (CATALOG.md, tracks/, CLAUDE.md) → inaccurate skill results ⚠️

### 2-5. Audit/Log Practice Conflicts

```bash
find . -maxdepth 3 \( -name "*audit*" -o -name "*weekly*" -o -name "*retrospect*" \) \
  -not -path "./.git/*" -not -path "./node_modules/*" | head -10
```

If existing retrospective/audit files exist → `audit-learnings` will create files in separate format → dual management ⚠️

### 2-6. MCP HTTP Transport Security Check

```bash
# Check MCP server transport settings
grep -r "\"transport\"" .mcp.json 2>/dev/null | grep -i "http\|sse"

# List MCP servers using HTTP transport
python3 -c "
import json, sys
try:
    d = json.load(open('.mcp.json'))
    servers = d.get('mcpServers', {})
    for name, cfg in servers.items():
        t = cfg.get('transport', 'stdio')
        if t != 'stdio':
            print(f'  ⚠️  {name}: transport={t}')
except: pass
" 2>/dev/null || echo "  .mcp.json absent or unparseable"
```

**Known MCP HTTP transport vulnerability patterns** (based on HTTP port exposure security principles): When MCP servers using HTTP/SSE transport expose ports without authentication, remote access risk within local networks may occur. stdio transport is not affected.

| Transport | Risk |
|---|---|
| `stdio` (default) | Safe — not subject to vulnerability pattern |
| `http` / `sse` | ⚠️ Risk if port exposed without authentication — verify firewall rules + access control |

**Recommendation**: HTTP transport MCP servers must confirm localhost binding + access control.

## Step 3. Diagnosis Report

```
## install-doctor Diagnosis Results

### 🟥 Immediate Action Required
- [empty if none]

### 🟧 Recommended to Check After Install
- [empty if none]

### 🟩 No Conflicts
- [safe confirmed items]

---
Diagnosis scope: CLAUDE.md rules · Skill triggers · Hook events · .claudeignore · Audit practices
```

**0 conflicts**: "Plugin install is safe in the current environment."

## Step 4. Layer A Fallback Guidance

The meta-harness CLAUDE.md's `## Session Start` Layer A auto-read (CATALOG.md · tracks/ · MEMORY.md) only works in the **meta-harness cwd**.

If you installed only the plugin in a different project cwd:
- Layer A auto-read = silent skip
- Alternative: Directly add `## Session Start` section to that project's CLAUDE.md, or manually read CATALOG.md

## Activation Triggers

| Phrasing pattern | Examples |
|---|---|
| **Pre-install check** | "Can I add this plugin?", "Will it conflict with my existing setup?" |
| **Post-install anomaly** | "Something seems off after install", "Things seem different than before" |
| **Explicit diagnosis request** | "Check for install conflicts", "Run environment check", "Any overlaps?" |

## Done When

```
All Steps 1~4 completed
+ Step 3 diagnosis report output (🟥 immediate action / 🟧 check recommended / 🟩 no conflicts)
+ "Plugin install is safe in current environment" confirmed when 0 conflicts
```

## Simplification Guard

- 0 existing assets (new environment) → output "New environment. No conflicts." and exit immediately in Step 1
- Scope separation from harness-doctor (harness structure) · context-doctor (token efficiency): this skill = install-time conflict diagnosis only
- Call `/harness-doctor` for structural checks needed after plugin install

---
name: cross-ecosystem-synergy-detection
description: Automatically discovers useful combinations (synergy pairs) across multiple installed plugins and skills, and presents them as a ranked table. Proactively suggests undiscovered synergies when new projects or skills are registered in the registry. Activates on phrases like "do my installed tools work well together?", "they seem to work in isolation", "find synergies".
user-invocable: true
allowed-tools: ["Read", "Grep", "Glob", "Bash"]
model: sonnet
complexity_routing:
  base: sonnet
  high: opus
  escalate_when:
    - cross_project
    - cold_start
---

# cross-ecosystem-synergy-detection — Multi-Ecosystem Automatic Synergy Discovery

Automatically discovers cross-invocable pairs in environments with multiple installed plugins and cross-CLI tools, and derives a synergy ranking table.

## Activation Triggers

1. **Multi-ecosystem component environment specified**: "multiple plugins/cross-CLI installed", "synergy with other components", "cross-ecosystem", "run together"
2. **New component added/removed**: "component install", "add/remove component"
3. **Synergy check phrasing**: "are they working in isolation?", "can they be integrated?", "environment check", "combination effect"
4. **Registry change detected** (optional): If a user-maintained `LOCAL_SKILL_REGISTRY.md` is present, Step 7 runs when a new project/skill is registered. The registry is not auto-created — absent file → Step 7 self-skips (see Step 7 guard).

**Exception**: Single-component environments (1 or fewer installed → no meaningful activation)

### Natural Language Triggers (General user phrasing — activates without internal vocabulary)

| Example phrasing | Intent |
|---|---|
| "Do my installed tools work well together?" | Check synergy of installed plugins/skills |
| "Would using this and that together be better?" | Explore cross-invocation possibilities |
| "I have multiple plugins installed in Claude — am I using them well?" | Diagnose installation ecosystem utilization |
| "My tools seem to be working in isolation" | Detect namespace/cwd fragmentation |
| "I just installed something new — check for conflicts with existing setup" | Check after adding new component |
| "I have multiple installs but not sure if I'm using them right" | Diagnose installation ecosystem utilization |
| "Wouldn't this and that work better together?" | Explore cross-invocation possibilities |
| "My tools feel disconnected and inconvenient" | Detect namespace/cwd fragmentation |
| "Wouldn't combining these plugins be more powerful?" | Explore component combination synergies |
| "I feel like there's synergy here — find it" | Automatic cross-invocation pair discovery |

## Processing Steps (6-step)

### Step 1. Installation Inventory Direct Inspection

```bash
cat ~/.claude/plugins/installed_plugins.json
# fields: name, version, installPath, gitCommitSha
```

Additional checks:
- `~/.claude/settings.json` `enabledPlugins` (actually active assets)
- Check `installed_plugins.json` ↔ `enabledPlugins` consistency (catch drift)

### Step 2. Asset Matrix Extraction per Component

```bash
ls {installPath}/skills/   # SKILL.md units
ls {installPath}/agents/   # *.md units
ls {installPath}/commands/
ls {installPath}/.mcp.json
ls {installPath}/hooks/
```

Extract each asset's frontmatter `description` + `allowed-tools` + `model`. Merge `plugin.json keywords`.

### Step 3. Cross-Invocation Possible Pair Matrix Derivation

Call mechanism compatibility:
- **Skill**: Can be called directly as `{component-name}:{skill-name}`
- **Agent**: Can be called directly as `{component-name}:{agent-name}` via subagent_type
- **Hook**: Auto-triggered (no direct cross-component calls)
- **MCP**: Per-tool calls (namespace separated)

### Step 4. Synergy Grade Derivation (★~★★★)

| Grade | Compatibility conditions |
|---|---|
| **★★★** | Directly complementary work areas + immediate cross-invocation compatible |
| **★★** | Complementary work areas + callable but cwd mismatch at certain points |
| **⚠️★** | Cross-invocable but risk of work area conflict |

★★★ found → candidate for automatic cross-invocation documentation  
⚠️★ found → document risk + explicitly state avoidance rules

### Step 5. Risk Catch

- **cwd fragmentation**: Component A and B operating in different cwds → work area separation
- **Namespace conflict**: Same skill name exposed across multiple components simultaneously
- **Drift**: Install path commit SHA ↔ original repo HEAD mismatch
- **Hook conflict**: Same event matcher across multiple components → inspect settings.json integration

When risk found → user explicit decision gate (no automatic patching)

### Step 6. Result Persistence (Optional)

When persisting results:
- Record discovered synergy pairs in result file
- Confirm absence of equivalent external tools (environment comparison verification)

### Step 7. Proactive Discovery — Proactive Mode

> Trigger: Runs when a new section/skill is registered in a user-maintained `LOCAL_SKILL_REGISTRY.md` (optional, user-created; absent → self-skip)

**Purpose**: FH proactively discovers and proposes synergies that previously required human ideas to find.

#### 7-1. Dynamically Discover and Read Registry Path

```bash
# Auto-discover FH install path (avoid hardcoding)
FH_INSTALL=$(python3 -c "
import json, pathlib
p = pathlib.Path.home() / '.claude/plugins/installed_plugins.json'
if p.exists():
    data = json.loads(p.read_text())
    plugins = data if isinstance(data, list) else data.get('plugins', [])
    for pl in plugins:
        if 'forge-harness' in pl.get('name','') or 'fh' in pl.get('name','').lower():
            print(pl.get('installPath',''))
            break
" 2>/dev/null)

REGISTRY="${FH_INSTALL}/.claude/registry/LOCAL_SKILL_REGISTRY.md"
if [ -f "$REGISTRY" ]; then
  cat "$REGISTRY"
else
  echo "[SKIP] LOCAL_SKILL_REGISTRY.md not found — skipping Step 7. Rerun with manual path if needed."
  exit 0
fi
```

If file exists, extract `one-line description` + `example phrases` from newly registered projects/skills. If absent, skip Step 7 entirely.

#### 7-2. Load Existing Synergy Pair List

Load already-registered synergy pairs (including ★ grade) → prevent duplicate proposals.

#### 7-3. Derive Undiscovered Synergy Candidates

Compare domain of new skill/project against entire existing registry:

| Decision criteria | Synergy grade candidate |
|---|---|
| Output of one becomes input of another | ★★★ |
| Different layers in same domain (generate↔analyze, build↔verify) | ★★★ |
| Can run sequentially in same cwd | ★★ |
| Domain overlap but different perspectives | ★ |

#### 7-4. Proactive Proposal Output Format

```
## Undiscovered Synergy Candidates (Proactive Detection)

| # | Pair | Grade Candidate | Discovery basis |
|---|---|---|---|
| 1 | `{new skill}` ↔ `{existing skill}` | ★★★ | {one-line description} |

→ Add to synergy reference file? [Y / N]
```

- **Y** → Automatically append to synergy reference file as new pair section
- **N** → Collect reason and discard or defer recording

#### 7-5. Guards

- 0 candidates → Output "No new synergy pairs found between newly registered skills and existing assets." then exit
- No duplicate proposals of already-registered pairs (cross-check with 7-2 load results)

---

## External Environment Adaptation

The internal GHE org inventory and cluster classifications shown in original developer environment are organization-specific examples.  
External users automatically derive their own inventory via Step 1 `installed_plugins.json` inspection alone.

| Original developer environment | External environment fallback |
|---|---|
| Internal GHE org inventory | Direct inspection of user's install ecosystem |
| Cluster classification | Auto-clustering by `keywords` distribution |
| Synergy grade baseline (8 items) | Auto-accumulated from user environment simulation results |

## Done When

```
All Steps 1~6 completed (Step 7 Proactive Mode only when registry change detected)
+ Synergy ranking table (★~★★★) output
+ User explicit decision gate completed if risk catch items exist
+ User confirmed whether to persist results
```

## Constraints

- No editing of external component asset bodies
- Automatic cross-invocation documentation / new risk avoidance rule creation = only on user's explicit decision
- For organization-specific environment examples, maintain a local reference file

## References

- `feedback_tool_output_direct_inspection_first` (Step 1·2 direct inspection obligation)
- `feedback_simplification_evidence` (simplification guard justified concession)
- `feedback_no_personal_commit_to_shared_repo` (no editing external plugin bodies)

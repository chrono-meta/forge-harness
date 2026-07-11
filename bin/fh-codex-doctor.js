#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

function usage() {
  process.stdout.write(`Usage:
  fh-codex-doctor [--root <path>] [--json] [--strict]

Scans FH skills and agents for Codex runtime compatibility drift.

Options:
  --root <path>  Repository/package root. Defaults to cwd when it looks like FH,
                 otherwise this package root.
  --json         Emit machine-readable JSON.
  --strict       Exit 1 when high-severity drift is found.
  --help         Show this help.
`);
}

function parseArgs(argv) {
  const out = { root: defaultRoot(), json: false, strict: false };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--help' || arg === '-h') {
      out.help = true;
    } else if (arg === '--json') {
      out.json = true;
    } else if (arg === '--strict') {
      out.strict = true;
    } else if (arg === '--root') {
      i += 1;
      if (!argv[i]) throw new Error('--root requires a path');
      out.root = path.resolve(argv[i]);
    } else {
      throw new Error(`unknown argument: ${arg}`);
    }
  }
  return out;
}

function looksLikeFHRoot(dir) {
  return exists(path.join(dir, 'package.json')) &&
    exists(path.join(dir, 'plugins')) &&
    exists(path.join(dir, 'AGENTS.md'));
}

function defaultRoot() {
  const cwd = process.cwd();
  if (looksLikeFHRoot(cwd)) return cwd;
  return path.resolve(__dirname, '..');
}

function readText(file) {
  return fs.readFileSync(file, 'utf8');
}

function maybeReadText(file) {
  try {
    return readText(file);
  } catch (_err) {
    return '';
  }
}

function exists(file) {
  try {
    fs.accessSync(file, fs.constants.F_OK);
    return true;
  } catch (_err) {
    return false;
  }
}

function walk(dir, predicate) {
  const results = [];
  if (!exists(dir)) return results;
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      results.push(...walk(p, predicate));
    } else if (!predicate || predicate(p)) {
      results.push(p);
    }
  }
  return results;
}

function rel(root, file) {
  return path.relative(root, file).split(path.sep).join('/');
}

function parseFrontmatter(text) {
  if (!text.startsWith('---\n')) return {};
  const end = text.indexOf('\n---', 4);
  if (end === -1) return {};
  const block = text.slice(4, end).split('\n');
  const out = {};
  for (const line of block) {
    const m = line.match(/^([A-Za-z0-9_-]+):\s*(.*)$/);
    if (!m) continue;
    out[m[1]] = m[2].replace(/^["']|["']$/g, '');
  }
  return out;
}

function extractBacktickNames(line) {
  const names = [];
  const re = /`([^`]+)`/g;
  let m;
  while ((m = re.exec(line)) !== null) {
    const value = m[1].trim();
    if (/^[a-z0-9][a-z0-9-]*$/.test(value)) names.push(value);
  }
  return names;
}

function documentedTiers(root) {
  const sources = [
    path.join(root, 'AGENTS.md'),
  ];
  const tiers = new Map();
  const evidence = [];
  for (const source of sources) {
    const text = maybeReadText(source);
    if (!text) continue;
    const lines = text.split('\n');
    lines.forEach((line, index) => {
      const tierMatch = line.match(/\|\s*\*\*(M[123])\b/);
      if (!tierMatch) return;
      const tier = tierMatch[1];
      for (const name of extractBacktickNames(line)) {
        tiers.set(name, { tier, source: rel(root, source), line: index + 1 });
        evidence.push({ name, tier, source: rel(root, source), line: index + 1 });
      }
    });
  }
  return { tiers, evidence };
}

function compatDocTierMentions(root, skillNames) {
  const source = path.join(root, 'docs', 'codex-compat.md');
  const text = maybeReadText(source);
  const mentions = new Map();
  if (!text) return mentions;
  const lines = text.split('\n');
  lines.forEach((line, index) => {
    const tierMatch = line.match(/\b(M[123])\b/);
    if (!tierMatch) return;
    const tier = tierMatch[1];
    for (const name of extractBacktickNames(line)) {
      if (!skillNames.has(name)) continue;
      if (!mentions.has(name)) mentions.set(name, []);
      mentions.get(name).push({ tier, source: rel(root, source), line: index + 1 });
    }
  });
  return mentions;
}

const PRIMITIVES = [
  {
    id: 'agent-dispatch',
    severity: 'adapter',
    regexes: [/Agent\s*\(/, /\bsubagent_type\b/, /\bAgent View\b/, /\bAgent\b tool\b/, /\bAgent invocation instruction\b/, /\bparallel-Agent dispatch\b/],
  },
  {
    id: 'slash-command',
    severity: 'adapter',
    regexes: [/(^|[\s`])\/[a-z][a-z0-9-]+(?=($|[\s`),.;:}]))/m],
  },
  {
    id: 'hook',
    severity: 'claude-native',
    regexes: [/\bStop hook\b/i, /\bPostToolUse\b/, /\bSessionStart\b/],
  },
  {
    id: 'model-command',
    severity: 'claude-native',
    regexes: [/(^|[\s`])\/model\b/m],
  },
];

function scanPrimitives(text) {
  const hits = [];
  for (const primitive of PRIMITIVES) {
    for (const regex of primitive.regexes) {
      const m = regex.exec(text);
      if (!m) continue;
      hits.push({
        id: primitive.id,
        severity: primitive.severity,
        line: text.slice(0, m.index).split('\n').length,
        match: m[0].trim(),
      });
      break;
    }
  }
  return hits;
}

function classify(docTier, primitives) {
  const hasClaudeNative = primitives.some((p) => p.severity === 'claude-native');
  const hasAgentDispatch = primitives.some((p) => p.id === 'agent-dispatch');
  const hasAdapter = primitives.some((p) => p.severity === 'adapter');
  if (docTier === 'M1' && (hasClaudeNative || hasAgentDispatch)) return 'tier-drift';
  if (docTier === 'M1') return 'codex-native';
  if (docTier === 'M2') return 'adapter-required';
  if (docTier === 'M3') return 'claude-native';
  if (hasClaudeNative) return 'claude-native-unclassified';
  if (hasAdapter) return 'adapter-required-unclassified';
  return 'codex-native-candidate';
}

function collectSkills(root) {
  const skillsRoot = path.join(root, 'plugins');
  const files = walk(skillsRoot, (p) => path.basename(p) === 'SKILL.md');
  return files.sort().map((file) => {
    const text = readText(file);
    const fm = parseFrontmatter(text);
    const skillName = fm.name || path.basename(path.dirname(file));
    return {
      type: 'skill',
      name: skillName,
      path: rel(root, file),
      frontmatter: fm,
      primitives: scanPrimitives(text),
    };
  });
}

function collectAgents(root) {
  const agents = [];
  for (const plugin of ['fh-meta', 'fh-commons']) {
    const dir = path.join(root, 'plugins', plugin, 'agents');
    for (const file of walk(dir, (p) => p.endsWith('.md')).sort()) {
      const text = readText(file);
      agents.push({
        type: 'agent',
        name: path.basename(file, '.md'),
        path: rel(root, file),
        plugin,
        primitives: scanPrimitives(text),
      });
    }
  }
  return agents;
}

function loadAgentCards(root) {
  const file = path.join(root, '.claude', 'registry', 'agent_cards.json');
  if (!exists(file)) return { present: false, count: 0 };
  try {
    const parsed = JSON.parse(readText(file));
    const count = Array.isArray(parsed)
      ? parsed.length
      : (Array.isArray(parsed.agents) ? parsed.agents.length : (parsed.agent_count || Object.keys(parsed).length));
    return { present: true, path: rel(root, file), count };
  } catch (err) {
    return { present: true, path: rel(root, file), error: err.message, count: 0 };
  }
}

function buildReport(root) {
  const docs = documentedTiers(root);
  const skills = collectSkills(root).map((skill) => {
    const doc = docs.tiers.get(skill.name);
    return {
      ...skill,
      documentedTier: doc ? doc.tier : null,
      tierEvidence: doc || null,
      codexMode: classify(doc && doc.tier, skill.primitives),
    };
  });
  const agents = collectAgents(root);
  const skillNames = new Set(skills.map((s) => s.name));
  const compatMentions = compatDocTierMentions(root, skillNames);
  const findings = [];

  for (const item of skills) {
    if (item.documentedTier === 'M1') {
      const bad = item.primitives.filter((p) => p.severity === 'claude-native' || p.id === 'agent-dispatch');
      if (bad.length > 0) {
        findings.push({
          severity: 'HIGH',
          code: 'M1_HAS_CLAUDE_NATIVE_PRIMITIVE',
          path: item.path,
          message: `${item.name} is documented M1 but contains ${bad.map((p) => p.id).join(', ')}`,
        });
      }
    }
  }

  for (const entry of docs.evidence) {
    if (!skillNames.has(entry.name)) {
      findings.push({
        severity: 'WARN',
        code: 'DOC_TIER_REFERENCES_MISSING_SKILL',
        path: `${entry.source}:${entry.line}`,
        message: `${entry.name} is listed as ${entry.tier} but no matching SKILL.md was found`,
      });
    }
  }

  for (const item of skills) {
    const mentions = compatMentions.get(item.name) || [];
    for (const mention of mentions) {
      if (item.documentedTier && mention.tier !== item.documentedTier) {
        findings.push({
          severity: 'HIGH',
          code: 'CODEX_COMPAT_TIER_DISAGREES_WITH_AGENTS',
          path: `${mention.source}:${mention.line}`,
          message: `${item.name} is ${item.documentedTier} in AGENTS.md but ${mention.tier} in docs/codex-compat.md`,
        });
      }
    }
  }

  const counts = {
    skills: skills.length,
    agents: agents.length,
    modes: {},
    tiers: { M1: 0, M2: 0, M3: 0, unclassified: 0 },
    findings: {
      HIGH: findings.filter((f) => f.severity === 'HIGH').length,
      WARN: findings.filter((f) => f.severity === 'WARN').length,
    },
  };
  for (const skill of skills) {
    counts.modes[skill.codexMode] = (counts.modes[skill.codexMode] || 0) + 1;
    counts.tiers[skill.documentedTier || 'unclassified'] += 1;
  }

  return {
    status: findings.some((f) => f.severity === 'HIGH') ? 'DRIFT' : 'OK',
    root,
    counts,
    agentCards: loadAgentCards(root),
    findings,
    skills,
    agents: agents.map((agent) => ({
      name: agent.name,
      path: agent.path,
      plugin: agent.plugin,
      codexMode: 'adapter-runnable',
      note: 'Agents are runnable via fh-run --agent or a runtime-specific dispatch adapter; auto-dispatch is host-specific.',
    })),
  };
}

function printText(report) {
  const lines = [];
  lines.push('FH Codex Doctor');
  lines.push(`Status: ${report.status}`);
  lines.push(`Root: ${report.root}`);
  lines.push('');
  lines.push('Summary');
  lines.push(`- Skills scanned: ${report.counts.skills}`);
  lines.push(`- Agents scanned: ${report.counts.agents}`);
  lines.push(`- Documented tiers: M1=${report.counts.tiers.M1} M2=${report.counts.tiers.M2} M3=${report.counts.tiers.M3} unclassified=${report.counts.tiers.unclassified}`);
  lines.push(`- Codex modes: ${Object.keys(report.counts.modes).sort().map((k) => `${k}=${report.counts.modes[k]}`).join(' ')}`);
  if (report.agentCards.present) {
    lines.push(`- Agent cards: ${report.agentCards.count}${report.agentCards.error ? ` (parse error: ${report.agentCards.error})` : ''}`);
  } else {
    lines.push('- Agent cards: missing');
  }
  lines.push('');
  lines.push('Findings');
  if (report.findings.length === 0) {
    lines.push('- none');
  } else {
    for (const finding of report.findings) {
      lines.push(`- ${finding.severity} ${finding.code} ${finding.path} :: ${finding.message}`);
    }
  }
  lines.push('');
  lines.push('Codex Runtime Contract');
  lines.push('- codex-native: run directly with fh-run/codex exec.');
  lines.push('- adapter-required: core method can run, but Agent/slash steps need adapter substitution.');
  lines.push('- claude-native: do not auto-pass; require Claude Code host or explicit dedicated adapter.');
  lines.push('- unclassified modes are drift signals for future manifest backfill.');
  process.stdout.write(`${lines.join('\n')}\n`);
}

function main() {
  let args;
  try {
    args = parseArgs(process.argv.slice(2));
  } catch (err) {
    process.stderr.write(`ERROR: ${err.message}\n`);
    usage();
    process.exit(11);
  }
  if (args.help) {
    usage();
    return;
  }
  const root = args.root;
  if (!exists(path.join(root, 'package.json'))) {
    process.stderr.write(`ERROR: root does not look like a package/repo root: ${root}\n`);
    process.exit(11);
  }
  if (!looksLikeFHRoot(root)) {
    process.stderr.write(`ERROR: root is missing required FH surfaces (AGENTS.md and plugins/): ${root}\n`);
    process.exit(11);
  }
  const report = buildReport(root);
  if (args.json) {
    process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
  } else {
    printText(report);
  }
  if (args.strict && report.counts.findings.HIGH > 0) {
    process.exit(1);
  }
}

main();

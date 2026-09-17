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

// The root predicate is derived from what buildReport() actually READS, not from what "FH root"
// suggests. Two surfaces are load-bearing:
//   · AGENTS.md            — documentedTiers()'s only source; absent ⇒ INSTRUMENT_ERROR (exit 10)
//   · plugins/**/SKILL.md  — collectSkills()/collectAgents()'s only subject
// `package.json` used to be required here and in main(). It is never OPENED anywhere in this file
// (the only two references were this predicate and main()'s gate), so the gate asserted a property
// nothing downstream consumes — and it made a shipped npm binary structurally unusable for every
// non-npm consumer harness that has all the audited surfaces (measured on a consumer harness that
// carries AGENTS.md with
// a tier table, plugins/ with 41 SKILL.md, .claude/registry/agent_cards.json — and no package.json).
//
// 🟥 The inverse error is the real hazard, so this is NOT merely a loosening. A random directory
// must not produce a confident empty report: the SKILL.md leg requires plugins/ to hold at least one
// skill, because an EMPTY plugins/ would otherwise yield `Skills scanned: 0` / `Findings: none` /
// `Status: OK` — "not found rendered as zero", this repo's named failure family. Degrade direction
// is unchanged: a genuinely wrong root still exits 11, loudly, naming each missing surface.
//
// 🟥 THREE NON-ZERO CLASSES, KEPT DISTINCT. The loosened predicate's hazard is not only fail-open,
// it is EXIT-CODE COLLAPSE: any surface whose shape the predicate stopped asserting used to reach
// `readdirSync`/`readFileSync` and throw, and an uncaught node exception is rc=1 — which is already
// spoken for by "--strict found HIGH drift". A caller cannot then tell "the harness broke" from
// "the harness found something". So:
//     11 = wrong root      (a surface is absent, or present with the wrong SHAPE)
//     10 = instrument/input error (a surface is there but unusable: unreadable, unparseable)
//      1 = --strict with HIGH findings   ← reserved. Nothing structural may land here.
function missingAuditSurfaces(dir, inputErrors) {
  const missing = [];
  const sink = inputErrors || [];
  if (!exists(path.join(dir, 'AGENTS.md'))) {
    missing.push('AGENTS.md — the tier table this doctor measures every skill against');
  }
  const pluginsDir = path.join(dir, 'plugins');
  if (!exists(pluginsDir)) {
    missing.push('plugins/ — the skill/agent surface to be audited');
  } else if (!isDirectory(pluginsDir)) {
    // `plugins` present but not a directory (a file, a device node, a symlink to one). This is a
    // ROOT-SHAPE fault, so it belongs at 11 alongside absence — measured before this branch existed:
    // walk() called readdirSync on it, threw ENOTDIR uncaught, and exited 1.
    missing.push('plugins/ — present but NOT a directory, so it cannot hold skills/agents');
  } else {
    const found = walk(pluginsDir, (p) => path.basename(p) === 'SKILL.md', sink);
    // 🟥 `sink.length` guard: a plugins/ that cannot be ENUMERATED yields 0 hits for a reason that
    // is not absence. Claiming "holds no skill" there would be this repo's not-found-is-zero family
    // wearing an exit code. Enumeration failure is an input error (10), handled by the caller.
    if (found.length === 0 && sink.length === 0) {
      missing.push('plugins/**/SKILL.md — plugins/ exists but holds no skill to classify');
    }
  }
  return missing;
}

function looksLikeFHRoot(dir) {
  return missingAuditSurfaces(dir).length === 0;
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

function isDirectory(p) {
  try {
    return fs.statSync(p).isDirectory();
  } catch (_err) {
    return false;
  }
}

// `errors` is an optional sink. A directory that EXISTS but cannot be enumerated must not return
// [] silently — that is a measurement failure rendered as an empty subject. With a sink the caller
// classifies it (→ exit 10); without one it throws, so the fault can never be swallowed by default.
function walk(dir, predicate, errors) {
  const results = [];
  if (!exists(dir)) return results;
  let entries;
  try {
    entries = fs.readdirSync(dir, { withFileTypes: true });
  } catch (err) {
    if (!errors) throw err;
    errors.push(`${dir}: directory exists but cannot be enumerated — ${err.code || err.message}`);
    return results;
  }
  for (const entry of entries) {
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      results.push(...walk(p, predicate, errors));
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

// The tier table IS this doctor's instrument. If it cannot be read or parsed, every skill
// comes back documentedTier=null, no M1 rule can ever fire, findings is empty, and the report
// says OK with --strict exiting 0 — a broken instrument reporting "no violations". An
// unreadable source (permissions, wrong root) and a parse yielding zero rows (the table's
// markdown drifted, e.g. bold dropped from `| **M1 |`) both land there, so both are reported
// as an instrument failure rather than a clean bill of health.
function documentedTiers(root) {
  const sources = [
    path.join(root, 'AGENTS.md'),
  ];
  const tiers = new Map();
  const evidence = [];
  const sourceErrors = [];
  for (const source of sources) {
    const text = maybeReadText(source);
    if (!text) {
      sourceErrors.push(`${rel(root, source)}: missing or unreadable`);
      continue;
    }
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
  if (tiers.size === 0 && sourceErrors.length === 0) {
    sourceErrors.push(
      `${rel(root, sources[0])}: readable but yielded 0 tier rows — the tier table format drifted`
    );
  }
  return { tiers, evidence, sourceErrors };
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

// `inputErrors` is required, not optional. A SKILL.md that walk() listed but readText() cannot open
// — chmod 000, a broken symlink, a file deleted between the scan and the read — used to throw out of
// here uncaught: rc=1, the same code as "--strict found HIGH drift". The subject being unreadable is
// an INPUT fault (10), and the diagnostic names the path so the caller can fix the input rather than
// re-run hunting for a finding that was never made.
function collectSkills(root, inputErrors) {
  const skillsRoot = path.join(root, 'plugins');
  const files = walk(skillsRoot, (p) => path.basename(p) === 'SKILL.md', inputErrors);
  const skills = [];
  for (const file of files.sort()) {
    let text;
    try {
      text = readText(file);
    } catch (err) {
      inputErrors.push(`${rel(root, file)}: skill input unreadable — ${err.code || err.message}`);
      continue;
    }
    const fm = parseFrontmatter(text);
    const skillName = fm.name || path.basename(path.dirname(file));
    skills.push({
      type: 'skill',
      name: skillName,
      path: rel(root, file),
      frontmatter: fm,
      // An empty or frontmatter-less SKILL.md gave the classifier nothing to classify. It already
      // lands in `unclassified`, but `unclassified` is also where a merely-undocumented-but-real
      // skill lands, so the two are indistinguishable in the summary. WARN (not HIGH, not 10):
      // the run did measure the surface, it just measured an empty one.
      emptyInput: text.trim() === '' || Object.keys(fm).length === 0,
      primitives: scanPrimitives(text),
    });
  }
  return skills;
}

// Plugin namespaces are DISCOVERED, not hardcoded. The previous list was ['fh-meta','fh-commons'],
// which renders "Agents scanned: 0" for any consumer whose plugins carry a different prefix
// (a consumer harness names its namespaces after ITSELF, e.g. <prefix>-meta/ and <prefix>-commons/,
// each with an agents/ dir) — the same not-found-is-zero family
// as the gate above, and it would have been the first thing a newly-unblocked consumer saw.
// No change for FH itself: its other plugin dirs (fh-preprep, fh-qp) ship no agents/ dir, so walk()
// returns [] for them and the count stays 14. Sorted for determinism.
//
// 🟥 DISCOVERED-BY-SHAPE, NOT BY NAME, AND NOT BY "any subdirectory". The first version accepted
// every directory immediately under plugins/, so `plugins/node_modules/`, a stale copy, a scratch
// dir, or `plugins/not-a-plugin/agents/ghost.md` all INFLATED `Agents scanned` — "the count is true
// but the referent drifted". The discriminator is the plugin manifest, because that is the file a
// real plugin must carry (verified present in all 4 FH plugins and in both plugins of a consumer
// harness measured off-tree) and it is
// prefix-independent: a consumer's <prefix>-meta/ resolves exactly as fh-meta/ does. A NAME filter
// would have re-broken the consumer axis lane6 exists to hold.
function isPluginShaped(dir) {
  return exists(path.join(dir, '.claude-plugin', 'plugin.json'));
}

// Two degrade rules, both aimed at the same failure family:
//   · NO manifest anywhere → shape is UNDETECTABLE on this root, which is not the same as "zero
//     plugins". Fall back to every subdirectory so a manifest-less consumer stays auditable, and
//     WARN that the count is unfiltered — a reader must not read it as shape-verified.
//   · Manifests exist but a dir lacks one AND still carries agents/ or skills/ → that is exactly
//     the material the old code counted. It is DROPPED, so the drop is named in a WARN. A silent
//     drop and a silent over-count are the same defect pointing opposite ways.
function pluginNamespaces(root, warnings) {
  const base = path.join(root, 'plugins');
  if (!isDirectory(base)) return [];
  let entries;
  try {
    entries = fs.readdirSync(base, { withFileTypes: true });
  } catch (err) {
    if (warnings) {
      warnings.push({
        severity: 'WARN',
        code: 'PLUGIN_DIR_UNENUMERABLE',
        path: rel(root, base),
        message: `plugins/ could not be enumerated for agent discovery — ${err.code || err.message}`,
      });
    }
    return [];
  }
  const dirs = entries.filter((entry) => entry.isDirectory()).map((entry) => entry.name).sort();
  const shaped = dirs.filter((name) => isPluginShaped(path.join(base, name)));
  if (shaped.length === 0) {
    if (warnings && dirs.length > 0) {
      warnings.push({
        severity: 'WARN',
        code: 'PLUGIN_SHAPE_UNDETECTABLE',
        path: rel(root, base),
        message: `no .claude-plugin/plugin.json under any of ${dirs.length} plugins/ subdirectories — agent discovery fell back to UNFILTERED subdirectory scan (${dirs.join(', ')})`,
      });
    }
    return dirs;
  }
  const shapedSet = new Set(shaped);
  for (const name of dirs) {
    if (shapedSet.has(name)) continue;
    const dir = path.join(base, name);
    if (!isDirectory(path.join(dir, 'agents')) && !isDirectory(path.join(dir, 'skills'))) continue;
    if (!warnings) continue;
    warnings.push({
      severity: 'WARN',
      code: 'PLUGIN_NAMESPACE_NOT_PLUGIN_SHAPED',
      path: rel(root, dir),
      message: `plugins/${name}/ carries agents/ or skills/ content but no .claude-plugin/plugin.json — EXCLUDED from agent discovery, so it is not counted`,
    });
  }
  return shaped;
}

function collectAgents(root, inputErrors, warnings) {
  const agents = [];
  for (const plugin of pluginNamespaces(root, warnings)) {
    const dir = path.join(root, 'plugins', plugin, 'agents');
    for (const file of walk(dir, (p) => p.endsWith('.md'), inputErrors).sort()) {
      let text;
      try {
        text = readText(file);
      } catch (err) {
        inputErrors.push(`${rel(root, file)}: agent input unreadable — ${err.code || err.message}`);
        continue;
      }
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
  const inputErrors = [];
  const shapeWarnings = [];
  const skills = collectSkills(root, inputErrors).map((skill) => {
    const doc = docs.tiers.get(skill.name);
    return {
      ...skill,
      documentedTier: doc ? doc.tier : null,
      tierEvidence: doc || null,
      codexMode: classify(doc && doc.tier, skill.primitives),
    };
  });
  const agents = collectAgents(root, inputErrors, shapeWarnings);
  const skillNames = new Set(skills.map((s) => s.name));
  const compatMentions = compatDocTierMentions(root, skillNames);
  const findings = [];
  findings.push(...shapeWarnings);

  for (const item of skills) {
    if (item.emptyInput) {
      findings.push({
        severity: 'WARN',
        code: 'SKILL_MD_HAS_NO_CLASSIFIABLE_CONTENT',
        path: item.path,
        message: `${item.name} is empty or carries no parseable frontmatter — it was counted as a skill but nothing could be classified from it`,
      });
    }
  }

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
    // INSTRUMENT_ERROR outranks both: without a tier table this run measured nothing, and
    // "measured nothing" must not be reported as OK (nor as DRIFT, which would claim a
    // finding it never made).
    // An UNREADABLE SUBJECT sits in the same class as an unreadable instrument: the run did not
    // measure what it claims to have measured, so it may not report OK — and it may not report
    // rc=1 either, which would be indistinguishable from a real drift finding.
    status: (docs.sourceErrors.length > 0 || inputErrors.length > 0)
      ? 'INSTRUMENT_ERROR'
      : findings.some((f) => f.severity === 'HIGH') ? 'DRIFT' : 'OK',
    instrumentErrors: docs.sourceErrors,
    inputErrors,
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
  // One gate, one predicate — see missingAuditSurfaces(). It names every missing surface rather
  // than the first, so a consumer fixes the root in one pass instead of one exit code at a time.
  // The sink separates the two classes at the ONE place they are both visible: an absent or
  // wrong-shaped surface is a wrong root (11); a present-but-unenumerable one is an input fault (10).
  const preflightErrors = [];
  const missing = missingAuditSurfaces(root, preflightErrors);
  if (preflightErrors.length > 0) {
    for (const err of preflightErrors) {
      process.stderr.write(`ERROR: audited surface unusable — ${err}\n`);
    }
    process.stderr.write('  The surface exists but could not be read, so nothing was measured. Failing closed.\n');
    process.exit(10);
  }
  if (missing.length > 0) {
    process.stderr.write(`ERROR: root is missing the surfaces this doctor audits: ${root}\n`);
    for (const item of missing) {
      process.stderr.write(`  - missing: ${item}\n`);
    }
    process.stderr.write('  Nothing could be classified from this root. Failing closed.\n');
    process.exit(11);
  }
  const report = buildReport(root);
  if (args.json) {
    process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
  } else {
    printText(report);
  }
  // An instrument failure is not a passing run. It exits non-zero unconditionally — not only
  // under --strict — because the failure mode it guards is precisely a caller reading exit 0
  // as "no drift" when nothing was measured. 10 = harness error, distinct from 1 = drift found.
  if (report.status === 'INSTRUMENT_ERROR') {
    for (const err of report.instrumentErrors) {
      process.stderr.write(`ERROR: tier source unusable — ${err}\n`);
    }
    for (const err of report.inputErrors) {
      process.stderr.write(`ERROR: audited input unusable — ${err}\n`);
    }
    process.stderr.write('  Nothing was classified, so no drift could be detected. Failing closed.\n');
    process.exit(10);
  }
  if (args.strict && report.counts.findings.HIGH > 0) {
    process.exit(1);
  }
}

main();

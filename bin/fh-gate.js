#!/usr/bin/env node
'use strict';
// Thin wrapper — the exit code IS the contract (0 PASS / 1 PENDING / 2 BLOCKED /
// 3 ESCALATE / 10 harness-error / 11 arg-error / 12 dry-run). execFileSync throws on any
// non-zero exit, so an uncaught throw collapsed every one of them into node's own exit 1 —
// i.e. BLOCKED arrived at the caller as PENDING ("proceed with awareness"). Propagate the
// real status, and fail closed (10) when there is no status to propagate.
const { execFileSync } = require('child_process');
const path = require('path');
try {
  execFileSync(
    path.join(__dirname, '..', 'scripts', 'fh-gate.sh'),
    process.argv.slice(2),
    { stdio: 'inherit' }
  );
} catch (err) {
  if (typeof err.status === 'number') process.exit(err.status);
  // Killed by a signal, or the script could not be spawned at all: no verdict exists.
  console.error(`fh-gate: could not run the gate (${err.signal || err.code || err.message}) — failing closed`);
  process.exit(10);
}

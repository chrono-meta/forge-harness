#!/usr/bin/env node
'use strict';
// Thin wrapper — propagate the script's real exit status. execFileSync throws on non-zero,
// so an uncaught throw collapsed every distinct status into node's own exit 1.
const { execFileSync } = require('child_process');
const path = require('path');
try {
  execFileSync(
    path.join(__dirname, '..', 'scripts', 'fh-run.sh'),
    process.argv.slice(2),
    { stdio: 'inherit' }
  );
} catch (err) {
  if (typeof err.status === 'number') process.exit(err.status);
  console.error(`fh-run: could not run (${err.signal || err.code || err.message}) — failing closed`);
  process.exit(10);
}

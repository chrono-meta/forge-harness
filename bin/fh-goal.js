#!/usr/bin/env node
'use strict';
const { execFileSync } = require('child_process');
const path = require('path');
execFileSync(
  path.join(__dirname, '..', 'scripts', 'fh-goal.sh'),
  process.argv.slice(2),
  { stdio: 'inherit' }
);

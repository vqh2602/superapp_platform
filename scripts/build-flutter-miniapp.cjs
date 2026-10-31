#!/usr/bin/env node
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const bundledFlutter = path.resolve(__dirname, '../.fvm/flutter_sdk/bin/flutter');
const flutter = process.env.FLUTTER_BIN || (fs.existsSync(bundledFlutter) ? bundledFlutter : 'flutter');
for (const [command, args] of [
  [flutter, ['build', 'web', '--release', '--no-web-resources-cdn']],
  [process.execPath, ['postbuild.js']],
]) {
  const result = spawnSync(command, args, { cwd: process.cwd(), stdio: 'inherit' });
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status || 1);
}

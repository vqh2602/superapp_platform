#!/usr/bin/env node
// Package an already-built Mini App. Never execute source from the input folder.
const fs = require('node:fs');
const path = require('node:path');
const { ZipFile } = require('yazl');

(async () => {
  if (!process.argv[2]) throw new Error('Usage: npm run package:miniapp -- <package-folder> [output.zip]');
  const root = path.resolve(process.argv[2]);
  const manifest = JSON.parse(fs.readFileSync(path.join(root, 'app.json'), 'utf8'));
  const { PackageService } = require('../dist/modules/registry/packages/package.service');
  const zip = new ZipFile();
  function add(folder, prefix = '') {
    for (const item of fs.readdirSync(folder, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
      if (item.name.startsWith('.') || item.name === 'node_modules') throw new Error('Package folder must contain release files only');
      const name = prefix + item.name;
      if (item.isSymbolicLink()) throw new Error('Symlinks are not allowed');
      if (item.isDirectory()) add(path.join(folder, item.name), name + '/');
      else zip.addFile(path.join(folder, item.name), name);
    }
  }
  add(root);
  const chunks = [];
  const buffer = new Promise((resolve, reject) => {
    zip.outputStream.on('data', chunk => chunks.push(chunk));
    zip.outputStream.on('end', () => resolve(Buffer.concat(chunks)));
    zip.outputStream.on('error', reject);
  });
  zip.end();
  const content = await buffer;
  const validated = await new PackageService().inspect(content, manifest.appId);
  const output = path.resolve(process.argv[3] || `${manifest.appId}-${manifest.version}.zip`);
  fs.writeFileSync(output, content);
  console.log(`${output}\n${manifest.appId} v${manifest.version} · ${validated.files.size} files · SHA256 ${validated.checksum}`);
})().catch(error => { console.error(error.message || error); process.exitCode = 1; });

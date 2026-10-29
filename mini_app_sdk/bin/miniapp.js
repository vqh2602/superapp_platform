#!/usr/bin/env node

import('../dist/cli/index.js').catch((err) => {
  console.error('[miniapp fatal error]', err);
  process.exit(1);
});

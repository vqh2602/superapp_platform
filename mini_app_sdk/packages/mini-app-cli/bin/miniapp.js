#!/usr/bin/env node

import('../dist/index.js').catch((err) => {
  console.error('[miniapp-cli fatal error]', err);
  process.exit(1);
});

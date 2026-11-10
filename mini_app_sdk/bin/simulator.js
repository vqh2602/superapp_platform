#!/usr/bin/env node

import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
let distDir = path.resolve(__dirname, '../simulator-dist');
if (!fs.existsSync(distDir)) {
  distDir = path.resolve(__dirname, '../dist/simulator');
}

const args = process.argv.slice(2);
if (args.includes('--help') || args.includes('-h')) {
  console.log(`
Usage: superapp-simulator [options]

Options:
  --port <number>    Port to run simulator on (default: 5175)
  --host <string>    Host interface to bind to (default: 127.0.0.1)
  -h, --help         Show this help message
`);
  process.exit(0);
}

const portIndex = args.indexOf('--port');
const port = portIndex !== -1 && args[portIndex + 1] ? parseInt(args[portIndex + 1], 10) : 5175;

const hostIndex = args.indexOf('--host');
const host = hostIndex !== -1 && args[hostIndex + 1] ? args[hostIndex + 1] : '127.0.0.1';

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.woff2': 'font/woff2',
};

function isAllowedCorsOrigin(origin) {
  if (!origin || typeof origin !== 'string') return false;
  try {
    const url = new URL(origin);
    return (
      url.hostname === 'localhost' ||
      url.hostname === '127.0.0.1' ||
      url.hostname === '[::1]' ||
      url.hostname.endsWith('.localhost')
    );
  } catch (_) {
    return false;
  }
}

const server = http.createServer((req, res) => {
  // Restricted CORS policy: only allow trusted local origins
  const reqOrigin = req.headers.origin;
  if (reqOrigin && isAllowedCorsOrigin(reqOrigin)) {
    res.setHeader('Access-Control-Allow-Origin', reqOrigin);
    res.setHeader('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, x-tenant-id');
    res.setHeader('Vary', 'Origin');
  }

  // Security Headers
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'SAMEORIGIN');
  res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  const parsedUrl = new URL(req.url, `http://${host}:${port}`);
  let pathname = parsedUrl.pathname;
  let filePath = path.join(distDir, pathname);

  if (!filePath.startsWith(distDir)) {
    res.writeHead(403);
    res.end('Forbidden');
    return;
  }

  fs.stat(filePath, (err, stats) => {
    if (err || !stats.isFile()) {
      filePath = path.join(distDir, 'index.html');
    }

    const ext = path.extname(filePath).toLowerCase();
    const contentType = MIME_TYPES[ext] || 'application/octet-stream';

    fs.readFile(filePath, (readErr, data) => {
      if (readErr) {
        res.writeHead(404);
        res.end('Not Found');
        return;
      }
      res.writeHead(200, { 'Content-Type': contentType });
      res.end(data);
    });
  });
});

server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    console.error(`\n❌ \x1b[31mError: Port ${port} is already in use.\x1b[0m Try passing a different port with: \x1b[33m--port <port>\x1b[0m\n`);
    process.exit(1);
  } else {
    console.error(`\n❌ Server error: ${err.message}\n`);
    process.exit(1);
  }
});

server.listen(port, host, () => {
  console.log(`\n📱 \x1b[36mSuperApp Browser Simulator\x1b[0m is running at: \x1b[1mhttp://${host}:${port}\x1b[0m`);
  console.log(`🔗 Open with target Mini App: \x1b[32mhttp://${host}:${port}/?url=http://localhost:3000\x1b[0m\n`);
});
